# TASK-059: Supabase `sync_events` Slice G iOS — outbox drain controllato e head-of-line safe

> **Planning + execution controllata.** Questo file prepara Slice G e registra la execution controllata autorizzata il 2026-05-07. Esito storico: **Path B — payload insufficiente**; drain RPC bloccato. Stato finale: **Slice G1 Payload Fidelity** reviewata con fix diretti e chiusa **APPROVED_FIXED_DIRECTLY / DONE**; persistenza payload minimale implementata, validata e privacy-safe; **nessun** drain RPC. **G2 drain RPC resta futuro/out-of-scope**.
>
> **Riferimento remoto (allineamento repo):** `https://github.com/XNIW/iOSMerchandiseControl` — prima dell’execution futura verificare il branch aggiornato; il gate schema resta il clone locale Supabase.

## Informazioni generali
- **Task ID**: TASK-059
- **Titolo**: Supabase `sync_events` Slice G iOS — outbox drain controllato e head-of-line safe
- **File task**: `docs/TASKS/TASK-059-supabase-sync-events-outbox-drain-ios.md`
- **Stato**: DONE
- **Fase attuale**: Chiusura
- **Responsabile attuale**: Utente / prossimo task da decidere
- **Data creazione**: 2026-05-07
- **Ultimo aggiornamento**: 2026-05-07 *(REVIEW+FIX Slice G1 completata; TASK-059 chiuso DONE solo per Payload Fidelity outbox. No drain RPC/Supabase live/SQL/Android/UI/TASK-060.)*
- **Ultimo agente che ha operato**: Codex / Reviewer+Fixer

## Dipendenze
- **Dipende da**: **TASK-058** (DONE) — `SupabaseSyncEventLiveRecorder` + `SyncEventRPCTransport` + mapper; **TASK-057** (DONE) — enqueue locale; **TASK-056** (DONE) — contract/validator/dry-run; **TASK-055** (DONE) — outbox SwiftData/state machine/store
- **Sblocca**: eventuali slice successive (solo candidati, **non** TASK-060): orchestrazione UI/business «chiama drain» oppure worker/BG **fuori scope esplicito da Slice G**

## Scopo
Progettare una **Slice G iOS minima**: servizio di **drain manuale e controllato** che legga `SyncEventOutboxEntry` eleggibili, invii `SyncEventRecording.record(_:)` (recorder TASK-058 / fake in test), aggiorni lo stato outbox tramite la **state machine esistente**, eviti **head-of-line blocking** in stile Android TASK-070, e resti **totalmente testabile** senza Supabase live né worker automatici.

## Contesto
- Slice **A–F** coprono read-only `sync_events`, UI DEBUG read-only, foundation outbox, contract/dry-run, enqueue locale, recorder live **isolato** senza drain.
- L’outbox locale accumula eventi con idempotenza `owner_user_id` + `client_event_id` (lato remoto); il drain è il passo successivo **logico** ma oggi **assente** nel codice iOS.
- Android documenta pattern **retry outbox head-of-line safe** (TASK-070) e rischi contrattuali `record_sync_event` / `PayloadValidation` (TASK-071); Supabase locale fissa limiti su `changed_count`, `entity_ids`, `metadata`.

## Non-obiettivi / anti-scope rigido
- **No** nuova UI in `OptionsView`; **no** `Localizable`
- **No** `BGTask`, timer, Realtime, worker automatici, drain all’avvio app
- **No** live dataset validation; **no** smoke RPC/Supabase live obbligatori in Slice G
- **No** SQL migration, **no** `db push`, **no** patch Android
- **No** cleanup/cancellazione outbox locale, **no** delete/purge su `sync_events` remoto
- **No** nuova auth/multi-tenant
- **No** refactor grande dei file monolitici preesistenti
- **No** creazione **TASK-060** o roadmap oltre quanto serve a Slice G
- **Nessuna implementazione Swift/progetto in TASK-059**: **no** modifica Swift, **no** `project.pbxproj`; build/XCTest ammessi solo come check di regressione/tracking se una execution controllata viene autorizzata e senza introdurre drain RPC

## Fonti da leggere (pre-execution futura)
### iOS (workspace)
- `SyncEventOutboxEntry.swift` — modello, factory, `SyncEventOutboxLocalStore`
- `SyncEventOutboxState.swift` — enum status/kind, `SyncEventOutboxStateMachine`, sanitizer privacy
- `SyncEventOutboxEnqueueService.swift` — mapping producer → entry; cosa viene persistito vs validato
- `SyncEventRecording.swift` — `SyncEventRecording`, request/result/error, `SyncEventRecordValidator`, dry-run recorder
- `SupabaseSyncEventLiveRecorder.swift`, `SyncEventRPCTransport`, `SyncEventRPCRequestMapper.swift`
- Test esistenti: `SyncEventOutboxStateTests`, `SyncEventOutboxLocalStoreTests`, `SyncEventOutboxEnqueueServiceTests`, `SyncEventRecordingTests`, `SyncEventLiveRecorderTests`

### Android (solo riferimento funzionale; **no** port 1:1 Compose → SwiftUI)
- TASK-070 — outbox retry **head-of-line safe**, outcome privacy-safe, app-side query «retryable», senza cleanup distruttivo
- TASK-071 — allineamento/mismatch `record_sync_event` vs PayloadValidation; `changed_count` oltre soglia; payload massivi
- TASK-068 — bulk push compatto / stato **PARTIAL** per validazione live (non blueprint iOS)

### Supabase locale (`MerchandiseControlSupabase`)
- Migration `sync_events` + RPC `record_sync_event` (es. `20260424021936_task045_sync_events.sql`): `changed_count` **0…1000**; `entity_ids` **nullable**; chiavi consentite; array max per chiave; `pg_column_size` su `entity_ids` / `metadata`; vincoli metadata (chiavi vietate, dimensione)

---

## Gap analysis iOS vs Android vs Supabase

| Area | iOS oggi | Android (TASK-070/071) | Supabase locale | Gap / rischio |
|------|----------|------------------------|-----------------|---------------|
| Persistenza payload | Outbox salva **shape** stringhe (`entityIDsShape`, `metadataShape`), non JSON completo | Eventi compatti / liste controllate | RPC accetta `entity_ids` null; metadata object con budget | **Replay fedele vs compatto**: se l’outbox salva solo shape, **D59-01** vieta replay automatico count-only; servono **D59-08/D59-09** chiusi (payload sufficiente **o** fallback documentato per `domain`/`eventType`) prima della futura execution |
| Head-of-line | `fetchRetryable` filtra stati + `attemptCount < maxAttempts` + `nextRetryAt <= now` | Salta entry non retryable / esaurite senza bloccare la coda | — | Allineare semantica: **una run di drain** deve poter **tentare più entry** senza fermarsi al primo fallimento se il batch lo consente; predica SQL già esclude `dead` / blocked |
| Idempotenza | Dedupe enqueue su `client_event_id` | Simile | Unique per `(owner_user_id, client_event_id)` + return row se esiste | Drain deve trattare `.noOp` / `recorded` come successo locale **sent** coerente con TASK-058; incrocia **D59-17** se RPC precedente è ok ma save locale è fallito |
| Limiti numerici | Factory blocca `changedCount > 1000` locale (contract) | Attenzione batch grandi | DB `changed_count > 1000` → errore | Allineato; test futuri su **1000 boundary** |
| Cancellation | Recorder/Task-058 propaga `CancellationError` | — | — | Drain **non** deve convertire cancel in `dead` / blocked; deve **ripristinare** + **persistere** + **rilanciare** `CancellationError` (**nessun** result parziale / flag `cancelled`) |
| Logging | Sanitizer outbox + validator | Privacy-safe | — | Drain: **nessun** log di payload raw; solo kind/code/shape già esistenti |

---

## Decisioni tecniche

| ID | Decisione | Alternative scartate | Motivazione | Stato |
|----|-----------|----------------------|-------------|--------|
| D59-01 | **Replay da outbox condizionato al gate payload**: il drain può inviare solo se (a) l’entry contiene **dati sufficienti** per un replay **fedele** di `SyncEventRecordRequest`, oppure (b) esiste una **decisione documentata** (per `domain` / `eventType`) che ammette un **fallback compatto** coerente con **D59-08/D59-09**. Con sola **shape** o informazioni insufficienti: **non** inviare automaticamente eventi **count-only** o semanticamente ambigui. Il fallback compatto è ammesso **solo dopo** chiusura esplicita del gate (stesso perimetro di D59-08/D59-09). Se manca payload sufficiente **e** non esiste fallback semanticamente accettato documentato, la futura **execution** deve **fermarsi** oppure introdurre **persistenza payload minimale** prima dell’invio | Persistere sempre JSON completo in SwiftData nella stessa Slice G; oppure inviare sempre compatto senza catalogo decisioni | Evita che la convenienza del drain trasformi shape-only in `sync_events` poveri o fuorvianti; allinea D59-01 al gate **prima** dell’implementation | attiva |
| D59-02 | **source** opzionale in replay: preferire `nil` o valore costante **allowlist-safe** se serve tracciabilità minima | Copiare sempre `ios_*` stringhe dal producer | Riduce divergenza con validator su stringhe/token; mapper accetta `p_source` opzionale | attiva |
| D59-03 | **Head-of-line policy**: in una singola `drain`, elaborare fino a **N tentativi** (configurabile), **continuando** dopo errore retryable su una entry; **non** cleanup di entry esaurite; gli exhausted diventano `.dead` via state machine esistente e **escono** dalla query retryable | FIFO strict stop-on-first-failure | Parità intent con TASK-070 + batch parziale utile | attiva |
| D59-04 | **Fetch horizon**: parametrizzo `batchLimit` (tentativi max per call) e `fetchScanLimit` ≥ `batchLimit` (default es. `max(batchLimit * 4, 32)`) per evitare di «non vedere» entry pronte se molte entry davanti sono scheduled nel futuro | Fetch illimitato | Costi/prevedibilità SwiftData | attiva |
| D59-05 | **Stato `sending`**: transizione `toSending` prima della RPC; su successo `toSent`; su fallimento `transitionAfterFailure` dalla snapshot **sending**; su **cancel** ripristinare snapshot pre-invio **senza** incremento attempt | Lasciare `sending` persistito dopo crash | Minimizza falsi `dead`; crash recovery = follow-up candidato fuori Slice G | attiva |
| D59-06 | **Remote id opzionale** (**non bloccante Slice G**): se `RemoteSyncEventRow.id` è disponibile, si *può* aggiungere su `SyncEventOutboxEntry` un campo opzionale (es. `recordedRemoteEventID`) **solo se** il costo/beneficio lo giustifica — **non** deve forzare migration/schema SwiftData **né** allargare il modello se non strettamente necessario. Se l’aggiunta aumenta rischio (schema, migrazione, test extra non banali) → **rimandarla**. **MVP**: funziona con **`clientEventID` + stato locale + idempotenza remota** `(owner_user_id, client_event_id)` senza id server persistito | Rendere l’id remoto obbligatorio per chiudere Slice G | Diagnostica futura possibile; Slice G resta snella e reviewabile | attiva |
| D59-07 | **Invarianti difensivi**: skip in-process se `!isRetryable` anche se query ha ritornato la riga (solo guard) | Fidarsi solo della predicate | Robustness su dati legacy/corrupt | attiva |
| D59-08 | **Gate payload prima dell’execution** (complementare a D59-01): prima di implementare il drain, verificare se `SyncEventOutboxEntry` contiene dati sufficienti per ricostruire un `SyncEventRecordRequest` semanticamente utile; se salva solo shape e non payload, l’execution deve fermarsi o introdurre una persistenza payload minimale esplicita (**stessa barriera** che D59-01 impone sul replay) | Inviare sempre eventi count-only senza conferma semantica | Evita `sync_events` remoti poco utili per pull mirati cross-device; non trasformare una limitazione locale in comportamento silenzioso | attiva |
| D59-09 | **Payload fidelity tiered** (implementazione del perimetro di D59-01/D59-08): preferire **sempre** replay fedele quando l’entry ha payload sufficiente; fallback compatto (`entity_ids == null`, metadata sotto-budget, ecc.) **solo** per domini/eventi in cui è **accettato dal contratto funzionale** e **documentato**; vietato perdere barcode/id rilevanti senza decisione esplicita catalogata | Un solo formato universale per tutti gli eventi | Catalogo/prezzi possono avere bisogni diversi; il drain deve rispettare il significato dell’evento, non solo il contratto SQL | attiva |
| D59-10 | **Drain result non-UI ma UX-ready**: `SyncEventOutboxDrainResult` espone conteggi privacy-safe con nomenclatura fissa: `attempted`, `sent`, `retryScheduled`, `blocked`, `dead`, `skippedIneligible`, `remainingRetryable` (quest’ultimo **secondario** e **solo se economico**, vedi **D59-13**) — **nessun** payload raw. **Semantica (dettaglio anche sotto Design):** `attempted` = numero di entry per cui è stato **effettivamente** invocato `SyncEventRecording.record(_:)`; **non** include `skippedIneligible`; **non** include owner blank/no-op **prima** del recorder; **non** include cancel **prima** della chiamata al recorder. `sent` = esiti che consentono di considerare l’entry **marcabile come sincronizzata lato outbox**, inclusi **`recorded`** e **`noOp`/risposta idempotente remota** (es. riga già esistente); **non** implica necessariamente un **insert nuovo** lato DB. In caso di **cancellation** della `Task`/`drain`, il service **non** restituisce un result parziale con flag `cancelled`: ripristina snapshot, persiste, **rilancia** `CancellationError` (vedi design API) | Ritornare solo `Void`; oppure mescolare sinonimi tipo `succeeded`/`failedRetryable` | UX futura senza rifare il service; conteggi non ambigui | attiva |
| D59-11 | **Concorrenza / reentrancy per owner**: il lock (in-memory o actor) è **per `ownerUserID`**. Due drain simultanei sullo **stesso** owner devono essere **no-op** o **join controllato** (una sola elaborazione effettiva), **mai** doppio invio RPC per la stessa entry. Drain su **owner diversi** sono ammessi **solo se** `ModelContext`/store lo rendono **sicuro**; in caso di dubbio, **serializzare tutto** nella Slice G minima (un solo “lane” globale o documentato) | Affidarsi solo a `sending` persistito; permettere N drain paralleli senza policy | Evita doppio invio, race su SwiftData e violazione idempotenza percepita | attiva |
| D59-12 | **Crash recovery fuori scope ma visibile**: non implementare recovery automatica in Slice G; documentare però che entry rimaste `sending` richiedono una futura policy (`reset stale sending`) prima di BGTask/timer | Lasciare il rischio implicito | Necessario prima di automatismi futuri, ma non blocca drain manuale testabile | attiva |
| D59-13 | **Batch fairness + `remainingRetryable` cost-aware**: `skippedIneligible` resta **prioritario** per segnalare scarti nella run. **`remainingRetryable`** è utile per UX futura ma può richiedere query/count extra — va calcolato **solo** se lo store lo permette in modo **economico** (es. predicato già usato, count limitato, niente full scan). Altrimenti: **`nil`**, stima conservativa documentata o **omesso** nella prima execution è accettabile. **Vietato** introdurre scan pesanti dell’**intera** outbox solo per un contatore UX/debug. **Priorità conteggi:** `skippedIneligible`, poi `attempted`, `sent`, `retryScheduled`, `blocked`, `dead`; `remainingRetryable` è **secondario** | Contare sempre tutti i retryable globali per “bel numero” | Osservabilità senza impatto prestazionale o scope creep | attiva |
| D59-14 | **Owner isolation obbligatoria**: `ownerUserID` è **parametro obbligatorio** del drain. Valore **blank/non valido** → **errore locale** o **no-op** definito, **nessuna** rete. `fetchRetryable` (o equivalente store) deve **filtrare** rigorosamente per `ownerUserID`; **nessuna** entry **cross-owner** può essere selezionata o processata nella stessa run | Inferire owner globalmente; query senza predicato owner | Coerenza multi-device/Supabase, privacy e assenza di side effect tra tenant/sessioni | attiva |
| D59-15 | **UI/UX future constraint**: eventuale UI futura deve essere manuale, discreta e coerente con lo **stile iOS / schede impostazioni** dell’app (senza obbligare modifiche a `OptionsView` in Slice G); **nessuna** nuova UI in Slice G, ma il service deve restare componibile per una card/debug CTA futura in un call site **esplicito** | Progettare service legato alla UI o a toast/snackbar | UX successiva nativa e non invasiva; Slice G resta business/service | attiva |
| D59-16 | **SwiftData save policy / transaction boundary**: la futura execution definisce una policy **esplicita** di salvataggio attorno al ciclo: snapshot pre-invio → transizione a `sending` → `SyncEventRecording.record(_:)` → transizione **terminale** o **retry** → **save locale** **per entry** o **micro-batch** documentato e sicuro. **Non** ritardare tutti i save fino a fine run se esistono **successi parziali** già riflessi nello stato in-memory: evitare batch interi non persistuti. Su **errore di save** locale: **non** continuare la run in silenzio; propagare/surface coerente (stop controllato) | Un solo `save()` globale a fine drain | Riduce perdita stati e outbox incoerente dopo crash/cancel/save failure; affianca **D59-05** con granularità operativa | attiva |
| D59-17 | **Remote success + local save failure**: se la RPC (`record_sync_event` via recorder) ha **esito remoto positivo** ma la persistenza locale (`toSent` o save associato) **fallisce**, **non** considerare successo **completo** lato app (outbox può restare incoerente). Sfruttare idempotenza `(owner_user_id, client_event_id)`: **run successiva** può ritentare `record`; se Supabase risponde **noOp** / riga esistente / equivalenza **duplicate-idempotent**, il drain deve poter **marcare `sent` locale** e chiudere. **Test XCTest futuro obbligatorio** che simuli save failure post-RPC | Trattare come `sent` locale solo perché la rete ha risposto OK | Evita **doppio evento** reale non voluto e stati locali bloccati senza recovery; incrocia idempotenza TASK-058 | attiva |
| D59-18 | **MVP minimal boundary (Slice G)**: la futura execution implementa solo il **minimo necessario**: `SyncEventOutboxDrainService` + `SyncEventOutboxDrainResult` + XCTest; **nessuna** UI; **nessun** recovery `sending` stale; **nessun** background/worker; **nessuna** migration/schema estesa **né** persistenza payload bulk salvo **blocco esplicito** del gate (Path B → task separato); **nessun** cleanup outbox/sync_events remoto; **nessuna** ottimizzazione prematura | Unire drain + payload persistence + UI + recovery nello stesso task | TASK-059 resta piccolo, reviewabile e tracciabile; combatte lo scope creep | attiva |
| D59-19 | **Store capability gate**: **prima** della futura execution, leggere `SyncEventOutboxLocalStore` (e test esistenti) e verificare capacità per: **fetch** retryable **owner-scoped**; transizione **`sending`**; transizioni **sent** / retry / **dead** / **blocked**; **save** e percorsi di **rollback** coerenti con **D59-16**; **test** in-memory riutilizzabili. Se manca qualcosa → aggiungere **solo** helper **piccoli** e testabili; **proibito** refactor grande dello store in contorno a Slice G | Riscrivere lo store per “comodità” drain | Riduce rischio e tempo di review; allinea execution al reale stato del codice | attiva |
| D59-20 | **Payload persistence candidate**: la prossima micro-slice deve valutare persistenza **minimale** di `entityIDs` e `metadata` in `SyncEventOutboxEntry`, preferibilmente come JSON codificato privacy-safe e validato, **non** come log raw | Continuare con sole shape + fallback count-only implicito | Sblocca replay fedele e riduce ambiguità semantica del drain | candidata planning |
| D59-21 | **Budget e privacy prima dello storage**: prima di salvare payload, riusare `SyncEventRecordValidator` (o variante locale equivalente) per garantire: `changedCount` 0...1000, `entityIDs` sotto budget, `metadata` sotto budget, chiavi metadata vietate rimosse/bloccate, nessun token/email/path/barcode raw se vietati dal contratto | Salvare payload “as-is” e validare solo in drain | Evita persistenza locale non conforme e riduce rischio privacy/contract | candidata planning |
| D59-22 | **Migration risk gate**: se la persistenza payload richiede modifica SwiftData/schema, pianificare migration **minima** e testata; se rischio migration alto, fermarsi e proporre alternativa documentale. **Nessuna** modifica schema in questa fase planning | Procedere subito con migration ampia | Contiene il rischio e mantiene la micro-slice reviewabile | candidata planning |

---

## Design futuro del drain service (nome provvisorio)
**`SyncEventOutboxDrainService`** (tipo `@MainActor` se usa `ModelContext`, coerente con enqueue/store; vedi anche isolamento sotto).

**Dipendenze iniettate (no singleton globale):**
- `ModelContext` + uso di `SyncEventOutboxLocalStore`
- `any SyncEventRecording` — in produzione `SupabaseSyncEventLiveRecorder`; in test `SyncEventRecordDryRunRecorder` o actor fake
- `clock: () -> Date`
- Parametri: `retryDelay: TimeInterval` (default allineato a state machine, es. 60s come `transitionAfterFailure`)
- Parametri: `batchLimit`, `fetchScanLimit` (opzionali) — **default conservativi (planning):** `batchLimit` **10**; `fetchScanLimit` **`max(batchLimit * 4, 32)`** (allinea **D59-04**); **hard cap** documentato es. **50** su tentativi massimi per run (o su `batchLimit` effettivo) per drain **manuali** non eccessivamente lunghi — **valori finali** da confermare in execution dopo lettura store/performance

**API suggerita (futura):**
- `func drain(ownerUserID: String, batchLimit: Int, fetchScanLimit: Int?) async throws -> SyncEventOutboxDrainResult`
- `SyncEventOutboxDrainResult`: conteggi privacy-safe (`attempted`, `sent`, `retryScheduled`, `blocked`, `dead`, `skippedIneligible`) e **`remainingRetryable` solo se a costo accettabile** (**D59-13**): può essere opzionale (`nil`/assente nella prima execution), stimato o calcolato via query **non** full-scan; **nessuna** stringa payload raw, **nessun** flag `cancelled` nel result
- **Semantica conteggi (contratto, allinea D59-10):**
  - **`attempted`**: numero di entry per cui è stata **effettivamente** invocata `SyncEventRecording.record(_:)`; **non** include incrementi solo per `skippedIneligible`; **non** include il percorso owner blank/no-op **prima** di qualsiasi chiamata al recorder; **non** include l’annullamento **prima** che `record` parta per quella entry
  - **`sent`**: numero di entry portate a stato coerente “sincronizzato lato outbox”, includendo sia **`recorded`** (nuova riga remota) sia esiti **`noOp`/idempotenza** che permettono la stessa chiusura locale (**non** significa necessariamente INSERT nuovo lato `sync_events`, ma **sì** “sicuro marcare come inviato” in outbox)
  - **`remainingRetryable`**: **solo** se calcolabile in modo **economico** (**D59-13**); altrimenti `nil`/omesso/stima documentata — **non** obbligare full-scan per questo campo
- **Cancellation**: se la chiamata è annullata, il service **ripristina** la snapshot **pre-`sending`**, **salva** lo stato ripristinato sullo store, **rilancia** `CancellationError` — **non** restituisce un `SyncEventOutboxDrainResult` parziale

**Nessuna** logica in SwiftUI View; orchestrazione solo da call site esplicito (test o futuro VM non parte di Slice G).

**ModelContext / actor isolation (futura execution, con D59-11):**
- Se il service usa `ModelContext`, deve restare sullo **stesso actor isolation previsto dal progetto** — in questa codebase, probabile coerenza con **`@MainActor`** come enqueue/store
- **Non** passare `ModelContext` dentro `Task` o concurrency **non isolata** al actor del modello
- Il lock di **reentrancy** serve anche a evitare **uso parallelo insicuro** dello stesso context sulla stessa istanza
- Parallelismo **multi-owner** resta **fuori scope** della Slice G minima salvo **dimostrazione esplicita** che store/context lo consentono senza race; in dubbio → **serializzazione globale** già indicata per **D59-11**

**Owner isolation + reentrancy (futura execution, coerente con D59-11/D59-14):**
- `ownerUserID` **obbligatorio**; blank/non valido → **errore locale** o **no-op** documentato, **zero** chiamate di rete/recorder finché non risolto
- Ogni selezione candidati (`fetchRetryable` o equivalente) **filtra** per `ownerUserID`; **vietato** elaborare entry di altri owner nella stessa run
- Lock / serializzazione **per `ownerUserID`**: due drain concorrenti sullo stesso owner → seconda chiamata **no-op** o **join** su un’unica run effettiva, **mai** doppio invio della stessa entry
- Drain **paralleli su owner diversi** solo se architettura `ModelContext`/store lo rende **sicuro**; altrimenti, nella Slice G minima, **serializzare globalmente** (un lane) e documentare il vincolo

---

## State machine prevista (riuso)
- **Pre-invio**: solo entry `.pending` o `.failedRetryable` con `isRetryable == true`
- **Invio**: `toSending(snapshot, now)`
- **Successo** (`recorded` / `noOp`): `toSent(sendingSnapshot, now)` + save secondo **D59-16**; opzionale persist `recordedRemoteEventID` (**D59-06**). Se persistenza locale fallisce **dopo** RPC OK → **D59-17** (non trattare come chiusura completa senza recovery/idempotenza)
- **Fallimento** `SyncEventRecordError`: `transitionAfterFailure(sendingSnapshot, failure: ..., now:, retryDelay:)` — mapping kind già definito in TASK-056/058
- **Cancel**: ripristino snapshot **pre** `toSending`, **persistenza** dello stato ripristinato, **rilancio** `CancellationError` (allineato all’API: nessun result parziale con flag cancellation)
- **Terminali**: nessun passaggio forzato a `sent` su errori non retryable; **no** transizioni inventate fuori da `SyncEventOutboxStateMachine`

---

## Error mapping previsto
Riutilizzare la tassonomia esistente (`SyncEventRecordError` → `plannedOutboxStatus` / `plannedOutboxErrorKind` dove applicabile). Il drain **non** duplica classificazione HTTP/PGRST: delega al recorder+transport.

**Cancel** ≠ `network` / `unknown` terminal: **propagare** (`CancellationError`).

---

## Mapping recorder/outbox/result *(planning-only)*

Tabella di chiarimento **planning** (non introduce una nuova state machine). La fonte di verità resta `SyncEventOutboxStateMachine`.

| Esito recorder / precondizione | Stato outbox previsto | Effetto su result |
|---|---|---|
| `recorded` | `sent` | `sent += 1` |
| `noOp` / duplicate idempotent / row already exists | `sent` | `sent += 1` |
| Errore retryable (`network` / timeout / 5xx / 429) | `failedRetryable` oppure `dead` se max attempts raggiunti | `retryScheduled += 1` **oppure** `dead += 1` |
| Errore non-retryable (`contract` / `schema` / payload validation) | `blocked`/`dead` secondo state machine esistente | `blocked += 1` **o** `dead += 1` |
| Auth/config locale non valida **prima** della rete | Nessuna transizione da call recorder (no network) | Nessun incremento `attempted` |
| Cancellation | restore snapshot + save + rethrow `CancellationError` | Nessun result parziale ritornato |

---

## Policy retry / head-of-line
1. Leggere candidati ordinati come oggi (`nextRetryAt`, `createdAt`, `id`) con limite `fetchScanLimit`.
2. Per ogni entry nell’ordine, se già raggiunto `batchLimit` **tentativi** → stop run.
3. Se entry non `isRetryable` → `skippedIneligible` + continua (**D59-07**).
4. Se errore **retryable** su entry A → aggiorna stato A e **continua** verso B (non bloccare tutta la run salvo cancel).
5. Entry **dead** / **blocked** non compaiono in `fetchRetryable` (predicate **scoped** a `ownerUserID`) — non richiedono cleanup.
6. **`maxAttempts`**: Slice G non introduce un nuovo `maxAttempts` se la policy esiste già in state machine/store; deve **riusare** la policy esistente.
7. Se `maxAttempts` non è centralizzato, la futura execution può introdurre solo una **costante locale minima** o un **helper piccolo** (no refactor globale).
8. Entry con attempts esauriti diventano `dead` **solo** tramite `SyncEventOutboxStateMachine` esistente.

---

## Privacy / logging
- Nessun `print` di `entity_ids` / metadata / JWT / URL con query
- Messaggi errore solo tramite sanitizer esistente (`SyncEventOutboxPrivacySanitizer` / `SyncEventRecordFailure`)
- Summary drain: **conteggi** + eventuali `kind` già tipizzati, no raw server body

---

## Payload budget e `changedCount` alto

Vincoli tecnici (allineamento factory iOS, contract locale TASK-055 e RPC Supabase documentato in repo):

- `changedCount ∈ [0, 1000]` (**1000 incluso** come limite superiore contract)
- `entity_ids` **null** / payload **compatto** ammessi **solo** dove **D59-08/D59-09** consentono il fallback per il `domain`/`eventType`; non sono una scorciatoia universale
- Budget dimensionali tipici: `metadata` ~**4KB**; `entity_ids` ~**16KB** (es. vincoli `pg_column_size` lato DB)
- **Max 250 elementi** per array chiave ammessa (vincolo SQL sul payload)
- Per **bulk** senza liste massicce: il **numero** reale può restare in `changed_count`; la semantica dell’evento resta soggetta al gate **D59-01/D59-08/D59-09**

---

## Vincoli UX/UI futuri *(planning-only, nessuna UI ora)*
Slice G non aggiunge UI, però il design deve evitare di rendere difficile una futura UX manuale e nativa Apple. **Slice G non anticipa layout, stringhe localizzate o schermate:** consegna solo un **`SyncEventOutboxDrainResult`** chiaro, sicuro e privacy-safe su cui una **futura** UI manuale potrà innestarsi — **senza** introdurre ora idee UI aggiuntive oltre a questo vincolo. **Per TASK-059 la scelta UX migliore è non introdurre UI, ma produrre un result chiaro per una futura UI manuale.**

Principi per una futura integrazione UI/UX, **fuori scope da questo task**:
- CTA manuale opzionale e discreta, probabilmente in area avanzata/debug già esistente, non nella home principale.
- Nessun auto-drain invisibile all’utente finché non esiste recovery per `sending` stale e diagnostica sufficiente.
- Stati leggibili e non tecnici: “sincronizzati”, “in attesa”, “da riprovare”, “bloccati”, evitando codici RPC grezzi.
- Niente payload raw, barcode massivi o UUID lunghi in UI.
- Coerenza con stile iOS esistente: `Form`/`Section`, `ContentUnavailableView` per vuoto (se disponibile sul **deployment target** dell’app), `ProgressView` durante operazione manuale, `alert`/`confirmationDialog` solo per errori o azioni destructive.
- **Prima** di una futura UI: verificare il **deployment target** iOS; se `ContentUnavailableView` non è disponibile, usare un fallback **SwiftUI** minimale (`VStack` + icona + titolo + descrizione + CTA) — **nessuna** implementazione UI in questo task.
- Se in futuro una UI mostra il drain, deve consumare `SyncEventOutboxDrainResult` (conteggi standard come da **D59-10**) e non leggere direttamente SwiftData/outbox nella View.
- Qualsiasi polish UI/UX legato al drain è rimandato a una slice futura dedicata; TASK-059 produce solo service/result testabile.

---

## Execution path futuri possibili *(planning-only)*

Scelta **prima** della futura execution; riduce scope creep e impone confini chiari.

- **Path A — Payload sufficiente**: se `SyncEventOutboxEntry` contiene dati sufficienti per ricostruire `SyncEventRecordRequest`, **oppure** esiste un **fallback compatto** già approvato per `domain`/`eventType` (**D59-01 / D59-08 / D59-09** chiusi), la futura execution può implementare un **`SyncEventOutboxDrainService` minimo** (**D59-18**) dopo **D59-19** (store gate).
- **Path B — Payload insufficiente**: se l’outbox ha **solo shape** e **non** payload semanticamente sufficiente, la futura execution **non** deve implementare un drain **count-only ambiguo**; deve **fermarsi** (planning/fix) **oppure** spostare **persistenza payload minimale** in un **task/slice separato**. **Nessuna** RPC di drain deve essere introdotta finché **D59-01 / D59-08 / D59-09** non sono **chiusi** per i casi d’uso previsti.
- **Path C — Store/API insufficienti**: se `SyncEventOutboxLocalStore` **non** espone query/transizioni/save adatti al ciclo drain (**D59-19**), la futura execution si limita a **piccoli helper** store **testabili**; **proibito** refactor grande dello store o API nuove invasive.

---

## Return to Planning — Payload Fidelity Strategy

- TASK-059 torna a **PLANNING** dopo review con verdict **APPROVED_STOPPED_BY_GATE / RETURN_TO_PLANNING**.
- Il drain resta bloccato finché l’outbox non può ricostruire un `SyncEventRecordRequest` semanticamente utile.
- Direzione preferita di planning: **persistenza payload minimale** in outbox.
- Nessun drain RPC deve essere implementato finché questa strategia non è pianificata e reviewata.

---

## Strategie valutate

### A) Fallback compatto documentato
- **Pro**: meno invasivo.
- **Contro**: rischio eventi poveri, pull mirati meno affidabili, semantica diversa dall’enqueue.

### B) Persistenza payload minimale nell’outbox
- **Pro**: replay fedele, `sync_events` più utili, test più chiari, meno ambiguità cross-device.
- **Contro**: possibile modifica modello SwiftData / migrazione / validazione budget.

### C) Lasciare drain bloccato
- **Pro**: zero rischio immediato.
- **Contro**: iOS non drena outbox, Slice G non avanza.

**Decisione planning consigliata**: **B** come candidata principale, **A** solo fallback limitato e documentato per eventi specifici, **C** solo se **B** risulta troppo rischiosa.

---

## Micro-slice candidata successiva

**Nome provvisorio**: `TASK-059 Payload Fidelity Planning / Slice G1`

**Scopo**: preparare la possibilità di replay fedele degli eventi outbox senza ancora drenare.

**Possibile futura execution (NON ora):**
- estendere `SyncEventOutboxEntry` con payload JSON minimale;
- aggiornare factory/enqueue per salvare payload validato;
- mantenere `entityIDsShape` / `metadataShape` per logging privacy-safe;
- aggiungere test payload persistence;
- nessuna RPC drain;
- nessuna UI;
- nessun Supabase live.

---

## Anti-scope — planning pass payload fidelity

- No Swift.
- No model/schema change.
- No migration.
- No drain service.
- No `SyncEventOutboxDrainServiceTests`.
- No RPC live.
- No Supabase live.
- No SQL.
- No UI.
- No `Localizable`.
- No `OptionsView`.
- No Android.
- No TASK-060.

---

## Gate Supabase locale — evidenze da compilare in futura execution *(planning-only)*

Checklist preparatoria da compilare in futura execution/review documentale; nessuna verifica live in TASK-059.

- [ ] File migration locale letto: percorso esatto `supabase/migrations/...sync_events...sql`
- [ ] RPC `record_sync_event` verificata localmente nel file SQL
- [ ] `changed_count` min/max verificato
- [ ] `entity_ids` nullable verificato
- [ ] budget `entity_ids` verificato
- [ ] budget `metadata` verificato
- [ ] chiavi metadata vietate/verificate
- [ ] comportamento idempotente `(owner_user_id, client_event_id)` verificato
- [ ] shape ritorno RPC object/row verificata
- [ ] nessuna assunzione sul live remoto dichiarata

---

## Piano file iOS da toccare in futura execution *(non ora)*
- **Nuovo**: `SyncEventOutboxDrainService.swift` (+ eventuale `SyncEventOutboxDrainResult.swift` se si preferisce file separato)
- **Estensione modello** (**solo se** costo/beneficio lo giustifica, **D59-06**): `SyncEventOutboxEntry.swift` — `recordedRemoteEventID` opzionale; **non** obbligatoria per MVP; **no** migration SwiftData **forzata** per Slice G
- **Opzionale**: piccolo builder `SyncEventRecordRequest` da entry (stesso file o file dedicato) — **no** logica UI
- **Test nuovo**: `SyncEventOutboxDrainServiceTests.swift` con `ModelContainer` in-memory (stesso schema di altri test outbox) e recorder fake
- **No** modifica obbligatoria a `OptionsView` / `Localizable` / recorder transport in Slice G minimale
- Progetto Xcode: cartella sincronizzata → nuovo file Swift sotto `iOSMerchandiseControl/` senza edit manuale `pbxproj` se la config attuale resta synchronized

---

## Piano test XCTest (futuro; non eseguito in planning)
- **T59-01** — Successo singolo: pending → sent, remote id opzionale popolato se fixture
- **T59-02** — Batch parziale: prima entry retryable fail, seconda success
- **T59-03** — HOL / skip: entry `dead` o non in query non blocca (solo entry successive processate)
- **T59-04** — Exhausted attempts: dopo max retry → `dead`, run successiva non seleziona quella entry
- **T59-05** — Non-retryable (`auth`/`schema`/`contract`) → terminal blocked mappato
- **T59-06** — Idempotenza: seconda drain run non riprocessa `sent`
- **T59-07** — Boundary **accettato**: `changedCount == 1000` con payload valido nel contract (compatto solo se permesso da gate **D59-08/D59-09**)
- **T59-08** — Boundary **rifiutato**: `changedCount == 1001` (o oltre) bloccato a **validazione locale/contract** prima della rete
- **T59-09** — Cancel: `CancellationError` dal recorder/Task → snapshot **pre-sending** ripristinata e **persistita**, **nessun** `dead` spurio; **`drain` rilancia** `CancellationError` (**nessun** `SyncEventOutboxDrainResult` parziale)
- **T59-10** — Regressione: suite TASK-055/056/057/058 invariata (grepping anti-scope su Slice G)

**Fake recorder**: `SyncEventRecordDryRunRecorder` o actor che registra ordine chiamate per verificare HOL.

- **T59-11** — Payload / decisione: fallback compatto **non** usato senza catalogo **D59-08/D59-09** chiuso per `domain`/`eventType` (o senza persistenza minimale); niente invio count-only/shape-only “automatico”
- **T59-12** — Owner blank: `ownerUserID` vuoto/non valido → **nessuna** rete, **nessuna** chiamata al recorder fake che simuli RPC
- **T59-13** — `fetchRetryable` (o store equivalente) **filtra** `ownerUserID`; fixture misti A/B → solo A elaborato quando si drena A
- **T59-14** — Reentrancy: due drain simultanei sullo **stesso** owner **non** duplicano invii né **corrompono** lo stato (cfr. **D59-11**)
- **T59-15** — Owner isolation end-to-end: drenare A non tocca entry di B
- **T59-16** — Result contract: `SyncEventOutboxDrainResult` contiene **solo** i conteggi **D59-10** (`attempted`, `sent`, `retryScheduled`, …) e **nessun** campo payload raw server/entry
- **T59-17** — **D59-17**: RPC/recorder simula **successo remoto** + **fallimento save** locale su `toSent` → **non** “successo locale completo”; run successiva con idempotenza (`noOp`/riga esistente) consente **marcare sent** senza duplicare l’evento reale
- **T59-18** — **`attempted`**: conteggio = sole chiamate **effettive** a `SyncEventRecording.record(_:)`, senza `skippedIneligible`, senza path owner blank prima del recorder
- **T59-19** — **`sent`**: include sia esito **`recorded`** sia **`noOp`/idempotent** idoneo a chiusura locale
- **T59-20** — **D59-16**: fallimento **save** lungo percorso retryable → **non** nascosto né ignorato silenziosamente (stop/errore esplicito; niente proseguimento “come OK”)
- **T59-21** — **`batchLimit`** e **hard cap** (es. 50) **rispettati** nella configurazione effettiva del drain
- **T59-22** — **ModelContext** / actor: doppio drain stesso owner **non** usa lo stesso context in **parallelo** non sicuro (lock/join; allinea design isolation)

---

## Acceptance criteria (contratto execution futura)
- [ ] Sezione **Execution path** **A/B/C** compresa e coerente con gate payload e store; se payload insufficiente, **nessun** drain ambiguo
- [ ] **D59-06**: `recordedRemoteEventID` **opzionale** e **non** bloccante; **nessuna** migration/schema SwiftData **indispensabile** solo per Slice G
- [ ] **D59-13**: `remainingRetryable` **senza** scan pesante sull’intera outbox; `nil`/stima/omissione accettabili se economia non soddisfatta
- [ ] **D59-18** (**MVP boundary**) accettato: solo drain + result + test
- [ ] **D59-19** (**Store capability gate**): lettura store e test **prima** di execution; gap coperti solo con helper **minimi**
- [ ] **D59-01**, **D59-08**, **D59-09** coerenti: **nessun** count-only / shape-only ambiguo inviato senza gate chiuso o persistenza minimale esplicita
- [ ] **Owner isolation**: `ownerUserID` obbligatorio; valori non validi → errore locale/no-op, **zero** rete; query candidati sempre filtrata per owner; **nessuna** entry cross-owner nella stessa run
- [ ] **Reentrancy protetta** per owner (lock/join/no-op): **mai** doppio invio sulla stessa entry per race doppio-drain; policy owner-divergenti allineata al vincolo store (serialize se non sicuro)
- [ ] **Cancellation**: ripristino snapshot pre-invio + persistenza + **`CancellationError` rilanciato**; **nessun** `SyncEventOutboxDrainResult` “parziale” / flag `cancelled` su quel percorso
- [ ] **`SyncEventOutboxDrainResult`** usa **solo** i nomi standard **`attempted`**, **`sent`**, **`retryScheduled`**, **`blocked`**, **`dead`**, **`skippedIneligible`**, **`remainingRetryable`** (niente sinonimi tipo `succeeded` / `failedRetryable` nel contratto result); **definizioni `attempted` / `sent` senza ambiguità** come da **D59-10** e sezione Design; **`remainingRetryable`** conforme a **D59-13** (opzionale/`nil`/stima, **no** scan pesante obbligatorio)
- [ ] Result **UX-ready** (conteggi leggibili) ma **nessuna** UI Swift in Slice G; **nessun** `Localizable`; **nessuna** modifica a `OptionsView` per questo task
- [ ] **Nessun** auto-drain all’avvio, timer, BGTask o worker: drain solo su call site **manuale** / test
- [ ] Esiste servizio drain **manuale**, DI pulita, **no** Realtime; **no** orchestra in View
- [ ] Usa solo `SyncEventRecording` per rete/logica RPC (test con fake)
- [ ] Head-of-line safe: **non** si blocca dietro entry esaurite/non eleggibili nella stessa run configurabile
- [ ] Mapping errori coerente con state machine; cancel **non** lascia stato terminale spurio
- [ ] Privacy: **no** log payload raw; summary safe; result **senza** payload raw
- [ ] Vincoli `changedCount` / payload budget allineati a Supabase locale **documentati** in task (sezione **Payload budget**)
- [ ] **SwiftData save policy** (**D59-16**) documentata e applicata: granularità save (per entry / micro-batch), **nessun** accumulo silenzioso di successi parziali non persistuti, **nessuna** continuazione dopo save failure senza gestione esplicita
- [ ] **Remote success + local save failure** (**D59-17**): path con idempotenza / `noOp` per recuperare marcatura `sent` locale; test **T59-17** presente
- [ ] **Default / cap batch** documentati (**Design**: `batchLimit` default 10, `fetchScanLimit` = `max(batchLimit*4, 32)`, hard cap es. 50 — conferma in execution)
- [ ] **ModelContext / actor isolation** documentata e rispettata: service sullo actor previsto (**probabile** `@MainActor`), **no** context in task non isolati, **no** parallelismo unsafe sullo stesso context (**D59-11** + design)
- [ ] **Nessuna UI/UX reale** introdotta in Slice G: solo API result/service; niente layout, stringhe prodotte o schermate nuove
- [ ] XCTest futuri coprono successo, batch parziale, retryable, non-retryable, cancel/rethrow, boundary **1000/1001**, idempotenza, owner/reentrancy/result contract, gate fallback, **save failure**, **counter semantics**, **batch cap**, **ModelContext isolation**, regressione slice precedenti (**lista T59-xx** fino **T59-22**)
- [ ] **Out-of-scope verificato per questo task**: **nessuna** implementazione Swift / `project.pbxproj`; build/XCTest ammessi solo come check di regressione/tracking nella execution controllata; **nessun** Supabase live / RPC live / SQL / migration / `db push` / Android; **nessuna** creazione **TASK-060**

---

## Checklist — PLANNING REVIEW *(pre-execution storico)*
- [ ] Gate schema Supabase locale riletto su clone (`record_sync_event`, limiti `changed_count` / `entity_ids` / `metadata`)
- [ ] **D59-01** letta insieme a **D59-08/D59-09**: triangolo decisionale unico su replay vs fallback vs stop/persistenza minimale
- [ ] **Nessun** invio count-only ambiguo senza decisione documentata per `domain`/`eventType` o estensione modello
- [ ] **Path A/B/C** rivisti: se payload insufficiente → **Path B**, niente drain ambiguo o RPC finché il gate non è chiuso
- [ ] **D59-06** confermata **opzionale** e **non bloccante**; niente schema SwiftData solo per “avere” id remoto
- [ ] **`remainingRetryable`** non introduce costo eccessivo (no full scan); ammessi `nil`/stima/omissione (**D59-13**)
- [ ] **MVP boundary** **D59-18** accettato nel team/reviewer
- [ ] **Store capability gate** **D59-19** verificato su codice reale (`SyncEventOutboxLocalStore` + test)
- [ ] **Definition of Ready — future execution** completata
- [ ] **Gate Supabase locale** preparato come checklist, senza esecuzione live
- [ ] **Mapping recorder/outbox/result** coerente con state machine esistente
- [ ] **`maxAttempts`** non duplicato inutilmente
- [ ] Marker ambigui rimossi (`blocked*` → `blocked`)
- [ ] Nessuna nuova UI/UX introdotta oltre al vincolo future-ready
- [ ] **D59-16** / **D59-17**: policy save SwiftData e split remote-OK/local-KO comprese nei test obbligatori
- [ ] **D59-10** + Design: semantica **`attempted` / `sent`** verificabile in review
- [ ] **D59-11/D59-14** + design drain: lock per owner, fetch scoped, policy parallelo multi-owner
- [ ] **D59-15** + sezione UX futura: deployment target / fallback se `ContentUnavailableView` assente; **nessuna** UI in Slice G
- [ ] Confine Slice G vs orchestrazione futura (call site manuale) chiaro; **nessun** auto-drain
- [ ] Anti-scope Slice G verificato (nessuna implementazione Swift/drain; build/XCTest solo check di regressione/tracking; nessun Supabase live/SQL/Android)
- [ ] Stato documento pre-execution: **READY FOR PLANNING REVIEW**, **non** READY FOR EXECUTION — handoff storico poi superato da user override esplicito e execution controllata Path B

---

## Planning (Claude)
### Analisi
Slice F ha chiuso il recorder isolato; Slice G collega l’outbox TASK-057 al recorder tramite un processore **locale e discreto**. Il rischio principale non è la RPC in sé ma **cosa è persistito** nell’outbox (shape vs JSON) e l’**ordine/elaborazione parziale** senza cleanup. Android e Supabase forniscono vincoli numerici e pattern HOL; iOS deve restare SwiftData + async idiomatici.

### Approccio proposto
Allineamento a **Execution path** **A/B/C**: solo **Path A** + **D59-19** soddisfatto → implementare MVP **D59-18** (drain + result + test). **Path B** → **no** RPC drain senza gate chiuso o task separato su payload. **Path C** → solo **helper** store minimi. Dopo review planning: gate **D59-01/D59-08/D59-09** per `domain`/`eventType`; **D59-19** lettura store; parametri batch (**D59-04**) con default/cap del Design; **D59-16** / **D59-17**; **`recordedRemoteEventID`** solo se **D59-06** a basso rischio. Replay **non** presume compatto universale.

### Rischi identificati
- **Scope creep Slice G**: accorpare drain + persistenza payload bulk + UI + recovery `sending` nello stesso task → mitigato da **D59-18** e path **A/B/C**
- **Counter costoso**: `remainingRetryable` ottenuto con **scan** completo outbox → mitigato da **D59-13** (nil/stima/omit, no full scan)
- **Schema SwiftData non necessario**: trattare **D59-06** come obbligo di migration → mitigato da testo **D59-06** + criteri acceptance
- **Remote recorded, local not saved**: RPC/recorder ok ma `toSent`/save locale fallisce → stato outbox incoerente; mitigato da **D59-17** + test **T59-17**
- **Batch troppo grande**: drain manuale o run lunga che impatta responsività o timeout percepiti; mitigato da **default conservativi** + **hard cap** documentato (conferma in execution)
- **ModelContext usato da task concorrenti**: race/crash SwiftData se il context esce dall’actor previsto; mitigato da **@MainActor** (o policy progetto) + lock reentrancy **D59-11** + test **T59-22**
- **Semantica evento**: replay con `entity_ids` null può differire dall’enqueue ricco — accettabile solo se prodotto/audit `sync_events` accetta eventi **count-only** per quel caso; altrimenti serve task successivo su persistenza JSON (**follow-up**, non TASK-060)
- **Crash durante `sending`**: recovery non in Slice G (**follow-up**)
- **Drift schema Supabase**: sempre verificare migration locale prima dell’execution
- **Evento count-only troppo povero**: se `sync_events` viene usato da altri device per pull mirati, perdere `entity_ids`/metadata può degradare la sync; D59-08/D59-09 devono essere chiusi prima dell’execution
- **Doppio drain manuale**: senza guard reentrancy un tap doppio/futuro call site concorrente può generare race; D59-11 deve essere coperto da test o guard esplicita
- **Owner sbagliato**: il drain deve essere owner-scoped; vietato processare outbox globalmente

### Handoff pre-execution storico → *(review documentale planning; **non** dichiarava execution approvata da questo documento)*

---

## Definition of Ready — future execution

TASK-059 può passare a execution futura **solo se**:

- **D59-01 / D59-08 / D59-09** sono chiusi per ogni `domain`/`eventType` che il drain processerà.
- **D59-19 Store capability gate** è verificato sul codice reale.
- Supabase locale è stato letto e i vincoli RPC sono documentati nel task.
- È scelto **un solo path** tra **A/B/C**.
- Se **Path B**, **non** si implementa drain RPC: si pianifica persistenza payload minimale separata.
- Se **Path C**, si implementano solo helper store piccoli e testabili.
- **Non** sono richieste UI, `Localizable`, `BGTask`, Realtime, worker, SQL, Supabase live o Android.

---

## Handoff finale — **READY FOR PLANNING REVIEW** *(NON READY FOR EXECUTION)*
- **Stato task**: **ACTIVE / PLANNING**
- **Responsabile attuale**: **Claude / Planner**
- **Prossima fase**: planning review documentale sulla payload fidelity / outbox replay strategy.
- **Prossimo agente**: **Claude / Reviewer** o **utente** (review planning).
- **Azione consigliata**: validare sezioni **Return to Planning**, **Strategie valutate**, decisioni **D59-20/21/22**, e micro-slice candidata **Slice G1**.
- **Esplicitamente escluso**: avvio execution Swift, drain RPC, migration/schema, UI/Localizable/OptionsView, SQL/Supabase live/Android/TASK-060.

**Non** impostare **READY FOR EXECUTION** automaticamente da questo task.

---

## Execution (Codex)
### Avvio execution controllata — 2026-05-07

**User override operativo:** il task file dichiarava esplicitamente `READY FOR PLANNING REVIEW` e `NON READY FOR EXECUTION`. L'utente ha autorizzato l'avvio di una execution controllata con gate bloccanti. Impatto: Codex procede solo con lettura repo/Supabase e scelta path; se il gate payload non passa, nessun Swift/drain RPC viene implementato.

**Obiettivo compreso:** verificare se esistono le condizioni minime per un drain outbox manuale, owner-scoped e HOL-safe via `SyncEventRecording`; se il payload outbox non consente ricostruzione semanticamente utile di `SyncEventRecordRequest`, fermare l'execution tecnica e preparare handoff documentale.

**File controllati finora:**
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-059-supabase-sync-events-outbox-drain-ios.md`
- repository remoto GitHub `origin/main` / `FETCH_HEAD` verificato: `dc553261a3d553d69e2b015521ab74c5590d18dd` allineato a `HEAD`
- iOS:
  - `iOSMerchandiseControl/SyncEventOutboxEntry.swift`
  - `iOSMerchandiseControl/SyncEventOutboxState.swift`
  - `iOSMerchandiseControl/SyncEventOutboxEnqueueService.swift`
  - `iOSMerchandiseControl/SyncEventRecording.swift`
  - `iOSMerchandiseControl/SupabaseSyncEventLiveRecorder.swift`
  - `iOSMerchandiseControl/SyncEventRPCRequestMapper.swift`
  - `iOSMerchandiseControl/SupabaseSyncEventRPCTransport.swift`
  - `iOSMerchandiseControl/SupabaseSyncEventDTOs.swift`
  - `iOSMerchandiseControlTests/SyncEventOutboxStateTests.swift`
  - `iOSMerchandiseControlTests/SyncEventOutboxLocalStoreTests.swift`
  - `iOSMerchandiseControlTests/SyncEventOutboxEnqueueServiceTests.swift`
  - `iOSMerchandiseControlTests/SyncEventRecordingTests.swift`
  - `iOSMerchandiseControlTests/SyncEventLiveRecorderTests.swift`
- Supabase locale:
  - `/Users/minxiang/Desktop/MerchandiseControlSupabase/supabase/migrations/20260424021936_task045_sync_events.sql`
- Android solo riferimento funzionale:
  - `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/docs/TASKS/TASK-070-outbox-retry-head-of-line-logging-strutturato.md`
  - `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/main/java/com/example/merchandisecontrolsplitview/data/SyncEventModels.kt`
  - `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/main/java/com/example/merchandisecontrolsplitview/data/InventoryRepository.kt`

**Piano minimo prima di Swift:**
1. Completare E0/E1/E2 con evidenze statiche.
2. Scegliere un solo path A/B/C prima di toccare Swift.
3. Se Path B: non implementare `SyncEventOutboxDrainService`, documentare blocco payload e chiedere review documentale.

### Gate Supabase locale — evidenze (E0)
- [x] File migration locale letto: `/Users/minxiang/Desktop/MerchandiseControlSupabase/supabase/migrations/20260424021936_task045_sync_events.sql`
- [x] RPC `record_sync_event` verificata localmente nel file SQL: funzione `public.record_sync_event(...) returns public.sync_events`
- [x] `changed_count` min/max verificato: funzione rifiuta `p_changed_count < 0 or p_changed_count > 1000` con errcode `22023`; tabella ha constraint non-negativo
- [x] `entity_ids` nullable verificato: colonna `entity_ids jsonb null`, parametro `p_entity_ids jsonb default null`, constraint tabella `entity_ids is null or jsonb_typeof(entity_ids) = 'object'`
- [x] budget `entity_ids` verificato: funzione rifiuta `pg_column_size(p_entity_ids) > 16384`; chiavi consentite solo `supplier_ids`, `category_ids`, `product_ids`, `price_ids`; ogni valore deve essere array; max 250 id per chiave; valori devono essere UUID
- [x] budget `metadata` verificato: `metadata jsonb not null default '{}'::jsonb`; funzione coalesce `{}` e rifiuta non-object o `pg_column_size(v_metadata) > 4096`
- [x] chiavi metadata vietate/verificate: `barcode`, `email`, `excel`, `path`, `price`, `product_name`, `supplier_name`, `category_name`, `token`
- [x] comportamento idempotente `(owner_user_id, client_event_id)` verificato: unique index `sync_events_owner_client_event_id_unique` dove `client_event_id is not null`; funzione seleziona riga esistente per `owner_user_id = auth.uid()` + `client_event_id` prima dell'insert e anche su `unique_violation`
- [x] shape ritorno RPC object/row verificata: `returns public.sync_events` e `return v_row`; README migration conferma singola row/object, non `setof`
- [x] nessuna assunzione sul live remoto dichiarata: nessuna RPC live, nessun Supabase live, nessun SQL eseguito, nessun `db push`

### Gate payload D59-01/D59-08/D59-09 (E1)
**Esito:** non passa per drain RPC MVP.

Evidenze:
- `SyncEventOutboxEntry` persiste `ownerUserID`, `clientEventID`, `batchID`, `domain`, `eventType`, `changedCount`, `entityIDsShape`, `metadataShape`, stato/retry e `sourceDeviceID`.
- `SyncEventOutboxEnqueueService` costruisce `SyncEventRecordRequest` completo solo durante enqueue, tramite `MappedEvent.entityIDs` e `MappedEvent.metadata`, ma salva nell'outbox solo `entityIDsShape` e `metadataShape`.
- Gli shape sono stringhe privacy-safe tipo `suppliers:count=...`, `price_rows:count=...`, `source=...`; non sono JSON RPC e non bastano a ricostruire `SyncEventJSONValue` fedele.
- Il contratto RPC accetta anche `entity_ids = null`, ma D59-01/D59-08/D59-09 vietano di trasformare automaticamente shape-only in eventi count-only o semanticamente ambigui senza decisione per `domain`/`eventType`.

Conclusione: con il modello attuale il drain non può ricostruire un `SyncEventRecordRequest` semanticamente utile senza fallback non ancora approvato o senza persistenza payload minimale.

### Store capability D59-19 (E2)
**Esito:** capacità di base presente, ma non usata perché E1 blocca Path A.

Evidenze:
- `SyncEventOutboxLocalStore.fetchRetryable(ownerUserID:now:limit:)` è owner-scoped, filtra `pending`/`failedRetryable`, `attemptCount < maxAttempts`, `nextRetryAt <= now`, ordina per `nextRetryAt`, `createdAt`, `id`, e supporta limite.
- `SyncEventOutboxStateMachine` espone `toSending`, `toSent`, `transitionAfterFailure`, stati terminali `blockedContract`/`blockedAuth`/`blockedSchema`/`dead`, e usa `maxAttempts` esistente.
- `SyncEventOutboxEntry.apply(_:)` consente snapshot/restore applicativo; `ModelContext.save()` / `rollback()` sono già usati da enqueue per persistenza e rollback.
- Lo store non espone helper dedicati `save/rollback` o transizioni atomiche; in Path A sarebbero sufficienti helper piccoli o uso diretto controllato di `ModelContext`, ma non è opportuno introdurli finché il gate payload resta bloccante.

### Execution path scelto (E3)
**Path B — Payload insufficiente.**

Decisione presa **prima di toccare Swift**: non implementare `SyncEventOutboxDrainService`, non creare `SyncEventOutboxDrainResult`, non aggiungere test drain e non introdurre drain RPC count-only. Il follow-up tecnico necessario è una decisione di planning su fallback compatto per `catalog/catalog_changed` e `prices/prices_changed`, oppure una persistenza payload minimale esplicita nell'outbox. Finché quel gate non è chiuso, inviare via `record_sync_event` da shape-only sarebbe fuori contratto D59-01/D59-08/D59-09.

### Modifiche fatte
- Aggiornato `docs/TASKS/TASK-059-supabase-sync-events-outbox-drain-ios.md` con avvio execution controllata, evidenze E0/E1/E2, scelta **Path B**, check, rischi e handoff.
- Aggiornato `docs/MASTER-PLAN.md` per tracciare l'avvio execution e poi il passaggio a **TASK-059 ACTIVE / REVIEW**.
- Nessun file Swift modificato.
- Nessun `project.pbxproj`, `OptionsView`, `Localizable`, Supabase locale, SQL o Android modificato.
- Nessun `SyncEventOutboxDrainService` creato, perché il gate payload è bloccante.

### Check eseguiti
- ✅ ESEGUITO — Build compila: `xcodebuild -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' build` → **BUILD SUCCEEDED**.
- ✅ ESEGUITO — Nessun warning nuovo introdotto: nessun Swift modificato; build mostra warning Xcode AppIntents preesistente/non causato da TASK-059 documentale (`Metadata extraction skipped. No AppIntents.framework dependency found`).
- ✅ ESEGUITO — Modifiche coerenti con il planning: D59-01/D59-08/D59-09 hanno bloccato Path A; applicato Path B senza drain RPC.
- ✅ ESEGUITO — Criteri di accettazione verificati per il gate: E0 compilato, E1 fallito in modo documentato, E2 letto, E3 scelto prima di Swift.
- ⚠️ NON ESEGUIBILE — `SyncEventOutboxDrainServiceTests`: test non esistente e non creato perché Path B vieta implementazione drain.
- ✅ ESEGUITO — Regressioni TASK-055/056/057/058: `xcodebuild -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' test -only-testing:iOSMerchandiseControlTests/SyncEventOutboxStateTests -only-testing:iOSMerchandiseControlTests/SyncEventOutboxLocalStoreTests -only-testing:iOSMerchandiseControlTests/SyncEventOutboxEnqueueServiceTests -only-testing:iOSMerchandiseControlTests/SyncEventRecordingTests -only-testing:iOSMerchandiseControlTests/SyncEventLiveRecorderTests` → **TEST SUCCEEDED**.
- ✅ ESEGUITO — `git diff --check` + `git diff --no-index --check /dev/null docs/TASKS/TASK-059-supabase-sync-events-outbox-drain-ios.md` → nessun errore whitespace (il secondo comando ritorna exit 1 solo perché confronta un file nuovo con `/dev/null`, senza output di whitespace).
- ✅ ESEGUITO — Anti-scope diff: `git diff --name-only` e `git diff -- iOSMerchandiseControl iOSMerchandiseControlTests` confermano nessuna modifica a codice iOS/test, `OptionsView`, `Localizable`, `project.pbxproj`, SQL/Supabase/Android.
- ✅ ESEGUITO — Nessun TASK-060: `rg --files docs/TASKS | rg 'TASK-060'` → nessun file trovato.
- ✅ ESEGUITO — Nessuna RPC live / Supabase live / SQL / `db push`: solo lettura file SQL locale e build/test Xcode.

### Anti-scope verificato
- Nessuna UI, nessun `OptionsView`, nessun `Localizable`.
- Nessun `BGTask`, Realtime, timer, worker, auto-drain o call site applicativo.
- Nessun `SupabaseClient` o `.rpc(` nuovo.
- Nessun SQL/migration/db push.
- Nessuna modifica Android.
- Nessun TASK-060.

### Rischi rimasti
- **Blocco payload:** `SyncEventOutboxEntry` salva shape, non JSON semantico; serve decisione di planning su fallback compatto per `catalog/catalog_changed` e `prices/prices_changed` oppure persistenza payload minimale.
- **Drain assente:** outbox resta non drenabile da iOS in modo sicuro finché E1 non viene risolto.
- **Store helper non introdotti:** D59-19 è sufficiente come lettura preliminare, ma eventuale Path A futuro dovrà decidere piccoli helper `save/rollback` o uso diretto controllato di `ModelContext`.
- **Recovery `sending` stale:** resta fuori scope come già pianificato.

### Handoff post-execution storico → Claude / Reviewer
- **Stato task (storico)**: **ACTIVE / REVIEW**
- **Responsabile attuale (storico)**: **Claude / Reviewer**
- **Esito execution**: **Path B — gate payload bloccante documentato**
- **Swift/progetto**: nessuna modifica
- **Richiesta review**: validare che lo stop Path B sia coerente con D59-01/D59-08/D59-09 e decidere se riportare a PLANNING per fallback compatto/persistenza payload minimale.
- **Non dichiarare DONE**: TASK-059 resta aperto in review documentale; TASK-058 resta ultimo completato DONE.

---

## Review (Claude)
### Review documentale post-execution controllata — 2026-05-07

**Verdetto:** **APPROVED_STOPPED_BY_GATE / RETURN_TO_PLANNING**

**Motivazione:** lo stop Path B è corretto. `SyncEventOutboxEntry` persiste solo `entityIDsShape` e `metadataShape`, mentre il JSON semantico completo (`MappedEvent.entityIDs` / `MappedEvent.metadata`) esiste solo durante enqueue e non viene salvato nell'outbox. Le decisioni **D59-01 / D59-08 / D59-09** vietano un replay count-only o fallback compatto implicito senza decisione documentata per `domain`/`eventType`. Quindi **non** doveva essere implementato `SyncEventOutboxDrainService` in questa execution.

**E0 Supabase locale:** evidenze approvate come documentali e locali: migration `20260424021936_task045_sync_events.sql` letta; RPC `record_sync_event` confermata; `changed_count` 0...1000; `entity_ids` nullable ma object se presente; budget metadata 4096 byte; chiavi metadata vietate documentate; idempotenza su `(owner_user_id, client_event_id)` confermata; ritorno `public.sync_events` object/row confermato; nessuna assunzione live remota.

**E2 Store capability:** lettura coerente. `fetchRetryable` è owner-scoped e filtra stati retryable, `attemptCount < maxAttempts`, `nextRetryAt <= now`; state machine presente con `toSending`, `toSent`, `transitionAfterFailure`; `maxAttempts` già esistente. Mancano helper dedicati save/rollback, ma la scelta di **non** introdurli ora è corretta perché E1 blocca Path A.

**Fix documentali applicati in review:**
- Nota iniziale aggiornata da “Solo planning” a “Planning + execution controllata di gate”.
- Anti-scope aggiornato per distinguere nessuna implementazione Swift/progetto da build/XCTest ammessi solo come check regressione/tracking.
- Handoff `READY FOR PLANNING REVIEW` marcato come **pre-execution storico** e superato dal user override.
- Review aggiornata da pending planning review a review post-execution documentale.
- Stato riallineato dopo verdict gate: **TASK-059 ACTIVE / PLANNING**, responsabile **Claude / Planner**, **TASK-058** ultimo DONE, nessun TASK-060.

**Anti-scope review:** nessun Swift modificato, nessun test Swift nuovo, nessuna UI, nessun `OptionsView`, nessun `Localizable`, nessun `project.pbxproj`, nessun SQL/Supabase/Android, nessun TASK-060.

**Stato finale consigliato:** mantenere **TASK-059 ACTIVE / PLANNING** per planning review della micro-slice payload fidelity / outbox replay strategy; non dichiarare DONE.

**Prossimo passo consigliato (senza execution):** tornare a planning e scegliere una sola strategia:
- **A)** fallback compatto documentato per `catalog/catalog_changed` e `prices/prices_changed`;
- **B)** persistenza payload minimale nell'outbox;
- **C)** lasciare il drain bloccato fino a una decisione più ampia.

Non creare automaticamente TASK-060.

---

## Execution — Slice G1 Payload Fidelity (Codex)
### Avvio execution controllata — 2026-05-07

**User override operativo:** dopo il verdict storico **APPROVED_STOPPED_BY_GATE / RETURN_TO_PLANNING**, l'utente ha autorizzato una micro-slice G1 dentro TASK-059 per risolvere il blocco Path B con persistenza payload minimale. Impatto: Codex ha potuto modificare Swift solo dopo gate G1-E0/G1-E1/G1-E2/G1-E3; drain RPC e qualunque call a `SyncEventRecording.record(_:)` restano fuori scope.

**Obiettivo compreso:** salvare in outbox un payload replay minimale, validato, privacy-safe e decodificabile per ricostruire in futuro un `SyncEventRecordRequest` senza fallback shape-only/count-only implicito. `entityIDsShape` / `metadataShape` restano invariati come shape di log/debug privacy-safe.

**File controllati:**
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-059-supabase-sync-events-outbox-drain-ios.md`
- `iOSMerchandiseControl/SyncEventOutboxEntry.swift`
- `iOSMerchandiseControl/SyncEventOutboxEnqueueService.swift`
- `iOSMerchandiseControl/SyncEventRecording.swift`
- `iOSMerchandiseControl/SyncEventOutboxState.swift`
- `iOSMerchandiseControl/SupabaseSyncEventDTOs.swift`
- `iOSMerchandiseControl/SyncEventRPCRequestMapper.swift`
- `iOSMerchandiseControl/SupabaseSyncEventLiveRecorder.swift`
- `iOSMerchandiseControl/SupabaseSyncEventRPCTransport.swift`
- `iOSMerchandiseControlTests/SyncEventOutboxStateTests.swift`
- `iOSMerchandiseControlTests/SyncEventOutboxLocalStoreTests.swift`
- `iOSMerchandiseControlTests/SyncEventOutboxEnqueueServiceTests.swift`
- `iOSMerchandiseControlTests/SyncEventRecordingTests.swift`
- `iOSMerchandiseControlTests/SyncEventLiveRecorderTests.swift`
- Supabase locale: `/Users/minxiang/Desktop/MerchandiseControlSupabase/supabase/migrations/20260424021936_task045_sync_events.sql`
- GitHub iOS disponibile/verificato: `HEAD` locale `dc553261a3d553d69e2b015521ab74c5590d18dd` allineato a `origin/HEAD`

**Piano minimo applicato:**
1. Chiudere gate payload/model/privacy/scope prima di Swift.
2. Aggiungere solo campi opzionali payload JSON a `SyncEventOutboxEntry`.
3. Codificare/decodificare `SyncEventJSONValue` con JSON deterministico.
4. Validare prima della persistenza; su payload invalido creare solo entry bloccata senza payload persistente.
5. Aggiungere helper replay testabile, senza rete e senza drain.
6. Aggiungere test mirati e regressioni TASK-055/056/057/058.

### Gate G1-E0 — Payload contract
**Esito:** PASS.

Evidenze:
- `SyncEventRecordRequest.entityIDs` e `SyncEventRecordRequest.metadata` usano `SyncEventJSONValue`.
- `SyncEventJSONValue` era `Decodable`; G1 lo rende `Codable` per serializzazione/derserializzazione testabile.
- `SyncEventRecordValidator` valida `changedCount` 0...1000, campi obbligatori, budget JSON, token/query string, liste massive e ora anche contratto locale Supabase:
  - `entity_ids`: `null` oppure object con sole chiavi `supplier_ids`, `category_ids`, `product_ids`, `price_ids`; valori array di UUID; max SQL 250 prima dei budget privacy esistenti.
  - `metadata`: object; chiavi vietate `barcode`, `email`, `excel`, `path`, `price`, `product_name`, `supplier_name`, `category_name`, `token`.
- Serializzazione deterministica tramite `JSONEncoder` con `.sortedKeys`; decoding tramite `JSONDecoder` verso `SyncEventJSONValue`.

### Gate G1-E1 — SwiftData model risk
**Esito:** PASS con rischio residuo documentato.

Evidenze:
- Modello app usa `.modelContainer(for:)` senza `VersionedSchema` o migration custom.
- La modifica modello è additiva e opzionale: `entityIDsPayloadJSON: String?`, `metadataPayloadJSON: String?`.
- Entry legacy restano rappresentabili con payload `nil`; il replay helper fallisce esplicitamente su payload mancante.
- Build Debug e test in-memory SwiftData passano. Non è stata eseguita una prova manuale di upgrade su store persistente reale preesistente.

### Gate G1-E2 — Privacy
**Esito:** PASS.

Evidenze:
- Payload persistito solo dopo `SyncEventRecordValidator`.
- Payload invalido/forbidden non viene salvato: entry bloccata con `entityIDsPayloadJSON == nil` e `metadataPayloadJSON == nil`.
- Nessun token/email/path/barcode raw/nome prodotto/fornitore/categoria/server body viene persistito nei nuovi campi.
- Le shape restano separate e privacy-safe; non vengono sostituite dal JSON payload.

### Gate G1-E3 — Scope
**Esito:** PASS.

Confermato:
- Nessun `SyncEventOutboxDrainService`.
- Nessun `SyncEventOutboxDrainServiceTests`.
- Nessuna chiamata a `SyncEventRecording.record(_:)`.
- Nessuna RPC `record_sync_event`, nessun Supabase live, nessun SQL/db push.
- Nessun Android, nessuna UI, nessun `OptionsView`, nessun `Localizable`, nessun BGTask/Realtime/timer/worker/auto-drain.
- Nessun TASK-060.

### Modifiche fatte
- `SyncEventOutboxEntry.swift`
  - aggiunti campi opzionali persistenti `entityIDsPayloadJSON` e `metadataPayloadJSON`;
  - aggiunto `SyncEventOutboxPayloadCodec`;
  - aggiunto helper `makeRecordRequestForReplay(...)`;
  - errori espliciti per legacy payload mancante, JSON corrotto, batch id invalido e validazione fallita.
- `SupabaseSyncEventDTOs.swift`
  - `SyncEventJSONValue` ora `Codable`.
- `SyncEventRecording.swift`
  - validator allineato al contratto locale `record_sync_event` per shape/chiavi `entity_ids` e metadata forbidden keys.
- `SyncEventOutboxEnqueueService.swift`
  - enqueue continua a calcolare shape;
  - payload JSON viene salvato solo se la request passa validazione/encoding;
  - default `entityIDs` per eventi senza ID reali è `.null`, ammesso dal contratto RPC; i conteggi restano in `changedCount` e metadata;
  - failure payload/contract produce entry bloccata senza payload replay.
- `SyncEventOutboxEnqueueServiceTests.swift`
  - test su persistenza payload catalog/prices, shape invariata, replay helper, legacy payload mancante, JSON corrotto, metadata forbidden key, boundary 1000/1001, payload raw non persistito.
- `SyncEventRecordingTests.swift`
  - test validator per metadata forbidden keys e contratto `entity_ids`.

### Schema/model impact
- Impatto SwiftData: due nuovi attributi opzionali `String?` su `SyncEventOutboxEntry`.
- Retrocompatibilità logica: entry vecchie con payload `nil` non vengono convertite in fallback count-only; il replay helper restituisce errore esplicito.
- Nessuna migration manuale introdotta; nessun `project.pbxproj` modificato.

### Check eseguiti
- ✅ ESEGUITO — Build compila: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' build` → **BUILD SUCCEEDED**.
- ✅ ESEGUITO — Nessun warning nuovo introdotto: build riuscita; unico warning osservato `Metadata extraction skipped. No AppIntents.framework dependency found`, già presente nelle build precedenti e non legato a G1.
- ✅ ESEGUITO — Test nuovi payload persistence: `SyncEventOutboxEnqueueServiceTests` + `SyncEventRecordingTests` → **TEST SUCCEEDED**.
- ✅ ESEGUITO — Regressioni TASK-055/056/057/058: `SyncEventOutboxStateTests`, `SyncEventOutboxLocalStoreTests`, `SyncEventOutboxEnqueueServiceTests`, `SyncEventRecordingTests`, `SyncEventLiveRecorderTests` → **TEST SUCCEEDED**.
- ✅ ESEGUITO — `git diff --check` → nessun output/errore.
- ✅ ESEGUITO — whitespace file task untracked: `git diff --no-index --check /dev/null docs/TASKS/TASK-059-supabase-sync-events-outbox-drain-ios.md` → nessun output whitespace; exit 1 atteso per confronto con `/dev/null`.
- ✅ ESEGUITO — Anti-scope diff codice: grep su `git diff --unified=0 -- iOSMerchandiseControl iOSMerchandiseControlTests` per `OptionsView`, `Localizable`, `BGTask`, `Realtime`, `timer`, `worker`, `SupabaseClient`, `.rpc(`, `record_sync_event`, `SyncEventOutboxDrainService`, `SyncEventOutboxDrainServiceTests`, `db push`, `Android`, `TASK-060` → nessun match.
- ✅ ESEGUITO — Nessun TASK-060: `rg --files docs/TASKS | rg "TASK-060"` → nessun output.

### Anti-scope confermato
- Nessuna UI, nessun `OptionsView`, nessun `Localizable`.
- Nessun `BGTask`, Realtime, timer, worker, auto-drain o call site applicativo.
- Nessun `SupabaseClient`, `.rpc(` o RPC live aggiunti.
- Nessun `SyncEventOutboxDrainService` o test drain.
- Nessun SQL, migration, db push, Supabase locale modificato o Android modificato.
- Nessun TASK-060.

### Rischi rimasti
- **Entity IDs reali non sempre disponibili:** per gli outcome esistenti senza ID reali, il payload fedele e valido salva `entityIDs == .null`; se una futura G2 richiede pull mirati per ID, servirà un producer più ricco che passi `supplier_ids`/`category_ids`/`product_ids`/`price_ids` reali.
- **Migration reale non provata su store persistente preesistente:** la modifica è opzionale/additiva e i test in-memory passano, ma non è stata eseguita una prova manuale di upgrade su database locale reale di un device/simulator già popolato.
- **Validator più stretto:** eventuali producer futuri che provano a mettere count object dentro `entity_ids` verranno bloccati; i count devono restare in `changedCount`/metadata oppure essere sostituiti da array UUID ammessi.
- **Drain RPC ancora assente:** G1 sblocca la payload fidelity, ma la futura Slice G2 dovrà implementare drain separato, HOL-safe, senza fallback legacy.

### Handoff post-execution — Slice G1 → Claude / Reviewer
- **Stato task**: **ACTIVE / REVIEW**
- **Responsabile attuale**: **Claude / Reviewer**
- **Esito execution**: **G1 Payload Fidelity implementata**
- **Swift/progetto**: Swift modificato in modo mirato; nessun `project.pbxproj`
- **Richiesta review**:
  - verificare che l'aggiunta opzionale SwiftData sia accettabile come lightweight/additive;
  - verificare l'allineamento validator ↔ Supabase locale;
  - verificare che `entityIDs == .null` per outcome senza ID reali sia una persistenza esplicita valida, non un fallback shape-only;
  - confermare che G2 drain RPC resti fuori scope e vada pianificata separatamente.
- **Non dichiarare DONE**: TASK-059 resta **ACTIVE / REVIEW**; **TASK-058** resta ultimo completato DONE.

---

## Review finale — Slice G1 Payload Fidelity (Codex / Reviewer+Fixer)
### Review tecnica severa + fix diretti — 2026-05-07

**User override operativo:** l'utente ha richiesto review tecnica severa con fix diretti mirati dentro TASK-059 / Slice G1, includendo aggiornamento a **DONE** se la review passa. Impatto sul workflow standard: Codex ha operato come **Reviewer+Fixer** solo sul perimetro G1; nessuna implementazione G2/drain.

**Verdetto:** **APPROVED_FIXED_DIRECTLY / DONE**.

**Problemi trovati in review:**
- Validator `entity_ids` ancora attraversato da regole legacy troppo strette: max array 100 e blocco "massive identifier list" anche su UUID RPC-validi, mentre la RPC locale consente max **250 UUID per chiave**.
- Budget JSON unico locale 8KB non allineato alla RPC: `metadata` deve restare entro ~**4KB**, `entity_ids` entro ~**16KB**.
- Validazione payload duplicata in enqueue: `validate(request)` + `makePayloadJSON(...)` rieseguivano lo stesso validator.
- Copertura test piccola mancante su Codable completo, budget separati, batchID replay invalido e factory blocked con payload passato direttamente.

**Fix applicati direttamente:**
- `SyncEventRecordValidationPolicy` separa `metadata` **4KB** da `entity_ids` **16KB** e mantiene array metadata 100 / array entity IDs 250.
- `SyncEventRecordValidator` accetta UUID lists RPC-valide fino a 250 per chiave, rifiuta 251, mantiene metadata forbidden keys (`barcode`, `email`, `excel`, `path`, `price`, `product_name`, `supplier_name`, `category_name`, `token`) e aggiunge limiti locali RPC-safe per `clientEventID` / `sourceDeviceID` max 160.
- `SyncEventOutboxEnqueueService` usa il payload codec come unico punto di validazione+encoding prima della persistenza.
- `SyncEventOutboxFactory.makeEntry` scarta payload JSON se la factory blocca l'entry per contract locale.
- Test aggiornati/aggiunti per Codable `.null`/object/array/string/number/bool, determinismo `.sortedKeys`, entity IDs 250/251, budget 16KB/4KB, batchID invalido, raw business ID non persistito, payload nil su changedCount 1001.

**File modificati in review/fix:**
- `iOSMerchandiseControl/SyncEventOutboxEntry.swift`
- `iOSMerchandiseControl/SyncEventOutboxEnqueueService.swift`
- `iOSMerchandiseControl/SyncEventRecording.swift`
- `iOSMerchandiseControl/SupabaseSyncEventDTOs.swift` *(già G1: `SyncEventJSONValue` `Codable`)*
- `iOSMerchandiseControlTests/SyncEventOutboxEnqueueServiceTests.swift`
- `iOSMerchandiseControlTests/SyncEventRecordingTests.swift`
- `docs/TASKS/TASK-059-supabase-sync-events-outbox-drain-ios.md`
- `docs/MASTER-PLAN.md`

**Check eseguiti:**
- ✅ ESEGUITO — Build compila: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' build` → **BUILD SUCCEEDED**.
- ✅ ESEGUITO — Nessun warning nuovo introdotto: unico warning osservato `Metadata extraction skipped. No AppIntents.framework dependency found`, già documentato/preesistente e non legato a G1.
- ✅ ESEGUITO — Test mirati/regressione: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' test -only-testing:iOSMerchandiseControlTests/SyncEventOutboxStateTests -only-testing:iOSMerchandiseControlTests/SyncEventOutboxLocalStoreTests -only-testing:iOSMerchandiseControlTests/SyncEventOutboxEnqueueServiceTests -only-testing:iOSMerchandiseControlTests/SyncEventRecordingTests -only-testing:iOSMerchandiseControlTests/SyncEventLiveRecorderTests` → **TEST SUCCEEDED**.
- ✅ ESEGUITO — Modifiche coerenti con il planning: solo Slice G1 payload fidelity; nessun drain RPC; shape privacy-safe invariata.
- ✅ ESEGUITO — Criteri di accettazione G1 verificati: payload opzionale, legacy nil fail-closed, JSON corrotto fail-closed, validator allineato ai punti RPC locali richiesti, enqueue salva payload solo dopo validazione, `changedCount == 1000` passa, `1001` bloccato senza payload.
- ✅ ESEGUITO — `git diff --check` → nessun errore whitespace.
- ✅ ESEGUITO — Whitespace check file nuovi/untracked: `git diff --no-index --check /dev/null docs/TASKS/TASK-059-supabase-sync-events-outbox-drain-ios.md` → nessun errore whitespace; exit 1 atteso per confronto con `/dev/null`.
- ✅ ESEGUITO — Anti-scope grep/diff: nessun `OptionsView`, `Localizable`, UI, BGTask, Realtime, timer/worker/auto-drain, `SyncEventOutboxDrainService`, `SyncEventOutboxDrainServiceTests`, nuova `.rpc(`, RPC live, Supabase live, SQL/db push, Android, TASK-060.

**Anti-scope confermato:**
- Nessun `SyncEventOutboxDrainService`; nessun drain RPC; nessuna chiamata `SyncEventRecording.record(_:)` da un drain.
- Nessuna RPC live, Supabase live, SQL/migration/db push, Android.
- Nessuna UI, `OptionsView`, `Localizable`, BGTask, timer, worker, Realtime o auto-drain.
- Nessun `project.pbxproj` necessario/modificato; nessun TASK-060.

**Rischi residui:**
- Migration reale su store persistente preesistente non provata manualmente; mitigazione: campi SwiftData opzionali/additivi e test in-memory/build PASS.
- Alcuni producer esistenti non hanno liste ID reali e persistono `entityIDs == .null` come payload esplicito valido; G2 potrà inviare fedelmente quello stato, ma pull mirato per ID richiederà producer più ricchi.
- G2 drain RPC resta futuro/out-of-scope: servirà implementare service HOL-safe separato, senza fallback legacy shape-only/count-only.

**Stato finale:** **TASK-059 DONE / Chiusura** solo per **Slice G1 Payload Fidelity**. Progetto riallineato a **IDLE** nel `MASTER-PLAN`; **TASK-058** resta precedente **DONE**; **TASK-052** resta **BLOCKED / superseded**, **non DONE**; **nessun TASK-060**.

---

## Decisioni / note successive
*Aggiornare qui solo con versioning (OBSOLETA) se le decisioni D59-xx cambiano.*
