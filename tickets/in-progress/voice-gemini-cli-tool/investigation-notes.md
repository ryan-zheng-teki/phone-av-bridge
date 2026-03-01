# Investigation Notes - Voice Gemini CLI Tool

## Overview
The goal is to create a `voice-gemini` CLI tool that provides voice input capabilities for the `gemini` command, similar to how `voice-codex-bridge` works for `codex`.

## Architecture of voice-codex-bridge
- **Language:** Python 3.
- **PTY Management:** Uses `pty.openpty()` to create a pseudo-terminal.
- **Input Handling:** Sets stdin to raw mode (`tty.setraw`) and uses `select.select` to multiplex input/output.
- **Hotkey Interception:** Intercepts `Ctrl+X` (0x18) or other configured keys from stdin.
- **Audio Capture:**
    - Linux: `pactl` + `parec`.
    - macOS: `ffmpeg`.
- **Transcription:** `faster-whisper`.
- **Text Injection:** Writes transcribed text directly to the PTY's master file descriptor.

## Gemini CLI Context
- **Command:** `gemini` (located at `/home/ryan-ai/.nvm/versions/node/v22.20.0/bin/gemini`).
- **Interactive Mode:** Default behavior.
- **Hotkey Conflict:** Need to verify if `gemini` uses `Ctrl+X`.
    - `gemini` uses `inquirer` or similar for some prompts, and might use `readline` for others.
    - Standard `readline` uses `Ctrl+X` as a prefix for some commands (e.g., `Ctrl+X Ctrl+E` to edit in editor).
    - If `Ctrl+X` is taken, `Ctrl+G` (for Gemini?) or `Ctrl+B` (Bridge?) or `F8/F9` could be alternatives.

## Implementation Plan (Initial)
1.  **Clone Structure:** Use `voice-codex-bridge` as a template.
2.  **Adapt for Gemini:** Change default command to `gemini`.
3.  **Refactor/Rename:** Ensure naming reflects `voice-gemini`.
4.  **Integration:** Verify it works with the existing `gemini` CLI.

## Findings
- `voice-codex-bridge` is already quite generic but has "codex" hardcoded in many places (variable names, status messages, default commands).
- It relies on `faster-whisper` which requires a Python environment.
- It uses `pactl`/`parec` on Linux, which is appropriate for the current environment.

## Triage
- **Scope:** Small. The task involves adapting an existing, proven PTY bridge architecture (`voice-codex-bridge`) to wrap the `gemini` CLI.
- **Complexity:** Low. The primary work is renaming, refactoring hardcoded strings, and ensuring compatibility with `gemini` CLI's input/output behavior.
- **Estimated Effort:** ~2-4 hours.

## Comparative Analysis: voice-codex vs voice-gemini
### Wrapper Script (voice-codex vs voice-gemini)
- `voice-codex` uses `set -euo pipefail`.
- `voice-codex` uses `readlink -f` for robust path resolution.
- `voice-codex` has better Python version checking via an inline Python script.
- `voice-codex` checks for both `faster_whisper` and `requests` modules. (Wait, I didn't include `requests` in my `requirements.txt`).
- `voice-codex` handles `.env` loading and STT model fallback logic in the shell script *before* calling `cli.py`.

### Dependencies
- `voice-codex` requirements include `faster-whisper` and `requests`. I should verify if `requests` is actually used in `cli.py`.

## Bug Investigation: Gemini UI becomes narrow in PTY
- **Symptom:** The `gemini` UI renders in a narrow width when running via `voice-gemini`.
- **Root Cause:** The PTY created by `pty.openpty()` defaults to 80x24 dimensions. If the host terminal size is not synchronized to the PTY, interactive tools like `gemini` (likely using `inquirer` or `readline`) will assume the default narrow width.
- **Fix:** Implement window size synchronization:
    1.  Get initial terminal size using `fcntl.ioctl(sys.stdin, termios.TIOCGWINSZ, ...)`.
    2.  Set PTY master size using `fcntl.ioctl(master_fd, termios.TIOCSWINSZ, ...)`.
    3.  Register a `SIGWINCH` signal handler to forward terminal resize events from the host to the PTY.
- **Verification:** User reported `voice-codex` works fine, but upon inspection, `voice-codex` ALSO appears to lack this logic. It's possible `gemini` is more sensitive to terminal size than `codex`, or the user's environment for `voice-codex` was different. Regardless, implementing this is the standard "correct" way to build a PTY bridge.
