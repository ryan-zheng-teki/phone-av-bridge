#!/usr/bin/env python3
import argparse
import os
import pty
import select
import shlex
import shutil
import signal
import subprocess
import sys
import tempfile
import termios
import tty
import wave
from dataclasses import dataclass
from typing import Optional


DEFAULT_MODEL = os.environ.get("STT_MODEL", "tiny.en")
DEFAULT_LANGUAGE = os.environ.get("STT_LANGUAGE", "en")
DEFAULT_DEVICE = os.environ.get("STT_DEVICE", "cpu")
DEFAULT_COMPUTE_TYPE = os.environ.get("STT_COMPUTE_TYPE", "int8")
DEFAULT_CODEX_CMD = os.environ.get("CODEX_CMD", "codex")
DEFAULT_RECORD_SOURCE = os.environ.get("VOICE_CODEX_RECORD_SOURCE", "").strip()
DEFAULT_SAMPLE_RATE = int(os.environ.get("VOICE_CODEX_SAMPLE_RATE", "16000"))
DEFAULT_RECORD_KEY = os.environ.get("VOICE_CODEX_RECORD_KEY", "ctrl-x").strip().lower()

CTRL_R_HOTKEY_BYTE = 0x12
CTRL_X_HOTKEY_BYTE = 0x18
ENTER_HOTKEY_BYTES = {0x0D, 0x0A}
RECORD_KEY_SEQUENCES = {
    "f8": [b"\x1b[19~"],
    "f9": [b"\x1b[20~"],
}
RECORD_KEY_CHOICES = {"ctrl-r", "ctrl-x", "enter", "f8", "f9"}
RECORD_KEY_LABELS = {
    "ctrl-r": "Ctrl+R",
    "ctrl-x": "Ctrl+X",
    "enter": "Enter",
    "f8": "F8",
    "f9": "F9",
}


def build_parec_record_command(
    source: str = DEFAULT_RECORD_SOURCE,
    sample_rate: int = DEFAULT_SAMPLE_RATE,
) -> list[str]:
    return [
        "parec",
        "--device",
        source,
        "--format",
        "s16le",
        "--channels",
        "1",
        "--rate",
        str(sample_rate),
    ]


def normalize_record_key(value: str) -> str:
    normalized = (value or "").strip().lower()
    if normalized in RECORD_KEY_CHOICES:
        return normalized
    return "ctrl-r"


def record_key_matches(byte: int, record_key: str) -> bool:
    key = normalize_record_key(record_key)
    if key == "enter":
        return byte in ENTER_HOTKEY_BYTES
    if key == "ctrl-x":
        return byte == CTRL_X_HOTKEY_BYTE
    return byte == CTRL_R_HOTKEY_BYTE


def record_key_sequence_matches(payload: bytes, record_key: str) -> int:
    key = normalize_record_key(record_key)
    if key in {"ctrl-r", "ctrl-x", "enter"}:
        if not payload:
            return 0
        return 1 if record_key_matches(payload[0], key) else 0
    for seq in RECORD_KEY_SEQUENCES.get(key, []):
        if payload.startswith(seq):
            return len(seq)
    return 0


def record_key_sequence_is_partial(payload: bytes, record_key: str) -> bool:
    key = normalize_record_key(record_key)
    if key in {"ctrl-r", "ctrl-x", "enter"}:
        return False
    for seq in RECORD_KEY_SEQUENCES.get(key, []):
        if seq.startswith(payload):
            return True
    return False


def compose_codex_command(command: str, extra_args: list[str]) -> str:
    base = (command or "").strip() or DEFAULT_CODEX_CMD
    remainder = [item for item in (extra_args or []) if item and item != "--"]
    if not remainder:
        return base
    return f"{base} {shlex.join(remainder)}"


@dataclass
class RecorderState:
    process: Optional[subprocess.Popen] = None
    raw_path: Optional[str] = None


class SttEngine:
    def __init__(self, model: str, device: str, compute_type: str):
        self.model_name = model
        self.device = device
        self.compute_type = compute_type
        self._model = None

    def _ensure_model(self):
        if self._model is not None:
            return self._model
        try:
            from faster_whisper import WhisperModel
        except ImportError as error:
            raise RuntimeError(
                "faster-whisper is not installed. Run: pip install -r requirements.txt"
            ) from error
        try:
            self._model = WhisperModel(
                self.model_name,
                device=self.device,
                compute_type=self.compute_type,
            )
        except Exception as error:
            if self.device.lower() == "auto" and "libcublas" in str(error).lower():
                self._model = WhisperModel(
                    self.model_name,
                    device="cpu",
                    compute_type="int8",
                )
            else:
                raise
        return self._model

    def transcribe_file(self, wav_path: str, language: str) -> str:
        model = self._ensure_model()
        segments, _info = model.transcribe(
            wav_path,
            language=language,
            vad_filter=True,
            beam_size=1,
            condition_on_previous_text=False,
        )
        parts = [segment.text.strip() for segment in segments if segment.text and segment.text.strip()]
        return " ".join(parts).strip()


class VoiceCodexCliBridge:
    def __init__(
        self,
        codex_command: str,
        language: str,
        model: str,
        device: str,
        compute_type: str,
        record_source: str,
        sample_rate: int,
        auto_send: bool,
        record_key: str,
    ):
        self.codex_command = codex_command
        self.language = language
        self.record_source = record_source
        self.sample_rate = sample_rate
        self.auto_send = auto_send
        self.record_key = normalize_record_key(record_key)
        self.stt_engine = SttEngine(model=model, device=device, compute_type=compute_type)

        self._master_fd: Optional[int] = None
        self._proc: Optional[subprocess.Popen] = None
        self._recorder = RecorderState()
        self._stdin_fd = sys.stdin.fileno()
        self._old_term = None
        self._stdin_pending = bytearray()
        self._transcript_draft = ""

    def run(self) -> int:
        self._ensure_prereqs()
        self._start_codex()
        self._enable_raw_stdin()

        key_label = RECORD_KEY_LABELS.get(self.record_key, "Ctrl+R")
        self._print_status(f"voice mode ready: press {key_label} to start/stop recording.")
        if self.auto_send:
            self._print_status("auto-send is enabled.")
        else:
            self._print_status("auto-send is disabled; transcript is printed only.")
        if self.record_key == "enter":
            self._print_status("warning: Enter is intercepted for voice toggle and will not submit normal prompts.")

        try:
            while True:
                if self._proc is None or self._master_fd is None:
                    return 1
                if self._proc.poll() is not None:
                    return self._proc.returncode or 0

                readable, _, _ = select.select([self._stdin_fd, self._master_fd], [], [], 0.05)
                for fd in readable:
                    if fd == self._master_fd:
                        self._pump_codex_output()
                    elif fd == self._stdin_fd:
                        self._handle_stdin_bytes()
        finally:
            self._restore_stdin()
            self._stop_recorder_if_running()
            self._stop_codex()

    def _ensure_prereqs(self) -> None:
        if shutil.which("parec") is None:
            raise RuntimeError("parec not found in PATH (install pulseaudio-utils).")
        if shutil.which("pactl") is None:
            raise RuntimeError("pactl not found in PATH.")
        if shutil.which("bash") is None:
            raise RuntimeError("bash not found in PATH.")

    def _start_codex(self) -> None:
        master_fd, slave_fd = pty.openpty()
        self._master_fd = master_fd
        self._proc = subprocess.Popen(
            ["bash", "-lc", self.codex_command],
            stdin=slave_fd,
            stdout=slave_fd,
            stderr=slave_fd,
            close_fds=True,
            text=False,
            env=os.environ.copy(),
        )
        os.close(slave_fd)

    def _stop_codex(self) -> None:
        if self._proc is not None and self._proc.poll() is None:
            try:
                self._proc.terminate()
                self._proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                self._proc.kill()
        self._proc = None
        if self._master_fd is not None:
            try:
                os.close(self._master_fd)
            except OSError:
                pass
        self._master_fd = None

    def _enable_raw_stdin(self) -> None:
        if self._old_term is None:
            self._old_term = termios.tcgetattr(self._stdin_fd)
            tty.setraw(self._stdin_fd)

    def _restore_stdin(self) -> None:
        if self._old_term is not None:
            termios.tcsetattr(self._stdin_fd, termios.TCSADRAIN, self._old_term)
            self._old_term = None

    def _pump_codex_output(self) -> None:
        if self._master_fd is None:
            return
        try:
            chunk = os.read(self._master_fd, 4096)
        except OSError:
            return
        if not chunk:
            return
        os.write(sys.stdout.fileno(), chunk)

    def _handle_stdin_bytes(self) -> None:
        data = os.read(self._stdin_fd, 1024)
        if not data or self._master_fd is None:
            return
        self._stdin_pending.extend(data)
        forward = bytearray()

        while self._stdin_pending:
            consumed = record_key_sequence_matches(bytes(self._stdin_pending), self.record_key)
            if consumed > 0:
                self._toggle_recording()
                del self._stdin_pending[:consumed]
                continue

            if record_key_sequence_is_partial(bytes(self._stdin_pending), self.record_key):
                break

            forward.append(self._stdin_pending[0])
            del self._stdin_pending[0]

        if forward:
            if self.record_key != "enter" and any(
                key in forward for key in (0x0D, 0x0A)
            ):
                self._transcript_draft = ""
            os.write(self._master_fd, bytes(forward))

    def _toggle_recording(self) -> None:
        if self._recorder.process is None:
            self._start_recording()
        else:
            wav_path = self._stop_recording()
            if not wav_path:
                self._print_status("recording stop failed.")
                return
            self._transcribe_and_maybe_send(wav_path)

    def _start_recording(self) -> None:
        source = self._resolve_record_source()
        fd, raw_path = tempfile.mkstemp(prefix="voice-codex-", suffix=".raw")
        os.close(fd)
        cmd = build_parec_record_command(
            source=source,
            sample_rate=self.sample_rate,
        )
        output_file = open(raw_path, "wb")
        proc = subprocess.Popen(cmd, stdout=output_file, stderr=subprocess.PIPE, text=False)
        output_file.close()
        self._recorder = RecorderState(process=proc, raw_path=raw_path)
        key_label = RECORD_KEY_LABELS.get(self.record_key, "Ctrl+R")
        self._print_status(f"recording started from source '{source}' ({key_label} to stop).")

    def _stop_recording(self) -> Optional[str]:
        process = self._recorder.process
        raw_path = self._recorder.raw_path
        self._recorder = RecorderState()
        if process is None or raw_path is None:
            return None
        try:
            process.send_signal(signal.SIGTERM)
            process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=1)

        stderr_text = ""
        if process.stderr is not None:
            try:
                stderr_text = process.stderr.read().decode("utf-8", errors="ignore").strip()
            except Exception:
                stderr_text = ""

        try:
            raw_size = os.path.getsize(raw_path)
        except OSError:
            return None
        if raw_size <= 0:
            try:
                os.remove(raw_path)
            except OSError:
                pass
            if stderr_text:
                self._print_status(f"recorder error: {stderr_text}")
            return None

        wav_path = raw_path[:-4] + ".wav"
        self._convert_raw_to_wav(raw_path=raw_path, wav_path=wav_path)
        try:
            os.remove(raw_path)
        except OSError:
            pass
        return wav_path

    def _stop_recorder_if_running(self) -> None:
        if self._recorder.process is not None:
            self._stop_recording()

    def _resolve_record_source(self) -> str:
        if self.record_source:
            return self.record_source
        try:
            result = subprocess.run(
                ["pactl", "list", "short", "sources"],
                capture_output=True,
                text=True,
                check=False,
            )
        except Exception:
            return "default"
        if result.returncode != 0:
            return "default"
        sources = []
        for line in result.stdout.splitlines():
            parts = line.strip().split("\t")
            if len(parts) < 2:
                continue
            sources.append(parts[1].strip())
        if not sources:
            return "default"

        def is_monitor(name: str) -> bool:
            return name.endswith(".monitor")

        preferred_non_monitor = [
            name for name in sources
            if not is_monitor(name)
            and not name.startswith("phone_av_bridge_mic_input_")
            and not name.startswith("phone_av_bridge_mic_sink_")
        ]
        bridge_monitor = [name for name in sources if name.startswith("phone_av_bridge_mic_sink_") and is_monitor(name)]
        bridge_input = [name for name in sources if name.startswith("phone_av_bridge_mic_input_")]
        candidates = preferred_non_monitor + bridge_monitor + bridge_input + sources
        ordered = []
        for name in candidates:
            if name not in ordered:
                ordered.append(name)

        for name in ordered:
            if self._source_supports_capture(name):
                return name
        return ordered[0] if ordered else "default"

    def _source_supports_capture(self, source_name: str) -> bool:
        fd, probe_path = tempfile.mkstemp(prefix="voice-codex-probe-", suffix=".raw")
        os.close(fd)
        try:
            with open(probe_path, "wb") as output_file:
                proc = subprocess.Popen(
                    build_parec_record_command(source=source_name, sample_rate=self.sample_rate),
                    stdout=output_file,
                    stderr=subprocess.DEVNULL,
                    text=False,
                )
            try:
                proc.wait(timeout=0.45)
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

    def _convert_raw_to_wav(self, raw_path: str, wav_path: str) -> None:
        with open(raw_path, "rb") as raw_file, wave.open(wav_path, "wb") as wav_file:
            wav_file.setnchannels(1)
            wav_file.setsampwidth(2)
            wav_file.setframerate(self.sample_rate)
            while True:
                chunk = raw_file.read(8192)
                if not chunk:
                    break
                wav_file.writeframes(chunk)

    def _transcribe_and_maybe_send(self, wav_path: str) -> None:
        try:
            self._print_status("transcribing...")
            text = self.stt_engine.transcribe_file(wav_path=wav_path, language=self.language)
        except Exception as error:
            self._print_status(f"transcribe failed: {error}")
            return
        finally:
            try:
                os.remove(wav_path)
            except OSError:
                pass

        if not text:
            self._print_status("no speech detected.")
            return
        appended = self._append_transcript_draft(text)
        self._print_status(f"transcript draft: {appended}")

        if self.auto_send and self._master_fd is not None:
            os.write(self._master_fd, (text + " ").encode("utf-8", errors="ignore"))
            self._print_status("appended to codex draft; press Enter to send.")

    def _append_transcript_draft(self, text: str) -> str:
        incoming = (text or "").strip()
        if not incoming:
            return self._transcript_draft
        if self._transcript_draft:
            self._transcript_draft = f"{self._transcript_draft} {incoming}"
        else:
            self._transcript_draft = incoming
        return self._transcript_draft

    def _print_status(self, message: str) -> None:
        sys.stdout.write(f"\r\n[voice-codex] {message}\r\n")
        sys.stdout.flush()


def parse_args():
    parser = argparse.ArgumentParser(
        description="Run Codex in PTY with voice hotkey support.",
        add_help=False,
    )
    parser.add_argument("--command", default=DEFAULT_CODEX_CMD, help="Command used to start Codex.")
    parser.add_argument("--stt-language", dest="language", default=DEFAULT_LANGUAGE, help="STT language code.")
    parser.add_argument("--stt-model", dest="model", default=DEFAULT_MODEL, help="STT model name (for faster-whisper).")
    parser.add_argument("--stt-device", dest="device", default=DEFAULT_DEVICE, help="STT device (cpu|auto|cuda).")
    parser.add_argument("--stt-compute-type", dest="compute_type", default=DEFAULT_COMPUTE_TYPE, help="STT compute type.")
    parser.add_argument("--record-source", default=DEFAULT_RECORD_SOURCE, help="Pulse audio source input.")
    parser.add_argument("--sample-rate", default=DEFAULT_SAMPLE_RATE, type=int, help="Recording sample rate.")
    parser.add_argument(
        "--no-auto-send",
        action="store_true",
        help="Do not auto-send transcript to Codex; print transcript only.",
    )
    parser.add_argument(
        "--record-key",
        choices=sorted(RECORD_KEY_CHOICES),
        default=normalize_record_key(DEFAULT_RECORD_KEY),
        help="Hotkey used to start/stop recording.",
    )
    args, unknown = parser.parse_known_args()
    args.codex_args = unknown
    return args


def is_help_request(args: list[str]) -> bool:
    return "-h" in args or "--help" in args


def main() -> int:
    args = parse_args()
    codex_command = compose_codex_command(args.command, args.codex_args)
    if is_help_request(args.codex_args):
        result = subprocess.run(["bash", "-lc", codex_command], check=False)
        return result.returncode
    bridge = VoiceCodexCliBridge(
        codex_command=codex_command,
        language=args.language,
        model=args.model,
        device=args.device,
        compute_type=args.compute_type,
        record_source=args.record_source,
        sample_rate=args.sample_rate,
        auto_send=not args.no_auto_send,
        record_key=args.record_key,
    )
    try:
        return bridge.run()
    except RuntimeError as error:
        sys.stderr.write(f"voice-codex error: {error}\n")
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
