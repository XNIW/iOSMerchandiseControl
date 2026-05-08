# TASK-070 — Supabase manual sync pull preview read-only planning iOS

## Informazioni generali

| Campo | Valore |
|-------|--------|
| **Task ID** | TASK-070 |
| **Titolo** | Supabase manual sync pull preview read-only planning iOS |
| **File task** | `docs/TASKS/TASK-070-supabase-manual-sync-pull-preview-readonly-planning-ios.md` |
| **Stato** | DONE |
| **Fase attuale** | Chiusura |
| **Responsabile attuale** | Nessuno / Workspace IDLE |
| **Data creazione** | 2026-05-07 |
| **Ultimo aggiornamento** | 2026-05-07 23:15 -04 — Planning review documentale APPROVED_FIXED_DIRECTLY; TASK-070 chiuso **DONE / Chiusura** come planning/gap analysis pull preview read-only. TASK-071 resta execution separata avviata e chiusa con override utente. |
| **Ultimo agente** | Codex / Reviewer+Closer |

## User override controllato

Avvio TASK-070 come **PLANNING + gap analysis tecnica** (repo iOS `/Users/minxiang/Desktop/iOSMerchandiseControl`); analoghi Android/Supabase solo riferimento a rischio, **senza Kotlin**, **senza modifiche backend/SQL**.

Impatto workflow: progetto da **IDLE** a **ACTIVE / PLANNING** con task attivo TASK-070. **TASK-063** resta planning base storica (**manual-first**, no automazione/no background/no Realtime/no baseline bump implicito). **TASK-071** **non viene creato** in questo task.

## Dipendenze e contesto

- **Dipende da**: **TASK-069 DONE**, **TASK-068 DONE** (live wiring pianificato, consumato anche via TASK-069), **TASK-067/066/065 DONE**, **TASK-063** (base architettonica, non riaperto).
- **Riferimento rischio esterni (non baseline di sicurezza iOS)**:
  - Android TASK-068 **PARTIAL** (bulk push live non usato come garante sicuro per iOS).
  - Android TASK-071: mismatch RPC / validation / dataset grandi (`changed_count`) — ricorda fragilità lato backend/app in scenari massivi; **TASK-070 non chiama `record_sync_event`**.
- **TASK-068** resta DONE come **planning precedente**, non rivalutato nel codice.
- **Sblocca** (solo dopo EXECUTION futura pianificata in TASK-071+): fase `.remotePreview` reale nella run guidata, con aggregati cloud user-facing senza apply/push automatici.

## Scopo

Definire un piano tecnico **repo-grounded** per agganciare in futuro la run guidata iOS (`SupabaseManualSyncCoordinator`) a una **preview remota solo lettura**: leggere uno snapshot/cloud diff **senza** applicare nulla localmente e **senza** scrittura remota, distinto da push/drain/outbox baseline writer.

Obiettivo utente UX (futura, non Execution qui): permettere alla card «Sincronizzazione cloud» di discriminare chiaramente (con copy non tecnico):

- tutto aggiornato sul piano **locally actionable** quando appropriato;
- modifiche **locali** da controllare (già TASK-069);
- **dati sul cloud da controllare** (nuova informazione dall’analisi preview);
- eventuale necessità di **riallineare dal cloud** (già gated baseline/auth oggi, da arricchire con segnali preview).

---

## Anti-scope rigido TASK-070

Task **solo markdown / planning**:

- NO Swift applicativo / NO `project.pbxproj`.
- NO `OptionsView`.
- NO `Localizable*` / chiavi nuove *(in **TASK-070**; **D70-14** impone invece che la **futura** EXECUTION che espone copy Release usi **IT/EN/ES/ZH-Hans**)*.
- NO codice XCTest / NO esecuzione suite.
- NO chiamata Supabase **live obbligatoria** (solo lettura codice/repo).
- NO apply locale (nessun path `SupabasePullApply*` in Execution da questo planning).
- NO push remoto, NO drain/flush outbox, NO enqueue.
- NO `SupabaseCatalogBaselineWriter` nell’orbita preview read-only pianificata.
- NO ProductPrice **live push**.
- NO SQL / migration / `db push` / RPC / RLS / schema.
- NO modifiche Android / backend esterni.
- NO Timer / `BGTask` / Realtime / worker / polling.
- NO «full sync» come obiettivo immediato della slice preview.
- NO cleanup/delete outbox dalla preview.
- **NO creazione file `TASK-071*.md`**.
- NO marcare questo task DONE senza planning review dedicata (`CHANGES_REQUIRED`/`REJECTED` → planning fix).

---

## Criteri di accettazione (planning TASK-070)

| ID | Criterio | Stato |
|----|----------|-------|
| CA70-01 | File TASK-070 creato e path coerente con MASTER-PLAN `File task`. | [x] |
| CA70-02 | MASTER-PLAN aggiornato durante planning (storicamente ACTIVE / PLANNING / task attivo / ultimo DONE TASK-069) e riallineato in chiusura a IDLE / TASK-071 ultimo completato. | [x] |
| CA70-03 | `SupabasePullPreviewService` e dipendenze **inventariate** (dati letti, paginazione, partial, side effects vs apply). | [x] |
| CA70-04 | Rischi read-only remoti chiari + legame a TASK-063 manual-first/sicurezza. | [x] |
| CA70-05 | UX user-facing **proposta** senza jargon in Release per stati preview (vedi §UX). | [x] |
| CA70-06 | Matrice test **futura** (non eseguite ora) prima di EXECUTION. | [x] |
| CA70-07 | Anti-scope completo e decisioni **D70-01…D70-26** compilate e coerenti. | [x] |
| CA70-08 | Nessun `.swift`/backend modificato dalla sessione TASK-070. | [x] `git diff` solo `docs/*` |

---

## Decisioni TASK-070 (D70)

| ID | Decisione |
|----|-----------|
| **D70-01** | TASK-070 è **planning-only**; non autorizza EXECUTION Codex né PR Swift. |
| **D70-02** | La **pull preview** pianificata è **solo lettura dal cloud nel perimetro network** orchestrato dal servizio di fetch inventariato (`SupabaseInventoryFetching` → SELECT paginati); **nessun apply** SwiftData dall’analisi nella slice preview. |
| **D70-03** | Dopo preview read-only nella run guidata, **nessun push automatico** (catalog/ProductPrice/events). |
| **D70-04** | **`SupabaseCatalogBaselineWriter`** non deve essere coinvolta nella preview; resta solo per scenari pull-apply confermati in task dedicati storici (**TASK-040** ecc.), non nell’orbita TASK-071 preview-only. |
| **D70-05** | **Nessun outbox flush/drain/enqueue** collegato alla fase `.remotePreview` read-only pianificata. |
| **D70-06** | Nessun uso di **`confirmationDialog`** nel planning TASK-070; una conferma UX nativa sarà ripresa **solo** se un task futuro introducesse **apply/write** dopo preview (fuori TASK-071 preview-only suggerito). |
| **D70-07** | L’output preview verso SwiftUI deve restare **privacy-safe**: **aggregati e contatori**, niente liste di barcode/identità remota nei messaggi pubblici TASK-067. |
| **D70-08** | Gli errori remoti/decodifica/RLS vanno progettati per mapparsi in **messaggi user-facing non tecnici**, **localizzabili** IT/EN/ES/ZH-Hans in fase di EXECUTION futura (vedi **D70-14**); il mapping sorgente resta da `SupabasePullPreviewError` / `SupabaseInventoryServiceError`. |
| **D70-09** | La preview deve essere **budgetata/paginata** come oggi in `SupabasePullPreviewPager` + `pageSize` clamp; il limite di completezza va **comunicato all’utente solo quando** il risultato è **partial** o **budget-limited** (**D70-13** / §UX), non in ogni caso. |
| **D70-10** | **TASK-071** può essere proposto testualmente più sotto; **non** creare ora il relativo file task. |
| **D70-11** | La preview read-only futura **può essere progettata** per eseguire anche con **`pending locali == 0`**, perché il cloud può differire da quanto è visibile nei soli aggregati locali; è **decisione UX/prodotto** da confermare in Planning Review prima di qualsiasi EXECUTION. |
| **D70-12** | Se **`pending locali > 0`**, la preview remota **non** deve far partire **apply** né **push**; arricchisce **solo** summary / copy user-facing (inform-only). |
| **D70-13** | Se il fetch remoto **supera budget/paginazione** e il risultato è **partial**, la UI deve comunicare **«Controllo cloud incompleto»** (o equivalente localizzato), **mai** «tutto aggiornato» / successo pieno ingannevole. |
| **D70-14** | **Nessun** nuovo copy Release **solo italiano hardcoded** nel ViewModel/SwiftUI pubblico: qualunque stringa **visibile all’utente in Release** da una futura EXECUTION va aggiunta **localizzata IT/EN/ES/ZH-Hans nello stesso task** *oppure* — se non localizzabile in quel task — resta **solo** in strati interni/non visibili (**TASK-070** stesso resta **senza** modifiche `Localizable`, per anti-scope). |
| **D70-15** | **Cancellation** durante la preview remota deve mapparsi a **«Controllo cloud annullato»** / stato **non-success** esplicito; **mai** **`Tutto aggiornato`** / equivalente che suggerisca verifica completata positivamente. |
| **D70-16** | La preview read-only resta **opzionale**, **bounded**, avviata dall’utente (vedi §Policy pending zero): **no** loop automatico, **no** retry aggressivo nella pipeline pianificata, **no** polling/timer/background (**coerente** con TASK-063 manual-first). |
| **D70-17** | La futura preview remota deve essere avviata da **gesto utente esplicito**, preferibilmente una **CTA semantica** tipo **«Controlla cloud»** (o equivalente localizzato); **vietato** come trigger principale: **`onAppear`**, **timer**, **automatico** subito dopo aggiornamenti dello stato «pending locale» o messaggi tipo «Tutto aggiornato» (**non** avviare la preview cloud come effetto collaterale di quel risultato). |
| **D70-18** | **Pending locali** e **segnali cloud** restano **dimensioni separate** nel `RunSummary` / modello di presentazione: non **sovraccaricare** lo stato user-facing **«Sincronizzazione parziale»** (`partialSync` / copy analoghi) per indicare una **preview read-only incompleta** — usare invece la famiglia **«Controllo cloud incompleto»** (**D70-13**, §UX). |
| **D70-19** | La futura UI deve **distinguere** **«modifiche locali da controllare»** da **«dati cloud da controllare»**; se lo spazio è limitato: **una frase sintetica** + **dettaglio secondario**, **non** due card concorrenti; restare **compatto** nello stile della sezione **OptionsView** esistente (**senza** progettare qui modifiche a `OptionsView`). |
| **D70-20** | Nella **prima micro-slice TASK-071**, la **preview remota ProductPrice** resta **deferred / esclusa**, salvo se il servizio sottostante (`fetchProductPricesPage` già in `SupabasePullPreviewService`) la rende **inevitabile** tecnicamente: in quel caso solo **aggregati** e **mai** dettaglio user-facing su storico prezzi in Release. |
| **D70-21** | **`SupabaseManualSyncRemotePreviewSummary`** **non** incorpora né espone l’intero **`SyncPreview`** alla UI Release: deriva **solo** flag e conteggi aggregati (vedi §Adapter — modello concettuale «piccolo DTO»). |
| **D70-22** | Se la preview cloud viene agganciata al **coordinator**, deve essere **feature-gated** tramite **dependency injection** (provider opzionale / fake) e **testabile senza rete live** nello stesso spirito del dry-run TASK-065. |
| **D70-23** | La **micro-slice TASK-071 consigliata** deve partire da **adapter + mapper + coordinator** con **copertura test** nei limiti del task futuro; **preferibilmente** **senza** modificare **`OptionsView`** (restare su strati orchestrazione / DI / XCTest dove possibile). |
| **D70-24** | **TASK-071** (quando autorizzato) **non** deve introdurre **nuove** stringhe **Release** / **`Localizable`** **se** la slice **non** espone **nuovi** stati o messaggi **visibili** all’utente in superficie pubblica; **se** li espone, devono essere **localizzati IT/EN/ES/ZH-Hans nello stesso task** (coerente con **D70-14**, qui reso esplicito per il perimetro TASK-071). |
| **D70-25** | La **Planning Review** di TASK-070 **non** impone **build**, **xcodebuild** né **test suite** come obbligatori: la verifica **primaria** è **documentale**; tool di build/test restano **opzionali** e solo se il **reviewer** li sceglie esplicitamente. |
| **D70-26** | TASK-070 può essere **chiuso** come planning (**DONE / Chiusura** task, dopo review **APPROVED** + utente) **anche se** **`TASK-071*.md` non viene mai creato**: lo scopo di TASK-070 è **decisioni, criteri e handoff documentale**, non impegnare l’implementazione della preview remota. |

---

## Planning (Claude): gap analysis tecnica repo-grounded

### Stato dopo TASK-069 (cosa c’è oggi)

- **Release factory** (`SupabaseManualSyncReleaseFactory`): auth gate + baseline reader + **`SupabaseManualSyncLocalPendingSnapshotProvider`** reale per `catalog`/`outbox` aggregates; **`SupabaseManualSyncReleaseDryRunPhaseSimulator`** resta **`simulateRemotePreview → .completed` fisso**.
- **`SupabaseManualSyncCoordinator`**: pipeline **solo `dryRun` eseguito**; `guidedManual`/altri bloccati. Se `privacyCounts.hasAnyPendingWork == false`, `markNoWorkSkips` **salta sempre** `.remotePreview` … `.finalRefresh` ⇒ nessuna informazione «cloud diverso anche senza pending locale» nella run attuale.
- **`SupabaseManualSyncViewModel`**: mappa stato pending locale («Ci sono modifiche da controllare» quando `completedSuccessfully && pending`), **nessun campo** circa «interesse cloud».

### Servizi esistenti rilevanti (read path)

| Componente | Ruolo chiave |
|-----------|---------------|
| `SupabasePullPreviewService` | Orchestratore: fetch paginati remoto tramite **`SupabaseInventoryFetching`**, lettura SwiftData **`SwiftDataInventorySnapshotService`** (solo lettura locale), diff in-memory `SupabasePullPreviewDiffEngine` → `SyncPreview` / **`SupabasePullPreviewViewState`**. |
| `SupabaseInventoryService` (+ protocol `SupabaseInventoryFetching`) | **SELECT owner-scoped/paginated** inventory tables; errore taxonomy `SupabaseInventoryServiceError` (config, session, network, RLS, decode, drift). Actor separato dall’analisi TASK-070. |
| `SupabasePullApplyService` | **Non usare nella preview pianificata** — applicazione locale post-preview; incluso nel repo solo come confine («cosa NON fare»). |
| `SupabaseCatalogBaselineReader` | Già in Release baseline gate (**lettura SwiftData baseline** manual push fingerprint). Preview read-only pianificata **non** deve scrivere baseline. |

### Risposte alle domande del brief

1. **Isolamento dietro protocolli/fake**  
   - **Si, parzialmente**: il fetch remoto è dietro **`SupabaseInventoryFetching`** (ottimo per XCTest fake).  
   - **Gap**: la struct pubblica **`SupabasePullPreviewService`** non espone ancora un **protocol dedicate** tipo `ManualSyncRemotePreviewing` vista dal coordinator/DI TASK-065; l’isolamento migliora introducendo **`SupabaseManualSyncRemotePreviewProviding`** (concept §Adapter).

2. **Solo read remoto / effetti collaterali**  
   - Rete: **solo GET/paginated select** lungo il percorso `fetch*Page` (nessuna insert/update orchestrata dal preview service).  
   - Locale: **`ModelContext`** usato tramite **`SwiftDataInventorySnapshotService`** — è **solo lettura** per produrre snapshot; **nessun salvataggio** nel file `SupabasePullPreviewService`.  
   - CPU: heavy diff su `Task.detached` dentro `generatePreview`.

3. **Paginato/bounded**  
   - **`pageSize` default 500, clamp `1…1000`**. Funzione **`fetchPaged`** con `rowBudget` opzionale: se si esaurisce il budget → **`isPartial: true`** (catalogo marcato partial + warning codice `.sourceError` / storico `.priceHistoryIncomplete`).

4. **Dataset grandi**  
   - Loop pagina-per-pagina fino budget o fine stream corta; dopo budget **partial garantito**.  
   - **Limite progettuale**: `SyncPreview` può contenere liste di sintesi/conflict voluminose ⇒ per Release serve **solo aggregazione sintetica** (D70-07/D70-09), non liste complete in UI pubblica TASK-067.

5. **Auth/sessione scaduta**  
   - In catena Inventory: `sessionMissing` / `.networkError` / `.permissionDeniedOrRLS`; preview mappa **`SupabasePullPreviewError.service(_)`**.  
   - Il gate **`SupabaseManualSyncReleaseAuthGate`** oggi controlla `isSignedIn` ma **non** anticipa expiry fine-grained ⇒ possibile errore tecnico quando la session SDK scade **tra** gate e fetch (da gestire nel mapper come `.failedRetryable` / messaggio Sign-in suggerimento).

6. **Partial/network/RLS/schema**  
   - Per-tabella **`catch`**: array vuoti + **`SyncPreviewWarning`**/`partialCatalog`; non abort dell’intera preview come eccezione (products block simile). Product prices aggiunge warning incompleto anche su catch.  
   - **Mapping UX**: distinguere connectivity generica (.failedRetry / retryable coordinator) vs blocco tecnico-soft (technical follow-up).

7. **Tipi output oggi**  
   - `SupabasePullPreviewViewState`: `success(SyncPreview)`, `partial(SyncPreview, warnings:…)`, `failed(SupabasePullPreviewError)` (+ idle/loading nei modelli).  
   - `SyncPreview`: metric counts, classifications (`newProducts`, `updateCandidates`, `conflicts`, `tombstones`, `warnings`, `priceHistoryDiffs`, …).

8. **Verso `SupabaseManualSyncPhaseOutcome`**  
   - Mapper dedicato suggerito: **`SupabaseManualSyncRemotePreviewOutcomeMapper`** trasforma stato preview logico (**`complete`**, **`partial`**, **`failed`**, **`cancelled`**) estratto da `.success`/`.partial`/`.failed` + **`Task`/cancellation**, + estratti aggregati (**non** preview intero pubblicato in UI Release) → `.completed`/`.partial`/`.failedRetryable`/`.blocked`/`.cancelled` conforme TASK-065 (**D70-15**: cancelled **≠** «tutto aggiornato»).  
   - Preservazione informazione interna tramite **`SupabaseManualSyncRemotePreviewSummary`** (solo aggregati/contatori + flag di interesse UX da definire in EXECUTION, es. equivalente ai concetti «differenze rilevanti» / «fetch incompleto») dentro `SupabaseManualSyncRunSummary` (campi nuovi consentiti nel task EXECUTION futuro).

9. **Evitare preview → apply automatico**  
   - Non invocare `SupabasePullApplyService` nel coordinator/Task preview-only; EXECUTION TASK-071: **solo** dopo review, nessuna transizione programmatica dalla preview a apply senza nuovo mode + conferma progettuale futura (**D70-06**).

10. **Evitare preview → push automatico**  
    - Stesso ostacolo orchestratore: dopo `.remotePreview` mapping a outcome **`completed`** o **`partial`**, le fasi successive `catalogPush`… devono rimanire **simulate** finché `guidedManual` non è abilitato; quando abilitato, policy esplicita: **run preview-only** deve terminare prima di qualsiasi push (stub no-op / skip fisso TASK-071 variante suggerita **«previewTerminatedRun`**).

11. **UI Release — stati distinguibili senza «sync completata» ingannevole**  
    - **`Controllo cloud completato`**: usarlo **solo** se la preview è **completa** (non partial per budget/troncamento) **e** le soglie/decision logic interne ritengono **assenti «differenze rilevanti»** tra cloud/locali (definizione «rilevanti» va fissata in EXECUTION/TASK futuro — es. buckets aggregati sopra soglia UX). *(Copy finale: **solo** tramite **`Localizable` IT/EN/ES/ZH-Hans** quando la stringa è visibile in Release — **D70-14**.)* Nota breve consentita come secondaria: **«Nessuna modifica è stata salvata sul dispositivo»**.  
    - **«Ci sono dati sul cloud da controllare»**: quando ci sono **segnali remoti/locali da rivedere** (mapper aggregati; **mai** liste di barcode/UUID in Release — **D70-07**).  
    - **«Controllo cloud incompleto»**: quando **`SupabasePullPreviewViewState`** è **partial** o budget-limitato (**D70-13**) — non presentare come successo pieno.  
    - Baseline mismatch: **`Serve riallineare i dati dal cloud`** come oggi. Errore generico recuperabile: **«Controllo cloud non riuscito. Puoi riprovare.»**  
    - Mai usare **`SupabaseManualSyncUserFacingCopy.syncFinishedSuccessfully`** dopo una preview read-only con mismatch o dopo partial/cancelled (**D70-15**).  
    - **`Nessuna modifica è stata salvata sul dispositivo`**: sempre **breve**, come nota **secondaria**; non deve sostituire il titolo principale quando lo stato è «incompleto» o «serve controllare».

12. **Test prima EXECUTION futura**  
    - Vedi § matrice più sotto (unit/coordinator mapper/ViewModel static/fake Inventory). **Non obbligatori live RPC** prima di primo merge logica.

13. **Prossimo micro-task (testuale TASK-071, file non creato)**  
    - Vedere § «Micro-slice TASK-071 consigliata», § «Definition of Ready — futura TASK-071 Execution» e § «Checklist per chiusura planning TASK-070» più sotto.

---

### Rischi tecnici principali

- **Bypass preview se pending locale zero** (`markNoWorkSkips`): impedisce stato «cloud da controllare» senza ridefinire quando eseguire preview (priorità PLANNING dopo review).
- **Volume dati SyncPreview**: necessità di **solo aggregati UI** contro completezza tecnica interna XCTest/UI DEBUG eventuale.
- **Baseline vs preview**: anche con baseline OK, remoti possono contenere modifiche ⇒ preview necessaria anche **senza pending locale** se prodotto lo richiede (decision review).
- **`SyncPreviewProductSummary.applyPayload`**: campo esiste dentro modello tecnico ⇒ rischio uso accidentale futuro ⇒ EXECUTION deve confinare DTO pubblici Coordinator.
- **Rischio Android/071**: mismatch contrattuali/eventi quando si integrano operazioni bulk — non applicabile alla preview perché **`record_sync_event` escluso** (D68/D70), ma avvisa sulla qualità datasets massivi quando si interpretano «partial».
- **Costo latenza/traffico/cpu**: preview remota paginata su cataloghi grandi può essere **lenta/costosa** (rete/batteria/dispositivi datati); mitigation: **solo** dopo tap utente, **budget**, **cancellation** (**D70-16**, **D70-15**).
- **UI «ansiosa»**: se **ogni** partial tecnico viene trattato come errore forte, si perde fiducia; serve tono neutro («incompleto» / ripeti più tardi), coerente con **D70-13**.
- **Falso positivo «cloud da controllare»**: aggregazione mapper troppo **sensibile** → troppi falsi positivi; mitigazione: soglie/flag reviewate e test di mapper XCTest (**§ matrice test**).
- **Confusione concettuale**: utente interpreta «controllo cloud» come **riallinea/applica già fatto**; mitigazione: copy sempre **solo lettura** + nota salvataggio (**D70-02**, **§UX**).
- **Localizzazione incompleta**: nuovi stati user-facing solo in IT o parziali in EN/ES/ZH-Hans — viola **D70-14** e incoerenze TASK-068/TASK-067 cultura Release.
- **Overload semantico (stesso stato per cose diverse)**: riusare **pending locale**, **preview cloud partial** e **sync parziale post-mutazione** sullo **stesso** canale UI (es. `partialSync`) può confondere — mitigazione: family copy distinte (**D70-18**) e eventualmente **`presentationKind`** dedicati in EXECUTION.
- **UI troppo densa in OptionsView**: seconda azione/copy senza hierarchy chiara ⇒ fatica cognitiva; mitigazione: **titolo + sottotitolo** compatto (**D70-19**), una CTA semantica (**D70-17**).
- **Leak dettagli diff remoto**: elenchi tecnic, SKU, UUID in Release — vietato (**D70-07**, **D70-21**).
- **ProductPrice troppo presto**: allargare la slice con storico/prezzi visibili ⇒ TASK-071 non è più micro; mitigazione: **defer** (**D70-20**) salvo inevitabile e solo aggregato.

---

### Policy proposta — pending locali zero

**Scelta consigliata definitiva del planner (subject a Planning Review): scenario A** — la preview remota read-only **è ammessa anche con `pending locali == 0`**, ma **unicamente** dopo **CTA utente esplicita e semantica** (es. **«Controlla cloud»** / equivalente localizzato — **D70-17**).

Punti chiave:

- **Non deve partire automaticamente** dopo aver mostrato «Tutto aggiornato» o dopo un run dry-run locale con zero pending: la preview cloud è una **seconda verifica informativa**, **non** una sync né un follow-up obbligatorio del messaggio «tutto OK» locale.
- **`pending == 0` è un esito valido** del **controllo locale** (TASK-069), ma **non** prova **parità** con il cloud; il cloud può contenere modifiche non riflesse nei soli aggregati pending.
- La preview cloud **non sostituisce** né **combina semanticamente** con «sync»: è **lettura/diff informativo** bounded, senza apply/push (**D70-02**, **D70-03**).

**Mitigazione se la review vuole ridurre traffico:**
- **Scenario B)** (alternativa conservativa): preview **solo** se **`pending locali > 0`**. Minor valore diagnostico sul cloud-vs-local senza pending.
- Il reviewer segnala **A o B** nella §Planning Review Checklist.

Coerenza con **TASK-068 / TASK-069**: TASK-069 chiude il micro-step **solo locale**; TASK-068 ha mappato il wiring futuro — questa policy aggiunge l’ingresso preview **senza** conflitto con **D68-04**.

---

### UX futura — pull preview read-only (senza jargon in Release TASK-067)

Regola generale (**D70-14**): **qualunque stringa che appare nella UI Release/card TASK-067** deve passare da **`Localizable` IT/EN/ES/ZH-Hans** nella stessa EXECUTION futura; *questo* documento TASK-070 usa italiano solo come **esempio di semantica**, non come approvazione di stringhe hardcoded nel codice.

**Separazione semantica obbligatoria**

- **Non** usare **«Sincronizzazione parziale»** (né stati/coordinator **`partialSync`** se creano ambiguità) per una **preview read-only partial**: quel linguaggio suggerisce **sync già in corso / invii parziali**. Per preview partial → **«Controllo cloud incompleto»** (**D70-13**, **D70-18**).
- **Pending locali**: usare messaggi nella famiglia **«Ci sono modifiche locali da controllare»** (o equivalente TASK-069), **distinti** dai messaggi cloud (**D70-19**).
- Layout: **una** card/compatta area nello **stile** `OptionsView` — **titolo sintetico** + **dettaglio secondario** se serve; **evitare** due card concorrenti.

**Quando usare ciascun messaggio (semantica)**

| Condizione (logica interna) | Messaggio principale (es. IT — da localizzare) |
|----------------------------|-----------------------------------------------|
| **Pending locali** / contatori locali > 0 (TASK-069) | **«Ci sono modifiche locali da controllare»** (o copy equivalente già allineato TASK-069) |
| Preview **completa** (non partial/budget-limited) **e** nessuna **differenza rilevante** definita in EXECUTION | **«Controllo cloud completato»** |
| Segnali di differenze cloud/locali da rivedere (aggregati oltre soglia / flag mapper) | **«Ci sono dati cloud da controllare»** |
| Preview **partial** o **budget-limited** | **«Controllo cloud incompleto»** — **non** «Sincronizzazione parziale» |
| Errore di rete/recuperabile | **«Controllo cloud non riuscito. Puoi riprovare.»** |
| **Cancellation** esplicita | **«Controllo cloud annullato»** (**D70-15**) |
| Baseline/auth non validi (già oggi) | **«Serve riallineare i dati dal cloud»** / **«Serve accedere di nuovo»** (flow esistente) |

**Nota secondaria (sempre breve, solo se serve chiarezza)**  
- **«Nessuna modifica è stata salvata sul dispositivo»** — **sottotitolo** breve durante/dopo preview informativa; **non** sostituisce titoli «incompleto» / «da controllare» / pending locale.

**Messaggio su estratto / campione (non sempre)**  
- Mostrare **solo** se il risultato è **partial** o **budget-limited**; **non** ripetere in ogni run completa (**D70-09**).

**Evitare nei testi pubblici Release/card TASK-067**

- `outbox`, `drain`, `sync_events`, `RPC`, `payload`, `retryable`, `JSON`, `UUID`, `record_sync_event`

*(Le chiavi tecniche interne e `hintKey` per opzioni avanzate restano dove già consolidate — non devono essere mostrate nella card Release TASK-067.)*

---

### Adapter design concettuale *(no codice, fakeable/testabile)*

**`SupabaseManualSyncRemotePreviewProviding`** (concept) deve garantire tutto quanto segue progettazione:

| Requisito | Nota |
|-----------|------|
| **Fakeable/testabile** | Doppio di test iniettabile senza Supabase live; combinare con **`FakeSupabaseInventoryFetching`**. |
| **Nessun apply** | Non invocare `SupabasePullApplyService` né mutare SwiftData dai risultati di preview. |
| **Nessuna scrittura SwiftData** | Letture solo per snapshot/diff dove serve (come oggi `SwiftDataInventorySnapshotService`); **vietato** `save`/insert/delete dal provider. |
| **Niente baseline writer** | Vietato **`SupabaseCatalogBaselineWriter`** in quest’orbita (**D70-04**). |
| **Solo summary aggregato** verso Coordinator/UI pubblica | Output consumer-facing limitato a **`SupabaseManualSyncRemotePreviewSummary`** (numeri sicuri). |
| **Niente liste prodotti/barcode/UUID esposti a Release** | Dettaglio tecnico eventualmente rimane in XCTest/UI DEBUG/non-Release (**D70-07**). |
| **`Task` cancellation propagata** | `withTaskCancellationHandler` / `checkCancellation`; esito **`cancelled`** distinto (**D70-15**, **D70-16**). |
| **Risultati logici**: `complete` / `partial` / `failed` / `cancelled` | Anche se l’implementazione interna rimappa da `SupabasePullPreviewViewState`, il boundary verso Coordinator deve essere esplicito. |
| **Policy budget/pagination esplicita** | Parametro o value type configurabile (catalog/productPrice caps coerenti con pager), **mai** paging infinito implicito (**D70-16**). |

**`SupabaseManualSyncRemotePreviewSummary` — modello concettuale (non API Swift vincolante)**

- Deve essere un **DTO piccolo**, **privacy-safe**, **non** un wrapper dell’intero **`SyncPreview`** e **non** esposto raw alla UI Release (**D70-21**).
- Campi **concettuali** ammessi (nomi indicativi; EXECUTION può rinominare):  
  - `hasRemoteSignals` — c’è qualcosa da segnalare all’utente sul cloud (soglia da definire).  
  - `isComplete` — fetch/diff ha coperto il perimetro budgetato senza troncamento «partial» lato prodotto.  
  - `isPartial` — budget/pager ha prodotto risultato incompleto (**D70-13**).  
  - `wasCancelled` — utente o task annullato (**D70-15**).  
  - `safeAggregateCounts` — solo **numeri** aggregati (bucket), **zero** identificativi business.  
  - `recommendedUserMessageKey` — **chiave** verso `Localizable` (non stringa letterale in Release).  
- **Vietato** nel summary verso Release: barcode, nomi prodotto, fornitore/categoria, **UUID**, **JSON**, payload raw, righe di diff.

**Altri tipi nell’orbita orchestratore**

- **`SupabaseManualSyncPullPreviewAdapter`**: wrapping `SupabasePullPreviewService` + applicazione delle policy sopra senza perdere cancellation.  
- **`SupabaseManualSyncRemotePreviewSummary`**: vedi blocco concettuale sopra; in EXECUTION i conteggi restano **safe-by-construction** (no campi identificativi).  
- **`SupabaseManualSyncRemotePreviewOutcomeMapper`**: da stato logico `complete`/`partial`/`failed`/`cancelled` + summary → `SupabaseManualSyncPhaseOutcome` + **chiavi `Localizable` o metadati** per copy (non stringhe hardcoded Release — **D70-14**); **evitare** di mappare preview partial su stati **`partialSync`** se generano ambiguità con sync reale (**D70-18**).

Testing futuro: **`FakeSupabaseInventoryFetching`**, paging parziali, `.networkError`, RLS simulate, truncation pages; test dedicati a **cancellation** → stato non-success (**D70-15**).

---

### Matrice test futura *(non eseguita in TASK-070)*

| Area | Piano |
|------|--------|
| `SupabasePullPreviewPaginationTests` / `DiffEngineTests` existenti | Regressione obbligatoria dopo toccare pager/diff (**già nel repo**) |
| Nuovi test mapper | Table-driven: `complete`/`partial`/`failed`/`cancelled`/`service(sessionMissing)` |
| Coordinator XCTest (`SupabaseManualSyncCoordinatorTests`) | Estensioni con fake `RemotePreviewProviding` verifying **no successive phase** when preview-only termination policy |
| `SupabaseManualSyncViewModelTests` | PresentationKind nuovi **senza jargon** assertions |
| `SupabaseManualSyncRelease*` static grep | No nuove stringhe forbid list in Release-facing files |
| Simulator | Opzionale, solo dopo task execution che lo richieda esplicitamente |

---

### Definition of Ready — futura **TASK-071** Execution *(proposta testuale, file non creato)*

**Checklist prerequisiti (tutti da segnare prima di EXECUTION TASK-071):**

- [ ] **TASK-070** Planning Review completata ed **approvata** (o ciclo `CHANGES_REQUIRED` chiuso su markdown solo).
- [ ] **Policy `pending == 0` vs preview solo con `pending > 0`** decisa (scenari **A/B** nella §Planning Review Checklist).
- [ ] **Budget/paginazione** preview catalogo / product prices **definiti** e documentati (coerenti con pager esistenti).
- [ ] **Mapper preview → `SupabaseManualSyncPhaseOutcome` + gestione partial/cancelled** definito a livello di specifica (ancora **senza** Swift in TASK-070).
- [ ] **Nessun apply / push / drain** nel perimetro TASK-071 preview-only **confermato** in review.
- [ ] **Nessun `SupabaseCatalogBaselineWriter`** nel perimetro preview-only **confermato**.
- [ ] **UX copy** per stati nuovi: **chiavi `Localizable` IT/EN/ES/ZH-Hans** pianificate nello **stesso** task EXECUTION che le espone (**D70-14**), oppure confermare che la slice **non** introduce stati visibili nuovi ⇒ **nessuna** stringa Release aggiuntiva (**D70-24**).
- [ ] **Matrice test** (mapper, coordinator fake, cancellation, partial) **pronta** come elenco accettato.
- [ ] Deciso se **TASK-071 modifica o non modifica la UI** (preferenza: **minimo impatto**, vedi §Micro-slice).
- [ ] Deciso se la **prima EXECUTION** resta **solo** adapter/mapper/coordinator (+ test), **senza** `OptionsView` se non strettamente indispensabile.
- [ ] **ProductPrice** nella prima slice: **deferred** vs **solo aggregato** se ingest tecnico inevitabile — decisione firmata (**D70-20**).
- [ ] **`SyncPreview`** raw **non** esposto alla UI Release (solo dentro stack adapter/test se serve — **D70-21**).
- [ ] **Test fake senza rete live** inclusi nella definizione del task EXECUTION (**D70-22**).
- [ ] **Fallback UX** quando il preview service produce **`partial`** (copy «incompleto», ripetizione sicura — **D70-13**) documentato prima del codice.
- [ ] **User override esplicito** per **creare** il file `TASK-071*.md` e avviare EXECUTION.

**Contenuto tecnico minimo proposto (dopo i prerequisiti sopra):**

1. Implementare protocol **`SupabaseManualSyncRemotePreviewProviding`** + **`SupabaseManualSyncRemotePreviewSummary`** + **`SupabaseManualSyncRemotePreviewOutcomeMapper`** (coerenti con §Adapter), XCTest con **fake** `SupabaseInventoryFetching`.  
2. Estendere `SupabaseManualSyncCoordinator.Dependencies` con provider preview opzionale (**default `nil`** ⇒ parity TASK-069) o doppio di test deterministico quando `guidedManual` non è ancora abilitato in produzione.  
3. Allineare la **policy di invocazione** al risultato della review (**A**: preview anche con pending zero da CTA dedicata vs **B**: solo con pending > 0).  
4. Estendere `SupabaseManualSyncFinalUserState` / `presentationKind` per stato **solo informativo** cloud (mai `syncFinishedSuccessfully` fuori contesto TASK-065 post-mutazioni).  
5. **OptionsView**: modifiche solo se strettamente necessarie; dove possibile cambi solo a ViewModel / coordinator / summary. Nuove stringhe **Release** ⇒ **solo** tramite **`Localizable` quattro lingue**, nello stesso PR/task (**D70-14**) — vietato intentionalmente il «solo IT hardcoded» in superficie pubblica Release.

**Blocchi dichiarativi EXECUTION TASK-071** se non chiari dopo review TASK-070: trade-off batteria/dati; tuning tono UX su partial senza allarmismo.

---

### Micro-slice TASK-071 consigliata *(solo testuale — **nessun file TASK-071 creato** da TASK-070)*

Scelta consigliata per la **prima EXECUTION** dopo **Planning Review approvata + user override esplicito**:

- **Solo** adapter + mapper read-only **fakeable**, wiring **DI/feature-gated**, **coordinator** + **XCTest** senza rete live obbligatoria (**D70-22**, **D70-23**).
- **Niente** refactoring strutturale `OptionsView` se non strettamente necessario (**D70-23**); preferire coordinator/ViewModel/`RunSummary` nei limiti del task.
- **Niente** apply / push / drain / baseline writer.
- **Niente** Supabase live obbligatorio nei criteri di accettazione della slice.
- **Niente** ProductPrice **user-facing dettagliato** nella prima slice — **deferred** (**D70-20**); se il path tecnico include fetch prezzi, solo **aggregazione** verso summary.
- Handoff a **review tecnica** prima di qualsiasi **espansione UI** «larga» sulla card cloud.

> **Nota vincolante:** **TASK-070 non crea né autorizza la creazione di `TASK-071*.md`**; la micro-slice resta **solo** raccomandazione testuale fino a override utente e nuovo file task.

---

### Planning Review Checklist

- [ ] Il reviewer **conferma** se usare una **CTA separata** «Controlla cloud» o **riusare** una CTA esistente sulla card (compattezza `OptionsView`).
- [ ] **Scelta consigliata:** CTA **distinta e semantica** (es. «Controlla cloud»), purché **compatta** e coerente col layout attuale delle opzioni (**D70-17**).
- [ ] Il reviewer **conferma** che **partial preview** **non** viene mappata su stato/copy **`partialSync`** user-facing se questo implica **ambiguità** con sync parziale post-mutazione — usare famiglia **«Controllo cloud incompleto»** (**D70-18**).
- [ ] Il reviewer **conferma** che **ProductPrice** resta **deferred** (o solo aggregato inevitabile) nella **prima** EXECUTION (**D70-20**).
- [ ] Il reviewer **conferma** che TASK-071 **non espone** **`SyncPreview`** raw alla UI Release (**D70-21**).
- [ ] Reviewer conferma inventario **`SupabasePullPreviewService`** e confine **`SupabasePullApplyService`**.  
- [ ] **Scelta obbligatoria reviewer** su preview con **`pending locali == 0`**:
  - **A)** preview remota read-only **consentita** anche con pending zero (raccomandazione planner: **solo** da **CTA manuale** «Controlla cloud» / equivalente, **bounded**).
  - **B)** preview **solo** se **`pending locali > 0`**.
  - **Raccomandazione testuale del planner: A via CTA dedicata** (non `onAppear`, non auto-loop).
- [ ] Verificare che **nessun** copy **solo IT hardcoded** sia **pianificato** per superficie **Release** senza piano **IT/EN/ES/ZH-Hans** nello stesso task EXECUTION (**D70-14**).
- [ ] Verificare che **partial / budget-limited** **non** venga presentato come **successo pieno** / «tutto aggiornato» (**D70-13**).
- [ ] Verificare che **`SupabasePullApplyService`** resti **completamente fuori** dal perimetro **TASK-071 preview-only** (solo apply in task dedicati futuri con conferma utente).  
- [ ] Confermare strategia **`pending zero` ↔ preview`** (coerente con punto A/B sopra).  
- [ ] Accettazione privacy/UI: **aggregati** solo in messaggi pubblici.  
- [ ] Conferma assenza **`SupabaseCatalogBaselineWriter`** dall’orbita TASK-071 preview-only.  
- [ ] Qualsiasi copy di esempio in italiano in TASK-070 è **solo semantica di planning**, non approvazione di stringhe di produzione.  
- [ ] Nessun comando live Supabase nel perimetro EXECUTION suggerito per TASK-071 fase zero; live smoke resta sempre opzionale e documentata.
- [ ] Il reviewer **conferma** che il documento TASK-070 è **sufficiente** per **chiudere TASK-070 come planning** documentale (**D70-26**) **anche senza** creare **`TASK-071*.md`** in parallelo.

---

### Checklist per chiusura planning TASK-070 *(governance reviewer — non equivale da sola a **DONE task progetto**)*

**Scopo:** supportare il **reviewer** nel decidere se il **planning markdown** TASK-070 è **chiudibile** (completezza, coerenza, assenza lacune documentali **bloccanti** sul perimetro dichiarato).

- **IMPORTANTE:** spuntare questa checklist **non** equivale automaticamente a **DONE / Chiusura** del task nel workflow progetto (**D70-26**). TASK-070 diventa **DONE / Chiusura** **solo** dopo **Planning Review con esito approvatorio** (**APPROVED** o equivalente di workflow) **e** **conferma esplicita dell’utente** — vedere anche **§Come chiudere TASK-070 dopo review**.
- **Non** autorizza **EXECUTION Codex**, **non** crea **TASK-071**, **non** modifica Swift. **Non richiede** build, **xcodebuild** né esecuzione test suite (**D70-25**: verifica primaria documentale).

- [ ] Documento TASK-070 **revisionato** (checklist §Planning Review soddisfatta o eccezioni note).
- [ ] Decisioni **D70-01…D70-26** complete, leggibili e **senza contraddizioni interne** evidenti.
- [ ] Rapporto con **TASK-068 D68-04** chiarito: **NESSUN tag OBSOLETA** necessario (**non** è in conflitto con questo planning — TASK-069 = micro-step senza read remoto; TASK-070 = slice successiva di **progettazione** read-only opzionale).
- [ ] Durante refinement TASK-070: **nessun** file `.swift` modificato dalla sessione; **nessuna** validazione tramite Supabase live obbligatoria; **nessun** file **`TASK-071*.md`** creato dall’azione di refinement.
- [x] `MASTER-PLAN.md` riallineato dopo chiusura ufficiale: progetto **IDLE**, nessun task attivo, TASK-070 **DONE / Chiusura**.

---

### Come chiudere TASK-070 dopo review

**Premessa:** questo task resta **solo planning** — **implementazione** della pull preview remota **non** è nel perimetro TASK-070 e **non** è richiesta per considerare il planning **completo** (**D70-26**).

#### Se la Planning Review è **APPROVED** (o esito equivalente positivo di workflow)

1. Compilare **§Review (Claude)** (esito, eventuali note, data).
2. Compilare **§Chiusura** (riferimento a conferma utente **esplicita** secondo workflow).
3. Nel file TASK-070 aggiornare metadati: **DONE / Chiusura** (solo **dopo** i passaggi sopra — **non** in questa rifinitura).
4. Aggiornare **`MASTER-PLAN.md`**: progetto **IDLE**, **nessun** task attivo; **Ultimo completato** = **TASK-070 DONE / Chiusura** (dettaglio testuale lasciato al reviewer conforme ai template di progetto).
5. **Prossimo consigliato** (solo testuale in backlog/note): eventualmente **TASK-071** come **micro-slice EXECUTION separata** — confermare che **`TASK-071*.md` non esiste ancora** e **non** è task attivo finché **user override + creazione file** non avvengano separatamente.
6. Nessuna delle operazioni sopra deve essere interpretata come **«pull preview già nel codice»**: resta pianificazione e criteri per lavoro futuro.

#### Se ci sono problemi (**CHANGES_REQUIRED**, **REJECTED**, o review non ancora concluded)

- Restare **ACTIVE / PLANNING** (o entrare in **FIX** solo **su markdown**, se previsto dal workflow), correggere **solo** documentazione TASK-070 / MASTER-PLAN testuale come da review.
- **Nessuno** Swift, **nessun** progetto Xcode / build / test imposto da TASK-070 stesso (**D70-25**) salvo **scelta esplicita review** estranea a questo piano.

---

## Handoff finale (TASK-070)

- **Stato storico pre-review:** **ACTIVE** / **PLANNING**.
- **Esito storico pre-review:** **READY FOR PLANNING REVIEW**.
- **Stato corrente post-review:** **DONE / Chiusura** come planning/gap analysis; resta **NON READY FOR EXECUTION** nel perimetro TASK-070 (nessuna autorizzazione Codex; **nessun** Swift / test obbligatori / xcodebuild / Supabase live obbligatori per validare questo planning).
- **TASK-070 è chiudibile come planning documentale dopo review favorevole secondo §Come chiudere**; **la chiusura non implica** che la **pull preview remota sia implementata** nell’app.  
- **TASK-071** resta una **proposta futura** scritta in questo documento, **non** un file **`TASK-071*.md`** esistente **né** un task attivo sul MASTER-PLAN.  
- **Nessun** file **Swift** modificato con questa rifinitura TASK-070.  
- **Nessun** file **`TASK-071*.md`** creato.  
- **Prossimo passo:** **Planning Review** (primariamente documentale — **D70-25**).  
- **Dopo** Planning Review **APPROVED** **+ conferma utente** e **solo** dopo **override** dedicato alla creazione file, una futura micro-slice **TASK-071** potrà essere trattata separatamente (vedi §Micro-slice consigliata).

---

### Handoff → Review (Planning)

- **Prossima fase**: REVIEW (planning documentale TASK-070)  
- **Prossimo agente**: Claude / Reviewer tecnico progetto  
- **Azione consigliata**: usare **§Planning Review Checklist**, **§Checklist per chiusura planning TASK-070**, **§Come chiudere TASK-070 dopo review**, **§Micro-slice TASK-071 consigliata**, coerenza **D68-04 / D70-25**. Esito planning: **APPROVED** documentale **o** **CHANGES_REQUIRED** (**solo markdown** / MASTER testuale). Dopo esito favorevole + conferma utente: compilare **§Review (Claude)** e **§Chiusura** secondo governance — **senza** implicare che Codex sia autorizzato o che TASK-071 esista.

*(Sezione EXECUTION Codex vuota deliberatamente.)*

---

## File letti (obbligatori indicati nel brief — sessione TASK-070)

### Documentazione

- `docs/MASTER-PLAN.md` *(aggiornato in parallelo a questo task)*  
- `docs/TASKS/TASK-063-supabase-production-safe-sync-orchestrator-planning-ios.md` *(testata + scopo/dipendenze; file interno segna ancora metadata planning storica — MASTER-PLAN tratta TASK-063 come base architetturale non attiva)*  
- `docs/TASKS/TASK-068-supabase-manual-sync-live-wiring-planning-ios.md` *(testata + decisioni D68 + inventario servizi)*  
- `docs/TASKS/TASK-069-supabase-manual-sync-local-pending-readonly-ios.md` *(informazioni generali + perimetro read-only locale)*  
- `docs/TASKS/TASK-067-supabase-manual-sync-release-ui-optionsview-ios.md` *(informazioni generali + anti-scope Release — file non modificato in TASK-070)*  
- `docs/TASKS/TASK-066-supabase-manual-sync-viewmodel-states-ios.md` *(dipendenze + scopo ViewModel)*  
- `docs/TASKS/TASK-065-supabase-manual-sync-coordinator-dryrun-ios.md` *(informazioni generali + scopo coordinator dry-run)*  

### Codice Swift (solo lettura / inventario per planning)

1. `iOSMerchandiseControl/SupabaseManualSyncLocalPendingSnapshotProvider.swift`  
2. `iOSMerchandiseControl/SupabaseManualSyncReleaseFactory.swift`  
3. `iOSMerchandiseControl/SupabaseManualSyncViewModel.swift`  
4. `iOSMerchandiseControl/SupabaseManualSyncCoordinator.swift`  
5. `iOSMerchandiseControl/SupabaseManualSyncCoordinatorModels.swift`  
6. `iOSMerchandiseControl/SupabaseManualSyncCoordinating.swift`  
7. `iOSMerchandiseControl/SupabasePullPreviewService.swift` (**include** pager + diff engine nello stesso file)  
8. `iOSMerchandiseControl/SupabasePullApplyService.swift` *(solo confine NON fare)* — prime definizioni enums/plan structs  
9. `iOSMerchandiseControl/SupabaseInventoryService.swift` *(protocol `SupabaseInventoryFetching` + error taxonomy HEAD)*  
10. `iOSMerchandiseControl/SupabaseCatalogBaselineReader.swift` *(solo conferma baseline read-only footprint)*  
11. `iOSMerchandiseControl/SupabaseCatalogBaselineWriter.swift` *(solo conferma apply-only path)*  
12. `iOSMerchandiseControl/SupabaseAuthViewModel.swift` *(firma/session)*  
13. `iOSMerchandiseControl/SupabaseAuthService.swift` *(error sanitization correlata inventory)*  
14. `iOSMerchandiseControl/iOSMerchandiseControlApp.swift` *(wiring DI `pullPreviewService`)*  
15. `iOSMerchandiseControl/SupabasePullPreviewModels.swift` *(solo `SupabasePullPreviewViewState` / enum error)*  

### Test esistenti (citati, senza modifiche TASK-070)

- `iOSMerchandiseControlTests/SupabasePullPreviewPaginationTests.swift`  
- `iOSMerchandiseControlTests/SupabasePullPreviewDiffEngineTests.swift`  
- XCTest TASK-069 / Release (`SupabaseManualSyncRelease*` / coordinator / VM) confermati come baseline QA storica dopo TASK-069 — **non rieseguiti** questo turno.

---

## Decisioni pregresse da non contraddire

- **TASK-068 · D68-04** escludeva che il **read remoto fosse obbligatorio** (o nel perimetro immediato) del **micro-step TASK-069**, dedicato agli **snapshot pending locali** read-only. Questo **non** vieta una **slice successiva e separata** (questo **TASK-070**) che **progetta**, in **planning-only**, un **read remoto opzionale read-only** per il futuro orchestratore / UI, senza EXECUTION qui. **Non c’è conflitto** con D68-04: TASK-069 resta **DONE** senza dipendere da rete; TASK-070 documenta **solo** l’analisi e le decisioni **D70** per un’integrazione futura. **Non** si dichiara D68-04 «obsoleta» né si richiede riscrittura di TASK-068 per TASK-070.

---

## Decisioni storiche TASK-063 coerenti

**Manual-first, no automation, no background**, preview/push ordinati dalla roadmap originale TASK-063; TASK-070 mantiene la preview **solo informativa** senza escalation automatiche post-fase.

---

## Review (Claude)

| Campo | Valore |
|-------|--------|
| **Stato review** | **COMPLETATA** |
| **Esito review** | **APPROVED_FIXED_DIRECTLY** *(solo tracking/markdown di chiusura; nessun codice in TASK-070).* |
| **Data review** | 2026-05-07 23:15 -04 |

Verifiche documentali:

- TASK-070 e' **planning-only**: non implementa e non dichiara implementata la pull preview remota.
- Le decisioni **D70-01...D70-26** sono coerenti e non contraddittorie.
- Il rapporto con **D68-04** e' chiarito senza dichiararlo obsoleto: TASK-069 resta micro-step locale read-only; TASK-070 pianifica una slice successiva remota read-only opzionale.
- La policy **pending locali zero** e' chiara: preview cloud futura ammessa solo da CTA manuale esplicita, bounded e non automatica.
- UX futura chiara: pending locali e segnali cloud separati; preview partial diversa da sync partial; famiglia copy **"Controllo cloud incompleto"** per partial/budget-limited; niente jargon Release.
- Adapter design concettuale sufficiente: provider fakeable, DTO piccolo/privacy-safe, mapper outcome, no `SyncPreview` raw verso Release.
- Definition of Ready e micro-slice **TASK-071** consigliata sono coerenti: adapter/mapper/coordinator/test, niente UI strutturale, niente apply/push/drain/baseline writer.
- TASK-070 puo' essere chiuso come planning anche se TASK-071 e' stato avviato con override separato: la chiusura non equivale a execution.

Fix applicato in review:

- Riallineati metadati e sezioni **Review / Chiusura** da **ACTIVE / PLANNING** a **DONE / Chiusura** secondo override utente controllato.

---

## Chiusura

| Campo | Valore |
|-------|--------|
| **Stato chiusura task** | **DONE / Chiusura** |
| **Nota** | TASK-070 e' chiuso come **planning/gap analysis** pull preview read-only. Non dichiara che la pull preview sia implementata nel codice; TASK-071 e' l'execution separata avviata con override utente. |

---
