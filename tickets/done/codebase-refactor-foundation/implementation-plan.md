# Implementation Plan

## Scope Classification

- Classification: `Large`
- Reasoning:
  - Cross-platform architecture refactor (`macOS`, `Android`, `Host server`).
  - Multi-module boundary extraction and decommission work.
  - Requires phased verification to avoid behavioral regressions.
- Workflow Depth: `Large` -> proposed design -> future-state runtime call stacks -> iterative review to `Go Confirmed` -> implementation plan -> progress tracking.

## Upstream Artifacts (Required)

- Investigation notes: `tickets/in-progress/codebase-refactor-foundation/investigation-notes.md`
- Requirements: `tickets/in-progress/codebase-refactor-foundation/requirements.md`
  - Current Status: `Design-ready`
- Runtime call stacks: `tickets/in-progress/codebase-refactor-foundation/future-state-runtime-call-stack.md` (v2)
- Runtime review: `tickets/in-progress/codebase-refactor-foundation/future-state-runtime-call-stack-review.md` (`Go Confirmed`)
- Proposed design: `tickets/in-progress/codebase-refactor-foundation/proposed-design.md` (v2)

## Plan Maturity

- Current Status: `Ready For Implementation`
- Notes: review gate is satisfied with two consecutive clean rounds.

## Preconditions (Must Be True Before Finalizing This Plan)

- `requirements.md` is at least `Design-ready`: `Yes`
- Runtime call stack review artifact exists and is current: `Yes`
- All in-scope use cases reviewed: `Yes`
- No unresolved blocking findings: `Yes`
- Runtime review has `Go Confirmed` with two consecutive clean deep-review rounds: `Yes`

## Runtime Call Stack Review Gate Summary (Required)

| Round | Review Result | Findings Requiring Write-Back | Write-Back Completed | Round State (`Reset`/`Candidate Go`/`Go Confirmed`) | Clean Streak After Round |
| --- | --- | --- | --- | --- | --- |
| 1 | Fail | Yes | Yes | Reset | 0 |
| 2 | Pass | No | N/A | Candidate Go | 1 |
| 3 | Pass | No | N/A | Go Confirmed | 2 |
| 4 | Pass | No | N/A | Go Confirmed | 3 |
| 5 | Pass | No | N/A | Go Confirmed | 4 |

## Go / No-Go Decision

- Decision: `Go`
- Evidence:
  - Final review round: `5`
  - Clean streak at final round: `4`
  - Final review gate line: `Implementation can start: Yes`

## Principles

- Bottom-up module extraction before controller slimming.
- Keep endpoint/API contracts unchanged.
- No legacy/parallel compatibility paths.
- Verify after each slice with narrow test scope, then full regression set.

## Dependency And Sequencing Map

| Order | File/Module | Depends On | Why This Order |
| --- | --- | --- | --- |
| 1 | `desktop-av-bridge-host/desktop-app/services/qr-token-service.mjs` | existing `server.mjs` token logic | isolates pure logic first and enables route split safely |
| 2 | `desktop-av-bridge-host/desktop-app/routes/*.mjs` + `http-router.mjs` | token/session services | route split requires stable service interfaces |
| 3 | `desktop-av-bridge-host/desktop-app/server.mjs` (composition-only rewrite) | router/routes/services | decommission inline route logic after extracted modules pass tests |
| 4 | `macos-camera-extension/samplecamera/host/HostBridgeClient.swift` | existing host API contracts | typed client must exist before controller decomposition |
| 5 | `macos-camera-extension/samplecamera/pairing/QrTokenCoordinator.swift` | host client | isolate timer lifecycle before controller cleanup |
| 6 | `macos-camera-extension/samplecamera/ui/CameraMainViewBuilder.swift` | existing UI component list | avoid mixed concerns in controller |
| 7 | `macos-camera-extension/samplecamera/ViewController.swift` slim-down | extracted macOS modules | decommission monolith internals safely |
| 8 | `android-phone-av-bridge/.../pairing/PairingCoordinator.kt` | existing API/discovery/parser | pairing extraction is primary complexity reducer |
| 9 | `android-phone-av-bridge/.../sync/HostStateRefresher.kt` | host API snapshot shape | decouple status ticker and snapshot logic |
| 10 | `android-phone-av-bridge/.../publish/ResourcePublishCoordinator.kt` | resource service + host API | isolate retry/publish behavior |
| 11 | `android-phone-av-bridge/.../MainActivity.kt` slim-down | new Android coordinators | remove inline business logic last |
| 12 | docs updates + final regression pass | all prior tasks | ensure maintained architecture documentation |

## Requirement And Design Traceability

| Requirement | Design Section | Use Case / Call Stack | Planned Task ID(s) | Verification |
| --- | --- | --- | --- | --- |
| R-001 | Target State (macOS), C-001..C-004 | UC-001 | T-100..T-140 | macOS build + runtime smoke |
| R-002 | Target State (Android), C-005..C-008 | UC-002 | T-200..T-240 | Android tests/build + manual flow |
| R-003 | Target State (Host), C-009..C-014 | UC-003 | T-300..T-340 | host unit/integration tests |
| R-004 | Verification continuity | UC-004 | T-900 | full regression + release dry run/tag |

## Design Delta Traceability (Required For `Medium/Large`)

| Change ID (from proposed design doc) | Change Type | Planned Task ID(s) | Includes Remove/Rename Work | Verification |
| --- | --- | --- | --- | --- |
| C-001..C-004 | Add/Modify/Remove | T-100..T-140 | Yes | `xcodebuild` + host-status/QR smoke |
| C-005..C-008 | Add/Modify/Remove | T-200..T-240 | Yes | `./gradlew testDebugUnitTest assembleDebug` + manual pair flow |
| C-009..C-014 | Add/Modify/Remove | T-300..T-340 | Yes | `npm test` in host module |

## Decommission / Rename Execution Tasks

| Task ID | Item | Action (`Remove`/`Rename`/`Move`) | Cleanup Steps | Risk Notes |
| --- | --- | --- | --- | --- |
| T-141 | `ViewController` inline parsing/timer helpers | Remove/Move | delete methods after extraction wiring + build pass | medium |
| T-241 | `MainActivity` inline pairing refresh blocks | Remove/Move | delete redundant methods and simplify listeners | medium |
| T-341 | `server.mjs` inline endpoint blocks | Remove/Move | remove old route condition blocks after route tests pass | medium |

## Step-By-Step Plan

1. Implement host service/router extraction and keep endpoint behavior identical.
2. Run host tests and stabilize imports.
3. Extract macOS host client and QR coordinator.
4. Extract macOS view builder and slim controller.
5. Run macOS build and runtime smoke checks.
6. Extract Android pairing coordinator.
7. Extract Android host refresher and publish coordinator.
8. Slim `MainActivity` to lifecycle + rendering delegates.
9. Run Android tests/build and manual pair/unpair/QR flow checks.
10. Run full cross-module regression pass.
11. Sync architecture docs (`docs/`) or create if missing.
12. Prepare release verification and report.

## Per-File Definition Of Done

| File | Implementation Done Criteria | Unit Test Criteria | Integration Test Criteria | E2E Criteria | Notes |
| --- | --- | --- | --- | --- | --- |
| `desktop-av-bridge-host/desktop-app/server.mjs` | only bootstrap/composition remains | route/service unit tests pass | host integration suite pass | N/A | endpoint contracts unchanged |
| `macos-camera-extension/samplecamera/ViewController.swift` | orchestration only, no raw parsing/timer internals | N/A | build pass + manual smoke | manual only | UI/UX redesign out-of-scope |
| `android-phone-av-bridge/.../MainActivity.kt` | lifecycle + delegate wiring, reduced business logic | coordinator unit tests pass | app build pass | manual device flow | MIUI instrumentation constraints apply |

## Test Strategy

- Unit tests:
  - host services/routes where applicable,
  - Android coordinator/parser units.
- Integration tests:
  - host API endpoint suite,
  - Android build + behavior integration through API client boundaries.
- E2E feasibility: `Partially Feasible`
- If E2E is not fully feasible, concrete reason and current constraints:
  - connected instrumentation runner is constrained by MIUI activity permission policy in current device environment.
- Best-available non-E2E verification evidence when E2E is not feasible:
  - host integration tests + Android unit/build + macOS build + manual real-device pairing checks.
- Residual risk notes:
  - UI-only regressions need targeted manual verification on macOS and Android.

## Test Feedback Escalation Policy (Execution Guardrail)

- Use mandatory classification: `Local Fix`, `Design Impact`, `Requirement Gap`.
- For `Design Impact`, always update investigation notes first, then design/call stack/review loop.
- For `Requirement Gap`, refine requirements first, then design/call stack/review loop.

## Cross-Reference Exception Protocol

| File | Cross-Reference With | Why Unavoidable | Temporary Strategy | Unblock Condition | Design Follow-Up Status | Owner |
| --- | --- | --- | --- | --- | --- | --- |
| `MainActivity.kt` | new coordinators during migration slice | staged extraction cannot be atomic in one commit | keep thin bridging wrappers for one slice only | wrappers removed once all delegates wired | Needed | refactor ticket |
| `ViewController.swift` | view builder + coordinator callbacks | AppKit wiring migration is staged | temporary adapter struct for UI refs | remove adapter after builder contract stabilizes | Needed | refactor ticket |

## Design Feedback Loop

| Smell/Issue | Evidence (Files/Call Stack) | Design Section To Update | Action | Status |
| --- | --- | --- | --- | --- |
| migration wrapper drift risk | `MainActivity` and `ViewController` staged extraction | `Decommission Checkpoints` | enforce explicit removal tasks T-141/T-241 | Planned |
