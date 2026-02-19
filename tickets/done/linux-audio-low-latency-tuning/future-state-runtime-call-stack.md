# Future-State Runtime Call Stack

## Version
v1

## UC-1: Start microphone route with low-latency defaults
1. `core/session-controller.mjs:applyResources(...)`
2. `adapters/linux-audio/audio-runner.mjs:startMicrophoneRoute()`
3. `adapters/linux-audio/audio-runner.mjs:#startMicFfmpeg(streamUrl)`
4. `adapters/linux-audio/audio-runner.mjs:buildLinuxMicFfmpegArgs(streamUrl, {lowLatency:true})`
5. `adapters/linux-audio/audio-runner.mjs:resolveLinuxMicPulseLatencyMsec(...)`
6. Spawn ffmpeg with low-latency args and pulse latency hint.

## UC-2: Compatibility fallback
1. `audio-runner.mjs:#awaitFfmpegStartup(...)` reports early failure.
2. `audio-runner.mjs:#startMicFfmpeg(streamUrl)` retries once with baseline args (`lowLatency:false`).
3. If retry succeeds, normal route startup continues.
4. If retry fails, explicit mic bridge error is surfaced.

## UC-3: Keep device behavior stable
1. Existing sink/module wiring and monitor source selection remain unchanged.
2. `getMicrophoneDeviceName()` output remains monitor-based target naming.
