# SIRAJ V2 fidelity closure implementation plan

> **For agentic workers:** Use superpowers:executing-plans inline, with one final independent review. Tests and measured reference comparisons precede completion claims.

**Goal:** Close the specific visual discrepancies recorded at79ba311, preserve actual services/data policy, and ship a new normal-main APK through PR12 without merging.
**Architecture:** Improve existing design components and feature presentation only. Controllers, repositories, Auth profile, download/validation/AI contracts and SQLite schema remain authoritative. Reference SVG glyphs become local assets through one shared icon component; no second design system or network fonts.
**Tech Stack:** Flutter3.38.5/Dart3.10.4, existing Android framework PDF engine; offline SVG rendering if required.
**Spec:** Latest user instruction29October2026; docs/design/reference_v2/ and previous Visual Fidelity Matrix; corrected P0 and revised Team B plan in docs/spec/.

## Global constraints

- Only shehab5552/siraj-codex, existing integration worktree/branch; baseline79ba3111fd5326ea4be95fd26c5edbe2386efce4 and main651af0d. No original repository/user computer access, no merge.
- Reference content viewport380x737@1 after excluding simulated device/OS chrome; include370x683 mobile-dark,320 width/200% and1024 tablet/RTL/LTR. Actual OS bars are not drawn by app.
- Colors match CSS light/dark, card16/field12/button13 radii, gutters15/top17, appbar68/nav66. Preserve48dp interactive hit areas; visual46px buttons may sit inside48dp targets.
- No demo scientific answers, books, catalog counts, bank source selector or Mixed mode in production. Four P0 Quiz types and RAM-only attempts remain.
- Ruling: user explicitly approved design/reference and instructed implementation, not a new design approval stop. Execute recorded scope directly; reviewable changes remain on draft PR12.
- Official logo source is promised but not yet supplied as an accessible image file. Prepare a deterministic asset pipeline; never call a monogram the official logo or silently keep Flutter's default icon in a claimed final build. Final branding validation depends on that source.

## Review focus

- Selected theme/language controls must invoke existing account persistence and survive logout/reopen; no UI-only fake preference.
- Repositioning History/New Chat/composer must preserve temporary draft and exactly-once USER persistence, cancellation and session revocation.
- Real error/unavailable states must stay visible without inventing resource data to imitate a populated mockup.
- Reference46px controls need48dp hit areas; RTL/LTR and200% text must remain usable, with no clipped controls.
- Branding generation must reject missing/undersized/unsafe inputs and prove the APK has no Flutter template launcher assets; no source asset fabrication.

## Task1: Reference measurements and shared visual primitives
Files: lib/core/design/siraj_v2_components.dart, siraj_design.dart, siraj_navigation.dart; assets/icons/v2/; tests/v2_*.
- [x] Extract reference SVG paths and exact DOM rectangles with original HTML/font; retain source hashes.
- [x] RED: assert specified onboarding/history/settings/chrome geometries and icons; compare actual baseline screenshots.
- [x] Implement local shared icons, bordered header actions, reference note/status/row/heading primitives in existing design directory; reuse colors/themes.
- [x] GREEN: primitive/geometry/accessibility tests, no service changes.

## Task2: Ordered primary screens
Files: OnboardingPage, HomePage, ConversationHistoryPage, SettingsPage, ChatPage/chat_widgets; their existing tests and new reference goldens.
- [x] Onboarding: original4-step copy/illustration/icon/halo/pill/dots/Next/Previous/Skip structure; preserve once-only preference and necessary privacy notice.
- [x] Home: exact header, hero text/layout/button/quick grid/history card; actual unavailable readiness rather than mockup state.
- [x] History: actual saved count, reference row cards, retention note and New Chat after list; empty/loading/error retain real behavior.
- [x] Settings:59px setting rows, compact light/dark/System control, language control, resources/account sections and real warning dialogs; reuse preference/session callbacks.
- [x] Chat: header/history action, empty illustration, honest unavailable note, bubbles/sources, bounded composer/loading/cancel/follow-up. Keep all business logic in coordinator.
- [x] RED→GREEN focused tests for callbacks/positions/large text, then actual light/dark captures before advancing.

## Task3: Remaining presentation states
Files: AuthFormFrame/signup/login; library/page/reader; resource widgets; quiz widgets; existing test fixtures.
- [x] Match field labels/layout/button/notice patterns without adding a new account field or security behavior.
- [x] Render real library catalog/readable/download/error/empty states with reference book covers/cards; production catalog stays unavailable until approved.
- [x] Match resource diagnostics/progress and Quiz setup/questions/review/results, using only test-scoped fixtures for available-state evidence.
- [x] Add golden coverage for these genuine widget states and compare reference geometry; mark scientific/device acceptance separately from UI verification.

## Task4: Official identity pipeline
Files: tool/branding*, android launcher/adaptive/launch resources, shared brand widget, branding tests/report.
- [ ] On source arrival inspect it, record provenance/hash/size, generate density icons/adaptive safe-zone/light/dark splash and app assets.
- [x] Before source arrival prepare validation/generation integration and an explicit blocked report, complete independent UI work.
- [x] Verify manifest label SIRAJ and final APK resources visually/byte-wise; reject final branding claim while template Flutter artwork remains.

## Task5: Evidence/review/delivery
- [x] Full pub get --enforce-lockfile, analyze, flutter test, changed Dart format and diff check; correct all discovered failures.
- [x] Generate same-viewport reference/actual/diff panels, refreshed matrix with per-screen fixed/justified/blocked status; no invented aggregate acceptance threshold.
- [x] Independent spec and architecture review on fixed79ba311..head; fix real findings with focused regression evidence.
- [ ] Commit/push to current integration branch, build normal-main APK and package source/current CI reports with existing workflow; verify native lifecycle regressions.
- [ ] Update PR12 without merge, publish Arabic report and actual counts/hashes/links; keep Samsung/AI/production gates distinct.

## Interface preflight

All five primary screens consume existing controllers/callbacks; shared primitives change only presentation. Settings tests/native flows currently expect dropdown theme keys, so adapting to direct segmented controls requires corresponding interaction updates without removing persistence assertions. Chat title/bubble selectors are used by native restart tests; retain stable message/action keys. Logo generator must not overwrite app resources before input validation succeeds.

## Execution checkpoint — 30 October 2026

Primary and remaining presentation changes implemented, 142 golden images and100 same-viewport comparison panels generated, geometry assertions added. Official logo source remains absent; reference monogram is explicitly provisional. Full-suite and native CI evidence is recorded in docs/qa/UIUX_V2_CLOSURE_2026-10-30_AR.md. Parallel and serial Linux engine teardown SIGSEGV was observed and is documented; no KDF/runtime/profile change is justified by that unknown cause.

## Final verification checkpoint — 1 November 2026

609 local host tests passed with zero failures/skips and clean analysis after final palette/header/dialog changes; 142 golden PNG and100 same-viewport panels regenerated and SHA-linked. Two independent reviews completed, including opaque Quiz identity and actual History/dialog regressions. Historical native Flutter engine crashes remain documented; separate concurrent Flutter commands sharing unit_test_assets are prohibited, without claiming a proven native root cause.

CI9904b4f built the normal-main APK and passed compiled launcher/adaptive/splash verification plus11 native KDF/PDF tests, but application Logout tap was outside320x640; restart targets did not run. Apply existing bounded UnifiedFlow helper to all application target taps; final fresh CI must execute all five native targets and package only on full success. Official logo, final pixel acceptance, Samsung, production resources/G2/G3 remain blocked and outside a success claim.

Final comparison correction: RTL deletion acknowledgement now matches logical leading placement/full text/background/radius, with real geometry assertion RED→GREEN in both themes. No further presentation changes planned; refresh exact-SHA full verification and CI after this scoped correction.

Native follow-up855a0a0:13 native passed, finalrestore target failedafterlogout/login. Existing native tool falselytreateddisabledbuttonasready (RED), now waits enabledform/button and single acceptedinput forTextField/TextFormField with7focusedtests. NoAuthsourcechanges; causeoforiginaltimeoutnotproven, finalnativeCIrequired. ArtifactBlobhostproductionresultssa1.blob.core.windows.net blockedbyproxyCONNECT403; originnotreached.
