# Proposed-Design-Based Runtime Call Stack

## use_case_id: mac_host_autostart_on_launch
1. `samplecamera/ViewController.swift:viewDidLoad()`
2. `refreshHostBridgeStatus(autoStartIfNeeded: true)`
3. `checkHostBridgeHealth()` -> `GET /health` on `127.0.0.1:8787`
4. health fails -> `startHostBridge(nil)`
5. `hostBridgeAppCandidates()` resolves host app by bundle id and fallback paths
6. `NSWorkspace.openApplication(...)`
7. Host Resource Agent starts `linux-app/server.mjs`
8. next heartbeat `hostBridgeHeartbeat()` -> `refreshHostBridgeStatus(false)`
9. health passes -> UI badge `Online`

## use_case_id: mac_host_manual_retry
1. user clicks `Start Host Bridge`
2. `startHostBridge(_:)`
3. if healthy: no-op + log
4. else open host app candidate
5. timer-driven health refresh updates status

## use_case_id: mac_host_ui_open
1. user clicks `Open Host UI`
2. `openHostBridgeUI(_:)`
3. opens `http://127.0.0.1:8787`
