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

## Linux quick install (release .deb)

```bash
VERSION="<release-version>"
sudo apt install -y "./phone-av-bridge-host_${VERSION}_amd64.deb"
phone-av-bridge-host-start
curl -s http://127.0.0.1:8787/health
```

If startup fails:

```bash
tail -n 120 ~/.local/state/phone-av-bridge-host/phone-av-bridge-host.log
```

## End-user install behavior

- Linux local installer (`installers/linux/install.sh`) creates:
  - app launcher: `Phone AV Bridge Host`
  - start command: `~/.local/bin/phone-av-bridge-host-start`
  - stop command: `~/.local/bin/phone-av-bridge-host-stop`
  - log file: `~/.local/state/phone-av-bridge-host/phone-av-bridge-host.log`
  - camera mode defaults:
    - `LINUX_CAMERA_MODE=compatibility` when compatibility camera deps are installed
    - `LINUX_CAMERA_MODE=userspace` when installed with `INSTALL_COMPAT_CAMERA=0`
- Linux Debian package (`.deb`) installs:
  - start command: `/usr/bin/phone-av-bridge-host-start`
  - stop command: `/usr/bin/phone-av-bridge-host-stop`
  - desktop launcher: `/usr/share/applications/phone-av-bridge-host.desktop`
  - host payload: `/opt/phone-av-bridge-host`
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
- Discovery direction: Android broadcasts probe UDP packet, host replies with bootstrap JSON to requester address.
- Host bootstrap includes `baseUrl`, startup `pairingCode`, and host identity (`hostId`, `displayName`, `platform`).
- QR pairing endpoints:
  - `POST /api/bootstrap/qr-token` issues single-use token payload (`token`, `expiresAt`, payload JSON),
  - `POST /api/bootstrap/qr-redeem` redeems token and returns bootstrap.
- Host UI behavior:
  - QR code is generated automatically when host UI loads,
  - QR auto-refreshes shortly before expiry,
  - `Regenerate QR Code` lets user issue a fresh token immediately.
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
  - host audio adapter creates a per-phone Pulse/PipeWire null sink (name includes phone identity),
  - host runs ffmpeg RTSP audio -> Pulse sink with low-latency defaults, and exposes a remapped virtual mic source for app compatibility,
  - meeting apps should select `PhoneAVBridgeMicInput-<phone>-<id>` as microphone input,
  - host treats remapped source creation as required; if remap creation fails, microphone route start fails with explicit error.
  - optional tuning via host environment:
    - `LINUX_MIC_LOW_LATENCY=1` (default; set `0`/`false`/`off`/`no` to disable low-latency ffmpeg flags),
    - `LINUX_MIC_PULSE_LATENCY_MSEC=30` (default, valid range `10..500`),
    - `LINUX_MIC_RTSP_TRANSPORT=tcp` (default; can be set to `udp` on clean local networks).
- Linux speaker path:
  - host prefers default Pulse/PipeWire monitor source, but excludes bridge-owned microphone sources (`phone_av_bridge_mic_*`) to avoid mic-to-speaker loopback,
  - if no safe monitor exists, host falls back to other safe non-bridge sources; if none exist, speaker route reports unavailable,
  - optional override:
    - Debian install: set `LINUX_SPEAKER_CAPTURE_SOURCE=<source-name>` in `/etc/default/phone-av-bridge-host` or run `sudo phone-av-bridge-host-set-speaker-source <source-name>`,
    - local installer: set `LINUX_SPEAKER_CAPTURE_SOURCE=<source-name>` in `~/.config/phone-av-bridge-host/env`,
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
- `Pair Host` now uses explicit pairing behavior:
  - 1 discovered host: quick pair after explicit tap,
  - multiple discovered hosts: Android shows host picker and user selects target host.
- Android also supports explicit QR path (`Scan QR Pairing`) by scanning host-generated QR payload and redeeming one-time token.
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
    - `phone-av-bridge-host-set-speaker-source` (sudo helper for persistent speaker capture source override)
    - `phone-av-bridge-host-enable-camera` (sudo helper to force-reload `v4l2loopback` after kernel/module changes)
    - default config file: `/etc/default/phone-av-bridge-host`
  - uninstall: `installers/linux/uninstall.sh`
- macOS:
  - run `installers/macos/install.command`
  - install target: `~/Applications/PhoneAVBridgeHost`
  - uninstall: `installers/macos/uninstall.command`

## Current limitations

- macOS and Linux host-side routing paths are E2E validated at host level (automated scripts + live host status checks).
- Final per-meeting-app UX still depends on each app refreshing device lists after permission/extension changes.
- On Linux, compatibility webcam exposure still depends on `v4l2loopback` availability/configuration.

## Linux quick troubleshooting

Use these checks when a meeting app does not show devices or audio behaves unexpectedly.

```bash
# Host process + status summary
ps -ef | rg 'desktop-app/server.mjs' | rg -v rg
curl -s http://127.0.0.1:8787/api/status | jq '{resources:.status.resources,routeHints:.status.routeHints,issues:.status.issues}'

# Virtual sources/sinks from host bridge
pactl list short sources | rg 'phone_av_bridge_mic'
pactl list short sinks | rg 'phone_av_bridge_mic'

# Recent host logs
tail -n 120 ~/.local/state/phone-av-bridge-host/phone-av-bridge-host.log
```

Common actions:
- Mic not visible in Zoom/Discord: fully quit and reopen the app, then choose `PhoneAVBridgeMicInput-<phone>-<id>`.
- Doubled/echoed outgoing voice: run `phone-av-bridge-host-stop` then `phone-av-bridge-host-start` to clear stale workers.
- Persistent speaker source override (advanced): `sudo phone-av-bridge-host-set-speaker-source <source-name>` or `sudo phone-av-bridge-host-set-speaker-source auto`.
- Mic was working, then suddenly disappears or stops capturing (PipeWire/WirePlumber stale stream restore):

```bash
# 1) fully quit meeting/browser apps first (Zoom, Chrome, Discord)
phone-av-bridge-host-stop || true

# 2) restart user audio graph
systemctl --user restart wireplumber pipewire pipewire-pulse

# 3) start host again
phone-av-bridge-host-start
```

- If instability keeps returning, do a one-time cleanup of stale bridge restore entries:

```bash
cp ~/.local/state/wireplumber/restore-stream ~/.local/state/wireplumber/restore-stream.bak.$(date +%s)
tmpf=$(mktemp)
grep -vE 'phone_av_bridge|PhoneAVBridgeMicInput|Google\\sChrome\\sinput|ZOOM\\sVoiceEngine' ~/.local/state/wireplumber/restore-stream > "$tmpf" || true
mv "$tmpf" ~/.local/state/wireplumber/restore-stream
systemctl --user restart wireplumber pipewire pipewire-pulse
phone-av-bridge-host-start
```
