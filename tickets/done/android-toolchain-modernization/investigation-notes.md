# Investigation Notes: Android Toolchain Modernization

## Sources Consulted
- `/Users/normy/autobyteus_org/phone-resource-companion/android-resource-companion/build.gradle.kts`
- `/Users/normy/autobyteus_org/phone-resource-companion/android-resource-companion/gradle/wrapper/gradle-wrapper.properties`
- `/Users/normy/autobyteus_org/phone-resource-companion/android-resource-companion/gradle.properties`
- Local build verification commands and outputs with JDK 21.

## Key Findings
1. Project was pinned to older Android tooling:
   - AGP `8.5.2`
   - Kotlin Android plugin `1.9.24`
   - Gradle wrapper `8.7`
2. Older pinning was not a runtime bug; it was simply a stale version baseline.
3. Android toolchain upgrades must honor AGP/Gradle compatibility and cannot blindly jump to latest Gradle core.
4. JDK 21 is available locally and works for this project.

## Constraints
- Keep project buildable immediately after upgrade.
- Avoid introducing migration complexity that blocks active development.
- Prefer modern stable AGP 8.x line first; AGP 9.x can be a separate migration.

## Unknowns
- None blocking for AGP 8.x upgrade path.

## Implications
- Safe modernization path: upgrade AGP + Kotlin plugin + wrapper to newer compatible versions and verify build with JDK 21.
