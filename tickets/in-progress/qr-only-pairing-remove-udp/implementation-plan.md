# Implementation Plan

## Scope Classification

- Classification: `Medium`
- Reasoning: Cross-layer removal of discovery transport and UX/docs references.
- Workflow Depth: `Medium` -> proposed design -> call stack -> iterative review (`Go Confirmed`) -> implementation plan -> progress tracking.

## Upstream Artifacts (Required)

- Investigation notes: `tickets/in-progress/qr-only-pairing-remove-udp/investigation-notes.md`
- Requirements: `tickets/in-progress/qr-only-pairing-remove-udp/requirements.md`
  - Current Status: `Design-ready`
- Runtime call stacks: `tickets/in-progress/qr-only-pairing-remove-udp/future-state-runtime-call-stack.md`
- Runtime review: `tickets/in-progress/qr-only-pairing-remove-udp/future-state-runtime-call-stack-review.md`
- Proposed design: `tickets/in-progress/qr-only-pairing-remove-udp/proposed-design.md`

## Plan Maturity

- Current Status: `Ready For Implementation`
- Notes: Review gate is `Go Confirmed` with two clean rounds.

## Preconditions (Must Be True Before Finalizing This Plan)

- `requirements.md` is at least `Design-ready`: `Yes`
- Runtime call stack review artifact exists and is current: `Yes`
- All in-scope use cases reviewed: `Yes`
- No unresolved blocking findings: `Yes`
- Runtime review has `Go Confirmed`: `Yes`

## Runtime Call Stack Review Gate Summary (Required)

| Round | Review Result | Findings Requiring Write-Back | Write-Back Completed | Round State (`Reset`/`Candidate Go`/`Go Confirmed`) | Clean Streak After Round |
| --- | --- | --- | --- | --- | --- |
| 1 | Pass | No | N/A | Candidate Go | 1 |
| 2 | Pass | No | N/A | Go Confirmed | 2 |

## Go / No-Go Decision

- Decision: `Go`
- Evidence:
  - Final review round: `2`
  - Clean streak at final round: `2`
  - Final review gate line: `Implementation can start: Yes`

## Principles

- Bottom-up implementation sequence.
- Remove discovery legacy paths in same change set.
- Keep QR token path and pair/unpair APIs stable.

## Dependency And Sequencing Map

| Order | File/Module | Depends On | Why This Order |
| --- | --- | --- | --- |
| 1 | `desktop-av-bridge-host/desktop-app/server.mjs` | None | Remove core discovery runtime branch first |
| 2 | `desktop-av-bridge-host/tests/integration/*.mjs` + scripts | 1 | Align tests/startup args to new server contract |
| 3 | Android pairing/sync modules (`PairingCoordinator`, `HostStateRefresher`, `MainActivity`) | 1 | Remove discovery usage and keep QR-only flow |
| 4 | Android resources (`strings.xml`, `activity_main.xml`) | 3 | Keep UI behavior consistent with code |
| 5 | Docs + macOS copy (`README.md`, host README, `AGENTS.md`, `ViewController.swift`) | 1-4 | Final sync to implemented behavior |

## Requirement And Design Traceability

| Requirement | Design Section | Use Case / Call Stack | Planned Task ID(s) | Verification |
| --- | --- | --- | --- | --- |
| R-001 | C-001,C-002,C-005 | UC-001 | T-003,T-004 | Android build + manual flow check |
| R-002 | C-001,C-002 | UC-002 | T-003 | Android unpair/pair validation |
| R-003 | C-006,C-007,C-008 | UC-003 | T-001,T-002 | Host test suite |
| R-004 | C-009,C-010 | UC-004 | T-005,T-006 | Doc/copy grep + manual inspection |

## Design Delta Traceability (Required For `Medium/Large`)

| Change ID (from proposed design doc) | Change Type | Planned Task ID(s) | Includes Remove/Rename Work | Verification |
| --- | --- | --- | --- | --- |
| C-001 | Modify | T-003 | No | Android build/test |
| C-002 | Modify | T-003 | No | Android build/test |
| C-003 | Modify | T-003 | No | Android build/test |
| C-004 | Remove | T-003 | Yes | Source grep + compile |
| C-005 | Modify | T-004 | No | Android build/test |
| C-006 | Modify | T-001 | No | Host test suite |
| C-007 | Remove | T-002 | Yes | Host test suite |
| C-008 | Modify | T-002 | No | Host test suite |
| C-009 | Modify | T-006 | No | UI text inspection |
| C-010 | Modify | T-005 | No | Docs inspection |

## Decommission / Rename Execution Tasks

| Task ID | Item | Action (`Remove`/`Rename`/`Move`) | Cleanup Steps | Risk Notes |
| --- | --- | --- | --- | --- |
| T-DEL-001 | `HostDiscoveryClient.kt` | Remove | Delete file + remove imports + compile | Low |
| T-DEL-002 | UDP discovery runtime branch | Remove | Delete socket setup/teardown and env toggles | Low |
| T-DEL-003 | `discovery.test.mjs` | Remove | Delete obsolete test and run suite | Low |

## Step-By-Step Plan

1. Remove host UDP discovery runtime code and update host tests/scripts.
2. Remove Android discovery code paths and make pairing action QR-only.
3. Update Android strings/layout to match QR-only behavior.
4. Update macOS host app copy and docs/runbook.
5. Run verification (host tests, Android unit/build, plus any feasible E2E/manual checks).
6. Update implementation progress and docs sync log.

## Per-File Definition Of Done

| File | Implementation Done Criteria | Unit Test Criteria | Integration Test Criteria | E2E Criteria | Notes |
| --- | --- | --- | --- | --- | --- |
| `desktop-av-bridge-host/desktop-app/server.mjs` | no UDP discovery code remains | N/A | Host integration tests pass | manual host start OK | |
| `desktop-av-bridge-host/tests/integration/*` | no discovery expectations | test run pass | test run pass | N/A | |
| `android-phone-av-bridge/.../MainActivity.kt` | no discovery flow/state remains | compile + unit tests pass | N/A | manual QR pair/unpair (if feasible) | |
| `android-phone-av-bridge/.../PairingCoordinator.kt` | only QR + pair/unpair methods remain | compile pass | N/A | covered by app behavior | |
| `android-phone-av-bridge/.../HostStateRefresher.kt` | no discovery preview method | compile pass | N/A | N/A | |
| `android-phone-av-bridge/.../HostDiscoveryClient.kt` | removed | N/A | N/A | N/A | |
| docs/macOS copy files | wording updated | N/A | N/A | visual/manual check | |

## Test Strategy

- Unit tests: Android `testDebugUnitTest` and existing host unit/integration tests.
- Integration tests: host `npm test`.
- E2E feasibility: `Feasible` (if Android device is connected and host app can run locally).
- If real-device E2E becomes unavailable during this run, record constraint in progress tracker.

## Test Feedback Escalation Policy (Execution Guardrail)

- Follow standard classification: `Local Fix`, `Design Impact`, `Requirement Gap`.
- For cross-cutting or low-confidence failures, reopen investigation first.

## Cross-Reference Exception Protocol

| File | Cross-Reference With | Why Unavoidable | Temporary Strategy | Unblock Condition | Design Follow-Up Status | Owner |
| --- | --- | --- | --- | --- | --- | --- |
| N/A | N/A | N/A | N/A | N/A | `Not Needed` | Agent |

## Design Feedback Loop

| Smell/Issue | Evidence (Files/Call Stack) | Design Section To Update | Action | Status |
| --- | --- | --- | --- | --- |
| None yet | N/A | N/A | N/A | Pending |
