# Proposed-Design-Based Runtime Call Stack

Version: v1
Scope: Small

## UC-001 Auto apply from macOS toggle
1. `macos-camera-extension/samplecamera/ViewController.swift:hostResourceToggleChanged(_:)`
2. debounce schedule -> `ViewController.swift:applyHostResourceTogglesInternal(autoTriggered:)`
3. build payload from checkbox states (+ stream URL guard)
4. `URLSession.dataTask` -> `POST /api/toggles`
5. host: `host-resource-agent/linux-app/server.mjs:/api/toggles`
6. host: `host-resource-agent/core/session-controller.mjs:applyResourceState(...)`
7. response success -> macOS `refreshHostResourceStatus()`

Fallback/error:
- bridge offline/no pair -> message + no request
- missing stream URL for camera/mic enable -> message + no request
- non-2xx -> refresh status rollback view

## UC-002 Android state reconciliation from host status
1. `MainActivity.kt:ensureHostStatusTicker()` periodic tick
2. `MainActivity.kt:refreshHostStatusIfPaired(...)`
3. `HostApiClient.kt:fetchStatus(...)` parses `status.resources.*`
4. `MainActivity.kt:syncPrefsFromHostSnapshot(...)`
5. if changed -> `applyForegroundServiceState()` updates service + publishes aligned state
6. `updateUiFromPrefs()` renders toggles consistent with host

Error path:
- status fetch fails -> keep local state, show degraded status detail

## UC-003 Status badge no longer stuck on Starting
1. `ViewController.swift:propertyTimer()` reads stream demand
2. if active -> badge `Streaming`
3. if idle + previously starting -> badge `Enabled`
4. `statusDetailLabel` remains log-driven
