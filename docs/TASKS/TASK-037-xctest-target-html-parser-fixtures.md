# TASK-037: XCTest target for ExcelAnalyzer HTML parser fixtures

## Informazioni generali
- **Task ID**: TASK-037
- **Titolo**: XCTest target for ExcelAnalyzer HTML parser fixtures
- **File task**: `docs/TASKS/TASK-037-xctest-target-html-parser-fixtures.md`
- **Stato**: DONE
- **Fase attuale**: Chiusura
- **Responsabile attuale**: —
- **Data creazione**: 2026-04-27
- **Ultimo aggiornamento**: 2026-04-27
- **Ultimo agente che ha operato**: Claude Code reviewer/fixer

## Nota tracking
- User override 2026-04-27: dopo la chiusura DONE di TASK-036, l'utente ha richiesto esplicitamente di creare un test target coerente col perimetro. TASK-031 e TASK-036 restano DONE e non vengono riaperti.

## Dipendenze
- **Dipende da**: TASK-036
- **Sblocca**: validazione automatica minima del parsing HTML avanzato.

## Scopo
Creare un target XCTest minimale per coprire le fixture TASK-036 del parser HTML in `ExcelAnalyzer`, senza allargare a UI, Supabase o refactor generali.

## Scope
- Aggiungere target `iOSMerchandiseControlTests`.
- Copiare nel bundle test le fixture HTML TASK-036.
- Aggiungere test mirati su:
  - `colspan`
  - `rowspan`
  - multi-table
  - righe titolo prima dell'header
  - decorative-only negativo
- Eseguire `xcodebuild test`.

## Non incluso
- Supabase
- `RowDetailSheetView`
- `GeneratedView`
- redesign PreGenerate
- refactor generale di `ExcelAnalyzer`
- test UI

## Criteri di accettazione
- [x] `xcodebuild -list` mostra il target test.
- [x] `xcodebuild test` esegue i test TASK-036.
- [x] Le fixture HTML TASK-036 sono disponibili nel bundle test.
- [x] TASK-031 e TASK-036 restano DONE.
- [x] Nessun lavoro fuori scope.

## Planning (Claude) ← solo Claude aggiorna questa sezione
User override operativo: test target minimale coerente col perimetro TASK-036.

---

## Execution (Codex) ← solo Codex aggiorna questa sezione

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

## Review (Claude) ← solo Claude aggiorna questa sezione

### Review tecnica — 2026-04-27
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
APPROVED con fix diretti piccoli gia' applicati. TASK-037 chiuso **DONE** su autorizzazione utente esplicita.

---

## Fix (Codex) ← solo Codex aggiorna questa sezione
Non avviato: non serve ciclo Codex separato dopo i fix diretti di review.

---

## Chiusura

### Conferma utente
- [x] User override 2026-04-27: autorizzata review tecnica completa, fix diretti mirati e chiusura DONE se tutto OK.

### Follow-up candidate
- Mantenere allineate le fixture duplicate `docs/fixtures/TASK-036/` e `iOSMerchandiseControlTests/Fixtures/TASK-036/` se verranno modificate in futuro.

### Riepilogo finale
TASK-037 ha aggiunto un target XCTest minimale e stabile per validare automaticamente le fixture HTML avanzate TASK-036. Target, scheme, bundle fixture e test risultano corretti; build e test verdi. TASK-031 e TASK-036 restano DONE e non sono stati riaperti.

### Data completamento
2026-04-27
