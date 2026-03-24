# TASK-024: Full-database import progress UX + cancellation

## Informazioni generali
- **Task ID**: TASK-024
- **Titolo**: Full-database import progress UX + cancellation
- **File task**: `docs/TASKS/TASK-024-full-database-import-progress-ux-cancellation.md`
- **Stato**: ACTIVE
- **Fase attuale**: REVIEW
- **Responsabile attuale**: CLAUDE
- **Data creazione**: 2026-03-24
- **Ultimo aggiornamento**: 2026-03-23
- **Ultimo agente che ha operato**: CODEX

## Dipendenze
- **Dipende da**: TASK-022 (apply full-database stabile); la pipeline `DatabaseImportPipeline` / progress snapshot in `DatabaseView.swift` e' il presupposto. TASK-023 (idempotency + delta non-product) puo' essere in corso o in pausa: **non e' prerequisito** per TASK-024 e non va mescolato nel perimetro.
- **Sblocca**: UX prevedibile su import full-database lunghi; base per eventuali hardening futuri senza confondere correzione dati e feedback utente.

## Scopo
Migliorare in modo **minimo** la **UX di progresso** e introdurre una **cancellazione/abort controllato** (dove realistico) per il flusso **full-database import** (prepare → analisi → apply), con **messaggi di stato espliciti**, **presentazione leggibile dell'esito finale** (successo / errore / annullato, incl. metriche quando presenti) e **pulizia overlay/stato** in tutti gli esiti, **senza** refactor della pipeline dati ne' della logica TASK-023.

## Contesto
Dopo TASK-022 il apply grande non crasha. TASK-023 ha affinato idempotency/delta non-product. Resta il problema percepito dagli utenti: fasi lunghe (parsing, analyze, apply prodotti, apply price history) con **feedback ancora generico** o **duplicato** (overlay Database + overlay nella sheet di analisi durante Apply), e **nessuna cancellazione cooperativa** del `Task` async. TASK-024 isola solo progress + cancel + coerenza UI, in linea con Vibe Coding.

## Non incluso
- Logica dedup / fingerprint / `hasWorkToApply` / delta non-product (TASK-023).
- Riapertura o merge in TASK-011.
- Refactor largo di `DatabaseImportPipeline`, parser Excel, o redesign della schermata Database.
- Atomicita' transazionale "ideale" su tutto l'apply se non ottenibile senza cambi architetturali maggiori (vedi Integrita' dati: onesta' su best-effort).
- Progress/cancel per **import prodotto semplice** (CSV / Excel singolo foglio) salvo dove lo stesso `importProgress` e' gia' condiviso e il cambiamento e' **triviale e a rischio zero** (da valutare in execution; non obiettivo primario).
- **Result presentation**: redesign della **result surface** strutturata e sostituzione del binario `resultMessage`/`alert` legacy valgono il percorso **full-database import** (prepare → sheet analisi → apply full). **Non** e' obiettivo uniformare tutta la tab Database ne' migrare CSV / Excel semplice a quel sistema — salvo **micro-fix a rischio zero** gia' coperti da CA-5 e nessuna regressione.

## File potenzialmente coinvolti
- `iOSMerchandiseControl/DatabaseView.swift` — `DatabaseImportProgressState`, `DatabaseImportProgressSnapshot`, `DatabaseImportProgressStage`, `importProgressOverlay`, `importFullDatabaseFromExcel`, `applyConfirmedImportAnalysis`, `DatabaseImportPipeline.prepareFullDatabaseImport` / `applyImportAnalysisInBackground`.
- `iOSMerchandiseControl/ImportAnalysisView.swift` — `isApplying`, `processingOverlay` (o equivalente durante apply), toolbar Cancel/Apply, allineamento con progresso globale senza duplicare spinner.
- `*.lproj/Localizable.strings` — stringhe fase/cancel/messaggi finali (solo chiavi nuove o riuso chiavi esistenti).

---

## Planning (Claude)

### Analisi — stato attuale nel codice (verificato)

**Modello stato UI** (`DatabaseImportProgressState`, ~1389+):
- `isRunning`, `showsOverlay`, `stageText`, `processedCount`/`totalCount`, `resultMessage`/`resultIsError`.
- `progressFraction: Double?` — computed, ritorna `processedCount/totalCount` se `totalCount > 0`, altrimenti `nil` (usata per barra lineare; da **riutilizzare** nella nuova surface se serve).
- `resultTitle: String` — computed, ritorna titolo localizzato distinto per errore vs successo (`database.error.import_title` / `database.progress.completed_title`); **sara' sostituito/assorbito** dal payload strutturato della result surface.
- `startPreparation()`: overlay **on**, fase iniziale "Preparing...".
- `apply(snapshot)`: overlay **on**, testo da `DatabaseImportUILocalizer.progressText` + barra se `totalCount > 0`.
- `awaitingConfirmation()`: **`isRunning` resta true** ma **`showsOverlay = false`** — l'utente vede la **sheet di analisi** senza overlay full-screen sulla tab Database.
- `finishSuccess` / `finishError` / `resetRunningState`: chiudono overlay e azzerano stato corsa; risultato oggi in **`alert` dedicato** (legacy — da sostituire con **result surface** unica).
- `clearResult()`: azzera `resultMessage` e `resultIsError`; chiamata dall'alert dismiss attuale. **Da adattare/sostituire** col cleanup della nuova result surface.

**Snapshot pipeline** (`DatabaseImportProgressSnapshot` + `DatabaseImportProgressStage`):
- Fasi: `parsingExcel`, `parsingSheet(name)`, `analyzing`, `applyingProducts`, `applyingPriceHistory`.
- `reportImportProgress` invia aggiornamenti a batch durante apply prodotti e price history.
- **Batch sizes**: `importProgressBatchSize = 25` (frequenza report UI), `importSaveBatchSize = 250` (frequenza `context.save()` su disco). Punti **naturali** per inserire `Task.checkCancellation()` nella pipeline prepare (dopo ogni report batch o save batch).

**Prepare full import** (`importFullDatabaseFromExcel`):
- `Task { }` **senza** handle salvato: **nessun** `cancel()` cooperativo.
- `prepareFullDatabaseImport` riceve `onProgress` ma **non** ancora propagazione strutturata di cancellazione (es. `Task.checkCancellation()` nei punti naturali) — da introdurre in execution.
- La copia del file in temp (`copySecurityScopedImportFileToTemporaryLocation`) avviene **prima** del `Task` async: e' **sincrona** rispetto al flusso UI; la cancellazione cooperativa non puo' interromperla finche' non si sposta o si accetta questo limite (vedi *Limiti noti* nel planning).

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

**Doppio alert legacy (canale prepare vs canale apply)**:
- **`importError`** (`@State private var importError: String?`, ~riga 1485) → usato per errori **prepare** (incluso full-database: `finalizeImportPreparationFailure` scrive qui). Mostrato da un **`.alert`** dedicato (~righe 1810-1823), **separato** dall'alert del risultato apply.
- **`resultMessage`** (in `DatabaseImportProgressState`) → usato per esiti **apply** (successo/errore). Mostrato da un **secondo `.alert`** (~righe 1824-1840) tramite `resultTitle` + `clearResult()`.
- **Conseguenza per TASK-024**: sul percorso **full-database**, oggi ci sono **due alert distinti** per fasi diverse dello stesso flusso. La nuova **result surface unica** (CA-result-4) deve assorbire **entrambi** per il percorso full: sia errori prepare (`importError`) sia esiti apply (`resultMessage`). Se solo uno viene migrato, resta un **doppio binario** parziale. `importError` per **non-full** (CSV, Excel semplice) puo' restare invariato (**CA-scope**).

**Cancellazione "reale" oggi**:
- **No** cooperativa sulla pipeline async.
- L'utente puo' chiudere la sheet in attesa conferma (`handleImportAnalysisDismissed` resetta se `isRunning`) — non e' cancel del prepare in corso.

### Scope minimo TASK-024
- **Solo** full-database import path (stesso entry point che oggi usa `importProgress` + `prepareFullDatabaseImport` + sheet analisi + apply).
- Progress: testi/frazioni gia' esistenti **rafforzati** dove serve (chiarezza fase, evitare ridondanza overlay).
- Cancel: dove **sicuro e implementabile** senza promettere rollback totale impossibile.
- Messaggistica e reset stato/overlay in tutti gli esiti.
- **Esito finale** (**solo full-database**): la **result surface** strutturata unica sostituisce/assorbe il percorso legacy (`resultMessage` + `alert`) **per gli esiti del full import** (successo / errore / annullato su quel flusso). **CSV / Excel semplice**: `importError` e canali equivalenti possono **restare invariati** in questo task; nessun obbligo di refactor ampio della messaggistica non-full.
- **Escluso**: modifiche alla semantica dati TASK-023, nuove feature Database non legate all'import; **sistema unico di outcome** per tutta la schermata Database (fuori perimetro).

### Design tecnico proposto

1. **Task handle cancellabile e lifecycle completo**
   - Conservare in `DatabaseView` (es. `@State private var fullImportTask: Task<Void, Never>?` o equivalente) il `Task` avviato per **prepare** full-database **solo** (non riusare lo stesso handle per apply: apply resta su percorso distinto / `Task.detached` esistente).
   - **Lifecycle obbligatorio del handle**: (a) assegnare quando parte il job; (b) `cancel()` difensivo su eventuale task precedente **prima** di avviarne uno nuovo; (c) azzerare il riferimento (`nil`) su **success** prepare, su **errore** prepare, su **cancel** utente; (d) valutare ripulitura se il flusso viene abbandonato (es. navigazione tab) se in execution emerge che un task orfano puo' ancora pubblicare stato — obiettivo: nessun handle appeso ne' completamenti fantasma.
   - **Anti-race cancel vs completamento prepare**: prima di pubblicare su `MainActor` l'apertura della sheet (`importAnalysisSession`, `pendingFullImportContext`, `awaitingConfirmation()`), verificare che il completamento appartenga ancora al **job corrente**. Raccomandato: **run ID / token monotono** (es. `UUID` o `Int` incrementale per ogni avvio prepare) catturato alla partenza del task e confrontato sul main actor nel blocco di successo; se l'utente ha cancellato o ha avviato un nuovo import, il token non coincide → **non** aprire la sheet ne' aggiornare sessione. Stessa guardia utile dopo un retry rapido che cancella il task precedente.
   - Propagazione: `Task.checkCancellation()` (o `Task.isCancelled`) nei punti **naturali** della pipeline — dopo ogni `await onProgress`, tra sheet parse, tra batch di righe **dove gia' si fa await** — **senza** riscrivere tutto il parser; valutare in execution se togliere `Task.detached` **solo** da `prepareFullDatabaseImport` per ereditare la cancellazione del task chiamante.

2. **Prepare / parsing / analyze**
   - **Supporto cancel: SI (obiettivo)** tra sotto-fasi e dopo chunk di lavoro dove la pipeline gia' `await`a (es. dopo lettura foglio, dopo analisi). Se alcuni passaggi sono sincroni lunghi senza await, documentare come **limite** noto (CA esplicito).
   - Su cancel: interrompere task, `MainActor` → `resetRunningState` o stato dedicato **cancelled**, `importAnalysisSession = nil`, `pendingFullImportContext = nil`, temp file gia' gestito da `defer`.
   - **`CancellationError` (o equivalente)**: ramo **dedicato** nel catch del task prepare — **non** riusare `finalizeImportPreparationFailure` / `importError` generico per l'annullamento utente; esito **cancelled** con **result surface** (titolo + contenuto) distinti da errore file/prepare (allineato a CA-8).

3. **Apply products / apply price history**
   - **Cancel durante apply**: tecnicamente **non atomico** per via di `context.save()` a batch. **Decisione pianificata**:
     - **Opzione A (preferita, minima)**: durante apply **non** offrire cancel "silenzioso" che simuli rollback; se si offre, mostrare **avviso** che puo' lasciare dati parziali, oppure **disabilitare** cancel mentre `applyingProducts` / `applyingPriceHistory` (solo prepare + "waiting" cancellabili).
     - **Opzione B** (solo se utente accetta complessita' extra in un task successivo, **fuori** perimetro stretto): transazione unica — probabile **fuori scope** per SwiftData usage attuale.
   - **Scelta raccomandata per TASK-024**: cancel **abilitato** in **prepare** (parsing + analyze nel task prepare); **disabilitato o assente** durante **apply** dopo conferma, con messaggio chiaro nella UI ("L'applicazione non puo' essere interrotta senza lasciare dati parziali") **oppure** cancel con conferma + messaggio **best-effort stop** senza rollback (documentato in CA).

4. **Stati distinti e policy di cancellabilita' tipizzata**
   - Modello logico: `idle` | `runningPrepare` | `awaitingUserConfirmation` | `runningApply` | `completedSuccess` | `completedError` | `cancelledByUser`.
   - **Non basare la visibilita' del bottone Annulla solo su `stageText` o stringhe localizzate**: introdurre in `DatabaseImportProgressState` (o equivalente) una **policy esplicita e tipizzata** — es. `currentStage` / `operationPhase` enum, oppure `isCancellationAllowed: Bool` derivato da **fase + contesto / job kind** (tipo di import attivo), non dalla fase da sola. **Il cancel in UI e' ammesso solo per full-database prepare/analyze**; CSV e Excel semplice riusano lo stesso `importProgress` ma **non** devono ereditare per errore il bottone o l'affordance di cancel pensata per il full prepare.
   - Obiettivo: cancel mostrato **solo** con job kind = full-database **e** fase prepare/analyze sicura; **mai** durante `applyingProducts` / `applyingPriceHistory` (nessun finto stop sicuro).
   - Implementazione: estendere leggermente `DatabaseImportProgressState` **o** mappare su campi esistenti + enum/`ImportRunOutcome?` senza esplodere i tipi.

5. **Semantica `awaitingUserConfirmation` (baseline minimal-change)**
   - Oggi `awaitingConfirmation()` lascia **`isRunning == true`** e **`showsOverlay == false`** mentre la sheet di analisi e' visibile: tratta questo come **baseline da preservare** salvo necessita' dimostrata. Ritocchi ammessi **solo** se localizzati e senza rompere dismiss sheet (`handleImportAnalysisDismissed`), reset stato, gating toolbar, ne' la distinzione tra "corsa attiva ma overlay off" vs idle completo.
   - Obiettivo execution: non "ripulire" questa semantica per abitudine architetturale se non serve al TASK-024.

6. **Zombie overlay / sessioni appese**
   - Ogni uscita (success, error, cancel prepare) deve chiamare percorsi che portano a `showsOverlay == false` e `isRunning` coerente (dopo conferma utente sull'**esito finale** — una sola superficie, vedi **CA-result-4**).
   - `handleImportAnalysisDismissed` gia' resetta se import "in corso" senza sessione: mantenere e testare dopo cancel.

7. **Esito finale — sorgente dati strutturata e sequenza di presentazione**
   - **Modello / payload per la UI**: la nuova presentazione dell'esito **non** va costruita a partire da una **singola stringa concatenata** che la view mostra cosi' com'e'. La UI deve essere alimentata da un **tipo strutturato** o **campi separati** (es. outcome, summary, elenco metriche, note secondarie, hint CTA), cosi' la view decide layout e righe senza **parsing fragile** o composizione monolitica lato execution. Obiettivo: evitare di mantenere solo `userMessage` unica e "infilarla" in una superficie diversa (vedi **CA-result-3**).
   - **Ordine operativo dopo apply** (e analogamente dove ha senso per errore/annullato che passano da sheet + overlay): (1) **termina** l'overlay di progresso (`showsOverlay` / stato corsa coerente); (2) **chiude** la sheet di analisi (`importAnalysisSession` dismissed); (3) **solo dopo** mostra la superficie dell'esito finale. Evita risultato **dietro** la sheet, comparsa **troppo presto**, **doppia** superficie temporanea o glitch visivi. Stessa logica coerente per **successo**, **errore** e **annullato** ove applicabile al flusso.
   - **Sequenza state-driven, non time-based**: implementare questo ordine tramite **stato / flusso UI coerente** (transizioni su binding, completion del dismiss della sheet, `onDismiss` o pattern SwiftUI equivalenti), **non** con **delay artificiali** (`DispatchQueue.main.asyncAfter` per sincronizzare l'esito), **sleep**, timeout UI o hack legati alla durata delle animazioni. Obiettivo: robustezza indipendente dai tempi della sheet.
   - **Meccanismo dismiss sheet durante/dopo apply**: la sheet `ImportAnalysisView` viene chiusa impostando `importAnalysisSession = nil` (vedi `handleImportAnalysisDismissed`). Attualmente `finishSuccess`/`finishError` **non** chiudono la sheet — lo fanno solo indirettamente se l'utente la dismissa o se il codice esplicita il nil. Per la sequenza §7, **execution** deve assicurarsi che al termine dell'apply (success/error) venga impostato `importAnalysisSession = nil` **prima** di presentare la result surface, usando `onDismiss` della sheet o transizione di stato (non delay). `pendingFullImportContext` va azzerato contestualmente.
   - **Cleanup dopo chiusura result surface**: alla dismissal (OK / Chiudi), il **payload / stato outcome** della result surface va **azzerato esplicitamente** (`nil` o reset strutturato), riportando `DatabaseView` in **idle / ready** per un nuovo import — nessuna **riapparizione** dell'esito precedente su retry, nessuno **stale state**, nessun residuo accanto a campi legacy assorbiti. Un'unica **source of truth** per l'outcome finche' la surface e' visibile; poi ripulitura netta.
   - **Fonte unica dell'esito (no doppio binario) — perimetro full-database**: per il flusso **full-database import**, la result surface strutturata e' l'**unica** presentazione finale per quel outcome — **un solo stato / payload** sul main actor. Il legacy `resultMessage` + **`alert`** su quel percorso va **sostituito/assorbito**, mai in parallelo (**CA-result-4**, **TM-18**). **Fuori da questo perimetro**: `importError` e messaggistica **CSV / Excel semplice** non sono oggetto di redesign outcome in TASK-024 (**CA-scope**).

### UX minima richiesta

| Elemento | Specifica |
|----------|-----------|
| Overlay Database | Mantenere card con **titolo fase** + `ProgressView` lineare quando c'e' `totalCount`, altrimenti indeterminato. |
| Testi fase | Riutilizzare chiavi `database.progress.*` esistenti; aggiungere solo se serve distinzione **Cancellazione in corso...** / **Import annullato**. |
| Bottone **Annulla** | Visibile **solo** con **job kind** = full-database prepare/analyze **e** fase cancellabile **e** `showsOverlay` (non basarsi solo sullo stage condiviso con altri import). |
| Cancel durante prepare | Interrompe task, **nessuna** apertura sheet analisi; messaggio dedicato "Import annullato" (non errore generico). |
| Cancel durante analyze | Se analyze e' nello stesso task prepare, stesso comportamento; **non** mostrare analisi parziale. |
| Cancel durante apply | Per default **non offerto**; se offerto con conferma: messaggio su possibile stato parziale + CA esplicito. |
| Superficie unica di progresso (apply) | **Raccomandazione primaria**: durante apply la **fonte principale** di progresso dettagliato (fase + barra/numeri) e' l'**overlay** in `DatabaseView` (`importProgressOverlay`). La sheet `ImportAnalysisView` resta **disabilitata** (`isApplying`) e **senza** secondo spinner / overlay animato ridondante: al massimo messaggio statico breve che rimanda al tab Database (formulazione leggermente flessibile consentita, ma la direzione deve restare chiara in execution/review). |
| Retry dopo cancel/failure | Utente puo' rilanciare import da menu: `importProgress.isRunning` deve essere **false** e nessun overlay attaccato. |

#### Presentazione dell'esito finale (successo / errore / annullato)

- **Problema attuale**: il dialogo risultato e' funzionale ma, con **piu' metriche** (nuovi/aggiornati, storico prezzi, suffissi fornitori/categorie, ecc.), il body tende a un **unico paragrafo compresso** e poco scansionabile.
- **Requisito**: l'esito **non** va presentato come un solo blocco di testo denso quando ci sono **piu' voci numeriche o messaggi distinti**. Struttura minima consigliata:
  1. **Stato / titolo** (es. completato, errore, annullato)
  2. **Breve summary** (una riga o due)
  3. **Righe metriche separate** (una metrica per riga o blocco chiaro)
  4. **Note secondarie** (warning, irrisolti, dettaglio errore) se presenti
  5. **CTA** esplicita (OK / Chiudi) che chiude e ripristina l'uso della tab
- **Direzione UX (minima, pragmatica)**: se il risultato supera una **singola frase semplice**, preferire una **superficie custom** coerente con l'app (es. card, dialog SwiftUI composito, overlay result dedicato su `DatabaseView`) invece di un **solo** `alert` nativo con body lungo. Non e' richiesto un redesign esteso: solo leggibilita' e gerarchia.
- **Testi lunghi** (summary, note secondarie, dettaglio errore): la superficie finale deve restare **leggibile** — **multiline** corretta, **nessun** unico blocco compresso; se serve, **ScrollView** (o layout equivalente) che non **schiacci** il contenuto. Protezione UX minima, non redesign.
- **Sequenza (stato, non timer)**: allinearsi al Design §7 — progresso finito, sheet chiusa, poi esito; **senza** ritardi artificiali (vedi §7 bullet *state-driven*).
- **Metriche opzionali** (mostrare su righe distinte quando disponibili; **omettere** se assenti o **0** per non appesantire): prodotti nuovi; prodotti aggiornati; storico prezzi salvato; fornitori creati; categorie create; elementi irrisolti / warning rilevanti.
- **Tre esiti logici — anche in UI**: non basta differenziare il **testo**. Successo, errore e annullato devono avere **gerarchia visiva riconoscibile** (es. titolo, SF Symbol / tono semantico, ordine delle sezioni). **Nessun colore obbligatorio** fissato nel piano; execution/review scelgono valori coerenti con il tema.
- **Vincolo di minimalismo**: solo la **superficie del risultato finale**; **no** redesign della schermata Database, **no** nuove navigazioni, **no** flussi complessi aggiuntivi.
- **Una sola verita' UI per esito**: successo / errore / annullato devono attraversare **un solo canale** di presentazione finale (payload + superficie strutturata), senza convivenza con alert string-based legacy sullo stesso flusso (allinea Design §7 ultimo bullet).

### Integrita' dati

- **Prepare**: in genere **nessun** `save()` su modello principale fino ad apply (verificare in execution che prepare full resti read-only salvo design attuale); cancel prepare → basso rischio residui nel DB.
- **Apply**: `saveImportProgressIfNeeded` persiste **a tratti**. **Non** si garantisce rollback atomico su cancel a meta' apply senza redesign.
- **Impegno TASK-024**: documentare in UI + CA che **l'interruzione durante apply non e' reversibile**; default **non** esporre cancel in quella fase.
- Se in futuro servisse atomicita', e' **follow-up** architetturale, non parte di questo task.

### Limiti noti (cancellazione cooperativa)

- **Copia iniziale su file temporaneo**: nel codice attuale `importFullDatabaseFromExcel` chiama `copySecurityScopedImportFileToTemporaryLocation` **nel thread del chiamante** prima di entrare nel `Task` che esegue `prepareFullDatabaseImport`. Quindi l'utente puo' premere Annulla **solo dopo** che l'overlay/prepare async e' partito; il tratto sincrono di copia **non** e' interrompibile via `Task.checkCancellation()` senza refactor piu' ampio (fuori perimetro se non strettamente necessario). Da dichiarare onestamente in execution/review: cancel **non** garantisce interruzione immediata su quel segmento.
- Restano possibili tratti **sincroni lunghi** dentro parser/analisi senza `await` tra un punto e l'altro: gia' citati in §2 prepare; non promettere latenza zero sulla risposta al cancel.

### Criteri di accettazione

- **CA-1**: Durante prepare full-database, l'utente vede **fase** e, quando disponibile, **progresso numerico** (come oggi o migliorato) senza regressioni su import che prima completavano.
- **CA-2**: In fase **cancellabile** (prepare/analyze nel task prepare **full-database**), il bottone **Annulla** interrompe il lavoro, **non** apre la sheet analisi, **non** lascia `showsOverlay` bloccato, e mostra messaggio **esplicito** di annullamento (non confuso con errore file). Import CSV / Excel semplice **non** espongono cancel (nessuna regressione affordance).
- **CA-3**: **Full-database**: dopo **errore** prepare o apply, overlay chiuso, UI usabile, **result surface** errore coerente; corpo ricco → **CA-result-1**. **Non-full** (CSV, Excel semplice): errori possono restare su baseline (`importError` / UI attuale); **nessun** obbligo di result surface in questo task (**CA-scope**).
- **CA-4**: Dopo **cancel** consentito, `importProgress.isRunning` e overlay tornano coerenti con **idle**; e' possibile **riprovare** un import senza riavviare l'app.
- **CA-5**: **Nessuna regressione** su import Excel semplice (stesso `importProgress` condiviso: verificare che non resti bloccato `isRunning`).
- **CA-6**: **Nessuna regressione** su full import **completato con successo** fino in fondo (stesso risultato funzionale di oggi).
- **CA-7**: Se cancel durante apply **non** e' offerto: documentato in planning + stringa UI o help implicito; se offerto con conferma: CA separato che il DB puo' essere **parzialmente aggiornato** e l'utente e' avvisato.
- **CA-8**: Stati finali distinguibili almeno a livello di messaggio: successo / errore / **annullato** (tre vie logiche); per il livello **visivo** vedi **CA-result-2**.
- **CA-9** (anti-race): Dopo cancel o dopo un nuovo import avviato in rapida successione, un prepare **obsoleto** non deve poter aprire la sheet di analisi ne' scrivere sessione/context per quel job (verifica tramite guardia token/run ID o equivalente).
- **CA-result-1**: Quando l'esito include **piu' metriche** o piu' messaggi distinti, la presentazione e' **leggibile** (blocchi/righe), **non** come un unico paragrafo compresso; CTA di chiusura chiara.
- **CA-result-2**: Successo, errore e annullato sono **chiaramente distinguibili** non solo nel testo ma nella **gerarchia visiva** (titolo, icona/tone, ordine informazioni coerente con l'esito).
- **CA-result-3**: La result surface non dipende da una **sola stringa monolitica** per comporre l'intera UI: esiste un **payload / campi strutturati** (outcome, summary, metriche, note, ecc.) che la view usa per disporre blocchi e righe; niente strategia "una `String` concatenata + view che la stampa tutta".
- **CA-result-4**: **Una sola** superficie finale per ogni esito: **non** esistono due presentazioni concorrenti (es. nuova result surface **e** vecchio `alert` legacy) per lo stesso outcome; successo, errore e annullato passano da **un'unica source of truth** (stato/payload outcome → una UI di chiusura).
- **CA-result-5**: La sequenza overlay → sheet → result e' **guidata da stato** (no delay/sleep/asyncAfter per sincronizzare); alla chiusura della result surface il **payload outcome** e' **ripulito esplicitamente** — niente stale ne' riesposizione su import successivi.
- **CA-scope**: **Full-database import** → nuova **result surface** unica per esiti successo/errore/annullato (come da CA-result-*). **Import non-full** (CSV, Excel semplice) → **nessuna regressione**, **nessun** refactor ampio della presentazione finale richiesto; `importError` / flussi esistenti restano ammessi invariati salvo micro-fix a rischio zero.

### Test manuali (checklist)

| # | Scenario | Esito atteso |
|---|----------|--------------|
| TM-1 | Cancel durante parsing fogli (prepare) | Task si ferma; nessuna analisi; overlay chiuso; **result surface** annullamento; UI usabile |
| TM-2 | Cancel durante fase analyzing (stesso task prepare) | Come TM-1 |
| TM-3 | Full import completo senza cancel | Comportamento come baseline; **result surface** successo coerente (post-§7) |
| TM-4 | Errore file invalido in prepare | **Superficie finale dell'esito** (errore); overlay off; retry possibile |
| TM-5 | Apply completo dopo conferma | Nessun stallo; sheet si chiude; **result surface** successo (sequenza §7) |
| TM-6 | Apply con errore (simulato o reale) | Overlay off; **result surface** errore leggibile; sessione reset coerente |
| TM-7 | **Se** cancel apply non supportato: verificare assenza bottone o disabilitazione durante `applyingProducts` / `applyingPriceHistory` | Nessun finto "stop sicuro" |
| TM-8 | **Se** cancel apply supportato con conferma: interrompere a meta' | DB potenzialmente parziale; messaggio onesto; CA-7 |
| TM-9 | Retry dopo cancel prepare | Secondo import parte pulito; **nessun** esito precedente che riappare (**CA-result-5** cleanup) |
| TM-10 | Retry dopo failure | Come TM-9; verificare reset payload result dopo OK sulla surface |
| TM-11 | Confronto **CSV / Excel semplice** vs **full-database** | Non-full: comportamento **baseline** (es. `importError` dove gia' usato); full: **result surface** nuova per esiti finali; nessuna regressione incrociata |
| TM-12 | Cancel premuto **immediatamente prima** o **contemporaneamente** al completamento naturale del prepare/analyze (stress sul confine) | La sheet di analisi **non** deve aprirsi in ritardo per un job gia' annullato; stato UI coerente (nessuna sessione fantasma); eventualmente ripetere con retry rapido dopo cancel per esercitare il token/run ID |
| TM-13 | Stress **start → cancel → secondo full import immediato** (opz.: ripetere cancel+retry una seconda volta) | Nessuna sheet/overlay/sessione del **primo** job; handle/token coerenti; solo il secondo (o ultimo) job valido evolve la UI; Database resta retryable |
| TM-14 | **Successo** dopo apply con **molte metriche** valorizzate (nuovi, aggiornati, price history, suffissi fornitori/categorie se applicabili) | Leggibile; niente "muro" di testo; metriche scansionabili; CTA OK chiara; dopo chiusura nessun overlay import bloccato; `isRunning` coerente |
| TM-15 | **Errore** in prepare o apply (messaggio non banale) | Stesso criterio: leggibilita', gerarchia visiva **errore** vs successo (TM-14); CTA chiara; nessun overlay bloccato dopo OK |
| TM-16 | **Annullato** dopo cancel prepare | Presentazione **annullato** distinta da errore/successo (titolo/tone/icona); messaggio chiaro; CTA chiara; nessun overlay bloccato dopo OK |
| TM-17 | **Errore** o **nota secondaria** molto lunga (o messaggio di fallimento dettagliato) | Testo **leggibile** (wrap/multiline o scroll); niente paragrafo unico compresso; CTA chiara; dopo OK nessun overlay bloccato; verificare anche **sequenza** Design §7 (sheet/overlay prima dell'esito, nessun glitch di sovrapposizione) |
| TM-18 | Dopo **successo**, **errore** e **annullato** (almeno un caso ciascuno) | **Una sola** result surface per esito; nessun duplicato (incluso vecchio `alert` legacy); nessun fallback parallelo (**CA-result-4**) |

### Rischi
- **Complessita' annidata** `Task` + `Task.detached` in apply: cancel del prepare **non** deve cancellare apply gia' partito (gestire con flag o task distinti).
- **MainActor**: tutte le mutazioni UI stato devono restare su main actor.
- **Race cancel vs fine prepare**: senza guardia (run ID / token), un task che completa dopo `cancel()` o dopo un secondo avvio import puo' ancora impostare `importAnalysisSession` → **bloccante per qualita' UX**; mitigazione obbligatoria in execution (vedi Design §1).
- **Esito vs sheet**: mostrare il risultato finale **prima** che overlay progresso e sheet analisi siano stati smontati puo' causare sovrapposizioni o risultato "dietro" la sheet; rispettare la sequenza del Design §7.
- **Timing hack**: affidarsi a `asyncAfter` / sleep per ordinare sheet vs result rende il flusso fragile su device lenti o animazioni diverse; preferire stato + dismiss completion (**CA-result-5**).
- **Doppio binario esito**: lasciare alert legacy **e** nuova result surface attivi sullo stesso percorso genera duplicazioni e incertezza per l'utente; mitigazione: **CA-result-4** + assorbimento/sostituzione del vecchio meccanismo.
- **Scope creep**: ogni modifica a logica TASK-023 va rifiutata in review.
- **Ambiguita' scope**: interpretare la result surface come obbligo per **tutta** la Database (inclusi CSV/semplice) **allarga** il task; mitigazione: **CA-scope** e **Non incluso** (result presentation).

### Handoff → Execution
- **Prossima fase**: EXECUTION
- **Prossimo agente**: CODEX
- **Azione consigliata**: (0) **Scope**: result surface strutturata = **solo full-database**; non-full lasciare `importError`/baseline salvo micro-fix (**CA-scope**, **TM-11**). (1) Mappare tutti i `await` nel percorso `prepareFullDatabaseImport` per inserire `Task.checkCancellation()` — punti naturali: dopo ogni batch di 25 righe (`importProgressBatchSize`) e/o dopo save batch di 250 (`importSaveBatchSize`); valutare rimozione `Task.detached` solo su quel prepare se serve propagazione cancellazione. (2) Task handle con lifecycle completo (vedi Design §1) + **guardia anti-race** su success prepare. (3) Policy tipizzata: **fase + job kind** per cancel UI (solo full prepare/analyze). (4) Ramo dedicato `CancellationError` vs errore reale. (5) Preservare baseline `awaitingConfirmation` salvo necessita' locale (Design §5). (6) Overlay Database = progresso primario in apply; sheet senza spinner ridondante. (7) Policy apply-cancel: **no cancel** durante apply. (8) **Esito finale (full)**: **result surface** unica (payload **CA-result-3**, **CA-result-4**, Design §7), sequenza **state-driven** (**CA-result-5**), cleanup dismissal; **assorbire ENTRAMBI** gli alert legacy sul percorso full: sia `importError` (errori prepare, `finalizeImportPreparationFailure`) sia `resultMessage` (esiti apply, `finishSuccess`/`finishError`); `clearResult()` e `resultTitle` da adattare/sostituire di conseguenza. (8b) **Dismiss sheet prima della result surface**: impostare `importAnalysisSession = nil` + `pendingFullImportContext = nil` **prima** di mostrare la result surface, usando `onDismiss` o transizione di stato, **non** delay. (9) Stringhe localizzate minime. (10) Verificare CA/TM inclusi **CA-scope**, TM-11, TM-12…**TM-18**.

---

## Execution (Codex)
### Tracking / user override
- **User override applicato**: riallineamento tracking eseguito direttamente da Codex per sbloccare l'execution senza passare da un ulteriore step Claude, in coerenza con le istruzioni utente e senza ridefinire il planning.
- Tracking iniziale applicato: `PLANNING/CLAUDE` → `EXECUTION/CODEX`.

### File toccati
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-024-full-database-import-progress-ux-cancellation.md`
- `iOSMerchandiseControl/DatabaseView.swift`
- `iOSMerchandiseControl/ImportAnalysisView.swift`
- `iOSMerchandiseControl/en.lproj/Localizable.strings`
- `iOSMerchandiseControl/it.lproj/Localizable.strings`
- `iOSMerchandiseControl/es.lproj/Localizable.strings`
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`

### Modifiche implementate
- `DatabaseImportProgressState` esteso con **job kind**, **phase** e **isCancellationPending** per governare il cancel in modo tipizzato invece che tramite `stageText`; il bottone **Annulla** compare solo sul full-database prepare/analyze.
- `DatabaseImportPipeline.prepareFullDatabaseImport` non usa piu' `Task.detached` e propaga la cancellazione cooperativa tramite `Task.checkCancellation()` nei punti naturali del flow (sheet parse, analyze, classify/build summary), cosi' il task handle salvato in `DatabaseView` puo' fermare davvero il prepare.
- In `DatabaseView` il full prepare ora salva **task handle + run ID**, cancella in modo difensivo, differenzia `CancellationError`, impedisce aperture tardive della sheet da job obsoleti/cancellati e ripulisce correttamente task/context/sessione in success/error/cancel.
- L'overlay Database e' diventato la **superficie primaria unica** di progresso durante apply; `ImportAnalysisView` resta disabilitata ma mostra solo un messaggio statico, senza secondo spinner/overlay ridondante.
- Il full flow usa ora una **result surface strutturata** (`FullImportResultPayload` + `FullImportResultView`) per **successo / errore / annullato**. Gli esiti full non passano piu' dai due alert legacy separati (`importError` e `resultMessage`); i flussi non-full restano sulla baseline esistente.
- La sequenza finale del full apply e' **state-driven**: fine progresso → dismiss sheet analisi → presentazione result surface. Il payload viene pulito esplicitamente alla chiusura.
- Localizzazioni minime aggiunte/aggiornate per cancel, outcome full e messaggio statico della sheet durante apply.

### Limiti residui
- La copia iniziale del file in temp avviene ancora **prima** dell'avvio del task async: resta quindi un tratto sincrono non interrompibile dal cancel, come gia' documentato nel planning.
- Il cancel durante **apply** resta volutamente **non esposto**, per evitare di promettere rollback impossibili con i `save()` batch di SwiftData.

### Verifiche eseguite
- ✅ **BUILD** — `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
- ✅ **STATIC** — verifica log build senza warning via `xcodebuild ... | rg "warning:"` (nessun warning emerso)
- ✅ **STATIC** — controllo codepath full prepare/apply: handle + run ID anti-race, ramo `CancellationError`, outcome full-only strutturato, cleanup stato/UI, no cancel durante apply
- ✅ **STATIC** — controllo no-regression di scope: import non-full ancora instradati su `importError` / `resultMessage` legacy; nessun tocco a TASK-023 o al redesign generale Database

### Criteri / check coperti in execution
- ✅ `CA-1`, `CA-2`, `CA-4`, `CA-7`, `CA-8`, `CA-9` coperti staticamente dall'implementation del full prepare cancellabile, gating tipizzato del cancel e anti-race run ID
- ✅ `CA-3`, `CA-result-1`, `CA-result-2`, `CA-result-3`, `CA-result-4`, `CA-result-5`, `CA-scope` coperti staticamente dal nuovo payload outcome full-only, dal dismiss state-driven e dalla rimozione del doppio alert sul full flow
- ✅ `CA-5`, `CA-6` supportati da build verde e dal mantenimento del percorso legacy per import non-full
- ⚠️ Test manuali TM-1…TM-18 non eseguiti da Codex in questa fase; restano per review utente/Claude

### Handoff → Review
- Verificare nel Simulator i casi TM-1, TM-2, TM-9, TM-12 e TM-13 per stressare cancel + retry e confermare che nessun prepare obsoleto apra la sheet in ritardo.
- Verificare TM-5, TM-6, TM-14, TM-15, TM-16 e TM-18 per controllare la sequenza **overlay → dismiss sheet → result surface** e l'assenza di duplicazioni legacy sul full flow.
- Verificare TM-11 per confermare che CSV / Excel semplice restino su baseline senza nuova affordance di cancel e senza regressioni di `isRunning`.
- Se emergono problemi, il loop successivo e' **FIX → REVIEW**; nessun DONE da impostare in questa fase.

## Fix (Codex)
### Contesto
- Fix da review manuale utente (post-execution): coerenza visiva e stabilita' delle superfici full-database import **senza** cambiare logica prepare/apply/cancel/outcome.

### File toccati
- `iOSMerchandiseControl/DatabaseView.swift`
- `iOSMerchandiseControl/ImportAnalysisView.swift`
- `iOSMerchandiseControl/en.lproj/Localizable.strings`
- `iOSMerchandiseControl/it.lproj/Localizable.strings`
- `iOSMerchandiseControl/es.lproj/Localizable.strings`
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-024-full-database-import-progress-ux-cancellation.md`

### Modifiche (UI/UX)
- **Overlay progresso Database**: card piu' larga (larghezza da `GeometryReader`, clamp 300–620 pt), angolo 20, ombra leggera; area titolo/progresso/bottone Annulla con altezze piu' stabili (sezione progresso fissa 72 pt, riga bottone riservata quando il cancel non e' mostrato).
- **Esito full import**: rimosso `.sheet` + `presentationDetents` / drag indicator; stesso payload (`FullImportResultView`) presentato come **overlay centrato** sul `ZStack` della tab Database, stessa famiglia visiva (material + corner 20). OK con `.controlSize(.large)` e larghezza piena nella card.
- **Apply in `ImportAnalysisView`**: eliminato `safeAreaInset` in basso; overlay full-screen sulla lista con card centrata (stesso stile material/radius/ombra). Nessun secondo `ProgressView` (solo icona statica + testi).
- **Copy `import.analysis.processing.body`**: rimosso il messaggio che rimandava alla schermata Database; testo neutro sul salvataggio in corso e sul tenere aperta la finestra.
- **Type-checker**: estratte sotto-viste `ImportProgressMaterialCard` e `FullImportResultMaterialCard` per evitare crash del compiler Swift 6.2 su espressioni troppo annidate; `importSurfaceCardWidth(for:)` a livello file in `DatabaseView.swift`.

### Verifiche eseguite
- ✅ **BUILD** — `xcodebuild` su Simulator `iPhone 17` / iOS 26.2, `ONLY_ACTIVE_ARCH=YES`, `CODE_SIGNING_ALLOWED=NO` — **BUILD SUCCEEDED**
- ✅ **STATIC** — confermato che non risultano modifiche a pipeline dati, policy cancel/apply, o TASK-023
- ⚠️ **SIM / manuali** — non eseguiti in questa sessione; restano per l'utente (checklist sotto)

### Rischi residui
- Larghezza card in `ImportAnalysisView` duplica la formula numerica usata in `DatabaseView` (stesso clamp) senza helper condiviso tra file: accettato per perimetro minimo.
- Durante apply restano due livelli visivi (sheet analisi + overlay Database con progresso numerico): ora il copy non li contraddice; se l'utente volesse una sola superficie fisica servirebbe un task separato (fuori scope).

### Handoff → Review (Claude)
- **Prossima fase**: REVIEW
- **Prossimo agente**: CLAUDE
- **Azione consigliata**: Verificare in Simulator i criteri del fix UX (stabilita' card, apply centrato, result non-bottom-sheet, OK proporzionato) e rieseguire un sottoinsieme di TM-5, TM-11, TM-14, TM-18; nessun DONE finche' l'utente non conferma.

## Fix #2 (Claude — UI polish)
### Contesto
- Fix da review manuale utente: le surface del full-database import sono troppo grandi, troppo pesanti, con troppo spazio vuoto e gerarchia visiva non Apple-like. Richiesto polish sobrio senza toccare logica.

### File toccati
- `iOSMerchandiseControl/DatabaseView.swift`
- `iOSMerchandiseControl/ImportAnalysisView.swift`
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-024-full-database-import-progress-ux-cancellation.md`

### Modifiche (UI/UX polish)
- **Card width ridotta**: `importSurfaceCardWidth` da `width - 40, clamp 300–620` a `width - 64, clamp 280–440`. Stessa formula in `ImportAnalysisView`. Card meno invasive su iPhone, piu' proporzionate.
- **Prepare/analyze card** (`ImportProgressMaterialCard`):
  - Spacing ridotto da 18 a 14; padding da 24 a 20; corner radius da 20 a 16
  - Rimosso `minHeight: 240` — card si dimensiona naturalmente in base al contenuto
  - Rimosso placeholder `Color.clear.frame(height: 50)` quando cancel non e' mostrato — il bottone cancel ora appare solo quando serve, senza riserva di spazio
  - Titolo fase: da `.headline` a `.subheadline.weight(.medium)` — meno pesante
  - ProgressView indeterminato: da `.controlSize(.large)` a `.regular`, rimosso testo placeholder invisibile
  - Contatore: da `.caption` a `.caption2`, tinta `.tertiary` — piu' discreto
  - Cancel button: da `.borderedProminent` + `.large` + full-width a `.bordered` + `.regular` — piu' sobrio e secondario
  - Shadow ridotta da `0.12/20/10` a `0.08/12/4`
- **Result dialog** (`FullImportResultView` + `FullImportResultMaterialCard`):
  - Rimosso `minHeight: 320` — card si chiude sul contenuto
  - Padding da 24 a 20; corner radius da 20 a 16; shadow da `0.12/24/12` a `0.08/12/4`
  - Icona da 44pt a 32pt
  - Spacing principale da 20 a 14; spacing titolo/summary da 8 a 4
  - Titolo da `.title3.weight(.semibold)` a `.headline`; summary da `.body` a `.subheadline` — gerarchia piu' naturale
  - Metriche: font da `.body` a `.subheadline`; padding interno da 16 a 12; corner radius da 16 a 10; background da `.thinMaterial` a `.quaternary.opacity(0.5)` — meno "card-within-card"
  - Note: font da `.footnote` a `.caption`; stessi riduzioni padding/radius/background
  - Scroll area condizionale: ScrollView e' ora wrappata in `if !metrics.isEmpty || !notes.isEmpty` — nessuna area scroll vuota
  - maxScrollHeight da `180–420 (0.4)` a `120–280 (0.3)` — meno altezza inutile
  - OK button: da `.large` + `frame(maxWidth: .infinity)` a `.regular` senza full-width — meno isolato, piu' naturale
- **Apply card** (`applyingNotice` in `ImportAnalysisView`):
  - Icona statica sostituita con `ProgressView()` `.regular` — feedback piu' chiaro e nativo
  - Titolo da `.headline` a `.subheadline.weight(.medium)`; body da `.subheadline` a `.caption`
  - Spacing da 14 a 10; padding da 24 a 16; corner radius da 20 a 12
  - Shadow da `0.12/20/10` a `0.06/8/2` — piu' discreta
- **Scrim** (dimming dietro le overlay): opacita' uniformata a `0.12` (da 0.16/0.18) — meno pesante

### Cosa NON e' stato toccato
- Nessuna modifica a pipeline dati, anti-race, policy cancel/apply, outcome payload, state flow
- Nessuna modifica a stringhe localizzate
- Nessuna modifica a import CSV / Excel semplice
- Nessuna modifica a TASK-023

### Verifiche
- ✅ **BUILD** — `xcodebuild` su Simulator generic, `CODE_SIGNING_ALLOWED=NO` — **BUILD SUCCEEDED**
- ✅ **STATIC** — confermato scope solo UI: padding/spacing/font/radius/shadow/opacity; nessun cambio a logica
- ⚠️ **SIM / manuali** — restano per l'utente

### Limiti residui
- Il bottone Cancel nella prepare card ora non ha piu' riserva di spazio quando assente: la card cambia leggermente altezza tra stato con/senza cancel. Effetto atteso e corretto per un layout naturale.
- Le due card (DatabaseView e ImportAnalysisView) usano la stessa formula numerica per il width senza un helper condiviso tra file — accettato come nel fix precedente.

### Handoff → Review (Claude)
- **Prossima fase**: REVIEW
- **Prossimo agente**: CLAUDE
- **Azione consigliata**: Verificare in Simulator che le superfici siano ora piu' compatte, proporzionate e Apple-like. Sottoinsieme TM consigliato: TM-3 (successo con metriche), TM-5 (apply completo), TM-14 (metriche multiple), TM-16 (annullato). Nessun DONE.

## Fix #3 (Claude — result surface layout fix)
### Contesto
- Fix da review manuale utente: la finestra "Import completato" ha metriche con label collassate/invisibili (bug di layout), troppo spazio vuoto, bottone OK troppo distante, aspetto non Apple-like.

### File toccati
- `iOSMerchandiseControl/DatabaseView.swift`
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-024-full-database-import-progress-ux-cancellation.md`

### Root cause del bug metriche
Il layout `HStack { Text(label) Spacer(minLength: 8) Text(value) }` comprimeva la label a zero su card strette (280–440pt meno padding). Il Spacer e il value text prendevano priorita', la label senza `layoutPriority` ne' `fixedSize` collassava.

### Modifiche
- **Bug metriche risolto**: label ha ora `layoutPriority(1)` + `fixedSize(horizontal: false, vertical: true)` (wrappa ma non collassa); value ha `fixedSize(horizontal: true, vertical: false)` (non si tronca); `Spacer(minLength: 12)` tra i due.
- **Metriche ristrutturate**: blocco ora usa `Divider()` tra righe invece di spacing, con padding `vertical: 6` + `horizontal: 10` per riga. Background da `.quaternary.opacity(0.5)` a `Color(.secondarySystemGroupedBackground)` — stile grouped iOS nativo. Corner radius da 10 a 8.
- **Header piu' compatto**: icona da 32pt a 28pt; titolo da `.headline` a `.subheadline.weight(.semibold)`; spacing header interno da 4 a 6 (icona+titolo raggruppati); summary separato, da `.subheadline` a `.footnote`.
- **Spacing generale**: VStack principale da 14 a 12.
- **Notes**: font da `.caption` a `.caption2`, tinta `.tertiary`; rimosso background `.quaternary` — solo testo leggero con padding orizzontale minimo.
- **OK button**: da `.controlSize(.regular)` a `.controlSize(.small)` + `padding(.top, 2)` — proporzionato al contenuto senza dominare.
- **Card wrapper** (`FullImportResultMaterialCard`): padding da `20` uniforme a `horizontal: 16, vertical: 18`; corner radius da 16 a 14; shadow da `0.08/12/4` a `0.1/10/4` — leggermente piu' definita ma non pesante.
- **Font metriche**: da `.subheadline` / `.subheadline.weight(.semibold)` a `.footnote` / `.footnote.weight(.medium)` — proporzionate alla card.

### Cosa NON e' stato toccato
- Nessuna modifica a logica, payload, state flow, anti-race, cancel/apply
- Nessuna modifica a prepare/analyze card
- Nessuna modifica a ImportAnalysisView
- Nessuna modifica a stringhe localizzate
- Nessuna modifica a TASK-023

### Verifiche
- ✅ **BUILD** — `xcodebuild` Simulator generic — **BUILD SUCCEEDED**
- ✅ **STATIC** — scope solo layout/styling della result surface; nessun cambio logica
- ⚠️ **SIM / manuali** — restano per l'utente

### Limiti residui
- Il `maxScrollHeight` e' ancora passato dall'overlay come `max(120, min(geo.size.height * 0.3, 280))` — con poche metriche potrebbe non servire scroll; ma ScrollView e' wrappato in condizionale e non aggiunge altezza inutile quando il contenuto e' breve.

### Handoff → Review (Claude)
- **Prossima fase**: REVIEW
- **Prossimo agente**: CLAUDE
- **Azione consigliata**: Verificare in Simulator che le metriche siano ora visibili (label + value), la card sia compatta, e il bottone OK sia integrato. TM-3, TM-14, TM-15, TM-16.

## Fix #4 (Claude — result surface: torna a sheet nativa)
### Contesto
- Fix da review manuale utente: la finestra "Import completato" presentata come overlay centrato con material card non piace. L'utente vuole tornare alla presentazione **bottom sheet nativa** come nella vecchia versione (`2-4.png`).

### File toccati
- `iOSMerchandiseControl/DatabaseView.swift`
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-024-full-database-import-progress-ux-cancellation.md`

### Modifiche
- **Presentazione**: da **overlay centrato** (`GeometryReader` + `ZStack` + scrim + `FullImportResultMaterialCard`) a **`.sheet(item: $fullImportResultPayload)`** con `presentationDetents([.medium])` + `presentationDragIndicator(.visible)`. Nativa iOS, bottom sheet standard.
- **Rimossi**: `FullImportResultMaterialCard`, `fullImportResultOverlay()`, e il ramo overlay nel body `ZStack`. Codice morto eliminato.
- **`FullImportResultView` semplificata**: rimosso parametro `maxScrollHeight` (non serve in una sheet nativa); layout riscritto per contesto sheet:
  - Icona 44pt (piu' visibile nella sheet), titolo `.title3.weight(.semibold)`, summary `.subheadline`
  - Metriche: `.body` font, `Divider()` tra righe, padding 16h/10v per riga, sfondo `secondarySystemGroupedBackground` con corner radius 10 — stile grouped iOS nativo
  - Notes: `.footnote`, `.secondary`, allineate a sinistra
  - OK: `.borderedProminent` + `.controlSize(.large)` + `frame(maxWidth: .infinity)` — CTA piena larghezza come nella vecchia UI
  - Padding: 20 orizzontale, 16 bottom
- **Sheet non dismissabile a swipe**: `.interactiveDismissDisabled()` — l'utente deve premere OK per chiudere (coerente col cleanup state-driven di `clearPresentedFullImportResult`).

### Cosa NON e' stato toccato
- Nessuna modifica a logica, payload, state flow, anti-race, cancel/apply/retry
- Nessuna modifica a prepare/analyze overlay
- Nessuna modifica a ImportAnalysisView
- Nessuna modifica a stringhe localizzate
- Nessuna modifica a TASK-023

### Verifiche
- ✅ **BUILD** — due build successive, entrambe **BUILD SUCCEEDED**
- ✅ **STATIC** — scope solo presentazione result; overlay rimosso, sheet aggiunta; nessun cambio logica
- ⚠️ **SIM / manuali** — restano per l'utente

### Limiti residui
- Con `.presentationDetents([.medium])` la sheet occupa meta' schermo. Se le metriche fossero moltissime o le note molto lunghe, potrebbe non bastare. Se serve, si puo' aggiungere `.large` ai detents.

### Handoff → Review (Claude)
- **Prossima fase**: REVIEW
- **Prossimo agente**: CLAUDE
- **Azione consigliata**: Verificare in Simulator che la sheet finale sia visivamente vicina a `2-4.png`. TM-3, TM-14, TM-16, TM-18.

## Review (Claude)
*(Da compilare in fase REVIEW.)*

## Decisioni
| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|-------|
| 1 | Cancel **prioritario** su prepare; apply **senza** rollback atomico | Cancel libero durante apply con promessa rollback | Onesta' su SwiftData save a batch; perimetro minimo |
| 2 | Task handle salvato in `DatabaseView` + propagazione cancellation nella pipeline | Solo flag booleano senza Task | Cooperative cancellation idiomatica in Swift |
| 3 | Progresso apply: **overlay Database** come superficie primaria; sheet analisi senza spinner ridondante | Due spinner paritari; solo sheet | Chiarezza UX; allinea CA e TM |
| 4 | Anti-race su fine prepare: **run ID / token** (o identity check equivalente) prima di aprire sheet | Solo cancel del Task senza guardia | Evita sheet/sessione da job obsoleto |
| 5 | Cancellabilita' guidata da **stato tipizzato** / policy esplicita (**fase + job kind**) | Inferenza da `stageText` o solo da stage | Evita cancel su CSV/Excel semplice che condividono `importProgress` |
| 6 | **`CancellationError`** → **result surface** annullamento dedicata (non flusso errore `importError` indifferenziato) | Un solo catch che mappa tutto a `importError` | Distinguere annullato vs errore (CA-8) |
| 7 | **`awaitingConfirmation`**: baseline `isRunning` + overlay off **preservata** salvo tweak minimi necessari | Rifattorizzare semantica "idle" vs conferma | Riduce rischio regressioni dismiss/reset |
| 8 | Esito import: **result surface** strutturata se metriche multiple; tre esiti con gerarchia visiva distinta | Solo `alert` nativo con body lungo (scartato) | Leggibilita'; resta dentro perimetro UX TASK-024 |
| 9 | Esito: **payload / campi strutturati** + ordine **progresso off → sheet chiusa → result** | Stringa unica + result sopra sheet ancora aperta | CA-result-3; evita glitch e parsing fragile |
| 10 | **Unica** result surface per esito: sostituire/assorbire `resultMessage` + `alert` legacy, **no** parallelo | Due binari UI (legacy + nuova surface) | CA-result-4; chiarezza e manutenzione |
| 11 | Result surface strutturata **solo** per **full-database**; non-full (`importError`, ecc.) fuori redesign | Unificare tutta la messaggistica Database | CA-scope; perimetro TASK-024 |

---

## User override — switch task (2026-03-24)
- TASK-024 attivato come task attivo su decisione utente mentre TASK-023 e' messo in pausa (BLOCKED) senza DONE.

## Note revisione piano (integrazioni review)
- 2026-03-24 (e successive): integrati nel planning punti su anti-race (token/run ID), lifecycle completo del task handle, policy tipizzata per cancel, ramo dedicato `CancellationError`, raccomandazione UX superficie unica in apply, TM-12 confine cancel/fine prepare, limite noto copia file temp sincrona — senza allargare perimetro ne' TASK-023.
- Micro-integrazioni: **job kind + fase** per gating cancel (no affordance su import non-full); baseline **`awaitingConfirmation`** esplicitata; **TM-13** stress cancel + secondo full import immediato (e retry opzionale).
- **Presentazione esito finale** (**full-database**): **result surface** unica; **CA-result-1…5**, **CA-scope**; non-full invariato salvo no regression; **TM-11**, **TM-14…18**; **Decisione 8–11**.
- 2026-03-23 (review piano): integrati nell'analisi `progressFraction`, `resultTitle`, `clearResult()` (proprietà/metodi esistenti non precedentemente documentati); esplicitato il **doppio alert legacy** (`importError` per prepare + `resultMessage` per apply) come due canali separati da unificare nella result surface per il percorso full-database; aggiunti **batch sizes** (`importProgressBatchSize=25`, `importSaveBatchSize=250`) come punti naturali per `Task.checkCancellation()`; chiarito **meccanismo dismiss sheet** (`importAnalysisSession = nil`) nella sequenza Design §7; aggiornato handoff con indicazioni operative corrispondenti.
