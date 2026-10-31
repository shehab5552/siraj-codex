# Independent review evidence — 25 October 2026 (Asia/Aden)

Repository: shehab5552/siraj-codex only. Fixed base:651af0d62d05761c80d9a8cbc9d1f51b836929eb. Whole-branch review HEAD:30900976912100252bb4cae3828293ada3abd38c, tree948d464798f0a8c5506e5b1ef7fc66137c0c85f5. Two isolated read-only gpt-6-astra reviewers completed; their findings were assessed separately. Earlier dispatches that returned a usage-limit error did not review code and are excluded. Qodo CLI was unavailable; no Qodo review is claimed.

## Standards

Most severe: Important. All private showDialog routes used Flutter's default root Navigator, escaping the session-owned Navigator. Source text could survive above a signed-out screen after the private scope disposed. Original citations at3090097:quiz_page.dart:57/174, settings_page.dart:21, dataset_preparation_card.dart:23; architecture promise app_bootstrap.dart:211 and execution ledger session containment.

No additional substantiated Critical/Important issue was identified in inspected KDF global occupancy/background execution/cancel drain/owned bytes, SQL nonce/epoch and synchronous revocation fences, preference rebinding, provenance leases, promotion/ambiguous commits, signing or test-certificate isolation. This is scoped static review, not proof that all security defects are absent.

## Spec

Three Important findings against corrected P0 and unified request:

1. Damaged completed payload yielded candidateUnavailable then candidateExists on every retry. Original dataset_preparation.dart:185–195 and download_staging.dart:111–151. Violates FR-16 and request§§9–10.
2. Confirmed Quiz showed aggregate counts without per-question feedback or neutral Undetermined explanation. Original quiz_page.dart:117/310–319. Violates FR-11,UI-13,§12.3.
3. Catalog revision was checked before awaited authorization but replaced by current availability during request construction. Original quiz_controller.dart:326–387. Violates request§§7–8 revision/approved-scope binding.

## One fix pass and targeted closure

Fix commit:b2fa50044ff9628fb186debfbc4fd7c4eeca403d. Both original reviewers inspected3090097..b2fa500 and the new regression tests read-only. All four findings were addressed, with no new substantiated Important/Critical issue within that patch. This was targeted closure, not fresh whole-branch approval or production/security certification.

- Nearest-Navigator modal ownership; actual source/submit/account dialog teardown and resource-consent revocation regressions.
- Existing QuizFeedbackCard per question only after confirmation, RAM only.
- Expected catalog revision carried across session authorization; no port request on mismatch.
- Explicit lease-protected recovery of byte-damaged completed staging with well-formed matching approved provenance/size/hash; valid, leased and foreign completed candidates preserved; active release path is never accepted by API.

Qualification: refusal to delete malformed provenance applies to the explicit repair API. The existing generic transport restart may discard untrusted staging checkpoints; it does not acquire authority over an active release.

Parent verification: enforced pub PASS; analyze no issues;565 passed/0 failed/0 skipped. Reviewers inspected tests but did not independently rerun those commands or Android. Failed test-harness attempts and interrupted runs are excluded from acceptance counts. Missing-payload recovery already passed before the repair; it is regression coverage, not RED evidence. Size/hash damage, revision race, missing feedback and surviving dialogs were actually reproduced before fixes.

## Native completion ordering follow-up at06f2310

Exact CI40156003414 subsequently failed at600k with a masked generic KdfFailure (7 native passed/1 failed; app not run). Static investigation independently confirmed that posting success/error before buffer cleanup/global lane release allowed a subsequent call to observe completion while occupancy remained true. The old CI did not expose the raw platform code; KDF_BUSY is not claimed as its measured cause.

The standards reviewer inspected06f2310 and confirmed cleanup/lane release now precede posting either outcome; copied output is wiped after publication/disposal or failed post. Only the safe KDF_BUSY code maps to typed busy. No new Important/Critical risk was identified within that patch. The host RED→GREEN test proves error mapping, not native scheduling. Added Android sequential/global-contention tests still require exact-commit CI. No production approval.

Exact-code runtime closure:GitHub Actions40156855257 at06f2310 completed SUCCESS. Native Android10/10 and application1/1 passed on API33 Google APIs x86_64 emulator, including64 sequential calls across2 workers, global contention/recovery and logical cancellation/drain. Candidate600k measured2849ms/283 heartbeat ticks; logical cancel0ms. Not physical-device or production acceptance.
