# Requirements

## Status
Design-ready

## Goal
Make macOS flow operational from one visible app (`PRCCamera`) by automatically starting/monitoring host discovery service required by Android pairing.

## Scope
- PRCCamera app UX and host-service startup integration.
- No Android protocol changes.
- No host-agent server API changes.

## Acceptance Criteria
1. When PRCCamera opens and host service is offline, it attempts to start Host Resource Agent automatically.
2. PRCCamera displays host bridge online/offline state in UI.
3. User can manually retry start and open host UI from PRCCamera.
4. When host bridge is online, macOS listens on TCP `8787` and UDP `39888`.
5. Existing camera extension enable/disable behavior remains unchanged.

## Constraints
- Keep current architecture (camera extension app + host resource agent).
- No legacy fallback behavior retained beyond explicit robust path lookup.

## Risks
- Host Resource Agent missing on disk.
- macOS app-location variability (`~/Applications` vs `/Applications`).
