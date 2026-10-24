# Unified SIRAJ V2 execution ledger

Authority: user FINAL UNIFIED FLUTTER APPLICATION request, corrected P0 v1.0.1 and revised Team B plan. Visual package is a reference, not authority for sample science, subjects or account policy.

## Verified baseline (client date 2026-10-25, Asia/Aden)

- Work only in shehab5552/siraj-codex, existing PR #12 branch codex/unified-siraj-v2-integration-20261024.
- origin/main 651af0d62d05761c80d9a8cbc9d1f51b836929eb; integration ca17aed5b31344cc9f90874e2abd05ee0b504c55. PR remains OPEN/DRAFT.
- Existing feature trees are already present; Shared Embedding source matches PR #10. Do not cherry-pick stacked branches again.
- Enforced pub get and analyze passed. Unified baseline test machine output ended success=true; exact visible test count is recorded below after parsing.
- Current build targets main_v2_preview.dart, not main.dart. Release currently uses debug signing: must be replaced with explicit safe signing inputs.
- AuthService/Keystore/CAS are real; PasswordHasher currently uses Dart isolate PBKDF2. The cryptography_flutter native PBKDF2 implementation runs on its platform handler and lacks our cancellation ownership boundary. Add a narrow bounded native worker behind the existing KDF contract, not a second AuthService.
- No verified Samsung evidence or approved release KDF benchmark is available. Debug integration may exercise the strong 600000-iteration candidate; release approval must remain explicit and cannot be inferred from emulator or Linux.
- No approved model, Embedding/index/catalog/biology bundle/PDF books or scientific quiz policy were found. Keep these paths fail-closed, without manufactured catalog or sources.

## Execution order and completion evidence

1. Native KDF adapter and secure composition: RED tests for bounded dispatch, cancel/drain, malformed output and native vectors; implement background Android channel preserving AuthService, Keystore, nonce and session guards. Separate debug evaluation profile from release approval.
2. Device preferences + locales + semantic V2 system + onboarding: persist only language/theme/onboarding in app-private storage, no secrets; serialized writes and truthful errors; restore session independently of onboarding.
3. Unified account/settings/navigation/home: wire real account service, revoke routes and work on logout/delete; preserve shared resources and 10-conversation policy. Four actual destinations and current selection. Reuse Chat/Quiz controllers.
4. Complete localized Chat/History/Quiz/Library/Resources UI: trusted catalog and service limits only; RAM quiz review/navigation, no Question Bank and no fake questions. Central typed error presentation.
5. Safe download-to-atomic integration: reuse B07/B12 with exclusive validated completed-artifact handoff, exact provenance and immutable activation. No active-path deletion or false readiness.
6. Portable packaging/CI: Windows VS Code docs, licensed assets, isolated debug application ID, main.dart APK, source archive, SHA256 and safe release signing. Run unified pub/analyze/tests, UI scenarios/goldens and actual Android emulator where available.
7. Independent specification/security/integration review; fix verified significant issues, push checkpoints and update PR12. Merge only if the applicable acceptance gates truly pass. Otherwise leave open and record precise blockers.

## Shared interface checks

- 1 -> 3: PasswordHasher accepts a KDF worker port; existing IsolatePbkdf2 tests remain valid; no AuthService bypass.
- 2 -> 3/4: app-scoped appearance preferences are not account/session authorization; account-owned data stays guarded SQLite.
- 3 -> 4: revoked sessions dispose mounted feature controllers and their routes, guards still reject late persistence.
- 5 -> 4: UI consumes real progress/errors; only DatasetReleaseManager may promote and commit the pointer.
- 6 -> 7: successful APK compilation is not feature or G2/G3 acceptance.

## Progress

Inspection complete; implementation pending. Raw baseline evidence is retained in /tmp/siraj-unified-20261024 in this cloud environment; portable summaries will be committed, never runtime dependencies on that path.

Baseline visible test results: {'success': 485}.

Checkpoint 1: native KDF worker port/Android background channel, serialized appearance store and real AuthService composition controller implemented. New tests were run to missing-feature failure before implementation. Focused KDF 22/22, preferences 3/3, session/race/recovery 12/12 passed. Full unified host regression after these changes: 494 passed, 0 failed, 0 skipped; analyze clean after seven mechanical lint fixes. Native Android execution and Gradle changes are queued for CI, not claimed verified. UI task tests remain uncommitted until implemented.

Checkpoint 2 implementation: central semantic V2 themes and licensed bundled Noto Sans Arabic; persisted Arabic/English, Light/Dark/System and four-step onboarding; normal debug main uses real NativePbkdf2+AuthService+Keystore; release still requires an approved KDF profile. One session-scoped private Navigator, real logout/delete confirmations, real history/latest-conversation wiring and four retained tab destinations. Existing chat/history/auth/quiz/resource UI labels localized without translating student content or evidence. Library truthfully reports the missing approved catalog. Windows/VS Code and safe unsigned/release-signing instructions added.

Verification: initial unified run 500 passed/1 failed (Home Quiz action had moved below lazy viewport; test updated to scroll before exercising the unchanged callback). Corrected full run 501 passed/0 failed/0 skipped, analyze clean. Security regression proved a raw nonce appeared in a Navigator diagnostic key; replaced with an opaque controller-owned identity that stays stable when restoring the same session. Focused logout/delete/nested-resource/stable-restore tests pass after this fix; final checkpoint regression is recorded by its CI/host logs.

CI checkpoint 1: Debug main.dart APK and source archive were built (artifact exists); subsequent Release compile failed with `package dev.flutter.plugins.integration_test does not exist`. Root cause verified in Flutter 3.38.5 runner/flutter_command.dart: --no-pub skips build-mode plugin registrant regeneration; Gradle excludes the dev dependency in Release. Release command now regenerates normally and verifies lockfile unchanged. No test was removed and no generated registrant edited. Full CI logs download was denied HTTP 403 at results-receiver.actions.githubusercontent.com; diagnostic annotations were read through the allowed api.github.com. Do not report native Android tests passed: that job did not reach them.

Checkpoint 3: Quiz now separates answer drafts, navigation, review and explicit confirmed scoring in RAM. Trusted curriculum port supplies one subject/unit, four supported types and exact service count choices; default catalog stays unavailable. Scope IDs/revision are carried to QuizPort without inventing an A/C wire format. No Question Bank selector or mixed-type option is present. Missing/invalid answers must be corrected before final grading; they are never silently scored wrong or converted to Undetermined. Old synthetic widget sessions are started through their existing controller fixture, while a separate new widget test exercises the actual trusted selection/review/confirmation UI. Existing grading, source race and session-expiry assertions remain.

Additional safety: question-bound input callbacks reject late events from a prior question; submission confirmation is bound to the current RAM session identity. Independent source and revision protections remain unchanged. New catalog/review unit tests and full UI flow pass; unified regression pending this checkpoint.

CI checkpoint 2: both Debug main and unsigned Release builds passed after the plugin-regeneration fix; API33 emulator boot passed. Android integration step failed, with only an exit code exposed by GitHub annotations. Because the log download domain is still denied, the next CI revision emits bounded test failure diagnostics and separate KDF/application steps through supported GitHub check annotations. Native test success is not inferred from the successful builds.
