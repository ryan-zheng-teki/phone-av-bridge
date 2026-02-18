# Requirements

## Status
Design-ready

## Goal / Problem Statement
When Linux microphone and speaker are both enabled, speaker capture must avoid bridge-owned microphone sources by default so users do not hear microphone self-loopback through phone speaker playback.

## Scope Classification
Small

## Scope Rationale
- Localized to Linux speaker source selection in one adapter.
- Requires unit-test expansion and documentation sync, but no architectural split.

## In-Scope Use Cases
- UC-1: Speaker route chooses host output monitor when microphone route is active.
- UC-2: Explicit override `LINUX_SPEAKER_CAPTURE_SOURCE` still forces selected source.
- UC-3: If only bridge microphone sources exist, speaker route reports no suitable source.

## Acceptance Criteria
- Source resolver excludes current bridge microphone source names and known bridge mic naming prefixes.
- Source resolver prefers safe monitor candidates and avoids selecting microphone route sink/source.
- Override behavior remains unchanged when env var is provided.
- Unit tests cover:
  - safe default monitor selection,
  - exclusion when default sink points to bridge mic sink,
  - null result when only bridge mic sources are available.
- Linux docs explain default exclusion logic and override path.

## Constraints / Dependencies
- Linux path only (`desktop-av-bridge-host/adapters/linux-audio/audio-runner.mjs`).
- Pulse/PipeWire source discovery via `pactl` output parsing.

## Assumptions
- Bridge mic sink/source naming remains under `phone_av_bridge_mic_*` conventions.
- App-level sidetone/monitoring can still cause loopback independently.

## Open Questions / Risks
- Nonstandard naming environments may need manual override.
