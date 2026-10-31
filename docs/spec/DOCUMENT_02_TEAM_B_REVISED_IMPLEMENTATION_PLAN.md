# DOCUMENT 02 — TEAM B APPROVED & REVISED IMPLEMENTATION PLAN

**Canonical source:** `SIRAJ P0 — Flutter/Android Implementation Work Plan — Biology Pilot` (full source content appended unchanged at end).  
**Amendments:** explicit owner-approved corrections dated 20–21 October 2026. These are binding **overrides in task ordering and acceptance**, not a rewrite of product requirements.

## Amendment ledger — APPROVED, higher priority than stale original wording

1. **Biology-first:** real Android build uses reviewed Biology data and a strictly isolated fixture for earliest end-to-end proof. This is NOT a demo pretending to be P0 finished.
2. **B-12:** do not require the five complete production subject packs as a Biology pilot prerequisite. Preserve general revision/manifest/compatibility/atomic activation interfaces; exercise those with isolated Biology fixture where meaningful. `RAG_READY` requires the **complete five-pack production set + shared query embedder**, not the fixture.
3. **G2/G3 first:** do not gate early phone testing of a real Local LLM, Query Embedder, compatible index or the first real Biology RAG question on completion of all UI/download flows. Use minimal safely testable integration without allowing fixture to become production.
4. **Parallel execution:** B may build/verify SQLite, auth, UI, download/state contracts, PDF shell and Quiz shell while A works on ModelRuntime and C provides runtime dataset/indexes. Contract freezes are the dependency; no waiting for unrelated UI polish.
5. **Existing Biology extraction:** original Biology PDF, extracted/organized dataset, and Unit 1 review already exist according to team decisions. B/C should assess runtime format gaps and reuse verified extracted content; do not start extraction again.
6. **Status discipline:** a B-x step passing isolated widget or unit tests is not the same as all acceptance criteria for B-x or G2/G3. G2/G3 require actual Android real-runtime evidence.

## Status as of latest available log (2026-10-22)

- Last confirmed pushed `siraj-p0` revision: `main@9b199a4` (user-terminal push output). Original remote cannot currently be fetched by GitHub connector (404).
- Last completely green `flutter test`: **207**; `flutter analyze`: clean. These were before adding the uncommitted B-07 Step 6.
- B-07 Step 6 initial test run: **222 passed, 1 failed**; the updated provenance fix targets **225**, but no execution result after applying fix is available.
- Codex snapshot confirmed: `main@de84bcf`, old 89-test baseline (old test count is from Codex audit, not independently run here).

## B-01..B-13 task-by-task executable implementation matrix

The following operational steps/paths/status observations are **DERIVED implementation tracking**. Authoritative scope remains in the attached original Team B plan and DOCUMENT 01.

### B-01 — Repository / Android Preflight (TK-00)

- **Objective:** Git/Flutter/Android/ADB/ABI baseline; do not recreate project.
- **Dependencies:** none.
- **Affected files / layers:** `repo; android/; pubspec.yaml`; keep UI→controller/service→Repository/Port→SQLite/native direction.
- **Steps & ordering:** Inventory project, toolchain and device; record baseline SHA and local changes; build/run.
- **Contracts:** `Git/Flutter tools; none runtime`. Favor existing interface, no speculative abstraction.
- **Test plan:** flutter doctor -v; flutter devices; adb devices -l; inspect working tree; assert negative cases, restart and regression where applicable.
- **Acceptance:** Inventory + reproducible G0. Any untested physical-device requirement is separately `PENDING TEST`.
- **Deliverables:** G0 evidence, preflight report; stage report, files changed and reviewer evidence.
- **Verified/observed status:** HISTORIC PASS within recorded environment; rerun for Codex separately.
- **Remaining blockers and immediate work:** Codex repo snapshot check, toolchain parity and status.
- **Git/QA protocol:** task branch `codex/b-01-<scope>` in siraj-codex, code+focused tests+markdown report, `dart format`/`flutter analyze`/`flutter test`, device test when needed; planned conventional commit example `chore(B-01): record preflight evidence`. PR after review only.
- **Rollback:** revert the task commit if compatible and no schema migration; for DB/Resource changes use audited migration or immutable old active revision, never delete production data to fake rollback.

### B-02 — Android Startup Foundation (TK-06)

- **Objective:** Minimal app, RTL/startup/navigation/build.
- **Dependencies:** B-01.
- **Affected files / layers:** `lib/main.dart; lib/app/; android/`; keep UI→controller/service→Repository/Port→SQLite/native direction.
- **Steps & ordering:** Bootstrap, guarded navigation, loading/error state; start on device.
- **Contracts:** `AppBootstrap/StartupSessionResolver`. Favor existing interface, no speculative abstraction.
- **Test plan:** flutter analyze/test; real flutter run; assert negative cases, restart and regression where applicable.
- **Acceptance:** App launches without crash and session gate is fail-closed. Any untested physical-device requirement is separately `PENDING TEST`.
- **Deliverables:** Android build + screenshots/logs; stage report, files changed and reviewer evidence.
- **Verified/observed status:** HISTORIC PASS on SM-N986U; later bootstrap changed.
- **Remaining blockers and immediate work:** Retest latest compiled app after sync.
- **Git/QA protocol:** task branch `codex/b-02-<scope>` in siraj-codex, code+focused tests+markdown report, `dart format`/`flutter analyze`/`flutter test`, device test when needed; planned conventional commit example `feat(app): startup and navigation`. PR after review only.
- **Rollback:** revert the task commit if compatible and no schema migration; for DB/Resource changes use audited migration or immutable old active revision, never delete production data to fake rollback.

### B-03 — SQLite / Drift Foundation (TK-06)

- **Objective:** Single-account database schema, atomic operations, registry.
- **Dependencies:** B-01/02.
- **Affected files / layers:** `lib/data/{schema.drift,app_database.dart,*.g.dart,*repository.dart}`; keep UI→controller/service→Repository/Port→SQLite/native direction.
- **Steps & ordering:** Validate 5 tables, FK, singleton, migrations, transaction rollback, resource ownership.
- **Contracts:** `UserRepository/ConversationRepository/ResourceRepository`. Favor existing interface, no speculative abstraction.
- **Test plan:** Schema/in-memory DB, reopen, Android smoke; assert negative cases, restart and regression where applicable.
- **Acceptance:** No orphaned rows or cross-account reads, consistent rollback. Any untested physical-device requirement is separately `PENDING TEST`.
- **Deliverables:** DDL/migrations/repo tests; stage report, files changed and reviewer evidence.
- **Verified/observed status:** HISTORIC PASS; 21-test stage claim supported by earlier log.
- **Remaining blockers and immediate work:** Cross-revision schema review before Codex port.
- **Git/QA protocol:** task branch `codex/b-03-<scope>` in siraj-codex, code+focused tests+markdown report, `dart format`/`flutter analyze`/`flutter test`, device test when needed; planned conventional commit example `feat(db): foundation`. PR after review only.
- **Rollback:** revert the task commit if compatible and no schema migration; for DB/Resource changes use audited migration or immutable old active revision, never delete production data to fake rollback.

### B-04 — Local Auth & Security (TK-16)

- **Objective:** Signup/login/restore/logout/delete; PBKDF2 and Keystore.
- **Dependencies:** B-03.
- **Affected files / layers:** `lib/features/auth/; android/.../SirajSecureSessionChannel.kt`; keep UI→controller/service→Repository/Port→SQLite/native direction.
- **Steps & ordering:** Review cryptography implementation/parameters; handle Android native keystore; physical-device auth E2E.
- **Contracts:** `AuthService,PasswordHasher,SessionGuard,SessionMarkerStore`. Favor existing interface, no speculative abstraction.
- **Test plan:** Wrong password, nonce replay, logout/delete, runtime KDF on device; assert negative cases, restart and regression where applicable.
- **Acceptance:** No weak test-only KDF in production; local singleton session. Any untested physical-device requirement is separately `PENDING TEST`.
- **Deliverables:** Auth tests + Android security evidence; stage report, files changed and reviewer evidence.
- **Verified/observed status:** PARTIAL: 100k native parity benchmark + 1 Android session scenario passed; 600k experiment hung and rolled back.
- **Remaining blockers and immediate work:** Choose/test production KDF per DD-05, review Android method channel and fail-closed gate.
- **Git/QA protocol:** task branch `codex/b-04-<scope>` in siraj-codex, code+focused tests+markdown report, `dart format`/`flutter analyze`/`flutter test`, device test when needed; planned conventional commit example `fix(auth): choose reviewed production KDF`. PR after review only.
- **Rollback:** revert the task commit if compatible and no schema migration; for DB/Resource changes use audited migration or immutable old active revision, never delete production data to fake rollback.

### B-05 — Draft/Atomic Conversations (TK-17)

- **Objective:** 10 chats; draft in RAM; first send atomic.
- **Dependencies:** B-03/04.
- **Affected files / layers:** `lib/data/conversation_repository.dart; lib/features/chat/`; keep UI→controller/service→Repository/Port→SQLite/native direction.
- **Steps & ordering:** New draft no row; first message atomic; cancel/double send; oldest order; rollback.
- **Contracts:** `ConversationDraftController/ConversationRepository`. Favor existing interface, no speculative abstraction.
- **Test plan:** 10→11, rollback, duplicate, stale epoch, restart; assert negative cases, restart and regression where applicable.
- **Acceptance:** No deletion on new draft; no lost messages on failed transaction. Any untested physical-device requirement is separately `PENDING TEST`.
- **Deliverables:** Tests & report; stage report, files changed and reviewer evidence.
- **Verified/observed status:** HISTORIC PASS for unit/widget scope; production persistence further tested B-08.
- **Remaining blockers and immediate work:** Check race guards/device E2E.
- **Git/QA protocol:** task branch `codex/b-05-<scope>` in siraj-codex, code+focused tests+markdown report, `dart format`/`flutter analyze`/`flutter test`, device test when needed; planned conventional commit example `test(chat): atomic conversation regression`. PR after review only.
- **Rollback:** revert the task commit if compatible and no schema migration; for DB/Resource changes use audited migration or immutable old active revision, never delete production data to fake rollback.

### B-06 — Functional UI & Settings (TK-06/16/17)

- **Objective:** Arabic auth UI, home, routes, settings, deletion.
- **Dependencies:** B-02..05.
- **Affected files / layers:** `lib/app; lib/features/{auth,home,chat,settings}`; keep UI→controller/service→Repository/Port→SQLite/native direction.
- **Steps & ordering:** Connect verified session to screens, error/loading/empty, logout/delete, RTL.
- **Contracts:** `AppBootstrap/AuthActions/SettingsController`. Favor existing interface, no speculative abstraction.
- **Test plan:** Widget and SQLite integration, Android restart/logout/delete; assert negative cases, restart and regression where applicable.
- **Acceptance:** No bypass; no bogus account success. Any untested physical-device requirement is separately `PENDING TEST`.
- **Deliverables:** UI screenshots+tests; stage report, files changed and reviewer evidence.
- **Verified/observed status:** Step 3 merged 9b199a4, 207/207 green; E2E limited by KDF gate.
- **Remaining blockers and immediate work:** Remaining locale and Android authenticated flows.
- **Git/QA protocol:** task branch `codex/b-06-<scope>` in siraj-codex, code+focused tests+markdown report, `dart format`/`flutter analyze`/`flutter test`, device test when needed; planned conventional commit example `feat(ui): complete gated flows`. PR after review only.
- **Rollback:** revert the task commit if compatible and no schema migration; for DB/Resource changes use audited migration or immutable old active revision, never delete production data to fake rollback.

### B-07 — Resource Status, Download & Validation (TK-02)

- **Objective:** Independent downloads to staging, integrity, format, no false ready.
- **Dependencies:** B-03; trusted manifest/metadata.
- **Affected files / layers:** `lib/features/resources; lib/data/resource_repository.dart`; keep UI→controller/service→Repository/Port→SQLite/native direction.
- **Steps & ordering:** Get trusted spec; download/partial/resume; hash; format/runtime preflight; verified publish via separate gate.
- **Contracts:** `DownloadService,ResourceStatusReader,ArtifactIntegrityValidator`. Favor existing interface, no speculative abstraction.
- **Test plan:** Range/ETag or trusted provenance, abort, hash mismatch, disk full, power loss; assert negative cases, restart and regression where applicable.
- **Acceptance:** Staged != READY; preserve active set. Any untested physical-device requirement is separately `PENDING TEST`.
- **Deliverables:** Download/validation reports; stage report, files changed and reviewer evidence.
- **Verified/observed status:** Step 5 checks merged 9e4feb4; Step 6 uncommitted + one failing test, 222/223.
- **Remaining blockers and immediate work:** Fix test13 provenance, run 225 and Android network tests then commit.
- **Git/QA protocol:** task branch `codex/b-07-<scope>` in siraj-codex, code+focused tests+markdown report, `dart format`/`flutter analyze`/`flutter test`, device test when needed; planned conventional commit example `feat(resources): secure staging downloader`. PR after review only.
- **Rollback:** revert the task commit if compatible and no schema migration; for DB/Resource changes use audited migration or immutable old active revision, never delete production data to fake rollback.

### B-08 — Chat/Tutor Contracts Integration (TK-08)

- **Objective:** Tutor DTO, error/source mapping, follows-ups, saved chat history.
- **Dependencies:** B-05/06; A contract alignment.
- **Affected files / layers:** `lib/integrations/ai; lib/features/chat`; keep UI→controller/service→Repository/Port→SQLite/native direction.
- **Steps & ordering:** Version TutorResult; persist USER first; display sourced/refusal/error; guard stale replies.
- **Contracts:** `TutorPort/TutorResult/SourceReference/ChatTurnCoordinator`. Favor existing interface, no speculative abstraction.
- **Test plan:** Contract/widget, invalid source, cancellation, follow-up/rehydration; assert negative cases, restart and regression where applicable.
- **Acceptance:** No fake AI claimed real; exact revision IDs. Any untested physical-device requirement is separately `PENDING TEST`.
- **Deliverables:** DTO tests and conversation evidence; stage report, files changed and reviewer evidence.
- **Verified/observed status:** Step4 committed 8ef5b3e; 192/192 before B-06 update.
- **Remaining blockers and immediate work:** Finalize A adapter + Android full flow when A/C ready.
- **Git/QA protocol:** task branch `codex/b-08-<scope>` in siraj-codex, code+focused tests+markdown report, `dart format`/`flutter analyze`/`flutter test`, device test when needed; planned conventional commit example `feat(chat): connect real tutor adapter`. PR after review only.
- **Rollback:** revert the task commit if compatible and no schema migration; for DB/Resource changes use audited migration or immutable old active revision, never delete production data to fake rollback.

### B-09 — Android Real Biology G2/G3 (TK-13)

- **Objective:** First genuine offline Biology question RAG answer with sources.
- **Dependencies:** A model/embed + C fixture/index + minimal B contracts.
- **Affected files / layers:** `lib/integrations/ai; Android native runtime`; keep UI→controller/service→Repository/Port→SQLite/native direction.
- **Steps & ordering:** Model+embed/index same revision, retriever+evidence+LLM, verify sources/save.
- **Contracts:** `ModelRuntime/QueryEmbedder/Retriever/TutorService`. Favor existing interface, no speculative abstraction.
- **Test plan:** Cold/warm run and offline real device; RAM/latency logged; assert negative cases, restart and regression where applicable.
- **Acceptance:** G2 model + embed/index physically run; G3 true vertical slice. Any untested physical-device requirement is separately `PENDING TEST`.
- **Deliverables:** Device evidence logs + revision IDs; stage report, files changed and reviewer evidence.
- **Verified/observed status:** BLOCKED: no real A/C runtime/model/verified index evidence.
- **Remaining blockers and immediate work:** Keep early priority; arrange stable fixture without requiring full five-pack release.
- **Git/QA protocol:** task branch `codex/b-09-<scope>` in siraj-codex, code+focused tests+markdown report, `dart format`/`flutter analyze`/`flutter test`, device test when needed; planned conventional commit example `feat(ai): real Android G3 slice`. PR after review only.
- **Rollback:** revert the task commit if compatible and no schema migration; for DB/Resource changes use audited migration or immutable old active revision, never delete production data to fake rollback.

### B-10 — PDF Library & Reader (TK-18)

- **Objective:** Individual PDF download/open offline independent of RAG.
- **Dependencies:** B-07, C trusted BookCatalog.
- **Affected files / layers:** `lib/features/pdf; resource downloader`; keep UI→controller/service→Repository/Port→SQLite/native direction.
- **Steps & ordering:** Catalog mapping, verified/local file locator, PDF viewer, disconnected read.
- **Contracts:** `BookCatalog/PdfLibraryRepository/Reader`. Favor existing interface, no speculative abstraction.
- **Test plan:** missing/invalid/book independent of LLM; Android viewer; assert negative cases, restart and regression where applicable.
- **Acceptance:** PDF no RAG indexing; failed download not available. Any untested physical-device requirement is separately `PENDING TEST`.
- **Deliverables:** Library UI+Viewer+test; stage report, files changed and reviewer evidence.
- **Verified/observed status:** NOT IMPLEMENTED by latest confirmed commit.
- **Remaining blockers and immediate work:** Develop UI against catalog fixture, integrate trusted catalog.
- **Git/QA protocol:** task branch `codex/b-10-<scope>` in siraj-codex, code+focused tests+markdown report, `dart format`/`flutter analyze`/`flutter test`, device test when needed; planned conventional commit example `feat(pdf): offline library viewer`. PR after review only.
- **Rollback:** revert the task commit if compatible and no schema migration; for DB/Resource changes use audited migration or immutable old active revision, never delete production data to fake rollback.

### B-11 — Quiz Session UI (TK-10)

- **Objective:** RAM-only Quiz request/questions/scoring/feedback.
- **Dependencies:** B-06/08, A QuizPort, C examples.
- **Affected files / layers:** `lib/features/quiz; lib/integrations/ai/quiz_port.dart`; keep UI→controller/service→Repository/Port→SQLite/native direction.
- **Steps & ordering:** Request; 4 question renderers; validate answer; UNDETERMINED; dispose RAM.
- **Contracts:** `QuizService/QuizItem/AnswerSpec/Feedback`. Favor existing interface, no speculative abstraction.
- **Test plan:** 4 types, refusal/error/ambiguous; no DB persistence; assert negative cases, restart and regression where applicable.
- **Acceptance:** No bank-only, no saved QuizAttempt. Any untested physical-device requirement is separately `PENDING TEST`.
- **Deliverables:** Quiz widget/contract tests; stage report, files changed and reviewer evidence.
- **Verified/observed status:** NOT IMPLEMENTED confirmed; plan only.
- **Remaining blockers and immediate work:** Define minimum typed DTO consistent with A/C.
- **Git/QA protocol:** task branch `codex/b-11-<scope>` in siraj-codex, code+focused tests+markdown report, `dart format`/`flutter analyze`/`flutter test`, device test when needed; planned conventional commit example `feat(quiz): RAM quiz session UI`. PR after review only.
- **Rollback:** revert the task commit if compatible and no schema migration; for DB/Resource changes use audited migration or immutable old active revision, never delete production data to fake rollback.

### B-12 — Dataset Release Management (TK-19)

- **Objective:** 5 packs+shared embedder contract, immutable candidates and atomic active pointer.
- **Dependencies:** B-07; A+C schema/manifest.
- **Affected files / layers:** `resource release manager / dataset coordinator`; keep UI→controller/service→Repository/Port→SQLite/native direction.
- **Steps & ordering:** Candidate staging→contract checks→compatible integrity→atomic pointer activation→rollback.
- **Contracts:** `RevisionPinnedHandle,DatasetReleaseManager,Manifest`. Favor existing interface, no speculative abstraction.
- **Test plan:** Partial failed updates, crash recovery, revision consistency; assert negative cases, restart and regression where applicable.
- **Acceptance:** Biology fixture isolated; no five-pack requirement for pilot; no product RAG_READY. Any untested physical-device requirement is separately `PENDING TEST`.
- **Deliverables:** Activation/recovery tests; stage report, files changed and reviewer evidence.
- **Verified/observed status:** CONTRACTS PARTIAL; production release manager not proven.
- **Remaining blockers and immediate work:** Use fixture to test mechanism; full five-pack later.
- **Git/QA protocol:** task branch `codex/b-12-<scope>` in siraj-codex, code+focused tests+markdown report, `dart format`/`flutter analyze`/`flutter test`, device test when needed; planned conventional commit example `feat(resources): atomic dataset revision manager`. PR after review only.
- **Rollback:** revert the task commit if compatible and no schema migration; for DB/Resource changes use audited migration or immutable old active revision, never delete production data to fake rollback.

### B-13 — End-to-end Android QA & Delivery (TK-13/15)

- **Objective:** APK, offline/online, memory and regression evidence.
- **Dependencies:** All testable tasks; A/C for full integrated pass.
- **Affected files / layers:** `android/; integration_test; docs/reports`; keep UI→controller/service→Repository/Port→SQLite/native direction.
- **Steps & ordering:** Freeze commit/resources; run regressions and physical device measurements; disclose blocked.
- **Contracts:** `QA Matrix + release checklist`. Favor existing interface, no speculative abstraction.
- **Test plan:** Android scenario, stress, crash power loss, no secret log; assert negative cases, restart and regression where applicable.
- **Acceptance:** APK installable and all claimed gates proven. Any untested physical-device requirement is separately `PENDING TEST`.
- **Deliverables:** Device logs/screenshots/metrics/release report; stage report, files changed and reviewer evidence.
- **Verified/observed status:** ONGOING TEST EVIDENCE, no final release gate pass.
- **Remaining blockers and immediate work:** Close critical defects only with evidence.
- **Git/QA protocol:** task branch `codex/b-13-<scope>` in siraj-codex, code+focused tests+markdown report, `dart format`/`flutter analyze`/`flutter test`, device test when needed; planned conventional commit example `test(release): verified Android pilot`. PR after review only.
- **Rollback:** revert the task commit if compatible and no schema migration; for DB/Resource changes use audited migration or immutable old active revision, never delete production data to fake rollback.

## Workstream dependency / parallelism

```text
                   G0 baseline & G1 contracts
                       |
          +------------+-------------+
          |            |             |
       B-04/06       B-07          A ModelRuntime
          |            |             |
       B-05/08     B-10/B-12      C Biology runtime pack/index
          |            |             |
          +-------> EARLY G2 / G3 <---+
                       |
                 B-11/B-13 (pilot QA)
```

**Important:** this graph is a scheduling aid; early G2/G3 technical proof may use minimum B-07 handling and verified local test assets, without waiting for B-10/B-11/B-12 production completion. B-09’s G2/G3 evidence is not achieved by a simple UI fake.

## Formal source plan — complete extracted text

The content below is preserved from the separately supplied Team B plan. Its original priority/status wording is superseded where the approved amendments above conflict.

---

# SIRAJ P0 — Flutter/Android Implementation Work Plan — Biology Pilot

**خطة العمل التنفيذية لمسؤول Flutter / Android — العضو B**

**المرجع:** `SIRAJ_P0_FINAL_MASTER_SPECIFICATION_v1.0.1_CORRECTED.md`  
**النطاق التنفيذي:** Biology-First Engineering Pilot  
**الحالة:** خطة تكليف جاهزة للعمل — التنفيذ والاختبارات لم يُتحقق منهما بعد  
**المسؤول:** B — Flutter / Android / SQLite  
**التنسيق:** A — AI / Integration، وC — Dataset / RAG

## الهدف التنفيذي

بناء تطبيق SIRAJ الفعلي باستخدام Flutter وتشغيله على هاتف Android حقيقي، مع ربط الحساب المحلي وSQLite والمحادثات وإدارة الموارد وPDF وLocal AI/RAG وChat وQuiz بصورة قابلة للاستمرار ضمن P0 النهائي.

تُستخدم مادة الأحياء وحدها في الاختبار الهندسي الأول. ولا يعني ذلك تغيير نطاق P0 النهائي الذي يشمل خمس مواد.

**قاعدة العمل:** نفحص الموجود أولًا، ونستكمل الناقص فقط. لا نعيد إنشاء مشروع أو مكون ثبتت سلامته، ولا نستبدل التكامل الحقيقي بخدمات وهمية عند اختبار الإنجاز النهائي.

---

# 1. نطاق ومسؤوليات Flutter

## 1.1 توزيع المسؤوليات

| المجال | المطلوب من B — Flutter | مسؤولية عضو آخر |
|---|---|---|
| إعداد المشروع | فحص المستودع، إعداد Android Build، وتشغيل التطبيق على الهاتف | A ينسق المستودع والعقود المشتركة |
| المعمارية | تنظيم Flutter والاعتماديات وواجهات الخدمات | A يراجع اتجاهات التكامل |
| الواجهات | تنفيذ UI-01..UI-14 وظيفيًا | قائد المشروع يعتمد التصميم عند الحاجة |
| التنقل والحالة | Startup/Auth Gate، التنقل، Loading/Error/Empty States، دعم RTL | A يوفر حالات الخدمات التقنية |
| الحساب المحلي | Create/Login/Logout/Delete، تشفير الجلسة باستخدام Keystore، SessionGuard | A يراجع العقود والأمان |
| SQLite/Drift | المخطط والترحيلات وRepositories والمعاملات الذرية | لا يعتمد على Dataset |
| المحادثات | Draft مؤقت، حفظ الرسائل، حد 10، حذف الأقدم، متابعة المحادثة | A يوفر TutorService وسياق التوليد |
| إدارة الموارد | تنزيل وتحقق وتخزين وتفعيل الموارد، وإظهار حالاتها | A يتحقق من LLM/Embedding، وC يوفر Manifest/Artifacts |
| مكتبة PDF | Catalog، تنزيل منفصل، قارئ Offline | C يوفر بيانات الكتب والمراجع وروابطها الموثقة |
| AI Integration | توفير واستدعاء Dart Interfaces وربط النتائج بالواجهات | A مسؤول عن ModelRuntime وTutor orchestration |
| RAG Integration | استقبال نتائج Tutor والمصادر وإظهارها | C مسؤول عن Dataset/Indexes/Retrieval بالتعاون مع A |
| Quiz | واجهات الطلب والأسئلة والتصحيح والجلسة المؤقتة | A+C مسؤولان عن Generation/Validation العلمي |
| الإعدادات | اللغة، حالة الموارد، Logout، حذف الحساب | — |
| الاختبارات والتسليم | Flutter Tests، Android Tests، APK، سجلات الأعطال | A+C للاختبارات العلمية وتشغيل AI المتكامل |

**حدود مسؤولية B:**

لا يُكلّف باستخراج منهج الأحياء، أو مراجعة المحتوى العلمي، أو تدريب النموذج، أو إنشاء Embeddings وفهارس المحتوى، أو تطوير خوارزميات Retrieval وGrounding.

لكنه مسؤول عن أن يستطيع التطبيق استهلاك هذه المكونات عبر عقود صحيحة، وأن يحافظ على سلامة البيانات وحالات الموارد عند نجاح العمليات أو فشلها.

## 1.2 مبادئ ملزمة

1. حساب واحد فقط لكل تثبيت، وليس نظام حسابات متعددة.
2. لا اتصال بخادم لتسجيل الدخول أو حفظ المحادثات أو توليد الإجابات.
3. PDF وLLM وRAG موارد مستقلة وظيفيًا وتخزينيًا.
4. المحادثة الجديدة لا تُحفظ حتى أول رسالة صالحة.
5. لا تتجاوز المحادثات المحفوظة عشرًا.
6. لا يعرض التطبيق AI Answer أو Resource READY دون تحقق فعلي.
7. Quiz مولّد بواسطة Local LLM، ولا يُحفظ في SQLite.
8. لا تستخدم واجهة Chat اختيار مادة إلزاميًا.
9. مكونات Flutter العامة لا تحتوي شروطًا خاصة باسم الأحياء.
10. `INTEGRATION_FIXTURE_MODE` للاختبارات فقط، ولا يحوّل Dataset الأحياء إلى `RAG_READY` إنتاجية.

---

# 2. مواصفات الشاشات — UI-01..UI-14

يُنفذ B الشاشات التالية وفق القسم الثالث من المواصفة الرسمية. المقصود بالشاشة هنا وحدة واجهة وظيفية؛ يمكن تنفيذ UI-03 كنافذة تأكيد وUI-11 كمكوّن داخل المحادثة دون إنشاء صفحات منفصلة بلا حاجة.

| الشاشة والهدف | العناصر والإجراءات المطلوبة | الخدمات والبيانات | حالات التحميل/الفراغ/الفشل | الانتقال | معيار القبول |
|---|---|---|---|---|---|
| **UI-01 — إنشاء حساب** | Username وPassword وConfirm، والتحقق من الإدخال، وزر إنشاء | AuthService.create وUserRepository | Validation/DB Error/Account Exists؛ تعطيل تكرار Submit | UI-04 أو UI-06 بعد النجاح | حساب واحد فقط؛ TC-24/30 |
| **UI-02 — تسجيل الدخول** | Username وPassword وزر Login ورسالة خطأ عامة | AuthService.login/restoreSession | Loading/Invalid Credentials/Session Error؛ لا Forgot Password | UI-04 أو UI-06 | جلسة صحيحة؛ Restart بعد Logout يتطلب Login؛ TC-24/29/30 |
| **UI-03 — حذف الحساب** | التحذير الحرفي وزرا إلغاء وتأكيد | AuthService.deleteCurrentAccount | Pending/Delete Failed؛ منع التأكيد المكرر | Cancel إلى UI-14؛ Confirm إلى UI-01 | حذف البيانات الخاصة فقط، دون إعادة كلمة المرور؛ TC-29/30 |
| **UI-04 — تجهيز الموارد** | عرض حالة Dataset وLLM بصورة منفصلة، الموافقة الواحدة لتجهيز Dataset الإنتاجية، والتقدم والأخطاء | ResourceStatusRepository وDatasetPreparationCoordinator | Missing/Downloading/Verifying/Failed/Incompatible؛ لا جاهزية وهمية | UI-05 للنموذج، UI-06 أو البقاء عند التعذر | فصل الموارد وعدم نشر Dataset ناقصة؛ TC-26/32 |
| **UI-05 — النموذج المحلي** | تفاصيل النموذج وحالته، تنزيله، تقدم العملية، Retry | ModelArtifactManager/DownloadService/ModelRuntime status | Missing/Download Error/Invalid/OOM/Incompatible | UI-04 أو UI-06 | READY بعد التحقق المناسب فقط؛ TC-13/16/20 |
| **UI-06 — الرئيسية** | روابط Chat وPDF وQuiz والموارد والإعدادات، مع حالة الحساب | AuthSession وResource Status | Loading/Unavailable/Session Invalid | UI-07/09/12/04/14 | PDF لا يُعطّل عند غياب AI؛ TC-19/24/26 |
| **UI-07 — مكتبة PDF** | قائمة ديناميكية بالكتب، حالة كل كتاب، Download/Open | PdfLibraryRepository/BookCatalog | Empty Catalog/Offline/Missing/Corrupt/Downloading | UI-08 أو البقاء في المكتبة | تنزيل كل كتاب وفتحه مستقلًا؛ TC-02/27 |
| **UI-08 — قارئ PDF** | صفحات الكتاب، تمرير/تنقل، رجوع، Loading | PDF local file locator/Viewer | Missing/Unreadable/Loading Error | UI-07 | القراءة Offline دون LLM/RAG؛ TC-27 |
| **UI-09 — المحادثات** | قائمة المحادثات المحفوظة، فتح محادثة، زر محادثة جديدة، إظهار سياسة الحد | ConversationRepository | Empty/Loading/DB Error | UI-10 | زر New لا يضيف سجلًا ولا يحذف القديم؛ TC-25/30 |
| **UI-10 — المحادثة** | الرسائل، حقل السؤال، زر إرسال، منع Double Send، حالة التوليد | ConversationService/TutorService | Blank/Loading/Resource Error/Refusal/Generation Error | UI-11 لعرض الإجابة والمصادر؛ UI-09 للرجوع | أول رسالة تُحفظ ذريًا قبل AI؛ لا اختيار مادة يدوي؛ TC-01/08/25/30 |
| **UI-11 — الإجابة والمصادر** | النص، حالة ANSWER/REFUSAL/ERROR، دعم Partial، عناصر المصادر القابلة للفتح | TutorResult/SourceMapper.resolve | No Evidence/Source Unavailable/Runtime Error | العودة إلى UI-10 أو عرض تفاصيل المصدر | مصدر من Dataset Revision الصحيح فقط؛ TC-04/05/07/18 |
| **UI-12 — طلب Quiz** | حقل طلب الاختبار، تحديد النوع/العدد إن توفر، زر إنشاء | QuizService.create/ResourceStatus | Missing LLM/RAG/Scope Ambiguous/Invalid Generation | UI-13 عند نجاح Validation | أسئلة جديدة مولّدة، لا Bank-only؛ TC-09/10/31 |
| **UI-13 — الاختبار والتصحيح** | سؤال، خيارات أو حقل إدخال، Submit، Feedback، Finish، Summary | QuizSession/QuizService.answer/finish | Loading/Input Error/UNDETERMINED/Expired | الرجوع أو إنهاء الجلسة | الأنواع الأربعة، تصحيح محافظ، لا حفظ دائم؛ TC-11/15/31 |
| **UI-14 — الإعدادات** | اللغة، حساب المستخدم، حالة الموارد، Logout، حذف الحساب | SettingsService/AuthService/ResourceStatus | Loading/Write Error/Session Invalid | UI-03 للحذف، UI-02 للخروج | Logout يبطل الجلسة؛ حذف الحساب يتطلب تأكيدًا؛ TC-14/24/29/30 |

## 2.1 سلوك التنقل عند بدء التطبيق

يطبّق B القرار التالي بالترتيب:

- لا يوجد حساب محفوظ → UI-01.
- يوجد حساب، وجلسة Persistent Session صالحة → UI-04 عند الحاجة للموارد، وإلا UI-06.
- يوجد حساب، لكن الجلسة غير صالحة أو خرج المستخدم → UI-02.
- خطأ في DB أو Keystore → حالة خطأ آمنة، دون كشف البيانات أو تجاوز المصادقة.

لا يجوز اعتبار مجرد وجود اسم مستخدم في SQLite دليلًا على نجاح تسجيل الدخول.

## 2.2 قواعد المحادثات

عند ضغط «محادثة جديدة» ينشئ التطبيق `DraftConversation` في RAM فقط.

عند إرسال أول رسالة غير فارغة وصالحة، تنفذ معاملة SQLite واحدة تشمل إنشاء المحادثة وإدراج أول USER Message وحذف أقدم محادثة إذا كان العدد قد بلغ عشرًا.

إذا فشلت المعاملة، لا تُحذف القديمة ولا تُعلن الجديدة محفوظة. وإذا نجح حفظ السؤال ثم فشل LLM، تبقى رسالة المستخدم محفوظة ويظهر خطأ التوليد.

## 2.3 قاعدة حذف الحساب

يظهر التحذير التالي حرفيًا:

**«سيتم حذف هذا الحساب ومحادثاته نهائيًا، ولا يمكن استعادة بياناته».**

الإلغاء لا يغير شيئًا. التأكيد يلغي أو يعزل الطلبات الجارية، ويحذف الحساب وبياناته التابعة داخل SQLite، ويبطل الجلسة، ويترك ملفات LLM وRAG وPDF المشتركة محفوظة.

---

# 3. بنية المشروع والملفات

## 3.1 التنظيم المقترح

**هذا هيكل مستهدف، وليس وصفًا لملفات موجودة حاليًا.**

يُطبّق بعد TK-00 على المستودع الفعلي، مع إعادة استخدام أي تنظيم أو مكتبات موجودة ومناسبة. لا نحتاج إلى إنشاء Packages منفصلة لكل وظيفة أو Clean Architecture متعددة الطبقات.

```text
siraj/
├── pubspec.yaml
├── analysis_options.yaml
├── android/
│   └── app/
│       ├── build.gradle[.kts]
│       └── src/main/
│           └── AndroidManifest.xml
│
├── lib/
│   ├── main.dart
│   │
│   ├── app/
│   │   ├── siraj_app.dart
│   │   ├── app_bootstrap.dart
│   │   ├── app_routes.dart
│   │   └── build_mode.dart
│   │
│   ├── core/
│   │   ├── domain_error.dart
│   │   ├── result.dart
│   │   ├── path_resolver.dart
│   │   └── request_guard.dart
│   │
│   ├── data/
│   │   ├── app_database.dart
│   │   ├── tables.dart
│   │   ├── migrations.dart
│   │   ├── user_repository.dart
│   │   ├── conversation_repository.dart
│   │   ├── settings_repository.dart
│   │   └── resource_repository.dart
│   │
│   ├── features/
│   │   ├── auth/
│   │   │   ├── auth_service.dart
│   │   │   ├── secure_session_store.dart
│   │   │   ├── auth_controller.dart
│   │   │   ├── signup_page.dart
│   │   │   └── login_page.dart
│   │   │
│   │   ├── home/
│   │   │   └── home_page.dart
│   │   │
│   │   ├── chat/
│   │   │   ├── chat_list_page.dart
│   │   │   ├── chat_page.dart
│   │   │   ├── answer_source_view.dart
│   │   │   └── chat_controller.dart
│   │   │
│   │   ├── resources/
│   │   │   ├── resource_page.dart
│   │   │   ├── model_page.dart
│   │   │   ├── resource_controller.dart
│   │   │   ├── download_service.dart
│   │   │   ├── resource_validator.dart
│   │   │   ├── dataset_release_manager.dart
│   │   │   └── dataset_coordinator.dart
│   │   │
│   │   ├── pdf/
│   │   │   ├── pdf_library_page.dart
│   │   │   ├── pdf_reader_page.dart
│   │   │   └── pdf_library_repository.dart
│   │   │
│   │   ├── quiz/
│   │   │   ├── quiz_request_page.dart
│   │   │   ├── quiz_session_page.dart
│   │   │   └── quiz_controller.dart
│   │   │
│   │   └── settings/
│   │       ├── settings_page.dart
│   │       └── delete_account_dialog.dart
│   │
│   └── integrations/
│       └── ai/
│           ├── model_runtime_port.dart
│           ├── tutor_port.dart
│           ├── quiz_port.dart
│           └── source_resolver_port.dart
│
├── test/
│   ├── auth_test.dart
│   ├── conversation_test.dart
│   ├── database_test.dart
│   ├── resource_test.dart
│   ├── chat_widget_test.dart
│   └── quiz_test.dart
│
└── integration_test/
    ├── auth_flow_test.dart
    ├── chat_flow_test.dart
    └── offline_flow_test.dart
```

الأسماء أعلاه **اقتراح تنفيذي من B**؛ لا تغيّر أسماء العقود الرسمية أو سلوكها. ملفات `*.g.dart` المولّدة بواسطة Drift تُنشأ عبر أدوات التوليد، ولا تُحرر يدويًا.

## 3.2 مسؤوليات مجموعات الملفات

| المجموعة | الوظيفة |
|---|---|
| `app/` | تهيئة التطبيق، Startup، Auth Gate، التنقل، واختيار وضع Test/Production |
| `core/` | أنواع Result/Error المشتركة، المسارات، وحماية الطلبات |
| `data/` | SQLite/Drift، الترحيلات، Repositories، وعمليات Transaction |
| `features/auth/` | المصادقة المحلية والجلسات والشاشات |
| `features/chat/` | قائمة المحادثات والرسائل والتحكم في حالة الواجهة |
| `features/resources/` | تنزيل الموارد والتحقق منها وإدارة دورة حياتها |
| `features/pdf/` | تصفح PDF وتنزيله وقراءته مستقلًا |
| `features/quiz/` | طلب الاختبارات وعرض الجلسة والتصحيح المؤقت |
| `features/settings/` | اللغة وإدارة الحساب |
| `integrations/ai/` | عقود Dart التي تربط التطبيق بخدمات A، دون تنفيذ Retrieval داخل Widgets |
| `test/` و`integration_test/` | فحص المنطق وواجهات المستخدم وتكامل الجهاز |

## 3.3 التقنيات المقترحة

المواصفة تعتمد Flutter/Dart وSQLite/Drift وAndroid Keystore-backed session وLocal ModelRuntime.

**اختيارات تنفيذية مقترحة، وليست تعديلات لنطاق المشروع:**

- إدارة التنقل باستخدام Flutter Navigator مع Auth Gate واضحة.
- إدارة الحالة بوسائل Flutter البسيطة مثل `ChangeNotifier`/`ValueNotifier`، أو الاحتفاظ بمكتبة State Management مناسبة إذا كانت موجودة بالفعل.
- Drift كطبقة وصول SQLite، دون تنفيذ SQL مباشرة من Widgets.
- `flutter_secure_storage` أو تنفيذ مكافئ موثوق ومدقق لإدارة Session Marker المحمية بـAndroid Keystore.
- مكتبة تنزيل HTTP(S) واحدة تدعم Streaming والكتابة التدريجية وإلغاء العمليات؛ يتم اختيارها بعد TK-00.
- مكتبة PDF Viewer محلية متوافقة مع Android 13، ويُحسم اختيارها باختبار فتح ملف فعلي.

تُثبت إصدارات الحزم وتوافقها مع Flutter/Android الحالي أثناء التنفيذ، ولا تُضاف مكتبتان لأداء الوظيفة نفسها دون سبب.

## 3.4 قاعدة البيانات المطلوبة

المخطط الأساسي مطابق للقسم السابع من الوثيقة:

| الجدول | الوظيفة |
|---|---|
| `user_profile` | صف واحد فقط للحساب، Password Hash/Salt/Params، وSession Nonce Hash |
| `conversation` | محادثات الحساب، ومعرفاتها وتواريخها |
| `message` | رسائل USER/ASSISTANT والمصادر |
| `app_setting` | إعدادات الحساب |
| `installed_resource` | حالة الموارد المشتركة وإصداراتها ومؤشر Dataset النشط |

**ممنوع ضمن P0:** إنشاء جدول لحفظ QuizAttempt أو Quiz History أو DraftConversation.

يجب تفعيل Foreign Keys، ومعالجة Migration، واختبار سلامة Cascade Delete وRollback قبل اعتبار طبقة البيانات جاهزة.

---

# 4. قائمة المهام التنفيذية لمسؤول Flutter

المهام التالية معرفات عمل داخلية `B-01..B-13` لتسهيل المتابعة، وليست بديلًا عن معرفات `TK` الرسمية.

**كل مهمة لها مخرج قابل للفحص. لا تُوسم DONE لمجرد كتابة الملفات.**

## 4.1 المهام مرتبة بالأولوية

| ID | المهمة | العمل المطلوب تنفيذه | الملفات/المكونات المتأثرة | الاعتماديات | معيار الإنجاز |
|---|---|---|---|---|---|
| **B-01** | فحص المشروع والبيئة — TK-00 | تحديد المستودع وGit Revision وFlutter/SDK/ADB والهاتف وABI؛ جرد الموجود من UI/DB/Plugins/Native وإعداد تقرير الفجوات | المستودع الحالي وأدوات Windows/ADB | لا شيء | تقرير Inventory حقيقي، وتحديد ما يعمل وما يحتاج عملًا؛ G0 |
| **B-02** | جاهزية التطبيق على الهاتف — TK-06 | إصلاح Build القائم عند الحاجة، تشغيل التطبيق، إعداد Bootstrap/Auth Gate والتنقل الأساسي وRTL دون AI | `main.dart`، `app/`، Android Config | B-01 | Build وتشغيل حقيقي، والتنقل دون Crash؛ بداية G1 |
| **B-03** | SQLite/Drift Foundation — TK-06 | تنفيذ/تصحيح الجداول الخمسة وDAO/Repositories والترحيلات وFK وResource Registry، مع اختبارات DB | `data/` | B-01/02 ومراجعة Schema | فتح DB وCRUD وTransaction ومخطط صحيح؛ TC-15/22 |
| **B-04** | الحساب والجلسة — TK-16 | Signup/Login/Logout/Restore/Delete؛ قيد singleton؛ PBKDF2؛ Secure Marker؛ SessionGuard؛ حماية Logout/Delete | `features/auth/` و`data/user_repository.dart` | B-03 | حساب واحد، Auto-login، إبطال الجلسة، حذف آمن؛ TC-21/24/29/30 |
| **B-05** | المحادثات الذرية — TK-17 | تنفيذ Draft في RAM وRepositories وFirst-message Atomic Transaction والحد 10 وIdempotent Send | `conversation_repository.dart` و`features/chat/` | B-03/04 | 10 محادثات كحد أقصى، ولا حذف عند Draft، وRollback سليم؛ TC-08/15/25/30 |
| **B-06** | واجهات الأساس — TK-06/16/17 | توصيل إنشاء الحساب والدخول والرئيسية والمحادثات والإعدادات والتنقل والحالات بالبيانات الحقيقية | `features/auth/home/chat/settings/` | B-02..05 | رحلة مستخدم كاملة من Signup إلى Logout وإعادة الدخول دون AI؛ TC-15/24/25/29 |
| **B-07** | إدارة الموارد والتنزيلات — TK-02 | تنزيل HTTPS إلى staging، تقدم/إيقاف/استئناف/إعادة محاولة، تحقق Hash، تخزين مستقل، Validators وحالات خطأ | `features/resources/` و`resource_repository.dart` | B-03 وعقود Manifest/Resource | تنزيلات صحيحة وفاشلة دون READY وهمية، ولا فساد مورد نشط؛ TC-12/16/21 |
| **B-08** | عقود وربط Chat/AI — TK-08 | تثبيت TutorResult/Errors/SourceRefs/Request Guards مع A؛ بناء Chat UI قابل للاختبار بـFake مطابق للعقد؛ حفظ USER قبل الاستدعاء | `integrations/ai/` و`features/chat/` | B-05/06، اتفاق عقد A | Widget/Contract Tests للحالات ANSWER/REFUSAL/ERROR والمصادر؛ TC-07/18/28 |
| **B-09** | تجربة Chat/RAG الحقيقية — TK-13 | ربط A/C الحقيقيين؛ تشغيل LLM وEmbedding وRetriever عبر Test Fixture للأحياء؛ اختبار السؤال والمصادر والحفظ Offline | AI Adapters وChat/Resources | B-07/08؛ تكامل A/C وFixture صالحة | G2 ثم G3 على Android، مع أدلة تشغيل حقيقي؛ لا Product RAG_READY |
| **B-10** | مكتبة PDF — TK-18 | بناء Catalog ديناميكي وتنزيل كتاب منفرد والتحقق وPDF Viewer محلي واختبار الاستقلال | `features/pdf/` + DownloadService | B-07 وCatalog صالح من C | تنزيل وفتح Offline حتى مع غياب AI؛ TC-02/27 |
| **B-11** | واجهة Quiz والجلسة — TK-10 | ربط طلب Quiz بعقد A، عرض الأسئلة الجديدة المقبولة، الإجابات والتصحيح وUNDETERMINED وجلسة RAM | `features/quiz/` و`quiz_port.dart` | B-06/08، مخرجات Quiz من A+C | أربعة أنواع قابلة للعرض، لا حفظ SQLite، No Bank-only؛ TC-11/15/31 |
| **B-12** | تجهيز Dataset الإنتاجية — TK-19 | استكمال مسار One-consent Five Packs + Shared Embedder، Candidate Verification وImmutable Promotion وSQLite Atomic Pointer، مع الفصل عن Fixture | `dataset_coordinator.dart` و`dataset_release_manager.dart` | B-07؛ العقود المعتمدة من A/C | اختبارات سلامة/فشل/استعادة؛ قبول Product Ready مؤجل لحين الخمس؛ TC-12/26/32 |
| **B-13** | اختبارات Android والتسليم — TK-13/15 | اختبار وظائف B كاملة، Integration Regression، أداء الجهاز، Offline، معالجة Defects، وتجهيز APK مع الأدلة | المشروع والاختبارات وBuild | المهام ذات الصلة واكتمال تكامل A/C المطلوب لكل اختبار | APK قابل للتثبيت، اختبارات موثقة، ولا Critical Defects مفتوحة ضمن التسليم المعلن |

## 4.2 قواعد انتقال المهام

**B-01 إلى B-06 مستقلة عمليًا عن اكتمال Dataset وLLM.** يمكن البدء بها فور معرفة حالة المستودع.

يمكن تنفيذ B-07 بالتوازي مع بعض واجهات B-06 بعد تثبيت مخطط Resource Registry، كما يمكن إعداد واجهات B-08 وB-11 باستخدام Fake Services متوافقة مع العقود.

أما B-09 فلا يُعد منجزًا إلا بعد تشغيل AI/RAG الحقيقي على الهاتف.

وبالنسبة إلى B-12، تُبنى آلية التفعيل العامة وتُختبر بفحوص محكومة، لكن لا يُعلن نجاح شروط الخمس أو `RAG_READY` الإنتاجية باستعمال الأحياء فقط.

## 4.3 أهم مخرجات المراحل المبكرة

**بعد B-02:** تطبيق يعمل على Android، ولو دون بيانات تعليمية.

**بعد B-06:** حساب محلي وحيد، دخول مستمر، محادثات محفوظة وفق القاعدة المعتمدة، وإعدادات تعمل.

**بعد B-08:** واجهة Chat تتعامل مع العقود الصحيحة وتتعامل مع فشل AI دون انهيار، لكنها لم تثبت تشغيل AI الحقيقي.

**بعد B-09:** أول Vertical Slice حقيقي للأحياء: سؤال → Retrieval → Evidence → Local LLM → Answer/Sources → SQLite، على جهاز حقيقي وضمن وضع اختبار معزول.

---

# 5. نقاط التكامل بين A وB وC

## 5.1 العقود المطلوبة

| العقد | المدخل الأساسي | المخرج | المالك والتنسيق |
|---|---|---|---|
| `AuthService` | Username/Password أو Session Action | AuthSession/Typed Error | B |
| `ConversationRepository` | AuthSession وConversation/Message IDs | Saved Conversation/Message أو DB Error | B |
| `ModelRuntime` | ModelConfig/GenerationRequest | Text/Stream/Error/Metrics | A؛ B يدمجه مع Android/Flutter |
| `QueryEmbedder` | SharedEmbeddingConfig/Query | Compatible Vector أو Error | A+C |
| `Retriever` | Query/Scope/Options | Ranked RetrievalResults | C+A |
| `TutorService.ask` | Session/Conversation/Question/Request ID | `TutorResult` | A؛ B يستدعيه |
| `SourceMapper.resolve` | `pack_id+chunk_id+dataset_revision` | Metadata/Snippet أو SOURCE_UNAVAILABLE | A+C؛ B يعرضه |
| `QuizService` | Request Scope/Validated Answer | QuizSession/Scoring/Typed Error | A+C للتوليد والتحقق، B للواجهة والجلسة |
| `DownloadService` | DownloadSpec/Handle | Progress/Verified Artifact/Error | B |
| `DatasetReleaseManager` | Candidate/Manifest/Release ID | Verified Candidate/Active Revision/Error | B مع A+C |
| `PdfLibraryRepository` | Catalog/Book ID | Book Data/Local PDF Locator | B مع بيانات C |

جميع العقود تتبع مبدأ `Result<T, DomainError>`، وتُحدَّد أخطاؤها برموز ثابتة. لا ينبغي أن تفسر الواجهة نص استثناء تقني لتقرر حالة المنتج.

## 5.2 ما يحتاجه B من A

1. عقد `ModelRuntime` النهائي مع حالات Load/Generate/Cancel/Error.
2. عقد `TutorService.ask` و`TutorResult` بحالات ANSWER/REFUSAL/ERROR والأسباب.
3. طريقة ربط Flutter/Android بمحرك AI المحلي، ونوع Bridge المتفق عليه.
4. متطلبات Android ABI والمكتبات الأصلية وحالات OOM.
5. آلية إلغاء الطلب والتحقق من `request_id/account_epoch`.
6. عقد QuizService وحقول Question/AnswerSpec اللازمة للعرض.
7. نتائج اختبار نموذج LLM وQuery Embedding الفعليين؛ لا يكفي مجرد وجود ملفاتهما.

## 5.3 ما يحتاجه B من C

1. تعريف Manifest/Schema/Metadata لـRuntime Dataset.
2. ملفات اختبار أحياء مراجَعة تصلح لـ`INTEGRATION_FIXTURE_MODE`.
3. تعريف Shared Embedding Artifact/Vector Config والفهارس المتوافقة بالتنسيق مع A.
4. SourceReference Metadata وحقول درس/وحدة/صفحة، حيث تكون الصفحة مثبتة.
5. BookCatalog وروابط PDF الموثقة عند توفرها.
6. أمثلة Quiz Few-shot مراجَعة وAnswerSpec بالتعاون مع A.

لا يحتاج B إلى أن يستخرج هذه الملفات بنفسه.

## 5.4 كيف يختبر B قبل جاهزية AI؟

يُسمح باستخدام Fake implementations لعقود الخدمات نفسها في Unit/Widget/Contract Tests فقط.

مثلًا، Fake TutorService يعيد ANSWER أو REFUSAL أو ERROR ثابتة لاختبار الواجهة. وFake Resource Status يحاكي حالات التنزيل والفشل. وFake QuizService يعيد عناصر اختبارية للتحقق من العرض والتصحيح.

**هذه نتائج اختبارات واجهة وعقود فقط، وليست إثباتًا لنجاح AI أو RAG.**

عند اختبار G2/G3 تُستخدم الخدمات الحقيقية على Android، وFixture أحياء متوافقة مع Query Embedding وIndex وDataset Revision. ولا يُسمح بتفعيل Product `RAG_READY` بسبب نجاح هذه الاختبارات.

## 5.5 ترتيب التوافق بين الأعضاء

قبل دمج Chat الحقيقي، يجب الاتفاق على `TutorResult` والأخطاء والمصادر وإلغاء الطلب.

وقبل دمج Dataset الحقيقي، يجب الاتفاق على Manifest، وShared Embedding Config، وحالات الموارد، و`RevisionPinnedHandle`.

وقبل اختبار Quiz، يجب الاتفاق على QuizItem وAnswerSpec وFeedback، وألا يصبح بنك الأمثلة بديلًا للتوليد المحلي.

أي اختلاف عن المواصفة يُرفع للمراجعة الهندسية، ولا يحسم B بمفرده بتغيير سلوك المنتج.

---

# 6. اختبارات Android ومعايير قبول العمل

## 6.1 الاختبارات التي ينفذها B مستقلاً

| الاختبار | المطلوب إثباته | المعرف الرسمي |
|---|---|---|
| Build/Startup | تشغيل التطبيق والتنقل دون انهيار، وتوجيه Session الصحيح | G0/G1 وTC-24 |
| SQLite | سلامة المخطط والترحيلات وFK وPersistence | TC-15 |
| الحساب الواحد | رفض إنشاء حساب ثانٍ وقواعد Password/Session | TC-21/24/30 |
| Logout/Delete | إبطال الجلسة وحذف Owned Data مع بقاء الملفات المشتركة | TC-29/30 |
| المحادثات العشر | Draft غير محفوظ، First-message Atomic Commit، Retry/Rollback | TC-25/30 |
| التنزيلات | قطع الإنترنت، Resume/Restart، Hash، نقص المساحة، وعدم ظهور READY كاذبة | TC-16 |
| PDF | تنزيل وفتح Offline مع غياب LLM/RAG | TC-02/27 |
| واجهات Chat | عرض ANSWER/REFUSAL/ERROR والمصادر باستخدام Contract Fakes | TC-18 وجزء واجهة من TC-07 |
| Quiz UI | التصحيح المؤقت، UNDETERMINED، وعدم إنشاء QuizAttempt | TC-11/15 |
| أخطاء UI | تعذر الموارد وDB Error وإلغاء الطلب وعدم إعلان نجاح زائف | TC-28/30 |

## 6.2 اختبارات تكامل تتطلب A وC

| الاختبار | من يشارك؟ | دليل النجاح |
|---|---|---|
| Local LLM على Android | A+B | Load/Generate/Cancel وقياسات الجهاز؛ TC-20 |
| Query Embedding/Index | A+C+B | توافق Vector/Index وعدم قبول Mismatch؛ TC-13 |
| Biology RAG Slice | A+B+C | Retrieval حقيقي وإجابة ومراجع وحفظ Offline؛ G2/G3 |
| Source References | A+B+C | IDs وRevision صحيحة، وتعذر المصدر القديم يعرض صراحة؛ TC-07 |
| Full/Partial/Refusal | A+C+B للعرض | تمييز الحالات وفحوص المصادر والنتائج المرجعية؛ TC-04/05/18 |
| Quiz Generation | A+C+B | توليد أسئلة جديدة مع Validator، دون بنك فقط؛ TC-09/10/31 |
| Dataset Activation | B+C+A | عدم خلط المراجعات والمحافظة على Active القديمة؛ TC-12/26/32 |
| Offline Real AI | A+B+C | تشغيل المسار الفعلي دون شبكة ضمن شروط وضع التشغيل المخصص |

## 6.3 بوابات العمل المبكرة

**G0 — Repository Baseline:** جرد فعلي للمستودع والجهاز، مع تحديد المكونات الموجودة والناقصة دون تخمين.

**G1 — Contracts:** اتفاق على DB Schema وAuth وChat وResource/AI Interfaces قبل الاعتماد النهائي للربط.

**G2 — Android Technical Proof:** تشغيل LLM وShared Query Embedding وIndex متوافق على هاتف Android 6GB في Test/Debug Mode.

**G3 — Early Vertical Slice:** جلسة محلية مستمرة، وأول رسالة محفوظة ذريًا، وسؤال أحياء حقيقي يمر عبر Retrieval وEvidence Gate وLocal LLM ويعرض مصدرًا موثقًا Offline، باستخدام Fixture معزولة.

النجاح في G3 لا يحقق G4؛ إذ تتطلب G4 خمس Subject Packs وShared Embedder ضمن Product Active Revision.

## 6.4 أدلة الاختبارات الإلزامية

لكل اختبار يسلم B سجلًا يتضمن:

- Test ID وحالة `PASS/FAIL/BLOCKED/CANNOT_JUDGE`.
- Git Commit ونسخة التطبيق والجهاز وAndroid/ABI.
- إصدارات الموارد المستخدمة عند وجود AI/RAG.
- خطوات الاختبار والمدخلات والنتيجة المتوقعة والفعلية.
- Logs وScreenshots عند الحاجة، مع استبعاد كلمات المرور وبيانات الجلسة السرية.
- أي مشكلة مكتشفة ومالك إصلاحها.

لا تُخترع حدود RAM/Latency أو نسب نجاح. تُسجل القياسات الحقيقية أولًا، ثم تُقارن بمعايير القبول المعتمدة عند الحاجة.

---

# 7. التسليمات المطلوبة من مسؤول Flutter

## 7.1 التسليمات الفنية

1. مشروع Flutter قابل للبناء والتشغيل على Android الحقيقي، مع Git Revision معلوم.
2. تنفيذ وظيفي للشاشات `UI-01..UI-14` ضمن نطاق المرحلة.
3. SQLite/Drift Schema وRepositories وMigrations واختباراتها.
4. AuthService وKeystore-backed Persistent Session وSessionGuard.
5. نظام المحادثات العشر وFirst-message Atomic Transaction.
6. إدارة تنزيل الموارد وحالاتها والتحقق منها وفصل مخازن PDF/LLM/RAG.
7. مكتبة PDF وViewer مستقلان.
8. عقود AI/RAG وواجهة Chat والمصادر، مع توثيق ما ثبت باستخدام Runtime حقيقي.
9. Quiz UI والجلسة المؤقتة والتصحيح المحافظ ضمن ما يتيحه التكامل المراجع.
10. APK تجريبي قابل للتثبيت، وسجل اختبارات وأعطال واضح.

## 7.2 صيغة تقرير كل مهمة

عند إغلاق أي مهمة `B-xx`، يسلم B تقريرًا مختصرًا يحتوي:

**Task ID — Git Commit — Files Changed — Implemented Behavior — Tests Executed — Expected/Actual — PASS/FAIL/BLOCKED — Known Issues — Dependencies — Handoff.**

لا يُقبل وصف مثل «انتهيت من صفحة المحادثة» دون تحديد الوظائف المنفذة ونتائج اختبارها.

## 7.3 متى نعتبر عمل B مكتملًا؟

**اكتمال مهام B المستقلة** يعني أن التطبيق وقاعدة البيانات والحسابات والمحادثات وواجهات الموارد وPDF وعقود التكامل اجتازت اختبارات الوظائف المطلوبة بالأدلة.

**اكتمال تكامل Biology Pilot** يتطلب أيضًا اختبار G2/G3 على الهاتف الحقيقي بمشاركة A وC، مع عدم وجود عيوب حرجة تمنع المسار التجريبي.

إذا لم يكن LLM أو Dataset أو بنك الأمثلة المراجَع جاهزًا، يسلم B ما أنجزه ويصنف التكامل المعتمد عليها `BLOCKED`، بدل تحويل Fake Test إلى نجاح فعلي.

ولا يُعد ذلك إعلانًا باكتمال P0 النهائي.

---

# 8. أمر العمل الأول لمسؤول Flutter — ابدأ الآن

## التكليف: B-01 — فحص بيئة Flutter والمستودع وتشغيل النسخة الحالية على الهاتف

**الهدف المباشر:** إثبات أن بيئة Windows وFlutter وAndroid SDK والهاتف جاهزة، ومعرفة حالة مشروع SIRAJ الفعلية قبل تعديل أي ملف.

**المالك:** B  
**المهمة الرسمية المرتبطة:** TK-00  
**بوابة التحقق:** G0  
**المطلوب الآن:** نفذ الخطوات التالية بالترتيب، ولا تبدأ إنشاء مشروع جديد تلقائيًا.

### الخطوة 1 — فحص أدوات التطوير

افتح PowerShell أو Terminal داخل Windows، ونفذ:

```powershell
flutter --version
flutter doctor -v
flutter devices
adb version
adb devices -l
```

تحقق من أن Flutter والأدوات تعمل، وأن الهاتف ظاهر ضمن الأجهزة.

إن لم يعمل `adb` من PATH، حدد مكان `platform-tools` داخل Android SDK واستخدم ملف `adb.exe` الموجود بالفعل.

إذا ظهر الهاتف `unauthorized`، وافق على USB Debugging Authorization من الهاتف، ثم أعد فحص الاتصال.

### الخطوة 2 — معرفة مواصفات الهاتف الحقيقية

بعد التأكد من الاتصال، نفذ:

```powershell
adb shell getprop ro.product.manufacturer
adb shell getprop ro.product.model
adb shell getprop ro.build.version.release
adb shell getprop ro.product.cpu.abi
adb shell cat /proc/meminfo
adb shell df -h /data
```

إذا كان أكثر من جهاز متصلًا، استخدم `adb -s DEVICE_SERIAL` لتوجيه الأوامر إلى الهاتف المقصود.

سجل الشركة والطراز وAndroid Version وCPU ABI والذاكرة والمساحة المتاحة.

هذه البيانات مطلوبة لاحقًا عند اختبار Local LLM وNative Libraries، ولا ينبغي تخمينها.

### الخطوة 3 — فحص ملفات مشروع SIRAJ

إذا توفر مجلد المشروع، افتحه ونفذ:

```powershell
Get-Location
Get-ChildItem -Force
Test-Path pubspec.yaml
Test-Path android
Test-Path lib
git status --short
git rev-parse HEAD
```

أوامر Git تنفذ داخل مستودع Git فقط؛ إذا لم يكن المجلد مستودعًا، سجّل ذلك ولا تستنتج وجود Revision غير موجود.

افحص خصوصًا:

- `pubspec.yaml` لمعرفة Dependencies وFlutter SDK constraints.
- `lib/main.dart` ونظام التنقل الموجود.
- مجلدات Widgets/Screens/Services/Repositories.
- وجود Drift وSQLite وملفات Migrations.
- `android/app/build.gradle` أو `build.gradle.kts` و`AndroidManifest.xml`.
- وجود أي Platform Channels/FFI/Native Libraries.
- مجلد `test/` واختبارات التشغيل.

صنف كل مكون إلى: موجود ومتحقق، موجود غير متحقق، جزئي، غير منفذ، أو غير معروف.

**إذا لم يكن هناك مستودع أو مشروع رسمي متاح، يسجل B هذه الحقيقة ضمن TK-00 ولا ينشئ بديلًا على أنه SIRAJ الرسمي.** يستمر في فحص بيئة Android، وتُحسم هوية المشروع ومساره مع قائد الفريق.

### الخطوة 4 — محاولة تشغيل النسخة الموجودة

إذا ثبت وجود مشروع Flutter صالح، ولا توجد مخاطر تعديل غير مقصود على ملفات المشروع، نفذ من جذره:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d DEVICE_ID
```

استبدل `DEVICE_ID` بمعرف الجهاز المعروض في `flutter devices`.

`flutter test` يختبر الاختبارات الموجودة، إن وجدت؛ عدم وجود اختبارات ليس نجاحًا لها.

لا تبدأ بـ`flutter clean` أو حذف ملفات المشروع أو تحديث Dependency Versions عشوائيًا. عند فشل Build، سجل الرسالة الفعلية ثم أصلح مشكلة البيئة أو التوافق المحددة فقط بعد فهم أثرها.

### الخطوة 5 — التحقق من النجاح

تعد مهمة فحص البيئة ناجحة عندما:

1. يتعرف ADB وFlutter على الهاتف.
2. تكون معلومات Android/ABI/RAM/Storage موثقة.
3. تكون حالة المستودع والملفات والاعتماديات معروفة أو مصنفة صراحة كغير متاحة.
4. تكون محاولة Build/Run موثقة بنتيجة حقيقية.
5. إذا وُجد مشروع قابل للبناء، يتم تشغيله على الهاتف دون Crash عند بدء التشغيل.
6. تُسجل الأخطاء الحالية دون إخفائها أو وصفها بأنها أُصلحت.

**مهم:** نجاح G0 لا يشترط أن يكون التطبيق الأصلي مكتملًا. إذا لم توجد شيفرة أو كانت غير قابلة للبناء، يمكن إغلاق الجرد ببيان العائق، لكن اختبار تشغيل التطبيق يبقى `BLOCKED` حتى المعالجة.

### الخطوة 6 — ما الذي يسلّمه B لرئيس الفريق؟

يسلم تقريرًا بعنوان:

`SIRAJ Flutter Preflight — TK-00`

ويتضمن:

- إصدار Flutter/Dart/Android SDK الفعلي.
- بيانات الهاتف وADB/ABI.
- حالة المستودع وGit Revision عند توفره.
- قائمة الملفات والمكونات الموجودة.
- نتيجة Flutter Analyze/Test/Run.
- الأخطاء والعوائق ونقاط العمل الناقصة.
- التوصية المباشرة بما يجب تنفيذه ضمن B-02.

يرفق Logs/Screenshots المناسبة دون نشر Secrets أو ملفات حساسة.

## المهمة البرمجية التالية مباشرة: B-02

بعد إتمام فحص الموجود، ينتقل B إلى **تهيئة أساس التطبيق وتشغيل رحلة التنقل الأولى على الهاتف**.

المطلوب برمجيًا هو إكمال `main.dart` وApp Bootstrap وAuth Gate وNavigation وRTL وفق هيكل المشروع الحقيقي، مع إظهار حالة الحساب والموارد دون ادعاء توافر AI.

أول معيار نجاح برمجي لهذه المهمة: يفتح التطبيق على الهاتف، ويفحص وجود الحساب والجلسة بصورة صحيحة، ويوجه إلى شاشة البداية المناسبة، ويستطيع الانتقال بين الشاشات الأساسية المتاحة دون Crash أو تجاوز المصادقة.

لا يحتاج هذا الإنجاز إلى انتظار LLM أو Dataset الأحياء.

---

## قاعدة ختامية لإدارة العمل

يبدأ B بـB-01، ثم ينفذ المهام بالترتيب المحدد مع مراعاة الاعتماديات. وعند اكتمال كل مهمة يسلّم Git Commit ونتائج الاختبار ويعلن بوضوح ما اكتمل وما بقي معلقًا على A أو C.

**الأولوية الأولى هي تطبيق حقيقي يعمل على Android، والأولوية التالية هي تكامل Chat/RAG الحقيقي للأحياء، وليس الانتهاء الشكلي من جميع الواجهات.**

يحافظ B طوال العمل على قابلية إعادة استخدام التطبيق ضمن SIRAJ P0 النهائي، دون أن يدّعي أن تجربة الأحياء تحقق شروط إنتاج المواد الخمس.

**حالة هذه الوثيقة:** خطة عمل تنفيذية مقترحة ومتوافقة مع المواصفة الرسمية؛ تُخصص مسارات الملفات وحالة المهام الفعلية بعد TK-00، ولا تمثل دليل تنفيذ أو نجاح اختبارات.
