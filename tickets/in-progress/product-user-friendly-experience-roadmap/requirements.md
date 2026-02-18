# Requirements: Rotation UX Hardening (Phase 1)

## Status
Design-ready

## Goal / Problem Statement
Fix the camera orientation user experience so users always get expected video direction in Zoom/Meet with minimal effort.

## Scope Triage
- Classification: Small
- Rationale:
  - Focus only on orientation behavior and related user controls.
  - No broad onboarding redesign in this phase.

## In-Scope Use Cases
- UC-001 User enables camera and gets correct default orientation in meeting apps.
- UC-002 User can switch between back/front lens while keeping orientation correct.
- UC-003 User can explicitly lock orientation from Android (Portrait or Landscape).
- UC-004 macOS host clearly shows current camera mode/orientation state from phone.

## Out Of Scope (Phase 1)
- Full onboarding/checklist redesign.
- Broad status-model refactor across all resources.
- Packaging/distribution process changes.

## Acceptance Criteria
1. With camera enabled, default output appears upright in Zoom/Meet without manual trial-and-error.
2. Android app exposes orientation control: `Auto`, `Portrait Lock`, `Landscape Lock`.
3. Switching front/back lens preserves expected orientation behavior.
4. macOS host UI displays orientation mode and active lens from phone status.
5. Orientation changes propagate to host within 2 seconds while paired.

## Constraints / Dependencies
- Android remains the source of truth for camera settings.
- macOS host remains read-only for camera controls.
- Must not require reboot or system-level manual steps for orientation behavior.

## Assumptions
- User keeps phone app in foreground while testing.
- Phone and host are already paired and connected.

## Open Questions / Risks
1. Should default mode be `Auto` or `Landscape Lock` for desktop-meeting-first users?
2. Some camera hardware reports sensor orientation differently; device-specific fallback may be needed.
