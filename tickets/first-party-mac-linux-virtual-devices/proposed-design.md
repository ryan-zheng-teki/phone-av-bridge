# Proposed Design Document

## Design Version

- Current Version: `v3`
- Scope Classification: `Large`
- Requirements Basis: `tickets/first-party-mac-linux-virtual-devices/requirements.md` (`v2`)

## Revision History

| Version | Trigger | Summary Of Changes | Related Review Round |
| --- | --- | --- | --- |
| v1 | Initial draft | First-party virtual device architecture for macOS then Linux. | 1 |
| v2 | Requirements v2 refinement | Added explicit macOS/Linux first-party module split, remove inventory for OBS/BlackHole path, naming decisions, and drift checks. | Pending |
| v3 | Review round 1 write-back | Aligned adapter contract naming with controller identity contract (`setDeviceIdentity`). | 1 |

## Problem Summary

End users currently rely on external desktop apps and manual setup to expose phone camera/microphone/speaker to meeting apps. We need a first-party stack where Android app + desktop app is sufficient for macOS and Linux.

## Goals

- First-party virtual `Camera`, `Microphone`, and `Speaker` endpoints per paired phone.
- macOS-first delivery, Linux parity in same product track.
- Zero terminal requirement in normal user flow.
- Deterministic device naming for multi-phone environments.

## Non-Goals

- iOS implementation.
- WAN/internet relay.
- Backward compatibility with the OBS/BlackHole runtime in first-party mode.

## Current State (As-Is)

- Android app supports pairing and per-resource toggles.
- Host controller and API surfaces already manage resource lifecycle and status transitions.
- Linux stack already has user-space audio routing plus optional camera fallback.
- macOS stack currently depends on OBS Virtual Camera and BlackHole audio.

## Target State (To-Be)

- New first-party macOS adapter family backed by packaged user-space extension/plugin components.
- Linux default path centered on user-space media graph (PipeWire/Pulse), with kernel-camera compatibility mode only when user explicitly enables it.
- Host preflight and installer surface one-click remediation and app-guided first-run checks.
- Unified per-phone resource naming convention across all adapters.

## Change Inventory (Delta-Aware)

| Change ID | Change Type | Current Path | Target Path | Responsibility Delta |
| --- | --- | --- | --- | --- |
| C-001 | Add | N/A | `host-resource-agent/adapters/macos-firstparty-camera/camera-runner.mjs` | Own macOS first-party camera lifecycle (`startCamera/stopCamera/getCameraDeviceName`). |
| C-002 | Add | N/A | `host-resource-agent/adapters/macos-firstparty-audio/audio-runner.mjs` | Own macOS first-party mic + speaker lifecycle. |
| C-003 | Add | N/A | `host-resource-agent/adapters/common/device-name.mjs` | Canonical `<Phone Name> Camera/Microphone/Speaker` name generation. |
| C-004 | Modify | `host-resource-agent/linux-audio/audio-runner.mjs` | same | Keep Linux speaker/mic path first-party; harden user-space default and compatibility gates. |
| C-005 | Modify | `host-resource-agent/linux-camera/bridge-runner.mjs` | same | Explicit default backend policy and compatibility-mode branch. |
| C-006 | Modify | `host-resource-agent/core/preflight-service.mjs` | same | New first-party preflight checks and remediation messaging. |
| C-007 | Modify | `host-resource-agent/linux-app/server.mjs` | same | Platform adapter selection switches to first-party macOS path by default. |
| C-008 | Modify | `host-resource-agent/installers/macos/install.command` | same | Remove OBS/BlackHole bootstrap and install first-party components only. |
| C-009 | Modify | `host-resource-agent/installers/linux/install.sh` | same | Auto-remediation and default non-kernel user-space setup. |
| C-010 | Remove | `host-resource-agent/adapters/macos-camera/obs-websocket-client.mjs` | deleted | Remove OBS-specific control path. |
| C-011 | Remove | `host-resource-agent/adapters/macos-camera/obs-virtualcam-runner.mjs` | deleted | Remove OBS virtual camera dependency path. |
| C-012 | Remove | `host-resource-agent/adapters/macos-audio/audio-runner.mjs` | deleted | Remove BlackHole/OBS-linked macOS audio path. |

## File/Module Responsibilities And APIs

| File/Module | Responsibility | Public APIs | Inputs | Outputs | Dependencies |
| --- | --- | --- | --- | --- | --- |
| `host-resource-agent/adapters/macos-firstparty-camera/camera-runner.mjs` | Manage first-party macOS camera feed bridge | `startCamera`, `stopCamera`, `getCameraDeviceName`, `setDeviceIdentity` | RTSP URL, phone identity | Camera-ready state, named virtual camera | ffmpeg, packaged macOS camera extension/plugin helper |
| `host-resource-agent/adapters/macos-firstparty-audio/audio-runner.mjs` | Manage first-party mic and speaker routes on macOS | `startMicrophoneRoute`, `stopMicrophoneRoute`, `startSpeakerRoute`, `stopSpeakerRoute`, `attachSpeakerClient`, `setDeviceIdentity` | RTSP URL, phone identity, speaker stream clients | Mic input endpoint and speaker route endpoint | ffmpeg, packaged macOS audio plugin/helper |
| `host-resource-agent/adapters/common/device-name.mjs` | Normalize and generate per-phone labels | `buildDeviceNames(phoneName)` | phone name | camera/mic/speaker labels | none |
| `host-resource-agent/linux-audio/audio-runner.mjs` | Linux mic/speaker user-space routes | existing adapter APIs + `setDeviceIdentity` | toggles, phone identity, speaker stream clients | virtual source/sink routing | pactl/pipewire/ffmpeg |
| `host-resource-agent/linux-camera/bridge-runner.mjs` | Linux camera bridge with default/fallback policy | `startCamera`, `stopCamera`, `setDeviceIdentity` | RTSP URL, backend policy, phone identity | video device sink | ffmpeg, v4l2 backend only when compatibility mode is on |
| `host-resource-agent/core/preflight-service.mjs` | Evaluate dependencies and produce remediation list | `runPreflight` | platform + config | structured checks | OS commands, file/system probes |
| `host-resource-agent/linux-app/server.mjs` | Assemble controller + platform adapters | `createController` | env/config | running host service | controller + adapters |

## Naming Decisions

| Item | Decision | Rationale | Old Name Mapping |
| --- | --- | --- | --- |
| Shared name builder | `adapters/common/device-name.mjs` | Centralize name logic for multi-phone consistency. | scattered string building in platform adapters |
| macOS camera adapter | `macos-firstparty-camera/camera-runner.mjs` | Name reflects concern; avoids vendor-specific terms. | `macos-camera/obs-virtualcam-runner.mjs` |
| macOS audio adapter | `macos-firstparty-audio/audio-runner.mjs` | Name reflects native responsibility (not BlackHole/OBS). | `macos-audio/audio-runner.mjs` |
| Linux backend mode env | `LINUX_CAMERA_MODE` (`userspace`/`compatibility`) | Clear policy naming for users and tests. | `SINK_BACKEND` |

## Naming Drift Check

| Item | Drift Detected | Action | Mapped Change ID |
| --- | --- | --- | --- |
| `macos-camera` directory | Yes (implies generic camera but is OBS-specific) | Rename/split to `macos-firstparty-camera` and remove OBS files | C-001, C-010, C-011 |
| `macos-audio/audio-runner` | Yes (implies generic audio but BlackHole+OBS behavior) | Replace with first-party audio runner | C-002, C-012 |
| `SINK_BACKEND` env flag | Yes (ambiguous platform policy) | Replace with `LINUX_CAMERA_MODE` | C-005 |

## Dependency Flow And Cycle Control

`linux-app/server.mjs -> session-controller.mjs -> platform adapters -> system tools`

- No adapter imports controller internals.
- No cross-adapter imports except `adapters/common/device-name.mjs`.
- Shared helper module remains pure and dependency-free.

## Data Models And State

- Pairing state: `paired`, `resource active`, `needs attention` (existing controller state model retained).
- Device identity model:
  - `phoneName` (raw from pairing)
  - `normalizedName` (sanitized)
  - derived labels (`<name> Camera`, `<name> Microphone`, `<name> Speaker`)
- Toggle model:
  - `enableCamera`, `enableMicrophone`, `enableSpeaker` controls independent adapter lifecycles.

## Error Handling

- Adapter startup failure returns resource-scoped failure with remediation hint.
- Preflight failures are warnings unless resource activation depends on the missing component.
- Speaker, mic, camera are isolated: one failure must not force-stop healthy resources.
- Reconnect reuses pairing identity and re-runs adapter health checks.

## Use-Case Coverage Matrix

| use_case_id | Primary Path Covered | Fallback Path Covered | Error Path Covered | Mapped Runtime Call Stack Section |
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

## Decommission/Cleanup Intent

- Delete OBS and BlackHole adapter modules once first-party macOS adapters are integrated.
- Remove OBS/BlackHole preflight checks and installer bootstrap instructions.
- Remove legacy README/setup references that instruct external desktop app dependency.

## Open Design Risks

- macOS first-party camera/audio virtualization packaging may vary by OS minor versions.
- Linux meeting app behavior differs between native PipeWire consumers and V4L2-only clients.
- Speaker latency and echo-control quality require real-device validation.
