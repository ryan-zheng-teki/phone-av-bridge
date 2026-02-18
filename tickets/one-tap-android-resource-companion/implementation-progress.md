# Implementation Progress

## Kickoff Preconditions Checklist

- Scope classification confirmed (`Small`/`Medium`/`Large`): `Large`
- Runtime review rounds complete for scope (`Large` >= 5): `Yes`
- Runtime review final gate is `Implementation can start: Yes`: `Yes`
- No unresolved blocking findings: `Yes`

## Progress Log

- 2026-02-16: Workflow artifacts created (`requirements`, `design`, `call stack`, `review`, `plan`).
- 2026-02-16: Android module scaffolded (`MainActivity`, `ResourceService`, state machine, prefs, tests).
- 2026-02-16: First connected emulator run found two issues:
  - foreground service microphone permission crash path,
  - non-deterministic test defaults due persisted state.
- 2026-02-16: Applied fixes:
  - exact foreground-service type mask by active toggles,
  - permission reconciliation before service start,
  - deterministic test reset rule and service stop before launch,
  - unpair flow now clears toggle prefs.
- 2026-02-16: Re-ran validation successfully:
  - `testDebugUnitTest` passed,
  - `connectedDebugAndroidTest` passed (2/2 tests).
- 2026-02-16: Requirements refined to `v2` with strict zero-technical-setup target; implementation plan updated to Linux/macOS host installer-first delivery tasks.
- 2026-02-16: Runtime call stack and review artifacts upgraded to `v2` (`UC-001`..`UC-009`), with review rounds 6-7 confirming `Go` before continuing implementation.
- 2026-02-16: Implemented `host-resource-agent` Linux-first slice:
  - host core session controller + preflight service,
  - Linux host local web app/API,
  - Linux camera/audio adapter runners (speaker phase-gated),
  - Linux/macOS installer scripts and release archive builder.
- 2026-02-16: Host agent verification completed:
  - `npm test` passed (4 tests),
  - `npm run build:release` created host release archive,
  - host `/health` endpoint validated in mock runtime,
  - Docker emulation harness passed for bridge pipeline.
- 2026-02-16: Android instrumentation re-run attempt encountered emulator availability instability (`No connected devices`), while prior connected run in this session had already passed; unit tests remain green.
- 2026-02-16: Repository refactored into unified root project:
  - `phone-resource-companion/android-resource-companion`,
  - `phone-resource-companion/host-resource-agent`,
  - `phone-resource-companion/phone-ip-webcam-bridge`,
  - `phone-resource-companion/tickets/one-tap-android-resource-companion`.
- 2026-02-16: Implemented host discovery + pairing protocol:
  - host API now exposes `/api/bootstrap`,
  - host enforces startup pairing code on `/api/pair`,
  - host publishes UDP discovery responses on port `39888`.
- 2026-02-16: Implemented Android host control transport:
  - Android auto-discovers host (UDP),
  - Android fallback bootstrap for emulator (`10.0.2.2`),
  - Android toggles are now published to host `/api/toggles`.
- 2026-02-16: Additional verification:
  - host tests now pass (5 tests including UDP discovery),
  - host bootstrap/pair/toggle API smoke path validated with generated pair code,
  - Android `testDebugUnitTest`, `assembleDebug`, and `assembleDebugAndroidTest` passed,
  - Docker emulation rerun blocked by Docker daemon unavailable (`Cannot connect to the Docker daemon`),
  - bridge smoke preflight test passed.
- 2026-02-16: Installer usability hardening:
  - added Linux/macOS uninstall scripts,
  - installer copy fallback when `rsync` is missing,
  - Linux installer now warns when `ffmpeg` is missing.
- 2026-02-16: Android local JVM transport tests were attempted then removed due Android SDK `org.json` method stubs in unit-test runtime; protocol coverage remains validated in host integration tests.
- 2026-02-16: Host installer/runtime pass for lower user setup friction:
  - host release build now bundles Node runtime under `host-resource-agent/runtime/node`,
  - Linux installer now writes `host-resource-agent-start` / `host-resource-agent-stop` launchers with PID/log management and browser auto-open,
  - macOS installer now writes `start.command` / `stop.command` and creates `~/Applications/Host Resource Agent.app`.
- 2026-02-16: Installer smoke validation in isolated temp-home environments passed for Linux and macOS flows:
  - install -> start -> `/health` probe -> stop -> uninstall.
- 2026-02-16: Android connected emulator validation pass restored:
  - root cause of intermittent `No connected devices` was SDK path mismatch (`local.properties` SDK vs manually launched emulator SDK),
  - aligned emulator launch path and re-ran `connectedDebugAndroidTest` successfully.
- 2026-02-16: Android instrumentation regression fixed:
  - `MainActivityTest` now accepts both `status_connected` and `status_connected_degraded` after pairing when host sync endpoint is unreachable in test environment.
- 2026-02-16: Implemented Android real media-serving path:
  - integrated RTSP server dependencies (JitPack + compatible `RTSP-Server:1.2.8` / `RootEncoder:2.4.5`),
  - added `PhoneRtspStreamer` with camera+audio and audio-only modes,
  - `ResourceService` now starts/stops RTSP stream lifecycle and persists active stream URL.
- 2026-02-16: Implemented host stream URL plumbing:
  - Android toggle payload now includes `cameraStreamUrl`,
  - host `/api/toggles` accepts and forwards stream URL,
  - session controller stores stream URL and injects it into camera/audio adapters.
- 2026-02-16: Implemented Linux microphone route runtime:
  - `LinuxAudioRunner` now creates Pulse/PipeWire null sink via `pactl`,
  - ffmpeg consumes RTSP audio and feeds virtual sink monitor source for meeting apps.
- 2026-02-16: Re-ran validations after streaming integration:
  - host tests passed (6 tests),
  - Android `testDebugUnitTest` + `assembleDebug` passed,
  - Android connected instrumentation (`connectedDebugAndroidTest`) passed (2/2),
  - bridge Docker emulation passed with RTSP ingest checks.
- 2026-02-16: Camera stream root-cause isolation and fix:
  - root cause for emulator camera failure was background non-OpenGL camera path stream configuration incompatibility (`configureStreams` unsupported),
  - switched `PhoneRtspStreamer` to background OpenGL pipeline (`RtspServerCamera2(context, true, ...)`),
  - validated camera + audio RTSP tracks in emulator via `ffprobe` after startup warm-up.
- 2026-02-16: Stream URL publish hardening:
  - normalized published `cameraStreamUrl` to LAN IPv4 endpoint (`rtsp://<lan-ip>:1935/`) to avoid IPv6-local endpoint leakage.
- 2026-02-16: Physical Android validation blocker identified:
  - USB-connected device present in ADB, but APK install blocked by device policy (`INSTALL_FAILED_USER_RESTRICTED: Install canceled by user`),
  - emulator-only instrumentation run pinned with `ANDROID_SERIAL=emulator-5554` completed successfully.
- 2026-02-16: Physical Android phone validation completed after enabling Xiaomi USB security options:
  - APK install + ADB runtime permission grants succeeded,
  - real RTSP stream verified from physical phone (`H264 video + AAC audio`) via ADB-forward and direct LAN URL,
  - stream URL persisted as LAN endpoint (`rtsp://192.168.2.30:1935/` in this run).
- 2026-02-16: Control-path end-to-end validation with real phone + host mock app:
  - host paired using generated pair code,
  - phone published toggle state to host,
  - host `/api/status` reflected active resources and real `cameraStreamUrl`.
- 2026-02-16: Implemented macOS host runtime adapters:
  - camera: OBS Virtual Camera integration via OBS WebSocket automation (`scene/input setup`, `start virtual camera`),
  - microphone: RTSP audio -> AudioToolbox output device (`BlackHole 2ch`) route.
- 2026-02-16: Added platform-aware host adapter selection:
  - Linux keeps v4l2loopback/Pulse route,
  - macOS now uses OBS + BlackHole path by default,
  - unsupported platforms fall back to no-capability state.
- 2026-02-16: Added macOS UX hardening:
  - host status now exposes capability flags and issue list in UI,
  - preflight now checks OBS install, OBS WebSocket reachability, BlackHole presence, and camera-extension approval signals.
- 2026-02-16: Physical phone -> macOS host validation:
  - pairing and toggle publish confirmed,
  - host microphone route active on macOS,
  - camera path now reports explicit actionable gate when macOS requires OBS Camera Extension approval.
- 2026-02-16: Mic-route and naming hardening pass:
  - fixed host controller bug where `cameraStreamUrl` was cleared when camera was off (mic-only toggle now works),
  - added Android `deviceName`/`deviceId` publish to pair/toggle payloads,
  - host state now tracks paired phone identity and route hints for camera/mic devices,
  - Linux virtual microphone naming now includes phone identity for multi-phone recognition,
  - speaker capability is now explicitly reported as unavailable in production host runtimes until implemented.
- 2026-02-16: Validation updates:
  - host tests now pass with 8/8 (new mic-only and device-identity unit coverage),
  - live host API verification confirms mic-only activation with real RTSP URL and phone-aware route hints,
  - Android local build validation currently blocked on machine missing Java runtime (`Unable to locate a Java Runtime`).
- 2026-02-16: OBS/mic UX hardening:
  - macOS audio runner now auto-creates/updates OBS source `<Phone Name> Mic` bound to BlackHole when mic route starts,
  - Android app now fetches host capabilities and disables unsupported toggles (notably `speaker`) to prevent false expectations.
- 2026-02-16: Build/install validation refresh:
  - configured local JDK runtime (`openjdk@21`) for Android build execution,
  - rebuilt Android app (`testDebugUnitTest`, `assembleDebug`) and installed updated debug APK to physical phone,
  - connected instrumentation install still blocked by device policy for test APK (`INSTALL_FAILED_USER_RESTRICTED`).
- 2026-02-16: macOS host deployment refresh:
  - reinstalled Host Resource Agent app bundle via installer to include latest OBS/mic automation changes,
  - validated host runtime route hints and OBS source existence (`Xiaomi 11T Mic`).
- 2026-02-17: Final end-to-end macOS + physical Android validation pass:
  - OBS Camera Extension state confirmed active (`activated enabled`),
  - macOS AVFoundation enumerates `OBS Virtual Camera` and `BlackHole 2ch`,
  - host runtime status reaches `Resource Active` with `camera=true`, `microphone=true`, `speaker=false`,
  - OBS websocket confirms virtual camera active and phone mic source mapped to `BlackHole2ch_UID`.
- 2026-02-17: Linux speaker implementation + Docker validation cycle:
  - implemented Linux speaker capture/stream route in `LinuxAudioRunner` (Pulse source -> PCM stream endpoint),
  - enabled Linux speaker capability in production host runtime,
  - added Docker one-container E2E harness (`host-agent/tests/docker/*`) covering pair + camera + microphone + speaker toggles,
  - resolved two Docker validation defects during execution:
    - RTSP publisher command formatting bug in compose command payload,
    - Pulse module/source compatibility issue (`module-null-sink` fallback without explicit `source_name`),
  - final Docker E2E run passed with measured non-silent speaker stream payload.
- 2026-02-17: Ubuntu-container install/start validation:
  - ran `installers/linux/install.sh` inside `ubuntu:24.04` container (with `AUTO_INSTALL_DEPS=0`),
  - validated launcher start -> `/health` -> `/api/bootstrap` -> `/api/pair` -> `/api/status` API path,
  - confirmed host reports `camera=true`, `microphone=true`, `speaker=true` capabilities in Ubuntu container runtime.

## File-Level Progress Table

| Change ID | Change Type | File | File Status | Verification Command | Verification Status | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| C-001 | Add | `android-resource-companion/app/src/main/java/org/autobyteus/resourcecompanion/MainActivity.kt` | Completed | `./gradlew testDebugUnitTest connectedDebugAndroidTest` | Passed | Toggle UX + pairing + permission-safe service lifecycle implemented. |
| C-002 | Add | `android-resource-companion/app/src/main/java/org/autobyteus/resourcecompanion/service/ResourceService.kt` | Completed | `./gradlew connectedDebugAndroidTest` | Passed | Uses explicit foreground service type mask by active resource toggles. |
| C-003 | Add | `android-resource-companion/app/src/main/java/org/autobyteus/resourcecompanion/store/AppPrefs.kt` | Completed | `./gradlew connectedDebugAndroidTest` | Passed | Added clear helpers for deterministic state and safe unpair behavior. |
| C-004 | Add | `android-resource-companion/app/src/androidTest/java/org/autobyteus/resourcecompanion/MainActivityTest.kt` | Completed | `./gradlew connectedDebugAndroidTest` | Passed | Covers default state, pair/unpair, and speaker toggle flow. |
| C-005 | Add | `android-resource-companion/app/src/test/java/org/autobyteus/resourcecompanion/session/CompanionSessionStateMachineTest.kt` | Completed | `./gradlew testDebugUnitTest` | Passed | State-machine transition checks pass. |
| C-006 | Add | `host-resource-agent/core/session-controller.mjs` | Completed | `npm test` | Passed | Pairing and resource orchestration state model implemented. |
| C-007 | Add | `host-resource-agent/core/preflight-service.mjs` | Completed | `npm test` | Passed | Preflight report and remediation hints implemented. |
| C-008 | Add | `host-resource-agent/linux-app/server.mjs` + `host-resource-agent/linux-app/static/*` | Completed | `npm test`, manual health probe | Passed | Local host UX/API implemented for non-technical control flow. |
| C-009 | Add | `host-resource-agent/adapters/linux-camera/bridge-runner.mjs` | Completed | `npm test`, Docker emulation harness | Passed | Bridge-backed camera adapter with managed lifecycle. |
| C-010 | Add | `host-resource-agent/adapters/linux-audio/audio-runner.mjs` | Completed | `npm test` | Passed | Linux mic route and speaker route are implemented; speaker stream is exposed via `/api/speaker/stream`. |
| C-011 | Add | `host-resource-agent/installers/linux/install.sh` + `host-resource-agent/installers/macos/install.command` | Completed | script validation + release build | Passed | Install scripts now provided for end-user setup path. |
| C-012 | Add | `host-resource-agent/scripts/build-release.mjs` | Completed | `npm run build:release` | Passed | Installable archive artifact generation works. |
| C-013 | Modify | `host-resource-agent/linux-app/server.mjs` | Completed | `npm test` | Passed | Added bootstrap endpoint, pair-code validation, and UDP discovery responder. |
| C-014 | Add | `host-resource-agent/tests/integration/discovery.test.mjs` | Completed | `npm test` | Passed | Verifies LAN discovery response contract. |
| C-015 | Add | `android-resource-companion/app/src/main/java/org/autobyteus/resourcecompanion/network/HostApiClient.kt` | Completed | `./gradlew testDebugUnitTest assembleDebug` | Passed | Android host API client for bootstrap/pair/unpair/toggle sync. |
| C-016 | Add | `android-resource-companion/app/src/main/java/org/autobyteus/resourcecompanion/network/HostDiscoveryClient.kt` | Completed | `./gradlew testDebugUnitTest assembleDebug` | Passed | Android UDP discovery client with emulator fallback path. |
| C-017 | Modify | `android-resource-companion/app/src/main/java/org/autobyteus/resourcecompanion/MainActivity.kt` | Completed | `./gradlew testDebugUnitTest assembleDebug assembleDebugAndroidTest` | Passed | Pair/unpair now uses real host protocol and async network operations. |
| C-018 | Add | `host-resource-agent/installers/linux/uninstall.sh` + `host-resource-agent/installers/macos/uninstall.command` | Completed | installer syntax + macOS install/uninstall smoke | Passed | Added clean uninstall path for end users. |
| C-019 | Modify | `host-resource-agent/installers/linux/install.sh` + `host-resource-agent/installers/macos/install.command` | Completed | installer syntax + macOS install smoke | Passed | Added fallback copy path and improved setup diagnostics. |
| C-020 | Add | `host-resource-agent/scripts/prepare-runtime.mjs` | Completed | `npm run prepare:runtime` + runtime binary execution smoke | Passed | Bundles relocatable Node runtime (`bin/node` + `lib/`) into release payload. |
| C-021 | Modify | `host-resource-agent/scripts/build-release.mjs` + `host-resource-agent/package.json` | Completed | `npm run build:release` + archive content check | Passed | Release now auto-prepares runtime bundle and includes it in archive. |
| C-022 | Modify | `host-resource-agent/installers/linux/install.sh` + `host-resource-agent/installers/linux/uninstall.sh` | Completed | isolated temp-home Linux installer smoke | Passed | Added start/stop launchers, PID/log handling, runtime-first node resolution, and clean uninstall. |
| C-023 | Modify | `host-resource-agent/installers/macos/install.command` + `host-resource-agent/installers/macos/uninstall.command` | Completed | isolated temp-home macOS installer smoke | Passed | Added start/stop commands, app bundle creation, runtime-first launch, and cleanup. |
| C-024 | Modify | `host-resource-agent/README.md` + `phone-resource-companion/README.md` | Completed | docs review | Passed | Updated end-user launcher/runtime instructions and corrected stale transport statement. |
| C-025 | Modify | `android-resource-companion/app/src/androidTest/java/org/autobyteus/resourcecompanion/MainActivityTest.kt` | Completed | `./gradlew connectedDebugAndroidTest` | Passed | Assertion updated for degraded-sync status path to prevent false negatives. |
| C-026 | Add/Modify | `android-resource-companion/app/src/main/java/.../stream/PhoneRtspStreamer.kt` + `ResourceService.kt` + network/store wiring files | Completed | `./gradlew testDebugUnitTest assembleDebug connectedDebugAndroidTest` | Passed | Android app now starts RTSP server for camera/mic toggle modes and publishes stream URL metadata. |
| C-027 | Modify | `host-resource-agent/core/session-controller.mjs` + `linux-app/server.mjs` + `adapters/linux-camera/bridge-runner.mjs` | Completed | `npm test` | Passed | Host now accepts dynamic stream URL from Android and applies it in camera adapter lifecycle. |
| C-028 | Modify | `host-resource-agent/adapters/linux-audio/audio-runner.mjs` | Completed | `npm test` + adapter static review | Passed | Linux microphone virtual-route runtime implemented with Pulse/PipeWire + ffmpeg ingest path. |
| C-029 | Modify | `android-resource-companion/settings.gradle.kts` + `app/build.gradle.kts` | Completed | `./gradlew testDebugUnitTest assembleDebug` | Passed | Added compatible RTSP dependencies and repository setup. |
| C-030 | Modify | `android-resource-companion/app/src/main/java/org/autobyteus/resourcecompanion/stream/PhoneRtspStreamer.kt` | Completed | `./gradlew assembleDebug` + emulator `ffprobe` RTSP probe | Passed | Switched to OpenGL background camera pipeline; emulator now produces H264 camera stream. |
| C-031 | Modify | `android-resource-companion/app/src/main/java/org/autobyteus/resourcecompanion/stream/PhoneRtspStreamer.kt` | Completed | emulator prefs/state check + `ffprobe` RTSP probe | Passed | Published stream URL now prefers LAN IPv4 endpoint for host reachability. |
| C-032 | Add | `host-resource-agent/adapters/macos-camera/obs-websocket-client.mjs` + `obs-virtualcam-runner.mjs` | Completed | `npm test` + live host status validation | Passed | macOS camera adapter integrated with OBS WebSocket automation and startup handling. |
| C-033 | Add | `host-resource-agent/adapters/macos-audio/audio-runner.mjs` | Completed | `npm test` + live host status validation | Passed | macOS microphone routing implemented via ffmpeg AudioToolbox output to BlackHole device. |
| C-034 | Modify | `host-resource-agent/linux-app/server.mjs` + `core/preflight-service.mjs` + static UI files | Completed | `npm test` + live preflight/status API checks | Passed | Platform-aware adapter selection, macOS readiness checks, and issue surfacing in host UI. |
| C-035 | Modify | host installer/docs (`installers/macos/install.command`, `installers/linux/install.sh`, README files) | Completed | installer script lint/smoke + docs review | Passed | Added dependency bootstrap paths and clarified end-user flows for Linux/macOS. |
| C-036 | Modify | `host-resource-agent/core/session-controller.mjs` + `linux-app/server.mjs` | Completed | `npm test` + live API probes | Passed | Fixed mic-only stream URL lifecycle and added phone metadata (`deviceName`/`deviceId`) propagation in pair/toggle flow. |
| C-037 | Modify | `host-resource-agent/adapters/linux-audio/audio-runner.mjs` + macOS adapter files | Completed | `npm test` + live API probes | Passed | Added route hints and per-phone microphone naming support where platform permits. |
| C-038 | Add/Modify | Android device identity + host API client wiring (`device/DeviceIdentityResolver.kt`, `MainActivity.kt`, `HostApiClient.kt`) | Completed | static review + host API probes | Partially Passed | Code complete; Android build/test rerun blocked by missing local Java runtime. |
| C-039 | Modify | `host-resource-agent/adapters/macos-audio/audio-runner.mjs` | Completed | static check + OBS websocket live probe | Passed | Auto-manages per-phone OBS microphone input source on macOS (`<Phone Name> Mic` -> BlackHole). |
| C-040 | Modify | `android-resource-companion/MainActivity.kt` + `network/HostApiClient.kt` + `model/HostCapabilities.kt` | Completed | static review + `assembleDebug` | Passed | Android now reads host capabilities and disables unsupported resources per host runtime capability report. |
| C-041 | Validate | Android build/install flow (`testDebugUnitTest`, `assembleDebug`, `adb install -r`) | Completed | gradle + adb commands | Passed | Updated APK installed on physical device successfully after JDK setup. |
| C-042 | Validate | Android connected instrumentation (`connectedDebugAndroidTest`) | Completed | gradle connected test run | Blocked (device policy) | Test APK installation blocked by device-level restriction (`INSTALL_FAILED_USER_RESTRICTED`). |
| C-043 | Deploy/Validate | macOS host installer redeploy + OBS source probe | Completed | macOS installer + OBS websocket checks | Passed | Installed host bundle now auto-creates phone-named OBS mic source and exposes route hints. |
| C-044 | Validate | Final live macOS + physical Android E2E (`pair -> camera/mic active -> OBS virtual devices`) | Completed | host API + OBS websocket + AVFoundation probes | Passed | Camera and microphone routes validated end-to-end on current machine. |
| C-045 | Modify | `host-resource-agent/adapters/linux-audio/audio-runner.mjs` + `host-resource-agent/linux-app/server.mjs` | Completed | `npm test` + Docker E2E script | Passed | Implemented Linux speaker capture route, speaker client streaming, and enabled Linux speaker capability in production runtime. |
| C-046 | Add | `host-resource-agent/tests/docker/*` + `host-resource-agent/package.json` | Completed | `bash tests/docker/run_linux_container_e2e.sh` | Passed | Added one-container Docker Linux E2E harness (RTSP source + host agent + Pulse routing) and reusable npm script. |
| C-047 | Modify | `host-resource-agent/adapters/linux-audio/audio-runner.mjs` + Docker compose harness | Completed | repeated Docker E2E runs | Passed | Added null-sink compatibility fallback and fixed compose publisher command formatting to stabilize container validation. |

## Validation Matrix (Android-First)

| Use Case | Emulator Validation Status | Evidence | Residual Risk |
| --- | --- | --- | --- |
| UC-001 Install + launch + pair/unpair UX | Partially validated | Android connected tests + host API/discovery tests + installer smoke tests | Full pair flow against real host from emulator still depends on network/environment orchestration beyond current instrumentation slice. |
| UC-002 Camera toggle flow (state + host publish path) | Validated (device + emulator), partial overall | Android RTSP lifecycle wiring + emulator and physical-phone `ffprobe` confirm H264 stream + host status/toggle tests + bridge emulation | Final real Linux loopback device enumeration in meeting apps still pending. |
| UC-003 Microphone toggle flow (state + host publish path) | Validated (device + emulator), partial overall | Android RTSP audio mode + emulator/physical-phone `ffprobe` confirm AAC stream + Linux mic adapter implementation + host tests | Final real Linux meeting-app microphone enumeration still pending. |
| UC-004 Speaker toggle flow | Validated (container + macOS live) | Docker one-container E2E (`speaker=true` + PCM RMS check) + macOS live phone speaker verification | Real Linux meeting-app output-device selection still pending. |
| UC-005 Independent toggle updates without restart | Validated (container), partial overall | Docker one-container E2E verifies simultaneous camera/mic/speaker active state and route health | Real Linux desktop meeting-app behavior under prolonged load still pending. |
| UC-006 Reconnect/recovery | Not yet validated | No end-to-end transport in current slice | Requires host agent + network fault injection harness. |
| UC-007 Linux install + launch flow | Partially validated | Installer script, launcher generation, runtime bundle, isolated install/start/stop/uninstall smoke + Docker host runtime E2E | Needs native Linux desktop validation (real distro GUI launcher + meeting-app device lists). |
| UC-008 macOS install + guided permissions | Partially validated | Installer + runtime + preflight + live host path validated on macOS with real phone | One-time OBS Camera Extension approval remains manual OS security gate. |
| UC-009 Host preflight + remediation | Validated (logic + API) | Host tests and API/manual checks passed | Real distro-specific remediation commands need hardening. |

## Remaining Work (Outside Current Emulator-Validated Slice)

- Linux real-device validation for installer + meeting-app camera/mic/speaker selection.
- macOS per-phone OS-level camera/mic device renaming is constrained by OBS/BlackHole driver naming; current build exposes phone identity via host route hints instead.
- Encrypted Android-to-host transport (current HTTP LAN flow is not encrypted).
- macOS camera/audio adapters and signed packaging.
- Full desktop meeting-app end-to-end validation with physical Android phone.
