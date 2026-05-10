# TASK-097 Evidence Manifest

- **Task:** TASK-097 - Runtime sandbox smoke iOS <-> Supabase
- **Status:** REVIEW PASS - TASK-097 DONE
- **Created:** 2026-05-10 14:27 -0400
- **Final update:** 2026-05-10 14:57 -0400
- **Environment:** local workspace + iOS Simulator + Supabase sandbox, redacted project hash `bf02812f63e2`
- **Dataset prefix:** `TASK097_*`
- **Effective dataset suffix:** `R1778437271`, selected after exact-prefix collision from the first TASK-097 smoke attempt
- **Owner/session:** authenticated SDK session present; owner redacted as `owner_hash=81a269773be6`
- **Privacy rule:** no email, token, JWT, refresh token, service role, connection string, full backend URL, real barcode or real product name recorded

## Frozen Fixture Values

| Entity | Value used |
|--------|------------|
| Supplier | `TASK097_SUPPLIER_RUNTIME_SANDBOX_R1778437271` |
| Category | `TASK097_CATEGORY_RUNTIME_SANDBOX_R1778437271` |
| Product A | `TASK097_PRODUCT_A_PULL_BASELINE_R1778437271` |
| Barcode A | `TASK097_BAR_A_20260510_R1778437271` |
| Product B | `TASK097_PRODUCT_B_LOCAL_PUSH_R1778437271` |
| Barcode B | `TASK097_BAR_B_20260510_R1778437271` |

## ProductPrice Manifest

| Product | Type | Role | Price | effectiveAt |
|---------|------|------|-------|-------------|
| A | purchase | previous | 11.11 | `2026-05-10 10:00:00` |
| A | purchase | current | 12.34 | `2026-05-10 10:05:00` |
| A | retail | previous | 22.22 | `2026-05-10 10:10:00` |
| A | retail | current | 24.68 | `2026-05-10 10:15:00` |
| B | purchase | baseline | 33.33 | `2026-05-10 10:20:00` |
| B | retail | baseline | 66.66 | `2026-05-10 10:25:00` |
| B | purchase | local edit | 35.55 | `2026-05-10 10:30:00` |
| B | retail | local edit | 70.70 | `2026-05-10 10:35:00` |

Runtime used the app canonical ProductPrice timestamp format `yyyy-MM-dd HH:mm:ss`; ordering matches the UTC manifest order. Price comparison tolerance: absolute delta `<= 0.005`.

## Runtime Ledger

| Step | Actor | Mutation/read-back | Target | Result | evidence_ref |
|------|-------|--------------------|--------|--------|--------------|
| preflight | test_harness | Read config/session/project/owner only | iOS Supabase SDK config | PASS; project hash and owner hash redacted; publishable key only; no service role | `test-build-summary.md#runtime-smoke` |
| collision_scan | test_harness | Read counts for exact `TASK097_*` and suffix | supplier/category/product/product_prices | PASS; exact prefix occupied after first smoke attempt; suffix `R1778437271` clear before final write | `remote-readback-notes.md#collision-scan` |
| seed_setup | setup | Insert synthetic supplier/category/products/ProductPrice seed rows | Supabase sandbox | PASS; owner-scoped `TASK097_*_R1778437271`; no real data | `remote-readback-notes.md#seed-setup` |
| remote_readback_seed | test_harness | Read seed rows after insert | Supabase sandbox | PASS; 1 supplier, 1 category, 2 products, 6 ProductPrice rows | `remote-readback-notes.md#seed-read-back` |
| ios_pull_apply | ios_release_flow | Pull/apply through existing Release services | iOS local SwiftData store | PASS; 2 catalog inserts, 6 ProductPrice inserts, valid baseline | `local-readback-notes.md#pull-apply-read-back` |
| local_readback | test_harness | Read local catalog and ProductPrice history | iOS local SwiftData store | PASS; supplier/category/products and previous/current prices verified | `local-readback-notes.md#pull-apply-read-back` |
| ios_local_edit | ios_release_flow | Confirm Product B local edit using existing pending path | iOS local SwiftData store | PASS; pending total 3, catalog pending 1, price pending 2 | `local-readback-notes.md#local-edit-and-pending` |
| ios_aggregated_push | ios_release_flow | Push aggregated pending catalog/ProductPrice | Supabase sandbox | PASS; catalog completed; ProductPrice verified by read-back; pending acknowledged | `remote-readback-notes.md#post-push-read-back` |
| remote_readback_post_push | test_harness | Read Product B catalog and ProductPrice rows after push | Supabase sandbox | PASS; B purchase 35.55 and retail 70.70 current rows verified; 8 price rows total | `remote-readback-notes.md#post-push-read-back` |
| lifecycle_smoke | test_harness | Exercise interrupt/readyToRetry/duplicate-run gates | Release lifecycle gate | PASS | `scenario-matrix.md#m97-07` |
| ux_smoke | manual_review | Static/XCTest UX review | Release manual sync UI | PASS | `ux-acceptance.md` |

## Final Outcome

- M97-01...10: PASS with evidence references.
- Runtime smoke: PASS on Supabase sandbox, iOS-first, owner-scoped, RLS normal app context.
- Production Swift patch: none retained; `no-code-needed`.
- Review fix: retained a gated, read-only XCTest harness in `iOSMerchandiseControlTests/Task097RuntimeSmokeTests.swift` for reproducible TASK-097 remote read-back; standard suite skips it unless `TASK097_RUNTIME_SMOKE=1`.
- Review verification: Debug build PASS, Release build PASS, targeted regressions PASS 246/0, full XCTest PASS 626 passed / 1 skipped / 0 failed.
- Cleanup: not performed; TASK097 rows are left as evidence.
- Final task state: TASK-097 DONE / Chiusura - REVIEW PASS; project IDLE; TASK-098 not opened.
