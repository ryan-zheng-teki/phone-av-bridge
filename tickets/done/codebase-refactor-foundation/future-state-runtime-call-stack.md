# Future-State Runtime Call Stacks (Debug-Trace Style)

## Conventions

- Frame format: `path/to/file:functionName(...)`
- Boundary tags:
  - `[ENTRY]` external entrypoint
  - `[ASYNC]` async boundary
  - `[STATE]` in-memory mutation
  - `[IO]` network/file/process IO
  - `[FALLBACK]` non-primary branch
  - `[ERROR]` error branch

## Design Basis

- Scope Classification: `Large`
- Call Stack Version: `v2`
- Requirements: `tickets/in-progress/codebase-refactor-foundation/requirements.md` (status `Design-ready`)
- Source Artifact: `tickets/in-progress/codebase-refactor-foundation/proposed-design.md`
- Source Design Version: `v2`
- Referenced Sections:
  - `Target State (To-Be)`
  - `Change Inventory (Delta)`
  - `Use-Case Coverage Matrix`

## Future-State Modeling Rule (Mandatory)

- Model target design behavior; do not encode as-is monolith call paths.
- Migration notes are tracked separately in implementation plan/progress.

## Use Case Index (Stable IDs)

| use_case_id | Requirement | Use Case Name | Coverage Target (Primary/Fallback/Error) |
| --- | --- | --- | --- |
| UC-001 | R-001 | macOS controller decomposition parity | Yes/Yes/Yes |
| UC-002 | R-002 | Android activity decomposition parity | Yes/Yes/Yes |
| UC-003 | R-003 | Host server route/service decomposition parity | Yes/Yes/Yes |
| UC-004 | R-004 | Verification and release continuity | Yes/N/A/Yes |

## Transition Notes

- Existing monolith entry files remain as integration entrypoints while internals are extracted.
- Old inline logic is removed after each extracted module is wired and verified.
- Cutover checkpoints are strict:
  1. macOS parser/timer inline methods removed only after client/coordinator parity verification.
  2. Android inline pairing logic removed only after coordinator parity verification.
  3. Host inline route handlers removed only after router/service parity verification.

## Use Case: UC-001 [macOS controller decomposition parity]

### Goal

Keep macOS app behavior identical while splitting API, QR coordination, and view-building concerns from `ViewController`.

### Preconditions

- Host app reachable at `http://127.0.0.1:8787`.
- Camera extension app launches successfully.

### Expected Outcome

- UI shows host status + QR pairing state correctly.
- Start/restart host and refresh status continue to work.

### Primary Runtime Call Stack

```text
[ENTRY] macos-camera-extension/samplecamera/ViewController.swift:viewDidLoad(...)
├── macos-camera-extension/samplecamera/ui/CameraMainViewBuilder.swift:build(...) [STATE]
├── macos-camera-extension/samplecamera/ViewController.swift:bindUiActions(...)
├── macos-camera-extension/samplecamera/ViewController.swift:refreshHostBridgeStatus(autoStartIfNeeded=true) [ASYNC]
│   ├── macos-camera-extension/samplecamera/host/HostBridgeClient.swift:health(...) [IO]
│   ├── macos-camera-extension/samplecamera/ViewController.swift:applyHostBridgeHealth(...)
│   ├── macos-camera-extension/samplecamera/host/HostBridgeClient.swift:fetchStatus(...) [IO]
│   ├── macos-camera-extension/samplecamera/ViewController.swift:applyHostResourceStatus(...) [STATE]
│   └── macos-camera-extension/samplecamera/pairing/QrTokenCoordinator.swift:start(...) [ASYNC]
│       ├── macos-camera-extension/samplecamera/host/HostBridgeClient.swift:issueQrToken(...) [IO]
│       ├── macos-camera-extension/samplecamera/pairing/QrTokenCoordinator.swift:scheduleCountdown(...) [STATE]
│       └── macos-camera-extension/samplecamera/ViewController.swift:applyQrSnapshot(...) [STATE]
└── macos-camera-extension/samplecamera/ViewController.swift:startFrameServer(...) [IO]
```

### Branching / Fallback Paths

```text
[FALLBACK] host offline during heartbeat
ViewController.swift:refreshHostBridgeStatus(...)
├── HostBridgeClient.swift:health(...) [IO]
├── ViewController.swift:resetHostResourceSection(bridgeOnline=false) [STATE]
└── QrTokenCoordinator.swift:stop(reason="host_offline") [STATE]
```

```text
[FALLBACK] qr image payload missing but text payload available
QrTokenCoordinator.swift:refresh(...)
├── HostBridgeClient.swift:issueQrToken(...) [IO]
└── ViewController.swift:renderQrFromPayloadText(...) [STATE]
```

```text
[ERROR] qr token request fails
HostBridgeClient.swift:issueQrToken(...) [IO]
└── ViewController.swift:showQrErrorState(...) [STATE]
```

### State And Data Transformations

- `HostStatusResponse JSON -> HostStatusSnapshot` via typed decoder.
- `QrTokenResponse JSON -> QrTokenSnapshot` via typed decoder.
- `QrTokenSnapshot -> rendered NSImage + countdown labels`.

### Observability And Debug Points

- Runtime log messages at host online/offline transitions.
- Runtime log messages for qr issue failure/expiry/refresh.
- Decommission checkpoint logs: explicit temporary instrumentation confirms old path is removed before next slice.

### Design Smells / Gaps

- Any legacy/backward-compatibility branch present? `No`
- Any naming-to-responsibility drift detected? `No`

### Coverage Status

- Primary Path: `Covered`
- Fallback Path: `Covered`
- Error Path: `Covered`

## Use Case: UC-002 [Android activity decomposition parity]

### Goal

Preserve Android pairing/resource behavior while extracting pairing, refresh, and publish responsibilities from `MainActivity`.

### Preconditions

- Android app installed with required permissions.
- Host reachable on LAN or via QR payload base URL.

### Expected Outcome

- Pairing flows (discover-select-pair, QR pair, unpair) continue unchanged.
- Resource toggle publishing and status refresh continue unchanged.

### Primary Runtime Call Stack

```text
[ENTRY] android-phone-av-bridge/.../MainActivity.kt:onCreate(...)
├── MainActivity.kt:bindViewsAndListeners(...)
├── android-phone-av-bridge/.../pairing/PairingCoordinator.kt:attach(...)
├── android-phone-av-bridge/.../sync/HostStateRefresher.kt:startTicker(...) [ASYNC]
└── android-phone-av-bridge/.../MainActivity.kt:onPairButtonClick(...)
    └── PairingCoordinator.kt:beginPairSelectionFlow(...) [ASYNC]
        ├── HostDiscoveryClient.kt:discoverAll(...) [IO]
        ├── PairingCoordinator.kt:resolveSelection(...) [STATE]
        ├── HostApiClient.kt:pair(...) [IO]
        ├── AppPrefs.kt:setPairedHost(...) [STATE]
        └── MainActivity.kt:renderSessionState(...) [STATE]
```

### Branching / Fallback Paths

```text
[FALLBACK] qr pairing path
MainActivity.kt:onScanQrClick(...)
└── PairingCoordinator.kt:pairFromQrPayload(raw)
    ├── QrPairPayloadParser.kt:parse(raw)
    ├── HostApiClient.kt:redeemQrToken(...) [IO]
    ├── HostApiClient.kt:pair(...) [IO]
    └── MainActivity.kt:renderSessionState(...) [STATE]
```

```text
[FALLBACK] multiple host candidates
PairingCoordinator.kt:beginPairSelectionFlow(...)
├── HostDiscoveryClient.kt:discoverAll(...) [IO]
├── PairingCoordinator.kt:buildSelectionList(...) [STATE]
└── MainActivity.kt:showHostSelectionDialog(...) [STATE]
```

```text
[ERROR] publish toggles fails
ResourcePublishCoordinator.kt:publishWithRetry(...) [ASYNC]
├── HostApiClient.kt:applyToggles(...) [IO]
└── MainActivity.kt:showPublishFailure(...) [STATE]
```

### State And Data Transformations

- Discovery response list -> `DiscoveredHost` candidates.
- QR payload -> `QrPairPayload` -> resolved host bootstrap.
- Preferences + UI toggles -> publish command payload.

### Observability And Debug Points

- Existing `PhoneAvBridgeMain` log points retained at coordinator boundaries.
- Retry counters and failure classification emitted by publish coordinator.
- Decommission checkpoint logs: pairing events emitted from coordinator path only.

### Design Smells / Gaps

- Any legacy/backward-compatibility branch present? `No`
- Any naming-to-responsibility drift detected? `No`

### Coverage Status

- Primary Path: `Covered`
- Fallback Path: `Covered`
- Error Path: `Covered`

## Use Case: UC-003 [Host server route/service decomposition parity]

### Goal

Preserve host endpoint contracts while splitting routing and service internals.

### Preconditions

- Host runtime config resolved (`port`, `discovery`, persistence).

### Expected Outcome

- Existing `/api/*` behavior remains stable.
- Token lifecycle and session operations remain stable.

### Primary Runtime Call Stack

```text
[ENTRY] desktop-av-bridge-host/desktop-app/server.mjs:startServer(...)
├── desktop-av-bridge-host/desktop-app/server.mjs:createRuntimeContext(...) [STATE]
├── desktop-av-bridge-host/desktop-app/http-router.mjs:buildHttpHandler(...) [STATE]
│   ├── desktop-av-bridge-host/desktop-app/routes/bootstrap-routes.mjs:register(...)
│   └── desktop-av-bridge-host/desktop-app/routes/session-routes.mjs:register(...)
└── desktop-av-bridge-host/desktop-app/http-router.mjs:handle(req,res) [ASYNC]
    └── desktop-av-bridge-host/desktop-app/routes/session-routes.mjs:handleToggles(...) [ASYNC]
        ├── desktop-av-bridge-host/core/session-controller.mjs:applyResourceState(...) [ASYNC]
        └── desktop-av-bridge-host/desktop-app/http-response.mjs:json(...) [IO]
```

### Branching / Fallback Paths

```text
[FALLBACK] static asset request
http-router.mjs:handle(req,res)
└── desktop-av-bridge-host/desktop-app/static-server.mjs:serveStatic(...) [IO]
```

```text
[FALLBACK] qr token issue/redeem
routes/bootstrap-routes.mjs:handleQrIssue(...) [ASYNC]
├── services/qr-token-service.mjs:issueQrToken(...) [STATE]
└── http-response.mjs:json(...) [IO]
```

```text
[ERROR] invalid request payload
routes/session-routes.mjs:handlePair(...)
└── http-response.mjs:error(...) [IO]
```

### State And Data Transformations

- Request JSON -> validated route command.
- Token service state machine (`unused` -> `used`/`expired`).
- Session controller status -> response payload.

### Observability And Debug Points

- Route-level warning logs for failures.
- QR issue/redeem logs retained with token preview.
- Decommission checkpoint logs: route dispatch path identifies module-owned handler names.

### Design Smells / Gaps

- Any legacy/backward-compatibility branch present? `No`
- Any naming-to-responsibility drift detected? `No`

### Coverage Status

- Primary Path: `Covered`
- Fallback Path: `Covered`
- Error Path: `Covered`

## Use Case: UC-004 [Verification and release continuity]

### Goal

Ensure refactor delivery is testable and release automation remains unchanged.

### Preconditions

- Refactor slices merged and buildable.

### Expected Outcome

- Tests and builds pass.
- Tag push still triggers release workflow.

### Primary Runtime Call Stack

```text
[ENTRY] developer workflow: run verification suite
├── desktop-av-bridge-host/package.json:test [IO]
├── android-phone-av-bridge/gradlew:testDebugUnitTest [IO]
├── android-phone-av-bridge/gradlew:assembleDebug [IO]
├── macos-camera-extension/xcodebuild:samplecamera [IO]
└── git push --tags [IO]
    └── .github/workflows/release.yml:Release [ASYNC]
```

### Branching / Fallback Paths

- `N/A`

```text
[ERROR] test failure classification
implementation-progress.md:recordFailure(...)
└── classify as Local Fix / Design Impact / Requirement Gap
```

### State And Data Transformations

- Verification outputs -> progress status rows.

### Observability And Debug Points

- CI run status + local command outputs.

### Design Smells / Gaps

- Any legacy/backward-compatibility branch present? `No`
- Any naming-to-responsibility drift detected? `No`

### Coverage Status

- Primary Path: `Covered`
- Fallback Path: `N/A`
- Error Path: `Covered`
