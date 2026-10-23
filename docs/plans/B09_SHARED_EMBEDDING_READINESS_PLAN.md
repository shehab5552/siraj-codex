# B-09 Shared Embedding Readiness Implementation Plan

> For agentic workers: execute inline using superpowers:executing-plans; use test-first feature changes and final independent review.

**Goal:** implement the missing shared QueryEmbedder lifecycle around the existing B09 QueryEmbedder/EmbeddingBinding contract; document exact remaining production/G2/G3 inputs.
**Architecture:** one immutable configuration per revision; shared RuntimeOperationLane extracted from the already-tested ManagedModelRuntime instead of copying cancellation/drainage logic; real B07 byte validation before injected embedding backend load. No native runtime selection, model approval, scientific normalization/threshold policy or product readiness claim.
**Tech stack:** Flutter3.38.5/Dart3.10.4, existing cryptography/UUID/validators; no new packages.
**Spec:** approved cloud handover P0 v1.0.1 §§6.6,7.4.1,9.4,10.3; TC13/20/26/32. Prior docs/architecture/B09_AI_INTEGRATION_CORE.md remains authority for existing ports.

## Constraints and review focus
- Branch codex/b09-shared-embedding-readiness from PR7@dd1d7c42af0ef0d727c9ae6b70dfdfc17d53b994; PR targets PR7 branch. No PR merges/main/Auth/original repository/PC access.
- B12 and B09 both define handles in separate layers and have separate unmerged ancestors. Do not copy or merge their branches to manufacture integration. This delivery uses B09 ports; B12 coordinator will be a separate PR based on PR9.
- All resource identities/config/hashes supplied explicitly; unavailable backend by default; no HTTP in embedding; no fixture outside tests; no scientific vector normalization or numeric thresholds selected.
- Test cancellation/timeout while backend/cancel drainage stalls; no unload or second request before actual idle. Failed/partial load retains caller-owned file lease until successful unload.
- Test exact binding/runtime identity and every sidecar artifact hash, dimension/finite output, unsafe paths, backend errors/OOM and successful unload/reload recovery. Never silently fallback across revisions.

## Task1: Shared runtime lane and embedder
Files: create lib/integrations/ai/runtime_operation_lane.dart, shared_embedding_runtime_contract.dart, managed_query_embedder.dart; modify managed_model_runtime.dart only to reuse lane; create test/b09_managed_query_embedder_test.dart and support fixture.
Interfaces: RuntimeOperationLane.run<T>(external,work,{requestId,onCancel}), requireIdle/whenIdle/cancel; SharedEmbeddingConfig(binding,artifactRoot,runtimeId,artifacts); EmbeddingBackend.load/embed/cancel/unload; ManagedQueryEmbedder implements existing QueryEmbedder with fixed binding, load/embed/unload/whenIdle/state/metrics.
- [ ] Write failing lifecycle/integrity/cancel/output tests against new embedder API; verify absent behavior RED.
- [ ] Extract operation lane preserving existing model public behavior, run existing model regression.
- [ ] Implement immutable config, B07 integrity checks and backend identity checks; reject unsafe/duplicate/missing/main-file expectations; implement finite/dimension vector validation and fail-closed typed errors; GREEN focused.
- [ ] Add cancellation/timeout/drainage/recovery and pinned retriever consumer tests; run all tests/analyze, fix any failures.

## Task2: Evidence/readiness and delivery
Files: docs/architecture/B09_SHARED_EMBEDDING_RUNTIME.md, docs/reports/B09_PRODUCTION_INTEGRATION_READINESS_AR.md, docs/qa/B09_SHARED_EMBEDDING_2026-10-24.json; phase-specific CI.
- [ ] Matrix runtime revision/license/ABI/build hash, LLM identities/context/tokenizer/profile, embedding files/config, dataset/index/source mapping/gold vectors with approved tolerances, semantic policies, Auth conflicts and Android G2/G3 acceptance. Mark missing/contract-only/proven separately.
- [ ] Enforced pub get/analyze/full test, independent spec/standards review; important findings RED→GREEN; no fabricated Android proof.
- [ ] Commit/push/PR to PR7 branch, inspect CI, report exact SHAs/test counts/network errors/limits. Keep next B12 coordinator isolated.

Ledger: approved user explicitly requested actual implementation without stopping for a plan approval; existing spec/design decisions remain fixed. Approach is my implementation choice, not a new approved runtime/scientific policy. Pre-flight: embedder and model consume the same operation lane/error vocabulary; no B12 type imports. Baseline tests run before implementation. All raw logs remain in /tmp/siraj-next-20261024/b09.

Review ledger: two independent axes flagged a possible idle/state microtask-order issue on tree95a6297. Reproduction against that exact pre-fix implementation PASSED three public-seam tests (chained inference after embed/load and synchronous observed state), so no runtime failure is claimed. Ruling: make owner success/failure state publication an explicit synchronous lane hook before logical settlement, as a behavior-preserving refactor that removes reliance on callback scheduling. Cost if wrong: lifecycle ordering regression; existing model and new chained-operation tests must remain green. Initial asynchronous RED attempt was contaminated by a concurrent source edit; excluded from failure evidence. The verified reruns are retained verbatim. No fabricated RED→GREEN defect claim.
