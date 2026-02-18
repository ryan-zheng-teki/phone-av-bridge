# Requirements: First-Party Virtual Devices (macOS + Linux)

## Requirement Version

- Current Version: `v2`
- Date: `2026-02-17`
- Trigger: Start a new track to remove external app dependency (OBS-style) and provide first-party virtual `Camera`, `Microphone`, and `Speaker` devices.

## Goal / Problem Statement

Deliver one first-party product that lets non-technical users install one Android app and one desktop host app, pair once, toggle `Camera`, `Microphone`, `Speaker`, and select phone-backed devices in meeting apps on macOS and Linux.

## Scope Triage

- Classification: `Large`
- Rationale:
  - System-level virtual media devices on two desktop OS families.
  - Device drivers/extensions/plugins + host runtime + pairing + installer UX.
  - Different platform constraints for macOS (CoreMediaIO / audio plugin path) and Linux (PipeWire/Pulse + compatibility fallbacks).

## Product Principles

- One first-party app install per desktop OS (no requirement to install OBS-like external app).
- Android app remains simple (install -> pair -> toggle).
- No terminal required for normal end users.
- Mac-first implementation order, Linux immediately after (both are priority tracks).
- Local testing mode must avoid signing/notarization requirements; release signing is a separate distribution concern.

## In-Scope Use Cases

- UC-001: Install Android app, grant permissions, pair host in <= 2 minutes.
- UC-002: Enable `Camera`; meeting app can select a phone-backed camera device.
- UC-003: Enable `Microphone`; meeting app can select a phone-backed mic input device.
- UC-004: Enable `Speaker`; desktop output can route to phone speaker.
- UC-005: Use all three resources concurrently without full restart.
- UC-006: Disconnect/reconnect recovery within acceptable time.
- UC-007: macOS install and first-run flow requires no external app install.
- UC-008: Linux install and first-run flow requires no manual driver commands for default path.
- UC-009: Host preflight automatically detects missing prerequisites and provides one-click remediation.

## Functional Requirements

- FR-001: Host publishes three virtual devices per paired phone: camera, mic, speaker route target.
- FR-002: Device naming includes phone identity for multi-phone scenarios.
- FR-003: Toggle changes propagate in <= 3 seconds on healthy LAN.
- FR-004: Failure isolation: camera/mic/speaker failures do not hard-stop unrelated active resources.
- FR-005: Pairing requires explicit action on Android and host.
- FR-006: No manual stream URL entry in normal flow.
- FR-007: Host desktop app exposes guided first-run steps and preflight results in UI (not terminal output only).
- FR-008: Installer and app updates preserve pairing identity and prior user routing choices where safe.

## Platform-Specific Requirements

### macOS (Priority 1)

- MR-001: Replace OBS dependency with first-party camera virtualization component.
- MR-002: Replace BlackHole dependency with first-party virtual audio path (mic + speaker route support).
- MR-003: Local testing mode must work without signing/notarization requirements (developer/testing mode).
- MR-004: Distribution mode supports signing/notarization pipeline (not required to unblock local development testing).
- MR-005: First-run permission prompts are guided by app UI.
- MR-006: Camera virtualization path must be implemented as first-party user-space extension/plugin packaging controlled by our installer/app.
- MR-007: Audio virtualization path must expose one selectable mic input and one selectable output route endpoint with phone-name-prefixed labels.

### Linux (Priority 2, starts immediately after macOS baseline)

- LR-001: First-party host runtime supports camera/mic/speaker virtualization using native Linux media stack.
- LR-002: Default path should avoid manual kernel-driver operations for end user.
- LR-003: Compatibility fallback may use kernel module path when required by specific meeting apps.
- LR-004: Installer auto-installs/validates required system packages where permitted.
- LR-005: Default path prefers PipeWire/Pulse user-space virtual nodes; kernel module fallback is off by default and only enabled via app UI.
- LR-006: Linux installer includes one-click dependency remediation for common distros (`apt`, `dnf`, `pacman`) and reports exact missing items if auto-remediation is unavailable.
- LR-007: Linux desktop app provides in-app test buttons (`test camera`, `test microphone`, `test speaker`) with visible pass/fail.

## Testing Requirements

- TR-001: Unit + integration test coverage for host control and adapter lifecycle.
- TR-002: Docker E2E for pair/toggle/state and media-route health checks.
- TR-003: Real-device E2E on macOS + physical Android + meeting app selection.
- TR-004: Real-device E2E on Ubuntu + physical Android + meeting app selection.
- TR-005: Testing mode must avoid reboot and avoid destructive system changes whenever possible.
- TR-006: For macOS and Linux, each release candidate must pass explicit checks for named camera/mic/speaker discovery in at least one meeting app.
- TR-007: Automated speaker-route validation must include non-silent PCM and manual audible verification note.
- TR-008: Any E2E step that cannot be automated in container/emulator must be documented with concrete reason and compensating manual test checklist.

## Acceptance Criteria

- AC-001: On macOS, user does not install OBS/BlackHole to use phone camera/mic/speaker flow.
- AC-002: On Linux, user install is app/package driven; no mandatory terminal operations in default flow.
- AC-003: Zoom/Meet/Teams can select phone-backed camera and mic devices.
- AC-004: Speaker-to-phone route works and is measurable in automated tests (non-silent PCM) and audible in manual test.
- AC-005: Installer and first-run flow are documented for non-technical users.
- AC-006: Device labels appear as `<Phone Name> Camera`, `<Phone Name> Microphone`, `<Phone Name> Speaker`.
- AC-007: Recovery from phone disconnect/reconnect restores resource availability without restarting the desktop app.

## Non-Goals (This Ticket)

- iOS implementation.
- Internet relay across different networks (LAN-first).
- Legacy compatibility with old OBS-based path in first-party mode.

## Risks

- macOS virtual device implementation complexity and API stability.
- Linux distro differences and meeting-app behavior inconsistencies.
- Audio latency and echo behavior across device combinations.
- Driver/extension packaging and OS-security prompts can vary by OS version and hardware.

## Open Questions

- Which meeting app matrix is mandatory for release gate (`Zoom + Meet` minimum, or include `Teams` in first gate).
- Exact Linux fallback policy per distro when PipeWire tooling is partially present.
