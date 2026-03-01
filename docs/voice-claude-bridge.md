# Voice Claude Bridge

## Purpose
`voice-claude-bridge` captures microphone audio, transcribes it locally, and appends transcript text into a Claude PTY session.

## Runtime Architecture
- `voice-claude-bridge/cli.py`: PTY lifecycle, hotkey handling (default `Ctrl+K`), transcript flow, STT integration.
- `voice-claude-bridge/audio_capture.py`: platform-specific recorder backend selection and source handling.

### Recorder Backends
- Linux/WSL backend: PulseAudio (`parec` + `pactl`).
- macOS backend: AVFoundation via `ffmpeg`.

Backend selection is automatic by host OS and isolated from PTY/STT logic.

## Installation Notes
- Wrapper scripts select a supported Python interpreter (`3.9` to `3.13`, prefers `3.11`).
- Override Python selection with `VOICE_CLAUDE_PYTHON`.

Recording prerequisites:
- Linux/WSL: install `pulseaudio-utils`.
- macOS: install `ffmpeg` (`brew install ffmpeg`).

## Source Selection
- `--record-source` / `VOICE_CLAUDE_RECORD_SOURCE`:
  - Linux/WSL: Pulse source name.
  - macOS: AVFoundation audio index.
- macOS default source fallback can be set with `VOICE_CLAUDE_MACOS_AUDIO_INDEX`.
