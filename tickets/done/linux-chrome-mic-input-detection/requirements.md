# Requirements

## Status
Design-ready

## Goal / Problem Statement
Chrome (and sometimes other apps) can select the Linux virtual mic device but receives silence because the current remap-source path does not deliver frames reliably.

## Triage
Small

## Triage Rationale
- Single primary module (`desktop-av-bridge-host/adapters/linux-audio/audio-runner.mjs`) plus tests/docs.
- No API/schema changes.
- Behavior change is bounded to Linux mic source publication.

## In-Scope Use Cases
- UC-1: Linux host publishes a microphone source that meeting/browser apps can select and immediately receive phone mic audio.
- UC-2: Linux host reports clear route hints/device naming for the selected mic source.
- UC-3: Existing stop/start cleanup still unloads stale modules cleanly.

## Acceptance Criteria
- AC-1: Mic source selected by Chrome/Zoom yields non-empty PCM capture in local diagnostics.
- AC-2: Linux route hints point to monitor-based source and remain user-recognizable.
- AC-3: Unit tests pass with updated Linux mic source behavior.
- AC-4: macOS codepaths are unchanged.

## Constraints / Dependencies
- PulseAudio/PipeWire via `pactl` remains runtime dependency.
- ffmpeg RTSP audio ingest remains unchanged.

## Assumptions
- Null sink monitor sources are visible/selectable in target conferencing/browser clients.

## Open Questions / Risks
- Some clients may display monitor naming differently; docs should clarify expected mic label.
