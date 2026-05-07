# TASK-062 — Supabase `sync_events` manual drain — operational validation iOS

**Stato tracking:** TASK-062 **DONE / Chiusura** — Review tecnica severa **APPROVED_FIXED_DIRECTLY** su conferma esplicita utente; workspace IDLE.

## Informazioni generali

| Campo | Valore |
|-------|--------|
| **Task ID** | TASK-062 |
| **Titolo** | Supabase sync_events manual drain — operational validation iOS |
| **File task** | `docs/TASKS/TASK-062-supabase-sync-events-manual-drain-operational-validation-ios.md` |
| **Stato** | DONE |
| **Fase attuale** | Chiusura |
| **Responsabile attuale** | Nessuno / Workspace IDLE |
| **Data creazione** | 2026-05-07 |
| **Ultimo aggiornamento** | 2026-05-07 19:41 -04 — *Review tecnica severa completata con **APPROVED_FIXED_DIRECTLY**; fix piccoli documentali/tracking applicati; TASK-062 chiuso in **DONE / Chiusura** su conferma esplicita utente.* |
| **Ultimo agente** | Claude / Reviewer+Fixer |

## Dipendenze

- **Dipende da**
  - **TASK-061** (**DONE / Chiusura**) — UI DEBUG minima `OptionsView` (`#if DEBUG`): `SyncEventOutboxDrainDebugViewModel`, conteggi locale, drain manuale on-demand dopo conferma nativa, gating auth/owner, localizzazioni `options.supabase.syncEventsOutbox.*`, XCTest ViewModel/fake; **nessuno** smoke visuale/manuale obbligatorio documentato nella chiusura.
  - **TASK-060** (**DONE / Chiusura**) — `SyncEventOutboxDrainService` drain manuale via `SyncEventRecording`; **no** UI nel perimetro G2.
  - Contesto tecnico correlato (**DONE**): **TASK-059** G1 replay/payload; **TASK-058** recorder live / transport boundary; **TASK-057** enqueue locale (nessuna rete).
- **Sblocca** *(solo candidati, non impegni)* — recovery `sending` stale; retention outbox; eventuali miglioramenti UX post-smoke (**micro-fix** dentro policy §5.1); **non** parte di questo task senza nuovo backlog.

---

## Fonti lette / riferimenti di planning

### Repo remoto *(contesto pubblico)*

- [https://github.com/XNIW/iOSMerchandiseControl](https://github.com/XNIW/iOSMerchandiseControl) — confermata esistenza repo; **nessun diff codice scaricato o confrontato nel dettaglio in questo planning-only** (perimetro vietato Execution). Allineamento operativo futuro come da workflow standard (pull locale prima dell’executor).

### Documentazione iOS *(workspace `/Users/minxiang/Desktop/iOSMerchandiseControl`)*

- `docs/MASTER-PLAN.md` — tracking progetto (**ACTIVE**, task **TASK-062** dopo creazione questo file).
- `docs/TASKS/TASK-061-supabase-sync-events-manual-drain-debug-ui-ios.md` — comportamento UI/gating/copy/test automatici vs **gap smoke manuale**.
- `docs/TASKS/TASK-060-supabase-sync-events-outbox-drain-g2-ios.md` — servizio drain; regressioni XCTest pianificate anche in EXECUTION futura TASK-062.
- `docs/TASKS/TASK-059-supabase-sync-events-outbox-drain-ios.md` — Slice G1; head-of-line / contratti.
- `docs/TASKS/TASK-058-supabase-record-sync-event-live-recorder-planning-ios.md` — transport/recorder boundary; TASK-071/072 come rischi backend.
- `docs/TASKS/TASK-057-supabase-sync-events-slice-e-local-enqueue-ios.md` — enqueue locale-only.

### Master plan Android / Supabase esterni *(forniti dall’utente)*

L’utente ha fornito i **Master Plan Android e Supabase** aggiornati come riferimento funzionale/documentale per l’allineamento iOS. In questo planning **TASK-062** vengono usati **solo** per orientare la validazione e i guardrail; **nessun** Kotlin, SQL, migration o stato backend viene modificato.

| Fonte | Punto utile per TASK-062 |
|------|--------------------------|
| **Android Master Plan** | Android ha completato **TASK-070** / **TASK-071**; resta attenzione su `sync_events`, retry **head-of-line**, logging **privacy-safe** e mismatch **`changed_count > 1000`**. |
| **Android TASK-068** | Resta **`PARTIAL`**; la validazione live **bulk non** deve essere assunta come completata né usata come prerequisito iOS. |
| **Supabase Master Plan** | `sync_events` / **`record_sync_event`** sono parte della lane condivisa; qualunque verifica **live** deve restare prudente, **senza** SQL / `db push` / cambio contratto RPC. |

Riferimento schema/contratto **locale** già documentato nei task iOS (**TASK-059/060/061**): migration tipica **`20260424021936_task045_sync_events.sql`** *(clone Supabase progetto correlato)* — RPC **`returns public.sync_events`** (singola riga), **`changed_count`** 0…1000, limiti **`entity_ids`** / **`metadata`**.

> **Se in futura Execution** i file locali Android/Supabase non sono disponibili nel filesystem, **l’executor deve dichiararlo chiaramente** e usare **solo** i Master Plan forniti / documenti **iOS** già tracciati (**TASK-057 … TASK-061**, il presente file). **Non** deve inventare stato live.

---

## Scopo

Pianificare una **validazione operativa controllata** (Simulator iPhone **16e** o dispositivo disponibile; account Supabase opzionale) della **card DEBUG TASK-061** per confermare comportamento UX/safety sul runtime reale, **senza** introdurre auto-drain, cleanup outbox o mutazioni Supabase non intenzionali.

**Questo task in questo turno è solo PLANNING:** nessuna modifica Swift, `project.pbxproj`, build, XCTest eseguito, smoke live, RPC/SQL/Android, **nessun TASK-063**.

---

## 1. Stato attuale *(post TASK-061)*

| Voce | Stato |
|------|--------|
| **TASK-061** | **DONE / Chiusura** — UI DEBUG implementata (`OptionsView`, `#if DEBUG`, ViewModel dedicato, localizzazioni, test automatici PASS in chiusura TASK-061). |
| **Test automatici** | Documentati PASS in TASK-061 (build Debug/Release, XCTest ViewModel + localizzazioni, regressioni TASK-060, grep anti-scope, ecc.). |
| **Smoke visuale / manuale card DEBUG** | **Non ancora eseguito** come evidenza obbligatoria in TASK-061 — è il **motivatore principale di TASK-062**. |
| **Progetto (tracking prima di TASK-062)** | **IDLE**, nessun task attivo. |
| **Dopo creazione TASK-062** | Progetto **ACTIVE**; task attivo **TASK-062 / PLANNING**; **TASK-063 non creato**. |
| **TASK-060 / TASK-061** | Restano **DONE**; TASK-052 resta **BLOCKED / superseded**, **non DONE**. |

---

## 2. Obiettivo operativo *(EXECUTION futura)*

Validare la feature TASK-061 in modo **reale ma prudente**:

- Preferire **Simulator iPhone 16e** (o dispositivo reale disponibile senza dati prod sensibili).
- **Supabase**: usare solo config/account **non produzione sensibile**, già presente se disponibile (**`SupabaseConfig.plist`** locale ignorata da git, come da standard progetto).
- Preferire percorsi **noWork**, **retryable == 0**, messaggi/sessione invalida prima di intraprendere qualsiasi **drain reale**.
- **Drain reale RPC** (**opzionale**, vedi §4): solo se esiste una **singola entry retryable sicura/non distruttiva** già in outbox locale o scenario controllabile **senza** creare artefatti remoti finti o cleanup.

Obiettivi di verifica (allineamento con brief utente):

1. Card DEBUG visibile **solo** in build **DEBUG** / `#if DEBUG`.
2. UI **leggibile**, coerente con `OptionsView`, **non** “dashboard”: niente liste eventi né log viewer né payload grezzo.
3. **Aggiorna conteggi**: **solo lettura locale**; **zero** RPC, **zero** drain.
4. **Drena**: parte **solo** dopo **conferma nativa**; nessuna azione prima del tap conferma.
5. **No auto-drain** (nessun trigger implicito timer/`onAppear` drain/`BGTask`/Realtime/worker pianificati per TASK-062).
6. **Owner/auth gating**: sessioni o owner invalide → messaggi stabili; nessuna chiamata inappropriate a store/service RPC.
7. **noWork** / **retryable zero** / **errori** mostrati in modo chiaro e **privacy-safe** (codici/generic copy, mai URL/token/payload/barcode nel testo).
8. Il **drain manuale** (**quando autorizzato §4**) non deve essere confuso con **cleanup outbox** (no delete/truncate aspettato dalla sola UX TASK-062; eventuali transizioni stato **solo** come da TASK-060, non purge).
9. **Regressioni TASK-060**: XCTest **`SyncEventOutboxDrainServiceTests`** e correlati stabili dopo eventuali micro-fix TASK-062.
10. **Nessuna mutazione Supabase non intenzionale** (nessun INSERT finto su staging per “provare”; nessuna modifica RPC/RLS/migration nel task).

---

## 2.1 Modalità Execution futura

La futura **Execution** deve partire in modalità **conservativa**.

### Modalità A — default / no-live-drain

**Obiettivo:** validare UX, visibilità DEBUG/RELEASE, auth/owner gating, refresh conteggi, empty state, conferma nativa e anti-scope **senza** eseguire drain reale.

**Questa modalità è sufficiente per chiudere TASK-062** se:

- la card è visivamente corretta;
- refresh conteggi è read-only;
- drain non parte senza conferma;
- `retryable == 0` / **noWork** / auth missing sono corretti;
- test automatici e grep anti-scope passano;
- **non esiste** una entry **retryable** sicura *(v. Modalità B)*.

> **Nota di chiusura:** se la **Modalità A** produce evidenze **PASS** sufficienti su UI, gating, refresh read-only, conferma nativa, localizzazioni, build/test e anti-scope, TASK-062 **può essere chiuso** anche con Modalità **B** `NOT RUN`, purché il motivo sia documentato (**§3.0.1**). Il **drain live non è obbligatorio** per dichiarare valida la card DEBUG.

### Modalità B — opzionale / controlled live drain

Da eseguire **solo** se esiste **già** una entry retryable locale **sicura e non distruttiva**, **oppure** se l’utente **autorizza esplicitamente** lo scenario.

**Vincoli:**

- **nessuna** creazione manuale di righe remote;
- **nessun** cleanup;
- **nessuna** modifica SQL/RPC/RLS;
- documentare solo **conteggi aggregati** prima/dopo;
- **mascherare** account/email/UUID negli screenshot/log;
- se emerge **`PayloadValidation`** o **`changed_count > 1000`**, classificare come rischio backend noto (**TASK-071** / Master Plan Supabase) e **non** tentare fix dentro TASK-062.

> **Modalità B** non deve essere forzata per «completare» il task. Se non c’è una entry **retryable** sicura, **`S62-09`** può restare **`NOT RUN`** con motivazione (**§3.0.1**).

### Decisioni planning TASK-062

| ID | Decisione |
|----|-----------|
| **D62-01** | La futura Execution parte in **Modalità A** no-live-drain; **Modalità B** richiede precondizione sicura **o** autorizzazione esplicita. |
| **D62-02** | La **Modalità A è sufficiente** per chiudere TASK-062 se tutte le verifiche conservative passano; **Modalità B** resta opzionale e **non** va forzata. |
| **D62-03** | Ogni **`NOT RUN`** nella matrice smoke deve avere **motivo**, **impatto** e **decisione** espliciti (**template §3.0.1**). |

---

## 3. Matrice smoke proposta *(S62-01…S62-15)*

Da compilare in **EXECUTION futura**. **Tipo evidenza** suggerito per riga; **Risultato futuro** ammessi: `PENDING` | `PASS` | `FAIL` | `NOT RUN` | `N/A`.

> **`NOT RUN` è accettabile solo con motivo documentato.** Per esempio, **Modalità B** può restare **`NOT RUN`** se non esiste una entry retryable sicura *(si resta in Modalità A)*.

| ID | Scenario | Tipo evidenza *(suggerito)* | Atteso | Risultato futuro |
|----|----------|----------------------------|--------|------------------|
| S62-01 | Build DEBUG, apri `OptionsView` | SIM / screenshot o nota manuale | Card Outbox **`sync_events`** visibile nella sezione DEBUG / Avanzata coerente. | PENDING |
| S62-02 | Build RELEASE o configurazione senza DEBUG | BUILD + nota manuale | Card **assente**. | PENDING |
| S62-03 | Sessione Supabase assente | SIM / MANUAL | Copy tipo *Sessione Supabase non disponibile* (o chiave equiv. localizzata); refresh/drain **disabilitati** o ineffectivi sicuri. | PENDING |
| S62-04 | Owner invalido o assente | SIM / MANUAL | *Owner locale non valido* (o equiv. localizzato); **nessuna** chiamata store/drain/remota. | PENDING |
| S62-05 | Tap «Aggiorna conteggi» | SIM / MANUAL (+ grep/static opzionale) | **Solo** refresh conteggi locale; **no** drain; **no** RPC/recorder traffic. | PENDING |
| S62-06 | Conteggi mai caricati (fresh open) | SIM / MANUAL | Stato *Conteggi non ancora caricati* (o equivalente pulito, chiave **`counts.notLoaded`** / naming vigente TASK-061). | PENDING |
| S62-07 | `retryable == 0` | SIM / MANUAL | Empty state *Nessun evento da drenare*; CTA drain **disabilitata** o **non promossa** — nessuna pressione UX a inviare. | PENDING |
| S62-08 | Tap CTA drain con `retryable > 0` | SIM / MANUAL | Si apre **conferma nativa**; **nessun** `drainOnce` prima della conferma. | PENDING |
| S62-09 | Conferma drain *(solo Modalità B + §4)* | SIM / MANUAL / nota aggregata privacy-safe | **Un solo** ciclo drain per conferma; esito inline; **massimo un** refresh conteggi finale (policy TASK-061). | PENDING |
| S62-10 | Double tap / tap rapido su CTA confermato | SIM / MANUAL | **Nessun** doppio drain; stato *draining* chiaro/disabilitazioni coerenti. | PENDING |
| S62-11 | Errore rete *(simulato o naturale)* | SIM / MANUAL | Messaggio **generico privacy-safe**; mai URL/token/payload dettaglio. | PENDING |
| S62-12 | Cambio account/sessione dopo aver mostrato conteggi risultati | SIM / MANUAL | Conteggi/risultati **invalidati** o reset coerenti; **no** bleed cross-owner. | PENDING |
| S62-13 | Localizzazioni **IT / EN / ES / ZH-Hans** | MANUAL / SIM | Copy leggibile per ogni lingua; **nessuna** stringa hardcoded ingl-only visibile erronea. | PENDING |
| S62-14 | Accessibilità / VoiceOver (base) | SIM / MANUAL / VoiceOver | CTA + conteggi annunciati come **frasi** comprensibili (etichette/accessibility hints coerenti). | PENDING |
| S62-15 | Grep anti-scope sul diff / sorgenti | **grep** / STATIC *(+ BUILD se diff Swift)* | **Zero** nuovi punti di: auto-drain, `Timer`/scheduling BG, `BGTaskScheduler`, subscription Realtime, cleanup/truncate/delete outbox dentro il perimetro TASK-062. | PENDING |

### 3.0.1 Template motivazione `NOT RUN`

Quando una riga resta **`NOT RUN`**, **l’executor** deve aggiungere una nota breve con questo formato:

| Campo | Valore |
|------|--------|
| **Scenario** | `S62-xx` |
| **Motivo `NOT RUN`** | Es.: «Modalità B non sicura: nessuna entry retryable locale non distruttiva disponibile.» |
| **Impatto** | `Non bloccante` / `Bloccante` |
| **Follow-up richiesto** | `No` **oppure** descrizione task futuro |
| **Decisione** | Accettato per TASK-062 / richiede FIX |

**Esempi accettabili:**

- `S62-09 NOT RUN` perché non esiste entry retryable sicura *(Modalità A sufficiente (**D62-02**))*.
- `S62-11 NOT RUN` perché non è stato possibile simulare errore rete senza alterare configurazione *(motivo documentato)*.
- `S62-14 NOT RUN` solo se VoiceOver non disponibile nell’ambiente, **con motivo documentato**.

**`NOT RUN` senza motivazione non è accettabile in Review** (**D62-03**).

---

## 3.1 Evidenze runtime privacy-safe

Durante la futura **Execution**, se vengono raccolti screenshot o note manuali:

- salvare eventuali immagini sotto **`docs/fixtures/TASK-062/`** **oppure** documentare che non sono state salvate;
- **non** includere email complete, token, URL Supabase, UUID completi, barcode reali, nomi prodotto o payload;
- se uno screenshot mostra account/email, **oscurarlo** o sostituirlo con descrizione testuale;
- preferire **note sintetiche** nel file task quando lo screenshot non aggiunge valore;
- **non** committare file temporanei del Simulator o log grezzi.

---

## 4. Policy drain live *(EXECUTION opzionale)*

- Il **drain RPC reale tramite UI DEBUG** è **opzionale** entro TASK-062: molti CA possono essere soddisfatti con gated UI, stato vuoto ed errori simulati o reti assenti senza alcuna scrittura remota.

**Se NON esiste** un evento `retryable` **sicuro e non distruttivo** nell’outbox locale (scenario test/dev controllato), **non forzare** la creazione di dati né eseguire drain “a vuoto” oltre i casi sicuri (**noWork** acceptable).

Divieti espliciti:

- **Non** creare righe **`sync_events` finte** su Supabase a mano o da script dentro questo task.
- **Non** modificare SQL/migration/`db push` / RPC remote.
- **Non** progettare o eseguire **cleanup outbox** (delete/truncate/reset bulk) come obiettivo di validazione.
- **Non** cancellare dati utente/catalogo né usare questo task come **dump** Sicurezza staging produzione senza segregazione dedicata.

**Se** una EXECUTION autorizzata include drain reale confermato:

- Documentare in **Execution**: ambiente (**dev/staging**), account **anonimizzato** (mai segreti nei file tracciati), **conteggi outbox prima/dopo** (numeri aggregati solo), outcome UI (**drained/noWork/blocked**/…), dichiarazione **nessun payload sensibile** in log/console, log **privacy-safe** (solo codici/category error come da recorder TASK-058).

---

## 5. UX review della card *(criteri per EXECUTION futura)*

Durante smoke, valutare e documentare (testo ± screenshot):

- **Card compatta**, non full-screen explorer.
- **Gerarchia**: titolo sezione DEBUG → sintesi conteggi → azioni chiare.
- **CTA primaria** del drain chiaramente **destinata allo sviluppatore**, non linguaggio “prod utente”; non deve essere percepita come sync automatico dell’intera app.
- **Refresh («Aggiorna conteggi»)** **separate** dalla CTA drain (no ambiguità single-button).
- **Disclosure**/testo esplicativo: presente ma **non** wall-of-text legal-style.
- **Timestamp** ultimo refresh (se mostrato): **locale**, discreto (**HH:mm** o simile TASK-061).
- Copy che indichi **uso manuale DEBUG** / non produzione quando applicabile alle chiavi localizzate.
- **Divieto assoluto** in questo task di aggiungere: lista entry outbox rigo-per-rigo, viewer JSON/log, campo payload.

### 5.1 Micro-fix UX ammessi *(solo se EXECUTION rileva problemi nitidi)*

I micro-fix UX sono ammessi **solo** in **futura Execution** se emergono problemi chiari durante lo smoke.

> Se un micro-fix tocca Swift / **`Localizable.strings`**, TASK-062 deve proseguire con **EXECUTION → REVIEW** dopo build/test/check; **non** può essere chiuso (**DONE**) automaticamente senza **review**.

Se la UI risulta **brutta o confusa** ma il comportamento TASK-061 è corretto, autorizzare **solo**:

- spacing / gruppi visivi (`VStack`/padding minimi).
- ordine blocchi UI (conteggi sopra azioni, ecc.).
- **disabled state** più chiaro.
- **etichette**/copy localizzate (IT/EN/ES/ZH-Hans).
- migliorie **VoiceOver**/accessibilità leggere.

**Non ammessi**: redesign grande, nuove superfici tipo tabella/full sync, navigazione drill-down eventi.

**Esempi ammessi:**

- label più chiara per `retryable == 0`;
- spacing verticale minore/maggiore nella card;
- `disabled` state più evidente;
- VoiceOver label mancante;
- traduzione poco naturale;
- ordine CTA refresh/drain più leggibile.

**Esempi non ammessi:**

- nuova schermata dedicata;
- lista dettagliata degli eventi;
- viewer JSON;
- dashboard con grafici;
- nuovo flusso sync.

---

## 6. Anti-scope TASK-062

Assolutamente **vietati** dentro TASK-062 (EXECUTION inclusa quando autorizzata), salvo **nuovo task** utente separato:

- auto-drain, **Timer**, **`BGTask`**, Apple **BackgroundTasks** non richiesto, **Realtime** subscriptions.
- Worker/polling/work queue **automatici**.
- Cleanup outbox: **delete** / truncate / reset massivo delle entry **`SyncEventOutboxEntry`**.
- **Nuovo schema SwiftData** / migration SwiftData dedicate.
- **SQL modificato**, **Supabase db push**, modifica RPC `record_sync_event`, modifiche **RLS** live.
- **Product**/**ProductPrice push**, full catalog sync/pull, history sync.
- Codice **Android**/Kotlin.
- Creazione **`TASK-063`** o backlog artificiale oltre quanto espresso qui.
- Dati remoti creati artificialmente (**INSERT** staging “per prova”) quando esistono percorsi locali/noWork sufficienti.
- Liste eventi / viewer payload nella UI oltre a quanto già in perimetro **TASK-061**.

---

## 7. Check pianificati — futura EXECUTION *(non eseguiti in questo turno)*

| Area | Azione prevista |
|------|----------------|
| Build | Debug su Simulator (**iPhone 16e**) + **Release** (verifica card assente). |
| Test automatici TASK-061 | Ripetere XCTest **`SyncEventOutboxDrainDebugViewModel`** (o naming vigente) + localizzazioni. |
| Regressioni TASK-060 | **`SyncEventOutboxDrainServiceTests`**, **`SyncEventOutboxStateTests`**, `SyncEventOutboxLocalStoreTests`, enqueue/recorder test come in chiusura TASK-061. |
| Localizzazione | `plutil` / parity chiavi dove applicabile progetto; scan duplicati chiavi note. |
| Repo hygiene | `git diff --check` su diff futuro micro-fix UX. |
| Anti-scope | `grep` progetto contro pattern §6 (**auto-drain**, `BGTask`, `NSTimer`/scheduling abusive, `.channel`, ecc. — whitelist documentata nei task predecessori). |
| Evidenze umane | Screenshot brevi / note sintetiche (§5 e **§3.1** privacy-safe); video **opzionale** ma consigliato per review. |

---

## Criteri di accettazione — **planning-only** *(questo task, questo turno)*

- [x] TASK-062 creato come **planning-only** (solo markdown questo turno).
- [x] `docs/MASTER-PLAN.md` aggiornato → stato globale **ACTIVE**, task attivo **TASK-062**, fase **PLANNING**.
- [x] **TASK-061** resta **DONE** *(non modificato allo stato).*
- [x] **TASK-060** resta **DONE**.
- [x] **Nessun Swift** modificato in questo turno.
- [x] **Nessun** build/Xcode test eseguito in questo turno.
- [x] **Nessuna** modifica Supabase/Android/SQL/live RPC eseguita in questo turno.
- [x] Matrice smoke **S62-01…S62-15** predisposta: **tipo evidenza**, **Atteso**, **`Risultato futuro`** (`PENDING` / `PASS` / `FAIL` / `NOT RUN` / `N/A`; executor compila dopo smoke).
- [x] Policy **drain live** documentata (§4).
- [x] **Anti-scope** documentato (§6).
- [x] **Nessun TASK-063** creato.
- [x] Master Plan Android/Supabase **forniti dall’utente** considerati come riferimento documentale.
- [x] **Modalità Execution A/B** definite (§2.1).
- [x] Policy **evidenze runtime privacy-safe** definita (**§3.1**).
- [x] **Planning Review Checklist** aggiunta.
- [x] Heading **Fonti** reso pulito per il file task (**Fonti lette / riferimenti di planning**).
- [x] Decisione **D62-02** aggiunta: Modalità A sufficiente per chiusura se **PASS**.
- [x] Decisione **D62-03** aggiunta: ogni **`NOT RUN`** richiede motivazione (**§3.0.1**).
- [x] Template motivazione **`NOT RUN`** aggiunto (**§3.0.1**).
- [x] **Definition of Ready for Execution** aggiunta.
- [x] **Planning Freeze** aggiunto.
- [x] Sezione **`Review (Claude)`** aggiunta.
- [x] Sezione **`Chiusura`** aggiunta.

*(I criteri di accettazione **EXECUTION** verranno aggiunti dopo planning review positiva ed eventuale handoff Codex.)*

---

## Planning (Claude)

### Obiettivo *(sintesi deliverable planning)*

Definire matrice smoke, policy di sicurezza per drain opzionale, criteri UX e confini rigidi prima di autorizzare qualsiasi verifica Simulator.

### Analisi

- TASK-061 ha chiuso con **automatic tests + review** ma **senza smoke manuale** della superficie nuova → rischio **gap percepibilità**/accessibilità e **silent mismatch** gated edge cases fuori XCTest fake.
- La catena tecnica TASK-057→058→059→060 garantisce recorder/drain sicuri solo se **integration UI** replica i guard del ViewModel nei path reali (session churn, lingua, Release strip).
- I **Master Plan Android e Supabase** forniti dall’utente orientano priorità/guardrail (TASK-070/071 **DONE**, TASK-068 **PARTIAL**, lane `sync_events` / **`record_sync_event`** prudente); il dettaglio contrattuale resta comunque nei task iOS e nella migration sintetizzata nella sezione Fonti — se in Execution fossero assenti filesystem locali progetto corrispettivi → vedi **nota nella sezione Master plan esterni** (blockquote sotto § Fonti).

### Approccio proposto *(EXECUTION futura)*

1. **Partire sempre da Modalità A** (**§2.1**, **D62-01**): build Debug/Release, gating auth/owner, refresh read-only, empty state/conferma, localizzazioni, grep anti-scope — **senza drain RPC**.
2. **Modalità B** solo se prerequisiti sicuri o **override esplicito** utente; aggiornare colonna **`Risultato futuro`** per **S62-09**, **`NOT RUN`** con motivazione (**§3.0.1**, **D62-03**) se si resta solo in **Modalità A** (**D62-02**).
3. Preflight sicurezza Simulator/dispositivo (no dati sensibili prod; config plist locale non tracciata).
4. Percorrere la matrice **S62-xx** con **tipo evidenza** e aggiornare **`Risultato futuro`**; **Privacy:** **§3.1**.
5. Se emerge micro-fix UX **§5.1**: dopo patch Swift/strings → **build/test/check → REVIEW** (no chiusura silenziosa TASK-062).

### File coinvolti *(lettura/exec futura tipica — nessuna modifica questo turno)*

- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/SyncEventOutboxDrainDebugViewModel.swift` *(o naming vigente)*
- `*.lproj` / chiavi **`options.supabase.syncEventsOutbox.*`**
- Test esistenti da TASK-061 + suite TASK-060

### Rischi identificati

- **Drain reale (Modalità B)** — mitigazione: default **Modalità A** (**D62-02**); **§4**; **`NOT RUN`** con **§3.0.1** (**D62-03**).
- Confondere UX **DEBUG** come feature finale utente retail — mitigazione: copy/struttura §5 + Release hidden.
- Falso PASS su localizzazioni se si testa solo **EN UI** Simulator — mitigazione S62-13.

---

## Handoff post-planning

- **Modalità A può bastare per DONE futuro:** se tutte le evidenze conservative passano (**D62-02**), **non forzare** Modalità B.
- **Ogni `NOT RUN` deve avere motivo documentato** usando il template **§3.0.1** (**D62-03**).
- **Prima di Execution:** verificare **`Definition of Ready for Execution`** (sezione sopra).
- **Planning freeze:** non espandere oltre il documento salvo richieste della Review (**sezione Planning Freeze**).
- **Default consigliato per Execution futura:** **Modalità A** — no-live-drain.
- **Modalità B** (live drain): solo con **precondizione sicura** (entry retryable non distruttiva già locale) **o** **nuova autorizzazione esplicita** utente (**§2.1**, **D62-01**, **§4**).
- **Output Execution futuro:** tabella **S62** aggiornata con **PASS/FAIL/NOT RUN/N/A**, motivi documentati dei **NOT RUN**, eventuali screenshot **privacy-safe** (**§3.1**) o note manuali.
- **Se emergono problemi UX piccoli:** applicare solo micro-fix consentiti (**§5.1**) e passare comunque a **REVIEW**; **non** chiudere **DONE** senza review.
- **Prossima fase:** **Planning Review** — verificare **Definition of Ready for Execution**, **Planning Freeze**, poi checklist **Planning Review Checklist** sotto — stato documento **READY FOR PLANNING REVIEW**, **NON READY FOR EXECUTION** Codex finché l’utente non autorizza esplicitamente l’EXECUTION.
- **Prossimo agente:** Claude / Reviewer ***oppure*** Utente *(decision gate)*.
- **Azione dopo review APPROVED + override utente:** handoff EXECUTION-ready verso Codex con **CA**/`T-xx`/`S62-xx`, mandato screenshot §3.1, grep anti-scope confermati, dichiarazione **Modalità B IN/OUT**.
- **Ripristino governance:** se un micro-fix UX tocca Swift o `Localizable`, il flusso deve prevedere **EXECUTION → REVIEW**; **DONE** solo dopo review positiva **e** conferma utente (**§5.1**).

---

## Definition of Ready for Execution

TASK-062 può passare da **PLANNING** a **EXECUTION** solo se la **Planning Review** conferma:

- [ ] Modalità **A/B** comprese e accettate.
- [ ] **Modalità A** accettata come sufficiente se **Modalità B** non è sicura (**D62-02**).
- [ ] Matrice **S62-01…S62-15** completa e **non** contraddittoria.
- [ ] Template **`NOT RUN`** presente (**§3.0.1**, **D62-03**).
- [ ] Policy evidenze **privacy-safe** presente (**§3.1**).
- [ ] Micro-fix UX limitati e **non** trasformati in redesign (**§5.1**).
- [ ] Anti-scope completo (**§6**).
- [ ] **L’utente** ha dato **conferma esplicita** per avviare **Execution**.
- [ ] Se si vuole **Modalità B**, l’**utente** ha dato conferma esplicita **separata** **oppure** l’executor ha documentato una **entry retryable** locale sicura.

**Senza** questi punti, restare in **PLANNING**.

---

## Planning Freeze

Questo planning è considerato **abbastanza completo per Planning Review**.

Da questo punto in poi **evitare** di aggiungere nuove feature, nuove modalità, nuovi scenari smoke o nuovi flussi UX, salvo **correzioni reali** richieste dalla Review.

**Sono ammessi solo:**

- fix di wording;
- fix di coerenza interna;
- chiarimenti su **`NOT RUN`** (**§3.0.1**);
- chiarimenti su **Modalità A/B**;
- correzioni richieste dalla **Planning Review**.

**Non** aggiungere **`S62-16+`**, nuove decisioni **`D62-xx`** oltre **D62-03**, né nuovi task collegati, **salvo** richiesta **esplicita** del reviewer.

**Stato atteso:** **READY FOR PLANNING REVIEW** — **NON READY FOR EXECUTION**.

---

## Planning Review Checklist

La Planning Review può avere tre esiti:

- **APPROVED** — TASK-062 può passare a **Execution** solo dopo **conferma esplicita** dell’utente.
- **CHANGES_REQUIRED** — restare in **Planning** e correggere il documento.
- **REJECTED** — rifare il planning.

**Checklist reviewer:**

- [ ] Stato iniziale coerente: **TASK-061 DONE**, **TASK-060 DONE**, **TASK-062 ACTIVE / PLANNING**.
- [ ] Master Plan Android/Supabase considerati come **riferimento**, **senza** modifiche codice/backend.
- [ ] Modalità **A/B** definite (**§2.1**, **D62-01…D62-03**).
- [ ] **Modalità A** sufficiente per chiusura se verifiche conservative **PASS** (**D62-02**) e **Modalità B** non forzata.
- [ ] Smoke matrix **S62-01…S62-15** completa (**tipo evidenza** + **`Risultato futuro`**).
- [ ] Template **`NOT RUN`** **§3.0.1** presente (**D62-03**).
- [ ] Policy screenshot/evidenze **privacy-safe** presente (**§3.1**).
- [ ] Policy **drain live** prudente e **opzionale** (**§4**).
- [ ] Micro-fix UX **limitati** e non trasformati in redesign (**§5.1**).
- [ ] Anti-scope completo (**§6**); nessuno scope creep (**Planning Freeze**, niente **S62-16+**).
- [ ] **Definition of Ready for Execution** leggibile e coerente col body del task.
- [ ] Nessun Swift/build/test/Supabase/Android eseguito **in planning** questo documento (turni documentali TASK-062).
- [ ] **TASK-063 non creato**.

**Nota:** anche con review **APPROVED**, questo file **non autorizza Execution automatica**. Serve conferma esplicita dell’utente per passare da **PLANNING** a **EXECUTION**.

---

## Execution (Codex)

### Avvio EXECUTION controllata — 2026-05-07 18:56 -04

**Execution avviata su conferma esplicita utente.** Il file task era in **ACTIVE / PLANNING** e dichiarava necessaria Planning Review prima dell'execution; la richiesta utente vale come override esplicito per passare a **ACTIVE / EXECUTION**. Impatto workflow: Codex procede solo con la validazione operativa controllata gia' pianificata, senza ridefinire il piano e senza marcare il task come DONE.

**Modalità iniziale:** **Modalità A — no-live-drain**. Non verra' eseguita Modalità B salvo presenza gia' verificata di una entry retryable locale sicura/non distruttiva oppure nuova autorizzazione esplicita separata.

**Conferma anti-scope:** nessun auto-drain, timer, BGTask, Realtime/channel, worker, cleanup/delete/truncate/reset outbox, nuovo schema SwiftData, SQL/migration/db push, modifica RPC, Product/ProductPrice push, full sync/pull catalogo/history sync, Android code o TASK-063.

**Obiettivo compreso:** validare la card DEBUG TASK-061 in `OptionsView` per visibilita' DEBUG-only, assenza Release, gating sessione/owner, refresh conteggi read-only, conferma nativa prima del drain, empty state, localizzazioni, accessibilita' base, anti-scope e nessuna mutazione remota non intenzionale.

**File letti prima di avviare l'execution tecnica:**
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-062-supabase-sync-events-manual-drain-operational-validation-ios.md`
- `docs/TASKS/TASK-061-supabase-sync-events-manual-drain-debug-ui-ios.md`
- `docs/TASKS/TASK-060-supabase-sync-events-outbox-drain-g2-ios.md`
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/SyncEventOutboxDrainDebugViewModel.swift`
- `iOSMerchandiseControl/SyncEventOutboxDrainService.swift`
- `iOSMerchandiseControl/SyncEventOutboxEntry.swift` *(equivalente reale per `SyncEventOutboxLocalStore`; `SyncEventOutboxLocalStore.swift` non esiste come file separato)*
- `iOSMerchandiseControl/SyncEventRecording.swift`
- `iOSMerchandiseControl/iOSMerchandiseControlApp.swift`
- `iOSMerchandiseControl/ContentView.swift`
- `iOSMerchandiseControl/it.lproj/Localizable.strings`
- `iOSMerchandiseControl/en.lproj/Localizable.strings`
- `iOSMerchandiseControl/es.lproj/Localizable.strings`
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`

**File previsti in modifica:** inizialmente solo tracking markdown (`docs/TASKS/TASK-062-supabase-sync-events-manual-drain-operational-validation-ios.md`, `docs/MASTER-PLAN.md`). Eventuali micro-fix Swift/localizzazioni saranno applicati solo se emergono problemi UX nitidi dentro i limiti §5.1.

**Piano minimo:**
1. Eseguire Modalità A con build Debug/Release, review statica e smoke ove possibile, senza live drain forzato.
2. Compilare la matrice **S62-01…S62-15** con `PASS` / `FAIL` / `NOT RUN` / `N/A`, motivando ogni `NOT RUN`.
3. Eseguire test/check richiesti se disponibili: build, XCTest ViewModel, regressioni TASK-060, `plutil`, `git diff --check`, grep anti-scope.
4. Aggiornare tracking e handoff a **ACTIVE / REVIEW**, responsabile **Claude / Reviewer**, senza dichiarare DONE.

### Completamento EXECUTION controllata — 2026-05-07 19:12 -04

**Modalità eseguita:** **Modalità A — no-live-drain**. Modalità B non eseguita: non è stata identificata una entry retryable locale sicura/non distruttiva e non è stata richiesta una nuova autorizzazione esplicita separata.

**File letti/controllati:** quelli elencati nell'avvio EXECUTION, più verifica mirata di `ContentView.swift` per il wiring verso `OptionsView`. Nota path: `iOSMerchandiseControl/SyncEventOutboxLocalStore.swift` non esiste; il tipo `SyncEventOutboxLocalStore` è definito in `iOSMerchandiseControl/SyncEventOutboxEntry.swift`.

**Micro-fix UX applicato:** `iOSMerchandiseControl/OptionsView.swift` — reso più chiaro lo stato disabilitato dei due button della card (`Refresh sync_events outbox counts`, `Manually drain sync_events outbox`) usando `Color.secondary` quando non azionabili. Nessuna nuova feature, nessun cambio API, nessuna localizzazione modificata.

**Evidenze runtime privacy-safe:** smoke Debug su Simulator iPhone 16e avviato con app Debug aggiornata; nessuno screenshot salvato nel repo. Sono state usate solo note manuali e screenshot temporanei in `/tmp` non tracciati. Stato osservato: card `Outbox sync_events` visibile in `OptionsView` / `Advanced`; copy "Manual DEBUG drain..." presente; sessione Supabase assente; "Supabase session unavailable"; "Counts not loaded yet"; refresh e drain disabilitati; label accessibilità presenti come frasi; nessun drain avviato.

#### Smoke matrix S62

| ID | Risultato | Tipo verifica | Evidenza |
|----|-----------|---------------|----------|
| S62-01 | PASS | BUILD + SIM/MANUAL | Build Debug PASS; card `Outbox sync_events` visibile in `OptionsView` / `Advanced` su Simulator. |
| S62-02 | PASS | BUILD + STATIC | Build Release PASS; card/call e ViewModel sotto `#if DEBUG`; recorder live per drain assente in Release. |
| S62-03 | PASS | SIM/MANUAL + TEST | Sessione Supabase assente: copy "Supabase session unavailable"; refresh/drain disabilitati; test ViewModel copre sessione invalida senza fetch/drain. |
| S62-04 | PASS | TEST/STATIC | `testInvalidSessionOrOwnerDoesNotFetchOrDrain` PASS; nessun hack runtime per alterare owner. |
| S62-05 | PASS | TEST/STATIC | `testRefreshCountsSuccessReadsCountsAndDoesNotDrain` PASS; static review: `refreshCounts` legge store locale, non chiama drain/RPC/recorder live. |
| S62-06 | PASS | SIM/MANUAL | Fresh/no session state mostra "Counts not loaded yet" in modo pulito. |
| S62-07 | PASS | TEST/STATIC | `testDrainIsNotRequestedWhenRetryableCountIsZero` PASS; copy empty state localizzato presente; CTA drain non promossa quando non drainabile. |
| S62-08 | NOT RUN | MANUAL | Non eseguito: nessuna entry retryable locale sicura/non distruttiva disponibile; no creazione dati remoti finti. |
| S62-09 | NOT RUN | MANUAL | Modalità B non eseguita; nessun live drain confermato. |
| S62-10 | PASS | TEST | `testDoubleTapDuringDrainStartsOnlyOneRun` PASS; runtime CTA non disponibile per retryable/sessione assente. |
| S62-11 | NOT RUN | MANUAL | Errore rete non simulato per non alterare configurazione reale/network in modo rischioso. |
| S62-12 | PASS | TEST/STATIC | `testOwnerChangeResetsOldCountsAndResult` PASS; nessun bleed cross-owner nel ViewModel. |
| S62-13 | PASS | STATIC + TEST | `plutil -lint` IT/EN/ES/ZH-Hans PASS; test localizzazioni TASK-061 PASS. |
| S62-14 | PASS | STATIC + CUA | Accessibility tree mostra label CTA/conteggi come frasi: `Refresh sync_events outbox counts`, `Manually drain sync_events outbox`, `sync_events outbox counts`. VoiceOver audio non richiesto. |
| S62-15 | PASS | STATIC/GREP | Grep anti-scope PASS con falsi positivi interpretati: `truncated` su ProductPrice e `drainOnce` solo nel path manuale/confermato DEBUG. |

#### Motivazioni NOT RUN

| Campo | Valore |
|------|--------|
| **Scenario** | `S62-08` |
| **Motivo `NOT RUN`** | Nessuna entry retryable locale sicura/non distruttiva disponibile; non autorizzata creazione dati remoti finti. |
| **Impatto** | Non bloccante |
| **Follow-up richiesto** | No |
| **Decisione** | Accettato per TASK-062: Modalità A sufficiente secondo D62-02. |

| Campo | Valore |
|------|--------|
| **Scenario** | `S62-09` |
| **Motivo `NOT RUN`** | Modalità B/live drain non eseguita per assenza di entry retryable sicura e assenza di nuova autorizzazione esplicita separata. |
| **Impatto** | Non bloccante |
| **Follow-up richiesto** | No |
| **Decisione** | Accettato per TASK-062: live drain non obbligatorio. |

| Campo | Valore |
|------|--------|
| **Scenario** | `S62-11` |
| **Motivo `NOT RUN`** | Errore rete non simulato: richiederebbe alterare configurazione reale/network o scenario live non necessario in Modalità A. |
| **Impatto** | Non bloccante |
| **Follow-up richiesto** | No |
| **Decisione** | Accettato per TASK-062; copertura error mapping privacy-safe verificata da test TASK-061/TASK-060. |

#### Check eseguiti

| Check | Stato | Esito |
|------|-------|-------|
| Build Debug iPhone 16e | ✅ ESEGUITO | `xcodebuild ... -configuration Debug ... build` PASS (`** BUILD SUCCEEDED **`). Warning AppIntents metadata preesistente/non bloccante. |
| Build Release iPhone 16e | ✅ ESEGUITO | `xcodebuild ... -configuration Release ... build` PASS (`** BUILD SUCCEEDED **`). Warning Swift 6 preesistente in `SupabaseProductPriceApplyService.swift:771` e warning AppIntents metadata, non introdotti da TASK-062. |
| Nessun warning nuovo introdotto | ✅ ESEGUITO | Nessun warning nuovo attribuibile al micro-fix; i warning osservati sono preesistenti/fuori perimetro. |
| Test TASK-061 ViewModel | ✅ ESEGUITO | `SyncEventOutboxDrainDebugViewModelTests` PASS (`** TEST SUCCEEDED **`, 13 test). |
| Regressioni TASK-060 | ✅ ESEGUITO | `SyncEventOutboxDrainServiceTests`, `SyncEventOutboxStateTests`, `SyncEventOutboxLocalStoreTests`, `SyncEventOutboxEnqueueServiceTests`, `SyncEventRecordingTests`, `SyncEventLiveRecorderTests` PASS (`** TEST SUCCEEDED **`). |
| Localizzazioni lint | ✅ ESEGUITO | `plutil -lint` su IT/EN/ES/ZH-Hans PASS. |
| Test localizzazioni TASK-061 | ✅ ESEGUITO | `LocalizationCoverageTests/testTask061SyncEventsOutboxLocalizationKeysExistInSupportedLanguages` PASS. |
| `git diff --check` | ✅ ESEGUITO | PASS, nessun output. |
| Grep anti-scope | ✅ ESEGUITO | PASS interpretato: nessun auto-drain/Timer/BGTask/Realtime/channel/delete/truncate/RPC in UI; `drainOnce` solo nel ViewModel DEBUG manuale; `truncated` solo falso positivo ProductPrice. |
| Coerenza con planning | ✅ ESEGUITO | Modalità A rispettata, nessun live drain forzato, nessun TASK-063. |
| Criteri S62 verificati | ✅ ESEGUITO | Matrice S62 compilata: 12 PASS, 3 NOT RUN motivati, 0 FAIL, 0 N/A. |

**Anti-scope confermato:** nessun auto-drain, Timer, BGTask, Realtime/channel, worker, cleanup/delete/truncate/reset outbox, nuovo schema SwiftData, SQL/migration/db push, modifica RPC, Product/ProductPrice push, full sync/pull catalogo/history sync, Android code, TASK-063, dati remoti finti o live drain forzato.

**Rischi residui:** Modalità B/live drain non validata runtime per scelta prudente; errore rete non simulato runtime. Entrambi non bloccanti per D62-02 e documentati come `NOT RUN`.

**Handoff post-execution:** TASK-062 portato a **ACTIVE / REVIEW**, responsabile **Claude / Reviewer**. Non marcare DONE.

---

## Handoff post-execution

- **Stato finale:** TASK-062 **ACTIVE / REVIEW**.
- **Responsabile attuale:** **Claude / Reviewer**.
- **Modalità eseguita:** **A — no-live-drain**.
- **Esito:** 12 PASS, 3 NOT RUN motivati, 0 FAIL, 0 N/A.
- **Micro-fix:** solo disabled state visivo in `OptionsView.swift`.
- **Prossimo passo:** Review Claude; **non DONE**.

---

## Fix (Codex)

*(Vuoto)*

---

## Review (Claude)

### 2026-05-07 19:41 -04 — APPROVED_FIXED_DIRECTLY / DONE *(user override)*

**Verdetto review:** **APPROVED_FIXED_DIRECTLY**.

**Override esplicito utente:** la richiesta di review autorizza la chiusura in **DONE** solo se la review termina con **APPROVED** o **APPROVED_FIXED_DIRECTLY**. La review ha trovato solo problemi piccoli di documentazione/tracking, corretti direttamente; nessun blocco tecnico o regressione.

**Review repo-grounded eseguita:**
- `git status --short`, `git diff --stat`, diff di `docs/MASTER-PLAN.md`, `iOSMerchandiseControl/OptionsView.swift` e lettura diretta del file TASK-062.
- File task e contesto: `TASK-062`, `TASK-061`, `TASK-060`, `docs/MASTER-PLAN.md`.
- Codice: `OptionsView.swift`, `SyncEventOutboxDrainDebugViewModel.swift`, `SyncEventOutboxDrainService.swift`, `SyncEventOutboxEntry.swift`, `SyncEventRecording.swift`, `iOSMerchandiseControlApp.swift`, `ContentView.swift`.
- Localizzazioni IT/EN/ES/ZH-Hans per namespace `options.supabase.syncEventsOutbox.*`.

**Situazione git/tracking:** `docs/TASKS/TASK-062-supabase-sync-events-manual-drain-operational-validation-ios.md` risulta **untracked** in `git status`, ma e' un file reale del workspace, letto integralmente e trattato come parte della chiusura TASK-062. Non e' stato eseguito staging/commit; il file deve essere incluso insieme alle modifiche di tracking se il workspace viene preparato per commit/PR.

**Fix diretti applicati in review:**
- Rimossa la sezione Review stale che diceva di restare in PLANNING.
- Compilata la sezione **Chiusura**.
- Aggiornati stato/fase/responsabile del file task a **DONE / Chiusura**.
- Riallineato `docs/MASTER-PLAN.md` a progetto **IDLE**, ultimo completato **TASK-062 DONE**, nessun task attivo, nessun **TASK-063**.

**Valutazione tecnica:**
- Execution coerente con **Modalita' A — no-live-drain**; Modalita' B non forzata.
- `S62-08`, `S62-09`, `S62-11` restano **NOT RUN** con motivazione adeguata e non bloccante secondo **D62-02/D62-03**.
- Micro-fix UX in `OptionsView.swift` accettato: `Color.secondary` e' confinato alle label dei due button DEBUG disabilitati, non introduce colori custom, non impatta UI fuori card DEBUG e resta coerente con `OptionsView`.
- Nessun live drain, nessun dato remoto finto, nessun cleanup, nessun SQL/RPC/migration/db push, nessun Android, nessun TASK-063.

**Check review rieseguiti:**

| Check | Stato | Esito |
|------|-------|-------|
| Build Debug iPhone 16e | ✅ ESEGUITO | PASS — `xcodebuild ... -configuration Debug ... build` → `** BUILD SUCCEEDED **`. Warning AppIntents metadata non bloccante. |
| Build Release iPhone 16e | ✅ ESEGUITO | PASS — `xcodebuild ... -configuration Release ... build` → `** BUILD SUCCEEDED **`. Warning Swift 6 preesistente in `SupabaseProductPriceApplyService.swift:771` e warning AppIntents metadata; nessuno attribuibile a TASK-062. |
| Test TASK-061 ViewModel | ✅ ESEGUITO | PASS — primo tentativo parallelo fallito per lock infrastrutturale `build.db`; rerun sequenziale di `SyncEventOutboxDrainDebugViewModelTests` → `** TEST SUCCEEDED **`, 13 test. |
| Regressioni TASK-060 | ✅ ESEGUITO | PASS — suite `SyncEventOutboxDrainServiceTests`, `SyncEventOutboxStateTests`, `SyncEventOutboxLocalStoreTests`, `SyncEventOutboxEnqueueServiceTests`, `SyncEventRecordingTests`, `SyncEventLiveRecorderTests` → `** TEST SUCCEEDED **`. |
| Localizzazioni lint | ✅ ESEGUITO | PASS — `plutil -lint` su IT/EN/ES/ZH-Hans. |
| Test localizzazioni TASK-061 | ✅ ESEGUITO | PASS — `LocalizationCoverageTests/testTask061SyncEventsOutboxLocalizationKeysExistInSupportedLanguages`. |
| `git diff --check` | ✅ ESEGUITO | PASS, nessun output. |
| Grep anti-scope | ✅ ESEGUITO | PASS interpretato — solo falsi positivi `truncated` esistenti in sezione ProductPrice di `OptionsView.swift`; nessun cleanup/truncate outbox, `.rpc`, `record_sync_event`, Timer/BGTask/Realtime/channel nella nuova UI. |

**Anti-scope confermato in review:** nessun auto-drain, Timer, BGTask, Realtime/channel, worker, cleanup/delete/truncate/reset outbox, nuovo schema SwiftData, SQL/migration/db push, modifica RPC, Product/ProductPrice push, full sync/pull catalogo/history sync, Android code, TASK-063, dati remoti finti o live drain forzato.

**Rischi residui non bloccanti:** Modalita' B/live drain e simulazione errore rete runtime non eseguite per scelta prudente; restano non bloccanti per **D62-02/D62-03** e sono gia' documentate come `NOT RUN`.

---

## Chiusura

TASK-062 **DONE / Chiusura**.

- **Esito finale:** **APPROVED_FIXED_DIRECTLY**.
- **Modalita' validata:** **A — no-live-drain**.
- **Smoke matrix:** 12 PASS, 3 NOT RUN motivati (`S62-08`, `S62-09`, `S62-11`), 0 FAIL, 0 N/A.
- **File Swift modificati nel task:** solo `iOSMerchandiseControl/OptionsView.swift` per micro-fix UX disabled state.
- **File tracking aggiornati:** `docs/TASKS/TASK-062-supabase-sync-events-manual-drain-operational-validation-ios.md`, `docs/MASTER-PLAN.md`.
- **Stato globale:** workspace **IDLE**, nessun task attivo.
- **Ultimo completato:** **TASK-062 DONE / Chiusura**; **TASK-061** e **TASK-060** restano precedenti **DONE / Chiusura**; **TASK-052** resta **BLOCKED / superseded**, **non DONE**.
- **TASK-063:** non creato.
