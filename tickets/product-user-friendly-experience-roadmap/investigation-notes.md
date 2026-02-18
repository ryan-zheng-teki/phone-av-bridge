# Investigation Notes

## Sources Consulted
- `/Users/normy/autobyteus_org/phone-resource-companion/README.md`
- `/Users/normy/autobyteus_org/phone-resource-companion/android-resource-companion/app/src/main/res/layout/activity_main.xml`
- `/Users/normy/autobyteus_org/phone-resource-companion/android-resource-companion/app/src/main/java/org/autobyteus/resourcecompanion/MainActivity.kt`
- `/Users/normy/autobyteus_org/phone-resource-companion/android-resource-companion/app/src/main/java/org/autobyteus/resourcecompanion/stream/PhoneRtspStreamer.kt`
- `/Users/normy/autobyteus_org/phone-resource-companion/macos-camera-extension/samplecamera/ViewController.swift`
- `/Users/normy/autobyteus_org/phone-resource-companion/host-resource-agent/linux-app/static/index.html`
- `/Users/normy/autobyteus_org/phone-resource-companion/tickets/stability-performance-ux-hardening/requirements.md`
- `/Users/normy/autobyteus_org/phone-resource-companion/tickets/macos-readonly-resource-status-ui/requirements.md`

## Current Product Behavior (As-Is)
- Multi-surface user journey:
  - Android app controls resources.
  - macOS PRCCamera app shows host + resource state.
  - Host Resource Agent runs separately.
- Pairing and status are functional but still cognitively heavy for non-technical users.
- Several setup actions are implicit (camera extension approval, host running, audio route expectation).
- Orientation handling is not explicit from user perspective; users can see sideways video depending on phone pose.

## High-Impact UX Friction Points
1. Installation mental model is fragmented (Android app + PRCCamera + Host Resource Agent).
2. Users are asked to infer system state from technical logs/status text.
3. Recovery path is not clear enough when state becomes degraded (paired but route not active).
4. Manual troubleshooting depends on technical knowledge (host port, extension settings, route choices).
5. Verification steps are distributed across apps rather than a single guided flow.

## Constraints
- Cross-platform: Android + macOS + Linux host path.
- Must preserve camera/mic/speaker capabilities while simplifying user decisions.
- Must avoid legacy dual-control models that create state drift.
- Existing architecture already has pairing, status polling, and resource toggles; improvements should reuse these foundations.

## Unknowns / Risks
- Gatekeeper/notarization behavior differs across user machines.
- Third-party meeting apps refresh device lists differently.
- Network quality and phone vendor differences can still impact stream quality.

## Implications For Requirements/Design
- Product success requires a "single guided journey" rather than more technical controls.
- UX must shift to intent-driven states with explicit fix actions.
- Host and phone should expose one canonical truth model for desired vs applied state.
- Packaging/distribution must reduce setup ambiguity and produce a clear install contract.
