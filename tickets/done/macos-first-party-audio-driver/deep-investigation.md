# Deep Investigation: macOS First-Party Virtual Audio Driver

## Investigation Date
- 2026-02-17

## Objective
Determine implementation difficulty of replacing BlackHole with a first-party macOS virtual audio driver (mic + speaker route) for Phone Resource Companion.

## Sources (Internet)
- Apple WWDC21: Create audio drivers with DriverKit: https://developer.apple.com/videos/play/wwdc2021/10190/
- Apple QA1811 (Audio Server Plug-In sandboxing): https://developer.apple.com/library/archive/qa/qa1811/_index.html
- Apple Audio Server Driver Programming Guide (archived PDF): https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/AudioServerDriverGuide/AudioServerDriverGuide.pdf
- BlackHole repository: https://github.com/ExistentialAudio/BlackHole
- BackgroundMusic repository: https://github.com/kyleneideck/BackgroundMusic
- libASPL (Audio Server Plug-In helper library): https://github.com/gavv/libASPL

## Evidence Summary
- Apple confirms DriverKit installation supports install/update without reboot.
- Apple explicitly states virtual audio drivers still use the Audio Server Plug-In model.
- Apple QA1811 confirms Audio Server Plug-In runs in a sandboxed process with strict access constraints.
- Apple driver guide confirms plug-ins register audio devices that appear system-wide to apps.
- BlackHole and BackgroundMusic both document install/uninstall plus `coreaudiod` restarts in practice.
- BackgroundMusic troubleshooting notes that driver crashes can disrupt system audio until output device is switched/recovered.
- libASPL documents significant realtime/thread-safety constraints and asynchronous initialization behavior.

## Practical Complexity Signals From Existing Codebases
Local clone and code-surface snapshot:
- BlackHole: ~4,620 LOC in driver source (`BlackHole.c`) plus installer/signing scripts.
- libASPL: ~19,118 LOC framework surface (library + examples + generation tooling).
- BackgroundMusic: ~48,775 LOC total code surface (app + helper + driver + packaging).

Interpretation:
- A minimal virtual device is feasible with modest code.
- Production-ready quality (installer, resiliency, naming, routing UX, supportability) expands scope substantially.

## Difficulty Assessment
- Technical difficulty: `Medium-High`
- Delivery difficulty (production quality): `High`
- Not blocked by kernel-mode work: `Yes` (user-space AudioServerPlugIn path).
- Reboot required: `No` for normal install/update path, but audio-service restart handling is still needed.

## Estimated Effort (Single focused engineer)
- Phase 1 (2-3 weeks): build/install first-party virtual input device, host mic pipeline integration, local signing/dev install.
- Phase 2 (2-4 weeks): output/speaker route integration and robust lifecycle handling.
- Phase 3 (1-2 weeks): packaging hardening, preflight UX, e2e validation matrix (Zoom/OBS), regression fixes.
- Total: ~5-9 weeks to production-ready quality.

## Decision
- “Not so difficult” for a proof-of-concept: `Yes`.
- “Not so difficult” for production replacement of BlackHole with polished UX: `No` (requires careful system work).
- Recommendation: proceed with phased implementation now, starting with first-party mic device and then speaker route.

## Implications For Our Current Codebase
Current macOS host path still hard-codes BlackHole checks and routing in:
- `host-resource-agent/adapters/macos-audio/audio-runner.mjs`
- `host-resource-agent/core/preflight-service.mjs`
- `host-resource-agent/installers/macos/install.command`

Therefore this is a real replacement project, not a simple config tweak.
