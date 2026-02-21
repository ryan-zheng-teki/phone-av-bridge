# Proposed Design Document

## Design Version

- Current Version: `v1`

## Revision History

| Version | Trigger | Summary Of Changes | Related Review Round |
| --- | --- | --- | --- |
| v1 | Initial draft | Persistent host list in paired mode + explicit switch flow + host selection state extraction | 1 |

## Artifact Basis

- Investigation Notes: `tickets/done/host-list-persistent-switching-ux/investigation-notes.md`
- Requirements: `tickets/done/host-list-persistent-switching-ux/requirements.md`
- Requirements Status: `Design-ready`

## Summary

Expose a persistent host list on Android main screen for both unpaired and paired states, and enable deterministic host switching by selecting a different host and executing a switch action (`unpair current -> pair selected`). Separate host-selection state reconciliation logic from activity UI/event orchestration to improve file-level responsibility clarity.

## Goals

- Make host availability transparent at all times.
- Make switching hosts explicit and low-friction.
- Keep behavior deterministic with clear failure handling.
- Reduce host-selection logic density inside `MainActivity`.

## Legacy Removal Policy (Mandatory)

- Policy: `No backward compatibility; remove legacy code paths.`
- Required action: remove paired-mode behavior that hides host candidates and remove preview-only assumptions for host visibility.

## Requirements And Use Cases

| Requirement | Description | Acceptance Criteria | Use Case IDs |
| --- | --- | --- | --- |
| R-001 | Main screen shows host list before and after pairing | AC-1, AC-2 | UC-001, UC-002 |
| R-002 | Selected host drives pairing/switch action semantics | AC-3, AC-4, AC-9, AC-10 | UC-002, UC-003 |
| R-003 | Switch transaction is deterministic and user-visible on failure | AC-5, AC-6 | UC-003, UC-004 |
| R-004 | Discovery refresh keeps host visibility updated while paired | AC-8 | UC-005 |
| R-005 | QR flow remains intact | AC-7 | UC-004 |

## Codebase Understanding Snapshot (Pre-Design Mandatory)

| Area | Findings | Evidence (files/functions) | Open Unknowns |
| --- | --- | --- | --- |
| Entrypoints / Boundaries | Pair/unpair starts in activity click handlers; coordinator owns network calls | `MainActivity.kt:pairButton.setOnClickListener`, `PairingCoordinator.kt:pairHost/unpairHost` | none |
| Current Naming Conventions | Activity methods use `beginXxx`, `refreshXxx`, `resolveXxx`; coordinator methods are concise verbs | `MainActivity.kt`, `PairingCoordinator.kt` | none |
| Impacted Modules / Responsibilities | Host list selection logic currently mixed into `MainActivity` | `MainActivity.kt:updateHostCandidatesUi`, selection vars | whether additional class is enough without over-refactor |
| Data / Persistence / External IO | `AppPrefs` holds current host; UDP discovery and HTTP host APIs are existing boundaries | `AppPrefs.kt`, `HostDiscoveryClient.kt`, `HostApiClient.kt` | rollback semantics on switch failure (resolved as no rollback) |

## Current State (As-Is)

- Host list is primarily designed around unpaired flow visibility.
- Paired user experience focuses on current host summary; alternate hosts are not first-class in paired mode behavior.
- Pair button semantics are unpair-first while paired, not switch-first by selected alternate host.
- Selection/reconcile/action semantics are concentrated in activity state fields.

## Target State (To-Be)

- Host list is always visible (paired/unpaired) and continuously refreshed.
- Selected row controls primary action semantics:
  - unpaired + selected -> `Pair`
  - paired + selected current -> `Unpair`
  - paired + selected different host -> `Switch`
  - multi-host + no explicit selection -> selection-required state
- Switch action runs deterministic sequence (`unpair current`, then `pair selected`).
- Host selection reconciliation logic is isolated in a dedicated pairing state helper.

## Change Inventory (Delta)

| Change ID | Change Type (`Add`/`Modify`/`Rename/Move`/`Remove`) | Current Path | Target Path | Rationale | Impacted Areas | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| C-001 | Add | N/A | `android-phone-av-bridge/app/src/main/java/org/autobyteus/phoneavbridge/pairing/HostSelectionState.kt` | Extract host-selection reconcile/action decisions from activity | Android pairing UX | Pure state helper, no Android UI dependencies |
| C-002 | Modify | `android-phone-av-bridge/app/src/main/java/org/autobyteus/phoneavbridge/MainActivity.kt` | same | Keep host list visible while paired; switch flow; action labels and status text updates | Main UI orchestration | Replace preview-only refresh behavior with candidate refresh behavior |
| C-003 | Modify | `android-phone-av-bridge/app/src/main/java/org/autobyteus/phoneavbridge/pairing/PairingCoordinator.kt` | same | Add explicit switch helper for deterministic unpair->pair | Pairing orchestration | best-effort old-host unpair before target pair |
| C-004 | Modify | `android-phone-av-bridge/app/src/main/res/values/strings.xml` | same | Add concise action labels/messages for Pair/Switch/Unpair and selection-required status | UX copy | preserve QR strings |
| C-005 | Modify | `android-phone-av-bridge/app/src/main/res/layout/activity_main.xml` | same | Keep host list/hints in visible layout for paired and unpaired states | Main screen UI | no structural redesign beyond behavior support |

## Architecture Overview

`MainActivity` remains UI orchestration entrypoint. `HostSelectionState` becomes the single source of truth for selection reconciliation and action intent derivation. `PairingCoordinator` remains the boundary to host API/discovery, now with a switch helper for explicit switch behavior.

## File And Module Breakdown

| File/Module | Change Type | Concern / Responsibility | Public APIs | Inputs/Outputs | Dependencies |
| --- | --- | --- | --- | --- | --- |
| `pairing/HostSelectionState.kt` | Add | Reconcile discovered candidates, selected host, and current paired host into actionable state | `reconcile(...)` | in: candidates/current/selection; out: normalized selection + action kind | `model/DiscoveredHost.kt` |
| `MainActivity.kt` | Modify | Render UI, react to user input, orchestrate calls to pairing/state helpers | existing activity methods + new switch path | in: UI events/ticker events; out: host API actions/UI state | `PairingCoordinator`, `HostSelectionState`, `AppPrefs` |
| `PairingCoordinator.kt` | Modify | Network-level pairing operations including switch transaction helper | `switchHost(...)` | in: current host + target host + device identity; out: pair result/error | `HostApiClient`, `HostDiscoveryClient` |
| `strings.xml` | Modify | Human-readable action/status copy | resource keys | N/A | Android resources |
| `activity_main.xml` | Modify | Always-available host list section | view IDs | N/A | Android view system |

## Layer-Appropriate Separation Of Concerns Check

- UI/frontend scope: host selection decision logic is moved out of direct view event handlers into a dedicated pairing state helper.
- Non-UI scope: pairing transaction semantics (`switchHost`) are kept in coordinator, not activity.
- Integration/infrastructure scope: no changes to discovery transport/API boundaries.

## Naming Decisions (Natural And Implementation-Friendly)

| Item Type (`File`/`Module`/`API`) | Current Name | Proposed Name | Reason | Notes |
| --- | --- | --- | --- | --- |
| File | N/A | `HostSelectionState.kt` | Explicitly describes candidate-selection/action-state domain | no Android UI types inside |
| API | N/A | `PairingCoordinator.switchHost(...)` | Clear and intention-revealing switch entrypoint | deterministic sequence |
| API | existing ad-hoc selection vars in activity | `HostSelectionAction` enum values (`PAIR`, `SWITCH`, `UNPAIR`, `SELECT_REQUIRED`) | Removes implicit branch logic | used for button text and click behavior |

## Naming Drift Check (Mandatory)

| Item | Current Responsibility | Does Name Still Match? (`Yes`/`No`) | Corrective Action (`Rename`/`Split`/`Move`/`N/A`) | Mapped Change ID |
| --- | --- | --- | --- | --- |
| `MainActivity` host-selection branch logic | mixed UI + state reconciliation | No | Split | C-001 |
| `PairingCoordinator` pairing orchestration | pairing/unpair orchestration | Yes | N/A | C-003 |
| `HostDiscoveryClient` | discovery transport client | Yes | N/A | N/A |

## Dependency Flow And Cross-Reference Risk

| Module/File | Upstream Dependencies | Downstream Dependents | Cross-Reference Risk | Mitigation / Boundary Strategy |
| --- | --- | --- | --- | --- |
| `MainActivity.kt` | Android UI + coordinators + state helper | none | Medium | Keep selection policy in `HostSelectionState`; keep network orchestration in coordinator |
| `HostSelectionState.kt` | `DiscoveredHost` model only | `MainActivity` | Low | pure deterministic helper |
| `PairingCoordinator.kt` | `HostApiClient`, `HostDiscoveryClient` | `MainActivity` | Low | expose single-purpose switch API |

## Decommission / Cleanup Plan

| Item To Remove/Rename | Cleanup Actions | Legacy Removal Notes | Verification |
| --- | --- | --- | --- |
| Paired-mode host list hiding path | Remove paired-only host-candidate hide logic in activity update path | Do not retain alternate paired-only branch | UI dump/manual verification paired state shows host list |
| Preview-only discovery assumptions | Replace `refreshHostPreviewIfUnpaired` behavior with candidate refresh usable in paired mode | avoid dual preview+candidate branch | compile + runtime pairing checks |

## Data Models (If Needed)

- `HostSelectionSnapshot` (new):
  - `candidates: List<DiscoveredHost>`
  - `selectedBaseUrl: String?`
  - `explicitSelection: Boolean`
  - `action: HostSelectionAction`

## Error Handling And Edge Cases

- Switch target disappears before action:
  - `switchHost(...)` throws; UI shows switch failure; state remains consistent.
- Discovery cycles while paired:
  - preserve explicit selection if selected host still present.
  - clear explicit selection when selected host disappears and multiple candidates remain.
- Current host temporarily absent from discovery:
  - include current host via fallback discovery candidate logic so connected host remains visible.

## Use-Case Coverage Matrix (Design Gate)

| use_case_id | Requirement | Use Case | Primary Path Covered (`Yes`/`No`) | Fallback Path Covered (`Yes`/`No`/`N/A`) | Error Path Covered (`Yes`/`No`/`N/A`) | Runtime Call Stack Section |
| --- | --- | --- | --- | --- | --- | --- |
| UC-001 | R-001 | Unpaired persistent host list | Yes | Yes | Yes | UC-001 |
| UC-002 | R-001, R-002 | Paired persistent host list + action state | Yes | Yes | N/A | UC-002 |
| UC-003 | R-002, R-003 | Switch selected host while paired | Yes | Yes | Yes | UC-003 |
| UC-004 | R-003, R-005 | Switch/pair error handling + QR remains available | Yes | N/A | Yes | UC-004 |
| UC-005 | R-004 | Discovery refresh while paired | Yes | Yes | N/A | UC-005 |

## Performance / Security Considerations

- Discovery frequency remains existing ticker cadence; no additional network protocol introduced.
- No new sensitive data persisted beyond existing host base URL/pair code fields.

## Migration / Rollout (If Needed)

- No schema migration.
- Behavior rollout is immediate with app update.

## Change Traceability To Implementation Plan

| Change ID | Implementation Plan Task(s) | Verification (Unit/Integration/E2E/Manual) | Status |
| --- | --- | --- | --- |
| C-001 | T-001 | Unit-ish deterministic checks via activity behavior + compile | Planned |
| C-002 | T-002 | ADB UI flow tests + manual host switching | Planned |
| C-003 | T-003 | Integration-style switch flow using real host APIs | Planned |
| C-004 | T-004 | UI text verification via uiautomator dump | Planned |
| C-005 | T-005 | Layout render and behavior check on device | Planned |

## Design Feedback Loop Notes (From Review/Implementation)

| Date | Trigger (Review/File/Test/Blocker) | Classification (`Local Fix`/`Design Impact`/`Requirement Gap`) | Design Smell | Requirements Updated? | Design Update Applied | Status |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-02-21 | Initial design | N/A | N/A | No | v1 created | Open |

## Open Questions

- None blocking for implementation kickoff.
