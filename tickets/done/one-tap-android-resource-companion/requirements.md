# Requirements: One-Tap Phone Resource Companion (Android First)

## Requirement Version

- Current Version: `v3`
- Date: `2026-02-17`
- Trigger: Added Linux speaker implementation + single-container Docker E2E validation scope.

## Goal / Problem Statement

Enable non-technical users to install one Android app and one desktop host app, then use phone `Camera`, `Microphone`, and `Speaker` in meeting apps (for example Zoom) with no terminal commands, no manual stream URLs, and no driver commands.

## Scope Triage

- Classification: `Large`
- Rationale:
  - Multi-platform app + system-level virtual device exposure.
  - Camera + bidirectional audio + pairing + installer UX.
  - Linux and macOS have different device virtualization and packaging constraints.

## Current End-To-End Readiness Snapshot (As Of 2026-02-17)

- Android app camera/microphone streaming is validated on emulator and physical phone.
- Host app is implemented for Linux and macOS with installer + preflight UX.
- Camera + microphone + speaker paths are functional on macOS.
- Linux camera + microphone + speaker control path is validated in one-container Docker E2E using emulated camera backend (`linux-null-emulator`) and PulseAudio routing.
- macOS camera path still has one OS-level gate: first-time user approval for OBS Camera Extension.

## Product Requirement: Zero-Technical Setup

- End users must only:
  1. install Android app,
  2. install desktop host app,
  3. pair once,
  4. toggle resources.
- End users must not need:
  - shell/terminal commands,
  - manual device-node operations,
  - manual URL copy/paste,
  - custom scripts,
  - developer options on phone.

## In-Scope Use Cases

- UC-001: User installs Android app, grants permissions, and pairs host in <= 2 minutes.
- UC-002: User enables `Camera`; desktop meeting apps can select a phone camera device.
- UC-003: User enables `Microphone`; desktop meeting apps can select a phone microphone input device.
- UC-004: User enables `Speaker`; desktop audio output can route to phone speaker.
- UC-005: User toggles each resource independently without restarting the full stack.
- UC-006: Temporary network interruption auto-recovers and status is shown clearly.
- UC-007: Linux user installs host app via GUI installer/package manager and starts from app icon.
- UC-008: macOS user installs signed host app and grants required permissions with guided UI.
- UC-009: First-run host setup auto-checks dependencies and offers one-click remediation or clear guided action.

## Out-Of-Scope For First Delivery Slice

- Internet relay across different networks (LAN-first only).
- iOS implementation (tracked separately after Android-first completion).

## Acceptance Criteria

- Functional:
  - No manual stream URL entry in normal flow.
  - Pairing requires explicit user confirmation on both devices.
  - Desktop OS exposes resources as standard selectable devices for meeting apps.
- UX:
  - Android app shows only `Camera`, `Microphone`, `Speaker` toggles and connection status.
  - Host app shows simple status: `Not Paired`, `Paired`, `Resource Active`, `Needs Attention`.
  - Toggle effect visible on host in <= 3 seconds under healthy LAN.
- Installer/Setup:
  - Linux: packaged installation path (for example `.deb`/`.rpm`/AppImage) with GUI launch entry.
  - macOS: signed/notarized app install path with first-run setup wizard.
  - No shell commands in default user documentation.
- Reliability:
  - One resource failure does not hard-stop other enabled resources.
  - Reconnect after transient LAN drop target < 10 seconds.
- Security:
  - Encrypted control/media transport.
  - No plaintext key/token logging.
- Supportability:
  - Host app includes preflight diagnostics and actionable error messages.

## Platform-Specific Requirements

### Android

- Runtime camera/microphone permission flow.
- Foreground-service compliant operation for active resources.
- Local network discovery and explicit pairing.

### Linux Host

- Camera virtualization (target: `v4l2loopback`) behind host app UX.
- Audio virtualization (target: PipeWire/Pulse virtual endpoints) behind host app UX.
- Dependency checks performed by host app with guided remediation.

### macOS Host

- Camera virtualization via OBS Virtual Camera integration.
- Audio virtualization path via BlackHole virtual audio device.
- Signed/notarized distribution and user-guided permissions flow.

## Existing Components vs Missing Components

- Existing:
  - Android app shell + toggle lifecycle + emulator test coverage.
  - Android embedded RTSP media-serving path wired from toggle lifecycle (camera + mic modes).
  - Linux-first host app shell (`host-resource-agent`) with local UI/API and tests.
  - LAN pairing bootstrap/discovery protocol (`/api/bootstrap` + UDP discovery + pair code validation).
- Missing:
  - Encrypted production transport/control channel between Android and host.
  - Final Linux production validation in real meeting apps (Zoom/Teams) for camera/microphone/speaker device discoverability.
  - macOS first-run camera-extension approval automation + final meeting-app validation.

## Assumptions

- User has Android 12+ device and stable LAN.
- User can install desktop applications but is not expected to run terminal commands.
- Meeting-app integration uses standard OS device selection.

## Risks

- macOS virtual audio implementation and distribution complexity.
- Linux distribution fragmentation for packaging/dependency automation.
- Meeting-app-specific quirks in device enumeration timing.

## Open Questions

- Preferred host app stack (Rust/Go/TS + UI framework) for fastest reliable packaging on Linux/macOS.
- Linux packaging strategy priority (`AppImage` first vs distro-native packages first).
- Whether Linux speaker route should be enabled by default in all host builds or guarded by a feature flag per distro family.
