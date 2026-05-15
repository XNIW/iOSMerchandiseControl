# TASK-109 — 105 Review Supabase/Data/Performance

Review pass: 2026-05-15 02:25 -0400

## Schema e sicurezza

- Nessuna migration applicata in review.
- Nessun `service_role` aggiunto o usato nel client app.
- Nessun bypass RLS nel codice client.
- Seed eseguito via `supabase db query --linked` come admin/dev SQL test-only, non nel client.

## Query owner-scoped

- `shared_sheet_sessions` seed associato all'owner dominante del dataset dev, documentato solo come SHA-256 hash.
- Remote rows prima/dopo seed documentate in `104-review-history-live-non-empty.md`.

## Indici live verificati

Query riuscita:

- `shared_sheet_sessions_owner_remote_id_idx` su `(owner_user_id, remote_id)`
- `shared_sheet_sessions_pkey` su `remote_id`
- `sync_events_owner_client_event_id_unique`
- `sync_events_owner_created_at_idx`
- `sync_events_owner_domain_id_idx`
- `sync_events_owner_id_idx`
- `sync_events_owner_store_id_idx`

## RLS / grants

L'audit RLS/policy era gia' presente nell'evidence execution. Durante review, una query parallela su policy/rowsecurity ha riattivato `ECIRCUITBREAKER`, quindi non viene promossa a nuova evidence PASS. Non sono state applicate modifiche schema.

## Pooler/backoff

Osservazione reale:

- Query singole dopo cooldown funzionano.
- Query parallele Supabase CLI possono produrre `ECIRCUITBREAKER`.

Impatto TASK-109:

- Nessun codice client e' stato cambiato.
- La review non martella ulteriormente il pooler.
- Per rerun R4 usare query singole o app-auth, non parallelizzare CLI admin.

## Performance/data

- Count History in Options e' locale SwiftData count, coperto da `OptionsLocalDatabaseSummaryTests`.
- Remote History fetch iOS e' paginato in `fetchSharedSheetSessionsPage`.
- No duplicate History e' coperto da `HistorySessionSyncServiceTests.testSecondPullIsNoOpAndDoesNotDuplicateRemoteHistorySession`, ma resta da riprovare live app-auth sul seed creato.
