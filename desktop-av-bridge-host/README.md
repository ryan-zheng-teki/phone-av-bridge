# desktop-av-bridge-host

Linux/macOS host application layer for the Android Phone AV Bridge workflow.

## Goals

- non-technical host UX (`Not Paired`, `Paired`, `Resource Active`, `Needs Attention`)
- no manual stream URLs in default flow
- preflight diagnostics with guided remediation hints
- Linux and macOS execution with minimal user setup
- user-safe issue messages (camera/microphone/speaker) instead of raw adapter errors

## Quick start (developer)

```bash
cd desktop-av-bridge-host
npm test
npm run start:mock
```

Then open `http://127.0.0.1:8787`.

## End-user install behavior

- Linux installer creates:
  - app launcher: `Phone AV Bridge Host`
  - start command: `~/.local/bin/phone-av-bridge-host-start`
  - stop command: `~/.local/bin/phone-av-bridge-host-stop`
  - log file: `~/.local/state/phone-av-bridge-host/phone-av-bridge-host.log`
  - camera mode defaults:
    - `LINUX_CAMERA_MODE=compatibility` when compatibility camera deps are installed
    - `LINUX_CAMERA_MODE=userspace` when installed with `INSTALL_COMPAT_CAMERA=0`
- macOS installer creates:
  - app bundle: `~/Applications/Phone AV Bridge Host.app`
  - start command: `~/Applications/PhoneAVBridgeHost/start.command`
  - stop command: `~/Applications/PhoneAVBridgeHost/stop.command`
  - log file: `~/Library/Logs/PhoneAVBridgeHost/phone-av-bridge-host.log`
  - dependency bootstrap:
    - Homebrew (when available): `ffmpeg`
    - first-party camera app: `PhoneAVBridgeCamera.app` (camera extension host)
    - first-party audio driver: `PhoneAVBridgeAudio.driver` (installed by host installer)
  - persisted pairing state:
    - file: `~/.phone-av-bridge-host/state.json`
    - keeps pairing code + paired phone identity across host restarts
- Bundled runtime:
  - release artifacts now include `runtime/node/bin/node`
  - installer launchers use bundled runtime first and only fall back to system `node`

## Runtime modes

- `USE_MOCK_ADAPTERS=1`: deterministic test-safe mode.
- default mode:
  - Linux:
    - `LINUX_CAMERA_MODE=compatibility`: RTSP -> `v4l2loopback` camera device.
    - `LINUX_CAMERA_MODE=userspace`: RTSP ingest validation path (`linux-null-emulator`).
    - `LINUX_CAMERA_MODE=auto`: use `v4l2` when configured device exists; otherwise userspace ingest path.
    - RTSP audio -> Pulse/PipeWire virtual mic route.
    - host speaker capture -> phone speaker stream.
  - macOS: RTSP -> Phone AV Bridge Camera frame socket (camera extension), RTSP audio -> Phone AV Bridge Audio route, host speaker capture -> phone speaker stream.
- host auto-discovery (UDP) is enabled by default on port `39888`.

## Pairing and discovery

- HTTP bootstrap endpoint: `GET /api/bootstrap`
- UDP discovery probe payload: `PHONE_AV_BRIDGE_DISCOVER_V1`
- Host returns `baseUrl` and one-time startup `pairingCode`
- Pairing code is persisted across host restarts by default (can be disabled with `PERSIST_STATE=0`).
- Pairing endpoint requires matching code: `POST /api/pair`
- Presence endpoint for pre-pair phone identity updates: `POST /api/presence`
- Toggle endpoint supports Android-provided stream URL:
  - `POST /api/toggles` body keys include `camera`, `microphone`, `speaker`, `cameraStreamUrl`, `deviceName`, `deviceId`
  - `POST /api/pair` also accepts optional `deviceName` and `deviceId`.
  - `POST /api/presence` accepts optional `deviceName` and `deviceId`.

## Media flow (Android -> Linux host)

- Android app starts an embedded RTSP server when camera/microphone toggles are enabled.
- Android publishes `cameraStreamUrl` to host on toggle updates.
- Linux camera path:
  - compatibility mode: host camera adapter pulls RTSP and writes to configured `v4l2loopback` device.
  - userspace mode: host validates ingest/decode path without exposing a loopback webcam device.
- Linux microphone path:
  - host audio adapter creates a per-phone Pulse/PipeWire null sink/source (name includes phone identity),
  - host runs ffmpeg RTSP audio -> Pulse sink,
  - meeting apps can select the generated source as microphone input (`Monitor of PhoneAVBridgeMic-<phone>-<id>`).
- Linux speaker path:
  - host prefers default Pulse/PipeWire monitor source, but excludes bridge-owned microphone sources (`phone_av_bridge_mic_*`) to avoid mic-to-speaker loopback,
  - if no safe monitor exists, host falls back to other safe non-bridge sources; if none exist, speaker route reports unavailable,
  - optional override: set `LINUX_SPEAKER_CAPTURE_SOURCE=<source-name>` to force a specific Pulse/PipeWire source,
  - Android app pulls this stream when `Enable Speaker` is toggled.
- macOS microphone path:
  - host routes RTSP audio to `PhoneAVBridgeAudio 2ch`,
  - meeting apps can select the Phone AV Bridge Audio-backed virtual route as `<Phone Name> Microphone`.
- macOS speaker path:
  - host exposes a raw PCM stream endpoint at `/api/speaker/stream`,
  - Android app pulls this stream when `Enable Speaker` is toggled.
  - capture stream is normalized to explicit PCM format/sample-rate/channels before transport.
  - speaker capture now uses filter fallback (`aresample` variants) for ffmpeg compatibility across builds that differ on advanced filter options.

## Android UX behavior (current)

- App shows explicit host status and status detail (`Not paired`, `Pairing`, `Paired and ready`, `Paired with host sync issue`).
- App shows host summary and active issues returned by host status API.
- While unpaired, Android now shows discovered host preview (`Host discovered: ...`) before user taps Pair.
- Host keeps last-seen/nearby phone identity in status while unpaired, so macOS host UI can show the phone before pair completion.
- Pairing failures are categorized into:
  - discovery failure,
  - host unreachable,
  - pair rejected,
  - unknown host error.
- Camera/microphone/speaker toggles remain independent and are still one-tap.

## Linux prerequisites for real meeting-app use

- `ffmpeg` installed.
- PulseAudio or PipeWire with `pactl` available for microphone virtual routing.
- For webcam device exposure in meeting apps:
  - `LINUX_CAMERA_MODE=compatibility` and `v4l2loopback` module loaded with writable target (default `/dev/video2`).
  - default camera card label is `AutoByteusPhoneCamera` to simplify app-side selection.
  - installer can auto-provision compatibility packages/module; override with `INSTALL_COMPAT_CAMERA=0` for userspace-only setup.

## macOS prerequisites for real meeting-app use

- `ffmpeg` installed.
- `PhoneAVBridgeCamera.app` installed/running and camera extension approved in:
  - `System Settings -> General -> Login Items & Extensions -> Camera Extensions`
- `PhoneAVBridgeAudio.driver` installed (host installer runs `macos-audio-driver/scripts/install-driver.sh`).

## Packaging artifacts

```bash
npm run build:release
```

Generated archives are stored under `dist/`.
Each release run also prepares a local bundled Node runtime for the current build platform.

Build Debian package (Ubuntu/Debian):

```bash
./scripts/build-deb-package.sh 0.1.2
```

Generated package:

- `dist/phone-av-bridge-host_<version>_<arch>.deb`

## Installer scripts

- Linux:
  - run `installers/linux/install.sh`
  - optional env controls:
    - `INSTALL_COMPAT_CAMERA=0` to skip loopback camera dependency install.
    - `LINUX_CAMERA_MODE_DEFAULT=userspace|compatibility|auto` to choose startup default.
    - `V4L2_DEVICE_DEFAULT=/dev/videoN` to set preferred compatibility device.
    - `V4L2_CARD_LABEL=YourCameraLabel` to set visible camera name in meeting apps.
  - app launcher name: `Phone AV Bridge Host`
  - Debian package installs provide:
    - `phone-av-bridge-host-start`
    - `phone-av-bridge-host-stop`
    - `phone-av-bridge-host-enable-camera` (sudo helper to force-reload `v4l2loopback` after kernel/module changes)
  - uninstall: `installers/linux/uninstall.sh`
- macOS:
  - run `installers/macos/install.command`
  - install target: `~/Applications/PhoneAVBridgeHost`
  - uninstall: `installers/macos/uninstall.command`

## Current limitations

- macOS and Linux host-side routing paths are E2E validated at host level (automated scripts + live host status checks).
- Final per-meeting-app UX still depends on each app refreshing device lists after permission/extension changes.
- On Linux, compatibility webcam exposure still depends on `v4l2loopback` availability/configuration.
