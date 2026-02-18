# Proposed-Design-Based Runtime Call Stacks (Debug-Trace Style)

## Design Basis
- Scope Classification: `Large`
- Call Stack Version: `v2`
- Source Artifact: `tickets/macos-first-party-audio-driver/proposed-design.md`
- Source Design Version: `v2`
- Referenced Sections: Architecture Overview, Change Inventory (C-001..C-010), Use-Case Coverage Matrix

## Use Case Index
- UC-001: Install first-party driver and verify visibility.
- UC-002: Enable microphone and expose phone audio to meeting app.
- UC-003: Enable speaker route and stream desktop audio to phone.
- UC-004: Concurrent camera + microphone + speaker toggles.
- UC-005: Apply phone-name-prefixed device labels.
- UC-006: Recover routes after host restart.

## Use Case: UC-001 Install First-Party Driver And Verify Visibility

### Goal
Install PRC host package and get first-party audio virtual device(s) visible in macOS audio clients.

### Preconditions
- Host package copied locally.
- Installer has privileges for `/Library/Audio/Plug-Ins/HAL`.

### Expected Outcome
- `PRCAudio.driver` present and loaded by audio service.
- Preflight reports audio path ready.

### Primary Runtime Call Stack
```text
[ENTRY] host-resource-agent/installers/macos/install.command:main()
├── host-resource-agent/installers/macos/install.command:installHostBundle() [IO]
├── host-resource-agent/macos-audio-driver/scripts/install-driver.sh:installDriverBundle() [IO]
│   ├── cp PRCAudio.driver -> /Library/Audio/Plug-Ins/HAL [IO]
│   └── restart coreaudiod (if needed) [IO]
├── host-resource-agent/core/preflight-service.mjs:runPreflight()
│   ├── host-resource-agent/adapters/macos-firstparty-audio/driver-probe.mjs:probeDriverPresence() [IO]
│   └── host-resource-agent/adapters/macos-firstparty-audio/driver-probe.mjs:probeDeviceVisibility() [IO]
└── host-resource-agent/linux-app/server.mjs:respondStatusReady()
```

### Branching / Fallback Paths
```text
[FALLBACK] driver already installed, same version
install-driver.sh:detectInstalledVersion()
└── install-driver.sh:skipCopyAndRunLightRestart()
```

```text
[ERROR] insufficient permissions or install failure
install-driver.sh:installDriverBundle()
└── install-driver.sh:emitFailure("driver_install_failed")
```

### Coverage Status
- Primary Path: `Covered`
- Fallback Path: `Covered`
- Error Path: `Covered`

## Use Case: UC-002 Enable Microphone And Expose Phone Audio

### Goal
When user enables microphone toggle, meeting apps can select phone-backed PRC mic input.

### Preconditions
- Pairing established.
- RTSP stream URL available from Android app.

### Expected Outcome
- Driver input stream receives decoded PCM.
- Meeting app sees live phone mic audio.

### Primary Runtime Call Stack
```text
[ENTRY] host-resource-agent/core/session-controller.mjs:applyResourceState({ microphone:true, cameraStreamUrl }) [ASYNC]
├── host-resource-agent/adapters/macos-firstparty-audio/audio-runner.mjs:setDeviceIdentity(deviceName, deviceId) [STATE]
├── host-resource-agent/adapters/macos-firstparty-audio/audio-runner.mjs:setMicStreamUrl(rtspUrl) [STATE]
├── host-resource-agent/adapters/macos-firstparty-audio/audio-runner.mjs:startMicrophoneRoute() [ASYNC]
│   ├── host-resource-agent/adapters/macos-firstparty-audio/audio-runner.mjs:startRtspDecodeFfmpeg() [IO]
│   ├── host-resource-agent/adapters/macos-firstparty-audio/ipc-client.mjs:connectControlSocket('/tmp/prc-audio-driver.sock') [IO]
│   ├── host-resource-agent/adapters/macos-firstparty-audio/ipc-client.mjs:mapSharedMemory('mic_ingress') [IO]
│   └── host-resource-agent/adapters/macos-firstparty-audio/ipc-client.mjs:pushPcmFramesToRingBuffer() [IO]
├── host-resource-agent/macos-audio-driver/src/IPCBridge.mm:ReceiveMicFramesFromSharedMemory() [IO]
├── host-resource-agent/macos-audio-driver/src/PRCAudioDevice.mm:WriteInputRingBuffer() [STATE]
└── host-resource-agent/macos-audio-driver/src/PRCAudioDevice.mm:DoReadInputData() [ASYNC]
```

### Branching / Fallback Paths
```text
[FALLBACK] ffmpeg reconnect after RTSP interruption
audio-runner.mjs:monitorMicDecode()
└── audio-runner.mjs:restartRtspDecodeFfmpegWithBackoff() [IO]
```

```text
[ERROR] driver IPC unavailable
ipc-client.mjs:connectMicIngress()
└── session-controller.mjs:recordIssue({ resource:'microphone', message:'driver_ipc_unavailable' }) [STATE]
```

### Coverage Status
- Primary Path: `Covered`
- Fallback Path: `Covered`
- Error Path: `Covered`

## Use Case: UC-003 Enable Speaker Route And Stream Desktop Audio To Phone

### Goal
When user enables speaker toggle, desktop audio selected on PRC output route reaches phone speaker.

### Preconditions
- Driver output stream visible.
- Android app connected to `/api/speaker/stream`.

### Expected Outcome
- Output PCM from macOS apps is forwarded to phone with bounded latency.

### Primary Runtime Call Stack
```text
[ENTRY] host-resource-agent/core/session-controller.mjs:applyResourceState({ speaker:true }) [ASYNC]
├── host-resource-agent/adapters/macos-firstparty-audio/audio-runner.mjs:startSpeakerRoute() [ASYNC]
│   ├── host-resource-agent/adapters/macos-firstparty-audio/ipc-client.mjs:connectControlSocket('/tmp/prc-audio-driver.sock') [IO]
│   ├── host-resource-agent/adapters/macos-firstparty-audio/ipc-client.mjs:mapSharedMemory('speaker_egress') [IO]
│   └── host-resource-agent/adapters/macos-firstparty-audio/audio-runner.mjs:startSpeakerPump() [ASYNC]
├── [ENTRY] host-resource-agent/linux-app/server.mjs:GET /api/speaker/stream
│   └── host-resource-agent/adapters/macos-firstparty-audio/audio-runner.mjs:attachSpeakerClient(response) [IO]
├── host-resource-agent/macos-audio-driver/src/PRCAudioDevice.mm:DoWriteOutputData() [ASYNC]
├── host-resource-agent/macos-audio-driver/src/IPCBridge.mm:PublishSpeakerFramesToSharedMemory() [IO]
└── host-resource-agent/adapters/macos-firstparty-audio/audio-runner.mjs:broadcastSpeakerFrame(chunk) [IO]
```

### Branching / Fallback Paths
```text
[FALLBACK] no active speaker clients
audio-runner.mjs:broadcastSpeakerFrame()
└── audio-runner.mjs:dropFrameAndIncrementCounter() [STATE]
```

```text
[ERROR] speaker route enabled before pair complete
session-controller.mjs:#applySpeaker(true)
└── session-controller.mjs:recordIssue({ resource:'speaker', message:'pairing_required' }) [STATE]
```

### Coverage Status
- Primary Path: `Covered`
- Fallback Path: `Covered`
- Error Path: `Covered`

## Use Case: UC-004 Concurrent Camera + Microphone + Speaker

### Goal
All three resources run simultaneously without cross-resource shutdown cascades.

### Primary Runtime Call Stack
```text
[ENTRY] POST /api/toggles { camera:true, microphone:true, speaker:true, cameraStreamUrl }
├── session-controller.mjs:applyResourceState() [ASYNC]
│   ├── cameraAdapter:startCamera()
│   ├── macos-firstparty-audio/audio-runner.mjs:startMicrophoneRoute()
│   └── macos-firstparty-audio/audio-runner.mjs:startSpeakerRoute()
├── session-controller.mjs:verifyHealth() [ASYNC]
│   ├── cameraAdapter:isCameraRunning()
│   ├── audio-runner.mjs:isMicrophoneRunning()
│   └── audio-runner.mjs:isSpeakerRunning()
└── session-controller.mjs:publishStatus(resources={camera:true,microphone:true,speaker:true}) [STATE]
```

### Branching / Fallback Paths
```text
[ERROR] one resource fails to start
session-controller.mjs:applyResourceState()
└── session-controller.mjs:markOnlyFailedResourceInactive() [STATE]
```

### Coverage Status
- Primary Path: `Covered`
- Fallback Path: `N/A`
- Error Path: `Covered`

## Use Case: UC-005 Phone-Name-Prefixed Device Labels

### Goal
Device labels reflect active phone identity for user selection clarity.

### Primary Runtime Call Stack
```text
[ENTRY] host-resource-agent/core/session-controller.mjs:pairDevice(deviceName, deviceId)
├── host-resource-agent/adapters/common/device-name.mjs:buildDeviceNames(deviceName) [STATE]
├── host-resource-agent/adapters/macos-firstparty-audio/audio-runner.mjs:setDeviceIdentity() [STATE]
└── host-resource-agent/macos-audio-driver/src/PRCAudioPlugin.mm:UpdateDeviceProperties(deviceLabels) [ASYNC]
```

### Branching / Fallback Paths
```text
[ERROR] invalid or empty device name
device-name.mjs:normalizeDeviceIdentity()
└── device-name.mjs:returnDefault("Phone") [STATE]
```

```text
[FALLBACK] active paired phone changes
session-controller.mjs:applyResourceState({ pairedDeviceChanged:true })
└── PRCAudioPlugin.mm:UpdateDeviceProperties(newActivePhoneLabel) [ASYNC]
```

### Coverage Status
- Primary Path: `Covered`
- Fallback Path: `N/A`
- Error Path: `Covered`

## Use Case: UC-006 Restart Recovery Without Reboot

### Goal
After host app restart, previously enabled routes recover automatically from persisted state.

### Primary Runtime Call Stack
```text
[ENTRY] host-resource-agent/linux-app/server.mjs:bootstrap()
├── host-resource-agent/core/session-controller.mjs:loadPersistedState() [IO]
├── host-resource-agent/core/session-controller.mjs:reapplyActiveResources() [ASYNC]
│   ├── macos-firstparty-audio/audio-runner.mjs:startMicrophoneRoute()
│   └── macos-firstparty-audio/audio-runner.mjs:startSpeakerRoute()
└── host-resource-agent/core/session-controller.mjs:publishStatus("Resource Active") [STATE]
```

### Branching / Fallback Paths
```text
[FALLBACK] driver not yet ready during bootstrap
audio-runner.mjs:startMicrophoneRoute()
└── audio-runner.mjs:retryAfterDriverReadyProbe() [ASYNC]
```

```text
[ERROR] persisted state incompatible with current driver version
session-controller.mjs:loadPersistedState()
└── session-controller.mjs:resetResourcesAndRaiseIssue('state_upgrade_required') [STATE]
```

### Coverage Status
- Primary Path: `Covered`
- Fallback Path: `Covered`
- Error Path: `Covered`
