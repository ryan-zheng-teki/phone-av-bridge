# Implementation Plan

## Scope Classification

- Classification: `Large`
- Active Delivery Objective: `True end-to-end for non-technical users (Android + Linux first, then macOS parity)`

## Plan Maturity

- Current Status: `Execution In Progress`
- Runtime Call Stack Review Gate: `Go` (confirmed for design/call-stack `v3` in review rounds 8-9)
- Requirement Baseline: `requirements.md v3` (`zero-technical-setup` + Linux Docker validation)

## Current User-Facing Status (2026-02-17)

- Android app can be built, installed, and tested in emulator.
- Android app now includes embedded RTSP media server path for camera/microphone toggles.
- Android RTSP camera pipeline has been validated in emulator with H264 stream output after OpenGL background-path fix.
- Android RTSP camera/microphone pipeline has been validated on a physical Android phone with direct LAN probe (`H264 + AAC`).
- Linux-first host app/API slice is implemented and test-validated.
- macOS host path is implemented with OBS Virtual Camera + BlackHole integration (non-extension packaging approach).
- Host installers now create start/stop launchers; macOS installer also creates a clickable `.app` bundle.
- Host release archive now bundles a Node runtime so installed launchers can run without a preinstalled system Node in default path.
- Android-to-host control transport is implemented (auto-discovery + pair + toggle publish over LAN HTTP).
- Linux microphone virtual route is implemented (RTSP audio -> Pulse/PipeWire virtual sink monitor path).
- Linux speaker virtual route is implemented (Pulse monitor capture -> `/api/speaker/stream` PCM pull path).
- One-container Linux Docker E2E validation now passes (`camera + microphone + speaker` control path with RTSP publisher + Pulse routing).
- End-to-end meeting-app device selection path still requires final real Linux desktop validation (physical phone + Zoom/device list confirmation).

## Sequencing Strategy

1. Linux-first complete path (fastest to production-grade end-to-end).
2. macOS camera path.
3. macOS audio parity.

## Step-By-Step Plan

1. T-001: Keep Android app stable (`pair/unpair`, three toggles, permission-safe foreground service).
2. T-002: Implement host core (pairing, encrypted control/media channel, capability negotiation). `In Progress` (pair code + discovery + state orchestration complete; encrypted transport pending)
3. T-003: Build Linux host desktop app shell (GUI app + tray/status + start-on-login option). `In Progress` (web UI/API shell + launcher/start-stop flow complete; tray/start-on-login pending)
4. T-004: Implement Linux camera adapter and expose selectable webcam device. `In Progress` (managed bridge runner complete; real-device selection validation pending)
5. T-005: Implement Linux audio adapters for virtual mic + virtual speaker route. `Completed`
6. T-006: Add Linux dependency preflight checks with one-click remediation guidance in host UI.
7. T-007: Package Linux app for non-technical install path (`AppImage` + one distro-native package). `In Progress` (installer + launchers + bundled runtime archive complete; AppImage/native package pending)
8. T-008: Execute Linux end-to-end validation: Android toggle -> host device -> Zoom/meeting app selection. `In Progress` (Docker one-container E2E complete; real meeting-app selection pending)
9. T-009: Complete macOS one-time system approval flow validation for OBS Camera Extension.
10. T-010: Validate macOS Zoom device selection (`OBS Virtual Camera`, `BlackHole 2ch`) in real meeting-app run.
11. T-011: Package/sign/notarize macOS host app and validate non-technical install flow.

## Non-Technical User Definition Of Done

- User does not open terminal.
- User installs Android app + host app and completes first pairing in <= 2 minutes.
- User can select phone camera and mic in a meeting app without manual technical steps.
- If dependency or permission is missing, host app provides guided, click-driven remediation.

## Validation Strategy

- Emulator:
  - Android UI/toggle/service behavior and connected instrumentation suite.
- Containerized/dev harness:
  - host core protocol, pairing, discovery, and state transitions.
- Linux real environment:
  - virtual device exposure and meeting-app interoperability.
- macOS real environment:
  - camera/audio extension behavior and signing/distribution.

## Known Non-Emulatable Gaps

- Real sensor quality/latency and thermal behavior.
- Real LAN variability and roaming behavior.
- Final meeting-app interoperability guarantees across vendor builds.
