# Proposed-Design-Based Runtime Call Stack (v1)

## UC-001 Resource status visibility rows
### Primary path
1. `macos-camera-extension/samplecamera/ViewController.swift:configureInterface()` creates resource section with three label+chip rows.
2. `...:refreshHostResourceStatus()` requests host status payload.
3. `...:fetchHostResourceStatus(...)` parses `resources`, `capabilities`, and `issues`.
4. `...:refreshHostResourceStatus()` updates global section badge.
5. `...:updateResourceChipStates(from:)` writes each chip text/color.
6. User sees non-interactive row chips for camera/microphone/speaker.

### Error path
- If host status fetch fails, `resetHostResourceSection(bridgeOnline:)` sets chips to `Unavailable` and shows degraded section state.

## UC-002 Read-only chip semantics
### Primary path
1. `...:updateResourceChipStates(from:)` evaluates each resource.
2. Decision order per resource:
   - capability false -> `Unavailable`,
   - issue present for resource -> `Issue`,
   - resource true -> `Active`,
   - else -> `Off`.
3. `...:updateResourceChip(...)` applies chip text and color.

### Fallback path
- If issues are generic and not resource-specific, row-level issue state is not forced; global issue badge still indicates `Needs Attention`.

## UC-003 Polling continuity
### Primary path
1. `...:hostBridgeHeartbeat()` triggers existing refresh loop.
2. `...:refreshHostBridgeStatus(autoStartIfNeeded:)` keeps bridge status logic unchanged.
3. `...:syncHostResourceStatus(_:)` still manually refreshes status.

### Error path
- Offline bridge keeps existing `Unavailable` section handling and disables refresh action accordingly.
