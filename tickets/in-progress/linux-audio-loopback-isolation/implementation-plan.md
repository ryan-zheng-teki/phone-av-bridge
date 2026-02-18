# Implementation Plan

## Status
Finalized

## Preconditions
- Requirements: Design-ready
- Runtime call stack review: Go Confirmed
- Scope: Small

## Execution Steps
1. Refactor Linux speaker source selection into pure helper logic with explicit exclusion rules.
2. Integrate helper into `#resolveSpeakerSourceName` while preserving env override behavior.
3. Add/extend unit tests for source selection.
4. Run host unit+integration tests (`npm test`).
5. Update Linux docs to reflect isolation behavior.
6. Update implementation progress with verification evidence.

## Verification Strategy
- Unit tests: source-selection helper behavior (safe monitor, exclusion, null fallback).
- Integration baseline: full `desktop-av-bridge-host` test suite (`npm test`).
- E2E feasibility: partial/manual for real audio topology; automated E2E not deterministic for desktop audio graph on CI runner.

## Requirement Traceability
| Requirement | Design/Call Stack | Implementation |
| --- | --- | --- |
| Exclude bridge mic sources | UC-1/UC-3 | helper + resolver filtering |
| Preserve override | UC-2 | early return path for env override |
| Unit coverage | UC-1/2/3 | `tests/unit/linux-audio-runner.test.mjs` |
| Docs guidance | UC-1/UC-2 | `desktop-av-bridge-host/README.md` |
