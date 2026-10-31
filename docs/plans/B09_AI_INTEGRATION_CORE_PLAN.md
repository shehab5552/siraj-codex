# B-09 AI integration core implementation plan

> Execute inline with superpowers:executing-plans. The owner explicitly authorizes implementation, commits, pushes and stacked PRs; no merge or new approval stage.

**Goal:** connect the existing B08 ports to an offline, fail-closed AI pipeline without inventing runtime/model approval.
**Architecture:** see ../architecture/B09_AI_INTEGRATION_CORE.md. Three testable slices: runtime ownership; revision-pinned retrieval; tutor/source integration with existing SQLite coordinator.
**Tech:** Flutter3.38.5/Dart3.10.4; existing packages only.
**Spec:** official P0 v1.0.1 §§6.6–6.8,8,9 and revised B09/TK13, plus user's 23October resume directive.

## Constraints / review focus

- No merges, original repository or PC access; no Auth changes or fake readiness.
- Cancel/timeout must not free native memory while a backend still runs.
- Exact revision/model artifact/tokenizer/pooling/normalization/dimension/index binding; reject nonfinite vectors and unsafe source identities.
- No model-created references, history-as-evidence, partial-as-full or late SQLite writes.
- Product five-pack checks remain independent from Debug fixture mode.
- Unavailable old source revisions never resolve to new content.

## Task 1 — ModelRuntime lifecycle

Create runtime_contract.dart and managed_model_runtime.dart; test/b09_model_runtime_test.dart.
Interfaces: ModelConfig, ModelCapabilities, GenerationRequest, RuntimeFailure, ModelRuntime, ModelBackend; reuse TutorCancellation.
- [x] Write tests for load/generate/busy/unload, malformed configuration/capabilities, cancellation/timeout with delayed backend completion, typed errors and recovery.
- [x] Run RED against minimal contract scaffold, implement lifecycle and run GREEN.

## Task 2 — Revision-pinned retrieval

Create rag_runtime_contract.dart and pinned_retriever.dart; test/b09_pinned_retriever_test.dart.
Interfaces: EmbeddingBinding, DatasetRuntimeConfiguration, QueryEmbedder, IndexPort, DatasetProvider/RevisionPinnedHandle, RetrievalHit.
- [x] Write RED tests for fixture/product validation, complete preprocessing identity, vector and hit validation, missing metadata and cancellation.
- [x] Implement using existing RagCandidateContract for product structure and test GREEN. No publication or DB changes.

## Task 3 — Tutor integration

Create tutor_pipeline_contract.dart and pipeline_tutor_port.dart; test/b09_pipeline_tutor_test.dart and test/b09_chat_pipeline_persistence_test.dart.
Interfaces: ScopeResolver, EvidenceGate, TutorPromptBuilder, AnswerValidator; consume runtime/retriever and implement existing TutorPort/SourceResolverPort.
- [x] Write RED tests for fresh retrieval, evidence decisions, output source validation, revision pinning, cancellation/lease retention, runtime errors and source resolution.
- [x] Connect real ChatTurnCoordinator/SQLite with test-only backends and verify USER-first, follow-up, logout/delete/cancel and no fabricated persisted answer.
- [x] Run enforced pub get, analyze, full/focused tests; review full diff independently; record actual Android limitations and A/C inputs.
- [x] Commit/push and PR targeting codex/b08-independent-chat-tutor; then move to the next independently implementable task, with separate branch/PR.

## Execution ledger

- Baseline main651af0d, B08 head306b3a69bb855a49b3bf01bbb1b6bd30a1c087f5; PR3–6 open, PR2 merged.
- Ruling: user explicitly requests implementation without approval pauses; apply approved P0 contracts and document unresolved runtime choices, rather than inventing a new runtime/native ABI. Cost if wrong: adapters may need adjustment when A freezes the implementation, while UI/SQLite ports remain stable.
- Baseline first native-hook download failed DNS for github.com (no HTTP status), verified cached sqlite3 binary SHA256 b17729184e5a2818055ecbddd5ed6642521bfe6e56aafa472330e483c0e2e0d2 reused without dependency changes; rerun recorded separately.

- Task1/2/3 complete for this core scope: runtime11→12, retrieval26, pipeline20→21, SQLite5; total64 new tests,261 regression tests after fixes.
- Final spec review: P2 logical cancellation drainage finding fixed by stalled-cancel regression RED→GREEN.
- Final standards review: the same cancellation issue and source-read shutdown tracking fixed by independent public-seam regressions; no critical findings or deferred minors.
- A short80ms load+generation fixture watchdog proved flaky under parallel native file hashing; changed test budget to2s, without changing runtime defaults or production policy.
- A source cleanup regression first failed; final close tracks source acquisition/read/lease closure. Native cancellation regression uses a backend that completes generation from its still-pending cancel call; the earlier instant-completion fixture did not model that defect correctly and was corrected.
- Final full261/0/0, focused64/0/0, enforced pub and analyzer clean. Detailed command/time/hash evidence in docs/qa/B09_CLOUD_VERIFICATION_2026-10-23.json.
- Next independent task: B11 RAM Quiz UI/typed contracts/scoring; its backend stays unavailable until real validated LLM-generated items exist. B10 needs trusted BookCatalog/reader and B07 integration; no PDF or five-pack work gates Biology G2/G3.
