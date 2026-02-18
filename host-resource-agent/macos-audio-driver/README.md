# PRC macOS Audio Driver (Work In Progress)

This folder contains the bundled first-party macOS virtual audio driver path.

## Deliverables
- `PRCAudio.driver` AudioServerPlugIn bundle (2-channel virtual loopback).
- Driver install/uninstall scripts for host package integration.

## Current Status
- Bundled driver binary is present under `PRCAudio.driver`.
- Installer scripts deploy/remove the driver under `/Library/Audio/Plug-Ins/HAL`.

## Notes
- This bundle is used by `adapters/macos-firstparty-audio/audio-runner.mjs`.
- Device name expected by runtime defaults to `PRCAudio 2ch`.
- Legacy bundled upstream docs were removed from `PRCAudio.driver/Contents/Resources` to keep this repo aligned with first-party runtime messaging.
