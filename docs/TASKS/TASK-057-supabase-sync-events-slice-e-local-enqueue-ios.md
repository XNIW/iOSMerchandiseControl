# TASK-057: Supabase `sync_events` — **Slice E iOS** — **local enqueue** da outcome manual push/apply, **no network**

## Informazioni generali *(metadata tracking)*
- **Task ID**: TASK-057
- **Titolo**: Supabase sync_events Slice E iOS — local enqueue integration from manual push/apply outcomes, no network
- **File task**: `docs/TASKS/TASK-057-supabase-sync-events-slice-e-local-enqueue-ios.md`
- **Stato**: DONE
- **Fase attuale**: Chiusura
- **Responsabile attuale**: Utente / prossimo task da decidere
- **Data creazione**: 2026-05-06
- **Ultimo aggiornamento**: 2026-05-07 *(REVIEW+FIX Slice E completata; TASK-057 chiuso DONE solo per local enqueue. No Supabase live/RPC/drain/UI/SQL/Android; TASK-058 non aperto.)*
- **Ultimo agente che ha operato**: Codex / Reviewer+Fixer

> **USER OVERRIDE — planning / Slice E TASK-057:** aggiornare **solo** markdown (`TASK-057`, `MASTER-PLAN` se necessario). **Vietato:** file Swift, `project.pbxproj`, build, XCTest, Supabase live, SQL/Android, **TASK-058**, execution tecnica.
> **USER OVERRIDE — EXECUTION Slice E only (2026-05-07):** autorizzata execution controllata solo per **local enqueue** da outcome terminali catalog/ProductPrice manual push; restano vietati Supabase live, RPC live `record_sync_event`, `SupabaseClient`, drain/worker/timer/BGTask/Realtime, UI/`OptionsView`, SQL/Supabase/Android, **TASK-058**.

## Dipendenze
- **Dipende da / contesto soddisfatto**:
  - **TASK-053** — **DONE**: read-only `sync_events` (DTO/service).
  - **TASK-054** — **DONE**: UI DEBUG read-only `sync_events`.
  - **TASK-055** — **DONE** (Slice **C**): `SyncEventOutboxEntry`, `SyncEventOutboxState`, `SyncEventOutboxLocalStore`, factory, test — **nessun** producer reale collegato ai flussi push.
  - **TASK-056** — **DONE** (Slice **D**): `SyncEventRecording`, `SyncEventRecordRequest`, **`SyncEventRecordValidator`**, dry-run recorder — **nessun** enqueue outbox da business flow.
- **TASK-052** — **BLOCKED / superseded by TASK-053**; **non DONE**; documento storico — **non** riaprire per execution.
- **Riferimenti esterni (sola lettura documentale — non modificare)**:
  - **Android TASK-070** — **DONE**: retry outbox anti head-of-line.
  - **Android TASK-071** — **DONE**: mismatch `record_sync_event` / `changed_count` vs payload; backend **TASK-072** (o equivalente) **futuro**.
  - **Supabase live** ≠ clone locale — nessuna assunzione di parity senza audit.

## Scopo
Pianificare **Slice E**: introdurre **solo** il **producer locale** che, dopo outcome **gia' confermati** dai flussi manuali esistenti (catalog push, ProductPrice push, ecc.), crea righe **`SyncEventOutboxEntry`** persistenti, con validazione **contract** via **`SyncEventRecordValidator`** (TASK-056), **senza** chiamate di rete, **senza** RPC live, **senza** drain/worker.

---

## 1. Contesto

### Stato iOS
- Esiste **outbox SwiftData** + state machine (**TASK-055**) ma **nessun collegamento** reale dagli esiti di `SupabaseManualPushService`, `SupabaseProductPriceManualPushService`, preflight/baseline ViewModel — i servizi **non** creano ancora entry outbox.
- Esiste **contratto locale** + **validator** + dry-run recorder (**TASK-056**) pensato per allinearsi a `record_sync_event`, ma **Slice E non invoca** il recorder verso rete; l’integrazione pianificata è: **validare** la forma della richiesta/evento **prima** di persistere l’outbox (o marcare stati bloccati).
- **Slice E** = **solo enqueue locale** = chiude il gap «foundation + contract senza producer».

### Cosa Slice E **non** fa (perimetro assoluto)
- **Nessuna** RPC live **`record_sync_event`**, **nessun** `SupabaseClient`, **nessun** `.rpc(` in production Slice E.
- **Nessun** drain outbox, **nessun** worker/timer, **nessun** BGTask, **nessun** Realtime.
- **Nessuna** UI nuova **obbligatoria** (raccomandazione: **zero UI** in Slice E; vedi §8).
- **Nessuna** modifica **Supabase/SQL** o **Android**.
- **Nessun** sync automatico all’avvio o in background.

### Nota — Debug / Release *(Slice E non è «UI DEBUG»)*
- Slice E è **logica locale** del producer outbox / enqueue, **non** una feature di **UI DEBUG** né un overlay di sviluppo obbligatorio.
- In futura **EXECUTION**, il modulo può essere compilato anche in **Release** se serve **coerenza dati** sul percorso enqueue; restano **vietati** in ogni configuration: **UI** nuova obbligatoria, **drain**, **RPC**, **Realtime**, **background sync** / **BGTask** (allineamento **§10**).
- Qualsiasi **controllo visibile**, **CTA**, **conteggi diagnostici in schermata** resta **fuori scope**; se un executor ritenesse indispensabile tale superficie, va trattata come **solo DEBUG** (o strumento separato) e **task separato** — **non** parte del default Slice E.
- **Decisione consigliata:** **core enqueue** testabile e sicuro (**validator** + persistenza + test), **UI zero**.

---

## 2. Obiettivo Slice E *(solo planning — deliverable questo file)*

| Elemento | Cosa pianificare in EXECUTION futura (non ora) |
|----------|-----------------------------------------------|
| **Origine outcome** | Da quali tipi di esito (`SupabaseManualPushResult`, `ProductPriceManualPushResult`, stati ViewModel, baseline refresh) derivare un enqueue. |
| **Negative paths** | Quando **non** creare entry (dry-run, preflight fallito, no-op, apply locale read-only, ecc.). |
| **Mapping** | `domain` (`catalog` \| `prices`), `eventType`, `changedCount`, shape `entityIDsShape` / `metadataShape` (stringhe sintetische privacy-safe su `SyncEventOutboxEntry`). |
| **Isolamento** | `ownerUserID` sessione; **account mismatch** → **no enqueue** o diagnostica locale coerente **D55-13**. |
| **Idempotenza** | `clientEventID` generato **una sola volta** per batch/outcome logico, stabile tra retry futuri (allineamento **D55-14** / **D56-04**). |
| **Validazione** | **`SyncEventRecordValidator.validate(_:)`** (TASK-056) **prima** di `pending` — se fallisce: policy **blockedContract** / **blockedAuth** / **blockedSchema** vs **skip enqueue** (tabella decisioni §6). |
| **Test futuri** | XCTest elencati §9 (eseguiti solo in EXECUTION separata con override). |
| **Gate anti-network** | EXECUTION futura: grep/assert **nessun** transport Supabase nel codice Slice E; nessun import che invii richieste. |

---

## 3. Decisioni architetturali *(D57-xx)*

| ID | Decisione |
|----|------------|
| **D57-01** | **Slice E è solo local enqueue** — persistenza outbox + logica producer; **zero network**. |
| **D57-02** | **Nessuna** RPC **`record_sync_event`**, **nessun** `SupabaseClient`, **nessun** drain della coda. |
| **D57-03** | Il **producer** deve essere **esplicito** e limitato ai **flussi manuali** già esistenti; **niente** auto-sync, **niente** background implicito. |
| **D57-04** | **Enqueue solo dopo** che l’outcome è **confermato dal flusso esistente** (es. push completato + read-back dove gia' richiesto dal task originale), **non** al tap iniziale né durante dry-run. |
| **D57-05** | **`clientEventID`**: generato **una sola volta**, **stabile** per lo stesso evento logico (stesso batch/outcome idempotente). |
| **D57-06** | **`ownerUserID`** corrente **obbligatorio**; **account mismatch** con sessione Supabase → **enqueue bloccato** / assente (coerente con preflight TASK-041/044/051). |
| **D57-07** | **`changedCount > 1000`** → **`blockedContract`** o **`localOnly`**, **mai** stato retryable; allineato **TASK-071** / attesa **TASK-072**. |
| **D57-08** | Payload outbox resta **shape + conteggi + metadata sanificato**; **vietate** liste massive di ID/barcode in chiaro. |
| **D57-09** | **No-op** (zero modifiche confermate): **default = non enqueue** salvo esigenza diagnostica **esplicitamente documentata** e gated (override separato). |
| **D57-10** | **ProductPrice** e **catalog** possono condividere un **helper enqueue** (factory/builder); **non** accoppiare logica business pesante dentro il modello outbox. |
| **D57-11** | **Enqueue locale post-push è best-effort controllato** e **non** deve trasformare un push remoto già riuscito in **fallimento business**. |
| **D57-12** | La futura **EXECUTION** deve **evitare doppio enqueue** per lo stesso **outcome logico** (dedupe / idempotenza locale prima di insert). |

**Dettaglio D57-11 (atomicità / failure policy enqueue):**
- Se **push remoto** + **read-back** hanno **successo** secondo il task sorgente, ma **`insert` outbox locale** fallisce:
  - **nessun rollback remoto**;
  - **nessun** secondo tentativo del **push remoto** “per compensare” l’outbox;
  - **non** classificare l’esito business del push come **failed** per colpa dell’outbox;
  - registrare **solo** diagnostica locale **privacy-safe** (es. log interno / warning strutturato, **non** stringhe UI localizzate come SSOT);
  - eventuale **retry/recovery** dell’enqueue o riconciliazione → **task futuro separato**, fuori Slice E se non strettamente locale.
- Se il **push remoto non è confermato** → **non enqueue** (**D57-04**).
- Se **read-back fallisce** e il task sorgente classifica esito **non confermato** / **partial** → mappare **solo** i record **confermati**; il resto non entra nel `changedCount` né forza enqueue “pieno”.

**Finestra crash / process-kill (post-push confermato, pre-enqueue locale):**
- Slice E **non** garantisce atomicità **cloud + outbox locale** né ordine transazionale unico tra i due store.
- Se l’app **crasha**, viene **terminata** o riciclata **dopo** push remoto **confermato** ma **prima** che l’enqueue locale sia persistito, l’evento sync **può non essere registrato** in outbox in questa slice — **accettabile** in Slice E: **non** esiste ancora reconciliation / **backfill** da event log remoto obbligatorio.
- **Non** compensare ripetendo il **push remoto**. Recovery / backfill eventi mancanti → **task futuro separato**, fuori Slice E.

**Dettaglio D57-12 (dedupe / idempotenza locale):**
- **Default consigliato:** dedupe tramite **`ownerUserID + clientEventID`** usando il modello **TASK-055** esistente — **non** introdurre una **nuova migration** o un **nuovo** campo SwiftData **solo** per dedupe se i campi attuali bastano.
- **Default operativo:** derivare **`clientEventID` deterministico** da batch/outcome **oppure** **riusarlo** se il **result terminale** del servizio lo espone gia'.
- **`sourceOperationKey`** resta **opzionale**: **non** introdurre nuovo campo/schema SwiftData **solo** per questo se **`ownerUserID + clientEventID`** basta. Se in EXECUTION servisse davvero, richiede **motivazione + test** in review prima di aggiungerlo al modello.
- In **EXECUTION**: verificare **per prima cosa** se lo schema esistente è sufficiente; indice/unique aggiuntivo solo se **necessario** e **coperto da review**.
- **Prima** di `insert`: controllo duplicati su **`ownerUserID + clientEventID`**; uso di **`sourceOperationKey`** (derivato o persistito) solo se documentato e giustificato, **non** come scorciatoia schema.
- Il dedupe **non** vale solo per entry **`pending`**: vale anche per righe già classificate **`blockedContract`**, **`blockedAuth`**, **`blockedSchema`**, **`localOnly`** — stesso **outcome logico** / stesso **`clientEventID`** non deve moltiplicare righe a ogni **ripubblicazione** di stato (es. SwiftUI re-render): la **seconda passata** deve risultare **`duplicateNoOp`** (o esito equivalente), **non** una nuova fila **`blocked*`** identica.
- **Anti-spam:** un outcome «massivo» con **`changedCount > 1000`** che mappa a **`blockedContract`** **non** deve generare **righe duplicate** infinite su ripetute notifiche dello stesso terminale — **`duplicateNoOp`** dopo la prima persistenza coerente.
- Stesso outcome rielaborato → **una sola** riga outbox per quell’idempotency key; seconda passata → **`duplicateNoOp`** (vedi §5.5).
- **XCTest obbligatorio** per dedupe; nessun obbligo di nuova colonna in questa fase **PLANNING**.

---

## 4. Sorgenti outcome da valutare

| Source | File probabile | Outcome disponibile | Enqueue sì/no *(regola iniziale)* | Note |
|--------|----------------|---------------------|-------------------------------------|------|
| Manual push catalog (suppliers/categories/products) | `SupabaseManualPushService.swift`, `SupabasePushPreflightViewModel.swift` | `SupabaseManualPushResult` + `SupabaseManualPushTerminalStatus` (completed, partial, failed, blocked, baseline refresh failed) | **Sì** solo se push remoto **confermato** con policy TASK-044 (es. **completed** con read-back ok; **partial** solo per conteggi **confermati**) | **No** su `blockedBeforeWrite`, `failedBeforeWrite` senza write confermata |
| ProductPrice manual push live | `SupabaseProductPriceManualPushService.swift`, `ProductPriceManualPushDebugViewModel.swift` | Esito insert + verify read-back (TASK-051) | **Sì** dopo **successo + verifica** coerente al task 051 | Dominio **`prices`** |
| Preflight/dry-run catalog | `SupabasePushPreflightViewModel.swift`, planning TASK-041/042 | Piani e stati dry-run | **No** | Dry-run non è outcome remoto confermato |
| Preflight/dry-run ProductPrice | TASK-050 / ViewModel dedicati | Snapshot dry-run | **No** | Stesso principio |
| Local apply pull (TASK-039/049) | `SupabasePullApplyService` (apply locale) | Piano applicato senza evento «push cloud» | **No** *(default)* | Eventuale enqueue = **task/override separato** (scope creep se misto a Slice E) |
| Baseline refresh / recovery | TASK-043/046, `SupabaseCatalogBaselineWriter`, servizi baseline | Baseline valid/refresh post-pull | **No** *(default)* | Non è push catalog/prezzi verso cloud; riesame solo se prodotto decisione dedicata |
| No-op push (contatori tutti zero dopo conferma) | Stessi servizi push | `completed` senza touched / work | **No** *(default — D57-09)* | Evita rumore diagnostico salvo policy esplicita |
| Partial success | `SupabaseManualPushResult` | `.partial` con mix confermato | **Sì condizionale** | `changedCount` = solo record **effettivamente confermati** nel mapping |
| Failed preflight | ViewModel preflight | Stati validation/blocked pre-write | **No** | Nessuna scrittura remota da riflettere |
| `blockedContract` (validator) | Integrazione futura | Validazione TASK-056 fallita per budget/count | **Sì opzionale** come riga **`blockedContract`** solo se utile diagnostica; **non retryable** |
| `blockedAuth` | Sessione assente/mismatch | Auth gate | **No enqueue** o riga **blockedAuth** — decidere in EXECUTION (preferenza: **no row** se sessione assente) |
| `blockedSchema` | Payload/shape | Incompatibilità schema validator | **blockedSchema** o skip — **non** retryable come network |
| **Baseline refresh fallito / warning dopo write** *(catalog push)* | `SupabaseManualPushService.swift` / stati TASK-044 | Es. `completedBaselineRefreshFailed`, `completed` con baseline refresh warning, `partial` con baseline refresh warning | **Sì** se **write remota e/o read-back** sono **già confermati** dal flusso per almeno un sottoinsieme di record | **No** se la **write non è confermata**; vedi nota sotto |

**Nota — stati baseline / refresh post-write (TASK-043/044):**
- Se il **cloud è già stato aggiornato** (write confermata e/o read-back confermato secondo task sorgente) ma il **refresh baseline** locale fallisce o resta solo warning → **non annullare** l’idea di enqueue per i record confermati: il fallimento baseline **non** deve «cancellare» l’evento come se il push non fosse avvenuto.
- In **`metadataShape`** (sintetico, privacy-safe) includere un flag tipo **`baselineRefreshFailed=true`** o **`baselineRefreshWarning=true`** (o equivalente compatto), **senza** payload raw né stack trace.
- Se **nessuna** write remota è confermata → **non enqueue** (allineamento **D57-04**).
- **`partial` + warning baseline**: enqueue **solo** per record **confermati**; aggregati skipped/failed solo come **conteggi** in metadata.

**Regole iniziali consigliate (executive summary):**
- Enqueue su **push remoto manuale confermato** + **read-back ok** dove il task sorgente lo richiede.
- Enqueue su **partial** solo per **cambi confermati**, `changedCount` coerente.
- **Non** enqueue su **dry-run puro**, **failed preflight**, **apply/pull locale read-only** (default), **no-op** (default).
- **`blockedContract`** può materializzarsi come entry **blocked** locale per tracciabilità, **mai** coda retryable implicita.

**Nota — hook solo su outcome terminali (no stati UI intermedi):**
- **Ownership:** il **producer/enqueue** deve essere invocato da un **punto controllato** nel **servizio/orchestratore** (o da un **facade** chiamato **subito dopo** un **result terminale** restituito dal servizio). **Non** deve dipendere da osservazione **passiva** di stati ViewModel/UI.
- Se un **ViewModel** chiama il facade, lo fa **una sola volta** dopo aver ricevuto il **result terminale** dal servizio (valore/completamento async), **non** su ogni aggiornamento dello stato o refresh della proprietà pubblicata.
- **Evitare** in particolare: **`onChange`**, **`onAppear`/`onDisappear`**, callback **snackbar/dialog**, **re-render** come **sorgente** dell’enqueue.
- La futura **EXECUTION** deve **agganciare** il producer/facade **solo** dove il **servizio/orchestratore** ha gia' prodotto un **risultato terminale** strutturato (struct/esito di completamento), **non** osservando stati **transitori** SwiftUI / ViewModel.
- **Vietato** generare outbox reagendo a **`@State`**, **`@Published`** generico, **loading**, **progress**, **retry in corso**, **refresh UI**, **re-render** della view, **`onAppear`/`onDisappear`**, stato **snackbar/dialog**, o ripubblicazioni ripetute dello **stesso** stato.
- L’**enqueue** deve essere **una sola volta per outcome terminale** valido, es.: **completed**; **partial** con record confermati; **`completedBaselineRefreshFailed`** (o equivalente) **con** write/read-back **confermati** dal flusso (§4). Motivazione: evitare **doppio enqueue** da ridisegni SwiftUI o **re-drive** del ViewModel.

---

## 5. Mapping evento *(prudente — execution confermerà enum/stringhe da schema reale)*

### 5.1 Tabella riassuntiva

| Dim | Piano |
|-----|--------|
| **`domain`** | **`catalog`** per supplier/category/product push; **`prices`** per `inventory_product_prices` / ProductPrice manual push. Stessa **policy anti-literal** della riga **`eventType`**: costanti/helper condivisi se i valori sono **confermati** in EXECUTION. |
| **`eventType`** | **Non** definire enum rigido **non verificato** contro backend: in **EXECUTION futura**, **leggere prima** schema/RPC **locale** e naming **Android** rilevante (TASK-045/068 ecc. come riferimento funzionale, **non** copia). **Se in EXECUTION il naming `domain` / `eventType` è confermato**, centralizzare in **helper costanti** (es. `SyncEventOutboxEventType`, file `*_SyncEventTypes.swift`) e **vietare** literal ripetuti nei servizi manual push / mapper. **Se non confermato:** **fermare** o lasciare **TODO bloccante** (non hardcodare stringhe sparse «a caso»); in alternativa limitare valori provvisori **solo** a **test/fixture** con **`UNKNOWN`**. Non introdurre enum Swift chiuso che possa divergere dal backend senza evidenza. |
| **`changedCount`** | Vedi **§5.2** (regole per `catalog`, `prices`, `partial`, zero). |
| **`entityIDsShape`** | **Catalog:** conteggi **per tipo** (suppliers / categories / products confermati). **Prices:** shape coerente col contratto (es. conteggio righe prezzo), **non** obbligatoriamente «per prodotto» salvo conferma backend. **No** liste massive. |
| **`metadataShape`** | Riepilogo: task/scope, `partial`, flag baseline (§4), conteggi aggregati failed/skipped — **no raw payload**, no JWT/URL query. |

### 5.2 `changedCount` e partial *(precisione)*

- **Catalog manual push:**
  `changedCount` = **`suppliersConfirmed + categoriesConfirmed + productsConfirmed`** (naming indicativo: usare i contatori **confermati** dal result dopo write+verifica, non candidati preflight, non voci **escluse/blocked**, non dry-run, non sola intenzione no-op).
- **ProductPrice push:**
  `changedCount` = **numero di righe prezzo confermate** (insert/verify riusciti secondo TASK-051), **non** «numero prodotti» salvo un contratto backend esplicito che richieda semantica diversa (da verificare in EXECUTION).
  - **Batch ampi:** ProductPrice può avere **molte righe prezzo** nello stesso outcome; se le **righe prezzo confermate** superano **1000**, **non** creare entry **`pending`** retryable — applicare **TASK-056** / **D57-07**: esiti **`blockedContract`** e/o **`localOnly`** (o equivalente non retryable). **Split automatico** del batch in Slice E è **vietato** (non inventare partizionamento in execution); uno **split controllato** è **task futuro** fuori Slice E.
- **Partial:**
  Contare **solo** record **confermati**; in **`metadataShape`** si può porre **`partial=true`** e conteggi **aggregati** skipped/failed, **mai** payload grezzo.
- **`changedCount == 0`:** default allineato **D57-09** → **no enqueue** (salvo diagnostica esplicitamente gateata altrove).

### 5.3 Event source whitelist *(perimetro esplicito)*

- Slice E supporta **solo** le **source** descritte in **questo task** (tabella §4; contesto TASK-044/047/051). **Vietato** un enqueue «catch-all» su risultati generici di «sync» non mappati.
- Nuovo source in EXECUTION **non** previsto qui → **non** inventare mapping ad hoc: **`unsupportedSource`** / **no enqueue** + **follow-up** documentato (task/override).
- **Se un outcome non rientra nella whitelist di §4**, il default deve essere **`skippedUnsupported`** (§5.5) — **non** `blockedSchema` (un gap di mapping locale **non** è un errore schema backend).
- Il follow-up è **planning/review** o task separato — **mai** mapping inventato in execution senza aggiornare questo documento / backlog.
- Allineare naming esito in EXECUTION con la tabella **§5.5** (es. riga **`skippedUnsupported`**).

### 5.4 Generator / clock *(determinismo test — futura EXECUTION)*

- Evitare **`UUID()`** / **`Date()`** sparsi **nel mapper** come unica fonte: pianificare **injection** leggera di:
  - **`clientEventIDGenerator`** (o closure stabile per test);
  - **`clock`** (timestamps `createdAt` / `updatedAt` coerenti nei test);
  - eventualmente **`sourceOperationKeyBuilder`** per chiavi deterministiche.
- In **XCTest** i generator/clock devono essere **deterministici**; in **produzione** default reali (UUID v4, `Date()`, ecc.) restano ammessi via default del facade.
- Scopo: testare **dedupe**, **idempotenza** e **duplicateNoOp** senza flake.

### 5.5 Producer result model futuro *(tipizzato, **non** UI)*

Pianificare (EXECUTION) un tipo esito **puro** del producer/facade — **stati logici / testabili**, **non** chiavi `Localizable.strings`:

| Esito logico | Significato sintetico |
|--------------|------------------------|
| `enqueued` | Entry outbox creata (tipicamente `pending` o blocked intenzionale). |
| `skippedNoOp` | Nessun lavoro confermato / niente da registrare. |
| `skippedDryRun` | Solo simulazione, nessuna write confermata. |
| `skippedFailedPreflight` | Preflight/validazione pre-write fallita. |
| `blockedContract` | Validator TASK-056 / limiti budget / `changedCount` oltre soglia. |
| `blockedAuth` | Sessione/owner mismatch. |
| `blockedSchema` | Shape/validator schema bucket. |
| `duplicateNoOp` | Stesso outcome già rappresentato — **nessuna** seconda entry (**D57-12**). |
| `enqueueFailedLocal` | Persistenza SwiftData/outbox fallita; **push business** può restare **success** (**D57-11**) — **non** confondere con fallimento remoto. |
| `skippedUnsupported` | Source/outcome **non** in whitelist §5.3 — **no enqueue**, follow-up planning. |

**Regole:** Slice E **senza UI**; log/console di debug devono usare questi **outcome tipizzati** / codici, **non** testo localizzato utente come fonte di verità.

**Owner/session:** ogni entry deve avere **`ownerUserID`** == utente Supabase collegato all’outcome; **`sourceDeviceID`** se disponibile senza log invasivi.

---

## 6. Integrazione validator *(TASK-056)*

- **Prima** di inserire una entry in stato **`pending`**, costruire un **`SyncEventRecordRequest`** (o equivalente minimo) e passarlo da **`SyncEventRecordValidator`**.
- Se **`validate` OK**: procedere a materializzare **`SyncEventOutboxEntry`** (in EXECUTION) via **`SyncEventOutboxLocalStore`** / factory TASK-055.
- Se **`contract`** (es. **`changedCount > 1000`**, budget JSON): mappare a **`blockedContract`** o **`localOnly`** (**D57-07**); **non** `failedRetryable`.
- Se **`auth`**: **`blockedAuth`** o **abort enqueue** senza riga — preferenza da fissare in EXECUTION (**D57-06**).
- Se **`schema`**: **`blockedSchema`**.
- **Nessun** utilizzo del **dry-run recorder** per simulare RPC in Slice E se cio' implica complessità non necessaria: il **validator** è il gate; il **recorder** resta per Slice D / futuro **Slice F**.

---

## 7. Store / integrazione locale

### 7.1 Facade enqueue *(opzione consigliata)*

- Introdurre in EXECUTION futura un **servizio/facade** dedicato (nome indicativo **`SyncEventOutboxEnqueueService`** o equivalente) che:
  - riceve **DTO / outcome gia' normalizzati** (valori Sendable/struct derivati dal servizio, **non** stato UI grezzo);
  - orchestra **validator** → factory/store **TASK-055**; **inject** opzionale di **`clientEventIDGenerator`** / **`clock`** per test (**§5.4**);
  - espone il **Producer result model** (§5.5).
- **`SupabaseManualPushService`** / **`SupabaseProductPriceManualPushService`**: **non** devono importare dettagli di **JSON budget**, **metadata raw**, ne' costruire **entity_ids** complessi; restano **sottili** (**una** chiamata al facade con outcome terminale). Mapping pesante (conteggi confermati, shape metadata) → **mapper puri** testabili in modulo dedicato — **evitare** che i file dei servizi push **crescano** oltre il necessario.
- I ViewModel **non** contengono logica outbox: al massimo **una** invocazione al facade dopo **esito terminale** dal servizio (§4 nota hook).

### 7.2 SwiftData write safety *(futura EXECUTION)*

- Usare il **pattern `ModelContext`** gia' presente nel progetto (MainActor / container condiviso come negli altri flussi SwiftData).
- **Non** inserire entry outbox da **Task detached** o thread **non coerente** con il context che persiste l’outbox.
- Se il servizio push **non** ha accesso sicuro al `ModelContext`, **non** «passare context ovunque» lasciando il servizio: preferire **injection** del facade enqueue dal layer che gia' possiede il context (es. ViewModel / orchestratore), o un **adapter** locale limitato.
- **Evitare singleton globale** del `ModelContext`.
- **Test** con **SwiftData in-memory** per insert + **dedupe** (**D57-12**).
- Slice E: **nessun** drain / query «retry queue» / worker.

**Nota — Transaction / policy `save` locale (non atomica rispetto al cloud):**
- L’enqueue è una **write SwiftData separata** dal **push remoto** → **nessuna** transazione atomica cross-cloud / cross-process; **non** tentare di simulare atomicità remoto+locale.
- Se **`context.save()`** (o equivalente) **fallisce dopo** che il task sorgente ha gia' classificato il push come **confermato**, applicare **D57-11**: esito business **resta** success/parziale conseguito; **no** rollback remoto, **no** retry remoto; diagnostica locale privacy-safe; producer → **`enqueueFailedLocal`**.
- **Vedi anche** in **D57-11** la **finestra crash/kill** tra push confermato e enqueue locale (evento outbox **mancante** accettabile in Slice E senza backfill).

### 7.3 Persistenza outbox

- Riutilizzare **`SyncEventOutboxLocalStore`** e factory **TASK-055** per insert **solo in EXECUTION futura**.
- Campi: **`ownerUserID`** obbligatorio; **`sourceDeviceID`** opzionale; **`maxAttempts`/`nextRetryAt`** coerenti con modello esistente — **in Slice E non** si esegue retry/drain, solo persistenza stati iniziali corretti.
- **Nessuna** query «prossima riga da inviare» / drain.

**Nota — crescita outbox / retention *(fuori scope E)*:**
Slice E **può creare** righe outbox ma **non** le invia (nessun drain). La **crescita** della tabella va quindi **tenuta presente**. **In Slice E non** implementare **cleanup**, **retention policy**, né **compattazione** outbox. Pianificare solo mitigazioni **locali e testabili**: **nessun enqueue** per **no-op** / **dry-run**; **dedupe** forte (**D57-12**); evitare **spam** di righe **`blockedContract`** duplicate per lo stesso outcome. **Retention / cleanup / compaction** richiedono **task futuro separato**, verosimilmente legato a **Slice G** (o successivo), dopo che esiste invio/reconciliation.

---

## 8. UI/UX

- **Execution futura Slice E:** partire da **zero UI** come **scelta predefinita** (solo logica + test). Se l’executor ritenesse indispensabile conteggio/debug in UI, **fermarsi** e **documentare il motivo** (non aggiungere UI «di default» senza decisione esplicita).
- **Nessun** `OptionsView`, **nessuna** nuova stringa **localizzata**, **nessuna** CTA (sync/drain/invio eventi) in Slice E salvo override utente successivo documentato.
- Slice E: **nessuna** nuova sezione `OptionsView` obbligatoria (reiterazione §10).
- **Raccomandazione forte:** **nessuna UI** in Slice E — solo logica + test.
- **No** CTA «Sincronizza tutto», «Invia eventi», «Drain», contatori extra obbligatori — eventuale debug solo via test o documentazione.

---

## 9. Test futuri *(XCTest — pianificati; non eseguiti in questo turno)*

| # | Intento |
|---|---------|
| T57-01 | Catalog manual push **success** (mock) → **una** entry `pending` con `domain=catalog`. |
| T57-02 | ProductPrice push **success** (mock) → entry `pending` con `domain=prices`. |
| T57-03 | **Partial** success → `changedCount` uguale al **solo** subset confermato; metadata `partial=true` senza raw. |
| T57-04 | **No-op** → **nessuna** entry (default). |
| T57-05 | **Dry-run** / preflight only → **nessuna** entry. |
| T57-06 | **Failed preflight** → **nessuna** entry. |
| T57-07 | **Owner mancante** → **no** enqueue (o errore factory documentato). |
| T57-08 | **Account mismatch** → **no** enqueue. |
| T57-09 | **`changedCount` 1001** → `blockedContract` / `localOnly`, **non** pending retryable. |
| T57-10 | **Validator contract** (metadata/entityIDs budget) → `blockedContract`. |
| T57-11 | **EntityIDs** shape senza liste massive — assert contenuto stringa/shape. |
| T57-12 | **Grep anti-scope**: nessun `SupabaseClient`, `.rpc(`, URL session live in **nuovi file Slice E**. |
| T57-13 | **Grep**: nessun «drain», worker, `BGTask`, Realtime nei file Slice E. |
| T57-14 | **Grep**: nessuna modifica obbligatoria pattern UI (se zero UI). |
| T57-15 | **Idempotenza / dedupe**: stesso batch/outcome due volte → **una** entry; seconda = **`duplicateNoOp`** (**D57-12**). |
| T57-16 | **Push remoto + read-back OK** ma **insert outbox locale fallisce** → esito business push resta **success** / warning locale — **no** retry remoto, **no** rollback cloud; producer = `enqueueFailedLocal` (**D57-11**). |
| T57-17 | **`completedBaselineRefreshFailed`** (o equivalente) con write confermata → **enqueue sì** con flag sintetico baseline in `metadataShape` (§4). |
| T57-18 | **Catalog** `changedCount` = somma confermati suppliers+categories+products (mock mapper). |
| T57-19 | **Prices** `changedCount` = righe prezzo confermate, non conteggio prodotti salvo contratto esplicito. |
| T57-20 | **`changedCount == 0`** → nessuna entry. |
| T57-21 | **Partial** con confermati + falliti → solo confermati in outbox. |
| T57-22 | **SwiftData in-memory**: insert + lookup dedupe (`ownerUserID`+`clientEventID`). |
| T57-23 | **No** `ModelContext` singleton globale / anti-pattern documentato in code review. |
| T57-24 | **Grep**: nessun `.rpc(`, `SupabaseClient`, drain, worker, BGTask, Realtime (reiterazione con T57-12/13). |
| T57-25 | **Stesso** outcome terminale ripubblicato dal ViewModel / re-render SwiftUI → **una sola** enqueue (o `duplicateNoOp` alla seconda barra di protezione). |
| T57-26 | **Loading / progress / onAppear / snackbar** → **nessuna** enqueue. |
| T57-27 | **`clientEventIDGenerator`** deterministico in test → stesso esito → **dedupe** stabile / `duplicateNoOp`. |
| T57-28 | **`clock`** deterministico → `createdAt`/`updatedAt` prevedibili nei test (facade/mapper). |
| T57-29 | **Source non in whitelist** → `skippedUnsupported` / no entry. |
| T57-30 | **`context.save()`** fallito dopo push confermato → `enqueueFailedLocal`; esito remoto resta **success** (**D57-11**, §7.2). |
| T57-31 | **Dedupe** con **solo** campi TASK-055 esistenti — **nessun** nuovo schema/migration **solo** per dedupe (salvo review motivata). |
| T57-32 | **Mapper** senza `UUID()`/`Date()` hardcoded non injectati (flake) — usare generator/clock injectati (**§5.4**). |
| T57-33 | Stesso terminale **blockedContract** (o **`localOnly`**) riprocessato / ripubblicato → **nessuna** seconda riga duplicata; esito **`duplicateNoOp`** (**D57-12**). |

---

## 10. Anti-scope *(TASK-057 planning + future EXECUTION Slice E)*

**Nota — Release vs UI DEBUG:** Slice E è **enqueue locale** (vedi §1); compilazione **Release** ammessa per logica pura **senza** trasporto. **Vietato** confondere Slice E con una card **UI DEBUG**: ogni superficie utente / CTA / contatore è **fuori default** e solo **DEBUG + task separato** se mai richiesta.

**Vietato:**
- Supabase **live**, RPC **`record_sync_event`** reale, **`SupabaseClient`**, **`.rpc(`** in codice production Slice E.
- **Drain** outbox, **worker**, **timer**, **BGTask**, **Realtime** subscribe.
- **UI** / nuove card **OptionsView** (salvo override esplicito successivo).
- **SQL** / **migration** / **Android**.
- **TASK-058** / slice successive accorpate indebitamente.
- **Sync automatico**, cleanup outbox globale, **background sync startup**.

---

## Planning (Claude) — formato operativo

### Obiettivo
Definire progetto **Slice E** — **producer outbox locale** collegato agli outcome **manual-only** esistenti, con **validator TASK-056** e **zero rete**, preparando EXECUTION futura a scope minimo.

### Analisi
- **TASK-055** ha **storage**; **TASK-056** ha **contratto**; i **servizi push** (044/047/051) hanno **esiti strutturati** ma **non** alimentano l’outbox.
- Il rischio maggiore è **scope creep** (pull/apply, baseline) e **doppio conteggio** (candidati vs confermati).

### Approccio *(per EXECUTION futura — non eseguito ora)*
1. Introdurre facade **`SyncEventOutboxEnqueueService`** (nome indicativo, §7.1) che riceve **outcome strutturato** + contesto owner e restituisce **Producer result** (§5.5).
2. Agganciare **solo** nei punti terminali **manual-flow** dopo **write/read-back** dove gia' definito dai task 044/051; servizi push **solo** chiamata leggera al facade.
3. **Validator** sempre prima di pending; **mai** chiamate network nel modulo enqueue; **dedupe** prima insert (**D57-12**).

### File coinvolti *(futura EXECUTION — elenco probabile)*
- `SupabaseManualPushService.swift`, `SupabasePushPreflightViewModel.swift`
- `SupabaseProductPriceManualPushService.swift`, `ProductPriceManualPushDebugViewModel.swift`
- `SyncEventOutboxEntry.swift`, `SyncEventOutboxLocalStore.swift` (solo uso, non ridefinizione modello salvo necessità minima)
- `SyncEventRecording.swift` — **`SyncEventRecordValidator`**
- Nuovo modulo/facade enqueue (nome definito in EXECUTION) + eventuali **mapper puri** testabili
- Test bundle: nuovi test enqueue (nome da definire in EXECUTION)

### Rischi
| Rischio | Mitigazione |
|---------|-------------|
| Confondere candidati preflight con confermati | **D57-04**, mapping §5.2 |
| Eventi >1000 | **D57-07**, stati blocked/localOnly; ProductPrice batch §5.2 |
| Duplicati stesso push / stesso blocked | **D57-05**, **D57-12** (anche stati **blocked***), test T57-15 |
| Crescita outbox senza drain | §7.3 — mitigazioni testabili; retention **task futuro** |
| Outbox insert fallisce dopo push OK | **D57-11**, `enqueueFailedLocal`, test T57-16 |
| Baseline refresh fallito ma cloud OK | §4 nota baseline + metadata flag, test T57-17 |
| ModelContext / threading | §7.2, test T57-22/23 |
| SwiftUI ripubblicazione / doppio hook | §4 nota hook terminali, test T57-25/26 |
| Finestra crash / kill prima di enqueue | **D57-11**, §7.2 — accettabile in E; recovery fuori scope |
| Live ≠ clone | Nessuna assunzione; no live in E |

### Criteri di accettazione *(contratto TASK-057 — fase **PLANNING**)*
- [ ] File **TASK-057** contiene §1–§10 complete con **D57-01…12**, tabella sorgenti (inclusa baseline), mapping **§5.1–5.5**, validator §6, store/facade/SwiftData §7, test §9, anti-scope.
- [ ] **`MASTER-PLAN.md`** aggiornato: progetto **ACTIVE**, task **TASK-057** **ACTIVE/PLANNING**, ultimo **TASK-056 DONE**, **TASK-052** BLOCKED/superseded, **nessun TASK-058**.
- [ ] **Nessun** Swift, **nessun** build/test, **nessuna** chiamata live in questo turno.
- [ ] TASK-057 **non** marcato **DONE**.

### Handoff post-planning
- **READY FOR PLANNING REVIEW** — **non** «READY FOR EXECUTION»; la fase resta **PLANNING** fino a review documentale esplicita.
- **Planning frozen except review fixes.** Significato: **nessun** nuovo scope; **nessuna** nuova feature; **nessuna** Slice F/G/H/I; **nessun** **TASK-058**; **solo** correzioni richieste dalla **review documentale** (o micro-allineamenti testo tracking), non ampliamenti di perimetro.
- **Prossima fase**: **REVIEW documentale** (Claude / utente) su questo file — **nessuna** EXECUTION Swift implicita.
- **Prossimo agente**: **Claude / Reviewer** (documentale) o utente.
- **Prossima azione consigliata**: chiudere review planning; poi **solo** con **user override** separato → **EXECUTION Slice E only** (hook + facade + test). Dopo override: **ancora** **no RPC live**, **no drain**, **no UI** obbligatoria; task **non DONE** fino a review tecnica post-implementazione e conferma utente.

---

## Handoff post-planning — storico *(conferma tracking pre-execution)*

> Nota Codex 2026-05-07: questa sezione resta come handoff storico del planning. Lo stato corrente post-review e' in metadata, **Review**, **Fix** e **Handoff finale**: **TASK-057 DONE / Chiusura**.

- **TASK-057** = **ACTIVE / PLANNING** — **non DONE**.
- **READY FOR PLANNING REVIEW** — **non** «READY FOR EXECUTION»; **nessuna** EXECUTION Swift autorizzata da questo handoff da solo.
- **Prossima fase**: **REVIEW documentale** **solo** (checklist sotto); **Codex / EXECUTION** solo dopo **user override** esplicito.
- **Execution futura** = **Slice E only**; richiede **user override** separato; mantenere: **no** RPC live `record_sync_event`, **no** `SupabaseClient`, **no** drain/worker/BGTask/Realtime, **no** UI obbligatoria, **no** SQL/Android/**TASK-058**.
- **Ultimo completato progetto** (riferimento): **TASK-056 DONE**; **TASK-052** resta **BLOCKED / superseded**.

---

### Checklist — PLANNING REVIEW *(documentale)*

- [ ] **TASK-057** resta **ACTIVE / PLANNING** e **non DONE**.
- [ ] **TASK-056** resta **ultimo completato** **DONE**.
- [ ] **TASK-052** resta **BLOCKED / superseded** (**non DONE**).
- [ ] **Nessun TASK-058** aperto.
- [ ] **D57-01…12** coerenti con testo corrente.
- [ ] **Hook** solo su **outcome terminali** (§4 nota) documentato.
- [ ] **Dedupe / idempotenza** (**D57-12**, §5.4, §7) documentati.
- [ ] **Generator / clock** deterministic (**§5.4**) documentati.
- [ ] **SwiftData** write safety + nota transaction (**§7.2**) documentata.
- [ ] **No** network / RPC live / drain / UI obbligatoria documentato (§8, §10).
- [ ] Prossimo passo = **REVIEW documentale**, **non** EXECUTION automatica.
- [ ] **Planning frozen except review fixes** presente (Handoff post-planning).
- [ ] **Crash/window** post-push pre-enqueue documentata (**D57-11** / §7.2).
- [ ] **Zero UI** come default Slice E documentato (**§8**).
- [ ] Source **non** in whitelist §4 → **`skippedUnsupported`** documentato (**§5.3**).
- [ ] **`sourceOperationKey`** opzionale, **non** schema obbligatorio (**D57-12**).
- [ ] **Debug/Release** vs «UI DEBUG» e default **Release-safe** senza UI/drain/RPC (§1, §10).
- [ ] **Crescita outbox** / assenza retention in E documentata (**§7.3**).
- [ ] **Dedupe** anche per stati **blocked*** / **`localOnly`** (**D57-12**).
- [ ] **ProductPrice** batch **>1000** → non **pending** retryable, no split automatico (**§5.2**).
- [ ] **`domain`/`eventType`**: costanti centralizzate se confermate, altrimenti stop/TODO (**§5.1**).

---

## Review (Claude / Codex su user override)

- **Esito**: **APPROVED_FIXED_DIRECTLY**
- **Scope review**: review tecnica Slice E local enqueue completa su `SyncEventOutboxEnqueueService.swift`, outbox TASK-055, validator TASK-056, test Slice E e regressioni TASK-055/056.
- **Fix diretti applicati**:
  - rimosso fallback sentinel `"invalid-client-event-id"`: generator non valido -> `blockedContract` / `missing_client_event_id`, nessuna entry;
  - aggiunto rollback del `ModelContext` se `context.save()` locale fallisce nel facade con context reale;
  - aggiunti test ProductPrice zero-confirmed rows, ProductPrice verification failed, generator non valido.
- **Conferme tecniche**:
  - Slice E resta **local enqueue only**: nessun `SupabaseClient`, nessuna `.rpc(`, nessuna chiamata live `record_sync_event`, nessun `.from`/PostgREST write nel file production Slice E;
  - nessun drain/worker/timer/BGTask/Realtime, nessuna UI, nessuna modifica `OptionsView.swift`, nessuna modifica `Localizable.strings`;
  - nessuna modifica SQL/Supabase/Android e nessun TASK-058 aperto;
  - mapper catalog/ProductPrice privacy-safe: shape/conteggi sintetici, no payload raw Product/ProductPrice, no liste massive ID/barcode;
  - dedupe locale prima dell'insert su `ownerUserID + clientEventID`, valido anche per stati terminali/bloccati;
  - validator TASK-056 integrato prima di `pending`; `changedCount > 1000` e budget JSON -> `blockedContract`, non retryable.
- **Limiti accettati Slice E**: nessuna atomicita' cloud+local; crash/window post-push pre-enqueue resta limite documentato; retry/drain/reconciliation/retention/backfill restano Slice F/G/H/I o task futuri.

---

## Execution (Codex) — Slice E local enqueue

### Obiettivo eseguito
Implementata solo **Slice E**: facade locale che materializza `SyncEventOutboxEntry` da outcome terminali confermati dei flussi manual push catalog/ProductPrice, usando `SyncEventRecordValidator` (TASK-056) e `SyncEventOutboxLocalStore` / factory (TASK-055), **senza** invio Supabase.

### File modificati
- `iOSMerchandiseControl/SyncEventOutboxEnqueueService.swift`
- `iOSMerchandiseControlTests/SyncEventOutboxEnqueueServiceTests.swift`
- `docs/TASKS/TASK-057-supabase-sync-events-slice-e-local-enqueue-ios.md`
- `docs/MASTER-PLAN.md`

### Decisioni concrete
- Creati `SyncEventOutboxEnqueueService`, `SyncEventOutboxProducerOutcome`, `SyncEventOutboxProducerResult` e mapper/factory locali nel nuovo file Slice E.
- Supportate solo source whitelist: catalog manual push terminal outcome e ProductPrice manual push terminal outcome; source non mappata -> `skippedUnsupported`, nessuna entry.
- Enqueue ammesso solo per outcome terminali normalizzati: completed, partial con record confermati, `completedBaselineRefreshFailed` con write confermata; dry-run, failed preflight, no-op, transitori UI e source generiche non creano entry.
- Mapping catalog: `domain=catalog`, `eventType=catalog_changed`, `changedCount=suppliersConfirmed+categoriesConfirmed+productsConfirmed`, `entityIDsShape` solo conteggi per tipo, metadata sintetico con source/partial/baseline/skipped/failed.
- Mapping prices: `domain=prices`, `eventType=prices_changed`, `changedCount=confirmedPriceRows`; `changedCount==0` -> `skippedNoOp`; `changedCount>1000` -> `blockedContract`, non pending retryable e nessuno split automatico.
- Validator TASK-056 eseguito prima di creare entry `pending`; errori contract/auth/schema mappati a risultati tipizzati e, dove coerente, entry blocked locale.
- Dedupe locale prima dell'insert su `ownerUserID + clientEventID`, valido anche per stati `pending`, `blocked*`, `localOnly`, `sent`, `dead`; duplicato -> `duplicateNoOp`.
- Generator `clientEventIDGenerator` e `clock` iniettati per test deterministici; default produttivi reali confinati nel service.
- SwiftData: uso di `ModelContext` iniettato, `SyncEventOutboxLocalStore.add`, `context.save`; nessun singleton globale, nessun detached task. Save failure -> `enqueueFailedLocal`.
- Nessun hook automatico da UI/ViewModel/render: il facade riceve valori terminali gia' normalizzati e non osserva stato UI.

### Test e check eseguiti
- ✅ **ESEGUITO** — Build Debug: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' build` -> PASS.
- ✅ **ESEGUITO** — XCTest Slice E: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' test -only-testing:iOSMerchandiseControlTests/SyncEventOutboxEnqueueServiceTests` -> PASS, 23 test dopo review+fix.
- ✅ **ESEGUITO** — Regressione TASK-055 state: `SyncEventOutboxStateTests` -> PASS, 20 test.
- ✅ **ESEGUITO** — Regressione TASK-055 store: `SyncEventOutboxLocalStoreTests` -> PASS, 5 test.
- ✅ **ESEGUITO** — Regressione TASK-056: `SyncEventRecordingTests` -> PASS, 29 test.
- ✅ **ESEGUITO** — `git diff --check` -> PASS.
- ✅ **ESEGUITO** — whitespace no-index sui nuovi file Slice E/test -> nessuna segnalazione.
- ✅ **ESEGUITO** — grep anti-scope production Slice E: nessun match per `SupabaseClient`, `.rpc(`, `.from(`, `.insert(`, `.upsert(`, `.update(`, `.delete(`, `.channel(`, `.subscribe(`, `BGTask`, `Realtime`, `service_role`, `URLSession`, `record_sync_event`, `drain`, `worker`, `timer`.

### Conferme anti-scope
- Confermato: **nessuna** chiamata Supabase live, **nessuna** RPC live `record_sync_event`, **nessun** `SupabaseClient`.
- Confermato: **nessun** drain outbox, worker, timer, BGTask, Realtime.
- Confermato: **nessuna** UI nuova, **nessuna** modifica `OptionsView.swift`, **nessuna** modifica `Localizable.strings`.
- Confermato: **nessuna** modifica SQL/Supabase/Android.
- Confermato: **nessun TASK-058** aperto o anticipato.
- Confermato in execution: **TASK-057 non DONE** fino alla review tecnica successiva.

### Limiti rimasti / future slice
- Slice E non invia eventi, non draina l'outbox e non implementa retry/reconciliation/retention.
- Slice F/G/H/I restano fuori scope: RPC live, drain worker, UI/debug eventuale, cleanup/backfill/recovery richiedono task separati.

## Handoff post-execution (Codex)

- **Storico**: execution iniziale conclusa con **TASK-057 ACTIVE / REVIEW**, poi review tecnica su user override chiusa in questo turno.
- **Handoff storico**: Slice E implementata e verificata con build/test/grep; nessuna execution remota/live, nessuna UI, nessun drain, nessun TASK-058.

---

## Fix (Codex) — review tecnica

- **Fix applicati**:
  - `SyncEventOutboxEnqueueService.swift`: `context.save()` reale ora fa rollback del `ModelContext` su errore locale prima di restituire `enqueueFailedLocal`;
  - `SyncEventOutboxEnqueueService.swift`: rimosso fallback sentinel per `clientEventID`; generator vuoto/whitespace produce `blockedContract` con `missing_client_event_id` e non crea righe non deduplicabili;
  - `SyncEventOutboxEnqueueServiceTests.swift`: aggiunti test per ProductPrice `changedCount == 0`, ProductPrice verification failed e generator non valido.
- **Check reali post-fix**:
  - ✅ **ESEGUITO** — Build Debug iPhone 16e OS 26.2 -> PASS;
  - ✅ **ESEGUITO** — `SyncEventOutboxEnqueueServiceTests` -> PASS, 23 test;
  - ✅ **ESEGUITO** — `SyncEventOutboxStateTests` -> PASS, 20 test;
  - ✅ **ESEGUITO** — `SyncEventOutboxLocalStoreTests` -> PASS, 5 test;
  - ✅ **ESEGUITO** — `SyncEventRecordingTests` -> PASS, 29 test;
  - ✅ **ESEGUITO** — `git diff --check` -> PASS;
  - ✅ **ESEGUITO** — grep anti-scope production Slice E -> nessun match;
  - ✅ **ESEGUITO** — verifica file fuori scope -> nessuna modifica a `OptionsView.swift`, `Localizable.strings`, SQL/Supabase/Android.
- **Warning build/test**: visto warning Xcode/AppIntents `Metadata extraction skipped. No AppIntents.framework dependency found.`; non e' un warning Swift nei file Slice E e non risulta introdotto dalla patch, ma senza baseline build separata non lo marco come "nuovo/non nuovo" in modo assoluto.

## Handoff finale

**TASK-057 DONE — Slice E local enqueue integration reviewed and closed**
