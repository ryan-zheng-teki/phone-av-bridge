# Requirements

## Status
Design-ready

## Goal / Problem Statement
Improve pre-pair UX so users can see what they are pairing to (host on Android, phone on macOS) before pairing completes.

## Scope Triage
- Size: Small
- Rationale: focused behavior additions in existing Android + host status paths with minimal surface changes.

## In-Scope Use Cases
- UC-1: Android unpaired screen shows a discovered host candidate when available.
- UC-2: Android unpaired screen still allows pairing even if host preview is temporarily unavailable.
- UC-3: macOS host app shows detected phone identity even while host state is not paired.

## Acceptance Criteria
1. Android unpaired host line shows discovered host URL when discovery succeeds.
2. Android periodically refreshes host preview while unpaired and not currently pairing.
3. Android publishes phone presence to host when a host is discovered pre-pair.
4. Host `/api/status` can contain phone identity while `paired=false`.
5. macOS UI reflects that phone identity through existing status polling.
6. Host unit/integration tests and Android build pass.

## Constraints / Dependencies
- Keep Android as primary controller for resource toggles.
- No legacy/backward compatibility branch retention.
- Preserve current pair/toggle APIs.

## Assumptions
- Host discovery remains UDP + bootstrap fallback.
- Pre-pair presence endpoint can be unauthenticated within same-LAN trust model used today.

## Open Questions / Risks
- Phone identity while unpaired is effectively “last seen / nearby”; wording may need UX tuning in future pass.
