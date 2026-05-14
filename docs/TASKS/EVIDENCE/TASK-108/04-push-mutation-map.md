# TASK-108 Evidence 04 — Push Mutation Map

Status: EXECUTED (STATIC audit + existing tests), live read-back NOT RUN.

Initial audit scope:
- `DatabaseView`
- `EditProductView`
- `ProductPriceHistoryView`
- `LocalPendingChange`
- `LocalPendingAggregatedPushPlanner`
- `SupabaseManualPushService`

Result:
- Database product/supplier/category/ProductPrice flows still use existing `LocalPendingChange` and aggregated push providers.
- Release factory remains wired to catalog and ProductPrice push providers.
- No new automatic mass push was introduced.

Evidence:
- Debug build/run PASS.
- Manual sync targeted tests PASS 123/123.
- Live Supabase push/read-back NOT RUN.

FIX/COMPLETION update 2026-05-13:
- Added `historySession` as a separate pending entity kind so History/session changes do not get folded into catalog push batches.
- Catalog/ProductPrice push planning remains bounded to existing domains; History/session push is handled by `HistorySessionSyncService`.
- Existing full suite push/read-back/retry contract tests passed in the 659/0 run.
- Live app-auth read-back matrix remains NOT RUN.

Targeted Options cleanup FIX update 2026-05-13 20:45 -0400:
- No push mutation code was widened during Options cleanup.
- Options now surfaces local pending count in the public Local database status section.
- Live push/read-back remains NOT RUN / BLOCKED_APP_AUTH. Evidence: `26-live-database-push-smoke.md`.
