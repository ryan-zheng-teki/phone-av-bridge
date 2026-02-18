# Proposed Design Document

## Design Version
- Current Version: `v2`

## Revision History
| Version | Trigger | Summary Of Changes | Related Review Round |
| --- | --- | --- | --- |
| v1 | Initial draft | Defined canonical naming and rename inventory for active runtime modules. | 1 |
| v2 | Scope expansion | Added full macOS camera/audio artifact and bundle-ID rebrand (`PRC*` removal). | 3 |

## Artifact Basis
- Investigation Notes: `tickets/in-progress/project-naming-refactor/investigation-notes.md`
- Requirements: `tickets/in-progress/project-naming-refactor/requirements.md`
- Requirements Status: `Design-ready`

## Summary
Standardize active project naming to `Phone AV Bridge` / `phone-av-bridge` and remove naming drift across module paths, runtime identifiers, and UI copy while preserving runtime behavior.

## Goals
- Use one canonical product name across user-facing surfaces.
- Use responsibility-aligned module names across source tree.
- Keep runtime behavior identical (pairing/discovery/toggle/media routing).

## Legacy Removal Policy (Mandatory)
- Policy: `No backward compatibility; remove legacy code paths.`
- Required action: remove legacy naming references from active runtime code/docs; no alias constants or dual-name branches.

## Requirements And Use Cases
| Requirement | Description | Acceptance Criteria | Use Case IDs |
| --- | --- | --- | --- |
| R-001 | Canonical naming adoption | AC-001, AC-004 | UC-001, UC-002 |
| R-002 | Module path rename | AC-002, AC-005 | UC-001, UC-004 |
| R-003 | Runtime identifier rename | AC-003, AC-005 | UC-003, UC-004 |
| R-004 | Docs sync | AC-006 | UC-001, UC-002 |

## Codebase Understanding Snapshot (Pre-Design Mandatory)
| Area | Findings | Evidence (files/functions) | Open Unknowns |
| --- | --- | --- | --- |
| Entrypoints / Boundaries | Android controller app -> host API server -> platform adapters. | `android-resource-companion/.../MainActivity.kt`, `host-resource-agent/linux-app/server.mjs`, `host-resource-agent/core/session-controller.mjs` | None blocking rename plan. |
| Current Naming Conventions | Kebab-case module folders; mixed user-facing naming. | root `README.md`, Android `strings.xml`, host static UI | Whether to rename `PRCCamera`/`PRCAudio` now. |
| Impacted Modules / Responsibilities | 3 active runtime modules plus docs and installers. | root `README.md` module list | External scripts outside repo may still use old paths. |
| Data / Persistence / External IO | Pairing state and host launcher/log paths include old names. | `host-resource-agent/linux-app/server.mjs`, installer scripts | Data migration policy for renamed state path. |

## Current State (As-Is)
- Root naming: `phone-resource-companion`.
- Runtime modules: `android-resource-companion`, `host-resource-agent`, `phone-ip-webcam-bridge`.
- Discovery/service identity uses `PHONE_RESOURCE_COMPANION_DISCOVER_V1` and `phone-resource-companion`.
- User copy includes `Resource Companion`, `Phone Resource Companion`, `Host Resource Agent`, `PRC Camera Host`.

## Target State (To-Be)
- Canonical display name: `Phone AV Bridge`.
- Canonical slug: `phone-av-bridge`.
- Active runtime module names are explicit and responsibility-aligned.
- Discovery/service identifiers and user-visible strings align to canonical name.

## Change Inventory (Delta)
| Change ID | Change Type (`Add`/`Modify`/`Rename/Move`/`Remove`) | Current Path | Target Path | Rationale | Impacted Areas | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| C-001 | Rename/Move | `android-resource-companion/` | `android-phone-av-bridge/` | Canonical naming consistency | Android build/test paths | Update Gradle root project name accordingly. |
| C-002 | Rename/Move | `host-resource-agent/` | `desktop-av-bridge-host/` | Responsibility clarity and canonical naming | Host runtime, tests, installers | Update package name and scripts. |
| C-003 | Rename/Move | `phone-ip-webcam-bridge/` | `phone-av-camera-bridge-runtime/` | Bridge runtime naming aligned to AV product | Linux camera adapter, docs, docker configs | Camera-specific bridge stays explicit. |
| C-004 | Modify | Discovery/service constants and payload values | Canonical `PHONE_AV_BRIDGE_DISCOVER_V1`, `phone-av-bridge` | Remove identifier drift | Android discovery + host broadcast tests | Must update both ends. |
| C-005 | Modify | User-facing strings (`Resource Companion`, `Host Resource Agent`) | `Phone AV Bridge`, `Phone AV Bridge Host` | Product consistency | Android and host web UI | No behavior change. |
| C-006 | Modify | Host path/binary/log/state naming (`host-resource-agent*`) | `phone-av-bridge-host*` forms | Remove old naming from runtime operations | installers, runtime state/log files | No compatibility alias retained. |
| C-007 | Modify | Top-level and module README references | Canonical names + renamed module paths | Keep docs accurate | root/docs/module docs | Active docs only. |
| C-008 | Remove | Old naming references in active code paths | N/A | Mandatory cleanup | runtime code/docs/scripts | Historical `tickets/done` kept archival. |
| C-009 | Modify | macOS camera/audio artifact names + bundle identifiers | `PhoneAVBridgeCamera*`, `PhoneAVBridgeAudio*`, `org.autobyteus.phoneavbridge.*` | Complete brand consistency | macOS app, extension, host preflight/install/runtime | Requires one-time extension approval with new identifier. |

## Architecture Overview
Runtime architecture remains unchanged:
- Android app discovers/pairs with host and publishes toggles + stream URL.
- Desktop host applies resource routes using platform adapters.
- Camera bridge runtime supports Linux ingest/output path.

## File And Module Breakdown
| File/Module | Change Type | Concern / Responsibility | Public APIs | Inputs/Outputs | Dependencies |
| --- | --- | --- | --- | --- | --- |
| `android-phone-av-bridge` | Rename/Move + Modify | Phone-side controller app | Pair/toggle flows | Host API payloads | host server + RTSP libs |
| `desktop-av-bridge-host` | Rename/Move + Modify | Desktop orchestration and host API | `/api/bootstrap`, `/api/pair`, `/api/toggles`, `/api/status` | Device states/routes | adapters + bridge runtime |
| `phone-av-camera-bridge-runtime` | Rename/Move | Linux camera bridge runtime | `bin/run-bridge.sh` | RTSP in, sink out | ffmpeg/v4l2 |

## Layer-Appropriate Separation Of Concerns Check
- UI/frontend scope: unchanged; only naming/text updates.
- Non-UI scope: host server/adapters responsibilities unchanged.
- Integration scope: adapter contracts unchanged; path/constants updated.

## Naming Decisions (Natural And Implementation-Friendly)
| Item Type (`File`/`Module`/`API`) | Current Name | Proposed Name | Reason | Notes |
| --- | --- | --- | --- | --- |
| Product | Phone Resource Companion / Resource Companion | Phone AV Bridge | Exact value proposition | Canonical user-facing term |
| Module | `android-resource-companion` | `android-phone-av-bridge` | Align app module to product | Keeps android prefix |
| Module | `host-resource-agent` | `desktop-av-bridge-host` | Clarifies desktop host role | Avoids generic “agent” |
| Module | `phone-ip-webcam-bridge` | `phone-av-camera-bridge-runtime` | Accurate camera-runtime responsibility | Keeps runtime-specific meaning |
| Identifier | `PHONE_RESOURCE_COMPANION_DISCOVER_V1` | `PHONE_AV_BRIDGE_DISCOVER_V1` | Protocol naming consistency | Must change both producer/consumer |
| Service payload | `phone-resource-companion` | `phone-av-bridge` | Canonical slug alignment | Android discovery filter updated |

## Naming Drift Check (Mandatory)
| Item | Current Responsibility | Does Name Still Match? (`Yes`/`No`) | Corrective Action (`Rename`/`Split`/`Move`/`N/A`) | Mapped Change ID |
| --- | --- | --- | --- | --- |
| `host-resource-agent` | Desktop host API and adapter orchestration | No | Rename | C-002 |
| `phone-ip-webcam-bridge` | Linux camera ingest runtime under broader AV product | No | Rename | C-003 |
| `linux-app/` | Hosts Linux + macOS logic | No | Rename | C-002 |
| `Resource Companion` UI copy | Product name for AV bridge | No | Rename | C-005 |

## Dependency Flow And Cross-Reference Risk
| Module/File | Upstream Dependencies | Downstream Dependents | Cross-Reference Risk | Mitigation / Boundary Strategy |
| --- | --- | --- | --- | --- |
| Host server entrypoint path rename | installer scripts, npm scripts | tests, launchers | High | Rename path and update all script references in same change set. |
| Bridge module folder rename | host linux camera adapter | docker tests, docs | Medium | Update adapter hard-coded repoRoot path usage and docker compose references. |
| Android module path rename | Gradle settings + docs | CI/build commands | Medium | Update `settings.gradle.kts` and docs commands together. |

## Decommission / Cleanup Plan
| Item To Remove/Rename | Cleanup Actions | Legacy Removal Notes | Verification |
| --- | --- | --- | --- |
| Old module names in active files | Replace references and paths in scripts/docs/tests | No alias paths retained | `rg` scan for old names in active modules |
| Old discovery/service constants | Replace in both Android and host/tests | No dual constant fallback | integration tests + static scan |
| Old host launcher/log/state names | Rename generated file names and default paths | no compatibility start scripts | installer script sanity checks |

## Data Models (If Needed)
No data model schema changes.

## Error Handling And Edge Cases
- If external local scripts still call old module paths, they will fail; docs will point to new paths.
- If existing host persisted state exists at old path, new path is used without migration in this ticket.

## Use-Case Coverage Matrix (Design Gate)
| use_case_id | Requirement | Use Case | Primary Path Covered (`Yes`/`No`) | Fallback Path Covered (`Yes`/`No`/`N/A`) | Error Path Covered (`Yes`/`No`/`N/A`) | Runtime Call Stack Section |
| --- | --- | --- | --- | --- | --- | --- |
| UC-001 | R-001/R-002 | Developer sees canonical module naming | Yes | N/A | N/A | UC-001 |
| UC-002 | R-001 | User sees canonical product naming in UI | Yes | N/A | N/A | UC-002 |
| UC-003 | R-003 | Pair/discovery still works with new identifiers | Yes | Yes | Yes | UC-003 |
| UC-004 | R-002/R-004 | Host + bridge runtime still wired after path rename | Yes | Yes | Yes | UC-004 |

## Performance / Security Considerations
No performance/security behavior changes expected; refactor is naming-only.

## Migration / Rollout (If Needed)
- Single-shot rename release with synchronized Android + host + bridge updates.
- No backward compatibility aliases.

## Change Traceability To Implementation Plan
| Change ID | Implementation Plan Task(s) | Verification (Unit/Integration/E2E/Manual) | Status |
| --- | --- | --- | --- |
| C-001 | T-001, T-006 | Android unit test command | Planned |
| C-002 | T-002, T-006 | Host unit/integration tests | Planned |
| C-003 | T-003, T-006 | Host adapter + docker config static checks | Planned |
| C-004 | T-004, T-006 | discovery integration tests | Planned |
| C-005 | T-005, T-006 | UI string/static checks | Planned |
| C-006 | T-002, T-006 | installer script static checks | Planned |
| C-007/C-008 | T-005, T-006 | docs + old-name scan | Planned |
| C-009 | T-005, T-006 | macOS build/install + preflight checks | Planned |

## Design Feedback Loop Notes (From Review/Implementation)
| Date | Trigger (Review/File/Test/Blocker) | Classification (`Local Fix`/`Design Impact`/`Requirement Gap`) | Design Smell | Requirements Updated? | Design Update Applied | Status |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-02-18 | Initial design | N/A | N/A | No | Yes (v1) | Open for review |

## Open Questions
- None for naming scope; full macOS artifact rename is included in this ticket.
