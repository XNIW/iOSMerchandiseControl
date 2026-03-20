# TASK-004: GeneratedView editing parity (revert, delete, mark all, search nav)

## Informazioni generali
- **Task ID**: TASK-004
- **Titolo**: GeneratedView editing parity (revert, delete, mark all, search nav)
- **File task**: `docs/TASKS/TASK-004-generatedview-editing-parity.md`
- **Stato**: DONE
- **Fase attuale**: —
- **Responsabile attuale**: —
- **Data creazione**: 2026-03-20
- **Ultimo aggiornamento**: 2026-03-20
- **Ultimo agente che ha operato**: CLAUDE

## Dipendenze
- **Dipende da**: nessuno
- **Sblocca**: nessuno

## Scopo
Aggiungere 4 feature mancanti alla schermata GeneratedView (editing inventario):
- **Revert** (parity Android): ripristinare i dati della griglia allo stato originale della sessione
- **Delete row** (parity Android): eliminare una riga dalla griglia con conferma
- **Mark All Complete** (enhancement iOS, decisione utente): segnare/desegnare tutte le righe in un'azione
- **Search navigation** (enhancement iOS, decisione utente): navigare tra i risultati di ricerca con next/previous

## Contesto
Il gap audit TASK-001 ha identificato queste 4 feature come mancanti in iOS rispetto ad Android. Analisi successiva ha rivelato che solo Revert e Delete sono vera parity Android; Mark All e Search Nav non esistono in Android (il gap audit era impreciso). L'utente ha confermato esplicitamente di includere tutte e 4 nel task. Il termine "parity" nel titolo va inteso come parity parziale + enhancement approvati.

## Non incluso
- Undo multi-step o cronologia versioni per revert
- Search navigation circolare
- Redesign della search UX
- Refactor o decomposizione di GeneratedView.swift
- Modifiche a file diversi da `iOSMerchandiseControl/GeneratedView.swift`
- Modifiche a HistoryEntry.swift, ExcelSessionViewModel.swift o modelli SwiftData

## File potenzialmente coinvolti
- `iOSMerchandiseControl/GeneratedView.swift` — unico file da modificare (~3245 righe)

## Criteri di accettazione
Questi criteri sono il contratto del task. Execution e review lavorano contro di essi.
- [ ] Menu toolbar mostra "Ripristina originale"; confirmation dialog appare; dopo revert la griglia torna ai dati originali (data/editable/complete); `entry.totalItems` riallineato; metadata non toccati
- [ ] Righe eliminabili via context menu, trailing swipe, RowDetailSheetView; guard su row 0 (header non eliminabile); confirmation dialog; data/editable/complete sincronizzati (stessa count, stesso significato indice-per-indice); totalItems aggiornato; autosave scatta
- [ ] Menu toolbar mostra "Segna tutti completati" / "Segna tutti incompleti" (toggle su `allRowsComplete`); tutte le righe dati aggiornate (header escluso, indici 1..N); autosave scatta
- [ ] Search sheet mostra bottoni next/previous quando ci sono risultati; tap risultato resta invariato (open detail + dismiss); next/prev saltano senza chiudere lo sheet; contatore "Risultato X di N" visibile; bottoni disabilitati agli estremi; currentResultIndex resettato su cambio query e su cambio results.count
- [ ] Build senza errori né warning nuovi
- [ ] Flussi esistenti non impattati: barcode scan, editing dettaglio, sync, export, entry manuale
- [ ] **Persistenza — delete**: dopo delete uscire e rientrare da cronologia → riga assente
- [ ] **Persistenza — mark all**: dopo mark all uscire e rientrare → stato salvato corretto
- [ ] **Persistenza — revert**: dopo revert uscire e rientrare → dati ripristinati salvati
- [ ] **Header row protetta**: in tutti i flussi (revert, delete, mark all, search nav) la riga 0 non viene mai modificata, eliminata, marcata o inclusa come target di navigazione

## Decisioni
| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|-------|
| 1 | Revert a un solo livello (stato all'apertura) | Two-level revert come Android | Pre-generate revert già gestito dal dismiss di PreGenerateView; one-level è minimale e sufficiente | attiva |
| 2 | Snapshot revert in @State in-memory | Nuovi campi su HistoryEntry | Nessun cambio schema SwiftData; snapshot valido solo per la sessione corrente | attiva |
| 3 | Delete con confirmation dialog | Delete immediato | Azione distruttiva; coerente con convenzioni iOS | attiva |
| 4 | Mark all senza conferma | Con confirmation dialog | Facilmente reversibile; nessuna conferma necessaria | attiva |
| 5 | Search: tap invariato + bottoni nav extra | Tap = solo jump (sheet aperto) | Mantiene comportamento attuale; next/prev sono azione separata | attiva |
| 6 | currentResultIndex in @State locale InventorySearchSheet | Coordinato dalla view padre | Non richiede coordinazione esterna; reset naturale a ogni riapertura | attiva |
| 7 | currentResultIndex position-based (no tracking semantico) | Tracking per row-id | Garantire bounds validity è sufficiente; row-id tracking esula dal minimo cambiamento | attiva |

---

## Planning (Claude) ← solo Claude aggiorna questa sezione

### Analisi

**Stato attuale iOS** (GeneratedView.swift, ~3245 righe):
- Nessuna delle 4 feature esiste
- Data model: tre array paralleli `data: [[String]]`, `editable: [[String]]`, `complete: [Bool]` — allineati per indice
- Autosave: debounce 0.8s via `markDirtyAndScheduleAutosave()`
- HistoryEntry: SwiftData @Model con data/editable/complete come JSON-encoded Data?
- `setComplete(rowIndex:headerRow:value:haptic:)` (~riga 964): aggiorna complete[] e data[][completeCol]; non chiama autosave né haptic se haptic:false
- `initializeFromEntryIfNeeded()` (~riga 689): popola i tre array una sola volta, guardato da `data.isEmpty`
- Toolbar Menu (~riga 423): "Modifica dettagli" + "Condividi…"
- RowDetailSheetView (~riga 1880): detail panel con callbacks
- InventorySearchSheet (~riga 2855): `results` computed da `1..<data.count`, max 200 match

**Android reference** (funzionale, non per porting):
- Revert: backup deep copy a due livelli (pre-generate + at-load)
- Delete: rimozione da tutti e tre gli array in `deleteManualRow()`
- Mark All: non esiste in Android
- Search Nav next/prev: non esiste in Android

### Approccio proposto

**Feature 1 — Revert** (~25 righe):
1. 3 nuovi `@State`: `originalData`, `originalEditable`, `originalComplete` (tutte `[]` come default)
2. In `initializeFromEntryIfNeeded()`, dopo popolamento completo dei 3 array: snapshot catturato in blocco atomico condizionato a `originalData.isEmpty` (o boolean `hasCapturedOriginalSnapshot` — scelta a Codex, da documentare)
   - Sentinella robusta: una HistoryEntry valida ha sempre almeno header, quindi `data` post-init non è mai vuoto
   - Snapshot immutabile dopo la cattura: nessun'altra funzione deve scrivere su questi tre @State
3. `@State private var showRevertConfirmation = false`
4. Voce toolbar Menu "Ripristina originale" (role: .destructive, systemImage: arrow.uturn.backward)
5. `.confirmationDialog`: chiude `rowDetail`, ripristina i 3 array, aggiorna `entry.totalItems = max(0, originalData.count - 1)`, chiama `markDirtyAndScheduleAutosave()`

**Feature 2 — Delete Row** (~55 righe):
1. `deleteRow(at rowIndex: Int)`: guard `rowIndex >= 1`; invalida TUTTI gli @State index-based (rowDetail, flashRowIndex, scrollToRowIndex, pendingForceComplete + verifica altri); rimuove da data/editable/complete atomicamente; aggiorna totalItems; chiama autosave
   - Invariante obbligatoria: data/editable/complete sempre allineati (stesso count, stesso significato indice-per-indice)
   - Codex verifica esistenza di altri @State con rowIndex in GeneratedView prima di implementare
2. `@State private var pendingDeleteRowIndex: Int? = nil`
3. "Elimina riga" in context menu, trailing swipe, RowDetailSheetView (via nuovo callback `onDeleteRow`)
4. Callback in `rowDetailSheet(_:)`: cattura `detail.rowIndex` in `pendingDeleteRowIndex` PRIMA di `rowDetail = nil`
5. `.confirmationDialog` con barcode riga se disponibile

**Feature 3 — Mark All** (~25 righe):
1. Computed `allRowsComplete`: `complete.dropFirst().allSatisfy { $0 }` (guard count > 1)
2. `markAllComplete(_ value: Bool)`: loop da 1 a complete.count-1, chiama `setComplete(haptic: false)` per ogni riga; poi autosave unico; poi haptic .medium unico. Non tocca totalItems/missingItems/metadata.
3. Voce toolbar Menu label dinamica; `.disabled(data.count <= 1)`

**Feature 4 — Search Navigation** (~55 righe):
1. `@State private var currentResultIndex: Int? = nil` in InventorySearchSheet
2. `.onChange(of: searchText)`: reset a nil
3. `.onChange(of: results.count)`: se currentResultIndex >= results.count → reset a nil
4. `navigateToNextResult()`: next = (currentResultIndex ?? -1) + 1, guard < results.count
5. `navigateToPrevResult()`: guard current > 0
6. Tap su risultato: aggiornare `currentResultIndex` PRIMA di onOpenDetail + dismiss (non opzionale)
7. Barra nav in `safeAreaInset(edge: .bottom)`: prev/next buttons + contatore; visibile solo se !results.isEmpty
8. Header esclusa: `results` già parte da `1..<data.count` — invariante da preservare

### File da modificare
- `iOSMerchandiseControl/GeneratedView.swift` — unico file

### Rischi identificati
| Rischio | Prob. | Mitigazione |
|---------|-------|-------------|
| Delete corrompe @State index-based | Media | deleteRow() invalida tutti gli stati dipendenti prima della rimozione |
| Snapshot revert catturato in stato parziale | Bassa | Blocco condizionale dopo tutti e tre i blocchi di init |
| currentResultIndex fuori bounds | Media | .onChange su searchText e results.count |
| entry.totalItems incoerente dopo delete o revert | Media | Aggiornato esplicitamente in deleteRow() e nel confirmation revert |
| Altri @State index-based non previsti | Bassa | Verifica esplicita da fare prima di implementare Feature 2 |

### Handoff → Execution
- **Prossima fase**: EXECUTION
- **Prossimo agente**: CODEX
- **Azione consigliata**: Leggere le sezioni toolbar Menu (~riga 421), context menu/swipe (~riga 237-295), RowDetailSheetView (~riga 1880), InventorySearchSheet (~riga 2855), initializeFromEntryIfNeeded (~riga 689). Poi implementare nell'ordine:
  1. Feature 3 (Mark All) → build check
  2. Feature 1 (Revert) → build check
  3. Feature 2 (Delete Row) → build check — verificare prima altri @State index-based
  4. Feature 4 (Search Navigation) → build check

  **Vincoli obbligatori**:
  - Solo `GeneratedView.swift` — nessun altro file
  - Nessun refactor, nessuna decomposizione del file
  - Nessuna dipendenza nuova
  - Minimo cambiamento necessario
  - Build check dopo ogni feature
  - Lavoro fuori scope → follow-up candidate, non implementare

---

## Execution (Codex) ← solo Codex aggiorna questa sezione

### Obiettivo compreso
Implementare in `GeneratedView.swift` le 4 feature richieste dal task attivo mantenendo il minimo cambiamento necessario, proteggendo sempre la header row (row 0) e preservando l'allineamento indice-per-indice tra `data`, `editable` e `complete`.

### File controllati
- `docs/TASKS/TASK-004-generatedview-editing-parity.md`
- `docs/MASTER-PLAN.md`
- `iOSMerchandiseControl/GeneratedView.swift`

### Piano minimo
- Allineamento iniziale al task attivo e verifica dei punti d'innesto in `GeneratedView.swift`
- Implementazione nell'ordine richiesto dall'utente: Mark All Complete → build → Revert → build → Delete Row → build → Search Navigation → build finale
- Aggiornamento del tracking solo con il lavoro realmente eseguito

Nota di coerenza: l'handoff di planning suggeriva un ordine tecnico diverso (`Mark All` → `Revert` → `Delete` → `Search Nav` come feature 3/1/2/4), ma l'utente ha imposto esplicitamente l'ordine operativo seguito qui; l'approccio implementativo e il perimetro del task sono rimasti invariati.

### Modifiche fatte
- **Mark All Complete**
  - Aggiunto computed `allRowsComplete`
  - Esteso il menu toolbar con toggle dinamico "Segna tutti completati" / "Segna tutti incompleti"
  - Reso `setComplete(...)` riusabile in batch con `scheduleAutosave`
  - Implementato `markAllComplete(_:)` con update delle sole righe dati `1..<count`, header esclusa, un solo autosave finale e un solo haptic finale
- **Revert**
  - Aggiunti snapshot session-scoped in-memory `originalData`, `originalEditable`, `originalComplete`
  - Cattura snapshot in `initializeFromEntryIfNeeded()` dopo l'allineamento iniziale dei tre array locali
  - Aggiunta voce menu "Ripristina originale" con confirmation dialog
  - Implementato `revertToOriginalSnapshot()` che ripristina i tre array, chiude l'eventuale `rowDetail`, riallinea `entry.totalItems` e schedula autosave
- **Delete Row**
  - Aggiunto `pendingDeleteRowIndex` con confirmation dialog dedicato
  - Aggiunta azione di delete in context menu, trailing swipe e `RowDetailSheetView`
  - Implementato `deleteRow(at:)` con guard sulla row 0, invalidazione preventiva degli state UI index-based (`rowDetail`, `flashRowIndex`, `scrollToRowIndex`, `visibleRowSet`, `pendingForceComplete`, `pendingReopenRowIndexAfterScannerDismiss`, `reopenRowDetailAfterScan`, `focusCountedOnNextDetail`) e rimozione atomica da `data`, `editable`, `complete`
  - Aggiornato `entry.totalItems` dopo la rimozione e mantenuto autosave
- **Search Navigation**
  - Aggiunto `currentResultIndex` locale a `InventorySearchSheet`
  - Implementati `navigateToNextResult()` e `navigateToPrevResult()` non circolari
  - Reset di `currentResultIndex` su cambio query e su riduzione di `results.count`
  - Aggiunta barra nello sheet con bottoni separati prev/next, contatore "Risultato X di N" e disabilitazione agli estremi
  - Il tap su un risultato mantiene il comportamento esistente: `onJumpToRow` + `onOpenDetail` + `dismiss`, aggiornando prima `currentResultIndex`

### Check eseguiti
- ✅ ESEGUITO — Build compila: eseguiti 4 build check con `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO`; tutti con esito `BUILD SUCCEEDED`
- ⚠️ NON ESEGUIBILE — Nessun warning nuovo: i build riportano il warning `Metadata extraction skipped. No AppIntents.framework dependency found.` in `appintentsmetadataprocessor`; senza baseline automatica precedente non è verificabile formalmente se sia nuovo, ma non nasce dalle modifiche a `GeneratedView.swift`
- ✅ ESEGUITO — Modifiche coerenti con planning: implementate le 4 feature richieste, mantenendo file unico, niente refactor, niente nuove dipendenze, header row protetta e snapshot revert in-memory di sessione
- ⚠️ NON ESEGUIBILE — Criteri di accettazione verificati: verificati via codice build, guard su row 0, batch autosave per mark all, snapshot revert session-scoped, rimozione sincronizzata di `data/editable/complete`, nav search non circolare; non eseguiti test manuali UI/persistenza di uscita-rientro in simulatore/dispositivo in questa execution

### Rischi rimasti
- Va ancora verificata in review la persistenza end-to-end di delete / mark all / revert uscendo e rientrando dalla cronologia
- Va verificata manualmente la UX del delete dal `RowDetailSheetView` quando la sheet viene chiusa e il dialog di conferma viene presentato subito dopo
- Il warning `appintentsmetadataprocessor` compare ancora nei build log, ma non è stato toccato da questo task

### Handoff → Review
- **Prossima fase**: REVIEW
- **Prossimo agente**: CLAUDE
- **Azione consigliata**: Verificare i criteri di accettazione con focus su: persistenza dopo uscita/rientro per delete / mark all / revert, conferma delete da context menu-swipe-row detail, invarianti `data/editable/complete` dopo delete, header row sempre esclusa da mark/delete/search nav e comportamento tap risultato search (open detail + dismiss)

---

## Review (Claude) ← solo Claude aggiorna questa sezione

### Verifica criteri di accettazione

**Mark All Complete**
- ✅ Toolbar Menu mostra toggle "Segna tutti completati" / "Segna tutti incompleti" basato su `allRowsComplete` (~riga 452-460)
- ✅ `markAllComplete(_:)` itera da indice 1 a `complete.count - 1` — header row (0) esclusa
- ✅ `setComplete(haptic: false, scheduleAutosave: false)` per ogni riga, un solo autosave e un solo haptic dopo il loop
- ✅ Non tocca `entry.totalItems` né altri metadata
- ✅ Disabilitato quando `data.count <= 1`
- ✅ Test manuali: stato misto → tutti completi → toggle → tutti incompleti. Confermato positivo.

**Revert**
- ✅ Snapshot `originalData/originalEditable/originalComplete` catturato in `initializeFromEntryIfNeeded()` dopo popolamento completo di tutti e tre gli array, condizionato a `originalData.isEmpty && !data.isEmpty` (~riga 819-823)
- ✅ Snapshot immutabile: nessun'altra funzione lo sovrascrive
- ✅ `revertToOriginalSnapshot()`: chiude `rowDetail`, ripristina i tre array, aggiorna `entry.totalItems = max(0, originalData.count - 1)`, chiama autosave (~riga 1111-1120)
- ✅ Voce menu "Ripristina originale" con `role: .destructive` e `disabled(originalData.isEmpty)` (~riga 462-467)
- ✅ Confirmation dialog con messaggio esplicativo (~riga 543-554)
- ✅ Caso revert-dopo-delete: `entry.totalItems` riallineato con `originalData.count - 1`
- ✅ Test manuali: modifica righe → revert → dati originali ripristinati. Confermato positivo.

**Delete Row**
- ✅ Guard `rowIndex >= 1` con controllo su tutti e tre gli array (~riga 1144-1148)
- ✅ `invalidateIndexBasedUIStateBeforeRowRemoval()` pulisce: `rowDetail`, `flashRowIndex`, `scrollToRowIndex`, `visibleRowSet`, `pendingForceComplete`, `pendingReopenRowIndexAfterScannerDismiss`, `reopenRowDetailAfterScan`, `focusCountedOnNextDetail` (~riga 1132-1141) — coverage più ampia di quanto pianificato
- ✅ Rimozione atomica da `data`, `editable`, `complete` allo stesso indice (~riga 1153-1155) — invariante allineamento preservata
- ✅ `entry.totalItems` aggiornato dopo rimozione (~riga 1156)
- ✅ `pendingDeleteRowIndex` cattura l'indice prima del dismiss del detail — il confirmation dialog non dipende da `rowDetail`
- ✅ Entry point: context menu (~riga 261), trailing swipe (~riga 298), RowDetailSheetView (~riga 1976)
- ✅ Confirmation dialog con barcode della riga se disponibile (~riga 555-580)
- ✅ Test manuali: delete via context menu, swipe, detail — tutti funzionanti. Persistenza confermata (uscita + rientro da cronologia). Confermato positivo.

**Search Navigation**
- ✅ `currentResultIndex: Int?` locale a `InventorySearchSheet` (~riga 3038)
- ✅ `navigateToNextResult()` e `navigateToPrevResult()` non circolari con bounds check (~riga 3090-3103)
- ✅ `canNavigateToPrevResult` / `canNavigateToNextResult` per disabilitazione bottoni (~riga 3105-3112)
- ✅ Tap su risultato: aggiorna `currentResultIndex` prima di `onJumpToRow` + `onOpenDetail` + `dismiss` (~riga 3126) — comportamento tap invariato
- ✅ `.onChange(of: searchText)`: reset a nil (~riga 3317-3318)
- ✅ `.onChange(of: results.count)`: reset se indice fuori bounds (~riga 3320-3325)
- ✅ Highlighting visuale del risultato selezionato via `listRowBackground` (~riga 3163)
- ✅ Header esclusa: `results` parte da `1..<data.count` — invariante preservata
- ✅ Test manuali: query con più risultati, next/prev, contatore, disabilitazione estremi. Confermato positivo.

**Criteri trasversali**
- ✅ Build senza errori: 4 BUILD SUCCEEDED confermati. Warning `appintentsmetadataprocessor` preesistente, non introdotto da questo task.
- ✅ Flussi esistenti non impattati: barcode scan, editing dettaglio, sync, export, entry manuale verificati.
- ✅ Persistenza delete: riga assente dopo uscita e rientro da cronologia.
- ✅ Persistenza mark all: stato salvato corretto dopo uscita e rientro.
- ✅ Persistenza revert: dati ripristinati salvati dopo uscita e rientro.
- ✅ Header row protetta in tutti i flussi: guard su row 0 in `deleteRow`, loop da 1 in `markAllComplete`, `results` da 1 in search, snapshot preserva header ma non la espone come target modificabile.

### Problemi critici
Nessuno.

### Problemi medi
Nessuno.

### Miglioramenti opzionali
- La `invalidateIndexBasedUIStateBeforeRowRemoval()` è stata estratta come funzione separata — scelta di Codex apprezzabile per leggibilità, coerente con il piano e non è refactoring non richiesto.
- Il highlighting del risultato selezionato (`listRowBackground`) è un'aggiunta migliorativa non esplicitamente pianificata ma utile e non invasiva.

### Fix richiesti
Nessuno.

### Esito
APPROVED — tutti i criteri di accettazione soddisfatti, test manuali positivi, persistenza verificata, nessun problema bloccante né medio.

---

## Fix (Codex) ← solo Codex aggiorna questa sezione

### Fix applicati
[Da compilare]

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
- [x] Utente ha confermato il completamento

### Follow-up candidate
- **Decomposizione GeneratedView.swift**: il file è cresciuto a ~3400 righe. La decomposizione in componenti più piccoli è un task futuro separato, non urgente.
- **Warning `appintentsmetadataprocessor`**: preesistente, non causato da questo task. Non bloccante.
- **Revert pre-generate**: riportare i dati allo stato pre-GeneratedScreen (non solo alla sessione corrente) richiederebbe un secondo livello di snapshot. Esplicitamente fuori scope di questo task.

### Riepilogo finale
Implementate con successo le 4 feature previste in `iOSMerchandiseControl/GeneratedView.swift` (~155 righe aggiunte, unico file modificato):
- **Mark All Complete**: toggle bulk via toolbar menu, header protetta, autosave unico post-loop
- **Revert**: snapshot session-scoped in-memory, confirmation dialog, riallineamento totalItems
- **Delete Row**: guard su row 0, invalidazione completa stati UI index-based, rimozione atomica dei tre array paralleli, persistenza confermata
- **Search Navigation**: next/prev non circolari, reset su cambio query e risultati, tap invariato, highlighting visuale risultato selezionato

Tutti i criteri di accettazione soddisfatti. Build verde. Test manuali (inclusi casi combinati e persistenza) confermati positivi dall'utente.

### Data completamento
2026-03-20
