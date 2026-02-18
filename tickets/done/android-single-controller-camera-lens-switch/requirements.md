# Requirements

## Status
Design-ready

## Goal / Problem Statement
Provide a predictable control model where Android is the only controller for phone resources (camera/microphone/speaker), macOS is a read-only mirror of host state, and Android offers explicit Front/Back camera selection while macOS still exposes one virtual camera device.

## Scope Triage
- Scope: Medium
- Rationale: Cross-platform behavioral change touching Android UI/state/service/stream pipeline and macOS host UI interaction behavior.

## In-Scope Use Cases
- UC-001 Android authoritative control
  - User pairs phone and changes camera/microphone/speaker toggles on Android.
  - Host state updates and macOS reflects the new state.
- UC-002 macOS read-only mirror
  - User views resource states on macOS but cannot apply state changes from macOS UI.
- UC-003 Android lens selection
  - User selects `Back` or `Front` lens on Android.
  - When camera streaming is active, selected lens is used and remains persisted across app restarts.
- UC-004 Stability and continuity
  - Existing pair/unpair flow and host status/issue display continue to work.

## Acceptance Criteria
1. `PRC Camera Host` macOS app does not post toggle mutations to `/api/toggles`.
2. macOS resource checkboxes are non-editable and clearly operate as status indicators.
3. Android app has a front/back camera selector in the main control card.
4. Android persists selected lens in app preferences.
5. Foreground service applies selected lens to RTSP camera stream when camera is enabled.
6. Host still exposes a single camera device (`Phone Resource Companion Camera`) on macOS.
7. Android toggles remain the only active mutation path and continue publishing `/api/toggles`.

## Constraints / Dependencies
- No backward compatibility path for macOS-driven toggle control; remove write path cleanly.
- Preserve existing host API surface and pairing contract.
- Keep one macOS camera extension device only.
- Lens selection must degrade safely on devices missing selected lens.

## Assumptions
- Most target phones provide both front and back lens options.
- Stream mode without camera (microphone-only or speaker-only) should ignore lens choice.

## Open Questions / Risks
- Risk: some vendor camera HALs may fail explicit lens switch without restart.
- Mitigation: route lens choice through camera-id targeting with explicit error handling and existing retry/publish loop.
