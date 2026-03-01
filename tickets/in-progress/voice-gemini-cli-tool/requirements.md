# Requirements - Voice Gemini CLI Tool

- **Status:** Design-ready
- **Goal:** Create a `voice-gemini` CLI tool similar to `voice-codex`, allowing users to enable voice mode with a keyboard combination while interacting with the `gemini` command.

## Goal / Problem Statement
Users want a voice-enabled interface for `gemini` CLI that can be toggled using a global hotkey, similar to `voice-codex`.

## In-Scope Use Cases
1.  **UC-001: Hotkey Toggle:** User presses `Ctrl+G` (default) or a configured key to start/stop voice recording.
2.  **UC-002: Voice to Text:** Capture user audio using local microphone and transcribe it using `faster-whisper`.
3.  **UC-003: Gemini Input Injection:** Transcribed text is injected into the stdin of the `gemini` command running in a PTY.
4.  **UC-004: Interactive PTY:** Maintain full interactive capabilities of the `gemini` CLI (colors, progress bars, interactive prompts).

## Acceptance Criteria
- **AC-001:** `voice-gemini` starts the `gemini` command in a pseudo-terminal.
- **AC-002:** `Ctrl+G` (default) toggles voice recording without forwarding the key to `gemini`.
- **AC-003:** Status messages (e.g., "recording started", "transcribing...") are displayed in a non-intrusive overlay or status line.
- **AC-004:** Transcribed text is successfully appended to the current `gemini` input line.
- **AC-005:** Hotkey is configurable via environment variables (`VOICE_GEMINI_RECORD_KEY`) and command-line flags (`--record-key`).
- **AC-006:** All non-hotkey input from the keyboard is forwarded to `gemini` unchanged.
- **AC-007:** An `install.sh` script is provided to automate dependency checks and initial configuration.
- **AC-008:** `voice-gemini` synchronizes the terminal window size with the child PTY, ensuring the UI takes the full width.

## Constraints / Dependencies
- **OS:** Linux (current) and macOS support.
- **Audio Capture:** `pactl`/`parec` (Linux), `ffmpeg` (macOS).
- **Python:** Requires Python 3.9+ for `faster-whisper`.
- **Gemini CLI:** Must wrap the existing `gemini` binary found in the system PATH.

## Assumptions
- The `gemini` command is available and executable.
- Python and required audio utilities are installed or installable via a setup script.

## Open Questions / Risks
- Does `gemini` use `Ctrl+G` for anything? (Unlikely, but worth checking).
- Will the PTY approach affect the agent's ability to render complex UI elements if it uses them?

## Requirement Coverage Map
| Req ID | Use Case ID | AC ID |
| :--- | :--- | :--- |
| Goal | UC-001, UC-003 | AC-001 |
| Hotkey | UC-001 | AC-002, AC-005, AC-006 |
| Recording | UC-002 | AC-003 |
| Injection | UC-003 | AC-004 |
| Setup | N/A | AC-007 |
| UI | UC-004 | AC-008 |
