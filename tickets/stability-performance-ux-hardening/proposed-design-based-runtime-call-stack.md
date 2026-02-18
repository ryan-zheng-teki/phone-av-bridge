# Proposed-Design-Based Runtime Call Stacks (Debug-Trace Style)

## Design Basis
- Scope Classification: `Medium`
- Call Stack Version: `v1`
- Requirements: `tickets/stability-performance-ux-hardening/requirements.md` (status `Design-ready`)
- Source Artifact: `tickets/stability-performance-ux-hardening/proposed-design.md` (`v1`)

## Use Case Index (Stable IDs)
| use_case_id | Requirement | Use Case Name | Coverage Target (Primary/Fallback/Error) |
| --- | --- | --- | --- |
| UC-PAIR-01 | R-001 | Pair host from disconnected state | Yes/Yes/Yes |
| UC-STATUS-01 | R-001,R-002 | Render clear paired/degraded status | Yes/N/A/Yes |
| UC-CAMERA-01 | R-003 | Enable camera with explicit quality profile | Yes/Yes/Yes |
| UC-MIC-01 | R-003 | Enable microphone route | Yes/Yes/Yes |
| UC-SPEAKER-01 | R-004 | Enable speaker route and playback | Yes/Yes/Yes |
| UC-HOST-ISSUE-01 | R-005 | Normalize host issues for UI | Yes/N/A/Yes |

## Use Case: UC-PAIR-01 Pair host from disconnected state

### Primary Runtime Call Stack
```text
[ENTRY] android.../MainActivity.kt:pairHost()
├── android.../MainActivity.kt:discoverHostOrThrow() [ASYNC][IO]
│   ├── android.../network/HostDiscoveryClient.kt:discover(timeoutMs)
│   └── android.../network/HostApiClient.kt:fetchBootstrap(savedBaseUrl?) [FALLBACK][IO]
├── android.../network/HostApiClient.kt:pair(baseUrl, pairCode, deviceName, deviceId) [IO]
├── android.../store/AppPrefs.kt:setHostBaseUrl/setHostPairCode/setPaired [STATE]
├── android.../network/HostApiClient.kt:fetchCapabilities(baseUrl) [IO]
└── android.../MainActivity.kt:updateUiFromPrefs()+applyForegroundServiceState() [STATE]
```

### Fallback / Error Paths
```text
[FALLBACK] discovery timeout
MainActivity.kt:discoverHostOrThrow()
└── HostApiClient.kt:fetchBootstrap(savedBaseUrl) [IO]
```

```text
[ERROR] host unreachable or pair rejected
HostApiClient.kt:request(...)
└── MainActivity.kt:pairHost(catch) -> setPaired(false), render categorized error [STATE]
```

## Use Case: UC-STATUS-01 Render clear paired/degraded status

### Primary Runtime Call Stack
```text
[ENTRY] android.../MainActivity.kt:onCreate()/onResume()
├── MainActivity.kt:refreshHostCapabilitiesIfPaired() [ASYNC][IO]
├── MainActivity.kt:refreshHostStatusIfPaired() [ASYNC][IO]
│   └── HostApiClient.kt:fetchStatus(baseUrl)
├── MainActivity.kt:deriveUiState(prefs + hostStatus + local flags) [STATE]
└── MainActivity.kt:renderUiState()
```

### Error Path
```text
[ERROR] fetch status failed while paired
MainActivity.kt:refreshHostStatusIfPaired(catch)
└── MainActivity.kt:markDegraded("Host unreachable") + keep paired state [STATE]
```

## Use Case: UC-CAMERA-01 Enable camera with explicit quality profile

### Primary Runtime Call Stack
```text
[ENTRY] android.../MainActivity.kt:cameraSwitch.onCheckedChange
├── AppPrefs.kt:setCameraEnabled(true) [STATE]
├── MainActivity.kt:applyForegroundServiceState()
│   └── ResourceService.kt:onStartCommand(...)
│       ├── ResourceService.kt:syncPhoneMediaRoutes(state)
│       │   └── PhoneRtspStreamer.kt:update(camera=true,mic=*) 
│       │       └── PhoneRtspStreamer.kt:startCameraMode() -> prepareVideo(explicit profile)+prepareAudio?+startStream [STATE]
│       └── ResourceService.kt:publishStateToHost(stateWithCameraStream) [ASYNC][IO]
└── host.../linux-app/server.mjs:POST /api/toggles -> SessionController.applyResourceState(diff) [IO]
```

### Fallback / Error Paths
```text
[FALLBACK] camera route unhealthy
SessionController.mjs:#applyResourceStateSerial(...)
└── runtimeHealthy=false -> re-apply camera adapter start
```

```text
[ERROR] stream prep failure
PhoneRtspStreamer.kt:startCameraMode()
└── throws -> ResourceService.kt:syncPhoneMediaRoutes(catch) clear stream url + publish degraded [STATE]
```

## Use Case: UC-MIC-01 Enable microphone route

### Primary Runtime Call Stack
```text
[ENTRY] android.../MainActivity.kt:micSwitch.onCheckedChange
├── AppPrefs.kt:setMicEnabled(true) [STATE]
├── ResourceService.kt:syncPhoneMediaRoutes()
│   └── PhoneRtspStreamer.kt:update(camera|mic) -> camera mode with audio or audio-only mode
├── ResourceService.kt:publishStateToHost(...) [IO]
└── host.../SessionController.mjs:#applyMicrophone(true)
    ├── audioAdapter.setStreamUrl(cameraStreamUrl)
    └── audioAdapter.startMicrophoneRoute() [IO/subprocess]
```

### Error Path
```text
[ERROR] microphone adapter start failure
SessionController.mjs:#applyMicrophone(catch)
└── push normalized issue("Microphone route unavailable...") [STATE]
```

## Use Case: UC-SPEAKER-01 Enable speaker route and playback

### Primary Runtime Call Stack
```text
[ENTRY] android.../MainActivity.kt:speakerSwitch.onCheckedChange
├── AppPrefs.kt:setSpeakerEnabled(true) [STATE]
├── ResourceService.kt:syncPhoneMediaRoutes()
│   └── HostSpeakerStreamPlayer.kt:start(baseUrl) -> runLoop(streamUrl) [ASYNC]
│       └── streamOnce() [IO] -> parse PCM headers -> AudioTrack.write(aligned chunks) [STATE]
└── host.../SessionController.mjs:#applySpeaker(true)
    └── audioAdapter.startSpeakerRoute() [IO/subprocess]
```

### Fallback / Error Paths
```text
[FALLBACK] transient speaker stream disconnect
HostSpeakerStreamPlayer.kt:runLoop()
└── catch -> sleep -> reconnect
```

```text
[ERROR] no speaker route active on host
GET /api/speaker/stream -> SessionController.attachSpeakerStream()
└── throws -> Android player reconnect loop remains active until route enabled
```

## Use Case: UC-HOST-ISSUE-01 Normalize host issues

### Primary Runtime Call Stack
```text
[ENTRY] host.../SessionController.mjs:#applyCamera/#applyMicrophone/#applySpeaker
├── adapter throws low-level error
├── SessionController.mjs:#normalizeIssue(resource, errorMessage) [STATE]
└── SessionController.mjs:state.issues.push(normalizedIssue) [STATE]
```

### Error Path
```text
[ERROR] unknown adapter message
SessionController.mjs:#normalizeIssue(...)
└── fallback generic remediation message per resource class
```
