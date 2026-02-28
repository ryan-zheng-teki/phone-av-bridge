#!/usr/bin/env python3
import os
import platform
import re
import shutil
import subprocess
import tempfile
from abc import ABC, abstractmethod
from typing import Optional


class AudioCaptureBackend(ABC):
    @property
    @abstractmethod
    def backend_name(self) -> str:
        raise NotImplementedError

    @abstractmethod
    def ensure_prereqs(self) -> None:
        raise NotImplementedError

    @abstractmethod
    def build_record_command(self, source: str, sample_rate: int) -> list[str]:
        raise NotImplementedError

    @abstractmethod
    def default_source(self) -> str:
        raise NotImplementedError

    @abstractmethod
    def candidate_sources(self) -> list[str]:
        raise NotImplementedError

    def normalize_source(self, source: str) -> str:
        value = (source or "").strip()
        return value or self.default_source()

    def resolve_source(self, configured_source: str, sample_rate: int) -> str:
        explicit = (configured_source or "").strip()
        if explicit:
            return self.normalize_source(explicit)

        candidates = self.candidate_sources()
        if not candidates:
            return self.default_source()

        for source in candidates:
            if self.source_supports_capture(source=source, sample_rate=sample_rate):
                return source
        return candidates[0]

    def source_supports_capture(self, source: str, sample_rate: int) -> bool:
        fd, probe_path = tempfile.mkstemp(prefix="voice-gemini-probe-", suffix=".raw")
        os.close(fd)
        try:
            with open(probe_path, "wb") as output_file:
                proc = subprocess.Popen(
                    self.build_record_command(source=source, sample_rate=sample_rate),
                    stdout=output_file,
                    stderr=subprocess.DEVNULL,
                    text=False,
                )
            try:
                proc.wait(timeout=0.55)
            except subprocess.TimeoutExpired:
                proc.terminate()
                try:
                    proc.wait(timeout=0.5)
                except subprocess.TimeoutExpired:
                    proc.kill()
            try:
                return os.path.getsize(probe_path) > 0
            except OSError:
                return False
        finally:
            try:
                os.remove(probe_path)
            except OSError:
                pass


class PulseAudioBackend(AudioCaptureBackend):
    @property
    def backend_name(self) -> str:
        return "linux-pulse"

    def ensure_prereqs(self) -> None:
        if shutil.which("parec") is None:
            raise RuntimeError("parec not found in PATH (install pulseaudio-utils).")
        if shutil.which("pactl") is None:
            raise RuntimeError("pactl not found in PATH.")

    def default_source(self) -> str:
        return "default"

    def build_record_command(self, source: str, sample_rate: int) -> list[str]:
        return [
            "parec",
            "--device",
            self.normalize_source(source),
            "--format",
            "s16le",
            "--channels",
            "1",
            "--rate",
            str(sample_rate),
        ]

    def candidate_sources(self) -> list[str]:
        try:
            result = subprocess.run(
                ["pactl", "list", "short", "sources"],
                capture_output=True,
                text=True,
                check=False,
            )
        except Exception:
            return [self.default_source()]
        if result.returncode != 0:
            return [self.default_source()]

        raw_sources: list[str] = []
        for line in result.stdout.splitlines():
            parts = line.strip().split("\t")
            if len(parts) < 2:
                continue
            raw_sources.append(parts[1].strip())

        if not raw_sources:
            return [self.default_source()]

        def is_monitor(name: str) -> bool:
            return name.endswith(".monitor")

        preferred_non_monitor = [
            name
            for name in raw_sources
            if not is_monitor(name)
            and not name.startswith("phone_av_bridge_mic_input_")
            and not name.startswith("phone_av_bridge_mic_sink_")
        ]
        bridge_monitor = [
            name
            for name in raw_sources
            if name.startswith("phone_av_bridge_mic_sink_") and is_monitor(name)
        ]
        bridge_input = [name for name in raw_sources if name.startswith("phone_av_bridge_mic_input_")]

        ordered: list[str] = []
        for name in preferred_non_monitor + bridge_monitor + bridge_input + raw_sources + [self.default_source()]:
            if name and name not in ordered:
                ordered.append(name)
        return ordered


class MacOSAvFoundationBackend(AudioCaptureBackend):
    @property
    def backend_name(self) -> str:
        return "macos-avfoundation"

    def ensure_prereqs(self) -> None:
        if shutil.which("ffmpeg") is None:
            raise RuntimeError("ffmpeg not found in PATH (install via Homebrew: brew install ffmpeg).")

    def default_source(self) -> str:
        value = (os.environ.get("VOICE_GEMINI_MACOS_AUDIO_INDEX") or "0").strip()
        return value or "0"

    def normalize_source(self, source: str) -> str:
        value = (source or "").strip()
        if not value:
            return self.default_source()
        if value.startswith(":"):
            value = value[1:]
        return value or self.default_source()

    def build_record_command(self, source: str, sample_rate: int) -> list[str]:
        normalized_source = self.normalize_source(source)
        return [
            "ffmpeg",
            "-hide_banner",
            "-loglevel",
            "error",
            "-nostdin",
            "-f",
            "avfoundation",
            "-i",
            f":{normalized_source}",
            "-ac",
            "1",
            "-ar",
            str(sample_rate),
            "-f",
            "s16le",
            "-acodec",
            "pcm_s16le",
            "-",
        ]

    def candidate_sources(self) -> list[str]:
        default = self.default_source()
        try:
            result = subprocess.run(
                [
                    "ffmpeg",
                    "-hide_banner",
                    "-f",
                    "avfoundation",
                    "-list_devices",
                    "true",
                    "-i",
                    "",
                ],
                capture_output=True,
                text=True,
                check=False,
            )
            output = f"{result.stdout}\n{result.stderr}"
        except Exception:
            return [default]

        sources: list[str] = []
        in_audio_section = False
        for line in output.splitlines():
            lowered = line.lower()
            if "avfoundation audio devices" in lowered:
                in_audio_section = True
                continue
            if "avfoundation video devices" in lowered:
                in_audio_section = False
                continue
            if not in_audio_section:
                continue
            match = re.search(r"\[(\d+)\]\s+", line)
            if not match:
                continue
            index = match.group(1)
            if index not in sources:
                sources.append(index)

        if default not in sources:
            sources.append(default)
        return sources


def select_audio_backend(system_name: Optional[str] = None) -> AudioCaptureBackend:
    selected_system = (system_name or platform.system() or "").strip().lower()
    if selected_system == "linux":
        return PulseAudioBackend()
    if selected_system == "darwin":
        return MacOSAvFoundationBackend()
    raise RuntimeError(
        f"unsupported platform '{selected_system or 'unknown'}' for voice recording backend."
    )
