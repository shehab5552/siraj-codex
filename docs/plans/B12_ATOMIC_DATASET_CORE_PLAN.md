# B-12 / TK-19: immutable dataset release core

Authority: P0 v1.0.1 §§6.5,7.4.1,10.3,15.3 TK-19 and TC12/26/32; revised Team B §4.2 explicitly permits controlled mechanism tests before production resources. Branch from B07@27ff8e5265e03092ccf84fedeae39d5bb4d008a7, PR targets B07. No merge; no original-repository, Auth or B08/B09/B11 changes.

Bounded delivery: app-private candidate ownership/write serialization; reuse existing hash validator and five-pack/shared-embedding structural contract; mandatory trusted semantic/runtime validator default unavailable; immutable same-filesystem rename; one transactional reserved SQLite pointer; pinned reader lifetime; conservative startup recovery and guarded orphan/old-release cleanup. No production manifest serialization, archive format, runtime selection or sample-query results invented. No automatic Product readiness based on metadata/check names. One-consent network/assembly UI and approved catalog/real validator remain integration inputs.

1. Read contracts/spec; add failing tests for reserved-pointer protection and old pointer preservation.
2. Add approved plan DTO, typed failures and unavailable validation/catalog boundaries; implement pointer store with transactional compare-and-swap.
3. Implement manager path/ownership, staged writes, integrity/semantic validation and sealed receipt; no public caller-constructed verified receipt.
4. Implement promotion/commit/pin/recovery/cleanup, with fault-injection real SQLite/files tests including crash boundary and concurrent reader.
5. Enforced pub get, analyzer/full test, independent review, fix with regressions, Arabic report, commit/push/stacked PR. No production readiness/G2/G3/Android claims.

Ledger: initial reserved-row RED→GREEN confirmed destructive unverified-write path and repaired it. Initial full226/0/0. Independent spec/standards review tree5bfd8cb76b749c10433bc06d8180eea09d51aa4c found cached runtime proof reuse after failed recovery and stalled-stream cancellation. Both reproduced RED→GREEN; writer subscription drainage and file-backed SQLite restart included. Focused47/0/0 before final full run. Same-revision single-instance embedder proof reuse also has RED→GREEN regression.
