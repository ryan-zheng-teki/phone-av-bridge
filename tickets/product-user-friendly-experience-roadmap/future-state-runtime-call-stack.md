# Future-State Runtime Call Stacks (Debug-Trace Style)

## Design Basis
- Scope Classification: Large
- Call Stack Version: v2
- Requirements: `tickets/product-user-friendly-experience-roadmap/requirements.md` (Design-ready)
- Source Artifact: `tickets/product-user-friendly-experience-roadmap/proposed-design.md`
- Source Design Version: v2

## Use Case Index (Stable IDs)
| use_case_id | Requirement | Use Case Name | Coverage Target |
| --- | --- | --- | --- |
| UC-001 | R-001 | First-run onboarding checklist | Yes/Yes/Yes |
| UC-002 | R-001 | Pairing + permissions | Yes/Yes/Yes |
| UC-003 | R-002 | Intent vs applied resource state | Yes/Yes/Yes |
| UC-004 | R-003 | Guided remediation | Yes/Yes/Yes |
| UC-005 | R-004 | Pre-meeting self-test | Yes/Yes/Yes |
| UC-006 | R-005 | Share/install package | Yes/N/A/Yes |

## Use Case: UC-001 First-run onboarding checklist
### Primary Runtime Call Stack
```text
[ENTRY] android-resource-companion/.../MainActivity.kt:onCreate(...)
├── MainActivity.kt:refreshHostPreviewIfUnpaired(...) [ASYNC][IO]
├── MainActivity.kt:updateUiFromPrefs(...) [STATE]
└── MainActivity.kt:renderSetupChecklist(...) [STATE]
```
### Fallback / Error
```text
[FALLBACK] host preview missing
MainActivity.kt:resolveUnpairedHostSummary(...)
└── render checklist step as "Searching host"
```
```text
[ERROR] discovery timeout
MainActivity.kt:refreshHostPreviewIfUnpaired(...)
└── statusDetail = actionable retry hint
```

## Use Case: UC-002 Pairing + permissions
### Primary Runtime Call Stack
```text
[ENTRY] MainActivity.kt:pairHost(...)
├── HostDiscoveryClient.kt:discover(...) [IO]
├── HostApiClient.kt:pair(...) [IO]
├── AppPrefs.kt:setPaired(...) [STATE]
├── MainActivity.kt:applyForegroundServiceState(...) [ASYNC]
└── MainActivity.kt:updateUiFromPrefs(...) [STATE]
```
### Fallback / Error
```text
[FALLBACK] discovery miss -> bootstrap fallback
MainActivity.kt:discoverHostOrThrow(...)
└── HostApiClient.kt:fetchBootstrap(...) [IO]
```
```text
[ERROR] permission denied
MainActivity.kt:permissionLauncher callback
└── updateUiFromPrefs(...) -> explicit next action
```

## Use Case: UC-003 Intent vs applied resource state
### Primary Runtime Call Stack
```text
[ENTRY] MainActivity.kt:applyForegroundServiceState(...)
├── AppPrefs.kt:isCameraEnabled/isMicEnabled/isSpeakerEnabled(...) [STATE]
├── ResourceService.kt:onStartCommand(...) [ASYNC]
├── HostApiClient.kt:publishToggles(...) [IO]
├── host-resource-agent/linux-app/server.mjs:/api/toggles [ENTRY]
├── session-controller.mjs:applyResourceState(...) [STATE]
└── /api/status -> HostApiClient.kt:fetchStatus(...) [IO]
```
### Fallback / Error
```text
[FALLBACK] drift detected
MainActivity.kt:refreshHostStatusIfPaired(...)
└── applyForegroundServiceState(...) retry
```
```text
[ERROR] route failed
session-controller.mjs:#pushIssue(...)
└── status.healthState=degraded + nextAction
```

## Use Case: UC-004 Guided remediation
### Primary Runtime Call Stack
```text
[ENTRY] macos-camera-extension/.../ViewController.swift:refreshHostResourceStatus(...)
├── fetch /api/status [IO]
├── render health chip + issue summary [STATE]
└── render nextAction button mapping [STATE]
```
### Fallback / Error
```text
[FALLBACK] host offline
ViewController.swift:refreshHostBridgeStatus(...)
└── nextAction = Start Host Bridge
```
```text
[ERROR] extension blocked
ViewController.swift:openExtensionsSettings(...)
└── user remediation deep link
```

## Use Case: UC-005 Pre-meeting self-test
### Primary Runtime Call Stack
```text
[ENTRY] MainActivity.kt:onRunSelfTest(...)
├── HostApiClient.kt:fetchStatus(...) [IO]
├── ResourceService.kt:syncPhoneMediaRoutes(...) [ASYNC]
├── host-resource-agent/...:/api/status [IO]
└── MainActivity.kt:renderSelfTestResults(...) [STATE]
```
### Fallback / Error
```text
[FALLBACK] mic/speaker unavailable
renderSelfTestResults -> partial pass with action hints
```
```text
[ERROR] no host
show "Start Host Agent" + disable meeting-ready badge
```

## Use Case: UC-006 Share/install package
### Primary Runtime Call Stack
```text
[ENTRY] release process
├── android build signed release APK [IO]
├── macOS PRCCamera build + zip [IO]
├── host-agent archive build [IO]
└── INSTALL.md + SHA256SUMS generation [IO]
```
### Error
```text
[ERROR] missing signing/runtime tool
release script exits with actionable message and no partial publish
```
