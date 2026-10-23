# B-04 Android Verification Implementation Plan

> **For agentic workers:** Execute inline with superpowers:executing-plans. The user has explicitly authorized execution and delivery; no additional plan approval is required.

**Goal:** Verify the existing B-04 repair where tools permit and deliver an executable Arabic Windows/Samsung reproduction guide.

**Architecture:** Keep PR #5 source unchanged. A dependent branch adds a debug-only, separate-entry Android probe, verification workflow and exact per-file reference patches. The probe uses the real AuthService/SQLite/Keystore and never changes AppBootstrap or the production gate.

**Tech Stack:** Flutter 3.38.5, Dart 3.10.4, PBKDF2-HMAC-SHA256 candidate 600000, Android API 33 emulator, JDK 17, GitHub Actions, Windows PowerShell.

**Spec:** User's uploaded B-04 Android Verification request; official P0 DD-05/06/07 and PR #5 at `17ac3cd1d27acd0ae32a24cc09a5aa99b363c126`.

## Global Constraints

- Work only in `shehab5552/siraj-codex`; no original repository/local PC access or PR merges.
- No production Auth gate, work-factor approval or Android success claim without its evidence.
- Android test package must differ from existing application ID; preserve namespace/MainActivity and production data.
- Cloud tests and fake storage do not establish real Keystore or Samsung success.
- Independent branch based on PR #5, PR target its branch so the added diff excludes the repair itself.

## Review Focus

- Test target accidentally installed over user app: isolated package guard and APK identity inspection before install.
- Debug probe accidentally run as production: entry-point debug/Android guard; main application untouched.
- Patches applied to a different architecture: exact base/hashes and manual adaptation prerequisites; no blind Auth/SQLite replacement.
- CI unavailable or token lacks workflow permission: report exact API/push/run failure; never invent a run.
- B-08 compatibility: inspect hypothetical merge-tree conflicts without merging or altering either PR.

## Task 1: Official Android verification path

- [x] Recheck SDK, devices, official SDK URL and GitHub permissions; save actual errors.
- [x] Add bounded GitHub-hosted emulator workflow with pinned official actions, Flutter 3.38.5, package isolation and sanitized artifacts.
- [x] Push and inspect actual workflow result; if unavailable, record the exact limitation and continue unaffected guide work.

## Task 2: Isolated device probe

- [x] Add tests for probe Signup/Login/Logout/Delete and storage failure, using test-only fakes in cloud tests.
- [x] Watch new tests fail before implementing `integration_test/support/b04_probe_app.dart`.
- [x] Implement debug-only probe with separate SQLite name, test Keystore scope, existing pages, cancellation and safe telemetry.
- [x] Add Android KDF metric test and run cloud tests/analyzer. Native tests only if Android available.

## Task 3: Local reproduction package

- [x] Generate immutable per-file patches from exact PR #5 base to code SHA, with SHA-256 manifest and full contents for new standalone files.
- [x] Write `docs/guides/B04_LOCAL_WINDOWS_REPRODUCTION_GUIDE_AR.md`: backup, clean experimental branch, per-file table, before/after excerpts, dependency order, manual adaptation, PowerShell/SDK/APK/package isolation, Samsung matrix and sanitized diagnostics.
- [x] Include genuine three-file B-08 conflict findings without claiming compatibility passes.

## Task 4: Verification and delivery

- [x] Run enforced pub get, analyze and full/focused tests, validate patch round-trip and hashes, inspect scope.
- [x] Independent review of probe/workflow/guide; fix substantive findings and verify.
- [x] Commit/push and independent dependent PR; preserve PR #3/#4/#5, report actual commits/run URLs and remaining device gates.

## Recorded outcome (23 October 2026, Asia/Aden)

- Local cloud SDK download blocked at proxy CONNECT403; GitHub official SDK path succeeded.
- Final Actions run39878012411 passed: APK/Kotlin, API33 emulator, 3 actual Android tests and bounded ANR event-buffer observation.
- Linux full suite170/0/0 and focused70/0/0; focused suite is a subset.
- Exact32-file patch round-trip verified; reference source hashes and document links verified.
- PR6 is stacked on PR5; production source from PR5 is unchanged. No PR was merged.
- Physical Samsung/Windows commands, force-stop/reboot, OEM backup/key-loss/lifecycle and combined B04/B08 tests remain unverified. Gate stays CLOSED.
- Native UI/cascade coverage was added after the initial2-test Android success. An intermediate post-test observer PATH failure was corrected and rerun successfully; see detailed report rather than treating that entire failed job as a pass.
