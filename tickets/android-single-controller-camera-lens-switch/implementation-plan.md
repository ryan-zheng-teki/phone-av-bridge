# Implementation Plan

## Scope
Implement Android single-controller mode + Android front/back lens selector + macOS read-only mirror behavior.

## Requirement Traceability
| Requirement | Design Section | Use Case | Planned Tasks | Planned Verification |
|---|---|---|---|---|
| AC-1 macOS no `/api/toggles` write | macOS mirror-only mode | UC-002 | T-004 remove/disable macOS write path | macOS build + UI behavior check |
| AC-2 macOS read-only indicators | macOS mirror-only mode | UC-002 | T-004 + T-005 UX text/state update | manual UI validation |
| AC-3 Android lens selector UI | Android lens selection | UC-003 | T-001 layout/strings + MainActivity binding | Android unit/build + UI smoke |
| AC-4 lens persistence | Android lens selection | UC-003 | T-002 AppPrefs + enum | Android unit/build |
| AC-5 lens applied to stream | Android lens selection | UC-003 | T-003 ResourceService + PhoneRtspStreamer | Android build + host status smoke |
| AC-6 one macOS virtual camera device | target-state summary | UC-003 | T-004 no extra device path added | macOS app behavior validation |
| AC-7 Android-only mutation path | Android control authority | UC-001/UC-004 | T-006 remove host->Android toggle sync | Android behavior + host API smoke |

## Tasks (Bottom-Up)
1. T-001 Add Android lens UI controls and strings.
2. T-002 Add `CameraLens` model + `AppPrefs` persistence APIs.
3. T-003 Extend `ResourceToggleState`, `ResourceService`, and `PhoneRtspStreamer` to propagate/apply selected lens.
4. T-004 Convert macOS resource section to read-only mirror (disable write path and toggling actions).
5. T-005 Update macOS UI copy/log hints to indicate Android is the controller.
6. T-006 Remove Android host-status back-write path (`syncPrefsFromHostSnapshot` flow).
7. T-007 Update README behavior documentation.
8. T-008 Run verification suite and summarize residual risk.

## Verification Strategy
- Unit/build:
  - Android: `./gradlew testDebugUnitTest assembleDebug`.
  - Host (regression): `pnpm test` in host-resource-agent.
  - macOS: `scripts/build-signed-local.sh`.
- Integration:
  - Host status/toggle API smoke with `curl /api/status` and Android publish path active.
- E2E feasibility:
  - Fully automated physical phone interaction is constrained when ADB device is unavailable.
  - Best available: local integration + live host status verification + app build/run validation.

## E2E Constraint Note
If physical device is not connected, final phone UI lens-switch visual assertion is blocked; capture as residual risk with explicit note in progress tracker.
