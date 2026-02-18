# Implementation Plan

1. macOS: add checkbox action handlers and debounced auto-apply path.
2. macOS: keep `Sync Status`, remove reliance on `Apply To Phone` button in UI flow.
3. macOS: add status badge promotion logic (`Starting` -> `Enabled`/`Streaming`).
4. Android: extend host status snapshot with resource booleans + device id.
5. Android: reconcile local prefs from host snapshot and apply service updates.
6. Run tests (`npm test`, Android unit tests, macOS audio E2E) and real host status verification.
7. Update workflow docs and handoff notes.
