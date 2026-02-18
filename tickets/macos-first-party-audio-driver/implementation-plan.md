# Implementation Plan

## Scope Classification
- Classification: `Large`
- Reasoning:
  - New macOS virtual audio driver plugin + installer changes + runtime adapter replacement.
  - Real-time audio path correctness and failure recovery requirements.
  - Legacy path removal (BlackHole runtime/install/preflight/docs) in same ticket.
- Workflow Depth:
  - `Large` -> proposed design -> runtime call stack -> runtime review (`Go Confirmed`) -> implementation plan -> progress tracking.

## Upstream Artifacts (Required)
- Investigation notes: `tickets/macos-first-party-audio-driver/deep-investigation.md`
- Requirements: `tickets/macos-first-party-audio-driver/requirements.md`
  - Current Status: `Design-ready`
- Runtime call stacks: `tickets/macos-first-party-audio-driver/proposed-design-based-runtime-call-stack.md`
- Runtime review: `tickets/macos-first-party-audio-driver/runtime-call-stack-review.md`
- Proposed design: `tickets/macos-first-party-audio-driver/proposed-design.md`

## Plan Maturity
- Current Status: `Ready For Implementation`
- Notes: Review gate achieved `Go Confirmed` with two consecutive clean rounds.

## Preconditions (Must Be True Before Finalizing This Plan)
- `requirements.md` is at least `Design-ready` (`Refined` allowed): `Yes`
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

## Go / No-Go Decision
- Decision: `Go`
- Evidence:
  - Final review round: `Round 3`
  - Clean streak at final round: `2`
  - Final review gate line (`Implementation can start`): `Yes`

## Principles
- Bottom-up: implement driver contract and installer primitives before host adapter cutover.
- Test-driven: unit/integration coverage for IPC protocol and route lifecycle.
- Mandatory modernization rule: no backward-compatibility shims or legacy branches.
- Update progress after each meaningful status change.

## Dependency And Sequencing Map
| Order | File/Module | Depends On | Why This Order |
| --- | --- | --- | --- |
| 1 | `host-resource-agent/macos-audio-driver/src/*` | none | Core driver contract first. |
| 2 | `host-resource-agent/macos-audio-driver/scripts/install-driver.sh` | 1 | Deployment path needed before host integration tests. |
| 3 | `host-resource-agent/adapters/macos-firstparty-audio/audio-runner.mjs` | 1,2 | Adapter depends on stable IPC contract and install path. |
| 4 | `host-resource-agent/core/preflight-service.mjs` | 3 | Readiness checks depend on new adapter/driver probes. |
| 5 | `host-resource-agent/core/session-controller.mjs` | 3 | Lifecycle orchestration depends on new adapter APIs. |
| 6 | `host-resource-agent/installers/macos/install.command` | 2,4 | Installer must package driver and updated health flow. |
| 7 | Remove legacy macOS BlackHole path files | 3,4,5,6 | Remove only after first-party path validated. |
| 8 | `host-resource-agent/tests/macos-audio-driver/*` and docs | 3..7 | Final verification and user-facing updates. |

## Requirement And Design Traceability
| Requirement | Design Section | Use Case / Call Stack | Planned Task ID(s) | Verification |
| --- | --- | --- | --- | --- |
| AC-001 | Change Inventory C-006/C-007/C-008 | UC-001/UC-004 | T-006, T-007, T-008 | Unit + integration + source scan |
| AC-002 | File breakdown `PRCAudioDevice` + adapter | UC-002 | T-001, T-004 | integration + manual Zoom/OBS |
| AC-003 | File breakdown `PRCAudioDevice` + adapter | UC-003 | T-001, T-004 | integration + speaker loop |
| AC-004 | Error handling section | UC-004/UC-006 | T-004, T-005 | lifecycle stress tests |
| AC-005 | Migration/rollout | UC-001..UC-006 | T-009 | real-device end-to-end checklist |
| AC-006 | Error handling + preflight | UC-001/UC-006 | T-006, T-009 | health probe + fault injection |

## Design Delta Traceability (Required For `Medium/Large`)
| Change ID (from proposed design doc) | Change Type | Planned Task ID(s) | Includes Remove/Rename Work | Verification |
| --- | --- | --- | --- | --- |
| C-001 | Add | T-001 | No | driver visibility test |
| C-002 | Add | T-001, T-002 | No | unit + stress tests |
| C-003 | Add | T-003 | No | installer smoke |
| C-004 | Add | T-004 | No | adapter integration |
| C-005 | Modify | T-005 | No | session-controller tests |
| C-006 | Modify | T-006 | No | preflight tests |
| C-007 | Modify | T-007 | No | installer validation |
| C-008 | Remove | T-008 | Yes | source scan + runtime smoke |
| C-009 | Modify | T-010 | No | docs review |
| C-010 | Add | T-009 | No | test suite execution |

## Decommission / Rename Execution Tasks
| Task ID | Item | Action (`Remove`/`Rename`/`Move`) | Cleanup Steps | Risk Notes |
| --- | --- | --- | --- | --- |
| T-008-A | `host-resource-agent/adapters/macos-audio/audio-runner.mjs` | Remove | delete file + imports + tests referencing legacy path | Medium: accidental runtime import leftovers |
| T-008-B | preflight check `macos_blackhole` | Remove/Rename | replace with first-party check ids/messages | Low |
| T-008-C | installer BlackHole bootstrap lines | Remove | delete brew cask install and tips | Low |

## Step-By-Step Plan
1. T-001: Implement first `PRCAudio.driver` plugin skeleton with one duplex virtual device and stable device identifiers.
2. T-002: Implement IPC bridge (`/tmp/prc-audio-driver.sock` + shared-memory ring buffers) and realtime-safe ring-buffer access.
3. T-003: Add macOS driver install/uninstall/update scripts and bundle packaging.
4. T-004: Build `macos-firstparty-audio` adapter (RTSP decode -> mic ingress, speaker egress -> `/api/speaker/stream`).
5. T-005: Update `session-controller` to use new adapter API and maintain independent resource failure isolation.
6. T-006: Replace preflight checks with first-party driver probe/health metrics.
7. T-007: Update macOS installer to include first-party driver setup path.
8. T-008: Remove BlackHole legacy runtime/install/docs references.
9. T-009: Run unit + integration + real-device E2E matrix and address defects.
10. T-010: Sync docs and release packaging notes.

## Per-File Definition Of Done
| File | Implementation Done Criteria | Unit Test Criteria | Integration Test Criteria | E2E Criteria | Notes |
| --- | --- | --- | --- | --- | --- |
| `host-resource-agent/macos-audio-driver/src/PRCAudioPlugin.mm` | plugin loads and registers duplex device | property/dispatch tests pass | visible in CoreAudio device list | selectable in Zoom/OBS | no lock-heavy callbacks |
| `host-resource-agent/macos-audio-driver/src/IPCBridge.mm` | socket + shm protocol stable | protocol tests pass | sustained stream test pass | no dropout over 10 min sample | glitch counters exposed |
| `host-resource-agent/adapters/macos-firstparty-audio/audio-runner.mjs` | mic/speaker route lifecycle works | unit route tests pass | toggle stress passes | phone hears speaker + meeting app hears mic | phone label propagation |
| `host-resource-agent/core/preflight-service.mjs` | first-party checks complete | unit checks pass | install->preflight pass | manual validation checklists pass | no BlackHole text remains |
| `host-resource-agent/installers/macos/install.command` | installs host + driver idempotently | shell lint/smoke pass | reinstall/upgrade test pass | fresh-machine manual checklist pass | no third-party cask installs |

## Test Strategy
- Unit tests:
  - driver protocol serializers, ring-buffer boundaries, adapter state transitions.
- Integration tests:
  - host adapter <-> driver IPC lifecycle, toggle races, recovery scenarios.
- E2E feasibility: `Feasible`
- If E2E is not feasible, concrete reason and current constraints: N/A
- Best-available non-E2E verification evidence when E2E is not feasible: N/A
- Residual risk notes:
  - macOS minor-version behavior drift and audio-service restart edge cases remain top risks.

## Test Feedback Escalation Policy (Execution Guardrail)
- `Local Fix`: patch directly and continue.
- `Design Impact`: stop implementation, update design + call stack + review gate.
- `Requirement Gap`: stop implementation, refine requirements then re-enter design/review.

## Cross-Reference Exception Protocol
| File | Cross-Reference With | Why Unavoidable | Temporary Strategy | Unblock Condition | Design Follow-Up Status | Owner |
| --- | --- | --- | --- | --- | --- | --- |
| `audio-runner.mjs` | `IPCBridge.mm` | protocol coupling required | versioned protocol schema + compatibility test | stable v1 protocol passes stress tests | Not Needed | Implementation |

## Design Feedback Loop
| Smell/Issue | Evidence (Files/Call Stack) | Design Section To Update | Action | Status |
| --- | --- | --- | --- | --- |
| None currently | N/A | N/A | N/A | Pending |
