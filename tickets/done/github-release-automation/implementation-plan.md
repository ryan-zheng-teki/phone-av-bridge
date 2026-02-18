# Implementation Plan

## Objective
Implement a tag-driven GitHub release pipeline that publishes Android APK, macOS app archive, and Linux `.deb` artifacts with checksums.

## Requirement Traceability
| Requirement | Design Section | Use Case | Implementation Tasks | Verification |
|---|---|---|---|---|
| Tag-driven release workflow | Proposed Design: GitHub Workflow | UC-REL-001 | Add `.github/workflows/release.yml` | Workflow lint + dry execution by local command checks |
| Android artifact release | Proposed Design: Android Optional Signing | UC-REL-002 | Add optional CI signing in Gradle + workflow branch logic | Gradle build locally + workflow script validation |
| macOS unsigned archive | Proposed Design: macOS Unsigned Packaging Script | UC-REL-003 | Add `build-unsigned-release.sh` + workflow macOS job | Run script locally and ensure zip output |
| Linux `.deb` package | Proposed Design: Linux `.deb` Packaging Script | UC-REL-004 | Add `build-deb-package.sh` + workflow ubuntu job | Shell syntax checks locally; Ubuntu runner build in workflow |
| Checksums and release publish | Proposed Design: Publish Release job | UC-REL-005 | Add publish job with `SHA256SUMS.txt` | Validate checksum step syntax and release action wiring |

## Task Breakdown
1. Add macOS unsigned build packaging script.
2. Add Linux Debian package build script.
3. Add Android optional CI signing config.
4. Add tag-triggered GitHub release workflow.
5. Update docs (`README.md`, module READMEs) with release usage.
6. Run local validations and report residual runner-only verification.

## Verification Strategy
- Unit-level/syntax checks:
  - `bash -n` on new shell scripts.
  - workflow YAML parse check via structural review and action syntax validation.
- Integration checks (local feasible):
  - run macOS unsigned script and verify output archive exists.
  - run Gradle task to confirm Android build config compiles.
- E2E feasibility:
  - Full tag-triggered GitHub Actions execution is not feasible locally.
  - Best available evidence: local script/build validation + committed workflow ready for tag push.
  - Residual risk: runner environment differences (especially `.deb` build on Ubuntu) until first tagged run.

## Risks / Mitigations
- Risk: Android signing secrets absent.
  - Mitigation: deterministic debug APK fallback and explicit release note text.
- Risk: Debian package script uses tools not present locally.
  - Mitigation: design for Ubuntu runner default tools, add strict failures on missing commands.
- Risk: unsigned macOS app user friction.
  - Mitigation: clearly label artifact as unsigned in filename and docs.
