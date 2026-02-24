# Voice Codex Bridge

## Purpose
`voice-codex-bridge` captures microphone audio, transcribes it locally, and appends transcript text into a Codex PTY session.

## Runtime Architecture
- `voice-codex-bridge/cli.py`: PTY lifecycle, key handling, transcript flow, STT integration.
- `voice-codex-bridge/audio_capture.py`: platform-specific recorder backend selection and source handling.

### Recorder Backends
- Linux/WSL backend: PulseAudio (`parec` + `pactl`).
- macOS backend: avfoundation via `ffmpeg`.

Backend selection is automatic by host OS and isolated from PTY/STT logic.

## Installation Notes
- Wrapper scripts select a supported Python interpreter (`3.9` to `3.13`, prefers `3.11`).
- Override Python selection with `VOICE_CODEX_PYTHON`.

Recording prerequisites:
- Linux/WSL: install `pulseaudio-utils`.
- macOS: install `ffmpeg` (`brew install ffmpeg`).

## Source Selection
- `--record-source` / `VOICE_CODEX_RECORD_SOURCE`:
  - Linux/WSL: Pulse source name.
  - macOS: avfoundation audio index.
- macOS default source fallback can be set with `VOICE_CODEX_MACOS_AUDIO_INDEX`.
