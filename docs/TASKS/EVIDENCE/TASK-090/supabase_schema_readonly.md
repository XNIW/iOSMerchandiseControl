# TASK-090 Supabase schema read-only evidence

Timestamp locale: 2026-05-09 17:03 -0400

Source: local filesystem `/Users/minxiang/Desktop/MerchandiseControlSupabase`, read-only.

## Catalog tables

Migration: `supabase/migrations/20260417120000_task013_inventory_catalog_rls.sql`.

| Table | Key columns | Constraints/RLS observed |
|-------|-------------|--------------------------|
| `public.inventory_suppliers` | `id`, `owner_user_id`, `name`, `updated_at` | unique index on `(owner_user_id, lower(name))`; RLS owner policies; authenticated DML grants in original migration |
| `public.inventory_categories` | `id`, `owner_user_id`, `name`, `updated_at` | unique index on `(owner_user_id, lower(name))`; RLS owner policies |
| `public.inventory_products` | `id`, `owner_user_id`, `barcode`, prices, lookup FKs, `stock_quantity`, `updated_at` | unique index on `(owner_user_id, barcode)`; RLS owner policies |

Tombstone migration `20260418200000_task019_inventory_catalog_tombstone.sql` adds `deleted_at` and active unique indexes for catalog rows.

TASK-086 migration `20260509120000_task086_inventory_catalog_updated_at_triggers.sql` adds updated_at triggers for catalog tables only; no ProductPrice/backfill/RLS changes.

## ProductPrice table

Migration: `supabase/migrations/20260417200000_task016_inventory_product_prices.sql`.

| Table | Key columns | Constraints/RLS observed |
|-------|-------------|--------------------------|
| `public.inventory_product_prices` | `id`, `owner_user_id`, `product_id`, `type`, `price`, `effective_at`, `source`, `note`, `created_at` | `type IN ('PURCHASE', 'RETAIL')`; unique `(owner_user_id, product_id, type, effective_at)`; RLS owner policies |

TASK-038 migration revokes authenticated DELETE grants for inventory tables, including ProductPrice; no destructive operation was run in TASK-090.

## Sync events

Migration: `supabase/migrations/20260424021936_task045_sync_events.sql`.

- `public.sync_events` is an event/catch-up layer, not business SoT.
- Domains constrained to `catalog` and `prices`.
- Authenticated users have SELECT via RLS owner policy.
- `record_sync_event` returns one `public.sync_events` row, per migration README.

## Scope conclusion

Schema supports the ProductPrice logical key used by iOS tests and TASK-088 evidence. No new table, column, policy, migration, repair, backfill, or SQL patch was introduced in TASK-090.
