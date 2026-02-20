# Requirements - WSL Compatibility Investigation

## Status
Design-ready

## Goal / Problem Statement
Determine if the Linux host/runtime path and `voice-codex` CLI can be installed and used in WSL, and define the practical support boundaries.

## In-Scope Use Cases
- UC-001: Install Linux host package/scripts inside WSL and start host service.
- UC-002: Run voice CLI (`voice-codex`) in WSL and capture microphone input.
- UC-003: Run Linux camera route in WSL compatibility mode (virtual webcam path via `v4l2loopback`).
- UC-004: Run Linux camera in userspace-only mode when compatibility mode is unavailable.

## Acceptance Criteria
- Clear yes/no + caveated answer for WSL installability and expected runtime behavior.
- Explicit dependency mapping for camera/microphone/speaker/voice CLI in WSL.
- Clear distinction between "works in WSL Linux apps" and "works with native Windows apps" implications.

## Constraints / Dependencies
- WSL distro must provide Linux userspace dependencies (`ffmpeg`, `pactl`, `parec`, Node runtime).
- Compatibility camera path depends on `v4l2loopback` and `/dev/video*` device presence.
- USB passthrough in WSL requires `usbipd-win` setup.

## Assumptions
- User is using WSL 2 (not WSL 1).
- User wants practical runtime outcome, not only package installation.

## Open Questions / Risks
- Target meeting app location (inside WSL Linux vs native Windows) is not yet confirmed.
- WSL kernel/module environment for `v4l2loopback` is unverified on the user's machine.

## Scope Triage
Small

## Triage Rationale
This is an investigation-only scope (no code change required) focused on dependency/runtime compatibility and expected behavior boundaries.
