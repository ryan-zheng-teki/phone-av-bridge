# Implementation Plan

## Solution Sketch (Small Scope Design Basis)
1. Host pre-pair presence support:
- Add `SessionController.notePhonePresence(metadata)` to update phone identity without changing paired state.
- Keep phone identity on `unpairHost()` (do not clear `phone`).
- Add `POST /api/presence` endpoint to call `notePhonePresence`.

2. Android pre-pair host preview:
- Add unpaired discovery refresh path in `MainActivity`.
- Store preview host in memory and display in unpaired UI text.
- Publish presence to discovered host via new `HostApiClient.publishPresence()`.

3. UI copy improvements (Android):
- Replace plain `Host: not selected` fallback with clearer “searching / discovered” messaging.

## Planned File Changes
- Modify: `host-resource-agent/core/session-controller.mjs`
- Modify: `host-resource-agent/linux-app/server.mjs`
- Modify: `host-resource-agent/tests/unit/session-controller.test.mjs`
- Modify: `host-resource-agent/tests/integration/server.test.mjs`
- Modify: `android-resource-companion/.../network/HostApiClient.kt`
- Modify: `android-resource-companion/.../MainActivity.kt`
- Modify: `android-resource-companion/.../res/values/strings.xml`

## Verification Strategy
- Host tests: `cd host-resource-agent && npm test`
- Android build/install: `./gradlew :app:assembleDebug :app:installDebug`
- Device/manual integration:
  - Launch unpaired Android app and verify discovered-host text appears.
  - Verify host `/api/status` contains phone identity before pairing.
  - Confirm pair flow still works.
