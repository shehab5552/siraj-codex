# B-09: offline AI integration core

This implements the owner's approved full-development request (23 October 2026),
P0 v1.0.1 §§5.3–5.5, 6.6–6.8, 8.3–8.7, 9.4–9.5.1, TC03/04/07/08/13/20/32,
and revised Team B B-09/TK-13. The supplied official specification SHA256 is
084d2f3ece9373dacc3795fb35bed99ee36ebbdbb9ba139d5cca9d0daa5727d8.

## Scope and design

Reuse B-08 TutorPort, SourceResolverPort, cancellation/result/error DTOs and
ChatTurnCoordinator unchanged. Add a concrete tutor orchestration adapter,
revision-pinned retrieval/configuration validation and a bounded model lifecycle
owner. Runtime, scope, evidence decisions, approved prompt profile and output
validation are injected at explicit ports. No score threshold, tokenizer,
model, prompt profile or semantic decision is invented. There is no permissive
production fallback. Native bindings require an approved, pinned runtime build;
none is provided by the handover. No new MethodChannel ABI or FFI ABI is guessed.

Retrieval uses the pinned shared embedder and compatible index, validates vector
shape/finiteness and resolves every hit in that same revision. History goes to
scope/prompt processing only; each question performs fresh retrieval. Evidence
must select a subset of resolved hits; sources never come from generated text.
Partial answers must remain explicitly partial. Deterministic validation is not
proof of semantic grounding. Reference validation does not imply science QA.

The lifecycle owner serializes load/generate/unload. Logical cancellation or
watchdog expiry may settle the caller, but never releases the backend lane until
its actual operation settles. A noncooperative backend keeps the lane occupied;
no concurrent unload or new request touches its memory. Recovery requires an
explicit unload after drainage. The tutor also retains its revision lease until
all outstanding work has drained, even if its caller cancels first.

Product handle validation requires the existing five-pack RagCandidateContract
and full embedding/index binding equality, including artifact revision and
preprocessing. Debug/test fixture mode may use one pack; it is rejected outside
Debug and never writes ResourceStatus or active_dataset_revision. Provider
implementations must verify files with existing B-07 validators, keep immutable
private paths and retain actual runtime/index handles; declarations alone are
not a resource validator or readiness authority. This slice adds no activation.

## Tests and limits

All synthetic text/vectors/backends live in test/support only. Tests exercise
actual orchestration, lifecycle, contract checking and SQLite conversation
persistence, including cancellation and stale replies. Normal AppBootstrap
remains unavailable/fail-closed. No shipped fake dataset or educational answer.
No Auth gate changes, schema changes, HTTP calls, PDF or Quiz coupling.

G2/G3 still require reviewed Biology chunks, shared embedding plus matching
index/config, independent LLM, approved runtime/prompt/evidence implementations,
known-vector tolerance and Android device evidence. Linux tests, injected test
doubles and a compiled APK cannot certify these gates.
