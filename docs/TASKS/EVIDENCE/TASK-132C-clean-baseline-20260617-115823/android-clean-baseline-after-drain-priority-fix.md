# Android clean baseline after drain-priority fix

| metric | value |
|---|---:|
| products | 19695 |
| suppliers | 59 |
| categories | 28 |
| product_prices | 41109 |
| history_active | 35 |
| history_total | 35 |
| sync_event_outbox | 0 |
| pending_catalog_tombstones | 0 |
| watermarks | 1 |
| task_suppliers | 0 |
| task_categories | 0 |
| task_products | 0 |
| task_prices | 0 |
| task_history | 0 |

Evidence:
- Raw polling: `raw/android-recovery-poll-counts-after-drain-priority-fix.txt`.
- DB snapshot: `raw/android-current-app_database-after-drain-priority-fix.sqlite`.

Result:
- Android Room reached Supabase active-count parity after reset/bootstrap.
- `CatalogAutoSyncCoordinator` now yields drain to required bootstrap, so lookup/history rows no longer suppress catalog baseline recovery.
- User-visible TASK residue is `0`, pending outbox is `0`.

