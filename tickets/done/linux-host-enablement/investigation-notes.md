# Investigation Notes

## Task Context
- User goal: make Linux host path production-ready for phone virtual camera/microphone/speaker flow in the current repository.
- Constraint: proceed autonomously and only ask user if absolutely blocked.

## Sources Consulted
- `README.md`
- `desktop-av-bridge-host/README.md`
- `desktop-av-bridge-host/desktop-app/server.mjs`
- `desktop-av-bridge-host/adapters/linux-camera/bridge-runner.mjs`
- `desktop-av-bridge-host/adapters/linux-audio/audio-runner.mjs`
- `desktop-av-bridge-host/core/preflight-service.mjs`
- `desktop-av-bridge-host/installers/linux/install.sh`
- `desktop-av-bridge-host/tests/docker/run_linux_container_e2e.sh`
- `tickets/done/first-party-mac-linux-virtual-devices/implementation-progress.md`

## Validation Evidence Collected
- Ran host unit/integration suite:
  - command: `cd desktop-av-bridge-host && npm test`
  - result: pass (`18/18`)
- Ran Linux Docker E2E:
  - command: `cd desktop-av-bridge-host && npm run test:docker:linux-e2e`
  - result: pass
  - observed state: `/api/status` reported `"Resource Active"` with `camera=true`, `microphone=true`, `speaker=true`, and `issues=[]`.
  - speaker stream check: non-silent PCM sample (`rms` > 0).
- Ran real Android-device Linux E2E (2026-02-18):
  - device authorized via ADB and app controlled through UI automation.
  - phone paired to host `http://192.168.2.124:8787`.
  - camera/microphone/speaker toggles validated with host status + process evidence.
  - speaker endpoint delivered non-silent PCM while host generated tone.

## Key Findings
- Linux camera/microphone/speaker runtime path is functionally working in automated E2E validation.
- A Linux reliability bug exists in camera shutdown:
  - file: `desktop-av-bridge-host/adapters/linux-camera/bridge-runner.mjs`
  - logic currently checks `if (!active.killed) active.kill('SIGKILL')` after sending `SIGTERM`.
  - in Node.js, `child.killed` becomes `true` immediately after `kill()` is called, so SIGKILL fallback may never run.
  - risk: `stopCamera()` can hang waiting for `exit` when child does not terminate promptly.

## Unknowns / Risks
- Physical Linux meeting-app device selection (Zoom/Meet/Teams) is not verifiable in this headless environment.
- Distro-specific desktop environments may vary in Pulse/PipeWire defaults even when adapter logic is correct.
- Follow-up run exercised true v4l2 webcam exposure mode after user loaded `v4l2loopback`; remaining risk is only per-meeting-app UI selection behavior.

## Implications
- Scope can be treated as `Small`: targeted fix in Linux camera adapter shutdown path plus regression tests.
- Success criteria should emphasize deterministic route shutdown/restart behavior and no regression in existing Linux E2E path.
