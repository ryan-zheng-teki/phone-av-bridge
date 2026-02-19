import importlib.util
import unittest
from pathlib import Path


def load_cli_module():
    module_path = Path(__file__).resolve().parents[1] / "cli.py"
    spec = importlib.util.spec_from_file_location("voice_codex_bridge_cli", module_path)
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(module)
    return module


class VoiceCodexCliHelperTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.cli = load_cli_module()

    def test_build_parec_record_command_uses_expected_flags(self):
        cmd = self.cli.build_parec_record_command(
            source="default",
            sample_rate=16000,
        )
        self.assertEqual(
            cmd,
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

    def test_record_hotkey_is_ctrl_r(self):
        self.assertEqual(self.cli.CTRL_R_HOTKEY_BYTE, 0x12)
        self.assertTrue(self.cli.record_key_matches(0x12, "ctrl-r"))
        self.assertFalse(self.cli.record_key_matches(0x0D, "ctrl-r"))
        self.assertEqual(self.cli.CTRL_X_HOTKEY_BYTE, 0x18)
        self.assertTrue(self.cli.record_key_matches(0x18, "ctrl-x"))
        self.assertFalse(self.cli.record_key_matches(0x12, "ctrl-x"))
        self.assertEqual(self.cli.record_key_sequence_matches(b"\x18", "ctrl-x"), 1)

    def test_enter_hotkey_mode(self):
        self.assertEqual(self.cli.normalize_record_key("enter"), "enter")
        self.assertTrue(self.cli.record_key_matches(0x0D, "enter"))
        self.assertTrue(self.cli.record_key_matches(0x0A, "enter"))
        self.assertFalse(self.cli.record_key_matches(0x12, "enter"))
        self.assertEqual(self.cli.record_key_sequence_matches(b"\r", "enter"), 1)
        self.assertEqual(self.cli.record_key_sequence_matches(b"\n", "enter"), 1)

    def test_compose_codex_command_with_forwarded_args(self):
        command = self.cli.compose_codex_command("codex", ["--", "--model", "gpt-5", "--approval", "never"])
        self.assertEqual(command, "codex --model gpt-5 --approval never")

    def test_function_key_hotkey_sequences(self):
        self.assertEqual(self.cli.normalize_record_key("f8"), "f8")
        self.assertEqual(self.cli.record_key_sequence_matches(b"\x1b[19~", "f8"), 5)
        self.assertEqual(self.cli.record_key_sequence_matches(b"\x1b[20~", "f9"), 5)
        self.assertTrue(self.cli.record_key_sequence_is_partial(b"\x1b[1", "f8"))
        self.assertFalse(self.cli.record_key_sequence_is_partial(b"\x1b[A", "f8"))

    def test_transcript_draft_accumulates(self):
        bridge = self.cli.VoiceCodexCliBridge(
            codex_command="cat",
            language="en",
            model="tiny.en",
            device="cpu",
            compute_type="int8",
            record_source="",
            sample_rate=16000,
            auto_send=False,
            record_key="ctrl-x",
        )
        self.assertEqual(bridge._append_transcript_draft("hello"), "hello")
        self.assertEqual(bridge._append_transcript_draft("world"), "hello world")
        self.assertEqual(bridge._append_transcript_draft(""), "hello world")
        self.assertEqual(bridge._append_transcript_draft(" again"), "hello world again")


if __name__ == "__main__":
    unittest.main()
