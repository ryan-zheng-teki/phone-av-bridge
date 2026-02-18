# Proposed Design (v1)

## Current State (As-Is)
- Android and macOS can both mutate host resource toggles.
- Android polls host status and may overwrite local toggle prefs from host snapshot.
- Android camera streaming has no explicit user lens selector.
- macOS UI checkboxes are writable and currently auto-apply to host.

## Target State (To-Be)
- Android is the single mutation authority for camera/microphone/speaker toggles.
- macOS host app displays read-only resource states (mirror only).
- Android UI includes persisted front/back lens selector.
- Android streamer applies selected lens when camera is enabled.
- macOS continues exposing one virtual camera device only.

## Design Overview
### Android control authority
- Remove host-to-Android toggle reconciliation in `MainActivity`.
- Keep Android publish path (`applyForegroundServiceState` + service periodic publish) as sole mutation channel.

### Android lens selection
- Add `CameraLens` enum model (`BACK`, `FRONT`).
- Persist lens preference in `AppPrefs`.
- Extend `ResourceToggleState` with `cameraLens`.
- Pass lens through `ResourceService` intent extras and into `PhoneRtspStreamer.update(...)`.
- In streamer, resolve desired camera ID via `CameraManager` and apply with `switchCamera(String)` when needed.

### macOS mirror-only mode
- Keep host status polling and display.
- Disable interactive mutation path (no `/api/toggles` from macOS app).
- Keep checkboxes for visual state only (disabled controls).

## Change Inventory
| Path | Change Type | Responsibility | Public/API Impact |
|---|---|---|---|
| `android-resource-companion/.../model/CameraLens.kt` | Add | Canonical camera lens enum | Internal only |
| `android-resource-companion/.../store/AppPrefs.kt` | Modify | Persist/retrieve camera lens preference | Internal only |
| `android-resource-companion/.../model/ResourceToggleState.kt` | Modify | Carry lens selection through runtime state | Internal only |
| `android-resource-companion/.../service/ResourceService.kt` | Modify | Propagate lens to streamer and service intent | Internal only |
| `android-resource-companion/.../stream/PhoneRtspStreamer.kt` | Modify | Apply explicit front/back camera targeting | Internal only |
| `android-resource-companion/.../MainActivity.kt` | Modify | Android-only control flow + lens UI behavior | Internal only |
| `android-resource-companion/.../res/layout/activity_main.xml` | Modify | Add front/back selector controls | UI only |
| `android-resource-companion/.../res/values/strings.xml` | Modify | Lens selector labels + guidance | UI copy |
| `macos-camera-extension/samplecamera/ViewController.swift` | Modify | Read-only mirror behavior for resources | macOS host app behavior |
| `README.md` | Modify | Product usage docs reflect Android-only control | User docs |

## Naming Decisions
- New enum name: `CameraLens`.
  - Rationale: short and explicit domain term; avoids camera2-specific wording in UI/state model.
- Preference key: `camera_lens`.
  - Rationale: stable, readable key name matching enum semantic.
- No rename of existing `ResourceToggleState`.
  - Rationale: still the correct state carrier; scope extends with lens field.

## Naming Drift Check
- `ResourceToggleState`: still represents runtime resource state including camera sub-selection -> `N/A` (no drift).
- `ViewController` resource checkboxes: now mirror-only but names remain accurate -> `N/A`.
- No rename/split required in this scope.

## Dependency Flow
- Android UI (`MainActivity`) -> state/prefs (`AppPrefs`, `ResourceToggleState`) -> service (`ResourceService`) -> stream (`PhoneRtspStreamer`) -> host publish (`HostApiClient`).
- macOS UI (`ViewController`) -> host status read (`/api/status`) only.

## Error Handling
- If selected lens cannot be resolved/applied, streamer throws descriptive `IllegalStateException`; existing UI/service warning path remains active.
- macOS remains non-authoritative; status read failures continue to show degraded state without sending writes.

## Use-Case Coverage Matrix
| use_case_id | Primary path covered | Fallback path covered | Error path covered | Runtime call stack section |
|---|---|---|---|---|
| UC-001 | Yes | N/A | Yes | UC-001 |
| UC-002 | Yes | N/A | Yes | UC-002 |
| UC-003 | Yes | Yes | Yes | UC-003 |
| UC-004 | Yes | N/A | Yes | UC-004 |
