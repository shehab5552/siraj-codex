# SIRAJ production completion and V2 implementation plan

> Implement inline with superpowers:executing-plans; tests before behavior changes, one final independent whole-change review. User explicitly requests execution, not a new approval/planning stop.

Goal: close implementable V2/PDF/lifecycle gaps while retaining the verified unified application and reporting each production acceptance gate truthfully.
Architecture: reuse the current design system, AuthService, Chat/Quiz controllers, DownloadService and DatasetReleaseManager. Add one Android PdfRenderer backend behind library ports; no second downloader or guessed AI engine/model/index policy.
Tech stack: Flutter3.38.5/Dart3.10.4; Java17/Kotlin Android API26+; pinned dependencies.
Spec: docs/spec/PRODUCTION_COMPLETION_USER_REQUEST_2026-10-28_AR.md; corrected official P0 and revised Team B plan. Visual reference: docs/design/reference_v2/.

## Baseline

GitHub verified28October2026 Asia/Aden: main651af0d, integration0b911d0, PR12 OPEN/DRAFT; prior CI40157567682 SUCCESS. No original repository/computer access. Managed network policy enforced; five allowed hosts, Actions download log hostname remains outside allowlist. No AGENTS.md found. Working tree isolated on existing integration branch.

## Constraints and rulings

- One main.dart/application/design/Auth/chat/download/Quiz/RAG system; no schema changes for visuals, no Quiz persistence.
- Four approved Quiz types, trusted catalog/counts, no bank selector. Mixed mode only if documented contracts support it; current single desiredType contract does not.
- Ruling: execute the already explicit user-approved scope without asking another design/plan approval. Implementer settles visual measurements/native-PDF adapter choice. Cost if wrong: reviewable changes remain on PR12, no merge.
- Ruling: compare actual app content at380x737 to396x790 phone reference after excluding8px device shell,26px synthetic status and11px home indicator. Never draw fake OS chrome inside production app. Keep48dp touch minimum despite46px reference buttons. Cost: small documented accessibility/OS differences.
- Brand board is visible inline but no standalone PNG/SVG asset exists in ZIP/cloud attachments. Do not claim exact approved logo extraction or upscale a tiny raster. Record asset blocker explicitly; keep reference monogram until correct source is available.
- PDF engine choice: Android framework PdfRenderer (API21+, existing min26), platform implementation, no additional third-party binary/plugin. Compare with external plugins and document licensing/platform limits. Real parser/rendering proof required; approved book catalog still absent.
- Missing approved native AI build/weights/embedding/index/science policies and physical device remain BLOCKED. Do not invent wire formats/thresholds or enable release Auth before acceptance.
- Explicit user approval required before merging PR12 even if all gates eventually pass. Push/PR updates/CI are already authorized.

## Review focus

- Private route/modal lifetime and stale render/download completions after logout/delete: no private pixels or writes may reappear.
- PDF path substitution/symlinks/truncation/huge page sizes: deny outside app staging; use descriptor ownership, bounded rendering, typed errors.
- Completed PDF staging must remain locked through native descriptor open/read/close; never replace active readers.
- Reference screenshots include fake science/catalog/bank options: visual resemblance must not turn those into production data.
- 200% text/small widths and queued render/cancel/close must remain usable, memory bounded and recoverable.

## Tasks

1. [ ] V2 geometry/components and all existing screen layouts. Modify core/design; home/navigation/onboarding/auth/chat/history/resources/quiz/library/settings presentation only. RED: toolbar68,nav66,explicit card/dialog/field tokens and semantic sizes. Implement shared header/tiles/pills/status/segmented selection, reference hero/cards/spacing, preserving labels/keys and real callbacks. Focused tests then full regression; commit/push/CI checkpoint.
2. [ ] Visual evidence. New controlled380x737 and370x683 actual Flutter captures for all screen groups and AR/EN/light/dark/scaled states; goldens use test-only fakes for unavailable branches. Compare supplied PNG app regions without matching fake science/OS chrome. Save matrix, actual/reference/diff artifacts and measured dimensions, no unsupported pixel-accuracy claim.
3. [ ] Verified native PDF. New features/library/pdf_reader_contracts.dart, native_pdf_reader.dart, pdf_reader_controller.dart, pdf_reader_page.dart, verified_library_actions.dart and Android SirajPdfChannel.kt; root library factory wiring. Consume existing withCompletedArtifact and DownloadHandle, not a new service. Descriptor-backed open/page/render/close on serialized worker, bounds/pixels/path checks and no external intents/network. RED unit/controller/real TLS+file tests, widget render/navigation/zoom/cancel tests, real two-page synthetic PDF on Android (test asset only, no official book claim).
4. [ ] Native/lifecycle/packaging. Extend normal app Android acceptance for restore/background/lifecycle as testable, retain KDF/Keystore/SQL and signing gates. Workflow produces SIRAJ_P0_FINAL_FLUTTER_SOURCE.zip, normal isolated-ID main APK, hashes, visual/QA reports. Uppercase SIRAJ app label; final branded launcher/splash blocked on source asset if unavailable.
5. [ ] Final independent review, fix verified Important/Critical once with RED→GREEN/full suite, pub enforced/analyze/test/format/diff, push and exact-commit CI; update PR12 and Arabic Gate1..8/visual/release-readiness reports. No merge request until all mandatory gates pass; otherwise report Integration Testing and exact inputs still missing.

## Interface preflight

1→2: shared typography/layout tokens used by captures; golden updates are intentional evidence, not substitutes for reference comparison.
3→1/4: LibraryBookActions.open Future lasts until private PdfReaderPage and native handle close; session scope destroys route, cleanup drains and releases B07 lease.
3→B07: staging root and DownloadSpec identity remain owner-selected, validator hashes/sizes plus native parser prove readable; no READY from header/SQL alone.
4→5: CI success proves emulator/build only, not physical-device or scientific acceptance. Source code and report commits are identified separately where necessary to avoid self-referential ZIP hashes.

## Execution ledger

Baseline rerun: enforced pub/analyze PASS;566 tests passed/0 failed/0 skipped (68766ms). Actual prior GitHub branch/PR/CI verified before editing. Package15 files read/inspected;13 PNGs viewed and HTML68,216 characters reviewed. Chromium file:// navigation was blocked by administrator; rendering the already-read HTML in an in-memory Playwright page succeeded with policy intact. Measured reference phone396x790, appbar380x68, body380x603, footer380x66, hero350x233.78125. No screenshots/prototype have been wired into production UI.

Checkpoint1 foundation: RED geometry tests proved missing68/66 heights and text/field/dialog tokens; home reference text/gutters also failed before implementation. One design system now supplies explicit V2 typography, field/card/dialog themes, shared header/tiles/pills/notices, reference home hero/grid, onboarding halo/dots, four-type trusted Quiz cards and message geometry. Existing source/actions are retained. Replaced opaque generic headers across account/chat/history/quiz/resources/library/settings, preserving real service callbacks.

Navigation RED: an existing real-auth/SQLite test proved four destinations vanished on Settings. App-scoped authenticated chrome now surrounds the existing single private Navigator; public tab changes are authorized by existing AppSessionController and logout/delete destroy the entire scope. A real rapid-popup regression then proved stale scheduled modal state could disable navigation after dismissal; coalescing the latest modal state fixed it. Dialogs block both route body and external navigation while open. No nonce enters keys.

First full run567 passed/2 failed: Home's intentional reference copy change required updating the existing English expectation (direction/theme assertions retained), and resource-consent rebuild during revocation referenced a deactivated source context. Reproduced error fixed using the live dialog context; the same defensive correction applies to Quiz submit dialog. Small-screen200% tests also reproduced unbounded status/caption rows; bounded Flexible children fixed all8 matrices. Removed an unsupported decorative text glyph after inspecting the updated goldens. Golden images were deliberately regenerated for the specified V2 change and visually inspected; this is not a claim that reference-diff acceptance has passed.

Checkpoint1 final: analyze no issues; full569 passed/0 failed/0 skipped (76013ms), plus updated/inspected2 Home goldens and focused16 cases. Task1 visual foundation is delivered; detailed all-screen comparison, official brand extraction, reader and release gates remain open. No change to Auth release approval or AI availability. Ruling: PDF must promote verified .part to a safe final PDF namespace per DD-13/UJ-07; an initial staging-only read approach was rejected before implementing PDF code.

### PDF implementation checkpoint (28 October)

- Added a real Android framework `PdfRenderer` adapter (API 21+, current minSdk
  26), serial background native worker, bounded PNG rendering, typed failures,
  no-follow descriptor open, canonical app-private allowlist, explicit close.
- Reused B07 `withCompletedArtifact` under its provenance/writer lease. PDF
  requires trusted SHA-256 and size, a second verified copy, native first-page
  parse/render and close, then a same-filesystem rename into
  `pdf-books-v1/<full transport identity>/book.pdf`. No SQL readiness writes.
- Installed-file reader/installer leases stay held until native close succeeds;
  failed close is retained by the shared app-scoped cleanup owner and retried
  explicitly/on resume. Quiz retains its existing cleanup behavior through a
  compatibility class. Cancelled/stale UI never resurrects rendered pixels.
- Normal Android composition selects this real adapter lazily when no custom
  library actions are injected. The official catalog is still unavailable;
  no sample textbook, URL, title or model is added to production.
- Host test groups added: real temporary-file installation, local TLS B07 to
  installation, parser refusal, cancellation during proof, close failure pin,
  controller concurrency, typed channel boundary, RTL/LTR 200% reader controls.
- Android integration target uses an isolated two-page synthetic test document,
  real native parser/PNG/page navigation/offline reopen/path denial/malformed
  rejection. Execution is pending CI; host fakes do not prove native success.
- `SIRAJ` Android label normalized. Official launcher/adaptive/splash artwork
  still requires the standalone original PNG/SVG, absent from this ZIP.
- Engine choice: framework PDF avoids a new third-party Flutter engine/plugin,
  ABI binary matrix and additional runtime license. AOSP PdfRenderer API source
  (android-13.0.0_r1) was inspected: seekable owned descriptor, ARGB_8888 bitmap,
  one open page, non-thread-safe renderer. Android framework PDFium is supplied
  by the OS. This selection is not official textbook/device acceptance.

PDF host checkpoint: enforced lockfile resolved without dependency changes;
`flutter analyze` no issues; full585 passed/0 failed/0 skipped (82636ms).
CI40769379925 for UI checkpointca2c0fc: host/analyze/debug+release build and10
native tests passed; application integration failed at delete tap after scroll.
Annotation proved the attempted center605 was covered by the global footer;
no delete dialog existed. Integration now awaits final ensureVisible/layout and
asserts hitTestable before tapping (no warning suppression or skipped action).
Native PDF and corrected complete application execution require the next CI.

### Independent review / lifecycle fix / visual evidence (29 October Asia/Aden)

Two isolated read-only reviewers (spec and architecture axes) reviewed the pinned
0b911d0..1194527 change. Both found one Important/P2 issue: destroying the session
Navigator does not complete the pushed PDF route future, so cancellation could
close native state but strand the book lease. No additional concrete findings
or deferred minors. Ruling: make operation cancellation complete independently
of route disposal; the existing owner still joins actual native close before
release. Cost if wrong: future cancellation could release too soon; explicit
failed-close tests guard against it.

Final: fixed PDF lease after session destruction — direct pending-presenter
regression timed out RED; actual authenticated Navigator destruction failed RED
for close-success and close-failure. Operation stop-completer raced against the
presentation future makes both GREEN. Native close failure still retains the
lease in app-scoped cleanup until retry succeeds. No second native owner.
Host harness note: keep real TLS unit tests in a separate suite from widget
binding (which deliberately returns HTTP400), and drain real filesystem events
alongside widget microtasks rather than awaiting fake-zone futures in runAsync.
No production transport/auth policy changed to accommodate tests.

Visual evidence:26 new AR light/dark app goldens,380x737@1 actual content viewport,
13 real states per theme; no demo scientific responses or book catalogs. Existing
EN dark tablet/Home goldens and320/1024@200% RTL/LTR/light/dark tests retained.
Nine reference/actual/absolute-diff panels expose remaining geometry/content
changes. Descriptive MAE is not an invented acceptance threshold. Visual gate
remains incomplete, especially official artwork, header/empty-state copy and
selected-tab treatment. No pixel-accurate approval claim.

CI40771453346 at1194527 SUCCESS:585 host tests;10 native KDF tests,1 actual native
PDF test and1 full application test. Debug and unsigned evaluation release build
passed. Synthetic2page PDF native parser/render/navigation/offline reopen/path
rejection/malformed rejection/close verified on API33 emulator only. Previous
application tap failure is fixed by waiting for layout/hit-testability.

Added real force-stop persistence setup/restore Android targets with real native
KDF/Keystore/SQLite, saved USER message, EN/dark and post-restart logout/login/delete.
CI disables emulator WiFi/mobile data, force-stops the isolated app and verifies
no PID before restore. These new targets are pending execution, not PASS yet.

Visual follow-through:30 AR light/dark goldens now include Logout/Delete before
and after acknowledgment. Public-screen dark captures initially followed System
into light; a RED mismatch exposed the mislabeled baseline. Set actual OS dark
in the test and assert Theme.brightness at every capture; regenerated baseline.
No application preference/auth policy changed for the test.

Ruling: correct the material selected-pill difference in the existing
NavigationBar using a presentation-only NavigationDestination subtype, retaining
its standard host/focus/layout contract and all guarded onSelect callbacks.
Cost if wrong: accessibility or large-text regression; full-tile83x54@380 test
and tap-target guidelines plus all8 responsive matrices cover it. Initial200%
text showed3px overflow from inherited text height; explicit caption line height
fixed it. Account content is aligned to the reference's top area rather than
vertically centered; local P0's three real fields are retained.

CI40780034725: host590/analyze/build and10native+1PDF+1App passed; restart setup
failed waiting for Signup (0setup passes/1failure; restore skipped). Root cause
verified in pinned Flutter SDK: IntegrationTestTestDevice.kill explicitly stops
and UNINSTALLS the app (integration_test_device.dart:144), as does default drive
cleanup. Separate targets therefore cannot assume persisted onboarding/account.
Ruling: use official flutter drive --keep-app-running with integrationDriver,
not a patched Flutter SDK or copied data, for all native targets. Cost if wrong:
state leakage; one isolated applicationId and explicit full-app deletion/setup
flow keep the sequence bounded. Host driver saves screenshots before teardown;
previous post-test run-as collector alone could lose them to uninstallation.

Full host after visual corrections:591 passed/0 failed/0 skipped,85390ms;
analyze clean and enforced lockfile unchanged. Native host driver validates
actual binding.results counts for all5targets and saves only the small count
summary plus PNG screenshots (no full byte-array logging). Expected case count
is checked so missing execution cannot silently report success. Corrected
native lifecycle execution remains a CI requirement, not an assumption.

CI40782077658 (990b247): official keep-installed driver verified, actual result
maps10KDF+1PDF+1App all pass and host screenshots saved. Restart setup reached
Signup but hitTestable assertion failed after entering credentials. IME/focus
still covered target; verification helper now unfocuses and waits for actual
viewInsets.bottom==0 before ensureVisible/layout and retains hit-test assertion.
No AuthService, KDF, or assertion bypass. Restore not run in that failed job.

Packaging ruling: generate source ZIP only after all actual host/native result
files pass; append an explicitly generated CI acceptance JSON/Arabic report to
the source package, then hash it with the normal-main Debug APK. This avoids a
self-referential report/Commit/hash loop and old test counts in a pre-test ZIP.
Cost if wrong: packaging fails closed; unit-host summary was exercised on actual
591-pass JSON, and incomplete native inputs must be rejected. No fabricated
positive counts or production gates. Final CI proves the complete package path.
