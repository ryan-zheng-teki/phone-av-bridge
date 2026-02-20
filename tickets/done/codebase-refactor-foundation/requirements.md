# Requirements

- Ticket: `codebase-refactor-foundation`
- Date: 2026-02-20
- Status: `Design-ready`

## Requirement Maturity Log

- Initial snapshot (`Draft`) captured from user request: create a dedicated refactor ticket, run deep whole-codebase investigation, and drive refactoring via software-engineering workflow artifacts.
- Current status (`Design-ready`) reached after investigation in `investigation-notes.md`.

## Goal / Problem Statement

Refactor the Phone AV Bridge codebase to reduce oversized, multi-responsibility controller files and improve separation of concerns across macOS app, Android app, and host server, while preserving current behavior and release flow.

## Scope Classification

- Classification: `Large`
- Rationale:
  1. Cross-platform impact (`macOS`, `Android`, `desktop host server`).
  2. Multi-layer boundary changes (UI/controller, network/client, runtime orchestration, route handling).
  3. Requires coordinated rename/move/remove tasks with strong regression controls.

## In-Scope Use Cases

- UC-001: macOS app runtime parity after decomposition of `ViewController.swift` responsibilities.
- UC-002: Android pairing/runtime parity after decomposition of `MainActivity.kt` responsibilities.
- UC-003: Host API/runtime parity after decomposition of `server.mjs` responsibilities.
- UC-004: Refactor safety and release readiness (tests, docs, tag-based release behavior unchanged).

## Acceptance Criteria

1. No user-visible regression in pair/unpair/QR pairing/resource toggles on supported platforms.
2. `ViewController.swift` is decomposed so networking/QR/status/domain parsing are extracted from UI orchestration.
3. `MainActivity.kt` is decomposed so pairing orchestration and host sync logic are extracted from direct UI event wiring.
4. `desktop-app/server.mjs` is decomposed into route handlers + service modules with unchanged API contracts.
5. Legacy/duplicate compatibility paths introduced by refactor are not retained.
6. Existing automated checks pass (`desktop host tests`, `android unit/build`, `macOS build`) and release workflow remains tag-triggered.

## Constraints / Dependencies

1. Must preserve current endpoint contracts used by Android/macOS (`/api/status`, `/api/bootstrap`, `/api/bootstrap/qr-token`, `/api/bootstrap/qr-redeem`, `/api/pair`, `/api/unpair`, `/api/toggles`).
2. Must keep current release workflow at `/Users/normy/autobyteus_org/phone-av-bridge/.github/workflows/release.yml`.
3. Refactor should be incremental and commit-safe; no large one-shot rewrite.
4. No backward compatibility policy: remove obsolete paths rather than keeping wrappers.

## Assumptions

1. Functional behavior shipped in `v0.1.7` is baseline-correct and should remain intact.
2. Current ticket focuses on architecture refactor; product UI redesign is tracked separately.
3. Developers accept new module boundaries and file moves when accompanied by traceable tests.

## Open Questions / Risks

1. Android decomposition target pattern (lightweight controller/services vs full architecture shift) must balance speed and risk.
2. macOS UI + runtime extraction may require careful ownership mapping for IBOutlet-like references and timers.
3. Host server split may temporarily increase file count and requires strict import boundary discipline.
4. Real-device E2E remains partially environment-constrained; must document infeasibility where applicable.
