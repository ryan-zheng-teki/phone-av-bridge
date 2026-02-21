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

### macOS camera app (local dev build + install)

```bash
cd macos-camera-extension
./scripts/build-signed-local.sh
```

Default behavior of `build-signed-local.sh`:
- cleans old local build output first,
- builds with project-local derived data (`macos-camera-extension/build`),
- installs to `~/Applications/PhoneAVBridgeCamera.app`,
- prunes duplicate `/Applications/PhoneAVBridgeCamera.app` copies.

### Real-Device Startup Checklist (Important)

Use this for physical Android testing, especially when multiple hosts are on the same LAN.

1. Resolve this Mac/Linux host LAN IP (example on macOS):

```bash
ipconfig getifaddr en0
```

2. Start host with explicit bind/advertise/port values:

```bash
cd desktop-av-bridge-host
HOST_BIND=0.0.0.0 ADVERTISED_HOST=<LAN_IP> PORT=8787 node desktop-app/server.mjs
```

3. Verify host health and advertised bootstrap URL:

```bash
curl -s http://127.0.0.1:8787/health
curl -s http://127.0.0.1:8787/api/bootstrap | jq '.bootstrap.baseUrl,.bootstrap.pairingCode'
```

4. In Android host list, select the entry whose URL matches `<LAN_IP>:8787`, then tap `Pair` (or `Switch` if already paired).

5. Only use loopback advertise mode for USB-reverse debugging:

```bash
adb reverse tcp:8787 tcp:8787
HOST_BIND=0.0.0.0 ADVERTISED_HOST=127.0.0.1 PORT=8787 node desktop-app/server.mjs
```

Troubleshooting:
- If Android keeps pairing to a wrong remembered host, clear app state and retry:

```bash
adb shell pm clear org.autobyteus.phoneavbridge
```

- If macOS seems to open an old camera app build, force deterministic launch path:

```bash
pkill -f 'PhoneAVBridgeCamera.app/Contents/MacOS/PhoneAVBridgeCamera' || true
open "$HOME/Applications/PhoneAVBridgeCamera.app"
```

- Reason: `open -a PhoneAVBridgeCamera` prefers `/Applications/PhoneAVBridgeCamera.app` if multiple copies exist (`/Applications` and `~/Applications`), which can start an older bundle.

## Current Linux User Flow (Release .deb)

1. Download `phone-av-bridge-host_<version>_amd64.deb` from GitHub Releases.
2. Install with:

```bash
sudo apt install -y ./phone-av-bridge-host_<version>_amd64.deb
```

3. Start host:

```bash
phone-av-bridge-host-start
```

4. Verify host is up:

```bash
curl -s http://127.0.0.1:8787/health
```

5. Install Android APK, pair, and enable `Camera` / `Microphone` / `Speaker`.
6. In Zoom/Meet on Linux:
   - Camera: `AutoByteusPhoneCamera`
   - Microphone: `PhoneAVBridgeMicInput-<phone>-<id>`

Notes:
- Debian package commands are installed under `/usr/bin` (not `~/.local/bin`).
- Prefer `apt install ./...deb` over `dpkg -i ...deb` so apt can resolve system dependencies.
- Local developer installer (`desktop-av-bridge-host/installers/linux/install.sh`) is still available, but release users should use the `.deb`.

## Current macOS User Flow (Preview)

1. Install host app with `desktop-av-bridge-host/installers/macos/install.command`.
2. Install `PhoneAVBridgeCamera.app` into `/Applications` and launch it.
3. `Phone AV Bridge Camera` auto-starts `Phone AV Bridge Host` in the background (when installed), and shows host bridge status in-app.
4. Install Android APK and open `Phone AV Bridge`.
5. In Android app, select a host from the visible host list and tap `Pair`; while already paired, select another host and tap `Switch`; or use `Scan QR Pairing` for explicit QR pairing.
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
git tag v0.1.8
git push origin v0.1.8
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
2. Install host package (important: use `apt`, not `dpkg -i`):

```bash
VERSION="<release-version>"
sudo apt install -y "./phone-av-bridge-host_${VERSION}_amd64.deb"
```

3. Start host:

```bash
phone-av-bridge-host-start
```

4. Verify host:

```bash
curl -s http://127.0.0.1:8787/health
```

5. Install Android APK on phone and pair to host.
6. In Zoom/Meet on Linux:
   - Camera: `AutoByteusPhoneCamera` (compatibility mode).
   - Microphone: `PhoneAVBridgeMicInput-<phone>-<id>` (fallback name may appear as `Monitor of PhoneAVBridgeMic-...`).
   - Speaker routing to phone is controlled from Android app `Enable Speaker`.

Linux quick checks (only if something fails):

```bash
# Host logs
tail -n 120 ~/.local/state/phone-av-bridge-host/phone-av-bridge-host.log

# Restart host once
phone-av-bridge-host-stop
phone-av-bridge-host-start
```

If you need fixed speaker capture source (advanced):

```bash
sudo phone-av-bridge-host-set-speaker-source <source-name>
sudo phone-av-bridge-host-set-speaker-source auto
```

Stop host:

```bash
phone-av-bridge-host-stop
```

Uninstall host:

```bash
sudo apt purge -y phone-av-bridge-host v4l2loopback-dkms v4l2loopback-utils
```

Optional Android signing secrets (GitHub repository secrets):

- `ANDROID_KEYSTORE_B64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
