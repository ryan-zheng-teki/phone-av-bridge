# Investigation Notes

## Sources Consulted
- `desktop-av-bridge-host/adapters/linux-audio/audio-runner.mjs`
- `desktop-av-bridge-host/tests/unit/linux-audio-runner.test.mjs`
- `desktop-av-bridge-host/README.md`
- `README.md`

## Key Findings
- Linux microphone route creates a per-phone null sink and writes RTSP audio into that sink.
- Linux speaker route resolves capture source from default sink monitor first.
- If default sink resolves to the bridge microphone sink (or if only bridge mic sources are present), speaker capture can include microphone path audio.
- There is currently no explicit exclusion logic to prevent selecting bridge-owned microphone sources for speaker capture.

## Constraints
- Must preserve manual override behavior via `LINUX_SPEAKER_CAPTURE_SOURCE`.
- Must not break existing microphone virtual device naming and route behavior.
- Must keep Linux-only behavior changes; macOS path should remain untouched.

## Unknowns
- Some user environments may not expose standard `.monitor` naming consistently.
- Host apps can still add their own mic-monitoring paths outside this bridge.

## Implications
- Add speaker-source selection filtering to exclude bridge microphone sources.
- Add deterministic unit tests for speaker source selection logic.
- Update documentation to explain isolation behavior and override guidance.
