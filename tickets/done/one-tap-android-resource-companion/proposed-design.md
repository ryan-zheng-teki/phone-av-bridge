# Proposed Design Document

## Design Version

- Current Version: `v3`

## Revision History

| Version | Trigger | Summary Of Changes | Related Review Round |
| --- | --- | --- | --- |
| v1 | Initial draft | Android + host virtualization architecture baseline. | 1-5 |
| v2 | Requirements v2 (`zero-technical-setup`) | Added host desktop app + installer/preflight UX responsibilities and Linux-first execution details. | 6 |
| v3 | Docker validation + Linux speaker implementation | Added Linux speaker stream route and one-container E2E validation harness architecture. | 8-9 |

## Summary

Build an Android companion app plus a desktop host app so non-technical users can install, pair once, toggle resources, and select phone camera/mic/speaker in meeting apps without terminal work.

## Goals

- End users perform no terminal commands.
- Android app keeps exactly three toggles: `Camera`, `Microphone`, `Speaker`.
- Host app exposes standard OS-selectable camera/mic/speaker devices.
- Host app provides guided preflight checks and remediation.

## Non-Goals

- Internet relay (LAN-first only).
- iOS implementation in this ticket.
- Backward compatibility with legacy plugin paths.

## Legacy Removal Policy

- Policy: `No backward compatibility; remove legacy/obsolete paths in affected scope.`

## Requirements And Use Cases

- Source:
  - `tickets/one-tap-android-resource-companion/requirements.md`
  - `tickets/one-tap-android-resource-companion/deep-investigation.md`
- Covered use cases: `UC-001`..`UC-009`

## Codebase Understanding Snapshot

| Area | Findings | Evidence | Open Unknowns |
| --- | --- | --- | --- |
| Android app | Basic app module exists with pairing/toggles/service state logic and tests. | `android-resource-companion/app/src/main/*` | Transport integration for real host pairing. |
| Host bridge baseline | Existing shell MVP for RTSP ingest and Linux sink backends. | `phone-ip-webcam-bridge/bin/*` | Best host-app runtime stack for Linux/macOS installers. |
| Host app baseline | Linux-first host app module exists with local API/UI, tests, and installers. | `host-resource-agent/*` | Transport/security hardening and macOS parity rollout details. |

## Current State (As-Is)

- Android app logic is emulator-validated.
- Host app baseline exists with installer-generated launchers and bundled runtime path, but full non-technical end-to-end is not complete.
- Linux and macOS control/media pipelines are implemented.
- One-container Linux Docker E2E validation exists for camera/mic/speaker control path with emulated camera backend.
- Full real meeting-app interoperability remains incomplete.

## Target State (To-Be)

- Android app:
  - Pair/unpair + three toggles.
  - Runtime permissions and foreground-service compliant behavior.
- Host app (`host-resource-agent`):
  - GUI status shell + local control API.
  - Pairing/session/control core.
  - Linux and macOS adapters behind capability-based abstraction.
  - Preflight diagnostics with guided remediation.
- Linux:
  - Camera via `v4l2loopback`.
  - Audio via PipeWire/Pulse virtual endpoints.
  - Package install path (`AppImage` + one native package).
- macOS:
  - Camera via OBS Virtual Camera integration.
  - Audio via BlackHole virtual audio route.

## Change Inventory (Delta)

| Change ID | Change Type | Current Path | Target Path | Rationale | Impacted Areas |
| --- | --- | --- | --- | --- | --- |
| C-001 | Add/Modify | `android-resource-companion/*` | `android-resource-companion/*` | Harden Android app and connect with host protocol. | Android |
| C-002 | Add | N/A | `host-resource-agent/core/*` | Typed host core for pairing/session/control. | Host core |
| C-003 | Add | N/A | `host-resource-agent/linux-app/*` | Linux desktop host UX + service launcher. | Linux host UX |
| C-004 | Add | `phone-ip-webcam-bridge/bin/run-bridge.sh` | `host-resource-agent/adapters/linux-camera/*` | Wrap/replace script path with managed adapter runtime. | Linux camera |
| C-005 | Add | N/A | `host-resource-agent/adapters/linux-audio/*` | Virtual mic/speaker routing path. | Linux audio |
| C-006 | Add | N/A | `host-resource-agent/installers/macos/*` | macOS host UX and guided setup shell. | macOS host UX |
| C-007 | Add | N/A | `host-resource-agent/adapters/macos-camera/*` | OBS virtual camera adapter path. | macOS camera |
| C-008 | Add | N/A | `host-resource-agent/adapters/macos-audio/*` | BlackHole-based mic routing path. | macOS audio |
| C-009 | Modify | `tickets/one-tap-android-resource-companion/*` | same | Keep workflow artifacts synchronized with execution. | Workflow |
| C-010 | Add/Modify | N/A + `host-resource-agent/adapters/linux-audio/*` | `host-resource-agent/tests/docker/*` + linux audio adapter updates | Add Linux speaker route and Docker E2E validation harness. | Linux audio + verification |

## Root Project Structure

- Root: `phone-resource-companion/`
- Modules:
  - `phone-resource-companion/android-resource-companion/`
  - `phone-resource-companion/host-resource-agent/`
  - `phone-resource-companion/phone-ip-webcam-bridge/`
  - `phone-resource-companion/tickets/one-tap-android-resource-companion/`

## Architecture Overview

- Android boundary:
  - UI toggles and permissions.
  - Sends desired resource state to host.
- Host core boundary:
  - Maintains pairing/session/auth state.
  - Dispatches requested resource state to OS adapters.
- Host UX boundary:
  - Presents non-technical status and remediation.
  - Never exposes raw device-node operations to users.
- Adapter boundary:
  - `CameraOutputAdapter`
  - `MicrophoneInputAdapter`
  - `SpeakerOutputAdapter`

## File And Module Breakdown

| File/Module | Change Type | Responsibility | Public APIs |
| --- | --- | --- | --- |
| `android-resource-companion/app/*` | Modify | Android toggles, permissions, service lifecycle. | app UI + intent/service API |
| `android-resource-companion/app/src/main/java/.../stream/PhoneRtspStreamer.kt` | Add | In-app RTSP media server lifecycle for camera/mic modes. | `update(camera,mic)`, `stop()` |
| `host-resource-agent/core/session-controller.mjs` | Add | Pairing, state negotiation, active resource orchestration. | `pairHost`, `applyResourceState`, `getStatus` |
| `host-resource-agent/core/preflight-service.mjs` | Add | Capability checks and remediation hints for host. | `runPreflight` |
| `host-resource-agent/linux-app/server.mjs` | Add | Local host API + static UI serving. | `startServer` |
| `host-resource-agent/linux-app/static/index.html` | Add | Non-technical host control/status UI. | browser UI events |
| `host-resource-agent/adapters/linux-camera/*` | Add | Linux camera virtualization runtime integration. | `startCamera`, `stopCamera` |
| `host-resource-agent/adapters/linux-audio/*` | Add | Linux mic/speaker virtualization runtime integration. | `startMicrophoneRoute`, `stopMicrophoneRoute`, `startSpeakerRoute`, `stopSpeakerRoute` |

## Naming Decisions

| Item Type | Proposed Name | Rationale |
| --- | --- | --- |
| Module | `host-resource-agent` | Clear host-side installable component name. |
| API | `runPreflight` | Explicitly maps to first-run diagnostic action. |
| API | `applyResourceState` | Single source of truth for toggle state application. |
| UI label | `Needs Attention` | Non-technical wording for recoverable setup issues. |

## Dependency Flow And Cross-Reference Risk

| Module | Dependencies | Risk | Mitigation |
| --- | --- | --- | --- |
| Android app | Android SDK + host protocol | Medium | Strict protocol contract and compatibility tests. |
| Host core | Node runtime + adapters | Medium | Keep adapters behind simple interfaces. |
| Linux adapters | ffmpeg + v4l2loopback + PipeWire/Pulse | Medium | Preflight plus remediation instructions in UI. |
| macOS adapters | OBS + BlackHole + AudioToolbox | Medium/High | Preflight checks and explicit first-run approval guidance. |

## Decommission / Cleanup Plan

| Item | Action |
| --- | --- |
| Script-only user path in docs | Replace with host-app-first instructions when host app is ready. |
| Legacy shell-only control flows | Keep for engineering diagnostics only, not default user path. |

## Data Models

- `PairingSession`:
  - host id, phone id, trust state, key fingerprint.
- `ResourceToggleState`:
  - camera, microphone, speaker booleans.
- `HostCapabilityState`:
  - camera support, microphone support, speaker support, missing dependencies list.
- `HostUiStatus`:
  - `Not Paired`, `Paired`, `Resource Active`, `Needs Attention`.

## Error Handling And Edge Cases

- Missing Linux dependency:
  - Host marks capability unavailable and surfaces one-click remediation guidance.
- Permission denied on Android:
  - Toggle is reset and host receives disabled state update.
- Adapter failure:
  - Failed resource transitions to `Needs Attention`; unrelated resources remain active.
- Session drop:
  - Auto-reconnect with bounded retries and clear UI state.

## Use-Case Coverage Matrix

| use_case_id | Primary | Fallback | Error | Runtime Call Stack Section |
| --- | --- | --- | --- | --- |
| UC-001 | Yes | Yes | Yes | UC-001 |
| UC-002 | Yes | Yes | Yes | UC-002 |
| UC-003 | Yes | Yes | Yes | UC-003 |
| UC-004 | Yes | Yes | Yes | UC-004 |
| UC-005 | Yes | Yes | Yes | UC-005 |
| UC-006 | Yes | Yes | Yes | UC-006 |
| UC-007 | Yes | Yes | Yes | UC-007 |
| UC-008 | Yes | Yes | Yes | UC-008 |
| UC-009 | Yes | Yes | Yes | UC-009 |

## Rollout Plan

1. Linux-first:
  - host core + host Linux UI + camera adapter + mic adapter.
2. Linux speaker stabilization + Docker E2E proof.
3. macOS first-run approval hardening.
4. macOS meeting-app validation pass.

## Change Traceability To Implementation Plan

| Change ID | Implementation Tasks |
| --- | --- |
| C-001 | T-001 |
| C-002 | T-002 |
| C-003 | T-003 |
| C-004 | T-004 |
| C-005 | T-005 |
| C-006 | T-009 |
| C-007 | T-010 |
| C-008 | T-011 |
| C-009 | docs sync tasks |
| C-010 | T-005, T-008 |
