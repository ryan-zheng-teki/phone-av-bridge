# Proposed Design Document

## Design Version

- Current Version: `v2`

## Revision History

| Version | Trigger | Summary Of Changes | Related Review Round |
| --- | --- | --- | --- |
| v1 | Initial draft | Define cross-platform modular refactor plan and target boundaries. | 1 |
| v2 | Review write-back | Added explicit interface contracts and decommission checkpoints for extraction sequencing. | 1 |

## Artifact Basis

- Investigation Notes: `tickets/in-progress/codebase-refactor-foundation/investigation-notes.md`
- Requirements: `tickets/in-progress/codebase-refactor-foundation/requirements.md`
- Requirements Status: `Design-ready`

## Summary

Refactor architecture by decomposing oversized controller modules into explicit boundary-owned modules while preserving behavior. The target shape is: thin UI/controller entrypoints, extracted domain/service coordinators, typed API client/model layers, and testable routing/service boundaries.

## Goals

1. Reduce multi-responsibility files (`ViewController.swift`, `MainActivity.kt`, `server.mjs`).
2. Increase testable seams for networking, state mapping, and pairing logic.
3. Preserve user-visible behavior and endpoint contracts.
4. Keep release pipeline and operational workflow unchanged.

## Legacy Removal Policy (Mandatory)

- Policy: `No backward compatibility; remove legacy code paths.`
- Required action: delete obsolete inline logic after extraction, avoid parallel old/new paths.

## Requirements And Use Cases

| Requirement | Description | Acceptance Criteria | Use Case IDs |
| --- | --- | --- | --- |
| R-001 | macOS architecture decomposition | `ViewController.swift` no longer owns API parsing + QR lifecycle internals | UC-001 |
| R-002 | Android architecture decomposition | `MainActivity.kt` reduced to UI orchestration + delegates | UC-002 |
| R-003 | Host server decomposition | routing/service/token logic split from server bootstrap | UC-003 |
| R-004 | Regression-safe delivery | tests/build/release remain functional | UC-004 |

## Codebase Understanding Snapshot (Pre-Design Mandatory)

| Area | Findings | Evidence (files/functions) | Open Unknowns |
| --- | --- | --- | --- |
| Entrypoints / Boundaries | UI entrypoints carry domain logic | `samplecamera/ViewController.swift`, `MainActivity.kt`, `desktop-app/server.mjs` | Final Android decomposition pattern |
| Current Naming Conventions | Mostly descriptive, but boundaries drift | `*Controller`, `*Runner`, `*Client` naming patterns | Preferred suffix convention for coordinators |
| Impacted Modules / Responsibilities | Three primary hotspots plus adapters | files listed in investigation notes | Sequencing to minimize churn |
| Data / Persistence / External IO | HTTP, UDP, timers, app prefs, state file | `/api/*`, `HostDiscoveryClient`, host state persistence | E2E coverage boundaries per platform |

## Current State (As-Is)

1. macOS: one `ViewController` handles UI, frame pipeline, host health/status polling, QR token generation/rendering, and status parsing.
2. Android: one `MainActivity` handles listeners, permissions, discovery/pairing orchestration, status refresh, and publish retry.
3. Host server: one `server.mjs` contains HTTP routing, bootstrap/QR logic, persistence wiring, and discovery setup.

## Target State (To-Be)

1. macOS:
   - `ViewController` keeps lifecycle/UI orchestration only.
   - `HostBridgeClient` owns typed API calls + parsing.
   - `QrTokenCoordinator` owns QR request/timer/expiry policy.
   - `CameraMainViewBuilder` owns AppKit view tree creation and component wiring.
2. Android:
   - `MainActivity` keeps view lifecycle and delegates actions.
   - `PairingCoordinator` owns discover/select/pair/unpair/QR parse workflow.
   - `HostStateRefresher` owns host status polling + cache update.
   - `ResourcePublishCoordinator` owns publish retry and service-state propagation.
3. Host:
   - `http-router.mjs` dispatches routes.
   - route modules own endpoint registration and request/response mapping.
   - service modules own token lifecycle/bootstrap/session operations.
   - `server.mjs` remains bootstrap/runtime composition entrypoint.

## Change Inventory (Delta)

| Change ID | Change Type (`Add`/`Modify`/`Rename/Move`/`Remove`) | Current Path | Target Path | Rationale | Impacted Areas | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| C-001 | Add | N/A | `macos-camera-extension/samplecamera/host/HostBridgeClient.swift` | Typed API boundary for host calls and status/QR parsing | macOS | Removes dictionary parsing from controller |
| C-002 | Add | N/A | `macos-camera-extension/samplecamera/pairing/QrTokenCoordinator.swift` | Isolate timer and token lifecycle | macOS | Owns auto-refresh + manual refresh policy |
| C-003 | Add | N/A | `macos-camera-extension/samplecamera/ui/CameraMainViewBuilder.swift` | Move giant UI builder out of controller | macOS | Returns structured view refs |
| C-004 | Modify | `macos-camera-extension/samplecamera/ViewController.swift` | same file | Convert to orchestration-only | macOS | delete inline parsing/build code |
| C-005 | Add | N/A | `android-phone-av-bridge/app/src/main/java/org/autobyteus/phoneavbridge/pairing/PairingCoordinator.kt` | Separate pairing workflow from activity | Android | includes QR parse/redeem orchestration |
| C-006 | Add | N/A | `android-phone-av-bridge/app/src/main/java/org/autobyteus/phoneavbridge/sync/HostStateRefresher.kt` | Separate status refresh lifecycle | Android | periodic refresh + state snapshots |
| C-007 | Add | N/A | `android-phone-av-bridge/app/src/main/java/org/autobyteus/phoneavbridge/publish/ResourcePublishCoordinator.kt` | Separate publish retry policy | Android | reduces activity complexity |
| C-008 | Modify | `android-phone-av-bridge/app/src/main/java/org/autobyteus/phoneavbridge/MainActivity.kt` | same file | Keep lifecycle/UI wiring, delegate business logic | Android | no behavior change |
| C-009 | Add | N/A | `desktop-av-bridge-host/desktop-app/http-router.mjs` | Isolate route dispatch from bootstrap | Host | easier route-unit testing |
| C-010 | Add | N/A | `desktop-av-bridge-host/desktop-app/routes/bootstrap-routes.mjs` | Encapsulate bootstrap + QR endpoints | Host | keeps existing endpoint contracts |
| C-011 | Add | N/A | `desktop-av-bridge-host/desktop-app/routes/session-routes.mjs` | Encapsulate pair/unpair/presence/toggles endpoints | Host | clear contract boundary |
| C-012 | Add | N/A | `desktop-av-bridge-host/desktop-app/services/qr-token-service.mjs` | Encapsulate issue/redeem token lifecycle | Host | isolates stateful token registry |
| C-013 | Modify | `desktop-av-bridge-host/desktop-app/server.mjs` | same file | Reduce to app composition + runtime startup | Host | remove inline route bodies |
| C-014 | Remove | inline anonymous/local parser/helper blocks | module-local extracted functions | eliminate duplicate parser logic in entry modules | macOS/Android/Host | no compatibility branch retained |

## Architecture Overview

- Presentation layer: `ViewController`, `MainActivity`, static web UI.
- Coordination/services layer: new `*Coordinator`/`*Client`/`*Service` modules.
- Runtime/adapters layer: existing camera/audio runners and session controller.
- Transport layer: host HTTP routing + Android/macOS clients.

## File And Module Breakdown

| File/Module | Change Type | Concern / Responsibility | Public APIs | Inputs/Outputs | Dependencies |
| --- | --- | --- | --- | --- | --- |
| `ViewController.swift` | Modify | macOS lifecycle + UI action orchestration | existing `@objc` actions + lifecycle | UI events -> coordinator/client calls | `HostBridgeClient`, `QrTokenCoordinator`, camera runtime hooks |
| `HostBridgeClient.swift` | Add | Typed host API adapter for macOS | `health()`, `fetchStatus()`, `issueQrToken()` | HTTP JSON -> typed models | `URLSession` |
| `QrTokenCoordinator.swift` | Add | QR timer lifecycle and refresh policy | `start()`, `stop()`, `refresh(manual:)` | token model -> callbacks for UI | `HostBridgeClient`, `Timer` |
| `CameraMainViewBuilder.swift` | Add | Construct and style macOS view hierarchy | `build()` returning refs | config -> NSView + component refs | `AppKit` |
| `MainActivity.kt` | Modify | Android lifecycle + view binding only | `onCreate/onResume/onDestroy` + delegates | UI events -> coordinator calls | new coordinators |
| `PairingCoordinator.kt` | Add | pair/unpair/discover/QR pairing orchestration | `beginPairSelection`, `pairFromQr`, `unpair` | UI intents -> host API ops | `HostApiClient`, `HostDiscoveryClient`, parser |
| `HostStateRefresher.kt` | Add | host status refresh + memoized snapshot | `refreshIfPaired`, `startTicker`, `stopTicker` | host status -> UI-facing state | executors/time |
| `ResourcePublishCoordinator.kt` | Add | resource toggle publish with retry | `publishTogglesWithRetry` | prefs/state -> host toggles update | `ResourceService`, `HostApiClient` |
| `server.mjs` | Modify | runtime startup/composition only | `createApp/startServer` | config -> running server | router + services + controller |
| `http-router.mjs` | Add | route dispatch abstraction | `buildHttpHandler(...)` | req/res -> route handler | route modules |
| `bootstrap-routes.mjs` | Add | bootstrap + qr endpoints | registration function | req -> bootstrap/qr responses | qr/bootstrap services |
| `session-routes.mjs` | Add | status/pair/unpair/presence/toggles routes | registration function | req -> session responses | session controller |
| `qr-token-service.mjs` | Add | token issue/redeem state machine | `issueQrToken`, `redeemQrToken` | token store + payload | crypto/qrcode |

## Interface Contracts (Write-Back Clarification)

| Contract ID | Producer | Consumer | Contract Shape | Notes |
| --- | --- | --- | --- | --- |
| IC-001 | `HostBridgeClient` | `ViewController` | Typed snapshots (`HostStatusSnapshot`, `QrTokenSnapshot`) via completion callback | Prevent `[String: Any]` parsing in UI controller |
| IC-002 | `QrTokenCoordinator` | `ViewController` | `onSnapshot`, `onError`, `onExpiryTick` callbacks | One-way update flow; coordinator does not know UI tree |
| IC-003 | `PairingCoordinator` | `MainActivity` | `PairingUiEvent` callback stream (`Loading`, `SelectionNeeded`, `Paired`, `Error`) | Keeps activity as rendering/orchestration shell |
| IC-004 | `HostStateRefresher` | `MainActivity` | `HostStatusUiModel` callback on schedule/manual refresh | Isolates ticker lifecycle from activity logic |
| IC-005 | `http-router` | route modules | route registration function signature (`method`, `path`, `handler`) | Prevent route logic from leaking into bootstrap |

## Layer-Appropriate Separation Of Concerns Check

- UI/frontend scope: UI entrypoints only orchestrate interaction + render.
- Non-UI scope: business/network logic extracted into dedicated modules.
- Integration scope: host route handling and token lifecycle isolated behind service boundaries.

## Naming Decisions (Natural And Implementation-Friendly)

| Item Type (`File`/`Module`/`API`) | Current Name | Proposed Name | Reason | Notes |
| --- | --- | --- | --- | --- |
| File | `ViewController.swift` monolith internals | `HostBridgeClient.swift` | clear host API adapter role | retained controller for lifecycle |
| File | `ViewController.swift` timer internals | `QrTokenCoordinator.swift` | explicit lifecycle owner | avoids timer leakage in controller |
| File | `MainActivity.kt` pairing internals | `PairingCoordinator.kt` | clear use-case owner | activity remains UI entrypoint |
| File | `MainActivity.kt` host status ticker internals | `HostStateRefresher.kt` | readable status sync owner | isolates executor logic |
| File | `server.mjs` route blocks | `bootstrap-routes.mjs` / `session-routes.mjs` | endpoint ownership clarity | reduces huge switch/if chain |
| API | inline closure-based route checks | `buildHttpHandler()` | testable router composition | retains same endpoint behavior |

## Naming Drift Check (Mandatory)

| Item | Current Responsibility | Does Name Still Match? (`Yes`/`No`) | Corrective Action (`Rename`/`Split`/`Move`/`N/A`) | Mapped Change ID |
| --- | --- | --- | --- | --- |
| `ViewController.swift` | Controller + API + QR + UI build + runtime | No | Split | C-001/C-002/C-003/C-004 |
| `MainActivity.kt` | Activity + pairing + sync + publish | No | Split | C-005/C-006/C-007/C-008 |
| `server.mjs` | bootstrap + routes + services + discovery | No | Split | C-009/C-010/C-011/C-012/C-013 |

## Dependency Flow And Cross-Reference Risk

| Module/File | Upstream Dependencies | Downstream Dependents | Cross-Reference Risk | Mitigation / Boundary Strategy |
| --- | --- | --- | --- | --- |
| `ViewController` | `HostBridgeClient`, `QrTokenCoordinator` | none | Medium | define callback-based coordinator outputs; no back-reference from coordinator to view controller |
| `PairingCoordinator` | API/discovery/parser | `MainActivity` | Medium | keep coordinator stateless where possible; pass explicit callbacks |
| `HostStateRefresher` | API + executor | `MainActivity` | Low | single owner lifecycle methods |
| `http-router` | route registry | `server.mjs` | Low | one-way registration at bootstrap |
| `qr-token-service` | crypto/qrcode | route handlers | Low | pure service module, no req/res knowledge |

## Decommission / Cleanup Plan

| Item To Remove/Rename | Cleanup Actions | Legacy Removal Notes | Verification |
| --- | --- | --- | --- |
| Inline host status JSON parsing in `ViewController` | move to typed model decoding in client module | remove duplicate parsing blocks | macOS build + status UI manual smoke |
| Inline QR timer logic in `ViewController` | move to coordinator and delete controller timer methods | no dual timer paths | unit-like coordinator tests + macOS build |
| Inline pairing orchestration in `MainActivity` | move to `PairingCoordinator` and remove redundant methods | no shadow methods retained | Android unit/build + pair/unpair smoke |
| Inline route bodies in `server.mjs` | move to route/service modules and remove old blocks | no fallback route path kept | host integration tests |

## Decommission Checkpoints (Write-Back Clarification)

1. `ViewController.swift`: remove inline status parsing methods only after `HostBridgeClient` parity checks pass.
2. `MainActivity.kt`: remove in-activity pairing orchestration methods only after coordinator-driven pair/unpair tests pass.
3. `server.mjs`: remove inline route handlers only after route module registration and host integration tests pass.

## Data Models (If Needed)

- macOS: introduce typed `Codable` models mirroring `/api/status` and `/api/bootstrap/qr-token` responses.
- Host: define token service internal model with explicit expiry/used state and validated payload shape.

## Error Handling And Edge Cases

1. Host offline transitions should update UI state without crashing coordinators.
2. QR token expiry and single-use semantics remain unchanged.
3. Discovery returning multiple hosts remains explicit-selection flow.
4. Route handler failures continue using standardized JSON error response.

## Use-Case Coverage Matrix (Design Gate)

| use_case_id | Requirement | Use Case | Primary Path Covered (`Yes`/`No`) | Fallback Path Covered (`Yes`/`No`/`N/A`) | Error Path Covered (`Yes`/`No`/`N/A`) | Runtime Call Stack Section |
| --- | --- | --- | --- | --- | --- | --- |
| UC-001 | R-001 | macOS decomposition with behavior parity | Yes | Yes | Yes | `future-state-runtime-call-stack.md#use-case-uc-001` |
| UC-002 | R-002 | Android decomposition with behavior parity | Yes | Yes | Yes | `future-state-runtime-call-stack.md#use-case-uc-002` |
| UC-003 | R-003 | Host server decomposition with API parity | Yes | Yes | Yes | `future-state-runtime-call-stack.md#use-case-uc-003` |
| UC-004 | R-004 | Verification/release continuity | Yes | N/A | Yes | `future-state-runtime-call-stack.md#use-case-uc-004` |

## Performance / Security Considerations

1. No added network round-trips; extraction only reorganizes code.
2. Keep QR tokens ephemeral and single-use.
3. Ensure route split does not weaken validation/error handling.

## Migration / Rollout (If Needed)

1. Land per-platform slices behind existing behavior, no feature flags.
2. Run automated tests after each slice.
3. Tag-based release only after all slices green.

## Change Traceability To Implementation Plan

| Change ID | Implementation Plan Task(s) | Verification (Unit/Integration/E2E/Manual) | Status |
| --- | --- | --- | --- |
| C-001..C-004 | T-100 series | macOS build + parity smoke | Planned |
| C-005..C-008 | T-200 series | Android unit/build + manual pairing smoke | Planned |
| C-009..C-014 | T-300 series | host unit/integration tests | Planned |

## Design Feedback Loop Notes (From Review/Implementation)

| Date | Trigger (Review/File/Test/Blocker) | Classification (`Local Fix`/`Design Impact`/`Requirement Gap`) | Design Smell | Requirements Updated? | Design Update Applied | Status |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-02-20 | Initial design draft | N/A | N/A | No | v1 created | Open for review |

## Open Questions

1. Should Android refactor stop at coordinator extraction or continue to dedicated state container in same ticket?
2. Should macOS view builder extraction include style tokens now or defer to UI-specific follow-up ticket?
