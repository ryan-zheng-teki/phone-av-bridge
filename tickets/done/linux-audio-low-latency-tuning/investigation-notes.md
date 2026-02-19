# Investigation Notes

## Sources Consulted
- `desktop-av-bridge-host/adapters/linux-audio/audio-runner.mjs`
- `desktop-av-bridge-host/tests/unit/linux-audio-runner.test.mjs`
- Runtime observations from earlier validation: monitor source is audible; browser path can have latency.

## Findings
- Current Linux mic ffmpeg command uses stable defaults but no explicit low-latency ingest/output hints.
- End-to-end latency budget includes RTSP transport buffering, ffmpeg demux/output buffering, Pulse/PipeWire buffering, and browser processing.
- We can reduce host-side latency by adding conservative low-latency ffmpeg flags and a Pulse latency hint while keeping fallback for compatibility.

## Constraints
- Must remain Linux-only and avoid impact on macOS behavior.
- Must not require users to run manual exports after install.
- Stability must be preserved if low-latency flags are unsupported on some ffmpeg builds.

## Open Questions
- Exact latency gain varies by network/jitter and browser audio processing pipeline.

## Implications
- Implement default-on low-latency mode with automatic fallback to baseline mode on startup failure.
