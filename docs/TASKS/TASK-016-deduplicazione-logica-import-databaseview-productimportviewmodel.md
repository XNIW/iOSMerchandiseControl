# TASK-016: Deduplicazione logica import DatabaseView/ProductImportViewModel

## Informazioni generali
- **Task ID**: TASK-016
- **Titolo**: Deduplicazione logica import DatabaseView/ProductImportViewModel
- **File task**: `docs/TASKS/TASK-016-deduplicazione-logica-import-databaseview-productimportviewmodel.md`
- **Stato**: BLOCKED
- **Fase attuale**: REVIEW *(sospesa — task non attivo progetto; ultima fase operativa prima della sospensione)*
- **Responsabile attuale**: UTENTE *(test manuali pendenti; se regressioni → segnalare per FIX/CODEX)*
- **Data creazione**: 2026-03-24
- **Ultimo aggiornamento**: 2026-03-24 (sospensione BLOCKED: review APPROVED, test manuali non eseguiti; TASK-017 attivato su richiesta utente)
- **Ultimo agente che ha operato**: CLAUDE

## Dipendenze
- **Dipende da**: riferimento di backlog da TASK-014: follow-up collegato alla logica oggi condivisa tra `TASK-005` e `TASK-006`; dettaglio operativo da confermare nel planning senza assumere che i task correlati siano gia' chiusi.
- **Sblocca**: riduzione del rischio di divergenza futura tra `DatabaseView` e `ProductImportViewModel`; nessun task bloccato direttamente dichiarato al momento.

## Scopo
Preparare un intervento minimo per ridurre la duplicazione della logica di import oggi presente tra `DatabaseView` e `ProductImportViewModel`, mantenendo invariato il comportamento utente e senza introdurre refactor ampi. Il planning dovra' chiarire quali porzioni sono davvero candidate a condivisione e quali no.

## Contesto
Il backlog corrente identifica TASK-016 come follow-up low priority emerso da TASK-014 (`DT-03`). Nel codice attuale `ProductImportViewModel.swift` contiene commenti espliciti che indicano logica copiata da `DatabaseView` per analisi, apply e helper DB; inoltre il calcolo dei `changedFields` nell'analisi prodotti risulta gia' centralizzato in `ProductUpdateDraft.computeChangedFields(...)` per il path `DatabaseView`, mentre `ProductImportViewModel` mantiene ancora una versione inline equivalente. Il task nasce per riallineare questo punto in modo prudente, senza mescolare cambiamenti funzionali non richiesti.

## Non incluso
- **Path CSV semplice** in `DatabaseView` (`importProducts` / `parseProductsCSV` e uso dei `findOrCreate*` in coda al file): **fuori dal target di deduplicazione** salvo motivazione forte in execution, prova di equivalenza semantica e aggiornamento esplicito di questo planning (vedi sotto **Target deduplicazione lato DatabaseView**)
- Pipeline full-database recente (`DatabaseImportPipeline.prepareFullDatabaseImport`, `applyImportAnalysisInBackground`, progress snapshot, pending supplier/category, `NonProductDeltaSummary`, fingerprint `PriceHistory`)
- Progress / cancellation / result surface del full import (TASK-024)
- Non-product diff / extra del full import e comportamento specifico di TASK-023
- Refactor di UX o cambi visibili nel flusso utente
- Refactor architetturale largo di `DatabaseView`
- Nuove dipendenze o modifiche di API pubbliche
- Estensioni fuori dal perimetro della deduplicazione minima tra `DatabaseView` e `ProductImportViewModel`

## File potenzialmente coinvolti
- `iOSMerchandiseControl/DatabaseView.swift` (priorita': ramo **Excel/simple** dentro `DatabaseImportPipeline`, es. `prepareProductsImport` / `analyzeImport` / apply correlato — **non** il blocco CSV in coda al file salvo eccezione documentata)
- `iOSMerchandiseControl/ProductImportViewModel.swift`
- `iOSMerchandiseControl/ImportAnalysisView.swift` — **consumer da preservare**: ospita `ProductDraft` / `ProductUpdateDraft`, `normalizedImportNamedEntityName(...)`, e l'editing in anteprima ricalcola i `changedFields` con `ProductUpdateDraft.computeChangedFields(...)`; la no-regression deve coprire anche questo flusso (il file puo' restare intoccato se l'estrazione non lo attraversa, ma i criteri e la matrice sotto restano vincolanti)
- **(candidato nuovo file)** helper/core interno condiviso, es. `iOSMerchandiseControl/ProductImportCore.swift` o nome equivalente da fissare in execution — allinea la lista al planning che gia' raccomanda l'estrazione; **non e' scope creep**: e' il veicolo naturale per il nucleo duplicato, senza allargare il perimetro funzionale oltre la deduplicazione concordata.

## Criteri di accettazione
Questi criteri sono il contratto iniziale del task e vanno confermati/raffinati nel planning prima dell'execution.
- [ ] Il planning identifica con precisione le unita' duplicate realmente in scope tra `DatabaseView` (Excel/simple via `DatabaseImportPipeline`) e `ProductImportViewModel`, distinguendole da **path CSV** e dai pezzi specifici del full import
- [ ] L'approccio proposto mantiene `DatabaseView` e `ProductImportViewModel` come orchestratori, estraendo solo il nucleo condiviso minimo
- [ ] L'analisi prodotti continua a produrre lo stesso comportamento su barcode duplicati, aggregazione quantity/stockQuantity, warning duplicati e costruzione di `newProducts` / `updatedProducts`
- [ ] Il calcolo dei `changedFields` sugli update resta coerente tra i due call site, senza introdurre una terza variante
- [ ] L'apply continua a creare/riusare supplier e category con la stessa semantica attuale per ciascun call site
- [ ] Su supplier/category: nessun cambiamento silenzioso rispetto al comportamento attuale su valori **assenti**, stringhe **vuote** o **solo spazi** dopo normalizzazione/trim (nessuna creazione accidentale di `Supplier` / `ProductCategory` con nome vuoto; stessa logica di "nil / non collegato" dove oggi il codice evita il find-or-create)
- [ ] La creazione dello storico prezzi su insert/update resta invariata nei casi coperti oggi dai due flussi, inclusa la regola attuale: **nessun nuovo record di storico** quando il prezzo nuovo **non differisce** da quello gia' presente (ove cosi' implementato oggi)
- [ ] Nessun cambiamento di comportamento utente viene introdotto sul simple import (Excel + anteprima `ImportAnalysisView` + `ProductImportViewModel`)
- [ ] Il path **CSV semplice** in `DatabaseView` non viene modificato ne' deduplicato per accidente; eventuali interventi richiedono motivazione forte, prova di equivalenza e aggiornamento esplicito del perimetro nel file task
- [ ] `ImportAnalysisView`: dopo modifiche al core, editing dell'anteprima e ricalcolo `changedFields` restano coerenti (es. update che non ha piu' differenze sparisce dalla lista come oggi)
- [ ] `ProductImportViewModel.analyzeExcelGrid(header:dataRows:)` e `analyzeMappedRows(_:)` restano **equivalenti** a parita' di contenuto logico delle righe (stesso insieme di coppie colonna/valore dopo il mapping)
- [ ] Nessuna regressione viene introdotta sul full import recente (`TASK-024` e relativi extras fuori scope)
- [ ] Se il core/apply estratto e' **riusato** dal ramo full-database: resta rispettata la semantica **`recordPriceHistory == false`** / **`suppressAutomaticProductPriceHistory`** (nessuno storico prezzi **automatico** sui prodotti quando lo storico e' gestito/importato separatamente dal foglio dedicato, come oggi)
- [ ] **`suppliersCreated`** e **`categoriesCreated`** nel full import continuano a riflettere **solo** supplier/category **realmente nuove**; nessuna alterazione silenziosa di metriche o **result surface** del full import per effetto della deduplicazione
- [ ] L'handoff a execution chiarisce ordine di estrazione, adattatori da preservare e verifiche minime di no-regression

## Decisioni
Decisioni superate o cambiate non vanno cancellate: marcarle come OBSOLETA con nota esplicita.
| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|-------|
| 1 | Bootstrap del task in PLANNING senza avviare execution | Saltare direttamente a EXECUTION | Richiesta utente esplicita; evitare assunzioni premature sul perimetro tecnico | attiva |
| 2 | Deduplicazione limitata al core condiviso import/simple apply, senza inglobare il full-import recente | Spostare nel task anche pipeline full import, progress e result surface | Evita scope creep su TASK-023/TASK-024 e riduce rischio regressioni | attiva |
| 3 | `DatabaseView` e `ProductImportViewModel` restano orchestratori; l'eventuale estrazione condivisa deve restare interna e piccola | Mega-service o refactor architetturale creativo | Minimo cambiamento efficace e minore rischio di accoppiamento improprio | attiva |
| 4 | Il core condiviso espone **funzioni/helper interni** con dipendenze **passate esplicitamente** (`ModelContext` dove serve, dati in input, flag necessari); **no** nuovi service stateful, singleton o ownership implicita del `ModelContext` | Core che incapsula e possiede il context, o layer generico riusabile ovunque | Mantiene orchestratori sottili, riduce rischio di refactor improprio e regressioni sui flussi esistenti | attiva |
| 5 | **Modello dati del core**: niente **nuovo** payload/tipo intermedio astratto o "generico" introdotto solo per avere un layer di analisi/import; il core deve **preferire il riuso** dei tipi di dominio gia' presenti e gia' usati dai due percorsi (es. `ProductDraft`, `ProductUpdateDraft`, `ProductImportRowError`, `ProductDuplicateWarning`, `ProductImportAnalysisResult` o equivalenti gia' nel modulo). Dove un call site oggi wrappa diversamente (es. payload full/simple lato `DatabaseView`), restano **adapter sottili ai bordi**, non un terzo modello parallelo | Nuovo DTO interno universale per "righe import" o analisi che duplica campi gia' espressi altrove | Evita che l'execution complichi la deduplicazione con mapping extra inutile | attiva |
| 6 | **Contratto di estrazione**: il core resta **piccolo, interno**, solo **helper/funzioni mirate**; **non** ingloba progress, cancellation, payload/result surface del full import, `PendingFullImportContext`, `DatabaseImportUILocalizer`, ne' altre responsabilita' di TASK-023/TASK-024. `applyImportAnalysis` (lato `DatabaseView`) va intesa come **scomponibile**: si estrae il minimo comune, **non** si "sposta in blocco" l'intera funzione se questo trascina dipendenze fuori perimetro | Core unico che avvolge apply + UI full import + stato progress | Evita regressioni e scope creep su pipeline recente | attiva |
| 7 | **Normalizzazione nomi** (supplier/category e affini): riusare la **semantica gia' codificata** (`normalizedImportNamedEntityName`, `trim`/`trimmedOrNil` dove gia' usati dai call site); **no** nuove regole di normalizzazione o persistenza dei nomi senza motivazione documentata e verifica esplicita di compatibilita' con Excel/simple, `ImportAnalysisView` e `ProductImportViewModel` | Normalizzazione "migliorata" ad hoc nel core | Riduce rischio di drift silenzioso su dati e anteprima | attiva |
| 8 | **Full-import apply / price history**: se l'estrazione tocca codice **riusato** da `DatabaseImportPipeline` per l'apply full-database, va **preservato** il comportamento con **`recordPriceHistory = false`** quando il payload/contesto impone **`suppressAutomaticProductPriceHistory`** (es. presenza foglio storico dedicato): il full import **non** deve generare `ProductPrice` automatici laddove oggi sono soppressi | Helper apply unico che scrive sempre storico su ogni update | Evita doppioni o conflitto con import storico da foglio separato | attiva |
| 9 | **Contatori full import**: `suppliersCreated` e `categoriesCreated` devono continuare a contare **solo** entita' **nuove** realmente inserite; la deduplicazione **non** deve cambiare in silenzio totali, testi di riepilogo o altra **result surface** del full import | Conteggio "facile" che include riusi | Metriche UX e trust utente restano allineate al comportamento attuale | attiva |

---

## Planning (Claude)

### Analisi — stato attuale nel codice (verificato)

La duplicazione reale in scope e' concentrata nel **core import prodotti** condiviso oggi in modo implicito tra `DatabaseView` e `ProductImportViewModel`, non nella pipeline full-database recente.

| Unita' / regola | `DatabaseView.swift` | `ProductImportViewModel.swift` | Stato |
|---|---|---|---|
| `parseDouble(from:)` | Presente come helper statico | Presente come helper statico quasi identico | Duplicazione diretta |
| `analyzeImport(...)` | Presente come helper statico; riceve `[ImportExistingProductSnapshot]` e restituisce `DatabaseImportAnalysisPayload` | Presente come helper privato (commento "copiata da DatabaseView"); riceve `[Product]` e restituisce `ProductImportAnalysisResult` | Duplicazione diretta; **tipi input/output diversi** — l'estrazione deve restituire tipi di dominio condivisi (`ProductDraft`, `ProductUpdateDraft`) e lasciare il wrapping specifico agli orchestratori |
| Raggruppamento barcode + somma quantita' | Dentro `analyzeImport(...)` | Dentro `analyzeImport(...)` | Duplicazione embedded |
| Costruzione `ProductDraft` da riga normalizzata | Dentro `analyzeImport(...)` | Dentro `analyzeImport(...)` | Duplicazione embedded |
| Calcolo `changedFields` sugli update | Usa `ProductUpdateDraft.computeChangedFields(...)` | Mantiene ancora logica inline equivalente su `ChangedField.allCases` | Duplicazione / divergenza da chiudere |
| `applyImportAnalysis(...)` | Presente nel path import, ma avvolto da logica full-import piu' ampia | Presente come helper privato con commento "copiata da DatabaseView" | Duplicazione parziale da isolare con prudenza |
| `createPriceHistoryForImport(...)` | Presente come helper statico con `ModelContext` esplicito | Presente come helper privato quasi identico | Duplicazione diretta |
| `findOrCreateSupplier(...)` | Helper **istanza** in coda al file, usati dal **path CSV**; il path **Excel/simple** usa invece **closure inline** `resolveSupplier` dentro lo static `applyImportAnalysis`, con tracking `createdSupplierNames` per contatori | Presente come helper privato quasi identico (istanza, usa `self.context`) | Duplicazione ViewModel vs **CSV** in `DatabaseView`; il path Excel/simple ha gia' una variante diversa (closure + contatori) — il core estratto deve modellarsi sulla variante **closure con contatori opzionali**, non sugli istanza-method CSV |
| `findOrCreateCategory(...)` | Come sopra (CSV = istanza; Excel/simple = closure inline `resolveCategory` con tracking `createdCategoryNames`) | Come sopra | Come sopra |

Osservazioni utili per il perimetro:
- La duplicazione in scope riguarda il **simple import core**: analisi righe prodotto, apply su `Product`, creazione price history, risoluzione supplier/category, parsing numerico.
- Il path **Excel/simple** in `DatabaseView` passa da **`DatabaseImportPipeline`** (es. `prepareProductsImport`, `analyzeImport`, `applyImportAnalysis`, `createPriceHistoryForImport` nel contesto preparazione/apply prodotti — allineare l'estrazione a questo ramo, non al CSV).
- Il path `DatabaseView` contiene anche responsabilita' **non condivisibili tal quali**: progress reporting, background context, pending supplier/category, contatori `suppliersCreated/categoriesCreated`, flag `recordPriceHistory`, handoff verso il full import e gestione extras non-product.
- `ProductImportViewModel` contiene responsabilita' **specifiche del caller**: `analysis` / `lastError`, `inferHeader(from:)`, conversione da mapped rows, `context.save()` finale e messaggi errore utente.
- **Divergenza normalizzazione nomi**: `DatabaseView` (path Excel/simple) delega a `normalizedImportNamedEntityName(...)` definito in `ImportAnalysisView.swift` (trims + nil se vuoto); `ProductImportViewModel` usa un helper locale `trimmedOrNil` con semantica analoga ma separata. L'estrazione deve unificare su `normalizedImportNamedEntityName` (gia' condiviso e usato da `computeChangedFields`), eliminando `trimmedOrNil` come variante locale.
- **Pattern snapshot vs Product diretto**: `DatabaseView.analyzeImport` riceve `[ImportExistingProductSnapshot]` (struct con `.draft` computed) per isolare l'analisi dal modello SwiftData; `ProductImportViewModel.analyzeImport` riceve `[Product]` direttamente. Il core estratto dovrebbe lavorare su **draft/snapshot** (input gia' trasformato), lasciando la conversione `Product → draft` o `Snapshot → draft` agli orchestratori.
- **Contatori supplier/category nel ViewModel**: `ProductImportViewModel.applyImportAnalysis` **non traccia** `suppliersCreated` / `categoriesCreated` (non servono al suo flow); `DatabaseView` li traccia tramite le closure `resolveSupplier`/`resolveCategory` con set `createdSupplierNames`/`createdCategoryNames`. Il core estratto per l'apply deve supportare contatori **opzionali** (o restituirli sempre lasciando al caller la scelta di usarli), senza forzare il ViewModel a tracciarli ne' privare il DatabaseView della metrica.

### Target deduplicazione lato DatabaseView (Excel/simple vs CSV)

- **In scope (default)**: codice condivisibile sul flusso **Excel con analisi** — orchestrazione tipo `importProductsFromExcel` → `DatabaseImportPipeline.prepareProductsImport` / analisi / apply prodotto — ovvero cio' che oggi convive con `analyzeImport` e gli helper statici del pipeline **senza** confondersi col full import.
- **Fuori scope (default)**: **import CSV semplice** (`importProducts`, `parseProductsCSV`, `splitCSVRow`, ... ) e i `findOrCreate*` **istanza** in fondo a `DatabaseView.swift` usati da quel path. TASK-016 **non** deve deduplicarli ne' spostarli nel core **per accidente**; includerli richiede motivazione forte, **prova di equivalenza semantica** con il ViewModel (o con un helper condiviso reale) e aggiornamento esplicito di questo file task.

### Scope guard esplicito

`TASK-016` deve colpire solo il **core condiviso** tra `DatabaseView` e `ProductImportViewModel`.

Fuori scope esplicito:
- path **CSV semplice** e relativi helper in coda a `DatabaseView` (salvo eccezione documentata come sopra)
- pipeline full-database recente
- progress / cancellation / result surface di `TASK-024`
- refactor di UX
- non-product diff / full import extras
- refactor architetturale largo di `DatabaseView`
- rewrite dei flow asincroni/background del full import

**Guardrail — riuso del codice apply con il full import (facoltativo ma vincolante se toccato)**  
L'estrazione del core **non** e' nel perimetro funzionale del full import, ma puo' **attraversare** funzioni condivise. In quel caso:
- rispettare **Decisione 8**: nessuna regressione su **`recordPriceHistory`** / **`suppressAutomaticProductPriceHistory`** (no storico automatico quando oggi e' soppresso per import storico separato).
- rispettare **Decisione 9**: **`suppliersCreated`** / **`categoriesCreated`** e ogni metrica esposta nel risultato full import restano fedeli al significato attuale (solo nuove entity).

### Approccio tecnico raccomandato

Direzione raccomandata: estrarre un **helper/core condiviso interno e minimo**, lasciando `DatabaseView` e `ProductImportViewModel` come orchestratori.

Linee guida:
- rispettare il vincolo dipendenze esplicite in **Decisione 4** (nessun context "nascosto" nel core)
- rispettare il **modello canonico** in **Decisione 5**: funzioni sul dominio esistente, **no** payload intermedio superfluo
- rispettare il **contratto di estrazione** in **Decisione 6**: core = solo funzioni/helper mirate; **vietato** introdurvi progress, cancellation, payload/result del full import, `PendingFullImportContext`, `DatabaseImportUILocalizer`, o logica TASK-023/TASK-024; `applyImportAnalysis` si **scompone**, non si sposta monolitica
- rispettare **Decisione 7** sulla normalizzazione nomi (nessuna nuova regola senza verifica)
- se il codice estratto e' sul percorso **condiviso** con il full import: rispettare **Decisioni 8-9** (price history soppresso quando previsto; contatori e result surface invariati nel significato)
- partire dalle unita' piu' piccole e deterministicamente condivise: `parseDouble(...)`, regole di analisi/import, `createPriceHistoryForImport(...)`, risoluzione supplier/category **nel perimetro Excel/ViewModel** (non CSV salvo decisione esplicita)
- riusare i tipi gia' nel modulo (come in Decisione 5) invece di introdurre nuove API pubbliche ampie
- non imporre un nome file definitivo, ma una direzione tipo `ProductImportCore.swift` o helper equivalente interno al modulo e' coerente con il perimetro
- evitare di trascinare nel core condiviso progress reporting, background apply, pending supplier/category, contatori extra, result surface o altre responsabilita' del full import

Ordine prudente suggerito per il futuro lavoro:
1. chiudere la divergenza piu' semplice: usare una sola regola per `changedFields`
2. isolare il nucleo puro/deterministico dell'analisi
3. isolare il minimo comune dell'apply prodotto/storico prezzi
4. lasciare adapters/orchestrazione specifica nei due call site

**Strategia di atterraggio in execution (stesso task, due micro-passi opzionali)**  
Se utile per ridurre il rischio in un'unica PR troppo grande, l'execution puo' procedere **in due step interni** senza allargare lo scope ne' aprire un secondo task:
- **(a)** riallineare prima il **nucleo di analisi** e la regola unica dei **`changedFields`**;
- **(b)** poi deduplicare il **nucleo apply** e gli helper DB condivisi (price history, find-or-create supplier/category, ecc.) **nel perimetro Excel + ViewModel**, senza coinvolgere il path CSV salvo decisione esplicita.  
Resta **un solo TASK-016**; e' solo sequencing prudente.

### Matrice no-regression — casi concreti (execution / review)

Verifiche minime consigliate (manuali o automatizzabili in seguito), da intendersi **a parita' di dati** rispetto a oggi:

1. **Barcode duplicati in analisi**: ultima riga vince sui **campi testuali** rilevanti; **quantita'** aggregata come oggi; warning duplicati coerenti.
2. **Supplier / category**: `nil`, stringa vuota, solo spazi (dopo trim/normalizzazione attuale): **nessuna** `Supplier` / `ProductCategory` con nome vuoto creata per errore; stessa semantica su prodotto **non collegato** vs collegato.
3. **Price history**: nuovo record solo quando il prezzo importato **differisce** da quello gia' presente secondo la logica attuale (nessun doppione inutile).
4. **ViewModel**: `analyzeExcelGrid` vs `analyzeMappedRows` — stesso risultato analitico a parita' di contenuto logico delle righe.
5. **`ImportAnalysisView`**: edit di un update in anteprima; se dopo salvataggio **non restano differenze** (`computeChangedFields` vuoto), l'update **esce dalla lista** come oggi.
6. **Full import (se il diff tocca codice riusato)**: con dataset che attiva **`suppressAutomaticProductPriceHistory`**, verificare che **non** compaiano `ProductPrice` automatici indesiderati rispetto a oggi; controllare che **`suppliersCreated` / `categoriesCreated`** (e messaggi di riepilogo collegati) non divergano nel significato.

### Call site e consumer da preservare (semanticamente)

La deduplicazione mira a **unificare implementazione** senza cambiare comportamento nei punti d'uso reali; in execution/review vanno verificati almeno:

- **`DatabaseView` — path Excel/simple** (`importProductsFromExcel` → `DatabaseImportPipeline.prepareProductsImport` / analisi / apply prodotto; **non** confondere con `importProducts` CSV ne' con i `findOrCreate*` in coda al file salvo piano esplicito).
- **`ImportAnalysisView`** — tipi `ProductDraft` / `ProductUpdateDraft`, `normalizedImportNamedEntityName`, editing anteprima e `ProductUpdateDraft.computeChangedFields`; ogni cambio al core che influisce su draft/update deve restare coerente con questa UI.
- **`ProductImportViewModel.analyzeExcelGrid(header:dataRows:)`** — dopo estrazione, deve restare semanticamente equivalente (stessa analisi/risultato per stessi input).
- **`ProductImportViewModel.analyzeMappedRows(_:)`** — idem, incluso il percorso `inferHeader` + grid interna prima dell'analisi.
- **`ProductImportViewModel.applyImport()`** — delega a `applyImportAnalysis(...)` interno: eventuale spostamento nel core deve preservare creazione/aggiornamento prodotto, supplier/category e storico prezzi come oggi per questo caller.

### Divergenze da preservare

Logica davvero comune da condividere:
- parsing numerico input (`parseDouble`)
- normalizzazione/aggregazione righe per barcode dentro l'analisi
- costruzione di `ProductDraft`
- calcolo `changedFields`
- regole di apply su `Product`
- creazione `ProductPrice` da import
- find-or-create di supplier/category nel perimetro Excel/ViewModel, se riallineato senza alterare semantica (**Decisione 7**)

Adapter / mapping / error handling che possono restare separati:
- `DatabaseView`: background context, progress, save batch, pending supplier/category, contatori **`suppliersCreated` / `categoriesCreated`**, flag **`recordPriceHistory`**, **`suppressAutomaticProductPriceHistory`** / `pendingFullImportContext`, integrazione full import (**Decisioni 8-9**), conversione `ImportExistingProductSnapshot → draft` prima di entrare nel core
- `ProductImportViewModel`: `inferHeader(from:)`, trasformazione mapped rows -> grid, conversione `Product → draft` prima dell'analisi, `analysis`/`lastError`, `context.save()` finale, stringhe errore utente
- mapping degli errori di analisi: `DatabaseImportPreparationError` / payload full-import da una parte, `ExcelLoadError` / `ProductImportRowError` dall'altra
- tipi di ritorno dell'analisi: `DatabaseImportAnalysisPayload` (DatabaseView) vs `ProductImportAnalysisResult` (ViewModel) — il core restituisce i tipi di dominio condivisi; ciascun orchestratore wrappa nel proprio payload
- differenze tra path (es. `DatabaseImportPipeline` / `ImportAnalysisView` vs `trimmedOrNil` nel ViewModel) vanno **riconciliate** unificando su `normalizedImportNamedEntityName` (gia' condiviso) e allineandosi a **Decisione 7**, non introducendo regole nuove; `trimmedOrNil` va eliminato come variante locale

### Rischi identificati

- **Confondere Excel/simple con CSV**: modifiche o estrazioni che toccano `importProducts` / `parseProductsCSV` o i `findOrCreate*` in coda a `DatabaseView` senza piano esplicito possono introdurre regressioni fuori perimetro
- Deducere al livello sbagliato puo' inglobare accidentalmente il full import recente e causare scope creep su `TASK-024`
- Unificare senza controllo la normalizzazione di supplier/category puo' cambiare dati persistiti o output analisi
- **Supplier/category "vuoti"**: unificare trim/normalizzazione senza attenzione puo' introdurre **find-or-create** su nomi effettivamente vuoti, o cambiare quando il prodotto resta **senza** supplier/category rispetto a oggi (vedi criterio CA dedicato)
- Estrarre l'intera `applyImportAnalysis(...)` di `DatabaseView` sarebbe troppo ampia: contiene responsabilita' extra non condivise
- Introdurre nuovi tipi o API troppo generiche aumenterebbe il costo del task senza beneficio proporzionato (**contrasto con Decisione 5**)
- **Apply condiviso full/simple**: refactor che ignora **`recordPriceHistory`** / **`suppressAutomaticProductPriceHistory`** puo' far riapparire storico prezzi automatico nel full import quando oggi e' soppresso (**Decisione 8**)
- **Contatori full import**: riuso di find-or-create o helper estratti senza threadare i contatori corretti puo' gonfiare o azzerare **`suppliersCreated` / `categoriesCreated`** o alterare la result surface (**Decisione 9**)

### Handoff interno (storico — pre-sospensione)
*La execution e la review sotto sono state completate; il task e' poi stato messo in **BLOCKED** per test manuali pendenti (vedi **Sospensione progetto — BLOCKED**).*

---

## Execution (Codex)

### Obiettivo compreso
Allineare formalmente `TASK-016` a `EXECUTION`, poi deduplicare con il minimo cambiamento efficace il core condiviso dell'import Excel/simple tra `DatabaseView` e `ProductImportViewModel`. Il lavoro deve colpire analisi/import, `changedFields`, apply/helper DB nel perimetro concordato, preservando `ImportAnalysisView` e senza trascinare CSV, progress/cancellation/result surface del full import o refactor architetturali larghi.

### File controllati
- `docs/MASTER-PLAN.md`
- `CLAUDE.md`
- `AGENTS.md`
- `docs/TASKS/TASK-016-deduplicazione-logica-import-databaseview-productimportviewmodel.md`
- `iOSMerchandiseControl/DatabaseView.swift`
- `iOSMerchandiseControl/ProductImportViewModel.swift`
- `iOSMerchandiseControl/ImportAnalysisView.swift`

### Piano minimo
1. Allineare tracking canonico `PLANNING -> EXECUTION` in `docs/MASTER-PLAN.md` e nel file task.
2. Estrarre un core interno piccolo per la parte deterministica condivisa (`parseDouble`, analisi/import, regola unica `changedFields`) senza cambiare i contratti dei caller.
3. Deduplicare il minimo comune dell'apply e degli helper DB nel perimetro Excel/ViewModel, lasciando `DatabaseView` e `ProductImportViewModel` come orchestratori e preservando `recordPriceHistory`, `suppressAutomaticProductPriceHistory`, `suppliersCreated` e `categoriesCreated`.
4. Eseguire build/check realistici, poi aggiornare tracking finale con esito reale e handoff verso `REVIEW`.

### Modifiche fatte
- Riallineato il tracking di `TASK-016` da `PLANNING` a `EXECUTION` prima del codice, poi a `REVIEW` a fine execution, mantenendo il task `ACTIVE` e senza chiusura prematura.
- Creato `iOSMerchandiseControl/ProductImportCore.swift` come core interno minimo condiviso per:
  - `parseDouble(from:)`
  - analisi prodotti (`analyzeImport(...)`) con aggregazione barcode/quantity, warning duplicati e regola unica `ProductUpdateDraft.computeChangedFields(...)`
  - apply minimo condiviso (`insertProduct`, `applyUpdate`)
  - `createPriceHistoryForImport(...)`
  - resolver condiviso `ProductImportNamedEntityResolver` per supplier/category con semantica `normalizedImportNamedEntityName`
- `ProductImportViewModel.swift` riallineato al core condiviso:
  - `analyzeImport(...)` delega al core dopo la conversione `Product -> ProductDraft`
  - eliminata la divergenza inline su `changedFields`
  - `applyImportAnalysis(...)` riusa il core e il resolver condiviso
  - rimasti invariati orchestration locale, `analyzeExcelGrid`, `analyzeMappedRows`, `applyImport`, `context.save()` finale e `lastError`
- `DatabaseView.swift` riallineato nel perimetro `DatabaseImportPipeline` Excel/simple:
  - `parseDouble(...)` delega al core condiviso
  - `analyzeImport(...)` delega al core e wrappa gli errori nel payload locale
  - `applyImportAnalysis(...)` mantiene progress/save batching/contatori/full-import orchestration ma riusa resolver e helper comuni per insert/update/price history
  - preservati `recordPriceHistory`, `pendingSupplierNames`, `pendingCategoryNames`, `suppliersCreated`, `categoriesCreated`
- Il path CSV in coda a `DatabaseView.swift` (`importProducts`, `parseProductsCSV`, `findOrCreateSupplier`, `findOrCreateCategory`) e la UX/full-import recente (`TASK-024`) sono rimasti fuori scope e non sono stati modificati.

### Check eseguiti
Per ogni check: ✅ ESEGUITO | ⚠️ NON ESEGUIBILE (motivo) | ❌ NON ESEGUITO (motivo)
- [x] Build compila: ✅ ESEGUITO — `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'generic/platform=iOS Simulator' build` -> `** BUILD SUCCEEDED **` (rieseguita anche con log su `/tmp/task016_build.log`)
- [x] Nessun warning nuovo: ✅ ESEGUITO — `rg -n "warning:|error:" /tmp/task016_build.log` ha restituito solo `BUILD SUCCEEDED` e nessun warning/error; il warning AppIntents visto in un build precedente non compare nel log finale
- [x] Modifiche coerenti con planning: ✅ ESEGUITO — STATIC — scope limitato a tracking `TASK-016` + `DatabaseView.swift` + `ProductImportViewModel.swift` + nuovo `ProductImportCore.swift`; nessun tocco a CSV, progress/cancellation/result surface, `PendingFullImportContext` o UX full import
- [x] Criteri di accettazione verificati: ✅ ESEGUITO — BUILD/STATIC — verificati dal codice i punti centrali del task:
  - regola unica `changedFields` centralizzata su `ProductUpdateDraft.computeChangedFields(...)`
  - aggregazione barcode/quantity e warning duplicati spostati nel core condiviso senza cambiare logica
  - normalizzazione nomi allineata a `normalizedImportNamedEntityName`
  - supplier/category vuoti o solo spazi continuano a risolversi a `nil` nel path condiviso
  - price history continua a essere creato solo quando il prezzo cambia
  - `recordPriceHistory: !(pendingFullImportContext?.suppressAutomaticProductPriceHistory ?? false)` resta invariato nel full import
  - `suppliersCreated` / `categoriesCreated` restano legati ai nomi realmente creati tramite set nel resolver condiviso
  - `ImportAnalysisView` non e' stato modificato; il consumer continua a usare `ProductDraft`, `ProductUpdateDraft` e `computeChangedFields(...)` esistenti
  - `analyzeExcelGrid` e `analyzeMappedRows` continuano a convergere sullo stesso `analyzeImport(...)` del view model

### Rischi rimasti
- Nessuna verifica manuale/UI eseguita in questo turno su `ImportAnalysisView`: la coerenza del consumer e' verificata staticamente e via build, ma Claude dovrebbe controllare in review soprattutto il caso "edit di un update che torna senza differenze".
- Nessun test runtime dedicato su dataset reali per confrontare `analyzeExcelGrid` vs `analyzeMappedRows`: il wiring e' identico e compilato, ma la review puo' voler ricontrollare i casi con barcode duplicati e quantity aggregata.
- Il path CSV resta deliberatamente duplicato rispetto al nuovo core condiviso: e' una scelta di scope, non un'incompletezza accidentale; se in futuro servira' convergenza anche li', andra' trattata come follow-up dedicato.
- Il full import non e' stato provato manualmente in questo turno: i guardrail `recordPriceHistory` / `suppressAutomaticProductPriceHistory` e i contatori supplier/category sono preservati staticamente, ma la review dovrebbe verificarne il mantenimento semantico.

### Handoff → Review
- **Prossima fase**: REVIEW
- **Prossimo agente**: CLAUDE
- **Azione consigliata**: verificare che il core condiviso resti davvero nel perimetro Excel/simple, che `ImportAnalysisView` continui a comportarsi uguale sugli edit con ricalcolo `changedFields`, e che il riuso lato `DatabaseImportPipeline` non alteri il significato di `recordPriceHistory`, `suppressAutomaticProductPriceHistory`, `suppliersCreated` e `categoriesCreated` nel full import.

---

## Review (Claude)

### Problemi critici
Nessuno.

### Problemi medi
Nessuno.

### Miglioramenti opzionali (non bloccanti, non richiedono fix)
1. **Dead code — `DatabaseImportPipeline.createPriceHistoryForImport` wrapper** (linee ~1256-1272 di `DatabaseView.swift`): il wrapper statico ora delega a `ProductImportCore.createPriceHistoryForImport`, ma **nessun call site lo chiama piu'** — `insertProduct` e `applyUpdate` nel core gestiscono internamente il price history. Resta come dead code innocuo. Non va rimosso in questo task (fuori scope minimo).
2. **Hardcoded `.barcodeMissing` nel mapping errori di `analyzeImport`** (DatabaseView linea ~707): tutti gli errori del core sono mappati a `.barcodeMissing`. Oggi e' corretto perche' il core genera solo errori di barcode mancante. Se in futuro il core aggiungesse altri tipi di errore, il mapping andrebbe aggiornato. Non e' un problema attuale.

### Fix richiesti
Nessuno.

### Check eseguiti (review statica)
- [x] **Orchestratori preservati**: `DatabaseView` e `ProductImportViewModel` restano orchestratori; il core (`ProductImportCore`) contiene solo helper statici e il resolver — ✅
- [x] **Deduplicazione reale**: `parseDouble`, analisi import, `changedFields`, insert/update/price history, resolver supplier/category tutti estratti nel core; nessuna duplicazione residua significativa — ✅
- [x] **Core non ingloba full import**: nessun progress, cancellation, `PendingFullImportContext`, `DatabaseImportUILocalizer`, result surface nel core — ✅
- [x] **Barcode duplicati**: stessa logica `PendingRow` con last-row-wins + quantity sum + warnings — ✅
- [x] **Aggregazione quantity/stockQuantity**: `pending.quantitySum += quantity` preservata — ✅
- [x] **`changedFields`**: ora usa `ProductUpdateDraft.computeChangedFields(old:new:)` ovunque; verificato che `computeChangedFields` usa `doublesEqual` con epsilon 0.0001, identico alla vecchia logica inline del ViewModel — ✅ **divergenza chiusa**
- [x] **Supplier/category nil-vuoti-spazi**: `resolveSupplier`/`resolveCategory` delegano a `normalizedImportNamedEntityName` che restituisce `nil` su input nil/vuoto/solo-spazi; nessun `Supplier`/`ProductCategory` con nome vuoto creato — ✅
- [x] **Normalizzazione nomi**: unificata su `normalizedImportNamedEntityName`; vecchio `trimmedOrNil` eliminato; semantica identica (trim + nil se vuoto) — ✅
- [x] **Price history**: `createPriceHistoryForImport` genera record solo quando `newPurchase != oldPurchase` o `newRetail != oldRetail`; nessun doppione — ✅
- [x] **`recordPriceHistory` nel full import**: passato da `payload.recordPriceHistory` a `insertProduct`/`applyUpdate` nel core; derivazione `!(pendingFullImportContext?.suppressAutomaticProductPriceHistory ?? false)` invariata (linea ~2801) — ✅
- [x] **`suppliersCreated`/`categoriesCreated`**: derivati da `resolver.suppliersCreatedCount`/`resolver.categoriesCreatedCount` che tracciano un `Set<String>` interno; semantica identica alle vecchie closure con `createdSupplierNames`/`createdCategoryNames` — ✅
- [x] **`preloadSuppliers`/`preloadCategories`**: correttamente richiamati prima dell'apply con `payload.pendingSupplierNames`/`pendingCategoryNames` — ✅
- [x] **`ImportAnalysisView` non toccata**: `ProductDraft`, `ProductUpdateDraft`, `computeChangedFields`, `normalizedImportNamedEntityName` invariati; editing anteprima e ricalcolo changedFields continuano a funzionare — ✅
- [x] **Path CSV non toccato**: `importProducts`, `parseProductsCSV`, `splitCSVRow`, `findOrCreateSupplier`/`findOrCreateCategory` istanza in coda a `DatabaseView` invariati — ✅
- [x] **Progress/cancellation/result surface**: loop progress con `reportImportProgress`, `saveImportProgressIfNeeded`, `autoreleasepool` invariati nell'`applyImportAnalysis` di DatabaseView — ✅
- [x] **Concorrenza**: `ProductImportNamedEntityResolver` e' una classe non-Sendable usata entro singolo scope funzione; nessun rischio di accesso concorrente — ✅
- [ ] **Build**: ⚠️ NON ESEGUITO da Claude in questa review — l'execution dichiara build verde (`BUILD SUCCEEDED`); accettato come evidenza

### Esito
**APPROVED** — tutti i criteri di accettazione verificati staticamente; nessun problema critico o medio; la deduplicazione e' reale, il perimetro e' rispettato, il comportamento e' invariato su tutti i path verificati.

Il task puo' passare alla **conferma utente** e ai **test manuali** consigliati sotto.

### Handoff → conferma utente *(sospeso — non eseguire DONE finche' il task non esce da BLOCKED)*
- **Prossima fase prevista (dopo test manuali)**: conferma utente → DONE, oppure FIX se emergono regressioni
- **Prossimo agente**: UTENTE (test manuali), poi CLAUDE/CODEX se necessario
- **Azione consigliata**: eseguire i test manuali elencati nella review; **non** dichiarare DONE senza esito reale

---

## Sospensione progetto — BLOCKED (user override 2026-03-24)

**Motivo della sospensione**
- Review codice **APPROVED** (Claude); nessun fix richiesto; warning build/concurrency trattati in execution.
- **Test manuali** previsti dalla review **non ancora eseguiti/completati** dall'utente.
- Il task **non** e' **DONE** e **non** e' piu' il **task attivo** del progetto (attivo: **TASK-017** su richiesta utente).

**Alla ripresa (ordine consigliato)**
1. **Test manuali** sul perimetro TASK-016 (simple import Excel, `ImportAnalysisView`, `ProductImportViewModel`, smoke full import se il diff lo tocca — come da matrice/review).
2. Se emergono regressioni → fase **FIX** (CODEX) → **REVIEW** (CLAUDE).
3. Solo dopo esito positivo e verifica criteri: **conferma utente** → **DONE**.

**Handoff operativo (task BLOCKED, non attivo)**
- **Prossima azione**: UTENTE — completare validazione manuale; poi aggiornare tracking e chiudere o aprire FIX.
- **Prossimo agente dopo i test**: CLAUDE (review post-test) o CODEX (solo se FIX necessario).

---

## Fix (Codex)

### Fix applicati
- [ ] [Da compilare in fase FIX]

### Check post-fix
Per ogni check: ✅ ESEGUITO | ⚠️ NON ESEGUIBILE (motivo) | ❌ NON ESEGUITO (motivo)
- [ ] Build compila: [Da compilare in fase FIX]
- [ ] Fix coerenti con review: [Da compilare in fase FIX]
- [ ] Criteri di accettazione ancora soddisfatti: [Da compilare in fase FIX]

### Handoff → Review finale
- **Prossima fase**: REVIEW
- **Prossimo agente**: CLAUDE
- **Azione consigliata**: Verificare i fix applicati

---

## Chiusura

### Conferma utente
- [ ] Utente ha confermato il completamento

### Follow-up candidate
[Da compilare in chiusura, se necessario]

### Riepilogo finale
[Da compilare in chiusura]

### Data completamento
YYYY-MM-DD
