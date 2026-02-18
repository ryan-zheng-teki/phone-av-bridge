# Proposed Design Document

## Design Version
- Current Version: `v1`

## Revision History
| Version | Trigger | Summary Of Changes | Related Review Round |
| --- | --- | --- | --- |
| v1 | Initial draft | Stability + UX + media-quality hardening plan | 1 |

## Artifact Basis
- Investigation Notes: `tickets/stability-performance-ux-hardening/investigation-notes.md`
- Requirements: `tickets/stability-performance-ux-hardening/requirements.md`
- Requirements Status: `Design-ready`

## Summary
Harden the Android pairing/status UX and media configuration, and harden host-side issue mapping plus macOS speaker capture normalization. Keep the existing architecture and replace unstable/opaque behaviors with explicit, user-facing state and robust defaults.

## Goals
1. Make pairing and status behavior predictable and explainable.
2. Improve camera and microphone source quality consistency.
3. Reduce speaker playback artifacts and improve route diagnostics.
4. Improve user-facing clarity without introducing legacy branches.

## Legacy Removal Policy (Mandatory)
- Policy: `No backward compatibility; remove legacy code paths.`
- Action in this ticket:
  - Remove coarse status-only UI behavior in Android and replace with structured state rendering.
  - Remove raw host adapter errors from user-facing issue surface and replace with normalized issue messages.

## Requirements And Use Cases
| Requirement | Description | Acceptance Criteria | Use Case IDs |
| --- | --- | --- | --- |
| R-001 | Reliable pairing + recovery UX | categorized pairing outcomes + actionable status | UC-PAIR-01, UC-STATUS-01 |
| R-002 | Better Android UX clarity | guided layout + host/status details | UC-STATUS-01 |
| R-003 | Better camera quality defaults | explicit video profile | UC-CAMERA-01 |
| R-004 | Better speaker stability | normalized capture + robust playback handling | UC-SPEAKER-01 |
| R-005 | User-safe host issues | mapped non-cryptic issue messages | UC-HOST-ISSUE-01 |
| R-006 | Installation clarity | updated docs + installer behavior docs | UC-INSTALL-01 |

## Codebase Understanding Snapshot (Pre-Design Mandatory)
| Area | Findings | Evidence (files/functions) | Open Unknowns |
| --- | --- | --- | --- |
| Entrypoints / Boundaries | Android UI triggers pair/toggle; host HTTP API applies routes | `MainActivity.kt`, `ResourceService.kt`, `linux-app/server.mjs`, `core/session-controller.mjs` | network edge case frequency |
| Current Naming Conventions | Direct, function-oriented names | `HostDiscoveryClient`, `PhoneRtspStreamer`, `SessionController` | none |
| Impacted Modules / Responsibilities | Android UI + Android stream + host session + macOS audio runner | listed in sources | exact per-device encoder limits |
| Data / Persistence / External IO | SharedPreferences + host persisted state + ffmpeg subprocess IO | `AppPrefs.kt`, `server.mjs`, adapter files | none blocking |

## Current State (As-Is)
- Pairing UI has limited state granularity.
- Discovery fallback is minimal.
- RTSP camera encoding defaults are implicit.
- Host issues are low-level adapter error strings.
- macOS speaker capture path lacks explicit resample/format normalization flags.

## Target State (To-Be)
- Android renders explicit connection health and host identity details.
- Pairing failures are categorized with deterministic fallback attempts.
- Android RTSP config uses explicit quality profile.
- Host session controller maps adapter errors into user-safe remediation messages.
- macOS speaker capture uses explicit ffmpeg audio normalization pipeline.

## Change Inventory (Delta)
| Change ID | Change Type | Current Path | Target Path | Rationale | Impacted Areas | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| C-001 | Modify | `android-resource-companion/.../MainActivity.kt` | same | pairing/state hardening + UI model improvements | Android UX/stability | |
| C-002 | Modify | `android-resource-companion/.../activity_main.xml` | same | guided UI and clearer status blocks | Android UX | |
| C-003 | Modify | `android-resource-companion/.../strings.xml` | same | actionable copy and state labels | Android UX | |
| C-004 | Modify | `android-resource-companion/.../PhoneRtspStreamer.kt` | same | explicit quality profile + stream robustness | camera quality | |
| C-005 | Modify | `android-resource-companion/.../HostSpeakerStreamPlayer.kt` | same | stronger playback robustness for stream artifacts | speaker quality | |
| C-006 | Modify | `host-resource-agent/core/session-controller.mjs` | same | user-safe issue normalization layer | host UX | |
| C-007 | Modify | `host-resource-agent/adapters/macos-firstparty-audio/audio-runner.mjs` | same | resample/format normalization for speaker capture | audio quality | |
| C-008 | Modify | `host-resource-agent/README.md` | same | simplified install/use guidance | packaging UX | |

## Architecture Overview
- No new services/processes.
- Existing control flow remains:
  - Android UI -> Host API pair/toggles.
  - Android foreground service -> RTSP + speaker pull.
  - Host session controller -> platform adapters.
- Improvements are behavior-level and UX-level in existing modules.

## File And Module Breakdown
| File/Module | Change Type | Concern / Responsibility | Public APIs | Inputs/Outputs | Dependencies |
| --- | --- | --- | --- | --- | --- |
| `MainActivity.kt` | Modify | user pairing/toggle orchestration and status rendering | internal activity methods | prefs + host status -> UI | `HostApiClient`, `HostDiscoveryClient`, `AppPrefs` |
| `activity_main.xml` | Modify | Android top-level interaction layout | N/A | user actions | Material components |
| `strings.xml` | Modify | user-facing language | N/A | text resources | Android resource system |
| `PhoneRtspStreamer.kt` | Modify | phone RTSP stream setup and mode switching | `update()`, `stop()` | toggle state -> RTSP endpoint | Pedro RTSP server |
| `HostSpeakerStreamPlayer.kt` | Modify | speaker stream playback on phone | `start()`, `stop()` | host PCM stream -> AudioTrack | `HttpURLConnection`, `AudioTrack` |
| `session-controller.mjs` | Modify | canonical host state + route orchestration + issues | `pairHost`, `unpairHost`, `applyResourceState` | API diffs -> normalized status | camera/audio adapters |
| `audio-runner.mjs` | Modify | macOS mic/speaker route process mgmt | start/stop route methods | ffmpeg IO | ffmpeg + avfoundation/audiotoolbox |

## Layer-Appropriate Separation Of Concerns Check
- UI/frontend scope: Android activity focuses on orchestration and display state.
- Non-UI scope: streamer/player/controller remain single-responsibility.
- Integration scope: macOS audio runner remains adapter boundary; no cross-leak into controller.

## Naming Decisions (Natural And Implementation-Friendly)
| Item Type | Current Name | Proposed Name | Reason | Notes |
| --- | --- | --- | --- | --- |
| API/Method | raw issue push | normalized issue push | user-safe messaging | implemented as helper functions, no file rename |
| UI State | status text only | status + detail lines | better UX clarity | no file rename |

## Naming Drift Check (Mandatory)
| Item | Current Responsibility | Does Name Still Match? | Corrective Action | Mapped Change ID |
| --- | --- | --- | --- | --- |
| `MainActivity` | Android screen controller | Yes | N/A | C-001 |
| `SessionController` | host session state machine | Yes | N/A | C-006 |
| `PhoneRtspStreamer` | RTSP media route manager | Yes | N/A | C-004 |

## Dependency Flow And Cross-Reference Risk
| Module/File | Upstream Dependencies | Downstream Dependents | Cross-Reference Risk | Mitigation / Boundary Strategy |
| --- | --- | --- | --- | --- |
| `MainActivity.kt` | Host clients, prefs | Android UI behavior | Medium | keep status derivation local; no adapter logic |
| `session-controller.mjs` | adapters | server API handlers | Medium | isolate issue normalization helper in controller |
| `audio-runner.mjs` | ffmpeg, devices | session controller | Low | adapter-only flag changes |

## Decommission / Cleanup Plan
| Item To Remove/Rename | Cleanup Actions | Legacy Removal Notes | Verification |
| --- | --- | --- | --- |
| raw issue strings in user surface | map known patterns to friendly messages | removes technical-only user messaging path | host integration tests + manual `/api/status` check |
| coarse Android status-only rendering | replace with richer state rendering | removes old ambiguous-only feedback path | Android build + UI sanity |

## Error Handling And Edge Cases
- Discovery timeout: explicit fallback and user-safe message.
- Host unreachable after paired: degraded state, toggles remain user-controlled, publish retries continue.
- Missing RTSP endpoint when media enabled: mapped issue and no crash.
- Speaker stream disconnect: player reconnect loop continues, no app crash.

## Use-Case Coverage Matrix (Design Gate)
| use_case_id | Requirement | Use Case | Primary Path Covered | Fallback Path Covered | Error Path Covered | Runtime Call Stack Section |
| --- | --- | --- | --- | --- | --- | --- |
| UC-PAIR-01 | R-001 | Pair host from disconnected state | Yes | Yes | Yes | 1 |
| UC-STATUS-01 | R-001,R-002 | Show paired/degraded state with details | Yes | N/A | Yes | 2 |
| UC-CAMERA-01 | R-003 | Enable camera with quality profile | Yes | Yes | Yes | 3 |
| UC-MIC-01 | R-003 | Enable mic route | Yes | Yes | Yes | 4 |
| UC-SPEAKER-01 | R-004 | Enable speaker route and play host audio | Yes | Yes | Yes | 5 |
| UC-HOST-ISSUE-01 | R-005 | Host reports normalized issues | Yes | N/A | Yes | 6 |

## Performance / Security Considerations
- Use conservative but explicit quality defaults to avoid excessive CPU.
- Keep network IO on background executors only.
- No new privileged operations added.

## Change Traceability To Implementation Plan
| Change ID | Implementation Plan Task(s) | Verification (Unit/Integration/E2E/Manual) | Status |
| --- | --- | --- | --- |
| C-001..C-008 | T1..T8 | mixed (unit/integration/build/manual) | Planned |

## Open Questions
1. Device-specific optimal bitrate ceiling for older Android hardware.
2. Best default capture source string for macOS speaker path on systems with custom audio routing.
