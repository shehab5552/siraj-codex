# SIRAJ P0 — B-07 Step 3: Resource Validation Contracts

**Status:** Prepared for Flutter analyze/test; not production approved.

## Scope

Two pure domain-level contracts, with zero I/O, database writes, network calls, or readiness setters:

1. `ResourceValidationRequirements`: required evidence *names* per resource. LLM requires transfer/hash/format/runtime/device/load proof; RAG packs require hash/secure unpack/schema/reference/index; shared embedder requires model/hash/config/vector/Android query; PDF requires readability and catalog SHA-256 if supplied.
2. `RagCandidateContract`: checks production manifest *structure* only: exactly five expected subjects, no duplicate/missing/extra pack, one shared embedder, single dataset revision, matching embedding identity and dimensions, and index type/version.

`ResourceEvidenceInventory.evidenceListComplete` does **not** verify files or imply READY. `RagCandidatePreflightResult.structureConsistent` does **not** imply ACTIVE/RAG_READY. In particular this is NOT an implementation of FR-12, FR-22 or atomic activation, nor is the Biology pilot eligible for production RAG_READY.

## Boundaries and follow-up implementation

- The `expectedSubjectIds` must eventually come from the approved product catalog; IDs in test fixtures are not production IDs.
- Hash checks, archive path defenses, PDF parse/read, LLM runtime load, Android query and embedding config require real specialized validators in later tasks.
- No new SQLite tables/columns, no dependencies, no changes to prior app UI, no bypass of auth, no write to `READY` or `ACTIVE`.
- Keep `recordUnverified` as-is; NEVER map `evidenceListComplete` or `structureConsistent` to a DB state.
- For real RAG activation, only a complete verified production candidate goes to immutable release promotion and a single atomic active pointer switch (§10.3). Old release must remain intact on failure.

## SIRAJ specification references

- DD-01/02/03; FR-12/21/22; §10.1-§10.5; TC-12/13/26/27/32.
- `INTEGRATION_FIXTURE_MODE` for early Biology G2/G3 remains isolated and must not set `RAG_READY`.

## Validation

```powershell
Set-Location "D:\SIRAJ\App Flutter"
dart format lib/features/resources/resource_validation_contracts.dart lib/features/resources/rag_candidate_contract.dart test/b07_validation_contracts_test.dart
flutter analyze
flutter test
```

Expected: 71 previous tests + 18 new tests = **89 total**, subject to real Flutter output. Do not commit before checking.
