# Investigation Notes

## Context
- User reports confusing UX when not paired:
  - Android shows `Host: not selected` with no visible candidate host.
  - macOS host app shows `Phone: unknown` while not paired.
- Goal: show useful pre-pair identity on both sides.

## Sources Consulted
- `/Users/normy/autobyteus_org/phone-resource-companion/android-resource-companion/app/src/main/java/org/autobyteus/resourcecompanion/MainActivity.kt`
- `/Users/normy/autobyteus_org/phone-resource-companion/android-resource-companion/app/src/main/java/org/autobyteus/resourcecompanion/network/HostDiscoveryClient.kt`
- `/Users/normy/autobyteus_org/phone-resource-companion/android-resource-companion/app/src/main/java/org/autobyteus/resourcecompanion/network/HostApiClient.kt`
- `/Users/normy/autobyteus_org/phone-resource-companion/android-resource-companion/app/src/main/res/values/strings.xml`
- `/Users/normy/autobyteus_org/phone-resource-companion/host-resource-agent/linux-app/server.mjs`
- `/Users/normy/autobyteus_org/phone-resource-companion/host-resource-agent/core/session-controller.mjs`
- `/Users/normy/autobyteus_org/phone-resource-companion/macos-camera-extension/samplecamera/ViewController.swift`

## Findings
1. Android UI currently hardcodes unpaired host text as `Host: not selected`.
- No proactive discovery preview is shown before pressing Pair.

2. macOS UI reads phone identity from host `/api/status` only.
- Host state currently clears `phone` metadata on unpair.
- Therefore macOS often shows `Phone: unknown` while not paired.

3. Host has no explicit pre-pair presence endpoint.
- Android only sends identity during `/api/pair` and `/api/toggles`.
- No identity update path exists while unpaired.

## Unknowns
- Exact desired wording for pre-pair labels (can be refined later).

## Implications
- Add lightweight host presence API (`/api/presence`) and controller method to store phone identity without pairing.
- Android should run non-intrusive host preview discovery while unpaired, show discovered host, and publish presence.
- Keep phone identity in host status across unpair so macOS can still show who is nearby/last-seen.
