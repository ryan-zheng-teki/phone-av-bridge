# Requirements

- Status: Design-ready
- Scope: Small
- Triage rationale: focused changes in existing macOS view controller and Android host-status sync model; no new backend API.

## Goal
Make macOS-to-phone resource control intuitive and reliable without requiring a separate apply step, and remove misleading `Starting` badge persistence.

## In-Scope Use Cases
- UC-001: User toggles camera/microphone/speaker in PRC Camera Host; change is pushed automatically.
- UC-002: User changes resource state from macOS; Android app reflects effective host state and no longer drifts.
- UC-003: PRC Camera Host is streaming/idle; status badge reflects real state instead of staying at `Starting`.

## Acceptance Criteria
1. Changing any macOS resource checkbox triggers host toggle apply automatically.
2. Android host-status polling updates local toggle prefs when host resource state differs.
3. When host state is synced from macOS, Android UI toggles match within polling interval.
4. PRC Camera Host badge transitions from `Starting` to `Enabled`/`Streaming` during normal operation.
5. Existing tests pass; added behavior is validated with real host status probes.

## Constraints / Dependencies
- Use existing `/api/status` and `/api/toggles` APIs.
- Must work with current real device pairing flow.

## Assumptions
- Host status payload includes paired phone identity for same-device reconciliation.
- Programmatic checkbox state updates in AppKit should not trigger user-action handlers; still guard explicitly.

## Open Risks
- Aggressive bidirectional sync can cause temporary race if both devices toggle rapidly.
