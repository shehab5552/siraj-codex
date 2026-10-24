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
