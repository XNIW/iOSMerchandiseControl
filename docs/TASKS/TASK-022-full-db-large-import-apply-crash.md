# TASK-022: Full-database large import: apply crash after analysis (EXC_BAD_ACCESS)

## Informazioni generali
- **Task ID**: TASK-022
- **Titolo**: Full-database large import: apply crash after analysis (EXC_BAD_ACCESS)
- **File task**: `docs/TASKS/TASK-022-full-db-large-import-apply-crash.md`
- **Stato**: ACTIVE
- **Fase attuale**: EXECUTION
- **Responsabile attuale**: CODEX
- **Data creazione**: 2026-03-23
- **Ultimo aggiornamento**: 2026-03-23
- **Ultimo agente che ha operato**: CODEX

## Dipendenze
- **Dipende da**: nessuno (task autonomo, estratto da TASK-011 dopo test reali di TASK-006)
- **Sblocca**: TASK-006 (blocco pratico attuale); eventuale ripresa del perimetro piu' ampio di TASK-011

## Scopo
Isolare e risolvere il crash specifico osservato nel full-database import con dataset grande dopo il completamento apparente dell'analysis, nella transizione verso l'apply e nella costruzione del payload, garantendo un esito deterministico e leggibile dall'utente: completamento corretto oppure errore gestito, mai crash.

## Contesto
Durante i test manuali di TASK-006 con un file Excel reale molto grande, l'analysis completa sembra arrivare al termine ma il flusso non conclude l'apply in modo affidabile. Per decisione utente del 2026-03-23, TASK-011 viene sospeso e questo blocker concreto, riproducibile e piu' specifico viene estratto in un task dedicato.

User override esplicito per questo task:
- il planning operativo viene redatto da Codex, non da Claude
- il tracking va mantenuto coerente con questo override
- questo turno esegue tracking minimale + execution per accelerare il fix richiesto

## Evidenza principale
- Dataset grande reale usato in import full-database da file Excel.
- L'analysis completa sembra terminare correttamente.
- I log riportano circa `16.788` righe `Products` analizzate e circa `34.726` righe `PriceHistory` parse.
- In UI puo' restare visibile a lungo `Importazione in corso...` oppure il flusso puo' apparire fermo nel passaggio conferma -> apply.
- In debugger il crash osservato e' `EXC_BAD_ACCESS` dentro `DatabaseView.makeImportApplyPayload(...)`.
- Il punto evidenziato e' la costruzione del payload di apply, in particolare le tre conversioni `.map(...)`: `analysis.newProducts.map(ImportProductDraftSnapshot.init)` (~16.680 elementi), `analysis.updatedProducts.map(ImportProductUpdateSnapshot.init)` (~108 elementi) e `pendingPriceHistoryEntries.map { ImportPendingPriceHistoryEntrySnapshot(...) }` (~34.726 elementi) — tutte eseguite sul MainActor in modo sincrono.
- Nuova evidenza runtime (stesso dataset grande reale, retry successivo al primo fix parziale): il crash non cade piu' sulle `.map(...)`, ma in `ProductImportAnalysisResult.hasChanges`, con stack `ProductImportAnalysisResult.hasChanges` -> `DatabaseView.makeImportApplyPayload(...)` -> `DatabaseView.applyConfirmedImportAnalysis(...)`.
- Nel nuovo crash il passaggio e' ancora conferma -> apply, con overlay `Importazione in corso...` visibile.

## Non incluso
- Risolvere l'intero umbrella di TASK-011 su large import stability, memory e progress UX oltre quanto necessario per questo crash specifico.
- Refactor ampio dell'architettura di import o della pipeline Excel non strettamente richiesto dal fix.
- Modifica del formato XLSX multi-sheet, dell'export database o del supporto ad altri formati.
- Modifiche al parser Excel o ad altri flussi se non direttamente necessari a rimuovere il crash specifico post-analysis.
- Lavoro su scenari non large-import, salvo i controlli minimi di non regressione sui file piccoli.
- Chiusura finale di TASK-006 o riapertura operativa di TASK-011.

## File potenzialmente coinvolti
- `iOSMerchandiseControl/DatabaseView.swift` — file primario quasi certo; contiene `applyConfirmedImportAnalysis`, `makeImportApplyPayload`, `ImportApplyPayload`, `PendingFullImportContext`, `DatabaseImportProgressState` e il background apply.
- `iOSMerchandiseControl/ImportAnalysisView.swift` — letto come fonte di verita' per `ProductImportAnalysisResult`; al momento non emerge una modifica necessaria dal crash point.
- `iOSMerchandiseControl/ExcelSessionViewModel.swift` — letto per capire `ExcelAnalyzer`, ma il parser non coincide con il punto del crash attuale.

## Decisioni
| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|-------|
| 1 | Separare il crash specifico di apply in un task dedicato | Continuare a trattarlo dentro TASK-011 | Il problema e' concreto, riproducibile e blocker immediato; un task separato riduce ambiguita' di perimetro e sblocca il tracking di TASK-006 | attiva |
| 2 | Per TASK-022 il planning operativo viene fatto da Codex su override utente | Mantenere il planning in carico a Claude | Override esplicito dell'utente; tracking e handoff devono rifletterlo senza cambiare la pipeline generale del progetto | attiva |

---

## Planning (Codex, user override)

### As-Is / stato attuale del codice

#### Flusso reale iOS oggi
- L'ingresso del full import passa da `DatabaseView.importFullDatabaseFromExcel(url:)`.
- `importFullDatabaseFromExcel(url:)` fa `guard !importProgress.isRunning`, azzera `importError`, `importAnalysisResult` e `pendingFullImportContext`, poi chiama `importProgress.startPreparation()`.
- Lo stesso metodo copia il file con `copySecurityScopedImportFileToTemporaryLocation(from:)` e lancia un `Task` che chiama `DatabaseImportPipeline.prepareFullDatabaseImport(from:modelContainer:onProgress:)`.
- `DatabaseImportPipeline.prepareFullDatabaseImport(...)` gira in `Task.detached`, importa eventuali `Suppliers` e `Categories`, legge il foglio `Products`, esegue `ExcelAnalyzer.analyzeSheetRows(_:)`, carica gli esistenti con `fetchExistingProductSnapshots(in:)`, esegue `analyzeImport(header:dataRows:existingProducts:)` e, se presente, costruisce `PendingFullImportContext` tramite `parsePendingPriceHistoryContext(at:sheetNameMap:)`.
- Quando la preparation termina, `importFullDatabaseFromExcel(url:)` torna sul `MainActor`, salva `pendingFullImportContext = prepared.pendingFullImportContext`, converte `prepared.analysis` in `ProductImportAnalysisResult` con `DatabaseImportUILocalizer.analysisResult(from:)`, assegna `importAnalysisResult`, poi chiama `progressState.awaitingConfirmation()`.
- La conferma utente avviene nella `.sheet(item: $importAnalysisResult, onDismiss: handleImportAnalysisDismissed)` che presenta `ImportAnalysisView`.
- `ImportAnalysisView` mantiene una copia locale in `@State private var analysis: ProductImportAnalysisResult` e, sul bottone Apply, chiama `onApply(analysis)`.
- In `DatabaseView`, `onApply` richiama `applyConfirmedImportAnalysis(_:)`.
- `applyConfirmedImportAnalysis(_:)` legge `pendingFullImportContext`, decide `recordAutomaticPriceHistory`, costruisce il payload con `Self.makeImportApplyPayload(...)`, poi chiama `importProgress.startPreparation()` e solo dopo avvia `DatabaseImportPipeline.applyImportAnalysisInBackground(...)`.
- `DatabaseImportPipeline.applyImportAnalysisInBackground(...)` crea un nuovo `ModelContext(modelContainer)`, applica prodotti con `applyImportAnalysis(_:in:onProgress:)`, poi eventuale `PriceHistory` con `applyPendingPriceHistoryImport(_:in:onProgress:)`, e ritorna un `ImportApplyResult`.
- Sul successo, `applyConfirmedImportAnalysis(_:)` azzera `pendingFullImportContext` e chiama `progressState.finishSuccess(message:)`. Sul throw del background apply fa `progressState.resetRunningState()` e rilancia un errore user-facing.

#### Overlay e progress oggi
- `DatabaseImportProgressState.startPreparation()` mette `isRunning = true` e `showsOverlay = true`.
- Durante preparation e apply, i callback `onProgress` aggiornano `DatabaseImportProgressState.apply(_:)`.
- Dopo analysis pronta, `awaitingConfirmation()` lascia `isRunning = true` ma mette `showsOverlay = false`: la view resta disabilitata mentre la sheet di conferma e' aperta.
- `handleImportAnalysisDismissed()` resetta lo stato running se la sheet viene chiusa.
- Punto critico attuale: in `applyConfirmedImportAnalysis(_:)` il nuovo `startPreparation()` avviene solo dopo `makeImportApplyPayload(...)`; quindi un crash o un failure in quella costruzione avviene prima dell'avvio dell'apply background e fuori da un percorso finale di stato chiaramente modellato.

#### Dove vivono i dati
- `ProductImportAnalysisResult` vive in `iOSMerchandiseControl/ImportAnalysisView.swift`; contiene `newProducts`, `updatedProducts`, `errors`, `warnings`.
- In `DatabaseView.swift`, la UI conserva il risultato in `@State private var importAnalysisResult: ProductImportAnalysisResult?`.
- In `ImportAnalysisView`, lo stesso risultato viene copiato in `@State private var analysis: ProductImportAnalysisResult`.
- `newProducts` vive come `[ProductDraft]` dentro `ProductImportAnalysisResult`.
- `updatedProducts` vive come `[ProductUpdateDraft]` dentro `ProductImportAnalysisResult`; ogni elemento porta `old`, `new` e `changedFields`.
- `pendingPriceHistoryEntries` non vive in `ProductImportAnalysisResult`: vive in `PendingFullImportContext.priceHistoryEntries` in `DatabaseView.swift`, creato da `parsePendingPriceHistoryContext(...)` durante la preparation.
- `ImportApplyPayload` vive in `DatabaseView.swift` come struct `Sendable` privata; oggi viene costruita in `makeImportApplyPayload(...)` e contiene nuove copie snapshot di `newProducts`, `updatedProducts`, `pendingPriceHistoryEntries` e il flag `recordPriceHistory`.

### Ipotesi root cause

#### 1. Probabilita' alta — eager materialization troppo grande del payload
- Evidenza a favore: il crash osservato cade esattamente sulle tre `.map(...)` di `makeImportApplyPayload(...)`, cioe' nel momento in cui vengono materializzati tre nuovi array completi di snapshot per dataset molto grandi: ~16.680 `ImportProductDraftSnapshot`, ~108 `ImportProductUpdateSnapshot` e ~34.726 `ImportPendingPriceHistoryEntrySnapshot` — tutti sul MainActor in modo sincrono.
- Evidenza aggiuntiva confermata in review: tutti e tre i tipi sorgente (`ProductDraft`, `ProductUpdateDraft`, `PendingPriceHistoryImportEntry`) sono gia' `Sendable` con campi identici ai rispettivi snapshot. L'intero layer snapshot e' quindi ridondante e la sua eliminazione rimuove tutte e tre le `.map(...)`, trasformando `makeImportApplyPayload(...)` in un semplice assegnamento diretto senza allocazioni aggiuntive.
- Evidenza mancante: non c'e' ancora una misura oggettiva before/after del peak memory nel preciso passaggio `applyConfirmedImportAnalysis -> makeImportApplyPayload`.
- Come verificarla: aggiungere logging temporaneo dei count e marker temporali immediatamente prima/dopo ogni map, riprodurre con il dataset grande reale e confrontare con memory graph/Allocations durante il passaggio.

#### 2. Probabilita' medio-alta — duplicazione ridondante di array grandi tra analysis, payload e apply
- Evidenza a favore: lo stesso dataset prodotti esiste gia' come `DatabaseImportAnalysisPayload`, poi come `ProductImportAnalysisResult`, poi come `ImportAnalysisView.analysis`, poi viene ricopiato in `ImportApplyPayload`; `updatedProducts` duplica anche `old` e `new`.
- Evidenza mancante: non e' ancora isolato quale duplicazione sia quella che porta il processo oltre la soglia reale di memoria o verso corruzione/accesso invalido.
- Come verificarla: in execution confrontare un fix che elimina tutti e tre i layer snapshot (`ImportProductDraftSnapshot`, `ImportProductUpdateSnapshot`, `ImportPendingPriceHistoryEntrySnapshot`) con il comportamento attuale, usando lo stesso dataset grande e gli stessi log.

#### 3. Probabilita' media — confine di lifetime / CoW non sicuro tra analysis UI state e apply background
- Evidenza a favore: il passaggio usa dati che vivono nello stato UI (`importAnalysisResult` in `DatabaseView`, `analysis` in `ImportAnalysisView`) e li converte proprio nel punto di passaggio verso il pipeline background.
- Evidenza mancante: il crash avviene prima del `Task.detached` dell'apply, quindi non c'e' ancora prova diretta di una race o di un use-after-free; i tipi coinvolti sono value type `Sendable`.
- Come verificarla: fare in execution un percorso in cui il background apply consuma un input immutabile gia' definitivo e non rilegge piu' direttamente lo stato UI dell'analysis; se il crash sparisce senza altre modifiche di perimetro, l'ipotesi guadagna peso.

#### 4. Probabilita' media — stato UI/overlay ambiguo se la build del payload fallisce o non completa
- Evidenza a favore: `awaitingConfirmation()` lascia `isRunning = true` con overlay nascosto, mentre `applyConfirmedImportAnalysis(_:)` richiama `startPreparation()` solo dopo la build del payload; non esiste un branch esplicito dedicato al fallimento pre-apply di `makeImportApplyPayload(...)`.
- Evidenza mancante: il caso oggi termina con crash, quindi non c'e' ancora una prova di UI realmente bloccata in un errore gestito pre-apply.
- Come verificarla: introdurre temporaneamente un errore controllato nella build del payload o subito prima dell'avvio del background apply e verificare che `importProgress` torni idle con messaggio d'errore esplicito.

### Strategia proposta

#### Direzione primaria raccomandata
Eliminare **tutti e tre** i layer snapshot ridondanti (`ImportProductDraftSnapshot`, `ImportProductUpdateSnapshot`, `ImportPendingPriceHistoryEntrySnapshot`) nel passaggio `applyConfirmedImportAnalysis(_:) -> makeImportApplyPayload(...)`, facendo in modo che `ImportApplyPayload` contenga direttamente i tipi sorgente gia' `Sendable` e che il background apply li consumi senza remapping intermedio.

Motivazione ancorata al codice attuale:
- `ProductDraft` (ImportAnalysisView.swift:7), `ProductUpdateDraft` (ImportAnalysisView.swift:22) e `PendingPriceHistoryImportEntry` (DatabaseView.swift:145) sono gia' value type `Sendable` con campi identici ai rispettivi snapshot.
- Il crash noto cade sulle `.map(...)` che creano gli snapshot, non nel parser e non nel corpo del background apply.
- Eliminando tutti e tre i layer, `makeImportApplyPayload(...)` diventa un semplice assegnamento diretto (nessuna `.map()`, nessuna allocazione aggiuntiva) e la pressione memoria sul MainActor si annulla per questo passaggio.
- Il fix minimo e mirato e' quindi rimuovere tutti e tre gli snapshot e adattare le firme downstream, non riaprire l'ombrello di TASK-011.

Nota su `@MainActor` e blocco UI:
- Oggi `makeImportApplyPayload(...)` e' `@MainActor` e esegue tre `.map(...)` su ~51k elementi in modo sincrono, bloccando la UI.
- Dopo l'eliminazione degli snapshot, la funzione diventa un banale struct init con assegnamento diretto (CoW, ~O(1)). Il vincolo `@MainActor` puo' essere mantenuto per semplicita' senza impatto pratico, oppure rimosso se si preferisce — in entrambi i casi il blocco UI scompare.

Direzione concreta da implementare in execution:
- fare in modo che `ImportApplyPayload` contenga direttamente `[ProductDraft]`, `[ProductUpdateDraft]` e `[PendingPriceHistoryImportEntry]`
- eliminare `makeImportApplyPayload(...)` o ridurlo a un semplice wrapper senza `.map()`
- adattare `applyImportAnalysis(...)` per usare `update.new` (ProductDraft) invece di `update.newDraft` (ImportProductDraftSnapshot) — mapping 1:1 dei campi verificato
- adattare `applyPendingPriceHistoryImport(...)` per accettare `[PendingPriceHistoryImportEntry]` direttamente
- evitare che il background apply dipenda ancora dal live state della sheet/UI dopo la conferma
- aggiungere un percorso esplicito di errore gestito se il pre-apply non riesce a costruire l'input necessario

#### Forma tecnica raccomandata del fix
Direzione primaria scelta: **A. mantenere `ImportApplyPayload`, ma farlo contenere direttamente `ProductDraft`, `ProductUpdateDraft` e `PendingPriceHistoryImportEntry`, eliminando tutti e tre gli snapshot intermedi (`ImportProductDraftSnapshot`, `ImportProductUpdateSnapshot`, `ImportPendingPriceHistoryEntrySnapshot`).**

Motivo della scelta:
- e' la variante minima piu' coerente con il codice attuale
- conserva la forma del pipeline di apply gia' esistente
- rimuove l'intero layer di duplicazione che coincide con il punto del crash, senza aprire un refactor piu' ampio
- include il terzo snapshot (`ImportPendingPriceHistoryEntrySnapshot`) nel fix primario perche' `PendingPriceHistoryImportEntry` e' gia' `Sendable` con campi identici e il dataset reale ha ~34.726 entries — trattarlo come fallback introdurrebbe un rischio inutile

Simboli/firme da toccare:
- `ImportApplyPayload` — cambiare i tipi dei campi: `[ProductDraft]`, `[ProductUpdateDraft]`, `[PendingPriceHistoryImportEntry]`
- `makeImportApplyPayload(...)` — eliminare le tre `.map(...)`, sostituire con assegnamento diretto
- `applyConfirmedImportAnalysis(_:)` — nessun cambio strutturale, ma verificare che la cattura rimanga coerente
- `applyImportAnalysis(_:in:onProgress:)` — rinominare `update.newDraft` → `update.new` nel loop degli update (DatabaseView.swift:865); i campi sono 1:1
- `applyPendingPriceHistoryImport(_:in:onProgress:)` — cambiare firma da `[ImportPendingPriceHistoryEntrySnapshot]` a `[PendingPriceHistoryImportEntry]`; i campi usati nel body (`.barcode`, `.type`, `.price`, `.effectiveAt`, `.source`) sono identici
- rimozione di `ImportProductDraftSnapshot` (DatabaseView.swift:13-35)
- rimozione di `ImportProductUpdateSnapshot` (DatabaseView.swift:37-47)
- rimozione di `ImportPendingPriceHistoryEntrySnapshot` (DatabaseView.swift:49-55)

Simboli idealmente da non toccare:
- `ProductImportAnalysisResult`
- `ImportAnalysisView`
- `DatabaseImportPipeline.prepareFullDatabaseImport(...)`
- `parsePendingPriceHistoryContext(...)`
- `ExcelAnalyzer` e i parser multi-sheet

Nota operativa:
- `makeImportApplyPayload(...)` puo' restare come helper leggero (un semplice struct init), oppure essere inlined in `applyConfirmedImportAnalysis(_:)` dato che dopo il fix diventa un one-liner.

#### Alternative scartate
- Chunkare soltanto `makeImportApplyPayload(...)` sul `MainActor`: puo' abbassare il picco ma lascia comunque il layer ridondante di copia e non chiarisce il confine con lo stato UI.
- Eliminare solo gli snapshot prodotti e lasciare `ImportPendingPriceHistoryEntrySnapshot` come fallback: `PendingPriceHistoryImportEntry` e' gia' `Sendable` con campi identici e il dataset reale ha ~34.726 entries; trattarlo separatamente introduce un passaggio inutile e rischia di lasciare un picco di memoria residuo evitabile.
- Spostare `makeImportApplyPayload(...)` off-MainActor senza eliminare gli snapshot: dopo l'eliminazione degli snapshot la funzione diventa banale (~O(1)), rendendo lo spostamento non necessario come fix aggiuntivo.
- Costruire un secondo snapshot completo gia' durante `prepareFullDatabaseImport(...)`: anticipa la duplicazione e la mantiene viva per tutta la fase di conferma utente, con rischio di footprint peggiore.
- Aprire modifiche su `ExcelAnalyzer` o sul parser multi-sheet: non c'e' evidenza che il crash attuale nasca in parsing; il punto osservato e' dopo analysis completata.
- Intervenire su `ImportAnalysisView.swift` come prima scelta: oggi la view ha gia' preview limit a 500/200 e un alert `applyError`; non emerge da qui la root cause del crash.

### Invarianti di stato / UI
- Dopo il tap su `Applica` deve sempre esistere un esito finale chiaro: successo oppure errore gestito.
- Se il pre-apply fallisce, `importProgress` deve uscire dallo stato running e la UI deve tornare interagibile.
- Nessun path deve lasciare `showsOverlay = false` con UI ancora bloccata e senza sheet attiva.
- Il dismiss/cancel della sheet di analisi deve continuare a ripulire `pendingFullImportContext`, `importAnalysisResult` e lo stato running senza lasciare stato sporco.

### Ownership / lifecycle dello stato nel passaggio di apply
- Al tap su `Applica`, il source of truth deve diventare una cattura immutabile locale dell'`analysis` confermata, insieme al `pendingFullImportContext` corrente. Il background apply deve lavorare solo su quell'input congelato e non deve dipendere dal live state della sheet/UI.
- `importAnalysisResult` puo' restare valorizzato durante il solo pre-apply, finche' serve a tenere coerente la sheet di conferma. Dopo che l'input immutabile dell'apply e' stato costruito con successo e l'avvio del background apply e' stato confermato, `importAnalysisResult` puo' essere pulito senza rischio di perdita dati, perche' non e' piu' il source of truth.
- `pendingFullImportContext` va gestito con questa policy unica:
  successo: ripulire;
  errore pre-apply: mantenere, per consentire retry immediato sulla stessa conferma dato che il background apply non e' ancora partito;
  errore durante background apply: ripulire, per evitare retry ciechi su stato potenzialmente gia' parzialmente applicato.
- UX raccomandata in caso di errore pre-apply: la sheet di conferma resta disponibile, viene mostrato un errore gestito, l'utente puo' riprovare subito con `Applica`, e overlay/progress non devono restare attivi o ambigui.
- Ordine raccomandato del lifecycle UI/progress nel pre-apply: **B. mantenere separato un mini-stato di pre-apply con chiusura errore esplicita**. Sequenza target: tap su `Applica` -> cattura input immutabile -> solo se la cattura riesce transizione a `importProgress.startPreparation()` o stato equivalente di apply -> avvio del background apply. Se la cattura fallisce, il background apply non parte, l'errore viene gestito esplicitamente e lo stato deve tornare in modo coerente alla conferma/retry senza overlay ambiguo.
- Obiettivo pratico: nessun path deve lasciare dati UI vivi "per caso", nessun path deve leggere stato mutabile della sheet dopo la conferma utente, e l'esito finale deve essere coerente con overlay/progress e con l'eventuale disponibilita' di retry.

### Sequenza raccomandata di execution
1. Rimuovere le tre struct snapshot: `ImportProductDraftSnapshot` (righe 13-35), `ImportProductUpdateSnapshot` (righe 37-47), `ImportPendingPriceHistoryEntrySnapshot` (righe 49-55).
2. Ridefinire `ImportApplyPayload` per contenere direttamente `[ProductDraft]`, `[ProductUpdateDraft]`, `[PendingPriceHistoryImportEntry]`.
3. Aggiornare `makeImportApplyPayload(...)`: eliminare le tre `.map(...)`, usare assegnamento diretto.
4. Aggiornare `applyImportAnalysis(_:in:onProgress:)`: nel loop degli update, rinominare `update.newDraft` → `update.new` (riga ~865). Verificare che tutti gli accessi ai campi siano 1:1.
5. Aggiornare `applyPendingPriceHistoryImport(_:in:onProgress:)`: cambiare firma da `[ImportPendingPriceHistoryEntrySnapshot]` a `[PendingPriceHistoryImportEntry]`. Il body non richiede modifiche (stessi campi).
6. Chiudere esplicitamente il ramo di errore pre-apply in `applyConfirmedImportAnalysis(_:)`, con reset coerente di `importProgress`.
7. Aggiungere logging temporaneo minimo attorno a `makeImportApplyPayload(...)` e al ramo di errore pre-apply.
8. Validare con dataset grande reale e smoke test con file piccolo.
9. Ridurre o rimuovere i log temporanei prima della chiusura del task.

### Fallback diagnostico
Con l'eliminazione di tutti e tre i layer snapshot nel fix primario, il passaggio `makeImportApplyPayload(...)` non produce piu' allocazioni aggiuntive significative. Se il crash o un problema di memoria persiste dopo il fix, i punti da verificare sono:
- la pressione memoria accumulata nelle fasi precedenti (parsing + analysis) che rimane viva al momento dell'apply — l'`analysis` e il `pendingFullImportContext` restano in memoria durante tutto il flusso
- `ProductUpdateDraft` porta sia `old` che `new` per ogni update (~108 nel dataset reale, trascurabile)
- il body di `applyImportAnalysis(...)` che fa `context.fetch(FetchDescriptor<Product>())` per tutti i prodotti esistenti nel database, aggiungendo pressione al punto di apply

Questo resta un fallback diagnostico e non amplia lo scope del fix iniziale.

### Non-regression boundaries
- Non deve cambiare il comportamento dell'import full-database piccolo.
- Non deve cambiare il flow singolo-sheet `importProductsFromExcel(url:)`, salvo eventuale minima condivisione tecnica inevitabile nello stesso helper di apply.
- Non deve cambiare il comportamento ordinario multi-sheet introdotto da TASK-006: sheet names, ordine logico, opzionalita' di `Suppliers`, `Categories`, `PriceHistory`, export e parser restano fuori scope.
- Non deve essere aperto un refactor generale del pipeline di import.
- Il progress UX minimo gia' esistente va preservato: overlay visibile durante preparation/apply, stato di conferma distinto, nessun redesign ulteriore salvo il minimo necessario per evitare stati ambigui.

### File da modificare
- File primario quasi certo: `iOSMerchandiseControl/DatabaseView.swift`
  Motivo: contiene il punto crash (`makeImportApplyPayload(...)`), il passaggio di stato `applyConfirmedImportAnalysis(_:)`, `ImportApplyPayload`, `PendingFullImportContext` e il reset del progress state.
- File secondario solo se necessario: `iOSMerchandiseControl/ImportAnalysisView.swift`
  Stato attuale: non appare necessario. La view ha gia' preview cap a `500` item (`200` per errori) e gia' mostra `applyError`. Toccarla solo se in execution emerge un vincolo reale sul passaggio `onApply`.
- File secondario solo se necessario: `iOSMerchandiseControl/ExcelSessionViewModel.swift`
  Stato attuale: non previsto. Il parser e `ExcelAnalyzer` non sono il punto osservato del crash.

### Rischi
- Un fix apparente puo' spostare il crash piu' avanti nel pipeline senza eliminarne la causa reale.
- Un fix che rimuove l'`EXC_BAD_ACCESS` ma crea un input ancora piu' grande puo' peggiorare il peak memory totale.
- Un fix troppo aggressivo sul passaggio di apply puo' rompere i file piccoli o il normale apply multi-sheet.
- Un fix incompleto puo' lasciare `importProgress` o la sheet in uno stato finale ambiguo se il pre-apply fallisce.

### Piano di verifica
- Riprodurre il caso principale con lo stesso dataset grande reale gia' usato, seguendo il path completo `import full database -> analysis -> conferma -> apply`.
- Eseguire uno smoke test con file piccolo full-database per confermare che il flusso ordinario non regredisca.
- Aggiungere logging temporaneo attorno a `applyConfirmedImportAnalysis(_:)` e `makeImportApplyPayload(...)` per count, inizio/fine step e ramo di errore; rimuoverlo o ridurlo dopo la validazione.
- Checkpoint intermedio esplicito con dataset grande reale: distinguere tra superamento del vecchio crash point e completamento finale dell'import.
- Al checkpoint intermedio deve risultare verificabile che `makeImportApplyPayload(...)` completa senza crash e che il background apply parte davvero; solo dopo questo superamento si valuta l'esito finale completo dell'import.
- Se dopo il fix emergesse un problema successivo ma il background apply fosse partito, il risultato diagnostico va classificato come "vecchio crash point superato, issue successiva da valutare", non come mancato fix del crash originario.
- Verificare esplicitamente lo stato overlay/progress in quattro momenti: preparation, analysis pronta/attesa conferma, apply in corso, esito finale.
- Forzare temporaneamente un errore gestito nel pre-apply oppure subito prima del background apply per verificare che l'app mostri errore invece di crash e che `importProgress` non resti bloccato.
- Eseguire build dopo il fix per confermare che la modifica resti confinata e non introduca warning nuovi.

### Criteri di accettazione
- [ ] **CA-1**: Nessun crash `EXC_BAD_ACCESS` nel passaggio analysis completata -> conferma utente -> apply del full-database import con dataset grande reale.
- [ ] **CA-2**: `makeImportApplyPayload(...)` non materializza piu' sul `MainActor` copie eager full-size di `analysis.newProducts`, `analysis.updatedProducts` e `pendingPriceHistoryEntries` (tutti e tre i layer snapshot eliminati); il passaggio usa assegnamento diretto dei tipi sorgente gia' `Sendable`, verificabile sul dataset grande reale.
- [ ] **CA-3**: L'utente distingue chiaramente se il flusso e' in preparation, in attesa di conferma, in apply, completato o fallito; overlay/progress non restano in stato ambiguo.
- [ ] **CA-4**: Se la costruzione del payload o l'apply non possono completare, lo stato import viene chiuso con errore gestito, `importProgress` esce dallo stato running e la UI non resta bloccata.
- [ ] **CA-5**: L'import full-database grande completa correttamente oppure fallisce con errore gestito e messaggio esplicito; non termina mai con crash.
- [ ] **CA-6**: Nessuna regressione sui file piccoli e sul comportamento ordinario di TASK-006; il flow singolo-sheet resta invariato salvo l'eventuale minimo cambiamento tecnico condiviso.
- [ ] **CA-7**: Build compila senza errori e senza warning nuovi.

## Handoff -> Execution
- **Fase corrente**: EXECUTION
- **Prossima fase prevista**: EXECUTION
- **Prossimo agente**: CODEX
- **Azione consigliata**: iniziare da `iOSMerchandiseControl/DatabaseView.swift`, eliminare tutti e tre gli snapshot (`ImportProductDraftSnapshot`, `ImportProductUpdateSnapshot`, `ImportPendingPriceHistoryEntrySnapshot`), ridefinire `ImportApplyPayload` con i tipi sorgente diretti (`ProductDraft`, `ProductUpdateDraft`, `PendingPriceHistoryImportEntry`), aggiornare `applyImportAnalysis` (`update.newDraft` → `update.new`) e `applyPendingPriceHistoryImport` (firma), e chiudere sempre lo stato di import con esito esplicito se il pre-apply fallisce.
- **Sequenza vincolante consigliata**: seguire i 9 passi della sequenza raccomandata di execution. I passi 1-5 sono il fix primario completo; il passo 6 e' la chiusura del ramo errore; i passi 7-9 sono validazione e cleanup.
- **Vincoli di execution**: non riaprire TASK-011, non allargare scope a export o parser, non toccare `ImportAnalysisView.swift` salvo necessita' emersa dal compilatore o da un vincolo reale del fix.
- **Nota su logging temporaneo**: eventuali log diagnostici aggiunti per validare il fix vanno rimossi o ridotti prima della chiusura del task.

## Nota tracking
- Il task resta `ACTIVE` e passa a `EXECUTION` per user override esplicito, con tracking minimale iniziale prima dell'implementazione.
- Claude ha integrato tre miglioramenti nel plan di Codex dopo review del codice sorgente:
  1. Inclusione di `ImportPendingPriceHistoryEntrySnapshot` nel fix primario (non fallback) — confermato che `PendingPriceHistoryImportEntry` e' gia' `Sendable` con campi identici
  2. Dettaglio delle modifiche downstream necessarie: `update.newDraft` → `update.new` in `applyImportAnalysis`, firma di `applyPendingPriceHistoryImport`
  3. Chiarimento che dopo l'eliminazione di tutti e tre gli snapshot, `makeImportApplyPayload(...)` diventa assegnamento diretto (~O(1)) e il blocco MainActor si risolve da se'
- Il file viene riallineato in questo turno per consentire execution immediata senza cambiare backlog o priorita'.
- Nuovo user/runtime update nello stesso task: il fix precedente ha rimosso il crash point delle `.map(...)`, ma il task non e' chiuso; la fase torna a `EXECUTION` per correggere il confine di ownership tra `DatabaseView` e `ImportAnalysisView` senza aprire nuovi task.
- Esito reale di questo turno: fix di ownership applicato nel workspace, ma task non review-ready; build bloccato da `GeneratedView.swift` e rerun simulator disponibile solo sul binary gia' installato, che continua a crashare con stack vecchio su `hasChanges`.

## Execution (Codex)

### Nuova evidenza runtime dopo il primo fix
- Il primo fix e' risultato parziale: il dataset grande reale non crasha piu' nel vecchio layer snapshot eager, ma crasha ancora in `ProductImportAnalysisResult.hasChanges`.
- Il sospetto operativo aggiornato e' la duplicazione/lifetime dello stato `ProductImportAnalysisResult` tra parent (`DatabaseView`) e child (`ImportAnalysisView`) e il passaggio del mega valore attraverso `onApply(analysis)`.
- Questo turno di execution e' focalizzato solo su quel confine di ownership.

### Modifiche applicate
- `iOSMerchandiseControl/ImportAnalysisView.swift`: introdotto `ImportAnalysisSession` (`ObservableObject`) come owner unico e mutabile del risultato editabile dentro la sheet; rimossa la seconda copia gigante in `@State private var analysis`.
- `ImportAnalysisView` non passa piu' `ProductImportAnalysisResult` attraverso `onApply(analysis)`: il callback e' ora `onApply: () async throws -> Void` e il bottone `Applica` lavora sullo stato del parent.
- L'editing dei draft resta attivo nella sheet, ma ora modifica `session.newProducts` e `session.updatedProducts` direttamente invece di ricopiare il mega valore.
- `iOSMerchandiseControl/DatabaseView.swift`: lo stato parent passa da `importAnalysisResult` a `importAnalysisSession`, presentata via `.sheet(item:)`.
- `applyConfirmedImportAnalysis()` non riceve piu' un mega valore dal child: legge solo lo stato confermato posseduto dal parent (`importAnalysisSession`) e il `pendingFullImportContext`.
- `makeImportApplyPayload(...)` usa `ImportAnalysisSession` e non chiama piu' `ProductImportAnalysisResult.hasChanges`; questo rimuove il crash point osservato nel call stack precedente sul boundary sheet -> apply.
- Resta valido anche il fix precedente su `ImportApplyPayload`: nessuna snapshot eager di prodotti o price-history nel passaggio conferma -> apply.
- Errore pre-apply: `importProgress.resetRunningState()`, sheet lasciata disponibile, retry possibile sullo stesso stato confermato.
- Errore durante background apply: `pendingFullImportContext` e `importAnalysisSession` vengono ripuliti, `importProgress.finishError(...)` chiude lo stato con esito esplicito.

### Check eseguiti
- [ ] Build compila: ❌ NON ESEGUITO con esito positivo — `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'generic/platform=iOS Simulator' build` eseguita, ma fallita su `iOSMerchandiseControl/GeneratedView.swift:139` con `the compiler is unable to type-check this expression in reasonable time`; `DatabaseView.swift` e `ImportAnalysisView.swift` compilano, ma non esiste un app aggiornato installabile per validare il fix.
- [ ] Nessun warning nuovo introdotto: ⚠️ NON ESEGUIBILE — il build non chiude e non ho una baseline warning affidabile nello stesso turno.
- [x] Modifiche coerenti con il planning: ✅ ESEGUITO — fix confinato a `DatabaseView.swift` + `ImportAnalysisView.swift`; nessuna modifica a parser/export/TASK-011/ExcelSessionViewModel.
- [ ] Criteri di accettazione verificati: ⚠️ NON ESEGUIBILE — CA statici del fix di ownership verificati via codice, ma la validazione runtime della patch e' bloccata dal build fallito.
- [x] Rerun dataset grande reale: ✅ ESEGUITO — nel Simulator ho aperto la sheet di analisi del dataset grande reale (`16.680` nuovi prodotti / `108` aggiornamenti) e ho eseguito il tap su `Applica`.
- [ ] Crash `hasChanges` superato sulla patch corrente: ⚠️ NON ESEGUIBILE — il rerun disponibile ha usato il binary gia' installato nel simulator, non la build aggiornata del workspace; il crash report mostra ancora lo stack vecchio con `ProductImportAnalysisResult.hasChanges` -> `DatabaseView.makeImportApplyPayload(analysis:pendingFullImportContext:)` -> `DatabaseView.applyConfirmedImportAnalysis(_)`.
- [ ] Background apply parte davvero sulla patch corrente: ⚠️ NON ESEGUIBILE — nel rerun reale l'app installata si chiude con `SIGSEGV` subito dopo il tap su `Applica`, senza consentire una validazione del nuovo percorso di apply.
- [ ] Smoke test minimo percorso non-large: ❌ NON ESEGUITO — non ho un binary aggiornato installabile e non ho eseguito un import piccolo nel simulator in questo turno.
- [ ] Errore pre-apply chiude progress/UI senza stato ambiguo: ⚠️ NON ESEGUIBILE — verificato staticamente nel codice, non con esercizio runtime della patch.

### Rischi residui
- Il task resta bloccato operativamente da un build failure fuori scope in `iOSMerchandiseControl/GeneratedView.swift:139`; senza build installabile non e' possibile validare la patch corrente nel simulator.
- Il rerun reale del dataset grande ha confermato che il binary attualmente installato crasha ancora al tap su `Applica`: crash report `2026-03-23 15:02:23`, `EXC_BAD_ACCESS / SIGSEGV`, `KERN_INVALID_ADDRESS 0x10`, thread principale, stack `ProductImportAnalysisResult.hasChanges` -> `DatabaseView.makeImportApplyPayload(analysis:pendingFullImportContext:)` -> `DatabaseView.applyConfirmedImportAnalysis(_)`.
- Lo stack del crash report appartiene al codice vecchio e non fornisce evidenza diretta sul nuovo fix di ownership nel workspace.
- Il ramo di errore pre-apply e quello di errore durante background apply sono stati allineati al planning, ma non sono ancora stati esercitati sulla build aggiornata.

## Handoff post-execution
- **Fase corrente**: EXECUTION
- **Prossima fase prevista**: EXECUTION
- **Prossimo agente**: CODEX
- **Sintesi handoff**: fix di ownership applicato nel workspace con `ImportAnalysisSession` per eliminare la doppia copia di `ProductImportAnalysisResult` e il passaggio di `analysis` gigante nel callback `onApply`, ma il task non e' review-ready.
- **Verifiche realmente concluse**: build eseguita con failure reale fuori scope in `GeneratedView.swift`; rerun simulator del dataset grande reale eseguito sul binary gia' installato; tap su `Applica` riprodotto; crash report raccolto.
- **Verifiche non concluse**: nessuna validazione runtime della patch corrente, perche' il crash report del rerun mostra ancora le vecchie firme `makeImportApplyPayload(analysis:pendingFullImportContext:)` e `applyConfirmedImportAnalysis(_)`, segno che l'app installata non contiene il fix corrente anche se il bottone `Applica` e' stato cliccato correttamente.
- **Blocco esplicito**: serve un build installabile del workspace per verificare se il crash `hasChanges` e' davvero sparito e se il nuovo apply parte.
