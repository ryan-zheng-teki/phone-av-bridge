import importlib.util
import shutil
import time
import unittest
from pathlib import Path

from fastapi.testclient import TestClient


def load_bridge_module():
    module_path = Path(__file__).resolve().parents[1] / "main.py"
    spec = importlib.util.spec_from_file_location("voice_codex_bridge_main", module_path)
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(module)
    return module


class VoiceCodexBridgeIntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.bridge = load_bridge_module()
        cls.client = TestClient(cls.bridge.app)

    def tearDown(self):
        try:
            self.client.post("/api/codex/stop")
        except Exception:
            pass

    def test_health_and_model_selection(self):
        health = self.client.get("/health")
        self.assertEqual(health.status_code, 200)
        payload = health.json()
        self.assertTrue(payload["ok"])
        self.assertIn("model", payload)

        bad_model = self.client.post("/api/model/select", json={"model": "not-a-model"})
        self.assertEqual(bad_model.status_code, 400)

        good_model = self.client.post("/api/model/select", json={"model": "tiny.en"})
        self.assertEqual(good_model.status_code, 200)
        self.assertEqual(good_model.json()["model"], "tiny.en")

    def test_codex_pty_send_and_output_tail(self):
        start = self.client.post("/api/codex/start", json={"command": "cat"})
        self.assertEqual(start.status_code, 200)
        self.assertTrue(start.json()["running"])

        send = self.client.post("/api/codex/send", json={"text": "integration-echo"})
        self.assertEqual(send.status_code, 200)

        deadline = time.time() + 2.0
        output_text = ""
        while time.time() < deadline:
            out = self.client.get("/api/codex/output?max_chars=4000")
            self.assertEqual(out.status_code, 200)
            output_text = out.json().get("output", "")
            if "integration-echo" in output_text:
                break
            time.sleep(0.1)

        self.assertIn("integration-echo", output_text)

    def test_real_codex_binary_smoke_when_available(self):
        if shutil.which("codex") is None:
            self.skipTest("codex binary not available in PATH")

        start = self.client.post("/api/codex/start", json={"command": "codex"})
        self.assertEqual(start.status_code, 200)
        self.assertTrue(start.json()["running"])

        send = self.client.post("/api/codex/send", json={"text": "/help"})
        self.assertEqual(send.status_code, 200)

        time.sleep(0.8)
        out = self.client.get("/api/codex/output?max_chars=6000")
        self.assertEqual(out.status_code, 200)
        payload = out.json()
        self.assertTrue(payload["running"])
        # At minimum we verify PTY accepted the write and session stays alive.
        self.assertIn("[voice->codex] /help", payload.get("output", ""))

    def test_transcribe_endpoint_with_mocked_stt_engine(self):
        original_transcribe = self.bridge.stt_engine.transcribe_file
        self.bridge.stt_engine.transcribe_file = lambda *_args, **_kwargs: "mock transcript"
        try:
            response = self.client.post(
                "/api/transcribe",
                data={"language": "en"},
                files={"file": ("clip.webm", b"fake-audio-bytes", "audio/webm")},
            )
            self.assertEqual(response.status_code, 200)
            payload = response.json()
            self.assertTrue(payload["ok"])
            self.assertEqual(payload["text"], "mock transcript")
        finally:
            self.bridge.stt_engine.transcribe_file = original_transcribe


if __name__ == "__main__":
    unittest.main()
