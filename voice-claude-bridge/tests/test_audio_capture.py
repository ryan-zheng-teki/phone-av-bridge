import unittest
from unittest.mock import patch
import sys
from pathlib import Path

# Add parent directory to sys.path so it can find audio_capture
module_dir = Path(__file__).resolve().parents[1]
if str(module_dir) not in sys.path:
    sys.path.insert(0, str(module_dir))

import audio_capture


class AudioCaptureBackendTests(unittest.TestCase):
    def test_select_audio_backend(self):
        self.assertIsInstance(audio_capture.select_audio_backend("linux"), audio_capture.PulseAudioBackend)
        self.assertIsInstance(audio_capture.select_audio_backend("darwin"), audio_capture.MacOSAvFoundationBackend)
        with self.assertRaises(RuntimeError):
            audio_capture.select_audio_backend("windows")

    def test_pulse_build_record_command(self):
        backend = audio_capture.PulseAudioBackend()
        self.assertEqual(
            backend.build_record_command(source="default", sample_rate=16000),
            [
                "parec",
                "--device",
                "default",
                "--format",
                "s16le",
                "--channels",
                "1",
                "--rate",
                "16000",
            ],
        )

    @patch("audio_capture.subprocess.run")
    def test_pulse_candidate_sources_prefers_non_monitor(self, mock_run):
        mock_run.return_value.returncode = 0
        mock_run.return_value.stdout = (
            "10\talsa_output.pci.monitor\t...\n"
            "11\talsa_input.pci\t...\n"
            "12\tphone_av_bridge_mic_input_x\t...\n"
            "13\tphone_av_bridge_mic_sink_x.monitor\t...\n"
        )
        backend = audio_capture.PulseAudioBackend()
        ordered = backend.candidate_sources()
        self.assertEqual(ordered[0], "alsa_input.pci")
        self.assertIn("default", ordered)

    @patch("audio_capture.subprocess.run")
    def test_macos_candidate_sources_parses_audio_indexes(self, mock_run):
        mock_run.return_value.stdout = ""
        mock_run.return_value.stderr = "\n".join(
            [
                "[AVFoundation indev @ 0x0] AVFoundation video devices:",
                "[AVFoundation indev @ 0x0] [0] FaceTime HD Camera",
                "[AVFoundation indev @ 0x0] AVFoundation audio devices:",
                "[AVFoundation indev @ 0x0] [0] MacBook Pro Microphone",
                "[AVFoundation indev @ 0x0] [1] External Mic",
            ]
        )
        backend = audio_capture.MacOSAvFoundationBackend()
        self.assertEqual(backend.candidate_sources()[:2], ["0", "1"])

    def test_macos_build_record_command(self):
        backend = audio_capture.MacOSAvFoundationBackend()
        self.assertEqual(
            backend.build_record_command(source=":2", sample_rate=16000),
            [
                "ffmpeg",
                "-hide_banner",
                "-loglevel",
                "error",
                "-nostdin",
                "-f",
                "avfoundation",
                "-i",
                ":2",
                "-ac",
                "1",
                "-ar",
                "16000",
                "-f",
                "s16le",
                "-acodec",
                "pcm_s16le",
                "-",
            ],
        )


if __name__ == "__main__":
    unittest.main()
