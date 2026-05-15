# TASK-110 — Reconciliation Report

Checkpoint: 2026-05-15 12:15 -0400.

## Domande P3

### 1. Quante sessioni History ci sono davvero su Supabase per l'utente?
- Supabase `shared_sheet_sessions`: 1 per owner osservato `bf727712...257e`.

### 2. Android e iOS usano stesso owner_user_id?
- Stesso project ref verificato.
- iOS local è allineato al dataset remoto dello stesso owner osservato.
- Android local contiene dati compatibili ma driftati.
- JWT `sub` runtime live non ancora estratto al checkpoint; verifica finale richiesta in manual test.

### 3. Le sessioni Android mancanti sono local-only, remote_id null, dirty, clean, legacy, synced erroneamente o bloccate da dirtyLocalSkips?
- Android `history_entries`: 7.
- Android `history_entry_remote_refs`: 6.
- Android senza ref: 1.
- Ref dirty: 0.
- Ref clean localmente: 6.
- Remote Supabase: 1.
- Root cause verificata: almeno parte delle sessioni Android è local-only/stale ma marcata clean nei metadata locali, quindi non viene ripushata dalla logica che seleziona solo dirty/pending.

### 4. iOS ha local-only non pushate o mostra solo remote?
- iOS ha 1 History con `remoteID != nil`, dirty 0.
- iOS mostra/cache il remoto allineato.

### 5. Il bootstrap Android/iOS parte dopo auth stable o durante no_auth?
- Android `MerchandiseControlApplication` ripristina sessione e poi schedula bootstrap/push su `SignedIn`.
- Android auto History osservata: push coordinator schedula push, ma non esegue una riconciliazione full pull+push delle sessioni clean/stale.
- iOS usa provider session e richiede sessione auth in service; mapping no_auth distinto presente.

### 6. Il sync manuale e automatico si sovrappongono?
- Android usa tracker/mutex per catalog e flight owner per sessioni, ma History auto push e manual refresh sono in coordinatori separati.
- iOS manual coordinator ha run gate/static active run.
- Verifica runtime di overlap ancora richiesta.

### 7. Delete History oggi è local-only o produce tombstone/outbox?
- iOS `HistoryView` cancella localmente con `context.delete(entry)`.
- Supabase `shared_sheet_sessions` non ha `deleted_at`.
- Conclusione: delete History non è tombstone-based end-to-end al checkpoint.

### 8. ProductPrice perché ha `pricesSkippedNoProductRef` massivo?
- Android locale ha 19695 product refs ma 39498 price refs; Supabase/iOS hanno 41109 prices.
- Il codice Android salta price rows se manca il bridge product remote_id -> local id.
- Il drift attuale mostra 1611 prezzi mancanti lato Android. Il messaggio massivo storico è coerente con bridge catalogo non disponibile o non riallineato prima del pull prezzi in alcuni run.

### 9. Catalog bridge viene eseguito prima dei prezzi?
- Nel full catalog sync Android attuale: catalog pull/realign precede price pull.
- In run storici o incremental/event-driven potrebbe restare gap; serve assicurare bridge before prices in ogni run completo e non full pull cieco.

### 10. Product update Android/iOS produce pending push e remote update?
- Non ancora verificato manualmente al checkpoint.

### 11. I grants/RLS/Data API possono bloccare select/insert/update/delete?
- Sì. 42501 anon su `inventory_products` verificato e atteso.
- Authenticated ha grants necessari per inventory e shared sessions.
- `shared_sheet_sessions` anon SELECT e `product_prices` legacy anon grants sono troppo permissivi.

### 12. Il problema è logica sync, schema, RLS/grants, ambiente, o combinazione?
- Combinazione:
  - ambiente project ref: OK;
  - Android History reconciliation: root cause primaria per sessioni invisibili;
  - schema History: manca tombstone per delete propagation;
  - grants: hardening necessario per anon shared/legacy;
  - catalog/prices Android: drift e pull prezzi non incrementale da correggere/validare.

## Fix applicato

### Android
- `pushHistorySessionsToRemote(..., candidateUids = null)` ora esegue full reconciliation user-visible: upsert idempotente anche delle sessioni clean/stale.
- Il push preciso con `candidateUids` continua a saltare le sessioni già synced.
- `HistorySessionPushCoordinator` su `login_fresh_tick` esegue bootstrap pull History e poi full reconciliation push, così login/re-login non dipende solo dal dirty set.

### iOS
- `HistorySessionSyncService.pushPendingHistorySessions(..., includeSynced: true)` consente full reconciliation idempotente anche per sessioni clean/stale.
- `SupabaseManualSyncReleaseFactory` ora orchestra History come pull iniziale → full reconciliation push → pull di conferma.

## Non completato per blocker/scope residuo
- Delete History tombstone richiede migration `shared_sheet_sessions.deleted_at`; migration preparata ma non applicata per divergence migration ledger Supabase.
- ProductPrice Android resta driftato: 39498 locali vs 41109 remoti/iOS; diagnosticato ma non risolto in questa patch.
- Manual cross-platform create/update/delete live non eseguito: richiede app runtime autenticato su entrambi i client e migration tombstone applicata per coprire delete.

## Classificazione entità

| Entità | Stato osservato |
|---|---|
| History Supabase/iOS | matched |
| History Android extra con clean ref | local-only/stale-clean |
| History Android senza ref | local-only legacy |
| Product catalog iOS/Supabase | matched |
| Product catalog Android products | matched count |
| Suppliers/categories Android | local-only/stale extras |
| Product prices Android | local missing vs remote/iOS |
| Tombstone History | schema missing |
| Orphan price | diagnostica da completare dopo bridge fix |
