# Implementation Plan

## Status
Finalized

## Solution Sketch (Small Scope Design Basis)
1. In `LinuxAudioRunner`, stop creating `module-remap-source` for Linux mic exposure.
2. Treat `\`<micSinkName>.monitor\`` as canonical app-selectable microphone source.
3. Keep sink description user-friendly so apps show a recognizable label (`Monitor of <PhoneAVBridgeMic-...>`).
4. Keep stale module cleanup limited to null-sink modules; remove remap-specific module lifecycle.
5. Preserve ffmpeg routing guard (`move-sink-input` by PID) and macOS isolation.

## Files To Change
- `desktop-av-bridge-host/adapters/linux-audio/audio-runner.mjs`
- `desktop-av-bridge-host/tests/unit/linux-audio-runner.test.mjs`
- `desktop-av-bridge-host/README.md`

## Verification Plan
- Unit tests: `cd desktop-av-bridge-host && npm test`
- Runtime local checks:
  - `pactl list short sources` confirms monitor source exists.
  - `parec -d <monitor-source>` returns non-zero bytes.
  - Route hints include monitor target for microphone.
