# Future-State Runtime Call Stacks (Debug-Trace Style)

- Ticket: `ios-companion-streaming-support`
- Scope Classification: `Medium`
- Call Stack Version: `v6`
- Requirements: `/Users/normy/autobyteus_org/phone-av-bridge/tickets/in-progress/ios-companion-streaming-support/requirements.md` (`Refined`)
- Source Design: `/Users/normy/autobyteus_org/phone-av-bridge/tickets/in-progress/ios-companion-streaming-support/proposed-design.md` (`v6`)

## Use Case Index

| use_case_id | Requirement | Use Case Name | Coverage Target |
| --- | --- | --- | --- |
| UC-011 | R-011 | active scan QR action | Primary/N-A/Error |
| UC-012 | R-012 | QR payload parser validation | Primary/N-A/Error |
| UC-013 | R-013 | redeem token then pair | Primary/N-A/Error |
| UC-014 | R-014 | separate-row action layout parity | Primary/N-A/N-A |
| UC-015 | R-015 | no manual fallback UI | Primary/N-A/N-A |

## Use Case: UC-011 Active Scan QR Action

### Primary Runtime Call Stack

```text
[ENTRY] MainScreenView.swift:scanQrButton.tap
└── presents QrPairingSheet.swift [UI]
    ├── camera frame detects QR payload [IO]
    └── callback -> MainScreenViewModel.swift:performQrPairing(rawPayload:) [ASYNC]
```

### Error Path

```text
[ERROR] camera unavailable or permission denied
QrPairingSheet/QrScannerController
└── status message shown, no manual payload submit path
```

### Coverage Status

- Primary Path: Covered
- Fallback Path: N/A
- Error Path: Covered

## Use Case: UC-012 QR Payload Parser Validation

### Primary Runtime Call Stack

```text
[ENTRY] MainScreenViewModel.swift:performQrPairing(rawPayload:)
└── QrPairPayloadParser.parse(rawPayload) [STATE]
    ├── parse JSON payload: service/token/baseUrl [STATE]
    └── normalize/validate token + http(s) baseUrl [STATE]
```

### Error Path

```text
[ERROR] malformed payload or unsupported service
QrPairPayloadParser.parse(...)
└── returns nil -> view-model sets invalid-QR user error
```

### Coverage Status

- Primary Path: Covered
- Fallback Path: N/A
- Error Path: Covered

## Use Case: UC-013 Redeem Token Then Pair

### Primary Runtime Call Stack

```text
[ENTRY] MainScreenViewModel.swift:performQrPairing(rawPayload:)
├── HostApiClient.swift:redeemQrToken(baseURL, token) [IO]
│   └── POST /api/bootstrap/qr-redeem -> bootstrap payload [IO]
└── MainScreenViewModel.swift:pairHost(redeemedHost) [ASYNC]
    ├── HostApiClient.swift:pair(...) [IO]
    ├── HostApiClient.swift:publishPresence(...) [IO]
    ├── HostApiClient.swift:fetchStatus(...) [IO]
    └── HostApiClient.swift:publishToggles(...) [IO]
```

### Error Path

```text
[ERROR] redeem fails (expired/used/invalid token)
HostApiClient.Error.requestFailed(...)
└── mapPairFailureMessage(...) -> QR-token-specific message [STATE]
```

### Coverage Status

- Primary Path: Covered
- Fallback Path: N/A
- Error Path: Covered

## Use Case: UC-014 Separate-Row Action Layout Parity

### Primary Runtime Call Stack

```text
[ENTRY] MainScreenView.swift:body
├── Primary action button row [UI]
└── Scan QR Pairing button row [UI]
```

### Coverage Status

- Primary Path: Covered
- Fallback Path: N/A
- Error Path: N/A

## Use Case: UC-015 No Manual Fallback UI

### Primary Runtime Call Stack

```text
[ENTRY] QrPairingSheet.swift:body
├── scanner preview + status text [UI]
└── no text editor / no submit button path
```

### Coverage Status

- Primary Path: Covered
- Fallback Path: N/A
- Error Path: N/A

## Existing Use Cases (UC-001 .. UC-010)

- UC-001 .. UC-010 remain unchanged from prior iteration behavior and are retained as covered.
