# Implementation Plan

- Ticket: `android-host-selection-and-qr-pairing`
- Date: 2026-02-20
- Scope Classification: `Medium`
- Plan Status: `Ready For Implementation`

## Upstream Artifacts

- Investigation: `/Users/normy/autobyteus_org/phone-av-bridge/tickets/in-progress/android-host-selection-and-qr-pairing/investigation-notes.md`
- Requirements: `/Users/normy/autobyteus_org/phone-av-bridge/tickets/in-progress/android-host-selection-and-qr-pairing/requirements.md` (`Design-ready`)
- Proposed Design: `/Users/normy/autobyteus_org/phone-av-bridge/tickets/in-progress/android-host-selection-and-qr-pairing/proposed-design.md` (`v2`)
- Runtime Call Stacks: `/Users/normy/autobyteus_org/phone-av-bridge/tickets/in-progress/android-host-selection-and-qr-pairing/future-state-runtime-call-stack.md` (`v2`)
- Runtime Review Gate: `/Users/normy/autobyteus_org/phone-av-bridge/tickets/in-progress/android-host-selection-and-qr-pairing/future-state-runtime-call-stack-review.md` (`Go Confirmed`)

## Go / No-Go

- Decision: `Go`
- Evidence: review round 3 reached `Go Confirmed` with clean streak `2` and no unresolved blockers.

## Dependency Sequencing

1. Host bootstrap + QR token backend contract (`server.mjs`, integration tests).
2. Android host discovery model/network refactor (`DiscoveredHost`, `HostDiscoveryClient`, `HostApiClient`).
3. Android unpaired pairing UX (`activity_main.xml`, `MainActivity.kt`, strings).
4. Host web QR panel (`desktop static app.js/index.html`).
5. Android QR scan wiring + tests.

## Task Plan

1. T-001 Host contract extension
- Files: `desktop-av-bridge-host/desktop-app/server.mjs`, `desktop-av-bridge-host/tests/integration/discovery.test.mjs`, `desktop-av-bridge-host/tests/integration/server.test.mjs`, `desktop-av-bridge-host/tests/integration/qr-pairing.test.mjs` (new)
- Outcome: bootstrap includes host metadata + QR token issue/redeem endpoints with one-time TTL semantics.

2. T-002 Android discovery list model
- Files: `android-phone-av-bridge/.../model/DiscoveredHost.kt`, `android-phone-av-bridge/.../network/HostDiscoveryClient.kt`, `android-phone-av-bridge/.../network/HostApiClient.kt`
- Outcome: Android can collect and parse multiple hosts plus QR-redeem response.

3. T-003 Android host selection UX
- Files: `android-phone-av-bridge/.../MainActivity.kt`, `android-phone-av-bridge/.../res/layout/activity_main.xml`, `android-phone-av-bridge/.../res/values/strings.xml`
- Outcome: selectable host list + quick pair + sticky selected host + explicit pair/unpair.

4. T-004 Host QR display UX
- Files: `desktop-av-bridge-host/desktop-app/static/index.html`, `desktop-av-bridge-host/desktop-app/static/app.js`
- Outcome: host operator can generate/refresh QR payload for scan.

5. T-005 Android QR scan flow
- Files: `android-phone-av-bridge/app/build.gradle.kts`, `android-phone-av-bridge/.../MainActivity.kt` (+ scanner integration)
- Outcome: scan QR token and redeem to bootstrap target pair flow.

6. T-006 Verification
- Unit/Integration: host `npm test`; Android unit tests and build.
- Manual/E2E: manual multi-host selection + QR pair + unpair.

## Requirement Traceability

| Requirement | Use Case | Tasks | Verification |
| --- | --- | --- | --- |
| R-001 explicit host selection | UC-001 | T-002, T-003 | Android tests + manual multi-host pair |
| R-002 unpair then pair another host | UC-002 | T-003 | Android tests + manual verification |
| R-003 QR pairing path | UC-003 | T-001, T-004, T-005 | Host integration + Android manual scan flow |
| R-004 single-host quick pair | UC-004 | T-003 | Android tests + manual single-host flow |

## Test Strategy

- Host integration tests: `cd desktop-av-bridge-host && npm test`
- Android tests/build: `cd android-phone-av-bridge && ./gradlew testDebugUnitTest assembleDebug`
- Manual checks:
  - two hosts on same LAN -> selection list has both -> pair selected one.
  - unpair -> choose other host -> pair succeeds.
  - host-generated QR -> phone scan -> pair succeeds.

## Risks And Mitigations

- Risk: QR scanner dependency introduces APK/runtime friction.
  - Mitigation: keep scanner integration minimal and isolated; fallback remains host-list pairing.
- Risk: token replay/security drift.
  - Mitigation: TTL + single-use token map + tests for expiry/reuse rejection.
- Risk: MainActivity complexity growth.
  - Mitigation: isolate pair path helpers and keep selection state transitions explicit.
