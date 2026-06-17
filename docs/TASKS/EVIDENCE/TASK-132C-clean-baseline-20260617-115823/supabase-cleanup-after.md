# Supabase Cleanup After

- Tipo verifica: SUPABASE/READONLY
- Counts query: PASS (`raw/supabase-after-counts.exit = 0`)
- Candidate query: PASS (`raw/supabase-candidate-counts-after.exit = 0`)

## Counts After

| table_name | total | active | tombstone |
|---|---:|---:|---:|
| inventory_categories | 28 | 28 | 0 |
| inventory_product_prices | 41109 | 41109 | 0 |
| inventory_products | 19696 | 19695 | 1 |
| inventory_suppliers | 59 | 59 | 0 |
| shared_sheet_sessions | 87 | 35 | 52 |
| sync_events | 1823 | 1823 | 0 |

## Active Candidate Counts After

| table_name | candidate_count |
|---|---:|
| inventory_categories | 0 |
| inventory_product_prices | 0 |
| inventory_products | 0 |
| inventory_suppliers | 0 |
| shared_sheet_sessions | 0 |
| sync_events | 0 |

## Result

Supabase user-visible TASK/test residue targeted by TASK-132C is `0` after cleanup. Product/session fixture rows with `deleted_at` support were tombstoned; price/sync_event fixture rows were backed up and deleted.

