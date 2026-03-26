# TASK-028: GeneratedView — Row Detail UX Refinement vs Android

## Informazioni generali
- **Task ID**: TASK-028
- **Titolo**: GeneratedView: Row Detail UX Refinement vs Android
- **File task**: `docs/TASKS/TASK-028-generatedview-row-detail-ux-refinement.md`
- **Stato**: ACTIVE
- **Fase attuale**: REVIEW (esito: APPROVED — in attesa conferma utente)
- **Responsabile attuale**: UTENTE
- **Data creazione**: 2026-03-26
- **Ultimo aggiornamento**: 2026-03-26
- **Ultimo agente che ha operato**: CLAUDE

## Dipendenze
- **Dipende da**: nessuno
- **Sblocca**: nessuno

## Scopo
Portare il dettaglio riga iOS **non-manuale** (`RowDetailSheetView` — righe da inventario/griglia importata) a parità operativa con Android, in stile Apple-like, senza rifare la logica business. L'obiettivo è un editor compatto "one-stop" dove l'utente capisce subito il prodotto, lo stato, e può agire sui campi chiave senza cercarli e senza scroll eccessivo. **Fuori perimetro:** `ManualEntrySheet` e ogni flusso di entry manuale (vedi Non incluso).

## Contesto
Il dialog Android mostra in un'unica schermata: nome prodotto (primario + secondario), barcode, codice articolo, quantità, prezzo totale, prezzo acquisto vecchio/nuovo, prezzo vendita vecchio, campi editabili (contata, vendita), calcolatrice inline, e azioni primarie (conferma, incompleto). Lo sheet iOS attuale è funzionale ma: (1) molti campi di riga sono già disponibili via `RowEditBindings` / `RowEditSnapshot` passati da `rowDetailSheet(_:)` ma non sono resi visibili nel layout del dettaglio, (2) le Section Form sono troppo ariose e spingono le azioni sotto fold, (3) lo stato/delta non domina abbastanza, (4) le azioni primarie e secondarie hanno lo stesso peso visivo.

## Non incluso
- **`ManualEntrySheet`** e **qualsiasi modifica al flusso di entry manuale** (UI, navigazione, stato) — il task riguarda **solo** il dettaglio riga non-manuale (`RowDetailSheetView`)
- Refactor strutturale del modello persistito (`HistoryEntry`, `Product`) o della griglia in `GeneratedView`
- Refactor import/sync
- Porting 1:1 del dialog Material Android
- Bottom sheet "Material clone" o troppi colori saturi
- Logica business mista alla UI
- Mega refactor della grid
- Duplicare fonti di verità per i valori di cella: niente copia parallela in stato locale se gli stessi dati sono già esposti in modo coerente tramite `RowEditBindings` / `RowEditSnapshot` (estendere `RowDetailData` solo per ciò che il sheet non copre già)

## File potenzialmente coinvolti
- `iOSMerchandiseControl/GeneratedView.swift` — `RowDetailSheetView`, `RowDetailData`, `rowDetailSheet(_:)`, `makeRowDetailData(for:headerRow:isComplete:autoFocusCounted:skipProductNameLookup:)`, `RowEditBindings`, `RowEditSnapshot` (non `ManualEntrySheet`)
- `iOSMerchandiseControl/{en,it,es,zh-Hans}.lproj/Localizable.strings` — nuove/aggiornate chiavi di localizzazione per etichette e badge (4 file `.strings`, uno per lingua)

## Criteri di accettazione
Questi criteri sono il contratto del task. Execution e review lavorano contro di essi.
Se cambiano in corso d'opera, aggiornare QUI prima di proseguire.

- [ ] **CA-1**: Aprendo il dettaglio riga, l'utente vede subito (senza scroll su iPhone standard): stato completamento con badge visivo, identità prodotto (barcode + nome), **delta quantità** (shortage/surplus/match) **solo ove** quantità da file e contata sono entrambe valide e parseabili (Decisione 8), campo contata editabile, campo prezzo vendita editabile, navigazione prev/next
- [ ] **CA-2**: Sono visibili nel dettaglio (con scroll minimo) tutti i campi informativi disponibili: secondProductName, itemNumber, totalPrice, purchasePrice corrente — ognuno solo se il dato è presente nella riga
- [ ] **CA-3**: Le azioni sono separate in due livelli: primarie (contata, prezzo, usa valore vecchio/file, complete/incomplete, prev/next, scan next) vs secondarie (edit row, calcolatrice generale, edit product, storico prezzi, delete row)
- [ ] **CA-4**: Quando il confronto è definito (Decisione 8), il delta quantità è evidenziato con colore semantico e copy esplicito: shortage (arancione), surplus (info), match (verde/neutro); se un lato manca o non è parseabile, **nessun** badge semantico fuorviante
- [ ] **CA-5**: Per ogni CTA «Usa quantità da file» / «Usa vendita vecchia» **per cui esiste** un valore sorgente applicabile, lo shortcut nel body è **raggiungibile senza scroll** dal primo viewport; se la sorgente **non** esiste, la CTA non deve occupare spazio con righe disabilitate salvo eccezione motivata (Decisione 8)
- [ ] **CA-6**: Nessuna regressione su: autosave, **scanner reopen flow**, prev/next row navigation, force-complete con shortage, edit row sheet, edit product, price history, delete row
- [ ] **CA-6b**: **Invariati** rispetto all’implementazione pre-task: **bottom bar** del dettaglio riga, **keyboard toolbar** (presenza e ruolo di acceleratore contestuale), **flusso scanner reopen**, **flusso manual entry** (`ManualEntrySheet` e relative aperture — nessuna modifica a quei percorsi)
- [ ] **CA-7**: Lo stile resta iOS-native: Form/NavigationStack, SF Symbols, spacing e corner radius coerenti col resto app
- [ ] **CA-8**: Funziona correttamente in light/dark mode
- [ ] **CA-9**: La tastiera non copre i campi editabili e il focus auto su counted è preservato
- [ ] **CA-10**: Nessuna perdita di input in corso quando l'utente usa prev/next, scan next, o riapre il dettaglio dopo il flusso scanner (stesso binding / stessa sorgente di verità della griglia)
- [ ] **CA-11**: Focus coerente sul campo contata dopo navigazione tra righe e dopo riapertura del dettaglio (comportamento atteso allineato al flag `autoFocusCounted` / flussi esistenti)
- [ ] **CA-12**: Nessun clipping o layout rotto per le nuove etichette nelle localizzazioni principali usate dall'app (testo visibile, linee non troncate in modo inaccettabile)
- [ ] **CA-13**: Verifica esplicita su **iPhone piccolo** e **iPhone grande** (simulatori o dispositivi), **light** e **dark** mode, per confermare CA-8 e CA-12 insieme al resto del dettaglio riga
- [ ] **CA-14**: Se dopo **Slice 1** il primo viewport su **iPhone piccolo** risulta ancora troppo carico, eseguire un **micro-pass finale** limitato a densità, padding e gerarchia delle etichette **prima** di valutare qualunque estensione di `RowDetailData` (Slice 2); in review, segnalare esplicitamente se questo pass è stato necessario e l’esito
- [ ] **CA-15**: Il primo viewport **non** contiene badge delta né righe read-only prive di dato reale; gli stati “dato assente” sono **neutri** (non confondibili con errori di sync o failure) — vedi anche nota Review

## Decisioni
| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|-------|
| 1 | Usare Form con Section compattate, non card custom; dove serve adattività usare `ViewThatFits` (o equivalente SwiftUI) per preferire layout compatto ma accettare fallback verticale | Solo griglia fissa a due colonne | Mantiene stile iOS e leggibilità su schermi piccoli / stringhe lunghe | attiva |
| 2 | Progressive disclosure rigorosa (above-the-fold): campi read-only secondari — es. `secondProductName`, `itemNumber`, `totalPrice`, `purchasePrice`, `oldRetailPrice` e analoghi — **solo** con valore reale (non vuoto / non solo spazi); **niente** placeholder decorativi tipo `—` nella parte alta del dettaglio | Righe fisse con segnaposto | Stesso principio della Decisione 8; UI più pulita | attiva |
| 3 | Azioni secondarie (edit riga, calcolatrice generale, edit prodotto, storico, delete) restano in basso nella Form, con gerarchia visiva chiara, **senza** competere con contata / prezzo vendita / stato | Mischiare tutte le azioni nello stesso blocco prominente | Priorità cognitive sui campi operativi | attiva |
| 4 | Bottom bar invariata (prev/scan/index/complete/next) | Spostare azioni nella Form | Bottom bar è già funzionale e Apple-like; non toccarla | attiva |
| 5 | Preferire riuso di `RowEditBindings` / `RowEditSnapshot` e helper locali; estendere `RowDetailData` solo se serve per header, stato, navigazione o dati **non** già disponibili nel sheet | Duplicare colonne in `RowDetailData` per comodità | Evita stato duplicato e rischio di dati stale | attiva |
| 6 | Gerarchia CTA «usa quantità da file» / «usa vendita vecchia»: restano nel **body** above-the-fold per soddisfare CA-5, ma con **peso visivo secondario** (shortcut leggero); la **keyboard toolbar** resta l’acceleratore contestuale quando il campo ha focus — evitare doppia enfasi (stesso peso su body e toolbar) | Due livelli entrambi «primary» | CA soddisfatti senza competizione visiva con contata/prezzo; toolbar = in-focus | attiva |
| 7 | `syncError` e warning analoghi: mostrare **solo se presenti**; **non** occupare il primo viewport operativo; priorità above-the-fold: stato, identità prodotto, contata, vendita nuova, navigazione (prev/next implicita nella bottom bar); messaggi di errore **sotto** il blocco operativo principale o in forma **compatta** | Section errori in cima | Leggibilità e flusso operativo prima della diagnostica | attiva |
| 8 | **Dato mancante / ambiguo nel dettaglio riga:** (1) **Badge delta** (shortage / surplus / match): mostrarli **solo** quando **sia** la quantità «da file» **sia** il valore «contata» sono **validi e parseabili** per il confronto; se uno manca o non è valido, **non** mostrare badge semantici fuorvianti. (2) Allineato alla Decisione 2: niente read-only vuoti o `—` in alto. (3) **CTA rapide** «Usa quantità da file» / «Usa vendita vecchia»: restano shortcut **leggeri** nel body (Decisione 6); se il valore sorgente **non esiste**, **preferire** nascondere o collassare la CTA invece di righe disabilitate che occupano spazio, **salvo** che la discoverability peggiori in modo evidente (caso eccezionale da giustificare in execution/review) | Badge sempre visibili; CTA sempre disabilitate in elenco | Onestà percettiva; primo viewport solo contenuto significativo | attiva |

---

## Planning (Claude)

### Analisi

**Stato attuale iOS** (`RowDetailSheetView`, linee ~3102-3579 di `GeneratedView.swift`):
- `RowDetailData` ha 8 campi: rowIndex, barcode, productName, supplierQuantity, oldPurchasePrice, oldRetailPrice, syncError, isComplete, autoFocusCounted
- `rowDetailSheet(_:)` costruisce già `RowEditBindings` e `RowEditSnapshot` con le colonne: `barcode`, `itemNumber`, `productName`, `secondProductName`, `quantity`, `purchasePrice`, `totalPrice`, `retailPrice`, `discountedPrice`, `supplier`, `category` — passati a `RowDetailSheetView` insieme a `countedText` / `newRetailText` e ai callback di navigazione
- `makeRowDetailData(for:headerRow:isComplete:autoFocusCounted:skipProductNameLookup:)` (non esiste `buildRowDetailData`) alimenta oggi soprattutto identità/nome (con lookup DB opzionale), quantità fornitore, prezzi vecchi, errore sync e flag UI
- Layout: 6 Section Form (stato, prodotto, quantità, prezzi, errori, azioni) + toolbar top/bottom + keyboard toolbar
- Bottom bar: prev, scan, "X/N", complete toggle, next — **ben fatto, non toccare**
- Keyboard toolbar: contestuale "usa da file"/"usa vendita vecchia" + Done — **ben fatto**

**Regola di efficienza (fonte di verità)**:
- Per valori di cella già presenti in `RowEditSnapshot` / `RowEditBindings`, il layout del dettaglio deve **leggere da lì** (read-only dove appropriato) invece di introdurre campi gemelli su `RowDetailData`, salvo che serva esplicitamente un dato non esposto altrimenti (es. metadati di stato/navigazione). Obiettivo: niente duplicazione di stato e niente divergenza stale tra dettaglio e griglia.

**Gap rispetto ad Android** (dalla screenshot e dall'analisi):

| Funzione | Android | iOS oggi | Gap / Priorità |
|----------|---------|----------|----------------|
| Nome prodotto primario | ✅ prominente | ✅ in Section prodotto | OK |
| Secondo nome prodotto | ✅ "Segundo nombre" | ❌ assente | **ALTA** — aggiungere |
| Codice articolo (itemNumber) | ✅ "Código del artículo" | ❌ assente | **ALTA** — aggiungere |
| Quantità da file | ✅ "Cantidad" | ✅ "Da file" | OK |
| Prezzo totale | ✅ "Precio total" | ❌ assente | **MEDIA** — aggiungere se presente |
| Prezzo acquisto vecchio | ✅ "Comp. Ant." | ✅ "Acquisto vecchio" | OK |
| Prezzo acquisto corrente | ✅ "Precio de compra" + calc | ❌ assente | **MEDIA** — mostrare (read-only) |
| Prezzo vendita vecchio | ✅ "Precio de venta anterior" | ✅ via "Usa vendita vecchia" | OK ma non visibile come label |
| Contata editabile | ✅ campo | ✅ campo | OK |
| Prezzo vendita editabile | ✅ campo | ✅ campo | OK |
| Calcolatrice prezzo | ✅ icona inline | ✅ icona inline | OK |
| "Usa quantità da file" | ✅ implicito | ✅ bottone | OK |
| "Usa vendita vecchia" | ✅ implicito | ✅ bottone | OK |
| Delta quantità visivo | ✅ colore | ⚠️ solo testo shortage/surplus | **ALTA** — badge + colore |
| Stato completamento badge | ✅ prominente | ⚠️ testo + icona piccola | **ALTA** — badge più forte |
| Prev/Next | ❌ non nel dialog Android | ✅ bottom bar | iOS avanti |
| Scan next | ❌ non nel dialog Android | ✅ bottom bar | iOS avanti |
| Edit row | ✅ icona edit | ✅ in Actions section | OK |
| Edit product | ✅ | ✅ | OK |
| Storico prezzi | ✅ | ✅ | OK |
| Delete row | ✅ | ✅ | OK |
| Calcolatrice generale | ✅ | ✅ | OK |
| Copy/Share barcode | ❌ | ✅ | iOS avanti |
| Carico cognitivo | medio (dialog denso) | alto (6 Section, scroll necessario) | **ALTA** — compattare |
| Above-the-fold | tutto visibile | solo stato + prodotto + inizio quantità | **ALTA** — ridurre altezza |

**Problema principale**: Le Section Form di iOS hanno padding generoso (~44pt per riga + header/footer). Con 6 Section il contenuto utile finisce sotto fold. Le azioni primarie (contata, prezzo) competono con quelle secondarie. **Non** forzare sempre un layout a due colonne per coppie tipo "Da file / Contata": su larghezze ridotte o con localizzazioni lunghe il fallback verticale (stacked) deve restare leggibile.

### Approccio proposto (ordine delle slice)

**Slice 1 — Refactor presentazionale di `RowDetailSheetView` (priorità massima)**  
Sfruttare ciò che esiste già:
1. Esporre in UI (read-only, progressive disclosure) i campi già in `editSnapshot` / `editBindings`: `secondProductName`, `itemNumber`, `totalPrice`, `purchasePrice`, `retailPrice` (e altri solo se coerenti col task), **solo se** il valore normalizzato non è vuoto — niente placeholder in cima al dettaglio. **Attenzione `secondProductName`:** `makeRowDetailData` usa `secondProductName` come fallback per `productName` quando il primario è vuoto (righe 1775-1778), quindi `detail.productName` potrebbe già contenere il valore di `secondProductName`. Mostrare `editSnapshot.secondProductName` **solo se** non è vuoto **e** diverso (case-insensitive trimmed) da `detail.productName` per evitare duplicazione visiva
2. Unire / compattare Section stato + prodotto in un "header" denso con priorità above-the-fold: **stato**, **identità prodotto** (barcode + nome), **contata**, **vendita nuova**, **CTA rapide** nel body (usa da file / usa vendita vecchia) — presenti senza scroll (CA-5) ma stile **secondario** rispetto ai campi editabili (Decisione 6); errori/sync **dopo** il blocco operativo o compatti (Decisione 7)
3. Per layout adattivo: dove si propone affiancamento (es. "Da file" + "Contata"), usare **`ViewThatFits`** o pattern equivalente — prima tentativo compatto (es. HStack), fallback stacked se non entra
4. Delta quantità e stato: badge/chip semantici **solo** con entrambe le quantità valide/parseabili (Decisione 8); altrimenti nessun badge shortage/surplus/match; shortage warning più compatto dove possibile
5. Separazione visiva azioni primarie (zona editabile + CTA contestuali) vs secondarie in fondo (edit row, calcolatrice generale, edit product, storico, delete con gerarchia `.secondary` / destructive)
6. Mostrare `oldRetailPrice` (già su `RowDetailData`) come label read-only in sezione prezzi ove manca oggi, oltre al bottone "usa vendita vecchia"

**Slice 2 — Estensione di `RowDetailData` / `makeRowDetailData` solo se necessario**  
Dopo la Slice 1, valutare se manca ancora qualcosa per header, stato, navigazione o dati **non** ricavabili da snapshot/bindings:
- Se nulla manca → **non** estendere `RowDetailData`
- Se serve un campo aggiuntivo documentato → aggiungere proprietà minime e alimentarle in `makeRowDetailData(...)`, evitando duplicati di colonne già in `RowEditSnapshot`

**Slice 3 — Localizzazione e matrice di test**  
1. Chiavi stringhe per nuove etichette / badge (file xcstrings / `.strings`)
2. Verifica CA-12 / CA-13: iPhone piccolo + grande, light/dark, lingue principali dell'app; focus e integrità input (CA-10, CA-11)

### File da modificare
| File | Motivazione |
|------|-------------|
| `iOSMerchandiseControl/GeneratedView.swift` | Principalmente `RowDetailSheetView` (layout, uso di `editBindings` / `editSnapshot`); eventualmente `RowDetailData` + `makeRowDetailData(...)` solo dopo Slice 1 se restano gap documentati; `rowDetailSheet(_:)` solo se servono parametri aggiuntivi oltre ai binding già costruiti |
| `iOSMerchandiseControl/{en,it,es,zh-Hans}.lproj/Localizable.strings` (4 file) | Chiavi per secondo nome, codice articolo, prezzo totale, prezzo acquisto corrente, badge match/surplus, eventuali etichette nuove |

### Rischi identificati
| Rischio | Probabilità | Impatto | Mitigazione |
|---------|-------------|---------|-------------|
| Compattazione eccessiva rende il layout illeggibile su iPhone piccolo | media | medio | `ViewThatFits` / fallback stacked; test espliciti CA-13 |
| Layout a due colonne forzato rompe localizzazioni lunghe | media | medio | Non assumere sempre HStack; preferire adattivo (Slice 1) |
| Duplicare campi su `RowDetailData` e snapshot causa stato stale | bassa | alto | Regola di efficienza: riuso snapshot/bindings; estensione minima solo se necessaria |
| Unire Section spezza la gerarchia Form standard | bassa | medio | Mantenere `LabeledContent` e stile Form; solo ridurre Section separate |
| Regressione autosave / prev-next / scanner reopen | bassa | alto | Non introdurre state locale parallelo ai binding griglia; verificare CA-10 |
| File `GeneratedView.swift` è molto grande | — | — | Modifiche localizzate; niente nuovi file salvo necessità eccezionale |

### Handoff → Execution
- **Prossima fase**: EXECUTION
- **Prossimo agente**: CODEX
- **Azione consigliata**: **Perimetro:** intervenire **solo** su `RowDetailSheetView` (dettaglio riga non-manuale). **Non** modificare `ManualEntrySheet` né introdurre cambi al flusso manual entry. **Diff minimo:** modifiche localizzate in `GeneratedView.swift`; helper `private` solo se servono alla leggibilità; ordine **Slice 1 → eventuale micro-pass CA-14 → Slice 2 solo se necessaria → localizzazione / test / evidenze visuali (Slice 3)**. Leggere `RowDetailSheetView`, `rowDetailSheet(_:)`, `makeRowDetailData(...)`, tipi `RowEditBindings` / `RowEditSnapshot`. **Invariati:** bottom bar, keyboard toolbar, scanner reopen, manual entry. Non toccare: calcolatrice sheets, `RowEditSheetView`, logica `syncCompletionFromCountedText` (salvo bug bloccante documentato). Build check dopo ogni slice significativa.

### Handoff post-planning
- **Planning approvato** (utente): si passa a **EXECUTION** con **CODEX** responsabile. **Nessun ulteriore ampliamento** del planning o nuovi vincoli teorici salvo **blocker reali** emersi in execution; ottimizzazioni solo in execution/review sul task così com’è.

---

## Execution (Codex) ← solo Codex aggiorna questa sezione

### Obiettivo compreso
Portare `RowDetailSheetView` a un layout piu' compatto e informativo per le righe non-manuali, mantenendo invariati bottom bar, keyboard toolbar, scanner reopen flow e tutto il manual-entry flow.

### File controllati
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-028-generatedview-row-detail-ux-refinement.md`
- `iOSMerchandiseControl/ContentView.swift`
- `iOSMerchandiseControl/GeneratedView.swift`
- `iOSMerchandiseControl/en.lproj/Localizable.strings`
- `iOSMerchandiseControl/it.lproj/Localizable.strings`
- `iOSMerchandiseControl/es.lproj/Localizable.strings`
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`

### Piano minimo
1. Compattare header e blocco operativo di `RowDetailSheetView` usando dati gia' disponibili in `RowEditBindings` / `RowEditSnapshot`
2. Rendere visibili solo i campi read-only con dato reale e separare meglio azioni primarie e secondarie
3. Introdurre badge stato/delta e shortcut leggeri above-the-fold senza toccare bottom bar, keyboard toolbar, scanner reopen o manual entry
4. Aggiungere solo le chiavi di localizzazione strettamente necessarie

### Nota di efficienza (execution)
- Preferire modifiche **localizzate** in `GeneratedView.swift` (perimetro `RowDetailSheetView` e ciò che lo alimenta nello stesso file, es. `RowDetailData` / `makeRowDetailData` / `rowDetailSheet` se toccati).
- Introdurre **`private` helper view** (o estratti locali nello stesso file) **solo** se migliorano leggibilità; **evitare file nuovi** salvo necessità reale e documentata nel handoff.

### Modifiche fatte
- Compattato `RowDetailSheetView` in `iOSMerchandiseControl/GeneratedView.swift` con un blocco iniziale piu' denso: nome prodotto, barcode, badge completamento, badge delta semantico, copy/share, campi `contata` e `vendita` in layout adattivo con `ViewThatFits`
- Riutilizzati `RowEditBindings` / `RowEditSnapshot` per mostrare in sola lettura `secondProductName`, `itemNumber`, `purchasePrice`, `oldPurchasePrice`, `oldRetailPrice` e `totalPrice` solo quando presenti; `RowDetailData` non e' stato esteso
- Aggiunti shortcut leggeri nel body per `Usa quantita' da file` e `Usa vendita vecchia` solo quando esiste il valore sorgente; nessuna riga placeholder o badge delta quando il confronto non e' definito
- Mantenuti in fondo `syncError` e le azioni secondarie (edit row, calcolatrice generale, edit product, storico prezzi, delete row) senza toccare la bottom bar o la keyboard toolbar esistenti
- Aggiunti helper locali privati per normalizzazione testo, calcolo delta e toggle completamento, senza modificare `ManualEntrySheet` o il flusso manual entry
- Aggiornate le localizzazioni `generated.detail.match` e `generated.detail.old_retail` nei 4 file `.strings`
- Micro-pass finale in `RowDetailSheetView`: icona calcolatrice resa con SF Symbol valido (`plus.forwardslash.minus`) sia nell'azione secondaria sia nel trigger inline del prezzo
- Micro-pass finale sulle quick actions above-the-fold: resa alleggerita con shortcut capsule `.plain`, spacing ridotto e gerarchia visiva secondaria rispetto ai campi editabili
- Micro-pass finale sullo stato: il badge header di complete/incomplete e' ora display-only e meno prominente; la bottom bar resta il controllo canonico invariato
- Allineata la fonte della quantita' "da file" usata per display, keyboard shortcut, delta shortage/surplus/match e messaggio di force-complete allo stesso valore effettivo (`detail.supplierQuantity` con fallback a `editSnapshot.quantity`)
- Ultimo micro-tuning stilistico in `RowDetailSheetView`: badge header e quick actions resi piu' chiaramente attivi ma ancora secondari, con accent/outline/fill piu' leggibili e senza cambiare struttura, logica business, bottom bar, keyboard toolbar o scanner reopen flow
- Ultimo micro-pass prezzi in `RowDetailSheetView`: `Retail (new)` resta il campo editabile principale ma ora mostra `Retail (old)` inline nel suo header, mentre `Purchase price` e `Purchase (old)` compaiono come mini-riferimenti compatti nello stesso blocco operativo; la sezione `Prices` completa resta invariata piu' in basso
- Ultimo cleanup del primo viewport: `Purchase (old)` above-the-fold viene ora nascosto quando coincide con `Purchase price`, cosi' il blocco operativo evita ridondanza visiva e mantiene il focus su `Retail (new)`, `Retail (old)` e sul solo riferimento di acquisto davvero utile
- Review mirata su codice + screenshot allegati utente (iPhone 15 Pro Max light mode, confronto Android): introdotto anche per `Counted / From file` un header adattivo con `ViewThatFits`, allineato al blocco `Retail (new) / Retail (old)` per migliorare la resa cross-language senza hardcode per lingua
- Review/fix mirata sul bug bloccante dei TextField: stabilizzata la keyboard toolbar con una struttura fissa e un solo shortcut contestuale, rimosse le animazioni/transizioni legate all'ingresso focus del campo `Contata`, e reso non animato l'auto-toggle complete/incomplete durante la digitazione per ridurre refresh/rilayout mentre la tastiera entra nello sheet
- Fix funzionale prioritario sul flusso input: i `TextField` editabili non sono piu' contenuti dentro un `ViewThatFits` con varianti duplicate del layout; il blocco `Counted` / `Retail (new)` usa ora un singolo layout adattivo basato sulla larghezza disponibile, per evitare istanze duplicate del campo durante la misura/layout e ridurre conflitti di focus/tastiera
- Completato il flusso di input Apple-like richiesto dal task: autofocus iniziale su `Counted` gestito con task asincrono per riga, submit/azione primaria dal campo `Counted` verso `Retail (new)`, e submit finale su `Retail (new)` che riesegue `syncCompletionFromCountedText(...)` e chiude la tastiera in modo coerente con la logica esistente
- Hardening per device reale: sostituiti i due `TextField` critici con un bridge UIKit locale (`UITextField`) dotato di first responder esplicito e `inputAccessoryView` proprietaria, cosi' il toolbar/accessory non dipende piu' da `.toolbar(placement: .keyboard)` dentro `sheet + Form + NavigationStack`; l'autofocus iniziale sul dettaglio riga punta ora sempre a `Counted` dentro `RowDetailSheetView`
- Micro-fix UI finale nel blocco operativo above-the-fold: il campo `Counted` riserva ora lo stesso slot inline del campo `Retail (new)` e usa quindi la stessa regola di larghezza visiva; inoltre gli header delle due colonne sono stati resi sempre verticali e simmetrici (`titolo` sulla prima riga, `From file` / `Retail (old)` sulla seconda), cosi' la struttura non dipende piu' dalla lunghezza delle stringhe localizzate
- Micro-pass aggiuntivo di rifinitura UI: `Counted` e `Retail (new)` condividono ora anche una stessa regola esplicita di altezza (`editorFieldHeight`) e il wrapper UIKit del campo applica la stessa `intrinsicContentSize.height` a entrambi, cosi' la coppia di editor resta allineata in larghezza, altezza e baseline visiva senza alterare autofocus / `Next` / `Done`
- Puliti i 2 warning Xcode dell'app: in `ContentView` la chiamata a `PriceHistoryBackfillService.backfillIfNeeded(context:)` viene ora eseguita dentro `MainActor.run`, mentre in `GeneratedView` il pulsante principale dell'accessory usa `UIBarButtonItem.Style.prominent` al posto dell'API deprecata `.done`

### Evidenza visuale (deliverable obbligatorio — task UI/UX)
Codex deve produrre evidenza **visiva** e riportarne **percorso o allegato** (es. cartella nel repo, allegati al messaggio, o link concordati con il workflow del progetto) insieme al handoff verso Review:

- [ ] Screenshot del **primo viewport** del dettaglio riga su **iPhone piccolo** (Simulator o device) — `❌ NON ESEGUITA`: simulatore esplicitamente non richiesto dall'utente nel pass finale del 2026-03-26; in attesa di eventuali screenshot utente
- [ ] Screenshot del **primo viewport** del dettaglio riga su **iPhone grande** — `⚠️ PARZIALE`: review visuale eseguita su screenshot utente iPhone 15 Pro Max in light mode; manca ancora il set completo richiesto dal task
- [ ] Almeno **un** caso con **dati completi** (layout “felice”: campi/badge/CTA attesi visibili e coerenti) — `❌ NON ESEGUITA`: simulatore esplicitamente non richiesto dall'utente nel pass finale del 2026-03-26; in attesa di eventuali screenshot utente
- [ ] Almeno **un** caso con **dati mancenti / ambigui**: nessun badge delta quando non applicabile; CTA **collassata/nascosta** ove la sorgente non esiste (Decisione 8), salvo eccezione motivata — `❌ NON ESEGUITA`: simulatore esplicitamente non richiesto dall'utente nel pass finale del 2026-03-26; in attesa di eventuali screenshot utente
- [ ] **Conferma visiva** (screenshot o insieme di screenshot annotati) che **bottom bar** e **keyboard toolbar** del dettaglio riga restano **coerenti** con il comportamento/aspetto pre-task (CA-6b) — `❌ NON ESEGUITA`: simulatore esplicitamente non richiesto dall'utente nel pass finale del 2026-03-26; in attesa di eventuali screenshot utente

### Check eseguiti
Per ogni check: ✅ ESEGUITO | ⚠️ NON ESEGUIBILE (motivo) | ❌ NON ESEGUITO (motivo)
- [x] Build compila: `✅ ESEGUITO` — rieseguito anche dopo il bridge UIKit per first responder/accessory, l'autofocus iniziale su `Counted` e il micro-fix finale di simmetria/larghezza dei due campi above-the-fold con `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`; esito `** BUILD SUCCEEDED **`
- [ ] Nessun warning nuovo: `✅ ESEGUITO` — clean build rieseguita dopo il micro-pass finale UI e i fix warning; i warning applicativi in `iOSMerchandiseControl/ContentView.swift:13` e `iOSMerchandiseControl/GeneratedView.swift:4221` risultano risolti. Resta solo il warning esterno `appintentsmetadataprocessor` (`Metadata extraction skipped. No AppIntents.framework dependency found.`), non introdotto da questo task
- [x] Modifiche coerenti con planning: `✅ ESEGUITO` — perimetro limitato a `RowDetailSheetView` e a 4 file di localizzazione; `ManualEntrySheet`, bottom bar e scanner reopen non modificati. La keyboard toolbar e' stata toccata solo internamente per stabilizzare il focus, preservandone presenza e ruolo di acceleratore contestuale (CA-6b)
- [ ] Criteri di accettazione verificati: `⚠️ NON ESEGUIBILE` completamente in questo turno — coperti staticamente CA-1/CA-2/CA-3/CA-4/CA-5/CA-6b/CA-7/CA-15 lato codice; il flusso input richiesto per CA-9/CA-11 e' stato implementato nel codice (`Counted` autofocus, accessory/toolbar per campo, `Counted -> Retail (new)`, submit finale su retail), ma resta da verificarlo end-to-end a runtime e con set visuale completo insieme a CA-6/CA-8/CA-10/CA-12/CA-13/CA-14
- [ ] **Evidenza visuale**: sezione “Evidenza visuale” sopra completa e referenziata: `⚠️ NON ESEGUIBILE` completamente — disponibile solo evidenza parziale su screenshot utente; manca ancora il set completo piccolo/grande light/dark richiesto dal task

### Rischi rimasti
- Verifica visuale e densita' del primo viewport su iPhone piccolo/grande, light/dark, rinviata al prossimo pass con screenshot/feedback utente
- CA runtime su focus tastiera, prev/next, scanner reopen e conservazione input non sono stati rieseguiti in questo turno; il rischio e' mitigato dal riuso degli stessi binding e dei flussi esistenti, ma il bug va considerato chiuso solo dopo verifica interattiva
- Causa tecnica piu' probabile del freeze `Contata`: i campi editabili erano dentro un `ViewThatFits`, quindi SwiftUI poteva materializzare piu' varianti dello stesso `TextField` durante la misura/layout; combinato con `@FocusState`, keyboard toolbar e autofocus iniziale, questo esponeva a conflitti di focus e tastiera. I log IME/candidate receiver osservati restano verosimilmente rumore di sistema, non la root cause primaria
- Differenza probabile device vs simulatore: la `.toolbar(placement: .keyboard)` SwiftUI era piu' tollerante nel simulatore ma poco affidabile sul device reale con tastiere/input mode concreti; spostando toolbar e first responder direttamente sul `UITextField` UIKit, l'accessory resta agganciata al responder reale invece che alla gerarchia SwiftUI della sheet
- I warning Auto Layout su `Vendita (nuovo)` erano compatibili con la reconfigurazione dell'accessory view della keyboard toolbar durante l'attach della tastiera; il toolbar e' ora un `inputAccessoryView` UIKit per campo, ma resta da confermare a runtime che la console non mostri piu' warning bloccanti
- Possibili micro-aggiustamenti di spacing o gerarchia testi in localizzazioni lunghe da valutare dopo il feedback visivo
- Il nuovo allineamento strutturale dei due editor e' staticamente coerente per tutte le lingue supportate, ma la conferma visiva finale su italiano/spagnolo/inglese/cinese resta dipendente da screenshot o verifica runtime dedicata
- Device reale rilevato nell'ambiente (`xcrun xctrace list devices` mostra `iPhone di Min`), ma in questo turno non e' stata eseguita una verifica interattiva automatizzata di tap/focus/tastiera sul telefono; la raccolta finale di evidenza visuale e la conferma runtime su device restano quindi incomplete

### Handoff → Review
- **Prossima fase**: REVIEW
- **Prossimo agente**: CLAUDE
- **Azione consigliata**: Review del codice eseguita da Claude. Fix minimo applicato (`reloadInputViews` condizionale). Esito: APPROVED. Validazione runtime/visuale rimane responsabilità utente.

---

## Review (Claude) ← solo Claude aggiorna questa sezione

### Nota obbligatoria (TASK-028)
- Valutare le **evidenze visuali** allegate da Codex (sezione Execution: screenshot e scenari) **insieme** al codice; se mancano o sono insufficienti per giudicare CA/UX → **CHANGES_REQUIRED** o richiesta integrazione evidenze.
- Verificare **CA-14**: se il primo viewport su iPhone piccolo era sovraccarico post–Slice 1, constatare che sia stato fatto il micro-pass (densità/padding/gerarchia etichette) **prima** di qualsiasi estensione di `RowDetailData`, e riportare esito.
- Verificare **CA-6b**: nessuna modifica accidentale a `ManualEntrySheet`, manual entry, bottom bar, keyboard toolbar, scanner reopen oltre il perimetro `RowDetailSheetView`.
- Verificare **CA-15** e **Decisione 8**: sul primo viewport **nessun** badge delta né riga read-only senza dato reale; assenza dati percepita come **neutrale**, non come errore (distinto da `syncError` quando presente).
- Se una CTA è stata mostrata disabilitata per discoverability (eccezione Decisione 8), la review deve riportare motivazione ed esito UX.

### Problemi critici
Nessuno.

### Problemi medi
Nessuno bloccante. Un problema di efficienza corretto direttamente (vedi sotto).

### Miglioramenti opzionali
Nessuno segnalato.

### Fix applicati da Claude in review

- [x] **`reloadInputViews()` chiamata su ogni aggiornamento SwiftUI** — `RowDetailInputTextField.refreshAccessoryIfNeeded()` veniva invocata da `updateUIView` a ogni render cycle (inclusa ogni battuta di tastiera), causando un reload non necessario dell'`inputAccessoryView`. Spostato `reloadInputViews()` dentro `rebuildAccessoryToolbar()` (dove serve davvero: solo quando la configurazione dell'accessory cambia) e rimosso il metodo `refreshAccessoryIfNeeded()`. Diff: 3 punti in `GeneratedView.swift`, build verificata OK.

### Verifiche eseguite

| Verifica | Esito | Note |
|----------|-------|------|
| **Simmetria width/height Counted vs Retail** | ✅ OK | Entrambi usano `editorFieldHeight = 36`, `editorInlineControlWidth = 28`, `.frame(maxWidth: .infinity)`. Il `RowDetailInputTextField` override `intrinsicContentSize.height = preferredHeight` per entrambi. Counted ha `Color.clear` spacer 28×28, Retail ha Button 28×28 → stessa geometria. |
| **Simmetria header/subheader cross-language** | ✅ OK | Entrambi i header usano `VStack(alignment: .leading, spacing: 4)` con titolo (`.subheadline.weight(.semibold)`) + riferimento opzionale (`.caption` + valore `.subheadline.weight(.semibold).monospacedDigit()`). Struttura identica e language-independent. EN/IT/ES/ZH verificati nelle stringhe. |
| **Autofocus su Counted** | ✅ OK (codice) | `.task(id:)` + `requestInitialFocusIfNeeded()` con doppio yield e retry. UIKit bridge gestisce `desiredFirstResponder` via `didMoveToWindow` + `DispatchQueue.main.async`. |
| **Next / Done / toolbar** | ✅ OK (codice) | Counted: `primaryTitle = Next`, `onPrimaryAction = moveFocusToRetail`. Retail: `primaryTitle = Done`, `onPrimaryAction = submitRetailEditor`. Toolbar è `inputAccessoryView` UIKit nativa per campo. |
| **CA-6b (invarianti)** | ✅ OK | Bottom bar (prev/scan/index/complete/next) intatta. `ManualEntrySheet` non toccata (grep confermato). Keyboard toolbar migrata da SwiftUI `.toolbar(.keyboard)` a UIKit `inputAccessoryView` — ruolo preservato. Scanner reopen flow non modificato. |
| **CA-15 / Decisione 8** | ✅ OK | Badge delta solo se `supplierQtyInt != nil && countedQtyInt != nil`. Campi read-only (`secondProductName`, `itemNumber`, etc.) mostrati solo se non vuoti (`normalizedText` guard). Nessun placeholder `—` nelle sezioni above-the-fold. CTA shortcut solo se valore sorgente esiste (`displaySupplierQuantity != nil`, `displayOldRetailPrice != nil`). |
| **CA-14 (micro-pass densità)** | ✅ OK | `RowDetailData` non estesa. Layout compattato con Section uniche, `ViewThatFits` per header/editors, progressive disclosure. |
| **Warning Xcode** | ✅ OK | `ContentView:15` — `backfillIfNeeded` ora dentro `MainActor.run`. `GeneratedView` — `.prominent` al posto di `.done`. Build pulita (solo warning esterno `appintentsmetadataprocessor`). |
| **Qualità tecnica** | ✅ OK | Nessuna duplicazione di stato (snapshot/bindings riusati). Helper locali `private`. UIKit bridge pulito con coordinator pattern. Nessun `ViewThatFits` attorno ai TextField (bug precedente risolto). |

### Limiti della review (onestà)

- **Non ho screenshot**: la richiesta menziona screenshot allegati, ma non ne ho ricevuti in questa conversazione. Le verifiche di simmetria visiva, cross-language rendering, dark mode e device reale sono state fatte **solo** analizzando il codice, non confermando il rendering effettivo.
- **Non ho eseguito test runtime**: autofocus, tastiera, prev/next, scanner reopen verificati a livello di codice, non interattivamente.
- **CA-8 (light/dark)**: il codice non usa colori hardcoded (usa `Color(uiColor: .secondarySystemBackground)`, `.secondary`, `.primary`, tint semantici) → dovrebbe funzionare, ma non confermato visivamente.
- **CA-12/CA-13 (clipping, iPhone piccolo/grande)**: layout adattivo (`ViewThatFits`, `minimumScaleFactor`, `lineLimit`) corretto a livello di codice; conferma visiva mancante.

### Esito

**APPROVED** — con la nota che le verifiche runtime/visuali restano pendenti per conferma finale dell'utente.

Il codice è pulito, coerente col planning, senza regressioni strutturali. Il fix applicato (`reloadInputViews` condizionale) migliora la stabilità della tastiera su device. La conferma utente è necessaria prima di chiudere come DONE.

### Handoff post-review
- **Prossima fase**: (in attesa conferma utente → DONE)
- **Prossimo agente**: UTENTE
- **Azione consigliata**: Verificare visivamente su device reale: simmetria campi, autofocus, keyboard toolbar, prev/next, dark mode, lingue diverse. Se tutto OK → conferma → DONE.

---

## Fix (Codex) ← solo Codex aggiorna questa sezione

### Fix applicati
- [ ] [fix 1 — fatto/non fatto]
- [ ] [fix 2 — fatto/non fatto]

### Check post-fix
Per ogni check: ✅ ESEGUITO | ⚠️ NON ESEGUIBILE (motivo) | ❌ NON ESEGUITO (motivo)
- [ ] Build compila: [stato]
- [ ] Fix coerenti con review: [stato]
- [ ] Criteri di accettazione ancora soddisfatti: [stato]
- [ ] Se la fix ha toccato UI visibile: aggiornare / allegare evidenza visuale come in Execution (stesso set minimo se applicabile): [stato]

### Handoff → Review finale
- **Prossima fase**: REVIEW ← dopo FIX si torna SEMPRE a REVIEW, mai a DONE
- **Prossimo agente**: CLAUDE
- **Azione consigliata**: Verificare i fix applicati

---

## Chiusura

### Conferma utente
- [ ] Utente ha confermato il completamento

### Follow-up candidate
[Eventuali follow-up emersi — non bloccano la chiusura salvo che siano criteri non soddisfatti]

### Riepilogo finale
[Cosa è stato fatto, limiti noti, note per il futuro]

### Data completamento
YYYY-MM-DD
