# Supabase Residue Before

- Tipo verifica: SUPABASE/READONLY
- Residue JSONPath matrix query eseguita: exit `0` (`raw/supabase-residue-jsonpath-before-redacted.raw`)
- Broad document scan disponibile solo come diagnostica: exit `0` (`raw/supabase-residue-before-redacted.raw`)
- Semantica primaria: match sui soli valori stringa JSON; `TASK%`, `TASK115_%`, `TASK123_%` mantengono significato prefix SQL con escape `_`.
- Nessun cleanup eseguito in questa fase.

## Non-zero

| table_name | pattern | rows_matching |
|---|---|---:|
| inventory_product_prices | `TASK%` | 1 |
| inventory_products | `TASK%` | 1 |
| shared_sheet_sessions | `%ANDROID_MATRIX%` | 18 |
| shared_sheet_sessions | `%IOS_MATRIX%` | 28 |
| shared_sheet_sessions | `%REALTIME%` | 14 |
| shared_sheet_sessions | `TASK%` | 50 |
| shared_sheet_sessions | `TASK115_%` | 14 |
| sync_events | `TASK%` | 157 |

## Full Matrix

| table_name | pattern | rows_matching |
|---|---|---:|
| inventory_categories | `%ANDROID_MATRIX%` | 0 |
| inventory_categories | `%BATCH_RT%` | 0 |
| inventory_categories | `%BURST%` | 0 |
| inventory_categories | `%IOS_MATRIX%` | 0 |
| inventory_categories | `%REALTIME%` | 0 |
| inventory_categories | `TASK%` | 0 |
| inventory_categories | `TASK115_%` | 0 |
| inventory_categories | `TASK123_%` | 0 |
| inventory_product_prices | `%ANDROID_MATRIX%` | 0 |
| inventory_product_prices | `%BATCH_RT%` | 0 |
| inventory_product_prices | `%BURST%` | 0 |
| inventory_product_prices | `%IOS_MATRIX%` | 0 |
| inventory_product_prices | `%REALTIME%` | 0 |
| inventory_product_prices | `TASK%` | 1 |
| inventory_product_prices | `TASK115_%` | 0 |
| inventory_product_prices | `TASK123_%` | 0 |
| inventory_products | `%ANDROID_MATRIX%` | 0 |
| inventory_products | `%BATCH_RT%` | 0 |
| inventory_products | `%BURST%` | 0 |
| inventory_products | `%IOS_MATRIX%` | 0 |
| inventory_products | `%REALTIME%` | 0 |
| inventory_products | `TASK%` | 1 |
| inventory_products | `TASK115_%` | 0 |
| inventory_products | `TASK123_%` | 0 |
| inventory_suppliers | `%ANDROID_MATRIX%` | 0 |
| inventory_suppliers | `%BATCH_RT%` | 0 |
| inventory_suppliers | `%BURST%` | 0 |
| inventory_suppliers | `%IOS_MATRIX%` | 0 |
| inventory_suppliers | `%REALTIME%` | 0 |
| inventory_suppliers | `TASK%` | 0 |
| inventory_suppliers | `TASK115_%` | 0 |
| inventory_suppliers | `TASK123_%` | 0 |
| shared_sheet_sessions | `%ANDROID_MATRIX%` | 18 |
| shared_sheet_sessions | `%BATCH_RT%` | 0 |
| shared_sheet_sessions | `%BURST%` | 0 |
| shared_sheet_sessions | `%IOS_MATRIX%` | 28 |
| shared_sheet_sessions | `%REALTIME%` | 14 |
| shared_sheet_sessions | `TASK%` | 50 |
| shared_sheet_sessions | `TASK115_%` | 14 |
| shared_sheet_sessions | `TASK123_%` | 0 |
| sync_events | `%ANDROID_MATRIX%` | 0 |
| sync_events | `%BATCH_RT%` | 0 |
| sync_events | `%BURST%` | 0 |
| sync_events | `%IOS_MATRIX%` | 0 |
| sync_events | `%REALTIME%` | 0 |
| sync_events | `TASK%` | 157 |
| sync_events | `TASK115_%` | 0 |
| sync_events | `TASK123_%` | 0 |
