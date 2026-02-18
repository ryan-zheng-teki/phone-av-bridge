# Investigation Notes

## Task
Evaluate current project naming for `phone-resource-companion` and propose a clearer naming system aligned with actual runtime responsibilities.

## Sources Consulted
- `/Users/normy/autobyteus_org/phone-resource-companion/README.md`
- `/Users/normy/autobyteus_org/phone-resource-companion/host-resource-agent/README.md`
- `/Users/normy/autobyteus_org/phone-resource-companion/phone-ip-webcam-bridge/README.md`
- `/Users/normy/autobyteus_org/phone-resource-companion/macos-camera-extension/README.md`
- `/Users/normy/autobyteus_org/phone-resource-companion/host-resource-agent/linux-app/server.mjs`
- `/Users/normy/autobyteus_org/phone-resource-companion/host-resource-agent/core/session-controller.mjs`
- `/Users/normy/autobyteus_org/phone-resource-companion/host-resource-agent/adapters/linux-camera/bridge-runner.mjs`
- `/Users/normy/autobyteus_org/phone-resource-companion/host-resource-agent/linux-app/static/index.html`
- `/Users/normy/autobyteus_org/phone-resource-companion/host-resource-agent/linux-app/static/app.js`
- `/Users/normy/autobyteus_org/phone-resource-companion/android-resource-companion/app/src/main/res/values/strings.xml`
- `/Users/normy/autobyteus_org/phone-resource-companion/android-resource-companion/app/build.gradle.kts`
- `/Users/normy/autobyteus_org/phone-resource-companion/android-resource-companion/settings.gradle.kts`
- `/Users/normy/autobyteus_org/phone-resource-companion/android-resource-companion/app/src/main/AndroidManifest.xml`

## Key Findings
- The project behavior is a phone-to-desktop media device bridge: phone camera/microphone/speaker is exposed to desktop meeting apps via host-side virtual device routes.
- The root name (`phone-resource-companion`) is generic and does not indicate the primary value proposition (phone-as-webcam/mic/speaker for desktop calls).
- Naming is inconsistent across surfaces:
  - product term variants: `Resource Companion`, `Phone Resource Companion`, `PRC Camera Host`, `Host Resource Agent`
  - technical terms: `host-resource-agent`, `phone-ip-webcam-bridge`, `linux-app` (used for macOS too)
- Some names are implementation-history artifacts instead of responsibility names:
  - `linux-app/server.mjs` currently hosts both Linux and macOS paths.
  - `phone-ip-webcam-bridge` only captures camera in name but actual system includes mic/speaker flows and host orchestration.
- End-user wording in Android UI references `PRC Camera Host`, but capability is broader than camera.
- Android package namespace `org.autobyteus.resourcecompanion` is also broad/ambiguous for long-term product identity.

## Current Naming Convention Snapshot
- Repo and module paths: lowercase kebab-case.
- Android code package: `org.autobyteus.resourcecompanion`.
- UI labels: title case and heavily mixed between abbreviation (`PRC`) and long form (`Phone Resource Companion`).
- macOS artifacts include `PRCCamera` and `PRCAudio` names, while host service uses `host-resource-agent`.

## Entrypoints And Execution Boundaries
- Android user control: `android-resource-companion` (`MainActivity`, `ResourceService`) publishes toggles + RTSP source.
- Host control plane/API: `host-resource-agent/linux-app/server.mjs` (`/api/bootstrap`, `/api/pair`, `/api/toggles`, `/api/status`, `/api/speaker/stream`).
- Linux camera ingest runtime: `phone-ip-webcam-bridge/bin/run-bridge.sh`, launched by host adapter runner.
- macOS camera and audio endpoints: `PRCCamera.app` and `PRCAudio.driver`, orchestrated by host runtime.

## Constraints
- Renaming should avoid user confusion across platforms (Android, macOS host app, Linux host app).
- Install paths, bundle identifiers, and package names may require migration steps and compatibility window at release level.
- Existing tickets/releases already reference current naming; docs and scripts need synchronized updates to avoid drift.

## Open Unknowns
- Preferred branding direction from product perspective (feature-descriptive vs brand-first).
- Whether a package/application ID migration is desired immediately or deferred.
- Whether distribution assets (`PRCCamera`, `PRCAudio`) should keep legacy abbreviation for continuity.

## Implications For Design
- A single canonical product term is needed and should map consistently to:
  - root repo/project name,
  - Android app name,
  - host app name,
  - internal module names.
- Internal module names should represent responsibility, not implementation history (`linux-app`).
- Naming refactor should be staged:
  1. Canonical vocabulary decision.
  2. Repo/module path rename.
  3. Runtime/API identifier rename.
  4. UI copy and docs synchronization.

## 2026-02-18 Real-Device E2E Follow-up

### Additional Sources Consulted
- `/Users/normy/autobyteus_org/phone-resource-companion/android-phone-av-bridge/app/build/outputs/apk/debug/app-debug.apk`
- `/Users/normy/autobyteus_org/phone-resource-companion/android-phone-av-bridge/app/src/main/java/org/autobyteus/phoneavbridge/MainActivity.kt`
- `/Users/normy/autobyteus_org/phone-resource-companion/desktop-av-bridge-host/desktop-app/server.mjs`
- `/Users/normy/Applications/PhoneAVBridgeHost/start.command`
- `/Users/normy/Library/Logs/PhoneAVBridgeHost/phone-av-bridge-host.log`
- ADB runtime evidence: `adb devices -l`, `adb install`, `adb reverse --list`, `adb logcat`, `adb shell uiautomator dump`
- Runtime verification endpoints: `http://127.0.0.1:8787/health`, `http://127.0.0.1:8787/api/status`

### Additional Key Findings
- Real-device APK installation initially failed with `INSTALL_FAILED_USER_RESTRICTED` (MIUI ADB install gate), then succeeded after installer flow approval; package `org.autobyteus.phoneavbridge` is now installed.
- When host advertised only LAN IP, phone-to-host connectivity was unreliable in this setup; forcing host advertise loopback (`ADVERTISED_HOST=127.0.0.1`) plus `adb reverse tcp:8787 tcp:8787` stabilized pairing.
- Android runtime permission prompts (`RECORD_AUDIO`, `CAMERA`) can block toggle activation until granted; explicit grants confirmed as needed for deterministic CLI-driven E2E.
- Host startup checks can report transient failures if checked too early or while another host process already occupies port `8787`; with a single process and readiness wait, host API is stable.
- End-to-end control path is validated:
  - phone app pairs with host,
  - camera toggle transitions host state (`camera: false -> true -> false`),
  - microphone and speaker toggles update host resource status.

### E2E Implications
- E2E automation for this stack should always include:
  1. permission pre-grant (camera/audio),
  2. host readiness probe loop before assertions,
  3. optional ADB reverse pathway for constrained LAN environments.

## 2026-02-18 Full macOS Artifact Rename Follow-up

### Additional Sources Consulted
- `/Users/normy/autobyteus_org/phone-resource-companion/macos-camera-extension/samplecamera.xcodeproj/project.pbxproj`
- `/Users/normy/autobyteus_org/phone-resource-companion/macos-camera-extension/cameraextension/Info.plist`
- `/Users/normy/autobyteus_org/phone-resource-companion/desktop-av-bridge-host/core/preflight-service.mjs`
- `/Users/normy/autobyteus_org/phone-resource-companion/desktop-av-bridge-host/macos-audio-driver/scripts/build-driver-local.sh`
- `/Users/normy/autobyteus_org/phone-resource-companion/desktop-av-bridge-host/installers/macos/install.command`

### Additional Key Findings
- Remaining user-facing `PRC*` names existed in active macOS runtime paths and preflight diagnostics even after initial naming refactor.
- Camera extension activation failures were tied to stale identifier drift; full bundle-ID migration is required to align runtime + UI naming.
- Audio device rename requires rebuilding first-party driver with `kDriver_Name` value that compiles without whitespace tokenization issues in xcconfig.

### Applied Decisions
- Camera app/bundle IDs are fully migrated to:
  - app: `PhoneAVBridgeCamera.app`, `org.autobyteus.phoneavbridge.camera`
  - extension: `org.autobyteus.phoneavbridge.camera.extension`
- Audio driver artifact is fully migrated to:
  - bundle: `PhoneAVBridgeAudio.driver`
  - bundle ID: `org.autobyteus.phoneavbridge.audio.driver`
  - runtime device target: `PhoneAVBridgeAudio 2ch`
- Host preflight/install/runtime messaging now references only `Phone AV Bridge Camera` and `PhoneAVBridgeAudio`.
