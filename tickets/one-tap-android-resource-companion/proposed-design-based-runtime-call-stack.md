# Proposed-Design-Based Runtime Call Stacks (Debug-Trace Style)

## Conventions

- Frame format: `path/to/file:functionName(args?)`
- Boundary tags:
  - `[ENTRY]`, `[ASYNC]`, `[STATE]`, `[IO]`, `[FALLBACK]`, `[ERROR]`
- Future-state model only (derived from design `v2`).

## Design Basis

- Scope Classification: `Large`
- Call Stack Version: `v3`
- Source Artifact: `tickets/one-tap-android-resource-companion/proposed-design.md`
- Source Design Version: `v3`

## Use Case Index

- UC-001: Install + Pair
- UC-002: Camera toggle ON/OFF
- UC-003: Microphone toggle ON/OFF
- UC-004: Speaker toggle ON/OFF
- UC-005: Independent toggle updates
- UC-006: Reconnect/recovery
- UC-007: Linux host install + launch
- UC-008: macOS host install + guided permissions
- UC-009: Host first-run preflight + remediation

---

## Use Case: UC-001 Install + Pair

### Primary Runtime Call Stack

```text
[ENTRY] android-resource-companion/app/src/main/java/.../MainActivity.kt:onPairButtonTapped()
├── android-resource-companion/.../AppPrefs.kt:setPaired(true) [STATE]
├── android-resource-companion/.../MainActivity.kt:applyForegroundServiceState() [STATE]
├── host-resource-agent/core/session-controller.mjs:pairHost(pairCode) [IO]
└── host-resource-agent/linux-app/server.mjs:createApp(...)/POST /api/pair handler [ASYNC][STATE]
```

### Branching / Error

```text
[ERROR] pair code invalid
session-controller.mjs:pairHost(pairCode)
└── linux-app/server.mjs:respondValidationError()
```

Coverage:
- Primary: `Covered`
- Fallback: `Covered`
- Error: `Covered`

---

## Use Case: UC-002 Camera toggle ON/OFF

### Primary Runtime Call Stack

```text
[ENTRY] android-resource-companion/.../MainActivity.kt:onCameraToggleChanged(enabled)
├── android-resource-companion/.../MainActivity.kt:applyForegroundServiceState() [STATE]
├── host-resource-agent/core/session-controller.mjs:applyResourceState({camera: enabled}) [STATE]
├── host-resource-agent/adapters/linux-camera/bridge-runner.mjs:startCamera(config) [IO][ASYNC]
└── host-resource-agent/linux-app/server.mjs:createApp(...)/POST /api/toggles handler [STATE]
```

### Fallback / Error

```text
[FALLBACK] camera capability missing on host
preflight-service.mjs:runPreflight()
└── server.mjs:publishNeedsAttention("camera capability unavailable")
```

```text
[ERROR] bridge startup failure
bridge-runner.mjs:startCamera(config)
└── session-controller.mjs:markResourceError("camera")
```

Coverage:
- Primary: `Covered`
- Fallback: `Covered`
- Error: `Covered`

---

## Use Case: UC-003 Microphone toggle ON/OFF

### Primary Runtime Call Stack

```text
[ENTRY] MainActivity.kt:onMicToggleChanged(enabled)
├── MainActivity.kt:applyForegroundServiceState() [STATE]
├── session-controller.mjs:applyResourceState({microphone: enabled}) [STATE]
└── adapters/linux-audio/audio-runner.mjs:startMicrophoneRoute() [IO][ASYNC]
```

### Error

```text
[ERROR] audio backend unavailable
audio-runner.mjs:startMicrophoneRoute()
└── session-controller.mjs:markResourceError("microphone")
```

Coverage:
- Primary: `Covered`
- Fallback: `Covered`
- Error: `Covered`

---

## Use Case: UC-004 Speaker toggle ON/OFF

### Primary Runtime Call Stack

```text
[ENTRY] MainActivity.kt:onSpeakerToggleChanged(enabled)
├── MainActivity.kt:applyForegroundServiceState() [STATE]
├── session-controller.mjs:applyResourceState({speaker: enabled}) [STATE]
├── adapters/linux-audio/audio-runner.mjs:startSpeakerRoute() [IO][ASYNC]
└── linux-app/server.mjs:GET /api/speaker/stream -> session-controller.mjs:attachSpeakerStream() [IO]
```

### Fallback

```text
[FALLBACK] speaker capture source unavailable
linux-audio/audio-runner.mjs:startSpeakerRoute()
└── session-controller.mjs:applyResourceState() -> hostStatus "Needs Attention"
```

Coverage:
- Primary: `Covered`
- Fallback: `Covered`
- Error: `Covered`

---

## Use Case: UC-005 Independent toggle updates

### Primary Runtime Call Stack

```text
[ENTRY] host-resource-agent/linux-app/static/app.js:onToggleChanged(resource, enabled)
├── linux-app/server.mjs:createApp(...)/POST /api/toggles handler [IO]
├── session-controller.mjs:applyResourceState(diff) [STATE]
├── session-controller.mjs:#applyCamera(diff.camera) [ASYNC]
└── session-controller.mjs:#applyMicrophone/#applySpeaker(diff.microphone, diff.speaker) [ASYNC]
```

Coverage:
- Primary: `Covered`
- Fallback: `Covered`
- Error: `Covered`

---

## Use Case: UC-006 Reconnect/recovery

### Primary Runtime Call Stack

```text
[ENTRY] session-controller.mjs:onHeartbeatTimeout() [ASYNC]
├── session-controller.mjs:connectionState -> reconnecting [STATE]
├── session-controller.mjs:resumeSession() [IO]
├── session-controller.mjs:reapplyResourceStateSnapshot() [STATE]
└── linux-app/server.mjs:createApp(...)/GET /api/status handler [STATE]
```

### Error

```text
[ERROR] reconnect retries exhausted
session-controller.mjs:resumeSession()
└── linux-app/server.mjs:publishNeedsAttention("manual re-pair required")
```

Coverage:
- Primary: `Covered`
- Fallback: `Covered`
- Error: `Covered`

---

## Use Case: UC-007 Linux host install + launch

### Primary Runtime Call Stack

```text
[ENTRY] host-resource-agent/installers/linux/install.sh:main()
├── install.sh:extractBundleToUserDir() [IO]
├── install.sh:installDesktopEntry() [IO]
├── install.sh:installLauncherScript() [IO]
└── linux-app/server.mjs:startServer() [ENTRY]
```

### Error

```text
[ERROR] missing runtime dependency
install.sh:checkRuntime()
└── install.sh:printGuidedRemediation()
```

Coverage:
- Primary: `Covered`
- Fallback: `Covered`
- Error: `Covered`

---

## Use Case: UC-008 macOS host install + guided permissions

### Primary Runtime Call Stack

```text
[ENTRY] host-resource-agent/installers/macos/install.command:main()
├── install.command:copyAppBundleToApplications() [IO]
├── install.command:bootstrapDependencies(ffmpeg,obs,blackhole) [IO]
├── linux-app/server.mjs:startServer() [ENTRY]
└── adapters/macos-camera/obs-virtualcam-runner.mjs:startCamera() [STATE]
```

### Fallback

```text
[FALLBACK] macOS blocks OBS Camera Extension until user approval
obs-virtualcam-runner.mjs:startCamera()
└── session-controller.mjs:#applyCamera()
   └── server.mjs:/api/status -> hostStatus "Needs Attention"
```

Coverage:
- Primary: `Covered`
- Fallback: `Covered`
- Error: `Covered`

---

## Use Case: UC-009 Host first-run preflight + remediation

### Primary Runtime Call Stack

```text
[ENTRY] linux-app/static/app.js:onRunPreflightClicked()
├── linux-app/server.mjs:handlePreflightRequest() [IO]
├── core/preflight-service.mjs:runPreflight(platform) [STATE]
├── core/preflight-service.mjs:buildRemediationPlan(findings) [STATE]
└── linux-app/server.mjs:returnPreflightReport() [IO]
```

### Error

```text
[ERROR] preflight execution failure
preflight-service.mjs:runPreflight(platform)
└── server.mjs:returnPreflightError("check logs and retry")
```

Coverage:
- Primary: `Covered`
- Fallback: `Covered`
- Error: `Covered`
