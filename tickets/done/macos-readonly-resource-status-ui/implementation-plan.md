# Implementation Plan

## Status
Finalized

## Scope
Replace macOS resource checkbox indicators with non-interactive status rows/chips while preserving existing host polling and read-only behavior.

## Requirement Traceability
| Requirement | Use Case | Task | Verification |
|---|---|---|---|
| AC-1 remove checkbox controls | UC-001 | T-001 UI component refactor | macOS build + UI smoke |
| AC-2 row + chip rendering | UC-001 | T-001 + T-002 status-row helpers | macOS build + UI smoke |
| AC-3 chip state mapping | UC-002 | T-003 capabilities/issues mapping | runtime status smoke |
| AC-4 no Android-control note | UC-001 | T-001 remove mirror note | visual inspection |
| AC-5 no last-updated metadata | UC-001 | T-001 keep UI minimal | visual inspection |
| AC-6 build passes | UC-003 | T-004 compile/sign build | `build-signed-local.sh` |

## Tasks
1. T-001 Refactor resource section UI in `ViewController.swift` to status rows/chips and remove checkbox controls.
2. T-002 Add reusable chip helper methods and per-resource chip fields.
3. T-003 Extend host status parsing for capabilities and apply row-state mapping (`Active/Off/Unavailable/Issue`).
4. T-004 Build and run macOS app to validate no compile/runtime regressions.
5. T-005 Update project docs if user-visible behavior text changed.

## Verification Strategy
- Compile/sign: `scripts/build-signed-local.sh`.
- Runtime smoke: launch `/Applications/PRCCamera.app` and verify section renders status rows/chips.
- API continuity smoke: `GET /api/status` remains consumed without mutation endpoints.
- E2E note: full UI screenshot automation is optional; functional smoke and build validation are sufficient for this small UI-only change.
