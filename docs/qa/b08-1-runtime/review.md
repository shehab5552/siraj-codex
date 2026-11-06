# B-08.1 independent review

Scope: delta from `33c335485b959a394130f92940027ccaa9045729` to
`4951875ae5ce09ff5ff396fca827428ab4f58de8` in PR14's existing branch.
Approved request: B-08.1 Runtime Lifecycle Hardening, supplied by the owner.
Two isolated read-only review axes; reviewers did not run tests or edit files.
Execution results are recorded separately in local-results.json and android-results.json.

## Standards axis

- Found post-cancel text suppression could truncate a normally completed answer.
  Added a prefix+suffix test, observed RED, then preserved text until Native terminal.
- Verified worker serialization/CAS, sanitized errors, SDK exception mapping,
  retained embedding reference and no unsafe native-delete retry.
- Re-reviewed process-owner monitor acquisition/release; no remaining concrete
  race/deadlock or ownership finding. Narrowed the failed-close comment to
  Embedding (LLM close retains its existing separate behavior).
- Named the selective test argument `embedding-only`; unknown arguments fail.

## Specification axis

- Found Activity recreation could bypass instance-only Busy while a prior
  generation waited for its missing terminal. Added a deterministic two-manager
  RED test and process-lifetime ownership; GREEN after correction.
- Confirmed cancel API acceptance is not terminal, callback-then-throw is failed,
  actual normal/failure outcomes remain truthful, and stale/duplicate callbacks
  cannot terminate a later request.
- Confirmed failed embedding close retains ownership across disposal/Activity
  replacement, prevents use/replacement/retry, and allows process-end recovery.
- Final evidence files deliberately trigger CI on their commit, rather than
  adding workflow path exclusions that would leave the final SHA unverified.
- Follow-up end-to-end review found Tutor could finalize cancellation on a late
  chunk and Coordinator could overwrite operational failure. Added failing
  delayed-terminal/error/persistence tests, then drained through terminal and
  the cancel reply, preserving errors. Both axes re-reviewed this correction.
- Final read-only pass: no remaining spec findings.

## Boundaries

No SDK version, thread count, model/embedding configuration, resource catalog,
UI, Auth, SQLite, Dataset/RAG, or DownloadService change. No PR merge/close,
force push, rebase, original repository or local computer access.
Historical B-08 QA files remain untouched. G2/G3 BLOCKED; Samsung PENDING.
