# Implementation Plan

1. Add new host-session status components to macOS host card.
2. Add host status polling method (`/api/status`) and render mapping.
3. Add macOS-side controls (`Apply To Phone`, `Sync Status`) using `/api/toggles`.
4. Add guardrails for missing camera stream URL.
5. Build signed macOS app and validate runtime.
6. Update docs/user flow notes.
