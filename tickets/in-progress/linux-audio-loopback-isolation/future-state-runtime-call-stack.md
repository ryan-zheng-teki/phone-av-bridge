# Future-State Runtime Call Stack

## Version
v1

## UC-1 Speaker route chooses safe monitor while mic route active
- `desktop-av-bridge-host/core/session-controller.mjs:applyResourceState(...)`
- `desktop-av-bridge-host/adapters/linux-audio/audio-runner.mjs:startSpeakerRoute()`
- `desktop-av-bridge-host/adapters/linux-audio/audio-runner.mjs:#resolveSpeakerSourceName()`
- `desktop-av-bridge-host/adapters/linux-audio/audio-runner.mjs:pickLinuxSpeakerCaptureSource(...)`
  - Inputs: env override, default sink name, discovered sources, mic sink/source identities
  - Decision gate: reject bridge mic sources
  - Decision gate: prefer monitor source candidates
- `desktop-av-bridge-host/adapters/linux-audio/audio-runner.mjs:#startSpeakerCapture(sourceName)`
- Result: speaker route captures safe host output source, reducing mic self-loopback risk.

Coverage:
- Primary: Yes
- Fallback: Yes (choose non-monitor safe source if monitor unavailable)
- Error: Yes (null source -> clear startup error)

## UC-2 Override remains authoritative
- `audio-runner.mjs:#resolveSpeakerSourceName()` reads `LINUX_SPEAKER_CAPTURE_SOURCE`
- `pickLinuxSpeakerCaptureSource` returns override immediately
- speaker route starts capture using explicit override

Coverage:
- Primary: Yes
- Fallback: N/A
- Error: Yes (override invalid -> ffmpeg startup error)

## UC-3 Only bridge mic sources available
- source resolver receives sources that all match bridge mic exclusion rules
- helper returns `null`
- `startSpeakerRoute` throws `No PulseAudio/PipeWire source available for speaker capture.`

Coverage:
- Primary: Yes
- Fallback: N/A
- Error: Yes
