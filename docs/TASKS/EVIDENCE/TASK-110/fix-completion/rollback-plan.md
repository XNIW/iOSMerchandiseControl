# TASK-110 Fix Completion — Rollback Plan

Timestamp: 2026-05-15 13:02 -0400.

## Ledger repair rollback

If the ledger repair must be reverted:

1. Do not drop application data.
2. Restore the local timestamp if required by reviewer:
   - `20260417000000_task012_ownership_rls.sql` -> `20260417_task012_ownership_rls.sql`
3. Use `supabase migration repair --linked --status reverted <version>` only for metadata rows proven to be incorrect.
4. Re-run `supabase migration list --linked` and attach before/after output.

Expected current stance: no rollback needed; the normalized timestamp is safer for future CLI ordering.

## TASK-110 migration rollback

If `20260515161500_task110_history_tombstone_grants.sql` causes an issue:

1. Stop client deploy/use of History tombstone delete.
2. Preserve any rows with `shared_sheet_sessions.deleted_at is not null`.
3. Re-grant previous privileges only if needed:
   - `shared_sheet_sessions` had historical `anon SELECT`; target policy removes it.
   - `product_prices` legacy had broad anon grants; target policy removes them.
4. Only after tombstone preservation decision, optional DB rollback:
   - `alter table public.shared_sheet_sessions drop column if exists deleted_at;`
   - drop TASK-110 indexes if needed.
5. Run PostgREST schema reload and smoke tests again.

## Test data rollback

Use only `TASK110_TEST_*` rows for destructive create/update/delete validation. Cleanup should tombstone test History rows first, then hard delete only if reviewer/user explicitly approves for test rows.
