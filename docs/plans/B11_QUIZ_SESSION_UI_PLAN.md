# B-11 Quiz RAM session implementation plan

Execute inline under owner's approved 23October full-development directive. Spec: ../architecture/B11_QUIZ_SESSION_UI.md and official P0 §§6.9/12.

Constraints: no PR merge, original repository/PC access, Auth production gate changes, SQLite schema, persistence of quiz answers or bank-only fallback. Synthetic examples only in tests. Keep scopes separate from B09.

Review focus: decimal tolerance boundaries and units; uncertain short answers; malformed/foreign/mixed-revision LLM results; cancel/logout/delete/dispose during async generation/source reads; no persistence or duplicate scoring; narrow RTL layouts.

1. Quiz contracts + conservative scorer: typed item/spec/answer/session/failure DTOs and unavailable generation port. Write tests, RED, implement exact decimal and reviewed-key scoring, GREEN.
2. RAM controller + SQLite-backed access adapter: correlation/session guards, duplicate prevention, end/close/cancel and summary. RED concurrency tests, implement, GREEN; no DB writes from quiz code.
3. Reusable widgets/QuizPage + guarded app composition: four question types, generation/unavailable/error/cancel, sources, feedback and summary. RED Widget tests, implement, GREEN.
4. Enforced pub get, analyze, complete suite, independent standards/spec review, fixes with regression tests, Arabic report and separate stacked PR targeting B08. No merges.

Ledger: baseline code B08@306b3a69bb855a49b3bf01bbb1b6bd30a1c087f5; validated197 tests in sibling B09 before changes. Reuse exact-hash cached SQLite binary for this isolated worktree, without dependency overrides.

Implementation ledger: steps1–3 implemented. Independent spec/standards review of tree0cb6c3e55ba068fafa2d7c97af28d50776e7a490 identified missing numeric precision metadata, source navigation race, and lost cleanup retry after disposal. All three were reproduced by failing regression tests before repair. Fixes add explicit reviewed precision adapter, per-question source fences, and app-scoped cleanup ownership. Focused suite now49 passing; final full validation/report/PR evidence follows. No production numeric rounding policy or generation service is invented.
