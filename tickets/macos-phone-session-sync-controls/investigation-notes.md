# Investigation Notes

## Problem
macOS `PRC Camera Host` did not show paired phone identity or live resource states, causing user uncertainty. Resource toggles could only be changed from Android, creating control-plane mismatch.

## Findings
- Host already exposes full runtime state through `GET /api/status`:
  - paired state, phone identity, resources, issues, and `cameraStreamUrl`.
- Host accepts state changes via `POST /api/toggles`.
- Therefore no protocol redesign is required to add sync/control in macOS app.
- Constraint: camera/mic enable from macOS requires a known `cameraStreamUrl`; if missing, host cannot start those routes.
- Additional runtime stability finding during verification:
  - Host launcher script on macOS did not detach server process (`nohup` missing), so host server could terminate when launcher exited.
  - Host launcher PATH did not guarantee Homebrew bins, causing false `ffmpeg is required` failures even when installed.

## Evidence
- `host-resource-agent/linux-app/server.mjs` already returns `controller.getStatus()`.
- `host-resource-agent/core/session-controller.mjs` state includes `phone`, `resources`, `issues`, and `cameraStreamUrl`.
- Runtime probe showed paired phone identity present in `/api/status`.

## Decision
Implement UI sync and optional control in `PRC Camera Host` by polling `/api/status` and posting `/api/toggles`, with guardrails when `cameraStreamUrl` is unavailable.
Also harden macOS host launcher startup behavior and PATH defaults so runtime checks match installed dependencies.
