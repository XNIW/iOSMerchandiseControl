# TASK-060 — Supabase `sync_events` outbox drain iOS — G2 manual controlled drain

> **USER OVERRIDE — EXECUTION APPROVED (2026-05-07):** l’utente ha autorizzato l’avvio di una EXECUTION controllata per la Slice **G2 minima**. Impatto workflow: il file era nato **planning-only**; Codex ha eseguito modifiche Swift piccole e verificabili solo per drain manuale/controllato via **`SyncEventRecording`**, senza UI, timer/background, Supabase live diretto, nuovo schema SwiftData o **TASK-061**. Stato storico dopo execution: **ACTIVE / REVIEW**; stato finale dopo review+fix: **DONE / Chiusura**.
> **USER OVERRIDE — REVIEW+FIX APPROVED / DONE (2026-05-07):** l’utente ha richiesto review tecnica completa post-execution con fix diretti se piccoli/medi e chiusura DONE se approvata. Review completata con esito **APPROVED_FIXED_DIRECTLY / DONE**; TASK-060 chiuso solo per **G2 manual controlled drain**, senza UI/worker/auto-drain/Supabase diretto/nuovo schema SwiftData/TASK-061.

## Informazioni generali

| Campo | Valore |
|-------|--------|
| **Task ID** | TASK-060 |
| **Titolo** | Supabase `sync_events` outbox drain iOS — G2 manual controlled drain |
| **File task** | `docs/TASKS/TASK-060-supabase-sync-events-outbox-drain-g2-ios.md` |
| **Stato** | DONE |
| **Fase attuale** | Chiusura |
| **Responsabile attuale** | — |
| **Data creazione** | 2026-05-07 |
| **Ultimo aggiornamento** | 2026-05-07 *(REVIEW+FIX G2 minima APPROVED_FIXED_DIRECTLY / DONE; build/test/check verdi; master plan IDLE, TASK-060 ultimo completato.)* |
| **Ultimo agente** | Codex / Reviewer+Fixer |

## Dipendenze

- **Dipende da**
  - **TASK-055** (DONE) — `SyncEventOutboxEntry` / state machine / `SyncEventOutboxLocalStore`
  - **TASK-056** (DONE) — `SyncEventRecording`, validator, error taxonomy, dry-run recorder
  - **TASK-057** (DONE) — `SyncEventOutboxEnqueueService` enqueue locale da outcome push manuali
  - **TASK-058** (DONE) — `SupabaseSyncEventLiveRecorder` + `SyncEventRPCTransport` + `SyncEventRPCRequestMapper` *(boundary RPC confinato al transport concreto)*
  - **TASK-059** (DONE) — Slice G1 **payload fidelity**: `entityIDsPayloadJSON` / `metadataPayloadJSON`, `SyncEventOutboxPayloadCodec.makeRecordRequestForReplay`, replay fail-closed su legacy/corrupt
- **Sblocca** *(solo candidati, non obbligatori in questo file)* — orchestrazione UI opzionale, recovery `sending` stale, eventuali slice successive **solo dopo** EXECUTION reviewata di G2

## Scopo

Progettare la **Slice G2**: un servizio di **drain manuale** (invocazione esplicita, nessun timer/background) che selezioni entry outbox **retryable**, ricostituisca `SyncEventRecordRequest` tramite **replay fedele** (TASK-059), invochi **`SyncEventRecording.record(_:)`** (produzione: live recorder TASK-058; test: fake/dry-run), aggiorni lo stato outbox via **state machine esistente** (`SyncEventOutboxStateMachine` + `ModelContext` save policy da definire in execution), rispetti **batch bounded** e pattern **head-of-line safe** allineato all’intento Android TASK-070, **senza** fallback count-only o perdita silenziosa di payload.

## Non incluso / anti-scope rigido (questo task = solo markdown)

- **Nessuna** modifica Swift, **`project.pbxproj`**, build, XCTest, esecuzione di test
- **Nessuna** chiamata **Supabase live**, **nessun** RPC live `record_sync_event`, **nessun** “drain reale” o smoke remoto
- **Nessun** timer, `BGTask`, Realtime subscription, worker automatico, drain all’avvio app
- **Nessuna** UI obbligatoria, **nessun** `Localizable`, **nessun** obbligo di modificare `OptionsView`
- **Nessuna** modifica SQL/migration/RLS/RPC/Supabase locale o remota
- **Nessuna** modifica Android / Kotlin / Room
- **Nessun** cleanup automatico outbox (delete/truncate/TTL), **nessuna** delete massiva su `sync_events` remoto
- **Non creare TASK-061**

---

## 1. Stato attuale iOS

### 1.1 Cosa esiste dopo TASK-055 … TASK-059

| Slice | Contenuto rilevante per G2 |
|-------|--------------------------------|
| **TASK-055** | Modello SwiftData `SyncEventOutboxEntry`, stati (`SyncEventOutboxStatus`), `SyncEventOutboxStateMachine`, factory, `SyncEventOutboxLocalStore.fetchRetryable` / `fetchCounts` |
| **TASK-056** | `SyncEventRecording`, `SyncEventRecordRequest`/`Result`/`Error`, `SyncEventRecordValidator`, budget/metadata/entity_ids allineabili a RPC locale |
| **TASK-057** | `SyncEventOutboxEnqueueService` — enqueue solo da outcome **terminali** push manuali catalog/ProductPrice; dedupe `ownerUserID + clientEventID`; **nessuna rete** |
| **TASK-058** | `SupabaseSyncEventLiveRecorder` chiama solo tramite `SyncEventRPCTransport`; validazione pre-RPC; mapping errori; **`SupabaseClient`/`.rpc` solo nel transport concreto** (vincolo da preservare in G2) |
| **TASK-059 G1** | Persistenza **`entityIDsPayloadJSON` / `metadataPayloadJSON`** opzionali; **`makeRecordRequestForReplay`** — fail esplicito se payload assente (legacy), JSON corrotto, o validazione replay fallita; **nessun drain** |

### 1.2 Cosa manca per un drain reale

1. **Orchestratore drain** che: selezioni batch di entry; per ciascuna transizioni **`pending`/`failedRetryable` → `sending`** (`toSending`); chiami **`record`**; mappi successo/idempotenza (`recorded` / `noOp`) → **`sent`**; mappi errori tramite taxonomia esistente → retry / blocked / dead; **`save()`** con policy atomica per-entry (vedi decisioni).
2. **Contratto risultato tipizzato** lato app per una singola chiamata manuale `drainOnce(limit:)` (vedi §5) — UX/debug futuri, **non** obbligatorio in questa fase planning nel codice.
3. **Test XCTest** dedicati al drain *(pianificati in §6; vietati in questo task markdown)*.
4. **Guard di reentrancy** per owner (due tap / due Task concorrenti) — da execution, pattern già anticipato in TASK-059 **D59-11**.
5. **Recovery `sending` stale** dopo crash — **fuori scope G2 minimale** (follow-up candidato; non blocca planning G2).

### 1.3 Perché TASK-059 da solo non basta

TASK-059 ha chiuso **solo G1 — payload fidelity**: senza JSON persistito non si poteva ricostruire una `SyncEventRecordRequest` fedele; ora sì. **Non** introduce però:

- iterazione sullo store;
- transizione `sending` / RPC;
- gestione errori di rete / schema / auth sul percorso drain;
- policy save post-successo remoto (**D59-17** idempotenza se save locale fallisce dopo RPC OK — resta vincolo per l’execution G2).

---

## 2. Riferimento Android (funzionale, non port 1:1)

### 2.1 TASK-070 — head-of-line retry

- **Problema**: retry che legeva un **prefisso FIFO fisso** di righe *pending* senza filtrare `attemptCount`; le prime N righe a max attempts **bloccavano** le successive ancora ritentabili.
- **Soluzione documentata**: nuova query **`listPendingRetryable(owner, maxAttempts, limit)`** — solo righe con `attemptCount < maxAttempts`, stesso ordinamento FIFO tra le ritentabili.
- **Utilità per iOS**: l’intent è **non restare bloccati dietro righe “esauste” o non eleggibili**. Su iOS `fetchRetryable` già filtra `attemptCount < maxAttempts` e `nextRetryAt <= now`; resta da definire in execution **`fetchScanLimit` ≥ tentativi effettivi** e iterazione che **salti** entry non processabili in-process (guard **D59-07**) senza abortire l’intera run dopo un fallimento **retryable** su una entry (allineamento **D59-03**).

### 2.2 Outcome / logging utili

Da TASK-070 / repository Android (concetti, non nomi Swift):

- Outcome espliciti tipo **`NoOp` / `Recorded` / `Enqueued` / `PartiallyRecordedAndEnqueued`** per evitare flag booleani ambigui.
- Metriche **privacy-safe**: `pendingBefore/After`, conteggi retry, skip per max attempts, **mai** payload pieno, barcode, JWT, URL con query.

**Adattamento iOS G2:**

- Il drain G2 non fa **enqueue** post-RPC nello stesso senso Android; l’analogo utile è **`SyncEventOutboxDrainResult`** (o enum §5) con **`noWork` / `partiallyDrained` / …** e conteggi **solo** shape/kind/code — coerente con `SyncEventOutboxPrivacySanitizer` / messaggi sanificati già usati in outbox e recorder.

### 2.3 Perché non copiare Kotlin / Room / WorkManager 1:1

- **Persistenza**: SwiftData + `ModelContext` ≠ Room DAO; le transazioni e il fetch predicate sono diversi.
- **Concurrency**: pattern `WorkManager` / retry periodico **non** richiesti; G2 resta **manuale**.
- **Query**: Android ha aggiunto una **seconda** query; iOS potrebbe riusare `fetchRetryable` con limiti e guard interne invece di duplicare, salvo gap dimostrato in execution (**minimo cambiamento**).

---

## 3. Riferimento Supabase (locale — non assumere live remoto)

**Fonte:** `MerchandiseControlSupabase/supabase/migrations/20260424021936_task045_sync_events.sql` *(clone locale; **non** prova stato progetto remoto)*.

### 3.1 RPC `record_sync_event`

- **Firma**: `public.record_sync_event(..., p_metadata jsonb default '{}')` **returns `public.sync_events`** — **singola riga** (tipo composite row Postgres / oggetto decodificabile come riga DTO iOS).
- **`changed_count`**: rifiuto esplicito se `< 0` o `> 1000` (`errcode '22023'`) — **allineato** al validator iOS `0...1000` e a `SyncEventOutboxFactory.changedCountContractLimit`.
- **`entity_ids`**: nullable; se presente deve essere **oggetto JSON** con sole chiavi `supplier_ids`, `category_ids`, `product_ids`, `price_ids`; array di stringhe UUID; max **250** elementi per chiave; `pg_column_size` ≤ **16384**.
- **`metadata`**: sempre oggetto; `pg_column_size` ≤ **4096**; denylist chiavi (`barcode`, `email`, …) come già validato lato client in TASK-056/059.
- **Idempotenza**: se `p_client_event_id` non nullo, lookup per `(owner, client_event_id)`; insert; su duplicato **ritorna riga esistente** — supporta **D59-17** (secondo tentativo marca `sent` locale se RPC risponde idempotentemente).

### 3.2 Risposta HTTP / shape decoding (lato app TASK-058)

- Il client decodifica tramite **`SyncEventRowsResponse`** / prima riga — gestione **array vs object** già nel perimetro recorder; risposta **vuota** o mismatch `client_event_id` → errore **schema** mappato come oggi.

### 3.3 RLS / grants

- Tabella `sync_events`: **RLS** con policy **select** per `authenticated` dove `owner_user_id = auth.uid()`; **`revoke all`** poi **`grant select`** a `authenticated`.
- Funzione RPC: **`grant execute`** a `authenticated`**; implementazione **`security definer`** con `auth.uid()` come owner — coerente con sessione Supabase richiesta dal live recorder.

### 3.4 Nota TASK-071 (Android) e decisione iOS prudente

- TASK-071 documenta mismatch storici tra **delta reali** (es. push di volumi elevati) e **`changed_count` ammesso (0…1000)** lato SQL.
- **Decisione G2 (planning)**: il drain iOS **non** deve “syntheticizzare” eventi con `changedCount > 1000`; **bloccare prima della RPC** (stato **blockedContract** / risultato **`blockedContract`**) in linea con factory/validator già presenti. **Nessun** downgrade silenzioso a count-only senza payload.

---

## 4. Decisioni tecniche pianificate (D60-xx)

| ID | Decisione | Note |
|----|-----------|------|
| **D60-01** | Drain **solo manuale** (`drainOnce` esplicito); **nessun** timer/BG/Realtime/worker | Obbligo utente |
| **D60-02** | **Batch bounded**: parametro `limit` (nome esecuzione `drainOnce(limit:)`); default conservativo da fissare in execution (es. 5–10) con **hard cap** documentato |
| **D60-03** | **Head-of-line**: riusare `fetchRetryable` + `fetchScanLimit` ampio; dopo errore **retryable** su entry A, **continuare** B se batch non esaurito; **non** fermare tutta la run salvo `CancellationError` |
| **D60-04** | **Replay**: solo `makeRecordRequestForReplay` — se fallisce → **`blockedPayloadReplay`** (o transizione blocked coerente), **zero** chiamata `record` |
| **D60-05** | **Nessun** fallback count-only / shape-only; **nessun** “best effort” che **omette** `entity_ids`/`metadata` persistiti |
| **D60-06** | **Boundary RPC**: tutta la rete solo via **`SyncEventRecording`**; **nessun** `SupabaseClient` nuovo fuori dal transport già ammesso (vincolo TASK-058) |
| **D60-07** | **Cancellation**: `CancellationError` / `URLError.cancelled` — **ripristino snapshot pre-`sending`**, save, **rethrow**; **non** marcare `failedRetryable` “finto” per cancel |
| **D60-08** | **Privacy**: log/last error solo **sanificati**; **mai** barcode, UUID grezzi lunghi, nomi prodotto, token, URL in chiaro |
| **D60-09** | **Retry conservativo**: riusare `transitionAfterFailure` + `retryDelay` allineato a state machine (es. 60s) per **network/unknown**; **auth/schema/contract** → terminali blocked come oggi |
| **D60-10** | **Owner scope**: `ownerUserID` obbligatorio; mismatch → **auth/blocked** locale senza rete |
| **D60-11** | **Reentrancy**: un drain per owner alla volta (actor/lock); seconda chiamata **no-op** o attesa — da dettagliare in execution (**D59-11**) |
| **D60-12** | **Save atomico per entry**: dopo ogni esito definito per quella entry, **`context.save()`** (o policy micro-batch documentata); su **save failure** dopo RPC OK seguire **D59-17** (non dichiarare successo completo; retry idempotente) |

---

## 5. Design futuro suggerito *(non implementato in TASK-060)*

### 5.1 Tipo / servizio

- **`SyncEventOutboxDrainService`** (nome indicativo), `@MainActor` se usa `ModelContext` come enqueue service.
- Dipendenze iniettate:
  - `ModelContext` + `SyncEventOutboxLocalStore`
  - `any SyncEventRecording` *(produzione: `SupabaseSyncEventLiveRecorder`; test: `SyncEventRecordDryRunRecorder` o mock)*
  - `clock`, `retryDelay`, validator opzionale override per test

### 5.2 API

```text
func drainOnce(ownerUserID: String, limit: Int, fetchScanLimit: Int?) async throws -> SyncEventOutboxDrainOutcome
```

- **`fetchScanLimit`**: default **`max(limit * 4, 32)`** (come **D59-04** in TASK-059).

### 5.3 Risultato tipizzato (proposta)

Enum / struct somma (nomi esatti in execution):

| Caso | Significato pianificato |
|------|-------------------------|
| **noWork** | Nessuna entry retryable al `now` corrente (o owner invalid → fail-fast locale senza RPC) |
| **drained** | Almeno una entry portata a **`sent`** con successo |
| **partiallyDrained** | Mix: almeno un **`sent`** e almeno un fallimento retryable / skip nella stessa run |
| **blockedContract** | Precondizione contrattuale (es. `changed_count` / validator) → blocked senza RPC |
| **blockedPayloadReplay** | `makeRecordRequestForReplay` fallito |
| **networkFailed** | Fallimento dominato da errori **network** (anche se altre entry erano ok — definire se aggregate o ultimo errore; execution deve chiarire) |
| **cancelled** | **Solo** se si sceglie di **non** usare `throws CancellationError` esclusivamente — *preferenza planning*: **throws** `CancellationError` e **non** restituire outcome “parziale”; se si usa enum, documentare che `cancelled` è mutuamente esclusivo con conteggi definitivi |

**Nota:** allineamento con **D59-10** (conteggi `attempted`, `sent`, …): o il nuovo enum **include** conteggi **oppure** coesiste con `SyncEventOutboxDrainResult` — decisione riservata all’execution per evitare duplicazione.

---

## 6. Test futuri da pianificare *(non eseguiti in TASK-060)*

Matrice sintetica (prefisso **T60-**):

| ID | Scenario |
|----|----------|
| **T60-01** | Nessun pending retryable → **`noWork`** / nessuna chiamata a `record` |
| **T60-02** | FIFO: prime entry a `maxAttempts` **non** in `fetchRetryable`; entry successiva ancora retryable viene **raggiunta** |
| **T60-03** | Payload legacy (`entityIDsPayloadJSON` nil) → **blockedPayloadReplay**, **nessuna** RPC |
| **T60-04** | JSON corrotto → idem |
| **T60-05** | `changedCount == 1000` + replay valido → recorder fake **success** |
| **T60-06** | `changedCount == 1001` → **blocked** prima di `record` |
| **T60-07** | `CancellationError` durante `record` → stato **non** `dead` spurio; snapshot ripristinato |
| **T60-08** | Errore **network** → `failedRetryable`, `attemptCount` incrementato, `nextRetryAt` spostato |
| **T60-09** | **auth** / **schema** / **contract** → blocked terminali corretti |
| **T60-10** | **`limit`** rispettato (max N tentativi `record`) |
| **T60-11** | Ultimo errore / log: assertion su assenza barcode/UUID/raw id nelle stringhe persistite |
| **T60-12** | Grep/architettura: **nessun** `SupabaseClient` / `.rpc(` nel drain service — solo `SyncEventRecording` |
| **T60-13** | **Nessun** accoppiamento a timer/BGTask/Realtime; test puri XCTest |

**D59-17** — RPC ok + save locale fallito: casistica **obbligatoria** in execution (già richiesta in TASK-059).

---

## 7. Criteri di accettazione (contratto TASK-060 — solo markdown)

- [ ] File **`docs/TASKS/TASK-060-supabase-sync-events-outbox-drain-g2-ios.md`** creato con sezioni **1–6** complete e **anti-scope** esplicito
- [ ] **`docs/MASTER-PLAN.md`** aggiornato: progetto **ACTIVE**, **TASK-060** **ACTIVE / PLANNING**, **TASK-059** come **ultimo completato DONE**, **TASK-052** **BLOCKED / superseded**
- [ ] Planning **execution-ready** (decisioni D60, design API, mapping errori, test elencati) ma **NESSUNA** execution Swift in questo task
- [ ] Handoff finale: **READY FOR PLANNING REVIEW** — **non** **READY FOR EXECUTION**
- [ ] **Non** creato **TASK-061**

---

## Decisioni (tabella estesa)

Le decisioni **D60-01 … D60-12** sono il contratto di planning; revisione solo via nuovo task o amend esplicito utente.

---

## Planning (Claude)

### Analisi

Dopo **TASK-059 G1** l’outbox può ricostruire richieste **fedeli** per `record_sync_event`. Manca il **collante operativo**: selezione batch, transizioni `sending`/`sent`/retry/blocked, invocazione **`SyncEventRecording`**, e politiche **save** / **cancel** / **idempotenza** già anticipate in **TASK-059** (D59-03, D59-05, D59-10, D59-11, D59-16, D59-17). Il contratto SQL locale (**1000**, budgets, idempotenza su `client_event_id`) è la **stessa stella polare** del validator iOS — il drain non deve aggirarla.

### Approccio proposto

1. Formalizzare **D60-xx** e risultato tipizzato §5.
2. In una futura EXECUTION: implementare **`SyncEventOutboxDrainService`** minimo + XCTest con **recorder fake**; **nessuna** UI obbligatoria.
3. Riusare **state machine** esistente; estendere store solo se gate D59-19 lo richiede con **helper minimi**.
4. Mantenere **confine TASK-058** sul **`SupabaseClient`**.

### File da modificare *(in futura EXECUTION, elenco indicativo)*

- Nuovo: `SyncEventOutboxDrainService.swift` *(o nome approvato in review)*
- Touch: `SyncEventOutboxEntry.swift` / store **solo se** necessario per atomicità *(preferenza: no schema change)*
- Test: `SyncEventOutboxDrainServiceTests.swift` *(nome indicativo)*

### Rischi identificati

| Rischio | Mitigazione pianificata |
|---------|-------------------------|
| Doppio invio RPC (reentrancy) | D60-11 + lock per owner |
| Stato `sending` dopo crash | Follow-up fuori G2 minimo |
| Save locale fallito dopo RPC OK | D59-17 + test |
| Drift RPC locale vs remoto | Documentare **schema_drift_da_chiarire**; non mascherare con silent fallback |

### Handoff post-planning

- **Prossima fase**: **PLANNING REVIEW** (documentale)
- **Prossimo agente**: **Claude / Reviewer** o **utente**
- **Azione consigliata**: leggere decisioni **D60**, allineamento con **D59-xx** ancora attive, confine **SupabaseClient**; **solo dopo** conferma esplicita utente → **EXECUTION** (Codex)

**Stato handoff:** **READY FOR PLANNING REVIEW** — **non** **READY FOR EXECUTION**

---

## Execution (Codex)

### USER OVERRIDE — EXECUTION controllata G2 minima — 2026-05-07

Il task era nato come **planning-only**; l'utente ha autorizzato esplicitamente una **EXECUTION controllata, piccola e verificabile** della Slice **G2 minima**. Impatto workflow: le parti planning-only sopra restano storico/contratto originale, ma questa sezione registra l'esecuzione approvata dall'utente. Non sono stati creati **TASK-061** o task paralleli.

### Obiettivo compreso

Implementare un servizio minimo di drain manuale/controllato per l'outbox locale `sync_events` iOS:
- usa `ModelContext` / `SyncEventOutboxLocalStore` esistenti;
- invia solo tramite `any SyncEventRecording`;
- ricostruisce la request con replay fedele TASK-059;
- aggiorna gli stati tramite `SyncEventOutboxStateMachine`;
- resta bounded, owner-scoped e head-of-line safe;
- non introduce UI, timer/background, Realtime, worker automatici, Supabase live diretto, schema SwiftData nuovo o fallback count-only.

### File controllati

- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-060-supabase-sync-events-outbox-drain-g2-ios.md`
- `docs/TASKS/TASK-055-supabase-sync-events-outbox-foundation-ios.md`
- `docs/TASKS/TASK-056-supabase-record-sync-event-contract-dry-run-ios.md`
- `docs/TASKS/TASK-057-supabase-sync-events-slice-e-local-enqueue-ios.md`
- `docs/TASKS/TASK-058-supabase-record-sync-event-live-recorder-planning-ios.md`
- `docs/TASKS/TASK-059-supabase-sync-events-outbox-drain-ios.md`
- `iOSMerchandiseControl/SyncEventOutboxEntry.swift`
- `iOSMerchandiseControl/SyncEventOutboxState.swift`
- `iOSMerchandiseControl/SyncEventOutboxEnqueueService.swift`
- `iOSMerchandiseControl/SyncEventRecording.swift`
- `iOSMerchandiseControl/SupabaseSyncEventLiveRecorder.swift`
- `iOSMerchandiseControlTests/SyncEventOutboxStateTests.swift`
- `iOSMerchandiseControlTests/SyncEventOutboxLocalStoreTests.swift`
- `iOSMerchandiseControlTests/SyncEventOutboxEnqueueServiceTests.swift`
- `iOSMerchandiseControlTests/SyncEventRecordingTests.swift`
- `iOSMerchandiseControlTests/SyncEventLiveRecorderTests.swift`

### Piano minimo

1. Aggiornare tracking TASK-060 da PLANNING a EXECUTION su user override.
2. Aggiungere un solo servizio `SyncEventOutboxDrainService`.
3. Usare store/outbox/state machine/validator/recorder già esistenti.
4. Coprire i casi G2 minimi con XCTest fake/in-memory.
5. Verificare build, regressioni e anti-scope.
6. Aggiornare handoff a **REVIEW** senza segnare DONE.

### Modifiche fatte

- Aggiunto `iOSMerchandiseControl/SyncEventOutboxDrainService.swift`
  - `@MainActor struct SyncEventOutboxDrainService`;
  - API `drainOnce(ownerUserID:limit:fetchScanLimit:) async throws -> SyncEventOutboxDrainOutcome`;
  - batch limit bounded con hard cap 50 e `fetchScanLimit` default `max(limit * 4, 32)`;
  - lock reentrancy per owner con seconda chiamata `alreadyRunning`;
  - replay via `makeRecordRequestForReplay(validator:)`;
  - success/idempotenza del recorder mappati a `sent`;
  - errori recorder mappati via `transitionAfterFailure`;
  - payload legacy/corrotto bloccato senza chiamare recorder;
  - cancellation e `URLError.cancelled` ripristinano snapshot pre-`sending` e rilanciano `CancellationError`;
  - save failure dopo RPC OK non dichiara successo completo e consente retry idempotente.
- Aggiunto `iOSMerchandiseControlTests/SyncEventOutboxDrainServiceTests.swift`
  - no work / zero recorder calls;
  - success -> `sent`;
  - legacy payload -> blocked senza recorder;
  - errore retryable continua alla entry successiva;
  - limit rispettato;
  - cancellation e `URLError.cancelled` ripristinano snapshot;
  - reentrancy per owner;
  - save failure post-success remoto + retry idempotente;
  - guard architetturale anti-scope su produzione.
- Aggiornato tracking in `docs/MASTER-PLAN.md` e in questo file task.

### Check eseguiti

- ✅ ESEGUITO — Build compila: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' build` → **BUILD SUCCEEDED**.
- ✅ ESEGUITO — Nessun warning nuovo introdotto: unico warning osservato `Metadata extraction skipped. No AppIntents.framework dependency found`, già documentato/preesistente in TASK-059 e non legato a G2.
- ✅ ESEGUITO — Test nuovi drain: `SyncEventOutboxDrainServiceTests` → **TEST SUCCEEDED** (10 test).
- ✅ ESEGUITO — Regressioni outbox/recorder/payload replay: `SyncEventOutboxStateTests`, `SyncEventOutboxLocalStoreTests`, `SyncEventOutboxEnqueueServiceTests`, `SyncEventRecordingTests`, `SyncEventLiveRecorderTests`, `SyncEventOutboxDrainServiceTests` → **TEST SUCCEEDED**.
- ✅ ESEGUITO — Modifiche coerenti con il planning + user override: servizio manuale, bounded, via `SyncEventRecording`; nessuna UI/timer/BG/Realtime/worker; nessun Supabase diretto; nessun nuovo schema SwiftData.
- ✅ ESEGUITO — Criteri execution G2 verificati: replay fedele, no fallback legacy/count-only, error mapping state machine, cancellation restore, save failure post-RPC gestito come non completo, reentrancy owner-scoped.
- ✅ ESEGUITO — `git diff --check` → nessun output/errore.
- ✅ ESEGUITO — Whitespace nuovi Swift: `git diff --no-index --check /dev/null iOSMerchandiseControl/SyncEventOutboxDrainService.swift` e `git diff --no-index --check /dev/null iOSMerchandiseControlTests/SyncEventOutboxDrainServiceTests.swift` → nessun output whitespace; exit 1 atteso per confronto con `/dev/null`.
- ✅ ESEGUITO — Anti-scope produzione: grep su `iOSMerchandiseControl/SyncEventOutboxDrainService.swift` per `SupabaseClient`, `.rpc(`, `.from(`, `.upsert(`, `.channel(`, `.subscribe(`, `BGTask`, `Realtime`, `service_role`, `URLSession`, `record_sync_event`, `OptionsView`, `Localizable`, `context.insert`, `TASK-061` → nessun match.
- ⚠️ NON ESEGUIBILE — Test Simulator/manuali UI: non applicabili al perimetro; il task non introduce UI o comportamento visibile richiesto in Simulator.

### Rischi rimasti

- Recovery di entry rimaste `sending` dopo crash resta fuori scope G2 minima; follow-up candidate, non implementato.
- Nessuna validazione live Supabase remota eseguita: il servizio usa il recorder astratto e i test usano fake; coerente col divieto di Supabase live diretto.
- Il task conserva sezioni planning-only storiche in alto; l'execution è registrata come user override esplicito e va reviewata da Claude per coerenza di processo.

### Handoff post-execution — G2 minima → Claude / Reviewer

- **Stato task**: **ACTIVE / REVIEW**
- **Responsabile attuale**: **Claude / Reviewer**
- **Esito execution**: **Slice G2 minima implementata**
- **Swift/progetto**: aggiunti due file Swift; nessuna modifica `project.pbxproj` richiesta dal project structure attuale.
- **Richiesta review**:
  - verificare che il drain resti confinato a `SyncEventRecording` e non attraversi direttamente Supabase/RPC;
  - verificare mapping stati/errori/cancellation/save failure rispetto a D60 e D59-17;
  - verificare che il risultato tipizzato sia sufficiente per futura UX manuale senza introdurre UI ora;
  - confermare che recovery `sending` stale e UI restino follow-up separati.
- **Non dichiarare DONE**: TASK-060 resta **ACTIVE / REVIEW**; **TASK-059** resta ultimo completato **DONE / Chiusura**.

## Review (Claude)

### 2026-05-07 — APPROVED_FIXED_DIRECTLY / DONE *(user override)*

**Verdetto:** **APPROVED_FIXED_DIRECTLY / DONE**.

Review repo-grounded eseguita su `MASTER-PLAN`, TASK-060, TASK-055…059, diff reale, codice modificato e dipendenze (`SyncEventOutboxEntry`, state machine/store/payload codec, `SyncEventRecording`, validator e recorder live). L’architettura G2 è corretta: il drain resta confinato a **`any SyncEventRecording`**, non importa/usa `SupabaseClient`, non chiama `.rpc`, `.from`, `.upsert`, `.channel`, Realtime o Supabase diretto, e non introduce UI, timer, BGTask, worker, drain automatico, cleanup outbox, nuovo schema SwiftData o TASK-061.

L’implementazione è minimale ed efficiente: fetch batch iniziale owner-scoped, loop in memoria, limite tentativi hard-capped, nessun fetch per-entry e nessun count/breakdown post-entry. Il replay usa solo `makeRecordRequestForReplay`; payload legacy/corrotto e `changedCount > 1000` bloccano prima del recorder. Errori retryable continuano sulle entry successive, entry a max attempts non bloccano la coda, cancellation ripristina snapshot e rilancia, e save failure post-RPC OK resta recuperabile tramite retry idempotente D59-17.

Problemi trovati e corretti direttamente: validazione owner troppo permissiva, `fetchScanLimit` non hard-capped, codici errore recorder potenzialmente raw in persistenza, copertura test incompleta su payload fedele/corrotto/1001/owner invalido/max attempts/scan cap/privacy.

Rischi residui non bloccanti: recovery di entry `sending` stale dopo crash resta follow-up separato; nessuna validazione live Supabase remota eseguita, coerente col perimetro G2; eventuale UI manuale futura dovrà essere task separato.

## Fix (Codex)

### 2026-05-07 — Fix diretti post-review

- `SyncEventOutboxDrainService.swift`
  - `ownerUserID` ora deve essere un UUID valido e viene normalizzato lowercase prima di fetch/lock; owner vuoto/non valido fallisce localmente senza fetch e senza recorder.
  - `fetchScanLimit` ora è bounded: default `max(limit * 4, 32)`, tentativi hard cap 50, scan hard cap 200.
  - I codici errore provenienti dal recorder vengono filtrati/redatti prima della persistenza (`redacted_error_code` se contengono token, URL/query, UUID lunghi, barcode-like o payload sospetto).
- `SyncEventOutboxDrainServiceTests.swift`
  - aggiunti test per replay fedele di `entity_ids`/`metadata`, payload corrotto, `changedCount == 1001` pre-recorder, entry oltre max attempts, cap `fetchScanLimit`, owner invalido senza fetch/recorder e privacy degli errori persistiti.
  - suite drain aggiornata a **17 test**.

## Chiusura

**TASK-060 DONE — Slice G2 manual controlled outbox drain reviewed and closed**

- Stato finale: **DONE / Chiusura**
- Esito review: **APPROVED_FIXED_DIRECTLY**
- Master plan: progetto **IDLE**, nessun task attivo, **TASK-060** ultimo completato, **TASK-059** precedente completato DONE.
- Conferme scope: nessuna UI/`OptionsView`/`Localizable`; nessun timer/BGTask/Realtime/worker/auto-drain; nessun Supabase diretto nel drain; nessun nuovo schema SwiftData; nessun cleanup outbox; nessun SQL/Supabase live/Android; nessun TASK-061.

### Check finali

- ✅ ESEGUITO — Build Debug: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' build` → **BUILD SUCCEEDED**. Warning osservato: `Metadata extraction skipped. No AppIntents.framework dependency found`, già noto/preesistente e non introdotto da TASK-060.
- ✅ ESEGUITO — Test mirati drain post-fix: `SyncEventOutboxDrainServiceTests` → **TEST SUCCEEDED**, 17 test.
- ✅ ESEGUITO — Regressioni richieste: `SyncEventOutboxDrainServiceTests`, `SyncEventOutboxStateTests`, `SyncEventOutboxLocalStoreTests`, `SyncEventOutboxEnqueueServiceTests`, `SyncEventRecordingTests`, `SyncEventLiveRecorderTests` → **TEST SUCCEEDED**.
- ✅ ESEGUITO — `git diff --check` → nessun output/errore.
- ✅ ESEGUITO — Whitespace no-index nuovi Swift: `SyncEventOutboxDrainService.swift`, `SyncEventOutboxDrainServiceTests.swift` → nessun output whitespace.
- ✅ ESEGUITO — Grep anti-scope produzione sul drain: nessun match per `SupabaseClient`, `.rpc(`, `.from(`, `.upsert(`, `.channel(`, `.subscribe(`, `BGTask`, `Realtime`, `service_role`, `URLSession`, `record_sync_event`, `OptionsView`, `Localizable`, `context.insert`, `TASK-061`.
- ✅ ESEGUITO — Nessun call site automatico: nessun uso di `SyncEventOutboxDrainService` / `drainOnce` fuori dal file service.
- ✅ ESEGUITO — Nessun TASK-061 creato.
