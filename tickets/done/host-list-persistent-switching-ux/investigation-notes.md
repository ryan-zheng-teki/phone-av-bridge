# Investigation Notes - Host List Persistent Switching UX

## Sources Consulted

- `/Users/normy/autobyteus_org/phone-av-bridge/android-phone-av-bridge/app/src/main/java/org/autobyteus/phoneavbridge/MainActivity.kt`
- `/Users/normy/autobyteus_org/phone-av-bridge/android-phone-av-bridge/app/src/main/java/org/autobyteus/phoneavbridge/pairing/PairingCoordinator.kt`
- `/Users/normy/autobyteus_org/phone-av-bridge/android-phone-av-bridge/app/src/main/java/org/autobyteus/phoneavbridge/network/HostDiscoveryClient.kt`
- `/Users/normy/autobyteus_org/phone-av-bridge/android-phone-av-bridge/app/src/main/java/org/autobyteus/phoneavbridge/sync/HostStateRefresher.kt`
- `/Users/normy/autobyteus_org/phone-av-bridge/android-phone-av-bridge/app/src/main/res/layout/activity_main.xml`
- `/Users/normy/autobyteus_org/phone-av-bridge/android-phone-av-bridge/app/src/main/res/values/strings.xml`
- User reports from live device usage in this thread:
  - host list appears in pairing flow but not persistently after pairing
  - users cannot see alternate available hosts once paired
  - desired UX: always-visible host list + explicit host switching by selection

## Current Findings

0. Entrypoints and execution boundaries (validated):
- UI intent entry: `MainActivity.setupListeners()` -> `pairButton.setOnClickListener`.
- Pairing orchestration entry: `MainActivity.beginPairSelectionFlow()` and `MainActivity.pairHost(...)`.
- Unpair orchestration entry: `MainActivity.unpairHost()`.
- Discovery refresh boundary: periodic ticker `MainActivity.ensureHostStatusTicker()` currently calls `refreshHostPreviewIfUnpaired()`.
- Discovery/provider boundary: `PairingCoordinator.discoverHostsForPair(...)` -> `HostDiscoveryClient.discoverAll(...)` (+ fallback bootstrap fetch).
- Network boundary: `HostApiClient.pair(...)`, `HostApiClient.unpair(...)`, `HostApiClient.fetchStatus(...)`.

1. Discovery-path split causes UX mismatch:
- Main screen status uses preview-oriented state and current pairing status.
- Pairing action runs full host discovery; this can surface more hosts than visible in non-action UI moments.

2. Pairing state currently biases "single active host":
- Paired UI emphasizes current host summary and hides/does not persistently expose alternate host inventory while paired.
- User perception issue: "only one device exists" when in reality multiple hosts are available.

3. Discovery mechanism is already sufficient for multi-host:
- Host discovery (`UDP 39888`) returns multiple hosts in local network.
- Existing `PairingCoordinator.discoverHostsForPair(...)` and `HostDiscoveryClient.discoverAll(...)` already provide host list data.

4. Switching behavior is not first-class:
- Current paired action is centered on unpair flow.
- There is no explicit, always-available "switch host" path tied to a persistent host list.

5. MainActivity concern concentration remains high:
- UI rendering, discovery, pairing/unpairing orchestration, service toggles, status refresh, and candidate list behavior are all in one file.
- For this ticket, separation improvements should avoid large risky refactor but still isolate host-list/switch behavior boundaries.

6. Naming/style conventions to preserve:
- Activity-level imperative handlers: `beginXxxFlow`, `refreshXxx`, `resolveXxx`, `updateXxxUi`.
- Coordinators encapsulate network orchestration (`PairingCoordinator`, `HostStateRefresher`).
- `DiscoveredHost` is the canonical host list item model.

## Constraints

- Keep existing transport/discovery architecture (UDP discovery + host APIs) in scope.
- Preserve current QR path as explicit fallback/alternate pairing path.
- Maintain robust behavior if a selected host disappears between selection and switch.
- Avoid legacy compatibility branches (per project policy).

## Open Unknowns

1. Preferred paired-mode action wording:
- Whether to show `Switch Host` dynamically vs keep `Pair Host` label and interpret as switch when paired.
- Decision should optimize clarity with minimal button proliferation.

2. Switch transaction behavior:
- If unpair old succeeds but pair new fails, should app remain unpaired (clean/simple) or attempt rollback to old host (complex).
- Provisional direction: no rollback (clean, deterministic), show clear failure and keep host list visible for retry.

3. Host availability semantics:
- Whether to show stale/offline last-paired host row if not in active discovery results.
- Provisional direction: keep current host visible even if discovery misses it in a cycle.

## Implications For Requirements/Design

- Requirements must explicitly define persistent host visibility in both unpaired and paired states.
- Design should define host list as a primary UI surface, not a conditional dialog-only structure.
- Design should introduce an explicit host-switch execution path with deterministic failure handling.
- File/module responsibilities should isolate host-selection/switch intent from broader media toggle logic in `MainActivity`.
- Ticker/discovery behavior must refresh host candidates while paired, not only while unpaired.
