# Requirements

- Ticket: `macos-camera-ui-polish-follow-up`
- Date: 2026-02-23
- Status: `Refined`
- Scope Triage: `Small`
- Triage Rationale: Refactor is limited to existing AppKit UI composition and controller state wiring; no protocol/API/storage/runtime contract changes.

## Goal / Problem Statement

Redesign the macOS host app setup flow into a guided, explicit journey so users clearly understand what to do first and why. The UI must make extension approval sequence obvious, then guide to phone pairing, with runtime logs available on a dedicated screen.

## In-Scope Use Cases

- `UC-1` Show a multi-screen guided journey with clear order.
- `UC-2` Enforce Step 1 (extension enablement) as the first required gate.
- `UC-3` Enforce Step 2 (phone connect/pair) before runtime-ready state.
- `UC-4` Keep runtime logs on a dedicated, scrollable screen.
- `UC-5` Auto-focus users to the first incomplete required step.

## Acceptance Criteria

1. UI shows 3 wizard screens with visible step chips:
- `1. Extension`, `2. Connect Phone`, `3. Runtime`.
2. Step 1 copy explicitly communicates order:
- click `Enable Extension` first,
- use `Open Settings` only if macOS approval prompt requires it.
3. Next-step navigation is gated:
- cannot proceed from Step 1 until extension readiness is detected,
- cannot proceed from Step 2 until host is online and phone is paired.
4. Auto-focus selects first incomplete required step on status refresh.
5. Runtime log is available on its own screen with vertical scrolling.
6. Existing host bridge controls, QR controls, resource status updates, and extension actions continue to work.

## Constraints / Dependencies

- AppKit-only changes in:
- `/Users/normy/autobyteus_org/phone-av-bridge/macos-camera-extension/samplecamera/ui/CameraMainViewBuilder.swift`
- `/Users/normy/autobyteus_org/phone-av-bridge/macos-camera-extension/samplecamera/ViewController.swift`
- No host API, Android behavior, or extension protocol changes.

## Assumptions

- The best onboarding UX is explicit sequencing and gating, not one long mixed content surface.
- Meeting-app verification (Zoom/Meet) is optional operational behavior, not part of required setup.

## Open Questions / Risks

- Extension readiness inference may still miss rare intermediate states; future hardening may add a stricter signal if needed.
