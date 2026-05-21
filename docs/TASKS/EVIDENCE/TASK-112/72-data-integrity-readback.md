# TASK-112 — Data integrity read-back

Timestamp: 2026-05-20 22:26 -0400  
Agent: Codex / Executor

## Local Supabase read-back

| Invariant | Result | Evidence |
|---|---:|---|
| Owner isolation | PASS | Owner B saw 0 rows for owner A synthetic catalog/session/event records. |
| ProductPrice no duplicate effective key | PASS | Replayed same effective key remained 1 row. |
| `record_sync_event` idempotency | PASS | Replayed same `client_event_id` remained one logical event. |
| Session payload shape | PASS_WITH_NOTES | `shared_sheet_sessions.data` JSON array accepted; object payload rejected by constraint and transaction rolled back. |
| Cleanup residue | PASS | Post-rollback `TASK112_LOCAL_*` residue count 0. |

## Client test read-back

| Platform | Result | Evidence |
|---|---:|---|
| iOS local/offline services | PASS_WITH_NOTES | Targeted suites and broader TASK-112 regression group passed; broader log has 227 passed test-case lines / 0 failed. |
| Android repository/coordinator | PASS_WITH_NOTES | Full `testDebugUnitTest` rerun passed with JVM self-attach enabled: 458 tests, 0 failures, 2 skipped. |
| Android live app-auth smoke | PASS_WITH_NOTES | Physical device live preflight completed; not a full TASK-112 dual-client data matrix. |
| iOS live app-auth | BLOCKED | Harness returned `sessionMissing`; no live TASK-112 rows created/read. |

## Verdict

**PASS_WITH_NOTES** for local DB and unit-level integrity, **BLOCKED** for required live iOS↔Android read-back.

## Final review+fix rerun update — 2026-05-20 22:26 -0400

Local Supabase read-back was rerun transactionally:

- owner A event visible to owner A = 1;
- owner B event visibility = 0;
- ProductPrice unique constraint present;
- `record_sync_event` replay idempotent;
- transaction rolled back;
- final residue count for `TASK112_LOCAL_*` / `TASK112_OFFLINE_*` = 0 across checked public tables.

## CA-20 app-auth rerun update — 2026-05-20 23:15 -0400

Live app-auth read-back now passes:

- iOS write/read-back: `TASK112_IOS_WRITE_SMOKE ... price_inserted=4 no_op=true`.
- Android pull iOS: instrumentation `OK (1 test)`.
- Android write/read-back: instrumentation `OK (1 test)`.
- iOS pull Android/no-op: `TASK112_IOS_PULL_ANDROID ... inserted_catalog=1 inserted_prices=4 no_op=true`.
- Medium ProductPrice: `products=50 prices=102 price_inserted=102 price_batches=2 remote_medium_products=50 export_spotcheck=true`; Android medium pull PASS.
- Conflict/fail-closed: `product_price_conflicts=1`, `price_ready=0`, `remote_unchanged=true`.
- Duplicate scan before cleanup: CA-20 prefix duplicate active barcodes `0`; offline prefix duplicate active barcodes `0`.

Integrity verdict update: **PASS_WITH_NOTES** for live read-back and no-duplicate evidence; **BLOCKED** for final residue-zero cleanup because app-auth delete is denied by RLS/grants.

## Final integrity closure update — 2026-05-21 00:01 -0400

Final prefix `TASK112_FINAL_R20260521T033505Z_` read-back PASS:

- iOS write/read-back PASS, including ProductPrice no-op.
- Android pull iOS PASS.
- Android write/read-back PASS.
- iOS pull Android/no-op PASS.
- Medium ProductPrice PASS: 50 products, 102 prices, Android medium pull PASS.
- Conflict/stale/fail-closed PASS: stale classified as preview stale, ProductPrice conflict fail-closed, remote unchanged.
- Final duplicate/residue SQL read-back returned 0 rows for all TASK112 prefixes after cleanup.

Final integrity verdict: **PASS**.
