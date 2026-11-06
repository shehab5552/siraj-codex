# B-08 independent two-axis review

Base: `208511419bea03600793a24125795fcf3780b1bc`. Initial pinned review: `364cd724e396d3adff1ec1b831b5679c61843cb6`. Follow-ups: `87b0df8`, `2c03054`, `230c158`, `4381b1d`, then final test/workflow/evidence-only worktree. Reviewers were separate read-only agents; they did not run tests, edit files, or retrieve remote Actions. The primary agent ran verification and retrieved actual CI proof.

## Standards

Fixed findings:

- A rejected duplicate request ID overwrote/removed the accepted request's listener. Native `RequestOwnership` uses identity leases, `putIfAbsent`, and owned removal; regression reproduces rejection while preserving the original lease.
- Ended/error EventChannel subscriptions allowed future requests to hang. The Dart client cancels the abandoned native run and refuses new generation on the dead transport until owner recreation; closure/error regressions pass.
- Cancellation throwing during disposal shut down the worker before a later terminal could release handles. Close waits for actual native termination, keeping ownership quarantined; regression checks cleanup after the terminal.
- A previous cancellation error survived an engine-close failure and contaminated an unrelated reload/close. Capture-and-clear precedes close; close-once-fails/retry/reload regression passes.
- Real cancellation probe subscribed after the generate acknowledgement and raced an already completed request. It now observes the known ID before invoking generation, retries a completion race within a bound, and requires an actual Native cancelled terminal; early-events regression passes.
- The CI reporter accepted a PASS print with zero/partial successful cases. It now requires six passed cases, zero failed/skipped, successful protocol completion, and the explicit engineering/model-execution/cancellation fields; zero/partial/wrong-scope regressions fail on the former implementation and pass after the fix.

Final reviewer result: no remaining concrete substantive Standards findings in the reviewed delta. Workflow ignores only report/result outputs; the functional license-review input still triggers verification.

## Spec

Checked against all18 sections of `docs/spec/B08_NATIVE_RUNTIME_USER_REQUEST_2026-11-06_AR.md` and documented P0 boundaries.

Fixed/verified:

- Explicit initialized-engine cleanup after initialization failure; SDK handle is assigned only after a successful native create, and close is guarded by SDK `isInitialized()`.
- Original EventChannel/disposal findings resolved with regressions.
- Empty Release catalog versus exact owner-pinned Debug fixtures, app-private/canonical paths, host/device SHA and byte counts, no model-path override or model binaries in Git/APK.
- Real SDK text extraction, explicit non-text/tool rejection, automatic tool execution disabled, Debug-only benchmark counters validated before publication, whitespace-only output rejected.
- Existing USER transaction/max10/IDs preserved; nonce checks occur inside guarded writes; late session/delete/cancel/revision results cannot append a verified answer.
- Actual result/report consistency: source4381b1d CI has six successful Android cases, four completed generations plus one native cancellation, three real finite/nonzero768 vectors, reload/offline evidence, actual APK hashes/readelf checks and sampled memory.

Final reviewer result: no remaining substantive Spec/proof-safety findings. G2/G3 remain BLOCKED, Release production resources remain closed, signing remains debug, physical ARM64/Samsung remains pending. Static APK inspection's NOT RUN field is not represented as an inference test; the separate real Android result is PASS.

## Verification ownership and limits

Independent review is code/evidence review, not a separate execution of models. Actual commands/counts and CI/artifact/source identifiers are in `local-final-results.json`, `android-final-results.json`, and the24-section Arabic report. Fake contract tests are not model/G2/G3 proof. Files list referenced by the report is included in `files-changed.txt`.

## Final delivery evidence refresh

The primary agent retrieved successful CI42291190266 at source0c9212cd8ae81d798b0ef7a4fd5f52e5877fcf4b after the additional contract/CI checks. All six Android cases passed, with0failed/0skipped. The application sources are unchanged from the reviewed4381b1d; the final report and results JSON now reference the newer run and its own APK hashes/measurements. Reviewer conclusions concern code/evidence review; they are not represented as independent model reruns.
