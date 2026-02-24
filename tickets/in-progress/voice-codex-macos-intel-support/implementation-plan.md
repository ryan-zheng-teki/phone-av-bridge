# Implementation Plan

## Scope Classification
- Classification: `Medium`
- Reasoning: cross-cutting install/runtime/test/docs changes with a new platform abstraction module.
- Workflow Depth: `Medium` path (design -> call stacks -> review -> implementation).

## Upstream Artifacts (Required)
- Investigation notes: `tickets/in-progress/voice-codex-macos-intel-support/investigation-notes.md`
- Requirements: `tickets/in-progress/voice-codex-macos-intel-support/requirements.md`
  - Current Status: `Design-ready`
- Runtime call stacks: `tickets/in-progress/voice-codex-macos-intel-support/future-state-runtime-call-stack.md`
- Runtime review: `tickets/in-progress/voice-codex-macos-intel-support/future-state-runtime-call-stack-review.md`
- Proposed design: `tickets/in-progress/voice-codex-macos-intel-support/proposed-design.md`

## Plan Maturity
- Current Status: `Ready For Implementation`
- Notes: review gate reached `Go Confirmed`.

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

## Dependency And Sequencing Map
| Order | File/Module | Depends On | Why This Order |
| --- | --- | --- | --- |
| 1 | `voice-codex-bridge/audio_capture.py` | N/A | foundational backend boundary used by CLI |
| 2 | `voice-codex-bridge/cli.py` | `audio_capture.py` | integrate new abstraction without mixing concerns |
| 3 | `voice-codex-bridge/install.sh` | None | installer python selection policy |
| 4 | `voice-codex-bridge/voice-codex` | install policy and runtime expectations | launcher parity with installer |
| 5 | `voice-codex-bridge/tests/test_cli_helpers.py` | code changes | validate behavior |
| 6 | `voice-codex-bridge/README.md` | finalized behavior | document operator workflow |

## Requirement And Design Traceability
| Requirement | Design Section | Use Case / Call Stack | Planned Task ID(s) | Verification |
| --- | --- | --- | --- | --- |
| R-001 | Change Inventory C-003/C-004 | UC-001 | T-003, T-004 | Manual install smoke |
| R-002 | Change Inventory C-001/C-002 | UC-002, UC-003 | T-001, T-002 | Unit + manual run |
| R-003 | Change Inventory C-001/C-002 | UC-004 | T-001, T-002 | Unit checks |
| R-004 | Change Inventory C-005 | UC-004 | T-005 | Unit tests |

## Design Delta Traceability (Required For `Medium/Large`)
| Change ID (from proposed design doc) | Change Type | Planned Task ID(s) | Includes Remove/Rename Work | Verification |
| --- | --- | --- | --- | --- |
| C-001 | Add | T-001 | No | Unit + manual |
| C-002 | Modify | T-002 | Yes | Unit + manual |
| C-003 | Modify | T-003 | No | Manual |
| C-004 | Modify | T-004 | No | Manual |
| C-005 | Modify | T-005 | No | Unit |
| C-006 | Modify | T-006 | No | Manual |
| C-007 | Modify | T-007 | No | Manual |

## Decommission / Rename Execution Tasks
| Task ID | Item | Action (`Remove`/`Rename`/`Move`) | Cleanup Steps | Risk Notes |
| --- | --- | --- | --- | --- |
| T-DEL-001 | Linux-only recorder helpers in `cli.py` | Remove | delete direct helper + source discovery functions and route through backend object | low |

## Step-By-Step Plan
1. T-001: add `audio_capture.py` with Pulse and macOS backends plus selector and probing helper.
2. T-002: refactor `cli.py` to use backend object for prereqs, source resolution, and record command creation.
3. T-003/T-004: update `install.sh` and `voice-codex` to choose supported Python interpreter and fail fast with guidance.
4. T-005: extend unit tests for backend selection and command construction.
5. T-006: update README for macOS setup and source selection behavior.
6. T-007: mark generated `.voice-codex.env` as ignored in repo status.
7. Verification: run unit tests and macOS runtime smoke test with local dependency checks.

## Per-File Definition Of Done
| File | Implementation Done Criteria | Unit Test Criteria | Integration Test Criteria | E2E Criteria | Notes |
| --- | --- | --- | --- | --- | --- |
| `audio_capture.py` | both backends + selector implemented | backend command/selection tests pass | N/A | manual recorder smoke path | no PTY logic inside |
| `cli.py` | no direct platform recorder logic remains | existing helper tests updated | N/A | manual `voice-codex --no-auto-send` startup | PTY/STT unchanged |
| `install.sh` | python selection + clear errors | N/A | N/A | manual run succeeds with supported python | |
| `voice-codex` | python selection mirrored | N/A | N/A | manual first-run path works | |
| `tests/test_cli_helpers.py` | new tests added and passing | pass | N/A | N/A | |
| `README.md` | macOS setup documented | N/A | N/A | manual command steps validated | |

## Test Strategy
- Unit tests: `python3 -m unittest discover -s tests -v` from `voice-codex-bridge`.
- Integration tests: N/A for this CLI-only refactor in current repo.
- E2E feasibility: `Not Feasible`
- If E2E is not feasible, concrete reason and current constraints:
  - full interactive microphone dictation loop needs live user speech and terminal interaction; not deterministic in this automated run.
- Best-available non-E2E verification evidence when E2E is not feasible:
  - dependency install probes, backend prerequisite checks, command path smoke execution, unit tests.
- Residual risk notes:
  - specific non-default microphone index selection may require manual tuning on some macOS hosts.
