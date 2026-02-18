# Future-State Runtime Call Stack

## Version
v1

## UC-1 Pair via improved discovery
1. `MainActivity.pairHost()`
2. `MainActivity.discoverHostOrThrow()`
3. `HostDiscoveryClient.discover()`
4. `HostDiscoveryClient.buildDiscoveryTargets()`
5. `DatagramSocket.send()` to each target
6. `DatagramSocket.receive()` response
7. `HostApiClient.pair(baseUrl,pairCode,deviceName,deviceId)`
8. Host `/api/pair` -> `SessionController.pairHost(...)`
9. `HostApiClient.fetchStatus(baseUrl)`
10. `MainActivity.updateUiFromPrefs()` + `applyForegroundServiceState()`

Fallback/error:
- If discovery gets no response, fallback saved bootstrap path and show discovery failure message.

## UC-2 Startup reconciliation
1. `MainActivity.onCreate()`
2. `MainActivity.refreshHostStatusIfPaired(applyServiceState=true)`
3. `HostApiClient.fetchStatus(hostBaseUrl)`
4. If `snapshot.paired == false`:
- `AppPrefs.setPaired(false)`
- `AppPrefs.clearResourceToggles()`
- `MainActivity.updateUiFromPrefs()`
- stop/no-start foreground resource service

## UC-3 No stale startup apply
1. `MainActivity.onCreate()` initializes UI
2. No unconditional `applyForegroundServiceState()` call before reconciliation
3. Reconciliation result gates resource apply path
