# TASK-011: Large import stability, memory e progress UX

## Informazioni generali
- **Task ID**: TASK-011
- **Titolo**: Large import stability, memory e progress UX
- **File task**: `docs/TASKS/TASK-011-large-import-stability-and-progress.md`
- **Stato**: BLOCKED
- **Fase attuale**: REVIEW (sospeso in questa fase)
- **Responsabile attuale**: — (task sospeso, nessun agente deve procedere)
- **Data creazione**: 2026-03-21
- **Ultimo aggiornamento**: 2026-03-23
- **Ultimo agente che ha operato**: CODEX

## Blocco (2026-03-23)

- **Motivo**: sospeso per decisione utente; il problema emerso nei test reali viene estratto in TASK-022 perche' piu' specifico e immediatamente bloccante.
- **Impatto sul tracking**: TASK-022 diventa il task attivo e il blocker pratico corrente per TASK-006. TASK-011 resta come contesto umbrella/storico per eventuale lavoro residuo su stabilita', memory e progress UX dei large import.
- **Azione necessaria per eventuale ripresa**: attendere il planning e l'esito di TASK-022, poi rivalutare con Claude e utente se restano parti residue di TASK-011 ancora utili o se il task va ridefinito.

> Nota tracking 2026-03-23: planning, execution, review e fix sotto questo punto restano come storico del lavoro gia' svolto. Non costituiscono handoff operativo corrente.

## Dipendenze
- **Dipende da**: TASK-006 (contesto originario del problema); TASK-022 (il crash specifico estratto va risolto prima di un'eventuale ripresa del perimetro piu' ampio)
- **Sblocca**: nessuno direttamente (lo sblocco pratico di TASK-006 e' ora attribuito a TASK-022)

## Scopo
Rendere l'import di dataset molto grandi (migliaia di prodotti) stabile, non bloccante per l'UI e con progress reporting chiaro, senza causare freeze, memory pressure o app kill. Il task copre **entrambi** i flussi di import:
- **`importFullDatabaseFromExcel`** (multi-sheet, TASK-006) — flusso principale, include PriceHistory
- **`importProductsFromExcel`** (singolo-sheet) — condivide `analyzeImport()` e `applyConfirmedImportAnalysis()` con il multi-sheet; il parsing è diverso (usa `readAndAnalyzeExcel`) ma l'apply è lo stesso codice

Le mitigazioni (offload parsing, progress pre-apply, autoreleasepool, troncamento preview) devono coprire entrambi i flow. Dove il codice diverge (parsing), le modifiche vanno applicate a ciascun entry point.

## Contesto
Durante i test di TASK-006 è emerso che l'import di dataset molto grandi (ordine di grandezza: migliaia di prodotti, decine di migliaia di record PriceHistory) causa instabilità:
- **App kill per memoria**: iOS termina il processo durante l'analisi o l'apply per OOM (Out Of Memory)
- **EXC_BAD_ACCESS**: crash durante operazioni SwiftData sotto pressione di memoria
- **UI congelata durante parsing/analyze**: il thread principale è bloccato durante il parsing dei fogli e l'analisi; l'utente non riceve feedback fino a quando ImportAnalysisView appare
- **ImportAnalysisView con dataset grandi**: nessun troncamento della preview, rendering di migliaia di view SwiftUI

**Stato attuale (post-lavoro precedente)**: L'apply è già stato spostato su background (`Task.detached` + `ModelContext` separato), con save ogni 250 item, progress UI con contatore aggiornato ogni 25 item, e `Task.yield()` dopo ogni save. I gap residui sono: parsing/analyze sincroni sul main thread, PriceHistory materializzato interamente in memoria, nessun autoreleasepool nei batch, ImportAnalysisView senza troncamento.

## Non incluso
- Modifica del formato XLSX multi-sheet (rimane com'è da TASK-006)
- Modifica degli entry point UI (già definiti da TASK-006)
- Ottimizzazione dell'export (non è il collo di bottiglia)
- Refactor completo dell'architettura di import (solo le modifiche minime necessarie per la stabilità)
- Streaming parser XLSX (complessità elevata, fuori perimetro)
- Supporto a file .xls legacy multi-sheet
- Localizzazione messaggi di progresso
- Gestione di file corrotti oltre quanto già gestito

## File potenzialmente coinvolti
- `iOSMerchandiseControl/DatabaseView.swift` — orchestrazione import, `analyzeImport`, `applyImportAnalysis`, `applyPendingPriceHistoryImport`, `importNamedEntitiesSheet`; aggiunta progress state
- `iOSMerchandiseControl/ImportAnalysisView.swift` — rendering della lista prodotti da analizzare; potenziale problema di rendering con migliaia di righe
- `iOSMerchandiseControl/ExcelSessionViewModel.swift` — `ExcelAnalyzer.readSheetByName` e analisi righe; già carica tutto in memoria, ma potenziale ottimizzazione del parsing

## Criteri di accettazione
- [ ] **CA-1**: Import full-database di 5.000 Products + 50.000 PriceHistory completa senza app kill né crash (OOM, EXC_BAD_ACCESS) — evidenza: log di completamento + Instruments Allocations. Target memoria: peak < 300 MB su device reale; su Simulator il valore assoluto non è vincolante (RAM illimitata), usare Allocations come confronto relativo before/after per validare che le ottimizzazioni riducano il peak
- [ ] **CA-2**: Durante parsing + analyzeImport l'UI mostra un indicatore di attività (spinner o ProgressView) — l'app non appare bloccata. Vale sia per il flow multi-sheet che singolo-sheet.
- [ ] **CA-3**: Durante l'apply l'UI mostra progress con contatore aggiornato — già presente, da verificare che funzioni anche sotto dataset grande senza lag significativo
- [ ] **CA-4**: Apply di 5.000 prodotti nuovi completa correttamente (tutti i record nel DB) senza errori SwiftData intermedi
- [ ] **CA-5**: Apply di 50.000 record PriceHistory completa senza crash
- [ ] **CA-6**: Zero regressioni su dataset piccoli (< 500 righe): singolo-sheet, CSV, multi-sheet funzionano come prima
- [ ] **CA-7**: ImportAnalysisView con 5.000+ righe non causa freeze né crash — preview troncata oltre soglia (500 per prodotti, 200 per errori), banner visibile, apply sull'intero dataset
- [ ] **CA-8**: Build compila senza errori e senza warning nuovi
- [ ] **CA-9**: Evidenza di profiling — log separati dei tempi di parsing, analyze, apply (tempi in secondi) e screenshot/report Instruments (Allocations + Time Profiler) su dataset grande
- [ ] **CA-10**: Nessun doppio import contemporaneo possibile — pulsanti import disabilitati durante l'intero ciclo (parsing → analyze → apply), guard programmatico che ignora trigger concorrenti
- [ ] **CA-11**: Partial failure gestito: se products completano ma PriceHistory fallisce, l'utente riceve messaggio esplicito che distingue il successo parziale dall'errore; i prodotti già salvati restano nel DB

## Decisioni
| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|-------|
| 1 | Partial failure best-effort: prodotti persistiti anche se PH fallisce | Rollback completo se PH fallisce | Coerente con TASK-006; rollback di migliaia di insert è costoso e fragile; meglio comunicare chiaramente il successo parziale | APPROVATO |
| 2 | `context.reset()` opzionale, solo se profiling lo richiede | `context.reset()` come parte della baseline | Troppo aggressivo, invalida riferimenti, richiede rebuild dei dict. Autoreleasepool + save cadence sono la baseline sufficiente | APPROVATO |
| 3 | Troncamento errors a 200 (non illimitato) | Errors completamente illimitati | Anche gli errori possono essere migliaia (es. file con colonne sbagliate); export completo sempre disponibile come safety net | APPROVATO |

---

## Planning (Claude)

### As-Is — Stato attuale del codice (branch main, 2026-03-23)

#### Cosa è GIÀ implementato

**1. Progress UI nell'apply (DatabaseView.swift:68-117, 512-540)**
- Classe `DatabaseImportProgressState` (`@MainActor ObservableObject`) con `stageText`, `processedCount`, `totalCount`, `progressFraction`
- Overlay con `ProgressView` determinata (barra) quando `progressFraction` è disponibile, indeterminata (spinner) altrimenti
- Aggiornamento del contatore visibile durante apply

**2. Apply in background con context separato (DatabaseView.swift:1259-1316)**
- `Task.detached(priority: .userInitiated)` per l'apply
- Nuovo `ModelContext(modelContainer)` creato nel background task — isolato dal main context
- Callback `onProgress` asincrono che risale al MainActor per aggiornare la UI

**3. Batched save (DatabaseView.swift:178-179, 1690-1701)**
- `importSaveBatchSize = 250`: `context.save()` ogni 250 item
- `importProgressBatchSize = 25`: aggiornamento UI ogni 25 item
- `Task.yield()` dopo ogni save per cedere tempo alla cooperative queue

**4. Conversione Sendable per il background (DatabaseView.swift:1278-1297)**
- `ImportApplyPayload` con snapshot Sendable di prodotti, PriceHistory, supplier, categorie
- Evita il passaggio di oggetti SwiftData tra actor

#### Cosa NON è implementato — gap reali

**GAP-1: Parsing + analyze sincroni sul main thread (entrambi i flow)**
- `importFullDatabaseFromExcel()` (line ~980): blocca l'UI per tutta la durata di:
  - `ExcelAnalyzer.readSheetByName()` × 4 fogli — decompressione ZIP + XML parsing
  - `analyzeImport()` — fetch di tutti i prodotti esistenti + confronto riga per riga
  - `parsePendingPriceHistoryContext()` — lettura e parsing dell'intero foglio PriceHistory
- `importProductsFromExcel()` (line ~945): stesso problema — `readAndAnalyzeExcel()` + `analyzeImport()` sincroni sul main thread
- **Risultato**: in entrambi i flow l'UI è completamente congelata, nessun spinner visibile. L'utente non ha feedback fino a quando non appare ImportAnalysisView.

**GAP-2: PriceHistory materializzato interamente in memoria**
- `parsePendingPriceHistoryContext()` (line ~1535): legge l'intero foglio PriceHistory in un `[[String]]`, poi costruisce un array di `PendingPriceHistoryImportEntry`
- Con 50.000 righe questo array e il suo `[[String]]` sorgente convivono in memoria → picco stimato 50-100 MB solo per questa struttura
- L'array viene poi convertito in `ImportPendingPriceHistoryEntrySnapshot` (altro array in memoria) per il background apply

**GAP-3: ImportAnalysisView senza troncamento**
- `ImportAnalysisView` (ImportAnalysisView.swift:139-395): usa `List` con `ForEach` diretto su `analysis.newProducts` e `analysis.updatedProducts`
- Nessuna LazyVStack, nessuna paginazione, nessun limite di rendering
- Con 5.000+ prodotti nuovi: rendering di migliaia di SwiftUI views al primo display → freeze percepibile, possibile OOM su device con poca RAM

**GAP-4: Nessun autoreleasepool nell'apply**
- I loop di apply (new products, updated products, price history) iterano item per item con save ogni 250
- Tra un save e l'altro, 250 oggetti SwiftData appena creati/modificati restano nella dirty page del context senza autorelease
- Su 5.000+ prodotti: il context accumula tutti gli oggetti senza mai rilasciarli (no `context.reset()`, no `autoreleasepool`)
- Possibile causa di memory pressure crescente durante l'apply nonostante il batched save

**GAP-5: Nessun progress durante la fase pre-apply**
- Il `DatabaseImportProgressState` è attivato solo nella fase apply
- Le fasi di parsing (lettura fogli) e analyze (confronto DB) non riportano nessun feedback UI
- L'utente vede solo schermo fermo fino a quando `importAnalysisResult` viene settato

### To-Be — Approccio proposto (refinement, non riscrittura)

#### Strategia generale
Raffinare l'implementazione esistente colmando i gap reali. L'architettura apply-in-background con batched save è corretta — va estesa alle fasi precedenti e ottimizzata per memory pressure.

#### Nota implementativa: security-scoped resource lifecycle

Attualmente `importFullDatabaseFromExcel()` e `importProductsFromExcel()` usano `url.startAccessingSecurityScopedResource()` / `defer { url.stopAccessingSecurityScopedResource() }` in modo sincrono. Spostando il parsing in un `Task {}`, il `defer` sulla funzione esterna rilascerebbe il permesso prima che il task asincrono abbia finito di leggere il file.

**Strategia richiesta**: copiare il file in una temp location app-owned **prima** di entrare nel `Task {}`, e parsare la copia. Questo è il pattern più sicuro perché:
- Il permesso security-scoped viene rilasciato subito (nel `defer` della funzione esterna, sul main thread)
- Il file copiato è sotto il controllo dell'app e non può essere revocato
- Elimina la possibilità di race condition su revoca permessi

```swift
// Pattern target
let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
try FileManager.default.copyItem(at: url, to: tempURL)
defer { try? FileManager.default.removeItem(at: tempURL) }
// ... poi nel Task {} usare tempURL
```

**Nota**: il `defer { try? FileManager.default.removeItem(at: tempURL) }` deve essere posizionato in modo che il cleanup avvenga dopo il completamento del `Task {}`, non alla fine della funzione esterna. In pratica, il `removeItem` va dentro il `Task {}` stesso (nel suo `defer` o al termine), non fuori.

#### Nota implementativa: failure cleanup pre-apply (comportamento obbligatorio)

Se il parsing o l'analyze falliscono (dentro il `Task {}` o prima), il cleanup deve **sempre** includere tutti i seguenti passi, sul MainActor:
1. **Reset di `isRunning`**: `importProgress.isRunning = false` (o equivalente reset dello stato)
2. **Rimozione overlay/progress**: lo stato di progress deve tornare a idle — nessun spinner residuo
3. **Ripristino trigger UI**: i pulsanti import devono tornare abilitati (conseguenza automatica del reset di `isRunning` se il `.disabled()` è legato a quel flag)
4. **Pubblicazione errore**: `importError = error.localizedDescription` (o messaggio appropriato) sul MainActor, in modo che l'utente veda l'alert di errore

Questo va implementato come `do/catch` attorno all'intero corpo del `Task {}`, con il cleanup nel ramo `catch`. Non è accettabile che un errore di parsing lasci l'UI in stato bloccato (overlay visibile, pulsanti disabilitati, nessun messaggio di errore).

#### STEP 1 — Offload parsing + analyze dal main thread (entrambi i flow)

**Flow multi-sheet** — spostare il corpo di `importFullDatabaseFromExcel()` in un `Task { }`:
- **Parsing fogli** (readSheetByName × 4): CPU-bound puro, nessun accesso a modelContext → può girare su background senza restrizioni
- **analyzeImport()**: richiede un fetch iniziale di prodotti esistenti dal DB. Strategia:
  - **Default**: creare un `ModelContext(modelContainer)` separato nel background (dentro il `Task {}`) e fare il fetch lì. Questo è coerente con il pattern già usato per l'apply e tiene tutto il lavoro pesante fuori dal main thread.
  - **Fallback**: pre-fetch sul main context prima del `Task {}`, passare il risultato come array di struct Sendable al background. Usare solo se emerge un vincolo tecnico concreto che impedisce il fetch su background context (es. crash, dati inconsistenti).
- **parsePendingPriceHistoryContext()**: puro parsing, nessun accesso al DB → background
- Aggiornare `importAnalysisResult` via `await MainActor.run { }` quando pronto

**Flow singolo-sheet** — spostare il corpo di `importProductsFromExcel()` in un `Task { }`:
- `readAndAnalyzeExcel()` è CPU-bound → background
- `analyzeImport()` → stessa strategia del multi-sheet (default: background context separato)
- Aggiornare `importAnalysisResult` via `await MainActor.run { }` quando pronto

**Progress pre-apply** (comune a entrambi): estendere `DatabaseImportProgressState` con stadi pre-apply:
- `.parsing(sheetName: String)` — aggiornato per ogni foglio letto (multi-sheet) o al singolo parsing (singolo-sheet)
- `.analyzing` — durante analyzeImport
- Gli stadi apply esistenti restano invariati

#### STEP 2 — Riduzione memory pressure nell'apply

L'apply usa già background context + save ogni 250 + yield. Integrare:

- **autoreleasepool** (baseline): wrappare ogni batch di 250 item in `autoreleasepool { }` per forzare il rilascio di oggetti Obj-C bridged e temporanei Swift. Il context di SwiftData usa internamente Core Data che beneficia di autoreleasepool.
- **PriceHistory**: il loop attuale elabora 1 entry per iterazione con save ogni 250. Verificare che il progress callback ogni 25 item non introduca overhead significativo su 50.000 iterazioni.

**Nota su `context.reset()`**: questa misura è **opzionale e guidata da profiling**. NON fa parte della baseline di implementazione. Applicarla solo se, dopo aver implementato autoreleasepool + rilascio anticipato PriceHistory + offload parsing, Instruments Allocations mostra che il peak memory durante l'apply resta sopra il target (300 MB). Se necessaria, richiede ricostruzione dei lookup dict dopo il reset — trade-off significativo. Non implementare preventivamente.

#### STEP 3 — Riduzione footprint PriceHistory pre-apply

`parsePendingPriceHistoryContext()` carica l'intero foglio PriceHistory in `[[String]]` e poi lo converte in array di struct.
- **Opzione minima**: dopo aver costruito l'array di `PendingPriceHistoryImportEntry`, rilasciare immediatamente il `[[String]]` sorgente (assicurarsi che la variabile esca dallo scope o assegnarla a `nil`)
- **Opzione avanzata**: non materializzare l'intero `[[String]]` — processare riga per riga dal XML/sheet e costruire direttamente le struct. Questo richiede modifiche a `ExcelAnalyzer.readSheetByName()` (fuori scope se troppo invasivo).
- Preferire l'opzione minima: è sufficiente e a basso rischio.

#### STEP 4 — Troncamento preview in ImportAnalysisView

**Soglie ufficiali**:
- `newProducts`, `updatedProducts`, `warnings`: **500** item per sezione
- `errors`: **200** item (soglia più bassa per dare massima visibilità agli errori)

**Comportamento**:
- Se `analysis.newProducts.count > 500`: mostrare solo i primi 500, con banner in testa alla sezione:
  > "Mostrando i primi 500 di 3.247 nuovi prodotti. L'import includerà tutti."
- Stessa logica per `updatedProducts` e `warnings` (soglia 500)
- **Errors**: soglia 200. Banner: "Mostrando i primi 200 di N errori. Esporta per la lista completa." L'export CSV/testo degli errori completi deve restare sempre disponibile (già presente o da aggiungere se mancante).

**Vincolo implementativo — troncamento solo visuale**:
- Il troncamento deve usare **computed slices / preview arrays** (es. `Array(analysis.newProducts.prefix(500))`) per il rendering
- **Non mutare** `analysis.newProducts`, `analysis.updatedProducts`, `analysis.errors` né nessun campo del dataset reale `ProductImportAnalysisResult`
- Il pulsante Apply e tutta la logica di apply devono continuare a operare sull'**intero dataset originale**, non sulle slice troncate
- Se esistono funzionalità di editing inline sulle righe in ImportAnalysisView, queste operano sulle righe visibili (prime N) — l'apply include comunque tutto

**Nessuna regressione UX su dataset piccoli**: sotto soglia non appare nessun banner, il comportamento è identico a oggi

#### STEP 5 — Logging dei tempi (per profiling e CA-9)

Aggiungere log strutturati con `os_log` o `print` per misurare:
- Tempo totale di parsing per foglio (inizio/fine readSheetByName per ogni sheet)
- Tempo totale di analyzeImport
- Tempo totale di parsePendingPriceHistoryContext
- Tempo totale di apply products (+ count)
- Tempo totale di apply price history (+ count)
- Memory peak se misurabile (altrimenti rilevarlo da Instruments)

Formato: `[TASK-011] phase=parsing sheet=Products elapsed=2.3s rows=5000`

#### STEP 6 — Import concurrency guard

L'apply ha già un guard (`guard !importProgress.isRunning`, line 1236) che impedisce un doppio apply contemporaneo. Estendere la protezione all'intero ciclo import (parsing + analyze + apply):

- **Principio**: niente doppio import contemporaneo. Un solo import attivo per volta, dall'inizio del parsing alla fine dell'apply.
- **UI**: disabilitare i pulsanti/azioni che triggerano import (file picker, pulsanti "Importa") quando un import è in corso. Il `.disabled(importProgress.isRunning)` sulla lista (line 317) copre già parte della UI, ma verificare che copra **tutti** i trigger di import, incluso il singolo-sheet.
- **Guard programmatico**: se nonostante il disable un secondo trigger arriva (es. race condition, gesture residua), il guard deve ignorarlo deterministicamente (early return o throw, non crash). L'`importProgress.isRunning` va attivato all'inizio del parsing (non solo all'inizio dell'apply) per coprire l'intero ciclo.
- **Nota**: dopo STEP 1 il parsing è asincrono — il flag `isRunning` deve essere settato **prima** di entrare nel `Task {}`, sul main thread, per evitare race tra due tap rapidi.

#### STEP 7 — Partial failure semantics e comunicazione errore

Attualmente `applyImportAnalysisInBackground` esegue sequenzialmente: (1) apply products, (2) apply price history. Se (1) completa ma (2) fallisce, i prodotti sono già persistiti (save ogni 250) ma la price history è parziale o assente.

- **Risultato strutturato**: `applyImportAnalysisInBackground` deve restituire (o produrre via callback) un risultato strutturato con count separati:
  ```swift
  struct ImportApplyResult {
      let productsInserted: Int
      let productsUpdated: Int
      let priceHistoryInserted: Int
      let priceHistoryError: Error?   // nil = successo, non-nil = partial failure
  }
  ```
  Sia il messaggio utente che i log STEP 5 devono derivare da questa struct, non da stringhe costruite ad-hoc nei vari rami. Questo garantisce che il successo parziale sia determinato da dati strutturati, non dedotto da log o messaggi.

- **Comportamento target**: partial failure è accettabile (best-effort, coerente con TASK-006). Se products completano ma price history fallisce:
  - I prodotti già salvati restano nel DB (non vengono rollbackati)
  - Il messaggio utente è costruito dal `ImportApplyResult`: "Prodotti importati: N nuovi, M aggiornati. Errore storico prezzi: [dettaglio]. Storico prezzi potrebbe essere incompleto (K di T salvati)."
  - Se `priceHistoryError == nil`: messaggio di successo completo
  - Se `priceHistoryError != nil` e `priceHistoryInserted > 0`: successo parziale (alcuni batch completati)
  - Se `priceHistoryError != nil` e `priceHistoryInserted == 0`: errore totale PH

- **Implementazione**: wrappare la chiamata a `applyPendingPriceHistoryImport` in un do/catch separato dentro `applyImportAnalysisInBackground`, anziché lasciare che il throw propaghi e mascheri il successo parziale dei prodotti. Accumulare i count in `ImportApplyResult` progressivamente durante l'apply.

- **Logging**: il log STEP 5 serializza `ImportApplyResult` in formato strutturato: `[TASK-011] result productsInserted=4800 productsUpdated=200 priceHistoryInserted=48000 priceHistoryError=nil`

### File da modificare
| File | Tipo modifica | Gap/STEP coperto |
|------|---------------|------------------|
| `DatabaseView.swift` | Task {} per parsing+analyze (entrambi i flow); progress pre-apply; autoreleasepool nei batch apply; rilascio anticipato PriceHistory; concurrency guard esteso; partial failure handling; logging tempi | GAP-1,2,4,5 + STEP 6,7 |
| `ImportAnalysisView.swift` | Troncamento sezioni con soglia 500 (200 per errors) + banner informativo | GAP-3 |

### Rischi identificati
| Rischio | Probabilità | Impatto | Mitigazione |
|---------|-------------|---------|-------------|
| `analyzeImport()` usa il modelContext per fetch — spostamento su background richiede context separato o pre-fetch | Media | Medio | Preferire pre-fetch su main context (singolo fetch), passare snapshot al background. Se il fetch stesso è lento, usare context separato |
| `autoreleasepool` in Swift structured concurrency potrebbe non rilasciare come atteso | Bassa | Basso | Verificare empiricamente con Instruments Allocations — confrontare peak con/senza autoreleasepool. Se non efficace, il save+yield ogni 250 è comunque il floor di mitigazione |
| Troncamento confonde l'utente | Bassa | Basso | Banner chiaro e visibile: "Mostrando i primi N di M. L'import includerà tutti i prodotti." |
| Pre-fetch di tutti i Product sul main thread per passarli al background potrebbe essere lento con DB già grande | Bassa | Medio | Il fetch è una singola query SQL — SwiftData lo ottimizza. Se emerge come collo di bottiglia (> 2s), spostare su background context |
| Partial failure: prodotti salvati ma PH fallito → utente confuso | Media | Medio | Messaggio esplicito che distingue successo prodotti da errore PH; logging separato dei count |
| Race condition: due tap rapidi su import prima che `isRunning` venga settato | Bassa | Medio | Settare `isRunning = true` sul main thread PRIMA di entrare nel `Task {}` — nessuna finestra di race |
| Security-scoped resource revocata durante parsing asincrono | Alta | Alto | Copiare il file in temp location app-owned PRIMA del Task {}, parsare la copia. Il permesso viene rilasciato subito, il file copiato non può essere revocato |
| Errore in parsing/analyze lascia UI bloccata (overlay + pulsanti disabilitati) | Media | Alto | do/catch obbligatorio attorno all'intero corpo del Task {}, cleanup completo nel catch (reset isRunning, rimozione overlay, pubblicazione errore) |

### Piano di verifica

#### Dataset di test
- **Piccolo**: 100 prodotti, 500 PriceHistory — smoke test regressione
- **Medio**: 1.000 prodotti, 5.000 PriceHistory — verifica funzionale
- **Grande**: 5.000 prodotti, 50.000 PriceHistory — test principale per CA-1/CA-4/CA-5

#### Test funzionali
1. **Smoke regression multi-sheet**: import file piccolo multi-sheet → comportamento invariato, nessuna regressione
2. **Smoke regression singolo-sheet**: import file piccolo singolo-sheet → comportamento invariato, nessuna regressione
3. **Progress pre-apply (multi-sheet)**: import file grande multi-sheet → verificare che appaia spinner/testo durante parsing e analyze, PRIMA della ImportAnalysisView
4. **Progress pre-apply (singolo-sheet)**: import file grande singolo-sheet → verificare spinner durante parsing/analyze
5. **Progress apply**: import file grande → verificare contatore aggiornato durante apply (già presente, validare che non lagga)
6. **Apply completeness**: dopo import grande → query DB: count Products == 5.000, count PriceHistory == 50.000
7. **ImportAnalysisView troncamento prodotti**: import con 5.000+ nuovi prodotti → banner "Mostrando i primi 500 di N", scrolling fluido
8. **ImportAnalysisView troncamento errori**: import con file che genera 500+ errori → banner "Mostrando i primi 200 di N errori", export completo disponibile
9. **ImportAnalysisView piccolo**: import file piccolo → nessun banner, lista completa come oggi
10. **Concurrency guard**: durante import in corso, verificare che pulsanti import siano disabilitati; tentare un secondo import (se possibile) → deve essere ignorato/bloccato
11. **Partial failure** (test tecnico controllato): per colpire il ramo "products salvati, errore in `applyPendingPriceHistoryImport`" servono dati che passano il parsing ma falliscono durante l'apply (es. barcode in PriceHistory che riferisce un prodotto non presente nel foglio Products, generando un mismatch nel lookup). Se non riproducibile con dati naturali, iniettare l'errore temporaneamente nel codice (es. `throw` forzato all'inizio di `applyPendingPriceHistoryImport`) per validare: (a) prodotti già salvati restano nel DB, (b) messaggio utente distingue successo parziale da errore PH, (c) log riporta count separati. Rimuovere l'iniezione dopo il test.
12. **Fogli opzionali mancanti** (regression check): importare un file multi-sheet con: (a) solo foglio Products (senza Suppliers, Categories, PriceHistory), (b) Products + Suppliers ma senza PriceHistory, (c) Products + PriceHistory vuoto (foglio presente ma 0 righe dati). Verificare che il parsing non crashi, l'analyze completi, l'apply salvi correttamente i prodotti senza errori spuri. Questo previene regressioni introdotte dal refactor del parsing in `Task {}`.

#### Profiling con Instruments
1. **Allocations** (Simulator + device reale):
   - Misurare memory peak durante parsing, analyze, apply
   - **Device reale**: target peak < 300 MB su dataset grande
   - **Simulator**: usare come confronto relativo before/after (peak assoluto non vincolante per RAM illimitata)
   - Confrontare prima/dopo le modifiche in entrambi gli ambienti
2. **Time Profiler** (Simulator + device reale):
   - Verificare che il main thread non è bloccato > 100ms durante parsing/analyze (dopo STEP 1)
   - Verificare che l'apply non blocca il main thread (già background — confermare)
3. **Logging tempi** (output console):
   - Raccogliere i log STEP 5 su dataset grande
   - Documentare: tempo parsing, tempo analyze, tempo apply products, tempo apply price history

#### Ambiente di test
- **Simulator**: iPhone 15 Pro, iOS 17+ — per test funzionali rapidi
- **Device reale** (se disponibile): per validare memory pressure reale (il Simulator ha RAM illimitata)
- Se device reale non disponibile: documentare come limitazione nota e usare Instruments su Simulator con focus su Allocations relative (delta, non assoluto)

### Nota tracking su TASK-006
Il planning originario prevedeva che TASK-011 sbloccasse TASK-006. Con l'override del 2026-03-23, il blocker pratico immediato e' stato estratto in TASK-022; TASK-011 resta sospeso e non e' il task operativo corrente per lo sblocco di TASK-006.

### Handoff → Execution
- **Prossima fase**: EXECUTION
- **Prossimo agente**: CODEX
- **Azione consigliata**: Implementare in ordine:
  1. **STEP 6** — Concurrency guard: estendere `isRunning` all'intero ciclo, settarlo prima del Task {}, verificare disable UI su tutti i trigger
  2. **STEP 1** — Offload parsing+analyze su Task {} con progress pre-apply, per ENTRAMBI i flow (multi-sheet e singolo-sheet)
  3. **STEP 3** — Rilascio anticipato array PriceHistory (scoping del `[[String]]`)
  4. **STEP 2** — Autoreleasepool nei batch apply (NON implementare context.reset() salvo evidenza da profiling)
  5. **STEP 7** — Partial failure handling: do/catch separato per PH, messaggio esplicito
  6. **STEP 4** — Troncamento ImportAnalysisView: soglia 500 prodotti, 200 errori, banner, export errori completo
  7. **STEP 5** — Logging tempi per profiling
  L'apply in background, il batched save e il progress apply sono già implementati e vanno preservati. Testare con dataset da 5.000 prodotti + 50.000 PriceHistory come verifica principale. Non modificare formato XLSX né logica import multi-sheet di TASK-006.

---

## Execution (Codex)

### Obiettivo compreso
Implementare `TASK-011` senza riaprire il planning: estendere la guardia di concorrenza all'intero ciclo import, spostare parsing/analyze off-main per entrambi i flow su copia temporanea app-owned, ridurre la pressione memoria in pre-apply/apply, gestire il partial failure dei PriceHistory, troncare solo la preview di `ImportAnalysisView` e aggiungere logging tempi strutturato, preservando apply background, batched save e progress apply gia` esistenti.

### File controllati
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-011-large-import-stability-and-progress.md`
- `iOSMerchandiseControl/DatabaseView.swift`
- `iOSMerchandiseControl/ImportAnalysisView.swift`
- `iOSMerchandiseControl/ExcelSessionViewModel.swift`
- `iOSMerchandiseControl/en.lproj/Localizable.strings`
- `iOSMerchandiseControl/es.lproj/Localizable.strings`
- `iOSMerchandiseControl/it.lproj/Localizable.strings`
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`

### Piano minimo
1. Riallineare tracking a `EXECUTION` e mantenere il perimetro limitato ai file gia` previsti dal planning.
2. Applicare in `DatabaseView.swift` i sette step approvati nell'ordine richiesto: concurrency guard, offload parsing/analyze, rilascio anticipato PriceHistory, autoreleasepool nei batch, partial failure handling, logging tempi.
3. Applicare in `ImportAnalysisView.swift` il troncamento solo visuale con banner e soglie approvate, senza toccare il dataset reale usato dall'apply.
4. Eseguire build/check locali minimi sensati, poi aggiornare sezione Execution, handoff a Review e tracking coerente con fine execution.

### Modifiche fatte
- `STEP 6` — estesa la guardia di concorrenza all'intero ciclo import: `importProgress.isRunning` viene attivato prima del `Task {}` nei due flow Excel, i trigger concorrenti vengono bloccati con guard esplicito, l'overlay resta visibile durante parsing/analyze/apply e viene nascosto durante la review dell'analisi mantenendo comunque la sessione import attiva fino a dismiss/apply.
- `STEP 1` — parsing e analyze dei flow `importProductsFromExcel` e `importFullDatabaseFromExcel` spostati off-main su `Task.detached`, usando una copia temporanea app-owned del file selezionato; il permesso security-scoped viene rilasciato subito dopo la copia, il cleanup del file temporaneo avviene al termine del task, e tutti gli aggiornamenti UI tornano sul `MainActor`.
- `STEP 1` — aggiunto cleanup obbligatorio dei fallimenti pre-apply: in caso di errore durante copy/parsing/analyze vengono resettati stato running/overlay, riabilitata la UI, svuotato il contesto pending e pubblicato `importError`.
- `STEP 3` — ridotto il lifetime del `[[String]]` sorgente di `PriceHistory`: il parsing ora usa uno scope locale che lascia uscire il foglio raw dalla memoria appena costruito l'array `PendingPriceHistoryImportEntry`.
- `STEP 2` — inserito `autoreleasepool` nei loop di apply prodotti e storico prezzi, mantenendo intatti apply in background, batched save ogni 250 item, progress apply e senza introdurre `context.reset()`.
- `STEP 7` — introdotto risultato strutturato `ImportApplyResult` e partial failure handling separato per `PriceHistory`: i prodotti restano persistiti, il ramo PH restituisce count realmente salvati, messaggio utente e log derivano dal risultato strutturato e distinguono successo completo da successo parziale.
- `STEP 4` — `ImportAnalysisView` ora tronca solo la preview visiva con `prefix`/slice computati (500 per prodotti e warning, 200 per errori) e mostra banner espliciti; il dataset reale `analysis` non viene mutato e l'apply continua a lavorare sull'intero contenuto.
- `STEP 5` — aggiunti log strutturati `[TASK-011]` per parsing, analyze, apply prodotti, apply price history e risultato finale, piu` le stringhe UI minime necessarie per progress pre-apply, successo completo/parziale e banner di preview.

### Check eseguiti
Per ogni check: ✅ ESEGUITO | ⚠️ NON ESEGUIBILE (motivo) | ❌ NON ESEGUITO (motivo)
- [x] Build compila: ✅ ESEGUITO — `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build` completata con `** BUILD SUCCEEDED **` in data 2026-03-23.
- [x] Nessun warning nuovo: ✅ ESEGUITO — controllo su `xcodebuild ... build | rg "warning:"` mostra solo il warning toolchain `Metadata extraction skipped. No AppIntents.framework dependency found.`; nessun warning Swift/Xcode emesso dai file toccati.
- [x] Modifiche coerenti con planning: ✅ ESEGUITO — verifica statica del diff contro l'ordine approvato `STEP 6 -> STEP 1 -> STEP 3 -> STEP 2 -> STEP 7 -> STEP 4 -> STEP 5`, preservando apply background, batched save e progress apply gia` esistenti.
- [ ] Criteri di accettazione verificati: ⚠️ NON ESEGUIBILE COMPLETAMENTE — verificati via build/static review i CA coperti dal codice (guardia concorrenza, cleanup errori pre-apply, troncamento visuale, messaggistica partial failure), ma non sono stati eseguiti test manuali/simulator con dataset grandi ne` profiling Instruments per CA-1, CA-3, CA-4, CA-5, CA-6 e CA-9.

### Rischi rimasti
- Validazione end-to-end con dataset grande (5.000 Products + 50.000 PriceHistory) non eseguita in questo ambiente: restano da confermare empiricamente memory peak, fluidita` UI e tempi reali di parsing/apply.
- Il ramo di partial failure `products ok / price history fail` e` coperto staticamente e con messaggio strutturato, ma non e` stato forzato con un test controllato nel runtime attuale.
- La guardia di concorrenza e il progress pre-apply compilano e risultano coerenti staticamente, ma richiedono una verifica manuale in Simulator/device per confermare UX e disable dei trigger durante tutto il ciclo.

### Handoff → Review
- **Prossima fase**: REVIEW
- **Prossimo agente**: CLAUDE
- **Azione consigliata**: Verificare in review che il nuovo ciclo import mantenga coerenti `isRunning`, overlay e dismiss dell'analisi, che la temp copy security-scoped venga sempre pulita, che `ImportApplyResult` copra correttamente il successo parziale di `PriceHistory`, e poi validare manualmente/profilare i CA rimasti aperti (dataset grande, warning check reale, UX progress/concurrency guard).

---

## Review (Claude)

### Problemi critici
[Da compilare]

### Problemi medi
[Da compilare]

### Miglioramenti opzionali
[Da compilare]

### Fix richiesti
[Da compilare]

### Esito
[Da compilare]

### Handoff → Fix (se CHANGES_REQUIRED)
- **Prossima fase**: FIX
- **Prossimo agente**: CODEX
- **Azione consigliata**: [Da compilare]

---

## Fix (Codex)

### Fix applicati
- Corretto il lifecycle critico della sheet/apply: `applyConfirmedImportAnalysis()` ora attende davvero la fine dell'apply reale invece di lanciare un `Task {}` fire-and-forget. La sheet viene chiusa solo dopo completamento riuscito, `handleImportAnalysisDismissed()` non azzera piu` lo stato durante l'apply e la guardia di concorrenza resta valida per tutta la fase di persistenza.
- Lasciato `pendingFullImportContext` vivo durante l'apply e svuotato solo su dismiss o successo finale, evitando che un errore in apply lasci la sheet aperta ma senza contesto PriceHistory per un eventuale retry.
- Disabilitati esplicitamente i trigger toolbar di import/export/add quando `importProgress.isRunning` e` vero, chiudendo il gap UI residuo di CA-10 lato toolbar.
- Resa esplicita la gestione delle righe `PriceHistory` con barcode non risolto: non vengono trattate come errore di apply, ma come righe saltate esplicitamente; il risultato strutturato ora traccia `priceHistorySkipped`, i log includono inserted/skipped e il messaggio utente dichiara quante righe non abbinate sono state escluse.
- Riallineato `STEP 7` sul messaggio utente: `userMessage(for:)` ora distingue esplicitamente tra successo parziale storico prezzi (`priceHistoryError != nil && priceHistoryInserted > 0`) ed errore totale storico prezzi (`priceHistoryError != nil && priceHistoryInserted == 0`) con una stringa localizzata dedicata al secondo caso, lasciando invariata la struttura di `ImportApplyResult`.
- Separata la pipeline non-UI off-main da `DatabaseView` in helper top-level dedicati: `DatabaseImportPipeline` ora gestisce parsing/analyze/apply in background, mentre `DatabaseImportUILocalizer` concentra la localizzazione e la materializzazione UI sul `MainActor`.
- Reso esplicito il perimetro actor-isolation dei helper puri introdotti dal task: i tipi/data snapshot e il service off-main in `DatabaseView.swift`, `ExcelAnalyzer` e gli helper puri usati dal parser/import (`normalizedExcelNumberString`, `toDouble`, `matches`, `count(where:)`, `computeChangedFields`) sono stati marcati `nonisolated`, eliminando i warning actor-isolation emersi dopo l'offload su background.
- Ottimizzato l'hotspot di parsing timestamp nel flow `PriceHistory`: `DatabaseImportPipeline.parseFullDatabaseTimestamp(_:)` usa ora un `DateFormatter` statico condiviso e riutilizzato, mantenendo invariati formato (`yyyy-MM-dd HH:mm:ss`), locale `en_US_POSIX` e timezone UTC. Pass rapido confermato: non ci sono altri `DateFormatter` ricreati dentro i loop dell'import `PriceHistory`; l'unico formatter aggiuntivo rimasto in `DatabaseView.swift` e` nell'export full database ed e` fuori dal path di import.

### Check post-fix
Per ogni check: ✅ ESEGUITO | ⚠️ NON ESEGUIBILE (motivo) | ❌ NON ESEGUITO (motivo)
- [x] Build compila: ✅ ESEGUITO — `xcodebuild clean build -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator'` completata con `** BUILD SUCCEEDED **` in data 2026-03-23 dopo il micro-fix sul formatter timestamp.
- [x] Nessun warning nuovo introdotto: ✅ ESEGUITO — sul clean build del micro-fix non risultano warning Swift/actor-isolation (`rg "actor-isolated|nonisolated context|outside of actor|Main actor-isolated" /tmp/task011_timestamp_fix_clean_build.log` senza match). Resta solo il warning noto e preesistente di `appintentsmetadataprocessor` su `AppIntents.framework`, non introdotto da TASK-011.
- [x] Fix coerenti con review: ✅ ESEGUITO — chiusi il bug critico sul dismiss/apply lifecycle e i due punti medi richiesti (disable toolbar esplicito, rappresentazione righe PriceHistory saltate) senza riaprire il planning e senza refactor fuori scope.
- [x] Fix coerenti con review: ✅ ESEGUITO — aggiunto anche il branch esplicito per il caso `priceHistoryInserted == 0`, con localizzazione distinta di errore totale storico prezzi come richiesto dall'ultima review.
- [x] Fix coerenti con review: ✅ ESEGUITO — il disallineamento actor-isolation introdotto dall'offload e` stato chiuso senza cambiare la logica funzionale di TASK-011: pipeline off-main separata, localizzazione rimasta sul `MainActor`, parser/helper puri marcati `nonisolated`.
- [ ] Criteri di accettazione ancora soddisfatti: ⚠️ NON ESEGUIBILE COMPLETAMENTE — confermati via build e review statica i fix richiesti; restano non eseguiti nel runtime attuale i test manuali/profiling su dataset grande gia` pendenti per i CA finali.

### Handoff → Review finale
- **Prossima fase**: REVIEW
- **Prossimo agente**: CLAUDE
- **Azione consigliata**: Verificare che `DatabaseImportPipeline` mantenga invariata la logica di TASK-011 spostando fuori da `DatabaseView` solo la pipeline non-UI, che `DatabaseImportUILocalizer` concentri davvero tutta la localizzazione sul `MainActor`, che il clean build resti senza warning actor-isolation, e che `userMessage(for:)` distingua correttamente tra successo parziale PriceHistory ed errore totale storico prezzi quando `priceHistoryInserted == 0`.

---

## Chiusura

### Conferma utente
- [ ] Utente ha confermato il completamento

### Follow-up candidate
- Streaming parser XLSX per ridurre ulteriormente il footprint di memoria durante il parsing (richiede refactor significativo di ExcelAnalyzer, fuori scope di questo task)
- Cancellazione dell'import in corso da parte dell'utente (pulsante "Annulla" durante il progress) — fuori scope, feature separata
- Deduplicazione logica import tra ProductImportViewModel e DatabaseView — già segnalata in TASK-006 come follow-up preesistente

### Riepilogo finale
[Da compilare]

### Data completamento
[Da compilare]
