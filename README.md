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
- `GET /api/bootstrap` (pairing code + base URL + host metadata)
- `POST /api/bootstrap/qr-token` (issue one-time QR token payload)
- `POST /api/bootstrap/qr-redeem` (redeem one-time QR token to bootstrap)
- `POST /api/pair`
- `POST /api/presence` (pre-pair phone identity heartbeat)
- `POST /api/toggles`
- UDP discovery flow on port `39888`: Android sends probe `PHONE_AV_BRIDGE_DISCOVER_V1`, host replies with bootstrap JSON.

### Android app

```bash
cd android-phone-av-bridge
./gradlew testDebugUnitTest
```

## Current Linux User Flow (Preview)

1. Install host app with `desktop-av-bridge-host/installers/linux/install.sh`.
2. Launch `Phone AV Bridge Host` from app menu (or `~/.local/bin/phone-av-bridge-host-start`).
3. Install Android APK and open `Phone AV Bridge`.
4. In Android app, either:
   - tap `Pair Host` to discover hosts on LAN (single host quick-pair, multi-host explicit selection), or
   - tap `Scan QR Pairing` to pair explicitly with a host-generated QR token.
5. Enable `Camera`, `Microphone`, and/or `Speaker`.
6. In Zoom/meeting app on Linux:
   - in compatibility mode, select camera device `AutoByteusPhoneCamera`,
   - select the virtual mic source matching `PhoneAVBridgeMicInput-<phone>-<id>` (fallback may appear as `Monitor of PhoneAVBridgeMic-<phone>-<id>`),
   - for phone speaker playback, host now avoids bridge mic sources by default; if needed, set `LINUX_SPEAKER_CAPTURE_SOURCE` to force a specific source.

Notes:
- Camera/mic media is sent from Android via in-app RTSP server.
- Android publishes RTSP endpoint as LAN IPv4 (`rtsp://<phone-lan-ip>:1935/`) for host reachability.
- Debian package install (`dpkg -i`) auto-configures persistent `v4l2loopback` loading for compatibility mode.
- Debian package also creates persistent host config at `/etc/default/phone-av-bridge-host`; use `sudo phone-av-bridge-host-set-speaker-source <source|auto>` instead of temporary `export`.
- Linux camera mode controls:
  - `LINUX_CAMERA_MODE=compatibility`
  - `LINUX_CAMERA_MODE=userspace`
  - `LINUX_CAMERA_MODE=auto`

## Current macOS User Flow (Preview)

1. Install host app with `desktop-av-bridge-host/installers/macos/install.command`.
2. Install `PhoneAVBridgeCamera.app` into `/Applications` and launch it.
3. `Phone AV Bridge Camera` auto-starts `Phone AV Bridge Host` in the background (when installed), and shows host bridge status in-app.
4. Install Android APK and open `Phone AV Bridge`.
5. In Android app, either tap `Pair Host` (LAN discovery + host selection) or `Scan QR Pairing` (explicit host via QR token).
6. Enable `Camera` and/or `Microphone` on phone.
7. If camera is enabled, choose `Front` or `Back` lens on phone.
8. In Zoom/meeting app on macOS:
   - select `Phone AV Bridge Camera` as camera input,
   - select `PhoneAVBridgeAudio 2ch` as microphone input,
   - for phone speaker playback, route macOS output to `PhoneAVBridgeAudio 2ch` (or a Multi-Output device that includes it).

Notes:
- Host pairing identity is persisted at `~/.phone-av-bridge-host/state.json`.
- Host UI now shows QR pairing code automatically and supports one-click `Regenerate QR Code`.
- On first camera use, macOS requires one-time camera extension approval in `System Settings -> General -> Login Items & Extensions -> Camera Extensions`.
- If `PhoneAVBridgeCamera.app` was downloaded from GitHub Releases, remove quarantine after copying to `/Applications`:
  `sudo xattr -dr com.apple.quarantine /Applications/PhoneAVBridgeCamera.app`

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

## Tag-Based GitHub Releases

This repository includes a release workflow at:

- `.github/workflows/release.yml`

Trigger a release by pushing a tag:

```bash
git tag v0.1.2
git push origin v0.1.2
```

Published release assets:

- Android APK (`release` if signing secrets are configured, otherwise `debug`)
- macOS camera app archive (`PhoneAVBridgeCamera` unsigned zip)
- Linux Debian package (`phone-av-bridge-host_<version>_<arch>.deb`)
- `SHA256SUMS.txt`

## End-User Installation Guides

These steps are for non-developer users installing from GitHub Releases.

### macOS (camera app + host app)

1. Download these release assets:
   - `PhoneAVBridgeCamera-macos-<version>-unsigned.zip`
   - `PhoneAVBridge-<version>-android-*.apk`
2. Install `PhoneAVBridgeCamera.app`:

```bash
VERSION="<release-version>"
APP_ZIP="$HOME/Downloads/PhoneAVBridgeCamera-macos-${VERSION}-unsigned.zip"
TMP_DIR="$(mktemp -d)"
unzip -q "$APP_ZIP" -d "$TMP_DIR"
sudo rm -rf /Applications/PhoneAVBridgeCamera.app
sudo ditto "$TMP_DIR/PhoneAVBridgeCamera.app" /Applications/PhoneAVBridgeCamera.app
sudo xattr -dr com.apple.quarantine /Applications/PhoneAVBridgeCamera.app
open -a /Applications/PhoneAVBridgeCamera.app
```

3. Install the host service app (currently from this repo install script):

```bash
git clone https://github.com/ryan-zheng-teki/phone-av-bridge.git
cd phone-av-bridge/desktop-av-bridge-host
./installers/macos/install.command
open "$HOME/Applications/Phone AV Bridge Host.app"
```

4. In macOS System Settings, approve camera extension:
   - `System Settings -> General -> Login Items & Extensions -> Camera Extensions`
5. Install the Android APK on phone and pair to host.
6. In Zoom/Meet/FaceTime, select:
   - Camera: `Phone AV Bridge Camera`
   - Microphone: `PhoneAVBridgeAudio 2ch`

If camera app keeps reopening after you close it, stop host first:

```bash
~/Applications/PhoneAVBridgeHost/stop.command
```

### Linux (Debian/Ubuntu host + Android APK)

1. Download these release assets:
   - `phone-av-bridge-host_<version>_amd64.deb`
   - `PhoneAVBridge-<version>-android-*.apk`
2. Install host package:

```bash
VERSION="<release-version>"
sudo apt install -y "$HOME/Downloads/phone-av-bridge-host_${VERSION}_amd64.deb"
```

3. Start host:

```bash
phone-av-bridge-host-start
```

4. Install Android APK on phone and pair to host.
5. In Zoom/Meet on Linux:
   - Camera: `AutoByteusPhoneCamera` (compatibility mode).
   - Microphone: `PhoneAVBridgeMicInput-<phone>-<id>` (fallback name may appear as `Monitor of PhoneAVBridgeMic-...`).
   - Speaker routing to phone is controlled from Android app `Enable Speaker`.

Linux troubleshooting quick checks:

```bash
# Host process + live status
ps -ef | rg 'desktop-app/server.mjs' | rg -v rg
curl -s http://127.0.0.1:8787/api/status | jq '{resources:.status.resources,routeHints:.status.routeHints,issues:.status.issues}'

# Virtual microphone sources
pactl list short sources | rg 'phone_av_bridge_mic'

# Host logs
tail -n 120 ~/.local/state/phone-av-bridge-host/phone-av-bridge-host.log
```

If microphone does not appear in Zoom/Discord:
- Fully quit and reopen the app (device list is often cached).
- Confirm `PhoneAVBridgeMicInput-*` exists in `pactl list short sources`.

If voice sounds doubled:
- Restart host once to clear stale media workers:

```bash
phone-av-bridge-host-stop
phone-av-bridge-host-start
```

If you need to pin speaker capture source persistently (advanced):

```bash
sudo phone-av-bridge-host-set-speaker-source <source-name>
# Return to automatic safe selection:
sudo phone-av-bridge-host-set-speaker-source auto
```

Stop host:

```bash
phone-av-bridge-host-stop
```

Uninstall host:

```bash
sudo apt remove -y phone-av-bridge-host
```

Optional Android signing secrets (GitHub repository secrets):

- `ANDROID_KEYSTORE_B64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
