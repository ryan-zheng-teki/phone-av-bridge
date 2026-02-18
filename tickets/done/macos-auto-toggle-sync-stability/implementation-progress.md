# Implementation Progress

- [x] Investigation completed.
- [x] Requirements captured (`Design-ready`, Small scope).
- [x] Runtime call-stack draft + review completed.
- [x] macOS auto-apply implementation.
- [x] Android host-state reconciliation implementation.
- [x] Status badge `Starting` transition fix.
- [x] Verification matrix + real-session sanity.

## Verification Log
- `host-resource-agent`: `npm test` -> pass (`16/16`).
- `android-resource-companion`: `JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home ./gradlew testDebugUnitTest assembleDebug` -> pass.
- `macos-camera-extension`: `scripts/build-signed-local.sh` -> pass.
- Installed latest signed app to `/Applications/PRCCamera.app` and confirmed UI:
  - no separate `Apply To Phone` action required,
  - status badge now reaches `Streaming` when demand is active.
- Added startup badge guard to avoid `Starting` overriding an already `Enabled/Streaming` state during launch, then rebuilt and reinstalled `/Applications/PRCCamera.app` (2026-02-17 16:23 local).
- UI automation validation (System Events) on macOS app checkboxes:
  - toggling `Speaker` checkbox changed host status automatically:
    - `speaker=true -> false -> true` observed via `GET /api/status`.

## Remaining Environmental Gap
- Physical Android ADB device disconnected during final reconciliation smoke run; real-device visual assertion of phone-switch auto-update from macOS control is pending reconnection.
