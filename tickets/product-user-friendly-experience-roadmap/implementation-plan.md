# Implementation Plan: Rotation UX Hardening (Phase 1)

## Scope Classification
- Classification: Small
- Reasoning: Android camera orientation controls + host status reflection only.
- Workflow Depth: Small

## Upstream Artifacts (Required)
- Requirements: `tickets/product-user-friendly-experience-roadmap/requirements.md`
- Proposed design: `tickets/product-user-friendly-experience-roadmap/proposed-design.md`

## Plan Maturity
- Current Status: Ready For Implementation

## Dependency And Sequencing Map
| Order | File/Module | Depends On | Why This Order |
| --- | --- | --- | --- |
| 1 | `android-resource-companion/.../CameraController*` | none | orientation behavior first |
| 2 | `android-resource-companion/.../MainActivity.kt` + layout/strings | 1 | expose controls to user |
| 3 | `host-resource-agent/.../session-controller*` + API serializer | 1 | publish lens/orientation in status |
| 4 | `macos-camera-extension/samplecamera/ViewController.swift` | 3 | show read-only lens/orientation state |

## Step-By-Step Plan
1. T1: Add Android orientation mode model (`Auto`, `Portrait Lock`, `Landscape Lock`) and apply to camera pipeline.
2. T2: Add Android UI controls for orientation mode and lens selection (front/back).
3. T3: Extend host status payload to include current lens + orientation mode.
4. T4: Update macOS host UI to show read-only lens + orientation fields.
5. T5: Validate behavior with real phone + Zoom smoke test.

## Test Strategy
- Build checks:
  - Android: `./gradlew :app:assembleDebug`
  - macOS: `xcodebuild -project samplecamera.xcodeproj -scheme samplecamera -configuration Debug build`
- Manual checks:
  - Back lens + Auto mode in Zoom.
  - Front lens + Auto mode in Zoom.
  - Portrait Lock + phone rotated physically.
  - Landscape Lock + phone rotated physically.
  - macOS host status reflects phone lens/orientation within 2 seconds.
