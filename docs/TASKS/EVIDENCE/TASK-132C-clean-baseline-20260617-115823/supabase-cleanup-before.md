# Supabase Cleanup Before

- Tipo verifica: SUPABASE/READONLY
- Linked smoke: PASS (`raw/supabase-select1.exit = 0`)
- Counts query: PASS (`raw/supabase-before-counts.exit = 0`)
- Candidate query: PASS (`raw/supabase-candidate-counts-before.exit = 0`)

## Counts Before

| table_name | total | active | tombstone |
|---|---:|---:|---:|
| inventory_categories | 28 | 28 | 0 |
| inventory_product_prices | 41111 | 41111 | 0 |
| inventory_products | 19696 | 19696 | 0 |
| inventory_suppliers | 59 | 59 | 0 |
| shared_sheet_sessions | 87 | 82 | 5 |
| sync_events | 1980 | 1980 | 0 |

## Active Candidate Counts Before

| table_name | candidate_count |
|---|---:|
| inventory_categories | 0 |
| inventory_product_prices | 2 |
| inventory_products | 1 |
| inventory_suppliers | 0 |
| shared_sheet_sessions | 47 |
| sync_events | 157 |

