# Implementation Plan

## Status
- Current: `Finalized`
- Scope: `Small`

## Implementation Strategy
1. Refactor Linux camera shutdown path to deterministic bounded termination.
2. Add targeted unit tests for forced-kill fallback and idempotent stop behavior.
3. Run full host unit/integration suite and Linux Docker E2E regression.

## Planned Changes
| Change ID | Type | File | Description |
| --- | --- | --- | --- |
| C-001 | Modify | `desktop-av-bridge-host/adapters/linux-camera/bridge-runner.mjs` | Replace `active.killed`-based fallback with timeout-driven force-kill flow that always resolves stop path. |
| C-002 | Add/Modify | `desktop-av-bridge-host/tests/unit/linux-camera-bridge-runner.test.mjs` | Add adapter-level lifecycle tests (forced kill fallback, stop idempotency, backend selection sanity). |
| C-003 | N/A | `desktop-av-bridge-host/package.json` | Existing `tests/unit/*.test.mjs` glob already includes new unit test file. No change required. |

## Requirement Traceability
| Requirement | Design Section | Call Stack Use Case | Implementation Change(s) | Verification |
| --- | --- | --- | --- | --- |
| AC-001 | Small-Scope Solution Sketch | UC-002 | C-001 | Unit tests in C-002 |
| AC-002 | Traceability + verification strategy | UC-003 | C-002, C-003 | `cd desktop-av-bridge-host && npm test` |
| AC-003 | Traceability + verification strategy | UC-003 | C-001, C-002 | `cd desktop-av-bridge-host && npm run test:docker:linux-e2e` |
| AC-004 | Small-Scope Solution Sketch | UC-001 | C-001, C-002 | Unit tests + Linux Docker E2E |

## Verification Strategy
- Unit tests:
  - Linux camera adapter lifecycle test coverage for stop timeout/kill behavior.
- Integration tests:
  - Existing host integration tests from `npm test`.
- E2E tests:
  - Feasible in this environment; run Linux Docker E2E script.
  - Command: `cd desktop-av-bridge-host && npm run test:docker:linux-e2e`.

## E2E Feasibility
- E2E is feasible in current environment via Docker-based harness.
- No infeasibility exception required.

## Execution Order
1. Implement C-001.
2. Implement C-002.
3. Confirm C-003 remains N/A (no `package.json` change needed).
4. Run verification suite and capture results in progress tracker.
