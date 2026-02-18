# Future-State Runtime Call Stack

## Version
v2

## UC-1 Speaker route chooses safe monitor while mic route active
- `desktop-av-bridge-host/core/session-controller.mjs:applyResourceState(...)`
- `desktop-av-bridge-host/adapters/linux-audio/audio-runner.mjs:startMicrophoneRoute()`
- `desktop-av-bridge-host/adapters/linux-audio/audio-runner.mjs:#ensureVirtualMicrophoneSource()`
  - Decision gate: create `module-remap-source` (`PhoneAVBridgeMicInput-*`) when supported
  - Fallback: keep monitor-based source target
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
- `phone-av-bridge-host-start` loads persistent config (`/etc/default/phone-av-bridge-host` for Debian or `~/.config/phone-av-bridge-host/env` for local install)
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

## UC-4 Restart/Stop does not leave duplicate media pipelines
- `phone-av-bridge-host-stop` kills host PID tree and stale bridge workers (`run-bridge.sh` + bridge mic ffmpeg).
- `desktop-av-bridge-host/desktop-app/server.mjs` handles `SIGTERM`/`SIGINT`/`SIGHUP`.
- `desktop-av-bridge-host/core/session-controller.mjs:shutdownResources()` disables active camera/microphone/speaker routes.
- `desktop-av-bridge-host/adapters/linux-audio/audio-runner.mjs:stopMicrophoneRoute()` unloads active + stale mic bridge modules.
- `phone-av-bridge-host-start` performs stale worker/module cleanup before launching server.

Coverage:
- Primary: Yes
- Fallback: N/A
- Error: Yes (cleanup best-effort; startup still proceeds)
