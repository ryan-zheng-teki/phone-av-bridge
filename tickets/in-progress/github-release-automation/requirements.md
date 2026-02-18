# Requirements

## Status
Design-ready

## Scope Classification
- Classification: Medium
- Rationale:
  - Cross-module impact (Android build flow, macOS build flow, Linux packaging, GitHub Actions release orchestration).
  - New public delivery surface (tag-triggered GitHub Releases with downloadable artifacts).
  - New packaging format introduction (`.deb`).

## Goal / Problem Statement
Create an industry-practice tag-driven GitHub release workflow for this public repository so each release tag publishes downloadable artifacts for Android, macOS, and Linux.

## In-Scope Use Cases
1. Maintainer pushes a semantic version tag (for example `v0.1.2`) and GitHub automatically creates a release.
2. Release includes Android APK artifact built from the current source (signed release when secrets exist; deterministic fallback otherwise).
3. Release includes macOS `PhoneAVBridgeCamera.app` packaged as an unsigned archive built on GitHub macOS runners.
4. Release includes Linux Debian package (`.deb`) for `desktop-av-bridge-host`.
5. Release uploads integrity checksums for all published artifacts.

## Acceptance Criteria
- A GitHub Actions workflow triggers on `push` tags matching `v*` and supports manual dispatch.
- Workflow publishes a GitHub Release with at least these artifacts:
  - Android APK
  - macOS camera app archive (`.zip` containing `.app`)
  - Linux `.deb`
  - checksum file covering release artifacts
- Linux `.deb` is buildable on Ubuntu runner and installs packaged host app payload with launch commands.
- macOS build path does not require Apple Developer signing credentials.
- Android path has explicit behavior when signing secrets are absent (no ambiguous failure).
- Workflow files and scripts are documented in repo docs.

## Constraints / Dependencies
- GitHub-hosted runners (`ubuntu-latest`, `macos-latest`).
- Existing project scripts and folder layout under:
  - `android-phone-av-bridge/`
  - `desktop-av-bridge-host/`
  - `macos-camera-extension/`
- No legacy compatibility wrappers: implement direct current-state release flow only.

## Assumptions
- Release tags follow `v<semver>` style.
- Unsigned macOS app distribution is acceptable for this project.
- Debian package target is Ubuntu/Debian-compatible systems.

## Open Questions / Risks
- Android production signing secrets may be unavailable initially.
- `.deb` dependency compatibility across non-Debian distributions is out of scope.
- End-user notarization/Gatekeeper behavior for macOS unsigned app is outside CI scope.

## Requirement Snapshot History
- Draft captured from user request + investigation notes.
- Refined to Design-ready after feasibility validation of unsigned macOS build and packaging paths.
