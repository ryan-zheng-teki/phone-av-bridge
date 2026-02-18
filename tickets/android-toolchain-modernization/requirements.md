# Requirements: Android Toolchain Modernization

## Status
- `Design-ready`

## Goal / Problem Statement
Modernize Android build tooling from stale versions to a newer stable baseline while keeping the project buildable and reducing future maintenance friction.

## Scope Triage
- Classification: `Small`
- Rationale: limited file changes (root plugin versions + wrapper), no runtime feature behavior changes.

## In-Scope Use Cases
1. `UC-UPGRADE-01`: developer runs Gradle build on modern JDK without tooling incompatibility.
2. `UC-UPGRADE-02`: project uses a modern AGP/Gradle/Kotlin plugin baseline.

## Acceptance Criteria
1. `build.gradle.kts` uses upgraded AGP/Kotlin plugin versions.
2. `gradle-wrapper.properties` uses upgraded Gradle wrapper version.
3. `:app:assembleDebug` succeeds with JDK 21.
4. No legacy compatibility wrappers introduced.

## Constraints / Dependencies
- Must respect AGP/Gradle compatibility.
- JDK 21 should be supported for local development.

## Assumptions
- Existing Android code compiles with newer Kotlin/AGP without refactor.

## Open Questions / Risks
- AGP 9.x + Gradle 9.x migration deferred to dedicated future ticket to limit risk.
