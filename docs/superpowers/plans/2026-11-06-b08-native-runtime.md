# B-08 LiteRT-LM Android/Flutter implementation plan

> Execute inline with superpowers:executing-plans and TDD. The owner's complete execution specification delegates compatibility-path selection and authorizes implementation, builds, CI, commits, push and a stacked PR. Final independent Standards/Spec review is required; no merge.

**Goal:** Link the real LiteRT-LM0.19.0 runtime into SIRAJ, expose typed Flutter operations, prove Android builds/JNI and licensed model execution where possible, and keep educational answers closed until grounded acceptance gates pass.

**Architecture:** Preserve existing download, validation, repository and Auth boundaries. Compare direct Kotlin consumption against a Java-only Android library facade whose public API contains no LiteRT/Kotlin types; choose using compiler, D8/R8, APK and JNI evidence. A worker-owned manager and native resource resolver sit behind versioned Method/Event channels. Flutter uses an independent client and application coordinator, never a direct ChatPage-to-LLM call.

**Tech stack:** Flutter3.38.5/Dart3.10.4; current AGP8.11.1/Gradle8.14/KGP2.2.20 unless a measured compatibility requirement demands the smallest change. JDK21 for Java-major65 inspection/compilation. Real LiteRT-LM0.19.0 only.

**Spec:** `docs/spec/B08_NATIVE_RUNTIME_USER_REQUEST_2026-11-06_AR.md` (all18 sections).

## Global constraints

- Repository siraj-codex only. PR3 is open at208511419bea03600793a24125795fcf3780b1bc; B08 branch `codex/b08-litertlm-android-runtime-01` starts there and targets `codex/b07-independent-download-01`.
- No merge/branch deletion/main changes; no siraj-p0 or owner computer. Baseline187 Flutter tests and30 Python tests pass; analyze/pinned pub pass.
- No metadata bypass/editing, disabling D8/R8 or alternative runtime. Compare Maven AAR to owner SHA before acceptance; audit actual POM/graph, licenses and APK.
- No model/AAR/ZIP in Git; models only in app-private debug/test fixture storage until a production resource authority exists. No arbitrary absolute path/channel override, production staging URLs or automatic resource readiness.
- No Auth/PBKDF2/Keystore/DB migration/new tables/Quiz work or UI redesign. Reuse DownloadService unchanged.
- Weights licensing is checked before inference. No invented pooling/normalization/prefix, IDs, retrieval policy, metrics or scientific acceptance. Missing scientific authority blocks G2/G3 and production grounded Chat, not independent native/Flutter work.

## Review focus

- Stale native callbacks after cancel/close must never complete a different request or persist an answer.
- Paths/symlinks/changed hashes cannot bypass native trusted-resource resolution, including in debug.
- Method completion and EventChannel terminal events must be exactly once, with recovery after failure.
- Session expiry/delete between generation and persistence must block the write without altering Auth.
- JNI/build success, raw model inference, embedding parity and grounded G2/G3 need separate evidence.

## Task1: Compatibility and dependency gate

Files: `tool/ai_runtime/`, `.github/workflows/b08-runtime-verification.yml`, small evidence under `docs/qa/b08-runtime/`; Android Gradle files only after selecting a proven route.

- [ ] Run actual Kotlin2.2.20 negative control and a compatible official compiler probe; run Java21-to17 facade and Kotlin-consumer probes without AAR metadata on the consumer boundary.
- [ ] Fetch actual Maven0.19.0 POM/AAR in authorized CI, verify size/SHA/version, resolve and record dependency graph; examine model-license provenance separately from build licensing.
- [ ] Compare direct-Kotlin and Java module paths; integrate the smallest route with real Debug/Release (R8 enabled), dependency and APK/JNI checks.

## Task2: Native runtime vertical slice

Files: `android/ai_runtime/` Java-only module if pathB passes; existing MainActivity plus focused channel/registry classes in the app module; native unit/instrumented tests.

- [ ] Write failing lifecycle/concurrency/cancellation/resource-path/error tests before the manager implementation.
- [ ] Implement real backend initialization, Message/Content.Text extraction, callback streaming, embedding output validation and close/reload on background executors. Public facade API uses plain Java DTOs only.
- [ ] Production resolver remains closed without approved resources; isolated debug registry accepts only owner-pinned app-private model identities, revalidating actual bytes without exposing paths through Flutter.
- [ ] Register versioned methods/events and dispose safely alongside existing secure-session/storage channels; protect request IDs, terminal ownership and listener cleanup.

## Task3: Flutter client and specialized format validation

Files: `lib/features/ai_runtime/`, `lib/features/resources/litertlm_*`, existing ResourceDownloadValidator, focused Dart tests.

- [ ] RED/GREEN typed client cases for native absence, channel errors, malformed/stale events, cancel/close and finite/nonzero dimension validation; no Widgets or arbitrary model paths in the client.
- [ ] RED/GREEN bounded official-container parser cases: malformed/truncated header, bad table/section bounds/overlap/alignment/types and changed files. Keep GGUF behavior and readiness requirements intact.
- [ ] Wire specialized LiteRT-LM evidence into existing validation without turning static structure into runtime/model-load proof or readiness.

## Task4: Existing Chat/persistence integration, fail-closed grounding

Files: existing ConversationRepository and draft/controller/Page; focused tutor/application contracts and tests only as needed by this base.

- [ ] Preserve first-message transaction/max10/stable ordering; add idempotent follow-up persistence and guarded assistant writes on existing tables.
- [ ] Test session invalidation/delete/stale result/retry/failed Tutor and source authority before wiring the application coordinator into existing Chat.
- [ ] Keep native generation behind retrieval/evidence/citation authority; absent approved mapping/parity is typed unavailability, never an ungrounded educational response or a fake release result.

## Task5: Real Android/model tests and CI artifacts

Files: `integration_test/b08_*`, native instrumentation, `tool/ai_runtime/` inspection/metrics helpers, the independent B08 workflow.

- [ ] Build Flutter/Gradle Debug and Release from the real app; inspect actual APK classes, native ELF ABI and SHA256; upload APKs as CI artifacts only.
- [ ] Run real x86_64 emulator JNI and licensed model load/generation/embedding/cancel/dispose/reload/offline tests where resources permit; record real timings/PSS/vector measurements, never estimates.
- [ ] Separate G2/G3 BLOCKED mapping/science/parity from raw runtime execution. No Samsung/arm64 physical-device claim without execution.
- [ ] Full locked Flutter/Python/native regression, format/analyze, and APK/dependency checks. Preserve exact network/HTTP failures.

## Task6: Review and delivery

- [ ] Independent Standards and Spec review of the pinned B08-only diff; fix substantive findings with failing regressions then green suites.
- [ ] Complete all24 sections of `docs/reports/B-08_LITERT_LM_ANDROID_RUNTIME_INTEGRATION_01_AR.md`, commands/evidence/tool versions/APK SHAs/limits and per-gate status.
- [ ] Commit/push small slices; new PR targets B07 while PR3 stays open. Verify base/head/CI and report remaining blockers without declaring unproven acceptance.
