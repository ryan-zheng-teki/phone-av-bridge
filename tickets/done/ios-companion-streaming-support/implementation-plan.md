# Implementation Plan

- Ticket: `ios-companion-streaming-support`
- Date: 2026-02-23
- Iteration: `6` (remove QR manual fallback UI)

## Scope Classification

- Classification: `Medium` (ticket-level)
- Iteration reasoning: contained UI/doc cleanup to enforce Android parity, while preserving delivered QR parse/redeem/pair runtime.

## Upstream Artifacts

- Investigation notes: `tickets/in-progress/ios-companion-streaming-support/investigation-notes.md`
- Requirements: `tickets/in-progress/ios-companion-streaming-support/requirements.md` (`Refined`)
- Proposed design: `tickets/in-progress/ios-companion-streaming-support/proposed-design.md` (`v6`)
- Runtime call stacks: `tickets/in-progress/ios-companion-streaming-support/future-state-runtime-call-stack.md` (`v6`)
- Runtime review: `tickets/in-progress/ios-companion-streaming-support/future-state-runtime-call-stack-review.md` (`Go Confirmed`, round 10)

## Plan Maturity

- Current Status: `Ready For Implementation`
- Runtime review gate: `Go` (`Go Confirmed`, clean streak = 2)

## Dependency And Sequencing Map

| Order | File/Module | Depends On | Why This Order |
| --- | --- | --- | --- |
| 1 | `QrScannerSheet.swift` | N/A | Remove fallback controls first; keep scan callback path untouched. |
| 2 | `ios-phone-av-bridge-app/README.md` | 1 | Keep docs consistent with actual shipped behavior. |
| 3 | verification commands | 1-2 | Ensure no regressions in package tests and app simulator E2E. |
| 4 | ticket artifacts | 1-3 | Record implementation and verification evidence. |

## Requirement And Design Traceability

| Requirement | Design Section | Use Case / Call Stack | Planned Task ID(s) | Verification |
| --- | --- | --- | --- | --- |
| R-011 | C-049 | UC-011 | T-601 | app UI + simulator launch checks |
| R-012 | C-049 | UC-012 | T-601,T-603 | `swift test` |
| R-013 | C-049 | UC-013 | T-601,T-603 | `swift test` |
| R-014 | C-049 | UC-014 | T-601,T-603 | app UI test path |
| R-015 | C-049,C-050 | UC-015 | T-601,T-602,T-603 | source inspection + tests |

## Step-By-Step Plan

1. T-601: Remove manual QR payload fallback UI and submit action from `QrScannerSheet`.
2. T-602: Remove simulator fallback wording from iOS app README.
3. T-603: Run verification (`swift test`, app simulator E2E) and update progress artifacts.

## Test Strategy

- Package unit tests:
  - `cd /Users/normy/autobyteus_org/phone-av-bridge/ios-phone-av-bridge && swift test`
- App-level simulator E2E:
  - `cd /Users/normy/autobyteus_org/phone-av-bridge && bash ios-phone-av-bridge-app/scripts/run_ios_app_sim_e2e.sh`

## Test Feedback Escalation Policy

- Classify failures as `Local Fix`, `Design Impact`, `Requirement Gap`.
- If scan-flow code changes break parser/redeem/pair behavior, re-enter design + call-stack review before further implementation.
