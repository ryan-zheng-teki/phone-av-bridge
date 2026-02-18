# Investigation Notes: Stability, Performance, UX Hardening

## Sources Consulted
- `/Users/normy/autobyteus_org/phone-resource-companion/android-resource-companion/app/src/main/java/org/autobyteus/resourcecompanion/MainActivity.kt`
- `/Users/normy/autobyteus_org/phone-resource-companion/android-resource-companion/app/src/main/java/org/autobyteus/resourcecompanion/service/ResourceService.kt`
- `/Users/normy/autobyteus_org/phone-resource-companion/android-resource-companion/app/src/main/java/org/autobyteus/resourcecompanion/network/HostDiscoveryClient.kt`
- `/Users/normy/autobyteus_org/phone-resource-companion/android-resource-companion/app/src/main/java/org/autobyteus/resourcecompanion/network/HostApiClient.kt`
- `/Users/normy/autobyteus_org/phone-resource-companion/android-resource-companion/app/src/main/java/org/autobyteus/resourcecompanion/stream/PhoneRtspStreamer.kt`
- `/Users/normy/autobyteus_org/phone-resource-companion/android-resource-companion/app/src/main/java/org/autobyteus/resourcecompanion/speaker/HostSpeakerStreamPlayer.kt`
- `/Users/normy/autobyteus_org/phone-resource-companion/android-resource-companion/app/src/main/res/layout/activity_main.xml`
- `/Users/normy/autobyteus_org/phone-resource-companion/android-resource-companion/app/src/main/res/values/strings.xml`
- `/Users/normy/autobyteus_org/phone-resource-companion/host-resource-agent/linux-app/server.mjs`
- `/Users/normy/autobyteus_org/phone-resource-companion/host-resource-agent/core/session-controller.mjs`
- `/Users/normy/autobyteus_org/phone-resource-companion/host-resource-agent/adapters/macos-firstparty-camera/cameraextension-runner.mjs`
- `/Users/normy/autobyteus_org/phone-resource-companion/host-resource-agent/adapters/macos-firstparty-audio/audio-runner.mjs`
- `/Users/normy/autobyteus_org/phone-resource-companion/host-resource-agent/installers/macos/install.command`
- `/Users/normy/autobyteus_org/phone-resource-companion/host-resource-agent/installers/linux/install.sh`
- `/Users/normy/autobyteus_org/phone-resource-companion/host-resource-agent/README.md`
- `/Users/normy/autobyteus_org/phone-resource-companion/macos-camera-extension/samplecamera/ViewController.swift`
- `/Users/normy/Applications/HostResourceAgent/linux-app/server.mjs` (installed runtime copy)
- `/Users/normy/Library/Logs/HostResourceAgent/host-resource-agent.log` (runtime evidence)

## Observed Problems
1. Pairing can feel unstable from user perspective.
2. Android UI is too technical/ambiguous for non-technical users.
3. Runtime errors are surfaced as raw low-level messages.
4. Camera quality can be worse than OBS path.
5. Speaker stream can produce audible noise/intermittent artifacts.
6. Packaging is functional but still not polished enough for truly non-technical flow.

## Key Findings

### 1) Pairing/reconnect UX gap
- `MainActivity.pairHost()` depends on UDP discovery first, then only limited fallback.
- Status line is coarse (`Paired and ready`, `Pairing failed`) and does not distinguish:
  - host unreachable,
  - discovery blocked,
  - pair API rejected,
  - publish/toggle sync degraded.
- Result: user may repeatedly click `Pair Host` without actionable next step.

### 2) Android UI communicates mechanism, not workflow
- `activity_main.xml` is just title + status + one button + three toggles.
- No guided "Step 1/2/3" flow, no host identity card, no explicit readiness checklist.
- Errors show through toasts; primary status is short-lived and not contextual.

### 3) Host issue messages are raw adapter errors
- `session-controller.mjs` stores `issues` directly from adapter exceptions.
- Raw messages such as ffmpeg/socket failures are technically useful but confusing for end users.
- Missing user-safe issue classification layer.

### 4) Camera quality likely constrained by defaults
- Android `PhoneRtspStreamer.startCameraMode()` currently calls `prepareVideo()` with defaults.
- macOS camera adapter scales to configured width/height/fps, but upstream encoded stream quality still depends on phone-side defaults.
- This can explain observed quality gap against OBS setups that may use better source encoding settings.

### 5) Speaker noise risk points
- `HostSpeakerStreamPlayer` reads raw PCM stream and pushes to `AudioTrack`.
- Host macOS speaker capture path uses ffmpeg + avfoundation and raw PCM streaming.
- Capture source defaults may not always represent intended system output route; mismatch in route configuration can manifest as noise/silence/artifacts.
- Buffering/resampling path is minimal; no explicit ffmpeg aresample normalization on macOS speaker capture path.

### 6) Packaging/install
- Installers exist for Linux/macOS and create launchers.
- macOS installation still relies on shell installer and optional Homebrew dependency install.
- "Install app and click start" is close but not yet fully polished/discoverable for non-technical users.

### 7) Installed-runtime drift can hide fixes
- A stale installed host bundle (`~/Applications/HostResourceAgent`) may keep legacy camera adapter code even when repo code is newer.
- Runtime symptoms observed:
  - Android shows paired but degraded host sync.
  - Host issues include legacy AkVirtualCamera failures even though project code uses camera extension path.
- Re-running the macOS installer from current project root updates installed runtime and resolves this drift.

## Constraints
- Must keep zero-kernel-crash-risk approach (user space only).
- Must preserve no-OBS camera path on macOS.
- Must keep Android app as simple one-tap resource toggles.
- Must avoid legacy compatibility layers; replace/clean where needed.

## Open Unknowns
1. Best explicit phone-side encoder profile that balances quality/latency across typical Android devices.
2. Exact speaker noise root cause on current macOS route in all cases (capture source selection vs resample/format vs route contention).
3. Whether discovery failures are mostly broadcast-block related in user network or host-process lifecycle timing.

## Implications For Design
- Add explicit host-health classification and messaging in Android app.
- Improve Android layout to a guided workflow with persistent state clarity.
- Add explicit RTSP video/audio quality settings on Android side.
- Add more robust/normalized ffmpeg audio capture arguments on macOS speaker route.
- Add issue-sanitization layer in host controller so UI receives actionable, non-cryptic messages.
- Keep installer flow but tighten docs and in-app hints to reduce support burden.
