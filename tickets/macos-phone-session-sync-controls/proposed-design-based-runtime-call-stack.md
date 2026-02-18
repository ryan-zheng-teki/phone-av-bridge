# Proposed-Design-Based Runtime Call Stack

## use_case_id: mac_view_phone_session_state
1. `ViewController.viewDidLoad()`
2. `refreshHostBridgeStatus(autoStartIfNeeded: true)`
3. host bridge online -> `refreshHostResourceStatus()`
4. `fetchHostResourceStatus()` -> `GET /api/status`
5. parse status: paired/phone/resources/issues/cameraStreamUrl
6. render status badge + phone identity + toggle states in host card

## use_case_id: mac_apply_phone_toggles
1. user updates camera/mic/speaker checkboxes
2. user clicks `Apply To Phone`
3. `applyHostResourceToggles(_:)`
4. validate host online + paired + stream URL requirement
5. `POST /api/toggles` with desired resource booleans (+stream URL when known)
6. refresh status via `refreshHostResourceStatus()`

## use_case_id: mac_status_sync_manual
1. user clicks `Sync Status`
2. `syncHostResourceStatus(_:)`
3. `refreshHostResourceStatus()`
4. update UI from latest host truth
