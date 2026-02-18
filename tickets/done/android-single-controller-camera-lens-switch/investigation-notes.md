# Investigation Notes

## Context
User requested two directional changes:
1. Make Android the single control surface for resource toggles (camera/microphone/speaker); macOS must reflect status only.
2. Add camera lens selection on Android (Front/Back) while keeping one virtual camera device on macOS.

## Sources Consulted
- `/Users/normy/autobyteus_org/phone-resource-companion/android-resource-companion/app/src/main/java/org/autobyteus/resourcecompanion/MainActivity.kt`
- `/Users/normy/autobyteus_org/phone-resource-companion/android-resource-companion/app/src/main/java/org/autobyteus/resourcecompanion/service/ResourceService.kt`
- `/Users/normy/autobyteus_org/phone-resource-companion/android-resource-companion/app/src/main/java/org/autobyteus/resourcecompanion/stream/PhoneRtspStreamer.kt`
- `/Users/normy/autobyteus_org/phone-resource-companion/android-resource-companion/app/src/main/java/org/autobyteus/resourcecompanion/store/AppPrefs.kt`
- `/Users/normy/autobyteus_org/phone-resource-companion/android-resource-companion/app/src/main/res/layout/activity_main.xml`
- `/Users/normy/autobyteus_org/phone-resource-companion/android-resource-companion/app/src/main/res/values/strings.xml`
- `/Users/normy/autobyteus_org/phone-resource-companion/macos-camera-extension/samplecamera/ViewController.swift`
- `/Users/normy/autobyteus_org/phone-resource-companion/README.md`
- Runtime API probe: `GET http://127.0.0.1:8787/api/status`
- Library surface inspection:
  - `~/.gradle/caches/modules-2/files-2.1/com.github.pedroSG94/RTSP-Server/1.2.8/.../RTSP-Server-1.2.8.aar`
  - `~/.gradle/caches/modules-2/files-2.1/com.github.pedroSG94.RootEncoder/library/2.4.5/.../library-2.4.5.aar`
  - `javap` confirms `Camera2Base.switchCamera()` and `switchCamera(String)` are available.

## Key Findings
1. Current behavior is bidirectional:
   - Android publishes toggles via `/api/toggles` in both activity and foreground service.
   - macOS host app currently also posts `/api/toggles` from UI checkbox changes.
2. Android currently has no persisted camera lens preference and no lens-selection UI.
3. Android host-status polling currently mutates local toggles from host snapshot (`syncPrefsFromHostSnapshot`), which conflicts with Android-as-single-controller intent.
4. macOS can already read host status and display phone identity + resource state, so read-only mirror mode is straightforward.
5. One macOS virtual camera device is already the architecture; adding front/back selection does not require exposing two macOS camera devices.

## Constraints
- Keep one virtual camera device on macOS (`Phone Resource Companion Camera`).
- Keep no backward-compat branches for old macOS-driven control flow (remove write path, not toggleable mode).
- Maintain existing pairing and host bridge APIs (`/api/status`, `/api/toggles`) used by Android publisher.

## Open Unknowns
- Whether explicit `switchCamera(String)` requires stream restart on certain devices.

## Resolution Strategy For Unknowns
- Implement explicit lens targeting with camera-id resolution + fallback failure handling.
- Validate with Android unit/build checks and runtime behavior against existing host status flow.
- If runtime instability appears, classify through workflow escalation policy.

## Implications
- We need coordinated updates across Android UI/state/service/streamer and macOS host UI interaction logic.
- This is cross-module and cross-runtime behavior change; classify as Medium scope.
