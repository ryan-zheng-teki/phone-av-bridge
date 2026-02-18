# Investigation Notes

## Sources Consulted
- `/Users/normy/autobyteus_org/phone-av-bridge/README.md`
- `/Users/normy/autobyteus_org/phone-av-bridge/android-phone-av-bridge/app/build.gradle.kts`
- `/Users/normy/autobyteus_org/phone-av-bridge/desktop-av-bridge-host/scripts/build-release.mjs`
- `/Users/normy/autobyteus_org/phone-av-bridge/desktop-av-bridge-host/scripts/prepare-runtime.mjs`
- `/Users/normy/autobyteus_org/phone-av-bridge/desktop-av-bridge-host/installers/linux/install.sh`
- `/Users/normy/autobyteus_org/phone-av-bridge/macos-camera-extension/README.md`
- `/Users/normy/autobyteus_org/phone-av-bridge/macos-camera-extension/samplecamera.xcodeproj`

## Key Findings
- No GitHub release workflow exists yet under `.github/workflows/`.
- Existing host packaging script only outputs a tarball (`desktop-av-bridge-host/scripts/build-release.mjs`), not a Debian package.
- Android module can build `assembleDebug` and `assembleRelease`; release signing is not currently configured for CI.
- macOS camera app can be built unsigned with `xcodebuild` when `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`.
- Linux installer logic currently targets user-local install paths (`~/.local/...`), so Debian packaging needs a distinct install layout (`/opt`, `/usr/bin`, `/usr/share/applications`) rather than reusing that installer directly.
- Runtime node bundling currently exists (`prepare-runtime.mjs`) and should be reused for release packaging.

## Constraints
- User explicitly wants tag-driven release automation and public GitHub distribution.
- User does not want Apple-ID-based distribution; macOS artifact should be unsigned and distributed as installable app bundle archive.
- Release should publish three artifact classes: Android APK, macOS app archive, Linux `.deb` package.
- Debian packaging build is expected to run in GitHub Ubuntu runners (local dev machine may not have `dpkg-deb`).

## Unknowns / Risks
- Android release-signing secrets may not be configured yet in GitHub; need deterministic fallback behavior.
- Unsigned macOS app can be distributed, but end users will still need manual security/extension approval steps.
- Debian dependencies vary by distro; package should target Ubuntu/Debian and keep dependencies minimal.

## Implications
- Build pipeline should produce usable artifacts without requiring sensitive credentials by default.
- Workflow should optionally use Android signing secrets when provided, and fallback to debug APK when absent.
- Need one new Debian packaging script and one unsigned macOS release packaging script.
- Need a release workflow that triggers on `v*` tags, uploads artifacts, and publishes checksums.
