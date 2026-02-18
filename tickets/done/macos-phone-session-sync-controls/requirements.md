# Requirements

## Status
Design-ready

## Goal
Eliminate information gap between Android and macOS by showing paired phone/session state on macOS and allowing macOS-originated resource toggle control.

## Scope
- macOS `PRC Camera Host` UI and host API integration.
- No Android protocol redesign.

## Acceptance Criteria
1. macOS app shows whether a phone is paired and displays phone name/id from host state.
2. macOS app shows current camera/mic/speaker enabled states from host state and refreshes automatically.
3. macOS app provides toggle controls and can apply updates through host API when paired.
4. If camera/mic is requested without known stream URL, macOS app shows explicit actionable error.
5. Existing extension enable/disable behavior continues to work.

## Constraints
- Keep first-party host architecture (`PRCCamera` + `Host Resource Agent`).
- Keep no-legacy behavior; no duplicate old control paths added.

## Risks
- Transient host API unavailability while host bridge restarts.
- User may attempt macOS camera/mic enable before phone has published stream URL.
