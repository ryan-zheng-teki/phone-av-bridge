# Phone Resource Companion

Unified root project for Android + desktop host + bridge tooling.

## Modules

- `android-resource-companion/`
  - Android app with pairing, `Camera/Microphone/Speaker` toggles, and front/back camera lens selection.
- `host-resource-agent/`
  - Desktop host app (Linux-first) with local UI/API, preflight checks, discovery, and adapter orchestration.
- `phone-ip-webcam-bridge/`
  - Bridge runtime and emulation harness used by Linux camera path.
- `tickets/one-tap-android-resource-companion/`
  - Software-engineering workflow artifacts (requirements/design/call stack/review/plan/progress).

## Developer Quick Start

### Host app

```bash
cd /Users/normy/autobyteus_org/phone-resource-companion/host-resource-agent
npm test
npm run start:mock
```

Build release archive with bundled runtime:

```bash
npm run build:release
```

Host runtime endpoints:

- `GET /api/bootstrap` (pairing code + base URL)
- `POST /api/pair`
- `POST /api/presence` (pre-pair phone identity heartbeat)
- `POST /api/toggles`
- UDP discovery probe message: `PHONE_RESOURCE_COMPANION_DISCOVER_V1` on port `39888`

### Android app

```bash
cd /Users/normy/autobyteus_org/phone-resource-companion/android-resource-companion
./gradlew testDebugUnitTest
```

## Current Linux User Flow (Preview)

1. Install host app with `host-resource-agent/installers/linux/install.sh`.
2. Launch `Host Resource Agent` from app menu (or `~/.local/bin/host-resource-agent-start`).
3. Install Android APK and open `Resource Companion`.
4. Tap `Pair Host`, then enable `Camera`, `Microphone`, and/or `Speaker`.
5. In Zoom/meeting app on Linux:
   - in compatibility mode, select the loopback camera device (for example `/dev/video2` backed camera),
   - select the virtual mic source named `<Phone Name> Microphone`,
   - for phone speaker playback, ensure host output is available on the default Pulse/PipeWire sink monitor.

Notes:
- Camera/mic media is sent from Android via in-app RTSP server.
- Android now publishes RTSP endpoint as LAN IPv4 (`rtsp://<phone-lan-ip>:1935/`) for host reachability.
- Linux camera mode controls:
  - `LINUX_CAMERA_MODE=compatibility` for meeting-app webcam exposure (`v4l2loopback` path),
  - `LINUX_CAMERA_MODE=userspace` for ingest-only setup without kernel loopback,
  - `LINUX_CAMERA_MODE=auto` to use compatibility device when present, else userspace.
- Linux Docker one-container E2E validation now covers camera/microphone/speaker control path.
- Host-level Linux validation is complete; final meeting-app selector UX depends on local desktop app behavior.
- For USB ADB test installs on some vendor ROMs, device-side approval may be required (for example developer option allowing USB installs).

## Current macOS User Flow (Preview)

1. Install host app with `host-resource-agent/installers/macos/install.command`.
2. Install `PRCCamera.app` into `/Applications` and launch it.
3. `PRCCamera` now auto-starts `Host Resource Agent` in the background (when installed), and shows host bridge status in-app.
4. Install Android APK and open `Resource Companion`.
5. Tap `Pair Host`, then enable `Camera` and/or `Microphone` on phone.
6. If camera is enabled, choose `Front` or `Back` lens on phone.
7. In Zoom/meeting app on macOS:
   - select `Phone Resource Companion Camera` as camera input,
   - select `PRCAudio 2ch` as microphone input,
   - for phone speaker playback, route macOS output to `PRCAudio 2ch` (or a Multi-Output device that includes it).

Notes:
- macOS host path now uses PRCCamera camera extension host app (camera) + first-party `PRCAudio.driver` (mic/speaker).
- Speaker route on macOS streams host audio to the phone when `Enable Speaker` is on.
- PRCCamera shows live phone session state (paired phone name/id + camera/mic/speaker states) as read-only mirror; resource toggles are controlled on Android.
- Installer bootstraps `ffmpeg`, installs `PRCAudio.driver`, and guides PRCCamera extension readiness.
- Host pairing identity is persisted (`~/.host-resource-agent/state.json`) so host restarts keep the same pairing code/device identity.
- Android app now retries/publishes toggles in background service mode to recover host restarts without manual re-toggle.
- Android unpaired screen now proactively shows discovered host preview (`Host discovered: ...`) when available.
- Host status can carry phone identity even while unpaired, so PRCCamera can display the detected phone before pairing.
- Camera stream source is selected on Android (front/back) and still maps to a single macOS virtual camera device.
- On first camera use, macOS requires one-time camera extension approval in `System Settings -> General -> Login Items & Extensions -> Camera Extensions`.
- Verify meeting-app camera list after approval if app was already open.

### Bridge Docker emulation

```bash
cd /Users/normy/autobyteus_org/phone-resource-companion/phone-ip-webcam-bridge
./tests/emulation/run_docker_emulation.sh
```

### Host Linux Docker E2E

```bash
cd /Users/normy/autobyteus_org/phone-resource-companion/host-resource-agent
bash tests/docker/run_linux_container_e2e.sh
```
