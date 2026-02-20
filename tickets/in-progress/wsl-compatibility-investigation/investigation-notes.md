# Investigation Notes - WSL Compatibility

## Task
Assess whether the Linux host path and voice CLI in this repository can be installed and used on Windows Subsystem for Linux (WSL).

## Sources Consulted

### Local repository
- `README.md`
- `desktop-av-bridge-host/README.md`
- `desktop-av-bridge-host/installers/linux/install.sh`
- `desktop-av-bridge-host/adapters/linux-camera/bridge-runner.mjs`
- `desktop-av-bridge-host/adapters/linux-audio/audio-runner.mjs`
- `phone-av-camera-bridge-runtime/README.md`
- `phone-av-camera-bridge-runtime/bin/run-bridge.sh`
- `phone-av-camera-bridge-runtime/bin/preflight.sh`
- `voice-codex-bridge/README.md`
- `voice-codex-bridge/cli.py`

### External primary references
- Microsoft WSL configuration doc: https://raw.githubusercontent.com/MicrosoftDocs/WSL/live/WSL/wsl-config.md
- Microsoft WSL USB doc: https://raw.githubusercontent.com/MicrosoftDocs/WSL/live/WSL/connect-usb.md
- Microsoft WSLg architecture README: https://raw.githubusercontent.com/microsoft/wslg/main/README.md
- Microsoft WSL2 Linux kernel config (6.6 branch): https://raw.githubusercontent.com/microsoft/WSL2-Linux-Kernel/linux-msft-wsl-6.6.y/arch/x86/configs/config-wsl

## Key Findings
1. Linux camera compatibility mode in this repo depends on `v4l2loopback` and `/dev/video*`.
2. Linux audio path and voice CLI depend on Pulse/PipeWire tooling (`pactl`, `parec`) and `ffmpeg`.
3. This repo supports a userspace camera mode (`linux-null-emulator`) that validates ingest but does not expose a webcam device.
4. WSL USB passthrough is not native and requires `usbipd-win`; this impacts Android USB/ADB-on-USB usage.
5. WSL supports custom kernel-module VHD configuration (`kernelModules`), which is relevant if `v4l2loopback` is needed.
6. WSLg provides Linux GUI + PulseAudio audio in/out plumbing for Linux apps.

## Constraints and Implications
- Installing the Linux package/host inside WSL is feasible.
- Full Linux meeting-app virtual camera behavior requires `v4l2loopback` availability in that WSL kernel environment.
- If `v4l2loopback` is unavailable, the host can still run with userspace camera mode, but no virtual webcam exposure occurs.
- Voice CLI can run when WSL has working Pulse capture path (`parec`/`pactl`).
- USB workflows (e.g., direct Android USB attachment) add WSL setup complexity (`usbipd-win`).

## Open Unknowns
- Whether the user's current WSL distro/kernel setup has module path ready for `v4l2loopback` installation and loading.
- Whether target meeting apps will run inside Linux (WSL GUI) vs native Windows.

## Preliminary Verdict
- `Can install`: Yes, with caveats.
- `Works fully out-of-the-box in WSL`: No, not guaranteed.
- `Most likely to work first`: host + voice CLI + userspace camera mode.
- `Hard part`: compatibility camera (`/dev/video*`) path via `v4l2loopback` under WSL.
