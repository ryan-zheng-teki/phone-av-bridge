# Requirements

- Ticket: `macos-camera-ui-polish-follow-up`
- Date: 2026-02-20
- Status: `In Progress`

## Background
The QR pairing functionality is accepted and works end-to-end. The macOS camera app visual design and responsive layout need product-level polish, especially at common laptop viewport sizes.

## Goals

1. Improve overall visual quality of the macOS camera app to feel production-grade.
2. Ensure primary actions and QR section remain visible and usable without overflow at common window sizes.
3. Introduce consistent spacing, typography hierarchy, and component styling tokens.
4. Preserve all current functional behavior (pairing, status, extension controls, logs).

## Non-Goals

- No changes to pairing protocol or backend API semantics.
- No changes to Android or Linux host behavior.

## Acceptance Criteria

1. At default app window size, all primary sections are visible without clipping critical controls.
2. QR pairing panel remains legible and scannable while preserving status context.
3. UI components have consistent visual language (buttons, badges, cards, chips).
4. Existing functional test/validation for pairing still passes after UI-only changes.
