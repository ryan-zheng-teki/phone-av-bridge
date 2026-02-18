# Proposed Design: Rotation UX Hardening (Phase 1)

## Design Version
- Current Version: v3

## Revision History
| Version | Trigger | Summary Of Changes |
| --- | --- | --- |
| v1 | Initial draft | Broad product UX roadmap |
| v2 | Review update | Clarified state model and remediation |
| v3 | Scope reduction | Narrowed to camera rotation usability only |

## Summary
Implement explicit orientation behavior on Android and reflect that state on macOS host UI.

## Goals
- Remove confusion about portrait/landscape behavior in Zoom/Meet.
- Let user pick orientation mode directly on phone.
- Keep Android as controller and macOS as read-only status surface.

## Requirements Mapping
| Requirement | Design Response |
| --- | --- |
| R-001 default orientation works | Auto mode applies sensor + display rotation mapping |
| R-002 orientation controls | Add `Auto`, `Portrait Lock`, `Landscape Lock` controls |
| R-003 lens switch correctness | Recompute output rotation on lens changes |
| R-004 host visibility | Surface `lens` + `orientationMode` in host status card |
| R-005 sync timing | Reuse existing status poll + immediate refresh after setting change |

## Architecture
- Android camera pipeline computes target rotation from selected mode.
- Android status payload includes:
  - `cameraEnabled`
  - `cameraLens` (`back`/`front`)
  - `cameraOrientationMode` (`auto`/`portrait_lock`/`landscape_lock`)
- Host API forwards this payload.
- macOS app renders read-only labels/chips for lens and orientation mode.

## UI Changes
- Android:
  - Keep camera toggle.
  - Add lens selector (`Back` / `Front`).
  - Add orientation selector (`Auto` / `Portrait Lock` / `Landscape Lock`).
- macOS:
  - In paired device panel, show `Camera Lens` and `Orientation` values.
  - No control widgets for these values on macOS.

## Error Handling
- If orientation mode cannot be applied, fallback to `Auto` and show issue text in phone status.
- If host has stale orientation data, show `syncing` hint until next successful status pull.

## Out Of Scope
- Full onboarding redesign.
- Packaging workflow changes.
- Mic/speaker behavior redesign.
