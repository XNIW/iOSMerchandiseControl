# Supabase Cleanup Backups

- Tipo verifica: SUPABASE/MUTATING BACKUP
- Backup/apply SQL: `raw/supabase-backup-cleanup-apply.sql`
- Backup/apply exit: `0`
- Suffix: `20260617_120028`
- Backup counts query: PASS (`raw/supabase-backup-counts.exit = 0`)
- Redacted samples query: PASS after SQL syntax retry (`raw/supabase-backup-samples-redacted.exit = 0`)

## Backup Tables

| backup_table | rows |
|---|---:|
| backup_task132c_inventory_product_prices_20260617_120028 | 2 |
| backup_task132c_inventory_products_20260617_120028 | 1 |
| backup_task132c_shared_sheet_sessions_20260617_120028 | 47 |
| backup_task132c_sync_events_20260617_120028 | 157 |

## Notes

- Backup tables were created without `IF NOT EXISTS`.
- Samples are redacted with row/owner hashes and truncated test labels in `raw/supabase-backup-samples-redacted.raw`.

