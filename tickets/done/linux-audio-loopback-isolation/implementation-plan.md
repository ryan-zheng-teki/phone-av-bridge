# Implementation Plan

## Status
Finalized

## Preconditions
- Requirements: Design-ready
- Runtime call stack review: Go Confirmed
- Scope: Small

## Execution Steps
1. Refactor Linux speaker source selection into pure helper logic with explicit exclusion rules.
2. Integrate helper into `#resolveSpeakerSourceName` while preserving env override behavior.
3. Add Linux microphone remap-source creation so meeting apps receive `Audio/Source` (`PhoneAVBridgeMicInput-*`) instead of monitor-only labels when supported.
4. Add persistent launcher config loading:
   - Debian launcher reads `/etc/default/phone-av-bridge-host` and user config `~/.config/phone-av-bridge-host/env`.
   - Linux local installer launcher reads `~/.config/phone-av-bridge-host/env`.
5. Add packaged helper command for Debian installs: `phone-av-bridge-host-set-speaker-source`.
6. Add graceful server shutdown hooks (SIGTERM/SIGINT/SIGHUP) to stop adapters and avoid stale media workers.
7. Harden Linux start/stop launchers to clean stale bridge workers and stale pulse modules before restart.
8. Add adapter-level stale microphone module cleanup before/after route startup/teardown.
9. Add/extend unit tests for source selection and microphone target naming behavior.
10. Run host unit+integration tests (`npm test`) and shell syntax checks for modified installers/packagers.
11. Rebuild Debian package artifact for reinstall validation.
12. Update Linux docs to reflect isolation behavior, visible microphone naming, and no-`export` override path.
13. Update implementation progress with verification evidence.

## Verification Strategy
- Unit tests: source-selection helper behavior (safe monitor, exclusion, null fallback).
- Integration baseline: full `desktop-av-bridge-host` test suite (`npm test`).
- E2E feasibility: partial/manual for real audio topology; automated E2E not deterministic for desktop audio graph on CI runner.

## Requirement Traceability
| Requirement | Design/Call Stack | Implementation |
| --- | --- | --- |
| Exclude bridge mic sources | UC-1/UC-3 | helper + resolver filtering |
| Preserve override | UC-2 | early return path for env override |
| Unit coverage | UC-1/2/3 | `tests/unit/linux-audio-runner.test.mjs` |
| Docs guidance | UC-1/UC-2 | `desktop-av-bridge-host/README.md` |
