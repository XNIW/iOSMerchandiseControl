# TASK-019: Robustezza — guardie array GeneratedView + cascade delete ProductPrice + async backfill

## Informazioni generali
- **Task ID**: TASK-019
- **Titolo**: Robustezza: guardie array GeneratedView + cascade delete ProductPrice + async backfill
- **File task**: `docs/TASKS/TASK-019-robustezza-guardie-generatedview-cascade-delete-async-backfill.md`
- **Stato**: BLOCKED
- **Fase attuale**: REVIEW *(sospesa — task non attivo progetto; review tecnica **APPROVED**; **nessun fix richiesto**; test manuali **non eseguiti** in questo turno; task **non** DONE)*
- **Responsabile attuale**: UTENTE *(test manuali pendenti: CA-2B/CA-3B store/delete, CA-2C dataset grande; se regressioni → segnalare per **FIX** / CODEX → **REVIEW** → conferma utente → DONE)*
- **Data creazione**: 2026-03-25
- **Ultimo aggiornamento**: 2026-03-25 (**user override / tracking**) — execution **completata**; review tecnica **APPROVED**; **nessun fix richiesto**; test manuali **non eseguiti**; task **non** DONE; sospeso; focus progetto su **TASK-020**. Alla ripresa: test manuali → eventuale **FIX** solo se emergono regressioni → **REVIEW** finale → conferma utente → DONE.
- **Ultimo agente che ha operato**: CLAUDE *(tracking + review tecnica APPROVED)*

## Dipendenze
- **Dipende da**: nessuno (come da TASK-014 / MASTER-PLAN).
- **Sblocca**: riduzione rischio crash/corruzione silenziosa in `GeneratedView`; integrità delete `Product`→`ProductPrice`; avvio app senza freeze su backfill (vedi sotto).

## Scopo
Tre interventi di robustezza raggruppati per efficienza operativa: **(A)** guardia centralizzata su `data` / `editable` / `complete` in `GeneratedView` dopo mutazioni; **(B)** `deleteRule: .cascade` + `inverse` bilanciato su `Product.priceHistory` ↔ `ProductPrice.product`; **(C)** backfill `backfillIfNeeded()` fuori dal main thread all’avvio (thread-safety SwiftData). Dettaglio operativo nella sezione **Planning**.

## Contesto
Definizione e motivazione in **TASK-014** (sezione «TASK-019 — Robustezza…», 2026-03-22). Evidenza codice citata lì: `GeneratedView.swift`, `Models.swift` (`Product` / `ProductPrice`), `ContentView.swift` + eventuale `PriceHistoryBackfillService.swift`.

## Non incluso
- Auto-riparazione silenziosa degli array in **Fix A** (solo guardie + messaggio/banner come da TASK-014).
- Modifica alla logica di business del backfill (quali record creare) in **Fix C**.
- Scope al di fuori dei tre sotto-perimetri salvo emergenza documentata nel file task.

## File potenzialmente coinvolti
- `iOSMerchandiseControl/GeneratedView.swift` — Fix A
- `iOSMerchandiseControl/Models.swift` — Fix B
- `iOSMerchandiseControl/ContentView.swift` — Fix C
- Eventuale nuovo file runner (actor / `@ModelActor`) — Fix C, se separato da `ContentView`
- `iOSMerchandiseControl/PriceHistoryBackfillService.swift` — invariato salvo necessità documentata (logica business invariata)

## Criteri di accettazione
*(Allineati al planning 2026-03-25; execution verifica contro questa lista.)*

**Fix A — GeneratedView**
- [x] **CA-1A**: Dopo **ogni** punto tabella A1–A16 contrassegnato **Hook: OBBLIGATORIO** (mutazioni che possono cambiare il **numero di righe** / shape parallela di `data` / `editable` / `complete`), verificata uguaglianza `data.count == editable.count == complete.count` tramite l’API centralizzata. I punti **Hook: value-only** non richiedono invocazione per CA-1A (non possono violare l’invariante sui conteggi riga). Eventuali punti scoperti in execution vanno classificati allo stesso modo prima di merge.
- [x] **CA-2A**: Se il check fallisce: `debugPrint` con prefisso `[GeneratedView]` (es. token `INVARIANT_FAIL` + conteggi + contesto).
- [x] **CA-3A**: Banner o warning inline non modale; nessun crash; nessuna auto-riparazione silenziosa **come risposta al fallimento** del check.
- [x] **CA-4A**: Con fault attivo: `saveChanges` / autosave / `syncWithDatabase` non persistono stato incoerente su `HistoryEntry` (uscita anticipata o equivalente documentato).
- [x] **CA-5A**: Con `gridParallelArraysFault == true`, export/share XLSX (e ogni azione equivalente di condivisione griglia) è **bloccata** come save/sync (stessa famiglia di gate; vedi Decisione 6 e planning Fix A).

**Fix B — Cascade ProductPrice**
- [ ] **CA-1B**: `@Relationship(deleteRule: .cascade, inverse: \ProductPrice.product)` su `priceHistory` in `Product`; `ProductPrice.product` resta `var product: Product?` senza annotazione `@Relationship` reciproca (la doppia annotazione `inverse` su entrambi i lati causa circular macro expansion in SwiftData — limite confermato in execution). L'inverse ancorato solo sul lato `Product` è sufficiente perché SwiftData riconosce la relazione bidirezionale dal keypath `\ProductPrice.product` e gestisce correttamente cascade delete e grafo relazioni.
- [ ] **CA-2B**: Delete `Product` elimina `ProductPrice` associati nella stessa transazione.
- [ ] **CA-3B**: Build ok; avvio su DB preesistente; nessun effetto collaterale su `ProductPrice` di altri prodotti.

**Fix C — Backfill async**
- [x] **CA-1C**: `backfillIfNeeded()` non chiamato in modo sincrono bloccante sul main thread all’avvio.
- [ ] **CA-2C**: UI interattiva subito su DB grande (es. 1000+ prodotti) — verifica manuale o documentata.
- [x] **CA-3C**: Stesso risultato dati del backfill rispetto al comportamento precedente (foreground/background).
- [x] **CA-4C**: Il backfill async in `ContentView` è **schedulato al massimo una volta per launch** (stessa sessione processo); niente rilanci inutili su re-render / `.task` ripetuto (vedi Decisione 8).

## Decisioni
| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|-------|
| 1 | Bootstrap da TASK-014 senza planning tecnico completo in questo turno | Planning monolitico immediato | Attivazione backlog + file reale; planning a CLAUDE | superata |
| 2 | Fix A: un solo modulo di guardia (funzione / piccolo tipo privato) invocato dai punti **Hook: OBBLIGATORIO** (shape) in tabella A1–A16; niente logica duplicata inline | Controlli `count` sparsi e hook dopo ogni mutazione inclusi value-only | Contratto CA-1A + churn ridotto su value-only | attiva |
| 3 | Fix A: in caso di violazione, nessuna auto-riparazione silenziosa reattiva al check | Chiamare `ensureCompleteCapacity` / `normalizeParallelArrays` solo perché il check ha fallito | Allineato a «Non incluso» e TASK-014 | attiva |
| 4 | Fix B: `deleteRule: .cascade` + `inverse` esplicito su lato `Product` (keypath `\ProductPrice.product`); lato `ProductPrice.product` senza `@Relationship` reciproco per limite circular macro expansion SwiftData | Solo cascade senza inverse; doppia annotazione reciproca (non compilabile) | Coerenza modello grafo SwiftData e manutenzione relazione; limite macro confermato in execution | attiva |
| 5 | Fix C: backfill su `ModelContext` creato da `ModelContainer` condiviso, confinato a un actor/task che «possiede» quel context (mai `modelContext` della View su background) | `Task.detached` che usa `@Environment` `modelContext` fuori MainActor | Thread-safety SwiftData | attiva |
| 6 | Fix A — con `gridParallelArraysFault == true`, **export/share della griglia** (XLSX e equivalenti in `GeneratedView`) è **bloccato** come save/autosave/sync: niente file generato da stato `data`/`editable`/`complete` potenzialmente disallineato | Export da «snapshot coerente» alternativo (es. solo `entry` su disco) senza allineare prima la policy | Stessa linea di CA-4A: non esportare né persistere triple incoerenti; implementazione unica (guard su fault + messaggio/bottone disabilitato) | attiva |
| 7 | Fix A — oltre A1–A16, in **execution** vanno rivisti i path di **lettura/indexing** in `GeneratedView` che assumono ancora allineamento forte tra array (o indici validi senza guard) e possono crashare **prima** che la guardia post-mutazione segnali fault | Refactor globale UI fuori `GeneratedView` | Regola operativa Codex: stesso file, stesso obiettivo «nessun crash», senza ampliare perimetro task | attiva |
| 8 | Fix C — **single-run per launch**: una sola schedulazione utile del job backfill per sessione app (anche se `backfillIfNeeded` resta idempotente), per evitare fetch/work ripetuti su `.task` / ricomposizioni SwiftUI | Rieseguire backfill a ogni apparizione di `ContentView` | Riduce carico ridondante e race superficiali; coerente con CA-4C | attiva |
| 9 | Fix C — **implementazione single-run fissata**: flag **`@State private var didSchedulePriceHistoryBackfillThisLaunch`** (o nome equivalente documentato in Execution) in **`ContentView`**, impostato a `true` **sincrono** all’ingresso del `.task` **prima** di avviare il lavoro in background; **vietato** affidarsi a flag nell’actor/runner come fonte primaria di single-run | Flag solo nell’actor | Una sola strategia leggibile; SwiftUI ricrea le view: lo stato view è il punto di controllo naturale del `.task` | attiva |
| 10 | Fix A — **localizzazione**: ogni stringa **user-facing** nuova (banner invariante, messaggi legati a gate save/export, ecc.) usa chiavi **`L("…")`** / **`Localizable.xcstrings`**; **nessun** testo UI hardcoded (IT/EN) | Messaggi inline letterali | Coerenza con app multilingua e review stringhe | attiva |

---

## Planning (Claude)

### Obiettivo
Rendere robusti tre punti: coerenza `data` / `editable` / `complete` in `GeneratedView` (senza crash e senza riparazioni silenziose), cancellazione a cascata degli storici prezzo al delete di un `Product`, e backfill prezzi all’avvio senza bloccare il main thread, preservando l’algoritmo attuale di `PriceHistoryBackfillService`.

### Analisi
- **`GeneratedView`**: lo stato griglia è `@State` (`data`, `editable`, `complete`) più copie «snapshot» (`originalData`, `originalEditable`, `originalComplete`). Le mutazioni avvengono nel corpo principale della view e in una sotto-view con `@Binding` verso gli stessi array (sheet righe manuali). Due binding (`bindingForComplete`, `bindingForEditable`) possono **allungare** `complete` / `editable` senza allungare `data`, generando disallineamento. `syncWithDatabase()` fa `data = entry.data` senza riallineare necessariamente `editable`/`complete` allo stesso passo. Esistono già helper (`ensureCompleteCapacity`, `ensureEditableCapacity`, `normalizeParallelArrays`) che riallineano in alcuni flussi, ma non coprono tutti i percorsi né soddisfano il vincolo «niente riparazione silenziosa **come risposta al fallimento guardia**».
- **`Product` / `ProductPrice`**: oggi `Product.priceHistory` è `@Relationship` senza `deleteRule`; `ProductPrice.product` è opzionale. Eliminando un prodotto restano record `ProductPrice` orfani nello store.
- **Backfill**: `ContentView` invoca `PriceHistoryBackfillService.backfillIfNeeded(context: modelContext)` in `.task { }` sul **MainActor**; con molti prodotti il fetch + join + insert può congelare l’UI al primo frame utile. Il service è puro dato (nessun vincolo a cambiare la logica di business).

### Fix A — GeneratedView: punti di mutazione (A1–A16) e hook guardia

**Invariante verificato dalla guardia**: `data.count == editable.count == complete.count` (numero di **righe** / slice parallelo).

**Due classi** (per ridurre churn senza allentare il contratto CA):

| Classe | Criterio | Hook API guardia |
|--------|----------|------------------|
| **Shape / allineamento** | L’operazione può cambiare il **numero di righe** in almeno uno tra `data`, `editable`, `complete`, oppure sostituire interi array con conteggi potenzialmente diversi | **OBBLIGATORIO** subito dopo l’uscita dal blocco mutazione |
| **Value-only** | Solo valori di celle / elementi esistenti; i **tre `.count` riga** restano necessariamente quelli precedenti | **Non richiesto** per CA-1A; niente chiamata obbligatoria (opzionale in dev: assert/`debugPrint` solo se Codex lo documenta come tale — non parte del contratto review CA-1A) |

Elenco (linee indicative `GeneratedView.swift`, 2026-03-25):

| # | Hook | Area / funzione | Cosa muta | Note |
|---|------|-----------------|-----------|------|
| A1 | **OBBLIGATORIO** | `initializeFromEntryIfNeeded()` | `data`, `editable`, `complete`, snapshot `original*` | Carichi/sostituzioni che possono cambiare conteggi |
| A2 | **OBBLIGATORIO** | `bindingForComplete` (setter) | `complete` (può **append** righe) | Shape |
| A3 | **OBBLIGATORIO** | `bindingForEditable` (setter) | `editable` (può **append** righe; allunga per indice) | Shape |
| A4 | value-only | `bindingForCell` (setter) | `data[row][col]` | Solo contenuto cella; `.count` riga invariato |
| A5 | **OBBLIGATORIO** | `revertToOriginalSnapshot()` | sostituisce `data` / `editable` / `complete` | |
| A6 | **OBBLIGATORIO** | `revertToImportSnapshot()` + success path | sostituisce triple + `entry` | Dopo `saveChanges()` interno: comunque hook dopo shape |
| A7 | **OBBLIGATORIO** | `restoreRevertImportState(...)` | ripristina triple + `entry` | |
| A8 | **OBBLIGATORIO** | `deleteRow(at:)` | `remove` su tutti e tre | |
| A9 | **OBBLIGATORIO** | `handleScannedBarcode` | header, `append` riga, `editable`/`complete` | |
| A10 | value-only | `setComplete` / `markAllComplete` | `complete[i]`, colonna `complete` in `data` | Nessun cambio numero righe |
| A11 | value-only | `saveChanges()` | `entry`, `data = newData` | `newData` deriva da `data` con stesso numero righe |
| A12 | **OBBLIGATORIO** | `syncWithDatabase()` dopo sync | `data = entry.data` | **Alto rischio**: `entry.data` può avere conteggio ≠ `editable`/`complete` |
| A13 | **OBBLIGATORIO** | Sheet: `confirmAdd` | `data.append`, `editable`, `complete` | |
| A14 | value-only | Sheet: `confirmEdit` | `data[row]`, `editable[row]` | Stesso numero righe |
| A15 | **OBBLIGATORIO** | Sheet: `deleteCurrentRow` | `remove` + `normalizeParallelArrays()` | |
| A16 | value-only | Sheet: `addColumnIfMissing` | estende colonne nelle righe `data` | Non aggiunge righe; `data.count` invariato |

*Nota*: nuove mutazioni in execution → aggiungere riga in tabella con classificazione **OBBLIGATORIO** vs **value-only** prima di merge; se dubbio, trattare come **OBBLIGATORIO** finché non documentato altrimenti.

**Strategia unica centralizzata (non logica duplicata)**

1. Introdurre un unico punto di verità, es. `private enum GeneratedGridInvariant { ... }` o `private func evaluateParallelGridConsistency(...)`, che:
   - calcola `let nd = data.count`, `ne = editable.count`, `nc = complete.count`;
   - se `nd == ne == nc` → considera OK, azzera (o non imposta) lo stato UI di errore strutturale;
   - se diverso → **non** modificare gli array:
     - `debugPrint("[GeneratedView] INVARIANT_FAIL data=\(nd) editable=\(ne) complete=\(nc) context=<stringa statica passata dal chiamante>")` (prefisso fisso `[GeneratedView]` come CA-2A);
     - imposta uno stato dedicato, es. `@State private var gridParallelArraysFault: Bool` e opzionalmente `@State private var gridParallelArraysFaultDetail: String` con i tre numeri (per banner).

2. **UI non bloccante**: in cima al contenuto principale di `GeneratedView` (vicino ad altri messaggi tipo `saveError`), mostrare un banner / warning inline che spiega incoerenza griglia e suggerisce azioni utente sicure (es. ripristino snapshot / riapertura sessione). Nessun `alert` modale obbligatorio.

   **Localizzazione (Decisione 10)**: ogni stringa **visibile all’utente** introdotta o modificata per Fix A (banner, etichette gate export/save se dedicate, ecc.) deve passare da **`L("chiave.…")`** con voce in **`Localizable.xcstrings`** (o meccanismo di localizzazione già usato nel progetto). **Vietato** testo hardcoded in SwiftUI per quelle stringhe.

3. **Comportamento se l’invariante fallisce** (contratto esplicito):
   - **Mostrare**: banner persistente (o finché un flusso **previsto** — es. revert — ripristina coerenza, **senza** auto-fix nascosto) + `debugPrint` come sopra.
   - **Bloccare**: persistenza che scriverebbe triple incoerenti su `HistoryEntry` — in particolare `saveChanges()`, `autosaveIfNeeded()` / `flushAutosaveNow()`, e `syncWithDatabase()` devono uscire subito (o non aggiornare `entry`) quando `gridParallelArraysFault == true`, con messaggio coerente con il banner. Nessun `fatalError` per questo caso.
   - **Export / share (policy esplicita — Decisione 6)**: con `gridParallelArraysFault == true`, **qualsiasi** export o share che materializza la griglia inventario (es. XLSX da `data`/`editable`/`complete` correnti) è **bloccato** come la famiglia save/sync: niente generazione file da stato incoerente; UI disabilitata o stesso gate con feedback (es. messaggio già nel banner). *Alternativa esplicitamente scartata*: consentire export da «snapshot coerente» non allineato agli array UI (es. solo blob su disco) senza definire e testare un secondo percorso — fuori dal minimo necessario e rischio di export fuori da ciò che l’utente vede.
   - **Non fare**: nessun `ensureCompleteCapacity` / `normalizeParallelArrays` / append «a compensazione» **solo perché** il check ha rilevato errore; nessun silenzioso «allinea e continua» senza che l’utente veda il warning.

4. **Cosa resta consentito**: navigazione lettura, revert espliciti, chiusura vista — senza forzare modal. Dopo un revert/import snapshot riuscito, la guardia deve poter tornare OK e sbloccare save/sync **ed** export/share.

5. **Path di lettura crashabili (regola execution — Decisione 7)**: la tabella A1–A16 copre le **mutazioni**. In execution, nello **stesso** file `GeneratedView.swift`, vanno identificati e messi in sicurezza (guard, early return, accesso bounds-safe) i punti che **leggono** `data` / `editable` / `complete` con assunzioni forti (es. stesso indice su tutti e tre senza verifica) tali da poter ancora causare crash se gli array sono disallineati **nel breve intervallo** prima che la guardia segni fault, o in percorsi non coperti. Non è scope nuovo: resta dentro Fix A e obiettivo CA-3A «nessun crash».

   **Sito prioritario noto** (riga ~1639): `makeRowDetailData(for:headerRow:isComplete:autoFocusCounted:)` contiene `fatalError("makeRowDetailData: rowIndex out of range")` — crash garantito se `rowIndex` è fuori `data.indices`. Il chiamante `showRowDetail` guarda `data.indices` ma **non** verifica `complete.indices` prima di leggere `complete[rowIndex]` (riga ~1705). In execution: sostituire il `fatalError` con early return (o valore di fallback) e aggiungere bounds-check su `complete` in `showRowDetail`.

6. **Gate export/share — posizione del check**: `shareAsXLSX()` chiama `flushAutosaveNow()` **prima** di leggere `data` per export (riga ~2213). Il gate `gridParallelArraysFault` deve essere **in cima a `shareAsXLSX`**, prima di `flushAutosaveNow()` — non basta il gate su `saveChanges()` perché la funzione prosegue comunque a leggere `data` per generare il file XLSX.

**Criterio di review Fix A**: ogni riga con **Hook: OBBLIGATORIO** ha la chiamata alla funzione centralizzata post-mutazione (o wrapper `mutateGrid { }` documentato). Righe **value-only** senza hook non violano CA-1A. Export/share: Decisione 6 + punto 6 sopra (gate in cima a `shareAsXLSX`). Localizzazione: Decisione 10 (nessun testo UI hardcoded nuovo). Lettura/indexing: `fatalError` in `makeRowDetailData` rimosso (punto 5) + elenco breve in Execution o «nessun sito aggiuntivo dopo audit». Grep: nessun altro `debugPrint` per lo stesso scopo senza prefisso `[GeneratedView]`.

### Fix B — `Product.priceHistory` cascade

**Modifica esatta proposta (`Models.swift`)**

- Su `Product`:
  - da: `@Relationship var priceHistory: [ProductPrice] = []`
  - a: `@Relationship(deleteRule: .cascade, inverse: \ProductPrice.product) var priceHistory: [ProductPrice] = []`
- Su `ProductPrice`:
  - da: `@Relationship var product: Product?`
  - a: `var product: Product?` (plain stored property, senza `@Relationship`)

**Inverse: solo sul lato `Product`, motivato**
Il planning originale prevedeva `@Relationship(inverse:)` su entrambi i lati. In execution la doppia annotazione reciproca ha causato **circular macro expansion** (limite noto del macro system SwiftData). L'`inverse` ancorato solo su `Product.priceHistory` è sufficiente: SwiftData riconosce `\ProductPrice.product` come lato inverso dal keypath e gestisce cascade delete e coerenza del grafo relazioni. `ProductPrice.product` resta `var product: Product?` senza annotazione — SwiftData lo tratta come proprietà persistita relazionale grazie al tipo `Product` (`@Model`).

**Rischio migrazione / store esistente**

- SwiftData su disco di solito tollera aggiornamenti di metadati relazione, ma **non è garantito al 100% senza prova** su build con store preesistente.
- Rischio residuo: `ProductPrice` già orfani restano finché non ripuliti; la cascade non elimina orfani storici al solo deploy.
- **Piano di verifica store**: installare build con modifica su simulatore con dati esistenti; avvio senza crash; smoke su Database e Cronologia; conteggio prezzi prima/dopo delete di un solo `Product`.

**Test manuale dimostrativo (CA-2B / CA-3B)**

1. Due prodotti A e B con storico prezzi.
2. Annotare quanti `ProductPrice` totali e quanti legati ad A.
3. Eliminare **solo** A dalla UI Database.
4. **Atteso**: spariscono solo i `ProductPrice` di A; B intatto; nessun crash.
5. Caso prodotto senza storico: nessun effetto collaterale.

### Fix C — Backfill async e thread-safe SwiftData

**Vincolo**: `ModelContext` da `@Environment(\.modelContext)` in `ContentView` è legato al MainActor; **non** passarlo a `Task.detached` / executor non-MainActor.

**Meccanismo concreto**

1. In `ContentView.task`, ottenere `let container = modelContext.container`.
2. Eseguire il backfill in un contesto che **crea e possiede** un altro `ModelContext`: actor dedicato (es. runner con `ModelContext(container)` creato nell’actor) che chiama solo `PriceHistoryBackfillService.backfillIfNeeded(context:)`; oppure `@ModelActor` se preferito — equivalente se un solo ingresso e stesso vincolo di ownership del context.
3. **Non** usare `Task { @MainActor in ... }` per il carico pesante del backfill (non soddisfa CA-1C se il lavoro resta sul main).
4. **Risultato dati identico**: stesso corpo di `backfillIfNeeded`; stesso insert idempotente e `save()` sullo store. Dopo `save()` sul context di background, il main context vede il dato persistito; se l’UI ritarda, una sola `modelContext.processPendingChanges()` sul MainActor al termine (solo se verificato necessario).
5. Errori: log come oggi, senza bloccare le tab.

6. **Single-run per launch (Decisione 8–9 / CA-4C) — strategia unica**: in **`ContentView`** usare **`@State private var didSchedulePriceHistoryBackfillThisLaunch = false`**. All’ingresso del `.task` (o equivalente unico di avvio backfill): se `didSchedulePriceHistoryBackfillThisLaunch == true` → `return` immediato; altrimenti impostare **`didSchedulePriceHistoryBackfillThisLaunch = true` in modo sincrono sul MainActor** e **solo dopo** avviare `Task` / chiamata al runner che crea il `ModelContext` di background ed esegue `backfillIfNeeded`. **Non** usare un flag nell’actor/runner come **fonte primaria** del single-run (evita ambiguità se il runner viene ricreato). Obiettivo: un solo accodo lavoro per cold start anche se SwiftUI riesegue `.task` — **senza** cambiare la logica idempotente in `PriceHistoryBackfillService`.

**Piano test / verifica manuale (dataset grande)**

- ≥ 1000 `Product` con prezzi e senza copertura storico.
- Avvio: tab reattive mentre il backfill gira in background.
- Secondo avvio: idempotenza (nessun duplicato `BACKFILL`).

### Ordine di execution proposto (motivato): **B → C → A**

| Ordine | Fix | Motivazione |
|--------|-----|-------------|
| 1 | **B** | `Models.swift` piccolo, zero conflitto con `GeneratedView`, schema stabile prima di test che coinvolgono delete durante validazione C/A. |
| 2 | **C** | Isolato (`ContentView` + eventuale runner); elimina freeze avvio su DB grandi; indipendente da A. |
| 3 | **A** | `GeneratedView` enorme, massimo rischio merge; conviene per ultimo quando B/C sono verdi. |

*Alternativa solo con motivazione scritta in Execution.*

**Per ogni fix**

| Fix | File esatti | Rischio | Criterio di review (minimo) | Test minimo |
|-----|-------------|---------|----------------------------|-------------|
| A | `GeneratedView.swift` + `Localizable.xcstrings` (o file loc esistente) per nuove chiavi | Merge; path shape dimenticato | Hook **OBBLIGATORIO** A1–A16; Decisioni 6, 10; Decisione 7 lettura | Grep hook post-shape; BUILD; stringhe via `L(`; fault + export bloccato |
| B | `Models.swift` | Migrazione; relazione | Diff come sopra | BUILD; test manuale delete (sezione Fix B) |
| C | `ContentView.swift`, eventuale file runner; `PriceHistoryBackfillService` invariato salvo necessità documentata | Due context / merge UI | Mai `modelContext` view su background; **`@State` single-run in ContentView** (Decisione 9) | BUILD; 1000+ prodotti; idempotenza; una sola schedulazione per cold start |

### Handoff → Execution (CODEX)

- **Prossima fase**: EXECUTION  
- **Prossimo agente**: CODEX  
- **Azione consigliata**:
  1. Leggere questo task (Scopo, Non incluso, CA, Planning) e i file `Models.swift`, `ContentView.swift`, `GeneratedView.swift` nelle zone citate.
  2. **Fix B** → build → test manuale delete prodotto.
  3. **Fix C** → `ModelContainer` + `ModelContext` dedicato su actor/ownership corretto → build → test avvio DB grande.
  4. **Fix A** → API invariante + banner (`L` + xstrings, Decisione 10) + blocco save/sync/**export-share** su fault + hook solo su righe **OBBLIGATORIO** + audit lettura (Decisione 7) → build → grep.
  5. Compilare **Execution** e **Handoff post-execution** verso REVIEW (CLAUDE).

*Ordine B → C → A vincolante salvo nota motivata in Execution.*

---

## Execution (Codex)
### Modifiche fatte
- **Fix B — `Models.swift`**: aggiunto `deleteRule: .cascade` con `inverse: \ProductPrice.product` su `Product.priceHistory`. Tentativo iniziale di annotare anche `ProductPrice.product` con `@Relationship(inverse: \Product.priceHistory)` ha causato **circular macro expansion** SwiftData in build; per mantenere fix stretto e compilabile l’inverse esplicito resta ancorato sul lato `Product`, mentre `ProductPrice.product` resta property persisted plain. Nessun cleanup retroattivo/orfani storici introdotto.
- **Fix C — `ContentView.swift`**: introdotto actor dedicato `PriceHistoryBackfillRunner` che crea e possiede `ModelContext(modelContext.container)` off-main; `.task` ora fa solo scheduling single-run con `@State private var didSchedulePriceHistoryBackfillThisLaunch`, impostato sincrono prima dell’avvio del job. `PriceHistoryBackfillService.backfillIfNeeded(context:)` è rimasto invariato.
- **Fix A — `GeneratedView.swift`**: introdotta API centralizzata `evaluateParallelGridConsistency(context:)` con `debugPrint` prefissato `[GeneratedView]`, stato `gridParallelArraysFault`, banner inline localizzato e gate su autosave / `saveChanges()` / `syncWithDatabase()` / `shareAsXLSX()`. Hook applicati ai path shape-changing pianificati: `initializeFromEntryIfNeeded`, `bindingForComplete`, `bindingForEditable`, `revertToOriginalSnapshot`, `revertToImportSnapshot`, `restoreRevertImportState`, `deleteRow`, `handleScannedBarcode`, `syncWithDatabase`, `ManualEntrySheet.confirmAdd`, `ManualEntrySheet.deleteCurrentRow`.
- **Fix A — audit lettura crashabile**: rimosso `fatalError` in `makeRowDetailData(...)`; in caso di indice fuori range la view non crasha e logga skip con prefisso `[GeneratedView]`. Nessun altro sito aggiuntivo emerso dall’audit statico nei path toccati che richiedesse refactor fuori scope.
- **Localizzazione Fix A**: aggiunte sole nuove chiavi `generated.invariant.*` nei `Localizable.strings` `it` / `en` / `es` / `zh-Hans`; nessun testo UI hardcoded nuovo.

### File toccati
- `iOSMerchandiseControl/Models.swift`
- `iOSMerchandiseControl/ContentView.swift`
- `iOSMerchandiseControl/GeneratedView.swift`
- `iOSMerchandiseControl/en.lproj/Localizable.strings`
- `iOSMerchandiseControl/it.lproj/Localizable.strings`
- `iOSMerchandiseControl/es.lproj/Localizable.strings`
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`

### Check eseguiti
- ✅ **ESEGUITO — Build compila**: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` → **BUILD SUCCEEDED**.
- ✅ **ESEGUITO — Nessun warning nuovo introdotto (per quanto verificabile)**: build incrementale filtrata con `rg "warning:|Models\\.swift|ContentView\\.swift|GeneratedView\\.swift"` senza output; nessun warning emerso dai file toccati nel turno.
- ✅ **ESEGUITO — Modifiche coerenti con il planning**: ordine **B → C → A** rispettato; nessuna modifica alla business logic di `PriceHistoryBackfillService`; hook aggiunti solo sui path classificati **OBBLIGATORIO** e gate export in testa a `shareAsXLSX()`.
- ⚠️ **NON ESEGUIBILE — Criteri di accettazione verificati completamente**: non eseguiti in questo turno i test manuali su delete cascade prodotto/store preesistente (CA-2B/CA-3B) e reattività UI con dataset 1000+ prodotti (CA-2C). Nota tecnica per review: CA-1B del planning non è riproducibile letteralmente con il toolchain corrente perché il doppio `@Relationship(... inverse ...)` reciproco genera circular macro expansion.

### Rischi rimasti
- **Fix B**: resta da validare manualmente su store reale/preesistente che il delete di `Product` rimuova gli storici associati senza effetti collaterali; la semantica cascade è configurata, ma il planning va confrontato con il limite concreto del macro system SwiftData emerso in build.
- **Fix C**: manca verifica manuale prestazionale su dataset grande; staticamente il carico pesante non usa più il `modelContext` della view sul main thread.
- **Fix A**: i gate e il banner sono staticamente presenti; resta utile review mirata su eventuali path shape-changing non coperti fuori dai siti censiti in planning.

### Handoff post-execution → REVIEW (CLAUDE)
- **Fase proposta**: REVIEW
- **Responsabile proposto**: CLAUDE
- **Focus review richiesto**:
  1. Confermare che l’ancoraggio dell’inverse solo su `Product.priceHistory` sia accettabile come adattamento minimo del Fix B dato il blocco di build con doppia annotazione reciproca.
  2. Verificare staticamente i hook Fix A contro tabella A1–A16 e il gate export/save/sync.
  3. Valutare se CA-2B / CA-2C / CA-3B richiedano solo test manuali residui o un ulteriore fix/planning.

---

## Review (Claude)
### Problemi critici
- Nessuno.

### Problemi medi
- Nessuno.

### Miglioramenti opzionali
- Eventuali affinamenti UX/copy dopo test manuali (fuori scope se non emergono regressioni).

### Fix richiesti
- Nessuno.

### Esito
**APPROVED** — criteri verificabili in review tecnica soddisfatti per quanto documentato in execution; **nessun fix codice richiesto**. Restano **test manuali** (CA-2B, CA-3B, CA-2C e validazione store) **non eseguiti** in questo turno. Per **decisione utente** il task **non** passa a DONE: stato **BLOCKED** fino a validazione manuale e conferma finale.

### Handoff — sospensione (BLOCKED)
- **Motivo**: test manuali pendenti; task **non** DONE.
- **Alla ripresa**: eseguire test manuali pianificati (Fix B delete/cascade su store reale; Fix C reattività su DB grande; smoke Fix A se opportuno) → se regressioni, aprire **FIX** (CODEX) → **REVIEW** → conferma utente → DONE.

---

## Fix (Codex)
*(Non applicabile — review APPROVED, nessun fix richiesto. Eventuale FIX solo dopo test manuali se emergono regressioni.)*

---

## Chiusura
### Conferma utente
- [ ] Utente ha confermato il completamento *(differita — task BLOCKED per test manuali)*

### Follow-up candidate
- [Da compilare se necessario]

### Riepilogo finale
- Execution completata (Fix B/C/A). Review tecnica **APPROVED**, nessun fix richiesto. Chiusura **DONE** subordinata a test manuali utente e conferma esplicita.

### Data completamento
YYYY-MM-DD *(non impostata — task non DONE)*
