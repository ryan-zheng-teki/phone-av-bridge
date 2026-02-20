# Future-State Runtime Call Stacks (Debug-Trace Style)

- Ticket: `android-host-selection-and-qr-pairing`
- Scope Classification: `Medium`
- Call Stack Version: `v2`
- Requirements: `/Users/normy/autobyteus_org/phone-av-bridge/tickets/in-progress/android-host-selection-and-qr-pairing/requirements.md` (`Design-ready`)
- Source Design: `/Users/normy/autobyteus_org/phone-av-bridge/tickets/in-progress/android-host-selection-and-qr-pairing/proposed-design.md` (`v2`)

## Use Case Index

| use_case_id | Requirement | Use Case Name | Coverage Target |
| --- | --- | --- | --- |
| UC-001 | R-001 | Unpaired user selects one host from discovered list and pairs | Primary/Fallback/Error |
| UC-002 | R-002 | User unpairs then pairs to another host | Primary/N-A/Error |
| UC-003 | R-003 | User pairs via QR token path | Primary/Fallback/Error |
| UC-004 | R-004 | Single-host quick pair with explicit confirmation tap | Primary/N-A/Error |

## Use Case: UC-001 Host Selection Pair

### Primary Runtime Call Stack

```text
[ENTRY] android-phone-av-bridge/.../MainActivity.kt:onResume()
├── MainActivity.kt:refreshUnpairedHostCandidates() [ASYNC]
│   ├── network/HostDiscoveryClient.kt:discoverAll(timeoutMs) [IO]
│   │   ├── HostDiscoveryClient.kt:buildDiscoveryTargets()
│   │   ├── HostDiscoveryClient.kt:sendDiscoveryProbes() [IO]
│   │   └── HostDiscoveryClient.kt:collectResponsesUntilDeadline() [IO]
│   ├── MainActivity.kt:dedupeAndSortCandidates() [STATE]
│   ├── MainActivity.kt:preserveUserSelectionIfStillPresent(candidates) [STATE]
│   └── MainActivity.kt:renderHostSelectionList(candidates) [STATE]
├── [USER ACTION] MainActivity.kt:onHostCandidateSelected(candidate)
│   └── MainActivity.kt:setSelectedHostCandidate(candidate) [STATE]
└── [USER ACTION] MainActivity.kt:onPairSelectedHostClick()
    ├── network/HostApiClient.kt:pair(baseUrl, pairCode, deviceName, deviceId) [IO]
    ├── store/AppPrefs.kt:setHostBaseUrl(...) [STATE]
    ├── store/AppPrefs.kt:setHostPairCode(...) [STATE]
    ├── store/AppPrefs.kt:setPaired(true) [STATE]
    ├── network/HostApiClient.kt:fetchStatus(baseUrl) [IO]
    └── MainActivity.kt:updateUiFromPrefs() [STATE]
```

### Fallback Path

```text
[FALLBACK] discovery returns empty list
MainActivity.kt:refreshUnpairedHostCandidates()
├── MainActivity.kt:loadSavedHostCandidateFromPrefs() [STATE]
└── MainActivity.kt:renderSavedCandidateAsFallback() [STATE]
```

### Error Path

```text
[ERROR] pair request fails (invalid code/unreachable)
MainActivity.kt:onPairSelectedHostClick()
├── HostApiClient.kt:pair(...) [IO]
└── MainActivity.kt:showPairFailureToast(resolvedMessage) [STATE]
```

### Coverage Status

- Primary Path: Covered
- Fallback Path: Covered
- Error Path: Covered

## Use Case: UC-002 Unpair And Re-Pair

### Primary Runtime Call Stack

```text
[ENTRY] [USER ACTION] MainActivity.kt:onUnpairClick()
├── network/HostApiClient.kt:unpair(baseUrl) [IO]
├── store/AppPrefs.kt:setPaired(false) [STATE]
├── store/AppPrefs.kt:clearResourceToggles() [STATE]
├── MainActivity.kt:refreshUnpairedHostCandidates() [ASYNC]
└── MainActivity.kt:updateUiFromPrefs() [STATE]

[ENTRY] [USER ACTION] MainActivity.kt:onPairSelectedHostClick()
└── (same flow as UC-001 pair primary path)
```

### Error Path

```text
[ERROR] host unpair API unreachable
MainActivity.kt:onUnpairClick()
├── HostApiClient.kt:unpair(baseUrl) [IO]
├── MainActivity.kt:ignoreRemoteUnpairErrorAndContinueLocalUnpair() [STATE]
└── MainActivity.kt:updateUiFromPrefs() [STATE]
```

### Coverage Status

- Primary Path: Covered
- Fallback Path: N/A
- Error Path: Covered

## Use Case: UC-003 QR Pairing

### Primary Runtime Call Stack

```text
[ENTRY] [USER ACTION] MainActivity.kt:onScanQrClick()
├── desktop-av-bridge-host/desktop-app/static/app.js:onGenerateQrClick() [IO]
│   ├── desktop-av-bridge-host/desktop-app/server.mjs:POST /api/bootstrap/qr-token [IO]
│   └── desktop-av-bridge-host/desktop-app/static/app.js:renderQrPayload(tokenPayload) [STATE]
├── MainActivity.kt:startQrScannerFlow() [ASYNC]
├── MainActivity.kt:onQrTokenScanned(token)
│   ├── network/HostApiClient.kt:redeemQrToken(token) [IO]
│   │   └── desktop-av-bridge-host/desktop-app/server.mjs:POST /api/bootstrap/qr-redeem [IO]
│   ├── HostApiClient.kt:pair(redeemedBaseUrl, redeemedPairCode, deviceName, deviceId) [IO]
│   ├── AppPrefs.kt:setHostBaseUrl(...) [STATE]
│   ├── AppPrefs.kt:setHostPairCode(...) [STATE]
│   └── AppPrefs.kt:setPaired(true) [STATE]
└── MainActivity.kt:updateUiFromPrefs() [STATE]
```

### Fallback Path

```text
[FALLBACK] scan unavailable or canceled
MainActivity.kt:startQrScannerFlow()
└── MainActivity.kt:returnToHostSelectionList() [STATE]
```

### Error Path

```text
[ERROR] token expired or already used
MainActivity.kt:onQrTokenScanned(token)
├── HostApiClient.kt:redeemQrToken(token) [IO]
└── MainActivity.kt:showQrPairFailure("Token expired or invalid") [STATE]
```

### Coverage Status

- Primary Path: Covered
- Fallback Path: Covered
- Error Path: Covered

## Use Case: UC-004 Single-Host Quick Pair

### Primary Runtime Call Stack

```text
[ENTRY] MainActivity.kt:refreshUnpairedHostCandidates() [ASYNC]
├── HostDiscoveryClient.kt:discoverAll(timeoutMs) [IO]
└── MainActivity.kt:renderQuickPairIfSingleCandidate(candidates) [STATE]

[ENTRY] [USER ACTION] MainActivity.kt:onQuickPairClick(singleCandidate)
└── MainActivity.kt:onPairSelectedHostClick()  # same pair execution as UC-001
```

### Error Path

```text
[ERROR] single candidate becomes unreachable before pair
MainActivity.kt:onQuickPairClick(singleCandidate)
├── HostApiClient.kt:pair(...) [IO]
└── MainActivity.kt:showPairFailureToast(resolvedMessage) [STATE]
```

### Coverage Status

- Primary Path: Covered
- Fallback Path: N/A
- Error Path: Covered
