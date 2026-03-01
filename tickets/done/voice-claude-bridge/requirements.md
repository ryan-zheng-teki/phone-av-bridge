# Requirements - Voice Claude Bridge

- Status: `Design-ready`
- Goal: Implement a voice bridge for Claude, similar to `voice-codex-bridge` and `voice-gemini-bridge`.
- Scope: A CLI tool that captures audio, transcribes it using `faster-whisper`, and sends the transcript to a Claude-compatible CLI or API.

## In-Scope Use Cases
- `UC-001`: Record audio from system/microphone.
- `UC-002`: Transcribe recorded audio to text.
- `UC-003`: Send transcribed text to a Claude CLI/process.
- `UC-004`: Hotkey support (toggle recording).

## Acceptance Criteria
- `AC-001`: User can start/stop recording with a configurable hotkey.
- `AC-002`: Default hotkey is `Ctrl-K` (0x0B).
- `AC-003`: Transcription uses `faster-whisper`.
- `AC-004`: Transcribed text is appended/sent to the Claude process.
- `AC-005`: Support for Linux (PulseAudio) and macOS (AVFoundation).
- `AC-006`: Terminal window size is synchronized with the wrapped process.

## Constraints
- Python 3.9 - 3.13 support.
- Dependency on `faster-whisper` and `requests`.

## Assumptions
- There is a `claude` CLI or equivalent that can be run in a PTY.

## Requirement Coverage Map
| Requirement ID | Use Case ID |
| --- | --- |
| AC-001 | UC-004 |
| AC-002 | UC-004 |
| AC-003 | UC-002 |
| AC-004 | UC-003 |
| AC-005 | UC-001 |
| AC-006 | UC-003 |

## Acceptance Criteria Coverage Map (Stage 7)
| Acceptance Criteria ID | Scenario ID |
| --- | --- |
| AC-001 | SC-001 |
| AC-002 | SC-001 |
| AC-003 | SC-002 |
| AC-004 | SC-003 |
| AC-005 | SC-004 |
| AC-006 | SC-005 |
