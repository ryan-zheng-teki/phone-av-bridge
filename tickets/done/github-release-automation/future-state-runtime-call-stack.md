# Future-State Runtime Call Stack (v1)

## UC-REL-001 Tag-Triggered Release Orchestration
1. `/.github/workflows/release.yml:on.push(tags=v*)`
2. `/.github/workflows/release.yml:jobs.build_android`
3. `/.github/workflows/release.yml:jobs.build_macos_camera`
4. `/.github/workflows/release.yml:jobs.build_linux_deb`
5. `/.github/workflows/release.yml:jobs.publish_release` (needs all build jobs)
6. `softprops/action-gh-release` publishes assets to GitHub Release

Primary path: all artifact jobs succeed -> publish job runs.
Error path: any build job fails -> publish job blocked by `needs`.

## UC-REL-002 Android APK Artifact Generation
1. `release.yml:build_android/checkout`
2. `release.yml:build_android/setup-java`
3. `release.yml:build_android/detect-signing`
4. `android-phone-av-bridge/app/build.gradle.kts:android.signingConfigs` loads env-based signing if present
5. Branch A (signed release):
   - `release.yml:build_android/run-gradle-assembleRelease`
   - artifact: `app/build/outputs/apk/release/app-release.apk`
6. Branch B (fallback debug):
   - `release.yml:build_android/run-gradle-assembleDebug`
   - artifact: `app/build/outputs/apk/debug/app-debug.apk`
7. `release.yml:build_android/upload-artifact`

Decision gate:
- if all signing env vars exist -> release branch
- else -> debug fallback branch

Error path:
- Gradle build failure -> job failure
- expected APK path missing -> job failure

## UC-REL-003 macOS Unsigned Camera Archive Generation
1. `release.yml:build_macos_camera/checkout`
2. `release.yml:build_macos_camera/run-script`
3. `macos-camera-extension/scripts/build-unsigned-release.sh:main`
4. `xcodebuild -project samplecamera.xcodeproj -scheme samplecamera CODE_SIGNING_ALLOWED=NO`
5. script resolves newest `PhoneAVBridgeCamera.app` in DerivedData
6. script packages app: `ditto -c -k --keepParent`
7. `release.yml:build_macos_camera/upload-artifact`

Primary path: unsigned build + zip succeeds.
Error path: xcodebuild fails or app path not found.

## UC-REL-004 Linux Debian Package Generation
1. `release.yml:build_linux_deb/checkout`
2. `release.yml:build_linux_deb/setup-node`
3. `release.yml:build_linux_deb/run-script`
4. `desktop-av-bridge-host/scripts/build-deb-package.sh:main`
5. `node desktop-av-bridge-host/scripts/prepare-runtime.mjs`
6. stage payload under temporary root:
   - `/opt/phone-av-bridge-host/*`
   - `/usr/bin/phone-av-bridge-host-start`
   - `/usr/bin/phone-av-bridge-host-stop`
   - `/usr/share/applications/phone-av-bridge-host.desktop`
7. `dpkg-deb --build` creates `.deb`
8. `release.yml:build_linux_deb/upload-artifact`

Primary path: `.deb` generated in `desktop-av-bridge-host/dist/`.
Error path: missing `dpkg-deb` or staging/build failures.

## UC-REL-005 Publish Release and Checksums
1. `release.yml:publish_release/download-artifact`
2. `release.yml:publish_release/generate-checksums` -> `SHA256SUMS.txt`
3. `release.yml:publish_release/generate-release-body`
4. `release.yml:publish_release/action-gh-release`
5. GitHub Release contains all artifacts + checksum file

State mutation points:
- GitHub Actions artifact store (intermediate uploads)
- GitHub Release assets (final persisted state)

Error path:
- release API failure -> publish job fails
- checksum generation failure -> publish job fails
