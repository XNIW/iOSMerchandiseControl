# TASK-018: GeneratedView — secondo livello revert (ai dati originali import)

## Informazioni generali
- **Task ID**: TASK-018
- **Titolo**: GeneratedView: secondo livello revert (ai dati originali import)
- **File task**: `docs/TASKS/TASK-018-generatedview-second-level-revert.md`
- **Stato**: BLOCKED
- **Fase attuale**: REVIEW *(sospesa — task non attivo progetto; ultima fase operativa prima della sospensione)*
- **Responsabile attuale**: UTENTE *(test manuali CA-7 obbligatori pendenti: S-1, M-1..M-10, M-12; se regressioni → segnalare per FIX/CODEX)*
- **Data creazione**: 2026-03-24
- **Ultimo aggiornamento**: 2026-03-25 (**user override / tracking**) — review codice **APPROVED** (nessun fix richiesto); **test manuali non eseguiti**; task **non** DONE; focus progetto su **TASK-019**
- **Ultimo agente che ha operato**: CLAUDE *(review + riallineamento tracking)*

## Dipendenze
- **Dipende da**: nessun blocco duro (nota TASK-014: idealmente post-TASK-008 DONE per ridurre conflitti su `GeneratedView`; TASK-008 resta BLOCKED per test manuali — non prerequisito formale nel MASTER-PLAN).
- **Sblocca**: chiusura GAP-03 (parity revert Android); vedi audit TASK-014.

## Scopo
Implementare un **secondo livello** di revert in `GeneratedView` che riporti la griglia (e lo stato editing associato) allo snapshot **immutabile** dell’import creato in `generateHistoryEntry()`. Il livello 1 resta il revert allo stato caricato all’**apertura corrente** della schermata.

## Contesto
Origine: **TASK-014** (GAP-03). Su Android esistono due livelli di revert; iOS dopo TASK-004 espone un solo revert, insufficiente se l’utente ha già autosalvato e riaperto la sessione.

## Non incluso
- Modifica della **semantica** del revert di livello 1 (stesso algoritmo: ripristino da `originalData` / `originalEditable` / `originalComplete` catturati al primo `initializeFromEntryIfNeeded()` della vista).
- Reset di **title** / **supplier** / **category** da `EntryInfoEditor` (metadati non fanno parte dello snapshot griglia).
- Modifiche a **PreGenerate**, **ExcelAnalyzer**, **InventorySyncService** (salvo tocco minimo elencato sotto se strettamente necessario — **vietato** salvo emergenza documentata).
- Nuove dipendenze SPM.

## File coinvolti (definitivi)

| File | Motivazione |
|------|-------------|
| `iOSMerchandiseControl/HistoryEntry.swift` | Il modello SwiftData **`HistoryEntry`** è definito **qui**, non in `Models.swift`. Aggiungere proprietà persistita opzionale per lo snapshot import. |
| `iOSMerchandiseControl/ExcelSessionViewModel.swift` | `generateHistoryEntry(in:)` costruisce `filteredData` e, con encoding **fail-fast**, popola `originalDataJSON` **una sola volta**. Delega a helper condiviso (file dedicato sotto) per template editable + summary — **nessun** accoppiamento semantico di `GeneratedView` → `ExcelSessionViewModel` per utility. |
| `iOSMerchandiseControl/HistoryImportedGridSupport.swift` *(nuovo, nome esatto a discrezione se coerente)* | Helper **puri** nel target: `editableTemplate(forGrid:)`, `initialSummary(forGrid:)` (stessa semantica di oggi `createEditableValues` / `calculateInitialSummary`). Usato da `generateHistoryEntry` **e** da L2 in `GeneratedView`. File-private o `enum` namespace senza stato. |
| `iOSMerchandiseControl/GeneratedView.swift` | Menu ⋯, dialog conferma, azione L2, aggiornamento `@State` + `HistoryEntry` + persistenza immediata. |
| `iOSMerchandiseControl/it.lproj/Localizable.strings` | Nuove stringhe L1/L2 + dialog L2 (IT). |
| `iOSMerchandiseControl/en.lproj/Localizable.strings` | Idem EN. |
| `iOSMerchandiseControl/es.lproj/Localizable.strings` | Idem ES. |
| `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings` | Idem zh-Hans. |

**Nota**: `Models.swift` contiene solo `HistorySyncStatus` e modelli prodotto — **non** ospita `HistoryEntry`.

## Criteri di accettazione
- [ ] **CA-1**: In `generateHistoryEntry()`, subito dopo aver costruito la matrice finale `filteredData` (stessa struttura oggi passata a `HistoryEntry(data:)`), il campo persistito **`originalDataJSON`** contiene l’encoding JSON di `[[String]]` di **quella** matrice e **non** viene mai riscritto da autosave, `saveChanges`, sync, delete row, manual row, né da altro codice.
- [ ] **CA-2**: In `GeneratedView` esiste un secondo comando revert, distinto dal primo, con etichetta e dialog dedicati (vedi sezione UX).
- [ ] **CA-3**: Dopo conferma utente, il revert L2 ripristina griglia + stato editing + totali come da planning; **persistenza immediata** tramite **`saveChanges()`** in `GeneratedView` (§4.3); niente solo “dirty” senza salvataggio; eccezioni solo se documentate in Execution/Review per impedimento tecnico.
- [ ] **CA-4**: Se `originalDataJSON == nil` (entry legacy o inventario manuale), la voce di menu per il revert L2 **non compare** (comportamento unico scelto: **nascosta**, non disabilitata).
- [ ] **CA-5**: Dopo revert L2, `syncStatus == .notAttempted` e `wasExported == false` (allineamento allo stato immediatamente post-`generateHistoryEntry()`).
- [ ] **CA-6**: Il revert L1 (`revertToOriginalSnapshot`) mantiene lo stesso comportamento di oggi; eventuali cambi limitati a **testi** localizzati per chiarezza (vedi UX) non alterano la logica.
- [ ] **CA-7**: Copertura manuale: **obbligatori** — matrice §7 **M-1..M-10** + smoke **S-1** + test persistenza forte **M-12** (allineato a *Vincoli execution / review*); **M-11** *(opzionale, consigliato)* — eseguiti o documentati con esito dove applicabile.

## Decisioni
| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|-------|
| 1 | Bootstrap tracking senza planning completo | — | Sostituita da planning execution-ready | **OBSOLETA** |
| 2 | Proprietà SwiftData: `originalDataJSON: Data?` — JSON di `[[String]]` identico a `entry.data` al momento di `generateHistoryEntry()` | Nome file diverso da CA | Allineamento ai CA del task; formato uguale a `dataJSON` | attiva |
| 3 | Snapshot contiene **solo** la griglia `data` (matrice); `editable` e `complete` si **rigenerano** con la stessa logica di creazione (template qty/retail vuoti; complete tutti `false`) | Snapshot triplo (data+editable+complete) | Duplica meno byte; `createEditableValues` oggi è determinato dalla griglia | attiva |
| 4 | Voce menu L2 **assente** se `originalDataJSON == nil` | Disabilitato + tooltip | Scelta utente: una sola UX; menu più pulito | attiva |
| 5 | Dopo L2: persistenza **immediata** tramite **`saveChanges()`** (vedi anche Decisione 11 / §4.3), non solo `markDirtyAndScheduleAutosave` | Solo debounce | Azione distruttiva: evitare perdita stato se kill app | attiva |
| 6 | Dopo L2: aggiornare **`originalData`**, **`originalEditable`**, **`originalComplete`**, **solo se** il salvataggio SwiftData del passo L2 è **riuscito** | Aggiornare baseline prima del save | CA coerenti con failure path: baseline L1 mai avanti rispetto al disco | attiva |
| 7 | Dopo L2: reset **`syncStatus`** / **`wasExported`** come post-generazione | Lasciare metadati sync/export | Griglia pre-sync + stato .success sarebbe incoerente | attiva |
| 8 | Helper editing/summary in **file dedicato** nel target (`HistoryImportedGridSupport.swift` o equivalente), **non** come `static` su `ExcelSessionViewModel` | `static` sul view model | `GeneratedView` non deve dipendere semanticamente da `ExcelSessionViewModel` per matematica griglia; il VM resta orchestrazione Excel | attiva |
| 9 | Encoding snapshot in `generateHistoryEntry`: **`try JSONEncoder().encode(filteredData)`** con propagazione errore (`throws`) — **vietato** `try?` | Silent failure | CA-1: nuove entry devono avere snapshot reale, non best-effort | attiva |
| 10 | L2: sequenza anti-race autosave + rollback su save failure (vedi §4.1–§4.2) | Solo menzione generica nei rischi | Elimina ambiguità per Codex | attiva |
| 11 | Persistenza L2: **solo** `saveChanges()` in `GeneratedView` | Duplicare persistenza ad hoc | Coerenza `lastSavedAt`, footer autosave, un solo percorso | attiva |
| 12 | Backup/rollback include **`hasUnsavedChanges`** e **`lastSavedAt`** (vedi §4.1) | Solo griglia/entry | Evita UI dirty/saved incoerente dopo decode fail o rollback save | attiva |
| 13 | Dopo decode JSON OK: **validazione minima** strutturale dello snapshot (§4.1.1); se fallisce → stesso percorso del decode error | Accettare qualsiasi `[[String]]` decodificabile | Evita JSON formalmente valido ma inutilizzabile | attiva |

---

## Planning (Claude)

### 1. Analisi — problema attuale (evidenza codice)

**Persistenza reale** (`HistoryEntry.swift`): la cronologia usa `dataJSON`, `editableJSON`, `completeJSON` (più campi riassuntivi). `GeneratedView` lavora su copie `@State` `data` / `editable` / `complete` e persiste tramite `saveChanges()` che riscrive `entry.data`, `entry.editable`, `entry.complete`, `entry.missingItems` (non ricalcola `orderTotal`/`paymentTotal` ad ogni save — restano quelli impostati alla creazione o da altre azioni).

**Revert livello 1 oggi** (`GeneratedView.swift`, `initializeFromEntryIfNeeded` + `revertToOriginalSnapshot`):

- Alla **prima** inizializzazione con `data` non vuoto, se `originalData.isEmpty`, la vista copia:
  - `originalData = data`
  - `originalEditable = editable`
  - `originalComplete = complete`
- `revertToOriginalSnapshot()` ripristina quei tre buffer e imposta `entry.totalItems = max(0, originalData.count - 1)`, poi `markDirtyAndScheduleAutosave()`.

**Perché non è l’import originario**

- La **source of truth** del “cosa c’era all’import” dopo il primo salvataggio è **sovrascritta** in `entry.data` / `editable` / `complete` da `saveChanges()` e da flussi come sync (`syncWithDatabase` ricarica `data` da `entry`).
- Alla **riapertura** della schermata da cronologia, `initializeFromEntryIfNeeded()` carica da `entry` lo **stato persistito più recente**, non lo stato al tick di `generateHistoryEntry()`.
- Quindi `originalData` cattura solo lo snapshot **alla prima load della vista in questa visita** (= tipicamente l’ultimo dato salvato su disco), **non** una copia immutabile del primo render post-generazione.

**Conclusione**: serve un **secondo canale** persistito, scritto **una sola volta** alla creazione entry, mai aggiornato dagli autosave.

### 2. Strategia dati

| Elemento | Specifica |
|----------|-----------|
| **Campo** | `var originalDataJSON: Data?` su `HistoryEntry` (opzionale). |
| **Formato** | JSON `[[String]]` — **stesso schema** della proprietà calcolata `entry.data` oggi (header + righe, colonne incl. `oldPurchasePrice`, `oldRetailPrice`, `realQuantity`, `RetailPrice`, `complete`, ecc. esattamente come in `filteredData` in `generateHistoryEntry`). |
| **Scrittura** | **Solo** in `ExcelSessionViewModel.generateHistoryEntry(in:)`, dopo `filteredData` finale. Encoding: **`let snapshotBytes = try JSONEncoder().encode(filteredData)`** — `generateHistoryEntry` già `throws`: propagare l’errore (nessun `try?`). Se l’encode fallisce, **nessuna** `HistoryEntry` inserita e **nessun** `context.save()` parziale con snapshot mancante. |
| **Lettura** | Solo per revert L2: `JSONDecoder().decode([[String]].self, from: data)`. |
| **Compatibilità legacy** | SwiftData: nuovo attributo opzionale → record esistenti → `nil` automatico. Nessuna migrazione manuale richiesta oltre al modello aggiornato. |
| **Comportamento `nil`** | Nessuna azione L2 in UI (voce menu assente). Include `createManualHistoryEntry` (mai impostare il campo) e qualsiasi entry creata prima del deploy. |
| **Invariante** | Nessun altro punto del codebase deve assegnare `entry.originalDataJSON` dopo l’insert iniziale (verifica in review con ricerca testuale). |

**Editable / complete dopo L2** (coerente con **Decisione 3**):

- `editable` = `HistoryImportedGridSupport.editableTemplate(forGrid: snapshotData)` (stessa semantica dell’attuale `createEditableValues(for:)`).
- `complete` = `Array(repeating: false, count: data.count)` (stessa lunghezza di `data`, indice 0 = header, coerente con uso esistente di `dropFirst()` sulle righe).

**Totali e missing dopo L2** (⚠️ **non** copiare la formula di `revertToOriginalSnapshot()`, che usa `entry.totalItems = max(0, originalData.count - 1)` ed è **semanticamente diversa** da `generateHistoryEntry`):

- `(totalItems, orderTotal) = HistoryImportedGridSupport.initialSummary(forGrid: snapshotData)` (stessa semantica di `calculateInitialSummary(from:)` oggi).
- `entry.totalItems = totalItems` (conteggio basato su righe con `quantity` > 0 e colonne `purchasePrice`/`quantity`, **identico** al path di generazione — vedi `ExcelSessionViewModel.swift` ~555–589).
- `entry.orderTotal = orderTotal`, `entry.paymentTotal = orderTotal` (come oggi righe 461–464 di `generateHistoryEntry`).
- `entry.missingItems = totalItems` dopo il reset di `complete` a tutti `false` (stesso valore iniziale di `generateHistoryEntry`: `missingItems: totalItems`).

### 3. Dove nasce lo snapshot (obbligatorio)

- **File**: `ExcelSessionViewModel.swift`, funzione `generateHistoryEntry(in:)`.
- **Momento**: dopo aver costruito `filteredData` completo (inclusi header extra e righe), **prima** di `HistoryEntry(...)` / `context.insert`.
- **Contenuto**: copia **esatta** della matrice che verrà passata a `HistoryEntry(data: filteredData)` (nessuna trasformazione successiva tipo sync o merge editable).
- **Serializzazione**: `let originalDataJSON = try JSONEncoder().encode(filteredData)` — **fail-fast**; in caso di errore la funzione esce con `throw` e non crea persistenza “senza snapshot”.
- **Una sola scrittura sul modello**: passare `originalDataJSON` al costruttore `HistoryEntry` (o assegnare una sola volta subito dopo init), **mai** in `GeneratedView.saveChanges()`, mai in fix-up post-sync.

### 4. Comportamento revert livello 2 (nessuna ambiguità per Codex)

**Input**: utente conferma il dialog L2.

#### 4.1 Sequenza operativa e race con autosave (obbligatoria)

Ordine **esatto** (MainActor):

1. **`autosaveTask?.cancel(); autosaveTask = nil`** — annulla il debounce in corso così nessun blocco schedulato invochi `autosaveIfNeeded()` dopo il delay con stato pre-L2.
2. **Backup metadati UI “dirty / saved” (pre-reset race)** — **prima** di qualsiasi `hasUnsavedChanges = false`, salvare in variabili locali (o struct di backup) i valori attuali di:
   - **`hasUnsavedChanges`**
   - **`lastSavedAt`**
   Questi valori servono per **ripristino su decode failure** e **ripristino su save failure** (insieme al backup griglia), così footer autosave / stato dirty non restano incoerenti rispetto ai dati.
3. **`hasUnsavedChanges = false`** — così, se un residual del task già in volo raggiunge `autosaveIfNeeded()` prima di essere cancellato, il guard `guard hasUnsavedChanges` impedisce scritture stale. *(Se il codice autosave non rispetta cancellazione strutturata dopo `sleep`, aggiungere **`try Task.checkCancellation()`** subito dopo l’`await` del debounce e **prima** di `autosaveIfNeeded()` — modifica minima nel solo blocco autosave di `GeneratedView`.)*
4. **`rowDetail = nil`** (e altre invalidazioni UI come per L1 se servono).
5. **Decode fail-fast** (prima di backup griglia / mutazioni griglia): leggere `bytes` da `entry.originalDataJSON`, `snapshotData = try JSONDecoder().decode([[String]].self, from: bytes)` dentro `do`; in `catch` → **ripristinare `hasUnsavedChanges` e `lastSavedAt` dal backup dello step 2**, alert, **`return`**. Griglia / `entry` / baseline L1 **invariati**. Vedi §4.2.
5bis. **Validazione minima post-decode** (subito dopo decode riuscito, **prima** del backup griglia): applicare i criteri in **§4.1.1**. Se la validazione fallisce → **stesso percorso operativo del decode error**: ripristino **`hasUnsavedChanges` / `lastSavedAt`** dallo step 2, alert (chiave **`generated.revert_import.snapshot_invalid`** — §5), **`return`**; nessun backup griglia / nessuna mutazione a `data` / `entry` / baseline L1.
6. **Solo se decode + validazione OK — backup pre-L2 (griglia + entry)** (deep copy) di: `data`, `editable`, `complete`, e di ogni campo `entry` che L2 sta per modificare (`totalItems`, `orderTotal`, `paymentTotal`, `missingItems`, `syncStatus`, `wasExported`). **Non** backup di `title` / `supplier` / `category`. **Non** backup di `originalDataJSON`. *(I metadati dirty/saved restano quelli salvati allo step 2 per il rollback save.)*
7. Mutare **`data = snapshotData`**, **`editable = HistoryImportedGridSupport.editableTemplate(forGrid: snapshotData)`**, **`complete = Array(repeating: false, count: snapshotData.count)`**, poi campi riassuntivi **`entry`** come in §2 (totali, `syncStatus`, `wasExported`).
8. **Persistenza immediata**: chiamare **`saveChanges()`** (metodo esistente di `GeneratedView`) — **nessun** percorso parallelo duplicato salvo impedimento tecnico documentato in Execution/Review. **Non** usare `markDirtyAndScheduleAutosave()` come unico effetto di L2.
8bis. **Rilevamento esito `saveChanges()`**: il metodo **non lancia** (`throws`). Internamente azzera `saveError = nil` all'ingresso, poi se `context.save()` fallisce imposta `saveError = error.localizedDescription`. Solo su successo esegue `hasUnsavedChanges = false; lastSavedAt = Date()`. **Attenzione**: poiché lo step 3 ha già forzato `hasUnsavedChanges = false` (anti-race), quel flag **non è un indicatore affidabile** di successo — sarà `false` in entrambi i casi. **Discriminare con `saveError`**: dopo il ritorno di `saveChanges()`, **`saveError == nil` → successo (step 9)**, **`saveError != nil` → fallimento (step 10)**.
9. **Se save OK** (`saveError == nil`): `originalData = data`, `originalEditable = editable`, `originalComplete = complete`; opzionale haptic. (`saveChanges()` ha già aggiornato `hasUnsavedChanges` / `lastSavedAt` secondo la semantica presente — non alterarla per L2.)
10. **Se save fallisce** (`saveError != nil`): §4.2 — rollback griglia/entry dal backup dello step 6 **e** ripristino **`hasUnsavedChanges` / `lastSavedAt`** dal backup dello step 2; **non** eseguire lo step 9.

**Perché non riscrive uno stale**: task cancellato + `hasUnsavedChanges == false` durante la finestra tra step 3 e la fine di `saveChanges()`; dopo successo, la semantica è quella già implementata in `saveChanges()`.

#### 4.1.1 Validazione minima snapshot (post-decode)

Obiettivo: rifiutare JSON `[[String]]` **formalmente valido** ma **inutilizzabile** come griglia inventario, senza entrare in euristiche da product owner.

Condizioni **tutte** necessarie (se una fallisce → snapshot invalido):

1. **`!snapshotData.isEmpty`**
2. **Header presente e non vuoto**: `snapshotData.first` esiste **e** `snapshotData.first!.count >= 1` **e** esiste almeno una cella header non vuota dopo trim (evita `[[]]` o riga header solo spazi).
3. **Almeno una riga dati** oltre l’header: `snapshotData.count >= 2` (allineato al fatto che `generateHistoryEntry` oggi produce sempre header + almeno una riga proveniente da `rows.dropFirst()` non vuoto quando la sessione è valida; uno snapshot “solo header” è considerato **malformato** per L2).

Implementazione consigliata: funzione pura **`HistoryImportedGridSupport.isValidImportSnapshotGrid(_ snapshotData: [[String]]) -> Bool`** (o nome equivalente) usata **solo** da L2, così i criteri restano centralizzati e testabili.

#### 4.2 Failure path (decode / save)

**Regola globale**: **`originalData` / `originalEditable` / `originalComplete` (baseline L1) si aggiornano solo dopo salvataggio riuscito del passo L2.**

| Fallimento | Comportamento |
|------------|----------------|
| **Decode** di `originalDataJSON` **oppure** **snapshot invalido** post-decode (§4.1.1) | Dopo step 3 §4.1 (`hasUnsavedChanges` già messo a `false` per la race): **nessuna** mutazione a griglia / `entry` / baseline L1 **e** nessun backup griglia. **Ripristinare `hasUnsavedChanges` e `lastSavedAt` dal backup dello step 2 §4.1.** Alert: `catch` decode → **`generated.revert_import.decode_error`**; validazione fallita → **`generated.revert_import.snapshot_invalid`**; **`return`**. |
| **`saveChanges()` fallisce** (es. `context.save()` interno) dopo mutazioni step 7–8 §4.1 | **Rollback obbligatorio** al backup griglia/entry dello **step 6** §4.1. **Ripristinare anche `hasUnsavedChanges` e `lastSavedAt` dal backup dello step 2** (stato UI dirty/saved **pre-L2**, non quello intermedio). Ripristino completo di `entry.data` / `editable` / `complete` e campi riassuntivi se `saveChanges()` li aveva mutati in RAM prima del fallimento — verificare in execution l’ordine interno di `saveChanges()`. **Nessun** secondo `save` forzato obbligatorio. Alert con errore. **`originalData` / `originalEditable` / `originalComplete` non toccati.** |

**Scelta unica**: su save failure = **rollback** (non “UI mutata + alert” senza rollback).

#### 4.3 Persistenza L2 (decisione unica)

- L2 deve invocare **`saveChanges()`** (stesso metodo usato oggi per persistere griglia + `missingItems` + aggiornamento `lastSavedAt` / `hasUnsavedChanges` su successo).
- **Vietato** in planning introdurre un secondo percorso di persistenza duplicato “equivalente”. Se in execution emerge un **impedimento tecnico reale** (es. rientro ricorsivo, flag `isSaving`), documentarlo in **Execution** e risolvere in **Review** con alternativa minima — non nel planning anticipato.

#### 4.4 Riepilogo passi L2 (checklist Codex)

1. `autosaveTask?.cancel(); autosaveTask = nil`.
2. Backup **`hasUnsavedChanges`**, **`lastSavedAt`**.
3. `hasUnsavedChanges = false`.
4. `rowDetail = nil`.
5. Decode → on failure: ripristino `hasUnsavedChanges` / `lastSavedAt` da step 2; alert `decode_error`; return.
5bis. Validazione §4.1.1 → on failure: stesso ripristino step 2; alert `snapshot_invalid`; return.
6. Backup `data` / `editable` / `complete` / campi `entry` (come §4.1 step 6).
7. Applicare snapshot + aggiornare `entry` **senza** `title` / `supplier` / `category` / `originalDataJSON`.
8. **`saveChanges()`** (unico percorso persistenza L2). **Non lancia**: esito via `saveError` (vedi §4.1 step 8bis).
9. `saveError == nil` → successo → baseline L1 (`original*`); `saveError != nil` → fallimento → rollback griglia/entry da step 6 **e** `hasUnsavedChanges` / `lastSavedAt` da step 2 + alert.

**Cosa NON fa L2**: non modifica `title` / `supplier` / `category`; non tocca `originalDataJSON`.

**Righe manuali / delete**: ripristinare allo snapshot **rimuove** righe aggiunte dopo la generazione e **ripristina** righe eliminate se presenti nello snapshot — comportamento atteso.

**Interazione con sync**: se la griglia corrente ha colonna `SyncError` da sync, lo snapshot iniziale **non** la contiene → L2 la elimina insieme al resto dello stato post-sync.

### 5. UX (testi e posizioni)

**Chiavi localizzazione nuove** (valori IT indicativi; tradurre EN/ES/zh-Hans in parità):

| Chiave | IT (proposta) |
|--------|----------------|
| `generated.action.revert_session_open` | Ripristina come all’apertura |
| `generated.action.revert_import_original` | Ripristina import originale |
| `generated.revert_session.title` | Ripristinare come all’apertura? |
| `generated.revert_session.message` | La griglia tornerà allo stato caricato all’apertura di questa schermata. |
| `generated.revert_import.title` | Ripristinare l’import originale? |
| `generated.revert_import.message` | La griglia tornerà ai dati salvati al momento della generazione dell’inventario. Modifiche e salvataggi successivi andranno persi. L’azione non può essere annullata. |
| `generated.revert_import.decode_error` | Impossibile leggere lo snapshot dell’import. L’inventario non è stato modificato. |
| `generated.revert_import.snapshot_invalid` | Lo snapshot dell’import non è valido o è incompleto. L’inventario non è stato modificato. |

**Aggiornamento livello 1 (solo copy)**:

- **Primo revert**: nel `Menu`, nel `confirmationDialog` e nel bottone conferma usare **`generated.action.revert_session_open`**, **`generated.revert_session.title`**, **`generated.revert_session.message`**. Le chiavi legacy `generated.action.revert_original` / `generated.revert.title` / `generated.revert.message` restano nei file finché non rimosse in cleanup opzionale, ma **non** devono più essere referenziate da `GeneratedView` dopo il task (grep su `GeneratedView.swift`).

**Posizione secondo controllo**: stesso `Menu` ⋯ in toolbar trailing, **sotto** la voce del revert L1, `role: .destructive`, visibile solo se `entry.originalDataJSON != nil`.

**Entry legacy / manuale**: nessuna riga L2 (CA-4).

### 6. Rischi

| Rischio | Mitigazione |
|---------|-------------|
| Crescita dimensione `HistoryEntry` | Accettato: una copia JSON della griglia in più; stesso ordine di grandezza di `dataJSON` già presente. |
| Entry legacy `nil` | UX nascosta; nessun crash. |
| Autosave sovrascrive dopo L2 | Mitigazione **operativa** in §4.1: `cancel` + `nil` su `autosaveTask`, poi `hasUnsavedChanges = false` **prima** delle mutazioni; opzionale `Task.checkCancellation()` nel blocco debounce. |
| Delete row / edit / reopen | L2 riallinea tutto allo snapshot; L1 invariato sul concetto “baseline visita”. |
| Regressione L1 | Non modificare corpo `revertToOriginalSnapshot` salvo se estrazione helper condivisa richiede chiamata — mantenere semantica identica. |
| Drift helper summary vs `generateHistoryEntry` | Una sola implementazione in `HistoryImportedGridSupport` (o nome scelto), usata da VM e `GeneratedView`. |
| Decode / validazione / save failure | §4.2: alert + rollback; decode/validazione: ripristino **`hasUnsavedChanges` / `lastSavedAt`**; save: + rollback griglia. |
| Snapshot JSON “valido” ma inutile | §4.1.1 + stesso percorso decode error (alert `snapshot_invalid`). |

### 7. Matrice test manuale (minima)

**Obbligatorietà**: **M-1..M-10**, **S-1** e **M-12** sono richiesti da **CA-7** e dai *Vincoli execution / review*; **M-11** resta opzionale ma consigliato.

| # | Scenario | Esito atteso |
|---|----------|----------------|
| M-1 | Nuova entry da Excel → genera → apri `GeneratedView` | Menu contiene **entrambi** i revert; `originalDataJSON` popolato (verificabile indirettamente: L2 disponibile). |
| M-2 | Modifica celle, attendi autosave, esci e rientra dalla cronologia | L1 ripristina come all’ultima apertura; L2 ripristina griglia identica a post-generazione (senza modifiche utente). |
| M-3 | Entry creata **prima** del deploy (o manuale) | Solo L1 visibile; L2 assente. |
| M-4 | Dopo M-2, usa **solo** L1 | Comportamento identico a pre-task (stesso perimetro righe/colonne che oggi). |
| M-5 | Aggiungi riga manuale, salva, usa **solo** L1 | La riga resta coerente con baseline “all’apertura” (nessuna scomparsa inattesa rispetto a oggi). |
| M-6 | Dopo aggiunta riga + save, usa **L2** | La riga aggiunta **non** è nello snapshot → scompare; griglia = import originario. |
| M-7 | Elimina una riga import, salva, **L2** | Riga riappare come in snapshot. |
| M-8 | Dopo sync DB (se applicabile), **L2** | Griglia senza esito sync “sporco” rispetto a snapshot; `syncStatus` torna `.notAttempted`. |
| M-9 | Dopo **export/share** XLSX (o azione che imposta `wasExported == true` oggi), esegui **L2** | `wasExported == false` dopo L2 (allineato a post-`generateHistoryEntry`). |
| M-10 | Modifica **metadati** in `EntryInfoEditor` (`title` / `supplier` / `category`), salva, poi **L2** | Metadati **invariati** rispetto a prima di L2; solo griglia + campi riassuntivi griglia / sync / export come da planning. |
| **M-11** *(opzionale, consigliato)* | Subito dopo un **L2 riuscito** (stessa sessione `GeneratedView`, senza uscire), esegui **L1** | **Nessun cambiamento visibile** alla griglia / editable / complete: la baseline L1 è stata riallineata allo stato post-L2 **solo** dopo `saveChanges()` riuscito, quindi L1 è già identico allo stato corrente. |
| **M-12** *(**obbligatorio** — persistenza forte; vincolo utente)* | Esegui **L2** con successo → **chiudi completamente l’app** (kill / swipe da app switcher) → riapri → apri la **stessa** `HistoryEntry` da cronologia | Griglia (e stato editing persistito) **resta** quello post-L2; `entry.syncStatus == .notAttempted`; `entry.wasExported == false`. |

#### 7.1 Smoke test store legacy (obbligatorio in review o execution)

| # | Scenario | Esito atteso |
|---|----------|----------------|
| S-1 | Installare/avviare build con **database SwiftData pre-task** (nessuna migrazione manuale oltre modello aggiornato) | App **senza crash** all’avvio; aprire una `HistoryEntry` legacy da cronologia → `GeneratedView` si apre; **nessuna voce L2** nel menu (`originalDataJSON == nil`); solo L1 disponibile se applicabile. |

### 8. Handoff → Execution (Codex)

**Chiusura planning — conferma utente 2026-03-24**: piano **approvato** e **execution-ready**; nessun ulteriore integrazione planning richiesta. Fase → **EXECUTION**; responsabile → **CODEX**. Rispettare i **vincoli** nella sezione **«Vincoli execution / review»** (sotto Planning, prima di Execution).

- **Prossima fase**: EXECUTION  
- **Prossimo agente**: CODEX  
- **Azione consigliata**:

1. **`HistoryEntry.swift`**: aggiungere `originalDataJSON: Data?`; estendere `init` con parametro default `nil`; registrarlo nel modello SwiftData come gli altri blob JSON.
2. **`HistoryImportedGridSupport.swift`** (nome file aderente allo scopo, nello stesso target): implementare funzioni pure **`editableTemplate(forGrid: [[String]]) -> [[String]]`**, **`initialSummary(forGrid: [[String]]) -> (totalItems: Int, orderTotal: Double)`**, e **`isValidImportSnapshotGrid(_:) -> Bool`** (§4.1.1), spostando la logica di `createEditableValues` / `calculateInitialSummary` da `ExcelSessionViewModel` senza cambiare semantica.
3. **`ExcelSessionViewModel.swift`**:  
   - `generateHistoryEntry` usa `HistoryImportedGridSupport` per editable + summary;  
   - dopo `filteredData` pronto: **`let originalBytes = try JSONEncoder().encode(filteredData)`** (nessun `try?`); passare `originalBytes` a `HistoryEntry`; in caso di errore di encode, **`throw`** e **non** inserire/salvare entry;  
   - **`createManualHistoryEntry`**: non impostare mai `originalDataJSON`.
4. **`GeneratedView.swift`**: `revertToImportSnapshot()` + dialog L2; sequenza **§4.1–§4.4** (decode → **validazione §4.1.1** → backup → mutazioni → **`saveChanges()`**); rollback decode/validazione/save come da §4.2; opzionale `Task.checkCancellation()` nel debounce autosave; chiavi L1/L2; baseline `original*` **solo** dopo `saveChanges()` OK.
5. **`Localizable.strings` (×4)**: chiavi UX §5 incl. **`generated.revert_import.decode_error`** e **`generated.revert_import.snapshot_invalid`** — IT + traduzioni.
6. **Ordine suggerito**: `HistoryImportedGridSupport` → `HistoryEntry` → refactor `ExcelSessionViewModel.generateHistoryEntry` (encode fail-fast) → `GeneratedView` + stringhe → smoke **S-1** + test persistenza **M-12** (vincoli utente).
7. **Verifica**: `rg 'originalDataJSON'` — assegnamenti solo in `generateHistoryEntry` (+ init default `nil`). Build `iOSMerchandiseControl`.

**Regole anti-regressione**: nessun `try?` sull’encode dello snapshot per nuove entry; nessuna dipendenza di `GeneratedView` da `ExcelSessionViewModel` per helper griglia; non toccare `InventorySyncService`; L1 = stessa logica pre-refactor (solo stringhe).

---

## Vincoli execution / review (conferma utente 2026-03-24)

Vincoli **non negoziabili** per Codex (execution) e Claude (review), salvo eccezione documentata nel file task:

1. **`originalDataJSON`**: scritto **una sola volta** in **`generateHistoryEntry`** (+ `init` / default `nil`).
2. **L2**: **unico** percorso di persistenza tramite **`saveChanges()`** in `GeneratedView`.
3. **Revert L1**: **nessuna regressione** di semantica (solo aggiornamento copy/localizzazioni se già pianificato).
4. **Helper griglia**: logica **pura/condivisa** nel target (es. `HistoryImportedGridSupport`); **nessun** accoppiamento semantico di `GeneratedView` verso `ExcelSessionViewModel` per matematica/template griglia.
5. **Verifica finale obbligatoria**: smoke store legacy **S-1** + test persistenza forte **M-12** (§7).

---

## Execution (Codex)
### Obiettivo compreso
Implementare il revert L2 allo snapshot immutabile dell'import in `GeneratedView`, mantenendo invariata la semantica del revert L1, con `originalDataJSON` scritto una sola volta in `generateHistoryEntry(in:)`, helper griglia puro/condiviso nel target e persistenza L2 esclusivamente via `saveChanges()`.

### File controllati
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-018-generatedview-second-level-revert.md`
- `AGENTS.md`
- `CLAUDE.md`
- `docs/CODEX-EXECUTION-PROTOCOL.md`
- `iOSMerchandiseControl/HistoryEntry.swift`
- `iOSMerchandiseControl/ExcelSessionViewModel.swift`
- `iOSMerchandiseControl/GeneratedView.swift`
- `iOSMerchandiseControl/it.lproj/Localizable.strings`
- `iOSMerchandiseControl/en.lproj/Localizable.strings`
- `iOSMerchandiseControl/es.lproj/Localizable.strings`
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`

### Piano minimo
1. Aggiungere al modello `HistoryEntry` il blob opzionale `originalDataJSON`.
2. Estrarre in file dedicato la logica pura condivisa per template editable, summary iniziale e validazione minima dello snapshot.
3. Rendere `generateHistoryEntry(in:)` fail-fast sull'encode di `filteredData`, scrivendo `originalDataJSON` solo in quel punto.
4. Aggiungere in `GeneratedView` il comando L2 con dialog dedicato, hidden per entry legacy/manuali, e flusso anti-race/rollback che passa solo da `saveChanges()`.
5. Aggiornare le stringhe L1/L2 nelle quattro localizzazioni e verificare con build + grep i vincoli del task.

### Modifiche fatte
- `HistoryEntry.swift`: aggiunta la proprietà persistita opzionale `originalDataJSON` e il relativo parametro `init` con default `nil`, senza toccare le API pubbliche del resto del task.
- `HistoryImportedGridSupport.swift` (nuovo): introdotto helper puro condiviso con `editableTemplate(forGrid:)`, `initialSummary(forGrid:)` e `isValidImportSnapshotGrid(_:)`.
- `ExcelSessionViewModel.swift`:
  - `generateHistoryEntry(in:)` ora esegue `let originalDataJSON = try JSONEncoder().encode(filteredData)` subito dopo la costruzione di `filteredData`;
  - `HistoryEntry` riceve `originalDataJSON` solo in quel punto;
  - `editable` e summary iniziale passano dal nuovo helper condiviso;
  - rimossa la duplicazione locale di `createEditableValues` / `calculateInitialSummary`.
- `GeneratedView.swift`:
  - L1 usa le nuove chiavi `revert_session_*` senza cambiare la logica di `revertToOriginalSnapshot()`;
  - aggiunto menu/dialog L2 visibile solo quando `entry.originalDataJSON != nil`;
  - implementato `revertToImportSnapshot()` con:
    - `autosaveTask?.cancel(); autosaveTask = nil`;
    - backup di `hasUnsavedChanges` / `lastSavedAt`;
    - decode fail-fast + validazione minima snapshot;
    - backup stato locale/entry per rollback;
    - reset di `totalItems`, `orderTotal`, `paymentTotal`, `missingItems`, `syncStatus`, `wasExported`;
    - persistenza esclusiva via `saveChanges()`;
    - aggiornamento baseline L1 solo dopo save riuscito;
    - rollback completo su save failure;
  - aggiornato il debounce autosave con `Task.checkCancellation()` per evitare che una cancellazione del task debounce continui fino ad `autosaveIfNeeded()`.
- `Localizable.strings` (`it/en/es/zh-Hans`): aggiunte le chiavi `generated.action.revert_session_open`, `generated.action.revert_import_original`, `generated.revert_session.*`, `generated.revert_import.*`.

### File e simboli toccati
| File | Azione | Simboli toccati |
|------|--------|-----------------|
| `iOSMerchandiseControl/HistoryEntry.swift` | Modificato | `HistoryEntry.originalDataJSON`, `HistoryEntry.init(...)` |
| `iOSMerchandiseControl/HistoryImportedGridSupport.swift` | Creato | `HistoryImportedGridSupport`, `editableTemplate(forGrid:)`, `initialSummary(forGrid:)`, `isValidImportSnapshotGrid(_:)` |
| `iOSMerchandiseControl/ExcelSessionViewModel.swift` | Modificato | `generateHistoryEntry(in:)` |
| `iOSMerchandiseControl/GeneratedView.swift` | Modificato | `RevertImportDecodeError`, `RevertImportUIBackup`, `RevertImportStateBackup`, `showImportRevertConfirmation`, `markDirtyAndScheduleAutosave()`, `revertToImportSnapshot()`, `restoreRevertImportUIState(...)`, `restoreRevertImportState(...)` |
| `iOSMerchandiseControl/it.lproj/Localizable.strings` | Modificato | chiavi `generated.action.revert_session_open`, `generated.action.revert_import_original`, `generated.revert_session.*`, `generated.revert_import.*` |
| `iOSMerchandiseControl/en.lproj/Localizable.strings` | Modificato | stesse chiavi L1/L2 EN |
| `iOSMerchandiseControl/es.lproj/Localizable.strings` | Modificato | stesse chiavi L1/L2 ES |
| `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings` | Modificato | stesse chiavi L1/L2 zh-Hans |

### Comando build eseguito
Comando: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
Esito: `** BUILD SUCCEEDED **` (exit `0`)
Warning nuovi: non rilevati nei file toccati; nel log compare solo `warning: Metadata extraction skipped. No AppIntents.framework dependency found.` del processor AppIntents, warning gia' noto e fuori perimetro del task.

### Check eseguiti
- ✅ ESEGUITO — Build compila: comando `xcodebuild` sopra concluso con `** BUILD SUCCEEDED **`.
- ✅ ESEGUITO — Nessun warning nuovo introdotto (per quanto verificabile): `rg -n "warning:|error:" /tmp/task018_build.log` ha trovato solo il warning AppIntents esterno al task.
- ✅ ESEGUITO — Modifiche coerenti con il planning: nessun tocco a `InventorySyncService`, nessuna nuova dipendenza, nessun refactor extra, helper griglia puro nel target, L2 solo via `saveChanges()`.
- ❌ NON ESEGUITO — Criteri di accettazione verificati integralmente: CA-1..CA-6 risultano verificati via STATIC+BUILD, ma CA-7 richiede ancora S-1 + M-1..M-10 + M-12 manuali non eseguiti in questo turno.

### CA → evidenza
| CA | Tipo verifica | Esito | Evidenza / nota |
|----|---------------|-------|-----------------|
| CA-1 | STATIC | PASS | `ExcelSessionViewModel.generateHistoryEntry(in:)` esegue `let originalDataJSON = try JSONEncoder().encode(filteredData)` e lo passa a `HistoryEntry`; `rg -n "originalDataJSON\\s*=|let originalDataJSON =|originalDataJSON:" ...` mostra solo init/default + `generateHistoryEntry` + lettura in `GeneratedView`. |
| CA-2 | STATIC | PASS | `GeneratedView` aggiunge un secondo comando/menu/dialog L2 con chiavi `generated.action.revert_import_original` / `generated.revert_import.*`, distinto dal L1. |
| CA-3 | STATIC | PASS | `revertToImportSnapshot()` cancella l'autosave, fa decode+validazione+backup, poi chiama solo `saveChanges()`; nessun `markDirtyAndScheduleAutosave()` nel percorso L2. |
| CA-4 | STATIC | PASS | Il menu L2 e' racchiuso in `if entry.originalDataJSON != nil`, quindi resta nascosto per entry legacy/manuali. |
| CA-5 | STATIC | PASS | Prima di `saveChanges()` il percorso L2 imposta `entry.syncStatus = .notAttempted` e `entry.wasExported = false`. |
| CA-6 | STATIC | PASS | `revertToOriginalSnapshot()` conserva la logica precedente; in `GeneratedView` sono cambiati solo i riferimenti alle chiavi di copy L1. |
| CA-7 | MANUAL | NOT RUN | Smoke legacy `S-1` e persistenza forte `M-12` non eseguiti; anche la matrice manuale `M-1..M-10` resta da validare runtime. |

### Test case → esito
| Test | Stato | Tipo | Nota |
|------|-------|------|------|
| S-1 | NOT RUN | MANUAL | Richiede store SwiftData legacy pre-task e apertura reale di una `HistoryEntry` legacy nel runtime app. |
| M-1 | NOT RUN | MANUAL | Richiede generazione entry da Excel e verifica UI dei due comandi revert. |
| M-2 | NOT RUN | MANUAL | Richiede autosave reale, uscita/rientro da cronologia e confronto L1 vs L2. |
| M-3 | NOT RUN | MANUAL | Richiede entry pre-deploy o manuale nel runtime app. |
| M-4 | NOT RUN | MANUAL | Richiede verifica comportamentale L1 su sessione reale. |
| M-5 | NOT RUN | MANUAL | Richiede aggiunta riga manuale e save reale in UI. |
| M-6 | NOT RUN | MANUAL | Richiede aggiunta riga + L2 in UI. |
| M-7 | NOT RUN | MANUAL | Richiede delete row + L2 in UI. |
| M-8 | NOT RUN | MANUAL | Richiede sync DB reale + L2 in UI. |
| M-9 | NOT RUN | MANUAL | Richiede export/share reale e verifica `wasExported` post-L2. |
| M-10 | NOT RUN | MANUAL | Richiede modifica metadati via `EntryInfoEditor` e verifica runtime post-L2. |
| M-11 | NOT RUN | MANUAL | Opzionale; non eseguito in questa execution. |
| M-12 | NOT RUN | MANUAL | Richiede L2 riuscito + kill app + riapertura stessa `HistoryEntry`; non eseguito in questo turno. |

### Conferma scope
Conferma scope: non ho modificato file o comportamenti fuori dal perimetro del task. L'unico file nuovo e' il helper condiviso previsto dal planning (`HistoryImportedGridSupport.swift`).

### Rischi rimasti
- La validazione runtime richiesta da CA-7 resta aperta: `S-1`, `M-1..M-10` e `M-12` non sono stati eseguiti in questa execution.
- Non ho una fixture/store legacy pre-task pronta nel repo per certificare `S-1` senza test manuale reale.
- `M-12` richiede persistenza forte attraverso relaunch dell'app e una `HistoryEntry` reale; qui e' documentato come `NOT RUN [MANUAL]`, non inferito dal codice.

### Aggiornamenti file di tracking
- Nessun riallineamento iniziale extra necessario: `MASTER-PLAN` e task file erano gia' coerenti con `TASK-018` in `EXECUTION`.
- A fine execution il task e' stato avanzato a **REVIEW** con responsabile **CLAUDE**.

### Handoff post-execution
- **Prossima fase**: REVIEW
- **Prossimo agente**: CLAUDE
- **Azione consigliata**: verificare in review i vincoli strutturali (`originalDataJSON` scritto una sola volta, L2 solo via `saveChanges()`, nessuna regressione L1, helper condiviso puro) e decidere il tracking successivo tenendo esplicitamente aperto il gap manuale su `S-1` / `M-1..M-10` / `M-12`.

---

## Review (Claude)

### Esito: **APPROVED**

Review tecnica su execution (codice + vincoli strutturali): implementazione coerente con planning e con la sezione *Vincoli execution / review*; **nessun fix richiesto** (nessun problema critico/medio bloccante emerso dalla verifica statica e dall’evidenza in Execution).

**Nota sui criteri end-to-end**: **CA-7** (smoke **S-1**, matrice **M-1..M-10**, persistenza **M-12**) resta **non verificato** in Simulator/device — documentato in Execution come `NOT RUN [MANUAL]`. Ciò **non** comporta `CHANGES_REQUIRED` sul codice già mergiato; la **chiusura DONE** resta **differita** fino a esecuzione test manuali utente e conferma esplicita.

### Problemi critici
Nessuno.

### Problemi medi
Nessuno.

### Miglioramenti opzionali
Nessuno richiesto ora.

### Fix richiesti
Nessuno.

### Checklist review finale (esito)

Allineata ai **vincoli** *Vincoli execution / review* e alla execution.

- [x] **`rg originalDataJSON`**: unica scrittura in **`generateHistoryEntry`** (+ init default) — coerente con evidenza Execution.
- [x] **`GeneratedView.swift`**: nessun uso delle chiavi L1 legacy — coerente con execution.
- [x] **`Task.checkCancellation()`**: introdotto solo nel blocco debounce documentato — coerente.
- [x] **L2**: persistenza solo **`saveChanges()`** — coerente.
- [ ] **S-1** + **M-1..M-10** + **M-12**: **pendenti** (utente); da eseguire alla ripresa TASK-018 prima di DONE.

### Handoff post-review (sospensione su richiesta utente 2026-03-25)

- **Stato task**: **BLOCKED** (non DONE).
- **Motivo**: review **APPROVED**; **test manuali CA-7 non ancora eseguiti** dall’utente.
- **Alla ripresa**: eseguire S-1, M-1..M-10, M-12; se regressioni → **FIX** (Codex) → **REVIEW** (Claude); se OK → **conferma utente** → **DONE**.
- **Focus progetto**: **TASK-019** (vedi `docs/MASTER-PLAN.md`).

---

## Sospensione (2026-03-25 — richiesta utente)

| Voce | Stato |
|------|--------|
| Execution (Codex) | Completata; build OK |
| Review (Claude) | **APPROVED**; nessun fix richiesto |
| Test manuali CA-7 (S-1, M-1..M-10, M-12) | **Pendenti** |
| **DONE** | **Rimandato** |

Il task **non** è chiuso: sospeso in **BLOCKED** per allineamento al workflow «review OK + validazione manuale differita» (stesso schema di TASK-016 / TASK-017).

---

## Fix (Codex)
*(Non applicabile.)*

---

## Chiusura
### Conferma utente
- [ ] Utente ha confermato il completamento

### Follow-up candidate
[Da compilare se necessario]

### Riepilogo finale
[Da compilare in chiusura]

### Data completamento
YYYY-MM-DD
