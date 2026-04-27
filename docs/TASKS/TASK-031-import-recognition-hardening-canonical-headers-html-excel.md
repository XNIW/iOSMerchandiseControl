# TASK-031: Import recognition hardening — canonical headers HTML/Excel

## Informazioni generali
- **Task ID**: TASK-031
- **Titolo**: Import recognition hardening: canonical headers HTML/Excel
- **File task**: `docs/TASKS/TASK-031-import-recognition-hardening-canonical-headers-html-excel.md`
- **Stato**: DONE
- **Fase attuale**: Chiusura
- **Responsabile attuale**: —
- **Data creazione**: 2026-04-26
- **Ultimo aggiornamento**: 2026-04-27
- **Ultimo agente che ha operato**: Claude Code reviewer/fixer

## Dipendenze
- **Dipende da**: nessuno
- **Sblocca**: flusso import più stabile per fixture HTML/Excel canoniche

## Scopo
Durante la validazione TASK-028, PreGenerate ha mostrato header canonici HTML come `col1/col2/...` e l'utente/Codex ha dovuto assegnare ruoli manualmente. È fuori perimetro TASK-028 ma impatta il flusso import.

## Contesto
Il problema riguarda riconoscimento colonne/header, non `RowDetailSheetView`. Il task isola l'hardening dell'import senza riaprire TASK-028.

## Non incluso
- Modifiche a RowDetailSheetView
- Supabase
- Redesign del flusso import
- Rimozione dell'override manuale dei ruoli

## Scope
- Analizzare ExcelAnalyzer / header recognition / HTML fixture
- Confrontare alias Android ExcelUtils
- Migliorare riconoscimento header canonici e HTML export
- Mantenere possibilità di override manuale ruoli

## Output richiesto
- Fix mirato
- Fixture minima HTML/XLSX
- Test: barcode/productName/purchasePrice/quantity/retailPrice riconosciuti senza override quando header sono canonici

## Criteri di accettazione
*Chiusura **DONE** (2026-04-27): criteri soddisfatti. Evidenza operativa: sezioni **Execution**, **Review** e **«Criteri di accettazione rafforzati»** nel Planning; fixture in `docs/fixtures/TASK-031/`.*
- [x] Header canonici HTML/Excel vengono riconosciuti senza override per i campi indicati
- [x] L'override manuale dei ruoli resta disponibile
- [x] La fixture minima HTML/XLSX documenta il caso coperto
- [x] Nessuna regressione introdotta sui flussi import esistenti

## Planning (Claude) ← solo Claude aggiorna questa sezione

*Ultimo aggiornamento planning: 2026-04-26 (raffinamento operativo). Task focalizzato su **import/header recognition** (PreGenerate / `ExcelAnalyzer`).*

### Obiettivo tecnico
Rendere **deterministico** il riconoscimento di header **canonici** e **alias comuni** per sorgenti **HTML** e **Excel** (inclusi export HTML tipo Office), evitando che intestazioni **leggibili e mappabili** finiscano come `col1` / `col2` / … quando l’utente si aspetta ruoli già assegnati. L’override manuale resta il ripiego corretto solo per casi senza header reale o non riconoscibili.

### Stato attuale iOS (da codice)
- **`ExcelSessionViewModel`**: mantiene `originalHeader`, `normalizedHeader`, `initialNormalizedHeader` (per validazione append), `rows`, `selectedColumns`; colonne essenziali `barcode` / `productName` / `purchasePrice` non disattivabili; ordinamento UI tramite `columnPriority`; metriche `analysisConfidence` / `analysisMetrics`; API `columnStatus(at:)` (`ColumnStatus`: exactMatch, aliasMatch, normalized, generated, emptyOriginal); swap ruoli / reset ruolo / aggiornamento metriche dopo mapping manuale.
- **`ExcelAnalyzer`** (in `ExcelSessionViewModel.swift`): pipeline `readAndAnalyzeExcel` → righe grezze (HTML / XLSX / legacy `.xls`) → `normalizeAllCells` → **`analyzeRows`**; rilevazione HTML con `looksLikeHtml` (snippet iniziale, `<html`, `mso-application`, `office:excel`, `<table`); **`rowsFromHTML`** con SwiftSoup: `select("tr")`, celle `th,td`, testo con NBSP → spazio, nessun handling esplicito di **colspan/rowspan**; **`findDataHeaderRow`**: prima riga “da dati” (≥3 numeri e ≥1 testo), header = riga precedente se `dataRowIdx > 0`, altrimenti header sintetico `col1…` e `hasHeader = false`; **`normalizeToken`** (fold diacritici, trim, rimozione spazi/`_`, solo lettere/cifre, lowercased); **`standardAliases`** ampia tabella key + patterns; **`normalizeHeaderCell`**: se token vuoto → `col(index+1)`; altrimenti match **esatto** token↔pattern alias; se nessun alias → restituisce il **token collassato** (non camelCase canonico); **`identifyColumns`**, **`pruneBadMappings`**, **`applyHeuristics`** (barcode per lunghezza cifre, quantity/purchasePrice numerici, totalPrice ≈ qty×purchase, productName testuale, retail/discount, ecc.), **`ensureMandatoryColumns`** (inserisce colonne obbligatorie mancanti con celle vuote), **`filterSummaryRows`**; caricamento multi-file: `loadFromMultipleURLs` chiama `readAndAnalyzeExcel` per ogni URL e richiede **uguaglianza** degli header normalizzati (`incompatibleHeader` se diverso).

### Riferimento Android (solo funzionale; file non presente in questo repo)
`ExcelUtils.kt` (app Android di riferimento) espone tipicamente: **alias estesi** (`possibleNames` / varianti lingua), **`normalizeHeader`**, rilevazione/struttura **HTML**, **`parseExcelHtmlToRows`** con attenzione a **colspan** / **rowspan** / **NBSP**, e **euristiche** su barcode, quantity, purchasePrice, totalPrice/retail, productName. **Non si copia Kotlin in Swift**: si usa solo come checklist di comportamento atteso e copertura alias.

### Differenze / gap da verificare (in Execution)
1. **Chiavi canoniche stile Swift/camelCase** devono mappare in modo stabile: `barcode`, `productName`, `secondProductName`, `purchasePrice`, `retailPrice`, `quantity`, `supplier`, `category`, `itemNumber` (oggi molte passano da alias con pattern già “collassati”, va verificato end-to-end su header reali).
2. **snake_case e varianti spaziate** devono mappare: `product_name`, `purchase_price`, `retail_price`, `item_number`, `supplier_name`, `category_name` (alcuni pattern esistono già in `standardAliases`; verificare completezza e assenza regressioni).
3. **Alias localizzati** già in `standardAliases` **non devono regredire** (IT/ES/CN/EN, ecc.).
4. **HTML con vere intestazioni**: non devono degradare a `col1/col2` per **parsing** (es. tabella sbagliata, righe pre-tabella, merge celle) o per **euristica** `findDataHeaderRow` che non trova una riga “dati” e imposta `hasHeader = false`.
5. **HTML senza header reale**: `col1/col2` resta accettabile; override manuale e colonne inserite da `ensureMandatoryColumns` restano comportamenti noti da documentare nei test.
6. **Nessun parsing doppio o letture ridondanti** dello stesso file: oggi `Data(contentsOf:)` + un solo percorso di analisi per URL; Execution deve evitare regressioni (es. ri-parse inutili).
7. **Non modificare** `RowDetailSheetView`.
8. **Non introdurre** Supabase.
9. **Nessun redesign** del flusso import / PreGenerate (solo riconoscimento e microcopy se necessario).

### Non incluso — perimetro rigido (ribadito)
- **Niente Supabase.**
- **Niente** modifiche a `RowDetailSheetView`.
- **Niente** su `GeneratedView` salvo eventuali **stringhe** strettamente necessarie (es. microcopy condiviso) — nessun cambio di navigazione o layout inventario.
- **Niente refactor generale** del flusso import o dell’analyzer oltre al minimo per header recognition.
- **Niente redesign** di PreGenerate (layout, struttura schermata, flussi).
- **Niente** modifica al comportamento dell’**override manuale** dei ruoli salvo **bug evidente** introdotto dal lavoro sul parser (fix minimo mirato).

### Strategia tecnica proposta (per Execution)
1. **Consolidare** la mappa alias / chiavi canoniche dentro `ExcelAnalyzer` (una sola fonte di verità, ordinata per ridurre conflitti retail vs purchase già gestiti in parte da priorità in `identifyColumns`).

2. **Mappa canonica esplicita (token → ruolo interno)**  
   Definire una mappa **stabile** *token normalizzato* (stesso algoritmo usato per il match, es. quello equivalente a `normalizeToken`) → **chiave interna** già usata dall’app. Obiettivo: **`normalizedHeader` contiene sempre le stringhe canoniche esatte** (`productName`, `purchasePrice`, …), non token collassati intermedi tipo `productname` quando il ruolo è noto.  
   Esempi attesi di equivalenza (da coprire con alias/mappa, senza elencare tutte le lingue qui):  
   - `productname`, da `product_name`, `product name`, `Product Name` → **`productName`**  
   - `purchaseprice`, da `purchase_price`, `purchase price` → **`purchasePrice`**  
   - `retailprice`, da `retail_price`, `retail price` → **`retailPrice`**  
   - `itemnumber`, da `item_number`, `item number` → **`itemNumber`**  
   - `secondproductname`, da `second_product_name`, `second product name` → **`secondProductName`**  
   (Stesso principio per le altre chiavi già in uso: `barcode`, `quantity`, `supplier`, `category`, ecc.)

3. **Unificare / rafforzare** la funzione di normalizzazione header (oggi `normalizeToken` + `normalizeHeaderCell`): stessi passi (accenti, spazi, `_`, punteggiatura/case, token alfanumerico); riconoscimento **chiavi canoniche interne** e **alias equivalenti ad Android**; output come al punto 2; **`colN` solo** se header originale vuoto/non significativo dopo normalizzazione **oppure** pipeline ha scelto header sintetico (nessun “indovinare” aggressivo su colonne già etichettate dall’utente come dati puri).

4. **Rilevazione riga header (più concreta dell’attuale sola euristica)**  
   Prima di affidarsi **solo** alla logica attuale “prima riga che sembra dati → header = riga precedente”, **valutare** una strategia a **punteggio** sulle prime **N** righe (es. **10–20**), limitata per costo e rumore. Per ogni riga candidata header, sommare evidenza da:  
   - **match** di celle contro **chiavi canoniche** o **alias** (peso alto);  
   - celle **testuali** non vuote;  
   - **unicità** delle celle (header tipicamente meno duplicati rispetto a colonne dati ripetitive);  
   - **bassa** percentuale di celle **solo numeriche** (sospetto riga dati);  
   - **coerenza** con le righe seguenti interpretate come dati (es. tipi/compatibilità senza inferenze profonde).  
   Se una riga ha **alto punteggio** alias/canonical, usarla come header **anche quando** l’euristica numerica attuale fallirebbe. Se **nessuna** riga sembra header reale, mantenere fallback **`col1`/`col2`/…** e override manuale. **Non** introdurre inferenze aggressive basate **solo** sui valori delle celle dati (niente “sembra un prezzo quindi questa colonna è purchasePrice” senza supporto header o regole molto conservative già esistenti).

5. **Conflict resolution (prezzi e label generiche)**  
   - Evitare alias **troppo generici** che mappano `price` / `prezzo` / `precio` in modo **ambiguo** (meglio non assegnare un ruolo che sbagliare).  
   - Segnali testuali nell’header (anche dopo normalizzazione): se contiene tratti **acquisto** (*purchase*, *acquisto*, *compra*, *costo*, *进价*, …) → preferire **`purchasePrice`**.  
   - Se contiene **vendita al dettaglio** (*retail*, *vendita*, *venta*, *零售*, *售价*, …) → preferire **`retailPrice`**.  
   - Se contiene **totale** (*total*, *totale*, *importe*, *subtotal*, *合计*, …) → preferire **`totalPrice`**.  
   - Se contiene **scontato / finale** (*discounted*, *final*, *scontato*, *descuento*, *折后*, …) → preferire **`discountedPrice`**.  
   - In caso **ambiguo**, preferibile: lasciare **token non canonico** o ruolo **non assegnato** + **override manuale**, piuttosto che un ruolo **errato**.

6. **Path HTML**: intervenire **solo se** la causa è perdita/allineamento header (es. scelta tabella, righe parasite, celle vuote da merge); mantenere parser **semplice**, niente riscrittura totale senza evidenza da fixture.

7. **colspan/rowspan**: valutare **solo se** una fixture reale dimostra shift colonne; altrimenti documentare come **follow-up** esplicito fuori da TASK-031 o sotto-criterio opzionale.

8. **Preservare** override manuale ruoli, swap ruoli unici, protezione colonne essenziali, `initialNormalizedHeader` per append.

9. **Microcopy UI** (badge/stato: riconosciuto / alias / da assegnare): vedi **Decisione UX** — ammesso solo **dopo** che parser + fixture passano; niente stringhe o badge che mascherino placeholder come “riconosciuto”.

### Fixture / test richiesti (da creare in Execution; qui solo specifica)
- **Percorso fixture (strategia, nessun file creato in Planning):** in Execution **verificare** se il progetto ha un **test target** utilizzabile.  
  - Se **sì**: preferire fixture nel bundle di test, es. `iOSMerchandiseControlTests/Fixtures/TASK-031/`.  
  - Se **no** o aggiungere un test target sarebbe **fuori proporzione** per TASK-031: usare fixture **documentali / manuali** sotto `docs/fixtures/TASK-031/`.  
  **Non** creare o decidere test target in questa fase di planning — solo questa strategia.
- **A.** HTML minimo con header canonici: `barcode`, `productName`, `purchasePrice`, `quantity`, `retailPrice` + 2–3 righe dati rappresentative. Verificare che ogni campo “riconosciuto” sia su **colonna reale** del file (vedi CA).
- **B.** XLSX minimo con **stesso** set di header e stesse righe (stesso significato colonne). Stessa verifica “colonna reale + dati”.
- **C.** Header **snake_case**: almeno `product_name`, `purchase_price`, `retail_price` (+ colonne necessarie per euristica dati se serve).
- **D.** Fixture **localizzata** allineata ad alias Android: es. IT *codice a barre* / *descrizione* / *prezzo acquisto* / *quantità* / *prezzo vendita*, oppure equivalente ES/CN già coperto dagli alias.
- **E.** **Negativo**: griglia senza riga di intestazione reale → atteso `col1`/`col2`/… (o equivalente) e possibilità di assegnazione manuale senza falsi positivi “troppo intelligenti”.
- **F.** **Append**: due file con **stesso** `normalizedHeader` finale (golden) e righe dati compatibili → `loadFromMultipleURLs` non deve lanciare `incompatibleHeader` e non deve cambiare la forma normalizzata rispetto allo snapshot atteso.

**Definizione operativa “riconosciuto senza override” (per fixture A–D):** vale solo se la colonna mappata a quel ruolo **proviene dal sorgente** (indice allineato a una colonna del file **prima** di inserimenti placeholder), ha **valori non vuoti** in almeno una riga dati dove il fixture prevede dati, e **non** è una colonna aggiunta solo da `ensureMandatoryColumns` (o logica equivalente) con celle tutte vuote.

### Criteri di accettazione rafforzati
1. HTML con header **canonici** (A): `barcode`, `productName`, `purchasePrice`, `quantity`, `retailPrice` risultano mappati **senza override utente** e soddisfano la **definizione operativa** sopra (colonna reale + dati + non placeholder).  
2. XLSX con stessi header (B): stesso esito.  
3. **snake_case** e **case-insensitive** (C): riconoscimento corretto; nessuna regressione su file esistenti; stessa definizione “reale vs placeholder”.  
4. Alias principali stile Android / localizzati (D): riconosciuti come oggi o meglio, **mai peggio** rispetto al baseline TASK-031.  
5. **Override manuale** ruoli sempre disponibile dopo import; le **colonne essenziali** (`barcode`, `productName`, `purchasePrice`) restano **selezionate e non disattivabili** come nel comportamento attuale.  
6. Se `ensureMandatoryColumns` inserisce `barcode` / `productName` / `purchasePrice` come **colonne vuote**, ciò **non** conta come “riconoscimento riuscito” nei CA 1–4; la **validazione PreGenerate** deve continuare a segnalare colonne essenziali **mancanti** quando sono soddisfatte solo da placeholder vuoti (allineamento a regole già note su inventario/validazione).  
7. File **senza header reale** (E): uso di `colN` accettabile; **nessuna** classificazione forzata come campi canonici solo dall’euristica quando l’utente si aspetta header generici.  
8. Scenario **append** (F): nessuna regressione; stessa normalizzazione tra file gemelli.  
9. **Nessuna modifica** a `RowDetailSheetView`, integrazione Supabase, o flusso `GeneratedView` oltre a **stringhe** strettamente necessarie (coerente con “Non incluso”).  
10. **Nessun parsing doppio** non necessario per file singolo.

### File iOS probabilmente coinvolti (Execution)
- `iOSMerchandiseControl/ExcelSessionViewModel.swift` (`ExcelAnalyzer` + eventuali stringhe/log).
- **Test target:** in Execution **verificare** se esiste un test target standard nel progetto; se **non** esiste, **documentare** test manuale con fixture oppure **valutare** creazione di un test target **solo se** proporzionata al task e al perimetro.
- `Localizable.xcstrings` (o equivalente) **solo** per microcopy badge/messaggi, se necessario e dopo priorità parser.

### Rischi
1. **Falsi positivi**: colonne numeriche scambiate tra prezzo e quantità o tra purchase e retail se alias o euristiche troppo larghe.
2. **Conflitto purchasePrice vs retailPrice** con pattern generici (“prezzo”, “price”, ecc.).
3. **HTML con più tabelle** o markup rumoroso: scelta della tabella sbagliata o righe fuori ordine.
4. Header già generici `colN` su file senza intestazione: evitare sovrascrittura “intelligente” che confonda l’utente.
5. **Append**: cambiare la normalizzazione rompe compatibilità con file storici già importati assieme.

### Decisione UX
**Priorità:** parser e prove su fixture (riconoscimento deterministico, distinzione reale/placeholder) **prima** di qualsiasi ritocco UI. **UI/UX è secondaria** rispetto al parser.

Dopo che i criteri di riconoscimento sono soddisfatti, sono ammessi solo **micro-polish** coerenti con l’app iOS esistente:
- badge/stato **header riconosciuto** (da colonna sorgente reale);
- stato **alias** vs **manuale**;
- messaggio **chiaro** per colonne essenziali **mancanti** (inclusi solo-placeholder).

**Non ammessi:** redesign PreGenerate, nuova navigazione, copia 1:1 Android. Se serve una scelta UX, preferire la soluzione **più nativa iOS**, leggibile e allineata al resto dell’app.

### Handoff storico (pre-promozione ACTIVE / pre-execution)

*Nota: il testo seguente era valido al momento del raffinamento planning **prima** dello user override del **2026-04-27**. In seguito il task è stato promosso ad **ACTIVE / Execution**, sottoposto a **Review** (con fix diretti Claude) e chiuso **DONE** — vedi sezioni **Execution**, **Review** e **Chiusura**.*

- **Stato task dopo questo raffinamento:** resta **TODO / backlog** — **non** promuovere ad **ACTIVE** da questo planning.
- **Non** compilare la sezione Execution; **non** iniziare patch di codice; **non** trattare questo documento come avvio di lavori implementativi.
- **Prossima fase (solo futura):** EXECUTION, **solo dopo promozione esplicita** ad ACTIVE nel MASTER-PLAN e handoff operativo aggiornato.
- **Prossimo agente (quando attivo):** Codex / Cursor executor.
- **Azione consigliata (quando attivo):** implementare strategia e CA sopra, con fixture secondo la strategia di percorso; aggiornare solo le sezioni Execution/Handoff a cura dell’esecutore.

---

## Execution (Codex) ← solo Codex aggiorna questa sezione
### Avvio Execution — 2026-04-27
- Planning approvato da user override; TASK-031 promosso a ACTIVE / Execution.
- File da ispezionare/intervenire: `iOSMerchandiseControl/ExcelSessionViewModel.swift` (`ExcelAnalyzer`, header normalization, HTML/XLSX analysis, append compatibility), project/test target, eventuali fixture sotto `docs/fixtures/TASK-031/`.
- Strategia minima: consolidare una mappa canonica stabile token normalizzato → ruolo interno, rafforzare `normalizeHeaderCell`, rendere più conservativa e deterministica la scelta della riga header nelle prime righe, aggiungere fixture/manual evidence per HTML/XLSX/snake_case/localizzati/negativo/append.
- Vincoli confermati: niente refactor generale, niente Supabase, niente `RowDetailSheetView`, niente redesign PreGenerate.

### Execution completata — 2026-04-27

#### Cosa ho modificato
- `iOSMerchandiseControl/ExcelSessionViewModel.swift`: aggiunta mappa stabile token normalizzato → ruolo interno (`canonicalHeaderTokenMap`) usata da `normalizeHeaderCell` e `isAliasMatch`, così `productName`, `Product Name`, `product_name`, `purchase_price`, `retail_price`, ecc. convergono sulle chiavi interne esatte.
- `ExcelAnalyzer.findDataHeaderRow`: aggiunto scoring conservativo sulle prime 20 righe, con peso alto per match canonici/alias, penalità per righe quasi tutte numeriche e fallback invariato alla vecchia euristica / `colN` quando non c'è header reale.
- `ExcelAnalyzer.analyzeRows` / `computeAnalysisMetrics`: disabilitate euristiche basate solo sui valori quando l'header è sintetico, per evitare falsi riconoscimenti su file senza intestazione reale; preservato l'override manuale.
- `ExcelAnalyzer.applyHeuristics`: ridotto il default aggressivo sui prezzi; `purchasePrice`, `retailPrice` e `discountedPrice` vengono promossi da euristica numerica solo se l'header ha segnali testuali coerenti, non per `price` / `prezzo` / `precio` neutri.
- `ExcelAnalyzer.standardAliases`: rimossi alias prezzo generici ambigui da `purchasePrice` (`prezzo`, `precio`, `unit price`, ecc.) e spostato `售价` verso `retailPrice`, coerente con la conflict resolution.
- `pruneBadMappings`: resa proporzionata a fixture/dataset piccoli, usando un minimo non-vuoto limitato dalla dimensione del campione.
- Nessuna modifica a UI, `RowDetailSheetView`, Supabase, `GeneratedView`, `Localizable.xcstrings` o dipendenze.

#### Fixture/test creati
- Non esiste un test target nel progetto (`xcodebuild -list` mostra solo target/scheme `iOSMerchandiseControl`); non ho creato un test target perché sarebbe fuori dal perimetro minimo.
- Create fixture documentali/manuali in `docs/fixtures/TASK-031/`:
  - `canonical-headers.html`
  - `canonical-headers.xlsx`
  - `snake-case-headers.html`
  - `localized-it-headers.html`
  - `no-real-header.html`
  - `append-compatible-a.html`
  - `append-compatible-b.html`
  - `README.md` con attesi per A-F.

#### Risultati verificati
- ✅ ESEGUITO — Build compila: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'generic/platform=iOS Simulator' build` → PASS (`BUILD_EXIT=0`).
- ⚠️ NON ESEGUIBILE — Nessun warning nuovo introdotto: senza baseline non è possibile attribuire storicamente i warning. Il build log contiene solo `appintentsmetadataprocessor` warning (`Metadata extraction skipped. No AppIntents.framework dependency found`) e nessun warning/error sui file modificati.
- ✅ ESEGUITO — Modifiche coerenti con il planning: intervento limitato a `ExcelAnalyzer`, tracking e fixture; nessun redesign PreGenerate, nessun Supabase, nessun `RowDetailSheetView`.
- ✅ ESEGUITO — Fixture XLSX valida come archivio: `unzip -l docs/fixtures/TASK-031/canonical-headers.xlsx` mostra workbook/sheet minimi e `sheet1.xml` contiene header canonici + righe dati non vuote.
- ✅ ESEGUITO — CA header canonici HTML/Excel: verifica STATIC su mappa canonica e fixture A/B; gli header sorgente normalizzano a `barcode`, `productName`, `purchasePrice`, `quantity`, `retailPrice` su colonne reali con dati.
- ✅ ESEGUITO — CA snake_case/case-insensitive: verifica STATIC su `canonicalHeaderTokenMap`; `product_name`, `purchase_price`, `retail_price` convergono sulle chiavi interne.
- ✅ ESEGUITO — CA alias localizzati: verifica STATIC su alias IT fixture D; `codice a barre`, `descrizione`, `prezzo acquisto`, `quantità`, `prezzo vendita` restano mappati a ruoli interni.
- ✅ ESEGUITO — CA negativo senza header: verifica STATIC sul path `hasHeader == false`; source columns restano `colN`, euristiche dati disabilitate, eventuali obbligatorie vuote non valgono come riconoscimento.
- ✅ ESEGUITO — CA append: verifica STATIC su fixture F; alias/case/snake_case producono stesso `normalizedHeader` atteso, quindi compatibile con confronto esatto esistente.

#### Rischi residui
- Validazione fixture A-F eseguita come build + ispezione statica/documentale, non con XCTest runtime, perché non esiste un test target.
- HTML con `colspan`/`rowspan` o più tabelle rumorose resta un follow-up candidate se emerge fixture reale: non ho riscritto il parser HTML.
- File storici che dipendevano da alias molto generici come `prezzo`/`precio` potrebbero richiedere override manuale: scelta intenzionale per evitare mapping errati purchase vs retail.

#### Handoff post-execution
- Fase proposta: REVIEW.
- Responsabile prossimo: Claude reviewer.
- Note per review: controllare soprattutto conflitti alias prezzo, path negativo senza header reale e compatibilità append con `initialNormalizedHeader`.

---

## Review (Claude) ← solo Claude aggiorna questa sezione
### Review + fix diretto — 2026-04-27

#### Cosa ho controllato
- Diff reale di `docs/MASTER-PLAN.md`, file task, `iOSMerchandiseControl/ExcelSessionViewModel.swift` e fixture `docs/fixtures/TASK-031/`.
- Coerenza stato: task in Review e MASTER-PLAN allineato prima della chiusura.
- `ExcelAnalyzer`: `canonicalHeaderTokenMap`, `standardAliases`, `normalizeToken`, `normalizeHeaderCell`, `findDataHeaderRow`, `analyzeRows`, `identifyColumns`, `applyHeuristics`, `pruneBadMappings`, `ensureMandatoryColumns`, `loadFromMultipleURLs`.
- Fixture A-F: HTML canonico, XLSX canonico, snake_case, alias IT, negativo senza header reale, append compatibile.
- Scope: nessuna modifica a Supabase, `RowDetailSheetView`, `GeneratedView`, UI PreGenerate o dipendenze.

#### Problemi trovati
- Commento `ColumnStatus.normalized` non più accurato: citava ancora `Product name → productname`, mentre il nuovo comportamento mappa il ruolo noto a `productName`.
- Scoring header migliorabile: con soli due match canonici poteva essere reso più conservativo richiedendo ruoli distinti e almeno un ruolo essenziale quando i match non arrivano a tre.

#### Fix applicati direttamente
- User override: Claude ha applicato fix diretti mirati in review.
- Aggiornato il commento `ColumnStatus.normalized` per non descrivere un output intermedio obsoleto.
- Rafforzato `bestCanonicalHeaderCandidate`: ora richiede almeno due ruoli canonici distinti e, se i match sono solo due, almeno un essenziale (`barcode`, `productName`, `purchasePrice`); gli essenziali aumentano leggermente lo score.

#### Check eseguiti
- ✅ ESEGUITO — `git status --short`, `git diff --stat`, diff specifici richiesti e `ls -la docs/fixtures/TASK-031`.
- ✅ ESEGUITO — `xcodebuild -list -project iOSMerchandiseControl.xcodeproj`: unico target/scheme `iOSMerchandiseControl`; nessun test target esistente.
- ✅ ESEGUITO — Build: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'generic/platform=iOS Simulator' build` → PASS (`BUILD_EXIT=0`).
- ⚠️ NON ESEGUIBILE — Warning nuovi: senza baseline non è attribuibile storicamente. Il log finale contiene solo warning Xcode non collegato ai file modificati: `appintentsmetadataprocessor` / `No AppIntents.framework dependency found`.
- ✅ ESEGUITO — Fixture XLSX: `unzip -t docs/fixtures/TASK-031/canonical-headers.xlsx` → OK.
- ✅ ESEGUITO — Criteri A-F verificati staticamente su codice + fixture: header canonici/snake/localizzati convergono a chiavi interne; negativo resta su `colN`/placeholder vuoti; append A/B produce lo stesso `normalizedHeader`.

#### Esito review
APPROVED con fix diretti piccoli già applicati. TASK-031 chiudibile come DONE su autorizzazione utente esplicita.

---

## Fix (Codex) ← solo Codex aggiorna questa sezione
Non avviato.

*Nota documentale: nessun ciclo **FIX** separato eseguito da Codex; i fix mirati sono documentati nella sezione **Review** (fix diretti Claude / user override).*

---

## Chiusura

### Conferma utente
- [x] Utente ha autorizzato chiusura a DONE se review/build/check risultano OK

### Follow-up candidate
- HTML avanzato con `colspan` / `rowspan` o più tabelle rumorose, solo se emerge una fixture reale che dimostri shift o scelta tabella errata.
- Eventuale XCTest target futuro per rendere automatiche le fixture A-F; non creato in TASK-031 perché assente dal progetto e fuori perimetro minimo.

### Riepilogo finale
TASK-031 completata. Il riconoscimento header HTML/XLSX ora converge su chiavi interne stabili per canonici camelCase, snake_case, varianti spaziate/case-insensitive e alias localizzati principali; il fallback senza header reale resta conservativo; override manuale e compatibilità append preservati. Build Debug Simulator PASS.

### Data completamento
2026-04-27
