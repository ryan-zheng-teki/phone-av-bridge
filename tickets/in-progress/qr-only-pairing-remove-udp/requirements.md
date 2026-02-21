# Requirements - QR-Only Pairing (Remove UDP Discovery)

## Status

- `Design-ready`

## Goal / Problem Statement

Pairing should be explicit and deterministic via QR code only. UDP auto-discovery and discovery-driven pairing create ambiguity in multi-host LAN environments and are no longer needed.

## Scope Classification

- Classification: `Medium`
- Rationale:
  - touches multiple runtime layers (Android app, host server runtime, tests, docs, macOS host app messaging),
  - removes a transport mechanism (UDP discovery),
  - requires UX/state-flow updates in Android and host messaging/docs.

## In-Scope Use Cases

- `UC-001`: Android user pairs to host by scanning host QR token; pairing succeeds and state is persisted.
- `UC-002`: Android user unpairs and can re-pair by scanning a newly generated QR token.
- `UC-003`: Host runtime starts/stops without UDP discovery socket while QR token endpoints remain available.
- `UC-004`: Documentation and UI copy reflect QR-only pairing path (no discovery references).

## Acceptance Criteria

1. Android app no longer performs UDP discovery or discovery preview logic.
2. Android unpaired pairing action is QR-based only.
3. Host server no longer imports/opens UDP discovery socket and no longer exposes discovery env controls.
4. Discovery integration test is removed or replaced to match QR-only behavior.
5. macOS host UI text no longer references UDP/discovery pairing.
6. Project docs (`README.md`, `desktop-av-bridge-host/README.md`, `AGENTS.md`) reflect QR-only pairing flow.
7. Existing QR token issuance/redeem + pair/unpair behavior remains functional.

## Constraints / Dependencies

- Keep current QR token API contract stable (`/api/bootstrap/qr-token`, `/api/bootstrap/qr-redeem`).
- No backward compatibility retention for UDP discovery code.
- Maintain existing paired host status/toggle behavior.

## Assumptions

- User wants QR scanning as the single pairing mechanism across supported platforms.
- LAN/advertised host settings still matter for QR payload `baseUrl` correctness.
- No external clients depend on UDP discovery protocol after this change.

## Risks

- Removing discovery may impact users who relied on one-tap auto-pair.
- Android UI regressions if pair/unpair controls are not simplified clearly.
- Possible leftover references in docs/tests if cleanup is incomplete.

## Open Questions

- None blocking; requirements are implementation-ready.
