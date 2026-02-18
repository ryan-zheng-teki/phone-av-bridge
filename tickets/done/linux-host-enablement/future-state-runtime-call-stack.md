# Future-State Runtime Call Stacks (Debug-Trace Style)

## Design Basis
- Scope Classification: `Small`
- Call Stack Version: `v1`
- Requirements: `tickets/in-progress/linux-host-enablement/requirements.md` (`Design-ready`)
- Source Artifact: `tickets/in-progress/linux-host-enablement/implementation-plan.md` (draft solution sketch)
- Source Design Version: `v1`
- Referenced Sections:
  - `Small-Scope Solution Sketch`
  - `Requirement Traceability (Draft)`

## Future-State Modeling Rule (Mandatory)
- Model target Linux camera adapter behavior with bounded shutdown and forced termination fallback.

## Use Case Index (Stable IDs)
| use_case_id | Requirement | Use Case Name | Coverage Target (Primary/Fallback/Error) |
| --- | --- | --- | --- |
| UC-001 | AC-001, AC-004 | Apply camera toggle with deterministic restart | Yes/Yes/Yes |
| UC-002 | AC-001 | Stop camera route with bounded termination | Yes/N/A/Yes |
| UC-003 | AC-002, AC-003 | Validate no regression in host/Linux E2E checks | Yes/N/A/Yes |

## Transition Notes
- No compatibility branch retained. Existing `active.killed`-based fallback is replaced directly with bounded timeout + force-kill flow.

## Use Case: UC-001 Apply camera toggle with deterministic restart

### Goal
Enable camera route and allow re-apply without hangs when stream URL changes or route is restarted.

### Preconditions
- Host paired and `/api/toggles` request accepted.
- Linux camera adapter instantiated in `desktop-av-bridge-host/desktop-app/server.mjs:createController(...)`.

### Expected Outcome
- Camera route starts successfully or reports explicit issue.
- Any prior camera process is stopped deterministically before restart.

### Primary Runtime Call Stack
```text
[ENTRY] desktop-av-bridge-host/desktop-app/server.mjs:createApp(...):POST /api/toggles
└── [ASYNC] desktop-av-bridge-host/core/session-controller.mjs:SessionController.applyResourceState(diff)
    └── [ASYNC] desktop-av-bridge-host/core/session-controller.mjs:SessionController.#applyResourceStateSerial(diff)
        └── [ASYNC] desktop-av-bridge-host/core/session-controller.mjs:SessionController.#applyCamera(enabled, streamUrl)
            ├── desktop-av-bridge-host/adapters/linux-camera/bridge-runner.mjs:LinuxCameraBridgeRunner.setStreamUrl(streamUrl) [STATE]
            └── [ASYNC] desktop-av-bridge-host/adapters/linux-camera/bridge-runner.mjs:LinuxCameraBridgeRunner.startCamera()
                ├── [FALLBACK] LinuxCameraBridgeRunner.stopCamera() when prior process exists
                ├── [IO] node:child_process.spawn(run-bridge.sh, ...)
                ├── [ASYNC] stderr startup monitor
                └── [STATE] mark process active + stream URL bound
```

### Branching / Fallback Paths
```text
[FALLBACK] if prior camera process exists with different stream URL
LinuxCameraBridgeRunner.startCamera()
└── LinuxCameraBridgeRunner.stopCamera()  # bounded termination before new spawn
```

```text
[ERROR] if startup fails or process exits early
LinuxCameraBridgeRunner.startCamera()
└── throws Error("Camera bridge failed to start: ...")
   └── SessionController.#applyCamera(...) maps to camera issue state
```

### State And Data Transformations
- Toggle payload -> normalized target resource state.
- `cameraStreamUrl` -> adapter `streamUrl` + `activeStreamUrl`.
- Child process handle -> adapter runtime state (`process`, `activeStreamUrl`).

### Observability And Debug Points
- Adapter startup errors surfaced through session issue `detail`.
- Host status endpoint reflects resource/issue transitions.

### Design Smells / Gaps
- Legacy branch present: `No`
- Naming-to-responsibility drift: `No`

### Coverage Status
- Primary Path: `Covered`
- Fallback Path: `Covered`
- Error Path: `Covered`

## Use Case: UC-002 Stop camera route with bounded termination

### Goal
Guarantee stop operation resolves even if camera bridge child does not exit on `SIGTERM`.

### Preconditions
- Linux camera process currently active.

### Expected Outcome
- `stopCamera()` resolves after graceful exit or forced kill timeout.

### Primary Runtime Call Stack
```text
[ENTRY] desktop-av-bridge-host/core/session-controller.mjs:SessionController.#applyCamera(enabled=false, ...)
└── [ASYNC] desktop-av-bridge-host/adapters/linux-camera/bridge-runner.mjs:LinuxCameraBridgeRunner.stopCamera()
    ├── [STATE] detach current process reference from adapter
    ├── [IO] send SIGTERM to child
    ├── [ASYNC] wait for exit with timeout guard
    ├── [FALLBACK] [IO] send SIGKILL when timeout elapses and child still running
    └── [STATE] resolve with cleared runtime state
```

### Branching / Fallback Paths
```text
[ERROR] if signal delivery throws
LinuxCameraBridgeRunner.stopCamera()
└── signal exception ignored, timer/exit guard still resolves stop path safely
```

### State And Data Transformations
- Active child handle -> nullable reference.
- Process running state -> terminated state with bounded wait.

### Observability And Debug Points
- Potential warning/error lines are captured by upstream issue mapping on next apply cycle.

### Design Smells / Gaps
- Legacy branch present: `No`
- Naming-to-responsibility drift: `No`

### Coverage Status
- Primary Path: `Covered`
- Fallback Path: `N/A`
- Error Path: `Covered`

## Use Case: UC-003 Validate no regression in host/Linux E2E checks

### Goal
Preserve existing Linux working behavior after lifecycle hardening change.

### Preconditions
- Code change applied.

### Expected Outcome
- Unit/integration suite passes.
- Linux Docker E2E passes with active camera/microphone/speaker and no issues.

### Primary Runtime Call Stack
```text
[ENTRY] desktop-av-bridge-host/package.json:scripts.test
└── [ASYNC] node --test tests/unit/*.test.mjs tests/integration/*.test.mjs

[ENTRY] desktop-av-bridge-host/package.json:scripts.test:docker:linux-e2e
└── [ASYNC] desktop-av-bridge-host/tests/docker/run_linux_container_e2e.sh
    ├── [IO] docker compose build/up host-agent + rtsp services
    ├── [IO] HTTP pair/toggle/status checks
    ├── [IO] process checks (camera bridge + mic source)
    └── [IO] speaker stream capture + RMS validation
```

### Branching / Fallback Paths
```text
[ERROR] if regression occurs in lifecycle or media route
run_linux_container_e2e.sh
└── non-zero exit with failed assertion and captured failing checkpoint
```

### State And Data Transformations
- Test harness requests -> host state transitions -> asserted status/resources.

### Observability And Debug Points
- E2E script logs each checkpoint with explicit failure boundary.

### Design Smells / Gaps
- Legacy branch present: `No`
- Naming-to-responsibility drift: `No`

### Coverage Status
- Primary Path: `Covered`
- Fallback Path: `N/A`
- Error Path: `Covered`
