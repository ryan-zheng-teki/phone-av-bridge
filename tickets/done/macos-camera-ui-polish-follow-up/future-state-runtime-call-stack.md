# Future-State Runtime Call Stack

- Ticket: `macos-camera-ui-polish-follow-up`
- Version: `v3`
- Scope: `Small`
- Design Basis: `/Users/normy/autobyteus_org/phone-av-bridge/tickets/in-progress/macos-camera-ui-polish-follow-up/implementation-plan.md`

## Use Case Coverage Summary

| use_case_id | primary path | fallback path | error path |
| --- | --- | --- | --- |
| UC-1-guided-wizard-screens | Yes | N/A | N/A |
| UC-2-extension-first-gating | Yes | N/A | Yes |
| UC-3-phone-connect-gating | Yes | N/A | Yes |
| UC-4-runtime-log-screen | Yes | N/A | N/A |
| UC-5-auto-focus-first-incomplete | Yes | N/A | N/A |

## UC-1 Guided Wizard Screens

1. `samplecamera/ViewController.swift:viewDidLoad()`
2. `samplecamera/ViewController.swift:configureInterface()`
3. `samplecamera/ui/CameraMainViewBuilder.swift:build(in:target:)`
4. Builder creates:
- step chips (`1. Extension`, `2. Connect Phone`, `3. Runtime`),
- `NSTabView` wizard with 3 tab items,
- Back/Next navigation buttons.
5. `configureInterface()` binds builder refs into controller properties.

## UC-2 Extension-First Gating

### Primary Path

1. User is on Step 1 tab (`wizard-step-extension`).
2. `ViewController.activate(_:)` triggers `activateCamera()`.
3. Extension status signals update through delegate callbacks and `updateStatusBadge(...)`.
4. `updateWizardJourney(autoFocus:)` calls `isExtensionStepComplete()`.
5. Step chip + next-button state updates:
- Next button enabled only when extension is complete,
- hint text explains order: enable first, open settings only if prompted.

### Error Path

1. Extension request fails in `request(_:didFailWithError:)`.
2. `updateStatusBadge("Error", ...)` executes.
3. `updateWizardJourney(autoFocus:true)` keeps Step 1 incomplete and blocks Step 2 navigation.

## UC-3 Phone Connect Gating

### Primary Path

1. Host status changes in `refreshHostBridgeStatus(...)`.
2. Resource/pair state updates in `refreshHostResourceStatus()`.
3. `updateWizardJourney(autoFocus:true)` evaluates `isPhoneStepComplete()` (`hostBridgeIsRunning && paired`).
4. On completion, Step 2 chip becomes complete and Next-to-Runtime is enabled.

### Error Path

1. Host status fetch fails.
2. `resetHostResourceSection(bridgeOnline:true)` and `showMessage("host status read failed")` run.
3. `updateWizardJourney(autoFocus:true)` keeps Step 2 incomplete.

## UC-4 Runtime Log Screen

1. Builder places runtime monitor controls on Step 3 tab (`wizard-step-runtime`).
2. `showMessage(...)` appends timestamped logs to `logTextView`.
3. `NSScrollView` with vertical scroller keeps runtime logs navigable during testing.

## UC-5 Auto-focus First Incomplete Step

1. `updateWizardJourney(autoFocus:true)` runs after status-changing events.
2. If extension incomplete -> select `wizard-step-extension`.
3. Else if phone incomplete -> select `wizard-step-connect`.
4. Else keep or allow runtime screen.

## Async / State Notes

- Async boundaries: host health callback, host status callback, QR callbacks, system extension delegate callbacks.
- State mutations: step chips, wizard button enabled states, status badges, hint label text, runtime log text storage.
