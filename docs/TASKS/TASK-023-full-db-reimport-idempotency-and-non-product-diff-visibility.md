# TASK-023: Full-database reimport idempotency + non-product diff visibility

## Informazioni generali
- **Task ID**: TASK-023
- **Titolo**: Full-database reimport idempotency + non-product diff visibility
- **File task**: `docs/TASKS/TASK-023-full-db-reimport-idempotency-and-non-product-diff-visibility.md`
- **Stato**: BLOCKED
- **Fase attuale**: REVIEW *(sospesa — vedi Sospensione)*
- **Responsabile attuale**: USER *(nessun lavoro agent attivo; in attesa test manuali utente)*
- **Data creazione**: 2026-03-23
- **Ultimo aggiornamento**: 2026-03-24
- **Ultimo agente che ha operato**: CLAUDE

## Dipendenze
- **Dipende da**: TASK-022 completato
- **Sblocca**: comportamento affidabile e idempotente del reimport full-database; maggiore trasparenza dei delta non-product nel riepilogo di import

## Scopo
Rendere il reimport dello stesso full database **idempotente per PriceHistory** (nessun duplicato inserito se i record sono gia' presenti) e **trasparente per i delta non-product** (supplier, category, price history) nella schermata di analisi, senza allargare il perimetro a progress UX, cancellation, o refactor ampi.

## Contesto
TASK-022 ha chiuso con successo il crash nel passaggio conferma -> apply del full-database import grande. Dopo la chiusura, i test manuali utente hanno evidenziato un problema diverso e fuori scope rispetto al crash: reimportando lo stesso file database completo, il lavoro effettivo puo' ricadere quasi tutto su `PriceHistory`, ma questo non appare in modo trasparente nella schermata di analisi prodotti. Per mantenere il perimetro minimo e rispettare l'etica del Vibe Coding, la correttezza/performance del reimport e la UX del progress vengono separati in due task distinti.

## Evidenza principale
- Test manuale utente: reimport dello stesso file database completo piu' volte.
- Nella schermata di analisi prodotti i conteggi possono risultare a zero o comunque non spiegare il lavoro reale dell'import.
- Rimuovendo il foglio `PriceHistory`, l'operazione finisce subito.
- Log rilevante osservato sul reimport invariato: `phase=apply_price_history elapsed=150.92s rows=34726 inserted=34726 skipped=0` (testo **legacy** del log pre-TASK-023; nel deliverable TASK-023 i conteggi strutturati usano solo i termini tecnici **`alreadyPresent`** e **`unresolved`**, non `skipped`).
- Conclusione operativa: oggi il reimport non e' idempotente per lo storico prezzi, introduce costo inutile e rende poco trasparente il delta non-product realmente applicato.

## Non incluso
- UX avanzata di progress/cancel (-> TASK-024).
- Refactor largo del parser Excel o della pipeline multi-sheet fuori necessita' reale.
- Nuovi redesign della schermata di analisi oltre quanto serve per rendere visibili i delta non-product rilevanti.
- Riaprire TASK-022 o TASK-011.

---

## Planning

### Root cause verificate nel codice attuale

**RC-1: PriceHistory non idempotente.**
`applyPendingPriceHistoryImport` (DatabaseView.swift:965-1068) inserisce un nuovo `ProductPrice` per OGNI entry parsata dal foglio Excel, senza alcun controllo di duplicato. Sul reimport invariato, 34726 record vengono reinseriti integralmente.

**RC-2: `skippedCount` non significa "gia' presente".**
`skippedCount` (DatabaseView.swift:993) e' calcolato come `entries.count - totalResolvableCount`, cioe' conta solo le entry il cui barcode non esiste nella tabella Product. Non esiste un conteggio `alreadyPresent` per record gia' nel DB. *(Nome attuale nel sorgente: `skippedCount`; nel nuovo output TASK-023 il bucket corrispondente ai barcode non risolvibili si chiama **`unresolved`** — non usare `skipped` come sinonimo tecnico in struct, log strutturati, CA o TM.)*

**RC-3: La schermata di analisi mostra solo delta prodotto.**
`ImportAnalysisView` e `ImportAnalysisSession` (ImportAnalysisView.swift:104-124) contengono solo: `newProducts`, `updatedProducts`, `errors`, `warnings`. Nessuna informazione su supplier, category, o price history. La `summarySection` (ImportAnalysisView.swift:301-307) mostra solo 4 righe: nuovi prodotti, aggiornamenti, warning, errori.

**RC-4: Suppliers/Categories vengono salvati nel DB PRIMA della conferma utente.**
In `prepareFullDatabaseImport` (DatabaseView.swift:285-309), `importSupplierNames` e `importCategoryNames` chiamano `context.save()` su un `backgroundContext`. Questo avviene nella fase di _prepare_, cioe' prima che l'utente veda la schermata di analisi e confermi. Se l'utente annulla, le entita' restano nel DB. Questo e' incoerente con il concetto di "analysis prima della conferma".

### Decisioni di planning

| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|-------|
| 1 | Separare correttezza/performance del reimport da UX/progress | Un unico task "blob" per tutto il follow-up full-database | Riduce scope creep e mantiene il task focalizzato su dati/idempotenza e trasparenza dei delta | attiva |
| 2 | Trattare `PriceHistory` come punto primario del reimport invariato | Refactor ampio immediato su tutta la pipeline multi-sheet | L'evidenza principale punta al reinserimento integrale di `PriceHistory`; il resto va valutato solo se rilevante al delta utente-visibile | attiva |
| 3 | Dedup PriceHistory in fase prepare (DB + **intra-file**), non in apply | Dedup solo in apply; oppure dedup in entrambi | La dedup in prepare permette di calcolare i conteggi per la UI e filtra le entry prima dell'apply. Include duplicati nello stesso foglio (set aggiornato mentre si classifica). Non serve ri-verificare in apply per concorrenza (`importProgress.isRunning`). Hardening in apply resta opzionale/futuro. | attiva |
| 4 | Fingerprint logica senza migration SwiftData | Aggiungere un campo `fingerprint` al modello `ProductPrice` | I campi necessari (`barcode` via relazione, `type`, `effectiveAt`, `price`, `source`) sono gia' disponibili. Una fingerprint calcolata a runtime evita migration e nuovi indici. | attiva |
| 5 | Deferire creazione Suppliers/Categories alla fase apply | Lasciare creazione in prepare (com'e' oggi) | Oggi vengono salvati nel DB prima della conferma utente, il che e' incoerente con l'analisi pre-conferma e impedirebbe di mostrare conteggi accurati nella UI. Il product analysis NON dipende dall'esistenza di Supplier/Category entities nel DB (usa solo stringhe via `ImportExistingProductSnapshot`), quindi il defer e' sicuro. | attiva |
| 6 | Estendere `ImportAnalysisSession` con un optional `NonProductDeltaSummary` | Creare una vista separata per i delta non-product | Minimizza le modifiche: il simple product import passa nil, il full import popola il summary. La `summarySection` mostra le righe extra solo se presente. | attiva |

### Soluzione minima proposta

**Convenzione terminologica PriceHistory (TASK-023)** — In payload, struct di risultato, campi di log strutturato, CA e TM usare **solo** `alreadyPresent` e `unresolved` come termini tecnici; **non** alternare `skipped` / `unresolved` per lo stesso significato. **`alreadyPresent`** include sia i record la cui fingerprint e' **gia' nel DB** sia i **duplicati intra-file** dello stesso import (stessa fingerprint gia' nel set per seed DB o per una `toInsert` precedente nella scansione).

**Niente campi legacy in parallelo**: dove si introducono `alreadyPresent` e `unresolved`, i vecchi nomi/campi che esprimevano semantica sovrapposta **non devono coesistere** con i nuovi in result struct, log strutturati o messaggi finali. In execution: **rimuovere o rinominare** (un solo significato) quanto non serve piu' — es. `skippedCount`, `priceHistorySkipped`, `totalResolvableCount`, totali ridondanti tipo `priceHistoryTotal` se duplicano informazione gia' coperta da `inserted` + `alreadyPresent` + `unresolved`. Obiettivo: zero **doppia semantica** nello stesso apply path.

#### Struttura codice `prepareFullDatabaseImport` (no refactor largo)

Per non gonfiare ulteriormente `prepareFullDatabaseImport`, estrarre **due helper privati** in `DatabaseView.swift` (stesso file, vicino al flusso full-import), senza nuovi moduli ne' split di file obbligatorio:

1. **Classificazione PriceHistory** — una funzione (nome a scelta del dev, es. `classifyParsedPriceHistoryForFullImport(...)`) che incapsula tutto il blocco A.2: fetch `ProductPrice` esistenti, costruzione seed del `Set`, universo barcode risolvibili, partizione `toInsert` / `alreadyPresent` / `unresolved` con dedup intra-file (inserimento fingerprint nel set dopo ogni `toInsert`), output: liste/conteggi da assegnare a `PendingFullImportContext`.

2. **Supplier/Category pending + summary** — una funzione (es. `buildPendingSuppliersCategoriesAndNonProductSummary(...)`) che incapsula lettura fogli + unione deduplicata + confronto con DB + costruzione di `pendingSupplierNames` / `pendingCategoryNames` e `NonProductDeltaSummary` (conteggi UI allineati ai payload), usando il **helper di normalizzazione nomi** descritto sotto.

Obiettivo: leggibilita' in execution e minor rischio di errori di copia-incolla, restando nel perimetro TASK-023.

#### A. PriceHistory idempotency — fingerprint e dedup in prepare

1. **Definire una struct `PriceHistoryFingerprint: Hashable`** (in `DatabaseView.swift`, sezione private structs):
   ```
   barcode: String
   type: PriceType
   effectiveAtEpochSeconds: Int64   // floor(effectiveAt.timeIntervalSince1970)
   priceFixed4: Int64               // round(price * 10000) — valore intero a 4 decimali (NON centesimi; il nome evita ambiguita' con "cents")
   source: String                   // gia' normalizzato via helper fingerprint
   ```
   **Naming prezzo**: non usare `priceCents` se la scala e' `* 10000`: il campo si chiama **`priceFixed4`** (o equivalente esplicito tipo `priceScaledValue`) cosi' il significato coincide con l'implementazione. Se in futuro si volesse davvero la scala centesimi, si rinomina di conseguenza e si cambia il fattore — non mescolare nome "cents" con fattore 10_000.

   La normalizzazione a secondi interi e' necessaria perche' l'export usa formato `"yyyy-MM-dd HH:mm:ss"` (precisione al secondo), ma nel DB `effectiveAt` puo' avere sub-secondi. Il round-trip export→import produce date con `.000` millisecondi. Troncando entrambi al secondo, la fingerprint coincide.

   **Normalizzazione `source` in `makePriceHistoryFingerprint(...)`** (obbligatoria per coerenza DB vs parser full-import):
   - `trim` di whitespace e newline
   - `nil` o stringa vuota dopo trim → un **default unico** concordato (es. stessa stringa usata dall'export/import, es. `IMPORT_DB_FULL` o equivalente gia' presente nel codice), cosi' non si creano mismatch tipo `""` vs valore canonico e la fingerprint non diverge tra record gia' salvati e righe appena parsate.

   **Source canonica PriceHistory**: il valore di default (e ogni altra costante `source` usata nel percorso full-database) deve risiedere in **una singola costante o piccolo helper condiviso** (stesso simbolo riusato da: parsing/assemblaggio entry PriceHistory, scrittura `ProductPrice` in apply, e `makePriceHistoryFingerprint`). Vietato spargere stringhe letterali duplicate per lo stesso significato — cosi' eventuali rinominazioni future non creano divergenza fingerprint vs DB.

   **Vincolo di efficienza**: la dedup DEVE essere O(n) in-memory:
   - Un solo fetch iniziale di tutti i `ProductPrice` esistenti (nessun FetchDescriptor per riga)
   - Costruzione di un `Set<PriceHistoryFingerprint>` in un singolo pass sugli esistenti (**seed iniziale** = tutte le fingerprint dei record gia' nel DB)
   - Classificazione delle entry parsate in un singolo pass con lookup O(1) nel set
   - **Dedup intra-file (stesso import)**: il set non copre solo i duplicati rispetto al DB, ma anche duplicati **dentro lo stesso foglio PriceHistory** importato. Regola operativa: durante la classificazione, quando una entry va in `toInsert`, aggiungere **subito** la sua fingerprint al `Set`; se una seconda entry identica compare piu' avanti nello stesso batch, deve finire nel bucket `alreadyPresent` (duplicato-in-batch) e **non** essere inserita due volte.
   - Un unico helper `makePriceHistoryFingerprint(barcode:type:effectiveAt:price:source:) -> PriceHistoryFingerprint` riusato sia per costruire le fingerprint dai record DB sia per le entry parsate, garantendo che la normalizzazione (date, prezzo, **source**) sia identica

2. **In `prepareFullDatabaseImport`, dopo aver parsato le PriceHistory entries** (preferibilmente delegando al **helper di classificazione** sopra):

   > **Nota implementativa**: oggi `parsePendingPriceHistoryContext` (DatabaseView.swift:889) restituisce direttamente `PendingFullImportContext`. Dopo le modifiche, la classificazione/dedup richiede l'analisi prodotti (per l'universo barcode INV-6). Quindi il flusso deve essere spezzato: (a) prima parsare le raw entries (la parte di lettura Excel puo' restare in `parsePendingPriceHistoryContext` o equivalente), (b) poi classificare/dedup in un passo separato che riceve sia le raw entries sia `analysis.newProducts`/`analysis.updatedProducts`. Non tentare di fare tutto dentro `parsePendingPriceHistoryContext`.
   - Fetch tutti i `ProductPrice` esistenti dal `backgroundContext`
   - Costruire un helper riusabile `makePriceHistoryFingerprint(barcode:type:effectiveAt:price:source:) -> PriceHistoryFingerprint` — usato sia per i record DB sia per le entry parsate
   - Per ciascun `ProductPrice` esistente, costruire la fingerprint via helper accedendo a `product?.barcode`
   - Costruire un `Set<PriceHistoryFingerprint>` degli esistenti
   - **Universo barcode risolvibili** = unione di:
     - barcode dei prodotti gia' nel DB (`existingProducts`)
     - barcode dei `newProducts` dall'analisi prodotti
     - barcode degli `updatedProducts` dall'analisi prodotti
     Questo e' necessario perche' sul primo import (DB vuoto) i prodotti non esistono ancora nel DB ma verranno creati dallo stesso import; classificare le loro PriceHistory come **`unresolved`** sarebbe scorretto.
   - Partizionare le entry parsate in 3 bucket (ordine di scansione del foglio: aggiornare il set come sopra per catturare i duplicati intra-file):
     - `toInsert`: barcode risolvibile E fingerprint NON nel set → poi inserire la fingerprint nel set
     - `alreadyPresent`: barcode risolvibile E fingerprint gia' nel set (**match DB** o **duplicato intra-file** nella stessa scansione)
     - `unresolved`: barcode NON nell'universo risolvibile
   - Salvare solo `toInsert` in `PendingFullImportContext.priceHistoryEntries`
   - Salvare `alreadyPresentCount` e `unresolvedCount` in nuovi campi di `PendingFullImportContext`

3. **In `applyPendingPriceHistoryImport`:**
   - Le entry ricevute sono gia' filtrate (solo nuove). Inserirle come prima.
   - Il log finale usa i conteggi dal payload: `inserted`, `alreadyPresent`, `unresolved` (stessi nomi in struct/CA/TM).

#### B. Non-product diff visibility

1. **Definire `NonProductDeltaSummary`** (in `ImportAnalysisView.swift`, accanto alle struct esistenti):
   ```
   suppliersToAdd: Int
   categoriesToAdd: Int
   priceHistoryToInsert: Int
   priceHistoryAlreadyPresent: Int
   priceHistoryUnresolved: Int   // allineato al termine tecnico `unresolved` (CA/TM/log); etichetta UI puo' restare in italiano es. "non risolvibili"
   ```
   **Conteggio supplier/category** — `suppliersToAdd` e `categoriesToAdd` rappresentano l'unione deduplicata di:
   - nomi letti dai fogli dedicati Suppliers/Categories
   - nomi referenziati dai ProductDraft nuovi (campo `supplierName`/`categoryName`)
   - nomi referenziati dai ProductUpdateDraft dove supplier/category sono tra i `changedFields`
   filtrati contro i nomi gia' esistenti nel DB. In questo modo il summary riflette il delta reale di entita' che verranno create in apply (inclusi quelli creati implicitamente da `resolveSupplier`/`resolveCategory` durante l'apply prodotti).

   > **Nota nomenclatura apply**: nel path full-import, `applyImportAnalysis` (statica su `DatabaseImportPipeline`) usa closures locali **`resolveSupplier(named:)`** e **`resolveCategory(named:)`** (DatabaseView.swift:735-763) per il find-or-create. Le instance methods `findOrCreateSupplier`/`findOrCreateCategory` (DatabaseView.swift:2440-2466) servono solo al path CSV (`parseProductsCSV`) e **non sono coinvolte** nel full-import. In tutto il planning, i riferimenti a find-or-create nel contesto apply full-import si riferiscono a `resolveSupplier`/`resolveCategory`.

   **Normalizzazione unica supplier/category** — dedup, unione e payload devono usare **un solo helper condiviso** (due overload o enum leggero supplier vs category se serve, ma una sola implementazione di regole), riusato in tutti questi punti:
   - nomi letti dai fogli dedicati Suppliers/Categories
   - nomi estratti da `ProductDraft` / `ProductUpdateDraft` (supplier/category)
   - popolamento di `pendingSupplierNames` / `pendingCategoryNames` (stesse stringhe che partono in apply)
   - `resolveSupplier` / `resolveCategory` (closures in `applyImportAnalysis`) e ogni lookup "esiste gia' nel DB?" in prepare/apply

   **Regola minima** (allineata alla semantica **reale** del codice di apply dopo le modifiche; se oggi apply usa regole diverse, il helper deve **diventare** la singola fonte di verita'):
   - `trim` di whitespace e newline
   - stringa vuota dopo trim → trattata come assente (`nil` / esclusa dall'unione e dai pending, non conteggiata come nome valido)
   - stessa stringa normalizzata per confronto con il DB e per creazione, cosi' summary UI, payload e `suppliersCreated`/`categoriesCreated` non divergono per spazi o righe vuote fantasma.

2. **Aggiungere `nonProductSummary: NonProductDeltaSummary?`** a `ImportAnalysisSession` e come init parameter.

3. **In `prepareFullDatabaseImport`:**
   - Per Suppliers/Categories: preferibilmente delegare al **helper pending+summary**; in ogni caso applicare sempre l'helper di normalizzazione unico.
   - Per Suppliers: leggere i nomi dal foglio Excel, normalizzare, confrontare con gli esistenti nel DB (confronto sulle stesse chiavi normalizzate), contare quelli nuovi. NON inserire nel DB (rimuovere la chiamata a `importSupplierNames`). Salvare i nomi pending **gia' normalizzati**.
   - Per Categories: analogo.
   - Per PriceHistory: i conteggi vengono dalla dedup (punto A).
   - Costruire `NonProductDeltaSummary` e aggiungerlo a `PreparedImportAnalysis`.

4. **In `DatabaseView`, passaggio alla UI:**
   - Dopo `prepareFullDatabaseImport`, costruire `ImportAnalysisSession` con il `nonProductSummary`.

5. **In `ImportAnalysisView.summarySection`:**
   - Se `nonProductSummary` non e' nil, aggiungere righe sotto le 4 esistenti:
     - Fornitori da aggiungere (solo se > 0)
     - Categorie da aggiungere (solo se > 0)
     - Storico prezzi da inserire (**sempre visibile**, anche se 0)
     - Storico prezzi gia' presenti (**sempre visibile**, anche se 0)
     - Storico prezzi non risolvibili (**sempre visibile**, anche se 0)
   Le 3 righe PriceHistory vanno mostrate sempre nel full import perche' il caso reimport invariato (tutto a 0/N/0) e' esattamente lo scenario che deve diventare trasparente. Supplier e category restano condizionali (solo se > 0) perche' hanno meno impatto.

6. **Semantica unica `hasWorkToApply` (work reale da applicare):**
   - Definire **una sola** espressione booleana usata in due punti: abilitazione/disabilitazione del bottone Apply **e** guardia di validita' di `makeImportApplyPayload()` (stessa semantica, niente derive parziali).
   - `hasWorkToApply` e' true se e solo se almeno uno tra:
     - `newProducts` non vuoto
     - `updatedProducts` non vuoto
     - `pendingPriceHistoryEntries` non vuoto (lista effettiva da applicare dopo dedup prepare)
     - `pendingSupplierNames` non vuoto
     - `pendingCategoryNames` non vuoto
   - **Motivazione**: `allowsApplyWithoutChanges` da solo e' troppo grezzo per il full import: sul reimport invariato rischia di lasciare Apply attivo senza lavoro reale (no-op o errore generico). Il full-import path deve basarsi su `hasWorkToApply` (eventualmente in combinazione con `allowsApplyWithoutChanges` solo dove serve distinguere full vs simple import, ma la logica "c'e' qualcosa da fare?" resta quella sopra).
   - `NonProductDeltaSummary.hasWork` (se presente) deve restare allineato ai conteggi UI, ma il bottone e il payload devono dipendere dai **payload effettivi** elencati sopra, non da euristiche duplicate.

#### C. Coerenza analysis/apply — defer Suppliers/Categories

1. **Rimuovere le chiamate a `importSupplierNames` e `importCategoryNames` da `prepareFullDatabaseImport`** (DatabaseView.swift:295, 308).

2. **Aggiungere a `PendingFullImportContext`:**
   ```
   pendingSupplierNames: [String]   // nomi da creare in apply
   pendingCategoryNames: [String]   // nomi da creare in apply
   ```

3. **In `prepareFullDatabaseImport`:**
   - Leggere i nomi dal foglio Excel (la funzione `readNamedEntitiesSheet` resta invariata).
   - Confrontare con gli esistenti nel DB (solo lettura, niente insert/save).
   - I nomi nuovi vanno in `pendingSupplierNames` / `pendingCategoryNames`.

4. **In `applyImportAnalysisInBackground` (o in una nuova sotto-funzione chiamata prima di apply products):**
   - Creare i supplier/category pending usando la stessa logica di `importSupplierNames`/`importCategoryNames` ma nel context dell'apply, passando sempre attraverso l'**helper di normalizzazione unico** (stesse stringhe del prepare).
   - Le closures **`resolveSupplier(named:)`/`resolveCategory(named:)`** in `applyImportAnalysis` (DatabaseView.swift:735-763) gia' fanno find-or-create per i prodotti; devono usare la **stessa** normalizzazione dell'helper unico. I pending coprono quelli presenti SOLO nel foglio Suppliers/Categories senza un prodotto corrispondente.

5. **Nota su `backgroundContext.save()` in prepare:**
   - Oggi viene chiamato da `importSupplierNames`/`importCategoryNames`. Dopo la rimozione, il `backgroundContext` in prepare non ha piu' bisogno di save per supplier/category. Il save avviene solo in apply.

6. **Estensione del flow apply per supportare il caso supplier/category-only:**
   - **`ImportApplyPayload`**: aggiungere `pendingSupplierNames: [String]` e `pendingCategoryNames: [String]`.
   - **`makeImportApplyPayload()`**: popolare i nuovi campi da `pendingFullImportContext`. La **guardia di validita'** deve coincidere con **`!hasWorkToApply`** (stessa definizione della sezione B.6): rifiutare il payload se non c'e' alcun lavoro reale; includere esplicitamente supplier/category pending oltre a prodotti e price history.
   - **`ImportApplyResult`**: aggiungere `suppliersCreated: Int` e `categoriesCreated: Int`.
   - **Conteggi finali supplier/category = creazioni reali uniche nel DB**: `suppliersCreated` e `categoriesCreated` nel risultato finale devono riflettere le entita' **effettivamente create** in quel apply, senza doppio conteggio e senza sottoconteggio. Devono sommare (in modo deduplicato a livello di conteggio, non di doppia insert):
     - creazioni dal pass esplicito su `pendingSupplierNames` / `pendingCategoryNames`
     - **piu'** eventuali creazioni implicite durante `applyImportAnalysis` tramite **`resolveSupplier`/`resolveCategory`** (closures locali, DatabaseView.swift:735-763) sui `ProductDraft` (nomi che non esistevano ancora e che quindi hanno creato una nuova entita' in quell'apply)
   - **Implementazione preferita in execution**: far restituire da **`resolveSupplier`/`resolveCategory`** anche l'informazione **`wasCreated`** (es. tupla `(entity, wasCreated: Bool)` o tipo dedicato minimo), e incrementare `suppliersCreated` / `categoriesCreated` solo quando `wasCreated == true`. Alternativa equivalente: un **accumulatore unico** passato per riferimento alle closures resolve che registrano le creazioni nello stesso posto. Per il pass esplicito sui pending, usare la stessa convenzione (stesso `wasCreated` o stesso accumulatore), cosi' i conteggi restano semplici e affidabili senza euristiche post-hoc. Resta valido un **Set** di ID o nomi gia' conteggiati se serve evitare doppio conteggio quando lo stesso nome e' toccato sia dal pass pending sia dal prodotto — ma la fonte di verita' per "e' stata una create?" deve essere la stessa segnalazione delle closures resolve, non il solo confronto pre/post.
   - **Propagazione conteggi supplier/category nel risultato**: `applyImportAnalysis` oggi restituisce `ImportApplyProductsResult` (DatabaseView.swift:62-65), che contiene solo `productsInserted`/`productsUpdated`. Va estesa con `suppliersCreated: Int` e `categoriesCreated: Int`. In `applyImportAnalysisInBackground`, sommare i conteggi dal pass esplicito pending + quelli da `ImportApplyProductsResult` → popolare `ImportApplyResult.suppliersCreated`/`.categoriesCreated`.
   - **`userMessage(for:)`**: includere i conteggi supplier/category nel messaggio finale se > 0.

#### D. Logging / osservabilita'

1. **Aggiungere `alreadyPresentCount` e `unresolvedCount`** (o nomi equivalenti ma coerenti) a `ImportApplyPriceHistoryResult` (e propagarli fino a `ImportApplyResult`).

2. **Nel log `apply_price_history`** (DatabaseView.swift:410-418), aggiungere i campi `alreadyPresent=N` e `unresolved=M` (vocabolario unificato; niente `skipped` come alias tecnico).

3. **Nel log `apply_result`** (DatabaseView.swift:702-713), aggiungere `priceHistoryAlreadyPresent=N` e `priceHistoryUnresolved=M` (stessa semantica delle struct).

4. **Tag log** (opzionale, non bloccante): cambiare `[TASK-011]` → `[DB-IMPORT]` per chiarezza (il tag `TASK-011` e' un residuo storico). Se il cambio introduce rischio o complessita' non necessaria, puo' essere omesso senza impattare i CA.

### Invarianti dati / regole di idempotenza

- **INV-1**: Un record `ProductPrice` con la stessa fingerprint `(barcode, type, effectiveAtEpochSeconds, priceFixed4, source normalizzato)` non deve essere inserito due volte dallo stesso import, **ne' due volte nella stessa scansione del foglio** (dedup intra-file), ne' da reimport successivi rispetto al DB.
- **INV-2**: Il primo import di un file full-database produce lo stesso risultato di prima (nessuna regressione).
- **INV-3**: Un reimport invariato produce 0 insert per PriceHistory (tutto `alreadyPresent`).
- **INV-4**: Nessuna entita' Supplier/Category viene salvata nel DB fino alla conferma dell'utente (fase apply).
- **INV-5**: I conteggi mostrati nell'analysis UI corrispondono a quanto verra' effettivamente applicato.
- **INV-8**: Nel percorso full-database import, `hasWorkToApply` (definito in B.6) e' la **stessa** condizione usata per abilitare il bottone Apply e per la guardia di `makeImportApplyPayload()`; reimport invariato con tutti i bucket vuoti → Apply disabilitato e payload non costruibile (nessun finto "apply" senza lavoro).
- **INV-9**: `suppliersCreated` / `categoriesCreated` nel risultato apply riflettono creazioni DB reali e uniche (pending + implicite da prodotti), senza doppio conteggio.
- **INV-6**: L'universo barcode per classificare PriceHistory come risolvibile/non risolvibile include i prodotti che verranno creati dallo stesso import (newProducts + updatedProducts), non solo quelli gia' nel DB.
- **INV-7**: I conteggi `suppliersToAdd`/`categoriesToAdd` riflettono l'unione deduplicata di nomi da fogli dedicati + nomi referenziati dai ProductDraft, filtrati contro gli esistenti nel DB, tutti passati dallo **stesso helper di normalizzazione** usato in apply (`resolveSupplier`/`resolveCategory` e pending).
- **INV-10**: Il campo prezzo nella fingerprint si chiama in modo coerente con la scala (es. `priceFixed4` per `round(price * 10000)`), mai `priceCents` con fattore 10_000.

### File coinvolti

| File | Tipo modifica | Dettaglio |
|------|---------------|-----------|
| `iOSMerchandiseControl/DatabaseView.swift` | Modifica sostanziale | Fingerprint struct (`priceFixed4`), helper classificazione PH + helper pending/summary, helper normalizzazione nomi supplier/category, dedup in prepare, defer supplier/category, propagazione conteggi, logging |
| `iOSMerchandiseControl/ImportAnalysisView.swift` | Modifica moderata | `NonProductDeltaSummary` struct, estensione `ImportAnalysisSession`, righe summary aggiuntive, condizione Apply |
| `iOSMerchandiseControl/Models.swift` | Nessuna modifica | Il modello `ProductPrice` resta invariato (nessuna migration) |
| `iOSMerchandiseControl/ProductImportViewModel.swift` | Nessuna modifica | Il simple product import non e' toccato |
| `iOSMerchandiseControl/ExcelSessionViewModel.swift` | Nessuna modifica | Il parser Excel non cambia |

### Criteri di accettazione raffinati

- **CA-1**: Reimportando lo stesso full database senza delta reali, `hasWorkToApply` e' false (Apply disabilitato) e **nessun** nuovo `ProductPrice` entra nel DB. Se in uno scenario controllato l'apply PH venisse comunque eseguito (solo entry gia' note), il log riporta `inserted=0 alreadyPresent=...` e nessun reinserimento massivo.
- **CA-2**: Il primo import reale del full database produce lo stesso numero di record `ProductPrice` di prima (nessuna regressione).
- **CA-3**: I log distinguono chiaramente tra `inserted`, `alreadyPresent`, e `unresolved` durante l'apply di PriceHistory (nessun terzo termine tecnico equivalente tipo `skipped`).
- **CA-4**: La schermata di analisi per il full import mostra almeno: fornitori da aggiungere, categorie da aggiungere, e le **tre** righe PriceHistory **sempre visibili** (anche se 0): storico prezzi **da inserire**, storico prezzi **gia' presenti**, storico prezzi **non risolvibili** (`unresolved`), in linea con la specifica UI in sezione B.5.
- **CA-5**: Suppliers e Categories non vengono salvati nel DB durante la fase di analisi (solo in apply, dopo conferma utente).
- **CA-6**: Se l'utente annulla l'import dopo l'analisi, nessuna entita' viene creata nel DB.
- **CA-7**: Nessuna migration SwiftData richiesta.
- **CA-8**: Due o piu' righe PriceHistory **identiche** nello stesso file (stessa fingerprint dopo normalizzazione, incluso `priceFixed4` e `source`) producono al massimo **un** insert per quella fingerprint; le successive risultano classificate come gia' presenti (in-batch) e non aumentano il numero di `ProductPrice` creati.
- **CA-9**: Stesso nome fornitore/categoria con solo spazi o righe vuote attorno non crea doppioni tra summary, pending e DB rispetto a un nome gia' normalizzato (helper unico).

### Test manuali

| ID | Scenario | Esito atteso |
|----|----------|-------------|
| TM-1 | Primo import full database su DB vuoto | Tutti i prodotti, supplier, category, price history vengono creati. PriceHistory le cui barcode corrispondono a prodotti nel file risultano risolvibili (non classificate come unresolved). Log: `inserted=N alreadyPresent=0 unresolved=M` dove M riguarda solo barcode assenti sia nel DB sia nel file. |
| TM-2 | Reimport immediato dello stesso file | 0 nuovi/0 aggiornati; summary PH da inserire=0, gia' presenti=N (tutte le righe classificate come gia' presenti / in-batch). Nessun altro pending: **Apply disabilitato** (`hasWorkToApply` false). Nessun apply obbligatorio per completare un no-op. |
| TM-3 | Import full database con qualche PriceHistory nuovo (file modificato) | I nuovi vengono inseriti, i vecchi riconosciuti come gia' presenti. Summary e log coerenti. |
| TM-4 | Import full database e annullamento alla schermata di analisi | Nessun Supplier/Category/Product/PriceHistory creato nel DB. |
| TM-5 | Import prodotti semplice (non full) | Comportamento invariato, nessuna sezione non-product nel summary. |
| TM-6 | Full import con foglio Suppliers contenente nomi nuovi | Il summary mostra "N fornitori da aggiungere". Dopo apply, i fornitori esistono nel DB. |
| TM-7 | Full import con soli delta supplier/category (prodotti e PH invariati) | Il bottone Apply e' abilitato. Dopo apply, i nuovi supplier/category esistono nel DB. Il messaggio finale li menziona. |
| TM-8 | Stesso file con due righe PriceHistory duplicate (stesso barcode/tipo/data/prezzo/source) | Un solo insert; summary/log coerenti con dedup intra-file; nessun doppio record in DB. |

### Rischi / non incluso

- **Performance fetch all ProductPrice**: su DB molto grandi (>100k price history records), il fetch di tutti i ProductPrice per costruire il set di fingerprint potrebbe usare memoria significativa. Per i volumi attuali (35k) e' ampiamente gestibile. Se in futuro servisse, si puo' partizionare per barcode. Fuori scope ora.
- **Collisione fingerprint teorica**: due record con stessa fingerprint ma `note` o `createdAt` diversi verrebbero considerati duplicati. Questo e' voluto: la fingerprint copre i campi semanticamente significativi per il reimport. Il campo `note` e' sempre nil per import e `createdAt` e' generato a runtime.
- **Progress UX / cancellation**: resta in TASK-024, esplicitamente fuori scope.
- **Dedup retroattiva**: se il DB contiene gia' duplicati da import precedenti, questo task NON li pulisce. La dedup agisce solo sul reimport futuro.
- **Tag log `[TASK-011]`**: il cambio a `[DB-IMPORT]` e' opzionale e non bloccante. Se introduce rischio o complessita' non necessaria, puo' essere omesso.

---

## Handoff a Codex per execution

- **Fase corrente**: PLANNING (completato)
- **Prossima fase prevista**: EXECUTION
- **Prossimo agente**: CODEX
- **Responsabile attuale**: da cambiare a CODEX all'avvio dell'execution

### Ordine di implementazione consigliato

1. **Struct e tipi** (fondamenta):
   - Aggiungere `PriceHistoryFingerprint` (Hashable) con campo **`priceFixed4`** (Int64 = `round(price * 10000)`) e helper `makePriceHistoryFingerprint(...)` in DatabaseView.swift (normalizzazione `source`: trim, nil/vuoto → **costante canonica condivisa** con parser/apply, vedi A.1)
   - Aggiungere helper **normalizzazione nomi** supplier/category (un punto solo, usato da prepare, pending, apply, `resolveSupplier`/`resolveCategory`)
   - Aggiungere `NonProductDeltaSummary` in ImportAnalysisView.swift
   - Estendere `PendingFullImportContext` con `pendingSupplierNames`, `pendingCategoryNames`, `alreadyPresentPriceHistoryCount`, `unresolvedPriceHistoryCount`
   - Estendere `ImportApplyPayload` con `pendingSupplierNames`, `pendingCategoryNames`
   - Estendere `ImportApplyPriceHistoryResult` e `ImportApplyResult` con `alreadyPresentCount` e conteggio **`unresolved`** (stessi nomi ovunque)
   - Estendere `ImportApplyProductsResult` con `suppliersCreated`, `categoriesCreated` (propagati poi a `ImportApplyResult` in `applyImportAnalysisInBackground`)
   - Estendere `ImportApplyResult` con `suppliersCreated`, `categoriesCreated`
   - Estendere `ImportAnalysisSession` con `nonProductSummary: NonProductDeltaSummary?`
   - Estendere `PreparedImportAnalysis` con `nonProductSummary: NonProductDeltaSummary?`

2. **Dedup PriceHistory in prepare** (core fix):
   - Implementare la logica in **helper privato di classificazione** (vedi "Struttura codice prepare"); `prepareFullDatabaseImport` orchestra solo le chiamate.
   - Dopo aver parsato le price history entries E dopo l'analisi prodotti:
     - `makePriceHistoryFingerprint` con **`priceFixed4`**, normalizzazione `source` (sezione A.1)
     - Fetch tutti i `ProductPrice` dal backgroundContext
     - `Set` seed dagli esistenti; universo barcode = esistenti ∪ new ∪ updated
     - Partizione `toInsert` / `alreadyPresent` / `unresolved` con dedup intra-file
     - Popolare `PendingFullImportContext` con solo `toInsert` e conteggi

3. **Defer Suppliers/Categories** (coerenza):
   - Implementare lettura/unione/confronto in **helper privato pending+summary**; normalizzare ogni nome con l'helper condiviso prima di dedup e confronto DB.
   - In `prepareFullDatabaseImport`:
     - Leggere i nomi dal foglio (invariato a livello Excel), poi normalizzare
     - Confrontare con DB (solo lettura): fetch existing, confronto su chiavi normalizzate, computare delta
     - Rimuovere `importSupplierNames(...)` e `importCategoryNames(...)` (e le relative `context.save()`)
     - Salvare nomi pending in `PendingFullImportContext` (gia' normalizzati)
     - Computare conteggi `suppliersToAdd`/`categoriesToAdd` come unione deduplicata di: fogli + ProductDraft nuovi/aggiornati, filtrati contro gli esistenti
   - In `applyImportAnalysisInBackground`:
     - Prima di applicare i prodotti, creare i supplier/category pending (logica identica alle funzioni rimosse, ma nel context di apply)
   - Estendere `makeImportApplyPayload()`: popolare i nuovi campi da `pendingFullImportContext`; **guardia = `hasWorkToApply`** (stessa booleana della UI, sezione B.6)
   - Implementare `suppliersCreated` / `categoriesCreated` tramite **`wasCreated`** (o accumulatore unico) da `resolveSupplier`/`resolveCategory` e dal pass pending, vedi C.6
   - Estendere `ImportApplyProductsResult` con `suppliersCreated`/`categoriesCreated` e propagarli a `ImportApplyResult` in `applyImportAnalysisInBackground`
   - Estendere `userMessage(for:)`: includere conteggi supplier/category nel messaggio finale se > 0

4. **UI non-product summary + Apply**:
   - In `DatabaseView`, dove si crea `ImportAnalysisSession`: passare anche `nonProductSummary` costruito dai dati del `PreparedImportAnalysis`
   - In `ImportAnalysisView.summarySection`: aggiungere righe per i delta non-product (supplier/category condizionali se > 0; le 3 righe PriceHistory sempre visibili nel full import)
   - Abilitazione bottone Apply: usare **`hasWorkToApply`** (B.6) in coerenza con `makeImportApplyPayload()`; non basarsi solo su `allowsApplyWithoutChanges` o su un `hasWork` UI scollegato dai payload

5. **Logging**:
   - Propagare `alreadyPresentCount` e conteggio **`unresolved`** nei result e nei log
   - Log `apply_price_history` e `apply_result`: campi `alreadyPresent` e `unresolved` (vocabolario unificato)
   - (Opzionale) Cambiare tag `[TASK-011]` → `[DB-IMPORT]` — non bloccante

6. **Pulizia e build**:
   - Rimuovere/rinominare campi PriceHistory **legacy** sovrapposti ai nuovi (`alreadyPresent` / `unresolved`), cosi' result, log e messaggi non hanno doppia semantica
   - Verificare che il build compili senza errori
   - Verificare che il simple product import (non full) non sia impattato

### File da toccare

- `iOSMerchandiseControl/DatabaseView.swift` — bulk delle modifiche
- `iOSMerchandiseControl/ImportAnalysisView.swift` — NonProductDeltaSummary, estensione session e summary UI

### Invarianti da non rompere

- Il simple product import (via Excel/CSV singolo foglio) deve funzionare esattamente come prima
- Il full database export non cambia
- Il modello SwiftData (`ProductPrice`, `Product`, `Supplier`, `ProductCategory`) non cambia — zero migration
- Il primo import su DB vuoto deve produrre gli stessi record di prima (INV-6: universo barcode include newProducts)
- Dove oggi `allowsApplyWithoutChanges` serve a non esigere delta **prodotti** nel full import, quel comportamento si mantiene; l'**abilitazione effettiva** di Apply e la validita' del payload usano **`hasWorkToApply`** (B.6), cosi' il reimport senza alcun lavoro non resta cliccabile
- Un full import con soli delta supplier/category (zero product e zero priceHistory) deve essere applicabile senza errori (`hasWorkToApply` true)
- La dedup fingerprint deve usare lo stesso helper (`makePriceHistoryFingerprint`) per record DB e entry parsate (INV-1, efficienza O(n)); campo prezzo = **`priceFixed4`**, non nome fuorviante (INV-10)
- Normalizzazione supplier/category: un solo helper end-to-end (INV-7, CA-9); nel path apply, le closures coinvolte sono `resolveSupplier`/`resolveCategory` (non le instance methods `findOrCreate*` che servono solo al CSV)
- `ImportApplyProductsResult` deve propagare `suppliersCreated`/`categoriesCreated` fino a `ImportApplyResult`
- PriceHistory: solo `alreadyPresent` / `unresolved` come termini tecnici in struct, log, CA, TM (vedi convenzione in Soluzione minima); nessun campo legacy parallelo (`skippedCount`, ecc.) nello stesso percorso

### Checklist test minima per handoff post-execution

- [ ] Build compila senza errori
- [ ] TM-1: primo import full database → tutto creato, PH risolvibili grazie a universo post-import
- [ ] TM-2: reimport invariato → Apply disabilitato (`hasWorkToApply` false), nessun insert PH
- [ ] TM-4: annullamento analisi → nessuna entita' creata nel DB
- [ ] TM-5: import prodotti semplice → comportamento invariato
- [ ] Summary UI mostra sempre le 3 righe PriceHistory nel full import (anche se 0): inserire, gia' presenti, non risolvibili (CA-4)
- [ ] Nessun campo PH legacy in parallelo a `alreadyPresent`/`unresolved` in result/log/messaggi
- [ ] Supplier/category conteggi = unione deduplicata fogli + ProductDraft
- [ ] Helper PH classificazione + helper pending/summary estratti da `prepareFullDatabaseImport`
- [ ] Nomi supplier/category: un solo helper normalizzazione (prepare + apply + resolveSupplier/resolveCategory)
- [ ] `hasWorkToApply` identico per bottone Apply e guardia `makeImportApplyPayload()` (full import)
- [ ] `suppliersCreated`/`categoriesCreated` = somma da `wasCreated` / accumulatore (pending + resolveSupplier/resolveCategory prodotti), senza doppioni
- [ ] `ImportApplyProductsResult` estesa e conteggi propagati a `ImportApplyResult`
- [ ] Costante (o helper) **source** PriceHistory unica: parser + insert PH + fingerprint
- [ ] TM-8: righe PH duplicate nello stesso file → un solo insert

## Execution

- Riallineato il tracking per l'avvio execution e poi completata l'implementazione del piano in `DatabaseView.swift` e `ImportAnalysisView.swift`, mantenendo perimetro stretto e nessuna migration SwiftData.
- Aggiunti `PriceHistoryFingerprint`, helper unici per fingerprint/source canonica (`IMPORT_DB_FULL`) e normalizzazione supplier/category, con classificazione `PriceHistory` in prepare (`toInsert`, `alreadyPresent`, `unresolved`) e dedup sia contro DB sia intra-file.
- Rimosse le create di supplier/category dalla prepare: ora `PendingFullImportContext` trasporta `pendingSupplierNames` / `pendingCategoryNames`, mentre l'apply usa un unico percorso `resolveSupplier` / `resolveCategory` anche per i pending e conta le create reali uniche.
- Estesi payload/result/session/summary per propagare i conteggi non-product fino alla UI e ai log; `hasWorkToApply` ora e' una sola semantica condivisa tra bottone Apply e `makeImportApplyPayload()`.
- Aggiornati summary UI e messaggio finale per mostrare i delta non-product rilevanti; aggiunte solo le localizzazioni minime necessarie per le nuove righe/suffix.

### Check eseguiti

- ✅ ESEGUITO — Build compila: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build` -> `BUILD SUCCEEDED` (2026-03-23).
- ⚠️ NON ESEGUIBILE — Nessun warning nuovo introdotto: non ho una baseline warning-diff affidabile del repo; il build riuscito non ha evidenziato un confronto automatico "nuovi vs preesistenti".
- ✅ ESEGUITO — Modifiche coerenti con il planning: verify statica del diff su helper fondazioni, dedup `PriceHistory` in prepare, defer supplier/category all'apply, summary UI, payload/log e `hasWorkToApply`.
- ✅ ESEGUITO — Criteri di accettazione verificati staticamente: CA-1, CA-3, CA-4, CA-5, CA-7, CA-8, CA-9 coperti da codice e build; CA/TM che richiedono prova runtime manuale restano da validare in review/manual testing.

### Rischi rimasti

- I test manuali TM-1/TM-2/TM-4/TM-5/TM-7/TM-8 non sono stati eseguiti in Simulator in questa execution; la copertura attuale per questi punti e' statica/logica + build.
- Il rename opzionale del tag log `[TASK-011]` -> `[DB-IMPORT]` e' stato lasciato fuori per evitare rumore extra non richiesto.

## Handoff post-execution

- Stato proposto: `ACTIVE / REVIEW`
- Responsabile proposto: `CLAUDE`
- Implementazione pronta per review: build verde, tracking riallineato, nessun refactor largo introdotto.
- Evidenze principali per review:
  - Reimport invariato: `PreparedImportAnalysis` + `classifyParsedPriceHistoryForFullImport(...)` filtrano `PriceHistory` in prepare, quindi il payload applica solo `toInsert`; `alreadyPresent` e `unresolved` restano visibili in UI/log.
  - Duplicati intra-file: la fingerprint entra subito nel `Set` dopo ogni `toInsert`, quindi una seconda riga identica nello stesso foglio viene classificata `alreadyPresent`.
  - Annullamento dopo analisi: prepare non salva piu' supplier/category e non crea prodotti/price history; se l'utente chiude la sheet, `pendingFullImportContext` viene solo scartato.
  - Full import con soli delta supplier/category: `pendingSupplierNames` / `pendingCategoryNames` alimentano `hasWorkToApply` e vengono creati in apply anche con `newProducts == updatedProducts == priceHistoryEntries == []`.
  - Simple product import: sessione e `GeneratedView` passano `hasWorkToApply` basato sui soli cambi prodotto; nessuna sezione non-product viene popolata fuori dal full import.
- Richiesta review: verificare in particolare coerenza dei conteggi tra `NonProductDeltaSummary`, payload effettivo, `ImportApplyResult` e messaggio finale, piu' il comportamento atteso dei casi TM-2 e TM-7.

## Review

### Esito: APPROVED

**Data review**: 2026-03-23
**Reviewer**: CLAUDE

### Verifiche superate

- **PriceHistory fingerprint e dedup in prepare**: `PriceHistoryFingerprint` con `priceFixed4` (Int64, `round(price * 10000)`) e `effectiveAtEpochSeconds` (floor). Helper unico `makePriceHistoryFingerprint`. Dedup O(n) con singolo fetch + singolo pass. Dedup intra-file con inserimento fingerprint nel set dopo ogni `toInsert`.
- **Bucket coerenti**: `toInsert` / `alreadyPresent` / `unresolved` in `classifyParsedPriceHistoryForFullImport`. Nessun campo legacy (`skippedCount`, `priceHistoryTotal`, `totalResolvableCount`) nelle struct/log/messaggi.
- **Universo barcode risolvibili**: `existingProducts ∪ newProducts ∪ updatedProducts` (INV-6).
- **Supplier/Category defer**: `importSupplierNames`/`importCategoryNames` rimossi da prepare. Nessun `context.save()` per supplier/category in prepare. Creazione solo in apply tramite `resolveSupplier`/`resolveCategory` (INV-4).
- **Normalizzazione unica**: `normalizedImportNamedEntityName` usato in tutti i path: prepare, pending, apply, `resolveSupplier`/`resolveCategory`, `EditProductDraftView.trimmedOrNil`, `readNamedEntitiesSheet` (INV-7, CA-9).
- **Source canonica PriceHistory**: costante `fullDatabasePriceHistorySource` usata via `normalizedFullDatabasePriceHistorySource` in parsing, fingerprint, e apply insert.
- **`hasWorkToApply` unico**: stessa funzione statica per bottone Apply e guardia `makeImportApplyPayload()` (INV-8).
- **`suppliersCreated`/`categoriesCreated`**: via Set `createdSupplierNames`/`createdCategoryNames` da `resolveSupplier`/`resolveCategory` (pending + impliciti da draft). Propagazione `ImportApplyProductsResult` → `ImportApplyResult` (INV-9).
- **Summary riallineato dopo edit inline**: `refreshNonProductSummary()` chiamato dopo salvataggio draft.
- **NonProductDeltaSummary coerente con apply**: conteggi PH dal classify; conteggi S/C dall'unione fogli+draft filtrata vs DB.
- **Simple product import non contaminato**: sessione senza `nonProductSummary`, `hasWorkToApply` basato su `session.hasChanges`, nessuna sezione non-product nella UI.
- **Logging strutturato**: `apply_price_history` e `apply_result` con vocabolario unificato `inserted`/`alreadyPresent`/`unresolved`.
- **Messaggio finale**: supplier/category come suffissi se > 0. `priceHistoryUnresolved` come suffisso se > 0. Condizione `success_with_price_history` su `priceHistoryInserted > 0`.
- **Localizzazione**: 5 nuove chiavi summary + 3 nuove chiavi suffisso in 4 lingue.
- **Nessuna migration SwiftData** (CA-7).

### Problemi trovati

Nessun problema critico o medio.

### Criteri di accettazione

| CA | Esito | Note |
|----|-------|------|
| CA-1 | PASS (statico) | Reimport invariato → `toInsert=[]`, pending vuoti → `hasWorkToApply=false`. MANUAL: TM-2 |
| CA-2 | PASS (statico) | Universo barcode include newProducts (INV-6). MANUAL: TM-1 |
| CA-3 | PASS | Log con `inserted`/`alreadyPresent`/`unresolved`, nessun `skipped` |
| CA-4 | PASS | Supplier/category condizionali (> 0); 3 righe PH incondizionali |
| CA-5 | PASS | `importSupplierNames`/`importCategoryNames` rimossi da prepare |
| CA-6 | PASS (statico) | Prepare non salva nulla. MANUAL: TM-4 |
| CA-7 | PASS | Nessuna modifica ai modelli SwiftData |
| CA-8 | PASS (statico) | `knownFingerprints.insert` dopo `toInsert.append`. MANUAL: TM-8 |
| CA-9 | PASS | Helper unico `normalizedImportNamedEntityName` in tutti i path |

### Rischio residuo

Basso. Logica coerente end-to-end. Unico edge case: product cancellato tra prepare e apply, coperto da safety net in `applyPendingPriceHistoryImport`. Test manuali TM-1/TM-2/TM-4/TM-5/TM-7/TM-8 necessari per validazione runtime.

### Decisione tracking

~~Task resta in ACTIVE / REVIEW in attesa di conferma utente + test manuali. Dopo conferma → DONE.~~ **Sostituito da sospensione (2026-03-24):** vedi sezione **Sospensione temporanea**.

## Sospensione temporanea (user override 2026-03-24)

- Il task **non** passa a DONE: sospeso temporaneamente per **decisione esplicita utente**.
- Motivo: test manuali **solo parziali**; la review codice risulta **APPROVED** (2026-03-23) ma la validazione runtime **non e' conclusa**.
- **Non** ripartire da nuovo planning alla ripresa: eseguire i **test manuali residui** (TM-1, TM-2, TM-4, TM-5, TM-7, TM-8 e altri dalla checklist nel file), eventuale **FIX** se emergono regressioni, poi **review finale breve** e conferma utente → DONE.
- Progress UX / cancellation del full import resta in **TASK-024** (separato).

## Handoff post-review

- **Stato attuale**: BLOCKED — handoff sospeso fino a ripresa utente.
- ~~**Prossima fase**: conferma utente + test manuali~~ → **Alla ripresa: test manuali residui + conferma DONE o FIX.**
- **Prossimo agente**: UTENTE
- **Azione consigliata**: eseguire TM-1, TM-2, TM-4, TM-5, TM-7, TM-8 nel Simulator. Se tutti passano → confermare DONE. Se emergono regressioni → aprire FIX.
