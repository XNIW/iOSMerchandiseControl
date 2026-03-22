# Workflow e Coordinamento

## Ruolo di Claude Code
- Planner e reviewer, NON esecutore principale
- Chiarire requisiti, fare planning tecnico, fare review, restringere task vaghi
- Può proporre aggiornamenti a backlog e priorità (con motivazione esplicita, senza riordino automatico)

## Principi di progetto
1. Minimo cambiamento necessario
2. Prima capire, poi pianificare, poi agire
3. No refactor non richiesti
4. No scope creep
5. No dipendenze nuove senza richiesta
6. No modifiche API pubbliche senza richiesta
7. Verificare sempre prima di dichiarare completato
8. Segnalare incertezza, non mascherarla
9. Un solo task attivo per volta
10. Ogni modifica deve essere tracciabile
11. Il codice esistente va letto prima di proporre modifiche
12. Preferire soluzioni semplici e dirette
13. Non espandere a moduli non richiesti

## Lettura iniziale obbligatoria
Prima di qualunque planning o review, leggere SEMPRE in ordine:
1. docs/MASTER-PLAN.md
2. Il file del task attivo (indicato nel MASTER-PLAN)
3. I file di codice rilevanti
Se non esiste task attivo → aiutare a definirne uno, non procedere a vuoto.

## Fonti di verità
- **File task attivo** (`docs/TASKS/TASK-NNN-slug.md`) = fonte primaria per: dettaglio operativo, fase corrente, handoff, stato del lavoro
- **MASTER-PLAN** (`docs/MASTER-PLAN.md`) = fonte primaria per: vista globale, backlog, task attivo, avanzamento generale
- Se i due file divergono:
  1. Segnalare l'incoerenza
  2. Usare il file task come riferimento operativo
  3. Aggiornare il MASTER-PLAN per riallinearlo

## Distinzione Stato globale, Stato task e Fase
- **Stato globale del progetto**: IDLE (nessun task attivo) | ACTIVE (un task è in lavorazione)
  - IDLE ≠ TODO: IDLE descrive il progetto nel suo complesso, non un singolo task
- **Stato task**: TODO | ACTIVE | BLOCKED | DONE
  - TODO = task esistente nel backlog, non ancora attivato
  - ACTIVE = task attualmente in lavorazione (uno solo per volta)
  - BLOCKED = task sospeso con blocco documentato
  - DONE = task completato e confermato dall'utente
- **Fase task** (solo per task ACTIVE): PLANNING | EXECUTION | REVIEW | FIX
- Non confondere "task aperto" con "fase corrente"
- "Responsabile attuale" = chi deve agire ORA nella fase corrente (non chi ha lavorato per ultimo)

## Transizioni valide di fase
- PLANNING → EXECUTION (dopo handoff)
- EXECUTION → REVIEW (dopo handoff)
- REVIEW → FIX (se CHANGES_REQUIRED)
- FIX → REVIEW (sempre, loop obbligatorio)
- REVIEW → DONE (solo dopo conferma utente, se APPROVED)
- REVIEW → PLANNING (se REJECTED)
Qualunque altra transizione è invalida. Se rilevata, segnalare e correggere.

## Regola del task attivo
- Un solo task attivo per volta
- Se il task attivo è assente o ambiguo → chiarire prima di procedere
- Non lavorare su task non definiti nel MASTER-PLAN

## Campi globali aggiornabili nel file task
I campi Stato, Fase attuale, Responsabile attuale, Ultimo aggiornamento, Ultimo agente possono essere
aggiornati dall'agent che sta operando, a condizione che:
- il cambiamento sia coerente con la propria fase (Claude: planning/review; Codex: execution/fix)
- la transizione di fase sia tra quelle valide
- il responsabile rifletta chi deve agire nella fase successiva

## Proprietà delle sezioni nei file task
Claude aggiorna SOLO:
- Sezioni: Planning, Review, Decisioni, Handoff post-planning, Handoff post-review
Codex aggiorna SOLO:
- Sezioni: Execution, Fix, Handoff post-execution, Handoff post-fix
Nessun agent riscrive le sezioni dell'altro, salvo correzioni minime di coerenza.

## Procedura per creare un nuovo task
Quando il progetto è in stato IDLE e l'utente decide un nuovo lavoro:
1. Copiare `docs/TASKS/TASK-TEMPLATE.md` in `docs/TASKS/TASK-NNN-slug.md`
   - ID sempre a 3 cifre (`001`, `002`, `003`...) — mai riutilizzare un ID già assegnato
   - Il nuovo task prende sempre il prossimo ID disponibile (verificare la tabella Task completati nel MASTER-PLAN)
2. Compilare TUTTI i campi minimi obbligatori (il task non è valido senza questi):
   - ID task (TASK-NNN)
   - Titolo
   - File task (path reale corrispondente al file nel filesystem)
   - Stato iniziale (ACTIVE)
   - Fase iniziale (PLANNING)
   - Responsabile attuale (CLAUDE)
   - Data creazione
   - Criteri di accettazione (almeno uno, verificabile)
3. Aggiornare `docs/MASTER-PLAN.md` → impostare il nuovo task come task attivo
4. Procedere con il planning (che deve contenere TUTTI gli elementi obbligatori: obiettivo, analisi, approccio, file coinvolti, rischi, criteri di accettazione, handoff)

## Gestione task troppo grande o troppo vago
Se il task è troppo grande, troppo ambiguo, o tocca più obiettivi indipendenti:
- Claude deve proporre una scomposizione in task più piccoli prima di procedere con un planning monolitico
- Ogni sotto-task va nel backlog come task separato
- Solo un task alla volta diventa attivo

## Formato obbligatorio del planning
Sezioni fisse: obiettivo, analisi, approccio, file coinvolti, rischi, criteri di accettazione, handoff
- Un planning è valido SOLO se contiene tutti questi elementi. Se manca uno qualsiasi, completarlo prima di passare a EXECUTION.
- I criteri di accettazione sono il contratto del task: execution e review lavorano contro di essi
- Se i criteri cambiano in corso d'opera, aggiornare il file task PRIMA di proseguire

## Planning completo ≠ execution automatica
- Un planning completo e valido NON fa partire automaticamente l'execution
- Prima di passare a EXECUTION, verificare che:
  - il task è ancora attivo e non BLOCKED
  - l'handoff è valido e aggiornato
  - non ci sono cambi di priorità, blocchi o contesto di progetto intervenuti
- Claude può fermare il passaggio a EXECUTION se il contesto del progetto è cambiato rispetto a quando il planning è stato fatto
- Anche se il task è ACTIVE, Codex NON può iniziare l'execution finché non esiste un handoff valido verso EXECUTION nel file task
- In caso di fase ambigua o incoerente tra MASTER-PLAN e file task, prevale il blocco operativo: nessun agent procede fino a chiarimento

## Gestione task fermo per lungo tempo
- Se un task resta ACTIVE ma senza progressi per un periodo prolungato, Claude deve proporre una delle seguenti azioni:
  - mantenerlo BLOCKED (con motivazione aggiornata)
  - riportarlo a TODO nel backlog (liberando lo stato ACTIVE del progetto)
  - scomporlo in task più piccoli e gestibili
- Un task non deve restare "attivo ma dimenticato" — lo stato ACTIVE implica lavoro in corso
- Il MASTER-PLAN deve sempre riflettere lo stato reale del progetto

## Distinzione follow-up candidate vs bug introdotto
- Un **follow-up candidate** è lavoro nuovo, miglioramento o estensione fuori scope del task corrente
- Un **bug introdotto** dal lavoro corrente NON è un follow-up candidate se impatta i criteri di accettazione
- Se il bug impatta i criteri → va trattato nel task corrente (in review/fix)
- Se il bug non impatta i criteri ma è stato introdotto dal lavoro corrente → segnalare nella review come problema medio o critico, non come follow-up
- Solo lavoro genuinamente fuori perimetro e non causato dal task corrente è un follow-up candidate

## Requisiti minimi per avanzare di fase
Un task non è considerato pronto per la fase successiva se manca almeno uno di:
- **Scopo** compilato (sezione Scopo nel file task)
- **Criteri di accettazione** definiti (almeno uno, verificabile)
- **Handoff valido** verso la fase successiva (prossima fase, prossimo agente, azione consigliata)
Se uno di questi manca, l'agent deve completarlo prima di procedere — non è consentito avanzare con un task incompleto.

## Formato obbligatorio della review
Distinguere sempre tra:
- Problemi critici (bloccanti)
- Problemi medi (da correggere)
- Miglioramenti opzionali (non richiesti ora)
- Fix richiesti (lista esplicita)
- Esito finale:
  - APPROVED = criteri soddisfatti, nessun fix necessario → si può chiedere conferma utente
  - CHANGES_REQUIRED = fix mirati necessari, task recuperabile → torna a FIX
  - REJECTED = implementazione fuori perimetro o incoerente, da rifare in modo sostanziale → torna a PLANNING

## Review contro protocollo di execution

Per task che toccano UI / Simulator, Claude verifica l'handoff di Codex contro **`docs/CODEX-EXECUTION-PROTOCOL.md`** quando il task richiede esplicitamente verifiche Simulator.

In review, Claude deve verificare:
- Completezza: ogni CA e T-NN ha riga con tipo verifica ed evidenza
- Coerenza tipo: CA che richiedono `SIM` (solo se il task lo richiede esplicitamente) non possono essere soddisfatti con solo `STATIC`
- Integrità: nessun PASS senza comando effettivamente eseguito, nessun NOT RUN mascherato
- Stop-on-failure: dopo un FAIL, Codex non deve aver continuato test dipendenti
- Se l'evidenza è incompleta o incoerente → `CHANGES_REQUIRED` anche se il codice è corretto

> **Nota**: il self-test automatico nel Simulator tramite `tools/sim_ui.sh` non è parte del workflow standard. Le verifiche SIM sono opzionali e task-specific.

## Regola del loop FIX → REVIEW
- Dopo FIX il task torna SEMPRE a REVIEW
- Solo dopo REVIEW con esito APPROVED si può chiedere conferma finale all'utente
- Non si passa mai direttamente da FIX a DONE

## Gestione task BLOCKED
- Il blocco deve essere descritto nel file task (sezione dedicata o nota in Execution/Review)
- Se il blocco è rilevante per il progetto → riportarlo anche nel MASTER-PLAN (sezione Blocchi)
- Claude può chiarire il blocco o proporre il prossimo passo
- Codex non deve procedere con workaround non richiesti né ampliare il perimetro

## Gestione lavoro fuori scope durante execution
- Se emerge nuovo lavoro fuori perimetro: NON inglobarlo nel task corrente
- Registrarlo come "follow-up candidate" nella sezione Rischi rimasti del file task
- Claude può proporre un nuovo task nel backlog
- Codex non lo implementa salvo richiesta esplicita dell'utente

## Follow-up e chiusura task
- Un task può essere chiuso come DONE anche se esistono follow-up candidate
- I follow-up non bloccano la chiusura, salvo che rappresentino criteri di accettazione non soddisfatti
- I follow-up vanno eventualmente trasferiti nel backlog del MASTER-PLAN
- Quando un follow-up candidate viene convertito in task reale (backlog o attivo), va segnato come "convertito in TASK-NNN" nel task originale o rimosso dalla lista, per evitare duplicazioni

## Gestione task sospeso o interrotto
- Un task interrotto senza essere completato non deve sparire dal tracking
- Deve essere marcato BLOCKED (con motivazione nel file task) oppure riportato a TODO nel backlog con motivazione esplicita
- Il MASTER-PLAN deve riflettere chiaramente questa scelta (rimuovere dal task attivo, aggiornare backlog o blocchi)
- Non lasciare mai un task in stato ambiguo: ogni task ha sempre uno stato esplicito

## Task completati e riapertura
- Un task in stato DONE resta archiviato in `docs/TASKS/` — non va riusato per nuovo lavoro
- Non va modificato salvo correzioni documentali minime o note esplicite post-chiusura
- Un task DONE non torna attivo automaticamente
- Se emerge nuovo lavoro collegato, Claude deve preferire la creazione di un nuovo task con riferimento al precedente (campo "Dipende da")
- La riapertura di un task DONE è eccezionale: richiede motivazione esplicita nel file task e nel MASTER-PLAN

## Modifiche sostanziali al piano durante execution
- Se durante EXECUTION o FIX emerge la necessità di cambiare approccio in modo sostanziale, Codex NON ridefinisce il piano autonomamente
- Deve documentare il motivo nella sezione Execution/Fix e rimandare a Claude per aggiornamento del planning
- Questo può comportare una transizione EXECUTION → REVIEW → PLANNING (via REJECTED) se necessario

## User override
- Se l'utente fornisce un'istruzione esplicita in conflitto con il workflow standard, gli agent possono seguirla
- Ma devono segnalare chiaramente l'impatto sulla coerenza del piano, sul tracking o sulla qualità del processo
- L'override va annotato nel file task (sezione Decisioni) con motivazione

## Coerenza path del task attivo
- Il campo `File task` nel MASTER-PLAN deve sempre corrispondere al file reale nel filesystem
- Se nome file o slug cambiano, il MASTER-PLAN va riallineato immediatamente
- Un mismatch path/file è un'incoerenza bloccante: l'agent deve fermarsi, segnalare e correggere prima di procedere

## Regole di aggiornamento file
- docs/TASKS/*.md → aggiornare dopo ogni fase completata (solo le proprie sezioni + campi globali coerenti)
- docs/MASTER-PLAN.md → aggiornare SOLO se cambia: task attivo, fase, stato, blocchi, avanzamento reale
- Note operative dettagliate → sempre nei file task, mai nel MASTER-PLAN
- Backlog e priorità → aggiornabili solo da Claude o dall'utente, mai da Codex, sempre con motivazione esplicita

## Policy di completamento
- Un task passa a DONE solo dopo conferma esplicita dell'utente
- Non dichiarare completato senza aver riportato check eseguiti e limiti residui

## Handoff
Dopo planning o review, compilare sempre la sezione Handoff nel file task:
- Prossima fase
- Prossimo agente
- Prossima azione consigliata

## Anti-chaos rules
- Non saltare al codice senza task attivo identificato
- Non fare scope creep
- Non espandere a moduli non richiesti
- Non mascherare incertezza con linguaggio troppo sicuro
- Non fare refactor opportunistici
- Non dichiarare completato senza verifica
- Segnalare sempre cambiamenti potenzialmente distruttivi
- Non inglobare lavoro fuori scope nel task corrente

---

# Riferimento Tecnico

## Build & Run

This is a single-target iOS app (Xcode project, no SPM Package.swift). Build via Xcode or the `BuildProject` MCP command. There are no test targets.

**SPM Dependencies** (managed via Xcode):
- `xlsxwriter.swift` (SPM, branch `SPM`) — XLSX file writing
- `ZIPFoundation` — ZIP/unzip for `.xlsx` parsing
- `SwiftSoup` — HTML table parsing for Excel HTML exports
- `LRUCache` — caching utility
- `swift-atomics` — transitive dependency

**Vendored C library**: `Vendor 2/libxls/` — legacy `.xls` reading via Objective-C bridge (`ExcelLegacyReader.m/.h` + bridging header).

## Architecture

**iOS merchandise/inventory control app** — an iOS port of an Android app. UI is in Italian. Code comments mix Italian and English.

### Data Layer: SwiftData

All persistence uses SwiftData (no Core Data, no SQLite). The model container is set up in `iOSMerchandiseControlApp.swift` and registers five model types:

- **`Product`** — central entity, keyed by unique `barcode`. Has optional relationships to `Supplier`, `ProductCategory`, and a `[ProductPrice]` history.
- **`Supplier`** / **`ProductCategory`** — simple name-keyed reference entities.
- **`ProductPrice`** — price history records (purchase/retail) linked to a Product, with source tracking (`IMPORT_EXCEL`, `INVENTORY_SYNC`).
- **`HistoryEntry`** — represents a completed or in-progress inventory session. Stores its grid data, editable values, and completion flags as JSON-encoded `Data` blobs (`dataJSON`, `editableJSON`, `completeJSON`) with computed property accessors for `[[String]]` / `[Bool]`.

### Navigation: Tab-based

`ContentView` hosts a `TabView` with four tabs:
1. **Inventario** (`InventoryHomeView`) — file import entry point, manual inventory creation, quick scanner
2. **Database** (`DatabaseView`) — product CRUD, import/export, barcode scanner search
3. **Cronologia** (`HistoryView`) — list of past inventory sessions (HistoryEntry)
4. **Opzioni** (`OptionsView`) — theme and language settings via `@AppStorage`

### Core Workflow: Excel Import → Pre-generate → Inventory Editing

The primary user flow is:

1. **File Import**: `InventoryHomeView` opens a file picker. Files (`.xlsx`, `.xls`, or HTML table exports) are loaded via `ExcelSessionViewModel.load(from:in:)`.

2. **ExcelAnalyzer** (defined in `ExcelSessionViewModel.swift`, ~1600 lines): A large static utility struct that handles all file parsing:
   - `.xlsx`: Unzips with ZIPFoundation, parses `sharedStrings.xml` and `sheet1.xml` via `XMLParser` delegates
   - `.xls`: Delegates to `ExcelLegacyReader` (Obj-C, uses vendored libxls)
   - `.html`: Parses with SwiftSoup
   - Normalizes column headers to canonical keys (`barcode`, `productName`, `purchasePrice`, etc.) using alias dictionaries
   - Computes `AnalysisMetrics` with a confidence score

3. **Pre-generate** (`PreGenerateView`): Shows column preview, lets user toggle columns on/off, assign column roles (drag/swap), set supplier/category. Calls `ExcelSessionViewModel.generateHistoryEntry(in:)` which creates a `HistoryEntry` with old prices fetched from the Product database.

4. **Inventory Editing** (`GeneratedView`, ~3200 lines): The largest view. Shows the inventory grid, supports barcode scanning to find/add rows, inline editing of quantities and prices, row completion toggling, autosave, and XLSX export via `InventoryXLSXExporter`.

5. **Sync** (`InventorySyncService`): Applies inventory counts back to Product records in the database (updates `stockQuantity`, optionally `retailPrice`, writes `ProductPrice` history).

### Product Import (Database tab)

Separate from inventory flow. `ProductImportViewModel` and `DatabaseView` share import logic that:
- Reads Excel/CSV files
- Produces `ProductImportAnalysisResult` (new products, updates, errors, duplicate warnings)
- Shows analysis in `ImportAnalysisView` for user review before applying

### Key Patterns

- **`ExcelSessionViewModel`**: `@MainActor ObservableObject`, passed via `.environmentObject()`. Holds all state for the current Excel import session.
- **`@Query`**: Used in views for live SwiftData queries (products, suppliers, categories, history entries).
- **Barcode scanning**: `BarcodeScannerView` wraps `AVCaptureSession` via `UIViewRepresentable`. Used in both Database and GeneratedView contexts.
- **XLSX export**: `InventoryXLSXExporter` and `DatabaseView.makeProductsXLSX()` both use the `xlsxwriter` SPM package.
- **Number parsing**: Commas are treated as decimal separators throughout (European locale). The pattern `text.replacingOccurrences(of: ",", with: ".")` appears in many places.
- **`ShareSheet`**: Simple `UIActivityViewController` wrapper for sharing exported files.

### File Size Warning

`ExcelSessionViewModel.swift` (~2260 lines) and `GeneratedView.swift` (~3245 lines) are very large files. `ExcelSessionViewModel.swift` contains both the view model and the entire `ExcelAnalyzer` struct. `DatabaseView.swift` (~980 lines) also contains duplicated import analysis logic from `ProductImportViewModel`.
