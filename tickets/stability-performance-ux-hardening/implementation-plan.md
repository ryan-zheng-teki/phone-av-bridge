# Implementation Plan

## Scope Classification
- Classification: `Medium`
- Reasoning: Cross-layer changes (Android UI + Android streaming + host control + macOS audio adapter + docs) without full architecture rewrite.
- Workflow Depth: `Medium`

## Upstream Artifacts (Required)
- Investigation notes: `tickets/stability-performance-ux-hardening/investigation-notes.md`
- Requirements: `tickets/stability-performance-ux-hardening/requirements.md` (`Design-ready`)
- Runtime call stacks: `tickets/stability-performance-ux-hardening/proposed-design-based-runtime-call-stack.md`
- Runtime review: `tickets/stability-performance-ux-hardening/runtime-call-stack-review.md`
- Proposed design: `tickets/stability-performance-ux-hardening/proposed-design.md`

## Plan Maturity
- Current Status: `Ready For Implementation`

## Preconditions
- requirements.md is at least Design-ready: `Yes`
- Runtime call stack review artifact exists and is current: `Yes`
- All in-scope use cases reviewed: `Yes`
- No unresolved blocking findings: `Yes`
- Runtime review has Go Confirmed with two consecutive clean rounds: `Yes`

## Runtime Call Stack Review Gate Summary
| Round | Review Result | Findings Requiring Write-Back | Write-Back Completed | Round State | Clean Streak After Round |
| --- | --- | --- | --- | --- | --- |
| 1 | Pass | No | N/A | Candidate Go | 1 |
| 2 | Pass | No | N/A | Go Confirmed | 2 |

## Go / No-Go Decision
- Decision: `Go`
- Evidence:
  - Final review round: `2`
  - Clean streak at final round: `2`
  - Final review gate line: `Implementation can start: Yes`

## Dependency And Sequencing Map
| Order | File/Module | Depends On | Why This Order |
| --- | --- | --- | --- |
| 1 | `session-controller.mjs` | none | establish normalized issue contract first |
| 2 | `audio-runner.mjs` | none | stabilize speaker capture source/format |
| 3 | `HostApiClient.kt` | none | provide status endpoint support to Android |
| 4 | `PhoneRtspStreamer.kt` | none | explicit quality profile |
| 5 | `HostSpeakerStreamPlayer.kt` | none | playback robustness |
| 6 | `strings.xml` + `activity_main.xml` | none | UX copy/layout basis |
| 7 | `MainActivity.kt` | 3,4,6 | integrate status model + pairing handling |
| 8 | `README.md` | all above | docs reflect behavior |

## Requirement And Design Traceability
| Requirement | Design Section | Use Case / Call Stack | Planned Task ID(s) | Verification |
| --- | --- | --- | --- | --- |
| R-001 | Target State, C-001 | UC-PAIR-01 | T1,T6 | Android build + live API check |
| R-002 | Target State, C-002,C-003 | UC-STATUS-01 | T5,T6 | Android build + UI validation |
| R-003 | Target State, C-004 | UC-CAMERA-01, UC-MIC-01 | T3 | Android build + host status |
| R-004 | Target State, C-005,C-007 | UC-SPEAKER-01 | T2,T4 | host tests + live speaker test |
| R-005 | Target State, C-006 | UC-HOST-ISSUE-01 | T1 | host tests |
| R-006 | C-008 | UC-INSTALL-01 | T7 | docs review |

## Design Delta Traceability
| Change ID | Change Type | Planned Task ID(s) | Includes Remove/Rename Work | Verification |
| --- | --- | --- | --- | --- |
| C-001 | Modify | T6 | Yes | Android build |
| C-002 | Modify | T5 | No | Android build |
| C-003 | Modify | T5 | No | Android build |
| C-004 | Modify | T3 | No | Android build |
| C-005 | Modify | T4 | No | Android build + manual |
| C-006 | Modify | T1 | Yes | node tests |
| C-007 | Modify | T2 | No | node tests + manual |
| C-008 | Modify | T7 | No | doc sync review |

## Step-By-Step Plan
1. T1: Implement host issue normalization in `session-controller.mjs`.
2. T2: Improve macOS speaker capture normalization in `audio-runner.mjs`.
3. T3: Add explicit RTSP quality profile in `PhoneRtspStreamer.kt`.
4. T4: Harden Android speaker player streaming behavior.
5. T5: Redesign Android layout and copy for clear workflow messaging.
6. T6: Integrate new pairing/status/degraded-state handling in `MainActivity.kt` + `HostApiClient.kt`.
7. T7: Update host docs for revised behavior and user guidance.
8. T8: Run tests/build/verification and finalize progress + docs sync log.

## Per-File Definition Of Done
| File | Implementation Done Criteria | Unit Test Criteria | Integration Test Criteria | E2E Criteria | Notes |
| --- | --- | --- | --- | --- | --- |
| `core/session-controller.mjs` | normalized issue mapping active | existing unit tests pass | integration server tests pass | host status payload inspected | |
| `adapters/macos-firstparty-audio/audio-runner.mjs` | speaker capture args hardened | unit tests unaffected/pass | integration tests pass | manual speaker stream sanity | |
| `HostApiClient.kt` | fetchStatus API available | N/A | N/A | consumed by activity | |
| `PhoneRtspStreamer.kt` | explicit profile compile-pass | N/A | N/A | verified via host status stream behavior | |
| `HostSpeakerStreamPlayer.kt` | robust playback loop | N/A | N/A | manual speaker playback sanity | |
| `activity_main.xml`,`strings.xml`,`MainActivity.kt` | guided UX + categorized status | N/A | N/A | manual device sanity | |
| `README.md` | docs reflect new behavior | N/A | N/A | doc review | |

## Test Strategy
- Unit tests: `host-resource-agent/tests/unit/*.test.mjs`
- Integration tests: `host-resource-agent/tests/integration/*.test.mjs`
- Android compile verification: `./gradlew :app:assembleDebug`
- E2E feasibility: `Partially Feasible`
- E2E constraint: full Zoom/Meet automation is not available in this environment.
- Best-available non-E2E evidence: host API/status checks, adapter tests, Android build, and connected-device behavior checks.
- Residual risk: app-specific media-device refresh behavior in third-party meeting apps.
