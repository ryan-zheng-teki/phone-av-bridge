# Requirements - Host List Persistent Switching UX

## Status

- `Design-ready`

## Goal / Problem Statement

Improve Android pairing UX so users can always see all discoverable hosts and can switch between hosts directly from the main screen while paired, without losing transparency of available devices.

## In-Scope Use Cases

- UC-001: Unpaired user sees full discovered host list on main screen.
- UC-002: Paired user still sees discovered host list (including current host and alternates).
- UC-003: Paired user selects another host and switches in one explicit action (auto-unpair previous host, then pair selected host).
- UC-004: Switch failure is handled cleanly with clear status and retry path.
- UC-005: Current paired host remains visible in host list even if a discovery cycle temporarily misses it.

## Acceptance Criteria

1. Main screen shows host list before and after pairing.
2. Paired state does not hide alternate hosts.
3. Host list includes a clear selected row; selected host drives action behavior.
4. Selecting a different host while paired enables switch flow.
5. Switch flow unpairs prior host and pairs selected host without requiring manual unpair first.
6. On switch failure, app remains stable and user sees actionable error/status.
7. Existing QR pairing path remains available.
8. Discovery refresh runs while paired so alternate hosts stay visible/updated.
9. If multiple hosts are present, user must explicitly select target host before pairing/switching.
10. Action labels are concise and stateful (`Pair`, `Switch`, `Unpair`) based on current selection vs current connection.

## Constraints / Dependencies

- Android app architecture under `android-phone-av-bridge`.
- Existing host discovery and pair/unpair APIs.
- No backward-compat/legacy parallel flow retention.
- Keep current resource-toggle behavior unchanged (camera/mic/speaker controls).

## Assumptions

- Multiple hosts can be simultaneously discoverable on LAN.
- Users understand host selection via list rows when clearly labeled.
- Host switch can be performed by sequential `unpair(current)` then `pair(target)` without transactional rollback requirement.

## Open Questions / Risks

- Risk: selected target host may disappear between selection and switch attempt.
  - Mitigation expectation: graceful failure message, keep UI stable with refreshed host list.
- Risk: periodic discovery refresh may override user selection.
  - Mitigation expectation: preserve explicit user selection while selected host remains in candidate list.

## Scope Triage (Preliminary)

- Final classification: `Medium`.
- Rationale: multi-state UX behavior changes (paired + unpaired + switching), runtime orchestration changes across discovery/pair/unpair flows, and planned responsibility refinement for host-selection concerns without full architectural rewrite.

## Out Of Scope

- Replacing UDP discovery protocol.
- Redesigning full visual theme/branding.
- Adding cross-host bulk management features.
