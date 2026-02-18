# Requirements

## Status
Design-ready

## Goal
Improve macOS resource display UX by replacing checkbox-like status indicators with explicit read-only status rows and non-interactive chips, avoiding control affordance confusion.

## Scope Triage
- Scope: Small
- Rationale: one-file UI refactor in macOS host app with no host API changes.

## In-Scope Use Cases
- UC-001 Resource status visibility
  - User sees three rows: `Camera`, `Microphone`, `Speaker`.
- UC-002 Read-only chip semantics
  - Each row has non-interactive chip state: `Active`, `Off`, `Unavailable`, or `Issue`.
- UC-003 Existing polling continuity
  - Host status refresh and bridge health behavior remains unchanged.

## Acceptance Criteria
1. Resource checkbox controls are removed from macOS host UI.
2. Resource rows are rendered as label + chip (non-clickable).
3. Chip state mapping works:
   - `Unavailable` when capability is unavailable,
   - `Issue` when resource-specific issue exists,
   - `Active` when resource is enabled without issue,
   - `Off` otherwise.
4. No extra explanatory Android-control note is shown.
5. No last-updated timestamp is shown.
6. Build succeeds for macOS app after UI refactor.

## Constraints / Dependencies
- Must preserve current read-only control model (no `/api/toggles` write path).
- Must preserve existing host API contract and status polling cadence.
- No backward-compat checkbox UI retained.

## Assumptions
- Host `capabilities` object is available via `/api/status` and can drive `Unavailable` state.
- Host issues include a resource identifier (`camera|microphone|speaker`) suitable for mapping.

## Open Questions / Risks
- Generic non-resource issue messages may not map to a single row; fallback is global `Needs Attention` badge plus unaffected row states.
