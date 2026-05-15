# TASK-110 — Supabase Access Matrix

Checkpoint: 2026-05-15 12:15 -0400.

## Grants/RLS per oggetto target

| Oggetto | RLS | anon | authenticated | service_role | Note |
|---|---|---|---|---|
| `inventory_suppliers` | enabled | nessun CRUD | select/insert/update | CRUD | delete diretto non concesso ad auth; usare tombstone/update |
| `inventory_categories` | enabled | nessun CRUD | select/insert/update | CRUD | delete diretto non concesso ad auth |
| `inventory_products` | enabled | nessun CRUD | select/insert/update | CRUD | delete diretto non concesso ad auth |
| `inventory_product_prices` | enabled | nessun CRUD | select/insert/update | CRUD | append-only/idempotente |
| `shared_sheet_sessions` | enabled | SELECT | CRUD | CRUD | anon SELECT da rimuovere per dati privati |
| `sync_events` | enabled | nessun CRUD | SELECT | CRUD | insert tramite RPC |
| `product_prices` legacy | enabled | CRUD grant | CRUD grant | CRUD grant | tabella vuota, senza owner; grants anon da rimuovere |

## Sequence/identity
- Sequenze public legacy concedono usage/select/update ad anon/authenticated/service_role.
- Per nuove sequenze usare grants espliciti minimi nella migration.

## Schema `public`
- `USAGE` presente per anon/authenticated/service_role.
- `CREATE` non presente per i ruoli client.

## Policy
- Inventory e shared sessions hanno policy owner-scoped basate su `auth.uid()`.
- `sync_events` ha select owner-scoped e RPC security definer per insert validato.

## Azioni raccomandate
1. Rimuovere anon `SELECT` da `shared_sheet_sessions`.
2. Rimuovere anon grants da `product_prices` legacy.
3. Aggiungere `deleted_at` owner-scoped a `shared_sheet_sessions` se si implementa tombstone History.
4. Aggiornare default privileges come rete di sicurezza, senza sostituire i grants espliciti per oggetto.
