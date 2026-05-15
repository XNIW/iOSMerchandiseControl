# TASK-110 Fix Completion — Supabase Smoke Test After Migration

Timestamp: 2026-05-15 13:12 -0400.

## Migration apply

- `supabase db push --linked --dry-run` showed only `20260515161500_task110_history_tombstone_grants.sql`.
- `supabase db push --linked --yes` applied `20260515161500_task110_history_tombstone_grants.sql`.
- `supabase migration list --linked` after apply shows all local/remote migrations aligned through `20260515161500`.

## Schema verification

`information_schema.columns` confirms:

| Table | Column | Result |
|---|---|---|
| `public.shared_sheet_sessions` | `deleted_at` | present |

## Grant verification

Post-apply SQL privilege check:

| Check | Result |
|---|---|
| `anon` can select `shared_sheet_sessions` | false |
| `anon` can select `product_prices` legacy | false |
| `authenticated` can select `shared_sheet_sessions` | true |
| `authenticated` can update `shared_sheet_sessions` | true |

## Authenticated smoke

Executed as DB role `authenticated` with request JWT claims scoped to the existing test owner, without printing owner id:

1. Inserted `TASK110_SMOKE_HISTORY_TOMBSTONE`.
2. Updated display name.
3. Set `deleted_at = now()`.
4. Re-read row through owner-scoped RLS.
5. Cleaned up the smoke row.

Result:

| Assertion | Result |
|---|---|
| authenticated owner can read own tombstone | true |

## Anon negative smoke

REST Data API with publishable key only:

| Endpoint | HTTP | Body |
|---|---:|---|
| `/rest/v1/shared_sheet_sessions?select=remote_id&limit=1` | 401 | `42501 permission denied for table shared_sheet_sessions` |
| `/rest/v1/product_prices?select=id&limit=1` | 401 | `42501 permission denied for table product_prices` |
| `/rest/v1/inventory_products?select=id&limit=1` | 401 | `42501 permission denied for table inventory_products` |

## Cleanup

The smoke row `TASK110_SMOKE_HISTORY_TOMBSTONE` was hard-deleted after the smoke verification because it was created only for migration validation.
