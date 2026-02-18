# Requirements: macOS First-Party Virtual Audio Driver

## Status
- Current: `Design-ready`
- Draft captured from user request: yes
- Design-ready refinement complete: yes

## Goal / Problem Statement
Replace the macOS BlackHole dependency with a first-party virtual audio driver so end users can install Phone Resource Companion only (Android app + macOS host package) and select phone-backed `Microphone` and `Speaker` routes in meeting apps without extra third-party installs.

## Scope Triage
- Classification: `Large`
- Rationale:
  - New system-level macOS audio driver/plugin and installer/signing workflow.
  - Cross-layer changes across host runtime, packaging, preflight, and end-to-end test harness.
  - Real-time audio correctness, crash isolation, and multi-device naming requirements.

## In-Scope Use Cases
- UC-001: User installs host package and gets first-party virtual microphone device visible in macOS apps.
- UC-002: User selects phone-backed microphone in Zoom/Meet/OBS and hears phone mic audio.
- UC-003: User routes desktop audio to phone speaker using first-party output route.
- UC-004: User toggles camera/microphone/speaker independently from Android app.
- UC-005: Multiple paired phones have distinct phone-name-prefixed audio device labels.
- UC-006: Driver/runtime restarts recover without requiring a reboot.

## Acceptance Criteria
- AC-001: No BlackHole dependency in installer, runtime preflight, docs, or runtime code paths.
- AC-002: macOS exposes a first-party selectable input device with phone-name-prefixed label.
- AC-003: macOS exposes a first-party selectable output route (speaker path) with phone-name-prefixed label.
- AC-004: Host toggles `microphone` and `speaker` on/off without crashing host app or macOS audio service.
- AC-005: End-to-end validation passes with real Android phone + macOS host for mic and speaker paths.
- AC-006: Failure handling is explicit (degraded route state, user-visible issue message, recovery steps).

## Constraints / Dependencies
- C-001: macOS virtual audio remains in AudioServerPlugIn model for virtual devices.
- C-002: Plugin runs sandboxed with restricted filesystem access and must declare needed capabilities.
- C-003: Realtime I/O path must avoid blocking operations to prevent glitches.
- C-004: Installer/distribution must handle signing/notarization policy for production releases.
- C-005: Driver install/remove may require audio service restart (`coreaudiod`) but must not require kernel extensions.

## Assumptions
- A-001: We continue existing camera extension path (PRCCamera) unchanged in this ticket.
- A-002: Android app already provides stable RTSP audio source and speaker stream endpoint.
- A-003: During development, local signing can be used before release-grade notarization pipeline.

## Risks
- R-001: Buggy plugin logic can destabilize audio routing and require audio-service recovery.
- R-002: Realtime safety regressions can cause glitches/latency spikes under load.
- R-003: macOS version changes can alter plugin behavior or install friction.
- R-004: Speaker-route semantics (virtual output device vs dedicated routing helper) may need iterative UX refinement.

## Open Questions
- Q-001: Do we ship a single combined device (input+output) or split mic/output devices per phone?
- Q-002: Should speaker route become default output automatically or remain opt-in only?
- Q-003: What minimum macOS version do we guarantee for first-party audio path?

## No-Legacy Policy (Mandatory)
- Legacy/compatibility requirement: none.
- Remove BlackHole-based runtime checks, install steps, and route hints in this implementation track.
