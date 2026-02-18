# Future-State Runtime Call Stack

## Version
v1

## UC-1: Enable microphone route on Linux with audible capture
1. `desktop-av-bridge-host/core/session-controller.mjs:applyResources(...)`
2. `desktop-av-bridge-host/adapters/linux-audio/audio-runner.mjs:startMicrophoneRoute()`
3. `desktop-av-bridge-host/adapters/linux-audio/audio-runner.mjs:#cleanupStaleMicrophoneModules()`
4. `desktop-av-bridge-host/adapters/linux-audio/audio-runner.mjs:#loadNullSink()`
5. `desktop-av-bridge-host/adapters/linux-audio/audio-runner.mjs:#setMonitorMicrophoneSelectionTarget()`
6. `desktop-av-bridge-host/adapters/linux-audio/audio-runner.mjs:#startMicFfmpeg(streamUrl)`
7. `desktop-av-bridge-host/adapters/linux-audio/audio-runner.mjs:#moveSinkInputToBridgeSink(pid, micSinkName)`
8. Apps capture from `\`<micSinkName>.monitor\`` (primary path)
9. Fallback/error: if ffmpeg startup or sink move fails, route start throws explicit error and session reports issue.

## UC-2: Report microphone naming and route hints
1. `desktop-av-bridge-host/core/session-controller.mjs:getStatus()`
2. `desktop-av-bridge-host/adapters/linux-audio/audio-runner.mjs:getMicrophoneDeviceName()`
3. `desktop-av-bridge-host/adapters/common/device-name.mjs:buildDeviceNames(...)`
4. Web UI reads status and displays monitor-based route hint/device label.

## UC-3: Stop route and cleanup
1. `desktop-av-bridge-host/adapters/linux-audio/audio-runner.mjs:stopMicrophoneRoute()`
2. Terminates mic ffmpeg process.
3. Unloads null-sink module and stale modules bound to `sink_name=<micSinkName>`.
4. Resets active route flags and selection target.
