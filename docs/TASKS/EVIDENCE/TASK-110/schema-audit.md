# TASK-110 — Supabase Schema Audit

Checkpoint: 2026-05-15 12:15 -0400.

## Tabelle target public

### `shared_sheet_sessions`
- PK: `remote_id text`
- Owner: `owner_user_id uuid`
- Payload: `data jsonb`, `session_overlay jsonb`
- Sync fields: `updated_at timestamptz`
- Mancante: `deleted_at`
- RLS: enabled
- Policies owner-scoped per authenticated select/insert/update/delete.
- Nota critica: anon ha `SELECT` grant; RLS non restituisce righe senza owner ma endpoint risponde 200.

### `inventory_suppliers`
- `id uuid`, `owner_user_id uuid`, `name`, `updated_at`, `deleted_at`
- RLS enabled
- Unique parziale owner/lower(name) active.
- Trigger updated_at e blocco update post-tombstone.

### `inventory_categories`
- Come suppliers.

### `inventory_products`
- `id uuid`, `owner_user_id uuid`, barcode/item/product fields, supplier/category refs, `updated_at`, `deleted_at`
- RLS enabled
- Unique parziale owner/barcode active.
- Trigger updated_at e blocco update post-tombstone.

### `inventory_product_prices`
- `id uuid`, `owner_user_id uuid`, `product_id uuid`, type/price/effective/source/note/created.
- RLS enabled.
- FK product cascade.
- Unique owner/product/type/effective_at.
- Nessun `deleted_at`: trattata append-only/idempotente.

### `sync_events`
- `id bigint`, `owner_user_id`, domain/event_type/source/client_event_id, `entity_ids`, `metadata`, `created_at`, `expires_at`.
- RLS enabled.
- Select owner-scoped.
- Insert via RPC `record_sync_event`.
- Domain/event_type attuali coprono catalog/prices, non History.

### `product_prices` legacy
- Tabella legacy senza owner.
- Count 0.
- RLS enabled ma grants broad storici a anon/authenticated/service_role.
- Raccomandazione: revocare almeno grants anon; non usarla per dati privati client.

## Views
- Nessuna view target rilevata per TASK-110.

## RPC/functions
- `record_sync_event(...)`
  - `security definer`
  - `search_path`: `public, pg_temp`
  - Execute: authenticated/service_role.
  - Valida `auth.uid()` vs `p_owner_user_id`.
- Helper/trigger functions:
  - `set_updated_at`
  - `set_inventory_catalog_updated_at`
  - `inventory_catalog_block_update_when_tombstoned`
  - `rls_auto_enable`

## Constraints e indici
- Catalog unique active e owner-scoped presenti.
- Product price unique idempotente presente.
- `shared_sheet_sessions` manca tombstone e indice owner/deleted.

## Default privileges
- Default privileges storici concedono automaticamente privilegi ampi a `anon`, `authenticated`, `service_role` per tabelle/funzioni/sequenze create da `postgres` e `supabase_admin`.
- Questo contrasta con la policy target Supabase 2026: grants espliciti per oggetto nella stessa migration.
