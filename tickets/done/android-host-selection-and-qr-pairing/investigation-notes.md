# Investigation Notes

- Ticket: `android-host-selection-and-qr-pairing`
- Date: 2026-02-20
- Stage: Understanding pass (Stage 0)

## Sources Consulted

- `/Users/normy/autobyteus_org/phone-av-bridge/android-phone-av-bridge/app/src/main/java/org/autobyteus/phoneavbridge/network/HostDiscoveryClient.kt`
- `/Users/normy/autobyteus_org/phone-av-bridge/android-phone-av-bridge/app/src/main/java/org/autobyteus/phoneavbridge/MainActivity.kt`
- `/Users/normy/autobyteus_org/phone-av-bridge/android-phone-av-bridge/app/src/main/java/org/autobyteus/phoneavbridge/network/HostApiClient.kt`
- `/Users/normy/autobyteus_org/phone-av-bridge/android-phone-av-bridge/app/src/main/java/org/autobyteus/phoneavbridge/store/AppPrefs.kt`
- `/Users/normy/autobyteus_org/phone-av-bridge/android-phone-av-bridge/app/src/main/res/layout/activity_main.xml`
- `/Users/normy/autobyteus_org/phone-av-bridge/android-phone-av-bridge/app/src/main/res/values/strings.xml`
- `/Users/normy/autobyteus_org/phone-av-bridge/android-phone-av-bridge/app/build.gradle.kts`
- `/Users/normy/autobyteus_org/phone-av-bridge/android-phone-av-bridge/app/src/main/AndroidManifest.xml`
- `/Users/normy/autobyteus_org/phone-av-bridge/desktop-av-bridge-host/desktop-app/server.mjs`
- `/Users/normy/autobyteus_org/phone-av-bridge/desktop-av-bridge-host/core/session-controller.mjs`
- `/Users/normy/autobyteus_org/phone-av-bridge/desktop-av-bridge-host/tests/integration/discovery.test.mjs`
- `/Users/normy/autobyteus_org/phone-av-bridge/desktop-av-bridge-host/tests/integration/server.test.mjs`

## Current-State Findings

1. Android currently sends UDP broadcast discovery (`PHONE_AV_BRIDGE_DISCOVER_V1`) and accepts only the first response packet. This is effectively first-responder selection and does not expose host choice UI.
2. Pairing is initiated by Android (`/api/pair`) after discovery. Host validates pair code but does not run any phone-side approval UI flow.
3. Android UI has one `Pair Host` button and no discovered-host list. While unpaired, background preview refresh can overwrite the saved host candidate.
4. Host maintains a single `phone` identity state (`deviceName`/`deviceId`) in session controller. No multi-phone session table exists.
5. Host discovery response currently includes `service`, `host`, `port`, `pairingCode`, `baseUrl`. No host display metadata or stable host ID is included.
6. No QR generation/scanning implementation exists in current Android or host code paths.
7. Android already has camera permission and runtime camera usage; adding QR scan is feasible from permission standpoint.

## Constraints

1. Keep UDP discovery convenience for single-host scenarios.
2. Eliminate accidental pairing to wrong host on multi-host networks.
3. Preserve explicit unpair behavior.
4. Introduce optional QR pairing without removing current HTTP pair API compatibility.
5. Keep architecture simple and avoid adding legacy dual behavior that is hard to reason about.

## Observed Risks

1. If host list selection is added but discovery remains one-response API, UX stays ambiguous. Discovery data model must become multi-host.
2. If QR payload embeds long-lived pair code without TTL/signature/nonce semantics, screenshot replay risk remains.
3. If host selection state is not persisted cleanly, background preview may keep replacing user-selected host.
4. If existing tests remain single-host only, regressions in multi-host behavior may slip.

## Unknowns / Open Questions

1. Should QR payload be plain bootstrap data with short TTL only, or signed token (HMAC) from host secret?
2. Should single discovered host allow one-tap quick pair, or still require explicit row tap?
3. Should host selection list be manual refresh only, or auto-refresh every N seconds while unpaired?
4. Should selected host remain sticky until user clears/unpairs, even if discovery sees newer hosts?

## Implications for Requirements/Design

1. Android discovery layer must be refactored from `discover(): DiscoveredHost?` to an API returning multiple candidates with dedupe/sort.
2. Android UI must replace single-candidate pairing with explicit host selection while keeping a fast path for exactly one host.
3. Pair flow should support two entry paths: UDP selected host and QR scanned host.
4. Host bootstrap contract likely needs non-breaking extension fields (`hostId`, `displayName`, maybe `platform`) to improve selection clarity.
5. Tests must be expanded for multi-host selection behavior and QR parse/validate logic.

## Initial Scope Triage Signal

- Estimated touched areas: Android networking + Android UI + Android state persistence + host bootstrap fields + tests.
- This is cross-layer and user-facing with protocol shape changes.
- Preliminary classification: `Medium`.
