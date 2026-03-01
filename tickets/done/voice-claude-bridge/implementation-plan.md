# Implementation Plan - Voice Claude Bridge

## Scope Classification

- Classification: `Small`
- Reasoning: Pattern-match implementation of existing stable logic.
- Workflow Depth: `Small`

## Upstream Artifacts (Required)

- Workflow state: `tickets/in-progress/voice-claude-bridge/workflow-state.md`
- Investigation notes: `tickets/in-progress/voice-claude-bridge/investigation-notes.md`
- Requirements: `tickets/in-progress/voice-claude-bridge/requirements.md`
  - Current Status: `Design-ready`
- Runtime call stacks: `tickets/in-progress/voice-claude-bridge/future-state-runtime-call-stack.md` (To be created)
- Runtime review: `tickets/in-progress/voice-claude-bridge/future-state-runtime-call-stack-review.md` (To be created)

## Plan Maturity

- Current Status: `Draft`
- Notes: Initial plan based on requirements and investigation.

## Solution Sketch (Required For `Small`)

- Use Cases In Scope: `UC-001`, `UC-002`, `UC-003`, `UC-004`
- Requirement Coverage Guarantee: All AC-001 to AC-006 are covered.
- Design-Risk Use Cases: None identified (standard PTY wrapping).
- Target Architecture Shape: Modular bridge with PTY wrapper and audio capture backend.
- New Layers/Modules/Boundary Interfaces To Introduce: None.
- Touched Files/Modules: New files in `voice-claude-bridge/`.
- API/Behavior Delta: New `voice-claude` CLI.
- Key Assumptions: `claude` CLI exists or is configurable.
- Known Risks: Hotkey conflicts with target process.

## Dependency And Sequencing Map

| Order | File/Module | Depends On | Why This Order |
| --- | --- | --- | --- |
| 1 | `voice-claude-bridge/requirements.txt` | N/A | Foundational dependencies. |
| 2 | `voice-claude-bridge/audio_capture.py` | `requirements.txt` | Core audio logic. |
| 3 | `voice-claude-bridge/cli.py` | `audio_capture.py` | Main orchestration logic. |
| 4 | `voice-claude-bridge/voice-claude` | `cli.py` | Bash wrapper script. |
| 5 | `voice-claude-bridge/install.sh` | All above | Installation script. |

## Requirement And Design Traceability

| Requirement | Acceptance Criteria ID(s) | Design Section | Use Case / Call Stack | Planned Task ID(s) | Stage 6 Verification (Unit/Integration) | Stage 7 Scenario ID(s) |
| --- | --- | --- | --- | --- | --- | --- |
| AC-001 | AC-001 | Hotkey logic | UC-004 | T-001 | Unit (mock PTY) | SC-001 |
| AC-002 | AC-002 | Hotkey configuration | UC-004 | T-001 | Unit | SC-001 |
| AC-003 | AC-003 | Transcription logic | UC-002 | T-002 | Unit (mock audio) | SC-002 |
| AC-004 | AC-004 | PTY write logic | UC-003 | T-003 | Unit (mock PTY) | SC-003 |
| AC-005 | AC-005 | Audio capture backends | UC-001 | T-004 | Unit (mock system) | SC-004 |
| AC-006 | AC-006 | WinSize sync logic | UC-003 | T-003 | Unit | SC-005 |

## Step-By-Step Plan

1. Create `voice-claude-bridge/` directory.
2. Create `voice-claude-bridge/requirements.txt`.
3. Create `voice-claude-bridge/audio_capture.py` (adapted from `voice-gemini-bridge`).
4. Create `voice-claude-bridge/cli.py` (adapted from `voice-gemini-bridge` with Claude specific naming and hotkey).
5. Create `voice-claude-bridge/voice-claude` wrapper script.
6. Create `voice-claude-bridge/install.sh`.
7. Create unit tests in `voice-claude-bridge/tests/`.

## Backward-Compat And Decoupling Guardrails (Mandatory)

- Backward-compatibility mechanisms introduced: `None`
- Legacy code retained for old behavior: `No`
- Decoupling impact assessment completed: `Yes`
- New tight coupling or cyclic dependency introduced: `No`

## Per-File Definition Of Done

| File | Implementation Done Criteria | Unit Test Criteria | Integration Test Criteria | Notes |
| --- | --- | --- | --- | --- |
| `requirements.txt` | Correct versions listed. | N/A | N/A | |
| `audio_capture.py` | Supports Linux and macOS. | Mocks subprocess calls. | N/A | |
| `cli.py` | Hotkey toggle works, transcription sent to PTY. | Mocks faster-whisper and PTY. | N/A | |
| `voice-claude` | Correctly sets up venv and calls cli.py. | N/A | Shell execution test. | |
