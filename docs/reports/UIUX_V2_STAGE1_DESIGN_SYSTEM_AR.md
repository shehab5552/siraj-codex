# SIRAJ UI/UX V2 — Stage 1 (Flutter)

Base: main `651af0d62d05761c80d9a8cbc9d1f51b836929eb`. Independent branch: `codex/uiux-v2-design-system-stage1-20261024`.

## Approved change

The *review package* is a visual reference, not production content. Its legacy "reviewed question bank" option is expressly superseded by the owner's final instruction: **Local LLM + RAG + reviewed evidence + Few-shot only**. No question bank, quiz history table, artificial sample questions, or fixture-to-product path is added.

## Dependency map

- `MaterialApp → SirajTheme` (visual only).
- `AppBootstrap → StartupSessionResolver → UserRepository/Keystore` (unchanged; production account creation and login remain security-gated).
- `HomePage → session-gated callbacks from AppBootstrap` (no direct DB calls).
- `HomePage → AuthenticatedChatRoute → ConversationDraftController → ConversationRepository/SessionGuard` (unchanged).
- `HomePage → guarded ResourceStatusPage → ResourceStatusReader/Repository` (unchanged).
- `SirajMainShell → HomePage + explicit unavailable states` (presentation only; not connected to AppBootstrap until dedicated navigation/security review).

## Implemented

- Central semantic palette, spacing, radius, breakpoints, light/dark ThemeData.
- Reusable card/button/text input/status/loading/error/confirmation components.
- Responsive shell (4 bottom tabs on compact, navigation rail on expanded viewports); one selected index.
- Rebranded home with resource readiness honestly unverified and existing guarded actions unchanged.
- Flutter widget tests for visual tokens and bottom tabs.

## Deliberate limitations and next integration

The V2 shell is rendered only from the **existing authenticated branch** of AppBootstrap; StartupSessionResolver, Keystore/session validation and the B-04 security gate remain unchanged. The chat callback still uses existing AuthenticatedChatRoute and session-guarded ConversationDraftController. There is no unconditional route to private chat or resources. Existing AppBootstrap/HomePage still owns the actual authenticated actions. No persistent theme preference, onboarding or functional PDF/quiz adapters in this Stage 1; subsequent focused PRs should implement them with tested session-aware persistence. The assistant tab invokes the existing guarded chat callback only when present; otherwise shows an unavailable notice. The tab still indicates home while the separately pushed chat route is open; current-route-aware highlighting is deferred until the B-08 stack is reconciled. Missing AI, RAG, approved book manifests and downloadable resources remain fail-closed.

PR#3 (B-07), PR#4 (B-08), PR#5 (B-04), PR#7 (B-09), PR#8 (B-11), PR#9 (B-12) remain separate. **Do not merge** them via this visual branch.

## Verification

Source-level review performed against GitHub main and user-supplied V2 package. Flutter SDK is **not available** in the current execution environment. Hence `flutter pub get --enforce-lockfile`, `flutter analyze`, `flutter test`, Golden, Android, and screenshot QA are **NOT_RUN**. This PR must remain **draft** until CI and Flutter tests run; no passing test counts are asserted.
