# Requirements - Voice Codex macOS Intel Support

## Status
Design-ready

## Goal / Problem Statement
Make `voice-codex-bridge` install and run with microphone-to-text on Intel macOS (current machine) while keeping Linux/WSL behavior intact.

## In-Scope Use Cases
- UC-001: Install voice bridge dependencies successfully on Intel macOS.
- UC-002: Start `voice-codex` on Intel macOS and pass prerequisite checks for recording.
- UC-003: Record speech audio and transcribe it on Intel macOS.
- UC-004: Preserve Linux/WSL recording behavior.

## Acceptance Criteria
- Install path no longer fails due to unsupported default Python interpreter.
- Runtime recording path supports macOS without requiring PulseAudio commands.
- Linux/WSL path continues to use PulseAudio recorder path and remains functional.
- Unit tests cover backend-specific command construction and backend selection logic.
- User can run a documented setup path on Intel macOS to enable speaking.
- `voice-codex` can be launched successfully on this machine and report ready state when dependencies are present.

## Constraints / Dependencies
- STT dependency chain from `faster-whisper` must be installable in selected Python version.
- macOS recording backend requires a concrete capture tool available on macOS (expected: `ffmpeg` avfoundation).
- Existing Linux/WSL users should not need to change their current recorder setup workflow.
- Keep command-forwarding and PTY behavior unchanged except where recorder backend wiring requires.

## Assumptions
- User accepts installation of additional local dependencies (Python version and recording tooling).
- User runs Codex from terminal and can grant microphone permissions.

## Open Questions / Risks
- Device source selection UX on macOS may differ from Pulse source naming.
- ffmpeg installation may be required on machines without it.
- Some macOS environments may require manual source index selection for non-default microphones.

## Scope Triage
Medium

## Triage Rationale
Scope crosses installation/runtime concerns and requires separation-of-concerns refactor:
- installer + launcher Python interpreter selection updates,
- recorder backend abstraction and macOS backend implementation,
- tests + documentation updates,
- local verification on Intel macOS while preserving Linux/WSL behavior.
