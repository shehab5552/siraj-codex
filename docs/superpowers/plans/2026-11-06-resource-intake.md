# STAGING resource intake and existing B-07 verification

> Execute inline using superpowers:executing-plans; independent Standards and Spec review before delivery. The user's detailed intake request authorizes this scope.

**Goal:** Audit the five pinned STAGING release artifacts, preserve the existing transport, and report real integration blockers without activating resources.

**Architecture:** Reuse DownloadService, its separate validators, and existing contracts. Add read-only developer intake tooling and adversarial tests; do not introduce a second application downloader or production catalog. Binaries stay in an app-independent private inspection directory.

**Tech stack:** Flutter3.38.5/Dart3.10.4, existing project dependencies; Python standard library for offline archive/manifest audits; JDK javap/readelf for binary inspection. Kotlin2.2.20 compiler is a verified external inspection tool only.

**Spec:** `docs/spec/RESOURCE_INTAKE_USER_REQUEST_2026-11-06_AR.md`, corrected P0 and revised Team B plan.

## Constraints and preflight

- Work only in siraj-codex. main/base651af0d62d05761c80d9a8cbc9d1f51b836929eb is verified. Reuse existing requested branch `codex/b07-independent-download-01` at27ff8e5265e03092ccf84fedeae39d5bb4d008a7 and existing open PR3; do not reset it or duplicate its implementation. Do not merge PRs.
- Five release assets match the owner's exact sizes/SHA256 in actual downloads outside application files. Record these pins only as developer STAGING evidence, never as production resource IDs/configuration.
- Baseline pub enforced/analyze/full Flutter tests passed184/0/0. All seven requested reference files were read before edits.
- No Auth/PBKDF2/Keystore/Chat/Quiz/SQLite schema/Gradle changes. No binaries, models, ZIPs, generated scientific data or production activation.
- Binary AAR has Java major65 and Kotlin metadata2.4.0; current Kotlin2.2.20 direct-consumption compile probe fails on metadata version (without bypass flags). This blocks that integration path; do not silently upgrade the project or classify a model as runtime-compatible.
- `.litertlm` is not GGUF. Existing LLM format policy remains fail-closed. Biology Units01/02 are a pilot, never the five-pack production candidate.

## Review focus

- Malformed/duplicate-key/invalid UTF-8 or oversized metadata cannot be accepted.
- Nested ZIP traversal, links, duplicates, CRC corruption, expansion budgets and internal checksum mismatches fail without extracting or replacing active files.
- Byte/hash/header checks are distinct from model execution, Android parity, dataset identity and scientific approval.
- Document absent configuration and conflicting/provisional declarations; never fill them with inferred defaults.
- No credential values or signed redirects appear in committed reports or CI artifacts.

## Task1: Read-only intake audit

Files: `tool/resource_intake/`, `tool/resource_intake_audit.py`, `tool/tests/test_resource_intake.py`.

- [x] Add owner-provided staging pins, bounded strict manifest/release validation, recursive ZIP/CRC/checksum audit and observed Biology structure/vector checks.
- [x] RED then GREEN tests for corrupt ZIP, traversal/absolute/backslash/link/duplicate members, expansion limits, invalid JSON/UTF-8/duplicate keys, size/hash mismatches, staging-only status and preservation of an existing resource.
- [x] Run the same audit on all actual verified artifacts; keep PASS/FAIL/BLOCKED/NOT RUN/PENDING DEVICE TEST separate.

## Task2: Actual binary and existing-validator evidence

Files: `tool/staging_resource_integrity_probe.dart`, curated evidence under `docs/qa/`.

- [x] Invoke the existing ArtifactIntegrityValidator/ResourceFormatPreflight on the three actual supported resource kinds without inventing an Android-runtime DB kind.
- [x] Inspect actual AAR manifest, classes.jar APIs, native ABI/dependencies, license/consumer metadata, and compiler compatibility. No model/runtime execution or app Gradle dependency is added.
- [x] Inspect bounded LiteRT-LM container metadata against pinned upstream0.19.0 schemas; report remaining tokenizer/pooling/config/device checks explicitly.

## Task3: Regression and Android transport boundary

Files: `integration_test/b07_download_storage_test.dart`, `.github/workflows/b07-resource-intake-verification.yml`.

- [x] Preserve and rerun existing real TLS transport regression cases covering success/interruption/resume/range/ETag/pause/cancel/IO/provenance/integrity/active-resource safety.
- [x] Add native Android tests for actual private-directory free space and outside-path rejection; no AI AAR is loaded or linked.
- [x] CI runs pinned SDK/lockfile/analyze/full Flutter/Python checks and isolated Android storage tests, with only small evidence outputs published. Physical device/model loading remain pending.

## Task4: Review and delivery

- [x] Run changed Dart format, full tests, diff review and two independent review axes; fix concrete findings.
- [x] Write all16 required report sections in `docs/reports/B-07_RESOURCE_INTAKE_AND_DOWNLOAD_01_AR.md`, link current evidence and update dated readiness notes.
- [x] Commit/push requested existing branch, update PR3 for review, record actual CI and exact errors. No merge and no automatic runtime integration/RAG activation.
