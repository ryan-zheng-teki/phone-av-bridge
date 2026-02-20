# Requirements

- Ticket: `android-host-selection-and-qr-pairing`
- Date: 2026-02-20
- Status: `Design-ready`
- Scope Classification: `Medium`
- Triage Rationale: Cross-layer work across Android discovery UX, Android pairing flow/state model, host bootstrap metadata, and optional QR pairing path.

## Goal / Problem Statement

Current Android pairing auto-selects a host from UDP first response. In multi-host home networks, users can pair to the wrong host. We need explicit host selection while preserving fast local discovery convenience and supporting optional QR pairing.

## In-Scope Use Cases

- UC-001: While unpaired, user sees discovered host list and selects one explicit host to pair.
- UC-002: User can unpair and then pair to a different discovered host.
- UC-003: User can pair via QR code path instead of UDP-discovered host list.
- UC-004: If exactly one host is discovered, user can still pair quickly (user-confirmed action, not background auto-pair).

## Acceptance Criteria

1. App no longer auto-pairs based on first UDP response.
2. App exposes host selection UI before calling `/api/pair`.
3. Selected host is used consistently for status polling and toggle publishing after pair.
4. Unpair keeps working and returns app to unpaired selectable-host state.
5. QR pairing path exists and can initiate pairing without UDP list dependency.
6. Existing host `/api/pair` contract remains usable.
7. While unpaired, host list refreshes periodically and deduplicates candidates by `baseUrl`.
8. If exactly one host is available, UI provides quick user-confirmed pair action (still explicit tap).
9. Once user selects a host candidate, that target remains sticky for the current pairing attempt.

## Constraints / Dependencies

- Keep UDP discovery available for convenience.
- Do not retain old auto-pair fallback behavior in production flow.
- Keep Android unpair semantics and host-side pair-code validation intact.
- Preserve existing media toggle behavior once paired.

## Assumptions

- Host can provide additional non-breaking bootstrap metadata fields.
- Android UI can include list + QR actions without introducing new activity architecture.
- QR pairing will use an explicit host-generated short-lived token contract (`/api/bootstrap/qr`) to avoid exposing long-lived reusable pairing data.

## Design Decisions (Resolved For This Ticket)

1. QR contract: use host-generated short-lived single-use token (opaque string) with TTL.
2. Single-host UX: present a `Quick Pair` CTA but still require user tap.
3. Refresh cadence: unpaired discovery refresh every ~3-5 seconds.
4. Selection stickiness: selected host stays fixed for current pair attempt; refresh updates list but does not silently replace selection.
5. Host identity presentation: show `displayName` when available, fallback to `baseUrl`.

## Open Questions / Risks

1. Camera lifecycle for QR scanning must not interfere with existing RTSP camera use path in the same activity lifecycle.
2. Token replay window and persistence behavior need explicit host-side tests.
