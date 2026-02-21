# Future-State Runtime Call Stacks (Debug-Trace Style)

## Conventions

- Frame format: `path/to/file:functionName(...)`
- Boundary tags: `[ENTRY]`, `[ASYNC]`, `[STATE]`, `[IO]`, `[ERROR]`
- Legacy/discovery branches are intentionally removed.

## Design Basis

- Scope Classification: `Medium`
- Call Stack Version: `v1`
- Requirements: `tickets/in-progress/qr-only-pairing-remove-udp/requirements.md` (status `Design-ready`)
- Source Artifact: `tickets/in-progress/qr-only-pairing-remove-udp/proposed-design.md`
- Source Design Version: `v1`
- Referenced Sections: `Change Inventory C-001..C-010`, `Use-Case Coverage Matrix`

## Future-State Modeling Rule (Mandatory)

- Model target design behavior even when current code still contains discovery paths.

## Use Case Index (Stable IDs)

| use_case_id | Requirement | Use Case Name | Coverage Target (Primary/Fallback/Error) |
| --- | --- | --- | --- |
| UC-001 | R-001 | Android pair via QR only | Yes/N/A/Yes |
| UC-002 | R-002 | Unpair and re-pair cycle | Yes/N/A/Yes |
| UC-003 | R-003 | Host startup without UDP discovery | Yes/N/A/Yes |
| UC-004 | R-004 | Docs/UI copy sync for QR-only | Yes/N/A/N/A |

## Transition Notes

- Transition is in-place code cleanup; no temporary compatibility branches are retained.

## Use Case: UC-001 [Android pair via QR only]

### Goal

Pair the Android app with the selected host by scanning a host-generated QR token.

### Preconditions

- Android app unpaired.
- Host is running and can issue QR token.

### Expected Outcome

- Android is paired to host and status reflects paired readiness.

### Primary Runtime Call Stack

```text
[ENTRY] android-phone-av-bridge/.../MainActivity.kt:setupListeners()#pairButton.onClick
├── android-phone-av-bridge/.../MainActivity.kt:launchQrScan()
├── [ENTRY] android-phone-av-bridge/.../MainActivity.kt:qrScanLauncher.onResult
│   └── android-phone-av-bridge/.../MainActivity.kt:beginQrPairingFlow(rawPayload)
│       ├── android-phone-av-bridge/.../pairing/PairingCoordinator.kt:parseQrPayload(rawPayload)
│       ├── [ASYNC] android-phone-av-bridge/.../MainActivity.kt:ioExecutor.execute
│       │   ├── android-phone-av-bridge/.../pairing/PairingCoordinator.kt:redeemQrPayload(payload)
│       │   │   └── android-phone-av-bridge/.../network/HostApiClient.kt:redeemQrToken(baseUrl, token) [IO]
│       │   └── android-phone-av-bridge/.../MainActivity.kt:pairHost(host)
│       │       ├── android-phone-av-bridge/.../pairing/PairingCoordinator.kt:pairHost(host, deviceName, deviceId)
│       │       │   ├── android-phone-av-bridge/.../network/HostApiClient.kt:pair(...) [IO]
│       │       │   └── android-phone-av-bridge/.../network/HostApiClient.kt:fetchStatus(baseUrl) [IO]
│       │       ├── [STATE] android-phone-av-bridge/.../store/AppPrefs.kt:setHostBaseUrl/setHostPairCode/setPaired
│       │       └── android-phone-av-bridge/.../MainActivity.kt:applyForegroundServiceState()
└── android-phone-av-bridge/.../MainActivity.kt:updateUiFromPrefs()
```

### Branching / Fallback Paths

```text
[ERROR] invalid QR payload
MainActivity.kt:beginQrPairingFlow(...)
└── Toast(scan_qr_invalid) + keep unpaired state
```

```text
[ERROR] token redeem failure or host unreachable
MainActivity.kt:beginQrPairingFlow(...)
└── resolvePairFailureMessageRes(...) -> toast + keep unpaired state
```

### State And Data Transformations

- QR text -> `QrPairPayload(baseUrl, token)`.
- Redeem response bootstrap -> `DiscoveredHost` (logical host descriptor).
- Host snapshot + user prefs -> UI status + resource toggle state.

### Observability And Debug Points

- `Log.i/w` in QR parse/redeem and pair transitions.
- Host API failures surfaced through `lastHostStatusError`.

### Design Smells / Gaps

- Any legacy/backward-compatibility branch present? `No`
- Any naming-to-responsibility drift detected? `No`

### Coverage Status

- Primary Path: `Covered`
- Fallback Path: `N/A`
- Error Path: `Covered`

## Use Case: UC-002 [Unpair and re-pair cycle]

### Goal

Allow explicit unpair and immediate re-pair by scanning a fresh QR token.

### Preconditions

- Android app currently paired.

### Expected Outcome

- Unpair clears paired state and resources; re-pair repeats UC-001 successfully.

### Primary Runtime Call Stack

```text
[ENTRY] MainActivity.kt:setupListeners()#pairButton.onClick (paired=true)
├── MainActivity.kt:unpairHost()
│   ├── [ASYNC] ioExecutor.execute
│   │   ├── PairingCoordinator.kt:unpairHost(hostBaseUrl)
│   │   │   └── HostApiClient.kt:unpair(baseUrl) [IO]
│   │   ├── [STATE] AppPrefs.setPaired(false)
│   │   ├── [STATE] AppPrefs.clearResourceToggles(...)
│   │   └── MainActivity.kt:updateUiFromPrefs()
│   └── MainActivity.kt:applyForegroundServiceState() # stops service
└── subsequent pair uses UC-001 path
```

### Branching / Fallback Paths

- `N/A` (no alternate non-QR pairing path retained).

### Error Paths

```text
[ERROR] unpair API unreachable
MainActivity.kt:unpairHost()
└── ignore remote failure, keep robust local unpair path
```

### Coverage Status

- Primary Path: `Covered`
- Fallback Path: `N/A`
- Error Path: `Covered`

## Use Case: UC-003 [Host startup without UDP discovery]

### Goal

Start host with HTTP+QR pairing APIs only, without UDP listener startup.

### Preconditions

- Host process launched via `node desktop-app/server.mjs`.

### Expected Outcome

- Host serves bootstrap/QR/session APIs and can pair Android via QR flow.

### Primary Runtime Call Stack

```text
[ENTRY] desktop-av-bridge-host/desktop-app/server.mjs:main
└── desktop-av-bridge-host/desktop-app/server.mjs:startServer({host,port,advertisedHost,useMockAdapters,qrTokenTtlMs})
    ├── createApp(...)
    │   ├── createBootstrapRoutes(...) [IO]
    │   └── createSessionRoutes(...) [IO]
    ├── [IO] http.server.listen(...)
    └── return { close() } # closes controller + http server only
```

### Error Paths

```text
[ERROR] startup bind/listen failure
server.mjs:startServer(...)
└── main catch -> log error and exit(1)
```

### Coverage Status

- Primary Path: `Covered`
- Fallback Path: `N/A`
- Error Path: `Covered`

## Use Case: UC-004 [Docs/UI copy sync for QR-only]

### Goal

Ensure operator/user-facing text does not mention discovery-based pairing.

### Preconditions

- Implementation code changes complete.

### Expected Outcome

- In-scope docs and macOS UI text align with QR-only behavior.

### Primary Runtime Call Stack

```text
[ENTRY] Implementation doc sync step
├── update README.md pairing sections
├── update desktop-av-bridge-host/README.md pairing sections
├── update AGENTS.md runbook wording
└── update macos-camera-extension/.../ViewController.swift host status copy
```

### Coverage Status

- Primary Path: `Covered`
- Fallback Path: `N/A`
- Error Path: `N/A`
