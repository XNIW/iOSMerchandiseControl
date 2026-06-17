# Supabase Cleanup Apply

- Tipo verifica: SUPABASE/MUTATING CLEANUP
- Approval source: `/Users/minxiang/.codex/attachments/5fc49aa9-28af-488a-8986-49aa8bfd2fe9/pasted-text.txt`
- Exact approval observed: `APPROVO TASK132C CLEANUP APPLY + LOCAL RESET`
- Apply SQL: `raw/supabase-backup-cleanup-apply.sql`
- Apply exit: `0`

## Cleanup Strategy

| table | strategy |
|---|---|
| inventory_product_prices | hard-delete after backup, because table has no `deleted_at` and candidates are fixture rows |
| inventory_products | soft-delete after backup via `deleted_at = now()`, `updated_at = now()` |
| shared_sheet_sessions | soft-delete after backup via `deleted_at = now()`, `updated_at = now()` |
| sync_events | hard-delete after backup, because both simulator clients are being reset and local watermarks will be rebuilt |
| inventory_suppliers | no-op, candidates `0` |
| inventory_categories | no-op, candidates `0` |

## Watermark Decision

`sync_events` TASK candidates were deleted only after backup. This is coupled to FASE 3 local simulator reset: iOS SwiftData and Android Room local watermarks must be reset/rebuilt from the cleaned cloud baseline before runtime/performance evidence is accepted.

