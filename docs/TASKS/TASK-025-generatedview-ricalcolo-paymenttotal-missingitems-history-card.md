# TASK-025: GeneratedView — ricalcolo dinamico paymentTotal + missingItems su History card

## Informazioni generali
- **Task ID**: TASK-025
- **Titolo**: GeneratedView: ricalcolo dinamico paymentTotal + missingItems su History card
- **File task**: `docs/TASKS/TASK-025-generatedview-ricalcolo-paymenttotal-missingitems-history-card.md`
- **Stato**: BLOCKED *(sospeso post-review; **non** DONE)*
- **Fase attuale**: — *(task non ACTIVE; review tecnica **APPROVED** gia' acquisita — vedi sezione **Review**)*
- **Responsabile attuale**: — *(nessuno operativo; congelato in attesa **test manuali utente** T-0..T-15)*
- **Data creazione**: 2026-03-25
- **Ultimo aggiornamento**: 2026-03-25 *(tracking: **BLOCKED** — review **APPROVED**; test manuali non eseguiti; ripresa = test → eventuale **FIX** → **REVIEW** finale → conferma utente → **DONE**)*
- **Ultimo agente che ha operato**: CLAUDE

## Dipendenze
- **Dipende da**: nessuno (origine: audit iOS vs Android 2026-03-25, gap funzionale su totali cronologia).
- **Sblocca**: coerenza tra valori mostrati su **History card** (`HistoryView`) e stato reale dell'inventario dopo editing in **`GeneratedView`**; allineamento funzionale atteso rispetto ad Android sul riepilogo «pagato» / articoli mancanti.

## Scopo
Garantire che i campi persistiti su **`HistoryEntry`** rilevanti per il riepilogo inventario — **`paymentTotal`**, **`missingItems`**, **`totalItems`** — riflettano il lavoro svolto in **`GeneratedView`**, e che la **scheda cronologia** in **`HistoryView`** li **mostri** in modo leggibile (oggi la card **non** renderizza `missingItems`: va aggiunto esplicitamente, salvo **decisione di scope** che escluda la UI — **non** adottata in questo planning).

## Contesto
- Audit **2026-03-25** (vedi `MASTER-PLAN`, nota coordinamento): gap residuo — su iOS **`paymentTotal`** non viene ricalcolato dinamicamente rispetto al comportamento di riferimento Android.
- **`HistoryRow`** (`HistoryView.swift`) oggi mostra in card solo i chip **articoli** (`totalItems`), **ordine** (`orderTotal`), **pagato** (`paymentTotal`) e, se applicabile, **errori** — **non** viene mostrato alcun chip per **`missingItems`**, anche se il campo esiste sul modello. **TASK-025** include quindi **modifica UI** in `HistoryView.swift` (nuovo chip + stringhe localizzate) salvo diversa decisione esplicita di perimetro (**non** prevista qui).
- **`GeneratedView.saveChanges()`** aggiorna gia' **`missingItems`** in base a `complete` e `entry.totalItems`, ma **non** aggiorna **`paymentTotal`** (ne **`orderTotal`**, che oggi e' etichettato in UI come totale ordine **iniziale**).
- **`generateHistoryEntry`** imposta oggi `paymentTotal = orderTotal` e `missingItems = totalItems` (quest'ultimo da `initialSummary`), mentre **`orderTotal`** deriva da **`initialSummary`** (fornitore). La nuova semantica di **`paymentTotal`** e' il **totale inventario confermato** (solo righe **complete**), con prezzo **acquisto/sconto** — **non** retail (**Decisione #1**, **Decisione finale vs Android**); serve **stato iniziale esplicito** post-generazione (**Decisione #4**).
- Semantica duale storica di **`totalItems`**: alla generazione da Excel era il conteggio «business» da `initialSummary`; dopo **`deleteRow`** / altre azioni veniva sovrascritto con `max(0, data.count - 1)`. **`handleScannedBarcode`** (nuove righe manuale) **non** aggiornava `entry.totalItems` → **`missingItems`** persistito poteva essere errato. Il planning impone **SSOT** (vedi **Decisioni #5**) e calcolo tramite **helper runtime dedicato** (vedi **Decisioni #6**).

## Non incluso
- Refactor di **`ExcelSessionViewModel`** / **`ExcelAnalyzer`** oltre a quanto strettamente necessario per coerenza dei campi riassuntivi iniziali + invocazione helper runtime (nessun ampliamento formato Excel).
- Modifiche al modello SwiftData oltre a riuso dei campi esistenti (`paymentTotal`, `missingItems`, `totalItems`, `orderTotal`) salvo emergenza documentata in execution.
- Parita' riga-per-riga con codice Kotlin Android (solo riferimento funzionale: «cosa deve vedere l'utente»).
- Nuove dipendenze SPM o API pubbliche esterne.
- **Perimetro UI esplicito (default TASK-025)**: **non** e' richiesto allineare il riepilogo live ai valori **persistiti** (`entry.paymentTotal` / `entry.missingItems` su disco) ne' mostrare il **«pagato»** in quella sezione. **Resta invece obbligatorio** (vedi **Decisione #7**) evitare **regressione UX** su **«Articoli totali»** e **«Da completare»** dopo la rimozione delle write dirette ai summary: tali due righe del riepilogo devono usare **solo** stato locale `data`/`complete`. Il totale ordine iniziale continua a usare **`entry.orderTotal`**.

## File potenzialmente coinvolti
- `iOSMerchandiseControl/GeneratedView.swift` — **`saveChanges()`** (unico writer persistito dei summary runtime in sessione, salvo eccezioni in **Decisioni #5**); rimozione assegnazioni dirette ai summary da altri percorsi; revert L1/L2; sync; **`summarySection`** (**Decisione #7** / **CA-8**).
- `iOSMerchandiseControl/HistoryView.swift` — **`HistoryRow`**: nuovo chip **`missingItems`**, layout **due righe** (**Decisione #8**).
- `iOSMerchandiseControl/HistoryEntry.swift` — eventuale documentazione semantica sui campi (nessun nuovo campo atteso).
- **Nuovo modulo Swift nel target** (nome suggerito: `HistoryEntryRuntimeSummary.swift`) — **calcolatore puro** del riepilogo **runtime** da griglia gia' merge-ata + `complete` (vedi Planning). **Separato** da `HistoryImportedGridSupport.initialSummary` (solo fornitore / creazione sessione).
- `iOSMerchandiseControl/HistoryImportedGridSupport.swift` — **solo** `initialSummary` / `editableTemplate` / validazione snapshot import; **nessun** calcolo runtime inventario qui (evitare ambiguita' concettuale).
- `iOSMerchandiseControl/ExcelSessionViewModel.swift` — **`generateHistoryEntry`**: stato iniziale coerente con **Decisioni #4** + stesso helper runtime sulla griglia+complete iniziali; **`createManualHistoryEntry`** se serve allineamento a zero fino alla prima griglia.
- Stringhe localizzazione (es. `*.lproj` / catalogo usato da `L(...)`) — chiave per etichetta chip **mancanti**.
- `iOSMerchandiseControl/InventorySyncService.swift` — **consultazione** per parsing numeri / priorita' `realQuantity` vs `quantity` dove utile al parity qty.

## Perimetro esplicito
- **INCLUSO**: (1) calcolo e **persistenza** coerenti di `paymentTotal`, `missingItems`, `totalItems` sul modello secondo regole del Planning; (2) **UI History card** che espone **`missingItems`** (nuovo chip) insieme agli esistenti, con layout leggibile; (3) aggiornamento **`generateHistoryEntry`** (e path atomici revert) per **stato iniziale** allineato alla semantica runtime (**Decisioni #4**), cosi' la card non e' incoerente **prima** del primo save in `GeneratedView`.
- **ESCLUSO (salvo nuova decisione utente)**: preview in **`GeneratedView`** del **«pagato»** (`paymentTotal`) identica al persistito, o parita' completa riepilogo↔modello prima dell'autosave. **INCLUSO nel perimetro (senza allargarlo)**: **Decisione #7** — anti-regressione sui due conteggi del riepilogo che oggi dipendono anche da `entry`. Eventuale follow-up per «pagato» in riepilogo sotto **Follow-up candidate**.

## Criteri di accettazione
Questi criteri sono il contratto del task. Execution e review lavorano contro di essi.

- [ ] **CA-1**: Dopo aver lavorato in **`GeneratedView`** (qty conteggiate, prezzi acquisto/sconto dove presenti, flag **complete**) e aver atteso autosave o **Fine** / **`flushAutosaveNow()`**, in **Cronologia** il chip **«pagato»** (`history.summary.paid` / `paymentTotal`) e' la **somma dei soli contributi riga con qty finale `> 0`**, ciascuno calcolato come in **Decisione #1**: per ogni riga **`complete == true`** si applica qty (**`realQuantity`** / fallback **`quantity`** come da **Decisione #1**), prezzo unitario finale (**`discountedPrice`** / **`discount` %** / **`purchasePrice`**); se **qty finale `≤ 0`** il contributo riga e' **0** (il chip **non** include importi negativi ne' «sottrazioni» da qty non positive). Verifica incrociata con scenari **T-1**, **T-8..T-15**.
- [ ] **CA-2**: Aggiornando lo stato **completo / incompleto** delle righe (swipe, dettaglio, mark-all, force-complete), dopo salvataggio, il valore persistito **`missingItems`** e' coerente con **Decisione #2** (calcolo via **Decisione #6** / **Contratto §2**: **`checked`** per indice riga, non conteggio «cieco» su `dropFirst` se le lunghezze divergono). *(Visibilita' in lista → **CA-7**.)*
- [ ] **CA-3**: Aggiungendo righe tramite **scanner** su inventario **manuale** e/o tramite **ManualEntrySheet**, e rimuovendo righe con **delete**, i valori persistiti **`totalItems`** / **`missingItems`** (e chip corrispondenti in **CA-7**) restano coerenti con la dimensione effettiva della griglia dopo salvataggio — **nessun** caso in cui `totalItems` resta incoerente con il numero di righe dati mentre la griglia ha righe > 0 **senza** ulteriore azione utente (rispetto **Decisioni #5**).
- [ ] **CA-4**: **`orderTotal`** continua a rappresentare il totale ordine **iniziale** (fornitore) come oggi presentato in **`GeneratedView`** sezione riepilogo (`generated.summary.initial_order_total`); non deve essere sovrascritto dai ricalcoli di **TASK-025** salvo decisione esplicita registrata nelle **Decisioni** (default: **non** modificare).
- [ ] **CA-5**: I percorsi **Revert sessione** (L1) e **Revert import** (L2) (`revertToOriginalSnapshot`, `revertToImportSnapshot` + backup/restore) producono **`paymentTotal`**, **`missingItems`** e **`totalItems`** coerenti con la griglia **dopo** l'operazione, usando la **stessa** logica del calcolatore runtime (**Decisioni #5–6**), e con **`saveChanges()`** quando il flusso prevede save.
- [ ] **CA-6**: Subito dopo **`generateHistoryEntry`** (prima interazione in **GeneratedView**), aprendo **Cronologia** (o tornando ad essa), chip **pagato** / **mancanti** / **articoli** rispettano lo **stato iniziale** definito in **Decisione #4** (nessun `paymentTotal` ancora legato al solo totale fornitore se la decisione impone `0`).
- [ ] **CA-7 (UI History card)**: In **`HistoryView`**, **`HistoryRow`** mostra un **nuovo chip** per **`missingItems`** (etichetta localizzata `history.summary.*`). **Layout prescrittivo (execution)** — vedi **Decisione #8**: i chip sono disposti in **due righe orizzontali stabili** (`VStack` di due `HStack`, o equivalente con stesso effetto): **prima riga** articoli + ordine + pagato (ordine fisso come oggi per i primi tre); **seconda riga** mancanti + (se presente) errori. **Non** usare `lineLimit(1)`+truncation sui chip; **non** ridurre aggressivamente la dimensione font rispetto agli altri chip della stessa card; testi etichetta+valore **completamente leggibili** (no ellissi su contenuto numerico/monetario). Verificare su **larghezza stretta** (es. iPhone SE) e **Dynamic Type** contenuti senza uscire dal perimetro HIG.
- [ ] **CA-8**: **`GeneratedView.summarySection`**: dopo delete / add row / scanner / edit **prima** dell'autosave, **«Articoli totali»** e **«Da completare»** restano coerenti con la griglia **`data`** e i flag **`complete`** (**Decisione #7**); **non** devono restare agganciati a `entry.totalItems` / `entry.missingItems` se questi aggiornano solo al save. Il campo **totale ordine iniziale** resta da **`entry.orderTotal`**.
- [ ] **CA-9**: Build **Debug** compila senza errori; nessun nuovo warning **evitabile** introdotto (se presente warning preesistente, non peggiorare).

## Decisioni
| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|-------|
| 1 | **`paymentTotal` — formula finale (allineamento Android, no semantica retail nuova)**: rappresenta il **totale finale confermato dell'inventario**, non un «parziale retail». **Solo** le righe dati con **`complete[i] == true`** (array `complete` allineato alle righe griglia, vedi Contratto difensivo) concorrono; per ciascuna, si calcola prima **qty** (griglia **merge-ata**): se **`realQuantity`** e' **vuota o non numerica** → usare **`quantity`**; se **`realQuantity`** e' **numerica** (incluso **`0`**) → usare quel valore — **`0`** e' **conteggio esplicito** dell'utente → **vietato** fallback a **`quantity`**. **Contributo riga a `paymentTotal`**: se **`qty ≤ 0`** (incluso **`0`** e qty **negative** risolte) → contributo **= 0**; se **`qty > 0`** → contributo **= `finalUnitPrice * qty`**, dove **`finalUnitPrice`** e' il risultato della catena prezzo (a)(b)(c). **Nessun** contributo negativo e **nessuna** riduzione del totale per effetto di qty non positive. **`missingItems`** / logica **complete**: **invariata** — una riga resta **complete** anche con **`qty = 0`** (**Decisione #2**). **Prezzo unitario `finalUnitPrice`** (ordine di priorita', **nessuna ambiguita' su `discount`**): (a) **`discountedPrice`** se presente in header e cella **numerica** parsabile; (b) altrimenti, se **`discount`** e' **numerico** e **`0 ≤ discount ≤ 100`** (percentuale): **`purchasePrice_parsato * (1 - discount / 100)`** come prezzo unitario (con **`purchasePrice`** parsato dalla riga; se **`purchasePrice`** non numerico → **0** come prezzo base); se **`discount < 0`**, **`discount > 100`**, **non numerico** o cella assente → trattare **`discount`** come **non valido** e passare a (c); (c) altrimenti **`purchasePrice`** parsato; se non numerico → 0. **Non** adottare **`discount` in `(0...1]`** come fattore moltiplicativo sul prezzo (**semantica esclusa**). **`RetailPrice`** e **`oldRetailPrice`** **non** entrano **mai** in `paymentTotal`. Riga **incompleta** → contributo **0** anche se qty o prezzi compilati. | Somma su tutte le righe; uso `RetailPrice`/`oldRetailPrice`; ignorare `complete`; `discount` come fattore **(0...1]** | Coerenza Android e import; UX/business prevedibile; una sola interpretazione in execution; allineato alle validazioni sui file. | attiva |
| 2 | Regola **`missingItems`**: `missingItems = max(0, rowCount - checked)` con **`rowCount = max(0, mergedGrid.count - 1)`** (righe dati, escluso header). **`checked`**: per ogni indice riga **`i`** con **`1 <= i < mergedGrid.count`**, la riga conta come completata se **`i < complete.count && complete[i] == true`**; altrimenti non completata. **`checked`** e' il **numero** di tali **`i`** completati. **Non** usare `complete.dropFirst().filter { $0 }.count` nel calcolatore: e' equivalente **solo** se **`complete.count == mergedGrid.count`**; con lunghezze disallineate si **sovrastima** o **sottostima** (allineare sempre al **Contratto difensivo §2**). Aggiornare **`entry.totalItems = rowCount`** ad ogni salvataggio riuscito (**SSOT**) cosi' lo chip **articoli** = righe inventario. **`HistoryImportedGridSupport.initialSummary.totalItems`** (conteggio fornitore con qty > 0) **non** e' piu' fonte del **`totalItems`** persistito salvo uguaglianza accidentale con **`rowCount`**. | Continuare a usare `initialSummary`-only count dopo mutazioni | Elimina incoerenza tra import «subset» e griglia reale dopo add/delete; coerente con deleteRow / row count fisico. | attiva |
| 3 | **`orderTotal`** non ricalcolato da editing inventario | Unificare order e paid | CA-4 e comportamento UI esistente; minimo rischio regressione semantica. | attiva |
| 4 | **Stato iniziale** subito dopo **`generateHistoryEntry`** (import): **`paymentTotal = 0`** (nessuna riga **complete**). **`orderTotal`** invariato da **`initialSummary`**. **`totalItems`** / **`missingItems`** da **`HistoryEntryRuntimeSummary`** con tutte le righe dati **incompleti** → mancanti = numero righe dati, articoli = stesso conteggio (**Decisione #2**). | `paymentTotal = orderTotal` storico | Con **Decisione #1**, il «pagato» parte da zero finche' non si confermano righe; coerente con Android e con confronto **ordine vs pagato**. | attiva |
| 5 | **Single source of truth (persistenza in sessione)**: **`saveChanges()`** e' l'**unico** punto che, dopo mutazioni utente nella sessione, **scrive** su `entry` i tre scalari **`paymentTotal`**, **`missingItems`**, **`totalItems`** (oltre ai JSON). Il calcolo numerico usa sempre il **calcolatore runtime puro** (**Decisione #6**). I percorsi **`deleteRow`**, **`ManualEntrySheet`**, scanner, mark-complete, ecc. **non** assegnano piu' direttamente quei tre campi: solo **`markDirtyAndScheduleAutosave()`** / equivalenti (o chiamate che convergono su **`saveChanges`**). **Eccezioni atomiche**: **`generateHistoryEntry`**, **`revertToImportSnapshot`**, **`revertToOriginalSnapshot`** (e restore da backup) devono impostare uno snapshot **coerente** applicando lo **stesso** calcolatore sulla coppia **(griglia merge-ata, complete)** risultante **oppure** valori equivalenti dimostrati uguali all'output del calcolatore — **vietata** formula ad hoc divergente. | Ogni call site aggiorna i summary in modo duplicato | Elimina drift tra delete/manual e save; riduce bug tipo scanner senza `totalItems`. | attiva |
| 6 | **Separazione helper**: introdurre **`HistoryEntryRuntimeSummary`** (file dedicato nel target) con API pura (es. `static func compute(from mergedGrid: [[String]], complete: [Bool]) -> RuntimeSummary` con campi `totalItems`, `missingItems`, `paymentTotal` secondo Decisioni #1–2). **`HistoryImportedGridSupport.initialSummary`** resta **solo** per il totale ordine fornitore alla creazione; **nessun** metodo «inventario runtime» in quel tipo. Il **contratto difensivo** dell'helper e' obbligatorio (sezione Planning **Contratto difensivo**). | Unificare tutto in `HistoryImportedGridSupport` | Evita ambiguita' tra summary fornitore e stato inventario salvato. | attiva |
| 7 | **Riepilogo live `GeneratedView.summarySection` — strategia A (scelta operativa)**: con **SSOT** su `saveChanges()`, `entry.totalItems` / `entry.missingItems` possono restare **stale** fino ad autosave/Fine. Per **non regressione UX**, le righe **«Articoli totali»** e **«Da completare»** devono usare **solo** `@State` **`data`** e **`complete`** con le **stesse** formule di **Decisione #2**: `rowCount = max(0, data.count - 1)`; **`checked`** = conteggio di **`i`** in **`1..<data.count`** con **`i < complete.count && complete[i]`**; **`missing = max(0, rowCount - checked)`**. **`entry.orderTotal`** resta la fonte per il totale ordine **iniziale**. **Strategia B** (lag su `entry` per quei due campi) **non** adottata. **Non** si allarga il task al «pagato» nel riepilogo. | Strategia B — lag su entry accettato | Mantiene coerenza immediata UI durante edit senza duplicare persistenza ne' estendere il perimetro al payment live. | attiva |
| 8 | **Layout chip `HistoryRow` (prescrittivo)**: **due righe orizzontali stabili** — riga 1: chip articoli, ordine, pagato (ordine invariato rispetto all'attuale sequenza dei primi tre); riga 2: chip **mancanti** + eventuale chip **errori**. Implementazione consigliata: `VStack(alignment: .leading, spacing: …)` con due `HStack` + `spacing` uniforme; **no** `lineLimit(1)` con truncation sui chip; **no** riduzione font aggressiva rispetto agli altri chip della card; valori sempre **non troncati** (numeri e soldi interi in vista). | Una sola riga con wrap imprevedibile; font piccolo ad hoc | Direzione chiara per Codex; leggibilita' su schermo stretto. | attiva |

---

## Planning (Claude)

### Obiettivo
Allineare **`paymentTotal`**, **`missingItems`**, **`totalItems`** persistiti al calcolatore **runtime** + **SSOT** su **`saveChanges()`**, con **`paymentTotal`** conforme a **Decisione #1** (parity **Android** — vedi **Decisione finale vs Android**). Stato iniziale post-import (**Decisione #4**); **`HistoryView`** chip mancanti + layout **due righe** (**Decisione #8** / **CA-7**). **Anti-regressione** **`GeneratedView.summarySection`**: **Decisione #7** (**CA-8**); **non** «pagato» live nel riepilogo.

### Decisione finale `paymentTotal` vs Android (allineamento esplicito)
- Il task **riallinea iOS al comportamento funzionale Android** di riferimento del progetto: **`paymentTotal`** = totale inventario **confermato** (solo righe **complete**), su base **acquisto / sconto** (`purchasePrice`, `discountedPrice`, `discount`, `quantity`, `realQuantity`), **non** una nuova semantica **retail** su righe parziali.
- **Non** si adotta la formula **`realQuantity × RetailPrice`** (né `oldRetailPrice`) per `paymentTotal`; righe **incomplete** **non** contribuiscono, anche se hanno qty o retail compilati — scelta deliberata di **UX** e **coerenza semantica** con **`orderTotal`** (ordine fornitore) vs **«pagato»** (inventario confermato).
- **Qty risolta `≤ 0`**: contributo riga a **`paymentTotal` = 0**; **`qty > 0`** → **`finalUnitPrice * qty`** (**Decisione #1**). Evita totali negativi e semantiche ambigue; **`missingItems`** / riga **complete** con qty 0 **invariati** rispetto a **Decisione #2**.
- **Motivazione registrata**: migliore chiarezza della **History card**; confronto **stabile** tra **ordine** e **pagato**; comportamento meno «rumoroso» durante editing/scanner; **stabilita'** rispetto al riferimento Android.

### Analisi (stato codice iOS)

**Nomenclatura progetto (vs Android):** non esistono file `GeneratedScreen` / `ExcelViewModel` / `HistoryScreen`. Gli equivalenti sono **`GeneratedView`**, **`ExcelSessionViewModel`**, **`HistoryView`**.

1. **Persistenza modello** (`HistoryEntry.swift`): `paymentTotal`, `missingItems`, `totalItems`, `orderTotal` sono proprieta' scalari SwiftData; la griglia vive in JSON (`dataJSON`, `editableJSON`, `completeJSON`).

2. **Creazione sessione import** (`ExcelSessionViewModel.generateHistoryEntry`): `HistoryImportedGridSupport.initialSummary(forGrid:)` calcola **`orderTotal`** (e un conteggio storico fornitore non piu' usato come `totalItems` persistito sotto le nuove regole). Stato iniziale **runtime** su modello: **`paymentTotal`**, **`totalItems`**, **`missingItems`** secondo **Decisione #4** + output di **`HistoryEntryRuntimeSummary`** sulla griglia iniziale e `complete` tutti `false`.

3. **Sessione manuale** (`createManualHistoryEntry`): entry con griglia vuota; `totalItems` / `missingItems` / totali monetari restano ai default (0) finche' la griglia non viene popolata — combinato con scanner che aggiunge righe **senza** aggiornare `totalItems`, produce incoerenze sui riassunti persistiti.

4. **Salvataggio** (`GeneratedView.saveChanges()`): merge `editable` → colonne `realQuantity` / `RetailPrice` in copia `newData`, poi scrive `entry.data`, `entry.editable`, `entry.complete`. Aggiorna **`missingItems = max(0, entry.totalItems - checked)`** ma **non** `paymentTotal`. Non ricalcola **`entry.totalItems`** in questo metodo (dipende da altri call site). **`checked`** oggi e' **`complete.dropFirst().filter { $0 }.count`**: equivale al contratto indicizzato (**Decisione #2**) **solo se** `complete.count == data.count`; se mai diverso (dati corrotti / bug), puo' sovrastimare o sottostimare — execution deve usare la formula **per indice riga** allineata al **Contratto difensivo §2**.

5. **UI GeneratedView — riepilogo** (`summarySection`): oggi **`inventoryCheckedCount`** coincide con `complete.dropFirst().filter` (**stessa equivalenza** `complete.count == data.count`); **`missing`** usa **`entry.totalItems - inventoryCheckedCount`** → disallineamento se **`entry.totalItems`** stale (es. scanner senza aggiornamento) rispetto a **`data.count - 1`**. **Decisione #7** rimuove la dipendenza da `entry` per i due conteggi usando **`rowCount`** da `data` e **`checked`** per indici (**Decisione #2**).

6. **`initialSummary` vs righe griglia** (`HistoryImportedGridSupport.initialSummary`): oggi **`totalItems`** li' e' il numero di **righe fornitore con `quantity` parsabile e > 0**, **non** necessariamente **`grid.count - 1`** (righe fisiche). **`generateHistoryEntry`** e **`revertToImportSnapshot`** usano quel valore per **`entry.totalItems`** / **`missingItems`** insieme a **`orderTotal`** — coerente col codice storico ma **in conflitto** con **Decisione #2** (rowCount = righe dati). Dopo TASK-025, **`entry.totalItems`** persistito deve seguire **solo** **Decisione #2**; **`initialSummary`** resta fonte **solo** di **`orderTotal`** (e non va riusato come `entry.totalItems` salvo coincidenza dimostrata).

7. **UI Cronologia** (`HistoryRow`): legge scalari su `entry` per **articoli / ordine / pagato**; **`missingItems`** oggi **non** e' mostrato — il task aggiunge il chip. Nessun ricalcolo da JSON in lista: dopo `save()` i valori devono essere gia' corretti sul modello. **Layout attuale**: un solo **`HStack`** con articoli+ordine+pagato **e** (se presente) chip errori sulla **stessa** riga — **Decisione #8** impone **due** righe (errori in riga 2 con mancanti).

8. **Uscita / flush**: `onDisappear`, cambio `scenePhase`, tasto **Fine** chiamano **`flushAutosaveNow()`** → **`saveChanges()`** se `hasUnsavedChanges`. Il punto unico principale per ricalcolo persistito resta **`saveChanges()`** (+ eventuali path che scrivono `entry` senza passare da li' — vanno elencati in execution).

9. **Percorsi che mutano dati rilevanti** (non esaustivo — execution verifichi grep):
   - Edit quantita'/prezzo: dettaglio riga, celle collegate a `editable`, scanner incremento qty.
   - Complete/incomplete: `setComplete`, `requestSetComplete`, mark-all, `syncCompletionForRow`, force-complete dialog.
   - Righe: `deleteRow`, `handleScannedBarcode` (nuova riga manuale), `ManualEntrySheet` (`onSave` aggiorna `totalItems`), possibili path import analisi / apply.
   - Revert: `revertToOriginalSnapshot`, `revertToImportSnapshot` (gia' reimpostano totali e `missingItems` in linea con snapshot).
   - Sync DB: `syncWithDatabase` → `saveChanges()` poi ricarica `data` da `entry`.

**Ipotesi causa radice (sintesi):**
- **paymentTotal**: **mancato ricalcolo** coerente con **Android** (solo righe **complete**, prezzi **acquisto/sconto**) e persistenza — valore storico iOS spesso «congelato» su **`orderTotal`** o su logica non allineata.
- **missingItems** / **totalItems**: mix tra **semantica import** e **conteggio righe** + **`totalItems` non aggiornato** su alcuni percorsi (es. scanner manuale) → **persistenza numericamente errata** anche se `saveChanges` gira; inoltre possibile **lag** di max ~0.8s per autosave (debounce) — accettabile se CA richiedono «dopo autosave o Fine».

**Tipo di fix atteso:** **logica + persistenza** secondo **SSOT** (**Decisione #5**) + **nuovo file** calcolatore (**Decisione #6**, contratto difensivo sotto) + **modifica UI** `HistoryView` (**Decisione #8** / **CA-7**) + aggiustamento **minimo** `summarySection` per **Decisione #7** (**CA-8**). Lista **Cronologia** via `@Query` dopo `save()`.

### Contratto difensivo: `HistoryEntryRuntimeSummary`
Obbligatorio per **implementazione e review**; l'helper **non** deve mai assumere griglia perfettamente allineata alla UI.

1. **Header**: la **riga 0** di `mergedGrid` e' sempre **esclusa** dai calcoli su righe dati (solo metadati colonne).
2. **`complete` (array) vs righe dati**: `rowCount = max(0, mergedGrid.count - 1)`. Per ogni indice griglia `i` in `1..<mergedGrid.count`, lo stato **completo** e' `complete[i]` se `i < complete.count`, altrimenti **`false`**. **`checked`** (per **Decisione #2**): numero di indici interi **`i`** con **`1 ≤ i < mergedGrid.count`**, **`i < complete.count`**, e **`complete[i] == true`**. **`missingItems`** = **`max(0, rowCount - checked)`**. **`paymentTotal`**: iterare solo righe con flag completo **`true`** come sopra; se `false`, contributo riga = **0** (indipendentemente da qty/prezzi). **Non** usare una colonna griglia chiamata `complete` per questa decisione se in conflitto: prevale l'array **`complete`** passato a `compute` (coerente con persistenza SwiftData). Se la griglia ha anche colonna testuale `complete`, execution verifica coerenza con `saveChanges`.
3. **Lunghezze disallineate**: se `complete.count != mergedGrid.count` (o assenza header), **nessun crash**; clamp come al punto 2; output sempre definito.
4. **Colonne letture per `paymentTotal` (solo righe complete)**: risolvere indici header per **`realQuantity`**, **`quantity`**, **`purchasePrice`**, **`discountedPrice`**, **`discount`**. **Qty effettiva**: stessa semantica **Decisione #1** — `realQuantity` **parsato come numero** (incluso **`0`**) vince; solo **`realQuantity`** vuota/non numerica attiva fallback su **`quantity`**. **Dopo** aver risolto **`qty`**: se **`qty ≤ 0`** → **contributo riga = 0**; se **`qty > 0`** → contributo = **`finalUnitPrice * qty`**. Il calcolatore **non** deve mai **sottrarre** importi dal totale ne' produrre **contributi negativi** da qty non positive (totale = somma di contributi **≥ 0**). **Non** leggere **`RetailPrice`** né **`oldRetailPrice`** per `paymentTotal` (**vietato**). Se un indice manca nell'header → per quella colonna valore = assente (qty/prezzo secondo fallback **Decisione #1**). Se `row.count <= index` → cella vuota. **Nessun** crash su righe corte o malformed.
5. **`missingItems` / `totalItems`**: secondo **Decisione #2** (inclusa definizione **`checked`** per indici riga, §2); stesso parsing sicuro su lunghezze; **nessun** crash se colonne acquisto assenti (solo impatto su contributi a zero dove applicabile).
6. **Parsing numeri e `discount`**: **una** funzione interna centralizzata (europeo `,` → `.`, trim, vuoto / non numerico → trattamento definito in **Decisione #1** per qty e prezzi). **`discount`**: **solo** semantica **percentuale** — valido se numerico e **`0 ≤ discount ≤ 100`**; prezzo da sconto = **`purchasePrice * (1 - discount / 100)`** (con `purchasePrice` gia' parsato per la riga). Valori **`< 0`** o **`> 100`** o non numerici → **`discount`** trattato come **assente** (si applica il fallback della catena **Decisione #1**). **Vietato** usare **`discount` in `(0...1]`** come moltiplicatore diretto sul prezzo.
7. **Determinismo**: stessi input (griglia + `complete`) → stesso `RuntimeSummary`; nessuna dipendenza da `Date`, locale UI o stato globale; griglia vuota o solo-header → `totalItems`/`missingItems`/`paymentTotal` coerenti con **Decisioni #2** e **#4**.
8. **Nessuna mutazione**: `compute` e' **puro** — non modifica input, non scrive su `ModelContext`.

### Approccio proposto
1. Aggiungere **`HistoryEntryRuntimeSummary.swift`**: struttura risultato + **`compute(from mergedGrid:complete:)`** che rispetta il **Contratto difensivo** e implementa **Decisioni #1** e **#2**.
2. In **`GeneratedView.saveChanges()`**, dopo aver costruito **`newData`** (merge `editable` → colonne come oggi): invocare il calcolatore; assegnare **`entry.totalItems`**, **`entry.missingItems`**, **`entry.paymentTotal`**; **non** modificare **`entry.orderTotal`**. Rimuovere dal file ogni assegnazione diretta ai tre campi fuori da questo flusso e dalle **eccezioni atomiche** (**Decisione #5**).
3. **`ExcelSessionViewModel.generateHistoryEntry`**: dopo creazione `filteredData` / `complete`, impostare **`entry.orderTotal`** **solo** dalla componente monetaria di **`initialSummary`** (come oggi); **`entry.paymentTotal`**, **`entry.totalItems`**, **`entry.missingItems`** **solo** da **`HistoryEntryRuntimeSummary.compute`** — **non** riusare **`initialSummary.totalItems`** per **`entry.totalItems`** (vedi **Analisi §6** / **Decisione #2**). Rispettare **Decisione #4** ( **`paymentTotal == 0`**, mancanti = righe dati se tutte incomplete).
4. **Revert L1/L2** e **restore backup**: sostituire assegnazioni manualle sparse con invocazione al calcolatore sulla griglia risultante **oppure** snapshot gia' equivalente; dopo operazione, se il codice gia' chiama **`saveChanges()`**, verificare che non si sovrascriva con valori obsoleti.
5. **`HistoryView` / `HistoryRow`**: chip **`missingItems`** + layout **due righe** come **Decisione #8** / **CA-7**; stringhe **L(...)** in tutte le lingue del target.
6. **`GeneratedView.summarySection`**: applicare **Decisione #7** (**CA-8**) — sostituire letture `entry.totalItems` / dipendenze stale per i conteggi con calcolo da `data`/`complete`.
7. Smoke opzionale: confronto comportamentale **pagato** (solo complete, acquisto/sconto) e **mancanti** vs Android, senza portare Kotlin pari-pari.

### File da modificare (lista operativa)
| File | Modifica |
|------|----------|
| `HistoryEntryRuntimeSummary.swift` (**nuovo**) | Calcolatore **runtime** puro + **Contratto difensivo**; **nessun** accoppiamento a `initialSummary`. |
| `GeneratedView.swift` | **`saveChanges()`** + rimozione write dirette a summary da altri metodi; **`summarySection`** per **Decisione #7** (**CA-8**); revert/sync. |
| `ExcelSessionViewModel.swift` | **`generateHistoryEntry`**: `orderTotal` da `initialSummary`; altri summary da **RuntimeSummary**; **`createManualHistoryEntry`**: confermare zeri fino a griglia (coerente con compute su griglia solo header / vuota). |
| `HistoryView.swift` | Chip **mancanti** + layout **due righe** (**Decisione #8**). |
| Localizzazioni | Nuova stringa titolo chip mancanti. |
| `HistoryImportedGridSupport.swift` | **Nessun** nuovo metodo runtime; lasciare **`initialSummary`** per solo-fornitore. |

### Rischi identificati
- **Implementazione `discount`**: rischio di deviazione (es. fattore **`(0...1]`** invece di percentuale **`0...100`**) — mitigato da **Decisione #1**, **Contratto difensivo §6** e **guardrail** in Handoff; review verifica coerenza con **T-11**.
- **Stato iniziale #4**: se il prodotto richiede chip «pagato» = ordine fornitore **prima** di confermare righe, va **rifiutata** `paymentTotal = 0` prima di EXECUTION (impatto CA-6) — **non** il caso della decisione corrente.
- **Performance**: griglie molto grandi — il ricalcolo e' O(righe); accettabile se eseguito solo su save (stesso ordine di grandezza del loop gia' presente in `saveChanges`).
- **Regressioni TASK-018**: revert L1/L2 e backup devono restare coerenti con **RuntimeSummary** + **SSOT** (nessun valore ripristinato che venga subito sovrascritto in modo incoerente da un secondo save). **L2 oggi** imposta **`entry.totalItems` / `missingItems` / `paymentTotal`** da **`initialSummary`** sullo snapshot — **diverso** da **Decisione #2** quando esistono righe dati con qty fornitore `<= 0` o non parsabile; execution **sostituisce** con **`HistoryEntryRuntimeSummary.compute`** sulla griglia post-revert ( **`orderTotal`** resta da **`initialSummary`** / fornitore).
- **Griglie senza colonne acquisto/sconto**: colonne `purchasePrice` / `discountedPrice` / `discount` assenti → contributi `paymentTotal` tipicamente 0 per righe complete finche' non si aggiungono colonne o dati; **nessun** crash.
- **Reintroduzione retail in `paymentTotal`**: rischio implementativo — mitigato da **guardrail** in Handoff e review su **CA-1** / **T-12**.
- **UI / i18n**: nuova chiave in **tutte** le lingue attive del target; layout **due righe** (**Decisione #8**) su iPhone stretto / Dynamic Type — verificare in Simulator.
- **Non-regressione riepilogo**: se **CA-8** non e' soddisfatta, la strategia **A** (**Decisione #7**) non e' stata applicata → **CHANGES_REQUIRED**.

### Handoff → Execution
- **Prossima fase**: EXECUTION
- **Prossimo agente**: CODEX
- **Guardrail obbligatori (review-blocking se violati)**:
  - **`paymentTotal`**: **non** reintrodurre **`realQuantity × RetailPrice`** (né **`oldRetailPrice`**) come base del totale; **non** sommare righe con **`complete != true`**.
  - **`paymentTotal` non** deve **mai diminuire** per effetto di qty **negative** o **zero** (nessuna sottrazione dal totale per qty non positive); **qty `≤ 0`** ⇒ **contributo riga nullo** (**0**).
  - Verificare che ogni contributo a **`paymentTotal`** rispetti **integralmente Decisione #1** (qty `realQuantity`→`quantity`, poi gate **`qty ≤ 0` → 0**, **`qty > 0` → `finalUnitPrice * qty`**; prezzo `discountedPrice`→**`discount` percentuale `0...100`** con **`purchasePrice * (1 - discount/100)`**→`purchasePrice`).
  - **`missingItems` / `checked`**: implementare **`checked`** come in **Contratto §2** / **Decisione #2** (per indice riga **`1..<grid`**, non **`dropFirst().filter`** nell'helper).
  - **`generateHistoryEntry` / L2**: **non** copiare **`initialSummary.totalItems`** su **`entry.totalItems`**; usare output **`RuntimeSummary`** ( **`orderTotal`** da **`initialSummary`** solo per **`entry.orderTotal`**).
  - **`discount`**: implementare **solo** come **percentuale `0...100`** su **`purchasePrice`** (**vietato** fattore **`(0...1]`**).
- **Azione consigliata**:
  1. Leggere **Decisione finale vs Android**, **Contratto difensivo**, **Decisioni #1–8**, **CA-1..CA-9** (inclusa formula **`discount`** definitiva).
  2. Creare **`HistoryEntryRuntimeSummary.swift`** (Contratto difensivo incluso colonne **acquisto/sconto** e gate **`complete`**).
  3. Integrare in **`saveChanges()`** e **`generateHistoryEntry`**; **grep** write sui summary; **SSOT** (**Decisione #5**).
  4. **`HistoryView` / `HistoryRow`**: chip **mancanti** + layout **due righe** (**CA-7**); localizzazioni.
  5. **`GeneratedView.summarySection`**: **Decisione #7** (**CA-8**); **non** «pagato» nel riepilogo.
  6. Build Debug; **Execution** + matrice **T-0..T-15** (inclusi **T-9** qty fallback, **T-13** `realQuantity` = 0, **T-14** qty negativa, **T-15** `initialSummary.totalItems` ≠ rowCount) + **CA-7**/**CA-8**.
  7. Handoff a **REVIEW** / CLAUDE.

---

## Execution (Codex) ← solo Codex aggiorna questa sezione

### Obiettivo compreso
Implementare il ricalcolo runtime/persistito di `paymentTotal`, `missingItems` e `totalItems` secondo le Decisioni #1-#8, mantenendo `saveChanges()` come SSOT in sessione, stato iniziale coerente da `generateHistoryEntry`, nuovo chip `missingItems` in `HistoryView` e anti-regressione UX su `GeneratedView.summarySection`.

### File controllati
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-025-generatedview-ricalcolo-paymenttotal-missingitems-history-card.md`
- `iOSMerchandiseControl/GeneratedView.swift`
- `iOSMerchandiseControl/HistoryView.swift`
- `iOSMerchandiseControl/HistoryEntry.swift`
- `iOSMerchandiseControl/ExcelSessionViewModel.swift`
- `iOSMerchandiseControl/HistoryImportedGridSupport.swift`
- `iOSMerchandiseControl/InventorySyncService.swift`
- `iOSMerchandiseControl/en.lproj/Localizable.strings`
- `iOSMerchandiseControl/it.lproj/Localizable.strings`
- `iOSMerchandiseControl/es.lproj/Localizable.strings`
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`

### Piano minimo
1. Riallineare il tracking a `TASK-025` unico task attivo in `EXECUTION`.
2. Introdurre un helper puro per il runtime summary e usarlo in `saveChanges()`, `generateHistoryEntry` e revert previsti dal planning.
3. Rimuovere write dirette fuori scope ai summary persistiti, preservando `orderTotal` come totale ordine iniziale.
4. Aggiornare `GeneratedView.summarySection`, `HistoryView` e localizzazioni nel minimo necessario.

### Modifiche fatte
- Riallineato il tracking operativo: `MASTER-PLAN` e file task portati da `PLANNING` a `EXECUTION`, poi a `REVIEW` al termine dell'implementation.
- Aggiunto `iOSMerchandiseControl/HistoryEntryRuntimeSummary.swift` come helper puro per `totalItems`, `missingItems` e `paymentTotal`, con formula `paymentTotal` conforme al planning: solo righe `complete == true`, `realQuantity` prevale su `quantity` anche quando vale `0`, `qty <= 0` => contributo `0`, priorità prezzo `discountedPrice` -> `discount` percentuale `0...100` su `purchasePrice` -> `purchasePrice`, nessun uso di `RetailPrice`/`oldRetailPrice`.
- Aggiornato `GeneratedView.saveChanges()` per usare il nuovo helper come SSOT dei summary persistiti in sessione (`entry.totalItems`, `entry.paymentTotal`, `entry.missingItems`), lasciando invariato `entry.orderTotal`.
- Rimosse write dirette fuori scope ai summary in percorsi ordinari (`ManualEntrySheet.onSave`, `deleteRow`) e spostata la coerenza sul save; mantenuta l'eccezione atomica prevista per `revertToOriginalSnapshot()` via helper runtime, mentre `revertToImportSnapshot()` riallinea `orderTotal` e converge subito su `saveChanges()`.
- Aggiornato `ExcelSessionViewModel.generateHistoryEntry()` per inizializzare `orderTotal` da `HistoryImportedGridSupport.initialSummary` e `paymentTotal` / `missingItems` / `totalItems` da `HistoryEntryRuntimeSummary`, ottenendo stato iniziale coerente (`paymentTotal = 0`, `missingItems = rowCount`, `totalItems = rowCount` con tutte le righe incomplete).
- Aggiornato `GeneratedView.summarySection` e i conteggi locali (`inventoryCheckedCount`, `allRowsComplete`, `markAllComplete`) per usare `data`/`complete` come fonte live dei valori "Articoli totali" e "Da completare", evitando regressioni UX prima dell'autosave.
- Aggiornato `HistoryView` con nuovo chip `missingItems`, layout stabile a due righe (riga 1: articoli/ordine/pagato; riga 2: mancanti/errori) e nuove chiavi localizzate in `en`, `it`, `es`, `zh-Hans`.

### Check eseguiti
- ✅ ESEGUITO — Build compila (Xcode / BuildProject): `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'generic/platform=iOS Simulator' build` → `** BUILD SUCCEEDED **`.
- ✅ ESEGUITO — Nessun warning nuovo introdotto (se verificabile): la build ha mostrato un warning preesistente in `iOSMerchandiseControl/ContentView.swift` sulla chiamata a `PriceHistoryBackfillService.backfillIfNeeded(context:)`; nessun nuovo warning emerso nei file toccati da TASK-025.
- ✅ ESEGUITO — Modifiche coerenti con il planning: verificati staticamente i guardrail su formula `paymentTotal`, SSOT su `saveChanges()`, stato iniziale `generateHistoryEntry`, eccezioni atomiche `revert`, anti-regressione `GeneratedView.summarySection`, chip/layout `HistoryView`.
- ✅ ESEGUITO — Criteri di accettazione verificati: copertura statica di `CA-1..CA-9` sui file toccati e build verde; le verifiche Simulator/manuali della matrice `T-0..T-15` non erano richieste esplicitamente in questo turno e non sono state eseguite.

### Rischi rimasti
- Verifica UI non eseguita in Simulator/manuale su larghezze strette e Dynamic Type per `HistoryView` (`CA-7`): il layout e' implementato secondo planning, ma manca conferma visiva diretta.
- La formula `paymentTotal` e i casi `discount`/`qty <= 0` sono verificati staticamente e via build, non con scenari runtime manuali della matrice `T-1`, `T-8..T-15`.
- Resta un warning preesistente fuori scope in `ContentView.swift`; TASK-025 non lo modifica ne' lo aggrava.

### Handoff → Review
- **Fase completata**: EXECUTION → REVIEW
- **Prossimo agente**: CLAUDE
- **File toccati**:
  - `docs/MASTER-PLAN.md`
  - `docs/TASKS/TASK-025-generatedview-ricalcolo-paymenttotal-missingitems-history-card.md`
  - `iOSMerchandiseControl/HistoryEntryRuntimeSummary.swift`
  - `iOSMerchandiseControl/GeneratedView.swift`
  - `iOSMerchandiseControl/ExcelSessionViewModel.swift`
  - `iOSMerchandiseControl/HistoryView.swift`
  - `iOSMerchandiseControl/en.lproj/Localizable.strings`
  - `iOSMerchandiseControl/it.lproj/Localizable.strings`
  - `iOSMerchandiseControl/es.lproj/Localizable.strings`
  - `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`
- **Sintesi implementazione**: summary runtime centralizzato in helper puro; `saveChanges()` e' ora il writer persistito dei summary di sessione; `generateHistoryEntry()` parte con summary coerenti; `revertToOriginalSnapshot()` usa la stessa logica runtime; `HistoryView` espone `missingItems` su seconda riga; `GeneratedView.summarySection` usa solo stato locale per "Articoli totali" / "Da completare".
- **Verifiche eseguite**: build Debug iphonesimulator OK; review statica sui guardrail del planning e sui CA.
- **Punti da rivedere in REVIEW**: conferma che `paymentTotal` segua esattamente Decisione #1 in tutti gli edge case (`discount`, `discountedPrice`, `realQuantity = 0`, qty negative), e che il layout a due righe in `HistoryView` sia accettabile rispetto a `CA-7` senza test manuale eseguito in questo turno.

---

## Review (Claude) ← solo Claude aggiorna questa sezione

### Esito: **APPROVED**

**Data review**: 2026-03-25
**Reviewer**: CLAUDE
**Build verificata**: Debug iphonesimulator — `** BUILD SUCCEEDED **`

### Problemi critici
Nessuno.

### Problemi medi
Nessuno.

### Miglioramenti opzionali (non richiesti ora)
Nessuno.

### Fix richiesti
Nessuno.

### Verifica CA

| CA | Esito statico | Note |
|----|---------------|------|
| CA-1 | PASS | `HistoryEntryRuntimeSummary.compute`: solo righe `complete == true`, qty `realQuantity` > fallback `quantity`, gate `qty <= 0` → 0, catena prezzo corretta, no retail. `max(0, finalUnitPrice)` extra-difensivo. |
| CA-2 | PASS | `checked` calcolato per indice riga (`1..<mergedGrid.count` con `i < complete.count && complete[i]`), non `dropFirst().filter`. |
| CA-3 | PASS | `deleteRow`, ManualEntrySheet onSave, `handleScannedBarcode`: nessuna write diretta ai summary; convergono su `markDirtyAndScheduleAutosave()` → `saveChanges()` → `applyRuntimeSummary()`. |
| CA-4 | PASS | `entry.orderTotal` non toccato da `saveChanges()` ne' da `applyRuntimeSummary()`. Solo impostato in `generateHistoryEntry` (da `initialSummary`) e `revertToImportSnapshot` (da `initialSummary`). |
| CA-5 | PASS | L1: `revertToOriginalSnapshot` → `mergedGridSnapshot` → `applyRuntimeSummary`. L2: `revertToImportSnapshot` → `saveChanges()` → `applyRuntimeSummary`. Restore backup → `applyRuntimeSummary` con valori backup. |
| CA-6 | PASS | `generateHistoryEntry`: `paymentTotal`, `totalItems`, `missingItems` da `HistoryEntryRuntimeSummary.compute` con `complete` tutto `false` → `paymentTotal = 0`, `totalItems = rowCount`, `missingItems = rowCount`. |
| CA-7 | PASS | `HistoryRow`: VStack di due HStack; riga 1: articoli/ordine/pagato; riga 2: mancanti + errori. `HistorySummaryChip` con VStack titolo/valore, `.fixedSize`, `.frame(maxWidth: .infinity)` — no truncation. Stringhe localizzate in 4 lingue. |
| CA-8 | PASS | `summarySection`: usa `inventoryTotalCount` (= `max(0, data.count - 1)`) e `inventoryCheckedCount` (index-based su `data`/`complete`); nessuna dipendenza da `entry.totalItems`/`entry.missingItems`. `entry.orderTotal` per totale ordine iniziale. |
| CA-9 | PASS | Build Debug OK, nessun nuovo warning introdotto. |

### Verifica contratto difensivo
Tutte le 8 clausole rispettate. Header esclusa, lunghezze disallineate gestite senza crash, colonne mancanti → valori assenti, parsing centralizzato con supporto locale europeo e `%` suffix, determinismo, purezza.

### Verifica guardrail handoff
- No retail in `paymentTotal` ✓
- No contributi negativi da qty ≤ 0 ✓
- Formula completa Decisione #1 rispettata ✓
- `checked` per indice riga, non `dropFirst().filter` ✓
- `generateHistoryEntry`/L2: `initialSummary` solo per `orderTotal` ✓
- `discount` solo percentuale 0...100 ✓

### Note non bloccanti
- `max(0, resolvedFinalUnitPrice(...))` (L30 helper): difensivo extra rispetto al planning (che gate solo su qty), ma coerente con principio "nessun contributo negativo". Non e' un problema.
- `HistorySummaryChip` riprogettato con VStack titolo/valore (anziché HStack inline): scelta Codex non prescritta, migliora leggibilita' su schermi stretti. Accettabile.

### Rischi residui non bloccanti
- Verifica UI non eseguita in Simulator: layout due righe su iPhone SE / Dynamic Type da confermare in test manuali (T-0, CA-7).
- Formula `paymentTotal` e edge case discount/qty verificati staticamente, non con scenari runtime manuali (T-1, T-8..T-15).

### Sospensione tracking (2026-03-25)
- **Motivo**: review tecnica **APPROVED** acquisita; **test manuali utente** (T-0..T-15) **non ancora eseguiti**; task **non** chiusa in **DONE**.
- **Stato task**: **BLOCKED** — congelata in attesa di futura validazione manuale.
- **Alla ripresa**: eseguire test manuali → se regressioni → **FIX** (Codex) → **REVIEW** (Claude) → conferma utente → **DONE**. Se i test passano senza fix → **REVIEW** finale di chiusura (se necessario) → conferma utente → **DONE**.

---

## Fix (Codex) ← solo Codex aggiorna questa sezione

_(vuoto)_

---

## Chiusura

### Conferma utente
- [ ] Utente ha confermato il completamento

### Follow-up candidate
- **Solo** preview live del totale **«pagato»** (`paymentTotal` persistito) dentro **`GeneratedView.summarySection`** / riepilogo schermata — **fuori perimetro** **TASK-025** (gia' escluso da **Perimetro esplicito** / **CA-8**). **Non** e' follow-up: allineamento **«Articoli totali»** e **«Da completare»** al solo stato locale `data`/`complete` — gia' **in scope** (**Decisione #7**, **CA-8**).

### Riepilogo finale
_(al DONE)_

### Data completamento
_(al DONE)_

---

## Matrice test manuali post-execution (obbligatorieta' da task / review)

| ID | Scenario | Pass attesi |
|----|----------|-------------|
| T-0 | Subito dopo **generateHistoryEntry**, tornare a **Cronologia** (nessuna riga ancora **complete**) | **CA-6**: **pagato** = **0**; **ordine** = `orderTotal` fornitore; **mancanti** = righe dati; layout (**CA-7**). |
| T-1 | Import con colonne acquisto; compilare qty (`realQuantity` o `quantity`); segnare **complete** su 1–2 righe con valori noti; autosave/Fine → Cronologia | **CA-1**: **pagato** = somma **Decisione #1** solo su righe **complete** (verifica manuale a campione). |
| T-2 | Stessa sessione: meta' righe **complete**, meta' **incomplete** | **Mancanti** e **pagato**: righe incomplete **non** aumentano **pagato** anche se hanno qty/prezzi; chip coerenti (**CA-7**). |
| T-3 | Inventario **manuale**: scanner / righe nuove | **Articoli** / **mancanti** coerenti; **pagato** solo se righe **complete** e formula #1. |
| T-4 | Eliminare una riga | Summary + chip dopo save coerenti. |
| T-5 | **Revert import** (L2) | `paymentTotal` / `missingItems` / `totalItems` coerenti con calcolatore post-revert. |
| T-6 | **Revert sessione** (L1) | Come T-5. |
| T-7 | **Mark all** complete / incomplete | **Mancanti** 0 o = rowCount; **pagato** rispetta solo righe complete. |
| T-8 | Due righe simili: una **complete** con qty/prezzo noti, altra **incomplete** con stessi numeri in griglia | **Pagato** include **solo** la riga **complete**; l'incompleta **non** contribuisce (**CA-1**). |
| T-9 | Riga **complete** con **`realQuantity`** **vuota o non numerica**, **`quantity`** fornitore > 0 | **Pagato** usa fallback **`quantity`** (**Decisione #1**). |
| T-13 | Riga **complete** con **`realQuantity` = 0** (numerico esplicito) e **`quantity`** fornitore > 0 | Contributo riga a **pagato** = **0** (qty risolta **0**; prezzo × 0); **nessun** fallback a **`quantity`** (**Decisione #1**). |
| T-14 | Riga **complete** con **`realQuantity` = -1** (numerico) **oppure** **`realQuantity`** vuota/non numerica e fallback **`quantity` = -1**; prezzo acquisto > 0 | Contributo riga a **`paymentTotal`** = **0** (qty **`≤ 0`** → contributo nullo); riga resta **complete**; chip **pagato** **non** diminuisce per questa riga (**Decisione #1** / **CA-1**). |
| T-10 | Riga **complete** con **`discountedPrice`** numerico valido (e `purchasePrice` diverso) | **Pagato** usa **`discountedPrice`** come prezzo unitario. |
| T-11 | Riga **complete**, nessun **`discountedPrice`** utilizzabile; **`purchasePrice` = 100**, **`discount` = 20** (percentuale), qty es. **1** | Contributo riga: prezzo unitario **80** (= **100 × (1 − 20/100)**); **pagato** coerente (**Decisione #1** / **T-11**). |
| T-12 | Riga **complete**: modificare **solo** **`RetailPrice`** (o `oldRetailPrice`) tra due salvataggi, lasciando invariati acquisto/sconto/qty e flag complete | **Pagato** **invariato** (retail **non** entra in **Decisione #1**). |
| T-15 | Import in cui esistono **righe dati** in griglia con **`quantity`** fornitore **0**, vuota o non parsabile (riga **presente** ma **esclusa** dal conteggio **`initialSummary.totalItems`** storico). Subito dopo **generate** (prima save) o dopo **Revert import (L2)** | Chip **articoli** = **`data.count - 1`** (tutte le righe fisiche); **mancanti** = stesso valore se nessuna **complete**; **non** il solo conteggio fornitore **`initialSummary.totalItems`** se **minore** del rowCount (**Decisione #2** vs codice pre-TASK-025). |

---

## Indicazione fix (perimetro tecnico)
**Logica + persistenza** + **`HistoryEntryRuntimeSummary`** (contratto difensivo) + **UI `HistoryView`** (**CA-7** / **Decisione #8**) + **aggiustamento minimo** **`GeneratedView.summarySection`** per **Decisione #7** (**CA-8**), **senza** mostrare «pagato» nel riepilogo. Refresh lista dopo `save()`.
