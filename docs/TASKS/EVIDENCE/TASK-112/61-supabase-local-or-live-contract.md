# TASK-112 — Supabase local/live contract

Timestamp: 2026-05-20 22:26 -0400  
Agent: Codex / Executor

## Target

Supabase local Docker stack in `/Users/minxiang/Desktop/MerchandiseControlSupabase`.

## Schema / RLS / grants

| Area | Stato | Evidenza |
|---|---:|---|
| Required tables | PASS | `inventory_suppliers`, `inventory_categories`, `inventory_products`, `inventory_product_prices`, `shared_sheet_sessions`, `sync_events` presenti in `public`. |
| RLS enabled | PASS | `relrowsecurity=true` su tutte le tabelle richieste. |
| Owner-scoped policies | PASS | Policy `auth.uid() = owner_user_id` per catalog, ProductPrice, History/session; `sync_events_select_owner` owner-scoped. |
| Authenticated grants | PASS_WITH_NOTES | `authenticated` ha SELECT/INSERT/UPDATE su catalog/ProductPrice, SELECT/INSERT/UPDATE/DELETE su `shared_sheet_sessions`, SELECT su `sync_events`; catalog hard delete e ProductPrice hard delete restano revocati come da TASK-038. |
| Anon grants | PASS | Nessun grant anon sulle tabelle richieste nel read-back locale. |
| `record_sync_event` | PASS_WITH_NOTES | Funzione presente come `SECURITY DEFINER`, signature `record_sync_event(text,text,integer,jsonb,uuid,text,text,uuid,text,jsonb)`, EXECUTE a `authenticated` e non ad `anon`/`public`. |
| Realtime publication | PASS_WITH_NOTES | `supabase_realtime` include `shared_sheet_sessions` e `sync_events`; non include catalog/ProductPrice table publication diretta. |
| Constraints | PASS_WITH_NOTES | ProductPrice unique `(owner_user_id, product_id, type, effective_at)` presente; FK ProductPrice→Product presente; `shared_sheet_sessions.data` richiede JSON array. |
| Triggers | PASS_WITH_NOTES | Catalog updated_at/tombstone block triggers presenti; `shared_sheet_sessions` updated_at trigger presente da migration TASK-110. |

## Local transactional contract test

Eseguito con `docker exec ... psql`, dentro `BEGIN`/`ROLLBACK`, con due owner sintetici e nessuna email/token raw.

| Scenario | Stato | Evidenza |
|---|---:|---|
| Owner A CRUD suppliers/categories/products/ProductPrice/History/session/sync_events | PASS | Tutti i conteggi read-back owner A = 1 dentro transazione. |
| ProductPrice replay same effective key | PASS | Seconda insert con stessa chiave effettiva deduped via `ON CONFLICT`; conteggio ProductPrice = 1. |
| `record_sync_event` replay idempotente | PASS | Due chiamate con stesso `client_event_id` producono una sola row e un solo id distinto. |
| Owner B isolation | PASS | Owner B non vede righe owner A per supplier/product/session/sync_events. |
| Cleanup | PASS | Transazione rollback; post-check residui `TASK112_LOCAL_*` = 0 su supplier/session/sync_events. |

## Gap non bloccanti per contratto DB locale

- `sync_events` resta limitato a `catalog` / `prices`; History/session usa `shared_sheet_sessions` e non e' dominio eventi separato.
- La pubblicazione Realtime locale non include direttamente supplier/category/product/ProductPrice; la pipeline client deve usare `sync_events`/foreground/reconnect per catalog/prices.
- Local stack prova il contratto DB/RLS/RPC, ma non sostituisce la matrice live iOS↔Android con client autenticati.

## Verdict

**PASS_WITH_NOTES** per contratto Supabase locale: Docker/local DB ora sono usabili per test TASK-112; nessuna migration TASK-112 e' giustificata dai check DB locali eseguiti.

## Final review+fix rerun update — 2026-05-20 22:26 -0400

Rieseguiti check SQL locali con `psql` su porta local Supabase:

- `record_sync_event` idempotente: due chiamate con lo stesso `client_event_id` restituiscono lo stesso id.
- Owner isolation: owner diverso vede `0` righe per l'evento sintetico.
- RLS enabled confermato su `inventory_suppliers`, `inventory_categories`, `inventory_products`, `inventory_product_prices`, `shared_sheet_sessions`, `sync_events`.
- Policy owner-scoped presenti per catalog/ProductPrice/session e `sync_events_select_owner`.
- Unique ProductPrice `(owner_user_id, product_id, type, effective_at)` presente.
- `supabase_realtime` include `shared_sheet_sessions` e `sync_events`.
- Tutto dentro transazione con `ROLLBACK`; nessuna migration o mutation live.

## Final closure live contract update — 2026-05-21 00:01 -0400

Live schema/RLS/grants were audited again before DONE:

- RLS remains enabled on `inventory_suppliers`, `inventory_categories`, `inventory_products`, `inventory_product_prices`, `shared_sheet_sessions`, and `sync_events`.
- `authenticated` retains SELECT/INSERT/UPDATE for catalog/ProductPrice tables and does not receive catalog/ProductPrice DELETE.
- No migration/grant/RLS change was applied because the app runtime does not require hard delete for TASK-112; the failing hard delete was only synthetic cleanup.
- `shared_sheet_sessions` keeps its owner DELETE policy; `sync_events` remains select-only.
- Admin/postgres was used only from backend CLI for scoped cleanup of `TASK112_*` / `TASK112_OFFLINE_*` / `TASK112_FINAL_*` synthetic rows.
- Final residue query returned zero rows for all TASK112 prefixes and `TASK112_ANY`.

Final Supabase contract verdict: **PASS** with security posture preserved.
