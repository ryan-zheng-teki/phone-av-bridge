# Investigation Notes - QR-Only Pairing (Remove UDP Discovery)

## Context

- Ticket: `qr-only-pairing-remove-udp`
- Goal: remove UDP host auto-discovery and keep only explicit QR-based pairing.

## Sources Consulted

- `/Users/normy/autobyteus_org/phone-av-bridge/android-phone-av-bridge/app/src/main/java/org/autobyteus/phoneavbridge/MainActivity.kt`
- `/Users/normy/autobyteus_org/phone-av-bridge/android-phone-av-bridge/app/src/main/java/org/autobyteus/phoneavbridge/pairing/PairingCoordinator.kt`
- `/Users/normy/autobyteus_org/phone-av-bridge/android-phone-av-bridge/app/src/main/java/org/autobyteus/phoneavbridge/sync/HostStateRefresher.kt`
- `/Users/normy/autobyteus_org/phone-av-bridge/android-phone-av-bridge/app/src/main/java/org/autobyteus/phoneavbridge/network/HostDiscoveryClient.kt`
- `/Users/normy/autobyteus_org/phone-av-bridge/android-phone-av-bridge/app/src/main/res/values/strings.xml`
- `/Users/normy/autobyteus_org/phone-av-bridge/android-phone-av-bridge/app/src/main/res/layout/activity_main.xml`
- `/Users/normy/autobyteus_org/phone-av-bridge/desktop-av-bridge-host/desktop-app/server.mjs`
- `/Users/normy/autobyteus_org/phone-av-bridge/desktop-av-bridge-host/tests/integration/discovery.test.mjs`
- `/Users/normy/autobyteus_org/phone-av-bridge/desktop-av-bridge-host/tests/integration/server.test.mjs`
- `/Users/normy/autobyteus_org/phone-av-bridge/macos-camera-extension/samplecamera/ViewController.swift`
- `/Users/normy/autobyteus_org/phone-av-bridge/README.md`
- `/Users/normy/autobyteus_org/phone-av-bridge/desktop-av-bridge-host/README.md`
- `/Users/normy/autobyteus_org/phone-av-bridge/AGENTS.md`

## Key Findings

1. Android currently supports two pair entry paths:
- UDP discovery path via `Pair Host` -> `PairingCoordinator.discoverHostsForPair(...)` -> `HostDiscoveryClient.discoverAll(...)`.
- QR path via `Scan QR Pairing` -> `redeemQrPayload(...)`.

2. Android unpaired UI currently depends on discovery preview state:
- `discoveredHostPreview` / `discoveredHostCandidates` fields in `MainActivity`.
- periodic preview refresh (`refreshHostPreviewIfUnpaired`) calls `HostStateRefresher.discoverHostPreview(...)`.

3. Host server currently opens UDP discovery socket in `startServer(...)`:
- `dgram` import + `DISCOVERY_MAGIC` protocol.
- runtime flags `ENABLE_DISCOVERY` and `DISCOVERY_PORT`.
- integration test verifies UDP reply (`tests/integration/discovery.test.mjs`).

4. QR bootstrap/token APIs are already complete and independent of UDP:
- `POST /api/bootstrap/qr-token`
- `POST /api/bootstrap/qr-redeem`

5. macOS camera app UI still references discovery wording:
- `"Host discovery + pairing service is running (port 8787 / UDP 39888)."`
- `"Android cannot pair/discover until started."`

6. Documentation still advertises discovery behavior in root and host READMEs and `AGENTS.md` runbook language.

## Constraints

- Must preserve pairing/unpair behavior, only remove discovery transport and discovery UX copy.
- Must not leave dead/legacy compatibility branches for UDP discovery.
- Existing QR pairing flow should remain default and explicit.

## Open Unknowns / Questions

- None blocking implementation. Scope and behavior are clear from existing code and user direction.

## Implications For Design

- Scope is cross-layer (Android app + host server + macOS host UI copy + tests + docs), so treat as `Medium`.
- Replace dual-entry pairing UX with QR-only entry on Android (single explicit action when unpaired).
- Remove UDP discovery runtime and tests from host server in the same ticket.
- Update docs/runbook to remove discovery references and make QR-only flow canonical.
