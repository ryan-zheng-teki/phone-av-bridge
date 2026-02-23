# ios-phone-av-bridge

Swift package for iOS-side host integration in Phone AV Bridge.

For a runnable simulator app target, use sibling module:
- `/Users/normy/autobyteus_org/phone-av-bridge/ios-phone-av-bridge-app/`

## Scope in this package

- Host API client (`/api/bootstrap`, `/api/pair`, `/api/unpair`, `/api/status`, `/api/toggles`, `/api/presence`)
- QR pairing support (`QrPairPayloadParser`, `/api/bootstrap/qr-redeem`, view-model QR pair orchestration)
- UDP discovery client (`PHONE_AV_BRIDGE_DISCOVER_V1` on `39888`)
- Speaker-stream client (`/api/speaker/stream`, PCM metadata + byte-stream consumption)
- Android-parity iOS controller layer:
  - `HostSelectionState` (`pair` / `switch` / `unpair` / `selectRequired`)
  - `PhoneBridgeMainScreenViewModel` (status/detail/issue/control orchestration)
  - `PhoneBridgeMainScreen` (SwiftUI screen for host + controls UI)
- Unit tests + iOS simulator integration test harness

## SwiftUI integration entry point

```swift
import SwiftUI
import PhoneAVBridgeIOS

struct ContentView: View {
  @StateObject private var viewModel = PhoneBridgeMainScreenViewModel(
    bootstrapBaseURL: "http://127.0.0.1:8787",
    deviceName: "iPhone",
    deviceId: "iphone-sim"
  )

  var body: some View {
    PhoneBridgeMainScreen(viewModel: viewModel)
  }
}
```

## Local development

```bash
cd /Users/normy/autobyteus_org/phone-av-bridge/ios-phone-av-bridge
swift test
```

Run simulator representative E2E from repo root:

```bash
cd /Users/normy/autobyteus_org/phone-av-bridge
bash ios-phone-av-bridge/scripts/run_ios_sim_e2e.sh
```

## Current validation boundary

- Simulator: control-plane + speaker-stream contract is validated.
- Physical iPhone: full camera/microphone RTSP publishing still requires on-device follow-up validation.
