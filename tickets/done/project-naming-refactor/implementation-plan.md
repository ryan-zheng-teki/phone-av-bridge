# Implementation Plan

## Scope Classification
- Classification: `Medium`
- Reasoning: cross-module rename with runtime identifier updates and docs synchronization.

## Upstream Artifacts (Required)
- Investigation notes: `tickets/in-progress/project-naming-refactor/investigation-notes.md`
- Requirements: `tickets/in-progress/project-naming-refactor/requirements.md`
  - Current Status: `Refined`
- Runtime call stacks: `tickets/in-progress/project-naming-refactor/future-state-runtime-call-stack.md`
- Runtime review: `tickets/in-progress/project-naming-refactor/future-state-runtime-call-stack-review.md`
- Proposed design: `tickets/in-progress/project-naming-refactor/proposed-design.md`

## Plan Maturity
- Current Status: `Ready For Implementation`
- Notes: runtime review reached `Go Confirmed` with two consecutive clean rounds.

## Preconditions (Must Be True Before Finalizing This Plan)
- `requirements.md` is at least `Design-ready`: Yes
- Runtime call stack review artifact exists and is current: Yes
- All in-scope use cases reviewed: Yes
- No unresolved blocking findings: Yes
- Runtime review has `Go Confirmed`: Yes

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
- Bottom-up and test-driven where practical.
- No backward-compatibility aliases in active runtime code.
- Execute path renames first, then update references, then verify.

## Dependency And Sequencing Map
| Order | File/Module | Depends On | Why This Order |
| --- | --- | --- | --- |
| 1 | Folder renames (`android-*`, `desktop-*`, `phone-av-camera-*`) | N/A | Establish target paths first. |
| 2 | Host runtime references/scripts/tests/docs | 1 | Most path dependencies fan out from host module. |
| 3 | Android identifiers and strings | 1 | Align discovery/service constants and app naming. |
| 4 | Root/module README sync | 2,3 | Finalized after technical references settle. |
| 5 | Verification commands + old-name scan | 2,3,4 | Validate refactor integrity and cleanup. |

## Requirement And Design Traceability
| Requirement | Design Section | Use Case / Call Stack | Planned Task ID(s) | Verification |
| --- | --- | --- | --- | --- |
| R-001 | Naming Decisions | UC-002 | T-003, T-004 | static copy checks |
| R-002 | Change Inventory C-001/C-002/C-003 | UC-001/UC-004 | T-001, T-002 | script/test command runs |
| R-003 | Change Inventory C-004 | UC-003 | T-003 | host+android integration tests |
| R-004 | Change Inventory C-007/C-008 | UC-001/UC-002 | T-004 | docs scan |

## Design Delta Traceability (Required For `Medium/Large`)
| Change ID (from proposed design doc) | Change Type | Planned Task ID(s) | Includes Remove/Rename Work | Verification |
| --- | --- | --- | --- | --- |
| C-001 | Rename/Move | T-001 | Yes | build/test path checks |
| C-002 | Rename/Move + Modify | T-001, T-002 | Yes | host tests |
| C-003 | Rename/Move | T-001, T-002 | Yes | adapter/path checks |
| C-004 | Modify | T-003 | No | discovery tests |
| C-005 | Modify | T-003 | No | static string checks |
| C-006 | Modify | T-002 | No | installer script sanity |
| C-007/C-008 | Modify/Remove | T-004 | Yes | `rg` cleanup scan |
| C-009 | Modify | T-005, T-006 | Yes | macOS build/install + preflight |

## Decommission / Rename Execution Tasks
| Task ID | Item | Action (`Remove`/`Rename`/`Move`) | Cleanup Steps | Risk Notes |
| --- | --- | --- | --- | --- |
| T-001 | Active module folders | Rename/Move | Move dirs and update direct path references | Broken paths if partial update |
| T-002 | Host runtime/scripts/tests | Modify | Replace old slugs, launcher names, default state/log paths | Installer assumptions |
| T-003 | Android discovery + UI naming | Modify | Replace constants/service filter/app labels | Pairing breaks if mismatch |
| T-004 | Root/module docs cleanup | Remove/Modify | Update commands/module names and remove old labels in active docs | Historical docs intentionally left |
| T-005 | macOS artifact rebrand | Modify | Rename camera/audio bundle IDs, app/driver names, and host preflight/default device identifiers | Requires extension re-approval |
| T-006 | Verification sweep | Modify | Run tests + old-name scans + progress updates | Environment-specific test limits |

## Step-By-Step Plan
1. Rename three active module directories.
2. Update host runtime code, package metadata, installers, docker/test configs, and bridge path references.
3. Update Android module metadata, discovery constants, service filters, and strings.
4. Synchronize root + module READMEs for new names.
5. Rebrand macOS camera/audio artifacts (`PhoneAVBridgeCamera*`, `PhoneAVBridgeAudio*`) and host preflight/install expectations.
6. Run host tests, Android unit tests, macOS camera build/install, and targeted scans for stale naming.

## Per-File Definition Of Done
| File | Implementation Done Criteria | Unit Test Criteria | Integration Test Criteria | E2E Criteria | Notes |
| --- | --- | --- | --- | --- | --- |
| host runtime + scripts | No stale active references, launch paths valid | `npm test` | discovery tests pass | real-device pairing/status validation | |
| Android discovery + strings | Canonical naming + matching identifiers | `./gradlew testDebugUnitTest` | host discovery interoperability check | N/A | |
| READMEs | Commands and naming consistent | N/A | N/A | N/A | docs sync gate |

## Test Strategy
- Unit tests: host `npm test`; Android `./gradlew testDebugUnitTest`.
- Integration tests: host discovery included in `npm test` suite.
- E2E feasibility: `Feasible`
- E2E validation scope:
  - Build Android APK and install to connected ADB device.
  - Build/install macOS camera host app (`PhoneAVBridgeCamera.app`) under user Applications.
  - Install/start `Phone AV Bridge Host` under user Applications.
  - Verify host status transitions (`paired` and resource toggles) with live API evidence.
- Residual risk notes:
  - Manual meeting-app selector validation is outside this command-line E2E sweep.

## Test Feedback Escalation Policy (Execution Guardrail)
- Standard policy from workflow applies. For this ticket, most failures are expected to classify as `Local Fix` unless runtime contract drift is found.
