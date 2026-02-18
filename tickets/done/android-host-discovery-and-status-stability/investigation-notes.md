# Investigation Notes

## Context
- Date: 2026-02-17
- Scope: Android pairing reliability + macOS host status correctness signals observed in PRC flow.

## Sources Consulted
- `/Users/normy/autobyteus_org/phone-resource-companion/android-resource-companion/app/src/main/java/org/autobyteus/resourcecompanion/MainActivity.kt`
- `/Users/normy/autobyteus_org/phone-resource-companion/android-resource-companion/app/src/main/java/org/autobyteus/resourcecompanion/network/HostDiscoveryClient.kt`
- `/Users/normy/autobyteus_org/phone-resource-companion/android-resource-companion/app/src/main/java/org/autobyteus/resourcecompanion/store/AppPrefs.kt`
- `/Users/normy/autobyteus_org/phone-resource-companion/host-resource-agent/linux-app/server.mjs`
- `/Users/normy/autobyteus_org/phone-resource-companion/macos-camera-extension/samplecamera/ViewController.swift`
- Runtime checks:
  - `curl http://127.0.0.1:8787/api/status`
  - `curl http://127.0.0.1:8787/api/bootstrap`
  - `adb shell pm clear org.autobyteus.resourcecompanion`
  - `adb shell uiautomator dump`
  - `adb shell input tap ...` (pair button)

## Findings
1. Discovery on Android currently sends UDP broadcast only to `255.255.255.255` and emulator `10.0.2.2`.
- This is weak on networks that filter global broadcast but permit subnet directed broadcast.

2. Android startup flow can apply resource toggles before host pairing state is reconciled.
- `onCreate()` currently calls `applyForegroundServiceState()` unconditionally.
- If local prefs are stale (paired/toggles true), Android can publish stale resource intent immediately.

3. Local/host pairing divergence is not auto-healed when host reports `paired=false`.
- `refreshHostStatusIfPaired()` stores host snapshot but does not clear local paired/toggles when host has been reset/unpaired.
- This can present misleading “connected/degraded” state and trigger confusing behavior.

4. Live repro on connected phone confirms pairing path itself works when bridge is online.
- Status transitions to `Paired and ready` and host API confirms `paired=true`.
- Intermittent “host not found” remains plausible from discovery transport weakness.

## Open Unknowns
- Whether every target Wi-Fi environment permits subnet broadcast uniformly.
- Whether any OEM network stack further restricts UDP replies to ephemeral ports.

## Implications
- We should strengthen discovery target list (directed broadcast addresses per interface).
- We should reconcile local pairing against authoritative host status before applying resources.
- We should prevent stale toggle publication at app startup before reconciliation completes.
