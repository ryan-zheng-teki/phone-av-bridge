# Proposed Design (v1)

## Current-State Summary (As-Is)
- No tag-triggered GitHub release automation exists.
- Host packaging supports tarball output only via `desktop-av-bridge-host/scripts/build-release.mjs`.
- Android CI signing behavior is undefined for public releases.
- macOS camera app build is documented for local signed flow, not CI unsigned archive release flow.

## Target-State Summary (To-Be)
- A GitHub Actions release pipeline triggers on `v*` tags and publishes release assets.
- Release assets include:
  - Android APK (signed release when secrets available, fallback debug APK otherwise),
  - unsigned macOS camera app zip,
  - Linux Debian package for host app,
  - SHA256 checksums.
- Packaging logic lives in repo scripts, reusable locally and in CI.

## Change Inventory
| ID | Change Type | File | Responsibility |
|---|---|---|---|
| D-001 | Add | `.github/workflows/release.yml` | Orchestrate build + publish pipeline on tags. |
| D-002 | Add | `desktop-av-bridge-host/scripts/build-deb-package.sh` | Build `.deb` artifact from host runtime payload. |
| D-003 | Add | `macos-camera-extension/scripts/build-unsigned-release.sh` | Build unsigned macOS app and package zip artifact. |
| D-004 | Modify | `android-phone-av-bridge/app/build.gradle.kts` | Optional CI signing config sourced from env. |
| D-005 | Modify | `README.md` | Add release workflow usage and artifact output docs. |
| D-006 | Modify | `desktop-av-bridge-host/README.md` | Add Debian packaging/release notes. |
| D-007 | Modify | `macos-camera-extension/README.md` | Add unsigned CI build/release guidance. |

## Module / API Design

### 1) GitHub Workflow
- File: `.github/workflows/release.yml`
- Trigger:
  - `push.tags: ["v*"]`
  - `workflow_dispatch`
- Jobs:
  - `build_android` (ubuntu): gradle build, optional signing, upload APK artifact.
  - `build_macos_camera` (macos): unsigned build + zip, upload artifact.
  - `build_linux_deb` (ubuntu): run deb packaging script, upload artifact.
  - `publish_release` (ubuntu): download artifacts, generate SHA256SUMS, create GitHub release.

### 2) Linux `.deb` Packaging Script
- File: `desktop-av-bridge-host/scripts/build-deb-package.sh`
- Inputs:
  - `VERSION` (from tag), optional `DEB_ARCH`.
- Outputs:
  - `desktop-av-bridge-host/dist/phone-av-bridge-host_<version>_<arch>.deb`
- Behavior:
  - Reuse bundled runtime preparation (`scripts/prepare-runtime.mjs`).
  - Stage payload under `/opt/phone-av-bridge-host`.
  - Install launchers in `/usr/bin`.
  - Install desktop entry in `/usr/share/applications`.
  - Build package with `dpkg-deb --build`.

### 3) macOS Unsigned Packaging Script
- File: `macos-camera-extension/scripts/build-unsigned-release.sh`
- Inputs:
  - `VERSION_SUFFIX`, optional `CONFIGURATION`.
- Outputs:
  - `macos-camera-extension/dist/PhoneAVBridgeCamera-macos-<version>-unsigned.zip`
- Behavior:
  - Run `xcodebuild` with code signing disabled.
  - Find newest built `.app` in DerivedData.
  - Zip `.app` using `ditto` with `--keepParent`.

### 4) Android Optional Signing
- File: `android-phone-av-bridge/app/build.gradle.kts`
- Add environment-driven signing config:
  - `ANDROID_KEYSTORE_PATH`
  - `ANDROID_KEYSTORE_PASSWORD`
  - `ANDROID_KEY_ALIAS`
  - `ANDROID_KEY_PASSWORD`
- If all present, release build uses CI signing config.
- If absent, workflow publishes debug APK fallback explicitly.

## Dependency Flow
1. Tag push -> workflow entry.
2. Parallel artifact jobs build outputs independently.
3. Publish job aggregates artifacts + checksums and creates release.

## Naming Decisions
- Workflow: `release.yml` (clear and standard for tag releases).
- Linux package: `phone-av-bridge-host_<version>_<arch>.deb` (Debian naming convention).
- macOS zip: `PhoneAVBridgeCamera-macos-<version>-unsigned.zip` (explicit platform + unsigned state).
- Android APK names include channel (`release` or `debug`) to avoid ambiguity.

## Naming Drift Check
- `desktop-av-bridge-host` remains accurate for Linux package payload.
- `PhoneAVBridgeCamera` naming aligned with current renamed macOS app.
- No additional rename/split/move required in this ticket.

## Use-Case Coverage Matrix
| use_case_id | Use Case | Primary | Fallback | Error Path | Runtime Call Stack Section |
|---|---|---|---|---|---|
| UC-REL-001 | Tag-triggered release orchestration | Yes | N/A | Yes | `future-state-runtime-call-stack.md#uc-rel-001` |
| UC-REL-002 | Android APK artifact generation | Yes | Yes | Yes | `future-state-runtime-call-stack.md#uc-rel-002` |
| UC-REL-003 | macOS unsigned app archive generation | Yes | N/A | Yes | `future-state-runtime-call-stack.md#uc-rel-003` |
| UC-REL-004 | Linux `.deb` generation | Yes | N/A | Yes | `future-state-runtime-call-stack.md#uc-rel-004` |
| UC-REL-005 | Release publishing with checksums | Yes | N/A | Yes | `future-state-runtime-call-stack.md#uc-rel-005` |

## Error Handling Expectations
- Each build job fails fast on build or packaging errors.
- Publish job runs only when all artifact jobs succeed.
- Android fallback path is explicit and reflected in release body.
