# TASK-110 — Catalog/Delete Policy

Checkpoint: 2026-05-15 12:15 -0400.

## Catalogo
- Suppliers/categories/products usano `deleted_at`.
- Update dopo tombstone bloccato da trigger.
- Authenticated può update ma non delete diretto: coerente con soft-delete.

## History
- `shared_sheet_sessions` non ha `deleted_at`.
- iOS oggi hard-delete locale da SwiftData.
- Android deve essere verificato nei delete handler, ma schema remoto non supporta tombstone History.

## Policy target
- Aggiungere `deleted_at timestamptz` a `shared_sheet_sessions`.
- Push delete come update tombstone owner-scoped.
- Pull tombstone applica hide/delete locale senza perdere idempotenza.
- Non cancellare legacy remoti senza snapshot e rollback.

## Stato
- Migration preparata ma non applicata: `/Users/minxiang/Desktop/MerchandiseControlSupabase/supabase/migrations/20260515161500_task110_history_tombstone_grants.sql`.
- Blocker tecnico: `supabase migration list --linked` mostra divergenza tra migration locali e remote; applicare raw SQL produrrebbe ulteriore drift non tracciato.
- Quindi delete History tombstone resta non completato in questa execution; il resto della riconciliazione History è stato patchato come upsert idempotente full-reconcile.
