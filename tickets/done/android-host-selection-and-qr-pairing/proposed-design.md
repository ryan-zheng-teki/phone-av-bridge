# Proposed Design

- Ticket: `android-host-selection-and-qr-pairing`
- Date: 2026-02-20
- Scope: `Medium`
- Version: `v2`
- Requirements Source: `/Users/normy/autobyteus_org/phone-av-bridge/tickets/in-progress/android-host-selection-and-qr-pairing/requirements.md` (`Design-ready`)

## Current-State Summary (As-Is)

- Android discovery API returns at most one host (`DiscoveredHost?`) and consumes first UDP responder.
- Android UI exposes one `Pair Host` button and does not provide host candidate selection.
- Android stores one host base URL/pair code, and unpaired preview may overwrite candidate.
- Host bootstrap payload has no explicit host display metadata or host identifier for user-facing disambiguation.
- No QR pairing flow exists in Android or host runtime.

## Target-State Summary (To-Be)

- Android discovery gathers multiple host candidates and surfaces a selectable list.
- Pairing is always user-confirmed against a selected host candidate.
- For exactly one discovered host, app offers a quick-pair CTA (still explicit tap).
- Host bootstrap adds non-breaking metadata: `hostId`, `displayName`, `platform`.
- Optional QR pairing path supports scanning a host-rendered QR that encodes short-lived single-use pairing token reference.
- Host provides QR token endpoints to issue and redeem short-lived single-use tokens for pairing bootstrap.

## Change Inventory

| Change ID | Type | File | Summary |
| --- | --- | --- | --- |
| C-001 | Modify | `android-phone-av-bridge/app/src/main/java/org/autobyteus/phoneavbridge/model/DiscoveredHost.kt` | Expand model for host metadata and optional QR token fields. |
| C-002 | Modify | `android-phone-av-bridge/app/src/main/java/org/autobyteus/phoneavbridge/network/HostDiscoveryClient.kt` | Return multi-host candidate list with dedupe and stable ordering. |
| C-003 | Modify | `android-phone-av-bridge/app/src/main/java/org/autobyteus/phoneavbridge/MainActivity.kt` | Replace implicit first-host pairing with selected-host flow + quick pair + QR entry path. |
| C-004 | Modify | `android-phone-av-bridge/app/src/main/res/layout/activity_main.xml` | Add discovered hosts list UI and QR action controls. |
| C-005 | Modify | `android-phone-av-bridge/app/src/main/res/values/strings.xml` | Add host selection and QR UX strings. |
| C-006 | Modify | `android-phone-av-bridge/app/build.gradle.kts` | Add QR scanning dependency (ML Kit or ZXing wrapper). |
| C-007 | Modify | `desktop-av-bridge-host/desktop-app/server.mjs` | Extend bootstrap payload and add QR token issue/redeem endpoints. |
| C-008 | Modify | `desktop-av-bridge-host/tests/integration/discovery.test.mjs` | Validate extended bootstrap fields are present and backward-compatible. |
| C-009 | Add | `desktop-av-bridge-host/tests/integration/qr-pairing.test.mjs` | Verify token issuance, expiry, one-time redemption, and pairing behavior. |
| C-010 | Modify | `android-phone-av-bridge/app/src/main/java/org/autobyteus/phoneavbridge/network/HostApiClient.kt` | Add API methods for QR bootstrap redemption flow. |
| C-011 | Modify | `android-phone-av-bridge/app/src/androidTest/java/org/autobyteus/phoneavbridge/MainActivityTest.kt` | Cover host selection, quick pair, and unpair flows. |
| C-012 | Modify | `desktop-av-bridge-host/desktop-app/static/index.html` | Add QR pairing panel and generate/refresh QR action. |
| C-013 | Modify | `desktop-av-bridge-host/desktop-app/static/app.js` | Call QR token endpoint and render QR payload for scan. |

## File/Module Responsibilities

### Android

- `model/DiscoveredHost.kt`
  - Responsibility: immutable host candidate model used by UI/discovery/pairing flow.
  - Inputs: UDP bootstrap payload, QR bootstrap payload.
  - Outputs: normalized candidate objects for selection.

- `network/HostDiscoveryClient.kt`
  - Responsibility: UDP discovery transport and candidate collection.
  - Inputs: timeout, broadcast targets.
  - Outputs: list of discovered candidates.

- `MainActivity.kt`
  - Responsibility: unpaired host selection UX, pair/unpair orchestration, status sync.
  - Inputs: discovered candidates, user selection, QR scan results.
  - Outputs: explicit `/api/pair` requests to selected host.
  - State rule: selected candidate is sticky during current pair attempt and cannot be replaced by background refresh.

- `network/HostApiClient.kt`
  - Responsibility: host HTTP integration for pair/unpair/status/toggles and QR bootstrap redemption.
  - Inputs: selected host data / qr token.
  - Outputs: parsed host API responses.

### Host

- `desktop-app/server.mjs`
  - Responsibility: bootstrap API contract, pair/unpair endpoints, discovery responder, QR token lifecycle endpoints.
  - Inputs: HTTP requests and UDP discovery probes.
  - Outputs: bootstrap payloads, pair status, token redemption response.

- `desktop-app/static/app.js` + `desktop-app/static/index.html`
  - Responsibility: host-side QR display workflow (issue token, render QR data, refresh when expired).
  - Inputs: host operator click events.
  - Outputs: scannable QR payload for Android app.

- `tests/integration/*.mjs`
  - Responsibility: enforce contract for discovery + QR token behavior + pairing correctness.

## Public API Changes

- Existing (extended, non-breaking): `GET /api/bootstrap`
  - Add fields in `bootstrap` payload:
    - `hostId` (stable host instance identifier)
    - `displayName` (friendly machine name)
    - `platform` (`linux`/`darwin`)

- New:
  - `POST /api/bootstrap/qr-token` -> returns `{ token, expiresAt }`
  - `POST /api/bootstrap/qr-redeem` with `{ token }` -> returns bootstrap payload for pairing and atomically marks token used.

## Naming Decisions

- `DiscoveredHost` remains name; broadened fields keep concept stable.
- `discoverAll(...)` for multi-host UDP collection API to avoid ambiguity of legacy `discover(...)` semantics.
- Host endpoint naming:
  - `qr-token` (issue)
  - `qr-redeem` (consume)
  These are action-clear and lifecycle-explicit.

## Naming-Drift Check

- `HostDiscoveryClient` still matches responsibility after list-return refactor: `N/A` rename.
- `MainActivity` owns more orchestration than ideal, but this ticket keeps activity architecture; no rename now.
- If QR flow complexity grows, split into dedicated `QrPairingCoordinator` in follow-up.

## Dependency Flow

1. UI triggers discovery -> `HostDiscoveryClient.discoverAll`.
2. User selects candidate OR scans QR -> `HostApiClient` resolves bootstrap data.
3. `MainActivity` calls `/api/pair` with explicit chosen target.
4. Session/status/toggles continue against selected host.
5. Host token endpoints remain independent from `SessionController`; they only produce bootstrap-level pairing data.

## SoC Risks / Mitigations

- Risk: `MainActivity` complexity increases.
  - Mitigation: isolate discovery list transform and QR parse/submit helpers into private functions now; extract coordinator later if needed.
- Risk: token-state logic bloats `server.mjs`.
  - Mitigation: keep a small in-memory token registry helper inside server file for this ticket; extract to module only if reused.

## Use-Case Coverage Matrix

| use_case_id | primary path | fallback path | error path | mapped runtime sections |
| --- | --- | --- | --- | --- |
| UC-001 | Yes | Yes | Yes | `future-state-runtime-call-stack.md` UC-001 |
| UC-002 | Yes | N/A | Yes | `future-state-runtime-call-stack.md` UC-002 |
| UC-003 | Yes | Yes | Yes | `future-state-runtime-call-stack.md` UC-003 |
| UC-004 | Yes | N/A | Yes | `future-state-runtime-call-stack.md` UC-004 |

## Legacy/Compatibility Policy

- No legacy auto-pair branch based on first UDP responder will remain in the active pairing path.
- Discovery remains as convenience input only; final pair target is always explicit user action.
