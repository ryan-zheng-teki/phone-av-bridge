# Implementation Plan

- Ticket: `macos-camera-ui-polish-follow-up`
- Date: 2026-02-23
- Status: `Finalized (Refined)`
- Scope: `Small`
- Review Gate: `Go Confirmed` (`v3`)

## Requirement Traceability

| Requirement | Call Stack Use Cases | Planned Changes | Verification |
| --- | --- | --- | --- |
| Guided multi-screen journey | UC-1 | C1 | Manual UI smoke + screenshot |
| Extension-first setup with conditional settings action | UC-2 | C1, C2 | Manual behavior check |
| Phone connect gating before runtime | UC-3 | C2 | Manual behavior check |
| Dedicated runtime log screen with scrolling | UC-4 | C1 | Manual UI smoke |
| Auto-focus first incomplete required step | UC-5 | C2 | Manual behavior check |

## Change Inventory

| Change ID | Type | File | Description |
| --- | --- | --- | --- |
| C1 | Modify | `/Users/normy/autobyteus_org/phone-av-bridge/macos-camera-extension/samplecamera/ui/CameraMainViewBuilder.swift` | Replace dense single-flow/checklist layout with guided 3-screen wizard (`Extension`, `Connect Phone`, `Runtime`) and navigation controls. |
| C2 | Modify | `/Users/normy/autobyteus_org/phone-av-bridge/macos-camera-extension/samplecamera/ViewController.swift` | Add wizard journey state derivation, required-step gating, auto-focus, and explicit extension/settings guidance updates. |
| C3 | Modify | `/Users/normy/autobyteus_org/phone-av-bridge/macos-camera-extension/samplecamera/ui/CameraMainViewBuilder.swift` + `/Users/normy/autobyteus_org/phone-av-bridge/macos-camera-extension/samplecamera/ViewController.swift` | Refine visual sizing and default window behavior for better readability and less empty space at launch. |

## Execution Order

1. Implement wizard UI structure and references (`C1`).
2. Wire journey logic and button gating in controller (`C2`).
3. Tune sizing/spacing/window defaults for practical desktop UX (`C3`).
4. Build signed app and verify installed bundle path.
5. Capture screenshot evidence and sync planning/progress docs.

## Verification Strategy

- Build/install: `./scripts/build-signed-local.sh`
- Launch path verification:
- `/Users/normy/Applications/PhoneAVBridgeCamera.app`
- `ps` path check for running process.
- Manual UX verification:
- step chips visible,
- Step 1/Step 2 gating works,
- runtime log screen remains scrollable,
- extension/settings relationship is explicit in Step 1 copy.
