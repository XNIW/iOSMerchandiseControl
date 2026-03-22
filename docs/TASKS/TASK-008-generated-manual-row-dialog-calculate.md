# TASK-008: Generated manual row dialog + calculate

## Informazioni generali
- **Task ID**: TASK-008
- **Titolo**: Generated manual row dialog + calculate
- **File task**: `docs/TASKS/TASK-008-generated-manual-row-dialog-calculate.md`
- **Stato**: BLOCKED
- **Fase attuale**: REVIEW
- **Responsabile attuale**: CLAUDE
- **Data creazione**: 2026-03-21
- **Ultimo aggiornamento**: 2026-03-21
- **Ultimo agente che ha operato**: CLAUDE

## Dipendenze
- **Dipende da**: nessuno
- **Sblocca**: nessuno

## Scopo
Implementare un dialog modale (sheet) per aggiunta e modifica manuale di righe nella schermata GeneratedView, con lookup prodotto da database, pre-fill campi, calcolo automatico del prezzo d'acquisto, validazione barcode e integrazione scanner. Allineare il comportamento iOS al ManualEntryDialog Android.

## Contesto
L'app iOS attualmente aggiunge righe manuali come righe vuote (funzione `addManualRow()`), costringendo l'utente a compilare i campi dopo. L'app Android ha un dialog completo (`ManualEntryDialog`) con campi pre-compilati, lookup DB, calcolo prezzi e validazione. Questo task porta la parità funzionale su iOS.

## Non incluso
- Refactoring di `RowDetailSheetView` esistente (resta com'è)
- Creazione inline di nuove categorie (follow-up)
- Change detection gate avanzata come Android (follow-up se necessario)
- Bottone "Aggiungi e Prossimo" per scan continuo (follow-up)
- Sticky "last used category" (follow-up)
- Modifiche al modello `Product` o `HistoryEntry`
- Modifiche ad altre schermate fuori da GeneratedView

## File potenzialmente coinvolti
- `iOSMerchandiseControl/GeneratedView.swift` — unico file da modificare
- `iOSMerchandiseControl/HistoryEntry.swift` — solo lettura (struttura dati)
- `iOSMerchandiseControl/ExcelSessionViewModel.swift` — solo lettura (header/colonne)
- `iOSMerchandiseControl/Models.swift` — solo lettura (modello Product)

## Criteri di accettazione
Questi criteri sono il contratto del task. Execution e review lavorano contro di essi.
Se cambiano in corso d'opera, aggiornare QUI prima di proseguire.
- [ ] CA-1: Quando l'utente preme "Aggiungi riga" in un inventario manuale, si apre un dialog (sheet) con i campi: barcode, nome prodotto, prezzo vendita, prezzo acquisto, quantità, categoria (Picker tra `ProductCategory` esistenti nel DB SwiftData)
- [ ] CA-2: Il dialog funziona in modalità ADD (campi vuoti, quantità default "1") e EDIT (campi pre-compilati dai valori attuali della riga secondo la tabella "Source of truth in EDIT")
- [ ] CA-3: Il campo barcode ha un'icona scanner; toccandola si apre `BarcodeScannerView`; il barcode scansionato popola il campo barcode del dialog
- [ ] CA-4: Quando un barcode valido è presente (digitato o scansionato), l'app cerca il `Product` nel DB tramite `product.barcode`; se trovato, mostra una card "Dati dal database" con `product.productName` e `product.retailPrice`; il bottone "Copia dati" sovrascrive nome prodotto, prezzo vendita e (se match trovato in DB) categoria nel dialog
- [ ] CA-5: Se il barcode digitato/scansionato è già presente in un'altra riga della griglia (esclusa la riga `data[editIndex]` in EDIT), viene mostrato un messaggio di errore rosso e il bottone Conferma è disabilitato; il barcode della riga in modifica non è mai considerato duplicato
- [ ] CA-6: Il prezzo d'acquisto viene calcolato come `round(prezzoVendita / 2)` solo se il campo è lasciato **vuoto/blank** al salvataggio; se l'utente ha esplicitamente inserito 0, il valore 0 viene rispettato
- [ ] CA-7: Validazione minima: barcode non vuoto + prezzo vendita > 0 + nessun errore barcode duplicato + quantità numericamente valida (o vuota) → bottone Conferma abilitato; quantità non numerica (lettere/simboli) blocca il Conferma con errore; quantità negativa non blocca (warning giallo)
- [ ] CA-8: In modalità ADD, Conferma: aggiunge eventuali colonne mancanti a `data[0]` con padding vuoto alle righe esistenti, appende la nuova riga a `data`, aggiunge `["<qty>", "<retailPrice>"]` a `editable`, aggiunge `false` a `complete`, chiama autosave
- [ ] CA-9: In modalità EDIT, Conferma: aggiunge eventuali colonne mancanti a `data[0]` con padding, sovrascrive `data[editIndex]`, aggiorna `editable[editIndex][0]` e `editable[editIndex][1]`, chiama autosave; `complete[editIndex]` non viene toccato
- [ ] CA-10: In modalità EDIT, il bottone "Elimina" (rosso) rimuove la riga da `data`, `editable`, `complete` all'indice `editIndex`, mantiene la coerenza degli array, poi chiama autosave
- [ ] CA-11: Annulla non modifica nulla: né `data`, né `editable`, né `complete`, né l'header; nessun autosave parte
- [ ] CA-12: Se il nome prodotto è vuoto al salvataggio, viene usato il nome della categoria selezionata; se anche la categoria è assente, viene salvata stringa vuota
- [ ] CA-13: Per inventari `isManualEntry == true`, il tap su una riga apre `ManualEntrySheet` in EDIT; per inventari da file, il tap apre `RowDetailSheetView` come prima
- [ ] CA-14: Il dialog funziona anche quando colonne `purchasePrice`, `category` e/o la colonna retail (`RetailPrice`/`retailPrice`) non esistono nell'header manuale: vengono aggiunte automaticamente (solo per inventari manuali, solo al Conferma); se `barcode`, `productName` o la colonna quantità mancano, il Conferma è bloccato con errore tecnico visibile
- [ ] CA-15: Dopo una Add/Edit/Delete, la sessione sopravvive ad autosave e restore da `HistoryEntry` senza corruzioni di `data`/`editable`/`complete`
- [ ] CA-16: Se il DB non contiene `ProductCategory`, il Picker categoria è vuoto/disabilitato e il salvataggio non è bloccato
- [ ] CA-17: In EDIT, se la riga ha una stringa `category` che non corrisponde ad alcun `ProductCategory` nel DB, il valore raw viene preservato al salvataggio (non viene svuotato)
- [ ] CA-18: Build compila senza errori e senza warning nuovi introdotti
- [ ] CA-19: Input non numerico nel campo `purchasePrice` non blocca il Conferma; al salvataggio il campo viene persistito come stringa vuota in `data` (equivalente a "non compilato")
- [ ] CA-20: Il bottone "Copia dati" copia sempre nome prodotto e prezzo vendita; la categoria viene copiata nel Picker se `product.category?.name` trova match tra le `ProductCategory` locali; se non trovata, il valore raw del nome categoria viene impostato in `rawCategoryString` e preservato al salvataggio tramite il fallback raw dichiarato; se `product.category` è nil, nessuna sovrascrittura avviene

## Decisioni
Decisioni superate o cambiate non vanno cancellate: marcarle come OBSOLETA con nota esplicita.
| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|-------|
| 1 | Implementare il dialog come struct privata `ManualEntrySheet` dentro GeneratedView.swift, presentato con `.sheet` | File separato ManualEntryView.swift | GeneratedView contiene già RowDetailSheetView inline; mantenere pattern esistente; evitare file bloat | attiva |
| 2 | Categoria come `Picker` tra `@Query` di `ProductCategory`, senza creazione inline | Creazione inline come Android | Fuori scope; follow-up candidate | attiva |
| 3 | Non implementare change detection gate | Implementare come Android | Complessità non necessaria per MVP; follow-up se richiesto | attiva |
| 4 | Leggere header dinamico `data[0]` per sapere quali colonne esistono | Header fisso hardcoded | La griglia può avere colonne diverse a seconda dell'import | attiva |
| 5 | Per `isManualEntry == true`, tap su riga → `ManualEntrySheet` (EDIT); per inventari da file, tap → `RowDetailSheetView` (invariato) | Aprire ManualEntrySheet in aggiunta a RowDetailSheetView; aprire sempre RowDetailSheetView | Eliminare l'ambiguità: in inventari manuali il dialog di editing dedicato sostituisce RowDetailSheetView; RowDetailSheetView resta accessibile via context menu "Dettagli riga" | attiva |
| 6 | Scanner nel dialog usa `@State private var showScannerInDialog: Bool` locale a `ManualEntrySheet`, presentato come `.sheet` (nested sheet, iOS 16+) — fallback `.fullScreenCover` permesso solo se emergono problemi di presentazione SwiftUI in execution | Usare `showScanner` del parent GeneratedView | Il `showScanner` del parent gestisce flussi distinti (`reopenRowDetailAfterScan`); accoppiamento indesiderato | attiva |
| 7 | Colonne aggiungibili solo per `isManualEntry == true`, solo al Conferma: `purchasePrice`, `category`, `retailPrice`/`RetailPrice` | Aggiungere all'apertura; aggiungere anche per import | Annulla non deve produrre side effect; header import è struttura controllata | attiva |
| 8 | `manualEntryEditIndex` rappresenta l'**indice reale in `data`** (header a 0, prima riga dati a 1) — stesso schema usato da tutta la codebase GeneratedView | Indice logico senza header (0-based sui soli dati) | Coerenza con `allRowIndices = 1..<data.count` e con tutte le funzioni esistenti (`showRowDetail`, `ensureEditableCapacity`, ecc.) | attiva |
| 9 | purchasePrice calcolato solo se blank al salvataggio; se l'utente inserisce 0, viene rispettato | Ricalcolo anche su 0 | Allineamento con Android ("if purchase price is blank"); rispetto dell'intento esplicito dell'utente | attiva |
| 10 | `.task(id: barcode)` senza debounce manuale — differenza deliberata rispetto ad Android (che usa 350ms debounce); `task` di Swift Concurrency cancella automaticamente il task precedente | Aggiungere `try await Task.sleep` per simulare debounce | Idiomatic Swift; la cancellazione automatica è sufficiente per evitare lookup ridondanti | attiva |
| 11 | "Copia dati" copia nome + prezzo vendita + categoria (se match trovato in DB) — allineamento con Android | Copiare solo nome + prezzo vendita | Maggior utilità; Android copia anche la categoria | attiva |
| 12 | Quantità: vuota, zero, decimale (con virgola), negativa = consentiti; valore non numerico (lettere/simboli) = **bloccante** (Conferma disabilitato con errore rosso) | Consentire sempre qualsiasi stringa; bloccare anche negativi | Valori non numerici in `editable[idx][0]` potrebbero corrompere silenziosamente il conteggio in `InventorySyncService` (se fa `Double(v) ?? 0`); bloccarli a monte è più sicuro. Negativi restano non bloccanti: warning giallo, ma valore consentito | attiva |
| 13 | La categoria è **cancellabile in modo esplicito via UI**: il Picker mostra sempre una prima voce "Nessuna categoria" (valore nil); selezionarla imposta `selectedCategory = nil` e azzera `rawCategoryString = ""`; questo distingue il "clear intenzionale" dal "nessun match in DB" | Categoria non cancellabile; flag `categoryCleared: Bool` separato | Con il Picker che ha una voce nil esplicita, l'utente può cancellare deliberatamente; il meccanismo usa le stesse variabili esistenti senza stato aggiuntivo; la logica di salvataggio rimane invariata | attiva |
| 14 | Per inventari manuali (`isManualEntry == true`), **solo il tap diretto su riga** apre `ManualEntrySheet` (EDIT). Tutti gli altri entry point — context menu "Dettagli riga", swipe action "Dettagli", search result `onOpenDetail`, scanner `reopenRowDetailAfterScan` — aprono `RowDetailSheetView` invariato, esattamente come per inventari da file | Rerouting di tutti gli entry point a ManualEntrySheet | Principio di minimo cambiamento: sostituire solo il tap, che è il flusso di editing primario; lasciare invariati i percorsi secondari riduce la superficie di modifica e il rischio di regressioni | attiva |

---

## Planning (Claude)

### Analisi

**Stato attuale iOS (da lettura diretta del codice):**
- `addManualRow()` (GeneratedView:1433-1450): appende riga vuota senza dialog. Chiama `ensureEditableCapacity(for: newIndex)` e `ensureCompleteCapacity()`, poi `markDirtyAndScheduleAutosave()`
- `handleScannedBarcode()` (GeneratedView:1265-1430): fa lookup DB sul barcode scansionato e pre-fill nome+prezzo, ma solo nel flusso scan integrato nella griglia, non in un dialog strutturato
- `RowDetailSheetView` (GeneratedView:2048+): sheet per editare riga esistente; resta invariato
- Tap su riga: `allRowIndices = 1..<data.count` → `rowIndex` è l'**indice reale in `data`** (header a 0). `flashAndOpenRow(rowIndex, headerRow:)` → `showRowDetail(for: rowIndex, ...)` — usa lo stesso schema di indici in tutta la codebase
- `showScanner` (GeneratedView:82): `@State private var showScanner: Bool = false`. Presentato via `.sheet(isPresented: $showScanner)` con `ScannerView`. Gestisce flusso normale + re-open post-scan dal pannello dettagli (`reopenRowDetailAfterScan`)
- Header manuale default: `["barcode", "productName", "realQuantity", "RetailPrice"]`
- `editable[rowIndex]` = `["<counted_qty>", "<retail_price>"]` (sempre 2 slot). Slot 0 = quantità contata; slot 1 = prezzo vendita
- `complete`: array booleano con stessa lunghezza di `data`

**Modello `Product` iOS (`Models.swift`):**
```swift
@Model final class Product {
    @Attribute(.unique) var barcode: String    // chiave di lookup
    var productName: String?                   // nome prodotto
    var purchasePrice: Double?
    var retailPrice: Double?                   // prezzo per card + copia
    var stockQuantity: Double?
    var supplier: Supplier?
    var category: ProductCategory?             // usato per "Copia dati"
    var priceHistory: [ProductPrice]
}
```

**Modello `ProductCategory` iOS (`Models.swift`):**
```swift
@Model final class ProductCategory {
    @Attribute(.unique) var name: String
}
```

---

### Contratto indice riga

**Convenzione ufficiale: `manualEntryEditIndex` = indice reale in `data`.**

- `data[0]` = header; prima riga dati = `data[1]`
- `editable[0]` = slot header (non usato); prima riga dati = `editable[1]`
- `complete[0]` = false (header); prima riga dati = `complete[1]`
- `allRowIndices = 1..<data.count` — i `rowIndex` che arrivano al tap sono già indici reali

Questa convenzione si applica coerentemente in:

| Punto | Valore di `editIndex` |
|---|---|
| Tap su riga (`.onTapGesture`) | `rowIndex` = indice reale in `data` (da `allRowIndices`) |
| Scan hit su riga esistente | `existingIndex` restituito da `handleScannedBarcode` = indice reale |
| Source of truth in EDIT | `data[editIndex]`, `editable[editIndex]` |
| `confirmEdit()` | Scrive in `data[editIndex]`, `editable[editIndex]` |
| `deleteRow()` | `data.remove(at: editIndex)`, `editable.remove(at: editIndex)`, `complete.remove(at: editIndex)` |
| Check duplicato barcode | Esclude `i == editIndex` (non `i + 1 == editIndex`) |

---

### Routing matrix: entry point → UI aperta

Per ogni entry point e per entrambi i tipi di inventario.

| Entry point | Inventario manuale (`isManualEntry == true`) | Inventario da file (`isManualEntry == false`) |
|---|---|---|
| **Tap su riga** | `ManualEntrySheet` (EDIT) ← **unico punto modificato** | `RowDetailSheetView` (invariato) |
| **Context menu "Dettagli riga"** | `RowDetailSheetView` (invariato) | `RowDetailSheetView` (invariato) |
| **Swipe action "Dettagli"** | `RowDetailSheetView` (invariato) | `RowDetailSheetView` (invariato) |
| **Search result / `onOpenDetail`** | `RowDetailSheetView` (invariato) | `RowDetailSheetView` (invariato) |
| **Scanner `reopenRowDetailAfterScan`** | `RowDetailSheetView` (invariato) | `RowDetailSheetView` (invariato) |
| **Bottone "Aggiungi riga"** | `ManualEntrySheet` (ADD) | — (bottone non presente su inventari da file) |

**Regola sintetica** (D-14): la modifica tocca un solo entry point — il tap diretto su riga per inventari manuali. Tutti gli altri flussi restano immutati, per entrambi i tipi di inventario.

**Implementazione**: la distinzione avviene dentro `flashAndOpenRow()` (o equivalente), con un branch `if entry.isManualEntry`. Gli altri entry point (`showRowDetail`, `reopenRowDetailAfterScan`, `onOpenDetail`) chiamano già `showRowDetail` direttamente e non passano per `flashAndOpenRow` — non vanno toccati.

---

### Mappatura campi dialog ↔ colonne griglia

| Campo dialog | Colonna preferita (scrittura) | Fallback (lettura) | Anche in `editable`? |
|---|---|---|---|
| Barcode | `barcode` | — | No |
| Nome prodotto | `productName` | — | No |
| Prezzo vendita | prima colonna trovata con candidati `["RetailPrice", "retailPrice"]` | — | Sì → slot 1 |
| Prezzo acquisto | `purchasePrice` | — | No |
| Quantità | prima colonna trovata con candidati `["realQuantity", "quantity"]` | — | Sì → slot 0 |
| Categoria | `category` | — | No |

---

### Risoluzione indici colonna

**Helper unico** (da usare in `ManualEntrySheet`, non duplicare):

```swift
func columnIndex(in header: [String], candidates: [String]) -> Int? {
    for name in candidates {
        if let idx = header.firstIndex(of: name) { return idx }
    }
    return nil
}
```

**Candidati per campo** (ordine = priorità, primo match vince):

| Campo | Candidati |
|---|---|
| Barcode | `["barcode"]` |
| Nome prodotto | `["productName"]` |
| Prezzo vendita | `["RetailPrice", "retailPrice"]` |
| Prezzo acquisto | `["purchasePrice"]` |
| Quantità | `["realQuantity", "quantity"]` |
| Categoria | `["category"]` |

**Regola ufficiale per prezzo vendita**: il primo candidato trovato nell'header vince. L'ordine dei candidati (`RetailPrice` prima di `retailPrice`) riflette il fatto che gli header manuali di default usano `RetailPrice`. Se coesistono entrambe in un header (caso anomalo), viene usata `RetailPrice`. Non si tocca l'altra colonna.

**Classificazione colonne:**

| Tipo | Colonne | Comportamento se mancante in header manuale |
|---|---|---|
| **Aggiungibili** | `purchasePrice`, `category`, `RetailPrice` (se nessuna delle due varianti è presente) | Aggiunta automaticamente al Conferma con padding vuoto alle righe esistenti |
| **Obbligatorie non aggiungibili** | `barcode`, `productName`, la colonna quantità (`realQuantity`/`quantity`) | **Fail-fast**: Conferma bloccato con messaggio di errore tecnico "Sessione non compatibile — struttura header incompleta"; nessuna scrittura avviene |

**Nota**: `RetailPrice` è aggiungibile perché è meno probabile che sia presente in vecchie sessioni corrutte, e la sua assenza non è un'anomalia strutturale grave. Le colonne `barcode`, `productName`, `realQuantity`/`quantity` devono sempre esistere; se mancano, la sessione è irrecuperabile da questo dialog.

---

### Stato locale del dialog vs colonne mancanti

`ManualEntrySheet` mantiene **sempre** `@State` locali per tutti i campi (barcode, productName, retailPrice, purchasePrice, quantity, selectedCategory, rawCategoryString), indipendentemente dalle colonne presenti nell'header.

Le colonne mancanti vengono aggiunte alla griglia **solo al momento del Conferma**, mai all'apertura. Se l'utente preme Annulla, l'header non viene mai modificato.

---

### Regole per colonne mancanti

**Solo per `isManualEntry == true`. MAI per inventari da file import.**

Colonne aggiungibili se mancanti (in ordine): `purchasePrice`, poi `category`, poi `RetailPrice` (se né `RetailPrice` né `retailPrice` sono presenti).

**Procedura** (eseguita in `confirmAdd()` / `confirmEdit()`, prima di scrivere la riga):
```
1. Check obbligatorie: columnIndex(barcode), columnIndex(productName), columnIndex(quantità)
   → Se nil: impostare errore tecnico, return senza scrivere nulla
2. Per ciascuna colonna aggiungibile mancante (nell'ordine dichiarato):
   a. data[0].append(colName)
   b. Per ogni riga data[i] con i >= 1: data[i].append("")
3. Ricalcolare tutti gli indici colonna (dopo le aggiunte)
4. Costruire la riga
5. Scrivere in data, editable, chiamare autosave
```

`editable` e `complete` non vengono toccati dalla procedura di aggiunta colonne.

---

### Source of truth in EDIT

| Campo dialog | Fonte | Dettaglio |
|---|---|---|
| Barcode | `data[editIndex]` | `data[editIndex][columnIndex(["barcode"])]` |
| Nome prodotto | `data[editIndex]` | `data[editIndex][columnIndex(["productName"])]` |
| Quantità | `editable[editIndex][0]` | Quantità contata dall'utente (non il valore originale in `data`) |
| Prezzo vendita | `editable[editIndex][1]` | Prezzo live modificato dall'utente (non il valore originale in `data`) |
| Prezzo acquisto | `data[editIndex]` | `data[editIndex][columnIndex(["purchasePrice"])]`; `""` se colonna assente |
| Categoria | `data[editIndex]` + lookup | Legge stringa raw → tenta match in `categories` → imposta `selectedCategory`; salva la stringa raw in `rawCategoryString` |

**Rationale**: quantità e prezzo vendita vengono da `editable` perché sono i valori che l'utente ha già modificato nella sessione — usare `data` sarebbe un revert.

**`rawCategoryString`**: `@State private var rawCategoryString: String = ""`. In EDIT viene inizializzato con il valore grezzo da `data[editIndex][categoryIdx]`. Viene usato come fallback al salvataggio (vedi sezione "Preservazione categoria raw e cancellazione esplicita").

---

### Apertura sicura del dialog su sessioni corrotte/incomplete

Questa sezione definisce come `ManualEntrySheet` si inizializza quando le strutture dati potrebbero essere incomplete. Le regole si applicano **all'apertura** (`.onAppear` o init), prima di qualsiasi interazione utente.

**Caso 1 — `editIndex` fuori range** (in EDIT):
```swift
guard data.indices.contains(editIndex) else {
    dismiss()   // chiudi il dialog immediatamente
    return
}
```
Questo caso non dovrebbe mai accadere (il routing lo previene), ma il guard evita crash.

**Caso 2 — `editable[editIndex]` con meno di 2 slot**:
```swift
let qty    = (editable.indices.contains(editIndex) && editable[editIndex].indices.contains(0))
             ? editable[editIndex][0] : ""
let retail = (editable.indices.contains(editIndex) && editable[editIndex].indices.contains(1))
             ? editable[editIndex][1] : ""
```
Usa `""` come default sicuro invece di crashare con index out of bounds.

**Caso 3 — Riga più corta dell'header** (lettura da `data[editIndex]`):
```swift
func safeRead(_ row: [String], at idx: Int?) -> String {
    guard let idx = idx, row.indices.contains(idx) else { return "" }
    return row[idx]
}
```
Usare sempre `safeRead` invece di `row[idx]` diretto per tutte le letture all'apertura.

**Caso 4 — Colonna obbligatoria mancante già all'apertura**:
- Il dialog si apre normalmente
- Viene impostato `headerError: String?` con il messaggio tecnico
- Il body del dialog mostra il banner di errore
- Il bottone Conferma è disabilitato (stesso comportamento del fail-fast al Conferma)
- L'utente può solo premere Annulla

Questa strategia garantisce che il dialog non crashia mai all'apertura e che le sessioni corrotte mostrino un messaggio chiaro invece di un crash silenzioso o dati sbagliati.

---

### Preservazione categoria raw in EDIT e cancellazione esplicita

**Problema**: la riga può avere una stringa `category` che non corrisponde ad alcun `ProductCategory` nel DB (es. categoria eliminata, o DB diverso). Se `selectedCategory` fosse nil senza distinzione, il salvataggio svuoterebbe silenziosamente il valore originale.

**Soluzione** (D-13): il Picker mostra sempre una prima voce "Nessuna categoria" (binding a `selectedCategory = nil`). Selezionarla esplicitamente imposta anche `rawCategoryString = ""`, segnalando il clear intenzionale.

**Regola al salvataggio** (uguale per ADD e EDIT):
```swift
let categoryToSave: String
if let cat = selectedCategory {
    categoryToSave = cat.name          // Picker ha una selezione reale → usarla
} else if !rawCategoryString.isEmpty {
    categoryToSave = rawCategoryString // EDIT: nessun match in DB, utente non ha toccato il Picker → preservare raw
} else {
    categoryToSave = ""                // ADD senza selezione, oppure utente ha scelto esplicitamente "Nessuna categoria"
}
```

**Casi coperti**:
| Scenario | `selectedCategory` | `rawCategoryString` | `categoryToSave` |
|---|---|---|---|
| EDIT, categoria DB presente | non-nil | qualsiasi | `cat.name` |
| EDIT, categoria non in DB, Picker non toccato | nil | `"vecchia"` | `"vecchia"` (preservato) |
| EDIT, utente seleziona "Nessuna categoria" | nil | `""` (azzerato) | `""` (clear intenzionale) |
| ADD senza selezione | nil | `""` | `""` |
| ADD con selezione | non-nil | `""` | `cat.name` |

---

### Sincronizzazione `data` ed `editable`

**Regola**: ogni campo ha una sola destinazione di scrittura.

| Campo | Scritto in `data`? | Scritto in `editable`? |
|---|---|---|
| Barcode | ✅ `data[idx][barcodeIdx]` | ❌ |
| Nome prodotto | ✅ `data[idx][productNameIdx]` | ❌ |
| Prezzo vendita | ✅ `data[idx][retailPriceIdx]` | ✅ `editable[idx][1]` |
| Prezzo acquisto | ✅ `data[idx][purchasePriceIdx]` | ❌ |
| Quantità | ✅ `data[idx][quantityIdx]` | ✅ `editable[idx][0]` |
| Categoria | ✅ `data[idx][categoryIdx]` | ❌ |

Prezzo vendita e quantità vanno in entrambi: `editable` li usa per calcoli live e sync; `data` li serve per export e restore.

**Ordine di scrittura**: prima `data[idx]`, poi `editable[idx]`, poi autosave. Non invertire.

---

### Barcode duplicato: comportamento preciso

**In ADD**: duplicato se barcode esiste in `data[i]` per qualsiasi `i >= 1`.

**In EDIT** (`editIndex = N`): duplicato se esiste in `data[i]` per `i >= 1` e `i != N`.

```swift
let cleaned = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
guard let bIdx = columnIndex(in: data[0], candidates: ["barcode"]) else { return false }
let isDuplicate = (1..<data.count).contains { i in
    let rowBarcode = data[i].indices.contains(bIdx) ? data[i][bIdx] : ""
    let isCurrentRow = (mode == .edit && i == editIndex)
    return rowBarcode == cleaned && !isCurrentRow
}
```

---

### Lookup database e "Copia dati"

**Trigger**: `.task(id: barcode)` — si ri-esegue ad ogni cambiamento di `barcode`. La cancellazione automatica del task precedente è sufficiente (nessun debounce manuale necessario — differenza deliberata rispetto ad Android, D-10).

**Step**:
1. `cleaned = barcode.trimmed`; se vuoto → reset errore + productFromDb, return
2. Check duplicato → se duplicato: `barcodeError = "Prodotto già presente nella lista"`, return
3. `barcodeError = nil`
4. Fetch `Product` da DB per `barcode == cleaned`
5. `productFromDb = result` (nil se non trovato; nessun errore)

**Card "Dati dal database"**: visibile se `productFromDb != nil`. Mostra `product.productName ?? ""` e `product.retailPrice`.

**Bottone "Copia dati"** (differenza vs versione precedente del planning — aggiornamento deliberato):
- `productName` ← `product.productName ?? ""`
- `retailPrice` ← `formatDoubleAsPrice(product.retailPrice ?? 0)`
- `selectedCategory` ← lookup in `categories` per `product.category?.name`
  - Se trovato: `selectedCategory = matchedCategory`; `rawCategoryString` invariato
  - **Se non trovato** ma `product.category?.name` è non-vuoto: `selectedCategory = nil`; `rawCategoryString = product.category!.name`
  - Se `product.category` è nil: `selectedCategory` e `rawCategoryString` restano invariati (nessuna sovrascrittura)

**Rationale edge case**: senza questo passaggio, "Copia dati" lascerebbe silenziosamente la categoria del DB nel campo vuoto/invariato. Valorizzare `rawCategoryString` garantisce che il nome categoria del prodotto sia comunque copiato — e al salvataggio verrà usato come fallback (via la regola `!rawCategoryString.isEmpty`). Non è selezionabile dal Picker, ma viene preservato in `data`.

---

### Calcolo purchasePrice al salvataggio

**Regola ufficiale** (D-9): calcolo solo se il campo è **blank** (stringa vuota o solo spazi). Se l'utente ha digitato `"0"`, viene rispettato.

```swift
let retailDouble = Double(retailPrice.replacingOccurrences(of: ",", with: ".")) ?? 0
let purchaseTrimmed = purchasePrice.trimmingCharacters(in: .whitespaces)

let purchaseDouble: Double?
if purchaseTrimmed.isEmpty {
    purchaseDouble = (retailDouble > 0) ? (retailDouble / 2.0).rounded() : nil
} else {
    purchaseDouble = Double(purchaseTrimmed.replacingOccurrences(of: ",", with: "."))
}

let purchaseStr = purchaseDouble.map { formatDoubleAsPrice($0) } ?? ""
```

**Validazione `purchasePrice`** — se il campo contiene testo non numerico (es. `"abc"`):
- `Double(purchaseTrimmed.replacingOccurrences(of: ",", with: "."))` restituisce `nil`
- `purchaseDouble` sarà `nil` → `purchaseStr = ""`
- Nessun crash; nessun blocco al Conferma
- Il valore viene salvato come `""` in `data` (equivalente a "campo non compilato")

**Rationale** (differenza rispetto alla quantità): `purchasePrice` non è letto da `InventorySyncService` per aggiornare conteggi critici. È un dato informativo/storico; salvarlo come `""` in caso di input invalido è sicuro e non corrompe flussi esistenti. Non vale la pena bloccare l'utente per questo campo. Aggiungere in futuro validazione UI opzionale è un follow-up candidate.

**Nome prodotto fallback**:
```swift
let finalName = productName.trimmingCharacters(in: .whitespaces).isEmpty
    ? (selectedCategory?.name ?? rawCategoryString)  // usa anche rawCategoryString come ultimo fallback
    : productName
```
(Nota: `rawCategoryString` è `""` in ADD, quindi il fallback in ADD rimane stringa vuota se nessuna categoria selezionata.)

---

### Validazione quantità

| Valore | Consentito? | Comportamento |
|---|---|---|
| Vuota `""` | ✅ | Salvata come `""` in `data`; `editable[idx][0] = ""` |
| Zero `"0"` | ✅ | Salvato normalmente |
| Decimale (es. `"2,5"`) | ✅ | Salvato con virgola; coerente col resto dell'app |
| Negativo (es. `"-1"`) | ⚠️ | Warning giallo non bloccante sotto il campo; salvataggio consentito |
| Non numerico (es. `"abc"`) | ❌ | **Bloccante**: errore rosso sotto il campo; Conferma disabilitato |

**Rationale** (D-12): `editable[idx][0]` è letto da `InventorySyncService` per aggiornare `stockQuantity` su `Product`. Un valore non numerico verrebbe silenziato a `0` via `Double(v) ?? 0`, corrompendo il conteggio. Bloccare a monte è più sicuro. Valori negativi sono consentiti perché `Double("-1")` è valido e il caso d'uso (storno/rettifica) è legittimo.

**Regola di validazione** (da applicare in `.task(id: quantity)` o `onChange`):
```swift
let isQuantityValid: Bool = {
    let t = quantity.trimmingCharacters(in: .whitespaces)
    if t.isEmpty { return true }
    return Double(t.replacingOccurrences(of: ",", with: ".")) != nil
}()
```
Conferma disabilitato se `!isQuantityValid`.

---

### Integrazione scanner nel dialog

**Design principale**: `@State private var showScannerInDialog: Bool = false` locale a `ManualEntrySheet`. Presentato come `.sheet(isPresented: $showScannerInDialog)` (nested sheet, iOS 16+).

**Fallback operativo**: se emergono problemi di presentazione, usare `.fullScreenCover`. Nessun'altra parte del design cambia.

**Dopo scansione**: `barcode = code`, `showScannerInDialog = false` → `.task(id: barcode)` riparte automaticamente.

**Assenza di conflitti**: `showScannerInDialog` è completamente indipendente da `showScanner` del parent.

---

### Cancel blindato

Unica azione: `dismiss()`. Nessuna colonna aggiunta, nessun padding, nessuna mutazione di `data`/`editable`/`complete`, nessun autosave.

---

### Lifecycle del ManualEntrySheet e pulizia stato temporaneo

**Dopo `confirmAdd()` riuscito**:
1. `onSave()` (= `markDirtyAndScheduleAutosave()`) viene chiamato
2. `dismiss()` chiude il sheet
3. SwiftUI distrugge la struct `ManualEntrySheet`: tutti gli `@State` locali (`barcode`, `productName`, `barcodeError`, `headerError`, `productFromDb`, `rawCategoryString`, `selectedCategory`, ecc.) vengono eliminati automaticamente
4. Nel parent: `showManualEntrySheet = false`; `manualEntryEditIndex` rimane al valore precedente (sarà sovrascritto alla prossima apertura prima di impostare `showManualEntrySheet = true`)

**Dopo `confirmEdit()` riuscito**: stesso schema di ADD — dismiss + distruzione struct.

**Dopo `deleteRow()` riuscito**: stesso schema — dismiss + distruzione struct.

**Dopo Cancel / dismiss senza azione**:
1. `dismiss()` — nessuna mutazione
2. SwiftUI distrugge la struct: stato pulito automaticamente

**Pulizia `manualEntryEditIndex`**: non va azzerato esplicitamente dopo la chiusura. Il valore viene sempre **sovrascritto prima** dell'apertura successiva:
- Bottone "Aggiungi riga": `manualEntryEditIndex = nil` → `showManualEntrySheet = true`
- Tap riga: `manualEntryEditIndex = rowIndex` → `showManualEntrySheet = true`

L'ordine di assegnazione è critico: impostare `manualEntryEditIndex` **prima** di `showManualEntrySheet = true`, in modo che SwiftUI catturi il valore corretto quando crea la struct.

**Nessuno stato stantio**: poiché `ManualEntrySheet` è una struct SwiftUI (non una classe) e viene ricostruita a ogni presentazione, non c'è rischio di stato residuo tra una presentazione e la successiva. Non serve un `onDismiss` per pulire variabili locali del dialog.

---

### Categoria: comportamento con DB vuoto

Se `@Query` restituisce array vuoto: Picker mostra solo placeholder "Nessuna categoria". Il campo è opzionale: nessun blocco del salvataggio. `selectedCategory = nil` → `categoryToSave = rawCategoryString` (EDIT) oppure `""` (ADD).

---

### Differenze deliberate rispetto ad Android

| Aspetto | Android | iOS (questo task) | Motivazione |
|---|---|---|---|
| Debounce lookup barcode | 350ms esplicito | `.task(id:)` senza sleep | Idiomatic Swift; cancellazione automatica sufficiente |
| "Copia dati" copia categoria | ✅ | ✅ (aggiunto — allineamento con Android) | Maggior utilità |
| "Aggiungi e Prossimo" | ✅ | ❌ (fuori scope) | Follow-up candidate |
| Sticky last used category | ✅ | ❌ (fuori scope) | Follow-up candidate |
| Change detection gate | ✅ | ❌ (fuori scope) | Follow-up candidate |

---

### Compatibilità con autosave e history

- `markDirtyAndScheduleAutosave()` persiste `data`/`editable`/`complete` in `HistoryEntry` via JSON
- Aggiunta colonne `purchasePrice`/`category`/`RetailPrice` è retrocompatibile (righe preesistenti con `""`)
- Sessioni manuali vecchie senza queste colonne: la prima Add/Edit aggiungerà le colonne e autosave fisserà il nuovo schema

---

### Struttura `editable` e `complete`

**In ADD:**
```
1. Fail-fast check obbligatorie
2. addColumnIfMissing per aggiungibili
3. data.append(newRow) → newIndex = data.count - 1
4. ensureEditableCapacity(for: newIndex)
5. editable[newIndex][0] = qty; editable[newIndex][1] = retailPrice
6. ensureCompleteCapacity()
7. complete[newIndex] = false
8. autosave
```

**In EDIT:**
```
1. Fail-fast check obbligatorie
2. addColumnIfMissing per aggiungibili
3. data[editIndex] = newRow  ← vedi sezione "Costruzione della riga (ADD vs EDIT)": copia + aggiornamento
4. ensureEditableCapacity(for: editIndex)
5. editable[editIndex][0] = qty; editable[editIndex][1] = retailPrice
   // complete[editIndex] invariato
6. autosave
```

**In DELETE:**
```
1. data.remove(at: editIndex)
2. editable.remove(at: editIndex) se indice valido
3. complete.remove(at: editIndex) se indice valido
4. autosave
```

**Invariante**: `data.count == complete.count == editable.count` sempre.

---

### Costruzione della riga (ADD vs EDIT)

**In ADD** — la riga viene costruita da zero con lunghezza esattamente uguale all'header (dopo eventuali `addColumnIfMissing`):
```swift
// Dopo addColumnIfMissing, data[0].count è il conteggio definitivo
var newRow = Array(repeating: "", count: data[0].count)
newRow[barcodeIdx]      = barcode.trimmingCharacters(in: .whitespaces)
newRow[productNameIdx]  = finalName
newRow[retailPriceIdx]  = retailPriceStr
newRow[purchasePriceIdx] = purchaseStr
newRow[quantityIdx]     = quantity.trimmingCharacters(in: .whitespaces)
if let catIdx = categoryIdx { newRow[catIdx] = categoryToSave }
data.append(newRow)
```
Tutte le colonne non gestite dal dialog restano `""`.

**In EDIT** — non si ricostruisce la riga da zero: si parte da una **copia** di `data[editIndex]` e si aggiornano solo le colonne gestite. Questo preserva eventuali colonne extra presenti nella riga (dati fuori scope del dialog):
```swift
// Dopo addColumnIfMissing, la riga potrebbe essere più corta dell'header se aggiunta in precedenza
var newRow = data[editIndex]
// Estendi se la riga è più corta (colonne aggiunte in questa sessione)
while newRow.count < data[0].count { newRow.append("") }
// Aggiorna solo i campi gestiti
newRow[barcodeIdx]       = barcode.trimmingCharacters(in: .whitespaces)
newRow[productNameIdx]   = finalName
newRow[retailPriceIdx]   = retailPriceStr
newRow[purchasePriceIdx] = purchaseStr
newRow[quantityIdx]      = quantity.trimmingCharacters(in: .whitespaces)
if let catIdx = categoryIdx { newRow[catIdx] = categoryToSave }
data[editIndex] = newRow
```

**Regola fondamentale**: in EDIT non scrivere `data[editIndex] = Array(repeating: "", count: n)`. Partire sempre dalla riga esistente.

---

### Approccio proposto: step di implementazione

**Step 1 — State variables in GeneratedView**
```swift
@State private var showManualEntrySheet: Bool = false
@State private var manualEntryEditIndex: Int? = nil  // nil = ADD, indice reale = EDIT
```

**Step 2 — Routing tap riga** (in `flashAndOpenRow()` o equivalente):
```swift
if entry.isManualEntry {
    manualEntryEditIndex = rowIndex   // rowIndex è già indice reale (da allRowIndices = 1..<data.count)
    showManualEntrySheet = true
} else {
    showRowDetail(for: rowIndex, headerRow: headerRow)
}
```

**Step 3 — Bottone "Aggiungi riga"**:
```swift
manualEntryEditIndex = nil
showManualEntrySheet = true
```

**Step 4 — Sheet modifier**:
```swift
.sheet(isPresented: $showManualEntrySheet) {
    ManualEntrySheet(
        editIndex: manualEntryEditIndex,
        data: $data,
        editable: $editable,
        complete: $complete,
        isManualEntry: entry.isManualEntry,
        onSave: { markDirtyAndScheduleAutosave() }
    )
}
```

**Step 5 — Struct ManualEntrySheet**: struct privata con:
- `@State` locali: barcode, productName, retailPrice, purchasePrice, quantity, selectedCategory, rawCategoryString
- `@State private var showScannerInDialog: Bool`
- `@State private var productFromDb: Product?`
- `@State private var barcodeError: String?`
- `@State private var headerError: String?` (per fail-fast colonne obbligatorie — impostato all'apertura se colonne obbligatorie mancanti)
- `@Query private var categories: [ProductCategory]`
- `.task(id: barcode)` per lookup + check duplicati
- `.onAppear` / init guard per apertura sicura (safeRead, editIndex range check)
- Picker categoria con prima voce "Nessuna categoria" (nil) che azzera anche `rawCategoryString`
- Helper `columnIndex(in:candidates:)`, `safeRead(_:at:)`
- Logica `confirmAdd()`, `confirmEdit()`, `deleteRow()`, `addColumnIfMissing(_:)`
- Computed `isQuantityValid: Bool` (per gate quantità non numerica)

**Step 6 — Colonne mancanti** (dentro confirm*):
```swift
func addColumnIfMissing(_ key: String) {
    guard data[0].firstIndex(of: key) == nil else { return }
    data[0].append(key)
    for i in 1..<data.count { data[i].append("") }
}
```

### File da modificare
| File | Tipo modifica | Motivazione |
|------|--------------|-------------|
| `iOSMerchandiseControl/GeneratedView.swift` | Modifica sostanziale (+~330 righe stimate) | Unico file da modificare |

### Rischi identificati
| Rischio | Probabilità | Impatto | Mitigazione |
|---------|-------------|---------|-------------|
| `manualEntryEditIndex` potrebbe essere nil quando `ManualEntrySheet` tenta di leggerlo in EDIT | Bassa | Medio | La sheet viene presentata solo dopo aver impostato `manualEntryEditIndex`; verificare che SwiftUI non catturi il valore prima dell'assegnazione |
| Nested sheet (scanner) su iOS 15 | Bassa | Medio | Verificare deployment target; usare `.fullScreenCover` se necessario (permesso da D-6) |
| `addColumnIfMissing` modifica `@Binding data`: verificare che le mutazioni siano visibili al parent | Bassa | Medio | `@Binding` propaga le mutazioni; non fare copie locali di `data` prima di passarle al helper |
| Fail-fast per colonne obbligatorie mancanti: messaggio tecnico deve essere comprensibile all'utente | Bassa | Basso | Usare stringa chiara, es. "Sessione non compatibile. Riapri l'inventario." |

### Test manuali previsti

| # | Scenario | Esito atteso |
|---|---|---|
| T-1 | ADD: barcode + prezzo vendita, Conferma | Riga in fondo; purchasePrice = round(prezzo/2) |
| T-2 | ADD: barcode 0 come prezzo acquisto esplicito + prezzo vendita 10 | purchasePrice = 0 (non ricalcolato) |
| T-3 | ADD con scanner: scan barcode | Campo valorizzato; lookup parte |
| T-4 | ADD: barcode trovato in DB → "Copia dati" | Nome, prezzo vendita e categoria copiati |
| T-5 | ADD: barcode duplicato | Errore rosso; Conferma disabilitato |
| T-6 | ADD: quantità negativa | Warning giallo; salvataggio consentito |
| T-7 | ADD: quantità vuota | Salvata come ""; nessun blocco |
| T-8 | EDIT: tap riga → dialog con campi pre-compilati (barcode/nome da `data`, qty/prezzo da `editable`) | Campi corretti |
| T-9 | EDIT: il barcode originale non è segnalato come duplicato | Nessun errore |
| T-10 | EDIT: cambia barcode con uno presente in altra riga | Errore rosso; Conferma disabilitato |
| T-11 | EDIT: modifica + Conferma | `complete[editIndex]` invariato; `data`/`editable` aggiornati |
| T-12 | EDIT: riga con categoria non più presente nel DB → apre e riconferma senza modifiche | Stringa raw categoria preservata (CA-17) |
| T-13 | DELETE in EDIT | Riga scompare; `data`/`editable`/`complete` coerenti agli indici corretti |
| T-14 | Annulla in ADD | Header invariato; nessun autosave |
| T-15 | ADD senza colonne purchasePrice/category/RetailPrice nell'header manuale | Colonne aggiunte; righe preesistenti con padding vuoto; nessuna corruzione |
| T-16 | EDIT sessione manuale vecchia senza purchasePrice e category: Conferma | Colonne aggiunte; autosave; restore da Cronologia coerente |
| T-17 | Inventario da file: tap riga | RowDetailSheetView (invariato); ManualEntrySheet non si apre |
| T-18 | Riapertura da Cronologia dopo Add/Edit/Delete | Dati persistiti; indici coerenti |
| T-19 | ADD con nome vuoto + categoria selezionata | productName = nome categoria |
| T-20 | ADD con DB categorie vuoto | Picker vuoto; salvataggio non bloccato |
| T-21 | ADD/EDIT: header manuale manca colonna `barcode` (sessione corrotta) | Conferma bloccato con messaggio errore tecnico; nessuna scrittura |
| T-22 | EDIT: riga ha colonne extra non gestite dal dialog; Conferma | Colonne extra preservate nella riga (copia + aggiornamento, non ricostruzione da zero) |
| T-23 | ADD/EDIT: quantità non numerica tipo "abc" | Errore rosso; Conferma disabilitato |
| T-24 | EDIT: categoria present in riga ma non in DB; utente seleziona "Nessuna categoria" e Conferma | Categoria salvata come "" (clear intenzionale, non preservazione raw) |
| T-25 | EDIT: `editIndex` fuori range (simulato) | Dialog si chiude senza crash |
| T-26 | Inventario manuale: apertura da search result / `onOpenDetail` su riga esistente | `RowDetailSheetView` si apre (non `ManualEntrySheet`) |
| T-27 | Inventario manuale: scanner rileva barcode di riga esistente → `reopenRowDetailAfterScan` | `RowDetailSheetView` si apre (non `ManualEntrySheet`) |
| T-28 | Inventario manuale: context menu "Dettagli riga" o swipe action "Dettagli" | `RowDetailSheetView` si apre (non `ManualEntrySheet`) |

### Handoff → Execution
- **Prossima fase**: EXECUTION
- **Prossimo agente**: CODEX
- **Azione consigliata**:
  1. Leggere integralmente GeneratedView.swift (focus: `addManualRow`, `flashAndOpenRow`, `allRowIndices`, tutti i `.sheet` modifier, `ensureEditableCapacity`, `ensureCompleteCapacity`, `markDirtyAndScheduleAutosave`)
  2. Leggere `Models.swift` per confermare campi `Product` e `ProductCategory`
  3. Verificare deployment target iOS (nested sheet vs fullScreenCover per scanner nel dialog)
  4. Implementare in ordine Step 1 → Step 6
  5. Eseguire test T-1..T-28 prima dell'handoff a review
  6. Riferimento Android: ManualEntryDialog in GeneratedScreen.kt:1873-2360

---

## Execution (Codex)

### Obiettivo compreso
Implementare in `GeneratedView.swift` un `ManualEntrySheet` per ADD/EDIT delle righe manuali, con lookup DB, scanner, validazioni, gestione colonne mancanti e persistenza coerente con `data` / `editable` / `complete`, mantenendo invariati i flussi fuori scope.

### File controllati
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-008-generated-manual-row-dialog-calculate.md`
- `CLAUDE.md`
- `AGENTS.md`
- `iOSMerchandiseControl/GeneratedView.swift`
- `iOSMerchandiseControl/Models.swift`
- `iOSMerchandiseControl/HistoryEntry.swift`
- `iOSMerchandiseControl/ExcelSessionViewModel.swift`

### Piano minimo
1. Riallineare il tracking minimo ed esplicitare il user override come nota di coerenza, senza alterare backlog o priorità.
2. Modificare solo `GeneratedView.swift` per introdurre il dialog manuale e il rerouting del tap/add manuale secondo il planning.
3. Verificare build, warning e CA realisticamente copribili in questa sessione, poi preparare l'handoff verso `REVIEW`.

Nota di coerenza: user override applicato su richiesta esplicita dell'utente per consentire a Codex di riallineare il tracking iniziale di TASK-008 e procedere direttamente con l'execution.

### Modifiche fatte
- Aggiunti in `GeneratedView` gli state `showManualEntrySheet` e `manualEntryEditIndex`, con rerouting minimo del task: `Aggiungi riga` apre il dialog in ADD e il tap diretto su riga manuale apre il dialog in EDIT; per inventari da file e per gli altri entry point (`Dettagli riga`, swipe, search, scanner reopen) resta invariato `RowDetailSheetView`.
- Implementata la struct privata `ManualEntrySheet` nello stesso file, con campi barcode / nome prodotto / prezzo vendita / prezzo acquisto / quantità / categoria, scanner locale nested-sheet, lookup DB su barcode, card "Dati dal database" e bottone `Copia dati`.
- Implementate le regole di validazione richieste: barcode duplicato bloccante con esclusione della riga corrente in EDIT, quantità non numerica bloccante, quantità negativa solo warning, prezzo vendita > 0 richiesto, `purchasePrice` calcolato solo se blank e persistito vuoto se l'input non è numerico.
- Implementata la gestione header/colonne per sessioni manuali: fail-fast con errore tecnico se mancano `barcode` / `productName` / colonna quantità; aggiunta al Conferma di `purchasePrice`, `category` e `RetailPrice` se mancanti, con padding delle righe esistenti.
- Implementata la persistenza ADD/EDIT/DELETE su `data` / `editable` / `complete`: ADD crea la riga nuova e inizializza `editable`/`complete`, EDIT preserva le colonne extra non gestite aggiornando solo i campi del dialog, DELETE rimuove la riga dagli array paralleli e riallinea le capacità prima dell'autosave.
- Implementata la preservazione della categoria raw non presente nel DB, con possibilità di clear intenzionale dal Picker e copia categoria da DB anche quando il nome non trova match locale.

### Check eseguiti
- ✅ ESEGUITO — Build compila: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' build` concluso con `BUILD SUCCEEDED`.
- ✅ ESEGUITO — Nessun warning nuovo introdotto: nel log del build non compaiono warning Swift/Clang sul codice modificato; compare un solo warning tool-level `Metadata extraction skipped. No AppIntents.framework dependency found.`, non collegato al task e verosimilmente preesistente.
- ✅ ESEGUITO — Modifiche coerenti con planning: intervento confinato a `GeneratedView.swift`, nessun refactor extra, nessuna dipendenza nuova, nessuna modifica ad API/modelli pubblici, routing limitato ai soli entry point previsti.
- ⚠️ NON ESEGUIBILE — Criteri di accettazione verificati: la copertura implementativa e il build supportano CA-1..CA-14 e CA-19..CA-20, ed è stato eseguito un smoke test reale di installazione+lancio tramite `simctl`; i test manuali UI end-to-end T-1..T-28 non sono stati completati in questa sessione.

### Rischi rimasti
- Validazione manuale end-to-end ancora aperta: i flussi UI del dialog (ADD/EDIT/DELETE, scanner nel dialog, categorie raw, colonne mancanti, restore da Cronologia) non sono stati percorsi interattivamente uno per uno nel simulatore durante questa execution.
- Il build è pulito rispetto al codice modificato, ma resta il warning tool-level di `appintentsmetadataprocessor`; non ho evidenza in questo turno che sia stato introdotto dal task.
- Follow-up candidate fuori scope: eventuale automazione UI del percorso manual inventory per chiudere rapidamente T-1..T-28 in review.

### Handoff → Review
- **Prossima fase**: REVIEW
- **Prossimo agente**: CLAUDE
- **Azione consigliata**: verificare in review i flussi manuali prioritari T-1, T-4, T-8, T-11, T-13, T-15, T-17, T-18, T-24 e T-28; confermare in particolare il comportamento del Picker su categoria raw non presente nel DB e il fatto che gli entry point secondari continuino ad aprire `RowDetailSheetView`.

---

## Review (Claude)

### Problemi critici
Nessuno. Il codice è sostanzialmente corretto per tutti i CA verificabili staticamente (CA-1..CA-14, CA-16..CA-20).

### Problemi medi
Nessuno.

### Miglioramenti opzionali
- In `isDuplicateBarcode`, il parametro si chiama `barcode` e shadowa la `@State var barcode`. Non è un bug (il parametro riceve già `cleanedBarcode`), ma rinominarlo `_ cleaned: String` o `_ candidateBarcode: String` eliminerebbe l'ambiguità. Non bloccante.

### Fix richiesti
Nessuno.

### Esito

**REVIEW SOSPESA — task messo in BLOCKED**

Il codice supera la review statica su tutti i CA verificabili. Nessun fix di codice necessario. La review non viene chiusa come APPROVED perché la validazione manuale UI end-to-end (T-1..T-28) è ancora incompleta: Codex ha dichiarato `⚠️ NON ESEGUIBILE` per i test UI, e l'infrastruttura di automazione del Simulator per questo task è ancora instabile.

**Motivazione blocco**: validazione UI finale sospesa in attesa di infrastruttura stabile per automazione del Simulator / skill Codex dedicata.

**Stato post-review**: BLOCKED (non DONE, non active). Il task non torna a FIX (nessun fix di codice richiesto) né viene chiuso (validazione manuale incompleta).

**Prossimo step operativo**: creare un task dedicato (TASK-012 o successivo) per l'automazione del Simulator e la chiusura dei test T-1..T-28. Quando i test saranno eseguiti e superati, tornare qui con esito APPROVED.

### Handoff → Fix (se CHANGES_REQUIRED)
Non applicabile — nessun CHANGES_REQUIRED emesso.

### Handoff → nuovo Planning (se REJECTED)
Non applicabile — nessun REJECTED emesso.

---

## Fix (Codex)

### Fix applicati
[da compilare]

### Check post-fix
- [ ] Build compila: [stato]
- [ ] Fix coerenti con review: [stato]
- [ ] Criteri di accettazione ancora soddisfatti: [stato]

### Handoff → Review finale
- **Prossima fase**: REVIEW
- **Prossimo agente**: CLAUDE
- **Azione consigliata**: Verificare i fix applicati

---

## Chiusura

### Conferma utente
- [ ] Utente ha confermato il completamento

### Follow-up candidate
- Bottone "Aggiungi e Prossimo" (scan continuo) — presente in Android, fuori scope qui
- Creazione categoria inline nel dialog — presente in Android, fuori scope qui
- Sticky "last used category" — presente in Android, fuori scope qui
- Change detection gate — presente in Android, fuori scope qui
- Estrazione ManualEntrySheet in file separato

### Riepilogo finale
[da compilare]

### Data completamento
[da compilare]
