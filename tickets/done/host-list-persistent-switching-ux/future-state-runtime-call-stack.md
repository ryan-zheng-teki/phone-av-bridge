# Future-State Runtime Call Stacks (Debug-Trace Style)

Use this document as a future-state (`to-be`) execution model derived from the design basis.
Prefer exact `file:function` frames, explicit branching, and clear state/persistence boundaries.
Do not treat this document as an as-is trace of current code behavior.

## Conventions

- Frame format: `path/to/file.ts:functionName(args?)`
- Boundary tags:
  - `[ENTRY]` external entrypoint (API/CLI/event)
  - `[ASYNC]` async boundary (`await`, queue handoff, callback)
  - `[STATE]` in-memory mutation
  - `[IO]` file/network/database/cache IO
  - `[FALLBACK]` non-primary branch
  - `[ERROR]` error path
- Comments: use brief inline comments with `# ...`.
- Do not include legacy/backward-compatibility branches.

## Design Basis

- Scope Classification: `Medium`
- Call Stack Version: `v1`
- Requirements: `tickets/done/host-list-persistent-switching-ux/requirements.md` (status `Design-ready`)
- Source Artifact:
  - `Medium/Large`: `tickets/done/host-list-persistent-switching-ux/proposed-design.md`
- Source Design Version: `v1`
- Referenced Sections:
  - Change Inventory C-001..C-005
  - File And Module Breakdown
  - Use-Case Coverage Matrix

## Future-State Modeling Rule (Mandatory)

- Model target design behavior even when current code diverges.
- If migration from as-is to to-be requires transition logic, describe that logic in `Transition Notes`; do not replace the to-be call stack with current flow.

## Use Case Index (Stable IDs)

| use_case_id | Requirement | Use Case Name | Coverage Target (Primary/Fallback/Error) |
| --- | --- | --- | --- |
| UC-001 | R-001 | Unpaired user sees full discovered host list on main screen | Yes/Yes/Yes |
| UC-002 | R-001,R-002 | Paired user still sees host list and action state | Yes/Yes/N/A |
| UC-003 | R-002,R-003 | Paired user selects different host and switches | Yes/Yes/Yes |
| UC-004 | R-003,R-005 | Switch failure handling and QR availability | Yes/N/A/Yes |
| UC-005 | R-004 | Discovery refresh while paired keeps list updated | Yes/Yes/N/A |

## Transition Notes

- Replace preview-only refresh behavior with candidate refresh behavior in activity periodic ticker.
- Retire paired-only host-list hide behavior.

## Use Case: UC-001 [Unpaired host list visibility]

### Goal

Unpaired user sees all currently discovered hosts in main-screen list.

### Preconditions

- App is open in `MainActivity`.
- User is not paired (`AppPrefs.isPaired == false`).

### Expected Outcome

- Host list shows all discovered hosts.
- Selection state is visible and actionable.

### Primary Runtime Call Stack

```text
[ENTRY] android-phone-av-bridge/.../MainActivity.kt:onResume()
├── android-phone-av-bridge/.../MainActivity.kt:refreshHostCandidates()
│   ├── android-phone-av-bridge/.../MainActivity.kt:discoverHostCandidates()
│   │   └── android-phone-av-bridge/.../pairing/PairingCoordinator.kt:discoverHostsForPair(...) [IO]
│   │       ├── android-phone-av-bridge/.../network/HostDiscoveryClient.kt:discoverAll(...) [IO]
│   │       └── android-phone-av-bridge/.../network/HostApiClient.kt:fetchBootstrap(...) [FALLBACK][IO]
│   ├── android-phone-av-bridge/.../pairing/HostSelectionState.kt:reconcile(...) [STATE]
│   └── android-phone-av-bridge/.../MainActivity.kt:updateUiFromPrefs() [STATE]
│       └── android-phone-av-bridge/.../MainActivity.kt:updateHostCandidatesUi(...) [STATE]
└── android-phone-av-bridge/.../MainActivity.kt:render host rows complete
```

### Branching / Fallback Paths

```text
[FALLBACK] UDP discovery empty
PairingCoordinator.kt:discoverHostsForPair(...)
└── HostApiClient.kt:fetchBootstrap(savedBaseUrl) [IO]
```

```text
[ERROR] discovery/bootstrap both fail
MainActivity.kt:refreshHostCandidates()
└── MainActivity.kt:updateUiFromPrefs() # show searching/no-host hint
```

### State And Data Transformations

- discovery responses -> `List<DiscoveredHost>`.
- list + prior selection + pairing context -> `HostSelectionSnapshot`.

### Observability And Debug Points

- Main activity logs discovery/presence failures.

### Design Smells / Gaps

- Any legacy/backward-compatibility branch present? (`No`)
- Any naming-to-responsibility drift detected? (`No`)

### Open Questions

- None.

### Coverage Status

- Primary Path: `Covered`
- Fallback Path: `Covered`
- Error Path: `Covered`

## Use Case: UC-002 [Paired host list visibility + action state]

### Goal

Paired user can still see all available hosts and current action mode (`Unpair` or `Switch`).

### Preconditions

- User is paired to host A.

### Expected Outcome

- Host rows remain visible including host A and alternates.
- Action label reflects selected row relative to current host.

### Primary Runtime Call Stack

```text
[ENTRY] android-phone-av-bridge/.../sync/HostStateRefresher.kt:startTicker(...) [ASYNC]
└── android-phone-av-bridge/.../MainActivity.kt:ensureHostStatusTicker()
    ├── MainActivity.kt:refreshHostStatusIfPaired(...) [IO]
    │   └── HostApiClient.kt:fetchStatus(currentBaseUrl) [IO]
    ├── MainActivity.kt:refreshHostCandidates()
    │   ├── MainActivity.kt:discoverHostCandidates() [IO]
    │   └── HostSelectionState.kt:reconcile(...) [STATE]
    └── MainActivity.kt:updateUiFromPrefs()
        ├── MainActivity.kt:updateHostCandidatesUi(paired=true)
        └── MainActivity.kt:resolvePrimaryActionLabel(...) # Pair/Switch/Unpair
```

### Branching / Fallback Paths

```text
[FALLBACK] current host absent from latest UDP list
PairingCoordinator.kt:discoverHostsForPair(...)
└── include saved/current host bootstrap fallback [IO]
```

### State And Data Transformations

- `currentBaseUrl` + selected host -> `HostSelectionAction`.

### Observability And Debug Points

- host status errors stored in `lastHostStatusError` and surfaced in issues text.

### Design Smells / Gaps

- Any legacy/backward-compatibility branch present? (`No`)
- Any naming-to-responsibility drift detected? (`No`)

### Coverage Status

- Primary Path: `Covered`
- Fallback Path: `Covered`
- Error Path: `N/A`

## Use Case: UC-003 [Switch selected host while paired]

### Goal

User selects host B while paired to host A and switches in one action.

### Preconditions

- Paired to host A.
- Host B is selected.

### Expected Outcome

- A is unpaired.
- B becomes paired and persisted to prefs.

### Primary Runtime Call Stack

```text
[ENTRY] android-phone-av-bridge/.../MainActivity.kt:pairButton.setOnClickListener
└── MainActivity.kt:beginPairSelectionFlow()
    ├── MainActivity.kt:resolvePrimaryAction() -> SWITCH [STATE]
    ├── MainActivity.kt:switchHost(targetHost)
    │   └── PairingCoordinator.kt:switchHost(currentBaseUrl, targetHost, deviceName, deviceId)
    │       ├── HostApiClient.kt:unpair(currentBaseUrl) [IO]
    │       ├── HostApiClient.kt:pair(targetBaseUrl, pairCode, deviceName, deviceId) [IO]
    │       └── HostApiClient.kt:fetchStatus(targetBaseUrl) [IO]
    ├── AppPrefs.kt:setHostBaseUrl/setHostPairCode/setPaired [IO]
    └── MainActivity.kt:updateUiFromPrefs() [STATE]
```

### Branching / Fallback Paths

```text
[FALLBACK] unpair old host fails (unreachable)
PairingCoordinator.kt:switchHost(...)
└── continue pair target host with best-effort old-host cleanup
```

```text
[ERROR] pair target fails
MainActivity.kt:switchHost(...)
└── update error text + remain stable with host list visible
```

### State And Data Transformations

- Selected `DiscoveredHost` + current host base URL -> switch transaction inputs.
- Switch success -> prefs current host rewritten to target host.

### Observability And Debug Points

- switch attempt and failure reason logged at activity/coordinator level.

### Design Smells / Gaps

- Any legacy/backward-compatibility branch present? (`No`)
- Any naming-to-responsibility drift detected? (`No`)

### Coverage Status

- Primary Path: `Covered`
- Fallback Path: `Covered`
- Error Path: `Covered`

## Use Case: UC-004 [Failure handling + QR availability]

### Goal

Switch/pair failures remain recoverable, and QR path is still available.

### Preconditions

- App can be paired or unpaired.

### Expected Outcome

- Error message shown; UI remains interactive.
- `Scan QR Pairing` remains available in unpaired mode.

### Primary Runtime Call Stack

```text
[ENTRY] MainActivity.kt:beginPairSelectionFlow()/switchHost()/pairHost()
└── [ERROR] exception from PairingCoordinator/HostApiClient
    ├── MainActivity.kt:lastHostStatusError = ... [STATE]
    ├── MainActivity.kt:updateUiFromPrefs() [STATE]
    └── Toast + issues/status detail update

[ENTRY] MainActivity.kt:scanQrButton.setOnClickListener
└── MainActivity.kt:launchQrScan() -> beginQrPairingFlow(...) [IO]
```

### Branching / Fallback Paths

```text
[ERROR] QR payload invalid/expired
MainActivity.kt:beginQrPairingFlow(...)
└── toast + stay unpaired with host list visible
```

### Coverage Status

- Primary Path: `Covered`
- Fallback Path: `N/A`
- Error Path: `Covered`

## Use Case: UC-005 [Discovery refresh while paired]

### Goal

While paired, alternate hosts remain visible and refreshed.

### Preconditions

- Ticker is active.
- User is paired.

### Expected Outcome

- Host list updates over time and preserves explicit selection when still valid.

### Primary Runtime Call Stack

```text
[ENTRY] HostStateRefresher.kt:startTicker(...) [ASYNC]
└── MainActivity.kt:ensureHostStatusTicker()
    └── scheduled task
        ├── MainActivity.kt:refreshHostStatusIfPaired()
        ├── MainActivity.kt:refreshHostCandidates()
        │   ├── MainActivity.kt:discoverHostCandidates() [IO]
        │   └── HostSelectionState.kt:reconcile(...) [STATE]
        └── MainActivity.kt:updateUiFromPrefs() [STATE]
```

### Branching / Fallback Paths

```text
[FALLBACK] selected host removed from candidate list
HostSelectionState.kt:reconcile(...)
└── clear explicit selection and require selection when multi-host
```

### Coverage Status

- Primary Path: `Covered`
- Fallback Path: `Covered`
- Error Path: `N/A`
