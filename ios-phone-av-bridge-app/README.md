# ios-phone-av-bridge-app

Runnable iOS simulator app target for Phone AV Bridge.

## What this app does

- Hosts `PhoneBridgeMainScreen` from `ios-phone-av-bridge` package.
- Uses package view-model and protocol clients for host discovery/pair/toggles.
- Supports QR pairing from app UI (`Scan QR Pairing`) via camera scanning flow.
- Provides app-level UI test target for simulator E2E validation.

## Generate project

```bash
cd /Users/normy/autobyteus_org/phone-av-bridge/ios-phone-av-bridge-app
xcodegen generate
```

## Run app-level simulator E2E

```bash
cd /Users/normy/autobyteus_org/phone-av-bridge
bash ios-phone-av-bridge-app/scripts/run_ios_app_sim_e2e.sh
```

## Build iOS simulator release artifact

```bash
cd /Users/normy/autobyteus_org/phone-av-bridge
RELEASE_VERSION=0.1.14 bash ios-phone-av-bridge-app/scripts/build-ios-simulator-release.sh
```

Output artifact:

- `ios-phone-av-bridge-app/dist/PhoneAVBridgeIOSApp-ios-simulator-<version>-unsigned.zip`

## Manual simulator install/launch

```bash
xcrun simctl boot "iPhone 17 Pro" || true
xcrun simctl install booted /Users/normy/autobyteus_org/phone-av-bridge/ios-phone-av-bridge-app/.derivedData-ios-app-sim/Build/Products/Debug-iphonesimulator/PhoneAVBridgeIOSApp.app
xcrun simctl launch booted org.autobyteus.phoneavbridge.ios
```
