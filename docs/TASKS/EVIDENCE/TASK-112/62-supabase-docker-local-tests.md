# TASK-112 — Supabase Docker local tests

Timestamp: 2026-05-20 22:26 -0400  
Agent: Codex / Executor

## Scope

Test realistici su Supabase local Docker, senza migration TASK-112 e senza reset globale. I dati sintetici sono stati creati dentro transazione PostgreSQL e rimossi con `ROLLBACK`.

## Results

| Scenario | Result | Evidence |
|---|---:|---|
| Schema bootstrap/status | PASS_WITH_NOTES | Stack local gia' running; `supabase db lint --local` PASS; non eseguito `db reset` per evitare reset distruttivo non necessario. |
| Required tables | PASS | Tabelle richieste presenti: catalog, ProductPrice, `shared_sheet_sessions`, `sync_events`. |
| RLS owner-scoped | PASS | RLS enabled; owner A read-back = 1, owner B read-back = 0 per righe sintetiche owner A. |
| Catalog CRUD | PASS | Supplier/category/product sintetici `TASK112_LOCAL_*` creati e letti nello stesso owner. |
| ProductPrice upsert/dedupe | PASS | Replay stessa chiave `(owner_user_id, product_id, type, effective_at)` resta a 1 row. |
| History/session push/pull contract | PASS | `shared_sheet_sessions` accetta payload array JSON e read-back owner-scoped. |
| `sync_events` insert/read | PASS | Row evento catalog/prices inserita e letta owner-scoped. |
| `record_sync_event` RPC | PASS | Due chiamate con stesso `client_event_id` producono una sola row logica. |
| Realtime publication | PASS_WITH_NOTES | Publication locale include `shared_sheet_sessions` e `sync_events`; catalog/ProductPrice non pubblicati direttamente. |
| Tombstone/delete DB contract | PASS_WITH_NOTES | Triggers/tombstone presenti; hard delete ProductPrice/catalog resta limitato dai grant storici. Live client tombstone matrix non eseguita. |
| Idempotent replay | PASS | ProductPrice + RPC replay idempotenti verificati localmente. |
| Pull delta/full reconciliation reason code | PASS_WITH_NOTES | DB supporta `sync_events`; reason-code client verificato solo da unit/static paths, non da live cross-platform gap simulation. |
| Cleanup | PASS | `ROLLBACK`; residue check `TASK112_LOCAL_*` = 0. |

## Privacy / safety

- Nessun token, JWT, email raw o service key e' stato scritto in evidence.
- Nessuna operazione `drop`, `truncate`, `db reset` o cleanup globale.
- Nessuna modifica remota live Supabase.

## Verdict

**PASS_WITH_NOTES** per Supabase local Docker. Il contratto DB/RLS/RPC locale e' utilizzabile e non richiede migration TASK-112, ma non sostituisce la matrice live con client iOS/Android autenticati.

## Final review+fix rerun update — 2026-05-20 22:26 -0400

| Scenario | Result | Evidence |
|---|---:|---|
| Status/lint rerun | PASS_WITH_NOTES | `supabase status` running con servizi core disponibili; `supabase db lint --local` PASS. |
| RPC idempotency rerun | PASS | `record_sync_event` replay con `TASK112_LOCAL_FINAL_REVIEW_EVENT` idempotente dentro transazione. |
| Owner isolation rerun | PASS | Owner sintetico differente vede 0 righe per il `client_event_id` creato nella stessa transazione. |
| Residue check rerun | PASS | `TASK112_LOCAL_*` / `TASK112_OFFLINE_*` residue count = 0 su catalog, ProductPrice, sessions e sync_events. |
