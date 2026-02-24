# Proposed Design Document

## Design Version
- Current Version: `v1`

## Revision History
| Version | Trigger | Summary Of Changes | Related Review Round |
| --- | --- | --- | --- |
| v1 | Initial draft | Introduce platform-separated recorder backend and Python interpreter selection policy updates for installer/launcher | 1 |

## Artifact Basis
- Investigation Notes: `tickets/in-progress/voice-codex-macos-intel-support/investigation-notes.md`
- Requirements: `tickets/in-progress/voice-codex-macos-intel-support/requirements.md`
- Requirements Status: `Design-ready`

## Summary
Enable `voice-codex` on Intel macOS without breaking Linux/WSL by separating recording backend concerns from PTY/STT orchestration and by selecting a supported Python interpreter for dependency installation.

## Goals
- Make install succeed on this machine by avoiding unsupported default Python version.
- Support microphone capture on macOS using an explicit macOS backend.
- Preserve Linux/WSL PulseAudio flow.
- Keep PTY/Codex interaction logic unchanged.

## Legacy Removal Policy (Mandatory)
- Policy: `No backward compatibility; remove legacy code paths.`
- Required action: remove Linux-only assumptions embedded inside CLI orchestration and replace with backend abstraction.

## Requirements And Use Cases
| Requirement | Description | Acceptance Criteria | Use Case IDs |
| --- | --- | --- | --- |
| R-001 | Installer chooses supported Python interpreter for STT deps | `voice-codex` setup no longer fails on Python 3.14-only default | UC-001 |
| R-002 | Runtime supports macOS audio capture | `voice-codex` can start and capture through macOS backend prerequisites | UC-002, UC-003 |
| R-003 | Linux/WSL behavior remains intact | Pulse path remains backend for Linux/WSL | UC-004 |
| R-004 | SoC and regression safety | Backend-specific tests exist and pass | UC-004 |

## Codebase Understanding Snapshot (Pre-Design Mandatory)
| Area | Findings | Evidence (files/functions) | Open Unknowns |
| --- | --- | --- | --- |
| Entrypoints / Boundaries | `voice-codex` shell launcher invokes `cli.py`; core orchestration in `VoiceCodexCliBridge` | `voice-codex`, `cli.py:VoiceCodexCliBridge.run` | none |
| Current Naming Conventions | flat module, procedural helpers + class orchestration | `cli.py` helper functions and class methods | none |
| Impacted Modules / Responsibilities | `cli.py` currently mixes PTY orchestration, STT, and platform recorder details | `build_parec_record_command`, `_ensure_prereqs`, `_resolve_record_source` | none |
| Data / Persistence / External IO | audio raw temp file -> wav -> faster-whisper; external commands `parec/pactl` | `_start_recording`, `_stop_recording`, `_convert_raw_to_wav` | ffmpeg device listing stability |

## Current State (As-Is)
- Linux Pulse command creation and source discovery are hard-coded in `cli.py`.
- Prerequisite checks block on `parec`/`pactl` on all platforms.
- Installer/launcher use `python3` without compatibility guard.

## Target State (To-Be)
- `audio_capture.py` owns platform-specific recorder logic (command build, prereq check, source discovery/probe).
- `cli.py` depends on backend interface only and remains responsible for PTY, key handling, transcript flow.
- `install.sh` and `voice-codex` choose supported Python interpreter with override support.
- README documents macOS-specific setup (ffmpeg + supported Python).

## Change Inventory (Delta)
| Change ID | Change Type (`Add`/`Modify`/`Rename/Move`/`Remove`) | Current Path | Target Path | Rationale | Impacted Areas | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| C-001 | Add | N/A | `voice-codex-bridge/audio_capture.py` | Separate OS-specific recording concern from bridge orchestration | Runtime recording | New module with backend classes |
| C-002 | Modify | `voice-codex-bridge/cli.py` | `voice-codex-bridge/cli.py` | Consume backend abstraction instead of direct Pulse logic | Runtime startup + recording | Keep PTY/STT behavior intact |
| C-003 | Modify | `voice-codex-bridge/install.sh` | `voice-codex-bridge/install.sh` | Select compatible python interpreter automatically | Install flow | Add override env var and version bounds |
| C-004 | Modify | `voice-codex-bridge/voice-codex` | `voice-codex-bridge/voice-codex` | Use same interpreter selection as installer for first-run install | Launcher flow | Keep default behavior, safer interpreter choice |
| C-005 | Modify | `voice-codex-bridge/tests/test_cli_helpers.py` | `voice-codex-bridge/tests/test_cli_helpers.py` | Align tests with backend abstraction | Unit tests | Add platform/backend selection tests |
| C-006 | Modify | `voice-codex-bridge/README.md` | `voice-codex-bridge/README.md` | Document macOS setup and backend behavior | Docs | Include intel mac guidance |
| C-007 | Modify | `.gitignore` | `.gitignore` | Ignore generated local voice env file | Repo hygiene | Prevent local install artifacts from appearing as source changes |

## Architecture Overview
- `cli.py`: PTY lifecycle, key handling, transcript state, STT orchestration.
- `audio_capture.py`: backend selection + backend operations (`ensure_prereqs`, `resolve_source`, `build_record_command`, `supports_capture`).
- shell scripts (`install.sh`, `voice-codex`): environment/bootstrap concerns only.

## File And Module Breakdown
| File/Module | Change Type | Concern / Responsibility | Public APIs | Inputs/Outputs | Dependencies |
| --- | --- | --- | --- | --- | --- |
| `audio_capture.py` | Add | Platform-specific audio capture backend logic | `select_audio_backend()`, backend methods | Inputs: OS, source, sample_rate; Outputs: command list/source | `platform`, `subprocess`, `tempfile`, `os` |
| `cli.py` | Modify | PTY + STT orchestration and command forwarding | existing CLI args + bridge class | Inputs: key events/audio files; Outputs: codex stdin and status | `audio_capture`, `faster_whisper` |
| `install.sh` | Modify | install-time venv+deps setup | shell install entrypoint | Inputs: env, python binaries; Outputs: `.venv` deps + link | shell + python |
| `voice-codex` | Modify | runtime launcher | wrapper entrypoint | Inputs: CLI args/env; Outputs: execute `cli.py` | shell + python |
| `tests/test_cli_helpers.py` | Modify | helper/backend unit checks | unittest cases | Inputs: helper calls; Outputs: pass/fail | unittest |
| `README.md` | Modify | operator documentation | markdown docs | Inputs: setup steps | user-facing instructions |

## Layer-Appropriate Separation Of Concerns Check
- Non-UI scope: recorder backend logic moved out of PTY orchestration file.
- Integration scope: each backend owns one integration concern (`PulseAudio` or `ffmpeg avfoundation`).

## Naming Decisions (Natural And Implementation-Friendly)
| Item Type (`File`/`Module`/`API`) | Current Name | Proposed Name | Reason | Notes |
| --- | --- | --- | --- | --- |
| File | N/A | `audio_capture.py` | Clear and scoped to recording concern | neutral across OS |
| API | `build_parec_record_command` in `cli.py` | backend `build_record_command` | removes Linux-only name from shared orchestration | improves extensibility |

## Naming Drift Check (Mandatory)
| Item | Current Responsibility | Does Name Still Match? (`Yes`/`No`) | Corrective Action (`Rename`/`Split`/`Move`/`N/A`) | Mapped Change ID |
| --- | --- | --- | --- | --- |
| `cli.py` recorder helpers | platform-specific recorder operations | No | Split | C-001, C-002 |
| `--record-source` CLI arg | audio source selector | Yes | N/A | C-002 |

## Dependency Flow And Cross-Reference Risk
| Module/File | Upstream Dependencies | Downstream Dependents | Cross-Reference Risk | Mitigation / Boundary Strategy |
| --- | --- | --- | --- | --- |
| `audio_capture.py` | stdlib only | `cli.py`, tests | Low | one-direction dependency (`cli.py` imports backend) |
| `cli.py` | `audio_capture.py`, STT libs | wrapper entrypoint | Medium | avoid importing PTY logic from backend module |

## Decommission / Cleanup Plan
| Item To Remove/Rename | Cleanup Actions | Legacy Removal Notes | Verification |
| --- | --- | --- | --- |
| Linux-only helpers inside `cli.py` | remove direct `parec/pactl` construction and source listing code | replace with backend calls; no compatibility shim | unit tests + runtime smoke tests |

## Error Handling And Edge Cases
- Unsupported platform: explicit runtime error from backend selector.
- Missing backend tools (`pactl`/`parec` or `ffmpeg`): explicit prerequisite error.
- Source probe failures: fallback to default backend source.
- Python interpreter not found in supported range: explicit install/launch error with guidance.

## Use-Case Coverage Matrix (Design Gate)
| use_case_id | Requirement | Use Case | Primary Path Covered (`Yes`/`No`) | Fallback Path Covered (`Yes`/`No`/`N/A`) | Error Path Covered (`Yes`/`No`/`N/A`) | Runtime Call Stack Section |
| --- | --- | --- | --- | --- | --- | --- |
| UC-001 | R-001 | Install on Intel macOS with compatible Python | Yes | N/A | Yes | UC-001 |
| UC-002 | R-002 | Start bridge on macOS and pass prereqs | Yes | Yes | Yes | UC-002 |
| UC-003 | R-002 | Record and transcribe using macOS source | Yes | Yes | Yes | UC-003 |
| UC-004 | R-003, R-004 | Linux/WSL Pulse behavior remains working | Yes | Yes | Yes | UC-004 |

## Change Traceability To Implementation Plan
| Change ID | Implementation Plan Task(s) | Verification (Unit/Integration/E2E/Manual) | Status |
| --- | --- | --- | --- |
| C-001 | T-001 | Unit + manual | Planned |
| C-002 | T-002 | Unit + manual | Planned |
| C-003 | T-003 | Manual | Planned |
| C-004 | T-004 | Manual | Planned |
| C-005 | T-005 | Unit | Planned |
| C-006 | T-006 | Manual | Planned |

## Design Feedback Loop Notes (From Review/Implementation)
| Date | Trigger (Review/File/Test/Blocker) | Classification (`Local Fix`/`Design Impact`/`Requirement Gap`) | Design Smell | Requirements Updated? | Design Update Applied | Status |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-02-24 | Initial design pass | N/A | none | No | v1 created | Completed |

## Open Questions
- No blocking open questions for implementation kickoff.
