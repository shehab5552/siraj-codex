# SIRAJ Unified V2 — integration candidate

## What is integrated
All currently uploaded Codex feature branches: B-04 security (PR #6 stack), B-07/B-12 resource pipeline (PR #9 stack), B-08/B-09 and Shared Embedding (PR #10 stack), B-11 Quiz (PR #8 stack), and UI/UX V2 stage 1 (PR #11). Base main commit: `651af0d62d05761c80d9a8cbc9d1f51b836929eb`.

- Single Flutter source tree, one MaterialApp, one guarded AppBootstrap and one V2 shell.
- Native Android channels for encrypted secure session and download space checks both retained.
- Manifest combines offline account backup protection with network permission for optional downloads.
- B-04 protected UserRepository selected; B-11 typed persistence and session-guarded draft path selected for Chat.
- Existing B-11 quiz/history/chat routes accessible through guarded callbacks in V2 shell; no fake generated output.
- Fixed `setState` closure to avoid returning a Future during session-gate refresh.

## Incomplete and blocked
**NOT A PRODUCTION RELEASE.** Native AI Runtime/Embedding and scientific resources are not approved; quiz generation remains unavailable. The branch does not enable production auth from AppBootstrap. Full V2 visual screens, PDF reader, and on-device G2/G3 acceptance are not complete. Chat/Quiz callbacks need independent regression review. Previous source branches were cloud-tested independently, not as a combined product.

## Verification
This branch has a GitHub Actions workflow to run enforced dependencies, analyzer, full Flutter test suite, Android APK build. It produces a single **isolated-ID** debug APK (`com.example.siraj.unifiedpreview`) only after all steps pass; this avoids overwriting the user's installed original app. Never represent it as the release APK.

## Before main
Require clean CI, verified Android signup/login/logout/delete with account preservation, Android download/activation and lifecycle checks, actual V2 accessibility/RTL checks, and security review. No `main` merge without verified readiness. Existing PRs remain unmerged.

## Isolated visual preview
`lib/main_v2_preview.dart` is a separate debug-only launch target for reviewing navigation without a real account. It never overrides the production entrypoint `lib/main.dart`, never enables Auth in release mode, and never represents real chat/AI/Quiz functionality. The preview APK opens four tabs with unavailable states; do not call it the completed app.
