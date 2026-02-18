# phone-av-camera-bridge-runtime

Use an Android phone camera stream (LAN IP) as a webcam feed path for desktop meeting apps.

MVP status:

- Linux: implemented via RTSP ingest -> `v4l2loopback` output.
- Linux emulation: implemented via RTSP ingest -> null sink (`linux-null-emulator`) for containerized tests.
- Linux emulation: implemented via RTSP ingest -> null sink and file sink (`linux-null-emulator`, `linux-file-emulator`) for containerized tests.
- macOS: adapter contract documented; extension implementation deferred.

## Safety

- Scripts in this module are non-destructive and do not modify kernel/system state.
- You must install/load OS dependencies yourself (for example `v4l2loopback` on Linux).

## Files

- `bin/preflight.sh`: capability checks.
- `bin/run-simulated-source.sh`: no-phone RTSP source generator.
- `bin/run-bridge.sh`: main ingest -> sink runtime.
- `config/bridge.example.env`: config template.
- `docs/macos-camera-extension-adapter.md`: phase-2 adapter contract.
- `tests/smoke/preflight_smoke_test.sh`: smoke test for preflight behavior.
- `tests/emulation/run_docker_emulation.sh`: full Docker-based emulation harness.

## Quick Start

1. Run preflight:

```bash
./phone-av-camera-bridge-runtime/bin/preflight.sh
```

2. Create local config:

```bash
cp ./phone-av-camera-bridge-runtime/config/bridge.example.env ./phone-av-camera-bridge-runtime/config/bridge.local.env
```

3. Edit `bridge.local.env` with your phone RTSP URL.

4. Linux run:

```bash
./phone-av-camera-bridge-runtime/bin/run-bridge.sh --config ./phone-av-camera-bridge-runtime/config/bridge.local.env
```

Linux emulation run (no `/dev/video*` required):

```bash
STREAM_SOURCE_URL=rtsp://127.0.0.1:8554/live \
SINK_BACKEND=linux-null-emulator \
MAX_SECONDS=10 \
./phone-av-camera-bridge-runtime/bin/run-bridge.sh
```

Linux file-output emulation run:

```bash
STREAM_SOURCE_URL=rtsp://127.0.0.1:8554/live \
SINK_BACKEND=linux-file-emulator \
OUTPUT_FILE=/tmp/bridge-output.mp4 \
MAX_SECONDS=10 \
./phone-av-camera-bridge-runtime/bin/run-bridge.sh
```

5. Linux dry run (safe command preview):

```bash
./phone-av-camera-bridge-runtime/bin/run-bridge.sh --config ./phone-av-camera-bridge-runtime/config/bridge.local.env --dry-run
```

## Simulation Without Android Device

Generate a local synthetic clip (safe default):

```bash
./phone-av-camera-bridge-runtime/bin/run-simulated-source.sh --mode file --duration 5 --output /tmp/phone-av-camera-sim.mp4
```

Optional RTSP publish attempt (environment-dependent ffmpeg behavior):

```bash
./phone-av-camera-bridge-runtime/bin/run-simulated-source.sh --mode rtsp --host 127.0.0.1 --port 8554 --path /live
```

Bridge dry run example:

```bash
STREAM_SOURCE_URL=rtsp://127.0.0.1:8554/live \
SINK_BACKEND=linux-v4l2 \
V4L2_DEVICE=/dev/video2 \
./phone-av-camera-bridge-runtime/bin/run-bridge.sh --dry-run
```

## Zoom End-State

- Linux path: after bridge writes to loopback device, choose that camera in Zoom settings.
- macOS path: requires phase-2 Camera Extension adapter implementation first.

## Docker-Based Emulation (Host-Safe)

Run end-to-end emulation in isolated containers:

```bash
./phone-av-camera-bridge-runtime/tests/emulation/run_docker_emulation.sh
```

What it does:

- starts RTSP server container (`mediamtx`)
- starts synthetic RTSP publisher container (`ffmpeg testsrc`)
- runs bridge preflight in Linux test container
- runs bridge ingest pipeline in `linux-null-emulator` backend for bounded duration
- runs bridge ingest pipeline in `linux-file-emulator` backend and verifies output artifact
- runs `linux-v4l2` backend in dry-run mode to validate command generation

Notes:

- This emulation intentionally avoids host kernel/device mutation.
- Android emulator-in-container is not part of this harness; hardware acceleration (`/dev/kvm`) is typically unavailable in Docker Desktop environments.

## Known Limitations

- MVP supports `STREAM_SOURCE_PROTOCOL=rtsp` only.
- Default simulation mode writes a local file; RTSP simulation depends on ffmpeg/environment support.
- `linux-null-emulator` backend is for testing only; it validates ingest/decode path, not webcam device output.
- `linux-file-emulator` backend is for testing only; it validates ingest + encoded output artifact generation, not webcam device output.
- macOS camera output backend is not implemented in this MVP.
- Auto-retry loop is deferred; on disconnect, restart the bridge.
