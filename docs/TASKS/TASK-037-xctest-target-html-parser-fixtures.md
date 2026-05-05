# TASK-037: XCTest target for ExcelAnalyzer HTML parser fixtures

## Informazioni generali
- **Task ID**: TASK-037
- **Titolo**: XCTest target for ExcelAnalyzer HTML parser fixtures
- **File task**: `docs/TASKS/TASK-037-xctest-target-html-parser-fixtures.md`
- **Stato**: DONE
- **Fase attuale**: Chiusura
- **Responsabile attuale**: —
- **Data creazione**: 2026-04-27
- **Ultimo aggiornamento**: 2026-05-04
- **Ultimo agente che ha operato**: Codex reviewer/fixer slice 2 (user override)

## Nota tracking
- **User override 2026-04-27** (slice 1): dopo la chiusura DONE di TASK-036, richiesta di creare un test target XCTest minimale coerente col perimetro. TASK-031 e TASK-036 restano DONE e non vengono riaperti.
- **User override 2026-05-04** (slice 2 — solo planning): perfezionare **solo** il planning per una validazione automatica **estesa** del parser HTML avanzato già chiuso in TASK-036. **Nessuna execution Swift**, nessun nuovo test eseguito, nessuna modifica a `project.pbxproj` in questa sessione. TASK-036 resta **DONE** e non va riaperto. La slice 1 (target + 5 test) resta **archiviata** sotto; il workflow slice 2 resta **ACTIVE / PLANNING** fino a approvazione formale utente e **user override** su EXECUTION (vedi sezione **Review planning slice 2** e handoff).
- **User override 2026-05-04** (review/close slice 2): autorizzata review tecnica completa, fix diretti sicuri e chiusura **DONE** se tutto corretto. Review approvata senza fix; TASK-037 slice 2 chiusa **DONE / Chiusura**. TASK-036 resta **DONE** e non viene riaperto.

## Dipendenze
- **Dipende da**: TASK-036 (implementazione parser HTML avanzato — **DONE**, non modificare per questo perimetro di planning)
- **Slice 1 (DONE 2026-04-27)**: target XCTest minimale + 5 fixture/test base (vedi archivio sotto).
- **Slice 2 (DONE 2026-05-04)**: copertura mirata aggiuntiva, fixture da export HTML reali/minimali, append/multi-file, microcopy UX documentata nel planning.

## Scopo (aggiornato — slice 2)
Definire in modo operativo **come** estendere — in una futura execution autorizzata — la validazione automatica del parser HTML in `ExcelAnalyzer`, sfruttando il target XCTest già introdotto in slice 1, **senza** toccare TASK-036 come task di implementazione e **senza** allargare il perimetro a UI complessa, Supabase o refactor dell’analyzer.

## Scope consigliato (slice 2 — futura execution)
- **Target**: riusare `iOSMerchandiseControlTests` (già creato in slice 1); crearne uno nuovo solo se emerge un vincolo tecnico documentato (da decidere in review pre-execution).
- **Fixture**: mantenere `docs/fixtures/TASK-036/` come fonte documentale; duplicare nel bundle test le varianti necessarie (allineamento obbligatorio già praticato in slice 1).
- **Test automatici mirati** (matrice obiettivo, da implementare solo dopo handoff EXECUTION):
  1. **Colspan header raggruppato** — header su più celle unite coerente con colonne canoniche / espansione rettangolare.
  2. **Rowspan data** — celle dati con `rowspan` non corrompono allineamento righe/colonne.
  3. **HTML con più tabelle** — presenza di più `<table>`; la tabella “dati” è selezionata in modo conservativo; tabella decorativa non sostituisce quella dati (coerente con hardening TASK-036 + fixture post/dopo tabella dati in slice 1).
  4. **Righe titolo/decorative prima dell’header** — righe non-dato sopra l’header reale non spostano l’associazione header→colonne.
  5. **Decorative-only negativo** — tabella solo decorativa non genera griglia dati utile / o produce esito documentato come “nessun dato” in linea con scoring conservativo.
  6. **Nested table** — tabella annidata **non inquina** righe/colonne della tabella principale scelta (nessuna fuoriuscita di `tr`/`td` dalla gerarchia errata).
  7. **Append / multi-file** — due (o più) HTML caricati in sequenza con **stesso header normalizzato** producono griglia aggregata coerente (stesso ordinamento colonne, nessuna duplicazione header spuria); vincolo: usare API già esposte dal flusso reale o helper testabile identificato in `ExcelSessionViewModel.swift` / `ExcelAnalyzer` durante execution.
  8. **HTML minimale senza header reale** — comportamento **documentato e testato** tra: etichette `colN` come fallback, percorso di override manuale lato PreGenerate (senza redesign), **oppure** fallimento conservativo con messaggio/empty state coerente; nessuna euristica aggressiva “indovina header dai soli dati”.

## Priorità test futura Execution (slice 2)
Ordine consigliato in **futura EXECUTION** (autorizzata): privilegiare **P0** prima di **P1** e **P2** per ridurre rischio di regressioni strutturali (tabella sbagliata, append errato, assenza header).

### P0 — prima ondata
- **Nested table** — la tabella annidata **non contamina** la tabella principale scelta (coerente con punto 6 della matrice sopra).
- **Append / multi-file** — stesso **header normalizzato** e aggregazione righe/colonne coerente (coerente con punto 7).
- **HTML minimale senza header reale** — esito **documentato e coperto da test** tra: fallback **`colN`**, **override manuale** ove già previsto dal flusso, **oppure** fallimento conservativo; nessuna euristica aggressiva solo-dati (coerente con punto 8).

### P1 — seconda ondata
- **Colspan** su header raggruppato (punto 1).
- **Rowspan** su area dati (punto 2).
- **Multi-table** con decorative **prima e dopo** la tabella dati (punto 3; allineato alla slice 1 e fixture post-dati).
- **Righe titolo/decorative prima dell’header** (punto 4).
- **Decorative-only negativo** (punto 5; non regressione rispetto al caso già coperto in slice 1 salvo estensione documentata).

### P2 — terza ondata / realismo controllato
- Casi **realistici anonimizzati** da export Excel o HTML browser, come **minimal repro** in repo (nessun dato sensibile).
- Opzionale: **smoke** leggero su HTML **più grande** (es. parse completo, row count/header stabili), **senza** benchmark di performance fragili o soglie wall-clock.

## Fixture sync policy (slice 2 — futura execution)
- **`docs/fixtures/TASK-036/`** = **fonte documentale** (review umana, descrizione scenari).
- **`iOSMerchandiseControlTests/Fixtures/TASK-036/`** = **copia per bundle test** (risorse XCTest).
- In **futura EXECUTION**: ogni fixture **nuova** o **modificata** va aggiornata in **entrambe** le directory nello stesso changeset/PR salvo eccezione esplicita (da evitare).

**Checklist futura** (da eseguire in EXECUTION, non ora):
- stessi **nomi file** nelle due cartelle;
- stesso **contenuto** (idealmente identico; evitare CRLF/LF misti senza motivo);
- **`docs/fixtures/TASK-036/README.md`** aggiornato (file nuovi, intento, link alla matrice P0–P2 se utile);
- verifica manuale o, se la struttura locale è omogenea, comando tipo **`diff -r docs/fixtures/TASK-036 iOSMerchandiseControlTests/Fixtures/TASK-036`**.

**Script automatici** di copia/sync: **non** previsti in questa fase planning; restano **opzione futura** solo se approvata esplicitamente (documentare nel task o nuovo micro-task).

## Regression guard TASK-031 / TASK-036
I test slice 2 **non devono far regredire** i comportamenti già consolidati in **TASK-031** e **TASK-036**, in particolare:
- **Header canonici** e riconoscimento tramite **alias**, header **localizzati** e varianti **snake_case** / naming eterogeneo già gestito.
- **Fallback `colN`** quando appropriato.
- **Override manuale** (ruoli colonne): compatibilità del risultato verso PreGenerate / flusso esistente **senza** rompere round-trip noti.
- **Append compatibility** (coerenza multi-file / header allineati).

Se un test richiede **cambio al parser** per passare:
- **non** si risolve dal planning né si assume fix implicito; documentare **follow-up** (nuovo task o estensione TASK-037) oppure **futura EXECUTION** **solo** dopo **user override** esplicito su modifica codice.

## Assertion style (slice 2 — futura execution)
- Verificare in modo stabile: **mapping** e **allineamento** colonne, **conteggio righe dati utili**, **header normalizzati**, **scelta tabella** nei casi multi-table.
- **Evitare** assert sulla **stringa numerica letterale** quando l’analyzer **normalizza** (es. `2.50` vs `2.5`): già nota in slice 1; preferire valore logico / parsing numerico o confronto documentato.
- Preferire **helper leggibili**, da implementare in EXECUTION, ad esempio:
  - `assertHeaderContains(...)`
  - `assertRowValue(...)`
  - `assertNoDecorativeRows(...)` (o equivalente sul modello righe esposto dall’analyzer)
- **Niente SwiftData** nei test se il parse è **puro** su strutture in memoria / risultato `ExcelAnalyzer`.

### Comandi futuri (solo riferimento — **non eseguiti** in fase planning)
- `xcodebuild -list -project iOSMerchandiseControl.xcodeproj`
- `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'generic/platform=iOS Simulator' build`
- `xcodebuild test -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=<versione_disponibile>'`
  (adattare `name`/`OS` all’ambiente locale; stesso avviso slice 1 su simulator concreto vs `generic`.)

## Decisioni UX (slice 2 — vincoli per future micro-modifiche testuali)
- **Nessun redesign** di PreGenerate, navigazione import, layout o gerarchia delle schermate esistenti.
- Se in **futura EXECUTION** serve **microcopy** per HTML non riconosciuto / senza righe dati utili: inserirla nello **stesso punto UI** già usato per **errori e feedback di import** (alert, banner, stato vuoto esistente — da mappare in EXECUTION senza introdurre nuovi pattern navigazionali).
- Testo **breve**, **stile iOS nativo** (chiaro, diretto), **localizzabile** tramite le convenzioni esistenti (`Localizable.strings` / chiavi; nuove chiavi solo se indispensabili).
- **Nessuna nuova schermata** e **nessun flusso nuovo** (niente wizard, tab aggiuntivi o entry point paralleli).
- UX preferita: **import conservativo** +, dove l’app lo consente già, **correzione / override manuale** (colonne e ruoli) anziché euristiche aggressive sul solo HTML.

## Non incluso (slice 2)
- Supabase, schema DB, client remoto.
- `GeneratedView`, `RowDetailSheetView`, UI runtime inventario o database oltre eventuale microcopy di import HTML (solo pianificata).
- Refactor strutturale di `ExcelAnalyzer` o split del file `ExcelSessionViewModel.swift`.
- Redesign PreGenerate (flussi, layout, nuove schermate).
- Test UI E2E complessi, Simulator automation, snapshot visuali.
- Parsing euristico aggressivo basato **solo** sui valori delle celle (senza header affidabile).
- Modifica del task **TASK-036** (resta **DONE**).
- Modifica a `project.pbxproj`, scheme Xcode, Swift di produzione o test **durante questa fase planning** (vietata finché non c’è handoff esplicito a EXECUTION).

## Criteri di accettazione — **slice 1** (storico, soddisfatti)
- [x] `xcodebuild -list` mostra il target test.
- [x] `xcodebuild test` esegue i test TASK-036 iniziali.
- [x] Le fixture HTML TASK-036 sono disponibili nel bundle test.
- [x] TASK-031 e TASK-036 restano DONE.
- [x] Nessun lavoro fuori scope (slice 1).

## Criteri di accettazione — **Planning slice 2** (contratto del *documento di piano*, pre-execution)
- [x] **TASK-036** resta **DONE** e non è oggetto di questa fase salvo lettura di riferimento.
- [x] Dopo questa integrazione il task resta **ACTIVE / PLANNING**; la **review documentale** del piano slice 2 risulta **APPROVED** (sezione Review); resta **READY FOR REVIEW APPROVAL** / conferma formale utente prima di EXECUTION; slice 2 **non** **DONE** automaticamente.
- [x] **Nessuna EXECUTION** aperta da questo documento; **nessun comando** riportato come **eseguito** nella fase planning.
- [x] Il follow-up **TASK-037** (slice 2): tragitto atteso **PLANNING** → review documentale **APPROVED** → **conferma utente** / **user override** → **EXECUTION** / Codex.
- [x] È chiaro cosa **Cursor/Codex** dovrà fare in **futura EXECUTION**: matrice 1–8, priorità **P0–P2**, Fixture sync policy, Regression guard, Assertion style, vincoli UX, esclusioni.
- [x] Sono indicati **comandi** `xcodebuild` previsti ma **non** presentati come eseguiti nella fase planning corrente.
- [x] **Rischi** e **rollback** documentati; allineamento fixture dettagliato nella sezione **Fixture sync policy**.
- [x] **Priorità P0–P2**, **Fixture sync policy**, **Regression guard TASK-031/036** e **Assertion style** presenti nel planning.
- [x] Dopo **conferma utente** e **user override** esplicito: handoff **EXECUTION** / **CODEX** (eseguito 2026-05-04).

## Rischi e rollback (slice 2)
- **Rischio**: fixture `docs/` vs `iOSMerchandiseControlTests/Fixtures/` divergono → test verdi ma non rappresentativi. *Mitigazione*: **Fixture sync policy** (checklist in EXECUTION); script automatici solo se approvati in futuro.
- **Rischio**: append/multi-file richiede stato `ExcelSessionViewModel` non isolabile in test → *Mitigazione*: estrarre helper puro o usare entry point minimo; se impossibile senza refactor, registrare **BLOCKED** tecnico e ridurre scope con motivazione.
- **Rischio**: HTML “real world” da Excel/browser troppo vari → iniziare da **minimal repro** committati come fixture, non dipendere da URL esterni.
- **Rollback**: eliminare test/fixture aggiunti nella slice 2; non toccare dati utente (nessuna migration); TASK-036 resta baseline git immutata per responsabilità slice 2.

## Strategia futura di Execution (solo piano — **non eseguire** finché non autorizzato)
1. Leggere `iOSMerchandiseControl/ExcelSessionViewModel.swift` e individuare **`ExcelAnalyzer`** / API pubbliche o `internal` testabili dal target test (incluso `@testable import` se già praticato).
2. Mappare ogni caso della matrice 1–8 a **una fixture** e a **asserzioni** (vedi **Assertion style**), seguendo dove possibile l’ordine **P0 → P1 → P2** — senza dipendere da SwiftData se evitabile.
3. Confermare che il target `iOSMerchandiseControlTests` basta; altrimenti proporre delta minimale a `project.pbxproj` **solo** dopo review tecnica (fuori da questa fase planning).
4. Aggiungere/allineare fixture nel bundle test e in `docs/fixtures/TASK-036/` (**Fixture sync policy**: doppia posizione + README).
5. Scrivere test XCTest mirati (nomi espliciti, un file o più file per chiarezza).
6. Eseguire `xcodebuild test` con destinazione simulator concreta; registrare evidenze nel task (sezione Execution).
7. **Lasciare TASK-036 invariato** come task e come responsabilità storica; eventuali fix parser solo se nuovo task o estensione TASK-037 concordata.

## Handoff post-planning (bozza)
- **Prossima fase**: conferma utente / **REVIEW APPROVAL** formale del piano; poi, solo con **user override**, **EXECUTION** (Codex/Cursor).
- **Prossimo agente**: utente (approvazione) → poi executor sotto override esplicito.
- **Prossima azione consigliata**: se il piano è accettato, **user override** esplicito per avviare **EXECUTION** slice 2; altrimenti iterazione planning.

**Nota handoff:** Planning slice 2 revisionato (documentale **APPROVED** in sezione Review). **Execution** solo con **user override** esplicito.

---

## Planning (Claude) ← solo Claude aggiorna questa sezione
**Nota processo:** il corpo operativo del planning slice 2 (obiettivo, scope, matrice 1–8, priorità P0–P2, Fixture sync policy, Regression guard, Assertion style, UX, non incluso, CA sul planning, strategia, rischi) è stato integrato **2026-05-04** nelle sezioni **precedenti** su **user override** (documentazione only). Per aggiornamenti successivi alla struttura del piano, Claude mantiene la competenza su questa sezione; allineare il riepilogo qui sotto se si diverge dal corpo.

**Riepilogo slice 2:** matrice 1–8; priorità **P0–P2**; **Fixture sync policy**; **Regression guard** TASK-031/036; **Assertion style**; UX microcopy nel punto feedback import esistente; HTML minimali anonimizzati; append/multi-file; execution e comandi **solo** dopo **user override**. *Review documentale piano slice 2: **APPROVED** (2026-05-04, v.sezione Review).*

---

## Execution (Codex) ← solo Codex aggiorna questa sezione
**Storico slice 1 (2026-04-27).** Per slice 2: iniziare una nuova sottosezione solo dopo handoff autorizzato verso **EXECUTION**.

### Avvio Execution slice 2 — 2026-05-04
- User override ricevuto: autorizzato passaggio di TASK-037 slice 2 da `PLANNING / READY FOR REVIEW APPROVAL` a `EXECUTION`.
- Obiettivo compreso: estendere la validazione automatica XCTest parser-only del parser HTML avanzato di `ExcelAnalyzer`, riusando il target esistente `iOSMerchandiseControlTests`, senza riaprire TASK-036 e senza modifiche UI/Supabase/project file.
- File da controllare/modificare nel perimetro autorizzato:
  - `docs/TASKS/TASK-037-xctest-target-html-parser-fixtures.md`
  - `docs/MASTER-PLAN.md` solo per riallineamento tracking/stato
  - `docs/fixtures/TASK-036/`
  - `iOSMerchandiseControlTests/`
  - `iOSMerchandiseControlTests/Fixtures/TASK-036/`
  - `iOSMerchandiseControl/ExcelSessionViewModel.swift` solo se indispensabile per micro-helper puro/testabile
- Piano minimo:
  1. verificare API/test/fixture esistenti della slice 1;
  2. implementare prima i casi P0 (nested table, append/multi-file, HTML minimale senza header reale);
  3. aggiungere i casi P1 se P0 resta parser-only e senza refactor rischiosi;
  4. aggiungere eventuali P2 solo se P0/P1 sono completi senza allargare il perimetro;
  5. sincronizzare fixture docs/test e aggiornare README fixture;
  6. eseguire build/test richiesti e riportare a `ACTIVE / REVIEW` con handoff post-execution.

### Execution completata slice 2 — 2026-05-04
- Aggiunti helper XCTest leggibili in `ExcelAnalyzerHTMLParsingTests`: `assertHeaderContains`, `assertRowValue`, `assertRowsAreRectangular`, `assertNoDecorativeRows`.
- Aggiunti test P0:
  - `testNestedTableDoesNotContaminateMainTable`
  - `testLoadFromMultipleHTMLFilesAggregatesRowsWithoutDuplicatingHeader`
  - `testMinimalHTMLWithoutRealHeaderUsesGeneratedColumnsWithoutDataHeuristicPromotion`
- Rafforzati i test P1 esistenti su colspan, rowspan, multi-table, title/decorative rows e decorative-only con asserzioni su mapping/allineamento e senza assert fragili su formattazione numerica letterale.
- Aggiunto test P2 leggero: `testRealisticAnonymizedMinimalReproKeepsLocalizedAliasesAligned`.
- Aggiunte e duplicate fixture in `docs/fixtures/TASK-036/` e `iOSMerchandiseControlTests/Fixtures/TASK-036/`:
  - `html-nested-table.html`
  - `html-append-inventory-a.html`
  - `html-append-inventory-b.html`
  - `html-minimal-no-header.html`
  - `html-realistic-anonymized-minimal.html`
- Aggiornato `docs/fixtures/TASK-036/README.md` con i nuovi casi e il comportamento documentato per HTML minimale senza header reale.
- Nessuna modifica a `ExcelSessionViewModel.swift`, SwiftData, UI runtime, Supabase, scheme o `project.pbxproj`. L'append/multi-file è stato testato tramite API parser-only già esistente `ExcelAnalyzer.loadFromMultipleURLs`.
- TASK-036 resta DONE e non è stato riaperto.

### Check eseguiti slice 2 — 2026-05-04
- ✅ ESEGUITO — `xcodebuild -list -project iOSMerchandiseControl.xcodeproj`: target `iOSMerchandiseControlTests` e scheme `iOSMerchandiseControl` visibili.
- ✅ ESEGUITO — `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'generic/platform=iOS Simulator' build`: BUILD SUCCEEDED.
- ✅ ESEGUITO — `xcrun simctl list devices available`: individuato `iPhone 16e` con `OS=26.2` disponibile.
- ✅ ESEGUITO — `xcodebuild test -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'`: TEST SUCCEEDED; 9/9 test HTML parser passati e suite test complessiva passata.
- ✅ ESEGUITO — `diff -r --exclude=README.md docs/fixtures/TASK-036 iOSMerchandiseControlTests/Fixtures/TASK-036`: nessuna differenza tra fixture documentali e copie bundle test, escluso README documentale non presente nel bundle.
- ✅ ESEGUITO — `git diff --check`: nessun whitespace/error diff rilevato.
- ✅ ESEGUITO — `git diff -- iOSMerchandiseControl.xcodeproj/project.pbxproj`: nessuna differenza finale nel project file.
- ✅ ESEGUITO — Build compila: esito positivo con comando build Debug Simulator.
- ✅ ESEGUITO — Nessun warning nuovo introdotto verificabile: unico warning osservato `Metadata extraction skipped. No AppIntents.framework dependency found`, già noto e non collegato a parser/test target.
- ✅ ESEGUITO — Modifiche coerenti con il planning: parser-only, nessuna dipendenza nuova, nessun refactor, nessuna UI, nessun Supabase, nessun task diverso.
- ✅ ESEGUITO — Criteri P0 verificati:
  - STATIC/XCTest: nested table non contamina righe/colonne dati (`testNestedTableDoesNotContaminateMainTable`).
  - STATIC/XCTest: append multi-file aggrega 4 righe dati con header normalizzato unico e senza duplicazione header (`testLoadFromMultipleHTMLFilesAggregatesRowsWithoutDuplicatingHeader`).
  - STATIC/XCTest: HTML senza header reale usa fallback conservativo `colN` e non promuove i soli dati a mapping canonico (`testMinimalHTMLWithoutRealHeaderUsesGeneratedColumnsWithoutDataHeuristicPromotion`).
- ✅ ESEGUITO — Criteri P1 verificati:
  - STATIC/XCTest: colspan header raggruppato allineato.
  - STATIC/XCTest: rowspan data espanso in righe rettangolari.
  - STATIC/XCTest: multi-table ignora decorative prima/dopo.
  - STATIC/XCTest: righe titolo/decorative prima dell'header ignorate.
  - STATIC/XCTest: decorative-only non inventa mapping canonico.
- ✅ ESEGUITO — Criterio P2 verificato:
  - STATIC/XCTest: minimal repro realistico anonimizzato con alias/localizzazione IT e snake_case resta allineato.

### Rischi residui slice 2 — 2026-05-04
- Copertura ancora basata su minimal repro HTML committati; nessun fuzzing e nessun benchmark performance fragile, per scelta coerente col planning.
- Il comportamento HTML senza header reale è documentato come fallback conservativo con colonne `colN` e colonne obbligatorie vuote per compatibilità override/manual flow; eventuali miglioramenti UX/microcopy restano fuori scope.
- Il target usa cartelle sincronizzate Xcode; l'aggiunta fixture non ha richiesto modifiche al project file, ma review può verificare che tutte le nuove risorse siano nel bundle come da log `xcodebuild test`.

### Handoff post-execution slice 2 — verso Claude Review
- Stato proposto: `ACTIVE / REVIEW`.
- Responsabile proposto: `Claude reviewer`.
- Da verificare in review:
  - coerenza dei test P0/P1/P2 con planning slice 2;
  - allineamento fixture `docs/` vs bundle test;
  - comportamento documentato per HTML senza header reale;
  - assenza di modifiche fuori scope a produzione/UI/Supabase/project file;
  - TASK-036 resta DONE e non viene riaperto.

### Avvio Execution — 2026-04-27
- Obiettivo compreso: aggiungere un test target XCTest minimale per il parser HTML avanzato, senza riaprire TASK-036.
- File da modificare:
  - `iOSMerchandiseControl.xcodeproj/project.pbxproj`
  - `iOSMerchandiseControl.xcodeproj/xcshareddata/xcschemes/iOSMerchandiseControl.xcscheme`
  - `iOSMerchandiseControlTests/`
  - `docs/MASTER-PLAN.md`
  - questo file task
- Piano minimo:
  1. aggiungere target XCTest con host app `iOSMerchandiseControl`;
  2. includere fixture TASK-036 nel bundle test;
  3. testare `ExcelAnalyzer.readAndAnalyzeExcel`;
  4. verificare build/test;
  5. riportare a Review.

### Execution completata — 2026-04-27
- Creato target XCTest `iOSMerchandiseControlTests` con host app `iOSMerchandiseControl`.
- Aggiunto scheme condiviso `iOSMerchandiseControl` con TestAction verso `iOSMerchandiseControlTests`.
- Copiate le fixture TASK-036 nel bundle test sotto `iOSMerchandiseControlTests/Fixtures/TASK-036/`.
- Aggiunta suite `ExcelAnalyzerHTMLParsingTests` per:
  - `html-colspan-header`
  - `html-rowspan-data`
  - `html-multiple-tables`
  - `html-title-rows-before-header`
  - `html-negative-decorative-table-only`
- Fix diretto durante execution: il bundle XCTest copia le fixture come risorse flat; il helper di lookup ora cerca prima `Fixtures/TASK-036`, poi il bundle root.
- Fix diretto durante execution: aspettative numeriche allineate al comportamento esistente dell'analyzer, che normalizza `2.50` in `2.5` e `5.00` in `5`. Il test resta focalizzato su mapping/allineamento, non sulla formattazione decimale letterale.
- TASK-031 e TASK-036 restano DONE e non sono stati riaperti.

### Check eseguiti — 2026-04-27
- ✅ ESEGUITO — `xcodebuild -list -project iOSMerchandiseControl.xcodeproj`: target `iOSMerchandiseControlTests` visibile; scheme `iOSMerchandiseControl` visibile.
- ✅ ESEGUITO — `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'generic/platform=iOS Simulator' build`: BUILD SUCCEEDED.
- ✅ ESEGUITO — `xcodebuild test -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,id=4CE85775-BEF1-44D5-9BBF-B180EDF09D0B'`: TEST SUCCEEDED, 5/5 test passati.
- ⚠️ NON ESEGUIBILE — `xcodebuild test` con destination `generic/platform=iOS Simulator`: Xcode richiede un simulatore concreto per l'esecuzione dei test unitari host-based; usato iPhone 16e disponibile/booted.
- ✅ ESEGUITO — Build app/test implicita in `xcodebuild test`: completata prima dell'esecuzione dei test.
- ✅ ESEGUITO — Nessun warning nuovo bloccante rilevato nei file modificati; resta il warning noto `Metadata extraction skipped. No AppIntents.framework dependency found`, gia' non collegato al parser/test target.
- ✅ ESEGUITO — Modifiche coerenti col perimetro: nessun Supabase, nessun `RowDetailSheetView`, nessun `GeneratedView`, nessun redesign PreGenerate, nessun refactor generale.

### Handoff post-execution — verso Claude Review
- Stato proposto: `ACTIVE / Review`.
- Responsabile proposto: `Claude reviewer`.
- Da verificare in review:
  - target XCTest e scheme condiviso nel project file;
  - inclusione fixture TASK-036 nel bundle test;
  - copertura test rispetto ai rischi HTML TASK-036;
  - compatibilita' con TASK-031/TASK-036 DONE.
- Rischi residui:
  - target aggiunto manualmente nel `project.pbxproj` per assenza del gem `xcodeproj`; review consigliata sul project file;
  - fixture test duplicate rispetto a `docs/fixtures/TASK-036`, volutamente per renderle risorse XCTest;
  - copertura limitata alle fixture TASK-036, non a fuzzing HTML o workbook reali.

---

## Review (Claude; Codex solo su user override)

### Review tecnica slice 2 (user override Codex) — 2026-05-04
- **Ambito**: review tecnica completa della slice 2 dopo execution XCTest parser-only; autorizzati fix diretti piccoli e chiusura **DONE** se build/test/scope/tracking risultano corretti.
- **Esito**: **APPROVED / DONE** — nessun problema bloccante o rischioso trovato; nessun fix diretto necessario su test, fixture o production code.
- **Coerenza P0/P1/P2**: copertura allineata al planning. P0 copre nested table, append/multi-file e HTML minimale senza header reale; P1 resta coperta per colspan, rowspan, multi-table con decorative prima/dopo, title rows e decorative-only; P2 copre un minimal repro realistico anonimizzato non fragile.
- **Helper XCTest**: `assertHeaderContains`, `assertRowValue`, `assertRowsAreRectangular`, `assertNoDecorativeRows` sono utili e leggibili; nessun cleanup applicato perche' ridurrebbe il segnale degli assert.
- **Stabilita' assert**: nessun confronto fragile su formattazione numerica `2.50` vs `2.5`; gli assert nuovi privilegiano mapping, header, row count, rettangolarita', scelta tabella e valori testuali/barcode stabili.
- **Fixture**: `diff -r --exclude=README.md docs/fixtures/TASK-036 iOSMerchandiseControlTests/Fixtures/TASK-036` senza output; SHA-256 docs/test combaciano; README aggiornato; fixture piccole, anonimizzate e non ridondanti.
- **Scope**: nessuna modifica a produzione, UI runtime, Supabase, SwiftData/schema DB, `ExcelAnalyzer`, `ExcelSessionViewModel.swift`, `GeneratedView`, `PreGenerate`, `RowDetailSheetView`, scheme o dipendenze. I test usano solo `XCTest`, `@testable import`, `ExcelAnalyzer.readAndAnalyzeExcel` e `ExcelAnalyzer.loadFromMultipleURLs`.
- **Project file**: `git diff -- iOSMerchandiseControl.xcodeproj/project.pbxproj` senza output; nessuna diff finale inattesa.
- **ExcelSessionViewModel.swift**: letto per verificare gli entry point parser; `git diff -- iOSMerchandiseControl/ExcelSessionViewModel.swift` senza output.

### Problemi trovati slice 2
- Nessun problema bloccante.
- Nessun problema piccolo da correggere direttamente.

### Fix diretti slice 2
- Nessuno. Review e check hanno confermato che test/fixture/tracking erano coerenti; sono stati aggiornati solo i file di tracking per chiusura **DONE**.

### Check eseguiti slice 2
- ✅ ESEGUITO — `git status --short`: diff limitata a tracking, README fixture, test XCTest e nuove fixture; nessun file production Swift modificato.
- ✅ ESEGUITO — `git diff --stat`: diff coerente con test/fixture/tracking.
- ✅ ESEGUITO — `git diff --check`: nessun errore whitespace.
- ✅ ESEGUITO — `git diff -- iOSMerchandiseControl.xcodeproj/project.pbxproj`: nessuna diff.
- ✅ ESEGUITO — `diff -r --exclude=README.md docs/fixtures/TASK-036 iOSMerchandiseControlTests/Fixtures/TASK-036`: nessuna differenza.
- ✅ ESEGUITO — `xcodebuild -list -project iOSMerchandiseControl.xcodeproj`: target `iOSMerchandiseControlTests` e scheme `iOSMerchandiseControl` presenti.
- ✅ ESEGUITO — `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'generic/platform=iOS Simulator' build`: **BUILD SUCCEEDED**.
- ✅ ESEGUITO — `xcodebuild test -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'`: **TEST SUCCEEDED**; 9/9 test `ExcelAnalyzerHTMLParsingTests` passati e suite XCTest complessiva passata.
- ✅ ESEGUITO — Build compila: esito positivo.
- ✅ ESEGUITO — Nessun warning nuovo introdotto verificabile: unico warning osservato `Metadata extraction skipped. No AppIntents.framework dependency found`, gia' noto e non collegato a TASK-037.
- ✅ ESEGUITO — Modifiche coerenti con il planning: parser-only, nessuna UI/Supabase/SwiftData/schema/refactor production.
- ✅ ESEGUITO — Criteri di accettazione verificati: P0/P1/P2 coperti; fixture allineate; `project.pbxproj` senza diff; TASK-036 resta DONE.

### Esito review slice 2
APPROVED senza fix diretti. TASK-037 **slice 2** chiusa **DONE / Chiusura** su override esplicito dell'utente.

### Review planning slice 2 (solo documento, nessuna execution) — 2026-05-04
- **Ambito**: coerenza e completezza del piano slice 2 (matrice 1–8, P0–P2, Fixture sync, Regression guard, Assertion style, UX, Non incluso, CA planning, strategia, handoff); **TASK-036** resta **DONE**; nessun codice né build in questa review.
- **Esito**: **APPROVED** — piano utilizzabile da executor futuro sotto **user override** esplicito; perimetro rispettato (vietati Swift/test/fixture/pbxproj/scheme/Supabase/UI runtime in fase planning); UX limitata a **microcopy** opzionale futura senza redesign; nessuna apertura implicita a Execution oltre i vincoli già scritti nel task.
- **Problemi**: nessun problema **bloccante**. Micro-integrazione: resa esplicita in **P1** la voce **decorative-only** (matrice 5) per allineamento executor/P1–matrice.
- **Stato consigliato**: **READY FOR REVIEW APPROVAL** da parte utente / conferma formale; task resta **ACTIVE / PLANNING** fino a **user override** su **EXECUTION** (o finché il tracking non viene riallineato esplicitamente).

### Review tecnica — 2026-04-27 (slice 1 — storico)
- Controllato tracking: `MASTER-PLAN` indicava TASK-037 come unico task `ACTIVE / Review`; TASK-031 e TASK-036 risultano DONE; TASK-032 non e' stato toccato.
- Controllato `project.pbxproj`: target `iOSMerchandiseControlTests` presente una sola volta come unit-test bundle, host app configurata con `TEST_HOST`/`BUNDLE_LOADER`, dependency verso target app, product `.xctest`, synchronized root group dedicato al test target, nessuna fixture aggiunta al target app.
- Controllato scheme condiviso `iOSMerchandiseControl.xcscheme`: BuildAction include app e test target, TestAction include `iOSMerchandiseControlTests`, nessun device/simulator hardcoded, launch/profile restano sull'app.
- Controllato test `ExcelAnalyzerHTMLParsingTests`: parser-only, nessuna UI, nessun Supabase, nessuna rete, nessun path assoluto, lookup fixture robusto con fallback da sottocartella a root bundle.
- Controllate fixture: cinque fixture minime presenti nel bundle test e coerenti con `docs/fixtures/TASK-036`; duplicazione intenzionale documentata.

### Problemi trovati
- README documentale TASK-036 ancora diceva che non esisteva un test target: vero per TASK-036, ma incompleto dopo TASK-037.
- Fixture `html-multiple-tables.html` copriva tabella decorativa prima della tabella dati, ma non una decorativa dopo; un parser che tornasse a leggere globalmente tutti i `<tr>` poteva non fallire in modo abbastanza evidente.

### Fix diretti Claude su user override
- Aggiornato `docs/fixtures/TASK-036/README.md` per documentare che TASK-037 duplica intenzionalmente le fixture nel bundle XCTest e che le copie vanno mantenute allineate.
- Rafforzata `html-multiple-tables.html` in `docs/fixtures/TASK-036/` e nella copia `iOSMerchandiseControlTests/Fixtures/TASK-036/` aggiungendo una tabella decorativa dopo la tabella dati; il test resta a `dataRows.count == 2`, quindi fallisce se il parser include righe decorative globali.

### Build/test eseguiti
- ✅ ESEGUITO — `git status --short`.
- ✅ ESEGUITO — `git diff --stat`.
- ✅ ESEGUITO — diff richiesti su `MASTER-PLAN`, task, `project.pbxproj`, scheme e test.
- ✅ ESEGUITO — `find iOSMerchandiseControlTests -maxdepth 4 -type f | sort`.
- ✅ ESEGUITO — `plutil -lint iOSMerchandiseControl.xcodeproj/project.pbxproj`: OK.
- ✅ ESEGUITO — `xmllint --noout iOSMerchandiseControl.xcodeproj/xcshareddata/xcschemes/iOSMerchandiseControl.xcscheme`: OK.
- ✅ ESEGUITO — confronto fixture docs/test: stessi file e contenuti allineati dopo fix.
- ✅ ESEGUITO — `xcodebuild -list -project iOSMerchandiseControl.xcodeproj`: target `iOSMerchandiseControlTests` visibile.
- ✅ ESEGUITO — `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'generic/platform=iOS Simulator' build`: BUILD SUCCEEDED.
- ⚠️ NON ESEGUIBILE — `xcodebuild test ... -destination 'platform=iOS Simulator,name=iPhone 16e'`: Xcode cerca `OS:latest`, ma gli iPhone 16e disponibili sono OS 26.1/26.2; rilanciato senza UUID con `OS=26.2`.
- ✅ ESEGUITO — `xcodebuild test -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'`: TEST SUCCEEDED, 5/5 test passati.
- ⚠️ Warning noto — `Metadata extraction skipped. No AppIntents.framework dependency found`, non collegato al target/parser.

### Esito review
APPROVED con fix diretti piccoli gia' applicati. TASK-037 **(slice 1)** chiuso **DONE** su autorizzazione utente esplicita.

---

## Fix (Codex) ← solo Codex aggiorna questa sezione
Non avviato: non serve ciclo Codex separato dopo la review slice 2; nessun fix richiesto.

---

## Archivio — Chiusura slice 1 (DONE 2026-04-27)

**Nota:** questa sezione è **storica**. La chiusura DONE seguente si riferisce **solo** alla slice 1; la slice 2 è chiusa nella sezione successiva.

### Conferma utente
- [x] User override 2026-04-27: autorizzata review tecnica completa, fix diretti mirati e chiusura DONE se tutto OK.

### Follow-up candidate (storico slice 1)
- Mantenere allineate le fixture duplicate `docs/fixtures/TASK-036/` e `iOSMerchandiseControlTests/Fixtures/TASK-036/` se verranno modificate in futuro.

### Riepilogo finale (slice 1)
TASK-037 (slice 1) ha aggiunto un target XCTest minimale e stabile per validare automaticamente le fixture HTML avanzate TASK-036. Target, scheme, bundle fixture e test iniziali risultano corretti; build e test verdi. TASK-031 e TASK-036 restano DONE e non sono stati riaperti.

### Data completamento slice 1
2026-04-27

---

## Archivio — Chiusura slice 2 (DONE 2026-05-04)

### Conferma utente
- [x] User override 2026-05-04: autorizzata review tecnica completa, fix diretti sicuri e chiusura **DONE** se tutto OK.

### Riepilogo finale (slice 2)
TASK-037 slice 2 estende la suite parser-only di `ExcelAnalyzer` con copertura P0/P1/P2, fixture documentali e bundle test allineate, e README aggiornato. Review tecnica approvata: build e test verdi, `project.pbxproj` senza diff, nessuna modifica production/UI/Supabase/SwiftData/schema/refactor. TASK-036 resta DONE e non viene riaperto.

### Data completamento slice 2
2026-05-04
