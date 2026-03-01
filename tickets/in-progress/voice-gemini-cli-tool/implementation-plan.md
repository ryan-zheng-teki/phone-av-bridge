# Implementation Plan - Voice Gemini CLI Tool

- **Status:** Draft
- **Scope:** Small

## Solution Sketch
The `voice-gemini` tool will be a Python-based PTY bridge that wraps the `gemini` command. It will use `faster-whisper` for local speech-to-text and `pty` for terminal management.

### Architecture
- **Wrapper Script:** `voice-gemini` (shell script) will manage the virtual environment and launch the Python bridge.
- **Python Bridge:** `cli.py` will handle PTY creation, keyboard interception, and transcription coordination.
- **Audio Capture:** `audio_capture.py` will provide OS-specific recording commands (PulseAudio for Linux, AVFoundation for macOS).
- **Default Hotkey:** `Ctrl+G` (0x07) to avoid conflicts with `Ctrl+X`.

### Refactoring Tasks (from voice-codex-bridge)
- Rename `VOICE_CODEX_*` environment variables to `VOICE_GEMINI_*`.
- Rename `CODEX_CMD` to `GEMINI_CMD` (default `gemini`).
- Update status message prefix from `[voice-codex]` to `[voice-gemini]`.
- Update temporary file prefixes.
- Update `README.md` and `install.sh` for `voice-gemini`.

## Implementation Tasks
### Task 1: Foundation
- [ ] Create `voice-gemini-bridge/` directory.
- [ ] Copy and refactor `audio_capture.py`.
- [ ] Copy and refactor `cli.py`.
- [ ] Create `requirements.txt` with `faster-whisper`.

### Task 2: Bootstrapping & Docs
- [ ] Create `voice-gemini` wrapper script.
- [ ] Create `install.sh` setup script.
- [ ] Create `README.md` with usage instructions.

### Task 3: Verification
- [ ] Run `voice-gemini` and verify it launches `gemini`.
- [ ] Verify `Ctrl+G` toggles recording.
- [ ] Verify transcription is injected correctly.

## Verification Strategy
### Unit/Integration Tests
- Test hotkey detection logic in `cli.py`.
- Test audio backend selection and command building in `audio_capture.py`.

### E2E Scenarios
- Launch `voice-gemini`, speak a prompt, and verify the prompt appears in the `gemini` CLI input.
