# Requirements

## Status
Refined

## Goal / Problem Statement
Current naming is inconsistent and misleading for what the project actually does. The system provides phone camera/microphone/speaker to desktop apps as external virtual AV devices, but current names use mixed terminology (`Resource Companion`, `Host Resource Agent`, `PRC Camera Host`, `phone-ip-webcam-bridge`).

Canonical naming must be unified to:
- Product name: `Phone AV Bridge`
- Slug/base identifier: `phone-av-bridge`

## Scope Classification
- Classification: `Medium`
- Rationale:
  - Cross-module rename across Android app, host service, bridge module, installers, runtime identity constants, and top-level docs.
  - No major runtime architecture change, but broad naming surface updates across code and packaging metadata.

## In-Scope Use Cases
- UC-001: Developer views root project/module names and sees consistent `phone-av-bridge` vocabulary.
- UC-002: End users on Android and host UI see `Phone AV Bridge` naming instead of `Resource Companion`/`Host Resource Agent` drift.
- UC-003: Android pairing/discovery still works after rename of runtime service identifiers.
- UC-004: Host runtime/integrations still reference renamed module paths and scripts successfully.

## Acceptance Criteria
- AC-001: Top-level naming is standardized to `Phone AV Bridge`/`phone-av-bridge` for active runtime modules.
- AC-002: Active module folder names are responsibility-aligned and canonical:
  - `android-resource-companion` -> `android-phone-av-bridge`
  - `host-resource-agent` -> `desktop-av-bridge-host`
  - `phone-ip-webcam-bridge` -> `phone-av-camera-bridge-runtime`
- AC-003: Runtime identifiers are renamed consistently where used by active code paths:
  - discovery magic constant,
  - service identifier payloads,
  - package/module names,
  - host app UI labels.
- AC-004: Android app visible strings and host web UI visible strings use `Phone AV Bridge` vocabulary.
- AC-005: Build/test scripts and key integration scripts run against renamed paths without broken references.
- AC-006: Project documentation for active runtime flow is synchronized to renamed terminology.
- AC-007: Real-device E2E validation is completed with:
  - Android APK built and installed to ADB-connected phone,
  - macOS host/camera apps built and installed under the home user `Applications` path,
  - host/phone pairing and resource toggle flow verified with live status evidence.
- AC-008: macOS-first-party artifact naming is fully rebranded:
  - app path/name: `PhoneAVBridgeCamera.app`,
  - camera bundle IDs: `org.autobyteus.phoneavbridge.camera*`,
  - audio driver bundle path/name: `PhoneAVBridgeAudio.driver`,
  - host defaults/preflight/messages use new camera/audio names.

## Constraints / Dependencies
- Keep runtime behavior unchanged; this ticket is a naming refactor.
- No legacy compatibility aliases should be kept in active runtime code paths.
- Historical ticket artifacts under `tickets/done/` may keep historical naming as archival records unless directly required.
- Renaming top-level parent directory outside project repo scope is optional and not required for runtime correctness.
- ADB device connectivity and local macOS build/signing prerequisites must be available during validation.

## Assumptions
- Canonical naming approved by user: `Phone AV Bridge`.
- Full macOS camera/audio artifact rename is in scope for this ticket.

## Open Questions / Risks
- Potential external automation scripts outside this repo that may still call old module paths.
- Android `applicationId` rename can impact upgrade path and may require migration strategy if published to users.
- macOS camera extension approval is required again after bundle identifier change.
