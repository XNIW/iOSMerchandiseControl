# TASK-064 — Supabase `sync_events` outbox sending stale recovery iOS

**Stato tracking:** TASK-064 **DONE / Chiusura** — Review tecnica severa **APPROVED_FIXED_DIRECTLY** su override esplicito utente; workspace IDLE.

## Informazioni generali

| Campo | Valore |
|-------|--------|
| **Task ID** | TASK-064 |
| **Titolo** | Supabase sync_events outbox sending stale recovery iOS |
| **File task** | `docs/TASKS/TASK-064-supabase-sync-events-outbox-sending-stale-recovery-ios.md` |
| **Stato** | DONE |
| **Fase attuale** | Chiusura |
| **Responsabile attuale** | Nessuno / Workspace IDLE |
| **Data creazione** | 2026-05-07 |
| **Ultimo aggiornamento** | 2026-05-07 20:26 -04 — Review tecnica severa completata con **APPROVED_FIXED_DIRECTLY**; fix piccoli mirati applicati; build/test/check finali PASS; TASK-064 chiuso in **DONE / Chiusura** su override esplicito utente. |
| **Ultimo agente** | Codex / Reviewer+Fixer |

## Dipendenze

- **Dipende da**
  - **TASK-063** — planning production-safe orchestrator: ordine slice, D63-05, invarianti e anti-scope.
  - **TASK-060** — `SyncEventOutboxDrainService` manuale/controllato via `SyncEventRecording`.
  - **TASK-061** — UI DEBUG drain manuale; non modificare salvo compilazione.
  - **TASK-062** — validazione operativa UI DEBUG; nessun live drain obbligatorio.
- **Non riapre**
  - **TASK-063** resta base planning precedente, non execution.

## Scopo

Implementare una slice iOS piccola e verificabile per recuperare entry outbox `sync_events` rimaste in stato `sending` dopo crash, cancellazione o interruzione di una run.

La recovery deve essere locale, owner-scoped, bounded, privacy-safe e integrata prima del drain manuale esistente. Non introduce UI Release, coordinator, timer, worker, BGTask, Realtime, SQL, migration, RPC live o cleanup distruttivo.

## Stati outbox reali

Stati esistenti rilevati nel codice:

- `pending`
- `sending`
- `sent`
- `failedRetryable`
- `blockedContract`
- `blockedAuth`
- `blockedSchema`
- `dead`
- `localOnly`

Non verranno introdotti nuovi stati. La recovery userà la state machine esistente:

- `sending` stale con tentativi residui -> `failedRetryable` e subito retryable;
- `sending` stale che esaurisce o ha già esaurito i tentativi -> `dead`;
- entry fresche o non `sending` -> nessuna modifica.

## Anti-scope TASK-064

- Solo iOS.
- Solo outbox `sync_events`: state/store/drain/test locali.
- Nessuna UI Release.
- Nessuna modifica alla card DEBUG salvo necessità di compilazione.
- Nessun coordinator completo.
- Nessuna sync automatica.
- Nessun timer, BGTask, Realtime, worker o avvio app automatico.
- Nessuna chiamata Supabase live.
- Nessuna modifica SQL, migration, RPC, RLS o `db push`.
- Nessun cleanup distruttivo outbox: no delete/truncate/reset massivo.
- Nessun Product/ProductPrice full sync.
- Nessuna modifica Android.
- Non creare TASK-065.
- A fine execution non dichiarare DONE; la chiusura è consentita solo in review con override esplicito utente.

## Criteri di accettazione

| ID | Criterio | Tipo verifica |
|----|----------|---------------|
| T64-01 | `sending` stale sotto max attempts viene recuperato a stato retryable esistente. | STATIC/XCTest |
| T64-02 | `sending` stale exhausted non torna pending/retryable. | STATIC/XCTest |
| T64-03 | `sending` recente non viene toccato. | STATIC/XCTest |
| T64-04 | `pending` / `failedRetryable` / `sent` non vengono toccati. | STATIC/XCTest |
| T64-05 | Entry di altro owner non viene toccata. | STATIC/XCTest |
| T64-06 | Payload replay (`entityIDsPayloadJSON`, `metadataPayloadJSON`) resta invariato. | XCTest |
| T64-07 | Recovery bounded rispetta scan limit. | XCTest |
| T64-08 | Drain manuale chiama recovery prima di processare. | XCTest |
| T64-09 | Cancellation non produce success falso. | XCTest |
| T64-10 | Save failure non dichiara recovery completata. | XCTest |
| T64-11 | Outcome/risultato espone `recoveredCount`, `exhaustedCount`, `skippedFreshSendingCount`. | STATIC/XCTest |
| T64-12 | Anti-scope confermato: no UI nuova, no auto-sync, no Supabase live, no SQL, no cleanup. | STATIC/GREP |

## Execution (Codex)

### Avvio EXECUTION controllata — 2026-05-07 20:04 -04

**User override operativo:** l'utente ha richiesto esplicitamente di aprire TASK-064 come prima slice operativa dopo TASK-063 e di non eseguire TASK-063. Impatto workflow: TASK-064 nasce direttamente con scopo, criteri e handoff operativo; Codex procede in EXECUTION controllata senza ridefinire il piano orchestratore e senza creare TASK-065.

**Obiettivo compreso:** hardening locale dell'outbox `sync_events` per recuperare entry `sending` stale in modo owner-scoped, bounded, privacy-safe e testabile, integrandolo prima del drain manuale esistente.

**File letti prima di modificare codice:**
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-063-supabase-production-safe-sync-orchestrator-planning-ios.md`
- `docs/TASKS/TASK-060-supabase-sync-events-outbox-drain-g2-ios.md`
- `docs/TASKS/TASK-061-supabase-sync-events-manual-drain-debug-ui-ios.md`
- `docs/TASKS/TASK-062-supabase-sync-events-manual-drain-operational-validation-ios.md`
- `iOSMerchandiseControl/SyncEventOutboxEntry.swift`
- `iOSMerchandiseControl/SyncEventOutboxState.swift`
- `iOSMerchandiseControl/SyncEventOutboxDrainService.swift`
- `iOSMerchandiseControl/SyncEventOutboxEnqueueService.swift`
- `iOSMerchandiseControl/SyncEventRecording.swift`
- `iOSMerchandiseControlTests/SyncEventOutboxDrainServiceTests.swift`
- `iOSMerchandiseControlTests/SyncEventOutboxLocalStoreTests.swift`
- `iOSMerchandiseControlTests/SyncEventOutboxStateTests.swift`
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/docs/TASKS/TASK-070-outbox-retry-head-of-line-logging-strutturato.md` *(solo riferimento funzionale; nessun Kotlin copiato o modificato)*

**File previsti in modifica:**
- `iOSMerchandiseControl/SyncEventOutboxState.swift`
- `iOSMerchandiseControl/SyncEventOutboxEntry.swift`
- `iOSMerchandiseControl/SyncEventOutboxDrainService.swift`
- `iOSMerchandiseControlTests/SyncEventOutboxStateTests.swift`
- `iOSMerchandiseControlTests/SyncEventOutboxLocalStoreTests.swift`
- `iOSMerchandiseControlTests/SyncEventOutboxDrainServiceTests.swift`
- `docs/TASKS/TASK-064-supabase-sync-events-outbox-sending-stale-recovery-ios.md`
- `docs/MASTER-PLAN.md`

**Piano minimo:**
1. Aggiungere helper state machine per riconoscere e recuperare `sending` stale senza nuovi stati.
2. Aggiungere metodo store owner-scoped e bounded per scandire entry `sending`, modificando solo quelle stale.
3. Invocare la recovery nel drain service prima di `fetchRetryable`, con soglia default 10 minuti e override nei test.
4. Estendere l'outcome del drain con conteggi recovery privacy-safe.
5. Coprire i criteri T64 con XCTest mirati e controlli anti-scope.

### Completamento EXECUTION — 2026-05-07 20:13 -04

#### Obiettivo compreso

Implementare il minimo hardening locale per evitare che entry outbox `sync_events` restino bloccate in `sending` dopo crash/cancellazione/interruzione: recovery owner-scoped e bounded prima del drain manuale, con soglia default conservativa e override test, senza UI/coordinator/auto-sync/Supabase live/SQL/cleanup.

#### File controllati

- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-063-supabase-production-safe-sync-orchestrator-planning-ios.md`
- `docs/TASKS/TASK-060-supabase-sync-events-outbox-drain-g2-ios.md`
- `docs/TASKS/TASK-061-supabase-sync-events-manual-drain-debug-ui-ios.md`
- `docs/TASKS/TASK-062-supabase-sync-events-manual-drain-operational-validation-ios.md`
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/docs/TASKS/TASK-070-outbox-retry-head-of-line-logging-strutturato.md` *(solo riferimento funzionale; nessun Kotlin copiato/modificato)*
- `iOSMerchandiseControl/SyncEventOutboxState.swift`
- `iOSMerchandiseControl/SyncEventOutboxEntry.swift`
- `iOSMerchandiseControl/SyncEventOutboxDrainService.swift`
- `iOSMerchandiseControl/SyncEventOutboxEnqueueService.swift`
- `iOSMerchandiseControl/SyncEventRecording.swift`
- test outbox/store/drain/enqueue/recorder esistenti.

#### Piano minimo

1. Estendere la state machine senza nuovi stati.
2. Aggiungere recovery nello store con owner scope e scan limit.
3. Invocare recovery nel drain service prima di `fetchRetryable`.
4. Esporre conteggi aggregati nell'outcome.
5. Coprire recovery e regressioni con XCTest + build + grep anti-scope.

#### Modifiche fatte

- `SyncEventOutboxState.swift`
  - aggiunto `SyncEventOutboxSendingRecoveryResult`;
  - aggiunta soglia default `defaultSendingStaleInterval = 10 * 60`;
  - aggiunti helper `isSendingStale` e `recoverStaleSending`;
  - recovery sotto max attempts -> `failedRetryable` immediatamente retryable, senza consumare attempt;
  - recovery already exhausted -> `dead`, con errore privacy-safe `sending_stale_recovered`.
- `SyncEventOutboxEntry.swift`
  - aggiunto `SyncEventOutboxLocalStore.recoverStaleSending(...)`;
  - query solo `ownerUserID + statusRaw == sending`;
  - scan limit default 50, hard cap 200;
  - fresh `sending` conteggiate come skip, non mutate;
  - payload, shapes, `changedCount`, `clientEventID`, `entityIDsPayloadJSON`, `metadataPayloadJSON` non modificati.
- `SyncEventOutboxDrainService.swift`
  - outcome esteso con `recoveredCount`, `exhaustedCount`, `skippedFreshSendingCount`;
  - recovery chiamata dopo lock owner e prima di `fetchRetryable`;
  - save recovery dedicato (`sending_stale_recovery`); su save failure il drain si ferma e non chiama recorder/fetch retryable.
- Test estesi:
  - `SyncEventOutboxStateTests`
  - `SyncEventOutboxLocalStoreTests`
  - `SyncEventOutboxDrainServiceTests`
- Tracking:
  - creato questo file TASK-064;
  - `docs/MASTER-PLAN.md` aggiornato a TASK-064 ACTIVE / REVIEW.

#### Check eseguiti

| Check | Stato | Esito |
|------|-------|-------|
| Build Debug iPhone 16e | ✅ ESEGUITO | `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' build` -> **BUILD SUCCEEDED**. Warning AppIntents metadata già noto/preesistente. |
| Test mirati TASK-064 | ✅ ESEGUITO | `SyncEventOutboxStateTests`, `SyncEventOutboxLocalStoreTests`, `SyncEventOutboxDrainServiceTests` -> **TEST SUCCEEDED**. |
| Test regressione outbox/enqueue/recorder | ✅ ESEGUITO | `SyncEventOutboxEnqueueServiceTests`, `SyncEventRecordingTests`, `SyncEventLiveRecorderTests` -> **TEST SUCCEEDED**. |
| Regressione TASK-061 DEBUG ViewModel | ✅ ESEGUITO | `SyncEventOutboxDrainDebugViewModelTests` -> **TEST SUCCEEDED**. |
| Nessun warning nuovo introdotto | ✅ ESEGUITO | Build Debug mostra solo warning AppIntents metadata già noto/preesistente; nessun warning Swift nuovo attribuibile a TASK-064. |
| `git diff --check` | ✅ ESEGUITO | PASS, nessun output; anche whitespace no-index sul nuovo file TASK-064 PASS. |
| Grep anti-scope produzione | ✅ ESEGUITO | Su `SyncEventOutboxState.swift`, `SyncEventOutboxEntry.swift`, `SyncEventOutboxDrainService.swift`: nessun `BGTask`, `Timer`, `Realtime`, `.channel`, `.subscribe`, `record_sync_event`, `SupabaseClient`, `.rpc`, `.from`, `.upsert`, `deleteAll`, `truncate`, `resetOutbox`, `cleanup`. |
| Grep anti-scope diff file | ✅ ESEGUITO | Nessun file Android/Kotlin, SQL/migration/Supabase, `OptionsView`, `Localizable`, `ContentView` o app wiring modificato. |
| Modifiche coerenti con planning | ✅ ESEGUITO | Verificato contro D63-05 e criteri T64-01…T64-12. |
| Criteri di accettazione | ✅ ESEGUITO | T64-01…T64-12 coperti da test/static/grep come sopra. |
| Test Simulator/manual UI | ⚠️ NON ESEGUIBILE | Non applicabile al perimetro: TASK-064 non introduce UI o comportamento visibile nuovo. |

#### Rischi rimasti

- Recovery preserva `attemptCount` quando una entry `sending` stale torna `failedRetryable`: scelta intenzionale per rispettare il contratto "sotto max attempts -> retryable" e non consumare un tentativo solo per crash/interruzione. Un futuro task può decidere policy diversa se emergono crash-loop reali.
- Nessuna validazione live Supabase eseguita: coerente con il divieto TASK-064.
- `TASK-063` resta file untracked nel workspace già presente prima di TASK-064; non è stato riaperto o modificato da questa execution.

#### Anti-scope confermati

Confermati: nessuna UI Release, nessuna modifica DEBUG card, nessun coordinator, nessuna sync automatica, nessun timer/BGTask/Realtime/worker, nessuna chiamata Supabase live, nessun SQL/migration/RPC/RLS, nessun cleanup/delete/truncate/reset outbox, nessun Product/ProductPrice full sync, nessun Android, nessun TASK-065.

## Handoff post-execution

- **Stato finale:** TASK-064 **ACTIVE / REVIEW**.
- **Responsabile attuale:** **Claude / Reviewer**.
- **Esito:** recovery `sending` stale implementata e testata.
- **File modificati:** `SyncEventOutboxState.swift`, `SyncEventOutboxEntry.swift`, `SyncEventOutboxDrainService.swift`, `SyncEventOutboxStateTests.swift`, `SyncEventOutboxLocalStoreTests.swift`, `SyncEventOutboxDrainServiceTests.swift`, `docs/MASTER-PLAN.md`, questo file task.
- **Prossimo passo consigliato:** review tecnica TASK-064.
- **Non dichiarare DONE:** completamento finale solo dopo review e conferma utente.

## Fix (Codex)

### 2026-05-07 20:23 -04 — Review tecnica severa / APPROVED_FIXED_DIRECTLY

**Verdetto review:** **APPROVED_FIXED_DIRECTLY**.

**Override esplicito utente:** la richiesta di review autorizza la chiusura in **DONE / Chiusura** se la review termina senza problemi grandi. La review ha trovato solo problemi piccoli e mirati, corretti direttamente senza allargare il perimetro outbox locale.

**Problemi trovati:**
- L'outcome del drain poteva risultare troppo ottimistico quando il recovery trasformava una entry `sending` stale exhausted in `dead` e contemporaneamente altre entry venivano inviate con successo: i conteggi erano presenti, ma `status` poteva restare `drained`.
- Il drain non controllava esplicitamente la cancellazione prima di recovery/fetch/loop; il path con recorder cancellato era coperto, ma mancava una guardia cooperativa prima del lavoro locale.
- I test coprivano lo scan limit base, ma non fissavano ancora hard cap del recovery e preservazione esplicita di `clientEventID` / `sourceDeviceID`.

**Fix applicati dentro scope TASK-064:**
- `SyncEventOutboxDrainService` ora esegue `Task.checkCancellation()` prima del recovery, dopo eventuale save recovery, dopo il fetch e prima di mutare/processare ogni candidato.
- L'outcome considera `exhaustedCount` come non-success: exhausted-only torna `networkFailed`; exhausted + invii riusciti torna `partiallyDrained`, evitando success falso.
- Test aggiunti/aggiornati:
  - recovery exhausted non processata -> `networkFailed`;
  - recovery exhausted + altra entry sent -> `partiallyDrained`;
  - cancellazione prima del drain non chiama recovery/fetch/recorder/save;
  - hard cap recovery nello store e nel service;
  - payload test esteso a `clientEventID` e `sourceDeviceID` invariati.

**Perché sono dentro scope:** tutti i fix restano su state/store/drain/test locali outbox `sync_events`; non introducono UI, coordinator, automazione, network, SQL, cleanup o task nuovi.

**Test/check rieseguiti in review/fix:**
- ✅ `SyncEventOutboxStateTests`, `SyncEventOutboxLocalStoreTests`, `SyncEventOutboxDrainServiceTests` -> **TEST SUCCEEDED** dopo i fix.
- ✅ Regressioni `SyncEventOutboxEnqueueServiceTests`, `SyncEventRecordingTests`, `SyncEventLiveRecorderTests`, `SyncEventOutboxDrainDebugViewModelTests` -> **TEST SUCCEEDED**.
- ✅ Build Debug iPhone 16e -> **BUILD SUCCEEDED**.
- ✅ `git diff --check` e whitespace no-index del nuovo TASK-064 -> PASS.
- ✅ Grep anti-scope produzione/diff e verifica `TASK-065*` assente -> PASS.

## Chiusura

TASK-064 **DONE / Chiusura**.

- **Esito finale:** **APPROVED_FIXED_DIRECTLY**.
- **Build/test/check:** PASS in chiusura.
- **Anti-scope confermati:** no UI Release, no coordinator, no sync automatica, no Timer/BGTask/Realtime/worker, no Supabase live diretto, no SQL/migration/RPC/RLS, no cleanup/delete/truncate/reset outbox, no Product/ProductPrice full sync, no Android.
- **Rischi residui:** nessun blocco noto. La policy `attemptCount` invariato nel recovery sotto max attempts resta intenzionale e documentata; eventuale tuning soglia/limit va trattato in task futuro.
- **TASK-065:** non creato. Prossimo passo consigliato nel Master Plan: **TASK-065 coordinator dry-run/mock**, solo come task futuro consigliato.
- **Stato workspace:** IDLE; nessun task attivo.
