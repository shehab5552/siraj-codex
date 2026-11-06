# LiteRT-LM header schema provenance

`litertlm_header_schema.fbs` is copied without structural changes from
google-ai-edge/LiteRT-LM, release0.19.0, commit
`83ce6067f2e2a3fb697556928f93936693ded971`, path
`schema/core/litertlm_header_schema.fbs`. Its original copyright/license header
is retained. It is a model-container schema, not an invented RAG pack schema.

Bindings use official flatc25.9.23, Linux g++ release asset SHA256
`de0c6ad114a5a686ecf64322528c602c7d4512446a93f290f54f00ee5abea487`.
The Dart runtime is pinned to `flat_buffers: 25.9.23` (package archive SHA256
`7c1de2d6eb5f3e61e5c50040841109f509deaaf2b12ec0d57b92456d9ea50345`),
compatible with the project's Dart3.10.4. This is the only new Dart dependency.
It provides schema readers/builders rather than a second hand-written binary
interpretation. Bounds/budgets, role requirements, payload checks and runtime
requirements are enforced by the specialized validator.

Regenerate with the pinned compiler, then the project's formatter:

```sh
flatc --dart --gen-object-api -o lib/features/resources/litertlm_schema lib/features/resources/litertlm_schema/litertlm_header_schema.fbs
dart format lib/features/resources/litertlm_schema/*generated.dart
```

The generated ignore_for_file list additionally names
`unnecessary_library_name`, `unnecessary_brace_in_string_interps` and
`unnecessary_non_null_assertion`: Dart3.10-only style/promoted-nullability
diagnostics in legacy-compatible generator output. This does not suppress
runtime, type, metadata-compatibility or authored-code diagnostics.

The validator bounds header reads to1MiB, aggregate metadata/section entries,
and tokenizer/protobuf material to16MiB. These are parser safety budgets, not
scientific thresholds, production model choices or resource-readiness policy.
It validates container structure/section encoding and TFLite signatures/root
bounds; it does not validate every tensor, execute tokenizers or prove model
load. Runtime/device/embedding-parity gates remain outstanding.

`ArtifactIntegrityMatch.matchesFileSnapshot` binds the subsequent parse to the
same private-file snapshot. The download coordinator retains its existing lease
through both passes. Ordinary stat/path checks are not an OS-level defense
against an adversary who can modify application-private files.
