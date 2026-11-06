# STAGING inspection tools

These tools are developer audits, separate from the app's DownloadService,
production catalog and validators. They cannot set READY, ACTIVE or RAG_READY.
Pins are copied from the owner's intake request, not learned from downloaded
metadata. No model, ZIP, AAR, content text or generated scientific data belongs
in Git. No new dependency is required (Python standard library / existing Dart
packages only).

The application staging fix in this delivery rejects duplicate decoded JSON
keys as protected `candidateExists/ambiguousProvenance`. It preserves the
candidate even during cancellation, since a conflicting completion marker must
not authorize deletion. Other existing malformed-partial restart policies stay
covered by the transport regression suite.

Use a private, quiescent directory outside application files:

```sh
python3 -B -m unittest discover -s tool/tests -v
python3 -B tool/resource_intake_audit.py /PRIVATE/STAGING --release-json /PRIVATE/release-api.json
dart run tool/staging_resource_integrity_probe.dart /PRIVATE/STAGING /PRIVATE/dart-evidence.json
```

Obtain release metadata and files using the official GitHub workflow for
`shehab5552/siraj-codex`, tag `siraj-ai-resources-staging-v1`. Do not commit signed
redirect URLs or credentials. `validate_release` compares tag, prerelease state,
asset count, names, sizes and API digests to independent owner pins. Then each
actual file is streamed and hashed before structured inspection.

The Python tool reads archives in memory without extracting, following links,
writing an app database or replacing resources. It rejects unsafe names, special
files, duplicate paths, file/directory aliases, encryption, bad CRC, bad checksums
and configured expansion/depth/member limits. Defaults are 128MiB expanded,
4096 entries, nesting depth3; these are inspection budgets, not approved runtime
limits. It is not a sandbox against malicious OS-level actors: use a trusted
private directory with no concurrent writers. Central-directory parsing happens
inside stdlib zipfile before the entry budget is checked; do not treat the tool
as a general public upload endpoint.

Biology checks all supplied checksum lists and final-manifest file registries,
strict JSON/JSONL, vector byte dimensions, finite/nonzero values, row order,
unique chunk IDs and model/index/content binding. Absent predecessor archives
are reported, never reconstructed. It does not approve evidence-selection rules,
map catalog IDs, create a pack reader, compute query embeddings or validate
scientific truth. Near-unit vector norms do not prove an approved normalization
policy or Android numerical parity.

The Dart probe calls the existing ArtifactIntegrityValidator and
ResourceFormatPreflight directly. PASS refers to size/hash only. Qwen's
LiteRT-LM header is intentionally unrecognized by the current GGUF-only LLM
preflight. Embedding and ZIP require specialized validators. Exit0 does not mean
format/runtime compatibility or application readiness; inspect individual fields.

See `docs/reports/B-07_RESOURCE_INTAKE_AND_DOWNLOAD_01_AR.md` and the small
evidence files under `docs/qa/b07-resource-intake/` for actual observations.
