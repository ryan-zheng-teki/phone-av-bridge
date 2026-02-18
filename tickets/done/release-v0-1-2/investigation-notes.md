# Investigation Notes

## Sources Consulted
- `.github/workflows/release.yml`
- `desktop-av-bridge-host/scripts/build-deb-package.sh`
- `desktop-av-bridge-host/package.json`
- `git remote -v`
- `git tag --list`
- `git ls-remote --tags origin`
- `https://api.github.com/repos/ryan-zheng-teki/phone-av-bridge`

## Key Findings
- Release workflow is tag-driven (`v*`) and publishes Android APK, macOS unsigned zip, Linux `.deb`, and checksums.
- Linux release job uses `desktop-av-bridge-host/scripts/build-deb-package.sh` directly.
- Local uncommitted changes already patch `build-deb-package.sh` with Linux runtime hardening: bundled bridge runtime, automatic `v4l2loopback` configuration/loading, and helper command `phone-av-bridge-host-enable-camera`.
- Existing remote tag list currently contains `v0.1.2-rc1`; `v0.1.2` is available for release.
- Repository for push/monitor is `ryan-zheng-teki/phone-av-bridge`.

## Constraints
- Must release from current `main` branch state.
- Must monitor workflow without `gh` CLI (not installed), so monitoring should use GitHub API.
- Linux package behavior must remain compatible with already-working macOS flow (Linux-only packaging changes).

## Open Unknowns / Risks
- Workflow success still depends on external GitHub runner availability.
- Android signing path depends on repository secrets; if absent, APK may be debug channel.

## Implications
- Final release should include patched Linux packaging script in source before tagging.
- Use `git push origin main`, then push `v0.1.2`, and poll Actions API until completion.
