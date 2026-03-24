# TASK-024: Full-database import progress UX + cancellation

## Informazioni generali
- **Task ID**: TASK-024
- **Titolo**: Full-database import progress UX + cancellation
- **File task**: `docs/TASKS/TASK-024-full-database-import-progress-ux-cancellation.md`
- **Stato**: ACTIVE
- **Fase attuale**: PLANNING
- **Responsabile attuale**: CLAUDE
- **Data creazione**: 2026-03-24
- **Ultimo aggiornamento**: 2026-03-24
- **Ultimo agente che ha operato**: CLAUDE

## Dipendenze
- **Dipende da**: TASK-022 (apply full-database stabile); la pipeline `DatabaseImportPipeline` / progress snapshot in `DatabaseView.swift` e' il presupposto. TASK-023 (idempotency + delta non-product) puo' essere in corso o in pausa: **non e' prerequisito** per TASK-024 e non va mescolato nel perimetro.
- **Sblocca**: UX prevedibile su import full-database lunghi; base per eventuali hardening futuri senza confondere correzione dati e feedback utente.

## Scopo
Migliorare in modo **minimo** la **UX di progresso** e introdurre una **cancellazione/abort controllato** (dove realistico) per il flusso **full-database import** (prepare → analisi → apply), con **messaggi di stato espliciti** e **pulizia overlay/stato** in tutti gli esiti (successo, errore, cancel), **senza** refactor della pipeline dati ne' della logica TASK-023.

## Contesto
Dopo TASK-022 il apply grande non crasha. TASK-023 ha affinato idempotency/delta non-product. Resta il problema percepito dagli utenti: fasi lunghe (parsing, analyze, apply prodotti, apply price history) con **feedback ancora generico** o **duplicato** (overlay Database + overlay nella sheet di analisi durante Apply), e **nessuna cancellazione cooperativa** del `Task` async. TASK-024 isola solo progress + cancel + coerenza UI, in linea con Vibe Coding.

## Non incluso
- Logica dedup / fingerprint / `hasWorkToApply` / delta non-product (TASK-023).
- Riapertura o merge in TASK-011.
- Refactor largo di `DatabaseImportPipeline`, parser Excel, o redesign della schermata Database.
- Atomicita' transazionale "ideale" su tutto l'apply se non ottenibile senza cambi architetturali maggiori (vedi Integrita' dati: onesta' su best-effort).
- Progress/cancel per **import prodotto semplice** (CSV / Excel singolo foglio) salvo dove lo stesso `importProgress` e' gia' condiviso e il cambiamento e' **triviale e a rischio zero** (da valutare in execution; non obiettivo primario).

## File potenzialmente coinvolti
- `iOSMerchandiseControl/DatabaseView.swift` — `DatabaseImportProgressState`, `DatabaseImportProgressSnapshot`, `DatabaseImportProgressStage`, `importProgressOverlay`, `importFullDatabaseFromExcel`, `applyConfirmedImportAnalysis`, `DatabaseImportPipeline.prepareFullDatabaseImport` / `applyImportAnalysisInBackground`.
- `iOSMerchandiseControl/ImportAnalysisView.swift` — `isApplying`, `processingOverlay`, toolbar Cancel/Apply, eventuale allineamento con stato globale progress.
- `*.lproj/Localizable.strings` — stringhe fase/cancel/messaggi finali (solo chiavi nuove o riuso chiavi esistenti).

---

## Planning (Claude)

### Analisi — stato attuale nel codice (verificato)

**Modello stato UI** (`DatabaseImportProgressState`, ~1389+):
- `isRunning`, `showsOverlay`, `stageText`, `processedCount`/`totalCount`, `resultMessage`/`resultIsError`.
- `startPreparation()`: overlay **on**, fase iniziale "Preparing...".
- `apply(snapshot)`: overlay **on**, testo da `DatabaseImportUILocalizer.progressText` + barra se `totalCount > 0`.
- `awaitingConfirmation()`: **`isRunning` resta true** ma **`showsOverlay = false`** — l'utente vede la **sheet di analisi** senza overlay full-screen sulla tab Database.
- `finishSuccess` / `finishError` / `resetRunningState`: chiudono overlay e azzerano stato corsa; risultato in alert dedicato.

**Snapshot pipeline** (`DatabaseImportProgressSnapshot` + `DatabaseImportProgressStage`):
- Fasi: `parsingExcel`, `parsingSheet(name)`, `analyzing`, `applyingProducts`, `applyingPriceHistory`.
- `reportImportProgress` invia aggiornamenti a batch durante apply prodotti e price history.

**Prepare full import** (`importFullDatabaseFromExcel`):
- `Task { }` **senza** handle salvato: **nessun** `cancel()` cooperativo.
- `prepareFullDatabaseImport` riceve `onProgress` ma **non** un `CancellationToken` / `Task.checkCancellation()`.

**Apply dopo conferma** (`applyConfirmedImportAnalysis`):
- Chiama `importProgress.startPreparation()` poi `await DatabaseImportPipeline.applyImportAnalysisInBackground(..., onProgress:)`.
- `applyImportAnalysisInBackground` usa `Task.detached` + `ModelContext`: salvataggi **incrementali** via `saveImportProgressIfNeeded` durante i loop prodotti (e analogamente price history) → **commit parziali** possibili.

**ImportAnalysisView durante Apply**:
- `isApplying` mostra `processingOverlay` **dentro la sheet** (spinner + testo generico `import.analysis.processing.*`).
- In parallelo, `DatabaseView` puo' mostrare **`importProgressOverlay`** sulla tab → rischio **doppio feedback** visivo.

**Cosa manca oggi (UX)**:
- Nessun bottone **Annulla** sull'overlay di preparazione/apply a livello Database.
- Nessuna distinzione esplicita in UI tra **completato** / **fallito** / **cancellato dall'utente** (solo success vs error alert + reset).
- Messaggi di fase gia' presenti via localizzazione, ma cancel e stati finali non omogenei.

**Cancellazione "reale" oggi**:
- **No** cooperativa sulla pipeline async.
- L'utente puo' chiudere la sheet in attesa conferma (`handleImportAnalysisDismissed` resetta se `isRunning`) — non e' cancel del prepare in corso.

### Scope minimo TASK-024
- **Solo** full-database import path (stesso entry point che oggi usa `importProgress` + `prepareFullDatabaseImport` + sheet analisi + apply).
- Progress: testi/frazioni gia' esistenti **rafforzati** dove serve (chiarezza fase, evitare ridondanza overlay).
- Cancel: dove **sicuro e implementabile** senza promettere rollback totale impossibile.
- Messaggistica e reset stato/overlay in tutti gli esiti.
- **Escluso**: modifiche alla semantica dati TASK-023, nuove feature Database non legate all'import.

### Design tecnico proposto

1. **Task handle cancellabile**
   - Conservare in `DatabaseView` (es. `@State private var fullImportTask: Task<Void, Never>?` o equivalente) il `Task` avviato per **prepare** full-database e, separatamente o lo stesso flusso, per **apply** se applicabile.
   - All'avvio di un nuovo import: **cancellare** eventuale task precedente ancora vivo (defensive) prima di crearne uno nuovo.
   - Propagazione: passare `Task.checkCancellation()` (o controllare `Task.isCancelled`) nei punti **naturali** della pipeline — dopo ogni `await onProgress`, tra sheet parse, tra batch di righe **dove gia' si fa await** — **senza** riscrivere tutto il parser.

2. **Prepare / parsing / analyze**
   - **Supporto cancel: SI (obiettivo)** tra sotto-fasi e dopo chunk di lavoro dove la pipeline gia' `await`a (es. dopo lettura foglio, dopo analisi). Se alcuni passaggi sono sincroni lunghi senza await, documentare come **limite** noto (CA esplicito).
   - Su cancel: interrompere task, `MainActor` → `resetRunningState` o stato dedicato **cancelled**, `importAnalysisSession = nil`, `pendingFullImportContext = nil`, temp file gia' gestito da `defer`.

3. **Apply products / apply price history**
   - **Cancel durante apply**: tecnicamente **non atomico** per via di `context.save()` a batch. **Decisione pianificata**:
     - **Opzione A (preferita, minima)**: durante apply **non** offrire cancel "silenzioso" che simuli rollback; se si offre, mostrare **avviso** che puo' lasciare dati parziali, oppure **disabilitare** cancel mentre `applyingProducts` / `applyingPriceHistory` (solo prepare + "waiting" cancellabili).
     - **Opzione B** (solo se utente accetta complessita' extra in un task successivo, **fuori** perimetro stretto): transazione unica — probabile **fuori scope** per SwiftData usage attuale.
   - **Scelta raccomandata per TASK-024**: cancel **abilitato** in **prepare** (parsing + analyze nel task prepare); **disabilitato o assente** durante **apply** dopo conferma, con messaggio chiaro nella UI ("L'applicazione non puo' essere interrotta senza lasciare dati parziali") **oppure** cancel con conferma + messaggio **best-effort stop** senza rollback (documentato in CA).

4. **Stati distinti (modello logico UI)**
   - `idle` | `runningPrepare` | `awaitingUserConfirmation` | `runningApply` | `completedSuccess` | `completedError` | `cancelledByUser`
   - Implementazione: estendere leggermente `DatabaseImportProgressState` **o** mappare su campi esistenti + nuovo enum `ImportRunOutcome?` senza esplodere i tipi.

5. **Zombie overlay / sessioni appese**
   - Ogni uscita (success, error, cancel prepare) deve chiamare percorsi che portano a `showsOverlay == false` e `isRunning` coerente (dopo conferma utente su alert, se necessario).
   - `handleImportAnalysisDismissed` gia' resetta se import "in corso" senza sessione: mantenere e testare dopo cancel.

### UX minima richiesta

| Elemento | Specifica |
|----------|-----------|
| Overlay Database | Mantenere card con **titolo fase** + `ProgressView` lineare quando c'e' `totalCount`, altrimenti indeterminato. |
| Testi fase | Riutilizzare chiavi `database.progress.*` esistenti; aggiungere solo se serve distinzione **Cancellazione in corso...** / **Import annullato**. |
| Bottone **Annulla** | Visibile **solo** quando `showsOverlay == true` **e** la fase e' **cancellabile** (prepare/analyze nel task prepare — **non** durante apply se si sceglie Opzione A). |
| Cancel durante prepare | Interrompe task, **nessuna** apertura sheet analisi; messaggio dedicato "Import annullato" (non errore generico). |
| Cancel durante analyze | Se analyze e' nello stesso task prepare, stesso comportamento; **non** mostrare analisi parziale. |
| Cancel durante apply | Per default **non offerto**; se offerto con conferma: messaggio su possibile stato parziale + CA esplicito. |
| Doppio overlay | Ridurre ridondanza: preferire **una** superficie dominante (es. solo overlay Database durante apply **oppure** solo sheet — **decisione execution**: minimizzare duplicazione; candidato: tenere progress dettagliato su overlay Database e sheet solo disabilitata senza secondo spinner, o viceversa, ma **un** messaggio di fase principale). |
| Retry dopo cancel/failure | Utente puo' rilanciare import da menu: `importProgress.isRunning` deve essere **false** e nessun overlay attaccato. |

### Integrita' dati

- **Prepare**: in genere **nessun** `save()` su modello principale fino ad apply (verificare in execution che prepare full resti read-only salvo design attuale); cancel prepare → basso rischio residui nel DB.
- **Apply**: `saveImportProgressIfNeeded` persiste **a tratti**. **Non** si garantisce rollback atomico su cancel a meta' apply senza redesign.
- **Impegno TASK-024**: documentare in UI + CA che **l'interruzione durante apply non e' reversibile**; default **non** esporre cancel in quella fase.
- Se in futuro servisse atomicita', e' **follow-up** architetturale, non parte di questo task.

### Criteri di accettazione

- **CA-1**: Durante prepare full-database, l'utente vede **fase** e, quando disponibile, **progresso numerico** (come oggi o migliorato) senza regressioni su import che prima completavano.
- **CA-2**: In fase **cancellabile** (prepare/analyze nel task prepare), il bottone **Annulla** interrompe il lavoro, **non** apre la sheet analisi, **non** lascia `showsOverlay` bloccato, e mostra messaggio **esplicito** di annullamento (non confuso con errore file).
- **CA-3**: Dopo **errore** prepare o apply, overlay si chiude e la UI Database resta **usabile**; messaggio coerente (alert esistente o esteso).
- **CA-4**: Dopo **cancel** consentito, `importProgress.isRunning` e overlay tornano coerenti con **idle**; e' possibile **riprovare** un import senza riavviare l'app.
- **CA-5**: **Nessuna regressione** su import Excel semplice (stesso `importProgress` condiviso: verificare che non resti bloccato `isRunning`).
- **CA-6**: **Nessuna regressione** su full import **completato con successo** fino in fondo (stesso risultato funzionale di oggi).
- **CA-7**: Se cancel durante apply **non** e' offerto: documentato in planning + stringa UI o help implicito; se offerto con conferma: CA separato che il DB puo' essere **parzialmente aggiornato** e l'utente e' avvisato.
- **CA-8**: Stati finali distinguibili almeno a livello di messaggio: successo / errore / **annullato** (tre vie logiche).

### Test manuali (checklist)

| # | Scenario | Esito atteso |
|---|----------|--------------|
| TM-1 | Cancel durante parsing fogli (prepare) | Task si ferma; nessuna analisi; overlay chiuso; messaggio annullamento; UI usabile |
| TM-2 | Cancel durante fase analyzing (stesso task prepare) | Come TM-1 |
| TM-3 | Full import completo senza cancel | Comportamento come baseline; messaggi successo coerenti |
| TM-4 | Errore file invalido in prepare | Alert errore; overlay off; retry possibile |
| TM-5 | Apply completo dopo conferma | Nessun stallo; sheet si chiude; alert successo |
| TM-6 | Apply con errore (simulato o reale) | Overlay off; messaggio errore; sessione reset coerente |
| TM-7 | **Se** cancel apply non supportato: verificare assenza bottone o disabilitazione durante `applyingProducts` / `applyingPriceHistory` | Nessun finto "stop sicuro" |
| TM-8 | **Se** cancel apply supportato con conferma: interrompere a meta' | DB potenzialmente parziale; messaggio onesto; CA-7 |
| TM-9 | Retry dopo cancel prepare | Secondo import parte pulito |
| TM-10 | Retry dopo failure | Come TM-9 |
| TM-11 | Verifica import semplice (non full) | Nessuna regressione `isRunning` / overlay |

### Rischi
- **Complessita' annidata** `Task` + `Task.detached` in apply: cancel del prepare **non** deve cancellare apply gia' partito (gestire con flag o task distinti).
- **MainActor**: tutte le mutazioni UI stato devono restare su main actor; race tra cancel e completamento naturale.
- **Scope creep**: ogni modifica a logica TASK-023 va rifiutata in review.

### Handoff → Execution
- **Prossima fase**: EXECUTION
- **Prossimo agente**: CODEX
- **Azione consigliata**: (1) Mappare tutti i `await` nel percorso `prepareFullDatabaseImport` per inserire `Task.checkCancellation()` o equivalente. (2) Aggiungere stato task salvato + bottone Annulla su `importProgressOverlay` con visibilita' condizionata. (3) Decidere e implementare la policy apply-cancel (default: **no cancel** in apply). (4) Ridurre doppio overlay sheet/Database se banale. (5) Stringhe localizzate minime. (6) Verificare CA/TM.

---

## Execution (Codex)
*(Da compilare in fase EXECUTION.)*

## Fix (Codex)
*(Da compilare se necessario.)*

## Review (Claude)
*(Da compilare in fase REVIEW.)*

## Decisioni
| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|-------|
| 1 | Cancel **prioritario** su prepare; apply **senza** rollback atomico | Cancel libero durante apply con promessa rollback | Onesta' su SwiftData save a batch; perimetro minimo |
| 2 | Task handle salvato in `DatabaseView` + propagazione cancellation nella pipeline | Solo flag booleano senza Task | Cooperative cancellation idiomatica in Swift |

---

## User override — switch task (2026-03-24)
- TASK-024 attivato come task attivo su decisione utente mentre TASK-023 e' messo in pausa (BLOCKED) senza DONE.
- Planning TASK-024 completato in questa sessione; **execution non avviata**.
