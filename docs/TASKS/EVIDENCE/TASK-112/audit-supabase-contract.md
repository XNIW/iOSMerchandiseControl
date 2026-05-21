# TASK-112 - Audit Supabase Contract

Timestamp: 2026-05-20 20:34 -0400

## Scope

Audit statico schema/migrations locali. Nessuna mutation Supabase eseguita.

## Workspace

- Path: `/Users/minxiang/Desktop/MerchandiseControlSupabase`
- Stato git: non e' un repository git.
- `supabase status`: bloccato da Docker daemon non raggiungibile.

## Tabelle/domini

| Dominio | Stato | Evidenza |
|---|---|---|
| suppliers | coperto | `inventory_suppliers`, `owner_user_id`, RLS owner, grants authenticated, tombstone `deleted_at`. |
| categories | coperto | `inventory_categories`, `owner_user_id`, RLS owner, tombstone `deleted_at`. |
| products | coperto | `inventory_products`, owner/RLS, FK remote supplier/category, tombstone. |
| ProductPrice | coperto | `inventory_product_prices`, unique `(owner_user_id, product_id, type, effective_at)`, RLS owner. |
| History/session | parziale | `shared_sheet_sessions` owner-scoped, tombstone/updated_at hardening TASK-110. |
| tombstone/delete | parziale | Catalog tombstone anti-resurrection e History tombstone presenti; hard delete grants catalog revocati. |
| sync_events | parziale | `sync_events` + `record_sync_event` presenti per `catalog`/`prices`; History non incluso nel dominio eventi. |
| watermarks/baselines | parziale | Watermark client-side Android; baseline client-side iOS. Nessuna tabella backend dedicata auditata. |
| outbox | parziale | Backend non contiene outbox; outbox e' client-side sync_events. |

## RLS/security

- Client mobile non richiede `service_role`.
- Policy owner-scoped presenti per catalog, ProductPrice, shared_sheet_sessions e sync_events select/RPC.
- `record_sync_event` usa `auth.uid()` come owner e idempotenza `(owner_user_id, client_event_id)`.
- Nota changelog Supabase 2026-04-28: nuove tabelle self-hosted non esposte automaticamente alla Data API; nessuna nuova tabella TASK-112 proposta in audit.

## Gap

- `sync_events` non rappresenta History/session.
- Retention/gap policy eventi non osservata come contratto DB verificabile.
- Ambiente local Supabase non avviabile senza Docker; live SQL/API non eseguito.

## Verdict audit Supabase

**GO_WITH_NOTES_NO_MIGRATION_YET**: schema locale copre i domini principali gia pianificati; nessuna migration TASK-112 e' tecnicamente giustificata prima di provare le carenze client-side.
