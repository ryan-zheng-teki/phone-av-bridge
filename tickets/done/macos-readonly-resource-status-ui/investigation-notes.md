# Investigation Notes

## Sources Consulted
- `/Users/normy/autobyteus_org/phone-resource-companion/macos-camera-extension/samplecamera/ViewController.swift`
- `/Users/normy/autobyteus_org/phone-resource-companion/README.md`

## Current Behavior
- Resource section uses non-interactive checkboxes (`Camera`, `Microphone`, `Speaker`) to show state.
- Checkboxes are disabled, but visually still imply control affordance.
- Global resource state badge is already present (`Not Paired`, `Resource Active`, etc.).
- Host status path is read-only (`GET /api/status`) and no macOS `/api/toggles` mutation path remains.

## User Requirement Interpretation
- Replace checkbox affordance with pure status display.
- Keep two improvements only:
  1. status rows for each resource,
  2. non-interactive state chips/badges.
- Do not add extra explanatory note line.
- Do not add last-updated metadata.

## Constraints
- Preserve existing read-only control model and host polling logic.
- Keep current host card layout and refresh action.
- No backward compatibility branch for old checkbox UI.

## Scope Signal
- Predominantly single-file macOS UI refactor with no API changes.
- Classified as Small scope.
