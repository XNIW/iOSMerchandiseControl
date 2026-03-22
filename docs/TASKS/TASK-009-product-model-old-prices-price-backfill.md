# TASK-009: Product model old prices + price backfill

## Informazioni generali
- **Task ID**: TASK-009
- **Titolo**: Product model old prices + price backfill
- **File task**: `docs/TASKS/TASK-009-product-model-old-prices-price-backfill.md`
- **Stato**: BLOCKED
- **Fase attuale**: — (sospeso dopo REVIEW)
- **Responsabile attuale**: — (in attesa di test manuali da parte dell'utente)
- **Data creazione**: 2026-03-22
- **Ultimo aggiornamento**: 2026-03-22
- **Ultimo agente che ha operato**: CLAUDE

## Dipendenze
- **Dipende da**: nessuno
- **Sblocca**: nessuno

## Scopo
Completare la parity "old prices + price backfill" su iOS: garantire che tutti i prodotti nel database abbiano almeno un record ProductPrice iniziale per ogni prezzo non-nil, e che il commento "per ora" in `fetchOldPricesByBarcode()` venga risolto con una decisione architetturale definitiva.

## Contesto
Il gap audit TASK-001 ha identificato che iOS manca di un meccanismo di backfill per lo storico prezzi. Il sistema ProductPrice esiste già ed è funzionante per i prodotti importati/modificati dopo la sua introduzione. Tuttavia, i prodotti pre-esistenti non hanno record ProductPrice, rendendo ProductPriceHistoryView vuota per loro e impedendo qualsiasi confronto basato sullo storico.

Il titolo originale "Product model old prices" è fuorviante: NON serve aggiungere campi `old*` al model `Product` (sarebbe regressivo rispetto all'architettura SwiftData corrente). Il vero gap è il backfill dei dati legacy.

## Non incluso
- Modifica del model `Product` (nessun campo old* aggiunto)
- Modifica della logica `fetchOldPricesByBarcode()` (l'approccio attuale è corretto per il suo use case — vedi Decisione #1)
- Modifica di InventorySyncService, GeneratedView, PreGenerateView
- Nuove dipendenze esterne
- Refactor dei flussi di import/export esistenti
- Modifica del formato di export del foglio PriceHistory
- Deduplicazione o correzione di storico prezzi già esistente (vedi "Out of scope dati incoerenti")

## Out of scope dati incoerenti
Il backfill colma **solo assenze minime legacy** (prodotti con prezzo ma senza alcun record ProductPrice del tipo corrispondente). In particolare, il backfill NON:
- Corregge mismatch tra `Product.purchasePrice` e l'ultimo `ProductPrice.price` di tipo `.purchase` (o `.retail`): se esiste già almeno un record ProductPrice del tipo richiesto, il prodotto viene saltato anche se il valore non corrisponde al prezzo corrente
- Deduplica storico già sporco (record ProductPrice duplicati, sovrapposti o incoerenti)
- Riordina timeline storiche esistenti (record con `effectiveAt` non cronologico)
- Corregge record con `source` mancante o errata
- Gestisce prodotti con prezzi a zero (trattati come prezzi validi se non-nil)
Eventuali problemi di coerenza nei dati preesistenti sono materia per un task dedicato di data-quality, non per questo backfill.

## File potenzialmente coinvolti
- **Nuovo file**: `iOSMerchandiseControl/PriceHistoryBackfillService.swift` — logica di backfill isolata
- `iOSMerchandiseControl/ContentView.swift` — hook del backfill (`.task {}` con `@Environment(\.modelContext)`)
- `iOSMerchandiseControl/ExcelSessionViewModel.swift` — solo aggiornamento commento (riga 490)
- `iOSMerchandiseControl/ProductPriceHistoryView.swift` — micro-rifinitura: helper per label source leggibili

## Criteri di accettazione
- [ ] CA-1: Ogni `Product` con `purchasePrice != nil` che non ha almeno un `ProductPrice` di tipo `.purchase` riceve un record di backfill con source `"BACKFILL"` ed `effectiveAt` uguale a una data fissa di bootstrap (non `Date()` corrente, per non inquinare la timeline)
- [ ] CA-2: Ogni `Product` con `retailPrice != nil` che non ha almeno un `ProductPrice` di tipo `.retail` riceve un record di backfill con source `"BACKFILL"` ed `effectiveAt` uguale alla stessa data fissa
- [ ] CA-3: Il backfill è **idempotente**: eseguirlo più volte non crea record duplicati
- [ ] CA-4: Il backfill non modifica record `ProductPrice` già esistenti
- [ ] CA-5: Il backfill non modifica i campi di `Product` (purchasePrice, retailPrice, ecc.)
- [ ] CA-6: Il backfill si esegue automaticamente al bootstrap dell'app tramite `.task {}` su ContentView. Il trigger può rieseguirsi se ContentView viene ricreata, ma essendo il backfill idempotente (CA-3), riesecuzioni successive non hanno effetti collaterali. Non è richiesto alcun guard in-memory aggiuntivo.
- [ ] CA-7: Dopo il backfill, `ProductPriceHistoryView` mostra almeno un record per ogni prodotto che ha un prezzo non-nil
- [ ] CA-8: I flussi esistenti (import prodotti, import/export DB completo, inventory sync, edit manuale) continuano a funzionare senza regressioni
- [ ] CA-9: Il commento "Per ora" a riga 490 di `ExcelSessionViewModel.swift` viene aggiornato per riflettere la decisione architetturale definitiva (Decisione #1)
- [ ] CA-10: Il progetto compila senza errori e senza warning nuovi
- [ ] CA-11: L'export completo del database (foglio PriceHistory) include correttamente i record `BACKFILL` con colonne `productBarcode`, `timestamp`, `type`, `oldPrice`, `newPrice`, `source` coerenti
- [ ] CA-12: I record BACKFILL vengono esportati nel foglio PriceHistory e trattati dal flusso `applyPendingPriceHistoryImport` esattamente come tutti gli altri record storici — nessun comportamento speciale, nessuna regressione introdotta da questo task. Il comportamento pre-esistente di `applyPendingPriceHistoryImport` (insert diretto senza deduplicazione per qualsiasi record storico) è fuori scope di questo task e rimane invariato.
- [ ] CA-13: In `ProductPriceHistoryView`, tutti i valori `source` (incluso `"BACKFILL"`) vengono mostrati come label italiane leggibili tramite un helper di mappatura (micro-rifinitura, vedi Decisione #5)

## Decisioni
| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|-------|
| 1 | `fetchOldPricesByBarcode()` continua a usare `Product.purchasePrice/retailPrice` (non lo storico) | Usare l'ultimo ProductPrice come "old price" | Per il contesto di pre-generazione inventario, il "vecchio prezzo" è per definizione il prezzo corrente del DB al momento della creazione della sessione. `Product.purchasePrice` È quel valore. Usare lo storico sarebbe equivalente (dopo backfill) ma meno efficiente (fetch + sort vs. campo diretto). Nessun vantaggio funzionale. | attiva |
| 2 | NON aggiungere campi `oldPurchasePrice`/`oldRetailPrice` persistiti al model `Product` | Aggiungere campi old* al model | L'architettura iOS è Product (corrente) + ProductPrice (storico). Duplicare i prezzi vecchi nel model sarebbe ridondante, creerebbe ambiguità sulla fonte di verità, e richiederebbe migrazione SwiftData. Il design attuale è superiore. | attiva |
| 3 | Data `effectiveAt` del backfill = data fissa convenzionale (`2000-01-01T00:00:00Z`) | Usare `Date()` corrente | Se il backfill usasse la data corrente, i record apparirebbero come "prezzo cambiato oggi" nello storico, inquinando la timeline. Una data fissa nel passato remoto segnala chiaramente che è un dato di bootstrap, non un evento reale. | attiva |
| 4 | Backfill in un file/service dedicato | Inline nell'app file o in Models.swift | Un service isolato è testabile, non inquina l'app entry point, e rispetta single responsibility. Il file è piccolo (~50-70 righe). | attiva |
| 5 | Micro-rifinitura source labels in `ProductPriceHistoryView`: helper `displaySource(_:)` che mappa TUTTI i source a label italiane leggibili (non solo BACKFILL) | (a) Lasciare i raw string tecnici; (b) Mappare solo BACKFILL | (a) sarebbe incoerente con l'obiettivo di rendere i record BACKFILL comprensibili all'utente; (b) sarebbe inconsistente — se si introduce una mappatura, è più pulito e coerente mapparli tutti. L'effort è ~7 righe, nessun rischio, puramente cosmetico. | attiva |
| 6 | Hook del backfill in `ContentView` con `.task {}` + `@Environment(\.modelContext)`, NON in `iOSMerchandiseControlApp` | (a) `.task {}` nell'App struct; (b) `.onAppear` con flag; (c) Background context separato | (a) L'App struct è sopra il punto di injection di `.modelContainer()` → `@Environment(\.modelContext)` non è disponibile lì; (b) `.onAppear` è sincrono e non offre cancellation automatica; (c) Un background context aggiunge complessità di threading non necessaria per dataset di dimensioni tipiche (<10K prodotti). `.task {}` in ContentView è il punto più basso dove il modelContext è già iniettato, offre cancellation automatica, gira sul MainActor (corretto per SwiftData mainContext), e non richiede wrapper aggiuntivi. | attiva |
| 7 | **User override — sospensione task dopo REVIEW APPROVED** (2026-03-22): task bloccato prima della conferma finale. Review codice APPROVED, validazione manuale rimandata. | Confermare DONE immediatamente | Test manuali VM-1..VM-9 richiedono validazione su device/Simulator; l'utente ha deciso di rimandare. Il task è tecnicamente completo ma non formalmente DONE fino alla validazione runtime. | attiva |

---

## Planning (Claude)

### Analisi

**Stato corrente dell'architettura prezzi iOS:**

Il sistema di tracking prezzi su iOS è già ben strutturato:
- `Product` (Models.swift:44-82): contiene `purchasePrice: Double?` e `retailPrice: Double?` come prezzi correnti, più una relazione `priceHistory: [ProductPrice]`
- `ProductPrice` (Models.swift:87-115): record storico con `type` (purchase/retail), `price`, `effectiveAt`, `source`, `note`
- I record ProductPrice vengono creati nei seguenti punti:
  - **ProductImportViewModel** (linee 275-281, 337-343): su creazione prodotto (oldPrice=nil) e su aggiornamento (se prezzo cambiato)
  - **DatabaseView** (linee 1699-1734): stessa logica per import da Database tab
  - **DatabaseView** (linee 1606-1661): import esplicito da foglio PriceHistory
  - **InventorySyncService** (linee 156-168): solo retail price durante sync inventario
  - **EditProductView** (linee 185-215): su modifica manuale prodotto, source `"EDIT_PRODUCT"`

**Verifica tracking (2026-03-22 — confermata su file reale)**: `docs/MASTER-PLAN.md` letto direttamente in repo (linee 7-58). Stato globale: `ACTIVE — TASK-009 in lavorazione`. Sezione Task attivo: ID TASK-009, stato ACTIVE, fase PLANNING, responsabile CLAUDE, ultimo aggiornamento 2026-03-22. Nessuna incoerenza tra MASTER-PLAN e file task. Il tracking è formalmente allineato e pronto per handoff.

**Gap identificato:**
1. **Nessun backfill per prodotti legacy**: prodotti che esistevano nel database prima dell'introduzione del sistema ProductPrice (o importati tramite percorsi che non creavano history) hanno `priceHistory` vuoto. ProductPriceHistoryView mostra una lista vuota per questi prodotti.
2. **Commento "per ora" in `fetchOldPricesByBarcode()`**: il commento a linea 490 suggerisce un'intenzione futura di cambiare approccio, ma l'approccio attuale è de facto corretto (vedi Decisione #1). Il commento va aggiornato per riflettere la decisione finale.
3. **Source labels non leggibili in ProductPriceHistoryView**: tutti i valori `source` (IMPORT_EXCEL, INVENTORY_SYNC, EDIT_PRODUCT, IMPORT_DB_FULL, e il nuovo BACKFILL) vengono mostrati come stringhe tecniche raw. Serve un helper di mappatura a label italiane.

**Cosa NON è un gap:**
- `fetchOldPricesByBarcode()` che usa `Product.purchasePrice/retailPrice` è **corretto** per il suo use case. Il "vecchio prezzo" nel contesto di pre-generazione inventario = prezzo corrente del DB al momento della sessione, che è esattamente `Product.purchasePrice`.
- Il model `Product` non necessita di campi aggiuntivi.

### 1. Bootstrap — punto di aggancio del backfill (Decisione #6)

**Dove**: `.task {}` modifier in `ContentView.swift`, sul `TabView`.

**Perché `ContentView` e non `iOSMerchandiseControlApp`**:
- `iOSMerchandiseControlApp.swift` (linee 1-18) dichiara `.modelContainer(for:)` sulla `WindowGroup`. Il `@Environment(\.modelContext)` è disponibile solo **sotto** quel punto nella gerarchia SwiftUI — quindi non nell'App struct stessa.
- `ContentView` (linee 4-73) è il primo view sotto la WindowGroup, ha già accesso a `@Environment(\.modelContext)`, e non richiede wrapper aggiuntivi.

**Perché `.task {}` e non `.onAppear`**:
- `.task {}` è asincrono, offre cancellation automatica se la view viene distrutta, e gira sul MainActor per default (corretto per SwiftData mainContext).
- `.onAppear` è sincrono — per lanciare lavoro asincrono servirebbe un `Task {}` esplicito senza cancellation automatica.

**Implementazione concreta**:
```swift
// In ContentView.swift, aggiungere:
@Environment(\.modelContext) private var modelContext

// Sul TabView, aggiungere modifier:
.task {
    do {
        let inserted = try PriceHistoryBackfillService.backfillIfNeeded(context: modelContext)
        if inserted > 0 {
            debugPrint("[Backfill] Inseriti \(inserted) record ProductPrice legacy.")
        }
    } catch {
        debugPrint("[Backfill] Errore durante il backfill prezzi: \(error)")
    }
}
```

**Semantica "una sola volta per sessione" e idempotenza (chiarimento CA-6)**:
`.task {}` su ContentView gira al primo `onAppear` della view e viene cancellato se la view sparisce. In condizioni normali, ContentView è la root view e persiste per tutta la sessione — il trigger si esegue una volta sola. In edge case (ricostruzione della view), potrebbe rieseguirsi.

Non viene aggiunto nessun guard in-memory (`@State private var backfillRan = false` o simili) per questo motivo: l'idempotenza del backfill (CA-3) è il meccanismo di protezione primario. Se il backfill viene chiamato di nuovo dopo che ha già girato, la funzione trova che tutti i prodotti hanno già almeno un record ProductPrice per ogni tipo, non inserisce nulla, e ritorna senza side effects. Il guard in-memory sarebbe difesa-in-profondità ma aggiunge complessità senza portare un vantaggio concreto in un'app single-window iOS standard.

**Nessun wrapper/coordinator necessario**: il layout attuale è già adeguato. ContentView è la root view e non richiede modifiche strutturali.

### 2. ModelContext e concurrency (Decisione #6, dettaglio tecnico)

| Aspetto | Scelta | Motivazione |
|---------|--------|-------------|
| **ModelContext** | `@Environment(\.modelContext)` di ContentView = il **mainContext** creato da `.modelContainer()` | È il context standard per operazioni dati in SwiftUI. Non serve crearne uno dedicato. |
| **Actor/thread** | **MainActor** | `.task {}` in un `@MainActor` view (ContentView) gira sul MainActor. Il mainContext di SwiftData è MainActor-bound. Nessuna violazione di concurrency. |
| **Context dedicato?** | NO | Un `ModelContext(container)` separato servirebbe solo per parallelismo pesante. Per dataset tipici (<10K prodotti), il backfill completa in millisecondi sul MainActor. Il costo di complessità threading non è giustificato. |
| **Violazioni SwiftData** | Nessuna | Il backfill usa un singolo context, sullo stesso actor che lo ha creato, con una singola `context.save()` alla fine. Nessun accesso cross-actor. |
| **Se il dataset è molto grande** | Il rischio è un micro-freeze UI (documentato nei rischi). Mitigazione: il backfill fa 2 fetch bulk + insert batch + 1 save. Non ci sono N+1 queries. Per >10K prodotti, eventuale follow-up per background context. |

### 3. Approccio proposto

**Passo 1: Creare `PriceHistoryBackfillService.swift`** — service minimale con una singola funzione statica. Signature definitiva:

```swift
enum PriceHistoryBackfillService {
    static let backfillSource = "BACKFILL"
    static let backfillDate   = Date(timeIntervalSince1970: 946_684_800) // 2000-01-01 00:00 UTC

    @discardableResult
    static func backfillIfNeeded(context: ModelContext) throws -> Int {
        // restituisce il numero di record ProductPrice inseriti
    }
}
```

**Algoritmo bulk — nessun N+1 per costruzione**:

L'accesso lazy a `product.priceHistory` su ogni prodotto nel loop sarebbe un potenziale N+1. L'algoritmo deve essere esplicitamente bulk, con fetch filtrato ai soli candidati per ridurre il lavoro inutile:

1. **Fetch bulk #1 — solo `Product` candidati** (con almeno un prezzo non-nil):
   ```swift
   var descriptor = FetchDescriptor<Product>(
       predicate: #Predicate { $0.purchasePrice != nil || $0.retailPrice != nil }
   )
   let allProducts = try context.fetch(descriptor)
   ```
   Prodotti senza prezzi sono irrilevanti per il backfill: escluderli riduce la fetch e il loop successivo.

2. **Costruisci `Set` dei barcode candidati** — usato per filtrare lo storico nel passo successivo:
   ```swift
   let candidateBarcodes = Set(allProducts.map(\.barcode))
   ```

3. **Fetch bulk #2** — tutti i `ProductPrice`: `context.fetch(FetchDescriptor<ProductPrice>())`

4. **Join in memoria** — popola `coveredTypes` solo per i barcode presenti nel set candidati:
   ```swift
   var coveredTypes: [String: Set<PriceType>] = [:]
   for pp in allPrices {
       guard let barcode = pp.product?.barcode,
             candidateBarcodes.contains(barcode) else { continue }
       coveredTypes[barcode, default: []].insert(pp.type)
   }
   ```
   I record storici di prodotti senza prezzi (non candidati) vengono saltati nel loop, riducendo la dimensione del dizionario.

   **Chiave del join — `barcode` come identificatore stabile**: `barcode` è dichiarato `@Attribute(.unique)` in `Models.swift` (riga 45) ed è la business key primaria e immutabile del dominio — non viene mai modificato dopo la creazione del prodotto. Usarlo come chiave della mappa `coveredTypes` è quindi intenzionale, non un'assunzione implicita: è un invariant del schema SwiftData. L'alternativa (`PersistentIdentifier` via `pp.product?.persistentModelID`) sarebbe equivalente ma richiederebbe di chiavare `allProducts` per ID, aggiungendo verbosità senza vantaggi. La scelta del barcode è la più diretta e coerente con il dominio.

5. **Loop unico sui candidati** — già filtrati al Passo 1, nessun accesso lazy alla relazione:
   ```swift
   var insertedCount = 0
   for product in allProducts {
       let covered = coveredTypes[product.barcode] ?? []
       if let price = product.purchasePrice, !covered.contains(.purchase) {
           context.insert(ProductPrice(type: .purchase, price: price,
               effectiveAt: backfillDate, source: backfillSource, product: product))
           insertedCount += 1
       }
       if let price = product.retailPrice, !covered.contains(.retail) {
           context.insert(ProductPrice(type: .retail, price: price,
               effectiveAt: backfillDate, source: backfillSource, product: product))
           insertedCount += 1
       }
   }
   ```
6. **Un solo `context.save()`** se `insertedCount > 0`, altrimenti nessuna operazione.

Risultato: fetch #1 limitata ai soli candidati con prezzo, `coveredTypes` popolato solo per barcode rilevanti, zero accessi lazy alla relazione, insert batch, un save finale. N+1 eliminato per costruzione.

**Idempotenza**: garantita dal join in memoria. Se il backfill è già stato eseguito (o il prodotto ha storico da import/sync/edit), `covered` contiene il tipo → nessun insert. Eseguirlo N volte produce lo stesso risultato.

**Passo 2: Hook in `ContentView.swift`** con error handling esplicito — `do/catch` con logging leggero, nessun alert utente, nessuna nuova UI:
```swift
.task {
    do {
        let inserted = try PriceHistoryBackfillService.backfillIfNeeded(context: modelContext)
        if inserted > 0 {
            debugPrint("[Backfill] Inseriti \(inserted) record ProductPrice legacy.")
        }
    } catch {
        debugPrint("[Backfill] Errore durante il backfill prezzi: \(error)")
    }
}
```
`try?` non usato: gli errori vengono loggati con `debugPrint`. L'app non mostra alert e non modifica la UI in caso di errore.

**Passo 3: Aggiornare commento in `ExcelSessionViewModel.swift`** — riga 490: sostituire il commento "Per ora usiamo direttamente i campi del Product, non ancora lo storico ProductPrice" con commento definitivo che documenta la decisione architetturale (Decisione #1).

**Passo 4: Micro-rifinitura `ProductPriceHistoryView.swift`** — aggiungere una funzione privata `displaySource(_:)` che mappa i source tecnici a label italiane:

```swift
private func displaySource(_ source: String) -> String {
    switch source {
    case "BACKFILL":       return "Prezzo iniziale"
    case "IMPORT_EXCEL":   return "Import Excel"
    case "INVENTORY_SYNC": return "Sync inventario"
    case "EDIT_PRODUCT":   return "Modifica manuale"
    case "IMPORT_DB_FULL": return "Import database"
    default:               return source
    }
}
```

E usarla al posto del raw `source` a linea 58. Nessuna altra modifica strutturale alla view.

**Libertà opzionale Codex su BACKFILL**: se il solo testo "Prezzo iniziale" non risulta sufficientemente distinguibile visivamente dagli altri record nella lista, è ammessa una micro-rifinitura Apple-like molto discreta — ad esempio un badge/label secondaria in `.caption2` con colore `.secondary` o `.tertiary`, coerente con il font/colore già usati nella view. Il vincolo è: nessun cambio di layout generale, nessun nuovo componente custom, rimane nel perimetro della riga HStack esistente.

### File da modificare

| File | Modifica | Motivazione |
|------|----------|-------------|
| **Nuovo: `iOSMerchandiseControl/PriceHistoryBackfillService.swift`** | Creare `enum` con costanti statiche `backfillSource`/`backfillDate` e signature esatta: `@discardableResult static func backfillIfNeeded(context: ModelContext) throws -> Int` | Logica di backfill isolata, idempotente |
| `iOSMerchandiseControl/ContentView.swift` | Aggiungere `@Environment(\.modelContext)` + `.task { do/catch }` con logging leggero sul TabView (vedi Passo 2 dell'approccio per il codice esatto) | Hook bootstrap — primo punto con modelContext disponibile |
| `iOSMerchandiseControl/ExcelSessionViewModel.swift` | Aggiornare commento a riga 490 | Rimuovere il "per ora", documentare decisione definitiva |
| `iOSMerchandiseControl/ProductPriceHistoryView.swift` | Aggiungere `displaySource(_:)` (~7 righe) e usarla a linea 58 | Micro-rifinitura: source leggibili per tutti i record, incluso BACKFILL |

**File NON coinvolti** (e perché):
- `iOSMerchandiseControlApp.swift` — non toccato (il hook è in ContentView, vedi Decisione #6)
- `Models.swift` — nessuna modifica al model
- `ProductImportViewModel.swift` — non toccato
- `DatabaseView.swift` — non toccato (l'export PriceHistory gestisce già qualsiasi source, incluso BACKFILL, senza modifiche)
- `InventorySyncService.swift` — non toccato
- `GeneratedView.swift` — non toccato
- `PreGenerateView.swift` — non toccato
- `EditProductView.swift` — non toccato

### Rischi identificati

| Rischio | Impatto | Mitigazione |
|---------|---------|-------------|
| **Performance su grandi database**: 2 fetch bulk (tutti i Product + tutti i ProductPrice) + join in memoria + insert batch | MEDIO — il costo in memoria e tempo è proporzionale a `|Product| + |ProductPrice|`, non solo al numero di prodotti. Le 2 fetch bulk materializzano entrambi i set completi; il dizionario `coveredTypes` cresce con il totale dei record `ProductPrice`. Su dataset tipici (<5K prodotti, <20K record storici) il backfill completa in millisecondi e il freeze UI è impercettibile. Su dataset molto grandi (es. >20K ProductPrice totali, anche con pochi prodotti ma storico molto lungo) il join in memoria e il batch insert sul MainActor potrebbero causare un micro-freeze UI al primo avvio. | L'algoritmo fa esattamente 2 query al DB, zero accessi lazy alla relazione `priceHistory`, e un solo `context.save()` finale. Il join è O(\|Product\| + \|ProductPrice\|) — dominato dalla dimensione dello storico, non dal solo conteggio prodotti. Per dataset tipici il costo è trascurabile. Il rischio è documentato; se emergesse su dataset reali con storico molto lungo → follow-up con background context dedicato (fuori scope di questo task). |
| **Duplicazione record**: race condition se il backfill gira in contemporanea con un import | BASSO — teorico | Il check di idempotenza mitiga il rischio. Nel worst case: un record extra BACKFILL per un prodotto che stava ricevendo storico da import nello stesso istante. Non causa danni funzionali (il record extra ha source BACKFILL e data fissa 2000-01-01, facilmente distinguibile). |
| **effectiveAt ambigua**: la data 2000-01-01 potrebbe apparire incongrua nella timeline | BASSO | Il source "Prezzo iniziale" (via displaySource) e la data chiaramente fuori epoca rendono evidente che è un dato di bootstrap. |
| **Export/reimport PriceHistory con record BACKFILL** | BASSO — comportamento pre-esistente confermato | L'export (DatabaseView linee 786-819) itera tutti i ProductPrice senza filtro su source: i record BACKFILL vengono esportati correttamente con `source: "BACKFILL"`, `timestamp: 2000-01-01`, e `oldPrice` derivato da `previousPriceByGroup` (vuoto per il primo record del gruppo — questo è il comportamento corretto per il primo record in assoluto). **Sul reimport**: `applyPendingPriceHistoryImport` (DatabaseView linee 1628-1640) fa un insert diretto per ogni riga del foglio PriceHistory senza deduplicazione. Questo comportamento è pre-esistente e vale per TUTTI i record storici, non solo BACKFILL. Un reimport su un DB già popolato aggiunge sempre nuovi record storici sovrapposti — è una limitazione nota del flusso, fuori scope di questo task. CA-12 è formulato di conseguenza: nessuna regressione introdotta, nessun comportamento speciale necessario. |
| **Migrazione SwiftData** | NESSUNO | Il backfill NON modifica lo schema — aggiunge solo dati. Nessuna migration richiesta. |

### Verifica manuale

Casi minimi da verificare dopo l'execution:

| # | Scenario | Verifica attesa |
|---|----------|-----------------|
| VM-1 | **Prodotto legacy con entrambi i prezzi, nessuna history**: creare manualmente un Product con purchasePrice=10 e retailPrice=20, senza ProductPrice | Dopo avvio app: ProductPriceHistoryView mostra 1 record purchase (10, "Prezzo iniziale", 01/01/2000) e 1 record retail (20, "Prezzo iniziale", 01/01/2000) |
| VM-2 | **Prodotto legacy con un solo prezzo**: Product con purchasePrice=5, retailPrice=nil | Dopo avvio: 1 record purchase creato, tab Vendita vuoto |
| VM-3 | **Prodotto già con history completa**: Product con priceHistory non vuoto (almeno un .purchase e un .retail) | Dopo avvio: nessun record BACKFILL aggiunto, storico invariato |
| VM-4 | **Prodotto con history parziale**: Product con purchasePrice=10, retailPrice=20, e un solo ProductPrice di tipo .purchase | Dopo avvio: 1 record BACKFILL di tipo .retail aggiunto, storico .purchase invariato |
| VM-5 | **Idempotenza**: riavviare l'app dopo un primo avvio che ha eseguito il backfill | Nessun record duplicato creato. Conteggio ProductPrice identico prima e dopo il riavvio |
| VM-6 | **ProductPriceHistoryView post-backfill**: aprire lo storico di un prodotto legacy dopo il backfill | Source mostrato come "Prezzo iniziale" (non "BACKFILL"), data 01/01/2000, prezzo corretto |
| VM-7 | **Nessuna regressione import prodotti**: importare un file Excel con prodotti nuovi e aggiornamenti | ProductPrice creati normalmente con source "Import Excel", nessun conflitto con record BACKFILL |
| VM-8 | **Nessuna regressione edit manuale**: modificare il prezzo di un prodotto da DatabaseView | ProductPrice creato con source "Modifica manuale", nessun conflitto |
| VM-9 | **Export database**: esportare il database completo e aprire il foglio PriceHistory | I record BACKFILL appaiono con `source: "BACKFILL"`, `timestamp: 01/01/2000`, `oldPrice` vuoto (primo record del gruppo), `newPrice` = prezzo del prodotto. Nessuna colonna mancante o anomala. (Nota: il reimport su DB già popolato aggiunge nuovi record storici sovrapposti per tutti i tipi di record — questo è comportamento pre-esistente di `applyPendingPriceHistoryImport`, fuori scope di questo task.) |

### Execution guardrails (istruzioni rigide per Codex)

1. **NON cambiare lo schema di `Product`** — nessun campo aggiunto, rimosso, o rinominato in `Models.swift`
2. **NON toccare i flussi di import/export** — `ProductImportViewModel`, `DatabaseView` (import/export), `InventorySyncService` NON vanno modificati. Il backfill è un'operazione separata che non interagisce con questi flussi.
3. **NON fare refactor** — nessun rename, nessuna estrazione, nessuna riorganizzazione di codice esistente
4. **Massimo cambiamento minimo** — i file toccati sono esattamente 4 (1 nuovo + 3 modifiche minime). Nessun altro file va toccato. I magic values `"BACKFILL"` e `Date(timeIntervalSince1970: 946_684_800)` devono essere definiti come costanti statiche nel service (`backfillSource`, `backfillDate`), non ripetuti inline.
5. **Se tocchi UI, solo micro-rifinitura** — in `ProductPriceHistoryView.swift` sono ammesse: (a) aggiunta del helper `displaySource(_:)` e il suo uso al posto del raw source; (b) opzionalmente, se il solo testo "Prezzo iniziale" non basta a distinguere visivamente il record BACKFILL, un badge/label secondaria discreta in `.caption2` con colore `.secondary` o `.tertiary`, dentro l'HStack esistente, senza componenti custom. Nessun cambio di layout generale, font principale, spacing, o struttura della view oltre questi due punti.
6. **NON aggiungere dipendenze** — nessun nuovo package, import di framework aggiuntivi, o file di supporto
7. **NON creare test target** — il progetto non ha test target; le verifiche sono manuali
8. **In caso di dubbio, fermarsi** — se emerge un problema non previsto dal planning, documentarlo nell'handoff e tornare a review. Non improvvisare soluzioni fuori scope.

### Nota tracking — snapshot vs repo reale
Il MASTER-PLAN caricato in questa sessione di chat può riflettere uno snapshot precedente (TASK-009 TODO / progetto IDLE). Il file reale `docs/MASTER-PLAN.md` in repo è stato verificato direttamente (lettura linee 7-58): stato globale ACTIVE, TASK-009 task attivo, fase PLANNING, responsabile CLAUDE. Codex deve leggere il file dalla repo al momento dell'execution — non fidarsi di snapshot in chat.

### Handoff → Execution
- **Prossima fase**: EXECUTION
- **Prossimo agente**: CODEX
- **Azione consigliata**:
  1. Leggere `Models.swift` (linee 44-115) per confermare il model Product e ProductPrice
  2. Leggere `ContentView.swift` (linee 1-73) per confermare la struttura attuale
  3. Leggere `ProductPriceHistoryView.swift` (linee 1-101) per confermare la UI attuale
  4. Creare `PriceHistoryBackfillService.swift` come `enum` con le costanti statiche `backfillSource`/`backfillDate` e la signature esatta:
     ```swift
     @discardableResult
     static func backfillIfNeeded(context: ModelContext) throws -> Int
     ```
     Logica: 2 fetch bulk (`FetchDescriptor<Product>()` + `FetchDescriptor<ProductPrice>()`) + join in memoria su barcode (`[String: Set<PriceType>]`) + insert batch + un solo `context.save()` finale se `insertedCount > 0`. Dettaglio completo al Passo 1 dell'approccio.
  5. In `ContentView.swift`: aggiungere `@Environment(\.modelContext) private var modelContext` e il `.task { do/catch }` sul TabView — usare `do/catch` con `debugPrint` come descritto al Passo 2 dell'approccio (non `try?`)
  6. In `ExcelSessionViewModel.swift`: aggiornare il commento a riga 490 — sostituire "Per ora usiamo direttamente i campi del Product, non ancora lo storico ProductPrice" con commento definitivo
  7. In `ProductPriceHistoryView.swift`: aggiungere `displaySource(_:)` e usarlo a linea 58 al posto di `price.source`
  8. Verificare che il build compili senza errori e senza warning nuovi
  9. Rispettare rigorosamente gli **Execution guardrails** sopra

---

## Execution (Codex)
<!-- solo Codex aggiorna questa sezione -->

### Obiettivo compreso
- Eseguire TASK-009 end-to-end secondo il planning approvato, con user override esplicito che autorizza Codex a fare anche l'allineamento tracking intermedio da PLANNING a EXECUTION senza nuovo passaggio da Claude.

### File controllati
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-009-product-model-old-prices-price-backfill.md`
- `CLAUDE.md`
- `AGENTS.md`
- `iOSMerchandiseControl/Models.swift`
- `iOSMerchandiseControl/ContentView.swift`
- `iOSMerchandiseControl/ExcelSessionViewModel.swift`
- `iOSMerchandiseControl/ProductPriceHistoryView.swift`
- `iOSMerchandiseControl/DatabaseView.swift`
- `iOSMerchandiseControl/InventorySyncService.swift`
- `iOSMerchandiseControl/EditProductView.swift`
- `iOSMerchandiseControl/ProductImportViewModel.swift`
- `iOSMerchandiseControl/iOSMerchandiseControlApp.swift`
- `iOSMerchandiseControl.xcodeproj/project.pbxproj`

### Piano minimo
- Allineare tracking a `EXECUTION / CODEX` mantenendo intatte le sezioni di Claude.
- Creare `PriceHistoryBackfillService.swift` con algoritmo bulk idempotente e costanti centralizzate.
- Agganciare il bootstrap in `ContentView.swift` con `.task {}` e `do/catch`.
- Aggiornare il commento architetturale in `ExcelSessionViewModel.swift`.
- Rendere leggibili i source in `ProductPriceHistoryView.swift` senza cambiare il layout generale.
- Eseguire una build reale e aggiornare poi tracking a `REVIEW / CLAUDE` con handoff pulito.

### Modifiche fatte
- Creato `PriceHistoryBackfillService.swift` con costanti centralizzate `backfillSource`/`backfillDate`, fetch bulk dei `Product` candidati, fetch bulk di tutti i `ProductPrice`, join in memoria `[String: Set<PriceType>]`, insert batch e `context.save()` solo se `insertedCount > 0`.
- Aggiunto in `ContentView.swift` `@Environment(\.modelContext)` e bootstrap `.task {}` con `do/catch` e logging leggero via `debugPrint`, senza `try?` e senza guard in-memory aggiuntivi.
- Aggiornato il commento di `fetchOldPricesByBarcode()` in `ExcelSessionViewModel.swift` per riflettere la decisione architetturale definitiva: il "vecchio prezzo" per la pre-generazione resta il prezzo corrente del `Product`.
- Aggiunto in `ProductPriceHistoryView.swift` l'helper `displaySource(_:)` per mostrare label italiane leggibili per `BACKFILL`, `IMPORT_EXCEL`, `INVENTORY_SYNC`, `EDIT_PRODUCT` e `IMPORT_DB_FULL`, mantenendo invariato il layout generale.
- Allineato il tracking come richiesto: passaggio intermedio `PLANNING → EXECUTION` eseguito da Codex per user override esplicito, poi transizione finale `EXECUTION → REVIEW`.

### Check eseguiti
- ✅ ESEGUITO — STATIC — CA-1: `PriceHistoryBackfillService.backfillIfNeeded(context:)` inserisce un record `.purchase` solo per prodotti con `purchasePrice != nil` e senza copertura `.purchase`, con `source = "BACKFILL"` ed `effectiveAt = backfillDate`.
- ✅ ESEGUITO — STATIC — CA-2: la stessa logica inserisce un record `.retail` solo per prodotti con `retailPrice != nil` e senza copertura `.retail`, usando la stessa data fissa e lo stesso source.
- ✅ ESEGUITO — STATIC — CA-3: l'idempotenza è garantita dal set `coveredTypes`; riesecuzioni successive trovano il tipo già coperto e non inseriscono duplicati.
- ✅ ESEGUITO — STATIC — CA-4: il service non modifica alcun `ProductPrice` esistente; crea solo nuovi record quando manca il tipo richiesto.
- ✅ ESEGUITO — STATIC — CA-5: il service non scrive mai sui campi del model `Product`; usa solo `purchasePrice`, `retailPrice` e `barcode` in lettura.
- ✅ ESEGUITO — STATIC — CA-6: il backfill è agganciato automaticamente al bootstrap in `ContentView.swift` tramite `.task {}` con `@Environment(\.modelContext)` e senza guard in-memory aggiuntivi.
- ✅ ESEGUITO — STATIC — CA-7: `ProductPriceHistoryView` continua a leggere `product.priceHistory` e a mostrare le entry per tipo; con il backfill applicato i prodotti legacy con prezzo non-nil non restano più privi di record storici. Nessuna verifica manuale UI eseguita.
- ✅ ESEGUITO — STATIC/BUILD — CA-8: nessun flusso di import/export/sync/edit è stato modificato; i file esclusi dal planning sono rimasti intatti e la build del progetto è verde.
- ✅ ESEGUITO — STATIC — CA-9: il commento "Per ora" in `ExcelSessionViewModel.swift` è stato sostituito con il commento definitivo coerente con la Decisione #1.
- ✅ ESEGUITO — BUILD — CA-10: eseguito `set -o pipefail && xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'generic/platform=iOS Simulator' build | rg -n "warning:|error:|\\*\\* BUILD"` con esito `** BUILD SUCCEEDED **`.
- ✅ ESEGUITO — STATIC — CA-11: il foglio `PriceHistory` in `DatabaseView.makeFullDatabaseXLSX()` esporta tutti i `ProductPrice` senza filtro sul source; i record `BACKFILL` vengono quindi esportati con barcode, timestamp, type, newPrice e source coerenti.
- ✅ ESEGUITO — STATIC — CA-12: `DatabaseView.applyPendingPriceHistoryImport()` continua a importare i record storici senza branch speciali sul source, quindi `BACKFILL` segue il flusso generico già esistente senza regressioni introdotte da questo task.
- ✅ ESEGUITO — STATIC — CA-13: `ProductPriceHistoryView` usa `displaySource(_:)` al posto del raw source e mappa anche `BACKFILL` a una label italiana leggibile.
- ✅ ESEGUITO — STATIC — Modifiche coerenti con il planning: nessun cambio schema `Product`, nessun refactor, nessuna modifica a import/export oltre al comportamento già previsto dal service e alla UI minima concessa.
- ✅ ESEGUITO — STATIC — `git diff --check`: nessun errore di whitespace o patch malformata nel diff applicato.
- ✅ ESEGUITO — BUILD — Nessun warning nuovo introdotto verificabile: l'unico warning emesso dopo le modifiche è `Metadata extraction skipped. No AppIntents.framework dependency found.`, già osservato nel baseline build eseguito prima delle modifiche in questa sessione.
- ❌ NON ESEGUITO — MANUAL/SIM — VM-1..VM-9 e validazione UI nel Simulator non eseguite in questa fase.

### Rischi rimasti
- Le verifiche manuali su database reale non sono state eseguite: restano da validare a runtime i casi VM-1..VM-9, in particolare idempotenza su dati persistiti già esistenti, storico visibile per prodotti legacy ed export del foglio `PriceHistory`.
- L'algoritmo usa due fetch bulk e un join in memoria su tutto lo storico prezzi: per dataset molto grandi resta il rischio già documentato di micro-freeze al bootstrap sul MainActor.
- Nota tracking: `docs/TASKS/TASK-009-product-model-old-prices-price-backfill.md` risulta ancora file non tracciato nel worktree Git (`??`), quindi Claude dovrebbe tenerne conto nella review/documentazione finale.

### Handoff → Review
- **Prossima fase**: REVIEW
- **Prossimo agente**: CLAUDE
- **Azione consigliata**:
  1. Verificare il service `PriceHistoryBackfillService` contro CA-1..CA-6 e CA-11..CA-12, con attenzione al join bulk su barcode e all'idempotenza.
  2. Verificare `ContentView.swift`, `ExcelSessionViewModel.swift` e `ProductPriceHistoryView.swift` contro CA-7, CA-9 e CA-13, confermando che la UI sia stata rifinita senza alterare il layout generale.
  3. Considerare se richiedere o meno una validazione manuale dei casi VM-1..VM-9 prima di un eventuale APPROVED, dato che in questa execution è stata eseguita solo verifica STATIC/BUILD.
  4. Tenere conto del fatto che il file task risulta untracked nel worktree Git.

---

## Review (Claude)
<!-- solo Claude aggiorna questa sezione -->

**Reviewer**: Claude — 2026-03-22
**Metodo**: code review statica completa su tutti i file modificati + verifica diff + verifica tracking + verifica progetto Xcode.

### Verifica per criterio

| CA | Esito | Tipo verifica | Note |
|----|-------|---------------|------|
| CA-1 | ✅ PASS | STATIC | `PriceHistoryBackfillService.swift:34-46`: controlla `purchasePrice != nil` + `!covered.contains(.purchase)`, inserisce con `backfillSource` e `backfillDate`. Corretto. |
| CA-2 | ✅ PASS | STATIC | Stessa logica per `retailPrice`/`.retail` (righe 48-60). Corretto. |
| CA-3 | ✅ PASS | STATIC | Idempotente per costruzione: `coveredTypes` include qualunque ProductPrice esistente (compresi record da backfill precedenti). Riesecuzioni trovano il tipo già coperto → 0 insert. |
| CA-4 | ✅ PASS | STATIC | Nessuna mutazione di ProductPrice esistenti. Solo `context.insert()` per nuovi record. |
| CA-5 | ✅ PASS | STATIC | Nessuna scrittura su campi Product. Solo lettura di `purchasePrice`, `retailPrice`, `barcode`. |
| CA-6 | ✅ PASS | STATIC | `ContentView.swift:61-70`: `.task {}` con `do/catch`, nessun guard in-memory. Posizione corretta: modifier sul TabView, sotto `.preferredColorScheme()`, sopra `.onOpenURL`. |
| CA-7 | ⏳ PARZIALE | STATIC | Per code inspection, dopo backfill i prodotti legacy avranno almeno un ProductPrice → `ProductPriceHistoryView` li mostrerà. **Validazione runtime (VM-1, VM-6) ancora necessaria.** |
| CA-8 | ✅ PASS | STATIC/DIFF | Nessun file di import/export/sync/edit modificato. Confermato via `git status`: solo 4 file toccati (1 nuovo + 3 modifiche minime). |
| CA-9 | ✅ PASS | STATIC/DIFF | Commento "Per ora" sostituito con commento definitivo coerente con Decisione #1. Diff verificato: `"Usiamo intenzionalmente i campi correnti di Product: nella pre-generazione il "vecchio prezzo" è il prezzo presente nel DB al momento della sessione."` |
| CA-10 | ✅ PASS | BUILD | Codex ha riportato `** BUILD SUCCEEDED **`. Il nuovo file è auto-incluso tramite `PBXFileSystemSynchronizedRootGroup` (Xcode 16+), verificato nel pbxproj. |
| CA-11 | ✅ PASS | STATIC | Export PriceHistory in `DatabaseView.makeFullDatabaseXLSX()` itera tutti i ProductPrice senza filtro su source. I record BACKFILL fluiscono nello stesso percorso degli altri. |
| CA-12 | ✅ PASS | STATIC | `applyPendingPriceHistoryImport` invariato — nessun branch speciale su source BACKFILL. Comportamento pre-esistente (insert diretto senza deduplicazione) confermato fuori scope. |
| CA-13 | ✅ PASS | STATIC/DIFF | `displaySource(_:)` aggiunto (righe 88-103), usato a riga 58 al posto del raw source. Mappatura corretta per tutti e 5 i source noti + fallback al raw string. Layout invariato. |

### Problemi critici

Nessuno.

### Problemi medi

Nessuno.

### Miglioramenti opzionali

1. **Badge visivo per record BACKFILL non usato**: Codex ha scelto di non usare la libertà opzionale per un badge/label secondaria distinguibile sui record BACKFILL. Il solo testo "Prezzo iniziale" è sufficiente e la scelta è coerente con il planning (la libertà era esplicitamente opzionale). Se l'utente volesse un distinguo visivo più forte, è un follow-up candidate.

2. **Nota su `price.product?.barcode` nel loop coveredTypes**: il loop al Passo 4 accede alla relazione to-one `product` su ogni ProductPrice (anche non candidati) per ottenere il barcode e verificare `candidateBarcodes.contains()`. Questo è il design esatto prescritto dal planning. In pratica, per i Product candidati la fault è già risolta (materialized in fetch #1); per i non-candidati il fault è risolto e il risultato scartato. Su dataset tipici il costo è trascurabile. Se emergesse un problema performance su dataset con storico molto lungo, un'ottimizzazione sarebbe aggiungere un predicato anche su fetch #2 (`#Predicate { $0.product != nil }`) o pre-filtrare server-side — ma questo è fuori scope e non giustificato ora.

### Fix richiesti

Nessuno.

### Esito

**APPROVED**

L'implementazione è corretta, pulita, e aderente al planning approvato su tutti i punti:

- **Service** (`PriceHistoryBackfillService.swift`, 69 righe): signature esatta, costanti centralizzate, algoritmo bulk con fetch filtrato ai candidati, join in memoria su barcode (invariant `@Attribute(.unique)`), idempotenza per costruzione, un solo `context.save()` condizionale. Nessun accesso lazy a `priceHistory`.
- **Bootstrap** (`ContentView.swift`): `@Environment(\.modelContext)` + `.task { do/catch }` sul TabView, logging leggero con `debugPrint`, nessun `try?`, nessun guard in-memory. Concurrency corretta: `.task {}` nel body di una View = MainActor, coerente con mainContext SwiftData.
- **Commento** (`ExcelSessionViewModel.swift`): "Per ora" rimosso, decisione architetturale documentata.
- **UI** (`ProductPriceHistoryView.swift`): `displaySource(_:)` con 5 mappature + fallback, layout invariato, nessun componente custom.
- **Guardrails**: tutti rispettati — nessun cambio schema, nessun refactor, nessun file extra, nessuna dipendenza aggiunta.
- **Progetto Xcode**: usa `PBXFileSystemSynchronizedRootGroup` → il nuovo file è auto-incluso nel build senza registrazione esplicita in pbxproj. Build verde confermata.
- **Tracking**: MASTER-PLAN e file task allineati (ACTIVE / REVIEW / CLAUDE).

**Nota sulla validazione runtime**: i CA sono tutti verificati staticamente. Le verifiche manuali VM-1..VM-9 (elencate nel planning) restano a carico dell'utente come test di conferma runtime. La code review non ha identificato nessun motivo per cui i casi VM fallirebbero — la logica è lineare e priva di edge case non coperti. La conferma manuale è comunque raccomandata prima di dichiarare DONE, in particolare per VM-1 (backfill base), VM-5 (idempotenza) e VM-6 (label nella UI).

**Nota Git**: i file nuovi (`PriceHistoryBackfillService.swift`, task doc) sono untracked e tutti i file modificati sono unstaged. Questo è atteso — l'utente deve committare a propria discrezione.

### Handoff → Fix (se CHANGES_REQUIRED)

Non applicabile — esito APPROVED.

### Handoff → nuovo Planning (se REJECTED)

Non applicabile — esito APPROVED.

---

## Fix (Codex)
<!-- solo Codex aggiorna questa sezione -->

### Fix applicati

### Check post-fix

### Handoff → Review finale

---

## Nota blocco (2026-03-22 — user override)

**Stato**: BLOCKED per decisione utente.

**Distinzione chiara**:
- **Review codice**: APPROVED (emessa da Claude il 2026-03-22). Tutti i CA verificabili staticamente superati. Nessun problema critico o medio. Nessun fix richiesto.
- **Validazione manuale/runtime**: rimandata. I test VM-1..VM-9 descritti nel planning non sono ancora stati eseguiti. In particolare: VM-1 (backfill base su prodotto legacy), VM-5 (idempotenza), VM-6 (label nella UI post-backfill).

**Motivo sospensione**: decisione esplicita dell'utente di rimandare i test manuali. Nessun problema tecnico emerso che blocchi la chiusura — il task è tecnicamente pronto.

**Handoff alla ripresa**:
- Prossima azione: eseguire i test manuali VM-1..VM-9 elencati nella sezione Verifica manuale del planning.
- Dopo i test: tornare in REVIEW (o confermare DONE direttamente se i test passano tutti e non emergono regressioni).
- In caso di regressioni emerse dai test: aprire FIX con Codex prima di confermare DONE.
- In caso di errori runtime non previsti: rivalutare se la review codice APPROVED è sufficiente o se servono fix.

---

## Chiusura

### Conferma utente
- [ ] Utente ha confermato il completamento

### Follow-up candidate

### Riepilogo finale

### Data completamento
