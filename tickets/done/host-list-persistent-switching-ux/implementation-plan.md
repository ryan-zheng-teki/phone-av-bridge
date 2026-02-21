# Implementation Plan

## Scope Classification

- Classification: `Medium`
- Reasoning: persistent host-list behavior changes in paired/unpaired states plus switch transaction and file-responsibility refinement.
- Workflow Depth:
  - `Medium` -> proposed design doc -> future-state runtime call stack -> future-state runtime call stack review (iterative deep rounds until `Go Confirmed`) -> implementation plan -> progress tracking

## Upstream Artifacts (Required)

- Investigation notes: `tickets/done/host-list-persistent-switching-ux/investigation-notes.md`
- Requirements: `tickets/done/host-list-persistent-switching-ux/requirements.md`
  - Current Status: `Design-ready`
- Runtime call stacks: `tickets/done/host-list-persistent-switching-ux/future-state-runtime-call-stack.md`
- Runtime review: `tickets/done/host-list-persistent-switching-ux/future-state-runtime-call-stack-review.md`
- Proposed design (required for `Medium/Large`): `tickets/done/host-list-persistent-switching-ux/proposed-design.md`

## Plan Maturity

- Current Status: `Ready For Implementation`
- Notes: Review gate passed with `Go Confirmed` after two clean deep-review rounds.

## Preconditions (Must Be True Before Finalizing This Plan)

- `requirements.md` is at least `Design-ready` (`Refined` allowed): Yes
- Runtime call stack review artifact exists and is current: Yes
- All in-scope use cases reviewed: Yes
- No unresolved blocking findings: Yes
- Runtime review has `Go Confirmed` with two consecutive clean deep-review rounds: Yes

## Runtime Call Stack Review Gate Summary (Required)

| Round | Review Result | Findings Requiring Write-Back | Write-Back Completed | Round State (`Reset`/`Candidate Go`/`Go Confirmed`) | Clean Streak After Round |
| --- | --- | --- | --- | --- | --- |
| 1 | Pass | No | N/A | Candidate Go | 1 |
| 2 | Pass | No | N/A | Go Confirmed | 2 |

## Go / No-Go Decision

- Decision: `Go`
- Evidence:
  - Final review round: 2
  - Clean streak at final round: 2
  - Final review gate line (`Implementation can start`): Yes

## Principles

- Bottom-up: implement dependencies before dependents.
- Test-driven: run build/tests after each meaningful phase.
- Mandatory modernization rule: no backward-compatibility shims or legacy branches.
- One file at a time is the default.
- Update progress after each meaningful status change.

## Dependency And Sequencing Map

| Order | File/Module | Depends On | Why This Order |
| --- | --- | --- | --- |
| 1 | `android-phone-av-bridge/app/src/main/java/org/autobyteus/phoneavbridge/pairing/HostSelectionState.kt` | none | Foundation for selection/action semantics |
| 2 | `android-phone-av-bridge/app/src/main/java/org/autobyteus/phoneavbridge/pairing/PairingCoordinator.kt` | none | Add switch helper used by activity |
| 3 | `android-phone-av-bridge/app/src/main/java/org/autobyteus/phoneavbridge/MainActivity.kt` | 1,2 | Wire UI rendering and action flow to new semantics |
| 4 | `android-phone-av-bridge/app/src/main/res/values/strings.xml` | 3 | Align labels/status with action semantics |
| 5 | `android-phone-av-bridge/app/src/main/res/layout/activity_main.xml` | 3 | Ensure host list remains visible in paired state |

## Requirement And Design Traceability

| Requirement | Design Section | Use Case / Call Stack | Planned Task ID(s) | Verification |
| --- | --- | --- | --- | --- |
| R-001 | Target State; C-002,C-005 | UC-001,UC-002 | T-002,T-005 | ADB UI verification |
| R-002 | Target State; C-001,C-002,C-003 | UC-002,UC-003 | T-001,T-002,T-003 | Build + runtime behavior checks |
| R-003 | Error Handling; C-003 | UC-003,UC-004 | T-003 | Manual switch failure path check |
| R-004 | Target State; C-002 | UC-005 | T-002 | Ticker-driven refresh observation |
| R-005 | Change Inventory C-004 | UC-004 | T-004 | UI text/flow checks |

## Design Delta Traceability (Required For `Medium/Large`)

| Change ID (from proposed design doc) | Change Type | Planned Task ID(s) | Includes Remove/Rename Work | Verification |
| --- | --- | --- | --- | --- |
| C-001 | Add | T-001 | No | Build + behavior checks |
| C-002 | Modify | T-002 | Yes | ADB paired/unpaired host list checks |
| C-003 | Modify | T-003 | No | Switch transaction check |
| C-004 | Modify | T-004 | No | UI string/state check |
| C-005 | Modify | T-005 | No | Layout visibility check |

## Decommission / Rename Execution Tasks

| Task ID | Item | Action (`Remove`/`Rename`/`Move`) | Cleanup Steps | Risk Notes |
| --- | --- | --- | --- | --- |
| T-002 | Paired-mode hidden host-list branch | Remove | eliminate paired-only hide logic and preview-only dependency | low |

## Step-By-Step Plan

1. Add `HostSelectionState` helper and action enum/snapshot.
2. Add `switchHost` API in `PairingCoordinator`.
3. Refactor `MainActivity` host candidate refresh + always-visible list + action semantics (`Pair/Switch/Unpair`).
4. Update strings/layout for action labels and selection-required copy.
5. Build, install, and run Android real-device flows:
   - unpaired list visibility,
   - paired list persistence,
   - switch host from selected row,
   - failure-safe behavior check.

## Per-File Definition Of Done

| File | Implementation Done Criteria | Unit Test Criteria | Integration Test Criteria | E2E Criteria | Notes |
| --- | --- | --- | --- | --- | --- |
| `.../pairing/HostSelectionState.kt` | Reconcile + action semantics implemented | compile + deterministic behavior via call sites | covered by activity integration behavior | N/A | pure helper |
| `.../pairing/PairingCoordinator.kt` | switch helper implemented with best-effort old unpair | compile | switch behavior exercised from activity flow | device switch flow passes | |
| `.../MainActivity.kt` | paired/unpaired/switch flow aligned with requirements | compile | integration behavior across discovery/pair/switch | real device verification | |
| `.../strings.xml` | labels/messages match semantics | N/A | UI text checks | included in device verification | |
| `.../activity_main.xml` | host list visible in paired and unpaired states | N/A | UI rendering behavior | included in device verification | |

## Test Strategy

- Unit tests: run existing `testDebugUnitTest` if present and keep compile strictness.
- Integration tests: exercise discovery + pair/switch behavior through app + host services.
- E2E feasibility: `Feasible`
- If E2E is not feasible, concrete reason and current constraints: N/A
- Best-available non-E2E verification evidence when E2E is not feasible: N/A
- Residual risk notes: UI edge cases under very unstable networks may require follow-up.

## Test Feedback Escalation Policy (Execution Guardrail)

- Use workflow default policy from skill; classify failures as `Local Fix`/`Design Impact`/`Requirement Gap` with mandatory investigation checkpoint when required.

## Cross-Reference Exception Protocol

| File | Cross-Reference With | Why Unavoidable | Temporary Strategy | Unblock Condition | Design Follow-Up Status | Owner |
| --- | --- | --- | --- | --- | --- | --- |
| N/A | N/A | N/A | N/A | N/A | `Not Needed` | N/A |

## Design Feedback Loop

| Smell/Issue | Evidence (Files/Call Stack) | Design Section To Update | Action | Status |
| --- | --- | --- | --- | --- |
| None at planning time | N/A | N/A | N/A | Pending |
