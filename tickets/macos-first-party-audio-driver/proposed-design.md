# Proposed Design: macOS First-Party Virtual Audio Driver

## Design Version
- Current Version: `v2`

## Revision History
| Version | Trigger | Summary Of Changes | Related Review Round |
| --- | --- | --- | --- |
| v1 | Initial draft | First-party AudioServerPlugIn-based virtual mic/output architecture replacing BlackHole dependency. | 1 |
| v2 | Review round 1 write-back | Locked IPC design to `UNIX domain control socket + shared-memory ring buffers`; constrained naming semantics to active-paired-phone model for v1. | 1 |

## Summary
Implement a first-party macOS AudioServerPlugIn bundle (`PRCAudio.driver`) plus host-side bridge that feeds phone RTSP audio into virtual input (microphone) and captures virtual output (speaker route) back to phone stream endpoint.

## Goals
- Eliminate BlackHole installation dependency.
- Expose first-party selectable mic/output endpoints for meeting apps.
- Keep camera path unchanged (PRCCamera remains current camera virtualization path).
- Preserve one-tap user workflow through host installer/app.

## Non-Goals
- iOS host support in this ticket.
- Multi-phone simultaneous audio graph in first release.
- Kernel extension development.

## Legacy Removal Policy (Mandatory)
- Policy: `No backward compatibility; remove legacy code paths.`
- Required action: delete BlackHole checks, installer bootstrap, and BlackHole-specific route hints in the same implementation.

## Requirements And Use Cases
- Requirements basis: `tickets/macos-first-party-audio-driver/requirements.md`
- Use cases: UC-001..UC-006

## Codebase Understanding Snapshot (Pre-Design Mandatory)
| Area | Findings | Evidence (files/functions) | Open Unknowns |
| --- | --- | --- | --- |
| Entrypoints / Boundaries | Toggle API controls camera/mic/speaker lifecycle; macOS audio adapter currently ffmpeg->BlackHole. | `host-resource-agent/core/session-controller.mjs`, `host-resource-agent/adapters/macos-audio/audio-runner.mjs` | None blocking for design stage. |
| Current Naming Conventions | Adapter folders by platform/capability; labels generated via common helper. | `host-resource-agent/adapters/*`, `host-resource-agent/adapters/common/device-name.mjs` | Multi-phone simultaneous labels deferred out of scope in v1. |
| Impacted Modules / Responsibilities | Preflight and installer explicitly require BlackHole. | `host-resource-agent/core/preflight-service.mjs`, `host-resource-agent/installers/macos/install.command` | Installer hardening for driver bundle upgrade path. |
| Data / Persistence / External IO | RTSP ingest via ffmpeg, speaker clients served by HTTP stream endpoint. | `host-resource-agent/adapters/macos-audio/audio-runner.mjs`, `host-resource-agent/linux-app/server.mjs` | Exact buffering policy for low-latency + dropout recovery. |

## Current State (As-Is)
- Mic: ffmpeg decodes RTSP and writes to BlackHole output device.
- Speaker: ffmpeg captures from AVFoundation-selected device (often BlackHole monitor-like path) and streams PCM to Android phone.
- Installer and preflight enforce BlackHole as dependency.

## Target State (To-Be)
- Mic: host agent decodes RTSP audio and writes PCM to first-party driver input ring buffer.
- Speaker: app audio written to first-party driver output stream is pulled by host agent and exposed to Android via `/api/speaker/stream`.
- Preflight validates first-party driver health only.
- Installer deploys/updates first-party driver bundle and host runtime without third-party audio tools.

## Change Inventory (Delta)
| Change ID | Change Type (`Add`/`Modify`/`Rename/Move`/`Remove`) | Current Path | Target Path | Rationale | Impacted Areas | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| C-001 | Add | N/A | `host-resource-agent/macos-audio-driver/PRCAudio.driver/*` | New first-party AudioServerPlugIn bundle. | macOS audio virtualization | Includes bundle metadata + plugin binary. |
| C-002 | Add | N/A | `host-resource-agent/macos-audio-driver/src/*` | Driver source, IPC bridge, ring buffers, property handlers. | Driver runtime | C++/ObjC++ implementation. |
| C-003 | Add | N/A | `host-resource-agent/macos-audio-driver/scripts/install-driver.sh` | Deterministic install/uninstall/update scripts. | Packaging | Handles `coreaudiod` restart when needed. |
| C-004 | Add | N/A | `host-resource-agent/adapters/macos-firstparty-audio/audio-runner.mjs` | Host-side lifecycle orchestration for first-party driver. | Host adapter | Replaces BlackHole-bound code. |
| C-005 | Modify | `host-resource-agent/core/session-controller.mjs` | same | Wire new adapter selection and health semantics. | Session lifecycle | Keep API shape stable. |
| C-006 | Modify | `host-resource-agent/core/preflight-service.mjs` | same | Replace BlackHole checks with driver health checks. | UX/preflight | Validate driver visibility + IPC readiness. |
| C-007 | Modify | `host-resource-agent/installers/macos/install.command` | same | Install first-party driver and remove BlackHole bootstrap. | Install UX | Keep one-click flow. |
| C-008 | Remove | `host-resource-agent/adapters/macos-audio/audio-runner.mjs` | deleted | Remove legacy BlackHole runtime path. | macOS audio runtime | Mandatory no-legacy cleanup. |
| C-009 | Modify | `host-resource-agent/README.md` | same | Update user setup and troubleshooting docs. | Docs | Remove third-party dependency instructions. |
| C-010 | Add | N/A | `host-resource-agent/tests/macos-audio-driver/*` | Integration tests for driver+adapter lifecycle. | Test coverage | Includes stress and recovery tests. |

## Architecture Overview
1. `session-controller` applies toggles.
2. `macos-firstparty-audio` adapter starts or stops mic/speaker routes.
3. Adapter uses a local UNIX domain control socket and shared-memory ring buffers exposed by `PRCAudio.driver` helper bridge.
4. Driver publishes virtual input/output endpoints to CoreAudio clients.
5. Android receives speaker PCM from existing `/api/speaker/stream` endpoint.

## File And Module Breakdown
| File/Module | Change Type | Concern / Responsibility | Public APIs | Inputs/Outputs | Dependencies |
| --- | --- | --- | --- | --- | --- |
| `host-resource-agent/macos-audio-driver/src/PRCAudioPlugin.mm` | Add | AudioServerPlugIn entry and object dispatch | `PRCAudio_Create`, HAL callbacks | HAL property/IO requests | CoreAudio framework |
| `host-resource-agent/macos-audio-driver/src/PRCAudioDevice.mm` | Add | Virtual input/output stream implementation | stream start/stop/read/write handlers | PCM frames in/out | lock-free ring buffer |
| `host-resource-agent/macos-audio-driver/src/IPCBridge.mm` | Add | IPC between host adapter and driver runtime | `publishMicFrames`, `consumeSpeakerFrames`, control ops | PCM/control messages | UNIX domain socket + shared memory |
| `host-resource-agent/adapters/macos-firstparty-audio/audio-runner.mjs` | Add | Host orchestration for mic/speaker lifecycle | `startMicrophoneRoute`, `startSpeakerRoute`, `attachSpeakerClient` | RTSP URL, HTTP clients, phone identity | ffmpeg + local IPC client |
| `host-resource-agent/core/preflight-service.mjs` | Modify | Surface install/readiness checks | existing preflight API | health status | driver probes |
| `host-resource-agent/installers/macos/install.command` | Modify | App + driver install UX | installer shell entrypoint | packaged assets | bash, launchctl/coreaudiod restart hook |

## Naming Decisions (Natural And Implementation-Friendly)
| Item Type (`File`/`Module`/`API`) | Current Name | Proposed Name | Reason | Notes |
| --- | --- | --- | --- | --- |
| Module | `macos-audio/audio-runner.mjs` | `macos-firstparty-audio/audio-runner.mjs` | Removes BlackHole-implied semantics, states ownership. | Replaces legacy module entirely. |
| Driver Bundle | N/A | `PRCAudio.driver` | Align with `PRCCamera` brand + clear purpose. | User-visible name uses phone prefix. |
| API | `setStreamUrl` only | `setDeviceIdentity`, `setMicStreamUrl`, `start/stop*Route` | Explicit lifecycle semantics for dual-path routing. | API parity with other adapters. |

## Naming-Drift Check
| Item | Drifted? | Action | Mapping |
| --- | --- | --- | --- |
| macOS audio adapter naming | Yes | Rename/replace | C-004, C-008 |
| preflight check id `macos_blackhole` | Yes | Rename | C-006 |
| installer tips referencing BlackHole | Yes | Remove/update | C-007 |

## Dependency Flow And Cross-Reference Risk
| Module/File | Upstream Dependencies | Downstream Dependents | Cross-Reference Risk | Mitigation / Boundary Strategy |
| --- | --- | --- | --- | --- |
| `session-controller` | API handlers, adapter factory | host API + UI | Medium | Keep adapter interface stable. |
| `macos-firstparty-audio` adapter | ffmpeg, IPC client, device-name helper | session-controller | Medium | Isolate IPC in single helper module. |
| `PRCAudio.driver` | CoreAudio HAL | macOS audio clients + adapter | High | Strict contract tests and versioned IPC protocol (control socket + ring-buffer schema). |
| installer scripts | packaged driver + host bundle | end users | Medium | idempotent install/uninstall + diagnostics output. |

## Decommission / Cleanup Plan
| Item To Remove/Rename | Cleanup Actions | Legacy Removal Notes | Verification |
| --- | --- | --- | --- |
| BlackHole runtime checks | Remove check ids and messages in preflight | No fallback path retained | source scan + preflight tests |
| BlackHole installer bootstrap | Remove brew cask install from mac installer | No optional auto-install remains | installer smoke test |
| legacy macOS audio adapter | delete old module and imports | enforce first-party path only | unit + integration tests |

## Data Models (If Needed)
- IPC frame header:
  - stream type (`mic_in` / `speaker_out`)
  - sample rate (default 48000)
  - channels (default 1)
  - sequence number + monotonic timestamp
  - payload length
- IPC transport:
  - control plane: UNIX domain socket at `/tmp/prc-audio-driver.sock`
  - data plane: two shared-memory ring buffers (`mic_ingress`, `speaker_egress`)

## Error Handling And Edge Cases
- Driver unavailable: preflight `needs_attention` + install remediation.
- IPC disconnect: adapter marks route unhealthy and retries with bounded backoff.
- Buffer overrun/underrun: counters exposed in health endpoint; route stays alive with dropped-frame reporting.
- Device rename failure: fallback to stable generic PRC name and log warning.

## Use-Case Coverage Matrix (Design Gate)
| use_case_id | Use Case | Primary Path Covered (`Yes`/`No`) | Fallback Path Covered (`Yes`/`No`/`N/A`) | Error Path Covered (`Yes`/`No`/`N/A`) | Runtime Call Stack Section |
| --- | --- | --- | --- | --- | --- |
| UC-001 | Install first-party mic visibility | Yes | Yes | Yes | UC-001 |
| UC-002 | Meeting app mic input via phone | Yes | Yes | Yes | UC-002 |
| UC-003 | Desktop audio to phone speaker | Yes | Yes | Yes | UC-003 |
| UC-004 | Toggle camera/mic/speaker independently | Yes | Yes | Yes | UC-004 |
| UC-005 | Phone-name-prefixed labeling | Yes | N/A | Yes | UC-005 |
| UC-006 | Restart recovery without reboot | Yes | Yes | Yes | UC-006 |

## Performance / Security Considerations
- Realtime I/O path avoids allocations/locks in render callbacks.
- IPC protocol restricted to local host only.
- Driver and host binaries signed; release path notarized.
- Health checks include glitch/drop counters and driver heartbeat.

## Migration / Rollout (If Needed)
1. Land driver + adapter behind internal dev channel.
2. Run real-device macOS validation matrix (Zoom + OBS + phone loop).
3. Remove BlackHole code and docs in same release branch.

## Change Traceability To Implementation Plan
| Change ID | Implementation Plan Task(s) | Verification (Unit/Integration/Manual) | Status |
| --- | --- | --- | --- |
| C-001..C-003 | T-001..T-003 | build + install + visibility checks | Planned |
| C-004..C-008 | T-004..T-008 | adapter tests + end-to-end toggles | Planned |
| C-009..C-010 | T-009..T-010 | docs/test suite updates | Planned |

## Design Feedback Loop Notes (From Review/Implementation)
| Date | Trigger (Review/File/Test/Blocker) | Design Smell | Design Update Applied | Status |
| --- | --- | --- | --- | --- |
| 2026-02-17 | Initial authoring | None yet | v1 drafted | Open |
| 2026-02-17 | Runtime call stack review round 1 | IPC transport ambiguity and naming scope ambiguity | v2 fixed transport contract + scoped naming to active paired phone only | Closed |

## Open Questions
- Whether to expose one duplex device vs separate input/output devices from first release.
