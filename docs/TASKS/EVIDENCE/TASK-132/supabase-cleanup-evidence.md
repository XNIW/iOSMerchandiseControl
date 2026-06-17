# TASK-132 Supabase Cleanup Evidence

Status: SCRIPTED_ONLY

No live Supabase query, backup creation, tombstone, hard delete, or cleanup apply was executed.

Added scripts:

- `scripts/supabase/task132_audit_test_residue.sql`
- `scripts/supabase/task132_cleanup_test_residue_DRY_RUN.sql`
- `scripts/supabase/task132_cleanup_test_residue_APPLY.sql`

Safety notes:

- Audit and dry-run scripts use `begin read only`.
- Apply script ends with `rollback` by default.
- Candidate order follows FK safety: product prices, products, categories/suppliers only when unreferenced, sessions, sync events.
- `inventory_product_prices` and `sync_events` have no tombstone column in local migrations, so cleanup must be backup-backed and explicit.
