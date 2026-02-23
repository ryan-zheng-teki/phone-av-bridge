# Proposed Design

- Ticket: `ios-companion-streaming-support`
- Date: 2026-02-23
- Scope: `Medium`
- Version: `v6`
- Requirements Source: `/Users/normy/autobyteus_org/phone-av-bridge/tickets/in-progress/ios-companion-streaming-support/requirements.md` (`Refined`)

## Current-State Summary (As-Is)

- iOS QR pairing is implemented (scan/parse/redeem/pair).
- Scanner sheet still exposes manual payload fallback UI (`QR Payload (fallback)` + submit button).
- Android has no equivalent fallback UI; this is parity drift.

## Target-State Summary (To-Be)

- Remove manual payload fallback UI/actions from iOS scanner sheet.
- Keep scan-only flow with parser + redeem + pair logic unchanged.
- Keep Pair and Scan QR buttons on separate rows (Android parity).

## Legacy Removal Policy

- Remove manual fallback controls and text from scanner sheet.
- Do not introduce alternate non-scan QR entry paths in this iteration.

## Change Inventory

| Change ID | Type | File | Summary |
| --- | --- | --- | --- |
| C-001..C-048 | Existing | previous iterations | Baseline retained. |
| C-049 | Modify | `ios-phone-av-bridge/Sources/PhoneAVBridgeIOS/QrScannerSheet.swift` | Remove manual payload editor/submit controls; keep camera scan + cancel only. |
| C-050 | Modify | `ios-phone-av-bridge-app/README.md` | Remove fallback mention from app behavior docs. |
| C-051 | Modify | ticket artifacts | Iteration 6 workflow updates and verification evidence. |

## File/Module Responsibilities

- `QrScannerSheet.swift`
  - Presents scan UI and handles captured QR payload callback.
  - Shows scan-unavailable status text when camera cannot be used.
- `MainScreenViewModel.swift`
  - No behavior change in parser/redeem/pair path.

## Public API Changes

- No public API changes.
- No host API changes.

## Naming Decisions

- Keep `QrPairingSheet` and `QrPairPayloadParser` naming unchanged.
- Remove "fallback" wording from UI copy.

## Naming-Drift Check

| Item | Current Responsibility | Name Match | Action |
| --- | --- | --- | --- |
| `QrPairingSheet` | scan QR flow UI | Yes | Modify internals only |
| `scanQrButton` | trigger QR scan flow | Yes | N/A |

## Dependency Flow

1. User taps `Scan QR Pairing`.
2. Scanner sheet opens and attempts camera scan.
3. On scanned payload, callback forwards raw payload to view-model.
4. View-model parser/redeem/pair flow proceeds unchanged.

## SoC Risks / Mitigations

- Risk: scanner sheet becomes non-actionable on simulator.
  - Mitigation: explicit status text indicates camera unavailability; accepted trade-off for Android parity.
- Risk: removal accidentally breaks scan callback.
  - Mitigation: keep callback path untouched and validate via tests/build.

## Decommission / Cleanup Plan

- Remove fallback text editor and submit button from scanner sheet.
- Remove fallback wording from README docs.

## Use-Case Coverage Matrix

| use_case_id | Requirement | Use Case | Primary | Fallback | Error | Runtime Call Stack Section |
| --- | --- | --- | --- | --- | --- | --- |
| UC-011 | R-011 | active scan QR action | Yes | N/A | Yes | UC-011 |
| UC-012 | R-012 | QR payload parse validation | Yes | N/A | Yes | UC-012 |
| UC-013 | R-013 | redeem token then pair | Yes | N/A | Yes | UC-013 |
| UC-014 | R-014 | separate-row action layout parity | Yes | N/A | N/A | UC-014 |
| UC-015 | R-015 | no manual fallback UI | Yes | N/A | N/A | UC-015 |

## Open Questions

1. Whether to add explicit "simulator unsupported for QR scan" docs in root troubleshooting section.
