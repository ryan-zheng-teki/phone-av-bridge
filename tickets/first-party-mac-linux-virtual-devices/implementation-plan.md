# Implementation Plan

## Scope Classification

- Classification: `Large`
- Reasoning:
  - Cross-platform media virtualization and installer behavior changes.
  - Requires add/modify/remove changes across adapters, preflight, installers, and docs.
- Workflow Depth: `Large` (requirements -> proposed design -> runtime call stack -> review -> plan/progress)

## Plan Maturity

- Current Status: `Implementation Executed (Validation Completed)`
- Notes: Runtime call stack review gate reached `Go`, implementation was completed, and macOS camera-extension approval/visibility checks were validated on the connected real device.

## Preconditions

- Runtime call stack review artifact exists: `Yes`
- All in-scope use cases reviewed: `Yes`
- No unresolved blocking findings: `Yes`
- Minimum review rounds satisfied (`Large` >= 5): `Yes` (6 rounds)
- Final gate decision is `Implementation can start: Yes`: `Yes`

## Runtime Call Stack Review Gate

| Round | Use Case | Call Stack Location | Review Location | Naming Naturalness | File/API Naming Clarity | Business Flow Completeness | Structure & SoC Check | Unresolved Blocking Findings | Verdict |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | UC-001..UC-009 | `tickets/first-party-mac-linux-virtual-devices/proposed-design-based-runtime-call-stack.md` | `tickets/first-party-mac-linux-virtual-devices/runtime-call-stack-review.md` | Fail | Fail | Pass | Pass | Yes | Fail |
| 2 | UC-001..UC-009 | same | same | Pass | Pass | Pass | Pass | No | Pass |
| 3 | UC-001..UC-009 | same | same | Pass | Pass | Pass | Pass | No | Pass |
| 4 | UC-001..UC-009 | same | same | Pass | Pass | Pass | Pass | No | Pass |
| 5 | UC-001..UC-009 | same | same | Pass | Pass | Pass | Pass | No | Pass |
| 6 | UC-001..UC-009 | same | same | Pass | Pass | Pass | Pass | No | Pass |

## Go / No-Go Decision

- Decision: `Go`
- Evidence:
  - Review rounds completed: `6`
  - Final review round: `6`
  - Final review gate line: `Implementation can start: Yes`

## Principles

- Bottom-up implementation with test updates per touched module.
- Keep no-legacy/no-backward-compat rule for first-party mode target.
- Deliver incremental value while preserving working Linux/Mac behavior until first-party macOS virtualization lands.

## Dependency And Sequencing Map

| Order | File/Module | Depends On | Why This Order |
| --- | --- | --- | --- |
| 1 | `host-resource-agent/adapters/common/device-name.mjs` | none | Shared helper for naming consistency across adapters. |
| 2 | `host-resource-agent/adapters/linux-*.mjs`, `host-resource-agent/linux-app/server.mjs` | C-001 helper | Linux simplification and route naming enforcement. |
| 3 | `host-resource-agent/core/preflight-service.mjs` | camera mode semantics from step 2 | Reflect effective Linux mode in diagnostics/remediation. |
| 4 | `host-resource-agent/installers/linux/install.sh` | camera mode + preflight behavior | One-click setup and compatibility-mode provisioning. |
| 5 | `host-resource-agent/tests/unit/*`, `host-resource-agent/tests/docker/*` | steps 1-4 | Lock behavior with automated validation. |
| 6 | `host-resource-agent/adapters/macos-firstparty-*` (new) | architectural baseline from steps 1-5 | Replace OBS/BlackHole path with first-party components. |
| 7 | `host-resource-agent/installers/macos/install.command`, `core/preflight-service.mjs` (mac section) | step 6 | Remove external dependency bootstrap and checks. |

## Design Delta Traceability

| Change ID | Change Type | Planned Task ID(s) | Includes Remove/Rename Work | Verification |
| --- | --- | --- | --- | --- |
| C-001 | Add | T-001, T-006 | No | unit tests + adapter integration tests |
| C-002 | Add | T-006 | No | macOS local validation checklist |
| C-003 | Add | T-001 | No | unit tests |
| C-004 | Modify | T-002 | No | unit + docker E2E |
| C-005 | Modify | T-002 | No | unit + docker E2E |
| C-006 | Modify | T-003, T-007 | No | unit tests |
| C-007 | Modify | T-002 | No | integration tests |
| C-008 | Modify | T-007 | No | install smoke test |
| C-009 | Modify | T-004 | No | install smoke test + docker E2E |
| C-010 | Remove | T-008 | Yes | reference scan + macOS smoke test |
| C-011 | Remove | T-008 | Yes | reference scan + macOS smoke test |
| C-012 | Modify | T-008 | No | Android build + real-device reconnect validation |

## Decommission / Rename Execution Tasks

| Task ID | Item | Action | Cleanup Steps | Risk Notes |
| --- | --- | --- | --- | --- |
| T-008 | OBS + AkVirtual adapter paths and Android publish stability path | Remove/Modify | update imports, installers, preflight, docs, tests; add retry/heartbeat + timeout hardening | Low: remaining risk is app-level manual meeting-app selection verification |

## Step-By-Step Plan

1. T-001: Add shared device-name helper and integrate naming contract.
2. T-002: Add Linux camera-mode policy (`LINUX_CAMERA_MODE`) and adapter wiring.
3. T-003: Update Linux preflight to reflect mode-driven requirements.
4. T-004: Simplify Linux installer dependency policy and compatibility provisioning.
5. T-005: Add/update unit and Docker E2E coverage for the new behavior.
6. T-006: Implement first-party macOS camera/audio adapters (new modules).
7. T-007: Switch macOS installer/preflight to first-party dependencies only.
8. T-008: Remove OBS/BlackHole legacy modules and references.
9. T-009: Synchronize docs and user setup guides.

## Per-File Definition Of Done

| File | Implementation Done Criteria | Unit Test Criteria | Integration Test Criteria | Notes |
| --- | --- | --- | --- | --- |
| `host-resource-agent/adapters/common/device-name.mjs` | deterministic identity + label generation | helper tests pass | N/A | Completed in this cycle |
| `host-resource-agent/adapters/linux-camera/bridge-runner.mjs` | supports camera mode policy and stable route hint naming | existing + new helper tests pass | server integration + docker e2e pass | Completed in this cycle |
| `host-resource-agent/adapters/linux-audio/audio-runner.mjs` | shared naming integrated without route regressions | helper + unit tests pass | docker e2e pass | Completed in this cycle |
| `host-resource-agent/core/preflight-service.mjs` | Linux checks map to selected mode | unit tests pass | `/api/preflight` integration pass | Completed in this cycle |
| `host-resource-agent/installers/linux/install.sh` | one-click dependency flow with optional compatibility packages | shellcheck/manual smoke | container install smoke | Completed in this cycle |
| `host-resource-agent/adapters/macos-firstparty-camera/*` | first-party camera implementation present | adapter tests pass | real-device macOS checklist | Completed on native camera-extension integration (`PRCCamera`) |
| `host-resource-agent/adapters/macos-firstparty-audio/*` | first-party mic/speaker implementation present | adapter tests pass | real-device macOS checklist | Completed |

## Cross-Reference Exception Protocol

| File | Cross-Reference With | Why Unavoidable | Temporary Strategy | Unblock Condition | Design Follow-Up Status | Owner |
| --- | --- | --- | --- | --- | --- | --- |
| `linux-app/server.mjs` | platform adapters | runtime assembly requires both adapters | keep adapter interfaces minimal and stable | first-party macOS adapter modules available | `Not Needed` | Codex |

## Test Strategy

- Unit tests:
  - `npm test` (`tests/unit/*.test.mjs` and integration tests already bundled).
- Integration tests:
  - mock server pairing/toggle/preflight flows in `tests/integration/server.test.mjs`.
- E2E tests:
  - `npm run test:docker:linux-e2e` (camera/mic/speaker lifecycle + non-silent speaker PCM).
- E2E infeasibility notes:
  - macOS first-party path is implemented and validated with physical Android + mac host status/resource activation, AVFoundation camera visibility, and speaker PCM checks.
  - Manual Zoom/Meet UI selection verification remains a final user-facing checklist item.
