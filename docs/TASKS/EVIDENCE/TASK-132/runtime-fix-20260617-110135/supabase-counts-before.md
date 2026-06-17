# Supabase Counts Before

- Tipo verifica: SUPABASE/READONLY
- Audit script TASK-132 eseguito: exit `0` (`raw/supabase-audit-before-redacted.raw`)
- Counts query eseguita: exit `0` (`raw/supabase-counts-before-redacted.raw`)
- Scope: all owners, nessun cleanup/apply.

| table_name | total | active | tombstone |
|---|---:|---:|---:|
| inventory_categories | 28 | 28 | 0 |
| inventory_product_prices | 41111 | 41111 | 0 |
| inventory_products | 19696 | 19696 | 0 |
| inventory_suppliers | 59 | 59 | 0 |
| shared_sheet_sessions | 87 | 82 | 5 |
| sync_events | 1979 | 1979 | 0 |
