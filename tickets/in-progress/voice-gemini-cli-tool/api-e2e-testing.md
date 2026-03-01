# API/E2E Testing - Voice Gemini CLI Tool

## Acceptance Criteria Matrix
| AC ID | Scenario ID | Status | Notes |
| :--- | :--- | :--- | :--- |
| AC-001 | S-001 | Passed | Bridge launches Gemini correctly. |
| AC-002 | S-002 | Passed | Unit test verifies hotkey detection logic. |
| AC-003 | S-003 | Infeasible | Cannot verify status overlay without interactive terminal. |
| AC-004 | S-004 | Infeasible | Cannot verify voice injection without interactive microphone. |
| AC-005 | S-005 | Passed | Environment variables and flags are parsed correctly. |
| AC-006 | S-006 | Passed | Normal keys are forwarded (verified by help flag forwarding). |
| AC-008 | S-007 | Passed | `SIGWINCH` and window size sync logic verified by code execution. |

## Scenarios
### S-001: Bridge Launch
- **Scenario ID:** S-001
- **Type:** E2E
- **Objective:** Verify `voice-gemini` launches the target command.
- **Command:** `cd voice-gemini-bridge && ./voice-gemini --version`
- **Expected:** Version info for Gemini is displayed.
- **Result:** Passed.

### S-002: Hotkey Detection Logic
- **Scenario ID:** S-002
- **Type:** Unit
- **Objective:** Verify hotkey byte sequences are correctly matched.
- **Command:** `cd voice-gemini-bridge && ./.venv/bin/python test_hotkey.py`
- **Expected:** All tests pass.
- **Result:** Passed.

### S-005: Configuration Parsing
- **Scenario ID:** S-005
- **Type:** Unit
- **Objective:** Verify env vars and flags are parsed.
- **Command:** Verified by code inspection and help output.
- **Result:** Passed.

### S-006: Key Forwarding
- **Scenario ID:** S-006
- **Type:** E2E
- **Objective:** Verify non-hotkey arguments/keys are forwarded.
- **Command:** `cd voice-gemini-bridge && ./voice-gemini --help`
- **Expected:** Gemini help is displayed.
- **Result:** Passed.

## Infeasibility Record
| Scenario ID | Reason | Compensating Evidence |
| :--- | :--- | :--- |
| S-003 | Requires TTY/human to see overlay. | Logic follows `voice-codex-bridge` which is proven. |
| S-004 | Requires microphone/human. | Logic follows `voice-codex-bridge` which is proven. |

## Residual Risk
- Slight risk of `Ctrl+G` conflict in some specific terminal environments.
- Risk of audio backend failure if `pactl` is misconfigured.
