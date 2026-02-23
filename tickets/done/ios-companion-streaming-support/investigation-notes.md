# Investigation Notes

- Ticket: `ios-companion-streaming-support`
- Date: 2026-02-23
- Status: `Refined For Runnable iOS App + Simulator E2E + Release Integration Iteration`

## Sources Consulted

- `/Users/normy/autobyteus_org/phone-av-bridge/AGENTS.md`
- `/Users/normy/autobyteus_org/phone-av-bridge/README.md`
- `/Users/normy/autobyteus_org/phone-av-bridge/desktop-av-bridge-host/README.md`
- `/Users/normy/autobyteus_org/phone-av-bridge/android-phone-av-bridge/app/src/main/java/org/autobyteus/phoneavbridge/stream/PhoneRtspStreamer.kt`
- `/Users/normy/autobyteus_org/phone-av-bridge/android-phone-av-bridge/app/src/main/java/org/autobyteus/phoneavbridge/service/ResourceService.kt`
- `/Users/normy/autobyteus_org/phone-av-bridge/android-phone-av-bridge/app/src/main/java/org/autobyteus/phoneavbridge/network/HostApiClient.kt`
- `/Users/normy/autobyteus_org/phone-av-bridge/android-phone-av-bridge/app/src/main/java/org/autobyteus/phoneavbridge/network/HostDiscoveryClient.kt`
- `/Users/normy/autobyteus_org/phone-av-bridge/android-phone-av-bridge/app/src/main/java/org/autobyteus/phoneavbridge/speaker/HostSpeakerStreamPlayer.kt`
- `/Users/normy/autobyteus_org/phone-av-bridge/desktop-av-bridge-host/desktop-app/server.mjs`
- `/Users/normy/autobyteus_org/phone-av-bridge/desktop-av-bridge-host/desktop-app/routes/session-routes.mjs`
- `/Users/normy/autobyteus_org/phone-av-bridge/desktop-av-bridge-host/adapters/linux-audio/audio-runner.mjs`
- `/Users/normy/autobyteus_org/phone-av-bridge/desktop-av-bridge-host/adapters/linux-camera/bridge-runner.mjs`
- `/Users/normy/autobyteus_org/phone-av-bridge/desktop-av-bridge-host/adapters/macos-firstparty-audio/audio-runner.mjs`
- `/Users/normy/autobyteus_org/phone-av-bridge/macos-camera-extension/samplecamera/host/HostBridgeClient.swift`
- `/Users/normy/autobyteus_org/phone-av-bridge/android-phone-av-bridge/app/src/main/res/layout/activity_main.xml`
- `/Users/normy/autobyteus_org/phone-av-bridge/android-phone-av-bridge/app/src/main/res/values/strings.xml`
- `/Users/normy/autobyteus_org/phone-av-bridge/android-phone-av-bridge/app/src/main/java/org/autobyteus/phoneavbridge/MainActivity.kt`
- `/Users/normy/autobyteus_org/phone-av-bridge/android-phone-av-bridge/app/src/main/java/org/autobyteus/phoneavbridge/pairing/HostSelectionState.kt`
- `/Users/normy/autobyteus_org/phone-av-bridge/android-phone-av-bridge/app/src/main/java/org/autobyteus/phoneavbridge/pairing/PairingCoordinator.kt`
- `/Users/normy/autobyteus_org/phone-av-bridge/ios-phone-av-bridge/Sources/PhoneAVBridgeIOS/HostApiClient.swift`
- `/Users/normy/autobyteus_org/phone-av-bridge/ios-phone-av-bridge/Sources/PhoneAVBridgeIOS/HostDiscoveryClient.swift`
- `/Users/normy/autobyteus_org/phone-av-bridge/ios-phone-av-bridge/Sources/PhoneAVBridgeIOS/HostModels.swift`
- `/Users/normy/autobyteus_org/phone-av-bridge/ios-phone-av-bridge/Sources/PhoneAVBridgeIOS/SpeakerStreamClient.swift`
- `/Users/normy/autobyteus_org/phone-av-bridge/ios-phone-av-bridge/README.md`
- `/Users/normy/autobyteus_org/phone-av-bridge/ios-phone-av-bridge/Package.swift`
- `/Users/normy/autobyteus_org/phone-av-bridge/ios-phone-av-bridge/Sources/PhoneAVBridgeIOS/MainScreenView.swift`
- `/Users/normy/autobyteus_org/phone-av-bridge/ios-phone-av-bridge/Sources/PhoneAVBridgeIOS/MainScreenViewModel.swift`
- `/Users/normy/autobyteus_org/phone-av-bridge/ios-phone-av-bridge/scripts/run_ios_sim_e2e.sh`
- `/Users/normy/autobyteus_org/phone-av-bridge/ios-phone-av-bridge-app/PhoneAVBridgeIOSApp.xcodeproj/project.pbxproj`
- `/Users/normy/autobyteus_org/phone-av-bridge/ios-phone-av-bridge-app/scripts/run_ios_app_sim_e2e.sh`
- `/Users/normy/autobyteus_org/phone-av-bridge/ios-phone-av-bridge-app/README.md`
- `/Users/normy/autobyteus_org/phone-av-bridge/.github/workflows/release.yml`
- Environment probes: `xcodebuild -version`, `xcrun simctl list devices`
- Tooling probes: `brew --version`, `brew list --versions xcodegen`, `find ... *.xcodeproj`
- Build probe: `xcodebuild -scheme PhoneAVBridgeIOS -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`

## Key Findings

1. Current transport is network streaming, not USB runtime.
   - Android camera/mic source is RTSP server (`PhoneRtspStreamer`) and publishes `rtsp://<lan-ip>:1935/`.
   - Host control plane is HTTP (`/api/bootstrap`, `/api/pair`, `/api/toggles`, `/api/status`).
   - Discovery is UDP broadcast probe/response (`PHONE_AV_BRIDGE_DISCOVER_V1`, port `39888`).
   - Speaker path to phone is HTTP byte stream (`/api/speaker/stream`) with PCM metadata headers (`X-PCM-*`).

2. Host already supports phone-identity metadata and platform-independent control contract.
   - `/api/toggles` includes `camera`, `microphone`, `speaker`, `cameraStreamUrl`, `deviceName`, `deviceId`.
   - This contract can be reused for iOS with minimal/no host changes.

3. Existing Swift host client implementation exists in macOS module.
   - `macos-camera-extension/samplecamera/host/HostBridgeClient.swift` already parses status and QR token endpoints and performs host HTTP operations.
   - This is a good base for shared iOS networking layer.

4. Local environment is iOS-ready for simulator development.
   - Xcode version: `26.1.1`.
   - Multiple iOS simulator devices are installed (`iPhone 17 Pro`, etc., iOS 26.1 runtime).

5. Android UX behavior includes a complete action/state model that is not represented in current iOS package scope.
   - Host candidate selection drives a derived action enum: `PAIR`, `SWITCH`, `UNPAIR`, `SELECT_REQUIRED`.
   - Pair button label and status-detail messaging are action-dependent and connection-health dependent.
   - Unpaired state still shows discovered/saved host summaries and guided hints.
   - Paired state includes degraded-status detection (`status` snapshot missing, host issues, route issues, or host unreachable).
   - Toggle controls are capability-aware and pair-gated.
   - Camera lens (`front`/`back`) and orientation mode (`auto`/`portrait`/`landscape`) are part of primary UI flow.

6. Current iOS deliverable in this repo validates protocol and simulator integration but does not yet expose Android-parity UI/state orchestration.
   - Existing iOS package provides transport clients and integration tests.
   - Missing pieces for parity: screen state model, host selection action reconciliation, status/detail/hint/issue derivation, and SwiftUI screen composition.

7. iOS simulator is installed and available on this machine; installation is not the blocker.
   - Xcode and simulator devices are present (`iPhone 17 Pro`, iOS 26.1 runtime).

8. Current repository has no runnable iOS app target for this feature.
   - `ios-phone-av-bridge/Package.swift` defines a library target and test targets only.
   - `find` confirms no iOS `xcodeproj`/app target exists under the iOS module path.
   - `xcodebuild ... build` for `PhoneAVBridgeIOS` produces module artifacts only (no `.app` bundle), so `simctl install` cannot be executed.

9. SwiftUI screen currently has an unimplemented QR action hook.
   - `Scan QR Pairing` button exists, but action body is empty in `MainScreenView.swift`.

10. Additional reliability finding from deep review.
   - Pair flow previously treated `publishPresence` failure as pair-failure path.
   - This was corrected to best-effort presence publish with pairing state retained.

## Current Naming/Architecture Conventions Observed

- Ticket artifacts live under `tickets/in-progress/<ticket-name>/`.
- Host routing uses explicit files by responsibility (`bootstrap-routes.mjs`, `session-routes.mjs`).
- Phone clients keep network/state responsibilities split (`HostApiClient`, discovery client, resource service/player).
- Device/route identity propagation is explicit (`deviceName`, `deviceId`, `cameraStreamUrl`).
- Android keeps host-selection policy in dedicated module (`HostSelectionState`) instead of embedding decision logic inline in view code.

## Unknowns

1. Production-grade RTSP serving approach on iOS (library selection + App Store feasibility) is not yet chosen.
2. Simulator capability for real camera/mic RTSP publishing equivalent to physical iPhone remains uncertain.
3. Foreground/background runtime policy for iOS media capture needs explicit product decision.
4. QR scan flow parity is Android-specific right now and requires either `AVFoundation` scanner UI or explicit deferment decision for iOS parity phase.
5. iOS package tests run on macOS host process; full iOS UI runtime assertions in simulator require app-layer harness not yet present.
6. Project currently lacks project-generation tooling (`xcodegen`) in local environment, but Homebrew is available so it can be installed.

## Implications For Requirements/Design

- iOS effort should be split into two layers:
  - immediate: iOS-compatible host-control + speaker-stream client + simulator-verifiable integration path,
  - follow-up: on-device camera/mic RTSP publisher with physical-device validation.
- Because physical iPhone is unavailable now, acceptance criteria must explicitly separate simulator-feasible E2E from device-only validation.
- Requirement scope now needs a second iteration focused on Android UX parity for controller UI behavior.
- Proposed iOS shape for parity:
  - add a UI-facing state machine (`HostSelectionState`) mirroring Android action semantics,
  - add a main-screen view model to orchestrate discovery, pair/switch/unpair, status refresh, and toggle publish,
  - add SwiftUI main screen view with deterministic labels/hints/status strings derived from view-model state,
  - keep transport clients unchanged and reuse canonical host APIs.
- Requirement scope now needs a third iteration with delivery focus:
  - create a runnable iOS app target (installable `.app`) that hosts `PhoneBridgeMainScreen`,
  - add simulator-deployable UI harness and deterministic end-to-end execution command(s),
  - keep package as reusable core while delivering an app-layer artifact that users can run in emulator.

## Implementation-Time Findings

1. `xcodebuild` scheme for this Swift package in current Xcode is `PhoneAVBridgeIOS` (not `PhoneAVBridgeIOS-Package`).
2. `URLProtocol`-captured requests may not always expose `httpBody` as expected in tests; payload verification should focus on serialization helper output and endpoint/method contract.
3. iOS simulator representative integration flow is feasible and passed:
   - bootstrap -> pair -> toggle speaker -> consume `/api/speaker/stream` -> unpair.
4. Current integration test validates protocol path but not Android-parity UX state transitions.
5. Deep review local fix applied: pair success now survives presence publish failures; regression test added.

## Release Iteration Findings (Iteration 4)

1. Release workflow currently publishes only Android/macOS/Linux assets.
   - `.github/workflows/release.yml` exposes `release_android`, `release_macos`, and `release_linux_deb`.
   - Tag target selector supports `android`, `macos`, `linux`, `all` only.
   - `publish_release` notes and job dependencies do not include iOS artifacts.

2. iOS app target is already CI-buildable without requiring physical iPhone hardware.
   - `ios-phone-av-bridge-app/PhoneAVBridgeIOSApp.xcodeproj` is committed.
   - The target has `CODE_SIGNING_ALLOWED = NO`, so simulator/archive build can run unsigned on CI.
   - A release artifact can be packaged from `Release-iphonesimulator/PhoneAVBridgeIOSApp.app`.

3. Existing release pattern can be reused.
   - macOS release already uses a dedicated packaging script and uploads a zip artifact.
   - iOS release should follow the same pattern: deterministic script output under `dist/` and upload through `actions/upload-artifact`.

4. User-facing release docs are currently out of date for iOS.
   - Root README release section and published asset list omit iOS simulator app zip.
   - Release selector examples do not include `ios`.

## Additional Unknowns (Release Scope)

1. GitHub `macos-latest` image Xcode version can vary; simulator archive build should avoid device-only settings.
2. Released simulator `.app` is useful for validation and internal distribution, but is not an App Store/TestFlight IPA artifact.
3. No notarization/signing pipeline is in scope for this iteration.

## Additional Implications For Requirements/Design

- Add release use cases for iOS artifact build, selector enablement (`release_ios`, `+targets=ios`), and release-note visibility.
- Keep release artifact explicit as `iOS simulator app archive (unsigned)` to avoid ambiguity with App Store distribution.
- Extend release verification to include workflow syntax checks and local script execution of iOS artifact packaging.

## Iteration 5 Findings (QR Parity + UI Parity Completion)

1. iOS QR action is currently a placeholder and blocked in UI.
   - `MainScreenView.swift` still renders `Scan QR Pairing (Coming Soon)` with `.disabled(true)`.
   - This is explicitly not parity with Android behavior.

2. Android QR flow is fully implemented and can be mirrored.
   - `MainActivity` launches scanner (`ScanContract`), parses payload via `QrPairPayloadParser`, redeems token through `/api/bootstrap/qr-redeem`, then pairs host.
   - Android UX keeps Pair and Scan QR buttons in separate rows and full-width controls.

3. Host-side APIs already support iOS QR parity without host changes.
   - `POST /api/bootstrap/qr-redeem` is available and validated in host integration tests.
   - QR payload format is JSON with `service`, `version`, `token`, `baseUrl`, `hostId`, and `displayName`.

4. iOS host API client currently lacks QR redeem operation.
   - `HostApiServing`/`HostApiClient` expose bootstrap/pair/unpair/toggles/status/presence only.
   - iOS needs explicit `redeemQrToken` support and shared payload parsing utility.

5. iOS simulator constraints require a fallback path for E2E validation.
   - Simulator often has no camera feed for realtime scanning.
   - To preserve end-to-end testability while keeping real scan behavior, iOS scanner UI should support manual QR payload entry fallback in simulator/permission-limited cases.

6. Button layout parity clarification.
   - Android intentionally places Pair and Scan QR on separate rows.
   - iOS should keep separate rows as parity, but should make sizing/spacing consistent with Android-style full-width action buttons.

## Iteration 6 Findings (Remove QR Payload Fallback)

1. User requested removal of manual QR payload fallback from iOS UI.
   - Current iOS scanner sheet includes `QR Payload (fallback)` text editor and submit action.
   - This diverges from Android UX and is considered redundant.

2. Android QR UX is scan-only and has no manual payload editor.
   - Android launches scanner, parses scanned payload, redeems token, and pairs.
   - There is no manual payload entry step in Android UI flow.

3. Parser/model remain required after fallback removal.
   - Scanned QR string still requires parse + validation before redeem.
   - Scope is to remove fallback UI only, not parser/redeem runtime logic.

4. Testability impact is accepted for this iteration.
   - Removing fallback means simulator-only environments cannot execute full QR scan flow.
   - Existing simulator E2E remains valid for primary pair/toggle path; QR runtime remains device-camera dependent.
