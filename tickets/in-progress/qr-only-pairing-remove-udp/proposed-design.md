# Proposed Design Document

## Design Version

- Current Version: `v1`

## Revision History

| Version | Trigger | Summary Of Changes | Related Review Round |
| --- | --- | --- | --- |
| v1 | Initial draft | Define QR-only pairing architecture and remove UDP discovery stack | 1 |

## Artifact Basis

- Investigation Notes: `tickets/in-progress/qr-only-pairing-remove-udp/investigation-notes.md`
- Requirements: `tickets/in-progress/qr-only-pairing-remove-udp/requirements.md`
- Requirements Status: `Design-ready`

## Summary

Replace dual-path pairing (UDP discovery + QR) with a single explicit QR pairing path. Remove UDP discovery runtime from host and discovery-client logic from Android. Keep QR token endpoints and pair/unpair APIs unchanged.

## Goals

- Deterministic host selection and pairing via QR only.
- Simpler Android pairing UX and reduced network ambiguity.
- Clean code removal of discovery transport and legacy copy/tests.

## Legacy Removal Policy (Mandatory)

- Policy: `No backward compatibility; remove legacy code paths.`
- Required action: remove discovery socket logic, discovery client code, and discovery-specific UI/messages/tests in this ticket.

## Requirements And Use Cases

| Requirement | Description | Acceptance Criteria | Use Case IDs |
| --- | --- | --- | --- |
| R-001 | Android pairing entry is QR-only | No discovery flow invoked from Android UI | UC-001 |
| R-002 | Android unpair/re-pair remains stable | Unpair works and next pair requires QR scan | UC-002 |
| R-003 | Host runtime no longer runs UDP discovery | `server.mjs` has no UDP discovery socket path | UC-003 |
| R-004 | Product copy/docs reflect QR-only pairing | No discovery language in updated in-scope docs/UI copy | UC-004 |

## Codebase Understanding Snapshot (Pre-Design Mandatory)

| Area | Findings | Evidence (files/functions) | Open Unknowns |
| --- | --- | --- | --- |
| Entrypoints / Boundaries | Android pairing currently starts in `MainActivity.beginPairSelectionFlow`; host discovery transport starts in `startServer` UDP socket branch | `MainActivity.kt`, `PairingCoordinator.kt`, `server.mjs` | None |
| Current Naming Conventions | `*Coordinator`, `*Refresher`, `*Client` naming in Android; route/service naming in host | `PairingCoordinator.kt`, `HostStateRefresher.kt`, `HostApiClient.kt`, `desktop-app/routes/*` | None |
| Impacted Modules / Responsibilities | Discovery concerns are mixed into pairing coordinator, state refresher, and UI status strings | `MainActivity.kt`, `HostStateRefresher.kt`, `strings.xml` | None |
| Data / Persistence / External IO | Pairing identity persists via `AppPrefs` (Android) and host state file (`~/.phone-av-bridge-host/state.json`) | `AppPrefs`, `server.mjs` persisted state functions | None |

## Current State (As-Is)

- Android offers `Pair Host` (UDP discovery) and `Scan QR Pairing`.
- Host server optionally enables UDP responder (`ENABLE_DISCOVERY`, `DISCOVERY_PORT`).
- Docs and macOS UI mention discovery/UDP.

## Target State (To-Be)

- Android unpaired flow has one pair action: QR scan and token redeem.
- Host server only exposes HTTP APIs for bootstrap/QR/pair/status/toggles; no UDP discovery socket.
- Copy/docs consistently describe QR-only pairing.

## Change Inventory (Delta)

| Change ID | Change Type (`Add`/`Modify`/`Rename/Move`/`Remove`) | Current Path | Target Path | Rationale | Impacted Areas | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| C-001 | Modify | `android-phone-av-bridge/.../MainActivity.kt` | same | Remove discovery-driven flow/state; keep QR-only pair/unpair flow | Android UI + pairing state | Simplify controls and status text usage |
| C-002 | Modify | `android-phone-av-bridge/.../pairing/PairingCoordinator.kt` | same | Remove `HostDiscoveryClient` dependency and discovery methods | Android pairing layer | Keep QR parse/redeem + pair/unpair |
| C-003 | Modify | `android-phone-av-bridge/.../sync/HostStateRefresher.kt` | same | Remove discovery preview method/dependency | Android sync layer | Keep paired status ticker behavior |
| C-004 | Remove | `android-phone-av-bridge/.../network/HostDiscoveryClient.kt` | removed | Remove obsolete UDP discovery client | Android network layer | Delete file and references |
| C-005 | Modify | `android-phone-av-bridge/.../res/layout/activity_main.xml` + `.../values/strings.xml` | same | Remove discovery-oriented UI/copy and keep QR-centric pair messaging | Android UX text/layout | Pair button becomes QR entry action |
| C-006 | Modify | `desktop-av-bridge-host/desktop-app/server.mjs` | same | Remove UDP socket, magic payload constant, and discovery env options | Host runtime startup/shutdown | Keep HTTP QR bootstrap endpoints |
| C-007 | Remove | `desktop-av-bridge-host/tests/integration/discovery.test.mjs` | removed | Remove obsolete protocol test | Host integration tests | No replacement needed for removed feature |
| C-008 | Modify | `desktop-av-bridge-host/tests/integration/server.test.mjs` and E2E scripts | same | Remove `enableDiscovery` toggles from startup calls/env | Host tests/scripts | Keep behavior equivalent |
| C-009 | Modify | `macos-camera-extension/samplecamera/ViewController.swift` | same | Replace discovery wording with QR pairing wording | macOS UI copy | No behavior change |
| C-010 | Modify | `README.md`, `desktop-av-bridge-host/README.md`, `AGENTS.md` | same | Document QR-only pairing flow and remove discovery references | Docs/runbook | Align operator instructions |

## Architecture Overview

- Pairing transport becomes strictly HTTP-based with QR token redemption.
- Android does not actively discover hosts; host selection is encoded in QR payload.
- Host startup no longer owns UDP side channel.

## File And Module Breakdown

| File/Module | Change Type | Concern / Responsibility | Public APIs | Inputs/Outputs | Dependencies |
| --- | --- | --- | --- | --- | --- |
| `MainActivity.kt` | Modify | UI state orchestration for pair/unpair + toggles | Activity callbacks | User actions, AppPrefs, Host API responses | `PairingCoordinator`, `HostStateRefresher` |
| `PairingCoordinator.kt` | Modify | QR parse/redeem and pair/unpair orchestration | `parseQrPayload`, `redeemQrPayload`, `pairHost`, `unpairHost` | QR payload, host responses | `HostApiClient` |
| `HostStateRefresher.kt` | Modify | Paired host status refresh ticker logic | `refreshPairedHost`, `startTicker` | host URL + desired states -> snapshot | `HostApiClient` |
| `HostDiscoveryClient.kt` | Remove | UDP discovery client | N/A | N/A | N/A |
| `server.mjs` | Modify | Host app startup, HTTP wiring, persistence | `startServer`, `createApp` | env + http requests | Node `http`, controller/routes/services |
| `discovery.test.mjs` | Remove | UDP integration test | N/A | N/A | N/A |

## Layer-Appropriate Separation Of Concerns Check

- UI/frontend scope: Android pairing action remains in `MainActivity`; transport details stay in coordinator/client.
- Non-UI scope: host runtime keeps single transport layer (HTTP), reducing mixed concern complexity.
- Integration/infrastructure scope: QR token service remains single pairing bootstrap mechanism.

## Naming Decisions (Natural And Implementation-Friendly)

| Item Type (`File`/`Module`/`API`) | Current Name | Proposed Name | Reason | Notes |
| --- | --- | --- | --- | --- |
| API behavior | `Pair Host` (discovery expectation) | `Pair via QR` semantics | Align button behavior with actual action | String-level behavior alignment |
| Module | `HostDiscoveryClient` | removed | No remaining discovery concern | Full decommission |

## Naming Drift Check (Mandatory)

| Item | Current Responsibility | Does Name Still Match? (`Yes`/`No`) | Corrective Action (`Rename`/`Split`/`Move`/`N/A`) | Mapped Change ID |
| --- | --- | --- | --- | --- |
| `PairingCoordinator` | Pairing orchestration including discovery fallback | No | Split by deleting discovery concerns, keep pairing-only methods | C-002 |
| `HostStateRefresher` | Paired host refresh plus discovery preview | No | Remove discovery-preview concern | C-003 |

## Dependency Flow And Cross-Reference Risk

| Module/File | Upstream Dependencies | Downstream Dependents | Cross-Reference Risk | Mitigation / Boundary Strategy |
| --- | --- | --- | --- | --- |
| `MainActivity.kt` | Android UI lifecycle + coordinators | User interaction flow | Medium | Keep QR scan invocation and pairing calls explicit; remove discovery state fields |
| `PairingCoordinator.kt` | `HostApiClient` | `MainActivity` | Low | Eliminate discovery client dependency |
| `server.mjs` | Node runtime + controllers/routes | all host entry flow | Low | Remove discovery branch cleanly with no fallback |

## Decommission / Cleanup Plan

| Item To Remove/Rename | Cleanup Actions | Legacy Removal Notes | Verification |
| --- | --- | --- | --- |
| Android UDP discovery client | Delete file, remove imports/calls, remove discovery-related strings | No compatibility branch retained | `rg -n "HostDiscoveryClient|discover" android-phone-av-bridge/...` scoped checks |
| Host UDP discovery runtime | Remove `dgram` import/constants/env options/socket lifecycle | No feature flag for legacy discovery kept | Host unit/integration tests + `rg -n "ENABLE_DISCOVERY|DISCOVERY_PORT|DISCOVERY_MAGIC|dgram"` |
| Discovery docs text | Update runbooks/README sections | Avoid mixed guidance | Manual doc grep for discovery pairing wording |

## Error Handling And Edge Cases

- Invalid QR payload -> existing `scan_qr_invalid` handling remains.
- Expired/used QR token -> existing `pair_failed_qr_token` mapping remains.
- Host unreachable -> existing unreachable error messaging remains.
- Unpair while host unreachable -> retain local robust unpair semantics.

## Use-Case Coverage Matrix (Design Gate)

| use_case_id | Requirement | Use Case | Primary Path Covered (`Yes`/`No`) | Fallback Path Covered (`Yes`/`No`/`N/A`) | Error Path Covered (`Yes`/`No`/`N/A`) | Runtime Call Stack Section |
| --- | --- | --- | --- | --- | --- | --- |
| UC-001 | R-001 | Pair via QR scan and redeem | Yes | N/A | Yes | UC-001 |
| UC-002 | R-002 | Unpair and re-pair via regenerated QR | Yes | N/A | Yes | UC-002 |
| UC-003 | R-003 | Host startup without UDP discovery | Yes | N/A | Yes | UC-003 |
| UC-004 | R-004 | Docs/UI copy aligned to QR-only | Yes | N/A | N/A | UC-004 |

## Performance / Security Considerations

- Removing UDP listener reduces exposed local-network surface area.
- Pairing remains token-based with expiry and single-use semantics.

## Migration / Rollout

- Single-shot cleanup in one release.
- Users pair using existing QR flow already present in host/macOS UI.

## Change Traceability To Implementation Plan

| Change ID | Implementation Plan Task(s) | Verification (Unit/Integration/E2E/Manual) | Status |
| --- | --- | --- | --- |
| C-001..C-010 | T-001..T-006 | Android build/tests, host tests, manual pairing check, docs grep | Planned |

## Design Feedback Loop Notes (From Review/Implementation)

| Date | Trigger (Review/File/Test/Blocker) | Classification (`Local Fix`/`Design Impact`/`Requirement Gap`) | Design Smell | Requirements Updated? | Design Update Applied | Status |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-02-20 | Initial design | N/A | None | No | v1 baseline | Open |

## Open Questions

- None.
