# Investigation Notes

## Sources Consulted
- `desktop-av-bridge-host/adapters/linux-audio/audio-runner.mjs`
- Runtime Pulse/PipeWire state via `pactl`:
  - `pactl list short sources`
  - `pactl list short modules`
  - `pactl list source-outputs`
  - `pactl list sink-inputs`
- Runtime audio data checks:
  - `parec -d phone_av_bridge_mic_sink_...monitor`
  - `parec -d phone_av_bridge_mic_input_...`

## Findings
- Linux mic route currently creates:
  - `module-null-sink` (`phone_av_bridge_mic_sink_*`)
  - `module-remap-source` (`phone_av_bridge_mic_input_*`)
- RTSP->ffmpeg audio reaches the null sink monitor with real PCM data.
- The remapped source is selectable by apps but returns zero bytes (`parec` captured `0` bytes).
- Chrome source outputs are attached to the remapped source and remain effectively silent for capture.

## Constraints
- Fix must be Linux-only and must not affect macOS runtime paths.
- User should not run manual export/setup commands after install.
- Device naming must remain understandable in Zoom/Chrome.

## Open Unknowns
- Whether PipeWire-specific `module-remap-source` behavior is the only trigger across all distros.

## Implication
- Mic exposure should use the null-sink monitor source directly as canonical capture source on Linux to guarantee audio frames.
