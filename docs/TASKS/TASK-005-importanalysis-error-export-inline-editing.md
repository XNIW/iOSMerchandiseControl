# TASK-005: ImportAnalysis error export + inline editing

## Informazioni generali
- **Task ID**: TASK-005
- **Titolo**: ImportAnalysis error export + inline editing
- **File task**: `docs/TASKS/TASK-005-importanalysis-error-export-inline-editing.md`
- **Stato**: BLOCKED
- **Fase attuale**: —
- **Responsabile attuale**: —
- **Data creazione**: 2026-03-20
- **Ultimo aggiornamento**: 2026-03-20
- **Ultimo agente che ha operato**: CLAUDE

> Stato sospeso: implementazione gia` esistente e tracking di execution completato; review finale temporaneamente rinviata finche' i test manuali non saranno completati.

## Dipendenze
- **Dipende da**: nessuno
- **Sblocca**: nessuno

## Scopo
Portare `ImportAnalysisView` a parity funzionale con il comportamento atteso del flusso import prodotti: esportazione errori in XLSX con share sheet e modifica inline dei `newProducts` e `updatedProducts` prima di confermare l'import.

Il task deve anche correggere il bug di snapshot nei caller (`DatabaseView`, `GeneratedView`) in modo che "Applica" usi sempre l'analisi effettivamente editata dall'utente.

## Contesto
La schermata `ImportAnalysisView` del flusso Excel → Database e` attualmente read-only: mostra nuovi prodotti, aggiornamenti, warning ed errori, ma non permette di esportare gli errori ne` di correggere i draft prima dell'applicazione. Il gap e` stato identificato nel gap audit TASK-001 come copertura di GAP-06 (error export) e GAP-11 (inline editing).

## Non incluso
- Edit di warning o errori: restano read-only
- Bulk edit o azioni massive sui draft
- Lookup fornitore/categoria dal database nel form
- Validazione avanzata oltre a barcode/productName obbligatori e collisione intra-lista dei new products
- Persistenza delle modifiche se `ImportAnalysisView` viene chiusa senza `Applica`
- Undo/redo nel form di edit
- Rimozione manuale di prodotti dalla lista
- Refactor della logica duplicata tra `DatabaseView` e `ProductImportViewModel`
- Validazione barcode contro prodotti gia` esistenti nel database o contro updated products della stessa analisi

## File potenzialmente coinvolti
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-005-importanalysis-error-export-inline-editing.md`
- `iOSMerchandiseControl/ImportAnalysisView.swift`
- `iOSMerchandiseControl/DatabaseView.swift`
- `iOSMerchandiseControl/GeneratedView.swift`

## Criteri di accettazione
Questi criteri sono il contratto del task. Execution e review lavorano contro di essi.
- [ ] **CA-1**: Con almeno 1 errore, la sezione errori mostra il bottone `Esporta errori`
- [ ] **CA-2**: Tappando `Esporta errori` viene generato un file `.xlsx` e compare il share sheet di sistema
- [ ] **CA-3**: Il file XLSX contiene il foglio `Errori di Importazione` con header = unione ordinata alfabeticamente delle chiavi di `rowContent` + `Errore`
- [ ] **CA-4**: Con errori che hanno chiavi `rowContent` diverse, le colonne coprono l'unione completa e le celle mancanti restano vuote
- [ ] **CA-5**: Con 0 errori il bottone non e` visibile
- [ ] **CA-6**: Ogni riga in `Nuovi prodotti` mostra un bottone edit con icona pencil
- [ ] **CA-7**: Tappando edit su un new product si apre un form sheet con i valori del `ProductDraft`
- [ ] **CA-8**: Salvando il form di un new product, la lista mostra i valori aggiornati
- [ ] **CA-9**: Premendo `Applica` dopo l'edit di un new product, il database usa i valori modificati
- [ ] **CA-10**: Premendo `Annulla` nel form, nessuna modifica viene applicata alla lista
- [ ] **CA-11**: Se un new product viene editato con il barcode di un altro new product, `Salva` resta disabilitato
- [ ] **CA-12**: Ogni riga in `Prodotti aggiornati` mostra un bottone edit
- [ ] **CA-13**: Il form per updated products parte dai valori del lato `new`
- [ ] **CA-14**: Il campo barcode e` non editabile per updated products
- [ ] **CA-15**: Dopo il salvataggio di un updated product, `changedFields` riflette solo le differenze reali rispetto a `old`
- [ ] **CA-16**: Se un updated product diventa identico a `old`, la riga viene rimossa da `updatedProducts`
- [ ] **CA-17**: Premendo `Applica` dopo l'edit di un updated product, il record esistente viene aggiornato con i valori modificati
- [ ] **CA-18**: Se un campo numerico contiene testo non parsabile, `Salva` resta abilitato e il valore finale applicato diventa `nil`
- [ ] **CA-19**: Eseguendo edit multipli su prodotti diversi e poi `Applica`, tutte le modifiche sono presenti nei dati importati
- [ ] **CA-20**: Editando uno o piu` prodotti e poi premendo `Annulla` su `ImportAnalysisView`, nessuna modifica viene applicata al database
- [ ] **CA-21**: Chiudendo `EditProductDraftView` con swipe-down, nessuna modifica viene applicata alla lista
- [ ] **CA-22**: Se un updated product viene riportato identico a `old`, la riga scompare e `Applica` non aggiorna quel record
- [ ] **CA-23**: `Applica` senza edit mantiene il comportamento originario
- [ ] **CA-24**: `Annulla` sulla toolbar di `ImportAnalysisView` chiude il foglio senza applicare nulla
- [ ] **CA-25**: Il flusso `DatabaseView -> ImportAnalysisView -> Applica` funziona con la nuova firma `onApply`
- [ ] **CA-26**: Il flusso `GeneratedView -> ImportAnalysisView -> Applica` funziona con la nuova firma `onApply`
- [ ] **CA-27**: Export con caratteri non ASCII produce un file apribile senza corruzione
- [ ] **CA-28**: Export con celle vuote o chiavi mancanti produce celle vuote senza crash
- [ ] **CA-29**: Export con stringhe molto lunghe genera il file senza troncamenti o errori
- [ ] **CA-30**: `BuildProject scheme="iOSMerchandiseControl" destination="platform=iOS Simulator,name=iPhone 16,OS=latest"` chiude con `BUILD SUCCEEDED`; eventuali warning nei file toccati vanno annotati in execution

## Decisioni
Decisioni superate o cambiate non vanno cancellate: marcarle come OBSOLETA con nota esplicita.
| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|-------|
| 1 | `computeChangedFields` duplicato localmente in `ProductUpdateDraft` | Refactor helper condiviso tra file grandi | Minimo cambiamento necessario, nessun refactor fuori scope | attiva |
| 2 | `ImportAnalysisView` gestisce una copia locale editabile di `analysis` tramite `@State` e restituisce il risultato editato ai caller | Mutare direttamente il binding esterno o mantenere la firma `onApply: () -> Void` | Corregge il bug di snapshot senza ampliare l'API oltre il necessario | attiva |
| 3 | `EditingItem` usa identificatori stabili (`barcode` per new, `UUID` per updated) | Indici posizionali nell'array | Evita lookup fragili e mantiene safe i fallback se l'elemento non viene trovato | attiva |
| 4 | La validazione barcode copre solo collisioni intra-lista tra new products tramite `forbiddenBarcodes` | Validazione contro DB o contro tutti i draft in analisi | E` la soglia minima necessaria per evitare collisioni di identity SwiftUI senza introdurre query/moduli fuori scope | attiva |
| 5 | Tracking iniziale e creazione del task file eseguiti da Codex su esplicito user override, perche' il turno di Claude e` terminato | Fermarsi in attesa che Claude aggiorni tracking | Mantiene il workflow tracciabile pur rispettando l'istruzione dell'utente | attiva |

---

## Planning (Claude) ← solo Claude aggiorna questa sezione

### Analisi
- `ImportAnalysisView` e` attualmente read-only e non permette ne` export errori ne` edit dei draft.
- `ProductUpdateDraft` ha `new` e `changedFields` immutabili, quindi non supporta il ricalcolo post-edit.
- `DatabaseView` e `GeneratedView` presentano `ImportAnalysisView` tramite `.sheet(item:)`, ma oggi `onApply` riusa la snapshot iniziale dell'analisi: se la vista diventasse editabile, l'import applicherebbe comunque i dati vecchi.
- `EditProductView` esistente non e` riusabile direttamente: lavora su modelli SwiftData persistiti, mentre qui servono draft in-memory callback-based.
- Il pattern di export XLSX e di share sheet esiste gia` nella codebase (`InventoryXLSXExporter`, `ShareSheet`, `GeneratedView.shareAsXLSX`) e va riusato come riferimento.

### Approccio proposto
1. Rendere mutabile `ProductUpdateDraft` dove serve e aggiungere `computeChangedFields(old:new:)` coerente con la logica di confronto esistente in `ProductImportViewModel`.
2. Portare `ImportAnalysisView` a `@State private var analysis` con init dedicato e nuova firma `onApply: (ProductImportAnalysisResult) -> Void`.
3. Aggiungere export errori XLSX con nome `errori_import_YYYY-MM-DD_HH-mm-ss.xlsx`, foglio `Errori di Importazione`, unione ordinata delle chiavi di `rowContent`, share sheet e alert di errore export.
4. Aggiungere editing inline per `newProducts` e `updatedProducts` tramite `EditProductDraftView`, con validazione minima su `barcode`, `productName`, `forbiddenBarcodes`, parsing numerico coerente con la pipeline esistente e fallback safe se il lookup dell'item non riesce.
5. Per gli updated products, ricalcolare `changedFields` dopo il salvataggio; se il draft diventa identico a `old`, rimuovere la riga da `updatedProducts`.
6. Aggiornare `DatabaseView` e `GeneratedView` per usare `editedAnalysis` in `onApply`, eliminando il bug di snapshot senza modificare altri flussi.

### File da modificare
- `iOSMerchandiseControl/ImportAnalysisView.swift`
  Motivo: modelli `ProductUpdateDraft`, export XLSX, share sheet, state locale editabile, UI di editing, helper di validazione e parsing
- `iOSMerchandiseControl/DatabaseView.swift`
  Motivo: caller di `ImportAnalysisView` da aggiornare alla nuova firma `onApply`
- `iOSMerchandiseControl/GeneratedView.swift`
  Motivo: caller di `ImportAnalysisView` da aggiornare alla nuova firma `onApply`

### Rischi identificati
| Rischio | Probabilita` | Mitigazione |
|---------|--------------|-------------|
| Persistenza del bug di snapshot nei caller | Media | Nuova firma `onApply` che riceve l'analisi editata dallo `@State` interno |
| Lookup fragile durante l'edit | Bassa | `EditingItem` con identificatori stabili e fallback safe con `if let` |
| Duplicate barcode tra new products rompe identity SwiftUI | Media | `forbiddenBarcodes` e `Salva` disabilitato in caso di collisione intra-lista |
| Divergenza nei confronti `changedFields` rispetto all'analisi iniziale | Bassa | Copia esatta della logica di confronto string/double gia` in uso in `ProductImportViewModel` |
| Warning o regressioni nei file toccati | Bassa | Minimo set di file, nessuna dipendenza nuova, build finale obbligatoria |

### Handoff → Execution
- **Prossima fase**: EXECUTION
- **Prossimo agente**: CODEX
- **Azione consigliata**: Aggiornare prima il tracking alla fase EXECUTION, poi implementare in ordine il supporto a `@State analysis` + nuova firma `onApply`, l'export XLSX degli errori, l'editing inline dei draft e infine l'adeguamento dei due caller con build finale obbligatoria

---

## Execution (Codex) ← solo Codex aggiorna questa sezione

### Obiettivo compreso
Attivare formalmente `TASK-005`, rendere `ImportAnalysisView` editabile in-memory con export errori XLSX + share sheet, propagare ai caller l'analisi effettivamente editata e chiudere l'execution con build verificata e tracking pronto per review.

### File controllati
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-005-importanalysis-error-export-inline-editing.md`
- `CLAUDE.md`
- `AGENTS.md`
- `/Users/minxiang/.claude/plans/tingly-percolating-rabbit.md`
- `iOSMerchandiseControl/ImportAnalysisView.swift`
- `iOSMerchandiseControl/DatabaseView.swift`
- `iOSMerchandiseControl/GeneratedView.swift`
- `iOSMerchandiseControl/ProductImportViewModel.swift`
- `iOSMerchandiseControl/EditProductView.swift`
- `iOSMerchandiseControl/ShareSheet.swift`
- `iOSMerchandiseControl/InventoryXLSXExporter.swift`

### Piano minimo
- Creare il task file dal piano approvato e portare il tracking a `EXECUTION`
- Aggiornare `ImportAnalysisView.swift` con `@State private var analysis`, nuova firma `onApply`, export errori XLSX, share sheet, editing inline e validazioni minime
- Aggiornare `DatabaseView.swift` e `GeneratedView.swift` per usare `editedAnalysis` senza snapshot bug
- Eseguire il build richiesto; se bloccato da discrepanze d'ambiente, documentarle e fare best effort con una destinazione iOS realmente disponibile
- Compilare la sezione Execution e portare il task a `REVIEW`

### Modifiche fatte
- Tracking iniziale completato:
  - creato `docs/TASKS/TASK-005-importanalysis-error-export-inline-editing.md` basato sul piano approvato
  - aggiornato `docs/MASTER-PLAN.md` per attivare `TASK-005` e poi riportarlo a `REVIEW` a fine execution
- `ImportAnalysisView.swift`:
  - aggiunto `import xlsxwriter`
  - resi mutabili `ProductUpdateDraft.new` e `ProductUpdateDraft.changedFields`
  - aggiunto `ProductUpdateDraft.computeChangedFields(old:new:)` coerente con la logica esistente di confronto string/double
  - cambiata la view per usare `@State private var analysis` con init dedicato e nuova firma `onApply: (ProductImportAnalysisResult) -> Void`
  - aggiunti export errori XLSX, share sheet e alert di errore export
  - aggiunti bottoni edit per `newProducts` e `updatedProducts`
  - aggiunto `EditProductDraftView` callback-based con validazione minima di `barcode`, `productName` e `forbiddenBarcodes`, parsing numerico coerente con la pipeline esistente e barcode non editabile per updated products
  - aggiunta gestione safe del lookup degli item in editing e rimozione di un updated product quando il draft torna identico a `old`
  - marcati `nonisolated` gli helper statici puri del form per evitare warning nuovi di actor isolation
- `DatabaseView.swift`:
  - aggiornato il caller di `ImportAnalysisView` per usare `editedAnalysis` in `onApply`
- `GeneratedView.swift`:
  - aggiornato il caller di `ImportAnalysisView` per usare `editedAnalysis` in `onApply`

### Check eseguiti
Per ogni check: ✅ ESEGUITO | ⚠️ NON ESEGUIBILE (motivo) | ❌ NON ESEGUITO (motivo)
- [x] Build compila: ✅ ESEGUITO — tentato il comando richiesto `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' build`, ma sulla macchina del 2026-03-20 il simulatore `iPhone 16` non e` disponibile; eseguito quindi build di fallback `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' build` con esito `BUILD SUCCEEDED`
- [x] Nessun warning nuovo: ✅ ESEGUITO — al build finale non risultano warning nei file toccati; resta solo il warning non correlato `Metadata extraction skipped. No AppIntents.framework dependency found.` emesso da `appintentsmetadataprocessor`
- [x] Modifiche coerenti con planning: ✅ ESEGUITO — il perimetro e` rimasto limitato a tracking TASK-005, `ImportAnalysisView.swift`, `DatabaseView.swift` e `GeneratedView.swift`, senza refactor extra o nuove dipendenze
- [ ] Criteri di accettazione verificati: ⚠️ NON ESEGUIBILE — non ho eseguito test UI/manuali end-to-end su export/share sheet, edit multipli, swipe-down del form e apply reale nei due flussi; verificati solo wiring, build e aderenza implementativa al piano

### Rischi rimasti
- Il criterio CA-30 con il comando/destinazione esatti del piano non e` chiudibile su questa macchina perche' `iPhone 16, OS=latest` non e` installato; il best effort verificato e` il fallback su `iPhone 16e, OS=26.2`
- Restano da verificare manualmente in review i flussi UI end-to-end: export errori con share sheet, edit multipli, dismiss swipe-down del form, apply dai caller `DatabaseView` e `GeneratedView`
- Per scelta di scope, le collisioni barcode contro prodotti gia` presenti nel DB o contro updated products della stessa analisi restano nel failure path esistente di apply; eventuale validazione preventiva e` follow-up candidate

### Handoff → Review
- **Prossima fase**: REVIEW
- **Prossimo agente**: CLAUDE
- **Azione consigliata**: Verificare i criteri di accettazione con focus su export/share sheet, editing dei new/updated products, rimozione degli updated identici a `old`, apply reale nei flussi `DatabaseView` e `GeneratedView`, e tenere esplicitamente conto del mismatch d'ambiente sul simulatore richiesto (`iPhone 16` assente sulla macchina)

---

## Review (Claude) ← solo Claude aggiorna questa sezione

### Stato review
Review temporaneamente sospesa su richiesta utente. Nessun esito definitivo (`APPROVED` / `CHANGES_REQUIRED` / `REJECTED`) viene emesso finche' la validazione manuale non e` completa.

### Test manuali pendenti
- Verifica end-to-end di `Esporta errori` con presentazione reale del `ShareSheet`
- Verifica di edit multipli + `Applica` nel flusso `DatabaseView`
- Verifica di edit multipli + `Applica` nel flusso `GeneratedView`
- Verifica dismiss con swipe-down di `EditProductDraftView`

### Problemi critici
[Da compilare]

### Problemi medi
[Da compilare]

### Miglioramenti opzionali
[Da compilare]

### Fix richiesti
- [ ] [Da compilare]

### Esito
- APPROVED = criteri soddisfatti, nessun fix necessario -> conferma utente
- CHANGES_REQUIRED = fix mirati necessari -> FIX
- REJECTED = fuori perimetro o incoerente -> nuovo PLANNING

Esito: [APPROVED | CHANGES_REQUIRED | REJECTED]

### Handoff → Fix (se CHANGES_REQUIRED)
- **Prossima fase**: FIX
- **Prossimo agente**: CODEX
- **Azione consigliata**: [Da compilare]

### Handoff → nuovo Planning (se REJECTED)
- **Prossima fase**: PLANNING
- **Prossimo agente**: CLAUDE
- **Azione consigliata**: [Da compilare]

---

## Fix (Codex) ← solo Codex aggiorna questa sezione

### Fix applicati
- [ ] [Da compilare]

### Check post-fix
Per ogni check: ✅ ESEGUITO | ⚠️ NON ESEGUIBILE (motivo) | ❌ NON ESEGUITO (motivo)
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
[Da compilare]

### Riepilogo finale
[Da compilare]

### Data completamento
YYYY-MM-DD
