#!/usr/bin/env python3
import os
import pty
import shlex
import subprocess
import tempfile
import threading
from collections import deque
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

APP_DIR = Path(__file__).resolve().parent
STATIC_DIR = APP_DIR / "static"

DEFAULT_MODEL = os.environ.get("STT_MODEL", "tiny.en")
DEFAULT_LANGUAGE = os.environ.get("STT_LANGUAGE", "en")
DEFAULT_DEVICE = os.environ.get("STT_DEVICE", "cpu")
DEFAULT_COMPUTE_TYPE = os.environ.get("STT_COMPUTE_TYPE", "int8")
DEFAULT_CODEX_CMD = os.environ.get("CODEX_CMD", "codex")

MODEL_CHOICES = [
    "tiny.en",
    "base.en",
    "small.en",
    "tiny",
    "base",
    "small",
]


class CodexStartRequest(BaseModel):
    command: str = DEFAULT_CODEX_CMD
    cwd: Optional[str] = None


class CodexSendRequest(BaseModel):
    text: str


class ModelSelectRequest(BaseModel):
    model: str


class CodexPtySession:
    def __init__(self):
        self._lock = threading.Lock()
        self._proc: Optional[subprocess.Popen] = None
        self._master_fd: Optional[int] = None
        self._reader_thread: Optional[threading.Thread] = None
        self._output = deque(maxlen=4000)

    def is_running(self) -> bool:
        with self._lock:
            return self._proc is not None and self._proc.poll() is None

    def start(self, command: str, cwd: Optional[str] = None) -> None:
        with self._lock:
            if self._proc is not None and self._proc.poll() is None:
                return

            master_fd, slave_fd = pty.openpty()
            workdir = cwd or str(Path.home())
            cmd = ["bash", "-lc", command]
            proc = subprocess.Popen(
                cmd,
                stdin=slave_fd,
                stdout=slave_fd,
                stderr=slave_fd,
                cwd=workdir,
                close_fds=True,
                env=os.environ.copy(),
                text=False,
            )
            os.close(slave_fd)

            self._proc = proc
            self._master_fd = master_fd
            self._output.clear()
            self._output.append(f"[codex] started: {command} (pid={proc.pid})\n")

            self._reader_thread = threading.Thread(target=self._reader_loop, daemon=True)
            self._reader_thread.start()

    def stop(self) -> None:
        with self._lock:
            proc = self._proc
            master_fd = self._master_fd
            self._proc = None
            self._master_fd = None

        if proc is not None and proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                proc.kill()
        if master_fd is not None:
            try:
                os.close(master_fd)
            except OSError:
                pass

        with self._lock:
            self._output.append("[codex] stopped\n")

    def send_line(self, text: str) -> None:
        payload = (text.rstrip("\n") + "\n").encode("utf-8", errors="ignore")
        with self._lock:
            if self._master_fd is None or self._proc is None or self._proc.poll() is not None:
                raise RuntimeError("Codex PTY is not running")
            os.write(self._master_fd, payload)
            self._output.append(f"[voice->codex] {text.rstrip()}\n")

    def tail_text(self, max_chars: int = 12000) -> str:
        with self._lock:
            joined = "".join(self._output)
        if len(joined) <= max_chars:
            return joined
        return joined[-max_chars:]

    def _reader_loop(self) -> None:
        while True:
            with self._lock:
                proc = self._proc
                master_fd = self._master_fd
            if proc is None or master_fd is None:
                return
            if proc.poll() is not None:
                with self._lock:
                    self._output.append(f"[codex] exited code={proc.returncode}\n")
                return
            try:
                data = os.read(master_fd, 4096)
            except OSError:
                return
            if not data:
                continue
            text = data.decode("utf-8", errors="ignore")
            with self._lock:
                self._output.append(text)


class SttEngine:
    def __init__(self):
        self._lock = threading.Lock()
        self._model_name = DEFAULT_MODEL
        self._model = None

    @property
    def model_name(self) -> str:
        with self._lock:
            return self._model_name

    def set_model(self, model_name: str) -> None:
        with self._lock:
            self._model_name = model_name
            self._model = None

    def _ensure_model(self):
        with self._lock:
            if self._model is not None:
                return self._model
            try:
                from faster_whisper import WhisperModel
            except ImportError as error:
                raise RuntimeError(
                    "faster-whisper is not installed. Run: pip install -r requirements.txt"
                ) from error

            device = os.environ.get("STT_DEVICE", DEFAULT_DEVICE)
            compute_type = os.environ.get("STT_COMPUTE_TYPE", DEFAULT_COMPUTE_TYPE)

            try:
                self._model = WhisperModel(
                    self._model_name,
                    device=device,
                    compute_type=compute_type,
                )
            except Exception as error:
                # Some hosts report GPU-capable runtimes but miss CUDA libs at runtime.
                # Fall back to CPU automatically for resilience.
                if str(device).lower() == "auto" and "libcublas" in str(error).lower():
                    self._model = WhisperModel(
                        self._model_name,
                        device="cpu",
                        compute_type="int8",
                    )
                else:
                    raise
            return self._model

    def transcribe_file(self, file_path: str, language: str = DEFAULT_LANGUAGE) -> str:
        model = self._ensure_model()
        segments, _info = model.transcribe(
            file_path,
            language=language,
            vad_filter=True,
            beam_size=1,
            condition_on_previous_text=False,
        )
        parts = [segment.text.strip() for segment in segments if segment.text and segment.text.strip()]
        return " ".join(parts).strip()


app = FastAPI(title="Voice to Codex PTY Bridge", version="0.1.0")
app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")

codex_session = CodexPtySession()
stt_engine = SttEngine()


@app.get("/")
def index():
    return FileResponse(STATIC_DIR / "index.html")


@app.get("/health")
def health():
    return {
        "ok": True,
        "codex_running": codex_session.is_running(),
        "model": stt_engine.model_name,
    }


@app.get("/api/models")
def list_models():
    return {
        "current": stt_engine.model_name,
        "choices": MODEL_CHOICES,
    }


@app.post("/api/model/select")
def select_model(request: ModelSelectRequest):
    model_name = request.model.strip()
    if model_name not in MODEL_CHOICES:
        raise HTTPException(status_code=400, detail=f"Unsupported model: {model_name}")
    stt_engine.set_model(model_name)
    return {"ok": True, "model": model_name}


@app.post("/api/codex/start")
def start_codex(request: CodexStartRequest):
    command = request.command.strip()
    if not command:
        raise HTTPException(status_code=400, detail="Command is required")
    cwd = request.cwd.strip() if request.cwd else None
    codex_session.start(command=command, cwd=cwd)
    return {"ok": True, "running": codex_session.is_running()}


@app.post("/api/codex/stop")
def stop_codex():
    codex_session.stop()
    return {"ok": True, "running": codex_session.is_running()}


@app.post("/api/codex/send")
def codex_send(request: CodexSendRequest):
    text = request.text.strip()
    if not text:
        raise HTTPException(status_code=400, detail="Text is required")
    try:
        codex_session.send_line(text)
    except RuntimeError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    return {"ok": True}


@app.get("/api/codex/output")
def codex_output(max_chars: int = 12000):
    return {
        "running": codex_session.is_running(),
        "output": codex_session.tail_text(max_chars=max(2000, min(max_chars, 60000))),
    }


@app.post("/api/transcribe")
async def transcribe(
    file: UploadFile = File(...),
    language: str = Form(DEFAULT_LANGUAGE),
):
    suffix = Path(file.filename or "clip.webm").suffix or ".webm"
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        tmp_path = tmp.name
        content = await file.read()
        tmp.write(content)

    try:
        transcript = stt_engine.transcribe_file(tmp_path, language=language.strip() or DEFAULT_LANGUAGE)
    except Exception as error:
        raise HTTPException(status_code=500, detail=f"Transcription failed: {error}") from error
    finally:
        try:
            os.remove(tmp_path)
        except OSError:
            pass

    return {
        "ok": True,
        "text": transcript,
        "model": stt_engine.model_name,
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="127.0.0.1", port=8799)
