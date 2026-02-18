# Future-State Runtime Call Stack

## Version
v1

## UC-1 Android shows host before pairing
1. `MainActivity.onCreate()` / ticker path
2. `MainActivity.refreshHostPreviewIfUnpaired()`
3. `HostDiscoveryClient.discover()` (UDP discovery)
4. fallback `HostApiClient.fetchBootstrap(savedHost)` if needed
5. `HostApiClient.publishPresence(discoveredHost, deviceName, deviceId)`
6. Host `POST /api/presence` -> `SessionController.notePhonePresence(...)`
7. Android `updateUiFromPrefs()` renders `Host discovered: <url>`

## UC-2 Pair still works from preview state
1. User taps Pair
2. `MainActivity.pairHost()` -> existing pair flow
3. Host `POST /api/pair` -> `SessionController.pairHost(...)`
4. Android UI transitions to paired

## UC-3 macOS sees phone while unpaired
1. macOS `ViewController.refreshHostResourceStatus()`
2. GET `/api/status` includes `phone` metadata even when `paired=false`
3. `phoneIdentityLabel` renders known phone identity with host state `Not Paired`
