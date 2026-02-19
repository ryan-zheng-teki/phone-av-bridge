# Implementation Plan

## Status
Finalized

## Solution Sketch (Small Scope Design Basis)
1. Add Linux mic helper functions for:
   - low-latency mode toggle parsing,
   - pulse latency hint parsing,
   - ffmpeg args construction.
2. Update mic ffmpeg startup to:
   - start with low-latency args by default,
   - pass `PULSE_LATENCY_MSEC` hint,
   - fall back once to baseline args when low-latency startup fails.
3. Add unit tests for helper behavior and args.
4. Update README with Linux low-latency defaults and optional tuning env vars.

## Files
- `desktop-av-bridge-host/adapters/linux-audio/audio-runner.mjs`
- `desktop-av-bridge-host/tests/unit/linux-audio-runner.test.mjs`
- `desktop-av-bridge-host/README.md`

## Verification
- `cd desktop-av-bridge-host && npm test`
