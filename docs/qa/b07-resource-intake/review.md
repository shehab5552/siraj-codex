# Independent review evidence

Scope: `651af0d62d05761c80d9a8cbc9d1f51b836929eb...f3b42107944cd9d7059e97a97eabf1e1d517010b`, emphasizing the intake delta after `27ff8e5265e03092ccf84fedeae39d5bb4d008a7`. Two isolated, read-only reviewers followed the code-review skill. Working-tree fixes were reviewed separately before delivery. Neither reviewer edited files or accessed another SIRAJ repository.

## Standards

One P2, resolved: `DownloadStaging.checkpointFor` used the last duplicate JSON
value, allowing `complete:true` followed by `complete:false` to hide the
completion guard. Independent reproduction with the actual service showed
immediate Cancel deleting the completed candidate; the valid-checkpoint control
preserved it. This violated the documented conservative completion/provenance
boundary.

The correction detects duplicate decoded string keys after syntax validation,
including `\u0063omplete`, and throws protected
`candidateExists / ambiguousProvenance` before any resume/discard decision.
Returning null would have retained the deletion flaw. Three new local TLS
regressions cover literal/escaped completion and duplicate identity, no HTTP or
payload replacement, cancellation after failure and immediate cancellation.
Literal and escaped cases failed RED before the fix. The independent reviewer
replayed all variants via isolated Dart: payload preserved; finding resolved.

No remaining substantive Standards findings. Inspection tools remain outside
application readiness and activation paths; archive budgets and OS isolation
limitations are documented.

## Spec

No additional actionable findings against the complete owner request.
The reviewer verified separation of byte integrity, demonstrated AAR compiler
failure, unproven runtime/device compatibility, pilot identity/science gaps and
activation prohibitions. Native tests/workflow definitions were not treated as
executed proof. The reviewer independently ran Python30/0 after the supplemental
DEFLATE fix.

## Additional verified correction

A generated malformed DEFLATE stream produced raw `zlib.error` (RED); the audit
now maps it to `IntakeError('invalidZip')` (GREEN). Original stored-data CRC tests
remain. Current complete local results after corrections: Flutter187/0/0,
Python30/0/0, enforced lockfile and analyze PASS. Runtime inference, G2/G3 and
physical-device tests remain unproven; CI/native status belongs in the report.
