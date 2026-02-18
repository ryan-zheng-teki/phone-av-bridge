# Investigation Notes

## Sources Consulted
- `/Users/normy/autobyteus_org/phone-resource-companion/macos-camera-extension/samplecamera/ViewController.swift`
- `/Users/normy/autobyteus_org/phone-resource-companion/android-resource-companion/app/src/main/java/org/autobyteus/resourcecompanion/MainActivity.kt`
- `/Users/normy/autobyteus_org/phone-resource-companion/android-resource-companion/app/src/main/java/org/autobyteus/resourcecompanion/network/HostApiClient.kt`
- `/Users/normy/autobyteus_org/phone-resource-companion/host-resource-agent/core/session-controller.mjs`

## Findings
1. macOS UI only applies resource checkboxes when `Apply To Phone` is clicked; checkbox change itself is passive.
2. Android polls host status, but host status snapshot model does not include host `resources` booleans, so Android local toggles are not reconciled to host-originated changes.
3. Phone-side foreground service continues to publish local toggles, so host state can be overwritten after macOS change.
4. PRC Camera Host status badge defaults to `Starting` and is not promoted during capture-demand updates, so UI can look stuck while stream is active.

## Constraints
- Keep no-legacy stance: remove separate manual apply path from primary UX and prefer direct behavior.
- Preserve existing host APIs (`/api/status`, `/api/toggles`).
- Keep app safe; no kernel-level changes.

## Unknowns Reduced
- The observed speaker-disable mismatch is caused by state synchronization gap, not endpoint rejection.
- `Starting` badge persistence is UI-state handling, not host bridge startup failure.
