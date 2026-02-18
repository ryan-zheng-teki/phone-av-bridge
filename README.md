# Phone AV Bridge

Unified root project for Android + desktop host + bridge tooling.

## Modules

- `android-phone-av-bridge/`
  - Android app with pairing, `Camera/Microphone/Speaker` toggles, and front/back camera lens selection.
- `desktop-av-bridge-host/`
  - Desktop host app with local UI/API, preflight checks, discovery, and adapter orchestration.
- `phone-av-camera-bridge-runtime/`
  - Bridge runtime and emulation harness used by Linux camera path.
- `tickets/in-progress/` and `tickets/done/`
  - Software-engineering workflow artifacts (requirements/design/call stack/review/plan/progress), split by status.

## Project Relationships

1. `android-phone-av-bridge` is the phone-side controller and media source.
2. `desktop-av-bridge-host` is the desktop-side orchestrator and API surface.
3. `desktop-av-bridge-host` uses:
   - `phone-av-camera-bridge-runtime` for Linux camera ingest/output (`adapters/linux-camera/bridge-runner.mjs` launches `phone-av-camera-bridge-runtime/bin/run-bridge.sh`).
   - `macos-camera-extension` runtime artifacts (`PhoneAVBridgeCamera.app`) for macOS virtual camera.
   - `desktop-av-bridge-host/macos-audio-driver` (`PhoneAVBridgeAudio.driver`) for macOS virtual mic/speaker route.

In short: Android sends state/media -> Phone AV Bridge Host orchestrates -> platform adapters expose desktop camera/mic/speaker devices.

## Active vs Reference

Active runtime projects:
- `android-phone-av-bridge/`
- `desktop-av-bridge-host/`
- `phone-av-camera-bridge-runtime/` (active on Linux camera path)
- `macos-camera-extension/` (active on macOS camera path)

Not primary runtime source projects:
- `tickets/`: planning/design/progress docs only.
- `dist/`, `releases/`: build/release outputs.
- `**/build`, `**/build_signed`, `**/.gradle`, `**/node_modules`: generated artifacts.
- `tmp_cameraextension_baseline/`: local baseline/reference snapshot; not used by host runtime.

## Developer Quick Start

### Host app

```bash
cd desktop-av-bridge-host
npm test
npm run start:mock
```

Build release archive:

```bash
npm run build:release
```

Host runtime endpoints:
- `GET /api/bootstrap` (pairing code + base URL)
- `POST /api/pair`
- `POST /api/presence` (pre-pair phone identity heartbeat)
- `POST /api/toggles`
- UDP discovery probe message: `PHONE_AV_BRIDGE_DISCOVER_V1` on port `39888`

### Android app

```bash
cd android-phone-av-bridge
./gradlew testDebugUnitTest
```

## Current Linux User Flow (Preview)

1. Install host app with `desktop-av-bridge-host/installers/linux/install.sh`.
2. Launch `Phone AV Bridge Host` from app menu (or `~/.local/bin/phone-av-bridge-host-start`).
3. Install Android APK and open `Phone AV Bridge`.
4. Tap `Pair Host`, then enable `Camera`, `Microphone`, and/or `Speaker`.
5. In Zoom/meeting app on Linux:
   - in compatibility mode, select the loopback camera device,
   - select the virtual mic source named `<Phone Name> Microphone`,
   - for phone speaker playback, ensure host output is available on the default Pulse/PipeWire sink monitor.

Notes:
- Camera/mic media is sent from Android via in-app RTSP server.
- Android publishes RTSP endpoint as LAN IPv4 (`rtsp://<phone-lan-ip>:1935/`) for host reachability.
- Linux camera mode controls:
  - `LINUX_CAMERA_MODE=compatibility`
  - `LINUX_CAMERA_MODE=userspace`
  - `LINUX_CAMERA_MODE=auto`

## Current macOS User Flow (Preview)

1. Install host app with `desktop-av-bridge-host/installers/macos/install.command`.
2. Install `PhoneAVBridgeCamera.app` into `/Applications` and launch it.
3. `Phone AV Bridge Camera` auto-starts `Phone AV Bridge Host` in the background (when installed), and shows host bridge status in-app.
4. Install Android APK and open `Phone AV Bridge`.
5. Tap `Pair Host`, then enable `Camera` and/or `Microphone` on phone.
6. If camera is enabled, choose `Front` or `Back` lens on phone.
7. In Zoom/meeting app on macOS:
   - select `Phone AV Bridge Camera` as camera input,
   - select `PhoneAVBridgeAudio 2ch` as microphone input,
   - for phone speaker playback, route macOS output to `PhoneAVBridgeAudio 2ch` (or a Multi-Output device that includes it).

Notes:
- Host pairing identity is persisted at `~/.phone-av-bridge-host/state.json`.
- On first camera use, macOS requires one-time camera extension approval in `System Settings -> General -> Login Items & Extensions -> Camera Extensions`.

### Bridge Docker emulation

```bash
cd phone-av-camera-bridge-runtime
./tests/emulation/run_docker_emulation.sh
```

### Host Linux Docker E2E

```bash
cd desktop-av-bridge-host
bash tests/docker/run_linux_container_e2e.sh
```
