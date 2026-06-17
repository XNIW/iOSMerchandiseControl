# Supabase Cleanup Dry-Run

- Tipo verifica: SUPABASE/READONLY
- Dry-run script: `scripts/supabase/task132_cleanup_test_residue_DRY_RUN.sql`
- Dry-run exit: `0`
- Candidate count query exit: `0`
- Apply script inspected: rollback-default, but would create backup tables and delete matching candidates if changed to COMMIT.
- Backup table name check exit: `0`; all planned `backup_task132_*_20260617` names are currently free.

## Candidate Counts

| table_name | candidate_count |
|---|---:|
| inventory_categories | 0 |
| inventory_product_prices | 2 |
| inventory_products | 1 |
| inventory_suppliers | 0 |
| shared_sheet_sessions | 50 |
| sync_events | 157 |

## Decision

Cleanup apply was not executed.

Reason: candidates include `shared_sheet_sessions` and historical `sync_events` for a real owner. Even though names/patterns strongly look like test residue and backup table names are free, deleting live cloud data requires explicit approval for the COMMIT step.

Required approval to proceed:
- Confirm applying `scripts/supabase/task132_cleanup_test_residue_APPLY.sql` after changing final `ROLLBACK` to `COMMIT`.
- Confirm global all-owner scope is acceptable, or provide the exact owner UUID scope to use.

