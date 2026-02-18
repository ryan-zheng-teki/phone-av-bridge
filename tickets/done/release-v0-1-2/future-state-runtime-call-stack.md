# Future-State Runtime Call Stack

## Version
v1

## UC-1: Prepare Release Source
- `git/main:operator` checks workspace and release script alignment.
- `desktop-av-bridge-host/scripts/build-deb-package.sh:build pipeline` is verified as Linux artifact source for workflow.
- `desktop-av-bridge-host/tests/*:node --test` validates host behavior remains stable.
- `desktop-av-bridge-host/scripts/build-deb-package.sh` builds `.deb` artifact locally (smoke verification).
- `git commit` persists source state for release.

Coverage:
- Primary path: Yes
- Fallback path: N/A
- Error path: Yes (test/build failure blocks release)

## UC-2: Trigger Release
- `git push origin main` updates release source branch.
- `git tag v0.1.2` marks release version.
- `git push origin v0.1.2` triggers GitHub workflow `Release`.
- `github/actions/release.yml:prepare` resolves tag/version.
- `github/actions/release.yml:build_*` builds Android/macOS/Linux artifacts.
- `github/actions/release.yml:publish_release` creates GitHub release with uploaded assets.

Coverage:
- Primary path: Yes
- Fallback path: N/A
- Error path: Yes (push/tag conflict or workflow job failure)

## UC-3: Monitor and Confirm
- `curl GitHub Actions API /actions/runs` fetches latest run for tag.
- Poll loop checks `status` and `conclusion` until terminal state.
- On success, read release endpoint for published asset confirmation.
- On failure, capture failed job status and stop with actionable output.

Coverage:
- Primary path: Yes
- Fallback path: N/A
- Error path: Yes (API unavailable or workflow failure)
