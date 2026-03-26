# TASK-027: ManualEntrySheet — modalità «Aggiungi e continua» (rapid entry)

## Informazioni generali
- **Task ID**: TASK-027
- **Titolo**: ManualEntrySheet: modalità «Aggiungi e continua» (rapid entry)
- **File task**: `docs/TASKS/TASK-027-manualentrysheet-aggiungi-e-prossimo.md`
- **Stato**: BLOCKED
- **Fase attuale**: — *(task **BLOCKED**; ultima fase di workflow chiusa: **REVIEW** con esito **APPROVED**; **DONE** solo dopo test manuali + conferma utente)*
- **Responsabile attuale**: **UTENTE** *(test manuali T-1…T-13)*; alla ripresa post-test **CLAUDE** (review finale / verso DONE) o **CODEX** (**FIX** se necessario)
- **Data creazione**: 2026-03-25
- **Ultimo aggiornamento**: 2026-03-25 *(execution **completata**; review **APPROVED** (OK); test manuali **non eseguiti**; task **BLOCKED** / pending manual verification; **non** **DONE**; planning tecnico **invariato**)*
- **Ultimo agente che ha operato**: CLAUDE *(review post-execution / allineamento tracking)*

## Stato operativo e sospensione (tracking 2026-03-25)
- **Implementation (Codex):** **completata** secondo planning e CA (nessun dettaglio implementativo modificato in questo aggiornamento).
- **Review (Claude):** **completata** — esito **APPROVED** / OK; nessun ciclo **FIX** richiesto dalla review.
- **Test manuali** (piano T-1…T-13 nel file task): **non eseguiti** in questo turno.
- **Chiusura:** task **non** **DONE**. Stato **BLOCKED** — *on hold for manual verification*.
- **Alla ripresa:** eseguire test manuali → eventuale **FIX** (Codex) → **REVIEW** (Claude) → conferma utente → **DONE**.

## Dipendenze
- **Dipende da**: nessuno (origine: audit iOS vs Android 2026-03-25 — gap funzionale su entry manuale rapida).
- **Sblocca**: parità UX con Android su inserimenti consecutivi da **`ManualEntrySheet`** (`GeneratedView.swift`).

## Scopo
Introdurre una modalità (copy UI: **«Aggiungi e continua»** / chiave `generated.manual.add_and_continue`) che permetta, dopo l’aggiunta di una riga manuale all’inventario, di **preparare immediatamente** l’inserimento della **riga successiva** con meno attrito rispetto al flusso attuale che richiede di **chiudere e riaprire** il foglio per ogni articolo — **senza** rimuovere il comportamento **salva e chiudi** esistente salvo decisione esplicita in planning.

## Contesto
- Su Android è prevista una modalità di **rapid entry** nell’aggiunta manuale; su iOS **`ManualEntrySheet`** è definito in **`GeneratedView.swift`** e oggi non espone un flusso equivalente documentato nel backlog.
- Task inserito in tabella backlog **MASTER-PLAN** (2026-03-25); questo file materializza il path canonico richiesto dal workflow progetto.

## Non incluso
- Refactor non necessario di **`GeneratedView`** oltre al perimetro che il **planning** definirà esplicitamente.
- Nuove dipendenze SPM senza richiesta esplicita.
- Parità riga-per-riga col codice Kotlin (solo riferimento funzionale).

## File coinvolti
- `iOSMerchandiseControl/GeneratedView.swift` — `ManualEntrySheet`: nuova funzione `resetForNextEntry()`, CTA localizzata «Aggiungi e continua» (chiave sotto) nel body, logica `@FocusState` per campo barcode (solo dopo rapid entry, v. D-9).
- `iOSMerchandiseControl/en.lproj/Localizable.strings` — nuova chiave `generated.manual.add_and_continue`.
- `iOSMerchandiseControl/it.lproj/Localizable.strings` — nuova chiave `generated.manual.add_and_continue`.
- `iOSMerchandiseControl/es.lproj/Localizable.strings` — nuova chiave `generated.manual.add_and_continue`.
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings` — nuova chiave `generated.manual.add_and_continue`.

Nessun altro file coinvolto. Il call site `.sheet(isPresented: $showManualEntrySheet)` (GeneratedView riga ~442) **non richiede modifiche**: il binding `isPresented` resta invariato; lo sheet si chiude solo tramite cancel o conferma toolbar (salva e chiudi), non tramite la CTA rapid entry.

## Criteri di accettazione
Questi criteri sono il contratto del task; verificabili in review.

- [ ] **CA-1**: In add mode, il pulsante toolbar "Conferma" (save & close) funziona esattamente come oggi: aggiunge la riga, chiude lo sheet. Nessuna regressione.
- [ ] **CA-2**: In add mode, una CTA con copy **«Aggiungi e continua»** (via `L("generated.manual.add_and_continue")`) è visibile nel Form (sotto le sezioni esistenti). **Non** visibile in edit mode.
- [ ] **CA-3**: Premere la CTA rapid entry (it: **«Aggiungi e continua»**) con dati validi: la riga viene aggiunta a `data`/`editable`/`complete` come con conferma normale; lo sheet **non** si chiude; i campi barcode, productName, retailPrice, purchasePrice si resettano a `""`; quantity torna a `"1"`; `productFromDb` torna a `nil`; `barcodeError` torna a `nil`; **categoria**: restano invariati sia la selezione picker standard (`categoryPickerSelection` / `selectedCategoryName`) sia l’eventuale **fallback raw** già nello stato del form (**`rawCategoryString`** e stato equivalente legato a categorie mancanti/non localizzate — il reset **non** deve toccarli); il focus torna sul campo barcode **solo** in questo caso (non alla prima apertura dello sheet; v. D-9).
- [ ] **CA-4**: La validazione della CTA rapid entry è identica a `canConfirm` (barcode non vuoto, retailPrice > 0, **quantity vuota o numerica** — come `isQuantityValid` nel codice attuale, senza rendere la quantity obbligatoria; nessuna nuova regola che imponga quantity compilata salvo decisione esplicita documentata; per questo task si mantiene il comportamento attuale per minimizzare regressioni), no `barcodeError`, no `headerError`. Il pulsante è disabilitato se `canConfirm` è false.
- [ ] **CA-5**: Un barcode duplicato (già presente nella griglia) viene bloccato da `barcodeError` come oggi — sia con conferma sia con la CTA rapid entry.
- [ ] **CA-6**: Edit mode è invariato: toolbar cancel + conferma, sezione delete, nessuna CTA rapid entry.
- [ ] **CA-7**: La chiave `generated.manual.add_and_continue` è presente in tutti e 4 i file `.lproj` (en, it, es, zh-Hans) con i valori indicati in planning (it: "Aggiungi e continua", en: "Add & continue", es: "Añadir y continuar", zh-Hans: "添加并继续").
- [ ] **CA-8**: Build Debug compila senza errori; nessun nuovo warning evitabile introdotto.
- [ ] **CA-9**: **Invariante riga nuova (add)**: sia con toolbar "Conferma" sia con la CTA rapid entry («Aggiungi e continua» in it), la riga manuale appena aggiunta mantiene il comportamento attuale di add — in particolare **`complete[newIndex] = false`** dopo l’aggiornamento di `complete`; **non** introdurre auto-completamento della riga appena inserita.
- [ ] **CA-10**: **Semantica salvataggio**: `ManualEntrySheet` **non** introduce `context.save()`, `flushAutosaveNow()` né altra persistenza sincrona nuova; `performAdd()` chiude il flusso dati **come oggi** invocando **solo** `onSave()` (oltre alle mutazioni in-memory già previste). L’autosave resta responsabilità del livello esterno (`GeneratedView` / callback esistenti); nessun cambio architetturale nascosto del save.

## Decisioni
| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|-------|
| D-1 | Save & close invariato: toolbar "Conferma" continua a chiudere lo sheet | Sostituire con rapid-only | Requisito utente: nessuna regressione al flusso esistente | APPROVATA |
| D-2 | CTA rapid entry («Aggiungi e continua» in it) solo in add mode, non in edit mode | Anche in edit mode | Requisito utente: edit mode invariato | APPROVATA |
| D-3 | CTA interna al Form (Button in una Section dedicata in fondo), non terza action in toolbar | Terzo ToolbarItem | Coerenza UI iOS — la toolbar mantiene solo cancel + conferma | APPROVATA |
| D-4 | Dopo rapid entry: reset barcode/name/prices, quantity→"1"; **preservare** picker categoria **e** eventuale fallback **`rawCategoryString`** / stato equivalente (missing-local); il reset **non** tocca questi campi | Reset anche categoria / raw | Requisito utente: stessa famiglia di prodotto e stesso testo categoria non risolto restano tra un inserimento e l’altro | APPROVATA |
| D-5 | Nessun toggle/preferenza aggiuntiva | Setting per abilitare/disabilitare rapid entry | Requisito utente: niente overengineering | APPROVATA |
| D-6 | Validazione rapid entry = `canConfirm` attuale: quantity **vuota o numerica** (`isQuantityValid`); nessuna nuova obbligatorietà su quantity | Rendere quantity sempre obbligatoria per la CTA rapid entry | Allineamento al codice reale; minimizzare regressioni; CA-4 esplicita | APPROVATA |
| D-7 | Riga nuova manuale: `complete[newIndex] = false` come oggi; **nessun** auto-complete sulla riga appena aggiunta (entrambe le CTA add) | Marcare completata automaticamente dopo add | Parità col flusso add attuale; CA-9 | APPROVATA |
| D-8 | Persistenza: solo catena esistente via **`onSave()`** nello sheet; niente `context.save()` / `flushAutosaveNow()` / save sincrono nuovo in `ManualEntrySheet` | Forzare flush SwiftData dallo sheet | CA-10; evitare regressioni e cambi architetturali | APPROVATA |
| D-9 | **Nessun autofocus** sul campo barcode alla **prima** apertura dello sheet; il focus programmatico sul barcode avviene **solo** dopo tap sulla CTA rapid entry («Aggiungi e continua») tramite `resetForNextEntry()` | Autofocus tastiera all’apertura | Su iOS evitare apertura invasiva immediata della tastiera; rapid entry resta veloce nei cicli successivi | APPROVATA |

---

## Planning (Claude) ← solo Claude aggiorna questa sezione

### Obiettivo
Aggiungere a `ManualEntrySheet` (solo add mode) una CTA con copy **«Aggiungi e continua»** (chiave `generated.manual.add_and_continue`) che salva la riga corrente e prepara immediatamente il form per un nuovo inserimento, senza chiudere lo sheet. Il flusso **save & close** attuale (toolbar "Conferma") resta invariato.

### Analisi del codice esistente

**`ManualEntrySheet`** è una `private struct` in `GeneratedView.swift` (riga ~2386). Punti rilevanti:

1. **Mode**: enum `Mode { case add; case edit(Int) }` — derivato da `editIndex: Int?`. La CTA va mostrata solo quando `mode == .add`.
2. **Validazione**: computed property `canConfirm` (riga ~2494) verifica: `headerError == nil`, barcode non vuoto, `retailPrice > 0`, `barcodeError == nil`, `isQuantityValid`. La stessa validazione si applica alla CTA rapid entry.
3. **Persistenza**: `confirmAdd()` (riga ~2677) esegue: `prepareColumnsForSave()`, `makePersistedValues()`, append a `data`, setup `editable`/`complete` (**`complete[newIndex] = false`** — comportamento add attuale, **senza** auto-complete della riga), chiama `onShapeMutation` + **`onSave()`** (nessun altro save sincrono nello sheet), poi `dismiss()`. La rapid entry riusa la stessa logica tranne `dismiss()`. **`ManualEntrySheet` non deve introdurre `context.save()`, `flushAutosaveNow()` o analoghi**: solo `onSave()` come oggi; autosave/debounce restano nel livello esterno.
4. **Lookup DB**: `.task(id: barcode)` chiama `refreshBarcodeLookup()` che aggiorna `productFromDb` e `barcodeError`. Dopo la CTA rapid entry, **`resetForNextEntry()` deve azzerare esplicitamente anche `productFromDb` e `barcodeError`** (oltre a svuotare `barcode`) per evitare UI stale; il `.task` resta utile al ciclo successivo ma non va considerato l’unico meccanismo di pulizia immediata.
5. **Categoria**: gestita da `categoryPickerSelection`, `selectedCategoryName`, **`rawCategoryString`** (e stato equivalente per categorie mancanti / non localizzate). Dopo rapid entry il reset **non** deve toccare **nessuno** di questi: si preserva sia la selezione picker “valida” sia l’eventuale **fallback raw** già presente nel form.
6. **Focus**: aggiungere `@FocusState` **solo** per il refocus dopo rapid entry (**D-9**): **nessun** `isBarcodeFieldFocused = true` su prima apertura dello sheet (`onAppear`, `task` iniziale, ecc.). Dopo «Aggiungi e continua», in `resetForNextEntry()`, provare **per prima** `DispatchQueue.main.async { isBarcodeFieldFocused = true }`; usare **delay esplicito** (`asyncAfter`) solo se, dopo prova su simulatore/dispositivo, il focus non si stabilizza senza.

### Approccio

**Modifica singola: `ManualEntrySheet` in `GeneratedView.swift`** + stringhe localizzate.

#### Step 1 — `@FocusState` per campo barcode
Aggiungere a `ManualEntrySheet`:
```swift
@FocusState private var isBarcodeFieldFocused: Bool
```
Applicare `.focused($isBarcodeFieldFocused)` al `TextField` barcode (riga ~2514). **Non** impostare il focus alla prima comparsa dello sheet: niente autofocus in `onAppear` o equivalente — **D-9**. L’unico momento in cui il codice imposta il focus sul barcode è **`resetForNextEntry()`** dopo «Aggiungi e continua».

#### Step 2 — Funzione `resetForNextEntry()`
Nuova funzione privata in `ManualEntrySheet`. **Non** affidarsi solo al `.task(id: barcode)` per pulire lo stato dopo «Aggiungi e continua»: azzerare **esplicitamente** anche `productFromDb` e `barcodeError` così la sezione dati da DB e gli errori non restano visibili un frame o più in stato obsoleto.
```swift
private func resetForNextEntry() {
    barcode = ""
    productName = ""
    retailPrice = ""
    purchasePrice = ""
    quantity = "1"
    productFromDb = nil
    barcodeError = nil
    DispatchQueue.main.async {
        isBarcodeFieldFocused = true
    }
}
```
**Non** tocca: `categoryPickerSelection`, `selectedCategoryName`, `rawCategoryString` (né altro stato equivalente al fallback categoria), `headerError`, `didLoadInitialValues`.

**Refocus**: preferire la `async` sul main come sopra; **non** introdurre `asyncAfter` con delay fisso salvo evidenza che il focus fallisce senza (documentare in handoff post-execution se usato).

#### Step 3 — Helper condiviso + `confirmAdd()` / `confirmAddAndNext()`
**Obbligatorio**: estrarre la logica comune di `confirmAdd()` in un helper privato condiviso (es. `performAdd() -> Bool` oppure `-> Int?` se serve propagare un indice — la firma esatta è a Codex, purché il contratto sia chiaro: successo/fallimento senza duplicare il corpo).

- **`performAdd()`**: contiene **tutto** il corpo attuale di `confirmAdd()` fino a `onSave()` (inclusi `prepareColumnsForSave()`, costruzione riga, `makePersistedValues()`, assegnazioni a `editable` / `complete` come oggi), nello **stesso ordine**. **Invariante**: per la nuova riga, **`complete[newIndex] = false`** come nel codice attuale; **non** impostare `complete` a `true` né introdurre logica di auto-completamento. Punto di riferimento per la mutazione dati: **`data.append(...)`** → **`ensureEditableCapacity`** → aggiornamento celle `editable` → **`ensureCompleteCapacity`** → **`complete[newIndex] = false`** → **`onShapeMutation`** → **`onSave()`** (unica chiusura del flusso persistenza lato sheet — **nessun** `context.save()`, `flushAutosaveNow()` o save sincrono aggiuntivo). Nessuna `dismiss()`, nessun reset form.
- **`confirmAdd()`**: `performAdd()` (se successo) + `dismiss()` — comportamento save & close invariato rispetto a oggi.
- **`confirmAddAndNext()`**: `guard case .add` come oggi; `performAdd()` (se successo) + `resetForNextEntry()` — nessuna `dismiss()`.

Non duplicare il blocco di persistenza in due funzioni: un solo percorso nel helper evita regressioni su uno dei due pulsanti.

#### Step 4 — CTA nel body
Dopo la sezione edit-mode delete (riga ~2606), aggiungere una `Section` visibile solo in add mode:
```swift
if !isEditMode {
    Section {
        Button(L("generated.manual.add_and_continue")) {
            confirmAddAndNext()
        }
        .disabled(!canConfirm)
    }
}
```
Stile: `Button` standard in `Section` (coerente col pulsante "Elimina" in edit mode). Non serve `.buttonStyle(.borderedProminent)` — lasciare lo stile di default del Form.

#### Step 5 — Stringhe localizzate
Aggiungere una sola chiave in ciascun file `.lproj`:
| Chiave | en | it | es | zh-Hans |
|--------|----|----|----|----|
| `generated.manual.add_and_continue` | `"Add & continue"` | `"Aggiungi e continua"` | `"Añadir y continuar"` | `"添加并继续"` |

### File coinvolti (definitivi)
| File | Tipo modifica | Righe indicative |
|------|--------------|-----------------|
| `iOSMerchandiseControl/GeneratedView.swift` | Modifica | ~2386–2910 (ManualEntrySheet) |
| `iOSMerchandiseControl/en.lproj/Localizable.strings` | Aggiunta 1 riga | dopo riga ~441 |
| `iOSMerchandiseControl/it.lproj/Localizable.strings` | Aggiunta 1 riga | dopo equivalente |
| `iOSMerchandiseControl/es.lproj/Localizable.strings` | Aggiunta 1 riga | dopo equivalente |
| `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings` | Aggiunta 1 riga | dopo equivalente |

Nessun altro file. Il call site dello sheet (riga ~442) non cambia.

### Rischi
| # | Rischio | Mitigazione |
|---|---------|-------------|
| R-1 | **Coerenza data/editable/complete dopo rapid entry**: se `confirmAddAndNext()` non chiama `onShapeMutation` + `onSave`, gli array paralleli divergono | Riusare esattamente la stessa sequenza di `confirmAdd()` (append data, ensureEditableCapacity, ensureCompleteCapacity, onShapeMutation, onSave) — l'unica differenza è l'assenza di `dismiss()` |
| R-2 | **Regressione edit mode**: la CTA potrebbe apparire anche in edit mode per errore | Guard `if !isEditMode` sulla Section; in review verificare che la condizione sia presente |
| R-3 | **Focus tastiera dopo reset**: `@FocusState` potrebbe non attivarsi nello stesso ciclo del reset | **Prima** prova: `DispatchQueue.main.async { isBarcodeFieldFocused = true }` alla fine di `resetForNextEntry()`; **solo se** dopo test reale il focus ancora fallisce, valutare `asyncAfter` con delay minimo e documentare |
| R-4 | **Testi lunghi in localizzazione**: "Aggiungi e continua" / "Añadir y continuar" potrebbero troncarsi su schermi piccoli | Stringhe scelte corte (max ~22 char). Su iPhone SE il Form `Section` fa wrap naturale. Rischio basso |
| R-5 | **`didLoadInitialValues` dopo reset**: se `resetForNextEntry()` non gestisce correttamente questo flag, `loadInitialValuesIfNeeded()` potrebbe non rieseguirsi o sovrascrivere il reset | `didLoadInitialValues` resta `true` dopo il primo caricamento — `loadInitialValuesIfNeeded()` non riesegue, quindi il reset manuale dei campi in `resetForNextEntry()` è sufficiente e non viene sovrascritto |

### Test plan manuale

| # | Scenario | Azione | Risultato atteso |
|---|----------|--------|-----------------|
| T-1 | Save & close invariato | Aprire ManualEntrySheet in add → compilare campi validi → premere "Conferma" (toolbar) | Riga aggiunta, sheet si chiude |
| T-2 | Rapid entry base | Aprire ManualEntrySheet in add → compilare campi validi → premere «Aggiungi e continua» | Riga aggiunta alla griglia, sheet resta aperto, campi barcode/name/prices svuotati, quantity = "1", categoria invariata (picker + eventuale `rawCategoryString` / fallback), focus su barcode; **alla sola apertura** dello sheet la tastiera **non** deve comparire automaticamente sul barcode (D-9) |
| T-3 | Rapid entry consecutivo | Dopo T-2, inserire un secondo prodotto con barcode diverso → premere «Aggiungi e continua» | Seconda riga aggiunta, form resettato di nuovo, 2 righe nella griglia |
| T-4 | Rapid entry poi save & close | Dopo T-3, compilare un terzo prodotto → premere "Conferma" (toolbar) | Terza riga aggiunta, sheet si chiude, 3 righe nella griglia |
| T-5 | Barcode duplicato dopo rapid entry | Dopo aver aggiunto un prodotto con rapid entry, inserire lo stesso barcode | `barcodeError` appare, entrambi i pulsanti (Conferma e «Aggiungi e continua») disabilitati |
| T-6 | Validazione su rapid entry | Campo barcode vuoto o retailPrice ≤ 0 → guardare «Aggiungi e continua» | Pulsante disabilitato |
| T-7 | Edit mode invariato | Tap su riga esistente → aprire ManualEntrySheet in edit mode | Nessuna CTA rapid entry visibile; toolbar cancel + conferma; sezione delete presente |
| T-8 | Categoria preservata (picker + raw) | Caso A: selezionare categoria X dal picker → «Aggiungi e continua» → verificare. Caso B: se il form consente uno stato con **solo** testo/raw categoria (es. `rawCategoryString` / missing-local), ripetere rapid entry e verificare che quel fallback **non** venga azzerato | Stessa selezione picker e stesso raw/fallback che prima del reset |
| T-9 | Autosave dopo rapid entry | Dopo rapid entry, verificare che l'autosave si attivi | `onSave()` chiamato → `markDirtyAndScheduleAutosave()` si attiva normalmente |
| T-10 | Build Debug | Build su simulatore | Nessun errore, nessun warning evitabile nuovo |
| T-11 | Sezione dati DB dopo rapid entry | In add mode, inserire barcode che mostra la sezione "dati da database" (o equivalente visibile nel form) → premere «Aggiungi e continua» | Subito dopo il reset, la sezione non è più visibile (nessuno stato stale da `productFromDb` / lookup precedente) |
| T-12 | Scanner dopo rapid entry ripetuti | Con scanner disponibile nel dialog manuale, eseguire uno o più «Aggiungi e continua» consecutivi, usando lo scanner tra un inserimento e l’altro | Lo scanner continua a popolare correttamente il barcode (nessun blocco o stato incoerente dopo rapid entry) |
| T-13 | Riga non completata dopo rapid entry | Dopo «Aggiungi e continua» con dati validi, chiudere lo sheet (o ispezionare la griglia senza chiudere, se visibile) e verificare lo stato della riga appena aggiunta | La nuova riga risulta **ancora non completata** come nel flusso add attuale (stesso criterio UI/completamento che per una riga aggiunta con "Conferma"); nessun auto-complete |

### Handoff post-planning → EXECUTION (Codex)
- **Stato handoff (storico):** planning → execution **consumato**; implementation **completata** (vedi sezione **Execution**).
- **Nota 2026-03-25:** al momento del blocco task, l’handoff verso **EXECUTION** non è più l’azione corrente.
- **Prossima fase (storico al momento dell’apertura execution):** EXECUTION
- **Prossimo agente (storico):** CODEX
- **Azione consigliata**:

1. Leggere `ManualEntrySheet` in `GeneratedView.swift` (righe ~2386–2910).
2. Implementare nell'ordine: Step 1 (`@FocusState` + `.focused` sul barcode, **senza** autofocus alla prima apertura — D-9), Step 2 (`resetForNextEntry()` con reset esplicito DB/error, preservazione categoria/raw, refocus via `DispatchQueue.main.async { … }`, delay solo se necessario), Step 3 (helper `performAdd()` con `complete[newIndex] = false` e **solo** `onSave()` — niente `context.save()` / `flushAutosaveNow()`; `confirmAdd()` / `confirmAddAndNext()` come da planning), Step 4 (CTA nel body con `L("generated.manual.add_and_continue")`).
3. Aggiungere la chiave `generated.manual.add_and_continue` nei 4 file `.lproj` con le stringhe indicate nella tabella Step 5.
4. Verificare build Debug senza errori/warning.
5. **Non** modificare: toolbar, edit mode, `confirmEdit()`, `deleteCurrentRow()`, call site `.sheet`, nessun altro file; **non** aggiungere save SwiftData sincrono nello sheet (CA-10).
6. Compilare handoff post-execution con evidenza di build e note per review.

---

## Execution (Codex) ← solo Codex aggiorna questa sezione

**Tracking 2026-03-25:** execution **completata** (implementazione conforme al planning: helper condiviso `performAdd()`, CTA «Aggiungi e continua» / `generated.manual.add_and_continue`, vincoli su `onSave()` / `complete[newIndex]` / autofocus, perimetro `GeneratedView.swift` + localizzazioni). Evidenza build e checklist dettagliate: come da handoff post-execution redatto dall’executor nel corso del lavoro.

### Handoff post-execution → REVIEW (Claude)
- **Stato (storico):** execution chiusa; passaggio a **REVIEW** effettuato.
- **Prossima fase:** REVIEW *(completata — vedi sotto)*

---

## Review (Claude) ← solo Claude aggiorna questa sezione

**Esito:** **APPROVED** (OK) — criteri coperti dalla review risultano soddisfatti; **nessun** **FIX** richiesto dalla review.

**Test manuali:** **non eseguiti** in questa fase; restano **requisito** per dichiarare il task **DONE** e per uscire dallo stato **BLOCKED** (insieme alla conferma utente).

**Problemi:** nessun problema critico/medio bloccante emerso dalla review documentata qui.

### Handoff post-review → validazione manuale / chiusura
- **Prossima azione consigliata:** **UTENTE** esegue il test plan manuale (T-1…T-13 nel planning).
- **Prossimo agente dopo i test:** **CLAUDE** (eventuale review finale minima / verso **DONE**) oppure **CODEX** (**FIX** solo se emergono regressioni → poi **REVIEW**).

---

## Fix (Codex) ← solo Codex aggiorna questa sezione

_(Nessun fix richiesto dalla review **APPROVED** — 2026-03-25.)_

---

## Chiusura

### Conferma utente
- [ ] Utente ha confermato il completamento

### Follow-up candidate
- _(eventuale — da aggiornare in chiusura)_

### Riepilogo finale
_(al DONE)_

### Data completamento
_(al DONE)_
