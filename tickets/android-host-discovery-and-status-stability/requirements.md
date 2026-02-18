# Requirements

## Status
Design-ready

## Goal / Problem Statement
Fix reliability and correctness gaps where Android can fail to discover a running host, and where Android/macOS status can drift due stale local pairing/toggle state.

## Scope Triage
- Size: Small
- Rationale: focused changes in Android discovery and Android startup/status reconciliation without new architecture layers.

## In-Scope Use Cases
- UC-1: User opens host app on macOS and taps Pair on Android; discovery should succeed more reliably on common LANs.
- UC-2: If host reports `Not Paired`, Android should stop treating local session as paired.
- UC-3: App cold start should not apply stale camera/mic/speaker toggles before host pairing state is validated.

## Acceptance Criteria
1. Discovery sends probes to subnet-directed broadcast targets in addition to current global targets.
2. On Android startup, stale local paired state is auto-cleared when host status reports `paired=false`.
3. Resource service/toggle publication is not started from stale local state prior to reconciliation.
4. Existing successful pair flow still works on connected real device.
5. Existing build/tests pass for touched modules.

## Constraints / Dependencies
- Must preserve current “Android is controller” UX direction.
- Must not require manual host URL entry.
- Must remain compatible with existing host API endpoints.

## Assumptions
- Host API `/api/status` is authoritative for pairing truth.
- Android has network permission required for UDP discovery + HTTP host status checks.

## Open Questions / Risks
- Some networks may still block UDP replies entirely; fallback behavior remains best-effort.
