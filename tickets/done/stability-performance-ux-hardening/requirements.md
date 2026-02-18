# Requirements: Stability, Performance, UX Hardening

## Status
- `Design-ready`

## Goal / Problem Statement
The current phone-resource-companion flow works intermittently but is not consistently reliable or clear for non-technical users. Pairing, media quality, and audio stability must be improved so users can install, pair, toggle resources, and use them in meeting apps with minimal confusion.

## Scope Triage
- Classification: `Medium`
- Rationale:
  - Cross-layer changes are required (Android UI + Android streaming + host controller + macOS audio adapter).
  - No core architecture rewrite is required.
  - API surface can remain stable while behavior, reliability, and UX messaging are improved.

## In-Scope Use Cases
1. `UC-PAIR-01`: Android user taps `Pair Host` and reliably reaches paired state with actionable error if not possible.
2. `UC-STATUS-01`: Android user can clearly understand current state (not paired, pairing, paired active, degraded with reason).
3. `UC-CAMERA-01`: User enables camera and gets improved quality/stability stream to host virtual camera route.
4. `UC-MIC-01`: User enables microphone and host route remains stable with clear route labeling.
5. `UC-SPEAKER-01`: User enables speaker and hears host audio on phone with reduced artifacts/noise under nominal conditions.
6. `UC-HOST-ISSUE-01`: Host exposes user-safe issue messages instead of raw low-level failures.
7. `UC-INSTALL-01`: macOS/Linux install and launch flow is clearly documented and user-facing messaging reduces setup confusion.

## Out Of Scope
- iOS implementation.
- Kernel-space custom camera/audio drivers.
- Signed/notarized distribution pipeline automation changes.
- Full Electron/native desktop host UI rewrite.

## Acceptance Criteria
1. Pairing:
  - Android pairing flow retries discovery/fallback paths and reports categorized failure message (discovery, host unreachable, pair rejected, unknown).
  - Pairing state is not silently ambiguous; UI reflects host health.
2. UI clarity:
  - Android home screen includes guided steps and explicit host/status details.
  - Toggle affordances remain simple and independent.
3. Camera quality:
  - Android RTSP stream uses explicit video/audio settings (resolution/fps/bitrate/sample rate/channels) instead of opaque defaults.
  - macOS host camera bridge preserves configured quality with lower-latency ffmpeg settings.
4. Audio quality/stability:
  - Speaker capture pipeline uses explicit normalization/resampling path.
  - Android speaker playback handles stream framing robustly and does not regress existing functionality.
5. Host issue quality:
  - Session issues are mapped to user-safe guidance messages for camera/microphone/speaker categories.
6. Verification:
  - Host-agent unit/integration tests pass.
  - Android project builds successfully (`assembleDebug`).
  - Manual host status verification path documented for remaining real-device checks.
7. Cleanup:
  - No legacy compatibility branches introduced.
  - Obsolete/error-prone code paths touched in this ticket are removed or simplified.

## Constraints / Dependencies
- Android minSdk 30.
- Existing RTSP server library (`com.github.pedroSG94:RTSP-Server`).
- Host runtime depends on ffmpeg.
- macOS camera path depends on PRCCamera extension availability.
- macOS audio path depends on PRCAudio device availability.

## Assumptions
1. Android device and host are on same LAN or reachable network path.
2. Host app process remains running while resources are enabled.
3. Meeting apps refresh or can reselect devices after route changes.

## Open Questions / Risks
1. Device-specific encoder capability limits may require fallback quality profiles.
2. Speaker noise may still occur under misrouted host audio device selection; guidance will be needed.
3. Network variability can still cause transient disruptions; app must surface recoverable degraded state.
