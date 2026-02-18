# macOS Camera Extension Adapter Contract (Phase 2)

## Purpose

Define the integration boundary between host bridge ingest and macOS virtual camera output via CoreMediaIO Camera Extension.

## Scope

- In scope:
  - Frame ingress contract from bridge runtime.
  - Extension lifecycle expectations.
  - Error and fallback behavior.
- Out of scope:
  - Signing/notarization automation.
  - Distribution packaging.

## Adapter Interface (Conceptual)

Bridge-side boundary:

- `AdapterInit(config) -> AdapterHandle`
- `AdapterPushFrame(handle, frame) -> Result`
- `AdapterReportHealth(handle) -> HealthStatus`
- `AdapterShutdown(handle) -> Result`

Extension-side responsibilities:

- Register virtual camera device and stream format(s).
- Pull/accept frame buffers from bridge process boundary.
- Publish frames with stable timestamps.
- Surface health/failure metrics to logs.

## Frame Contract

- Pixel format target: `yuv420p` (or extension-native conversion path).
- Frame dimensions: configurable (`1280x720` default).
- Frame rate: configurable (`30` default).
- Timestamp source: monotonic clock from bridge boundary.

## Lifecycle

1. Bridge starts and validates source ingest.
2. Bridge initializes adapter channel.
3. Extension reports ready state.
4. Bridge pushes frames continuously.
5. On source failure or process stop, bridge sends shutdown signal.

## Failure Semantics

- Adapter init failure:
  - Bridge exits non-zero with "macOS adapter unavailable".
- Frame push failure:
  - Bridge logs and exits non-zero; no infinite retry loop in MVP.
- Extension crash:
  - Bridge detects channel break, prints recovery command, exits non-zero.

## Security

- Never print tokenized source URL values in logs.
- Keep any IPC endpoint local-only.
- Validate frame payload bounds before enqueue.

## Observability

- Required logs:
  - adapter init success/failure
  - frame push start/stop
  - dropped frame counters
  - shutdown reason

## Implementation Note

This document is a contract only. The production macOS Camera Extension code is intentionally deferred from MVP and should be built as a separate phase with Apple signing/notarization workflow.
