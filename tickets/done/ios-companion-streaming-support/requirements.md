# Requirements

- Ticket: `ios-companion-streaming-support`
- Date: 2026-02-23
- Status: `Refined`
- Scope Classification: `Medium`
- Triage Rationale: iOS QR parity is functionally delivered, but manual QR payload fallback UI diverges from Android behavior and must be removed for strict parity.

## Goal / Problem Statement

Keep iOS QR pairing fully functional while removing manual QR payload fallback UI so iOS matches Android’s scan-only QR interaction model.

## In-Scope Use Cases

- UC-001: Build and run an installable iOS app bundle in simulator from this repo.
- UC-002: App renders Android-parity controller UI using `PhoneBridgeMainScreen` state/view-model.
- UC-003: App can discover/select host and execute pair/switch/unpair actions against host APIs.
- UC-004: App can publish camera/microphone/speaker toggles with lens/orientation and optional stream URL fields.
- UC-005: App-level simulator E2E test validates primary controller flow against mock host runtime.
- UC-006: A single command/script can run host mock + simulator E2E app test deterministically.
- UC-007: Docs and ticket artifacts clearly describe runnable app workflow and remaining device-only gaps.
- UC-008: GitHub release workflow can build/package/upload an iOS simulator app zip artifact.
- UC-009: Release trigger controls support iOS in both manual (`workflow_dispatch`) and tag selector (`+targets=ios`) paths.
- UC-010: Release notes and release docs list iOS artifact consistently with existing platforms.
- UC-011: iOS `Scan QR Pairing` button executes real QR flow (no placeholder/copy).
- UC-012: QR payload parsing accepts host QR payload format and rejects invalid payloads with user-facing error.
- UC-013: QR redeem endpoint flow (`/api/bootstrap/qr-redeem`) is used before pair and results in paired state on success.
- UC-014: Pair and Scan QR actions stay on separate rows with Android-like affordance and enabled/disabled behavior.
- UC-015: iOS scanner UI has no manual QR payload fallback editor or submit action.

## Acceptance Criteria

1. iOS UI no longer shows `Scan QR Pairing (Coming Soon)`.
2. `Scan QR Pairing` action is enabled when unpaired and disabled while paired or during pairing progress.
3. iOS QR scan flow supports realtime camera scanning on iOS devices where camera permission/hardware is available.
4. Scanner sheet no longer renders `QR Payload (fallback)` input field and no manual submit button.
5. Parsed QR payload must require valid `token` and valid `http(s)` `baseUrl`; invalid payload shows explicit invalid-QR error.
6. On successful QR parse and redeem, iOS pairs host using redeemed bootstrap pairing code and reaches paired-ready state.
7. On QR token failure (expired/used/invalid), iOS surfaces mapped error equivalent to Android messaging.
8. Pair and Scan QR buttons remain in different rows and use consistent full-width action layout.
9. Existing pair/switch/unpair and toggle behaviors remain functional (no regression).
10. Existing package tests plus QR-related tests pass.
11. App-level simulator E2E (existing non-QR path) still passes.
12. Release workflow changes from iteration 4 remain intact and passing static validation.

## Constraints / Dependencies

- Existing host contract remains source of truth:
  - `GET /api/bootstrap`
  - `POST /api/bootstrap/qr-token`
  - `POST /api/bootstrap/qr-redeem`
  - `POST /api/pair`
  - `POST /api/unpair`
  - `GET /api/status`
  - `POST /api/toggles`
  - `GET /api/speaker/stream`
- Simulator environment available on current machine via Xcode 26.1.1.
- Physical iPhone is unavailable in current implementation window.
- iOS package must continue compiling under Swift Package workflow used by existing tests.

## Assumptions

- QR payload emitted by host remains JSON payload containing `token` and `baseUrl`.
- iOS app project (`PhoneAVBridgeIOSApp.xcodeproj`) remains committed and buildable in CI.

## Open Questions / Risks

1. Without manual fallback, simulator cannot execute end-to-end QR scan path.
2. Camera permission denial UX in SwiftUI needs clear retry guidance.
3. Long-run/background capture behavior remains device-only and out of simulator scope.
4. App Store/TestFlight distribution remains out of scope.

## Out Of Scope (This Iteration)

- Physical iPhone RTSP camera/microphone validation.
- App Store/TestFlight distribution, notarization, and device-signing pipeline.
- Host protocol redesign.
