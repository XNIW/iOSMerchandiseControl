# TASK-073 — Supabase manual sync live wiring iOS

## Informazioni generali

| Campo | Valore |
|-------|--------|
| **Task ID** | TASK-073 |
| **Titolo** | Collegamento coordinator manuale ai servizi live esistenti |
| **File task** | `docs/TASKS/TASK-073-supabase-manual-sync-live-wiring-ios.md` |
| **Stato** | DONE |
| **Fase attuale** | Chiusura |
| **Responsabile attuale** | Nessuno / Workspace IDLE |
| **Data creazione** | 2026-05-08 |
| **Ultimo aggiornamento** | 2026-05-08 09:52 -0400 — Review tecnica S73-a completata con fix diretto minimo su UX post-preview; XCTest mirati, build Release, `git diff --check` e grep anti-scope PASS; TASK-073 chiuso **DONE / Chiusura** su override utente. |
| **Ultimo agente** | Codex / Reviewer+Fixer+Closer |

### Nota autorizzazioni (TASK-073)

Questo task nasce come planning-only, poi e' stato promosso con override utente esplicito alla sola EXECUTION **S73-a**: preview remota read-only in Release. Lo storico planning-only sotto resta valido come contesto e guardrail; la chiusura **DONE / Chiusura** riguarda esclusivamente la slice **S73-a** completata e revisionata.

Durante execution/review sono rimasti non autorizzati e non implementati:

- `guidedManual` eseguibile e `supportsGuidedManualSync = true`;
- `SupabasePullApplyService`, push catalogo, ProductPrice push, outbox drain/cleanup/reset/truncate;
- Timer, BGTask, Realtime, polling, retry automatici/background;
- backend Supabase, SQL/migration, Android, nuovo schema SwiftData, `project.pbxproj`;
- redesign della card Release o nuove stringhe Release.

## Dipendenze

- **Dipende da**
  - **TASK-072** (**DONE / Chiusura**) — CTA Release «Controlla cloud» / «Sincronizza ora», `SupabaseManualSyncPresentationState`, capability-driven UI, `Localizable` IT/EN/ES/zh-Hans.
  - **TASK-071** (**DONE / Chiusura**) — `SupabaseManualSyncRemotePreviewProviding`, `SupabaseManualSyncPullPreviewAdapter`, mapper privacy-safe, DI opzionale nel coordinator, default `nil` in Release factory.
  - **TASK-069** (**DONE / Chiusura**) — `SupabaseManualSyncLocalPendingSnapshotProvider` (catalog + outbox counts, ProductPrice deferred).
  - **TASK-070** (**DONE / Chiusura**) — gap analysis pull preview read-only, decisioni D70-xx.
  - **TASK-067/066/065** (**DONE**) — UI Release, ViewModel, coordinator dry-run.
  - **TASK-063** (**DONE**) — orchestrazione production-safe: gate, run modes, boundary no `SupabaseClient` nel coordinator, conferme per mutazioni.
- **Sblocca (documentale)** — preparazione a EXECUTION futura wiring live + prerequisiti UX per **TASK-074** (summary user-facing) e **TASK-075** (smoke operativo); **nessuno** dei due va avviato da questo task.

## Scopo

Definire **solo in documentazione** come collegare **`SupabaseManualSyncCoordinator`**, **`SupabaseManualSyncViewModel`** e **`SupabaseManualSyncReleaseFactory`** ai **servizi iOS gia’ esistenti** (auth, baseline, pending locale, pull preview, pull apply, push catalogo/ProductPrice, outbox enqueue/drain), con **gate** e **conferma utente** prima di ogni apply/push/drain, separando cio’ che puo’ essere reso **live** in modo sicuro da cio’ che resta **deferred**.

## Non incluso (perimetro rigido questo turno)

- **Passaggio planning v4 (questo documento):** modifiche **solo** a markdown in `docs/TASKS/TASK-073-*.md`; **nessun** file `.swift`, **nessun** `project.pbxproj`, **nessun** build/test nel repo come effetto di questo aggiornamento (coerente con **CA73-23**).
- **Nessuna** modifica Swift, `project.pbxproj`, `Info.plist`.
- **Nessun** build / `xcodebuild` / XCTest obbligatorio in questa sessione planning.
- **Nessuna** SQL migration, `db push`, modifica backend, Kotlin/Android.
- **Nessun** nuovo schema SwiftData.
- **Nessuna** sync automatica, Timer, BGTask, Realtime, worker, polling.
- **Nessun** cleanup distruttivo outbox (truncate/delete/reset).
- **Nessun** apply/push/drain **live** non mediato da coordinator + conferma utente (definita in execution futura).
- **Non** chiudere TASK-073 come DONE; **non** avviare TASK-074 / TASK-075.

## Criteri di accettazione (planning TASK-073)

| ID | Criterio | Stato |
|----|----------|-------|
| CA73-01 | File TASK-073 creato con path coerente con MASTER-PLAN. | [x] |
| CA73-02 | Inventario tecnico repo-grounded di coordinator / factory / ViewModel / adapter preview / servizi esistenti. | [x] |
| CA73-03 | Gap «live ora» vs «deferred» esplicito, incluso ProductPrice pending e full sync. | [x] |
| CA73-04 | Decisioni **D73-xx** compilate (gate, conferme, slice order). | [x] |
| CA73-05 | Micro-slice EXECUTION futura ordinate (dependency-aware). | [x] |
| CA73-06 | File iOS probabili vs file vietati elencati. | [x] |
| CA73-07 | UX Release senza jargon; nessun raw `SyncPreview` / DTO in UI (allineamento TASK-072/071). | [x] |
| CA73-08 | Error taxonomy privacy-safe (categorie user-facing vs interne). | [x] |
| CA73-09 | Test matrix XCTest + grep anti-scope. | [x] |
| CA73-10 | Definition of Ready / Done (planning); handoff **READY FOR PLANNING REVIEW v4**, **NON READY FOR EXECUTION**. | [x] |
| CA73-11 | Sezione **UX contract Release** con CTA, capability, jargon vietato, copy partial/errore. | [x] |
| CA73-12 | **User confirmation model** + decisione sheet riassuntiva (**D73-13**). | [x] |
| CA73-13 | Tabella **Live now vs deferred** + **Concurrency/cancellation/retry** + **Accessibility/localization checklist**. | [x] |
| CA73-14 | Micro-slice **S73-a…f** rafforzati: prima execution senza bundle apply+push+drain; S73-a solo preview read-only. | [x] |
| CA73-15 | **Capability truth table** presente (hide vs disable, auth/baseline, running). | [x] |
| CA73-16 | Sezione **S73-a execution brief** presente; perimetro strettamente read-only, niente mutazioni. | [x] |
| CA73-17 | Tabella **Remote cloud check UX states** presente. | [x] |
| CA73-18 | **Privacy/logging**, **performance/threading**, **rollback/recovery** guardrails presenti. | [x] |
| CA73-19 | Sezione **S73-a state machine — planning only** presente (stati logici + perimetro mutazioni **sempre NO** in S73-a). | [x] |
| CA73-20 | Sezione **Suggested user-facing copy** (indicativa, non stringhe finali) + nota **Localizable** futura. | [x] |
| CA73-21 | Sezione **S73-a explicit non-goals** (checklist). | [x] |
| CA73-22 | Sezione **Pre-execution checklist for S73-a** presente. | [x] |
| CA73-23 | Il documento dichiara esplicitamente che il passaggio **v4** modifica **solo** markdown (nessun Swift in questo turno). | [x] |

---

## Planning (Claude)

### Obiettivo

Portare la pipeline gia’ modellata nel coordinator (fasi: auth → baseline → pending locale → preview remota → …) da **dry-run + simulatori** verso **implementazioni delegate** ai servizi reali **gia’ nel repo**, mantenendo: (1) **manual-first**; (2) **nessun SDK diretto** nel coordinator (allineamento TASK-063/TASK-058); (3) **conferma esplicita** prima di mutazioni remote/locale applicate; (4) **testabilita’** via protocolli/fake.

### Stato attuale iOS (repo-grounded, 2026-05-08)

| Area | Situazione attuale |
|------|-------------------|
| **Release factory** (`SupabaseManualSyncReleaseFactory`) | `authGate` e `baselineGate` **reali** (`SupabaseAuthViewModel` + `SupabaseCatalogBaselineReader` via gate privati). `pendingSnapshot` = **`SupabaseManualSyncLocalPendingSnapshotProvider`** reale. `phaseSimulation` = **`SupabaseManualSyncReleaseDryRunPhaseSimulator`** (tutte le fasi simulate `.completed`). **Nessun** `remotePreviewProvider` passato a `Dependencies` → default `nil`. |
| **Coordinator** (`SupabaseManualSyncCoordinator`) | Esegue solo **`dryRun`**. **`guidedManual`**, **`debugDiagnostics`** → summary «modalita’ non disponibile». Supporta **`remotePreviewProvider` opzionale**: se presente, dopo `.remotePreview` con esito ok puo’ terminare in **preview-only** (salta conferma/push/drain) con **`finalizeRemotePreviewOnly`** (fix TASK-071). Se `nil`, usa `simulateRemotePreview`. |
| **Adapter preview** (`SupabaseManualSyncPullPreviewAdapter`) | Implementa `SupabaseManualSyncRemotePreviewProviding` chiamando **`SupabasePullPreviewService.generatePreview`**: read-only remoto + snapshot SwiftData locale in sola lettura nel servizio; summary mappato su **`SupabaseManualSyncRemotePreviewSummary`** (no `SyncPreview` in UI). |
| **ViewModel** (`SupabaseManualSyncViewModel`) | **`SupabaseManualSyncCapabilitySet.releaseCurrent`**: `supportsRemoteCloudCheck: false`, `supportsGuidedManualSync: false`. Espone `startDryRunVerification()` / `start(.dryRun)`. **`pendingConfirmation` / `shouldShowConfirmation`** stub **false**. Presentazione unificata **`SupabaseManualSyncPresentationState`** (TASK-072). |
| **Pull apply / push / drain** | Esistono nel codebase (**`SupabasePullApplyService`**, servizi **manual push** catalogo / ProductPrice, **`SyncEventOutboxDrainService`**, **`SyncEventOutboxEnqueueService`**) ma **non** sono cablati come fasi esecutive di `guidedManual` nel coordinator. |
| **Outbox DEBUG** | **`SyncEventOutboxDrainDebugViewModel`** + card `#if DEBUG` in `OptionsView` restano separati dalla run Release; eventuale integrazione «dentro run guidata» e’ decisione D63-04 / TASK-073 execution. |

### Riferimenti TASK usati

| Task | Uso nel planning TASK-073 |
|------|---------------------------|
| **TASK-063** | Ordine gate, run modes, boundary coordinator, conferme, drain solo in run guidata. |
| **TASK-065** | Scaffolding fasi/outcome; dry-run ancora unico path eseguito. |
| **TASK-066** | ViewModel come facciata; capability flags. |
| **TASK-067** | UI Release; factory pattern. |
| **TASK-069** | Pending locale reale; ProductPrice count = 0 nella prima slice. |
| **TASK-070** | Semantica preview remota, partial/budget, no apply nella preview. |
| **TASK-071** | Adapter + mapper; preview-only stop; Release factory senza provider. |
| **TASK-072** | CTA/capability-driven; nessun controllo cloud «finto»; preparazione a wiring TASK-073. |

### Riferimento Supabase (solo lettura / contratto)

- Contratti gia’ noti ai task storici: RPC **`record_sync_event`**, tabella **`sync_events`**, limiti **`changed_count`** 0…1000, RLS owner-scoped — **nessuna** modifica schema in TASK-073.
- Schema/progetto **Supabase locale** (se presente sul disco sviluppatore) resta riferimento per allineamento **solo in lettura**; **no** `db push`.

### Gap tecnico (principali)

1. **`guidedManual` non implementato** nel coordinator: occorre definire delega a servizi reali per fasi mutative, con **confirmation dialog** / equivalente **prima** di apply/push/drain (stub ViewModel da sostituire).
2. **Release factory** non inietta **`SupabaseManualSyncPullPreviewAdapter`**: la preview remota reale non e’ attiva in produzione; le capability restano false.
3. **Simulatore fasi push/flush**: sostituire con **adapter sottili** verso **`SupabaseManualPushService`** (e affini), **ProductPrice push** (TASK-051 percorso esistente), **`SyncEventOutboxDrainService`** — ogniuno gated e confermabile.
4. **Pull apply**: **`SupabasePullApplyService`** non deve essere invocato dalla sola preview; solo dopo conferma utente e stato coordinator esplicito (allineamento TASK-070).
5. **ProductPrice pending**: provider locale ancora **0** per design TASK-069; «full sync» ProductPrice **non** e’ obiettivo immediato; push/applicazioni gia’ coperte da task storici vanno **ripeggiate** fase-per-fase con conferma.
6. **Riassunto run ricco** (contatori «cosa e’ stato fatto») resta **TASK-074**, non TASK-073.

### Decisioni TASK-073 (D73)

| ID | Decisione |
|----|-----------|
| **D73-01** | TASK-073 e’ **planning-only** in questo turno; **non** autorizza EXECUTION Codex senza **review planning** + **user override** esplicito. |
| **D73-02** | Il wiring live deve usare **solo** servizi/protocolli **gia’ presenti**; nuovi singleton o SDK sparsi nella UI **vietati**. |
| **D73-03** | Il coordinator continua a **non** importare **`SupabaseClient`** direttamente; transport/recorder restano incapsulati (**TASK-058/060**). |
| **D73-04** | **Auth + baseline + pending locale** restano i primi gate; nessuna chiamata remota «mutante» prima di auth/baseline validi (salvo preview read-only gia’ definita come pre-condotta in TASK-070/071). |
| **D73-05** | **Preview remota read-only** via **`SupabaseManualSyncPullPreviewAdapter`**: prima slice EXECUTION consigliata = iniettare provider in **factory Release** + impostare **`supportsRemoteCloudCheck`** quando onesto (**allineamento D72-03**); test con fake/double. |
| **D73-06** | **Apply pull**, **push catalogo**, **push ProductPrice**, **drain outbox** richiedono **conferma utente** esplicita **prima** dell’invocazione del servizio; nessuna di queste azioni in **preview-only** o in **dryRun**. |
| **D73-07** | **DryRun** resta percorso **senza mutazioni** (regressioni TASK-065); non sostituisce `guidedManual`. |
| **D73-08** | **Drain outbox** in Release solo **dentro** run guidata confermata (**D63-04**), mai come azione isolata; niente cleanup distruttivo. |
| **D73-09** | **Enqueue** outbox: non espandere automaticamente; resta legato agli outcome dei push gia’ definiti (TASK-057). |
| **D73-10** | **ProductPrice full sync** e **pending price** oltre lo stato attuale: **deferred** salvo slice esplicita che dimostri copertura sicura via servizi esistenti; nessun nuovo schema. |
| **D73-11** | **TASK-074** assorbe il **summary narrativo** post-run; TASK-073 definisce **hook** e contratti ma **non** duplicare stringhe/finale summary ricco in UI. |
| **D73-12** | Opzioni **DEBUG** (`OptionsView` `#if DEBUG`) **non** sono obiettivo di wiring Release; possono restare indipendenti salvo decisione esplicita di unificare diagnostica in `debugDiagnostics` (fuori scope minimo TASK-073). |
| **D73-13** | **Conferme con conseguenze (apply/push/drain con contatori o impatto complesso):** per massima chiarezza UX, progettare una **sheet SwiftUI riassuntiva** (titolo, contenuto raggruppato/card leggere, **azione primaria** chiara, **Annulla**), stile nativo iOS coerente con l’app (`NavigationStack`, contenuto **grouped** / sezioni leggibili). **`alert` / `confirmationDialog`** riservati a **casi semplici** (binari, pochi attributi) o **conferme su azioni fortemente sensibili** secondo review HIG; non sostituire la sheet quando serve elenco sintetico di numeri/effetti. La sheet resta **definizione di prodotto** per EXECUTION futura; questo task non implementa Swift. |
| **D73-14** | **Visibilita’ vs stato disabilitato (scelta UX definitiva):** le funzioni **non realmente disponibili** vanno **nascoste** (niente CTA «fantasma» o disabilitate permanenti che **pubblicizzano** feature future). Le funzioni **disponibili** ma **temporaneamente non usabili** (es. durante **loading** o **run in corso**) vanno **disabilitate** con stato ancora **comprensibile** (label/hint accessibili). **Vietato** usare pulsanti disabilitati come teaser per funzioni non ancora cablate; preferire UI piu’ pulita e coerente con pattern iOS nativi (**D72-21**). |

### Piano micro-slice EXECUTION futura (ordine suggerito, vincolante per scope)

**Principi:** **S73-a** resta **obbligatoriamente** la prima slice consigliata (**solo** preview remota read-only in Release). **Ogni tipo di mutazione** (pull apply, push catalogo, drain, ProductPrice push) = **slice EXECUTION separata** con propri CA e review; **vietato** nella **prima** execution unire **pull apply + push catalogo + drain** (o qualsiasi combinazione di due mutazioni) nello stesso merge.

1. **S73-a — Preview remota in Release (solo lettura)** *(prima slice; unica mutazione consentita in questa fase = nessuna)*
   Costruire `SupabasePullPreviewService` + `ModelContext` nell’ambito gia’ usato altrove; passare **`SupabaseManualSyncPullPreviewAdapter`** come `remotePreviewProvider`. Aggiornare **`SupabaseManualSyncCapabilitySet`** / ViewModel per **`supportsRemoteCloudCheck`** solo quando l’iniezione e’ onesta (**D72-03**). Verificare scenari pending zero/non-zero + provider (**TASK-071**). XCTest: coordinator + fake transport + capability + assenza CTA «Controlla cloud» se capability false.

2. **S73-b — `guidedManual` fino al punto di conferma, senza mutazioni**
   Introdurre struttura `guidedManual` che ripete le fasi **read-only** (auth, baseline, pending, remote preview o skip coerente) e si **ferma prima** di qualsiasi apply/push/drain **finché** le slice mutative non sono cablate; utile per test e per future sheet di conferma **senza** rischio di scrittura accidentale.

3. **S73-c — Una sola mutazione: es. solo pull apply** *(merge dedicato; non accoppiare con S73-d/e)*
   Solo **`SupabasePullApplyService`** dopo **User confirmation model** + eventuale **sheet riassuntiva** (**D73-13**). Mapping esiti → `PhaseOutcome` / `RunSummary`.

4. **S73-d — Una sola mutazione: es. solo push catalogo** *(slice separata da S73-c)*
   Percorso manual push esistente; conferma obbligatoria; niente drain nella stessa PR obbligatoriamente.

5. **S73-e — Outbox drain nella run guidata** *(slice separata; dopo S73-c/d se dipendenze ordine)*
   Solo **`SyncEventOutboxDrainService`** dopo conferma dedicata; outcome aggregato privacy-safe.

6. **S73-f — ProductPrice push / applicazioni prezzo** *(opzionale, solo dopo validazione isolation; mai nella stessa prima wave di S73-a)*
   Richiama percorsi TASK-051 / apply storici; **mai** da preview sola.

*Ogni slice richiede propri CA, review e override utente; l’ordine c–f puo’ essere adattato salvo il divieto di bundle multi-mutazione in un unico primo merge.*

### S73-a execution brief — planning only

Brief operativo per la **futura** EXECUTION **S73-a** (nessun codice qui): obiettivo **unico** = abilitare il **controllo cloud read-only** in Release con perimetro minimo e verificabile.

| In scope S73-a | Dettaglio |
|----------------|-----------|
| **Provider preview** | Iniettare nella **Release factory** il **`remotePreviewProvider` reale** (es. **`SupabaseManualSyncPullPreviewAdapter`** costruito con `SupabasePullPreviewService` + `ModelContext` coerenti col resto dell’app). |
| **Capability cloud** | Impostare **`supportsRemoteCloudCheck = true`** **solo** quando il provider e’ **effettivamente** costruito e la run puo’ onestamente completare la fase read-only (**D72-03**). |
| **Guided sync** | Lasciare **`supportsGuidedManualSync = false`** (nessun «Sincronizza ora» funzionante finche’ non slice successive). |
| **Mutazioni escluse** | **Nessuna** chiamata a **`SupabasePullApplyService`**; **nessun** push catalogo; **nessun** ProductPrice push; **nessun** **`SyncEventOutboxDrainService.drain`** / flush; **nessun** enqueue «forzato» oltre cio’ che gia’ esiste fuori da questa slice. |
| **UI** | Cambiamenti **minimali**: solo cio’ che serve al comportamento **capability-driven** (CTA coerenti con **D73-14** / **Capability truth table**); **non** redesign della card. |
| **Semantica CTA** | **«Controlla cloud»** resta **solo** azione di **preview remota read-only**; nessuna etichetta che implichi applicazione o invio. |

### S73-a state machine — planning only

Macchina a stati **logica** per la futura azione **«Controlla cloud»** in **S73-a** (naming indicativo per mapping ViewModel / `SupabaseManualSyncPresentationState`). **Regola S73-a:** in **tutti** gli stati sotto, le **mutazioni** (apply/push/drain/enqueue forzato) sono **NO**.

| Stato | Cosa vede l’utente | CTA primaria | Mutazioni | Note ViewModel / PresentationState |
|-------|---------------------|--------------|-----------|--------------------------------------|
| **idle** | Card pronta; sottotitolo/badge coerenti con pending locale se presente | **Controlla cloud** (se `supportsRemoteCloudCheck` e gate OK) oppure CTA gate (vedi sotto) | **No** | Stato di riposo tra una run e l’altra; `isRunning == false`. |
| **blockedByAuth** | Messaggio che serve accedere | **Accedi** | **No** | «Controlla cloud» non primaria; allineare a **Capability truth table**. |
| **blockedByBaseline** | Messaggio che serve riallineare i dati | **Riallinea dati** | **No** | Preview remota non avviabile finche’ baseline KO. |
| **checkingRemotePreview** | Indicatore di attivita’ (es. progress) durante il fetch preview | **Annulla** (se la run e’ cancellabile) / CTA disabilitate | **No** | Mappare a fase coordinator `.remotePreview` / run attiva. |
| **completedNoRemoteIssues** | Esito positivo sintetico: controllo ok, nessun segnale rilevante dal cloud (per copy: vedi sezione indicativa) | **Ok** implicito → ritorno **idle** o messaggio neutro | **No** | Derivato da summary (`hasRemoteSignals == false`, success read-only). |
| **completedWithRemoteDifferences** | Controllo completato; risultato: ci sono differenze / cose da esaminare (solo informativo, **no apply** in S73-a) | Torna a **idle** / **Riprova** opzionale | **No** | Usare aggregati privacy-safe; **no** lista barcode in UI. |
| **completedPartial** | **Controllo cloud incompleto** (budget/partial lato preview) | **Riprova** (se retry consentito) | **No** | Non etichettare come «sync parziale» (**UX contract**). |
| **failedNetwork** | Messaggio breve connettivita’ | **Riprova** | **No** | Mappa categorie rete; niente dettaglio tecnico. |
| **failedPermissionOrSession** | Sessione o permessi insufficienti | **Accedi** o **Riprova** secondo caso | **No** | Distinguere da semplice errore rete. |
| **failedTechnical** | Problema generico senza stack | **Riprova** se applicabile | **No** | Dettaglio solo DEBUG/test, non Release. |
| **cancelled** | Controllo annullato | Rientro **idle** | **No** | Summary neutro (**D70-15**). |
| **alreadyRunning** | Operazione gia’ in corso; attendere | Nessuna nuova azione primaria duplicata; **Annulla** se previsto | **No** | Allineare a `concurrentRunNotAllowed` / busy; CTA disabilitati, non nascosti. |

### Suggested user-facing copy — non definitive

Esempi **brevi**, tono semplice e **iOS-like**, **senza gergo tecnico**. **Non** sono stringhe di produzione: nella **EXECUTION** futura andranno in **`Localizable.strings`** per **IT / EN / ES / zh-Hans** (TASK-072).

| Esempio (indicativo) | Uso |
|----------------------|-----|
| «Controllo cloud completato.» | Esito positivo dopo preview read-only. |
| «Non risultano modifiche locali da inviare.» | Pending zero; **non** implica «cloud aggiornato» senza verifica (**D72-25**). |
| «Il controllo cloud non è completo. Riprova più tardi.» | Preview **partial** / budget. |
| «Serve accedere prima di controllare il cloud.» | **blockedByAuth**. |
| «Riallinea i dati prima di controllare il cloud.» | **blockedByBaseline**. |
| «Controllo annullato.» | **cancelled**. |
| «Connessione non disponibile. Riprova.» | **failedNetwork**. |

### S73-a explicit non-goals

Checklist: cio’ che **S73-a** **non** deve fare o introdurre in EXECUTION (read-only only).

- [ ] **Nessun** ramo **`guidedManual`** eseguibile come risultato di questa slice.
- [ ] **Nessun** **`supportsGuidedManualSync = true`**.
- [ ] **Nessuna** chiamata a **`SupabasePullApplyService`** (pull apply).
- [ ] **Nessun** push catalogo.
- [ ] **Nessun** ProductPrice push.
- [ ] **Nessun** outbox **drain** / flush eventi dalla run Release.
- [ ] **Nessun** cleanup / **truncate** / reset outbox.
- [ ] **Nessun** timer, **nessun** retry automatico in background, **nessun** polling.
- [ ] **Nessun** redesign della card **Sincronizzazione cloud**.
- [ ] **Nessun** nuovo modello / **schema SwiftData** per questa slice.
- [ ] **Nessuna** migration SQL / `db push` / backend.

### Pre-execution checklist for S73-a

Condizioni raccomandate **prima** di autorizzare **EXECUTION** sulla sola **S73-a**:

- [ ] Review **planning v4** (questo documento) con esito positivo.
- [ ] **User override** esplicito: solo **S73-a**, **preview remota read-only**.
- [ ] **Scope** confermato: iniettare provider preview + capability cloud oneste; **zero** mutazioni.
- [ ] **File Swift target** individuati (es. factory, ViewModel, coordinator, eventuali test) — elenco operativo lasciato all’executor, coerente con § file probabili nel documento.
- [ ] **Test target** / suite di regressione identificati (coerenti con **Test matrix** + grep).
- [ ] **Grep anti-mutazione** (apply/push/drain/ProductPrice) e anti-scope pronti per il code review del diff S73-a.
- [ ] **Rollback dati** non richiesto: slice **read-only** (**Rollback / recovery policy**).
- [ ] **Un solo** task di wiring attivo: nessun altro task **ACTIVE / EXECUTION** parallelo che tocchi le stesse superfici (coerente con **un solo task attivo** nel workflow progetto).

### UX contract Release

Contratto UX per la sezione Release **Sincronizzazione cloud** (allineamento **TASK-072**, **D70-17…D70-19**, **D72-14…D72-25**), valido finche’ il codice rispetta questi vincoli:

| Regola | Dettaglio |
|--------|-----------|
| **«Controlla cloud» = preview remota read-only** | Azione esplicita utente; esegue solo lettura/consapevolezza tramite stack **`SupabaseManualSyncRemotePreviewProviding`** / **`SupabasePullPreviewService`**; **nessun** apply locale, **nessun** push, **nessun** drain, **nessun** enqueue forzato dalla CTA. |
| **Visibilita’ CTA «Controlla cloud»** | Mostrata **solo** se **`supportsRemoteCloudCheck`** e’ **tecnicamente `true`** (factory/coordinator/provider realmente collegati). **Vietato** etichetta che suggerisca controllo remoto reale se la capability e’ `false` (**D72-03**, **D72-21**). |
| **«Sincronizza ora»** | **Nascosta** oppure **disabilitata** (con spiegazione accessibile se necessario) finche’ **`guidedManual`** non e’ **realmente cablato** *e* **`supportsGuidedManualSync`** e’ `true` **e** esiste percorso di conferma per le mutazioni previste. Nessun testo «sync» che implichi scrittura se il percorso non esiste. |
| **Lessico vietato in stringhe visibili** | **outbox**, **drain**, **RPC**, **DTO**, **SyncPreview**, **payload**, **sync_events** (e varianti); anche in **chiavi o valori** destinati all’utente. Usare descrittori comportamentali (invio modifiche, operazioni in coda, connessione, permessi, ecc.). |
| **Preview parziale / budget** | Non usare «sincronizzazione parziale» per **incompletezza del solo controllo cloud**. Usare famiglia **«Controllo cloud incompleto»** (o equivalente localizzato **D70-13**); distinguere da **`partialSync`** solo quando si riferisce a **mutazioni** effettivamente parziali in una **run guidata** (futuro **TASK-074** puo’ rifinire etichette). |
| **Errori rete / sessione / schema** | Messaggi **brevi**, **privacy-safe** (niente stack, ID interni, path); **localizzabili** IT/EN/ES/zh-Hans; **retry** solo dove il ViewModel espone retry sicuro; permessi/sessione → filo **Accedi** / **Riallinea** gia’ previsto. |

### Capability truth table

Comportamento **atteso** della card Release rispetto a capability e gate (allineamento **TASK-072**, **D73-14**). La **PresentationState** deve implementare queste regole in EXECUTION futura.

| Condizione | Comportamento |
|------------|----------------|
| **`supportsRemoteCloudCheck == false`** | La CTA **«Controlla cloud»** e’ **nascosta** — **non** mostrata disabilitata «a mo’ di teaser» (**D73-14**). |
| **`supportsRemoteCloudCheck == true`** e **nessuna run** in corso (`isRunning == false`) | **«Controlla cloud»** **visibile** e **attiva** (salvo gate auth/baseline sotto che prevalgono sulla primarieta’). |
| **Run in corso** (`isRunning` / run attiva nel ViewModel) | Le CTA rilevanti sono **disabilitate**, **non nascoste**, con stato leggibile (progress / attesa). |
| **Auth mancante / non loggato** | Secondo la matrice **TASK-072**: **primaria** orientata a **«Accedi»**; **non** mostrare «Controlla cloud» come azione principale. |
| **Baseline non valida** | **«Riallinea dati»** (o equivalente); **non** «Controlla cloud» come azione risolutiva del gate. |
| **`supportsGuidedManualSync == false`** | **«Sincronizza ora»** = **nascosto** (non disabilitato come promessa futura). |
| **`supportsGuidedManualSync == true`** | Consentito **solo** quando **`guidedManual`** e’ **cablato**, esistono **conferme** per le mutazioni previste (**User confirmation model**) ed e’ presente **almeno una** mutazione reale pianificata (slice esecutiva approvata) — **non** solo stub. |

### Remote cloud check UX states

Stati orientati all’utente durante / dopo un **controllo cloud** read-only (S73-a+). Colonne guida per copy e CTA; dettaglio **PresentationState** in EXECUTION.

| Stato | Cosa vede l’utente | CTA primaria (indicativa) | Mutazioni consentite | Note |
|------|---------------------|-----------------------------|----------------------|------|
| **Non loggato** | Messaggio tipo «serve accedere»; nessun controllo cloud reale | **Accedi** | **Nessuna** | «Controlla cloud» **non** come primaria (**Capability truth table**). |
| **Baseline mancante / non valida** | Istruzioni per riallineare i dati rispetto al cloud | **Riallinea dati** | **Nessuna** remota di sync guidata finche’ baseline KO | Coerente con gate esistente. |
| **Provider preview non disponibile** (`supportsRemoteCloudCheck == false`) | Card senza azione «controlla cloud» reale; copy capability-neutral | Azione gia’ prevista dalla card (es. dry-run / messaggio idle) | **Nessuna** preview remota | **Nascosto**, non disabilitato finto (**D73-14**). |
| **Nessuna modifica locale pending** (snapshot = 0) e gate OK | Stato «nessuna modifica da sincronizzare» / neutro; **non** «tutto aggiornato» se non verificato remoto (**D72-25**) | **Controlla cloud** se capability **true** | Solo **lettura** preview se l’utente tappa | Pending zero non impedisce preview se provider attivo (**TASK-071**). |
| **Pending locali presenti** | Avviso che ci sono modifiche locali da controllare (TASK-069) | **Controlla cloud** (se capability) o iter su copy esistente | Solo **lettura** nella fase S73-a | Nessun push/drain implicito. |
| **Preview remota completata** | Esito sintetico «controllo completato» / messaggio chiave **privacy-safe** da summary | **Riprova** / chiusura o idle (secondo ViewModel) | **Nessuna** in S73-a | Nessun apply automatico. |
| **Preview remota incompleta / parziale** | **«Controllo cloud incompleto»** (famiglia D70-13), non «sync parziale» | **Riprova** se retry sicuro | **Nessuna** mutazione | Distinguere da `partialSync` mutativo (futuro). |
| **Errore rete** | Messaggio breve connettivita’; retry se applicabile | **Riprova** (se `canStart`/retry) | **Nessuna** | No dettagli tecnici in Release. |
| **Run cancellata** | Messaggio annullamento coerente (**D70-15**) | Azione per tornare a idle / **Riprova** | **Nessuna** dopo cancel | Summary **neutro**. |
| **Run gia’ in corso** | Progress / attesa; CTA non ripetibili | **Annulla** (se offerto) | **Nessuna** nuova finche’ termina | CTA **disabilitati**, non nascosti. |

### User confirmation model

Stati di conferma previsti **prima** delle EXECUTION mutative future (il ViewModel/coordinator devono riflettere questi vincoli; implementazione = task successivi).

| Scenario | Conferma richiesta? | Note |
|----------|---------------------|------|
| **`dryRun`** | **No** | Solo verifica simulata / rehearsal; nessuna mutazione remota o locale intenzionale orchestrata. |
| **Preview remota read-only** | **No** | Coerente con **D73-06** (read path); l’utente ha gia’ scelto «Controlla cloud»; nessuna seconda conferma obbligatoria salvo policy prodotto che introduca «Anteprima risultati» (opzionale, non richiesta qui). |
| **Pull apply** (SwiftData) | **Sì**, obbligatoria | **Prima** di chiamare **`SupabasePullApplyService`**; sheet riassuntiva preferita se contatori/conflitti (**D73-13**). |
| **Push catalogo** | **Sì**, obbligatoria | Prima di eseguire push manuale catalogo; sheet se impatto non banale. |
| **ProductPrice push** | **Sì**, obbligatoria **se e solo se** la capability/slice futura abilita quel percorso | Altrimenti fase **non esposta** / **deferred**. |
| **Outbox drain** (invio eventi in coda) | **Sì**, obbligatoria | Dentro run guidata, mai drain «silenzioso» Release (**D63-04**). |
| **Outbox enqueue** | **Nessuna conferma dedicata Release** per enqueue da outcome push | Effetto **controllato** dei flussi push esistenti (**TASK-057**); eventuali eccezioni solo per task dedicati. |
| **Annulla conferma** | Run **termina senza mutazioni** successive; summary **neutro** (non successo pieno); coerente con cancellazione gia’ modellata. |

### Live now vs deferred

| Fase | Stato attuale (2026-05-08) | Puo’ diventare live in una **execution futura** TASK-073? | Richiede conferma? | Note UX |
|------|----------------------------|--------------------------------------------------------|---------------------|---------|
| **Auth / session gate** | **Gia’ live** in Release factory (lettura stato sessione) | **Gia’ live** / raffinamenti minori | No (gate) | Copy **Accedi** / stato sessione (**TASK-072**). |
| **Baseline gate** | **Gia’ live** (`SupabaseCatalogBaselineReader`) | **Gia’ live** / raffinamenti minori | No (gate) | **Riallinea dati** quando baseline non valida. |
| **Pending locale** | **Gia’ live** (snapshot aggregato privacy-safe) | **Gia’ live** | No (lettura) | Messaggi «modifiche da controllare» senza promettere cloud aggiornato (**D72-25**). |
| **Remote preview read-only** | **Adapter presente nel codice**; **non** iniettato in Release factory | **Sì — candidata slice S73-a** | **No** | CTA **Controlla cloud** solo con capability vera; partial → **Controllo cloud incompleto**. |
| **Pull apply** | Servizio esiste; **non** nel coordinator Release | **Sì — slice dedicata** (es. S73-c) | **Sì** | Sheet riassuntiva se numeri/conflitti (**D73-13**). |
| **Push catalogo** | Servizi esistono; fasi simulate dry-run | **Sì — slice dedicata** (es. S73-d ordine) | **Sì** | Una mutazione per slice; non accoppiare con apply/drain. |
| **ProductPrice push / full sync** | Percorsi TASK-050/051; pending VM = 0 | **Solo slice separata / deferred** fino a validazione | **Sì** se esposto | Full sync **non** obiettivo TASK-073 minimo; terminology user-facing senza jargon. |
| **Outbox enqueue** | Automatico da outcome push (**TASK-057**) | Non e’ una «fase CTA»; resta **effetto controllato** | **No** (Release) | Spiegabilita’ affidata a **TASK-074** per riepilogo «inviato / in coda». |
| **Outbox drain** | **DEBUG** separato + servizio **G2** | **Sì — solo** run guidata + conferma (**S73-e**) | **Sì** | Mai come pulsante Release isolato (**D63-04**). |
| **Summary user-facing** | Parziale nel coordinator/VM; ricchezza limitata | **Maggior parte in TASK-074**; TASK-073 **hook** solo | Dipende | Nessun **SyncPreview** raw; messaggi neutri post-annulla. |

### Concurrency / cancellation / retry

| Tema | Regola |
|------|--------|
| **Durante una run** | **Tutti** i CTA rilevanti **disabilitati** o non ripetibili finche’ `isRunning` / equivalente (**D72-24**); **una** run attiva per sessione coordinator (**concurrentRunNotAllowed** gia’ in dry-run). |
| **Parallelismo** | **Nessuna** seconda run parallela; tentativi → esito **busy** / messaggio coerente. |
| **Cancel** | Interrompe **solo** lavoro **non ancora commesso** o fasi **cancellabili** (rete in corso, preview); **non** garantire annullamento dopo mutazione iniziata. |
| **Post-mutazione** | **Nessuna** promessa di **rollback automatico** dopo che una scrittura e’ partita; eventuali errori → stato **partial** / **follow-up** (**D63-08**). |
| **Retry** | **Nuova** azione utente (**nuova run manuale** o CTA **Riprova** quando il ViewModel lo consente); **nessun** polling, **nessun** timer, **nessun** retry loop in background. |

### Accessibility and localization checklist

Ogni EXECUTION che tocchi stringhe o CTA Release deve soddisfare:

- [ ] **Tutti** i testi **nuovi** o modificati passano da **`Localizable.strings`** (**IT / EN / ES / zh-Hans**), coerenti con **TASK-072**.
- [ ] **CTA**: titolo pulsante, **SF Symbol** (se usato) e **accessibilityLabel** allineati; **hint** per stati disabilitati **transitori** (non «funzione assente» mascherata).
- [ ] **Loading / success / error**: annunci **VoiceOver** comprensibili (`ProgressView` / stato run / messaggio conclusione).
- [ ] **Colore** non come **unico** canale informativo; usare simboli/testo secondari dove servono stati.
- [ ] **Sheet di conferma** (**D73-13**): focus VoiceOver logico (Annulla vs primario), **Dynamic Type** compatibile.
- [ ] Rerun **grep** su `options.supabase.manualSync.*` per **jargon** e termini tecnici.

### Privacy and logging guardrails

| Regola | Dettaglio |
|--------|-----------|
| **Logging** | Log tecnici **solo** dove necessari e preferibilmente **`#if DEBUG`** o canali di sviluppo; **nessun** log «rumoroso» in Release per default. |
| **Dati sensibili** | **Vietati** in log: **barcode**, **nome prodotto**, **supplier/category name** testuali, **payload** RPC/raw, elenchi ID — anche in sviluppo accanto alla UI Release. |
| **Aggregati** | Se serve diagnostica: **solo contatori** / flag / categorie errore (**privacy-safe**), coerenti con **`SupabaseManualSyncRemotePreviewSummary`**. |
| **Messaggi utente** | UI Release: messaggi **brevi**, **non tecnici**; errori interni dettagliati → **solo** test / **DEBUG** / strumenti interni. |
| **Fail-safe** | In dubbio, **meno testo** all’utente, non piu’ dettaglio. |

### Performance and threading guardrails

| Regola | Dettaglio |
|--------|-----------|
| **Main thread** | **Nessun** lavoro pesante (diff grandi, parsing massivo) bloccante sul **main**; rispettare gia’ i pattern del **`SupabasePullPreviewService`** / `Task` dove applicabile. |
| **Aggiornamento UI** | Solo tramite **ViewModel** / **`SupabaseManualSyncPresentationState`** (o equivalente **@MainActor**), mai aggiornamenti diretti sparsi dalla View. |
| **Preview remota** | **Cancellabile**; **nessuna** seconda preview **parallela** mentre una run e’ attiva; coordinare con lock run (**Concurrency**). |
| **UI** | **Nessun** caricamento di **payload raw** o liste complete in interfaccia Release — solo aggregati gia’ previsti. |
| **Aspettative** | Con preview **budgeted/partial**, **non** promettere «sync completa» / «tutto allineato» (**D70-09**, **D72-25**). |

### Rollback / recovery policy

| Contesto | Policy |
|----------|--------|
| **S73-a** | **Solo read-only** → **nessun rollback dati** necessario; fallimento = messaggio **privacy-safe** + eventuale **Riprova** manuale. |
| **Provider preview fallisce** | L’utente vede errore **generico** / rete / permessi; **nessun** dettaglio implementativo; **retry** solo manuale. |
| **Slice mutative future** | Dopo che una **scrittura** e’ iniziata, **nessun rollback automatico** promesso (**Concurrency**); recovery progettata **slice-per-slice** con review dedicata. |
| **Stato parziale** | Esiti **partial** / **follow-up** documentati nel coordinator; copy utente in **TASK-074** quando serve narrativa completa. |

### UX prevista (Release) — sintesi

Riferimento normativo: sezione **§ UX contract Release** sopra. Qui solo sintesi: **PresentationState** (**TASK-072**) resta il punto unico di verita’ per titoli/CTA; ViewModel espone capability vere; summary ricco e narrativa finale principalmente **TASK-074**.

### File iOS probabilmente toccati in EXECUTION futura

- `SupabaseManualSyncCoordinator.swift` — ramo `guidedManual`, deleghe fasi, conferme.
- `SupabaseManualSyncCoordinatorModels.swift` — se servono esiti/causali aggiuntivi (minimo necessario).
- `SupabaseManualSyncReleaseFactory.swift` — costruzione `Dependencies` con adapter preview reale e futuri adapter push/drain/apply.
- `SupabaseManualSyncViewModel.swift` — capability, conferme, `start` verso `guidedManual`, mapping summary.
- `SupabaseManualSyncCoordinating.swift` — solo se il protocollo deve espandere (evitare se possibile).
- `SupabaseManualSyncRemotePreview.swift` — solo se serve estensione mapper (preferire cambi minimi).
- Eventuali **nuovi file sottili** tipo `SupabaseManualSync*LiveAdapter.swift` che wrappano servizi esistenti (push/drain/apply) — **senza** duplicare logica domain.

### File da NON toccare (salvo necessita’ provata in review)

- `project.pbxproj` (a meno che non sia strettamente necessario per nuovi file — valutare in EXECUTION).
- Backend Android, SQL migrations, Edge Functions.
- **`OptionsView.swift`**: solo se strettamente necessario per pass-through; la logica resta sul ViewModel (**TASK-072**). Preferire modifiche minime.
- Nuovi modelli SwiftData per «sync state» globale.

### Error taxonomy (privacy-safe)

| Categoria interna | User-facing (esempi concettuali) | Note |
|-------------------|----------------------------------|------|
| Rete / timeout | Messaggio riconnettivita’, **retry** | Mappa da `SupabaseInventoryServiceError.networkError`, URLError |
| Permessi / sessione | **Accedi** / problema permessi generico | Session/RLS |
| Schema / decode | Messaggio generico «problema tecnico», no stack | Drift/logging solo DEBUG |
| Snapshot locale | Messaggio generico aggiornamento locale | No path file |
| Operazione annullata | «Annullato» / coerente con D70-15 | Cancellation |
| Successo senza diff | Neutro, no promesse «cloud aggiornato» se non verificato (**D72-25**) | |

### Test matrix (futura EXECUTION)

| Tipo | Suite / focus |
|------|----------------|
| **Unit / Coordinator** | `SupabaseManualSyncCoordinatorTests` — `guidedManual` con fake per ogni fase; ordine chiamate; stop dopo preview-only. |
| **ViewModel** | `SupabaseManualSyncViewModelTests` — capability on/off; conferma; running/cancel. |
| **Release UI** | `SupabaseManualSyncReleaseUITests` — assenza jargon; **una** `.borderedProminent`; capability false non mostra «Controlla cloud» «finto». |
| **Adapter preview** | Fake `SupabaseInventoryFetching` / viewState partial vs complete. |
| **Regressioni** | Outbox: `SyncEventOutbox*`, `SyncEventRecording*`, `SyncEventLiveRecorder*` (come task precedenti). |
| **Esecuzione** | Preferire **`-parallel-testing-enabled NO`** dove gia’ documentato. |

### Grep anti-scope (da eseguire in EXECUTION / review)

**Sorgenti Swift (coordinator / ViewModel / UI Release)**

```text
# Automazioni / background vietate nel perimetro manual sync + Options
rg -n "BGTask|Timer|Realtime|polling|poll\\(|UNUserNotification|BackgroundTasks" iOSMerchandiseControl/SupabaseManualSync*.swift iOSMerchandiseControl/OptionsView.swift

# SDK diretto vietato su superfici manual sync / card Release
rg -n "SupabaseClient|\\.rpc\\(|\\.channel\\(" iOSMerchandiseControl/SupabaseManualSync*.swift iOSMerchandiseControl/OptionsView.swift

# Capability «Controlla cloud»: true solo con provider reale (vedi anche review statica capability)
rg -n "supportsRemoteCloudCheck\\s*:\\s*true" iOSMerchandiseControl/SupabaseManualSync*.swift

# Capability guidata: non impostare a true senza wiring reale
rg -n "supportsGuidedManualSync\\s*:\\s*true" iOSMerchandiseControl/SupabaseManualSync*.swift
```

**Localizable / copy utente**

```text
# Jargon e termini tecnici nelle stringhe Release manual sync
rg -n "SyncPreview|outbox|drain|sync_events|payload|retryable|\\bRPC\\b|\\bDTO\\b" iOSMerchandiseControl/*.lproj/Localizable.strings
```

**Criteri di successo**

- **Zero** occorrenze indesiderate sui path Release e sulle chiavi `options.supabase.manualSync.*` (allineamento TASK-067/072).
- Match **attesi** solo in commenti interni, test **fake**, o documentazione — mai in **stringhe visibili** all’utente.

**Review diff / S73-a (prima slice)**

In fase di code review della **sola** S73-a, verificare che il diff **non** introduca:

- chiamate a **`SupabasePullApplyService`**;
- chiamate a **push catalogo** / **ProductPrice push** / **`SyncEventOutboxDrainService`** (o equivalenti drain);
- qualsiasi percorso che implicitamente invii mutazioni **fuori** dalla preview read-only.

**Suggerimento:** `git diff` + ricerca testuale incrociata sui file toccati (vedi anche grep sotto).

**Log e debug in `SupabaseManualSync*.swift`**

```text
# Evitare print rumorosi in codice production manual sync (ok in test o #if DEBUG controllato)
rg -n "\\bprint\\(|\\bdebugPrint\\(" iOSMerchandiseControl/SupabaseManualSync*.swift

# Dati business nei log (anti-pattern)
rg -n "barcode|productName|ProductName|supplierName|categoryName" iOSMerchandiseControl/SupabaseManualSync*.swift
```

**Nota:** i match `barcode` ecc. possono essere **ammissibili** in **commenti** o **stringhe di test** con dati fake — mai in **log Release** o **print** attivi in produzione.

### Rischi

| Rischio | Mitigazione |
|---------|-------------|
| Confondere preview con apply | Fasi e tipi distinti; nessun `SupabasePullApplyService` nella `remotePreview` path. |
| Doppio tap / run concorrente | Lock coordinator gia’ presente; ViewModel `canStart` (**D72-24**). |
| Capability true premature | Flag solo quando adapter/servizi realmente collegati (**D72-03**). |
| Head-of-line outbox / dataset grandi | Drain bounded (**TASK-060**); messaggi partial (**D70-09**). |
| Scope creep verso TASK-074 | Summary ricco delegato; TASK-073 si ferma ai hook necessari. |

### Definition of Ready (planning → EXECUTION)

- Review **APPROVED** su questo planning (o fix documentali **CHANGES_REQUIRED** risolti).
- **User override** esplicito che promuove **PLANNING → EXECUTION** per la slice scelta (es. S73-a).
- Criteri della slice ridotti e testabili; fake disponibili per i servizi toccati.

### Definition of Done (planning TASK-073)

- Tutti i **CA73-xx** soddisfatti nel documento.
- **Handoff** aggiornato sotto.
- **MASTER-PLAN** allineato (task attivo / stato).
- **Nessun** Swift modificato *in questo task* se il contratto e’ «planning-only».

---

### Handoff — Planning (v4)

- **Stato handoff:** **READY FOR PLANNING REVIEW v4**
- **NON** **READY FOR EXECUTION** (nessuna modifica codice autorizzata da questo file finche’ non soddisfatto il DoR qui sopra; **non** promuovere TASK-073 a EXECUTION o DONE da questo planning).
- **Prossima azione consigliata:** review del planning **v4**; poi, solo dopo **user override** esplicito, aprire **EXECUTION limitata alla sola S73-a read-only** (preview remota in Release).
- **Prossimo agente:** reviewer / utente per approvazione **v4**; quindi **Codex / Executor** solo su **S73-a** e solo dopo override.

---

## Execution (Codex) ← non compilare in PLANNING

### 2026-05-08 00:41 -0400 — EXECUTION S73-a

#### Obiettivo compreso

Abilitare in Release la CTA **«Controlla cloud»** come preview remota **read-only**, usando il provider/adapter gia' presente nel repo, senza cambiare il significato di **«Sincronizza ora»** e senza introdurre mutazioni.

#### File controllati

- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-073-supabase-manual-sync-live-wiring-ios.md`
- `iOSMerchandiseControl/SupabaseManualSyncReleaseFactory.swift`
- `iOSMerchandiseControl/SupabaseManualSyncViewModel.swift`
- `iOSMerchandiseControl/SupabaseManualSyncCoordinator.swift`
- `iOSMerchandiseControl/SupabaseManualSyncRemotePreview.swift`
- `iOSMerchandiseControl/SupabasePullPreviewService.swift`
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControlTests/SupabaseManualSyncViewModelTests.swift`
- `iOSMerchandiseControlTests/SupabaseManualSyncReleaseUITests.swift`
- `iOSMerchandiseControlTests/SupabaseManualSyncRemotePreviewTests.swift`

#### Piano minimo

1. Passare il `SupabasePullPreviewService` gia' costruito dall'app alla card Release.
2. Costruire nella Release factory un `SupabaseManualSyncPullPreviewAdapter` solo quando il servizio preview esiste.
3. Impostare `supportsRemoteCloudCheck` solo dalla presenza del provider costruito; mantenere `supportsGuidedManualSync = false`.
4. Aggiornare test minimi esistenti e grep anti-scope.

#### Modifiche fatte

- `OptionsView` passa `supabasePullPreviewService` a `SupabaseManualSyncReleaseCard`; nessun redesign della card.
- `SupabaseManualSyncReleaseFactory` costruisce `remotePreviewProvider` con `SupabaseManualSyncPullPreviewAdapter(service:context:)` quando `SupabasePullPreviewService` e' disponibile, e lo passa al coordinator.
- `SupabaseManualSyncCapabilitySet` conserva `releaseCurrent` conservativo e aggiunge `releaseCurrent(remotePreviewProvider:)`, con `supportsRemoteCloudCheck = true` solo quando il provider e' non nil e `supportsGuidedManualSync = false` sempre.
- Test aggiornati:
  - capability Release cloud true solo con provider;
  - factory Release cablata su preview read-only;
  - test TASK-071 aggiornato per consentire il wiring S73-a senza esporre `SyncPreview`/adapter nella card o nel ViewModel.

#### Volutamente lasciato fuori

- Nessun `guidedManual` eseguibile.
- Nessun `supportsGuidedManualSync = true`.
- Nessuna chiamata a `SupabasePullApplyService`.
- Nessun push catalogo, nessun ProductPrice push, nessun outbox drain/cleanup/reset/truncate.
- Nessun Timer, BGTask, Realtime, polling o retry automatico.
- Nessuna modifica a backend Supabase, SQL, migration, edge functions, Android, SwiftData schema o `project.pbxproj`.
- Nessuna modifica a `Localizable.strings` o copy Release.

#### Check eseguiti

- ✅ ESEGUITO — `git diff --check`: PASS.
- ✅ ESEGUITO — check extra su file task untracked: `git diff --no-index --check /dev/null docs/TASKS/TASK-073-supabase-manual-sync-live-wiring-ios.md` segnala trailing whitespace preesistenti nella sezione Planning (righe micro-slice S73-a...f); non corretti per rispettare ownership sezioni Claude.
- ✅ ESEGUITO — XCTest mirati: `xcodebuild test -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' -parallel-testing-enabled NO -only-testing:iOSMerchandiseControlTests/SupabaseManualSyncViewModelTests -only-testing:iOSMerchandiseControlTests/SupabaseManualSyncReleaseUITests -only-testing:iOSMerchandiseControlTests/SupabaseManualSyncRemotePreviewTests`: PASS, 44 test.
- ✅ ESEGUITO — Build Release: `xcodebuild build -scheme iOSMerchandiseControl -configuration Release -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'`: PASS.
- ✅ ESEGUITO — Nessun warning nuovo nei file toccati verificabile da build output; warning residui osservati solo in file fuori perimetro gia' noti (`SupabaseProductPriceApplyService.swift`, `SyncEventOutboxDrainService.swift` / `SyncEventOutboxEntry.swift`, AppIntents metadata).
- ✅ ESEGUITO — Modifiche coerenti con planning S73-a: solo provider preview read-only + capability cloud.
- ✅ ESEGUITO — Criteri S73-a verificati staticamente: `supportsGuidedManualSync` resta false, CTA `checkCloud` resta `.dryRun`, fasi mutative non cablate.

#### Grep anti-scope

- ✅ `rg -n "supportsGuidedManualSync\\s*:\\s*true" iOSMerchandiseControl/SupabaseManualSync*.swift`: zero match.
- ✅ `rg -n "SupabasePullApplyService|SyncEventOutboxDrainService|drain\\(|ProductPrice|push" iOSMerchandiseControl/SupabaseManualSync*.swift`: match ammessi/preesistenti su DTO aggregate `remoteProductPriceCount` e fasi dry-run concettuali `productPricePush` / `simulateProductPricePushPhase`; nessuna chiamata reale a apply, push o drain introdotta da S73-a.
- ✅ `rg -n "BGTask|Timer|Realtime|polling|poll\\(|BackgroundTasks" iOSMerchandiseControl/SupabaseManualSync*.swift iOSMerchandiseControl/OptionsView.swift`: zero match.
- ✅ `rg -n "SupabaseClient|\\.rpc\\(|\\.channel\\(" iOSMerchandiseControl/SupabaseManualSync*.swift iOSMerchandiseControl/OptionsView.swift`: zero match.
- ✅ `rg -n "SyncPreview|outbox|drain|sync_events|payload|retryable|\\bRPC\\b|\\bDTO\\b" iOSMerchandiseControl/*.lproj/Localizable.strings`: match preesistenti ammessi/test-debug-only su diagnostica/debug Supabase (`options.supabase.diagnostic.*`, `options.supabase.syncEvents*`, `options.supabase.syncEventsOutbox*`); zero match sulle chiavi `options.supabase.manualSync.*`.
- ✅ `rg -n "\\bprint\\(|\\bdebugPrint\\(" iOSMerchandiseControl/SupabaseManualSync*.swift`: zero match.

#### Rischi rimasti

- La preview remota Release dipende dalla presenza del `SupabasePullPreviewService` costruito all'avvio app; se Supabase config e' assente/non valida, la capability resta false e la CTA cloud resta nascosta.
- Non e' stato eseguito smoke manuale in Simulator sulla CTA; non richiesto esplicitamente per S73-a e fuori dai check standard eseguiti.
- Il file task risulta untracked nel workspace; trailing whitespace del markdown pulito durante review/chiusura.
- Follow-up candidate: copy/summary piu' ricchi post-preview restano TASK-074, non inclusi qui.

#### Handoff post-execution

- S73-a e' stata poi revisionata con override utente nella sezione Review sotto.
- Tracking finale dopo review/fix: **TASK-073 DONE / Chiusura**.

## Review (Claude) ← non compilare in PLANNING

### 2026-05-08 09:52 -0400 — REVIEW S73-a (user override, Codex reviewer+fixer)

#### Verdetto

**CHANGES_APPLIED / APPROVED_FIXED_DIRECTLY** — S73-a resta nel perimetro read-only e puo' essere chiusa **DONE / Chiusura**.

#### Problemi trovati

- **UX post-preview remota con segnali:** una preview remota completata e read-only con elementi da rivedere veniva presentata dal ViewModel come stato generico di follow-up tecnico. Non introduceva mutazioni, ma ora che **Controlla cloud** e' live in Release rendeva l'esito meno chiaro del planning S73-a.

#### Esito review architetturale

- `SupabaseManualSyncCoordinator` non importa ne' usa direttamente `SupabaseClient`, `.rpc` o `.channel`.
- `SupabaseManualSyncViewModel` e la card Release in `OptionsView` non usano SDK Supabase diretto.
- `SupabaseManualSyncReleaseFactory` e' il punto corretto di wiring: costruisce `SupabaseManualSyncPullPreviewAdapter` solo quando riceve `SupabasePullPreviewService`.
- `supportsRemoteCloudCheck` e' true solo con provider non nil; senza provider resta false e la CTA cloud resta nascosta.
- `supportsGuidedManualSync` resta false.
- Nessun singleton globale, accoppiamento o duplicazione rilevante introdotti dalla slice.

#### Esito review S73-a read-only

- Confermati: nessun `guidedManual` eseguibile, nessun `SupabasePullApplyService`, nessun push catalogo/ProductPrice, nessun drain/cleanup/reset/truncate outbox, nessun Timer/BGTask/Realtime/polling.
- Confermati: nessuna modifica a backend Supabase, SQL/migration, Android, schema SwiftData o `project.pbxproj`.

#### Esito review UI/UX

- **Controlla cloud** appare solo con capability reale.
- Se la capability e' false, la CTA e' nascosta, non finta/disabilitata.
- Durante run in corso, la UI mantiene progress/cancel e non duplica CTA.
- Auth e baseline restano gate prima della preview.
- **Sincronizza ora** resta nascosto perche' guided sync non e' supportata.
- Nessuna nuova stringa Release o copy non localizzata.

#### Check eseguiti

- ✅ ESEGUITO — `xcodebuild test -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' -parallel-testing-enabled NO -only-testing:iOSMerchandiseControlTests/SupabaseManualSyncViewModelTests -only-testing:iOSMerchandiseControlTests/SupabaseManualSyncReleaseUITests -only-testing:iOSMerchandiseControlTests/SupabaseManualSyncRemotePreviewTests`: PASS, **45 test**.
- ✅ ESEGUITO — `xcodebuild build -scheme iOSMerchandiseControl -configuration Release -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'`: PASS.
- ✅ ESEGUITO — `git diff --check`: PASS.
- ✅ ESEGUITO — grep anti-scope richiesti: PASS; match residui solo attesi/preesistenti su conteggi `ProductPrice`/simulatori dry-run o stringhe DEBUG non `options.supabase.manualSync.*`.
- ✅ ESEGUITO — Modifiche coerenti con planning S73-a e criteri read-only.

#### Rischi residui

- Smoke manuale Simulator della CTA non eseguito; non richiesto esplicitamente per questa review e coperto qui da build/test/static review.
- Warning Release residui preesistenti/out-of-scope in `SupabaseProductPriceApplyService.swift`, `SyncEventOutboxDrainService.swift` / `SyncEventOutboxEntry.swift` e AppIntents metadata.
- Summary narrativo piu' ricco e user-facing resta follow-up **TASK-074**, non incluso in S73-a.

## Fix (Codex) ← non compilare in PLANNING

### 2026-05-08 09:52 -0400 — FIX diretto in review

#### Modifiche fatte

- `SupabaseManualSyncViewModel` ora presenta una preview remota completa con segnali cloud come **"Ci sono modifiche da controllare" / "Nessun invio automatico."**, invece di usare lo stato generico di problema tecnico.
- `SupabaseManualSyncViewModelTests` aggiunge copertura per il caso post-preview con segnali remoti: niente copy tecnico, **Controlla cloud** resta l'azione disponibile, **Sincronizza ora** resta nascosto.
- Pulito trailing whitespace nel file task mentre veniva aggiornato per review/chiusura.

#### Handoff post-fix

- Fix verificato con test/build/grep sopra.
- Task chiuso **DONE / Chiusura** su override utente.

---

## Decisioni (tabella globale task)

| # | Decisione | Stato |
|---|-----------|--------|
| 1 | Vedi **D73-01…D73-14** (incluse **D73-13** sheet, **D73-14** hide/disable) | attiva |
