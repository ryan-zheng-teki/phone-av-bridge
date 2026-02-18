# Requirements

## Status
- Current: `Design-ready`
- Initial snapshot captured from user request: `Draft` ("make Linux work now using software engineering workflow").

## Goal / Problem Statement
Ensure Linux host media routing remains stable during camera lifecycle transitions so phone camera/microphone/speaker can be used reliably as virtual devices.

## Scope Triage
- Classification: `Small`
- Rationale:
  - Single high-impact reliability fix in Linux camera adapter process lifecycle.
  - No public API/schema changes.
  - Primary touch points are limited to Linux camera adapter and tests.

## In-Scope Use Cases
- `UC-001`: Pair host and enable camera+microphone+speaker on Linux host; status reaches `Resource Active`.
- `UC-002`: Camera route stop/restart does not hang when bridge child process is slow or unresponsive to `SIGTERM`.
- `UC-003`: Existing Linux Docker E2E behavior remains green after change.

## Acceptance Criteria
- `AC-001`: `LinuxCameraBridgeRunner.stopCamera()` must always resolve in bounded time for active processes (graceful exit or forced kill).
- `AC-002`: No regression in `desktop-av-bridge-host` test suite.
- `AC-003`: No regression in Linux Docker E2E (`camera=true`, `microphone=true`, `speaker=true`, `issues=[]`).
- `AC-004`: Route restart scenarios remain functional after stop/start transitions.

## Constraints / Dependencies
- Runtime remains Node.js-based and must preserve current adapter interface.
- Linux validation relies on Docker-based host E2E in this environment.
- Must keep no-legacy/no-backward-compat stance (clean replacement of flawed shutdown behavior).

## Assumptions
- Node child-process semantics for `child.killed` match current LTS behavior.
- Existing Docker E2E is representative of host-level Linux media orchestration correctness.

## Open Questions / Risks
- Physical meeting-app device listing behavior (Zoom/Meet/Teams) cannot be fully validated in this headless environment.
- Distros with unusual signal handling policies may still require future tuning, but bounded fallback kill addresses primary hang risk.
