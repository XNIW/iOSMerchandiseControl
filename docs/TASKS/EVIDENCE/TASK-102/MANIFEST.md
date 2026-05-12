# TASK-102 Evidence Manifest

## Stato corrente

- Task: TASK-102 — Release polish UX/UI iOS-native
- Stato: DONE — REVIEW PASS FINAL / PASS WITH NOTES
- Avvio execution: 2026-05-12 13:50 -0400
- Chiusura execution: 2026-05-12 15:27 -0400 — READY FOR FINAL REVIEW
- Review finale: 2026-05-12 15:52 -0400 — REVIEW PASS FINAL / PASS WITH NOTES
- Chiusura: 2026-05-12 16:46 -0400 — TASK-102 DONE / PASS WITH NOTES
- Agente: Codex / Executor + Reviewer su override utente
- Repository: `/Users/minxiang/Desktop/iOSMerchandiseControl`
- Task file: `docs/TASKS/TASK-102-release-polish-ux-ios.md`
- Note privacy: nessun dato reale salvato nelle evidenze; screenshot/log eventuali devono usare solo dati sintetici o schermate vuote.
- Note tracking: execution avviata con override utente perché task e MASTER erano ancora in PLANNING / NON READY FOR EXECUTION.

## Ambiente rilevato

- Progetto Xcode: `iOSMerchandiseControl.xcodeproj`
- Scheme: `iOSMerchandiseControl`
- Target: `iOSMerchandiseControl`, `iOSMerchandiseControlTests`
- Deployment target rilevato: iOS 26.1
- Package graph: risolto con `xcodebuild -list -project iOSMerchandiseControl.xcodeproj` il 2026-05-12.

## Evidence index

| File | Scopo | Stato |
|------|-------|-------|
| `MANIFEST.md` | Indice evidenze, ambiente, DoR slice attiva | DONE / PASS WITH NOTES |
| `MATRIX-M102-results.md` | Risultati M102-01...17 | DONE / PASS WITH NOTES |
| `TRACEABILITY-S102-CA-M102.md` | Slice -> CA -> M -> file | DONE / PASS WITH NOTES |
| `a11y-notes.md` | Dynamic Type / VoiceOver / touch target | PASS WITH NOTES |
| `l10n-plutil.txt` | Output plutil e note localizzazioni | PASS |
| `static-review-navigation.md` | Review statica NavigationStack/toolbar/sheet | PASS WITH NOTES |
| `visual-consistency-notes.md` | Coerenza visiva e CTA | PASS WITH NOTES |
| `performance-smoke-notes.md` | Performance percepita | PASS WITH NOTES |
| `smoke-regression-checklist.md` | Smoke regression core | PASS WITH NOTES |
| `component-reuse-notes.md` | Riuso componenti/pattern esistenti | PASS WITH NOTES |
| `definition-of-done-checklist.md` | Checklist DoD TASK-102 | DONE / PASS WITH NOTES |
| `before-after-index.md` | Indice screenshot privacy-safe | PASS WITH NOTES |
| `screenshots/` | Screenshot privacy-safe eventuali | PASS WITH NOTES |

## Slice results

| Slice | Stato | Evidenza principale | Note |
|-------|-------|---------------------|------|
| S102-A | PASS WITH NOTES | Release build+launch PASS; screenshot `screenshots/S102-A-home-after.jpg`; `LocalizationCoverageTests` PASS 8/0 in Debug | Primo build Release fallito per errore introdotto `.foregroundStyle(.accentColor)`, corretto con `Color.accentColor` e rilanciato con successo. Test in Release non applicabile ai target XCTest per errore modulo; rilanciato correttamente in Debug. |
| S102-B | PASS WITH NOTES | Release build+launch PASS; screenshot `screenshots/S102-B-home-import-ready.jpg`; `ExcelAnalyzerHTMLParsingTests` PASS 9/0 in Debug | Picker UI manuale non interagito; validazione import coperta da patch statica e test parser HTML esistente. |
| S102-C | PASS WITH NOTES | Release build+launch PASS; static review PreGenerate; full XCTest Debug PASS finale | Nessun XCTest diretto per la vista; walkthrough manuale file picker -> PreGenerate non eseguito. |
| S102-D | PASS WITH NOTES | Release build+launch PASS; static review GeneratedView; benchmark sintetici PASS nel full test finale | Walkthrough manuale griglia con dataset sintetico non eseguito. |
| S102-E | PASS WITH NOTES | Release build+launch PASS; static review row detail/manual entry; full XCTest Debug PASS finale | Sheet runtime con dati sintetici non interagiti manualmente. |
| S102-F | PASS WITH NOTES | Release build+launch PASS; plutil PASS; duplicate-key scan PASS | Camera permission/manual scanner runtime non interagito; fallback verificato staticamente. |
| S102-G | PASS WITH NOTES | Release build+launch PASS; screenshot `screenshots/S102-G-history-empty-after.jpg`; plutil/duplicate scan PASS; `LocalizationCoverageTests` PASS 8/0 in Debug; full XCTest Debug PASS finale | Runtime detail/lista con entry sintetica non interagito manualmente. |
| S102-H | PASS WITH NOTES | Release build+launch PASS; screenshot `screenshots/S102-H-database-empty-after.jpg`; plutil/duplicate scan PASS; `LocalizationCoverageTests` PASS 8/0 in Debug; full XCTest Debug PASS finale | Runtime CRUD/import/export manuale con dati sintetici non eseguito; performance coperta da benchmark sintetici. |
| S102-I | PASS WITH NOTES | Release build+launch PASS; screenshot `screenshots/S102-I-options-sync-after.jpg`; plutil/duplicate scan PASS | Nessuna stringa nuova; runtime sync reale non eseguito per evitare dati/backend reali. |

## Final validation

| Check | Esito | Evidenza |
|-------|-------|----------|
| Whitespace diff finale | PASS | `git diff --check` exit 0, nessun output. |
| Build Release finale + launch simulator | PASS | XcodeBuildMCP `build_run_sim`, Release, iPhone 17 Pro; warnings/errors: 0. |
| XCTest completo Debug | PASS | XcodeBuildMCP `test_sim`, Debug: 640 passed / 0 failed / 12 skipped. Warning test preesistenti su Sendable/AppIntents non introdotti da TASK-102. |
| Localizzazioni finali | PASS | `plutil -lint` IT/EN/ES/zh-Hans OK; duplicate-key scan PASS. |
| Performance sintetica media | PASS WITH NOTES | Inclusa nel full test: `Task089LargeDatasetBenchmarkTests` PASS e `Task100LargeDatasetAcceptanceTests` benchmark rilevanti PASS; nessun dataset reale usato. |
| Smoke simulator privacy-safe | PASS WITH NOTES | Screenshot S102-A/B/G/H/I catturati; flussi con dati reali/backend live non eseguiti. |
| Dati reali nelle evidenze | PASS | Screenshot/log salvati nel repo non contengono barcode/prodotti/fornitori/prezzi/path sensibili reali. |
| TASK-103 | PASS | Nessun file/task TASK-103 aperto o modificato. |

## Final review validation — 2026-05-12 15:52 -0400

| Check | Esito | Evidenza |
|-------|-------|----------|
| Review diff Swift/localizzazioni | PASS WITH FIXES | Letti i diff dei file Swift e `Localizable.strings` modificati da TASK-102. Applicati fix mirati in `GeneratedView.swift`, `DatabaseView.swift`, `EditProductView.swift`. |
| Problemi corretti | PASS | Fallback scanner principale non piu no-op; azioni Database row preservate per accessibilità; clear validazione barcode non dipende da stringa localizzata. |
| Whitespace diff post-review | PASS | `git diff --check` exit 0, nessun output. |
| Localizzazioni post-review | PASS | `plutil -lint` IT/EN/ES/zh-Hans OK; duplicate-key scan per file OK. |
| Build Release post-review + launch simulator | PASS | XcodeBuildMCP `build_run_sim`, Release, iPhone 15 Pro Max iOS 26.1; warnings/errors: 0. |
| Full XCTest Debug post-review | PASS | Primo run su iPhone 15 Pro Max bloccato da errore infrastrutturale CoreSimulator clone; retry su iPhone 17 Pro PASS: 640 passed / 0 failed / 12 skipped. |
| Scope guard post-review | PASS | Nessun Android/Kotlin, nessun Supabase schema/RLS/policy/grant/migration, nessuna nuova dipendenza, nessun TASK-103. |
| Decisione review | REVIEW PASS FINAL / PASS WITH NOTES | Stato storico pre-chiusura: TASK-102 pronto per approvazione utente; superato dalla chiusura DONE 2026-05-12 16:46 -0400. |

## Final manual closure validation — 2026-05-12 16:46 -0400

| Check | Esito | Evidenza |
|-------|-------|----------|
| Simulator finale | PASS | iPhone 17 Pro, iOS 26.4, scheme `iOSMerchandiseControl`, Release build/launch. Dynamic Type OS-level `extra-large`. |
| VoiceOver/accessibility sampling | PASS WITH NOTES | Snapshot/accessibility hierarchy campionati su Home, PreGenerate, GeneratedView, Database, History, Options e sheet principali; full gestural VoiceOver traversal non eseguito. |
| Dynamic Type OS-level | PASS | `xcrun simctl ui ... content_size` confermato `extra-large`; flussi principali campionati senza blocker di navigazione. |
| File picker / import sintetico | PASS WITH NOTES | Picker Files aperto; provider Simulator non mostrava file recenti. Import sintetico verificato tramite handoff file app con XLSX privacy-safe, arrivando a PreGenerate e GeneratedView. |
| Manual entry / dettaglio riga | PASS | Inserimento manuale con fixture sintetica, scanner button, add-and-continue e sheet dettaglio riga verificati. |
| Scanner fallback | PASS WITH NOTES | Permission denied in Simulator e fallback “Inserisci manualmente” verificati; ricerca manuale alternativa verificata. Scansione camera reale resta hardware-device-only. |
| Database CRUD / storico prezzi | PASS | Create/read/update/delete con dati sintetici; delete confirmation; storico prezzi aperto e chiuso dopo fix toolbar. |
| Import/export DB | PASS WITH NOTES | Export share sheet aperto; import options e file picker surface verificati. Import mutativo full DB non applicato per provider file vuoto. |
| History / Options sync | PASS WITH NOTES | Cronologia con entry sintetiche visibile; superficie sync cloud signed-out verificata. Sync live reale non eseguito. |
| Fix finali | PASS | `ProductPriceHistoryView.swift` aggiunge `Chiudi`; `ContentView.swift` sopprime banner root `blockedAuth` fuori da Opzioni per non coprire toolbar a Dynamic Type extra-large. |
| Build Release + launch | PASS | XcodeBuildMCP `build_run_sim`, iPhone 17 Pro iOS 26.4, warnings/errors 0. |
| Full XCTest Debug | PASS | `xcodebuild test`, Debug, iPhone 17 Pro iOS 26.4: 652 tests / 0 failed / 12 skipped, exit 0. WarningCount xcresult 5 non bloccante. |
| Localizzazioni finali | PASS | `plutil -lint` IT/EN/ES/zh-Hans OK; duplicate-key scan per file OK. |
| Scope guard finale | PASS | Nessun Android/Kotlin; nessun Supabase schema/RLS/policy/grant/migration; nessuna nuova dipendenza; nessun TASK-103. |
| Decisione finale | TASK-102 DONE / REVIEW PASS FINAL / PASS WITH NOTES | Limiti hardware/manuali residui accettati come non bloccanti. |

## DoR S102-A

| Campo | Valore |
|-------|--------|
| Slice attiva | **S102-A — Tab shell, Home inventario, titoli e navigazione radice** |
| UX target | Rendere la Home inventario più leggibile e iOS-native senza cambiare il modello mentale: una CTA primaria per importare file, azioni manuali secondarie, stato import/empty leggibile e navigazione radice stabile. La tab shell resta familiare e viene verificata staticamente senza redesign globale. |
| File reali da toccare | `iOSMerchandiseControl/InventoryHomeView.swift`; evidence TASK-102; tracking TASK-102/Master. `iOSMerchandiseControl/ContentView.swift` letto e verificato per shell, non previsto come modifica salvo blocker tecnico. |
| File vietati | Android/Kotlin; Supabase SQL/RLS/policy/grant/migration; `iOSMerchandiseControl.xcodeproj/project.pbxproj`; `Package.resolved`; modelli SwiftData; `docs/TASKS/TASK-103*`; dati reali in evidenze. |
| Touch budget | S102-A: massimo 2 file Swift principali; localizzazioni solo se indispensabili; documentazione/evidenze TASK-102 consentite. Se serve una migrazione AppTab/routing globale o refactor shell, stop e ritorno a review. |
| Evidenze minime | `MATRIX-M102-results.md` riga M102-01/M102-15; `TRACEABILITY-S102-CA-M102.md`; `static-review-navigation.md`; `visual-consistency-notes.md`; note a11y base; build o motivo del blocco. |
| Rollback | Revert puntuale di `InventoryHomeView.swift` e delle eventuali localizzazioni S102-A; nessuna migrazione dati o schema coinvolta. |
| Stop rule specifica | Stop se S102-A richiede cambiare modello di routing globale, API pubbliche, schema SwiftData, nuova dipendenza, o modifiche coordinate oltre 2 file Swift principali. |
| M102 collegati | M102-01, M102-13 (campionamento statico), M102-15, M102-17 (home/navigation smoke) |
| CA collegati | CA-T102-01, CA-T102-02, CA-T102-03, CA-T102-04, CA-T102-06, CA-T102-07, CA-T102-10, CA-T102-11, CA-T102-13, CA-T102-14, CA-T102-15, CA-T102-16, CA-T102-17 |

## Check S102-A

| Check | Esito | Evidenza |
|-------|-------|----------|
| Whitespace diff | PASS | `git diff --check` exit 0, nessun output. |
| Build Release + launch simulator | PASS | XcodeBuildMCP `build_run_sim`, scheme `iOSMerchandiseControl`, Release, iPhone 17 Pro iOS 26.4/26.5 latest; build/run succeeded, warnings/errors: 0. |
| Screenshot privacy-safe | PASS | `screenshots/S102-A-home-after.jpg`; Home vuota, nessun dato reale. |
| Localizzazioni plist | PASS | `plutil -lint` su IT/EN/ES/zh-Hans: OK. |
| XCTest mirato | PASS | `LocalizationCoverageTests` in Debug: 8 passed / 0 failed / 0 skipped. Warning noti in test non toccati. |
| Test automatico Release | NOT RUN | Tentativo non utile: XCTest in Release fallisce prima dei test con `unable to resolve Swift module dependency`; rilanciato in Debug con PASS. |

## DoR S102-B

| Campo | Valore |
|-------|--------|
| Slice attiva | **S102-B — Import file Excel/HTML, stati analisi, errori picker** |
| UX target | Rendere l'import da picker e "Apri con" più prevedibile: stesso percorso di validazione, errore leggibile sui formati non supportati, nessun alert quando l'utente annulla il picker, feedback loading/progress chiaro prima di PreGenerate. |
| File reali da toccare | `iOSMerchandiseControl/InventoryHomeView.swift`; evidence TASK-102. `iOSMerchandiseControl/ExcelSessionViewModel.swift` letto, non previsto come modifica. |
| File vietati | Android/Kotlin; Supabase SQL/RLS/policy/grant/migration; `project.pbxproj`; `Package.resolved`; modelli SwiftData; parser `ExcelAnalyzer` salvo blocker; TASK-103. |
| Touch budget | Massimo 2 file Swift principali; target effettivo 1 file Swift. Localizzazioni solo se indispensabili. |
| Evidenze minime | `MATRIX-M102-results.md` M102-02/M102-15/M102-17; traceability aggiornata; build+launch; nota su test automatici disponibili. |
| Rollback | Revert della patch import in `InventoryHomeView.swift`; nessun dato/schema coinvolto. |
| Stop rule specifica | Stop se serve modificare parser Excel/HTML, modello sessione, routing PreGenerate o introdurre nuova capability import. |
| M102 collegati | M102-02, M102-13, M102-15, M102-17 |
| CA collegati | CA-T102-01, CA-T102-05, CA-T102-06, CA-T102-10, CA-T102-13, CA-T102-14, CA-T102-15, CA-T102-16, CA-T102-17 |

## Check S102-B

| Check | Esito | Evidenza |
|-------|-------|----------|
| Whitespace diff | PASS | `git diff --check` exit 0, nessun output. |
| Build Release + launch simulator | PASS | XcodeBuildMCP `build_run_sim`, Release, iPhone 17 Pro; warnings/errors: 0. |
| Screenshot privacy-safe | PASS | `screenshots/S102-B-home-import-ready.jpg`; Home vuota, nessun dato reale. |
| Localizzazioni plist | PASS | `plutil -lint` su IT/EN/ES/zh-Hans: OK; nessuna stringa nuova. |
| XCTest import/parser | PASS | `ExcelAnalyzerHTMLParsingTests` in Debug: 9 passed / 0 failed / 0 skipped. Warning noti in test non toccati. |
| Picker manuale | NOT RUN | Interazione manuale picker non eseguita in S102-B; comportamento verificato staticamente e via build/launch. |

## DoR S102-C

| Campo | Valore |
|-------|--------|
| Slice attiva | **S102-C — Pre-generazione colonne, ruoli, preview** |
| UX target | Rendere la schermata di pre-generazione più scansionabile: preview e ruoli colonna leggibili, azione "Genera" chiaramente primaria, controlli select/deselect e menu ruolo coerenti con pattern SwiftUI esistenti. |
| File reali da toccare | `iOSMerchandiseControl/PreGenerateView.swift`; evidence TASK-102. |
| File vietati | Android/Kotlin; Supabase SQL/RLS/policy/grant/migration; `project.pbxproj`; `Package.resolved`; `ExcelAnalyzer`; `ExcelSessionViewModel` salvo blocker; modelli SwiftData; TASK-103. |
| Touch budget | Massimo 2 file Swift principali; target effettivo 1 file Swift. Localizzazioni solo se indispensabili. |
| Evidenze minime | `MATRIX-M102-results.md` M102-03/M102-13/M102-15/M102-17; traceability aggiornata; build+launch; eventuale screenshot privacy-safe. |
| Rollback | Revert della patch locale in `PreGenerateView.swift`; nessun dato/schema coinvolto. |
| Stop rule specifica | Stop se serve cambiare logica di mapping colonne, parser, generazione HistoryEntry o modello sessione. |
| M102 collegati | M102-03, M102-13, M102-15, M102-17 |
| CA collegati | CA-T102-01, CA-T102-05, CA-T102-06, CA-T102-07, CA-T102-08, CA-T102-10, CA-T102-11, CA-T102-13, CA-T102-14, CA-T102-15, CA-T102-16, CA-T102-17 |

## Check S102-C

| Check | Esito | Evidenza |
|-------|-------|----------|
| Whitespace diff | PASS | `git diff --check` exit 0, nessun output. |
| Build Release + launch simulator | PASS | XcodeBuildMCP `build_run_sim`, Release, iPhone 17 Pro; warnings/errors: 0. |
| Localizzazioni plist | PASS | `plutil -lint` su IT/EN/ES/zh-Hans: OK; nessuna stringa nuova. |
| XCTest diretto PreGenerate | NOT RUN | Nessun test esistente mirato alla vista; logica ViewModel/parser non modificata. |
| Walkthrough PreGenerate con dati sintetici | NOT RUN | Non eseguito manualmente; coperto parzialmente da static review, build finale e full XCTest Debug. |

## DoR S102-D

| Campo | Valore |
|-------|--------|
| Slice attiva | **S102-D — Griglia generata, header, scroll, azioni bulk leggibili** |
| UX target | Migliorare orientamento nella griglia senza rifare la tabella: header coerente, righe con stati distinguibili non solo dal colore, azione bulk completa/incompleta visibile oltre al menu. |
| File reali da toccare | `iOSMerchandiseControl/GeneratedView.swift`; evidence TASK-102. |
| File vietati | Android/Kotlin; Supabase SQL/RLS/policy/grant/migration; `project.pbxproj`; `Package.resolved`; modelli SwiftData; servizi sync/import/export; TASK-103. |
| Touch budget | 1 file Swift principale; nessuna nuova stringa prevista. Stop se serve refactor tabella o virtualizzazione diversa. |
| Evidenze minime | `MATRIX-M102-results.md` M102-04/M102-13/M102-15/M102-16/M102-17; traceability aggiornata; Release build+launch. |
| Rollback | Revert delle modifiche locali in `GeneratedView.swift`; nessun dato/schema coinvolto. |
| Stop rule specifica | Stop se serve cambiare struttura dati `data/editable/complete`, autosave, sync, import analysis o scanner. |
| M102 collegati | M102-04, M102-13, M102-15, M102-16, M102-17 |
| CA collegati | CA-T102-01, CA-T102-05, CA-T102-06, CA-T102-07, CA-T102-10, CA-T102-11, CA-T102-13, CA-T102-14, CA-T102-15, CA-T102-16, CA-T102-17 |

## Check S102-D

| Check | Esito | Evidenza |
|-------|-------|----------|
| Whitespace diff | PASS | `git diff --check` exit 0, nessun output. |
| Build Release + launch simulator | PASS | XcodeBuildMCP `build_run_sim`, Release, iPhone 17 Pro; warnings/errors: 0. |
| Localizzazioni plist | PASS | `plutil -lint` su IT/EN/ES/zh-Hans: OK; nessuna stringa nuova. |
| Dataset/grid walkthrough | NOT RUN | Non eseguito manualmente; patch S102-D è UI-only locale e benchmark sintetici finali sono PASS. |

## DoR S102-E

| Campo | Valore |
|-------|--------|
| Slice attiva | **S102-E — Dettaglio riga, edit, entry manuale** |
| UX target | Rendere più prevedibili dettaglio riga e inserimento manuale: azione edit chiara, scanner nel form manuale con target adeguato, tastiere coerenti e CTA "aggiungi e continua" leggibile. |
| File reali da toccare | `iOSMerchandiseControl/GeneratedView.swift`; evidence TASK-102. |
| File vietati | Android/Kotlin; Supabase SQL/RLS/policy/grant/migration; `project.pbxproj`; `Package.resolved`; modelli SwiftData; servizi sync/import/export; TASK-103. |
| Touch budget | 1 file Swift principale; nessuna nuova stringa prevista. |
| Evidenze minime | `MATRIX-M102-results.md` M102-05/M102-06/M102-13/M102-15/M102-17; traceability aggiornata; Release build+launch. |
| Rollback | Revert locale dei sottoblocchi row detail/manual entry in `GeneratedView.swift`. |
| Stop rule specifica | Stop se serve cambiare persistenza manual entry, validazione business, scanner engine o modelli dati. |
| M102 collegati | M102-05, M102-06, M102-13, M102-15, M102-17 |
| CA collegati | CA-T102-01, CA-T102-05, CA-T102-06, CA-T102-08, CA-T102-10, CA-T102-13, CA-T102-14, CA-T102-15, CA-T102-16, CA-T102-17 |

## Check S102-E

| Check | Esito | Evidenza |
|-------|-------|----------|
| Whitespace diff | PASS | `git diff --check` exit 0, nessun output. |
| Build Release + launch simulator | PASS | XcodeBuildMCP `build_run_sim`, Release, iPhone 17 Pro; warnings/errors: 0. |
| Localizzazioni plist | PASS | `plutil -lint` su IT/EN/ES/zh-Hans: OK; nessuna stringa nuova. |
| Sheet runtime detail/manual entry | NOT RUN | Non eseguito manualmente; coperto da static review, build finale e full XCTest Debug. |

## DoR S102-F

| Campo | Valore |
|-------|--------|
| Slice attiva | **S102-F — Scanner inventario + database** |
| UX target | Offrire un fallback manuale chiaro quando lo scanner non può partire, mantenendo torcia/permessi/chiusura nativi e coerenti tra inventario, ricerca e database. |
| File reali da toccare | `iOSMerchandiseControl/BarcodeScannerView.swift`, callsite scanner in `GeneratedView.swift` e `DatabaseView.swift`, localizzazioni IT/EN/ES/zh-Hans per una CTA fallback; evidence TASK-102. |
| File vietati | Android/Kotlin; Supabase SQL/RLS/policy/grant/migration; `project.pbxproj`; `Package.resolved`; camera/session engine oltre UI fallback; modelli SwiftData; TASK-103. |
| Touch budget | Massimo 3 file Swift principali + 4 Localizable; nessuna nuova dipendenza. |
| Evidenze minime | `MATRIX-M102-results.md` M102-07/M102-13/M102-14/M102-15/M102-17; traceability aggiornata; Release build+launch; `plutil`. |
| Rollback | Revert scanner fallback API/callsites/localizzazioni; nessun dato/schema coinvolto. |
| Stop rule specifica | Stop se serve cambiare AVCapture session, permessi OS, scanner engine o introdurre flusso manuale business nuovo. |
| M102 collegati | M102-07, M102-13, M102-14, M102-15, M102-17 |
| CA collegati | CA-T102-01, CA-T102-04, CA-T102-05, CA-T102-06, CA-T102-10, CA-T102-12, CA-T102-13, CA-T102-14, CA-T102-15, CA-T102-16, CA-T102-17 |

## Check S102-F

| Check | Esito | Evidenza |
|-------|-------|----------|
| Whitespace diff | PASS | `git diff --check` exit 0, nessun output. |
| Build Release + launch simulator | PASS | XcodeBuildMCP `build_run_sim`, Release, iPhone 17 Pro; warnings/errors: 0. |
| Localizzazioni plist | PASS | `plutil -lint` su IT/EN/ES/zh-Hans: OK. |
| Duplicate localization keys | PASS | `awk` duplicate scan su `*.lproj/Localizable.strings`: nessun output. |
| Camera permission/runtime scanner | NOT RUN | Interazione scanner/camera non eseguita in questa slice; fallback verificato staticamente. |

## DoR S102-G

| Campo | Valore |
|-------|--------|
| Slice attiva | **S102-G — Cronologia sessioni** |
| UX target | Rendere Cronologia piu leggibile e iOS-native senza cambiare dati o routing: empty state utile, lista filtrata con stato chiaro e riepilogo scansionabile, dettaglio raggiungibile senza ambiguita. Le azioni esistenti edit/share/delete restano nei pattern nativi gia presenti. |
| File reali da toccare | `iOSMerchandiseControl/HistoryView.swift`, `iOSMerchandiseControl/{it,en,es,zh-Hans}.lproj/Localizable.strings`; evidence TASK-102. |
| File vietati | Android/Kotlin; Supabase SQL/RLS/policy/grant/migration; `project.pbxproj`; `Package.resolved`; modelli SwiftData; export/import services; `GeneratedView.swift`; TASK-103. |
| Touch budget | 1 file Swift principale + 4 Localizable per copy filtro/status; nessun modello/servizio. |
| Evidenze minime | `MATRIX-M102-results.md` M102-08/M102-13/M102-15/M102-17; traceability aggiornata; Release build+launch; nota su localizzazioni se non toccate. |
| Rollback | Revert locale delle modifiche in `HistoryView.swift`; nessun dato/schema coinvolto. |
| Stop rule specifica | Stop se serve cambiare modello `HistoryEntry`, export XLSX, routing `GeneratedView`, filtri date o logica sync. |
| M102 collegati | M102-08, M102-13, M102-15, M102-17 |
| CA collegati | CA-T102-01, CA-T102-04, CA-T102-06, CA-T102-07, CA-T102-08, CA-T102-10, CA-T102-11, CA-T102-13, CA-T102-14, CA-T102-15, CA-T102-16, CA-T102-17 |

## Check S102-G

| Check | Esito | Evidenza |
|-------|-------|----------|
| Whitespace diff | PASS | `git diff --check` exit 0, nessun output dopo fix trailing whitespace. |
| Build Release + launch simulator | PASS | XcodeBuildMCP `build_run_sim`, Release, iPhone 17 Pro; warnings/errors: 0. |
| Screenshot privacy-safe | PASS | `screenshots/S102-G-history-empty-after.jpg`; Cronologia vuota, nessun dato reale. |
| Localizzazioni plist | PASS | `plutil -lint` su IT/EN/ES/zh-Hans: OK. |
| Duplicate localization keys | PASS | `awk` duplicate scan su `*.lproj/Localizable.strings`: nessun output. |
| XCTest localizzazioni | PASS | `LocalizationCoverageTests` in Debug: 8 passed / 0 failed / 0 skipped. Warning noti in test non toccati. |
| Runtime detail/lista con entry sintetica | NOT RUN | Non eseguito manualmente; patch S102-G non cambia persistenza/export/detail routing. |

## DoR S102-H

| Campo | Valore |
|-------|--------|
| Slice attiva | **S102-H — Database: prodotti, fornitori, categorie, storico prezzi, import/export** |
| UX target | Rendere Database piu scansionabile e iOS-native: ricerca/empty state chiari, row prodotto con gerarchia stabile, form prodotto con validazione utente e tastiere coerenti, storico prezzi piu leggibile, import/export con azioni nominate. |
| File reali da toccare | `iOSMerchandiseControl/DatabaseView.swift`, `iOSMerchandiseControl/EditProductView.swift`, `iOSMerchandiseControl/ProductPriceHistoryView.swift`, `iOSMerchandiseControl/{it,en,es,zh-Hans}.lproj/Localizable.strings`; evidence TASK-102. |
| File vietati | Android/Kotlin; Supabase SQL/RLS/policy/grant/migration; `project.pbxproj`; `Package.resolved`; SwiftData models; `ProductImportCore`; `ProductImportViewModel`; XLSX parser/writer logic salvo build blocker; TASK-103. |
| Touch budget | Massimo 3 file Swift UI principali + 4 Localizable; nessuna nuova dipendenza; nessun cambio schema/persistenza. |
| Evidenze minime | `MATRIX-M102-results.md` M102-09/M102-10/M102-11/M102-13/M102-14/M102-15/M102-16/M102-17; traceability aggiornata; Release build+launch; `plutil`/duplicate scan. |
| Rollback | Revert locale delle patch UI/localizzazioni S102-H; nessuna migrazione dati o modifica backend. |
| Stop rule specifica | Stop se serve cambiare schema SwiftData, logica import/export, ProductImportCore, sync outbox, Supabase o modello prezzi. |
| M102 collegati | M102-09, M102-10, M102-11, M102-13, M102-14, M102-15, M102-16, M102-17 |
| CA collegati | CA-T102-01, CA-T102-03, CA-T102-04, CA-T102-05, CA-T102-06, CA-T102-07, CA-T102-08, CA-T102-09, CA-T102-10, CA-T102-11, CA-T102-12, CA-T102-13, CA-T102-14, CA-T102-15, CA-T102-16, CA-T102-17 |

## Check S102-H

| Check | Esito | Evidenza |
|-------|-------|----------|
| Whitespace diff | PASS | `git diff --check` exit 0, nessun output. |
| Build Release + launch simulator | PASS | XcodeBuildMCP `build_run_sim`, Release, iPhone 17 Pro; warnings/errors: 0. |
| Screenshot privacy-safe | PASS | `screenshots/S102-H-database-empty-after.jpg`; Database vuoto, nessun dato reale. |
| Localizzazioni plist | PASS | `plutil -lint` su IT/EN/ES/zh-Hans: OK. |
| Duplicate localization keys | PASS | `awk` duplicate scan su `*.lproj/Localizable.strings`: nessun output. |
| XCTest localizzazioni | PASS | `LocalizationCoverageTests` in Debug: 8 passed / 0 failed / 0 skipped. Warning noti in test non toccati. |
| CRUD/import/export runtime con dati sintetici | NOT RUN | Non eseguito manualmente; patch S102-H non modifica parser/writer/import core/persistenza. |
| Dataset database medio/grande | PASS WITH NOTES | Benchmark sintetici TASK-089/TASK-100 PASS nel full XCTest finale; patch S102-H e' UI-only con row helper locali. |

## DoR S102-I

| Campo | Valore |
|-------|--------|
| Slice attiva | **S102-I — Opzioni, sync Release gia esistente, stati trasversali, a11y/l10n, review finale** |
| UX target | Migliorare ergonomia e accessibilità della card sync Release gia esistente senza cambiare logica, trigger, backend o copy sostanziale: azioni piu tappabili, stato running leggibile e review sheet piu coerente. |
| File reali da toccare | `iOSMerchandiseControl/OptionsView.swift`; evidence TASK-102. Localizzazioni solo se indispensabili. |
| File vietati | Android/Kotlin; Supabase SQL/RLS/policy/grant/migration; `project.pbxproj`; `Package.resolved`; SwiftData models; `SupabaseManualSyncViewModel.swift`; servizi Supabase/sync; TASK-103. |
| Touch budget | 1 file Swift UI principale; nessuna nuova stringa prevista; nessun cambio a view model o servizi. |
| Evidenze minime | `MATRIX-M102-results.md` M102-12/M102-13/M102-14/M102-15/M102-16/M102-17; traceability aggiornata; Release build+launch; final review checklist. |
| Rollback | Revert locale delle modifiche in `OptionsView.swift`; nessun dato/schema/backend coinvolto. |
| Stop rule specifica | Stop se serve cambiare run mode sync, trigger automatici, view model, servizi Supabase, backend o flussi TASK-103. |
| M102 collegati | M102-12, M102-13, M102-14, M102-15, M102-16, M102-17 |
| CA collegati | CA-T102-01, CA-T102-02, CA-T102-03, CA-T102-04, CA-T102-06, CA-T102-07, CA-T102-08, CA-T102-10, CA-T102-13, CA-T102-14, CA-T102-15, CA-T102-16, CA-T102-17 |

## Check S102-I

| Check | Esito | Evidenza |
|-------|-------|----------|
| Whitespace diff | PASS | `git diff --check` exit 0, nessun output. |
| Build Release + launch simulator | PASS | XcodeBuildMCP `build_run_sim`, Release, iPhone 17 Pro; warnings/errors: 0. |
| Screenshot privacy-safe | PASS | `screenshots/S102-I-options-sync-after.jpg`; Opzioni/sync signed-out, nessun dato reale. |
| Localizzazioni plist | PASS | `plutil -lint` su IT/EN/ES/zh-Hans: OK; nessuna stringa nuova in S102-I. |
| Duplicate localization keys | PASS | `awk` duplicate scan su `*.lproj/Localizable.strings`: nessun output. |
| Sync reale/manuale cloud | NOT RUN | Non eseguito per evitare write/read su dati backend reali; patch S102-I non modifica view model, servizi o run mode. |
