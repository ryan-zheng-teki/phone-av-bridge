# Implementation Plan

## Solution Sketch (Small Scope Design Basis)
1. Expand Android discovery target set:
- Add subnet-directed broadcast addresses from active interfaces.
- Keep existing `255.255.255.255` and emulator `10.0.2.2` targets.
- De-duplicate targets and send discovery packet to each.

2. Reconcile pairing state from host status before applying resources:
- In `refreshHostStatusIfPaired()`, when status fetch succeeds and host says `paired=false`, clear local paired flag + resource toggles and move UI back to Not Paired.
- Apply foreground resource state only if host snapshot confirms paired.

3. Remove unconditional startup publish/apply from `onCreate()`:
- Do not call `applyForegroundServiceState()` before reconciliation pass.
- Let reconciliation drive service state.

## Planned File Changes
- Modify: `android-resource-companion/.../network/HostDiscoveryClient.kt`
- Modify: `android-resource-companion/.../MainActivity.kt`

## Verification Strategy
- Unit/build: `./gradlew :app:assembleDebug`
- Device integration:
  - Clear app data, launch app, verify initial Not Paired state.
  - Pair via UI, verify host `paired=true`.
  - Unpair/reset host then refresh; verify Android local paired state clears.
- E2E feasibility:
  - Full Zoom/Meet E2E not required for this bugfix.
  - Runtime verification via app UI + host API is feasible and required.
