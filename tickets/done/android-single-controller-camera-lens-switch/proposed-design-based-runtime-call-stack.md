# Proposed-Design-Based Runtime Call Stack (v1)

## UC-001 Android authoritative control (camera/mic/speaker)
### Primary path
1. `android-resource-companion/.../MainActivity.kt:setupListeners()` receives user toggle change.
2. `android-resource-companion/.../store/AppPrefs.kt:setCameraEnabled/setMicEnabled/setSpeakerEnabled(...)` persists state.
3. `android-resource-companion/.../MainActivity.kt:applyForegroundServiceState()` builds `ResourceToggleState` with persisted lens.
4. `android-resource-companion/.../service/ResourceService.kt:onStartCommand(...)` receives intent and normalizes state.
5. `android-resource-companion/.../service/ResourceService.kt:syncPhoneMediaRoutes(...)` calls streamer update.
6. `android-resource-companion/.../stream/PhoneRtspStreamer.kt:update(...)` starts/stops camera/audio route.
7. `android-resource-companion/.../service/ResourceService.kt:publishStateToHost(...)` -> `HostApiClient.publishToggles(...)` -> `POST /api/toggles`.
8. Host updates `status.resources`; macOS polls and mirrors.

### Error path
- If publish fails, `ResourceService` logs warning; periodic publish ticker retries later.

## UC-002 macOS read-only mirror
### Primary path
1. `macos-camera-extension/.../ViewController.swift:hostBridgeHeartbeat()` triggers periodic refresh.
2. `...:refreshHostBridgeStatus(autoStartIfNeeded:)` confirms bridge online.
3. `...:refreshHostResourceStatus()` fetches `GET /api/status`.
4. `...:refreshHostResourceStatus()` writes checkbox states from host snapshot.
5. UI shows phone identity + issues; checkboxes remain disabled.

### Error path
- On status read failure: `resetHostResourceSection(bridgeOnline: true)` and runtime log message.

## UC-003 Android lens selection (Front/Back)
### Primary path
1. `android-resource-companion/.../MainActivity.kt` lens selector callback persists `CameraLens` preference.
2. `...:applyForegroundServiceState()` includes selected lens in `ResourceToggleState`.
3. `android-resource-companion/.../service/ResourceService.kt:syncPhoneMediaRoutes(...)` passes lens to streamer.
4. `android-resource-companion/.../stream/PhoneRtspStreamer.kt:startCameraMode(...)` ensures stream prepared.
5. `...:applyCameraLensSelection(...)` resolves target camera id and applies `switchCamera(String)` when needed.
6. Stream continues through same RTSP endpoint; macOS still receives single camera feed.

### Fallback path
- If camera disabled: lens stays persisted and is applied at next camera enable.

### Error path
- If selected lens unavailable: streamer throws `IllegalStateException`; service logs and clears stream URL.

## UC-004 Pairing/session continuity
### Primary path
1. `MainActivity.pairHost()` discovers + pairs host and persists identity.
2. `MainActivity.refreshHostStatusIfPaired()` updates capabilities/status only (no toggle back-write).
3. `MainActivity.updateUiFromPrefs()` reflects Android local source-of-truth + host health.

### Error path
- If host unreachable, app shows degraded status and keeps local toggles unchanged.

## Coverage Summary
| use_case_id | Primary | Fallback | Error |
|---|---|---|---|
| UC-001 | Yes | N/A | Yes |
| UC-002 | Yes | N/A | Yes |
| UC-003 | Yes | Yes | Yes |
| UC-004 | Yes | N/A | Yes |
