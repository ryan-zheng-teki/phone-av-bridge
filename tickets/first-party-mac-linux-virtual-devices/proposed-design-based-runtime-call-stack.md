# Proposed-Design-Based Runtime Call Stacks (Debug-Trace Style)

## Design Basis

- Scope Classification: `Large`
- Call Stack Version: `v2`
- Source Artifact: `tickets/first-party-mac-linux-virtual-devices/proposed-design.md`
- Source Design Version: `v3`
- Referenced Sections:
  - `Target State (To-Be)`
  - `Change Inventory (Delta-Aware)`
  - `File/Module Responsibilities And APIs`

## Use Case Index

- UC-001: Install Android app, pair host in <= 2 minutes.
- UC-002: Enable camera and select phone-backed camera in meeting app.
- UC-003: Enable microphone and select phone-backed mic in meeting app.
- UC-004: Enable speaker and route desktop output to phone speaker.
- UC-005: Run camera, microphone, and speaker concurrently.
- UC-006: Disconnect and reconnect recovery.
- UC-007: macOS install and first run without OBS/BlackHole.
- UC-008: Linux install and first run without mandatory manual driver commands.
- UC-009: Preflight auto-detects missing prerequisites and offers remediation.

## Use Case: UC-001 Pairing

### Primary Runtime Call Stack

```text
[ENTRY] android-resource-companion/app/...:PairScreen:onSubmitPairCode(...)
└── [IO] POST /api/pair
    └── host-resource-agent/linux-app/server.mjs:createApp(...)
        └── [ASYNC] host-resource-agent/core/session-controller.mjs:pairHost(pairCode, metadata)
            ├── [STATE] #updateDeviceMetadata(metadata)
            ├── [STATE] state.paired=true; state.hostStatus='Paired'
            ├── [STATE] #refreshRouteHints()
            └── return status snapshot
```

### Branching / Fallback / Error

```text
[ERROR] invalid pair code
host-resource-agent/linux-app/server.mjs:/api/pair
└── throw Error('Invalid pair code') -> 400 JSON error
```

```text
[FALLBACK] partial metadata input
session-controller.mjs:#updateDeviceMetadata
└── keeps previous non-empty device identity fields
```

### Coverage Status

- Primary Path: `Covered`
- Fallback Path: `Covered`
- Error Path: `Covered`

## Use Case: UC-002 Camera Toggle

### Primary Runtime Call Stack

```text
[ENTRY] android-resource-companion/app/...:ResourceToggle:onCameraEnabled(...)
└── [IO] POST /api/toggles { camera=true, cameraStreamUrl, deviceName, deviceId }
    └── host-resource-agent/linux-app/server.mjs:createApp(...)
        └── [ASYNC] session-controller.mjs:applyResourceState(diff)
            ├── [STATE] #updateDeviceMetadata(diff)
            ├── [ASYNC] #applyCamera(true, streamUrl)
            │   ├── host-resource-agent/adapters/common/device-name.mjs:buildDeviceNames(phoneName)
            │   ├── host-resource-agent/adapters/macos-firstparty-camera/camera-runner.mjs:setDeviceIdentity(...)
            │   ├── host-resource-agent/adapters/macos-firstparty-camera/camera-runner.mjs:setStreamUrl(...)
            │   └── [ASYNC][IO] .../camera-runner.mjs:startCamera()
            ├── [STATE] state.resources.camera=true
            └── [STATE] state.hostStatus='Resource Active'
```

### Branching / Fallback / Error

```text
[FALLBACK] Linux compatibility mode requested
session-controller.mjs:#applyCamera
└── linux-camera/bridge-runner.mjs:startCamera() with LINUX_CAMERA_MODE='compatibility'
```

```text
[ERROR] camera adapter start failure
session-controller.mjs:#applyCamera
└── state.issues += { resource:'camera', message:error } ; connectionState='needs_attention'
```

### Coverage Status

- Primary Path: `Covered`
- Fallback Path: `Covered`
- Error Path: `Covered`

## Use Case: UC-003 Microphone Toggle

### Primary Runtime Call Stack

```text
[ENTRY] android-resource-companion/app/...:ResourceToggle:onMicrophoneEnabled(...)
└── [IO] POST /api/toggles { microphone=true, cameraStreamUrl, deviceName }
    └── server.mjs:/api/toggles
        └── [ASYNC] session-controller.mjs:applyResourceState
            ├── [ASYNC] #applyMicrophone(true)
            │   ├── audioAdapter:setDeviceIdentity(...)
            │   ├── audioAdapter:setStreamUrl(cameraStreamUrl)
            │   └── [ASYNC][IO] macos-firstparty-audio/audio-runner.mjs:startMicrophoneRoute()
            ├── [STATE] resources.microphone=true
            └── [STATE] #refreshRouteHints() -> '<Phone Name> Microphone'
```

### Branching / Fallback / Error

```text
[FALLBACK] Linux user-space audio path
linux-audio/audio-runner.mjs:startMicrophoneRoute
└── pactl/pw route creation; if one command variant fails, fallback to supported argument set
```

```text
[ERROR] microphone capability unavailable
session-controller.mjs:#applyMicrophone
└── issues += {resource:'microphone', message:'Microphone capability unavailable on this host.'}
```

### Coverage Status

- Primary Path: `Covered`
- Fallback Path: `Covered`
- Error Path: `Covered`

## Use Case: UC-004 Speaker Toggle

### Primary Runtime Call Stack

```text
[ENTRY] android-resource-companion/app/...:ResourceToggle:onSpeakerEnabled(...)
└── [IO] POST /api/toggles { speaker=true }
    └── session-controller.mjs:applyResourceState
        ├── [ASYNC] #applySpeaker(true)
        │   └── [ASYNC][IO] audio-runner.mjs:startSpeakerRoute()
        └── [STATE] resources.speaker=true

[ENTRY] android-resource-companion/app/...:SpeakerStreamClient:connect(...)
└── [IO] GET /api/speaker/stream
    └── session-controller.mjs:attachSpeakerStream(response)
        └── [IO] audio-runner.mjs:attachSpeakerClient(response)
```

### Branching / Fallback / Error

```text
[ERROR] speaker toggle before pairing
session-controller.mjs:applyResourceState
└── throw Error('Host is not paired. Pair first.')
```

```text
[ERROR] speaker stream requested while disabled
session-controller.mjs:attachSpeakerStream
└── throw Error('Speaker route is not active. Enable speaker first.')
```

### Coverage Status

- Primary Path: `Covered`
- Fallback Path: `N/A`
- Error Path: `Covered`

## Use Case: UC-005 Concurrent Camera + Mic + Speaker

### Primary Runtime Call Stack

```text
[ENTRY] POST /api/toggles { camera=true, microphone=true, speaker=true, ... }
└── session-controller.mjs:applyResourceState
    ├── [ASYNC] #applyCamera(true, streamUrl)
    ├── [ASYNC] #applyMicrophone(true)
    ├── [ASYNC] #applySpeaker(true)
    ├── [STATE] resources = { camera:true, microphone:true, speaker:true }
    └── [STATE] hostStatus='Resource Active' if issues=[]
```

### Branching / Fallback / Error

```text
[ERROR] one resource fails while others succeed
session-controller.mjs:applyResourceState
└── failed resource -> issues[] entry; healthy resources remain enabled
```

### Coverage Status

- Primary Path: `Covered`
- Fallback Path: `N/A`
- Error Path: `Covered`

## Use Case: UC-006 Disconnect / Reconnect Recovery

### Primary Runtime Call Stack

```text
[ENTRY] network/device reconnect event represented by fresh /api/toggles call with existing pair
└── session-controller.mjs:applyResourceState
    ├── [STATE] clears prior resource issues for camera/microphone/speaker
    ├── [ASYNC] restarts requested resource adapters idempotently
    └── [STATE] connectionState back to 'paired' when issues=[]
```

### Branching / Fallback / Error

```text
[FALLBACK] stale stream URL
session-controller.mjs:#applyCamera/#applyMicrophone
└── keep paired state, mark resource-specific issue, allow retry with new URL
```

### Coverage Status

- Primary Path: `Covered`
- Fallback Path: `Covered`
- Error Path: `Covered`

## Use Case: UC-007 macOS First-Run (No OBS/BlackHole)

### Primary Runtime Call Stack

```text
[ENTRY] host-resource-agent/installers/macos/install.command
└── [IO] install runtime + app bundle + first-party extension/plugin components
    └── launch host app
        └── [IO] POST /api/preflight
            └── core/preflight-service.mjs:runPreflight('darwin')
                ├── check ffmpeg + first-party extension presence
                ├── check app permissions status
                └── return remediation guidance
```

### Branching / Fallback / Error

```text
[ERROR] missing first-party camera extension
preflight-service.mjs:runPreflight
└── status='needs_attention', remediation points to one-click reinstall/repair
```

### Coverage Status

- Primary Path: `Covered`
- Fallback Path: `N/A`
- Error Path: `Covered`

## Use Case: UC-008 Linux First-Run Default Path

### Primary Runtime Call Stack

```text
[ENTRY] host-resource-agent/installers/linux/install.sh
└── [IO] detect distro and install required user-space packages
    └── launch host app
        └── [IO] POST /api/preflight
            └── preflight-service.mjs:runPreflight('linux')
                ├── check ffmpeg
                ├── check PipeWire/Pulse CLI tooling
                ├── check compatibility camera backend availability (optional)
                └── return status='ready' or 'ready_with_notes'
```

### Branching / Fallback / Error

```text
[FALLBACK] package manager auto-remediation unavailable
install.sh
└── emits exact missing dependency list for manual guided install in app UI
```

```text
[ERROR] user forces compatibility mode but kernel backend unavailable
linux-camera/bridge-runner.mjs:startCamera
└── error -> session issues + remediation
```

### Coverage Status

- Primary Path: `Covered`
- Fallback Path: `Covered`
- Error Path: `Covered`

## Use Case: UC-009 Preflight Guided Remediation

### Primary Runtime Call Stack

```text
[ENTRY] host app UI:Run Preflight button
└── [IO] POST /api/preflight
    └── preflight-service.mjs:runPreflight(platform)
        ├── [ASYNC][IO] commandExists/pathExists checks
        ├── [STATE] aggregate check results
        └── [IO] return structured checks[] + remediation text
```

### Branching / Fallback / Error

```text
[FALLBACK] non-primary platform detected
preflight-service.mjs:runPreflight
└── add platform_support warning and continue
```

```text
[ERROR] command probe execution fails
preflight-service.mjs helper functions
└── return conservative warning/fail result for specific check
```

### Coverage Status

- Primary Path: `Covered`
- Fallback Path: `Covered`
- Error Path: `Covered`
