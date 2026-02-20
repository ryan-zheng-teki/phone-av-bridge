# Investigation Notes

- Ticket: `codebase-refactor-foundation`
- Date: 2026-02-20
- Stage: `Understanding pass complete`

## Investigation Goal

Establish a whole-codebase refactor baseline that reduces oversized controllers/modules, improves separation of concerns, preserves behavior, and sets an execution order safe for incremental delivery.

## Sources Consulted

### Local file paths

- `/Users/normy/autobyteus_org/phone-av-bridge/README.md`
- `/Users/normy/autobyteus_org/phone-av-bridge/macos-camera-extension/samplecamera/ViewController.swift`
- `/Users/normy/autobyteus_org/phone-av-bridge/macos-camera-extension/cameraextension/cameraextensionProvider.swift`
- `/Users/normy/autobyteus_org/phone-av-bridge/android-phone-av-bridge/app/src/main/java/org/autobyteus/phoneavbridge/MainActivity.kt`
- `/Users/normy/autobyteus_org/phone-av-bridge/desktop-av-bridge-host/desktop-app/server.mjs`
- `/Users/normy/autobyteus_org/phone-av-bridge/desktop-av-bridge-host/core/session-controller.mjs`
- `/Users/normy/autobyteus_org/phone-av-bridge/desktop-av-bridge-host/desktop-app/static/app.js`
- `/Users/normy/autobyteus_org/phone-av-bridge/tickets/README.md`
- `/Users/normy/.codex/skills/software-engineering-workflow-skill/SKILL.md`
- `/Users/normy/.codex/skills/software-engineering-workflow-skill/assets/*.md`

### Command evidence

- Hotspot file sizes (>=200 LOC): `ViewController.swift` (1646), `MainActivity.kt` (869), `server.mjs` (577), plus adapter-heavy modules.
- `ViewController.swift` has 61 functions and combines UI creation, networking, timers, camera extension lifecycle, frame ingestion, and status parsing.
- `MainActivity.kt` contains dense listener + pairing/network/service orchestration with many concurrent executor calls.
- `server.mjs` combines HTTP routing, bootstrap/QR token lifecycle, persistence wiring, discovery wiring, and static serving in one file.

## Key Findings

### 1) macOS app architecture hotspot

- `ViewController.swift` currently owns too many concerns:
  - camera extension activation/deactivation,
  - frame server (NWListener/NWConnection),
  - host status polling,
  - QR token lifecycle and timers,
  - JSON parsing for host status,
  - complete AppKit view tree construction.
- This concentration increases regression risk for UI and runtime behavior whenever any small feature changes.

### 2) Android app architecture hotspot

- `MainActivity.kt` similarly centralizes:
  - UI listeners,
  - permissions,
  - pairing and QR scan flow,
  - discovery and status polling,
  - service state publishing and retry logic.
- This design is functional but hard to maintain and difficult to test in isolated units.

### 3) Host server composition hotspot

- `desktop-av-bridge-host/desktop-app/server.mjs` is an orchestration + transport + route handler + token manager + static server file.
- QR logic added recently is correct and tested, but routing and domain logic are tightly coupled, limiting safe refactor velocity.

### 4) Testing posture

- Existing tests are strongest in host unit/integration (`desktop-av-bridge-host/tests/**`).
- Android and macOS UI-side changes rely more on manual and build verification than deterministic integration test coverage.

### 5) Naming and boundary consistency

- Overall naming is understandable, but boundary ownership is inconsistent:
  - files named as entry/controller also hold domain logic,
  - API parsing logic is embedded in UI controllers instead of typed clients.

## Constraints

1. Must preserve shipped behavior for pairing, QR scan pairing, unpair/re-pair, and resource toggles.
2. No backward-compatibility shims or dual-path legacy support (skill policy).
3. Refactor should be incremental and releasable by slice (avoid big-bang rewrite).
4. Existing release pipeline (`tag -> workflow`) should remain unchanged.

## Open Unknowns

1. Exact preferred architecture style for Android layer split (MVI vs lightweight presenter/service split) in this repo.
2. Whether macOS UI redesign should be bundled with refactor or kept strictly separate (current recommendation: separate).
3. Desired target for e2e automation coverage across macOS + Android real-device matrix.

## Implications For Design

1. Scope is `Large` due cross-module, cross-platform refactor and boundary redefinition.
2. Must use change-inventory driven execution (`Add/Modify/Rename/Move/Remove`) with traceability.
3. First refactor slices should establish stable boundaries without behavior change:
   - typed host API client extraction for macOS,
   - QR coordinator extraction for macOS,
   - route/controller split for host server,
   - activity decomposition scaffold for Android.
4. After boundaries stabilize, follow-up tickets can improve UI/UX independently with lower risk.
