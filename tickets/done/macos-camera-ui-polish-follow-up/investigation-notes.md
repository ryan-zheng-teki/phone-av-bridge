# Investigation Notes

- Ticket: `macos-camera-ui-polish-follow-up`
- Date: 2026-02-23
- Stage: `Understanding Pass (Updated)`

## Sources Consulted

- User screenshot evidence from conversation (long, clipped, and confusing single-flow UI).
- User clarifications in conversation:
- first required action must be extension enablement,
- `Open Settings` is conditional follow-up only when macOS approval is requested,
- explicit step-by-step journey is preferred over dense single-page layout.
- `/Users/normy/autobyteus_org/phone-av-bridge/macos-camera-extension/samplecamera/ui/CameraMainViewBuilder.swift`
- `/Users/normy/autobyteus_org/phone-av-bridge/macos-camera-extension/samplecamera/ViewController.swift`
- Local runtime verification screenshot: `/tmp/phoneavbridge-ui-wizard-v5.png`

## Current Entrypoints And Execution Boundaries

- UI entrypoint: `ViewController.viewDidLoad()` -> `configureInterface()` -> `CameraMainViewBuilder.build(in:target:)`.
- Journey state derivation and gating: `isExtensionStepComplete()`, `isPhoneStepComplete()`, `updateWizardJourney(autoFocus:)`.
- User navigation controls: `previousWizardStep(_:)`, `nextWizardStep(_:)`.
- Runtime state updates that feed journey refresh:
- `updateStatusBadge(...)`,
- `refreshHostBridgeStatus(...)`,
- `refreshHostResourceStatus()`,
- `resetHostResourceSection(...)`.

## Key Findings

1. The UX problem was not feature absence; it was sequence ambiguity.
- Users did not know that extension enablement is logically first and host connection is second.

2. `Enable Extension` and `Open Settings` are not equivalent actions.
- `Enable Extension` triggers the system extension activation request.
- `Open Settings` is only a remediation/support path when user approval is required by macOS.

3. A guided multi-screen flow reduces cognitive load.
- Step 1: Extension.
- Step 2: Connect phone.
- Step 3: Runtime monitor (operational/testing view).

4. Journey gating must be explicit in UI behavior, not only text.
- Step 2 navigation is blocked until Step 1 is complete.
- Step 3 navigation is blocked until phone is connected.
- Auto-focus returns to the first incomplete required step.

5. Runtime log remains available as a dedicated scrollable screen and is not buried below long setup content.

## Constraints

- Preserve host/pairing/status/runtime behavior; this ticket is UI-flow only.
- Keep implementation in existing AppKit builder/controller seam.
- Avoid protocol/API changes across host or Android components.

## Open Unknowns / Risks

- Extension completion signal still uses available runtime indicators (`sourceStream`, status badge state), which may need future hardening for rare edge conditions.

## Implications For Requirements And Design

- Requirements should define a required two-step setup journey plus one operational runtime screen.
- Call stack and review artifacts must verify journey gating and explicit relation between `Enable Extension` and `Open Settings`.
- Visual sizing should avoid oversized empty layouts and keep controls readable by default at launch.
