# TASK-033: Supabase schema audit and iOS/Android model mapping

## Informazioni generali
- **Task ID**: TASK-033
- **Titolo**: Supabase schema audit and iOS/Android model mapping
- **File task**: `docs/TASKS/TASK-033-supabase-schema-audit-ios-android-model-mapping.md`
- **Stato**: DONE
- **Fase attuale**: Chiusura
- **Responsabile attuale**: Review / Claude — completed
- **Data creazione**: 2026-04-26
- **Ultimo aggiornamento**: 2026-05-03
- **Ultimo agente che ha operato**: Claude / Review — approved TASK-033 audit and closed task

## Dipendenze
- **Dipende da**: nessuno
- **Sblocca**: TASK-034 e task Supabase successivi

## Scopo
Preparazione Supabase. Prima di scrivere codice iOS bisogna leggere lo schema reale nel progetto Supabase locale e allinearlo con SwiftData iOS e Room Android.

## Contesto
Questo task è solo audit e mapping. Non implementa client Supabase e non cambia codice iOS.

## Non incluso
- Implementazione client Supabase
- Dependency Supabase Swift
- Sync automatico
- Modifiche distruttive ai dati locali

## Scope
- Leggere `/Users/minxiang/Desktop/MerchandiseControlSupabase`
- Estrarre migration/schema/policy/seed
- Confrontare con iOS `Models.swift` e `HistoryEntry.swift`
- Confrontare con Android Room `AppDatabase.kt` e modelli
- Non implementare client Supabase

## Output richiesto
- Mapping tabelle/colonne
- Decisioni su id locale/remoto
- Timestamp
- Soft delete
- Conflict policy iniziale
- Piano task Supabase successivi

## Criteri di accettazione
- [x] Schema Supabase reale letto e sintetizzato (migrazioni SQL in `MerchandiseControlSupabase/supabase/migrations/`)
- [x] Mapping iOS/Android/Supabase documentato in `docs/SUPABASE/TASK-033-schema-audit.md`
- [x] Decisioni iniziali su id, timestamp, soft delete e conflict policy sono esplicite (decision log + gap nel documento audit)
- [x] Nessun client Supabase viene implementato

## Nota — Attivazione task (user override 2026-05-03)

TASK-033 è stato promosso da **TODO** ad **ACTIVE / PLANNING** su richiesta esplicita dell'utente, mettendo **TASK-032** in pausa come **BLOCKED / on hold**. Nessuna execution è stata avviata in questo aggiornamento; prima di lavorare sullo schema Supabase serve planning operativo.

## Planning (Claude) ← solo Claude aggiorna questa sezione

### 1. Obiettivo operativo

TASK-033 deve produrre, in una futura fase **Execution** (solo dopo approvazione esplicita del planning), un **audit leggibile** del backend Supabase reale e una **mappa di allineamento** tra domini dati **iOS (SwiftData)**, **Android (Room — riferimento funzionale)** e **Supabase (schema condiviso futuro)**.
Nessuna modifica implementativa: niente client Supabase, niente nuove dipendenze, niente alterazioni a modelli SwiftData/Room né a migration/schema Supabase in questo task.

### 2. Stato iniziale rilevato

- Task **TASK-033**: **ACTIVE** / **PLANNING**; planning operativo compilato qui; **Execution non avviata**.
- **TASK-032**: in pausa / **BLOCKED** (on hold) per priorità utente; non è prerequisito di TASK-033.
- **TASK-033** **sblocca** pianificazione e lavoro successivo (**TASK-034**, **TASK-035**, ulteriori task Supabase): l’audit e il mapping sono input obbligatori prima di integrazione.
- **Nessun codice** iOS/Android/Supabase modificato nell’ambito di questo aggiornamento al planning.

### 3. Fonti da leggere nella futura fase audit

**Percorsi di riferimento (verificare accessibilità in Execution; se irraggiungibili dall’agente o dalla macchina, documentare il blocco nel report e non dichiarare il task completato).**

| Area | Path / GitHub |
|------|----------------|
| Supabase locale | `/Users/minxiang/Desktop/MerchandiseControlSupabase` |
| iOS (target principale) | `/Users/minxiang/Desktop/iOSMerchandiseControl` — https://github.com/XNIW/iOSMerchandiseControl |
| Android (riferimento funzionale) | `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView` — https://github.com/XNIW/MerchandiseControlSplitView |

**Supabase** (lettura durante audit; contenuto effettivo solo dopo ispezione reale):

- Migration SQL (`supabase/migrations` o equivalente nel repo reale).
- Schema / dump SQL ufficiale o generabile (nessuna assunzione su tabelle/colonne fino a lettura).
- Seed e dati di esempio, se presenti.
- Policies **RLS** e ruoli pertinenti.
- Funzioni, trigger, viste/materialized views se esistono.
- Eventuali tipi generati dal progetto Supabase (es. codegen), se presenti.
- `README`, `.env.example` o configurazione documentata utile al contesto (senza segreti).

**iOS**:

- `Models.swift`, `HistoryEntry.swift`; eventuali modelli SwiftData in file dedicati nel target principale.
- Repository/service che leggono/scrivono **prodotti, fornitori, categorie, history, prezzi** (cercare pattern `@Model`, `@Query`, servizi sync/import).
- Eventuale **import/export database completo** già presente nell’app.
- Documentazione task precedente utile allo mapping (solo lettura citata nell’audit).

**Android** (solo confronto semantico, non priorità architetturale):

- `AppDatabase.kt`; entity **Product**, **Supplier**, **Category**, **HistoryEntry**, **ProductPrice**, **ProductPriceSummary** (o nomi equivalenti nel repo).
- **DAO** pertinenti e **InventoryRepository** (flussi dominio).
- Import/export database completo, se implementato.
- **ImportAnalyzer** / **ExcelUtils** solo se servono per capire **campi derivati dall’import** non ovvi dal modello.

**Regola di progetto**: iOS è target principale; Android è riferimento per modello e business logic; Supabase è backend condiviso **futuro**; SwiftData resta DB offline iOS; Room resta analogo offline Android — nessuna integrazione Supabase in TASK-033.

### 4. Tabelle e domini da mappare (checklist — senza colonne inventate)

Compilare le celle della matrice finale **solo dopo** lettura dello schema Supabase reale. Usare checklist di dominio:

- [ ] `products` (o equivalente nominale in Supabase)
- [ ] `suppliers`
- [ ] `categories`
- [ ] `product_prices` / storico prezzi (nome reale da schema)
- [ ] `history_entries` / fogli generati inventario (nome reale da schema)
- [ ] Metadata import/export se esistono lato Supabase o solo lato client
- [ ] Metadata sync se esistono
- [ ] Tabelle Supabase **extra** non rispecchiate chiaramente in iOS/Android
- [ ] Entità presenti in **iOS o Android** ma **assenti o non mappabili** in Supabase (gap)
- [ ] Tabelle Supabase **non ancora** usate da iOS/Android (futuro o dead code backend)

Non elencare colonne o tipi Supabase presumti: estrarli dal migration/schema reale nella fase audit.

### 5. Mapping matrix richiesta (output Execution)

Richiedere una tabella (Markdown o equivalente leggibile nel file task / allegato progetto docs) con **almeno** queste colonne:

| Dominio | Supabase table | Supabase column | Supabase type | nullable/default | constraint/index/policy rilevante | iOS model/property | Swift/SwiftData type | Android entity/property | Kotlin/Room type | note/gap/decision needed |

Righe aggiuntive ripetono per FK/vincoli/policy dove utili alla sync futura.

### 6. Decision log obbligatorio

L’audit deve produrre decisioni **esplicite** (anche “non deciso — follow-up TASK-NNN”), tra cui:

- **ID locale vs remote**: cosa resta solo su device, cosa è chiave di rete.
- **UUID remoto** Supabase: adozione, propagazione, generazione.
- **Barcode**: chiave di business / dedupe, **non** necessariamente primary key tecnica cross-device.
- **Autoincrement** Room/SwiftData: non sincronizzabile come pk globale; come trattarlo in mapping.
- **created_at**, **updated_at**, **deleted_at** (presenza e semantica).
- **Soft delete** (vedi §10).
- **Conflict policy** iniziale strategica (vedi §9), solo documentata.
- **Timezone** e formato storage vs UI.
- **Precisione prezzi** (decimali, rounding, tipo numerico).
- **Normalizzazione** nomi supplier/category (unique case-sensitive? trim? slug?).
- **Rapporto** prezzo “corrente” su entità product vs storico **product_prices**.
- **Cosa sincronizzare subito** vs cosa resta **solo locale** (inventario sessioni, draft, ecc.).

### 7. Strategia ID proposta (ipotesi — validazione obbligatoria su schema reale)

- Mantenere **ID locali** SwiftData/Room come **implementation detail** offline.
- Introdurre/usare **`remote_id` UUID** Supabase come ancoraggio per sync futura (se e come presente nello schema reale va verificato; non presumere nome colonna).
- **Barcode** come chiave business per dedupe prodotti, **senza** usarlo come unica PK tecnica distribuita.
- Supplier/category possono avere **remote_id** e vincolo su **nome normalizzato** *se lo schema e le policy lo consentono*.
- **product_prices** devono riferire il **prodotto remoto** quando esiste; cardinality e FK effettivi dipendono dallo **schema reale** — aggiornare la matrice dopo lettura migrations.

### 8. Strategia timestamp proposta (ipotesi — validazione obbligatoria)

- Supabase: **UTC**, tipi **`timestamptz`** / ISO dove applicabile (confermare da schema).
- iOS: conversione/formatting per **UI** lato client.
- Android: documentare gap se oggi si usano **stringhe** tipo `yyyy-MM-dd HH:mm:ss` invece di istanti tipizzati lato dominio/sync.
- Confrontare eventuale **`effective_at`** / equivalente tra storico prezzi locale e Supabase (**product_prices**).
- **created_at** / **updated_at** come supporto a sync e auditing.
- **deleted_at** se soft delete adottato lato schema.

### 9. Conflict policy iniziale (conservativa, solo documentazione)

- **TASK-033** documenta, non implementa.
- **TASK-034** (futuro): orientamento **read-only** verso Supabase salvo diverso rescoping documentato.
- **TASK-035** (futuro): **pull dry-run** prima di applicare merge.
- **Sync manuale** prima di automatismi.
- **Last-write-wins** solo come **fallback dichiarato** nelle decisioni, non come politica implicita silenziosa.
- Conflitti su **barcode / prezzi / supplier / category**: **loggati nel report**, non risolti automaticamente senza traccia.
- **Nessuna cancellazione remota distruttiva** nella prima fase di integrazione (da ribadire nei follow-up).

### 10. Soft delete

Verificare nello **schema reale** se esistono **`deleted_at`**, **`is_deleted`**, o equivalente.

- Se **mancano**: documentare **gap**, proporre **follow-up** come migration schema in **task futuro** dedicato — **nessuna migration** eseguita o progettata in dettaglio implementativo dentro TASK-033.
- Se **presenti**: allineare significato alla matrice iOS/Android (soft delete locale assente/presente).

### 11. Output documentale finale atteso (post Execution, sempre senza modifiche codice)

Al termine dell’audit in Execution (solo dopo approvazione planning):

- **Supabase schema summary** (sintesi fedele allo schema letto).
- **Mapping iOS/Android/Supabase** (matrice §5).
- **Decision log** (§6).
- **Gap list** (enti/tabelle/colonne/policy mancanti o ambigue).
- **Rischi** (tecnici, di sync, di privacy/RLS).
- **Follow-up ordinati** (TASK-034, TASK-035, ecc.) con dipendenze.
- **Conferma esplicita**: nessun file iOS/Android/Supabase del codice applicativo modificato da questo task.

### 12. UX/UI

**TASK-033 non modifica UI/UX.**
Note solo per roadmap: futura schermata **sync** nativa iOS; stati UX **non configurato / ultimo sync / errore / conflitti**. Nessun redesign ora. Per scelte future, preferire **UX nativa Apple** coerente col resto dell’app.

### 13. Criteri di accettazione raffinati (contratto Execution/Review)

- [ ] Schema Supabase **reale** letto da `MerchandiseControlSupabase` e **sintetizzato** (nessuna lista colonne inventata).
- [ ] Mappa **completa** almeno per domini: **products**, **suppliers**, **categories**, **product_prices**, **history_entries** (o nomi equivalenti emergenti dallo schema), con evidenziazione dove il backend usa nomi diversi.
- [ ] Gap **iOS/Android/Supabase** elencati in modo esplicito (enti solo locali, tabelle backend non usate, divergenze semantiche).
- [ ] Decisioni su **ID**, **timestamp**, **soft delete**, **conflict policy** documentate nel decision log.
- [ ] Follow-up task **ordinati** (TASK-034, TASK-035, migration eventuali solo come task futuri).
- [ ] Nessun **client Supabase** aggiunto; nessuna **dependency** Supabase Swift (o altro SDK) introdotta.
- [ ] **Nessuna modifica al codice** iOS/Android/Supabase nell’ambito TASK-033.
- [ ] Se lo **schema non è accessibile** (repo assente, permessi, path errato): il task **non** può essere chiuso come completo; va documentato il **blocco** e gli step per sblocco.

### 14. Limiti e blocchi documentabili

- Path **fuori workspace** Cursor (`MerchandiseControlSupabase`, repo Android): l’executor potrebbe non avere accesso in lettura — in tal caso dichiarare **NON ESEGUITO** per le parti interessate, registrare causa, e non APPROvare completamento audit finché il materiale non è disponibile **oppure** fornito come export allegato dall’utente.

### 15. Execution runbook futuro — solo dopo approvazione

Runbook ordinato **solo per la futura Execution**, dopo esplicito passaggio di fase. **Questo runbook è preparatorio per la futura Execution; non autorizza l’esecuzione in questa fase.**

Ordine futuro consigliato:

1. **Percorsi**: verificare accesso in lettura a
   `/Users/minxiang/Desktop/MerchandiseControlSupabase`,
   `/Users/minxiang/Desktop/iOSMerchandiseControl`,
   `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView`
   (se assenti: documentare blocco, vedi §14).

2. **Supabase prima**: migrations; schema SQL; policies/RLS; seed; trigger/funzioni/viste; eventuali tipi generati; `README`/`.env.example` — solo struttura e assenza/presenza, **mai** riportare segreti.

3. **iOS come target principale**: repo locale come fonte principale del mapping app; controllare se utile anche versione GitHub aggiornata; ricostruire modelli SwiftData, `HistoryEntry`, repository/service, import/export.

4. **Android solo riferimento funzionale**: `AppDatabase`; entity Room; DAO; `InventoryRepository`; `ProductPrice` / `ProductPriceSummary`; import/export DB; **ImportAnalyzer** solo per campi generati e regole di dominio dall’Excel.

5. Compilare **mapping matrix** (§5).
6. Compilare **decision log** (§6).
7. Compilare **gap list**.
8. Proporre **follow-up task** ordinati.
9. Controllo finale: **nessun file applicativo modificato**.

### 16. Output file/documenti attesi dalla futura Execution

La Execution futura deve produrre un documento audit **leggibile e centralizzato**, preferibilmente:

`docs/SUPABASE/TASK-033-schema-audit.md`

Se `docs/SUPABASE/` non esiste o la convenzione del repo è diversa, usare **percorso equivalente** sotto `docs/` (creazione cartella solo in Execution, quando si scrive il doc — non ora).

Il documento conterrà:

- Supabase schema summary;
- mapping matrix iOS/Android/Supabase;
- decision log;
- gap list;
- risk list;
- proposta follow-up task;
- nota finale: **nessun codice applicativo modificato**.

In questo **file task** restano tracking, sintesi e **link/riferimento** all’audit; evitare di incollare matrici giganti nel task se rendono illeggibile il tracking.

### 17. Guardrail Git / diff (fase PLANNING ed Execution documentale)

Per **ogni modifica associata al task**:

- Verificare (mentalmente o con `git diff`) che siano cambiati **solo** i file pertinenti allo scope dichiarato; per il planning/refinement del solo task TASK-033 ci si aspetta **unicamente** modifiche a:
  `docs/TASKS/TASK-033-supabase-schema-audit-ios-android-model-mapping.md`
  (salvo quando in Execution sarà autorizzato aggiungere **solo** il documento audit sotto §16).
- Non devono comparire modifiche non richieste a: `.swift`, `.kt`, `.sql`, `.xcodeproj`, `Package.swift`, migration Supabase, né file che contengono **segreti**.

Se il diff tocca altro senza autorizzazione, il deliverable è **non valido** → correggere prima di consegnare o passare fase.

### 18. Priorità sorgenti e regole progetto

- **iOS**: target principale; architettura e naming lato Apple si intendono dall’implementazione iOS.
- **Android**: riferimento funzionale (dominio e comportamento), non template da copiare nel Swift.
- **Supabase**: fonte di verità **remota futura**; in TASK-033 si **legge** lo schema quando si farà Execution, si **non altera**.
- Divergenza **iOS ↔ Android**: documentare; **non** scegliere automaticamente una migration Supabase in questo task.
- Divergenza **Supabase ↔ entrambi**: trattare come **gap** + proposta task futuri.
- **Non inventare** tabelle, colonne né policy finché non emerse da sorgenti reali.
- **Non introdurre** autenticazione/multi-tenant nel perimetro TASK-033 se non già esplicitamente nello schema reale o in task dedicato successivo.

### 19. Invarianti funzionali da preservare

Durante l’audit confrontare sempre con questi invarianti:

- **`barcode`**: chiave di business ricerca/dedupe prodotto; **non** promuovere silenziosamente a PK tecnica remota distribuita.
- **Prodotti, fornitori, categorie**: devono rimanere **mappabili** in uno schema di sync senza rottura di compatibilità con SwiftData/Room (semanticamente, anche se gli ID tecnici divergono).
- **Prezzo corrente sul prodotto** vs **storico prezzi**: concettualmente **separati**; mapping e decision log devono chiarire il legame senza fondere i ruoli senza trace.
- **Storico / `product_prices`**: preservare almeno a livello concettuale tipo acquisto/vendita, **valore**, timestamp o **effective date**, **origine/source** se presente lato client o schema.
- **Supplier/category**: confronto con occhio a normalizzazione (trim, case-insensitivity, regole di unicità).
- **History / fogli generati**: volumi elevati possibili; la prima sync potrebbe **escluderli** — **documentare**, non decidere “in silenzio”.
- **Import/export Excel** e futura sync remota: non devono **distruggere** dati locali esistenti nelle successive fasi (policy conservativa quando si progetta nei follow-up).
- **Prima integrazione futura**: conservativa — read-only / **pull dry-run** prima di eventuale push (coerente con §9).

### 20. Security / secrets / RLS

- **Non** copiare in report/API key/password/token da `.env`, `.env.local`, dashboard Supabase né chiavi private.
- Ammesso riportare: **nomi variabili attesi**, struttura file di esempio, presenza/assenza blocchi configurazione rilevanti.
- **Policy RLS**: sintetizzare il **significato** (chi può leggere/scrivere cosa); non incollare segreti.
- **RLS assente o disabilitata**: documentare come **rischio** o follow-up sicurezza — **non** attivare fix in TASK-033.
- **Nessuna** nuova auth o modello multi-utente nel perimetro di questo task.

### 21. UI/UX — note solo per task futuri

TASK-033 **non modifica** UI/UX.

Per futuri task con UI di sync suggerito:

- Schermata o sezione **nativa iOS** (SwiftUI coerente con l’app), non replica passiva dell’Android.
- **Stati** espliciti: non configurato; pronto; ultimo sync; sync in corso; errore; conflitti.
- **Azioni manuali** visibili: pull; push; dry-run; risolve conflitti (quando sarà nel perimetro dei task dedicati).
- Nessun redesign globale in TASK-033.

### 22. Checklist finale prima di consegnare il Planning

Prima di considerare questo planning consegnabile per review:

- [ ] Il task resta **ACTIVE** / **PLANNING**.
- [ ] Execution resta «Non avviata» nel file task.
- [ ] Nessun codice applicativo modificato nell’aggiornamento corrente.
- [ ] Nessun client Supabase introdotto.
- [ ] Nessuna dependency nuova (`Package.swift` / SPM Xcode invariati per questo task).
- [ ] Nessuna tabella/colonna/policy inventata nella documentazione planning (solo checklist e runbook astratti).
- [ ] Il runbook futuro è chiaro ma **non** eseguito in questa fase.
- [ ] Il diff previsto della modifica «solo planning/refinement» tocca **solo** questo file task.
- [ ] Il prossimo passo dichiarato resta **review utente/Claude**, non Execution.

### 23. Template audit output per futura Execution

La futura Execution userà un **formato uniforme** nel documento di audit (preferibilmente `docs/SUPABASE/TASK-033-schema-audit.md`, vedi §16).

#### 1. Supabase schema summary

Tabella:

| Table/View | Kind | Purpose inferred | Important columns | PK | FK | Unique/index | RLS/policy summary | Notes |
|------------|------|------------------|-------------------|----|----|--------------|---------------------|-------|

Regole:

- compilare **solo** da schema reale;
- **non** inventare colonne;
- tabella o ruolo ambiguo → annotare `unknown / needs decision`.

#### 2. iOS model summary

Tabella:

| iOS file | Model/type | Persistence | Key fields | Relationships | Used by screens/services | Notes |
|----------|------------|-------------|------------|---------------|---------------------------|-------|

Regole:

- iOS è **target principale**;
- annotare campi **solo locali** non candidati alla sync.

#### 3. Android Room model summary

Tabella:

| Android file | Entity/View/DAO | Table/view | Key fields | Relationships | Business role | Notes |
|--------------|-----------------|------------|------------|---------------|-----------------|-------|

Regole:

- Android è **riferimento funzionale**;
- **non** proporre porting 1:1 verso iOS.

#### 4. Mapping matrix

Usare la matrice definita in **§5**.

#### 5. Decision log

Usare il template in **§24**.

#### 6. Gap list

Usare il template in **§25**.

#### 7. Follow-up proposal

Usare il template in **§26**.

### 24. Template decision log

| ID | Topic | Decision | Status | Rationale | Evidence/source | Follow-up |
|----|-------|----------|--------|-----------|-----------------|-----------|

**Status ammessi**:

- `accepted`
- `proposed`
- `blocked`
- `needs user decision`
- `defer to future task`

**Decisioni minime** da coprire nella futura Execution:

- ID locale vs remote ID;
- UUID remoto;
- barcode come chiave business;
- timestamp;
- soft delete;
- conflict policy;
- precisione prezzi;
- normalizzazione supplier/category;
- prezzo corrente prodotto vs storico prezzi;
- sync history / fogli generati;
- RLS / security.

**Regola**: se manca evidenza dallo **schema reale**, non chiudere come definitivo — usare `proposed` o `needs user decision`.

### 25. Template gap list

| ID | Area | Gap | Severity | Impact | Proposed follow-up | Blocker? |
|----|------|-----|----------|--------|--------------------|----------|

**Severity ammessi**: `low`, `medium`, `high`, `blocking`.

**Aree minime** da considerare:

- schema Supabase;
- iOS SwiftData;
- Android Room;
- price history;
- import/export;
- sync metadata;
- RLS/security;
- timestamps;
- soft delete;
- UI sync futura.

**Regola**: TASK-033 (in Execution futura) **documenta** i gap, **non** li corregge.

### 26. Follow-up task boundaries

Confini **propostivi** per task successivi; nessuna creazione di nuovi file in `docs/TASKS/` in TASK-033 salvo richiesta esplicita dell’utente.

> **Nota Review 2026-05-03**: questa sottosezione resta storica del planning. Dopo l’assegnazione reale di `TASK-036` e `TASK-037` a task import/XCTest HTML, la proposta follow-up canonica approvata è nel documento audit: `TASK-034`, `TASK-035`, poi `TASK-038+` per merge/push/sync Supabase.

#### TASK-034 — Supabase Swift dependency + skeleton client read-only

Scope futuro **possibile**:

- dependency Supabase Swift **solo** dopo approvazione dedicata;
- configurazione sicura **senza** segreti hardcoded;
- service **read-only**;
- health check o fetch minimale;
- **nessun** push;
- **nessun** merge su dati locali.

#### TASK-035 — Pull dry-run mapping

Scope futuro **possibile**:

- lettura dati remoti;
- confronto con SwiftData locale;
- report differenze;
- **nessuna** modifica ai dati locali;
- **nessun** push remoto.

#### TASK-038 — Local merge controllato

Scope futuro **possibile**:

- pull selettivo applicato;
- backup / log;
- gestione conflitti di base;
- rollback se necessario.

#### TASK-039 — Push manuale controllato

Scope futuro **possibile**:

- push su azione esplicita utente;
- niente cancellazioni distruttive;
- log conflitti;
- gestione timestamp.

#### TASK-040+ — Sync avanzata

Scope futuro **possibile**:

- conflitti avanzati;
- background sync;
- UI sync;
- multi-device più robusto (se nel perimetro di task dedicati).

### 27. Review gate per approvare il Planning

Checklist per valutare se il planning è **pronto per la review** utente/Claude:

- [ ] Il planning comunica chiaramente che TASK-033 **non implementa** codice.
- [ ] Il runbook futuro (**§15**) è ordinato e non ambiguo.
- [ ] Gli output futuri hanno template concreti (**§23–§26**).
- [ ] I confini dei task successivi sono chiari (**§26**).
- [ ] Le decisioni **non** sono presentate come già prese senza evidenza da schema reale.
- [ ] UI/UX resta fuori scope, con sole note future (**§12, §21**).
- [ ] Security / RLS / segreti sono coperti (**§20**).
- [ ] Il task resta **ACTIVE** / **PLANNING**.
- [ ] Execution resta **Non avviata**.
- [ ] Il diff di questo refinement tocca **solo** questo file task.

**Stato storico al 2026-05-03 (post-approvazione utente EXECUTION-only, prima della Review)**: le righe PLANNING sopra sono **storiche del gate di review**. In quel momento la fase dell’audit documentale era **EXECUTION**, registrata nelle Informazioni generali e nella sezione Execution; il diff autorizzato per TASK-033 includeva anche `docs/SUPABASE/TASK-033-schema-audit.md`. Lo stato finale dopo Review è registrato nelle Informazioni generali, nella sezione Review e in Chiusura.

Se questa checklist è soddisfatta, il planning poteva essere considerato pronto per review (**stato storico del gate planning**).

### Nota tracking — approvazione utente e passaggio a EXECUTION (2026-05-03)

L’utente ha confermato la **review positiva** del Planning e ha autorizzato **EXECUTION** limitata a **audit documentale e mapping** (nessuna modifica a codice applicativo, nessun client Supabase, nessuna dependency). La fase corrente è registrata in **Informazioni generali** e nella sezione **Execution** sotto.

### Handoff post-planning

*(Contesto storico immediatamente prima dell’EXECUTION-only approvata; lo stato aggiornato è in **Informazioni generali** e nella **Nota tracking**.)*

Planning operativo completo e pronto per review utente/Claude. Questa dicitura non autorizza Execution.

- **TASK-033** resta **ACTIVE** / **PLANNING** dopo questo planning.
- **Non avviare Execution** senza **autorizzazione esplicita** successiva alla review.
- **Prossimo passo**: **review finale** del Planning da parte dell’**utente** / **Claude**.
- Dopo una **review positiva**, **l’utente** potrà autorizzare una **futura fase Execution**.
- **Fino ad allora** TASK-033 resta **ACTIVE** / **PLANNING**.
- Solo dopo **approvazione esplicita** si potrà transire verso **EXECUTION** con handoff aggiornato nel file task.
- Eventuali correzioni post-review restano nella sezione Planning o Decisioni.
- La **Execution futura** deve: leggere lo **schema reale** Supabase, compilare audit e matrice/decision log come sopra — **non** implementare client, **non** aggiungere dipendenze, **non** modificare modelli o schema persistence.

---

## Execution (Codex) ← solo Codex aggiorna questa sezione

**Execution avviata su autorizzazione esplicita dell’utente dopo review positiva del Planning. Scope limitato ad audit documentale e mapping; nessuna implementazione codice.**

### Audit documentale — 2026-05-03 (Cursor / Execution)

**Verifica stato task**

- File task: **Stato ACTIVE** e **Fase attuale EXECUTION** confermati.
- Sezione **Execution** già avviata; **Planning** lasciato come storico; **Review** resta `Non avviata`; **Fix** resta `Non avviato`.
- **Chiusura non eseguita**: conferma utente non selezionata e `Data completamento` vuota.
- Nota coerenza tracking al momento dell’Execution: `docs/MASTER-PLAN.md` risultava ancora `TASK-033 ACTIVE / PLANNING`; per vincolo esplicito utente sul diff autorizzato non era stato modificato. In Execution prevaleva il file task, che registrava correttamente `EXECUTION`. Il MASTER-PLAN è stato riallineato in Review dopo approvazione.

**Letto / verificato**

- **Supabase** (`/Users/minxiang/Desktop/MerchandiseControlSupabase`):
  - repo root accessibile in lettura;
  - `supabase/migrations/` letto: 8 migrazioni SQL + README;
  - RLS/policies lette dentro le migrazioni (`shared_sheet_sessions`, `inventory_*`, `inventory_product_prices`, `sync_events`);
  - trigger Postgres tombstone e RPC `record_sync_event` letti dalle migrazioni;
  - `supabase/functions/README.md` letto: nessuna Edge Function reale presente;
  - `docs/` e `TASKS/` Supabase consultati solo come contesto decisionale, non come fonte DDL primaria;
  - `sql/*.sql` rilevati come bozze/candidate/legacy, non usati come schema reale.
- **iOS** (`/Users/minxiang/Desktop/iOSMerchandiseControl`, target principale):
  - `iOSMerchandiseControl/Models.swift`;
  - `iOSMerchandiseControl/HistoryEntry.swift`;
  - `iOSMerchandiseControl/InventorySyncService.swift`;
  - `iOSMerchandiseControl/PriceHistoryBackfillService.swift`;
  - `iOSMerchandiseControl/DatabaseView.swift` per flussi import/export e normalizzazione lookup;
  - ricerca `Supabase`/`supabase` su target e `project.pbxproj` senza match.
- **Android** (`/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView`, riferimento funzionale):
  - `AppDatabase.kt`, `Product.kt`, `Supplier.kt`, `Category.kt`, `HistoryEntry.kt`, `ProductPrice.kt`, `ProductPriceSummary.kt`;
  - `HistoryEntryRemoteRef.kt`, `ProductRemoteRef.kt`, `SupplierRemoteRef.kt`, `CategoryRemoteRef.kt`, `ProductPriceRemoteRef.kt`;
  - `SyncEventModels.kt`;
  - `InventoryRepository.kt` ispezionato solo con grep/sezioni mirate per bridge, pull/push, refs e sync events.

**Sorgenti non accessibili / non verificate**

- **GitHub remoto iOS/Android** non fetchato: audit basato sui cloni locali.
- **Database Supabase hosted/live** non interrogato: possibile drift rispetto alle migrazioni versionate.
- **Seed SQL** non trovato nei path cercati.
- **`.env`, `.env.*`, `.env.example`, `*env*`** non trovati nei path cercati; `supabase/.temp/*` esiste ma non è stato aperto e non è fonte audit.
- Nessuna directory separata `policies/` o `RLS/` trovata; le policy lette sono quelle embedded nelle migrazioni.

**Documento audit aggiornato / confermato**

- Aggiornato **`docs/SUPABASE/TASK-033-schema-audit.md`** con:
  - sezione Sources più concreta su accessibilità e limiti;
  - nota esplicita su `sql/*.sql` candidate/legacy vs `supabase/migrations` come fonte schema;
  - riepilogo iOS ampliato a `PriceHistoryBackfillService.swift` e `DatabaseView.swift`;
  - decisioni aggiunte su sync metadata iOS, perimetro iniziale di sync e timezone client;
  - gap rafforzati su barcode, normalizzazione supplier/category, storico prezzi, history/generated sheets, RLS/live DB e SQL legacy;
  - follow-up TASK-034..038+ riallineati a read-only, dry-run, merge controllato, push manuale e sync avanzata.

**Gap principali confermati**

- iOS non ha bridge `remote_id` / `*_remote_refs` equivalenti ad Android.
- ID locali SwiftData/Room non sono PK distribuite; UUID Supabase resta ancoraggio remoto futuro.
- `barcode` è chiave business/dedupe, non PK tecnica globale cross-device.
- Timestamp misti: catalogo Supabase `timestamptz`, storico prezzi Supabase/Room `text`, iOS `Date`.
- Soft delete/tombstone presente sul catalogo remoto (`deleted_at`), non uniforme su iOS e non presente su righe storico prezzi DDL letto.
- `inventory_product_prices` separa storico prezzi dal prezzo corrente su `inventory_products`; iOS/Android mantengono anche snapshot prezzo corrente sul prodotto.
- Supplier/category possono divergere per case/trim/collation.
- `sync_events` e remote refs sono modellati su Android, non su iOS.
- History/generated sheets richiedono task dedicato: payload JSON/overlay e volumi rendono rischioso includerli nella prima sync.
- RLS e delete-restrict sono verificati da migrazioni, non da introspection live.

**Guardrail confermati**

- Nessun codice Swift modificato.
- Nessun codice Kotlin modificato.
- Nessuna migrazione/schema SQL Supabase modificata.
- Nessuna dependency aggiunta.
- Nessun client Supabase creato.
- Nessuna UI, auth, multiutente, sync reale, push/pull dati reali o refactor introdotti.
- Nessun segreto copiato.

**Stato finale consigliato**

- **Execution documentale completata, pronta per Review Claude/utente**.
- Task **non** chiusa: non impostare `DONE`, non compilare Review/Fix, non impostare Data completamento senza conferma utente.

### Tracking storico — 2026-05-03
- User override iniziale: TASK-032 in pausa (BLOCKED / on hold); TASK-033 attivato; la fase **EXECUTION** documentale sopra rende aggiornata la checklist di avanzamento audit.

---

## Review (Claude) ← solo Claude aggiorna questa sezione
### Review documentale — 2026-05-03

#### Review status
APPROVED.

#### Cosa ho verificato
- Stato iniziale file task: `ACTIVE / EXECUTION`, Execution documentale completata, Review/Fix non avviate e Chiusura non compilata.
- `docs/SUPABASE/TASK-033-schema-audit.md`: presenti e leggibili Scope, Sources inspected, Supabase schema summary, iOS model summary, Android Room model summary, Mapping matrix, Decision log, Gap list, Risk list, Follow-up proposal e Final confirmation.
- Coerenza tecnica con le fonti locali:
  - Supabase: migrazioni reali come fonte DDL primaria, RLS/policies, trigger tombstone, RPC `record_sync_event`, `sync_events`, `shared_sheet_sessions`, soft delete catalogo, distinzione SQL legacy/candidate.
  - iOS: SwiftData come target principale; `Supplier`, `ProductCategory`, `Product`, `ProductPrice`, `HistoryEntry`, servizi import/export/backfill/sync locale citati solo come fonti lette.
  - Android: Room come riferimento funzionale; `AppDatabase`, entity principali, remote refs e sync event model coperti senza proporre porting 1:1.
- Decisioni/gap obbligatori: ID locale vs UUID remoto, barcode business key, timestamp/timezone, soft delete, prezzo corrente vs `product_prices`, supplier/category normalization, precisione prezzi, history/generated sheets, RLS/security, conflict policy conservativa e primo sync read-only/dry-run.
- Guardrail: nessuna implementazione Supabase, nessun client, nessuna dependency, nessuna UI, nessun push/pull reale, nessuna modifica Swift/Kotlin/SQL.

#### Micro-correzioni applicate in review
- In `docs/SUPABASE/TASK-033-schema-audit.md` ho chiarito che il riferimento a `task038` riguarda una migrazione Supabase, non un task iOS.
- Ho corretto la proposta follow-up per evitare collisioni con `TASK-036` e `TASK-037`, già assegnati e DONE nel MASTER-PLAN: dopo `TASK-034` e `TASK-035`, i follow-up Supabase futuri partono da `TASK-038+`. Nessun nuovo file task creato.
- Ho rimosso trailing whitespace storico nel file task perché `git diff --check` lo segnalava e il file era già nel diff autorizzato.

#### Esito
Audit approvato e sufficiente per sbloccare la pianificazione di `TASK-034` e dei task Supabase successivi. `TASK-034` resta solo next candidate / unblocked: non è stata attivata automaticamente.

#### Check review
- ✅ ESEGUITO — Lettura `docs/MASTER-PLAN.md`, file task TASK-033 e documento audit TASK-033.
- ✅ ESEGUITO — Verifica statica delle sezioni audit e dei mapping contro migrazioni Supabase locali, modelli SwiftData iOS e modelli Room Android.
- ✅ ESEGUITO — Verifica scope: nessun codice Swift/Kotlin/SQL modificato in Review.
- ✅ ESEGUITO — Criteri di accettazione TASK-033 verificati: schema reale letto/sintetizzato, mapping documentato, decisioni/gap espliciti, nessun client Supabase implementato.
- ✅ ESEGUITO — `git status --short --untracked-files=all`: diff limitato a `docs/MASTER-PLAN.md`, questo file task e `docs/SUPABASE/TASK-033-schema-audit.md`.
- ✅ ESEGUITO — `git diff --check`: PASS dopo correzione trailing whitespace nel planning storico del file task.
- ✅ ESEGUITO — Build compila: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'generic/platform=iOS Simulator' build` → PASS (`** BUILD SUCCEEDED **`).
- ✅ ESEGUITO — Nessun warning nuovo introdotto: il build log della Review non mostra warning sui file modificati; nessun file applicativo è stato toccato.

---

## Fix (Codex) ← solo Codex aggiorna questa sezione
Non necessario.

*Nota: nessun ciclo FIX separato richiesto; le micro-correzioni documentali sono state applicate direttamente in Review.*

---

## Chiusura

### Conferma utente
- [x] User override 2026-05-03: autorizzata review documentale completa e chiusura DONE se audit/check risultano OK

### Follow-up candidate
- `TASK-034` — Supabase iOS foundation: client config + DTO readonly. **Unblocked / next candidate**, non attivato in TASK-033.
- `TASK-035` — Manual Supabase pull to SwiftData dry-run, dopo fondazione read-only.
- `TASK-038+` — merge locale, push manuale e sync avanzata/history, con ID futuri da assegnare senza riusare `TASK-036`/`TASK-037`.

### Riepilogo finale
TASK-033 completata come audit documentale Supabase/iOS/Android. Il documento `docs/SUPABASE/TASK-033-schema-audit.md` sintetizza schema Supabase da migrazioni, mapping SwiftData/Room, decision log, gap, rischi e follow-up. Nessun codice applicativo, migrazione SQL, dependency, client Supabase, UI o sync reale è stato introdotto.

### Data completamento
2026-05-03
