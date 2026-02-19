# Requirements

## Status
Design-ready

## Goal / Problem Statement
Reduce Linux phone-microphone capture latency perceived in browser/meeting apps while keeping routing stable.

## Triage
Small

## Triage Rationale
- Single Linux audio adapter module plus unit tests/docs.
- No API/schema changes; scoped runtime behavior tuning.

## In-Scope Use Cases
- UC-1: Start Linux mic route with lower buffering defaults.
- UC-2: If low-latency flags fail on a host, automatically fall back to baseline ffmpeg args.
- UC-3: Keep user-visible mic device behavior unchanged.

## Acceptance Criteria
- AC-1: Linux mic runner includes low-latency ffmpeg options by default.
- AC-2: Automatic fallback path exists and preserves startup on incompatible ffmpeg builds.
- AC-3: Unit tests pass including new helper/arg tests.
- AC-4: Docs mention low-latency tuning knobs and defaults.

## Constraints / Dependencies
- ffmpeg and pactl are required at runtime.
- Browser-side DSP/echo cancellation latency remains outside host control.

## Assumptions
- Conservative ffmpeg low-latency flags are available on mainstream builds.

## Open Risks
- Over-aggressive low-latency flags could reduce stability on some environments; fallback mitigates this.
