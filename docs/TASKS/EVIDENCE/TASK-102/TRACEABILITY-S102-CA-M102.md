# Traceability S102 -> CA -> M102

## Slice freeze

| Slice | Stato | File target | File letti/controllati | File vietati | CA | M102 |
|-------|-------|-------------|------------------------|--------------|----|------|
| S102-A | PASS WITH NOTES | `iOSMerchandiseControl/InventoryHomeView.swift` | `iOSMerchandiseControl/ContentView.swift`, `iOSMerchandiseControl/InventoryHomeView.swift`, localizzazioni inventory.home/tab | Android/Kotlin; Supabase SQL/RLS/migration; `project.pbxproj`; `Package.resolved`; SwiftData models; TASK-103 | CA-T102-01, 02, 03, 04, 06, 07, 10, 11, 13, 14, 15, 16, 17 | M102-01, 13, 14, 15, 17 |
| S102-B | PASS WITH NOTES | `iOSMerchandiseControl/InventoryHomeView.swift` | `iOSMerchandiseControl/ExcelSessionViewModel.swift`, `iOSMerchandiseControl/InventoryHomeView.swift`, import localizations | Android/Kotlin; Supabase schema/RLS; `project.pbxproj`; `Package.resolved`; parser `ExcelAnalyzer`; TASK-103 | CA-T102-01, 05, 06, 10, 13, 14, 15, 16, 17 | M102-02, 13, 15, 17 |
| S102-C | PASS WITH NOTES | `iOSMerchandiseControl/PreGenerateView.swift` | `iOSMerchandiseControl/PreGenerateView.swift`, `ExcelSessionViewModel` role helpers via read | Android/Kotlin; Supabase schema/RLS; `project.pbxproj`; `Package.resolved`; `ExcelAnalyzer`; SwiftData models; TASK-103 | CA-T102-01, 05, 06, 07, 08, 10, 11, 13, 14, 15, 16, 17 | M102-03, 13, 15, 17 |
| S102-D | PASS WITH NOTES | `iOSMerchandiseControl/GeneratedView.swift` | `GeneratedView.swift` inventory section/grid/header/row/floating actions | Android/Kotlin; Supabase schema/RLS; `project.pbxproj`; `Package.resolved`; SwiftData models; sync/import/export services; TASK-103 | CA-T102-01, 05, 06, 07, 10, 11, 13, 14, 15, 16, 17 | M102-04, 13, 15, 16, 17 |
| S102-E | PASS WITH NOTES | `iOSMerchandiseControl/GeneratedView.swift` | `GeneratedView.swift` row detail, `ManualEntrySheet`, row edit callsites | Android/Kotlin; Supabase schema/RLS; `project.pbxproj`; `Package.resolved`; SwiftData models; sync/import/export services; TASK-103 | CA-T102-01, 05, 06, 08, 10, 13, 14, 15, 16, 17 | M102-05, 06, 13, 15, 17 |
| S102-F | PASS WITH NOTES | `BarcodeScannerView.swift`, `GeneratedView.swift`, `DatabaseView.swift`, `*.lproj/Localizable.strings` | ScannerView fallback, inventory/database/search callsites | Android/Kotlin; Supabase schema/RLS; `project.pbxproj`; `Package.resolved`; AVCapture engine changes; SwiftData models; TASK-103 | CA-T102-01, 04, 05, 06, 10, 12, 13, 14, 15, 16, 17 | M102-07, 13, 14, 15, 17 |
| S102-G | PASS WITH NOTES | `HistoryView.swift`, `*.lproj/Localizable.strings` | `HistoryView.swift`, `HistoryEntry.swift`, history localizations via read | Android/Kotlin; Supabase schema/RLS; `project.pbxproj`; `Package.resolved`; SwiftData models; export/import services; TASK-103 | CA-T102-01, 04, 06, 07, 08, 10, 11, 12, 13, 14, 15, 16, 17 | M102-08, 13, 14, 15, 17 |
| S102-H | PASS WITH NOTES | `DatabaseView.swift`, `EditProductView.swift`, `ProductPriceHistoryView.swift`, `*.lproj/Localizable.strings` | `DatabaseView.swift`, `EditProductView.swift`, `ProductPriceHistoryView.swift`, `ImportAnalysisView.swift`, `ProductImportViewModel.swift`, database/product localizations | Android/Kotlin; Supabase schema/RLS; `project.pbxproj`; `Package.resolved`; SwiftData models; `ProductImportCore`; parser/writer business logic; TASK-103 | CA-T102-01, 03, 04, 05, 06, 07, 08, 09, 10, 11, 12, 13, 14, 15, 16, 17 | M102-09, 10, 11, 13, 14, 15, 16, 17 |
| S102-I | PASS WITH NOTES | `OptionsView.swift` | `OptionsView.swift`, `SupabaseManualSyncViewModel.swift`, manual sync localizations via read | Android/Kotlin; Supabase schema/RLS; `project.pbxproj`; `Package.resolved`; SwiftData models; sync services/view model; TASK-103 | CA-T102-01, 02, 03, 04, 06, 07, 08, 10, 13, 14, 15, 16, 17 | M102-12, 13, 14, 15, 16, 17 |

## DoR S102-A summary

- UX target: Home inventario con una CTA primaria chiara, azioni manuali secondarie, stato leggibile, navigazione radice stabile.
- Touch budget: massimo 2 file Swift principali; S102-A parte con `InventoryHomeView.swift` come unico Swift target.
- Rollback: revert del file Swift e di eventuali stringhe S102-A; nessun dato/schema coinvolto.
- Stop rule: stop se serve refactor routing globale, nuovo modello tab, nuova dipendenza o modifica schema.

## S102-A result

| File | Azione | Simboli toccati |
|------|--------|-----------------|
| `iOSMerchandiseControl/InventoryHomeView.swift` | Modificato | `loadedDataRowCount`, `homeStatusIcon`, `homeStatusTint`, `homeStatusTitle`, `startManualInventory(autoOpenScanner:)`, `headerSection`, `statusSection`, `manualInventoryButton`, `quickScannerButton`, `body` layout |
| `docs/TASKS/EVIDENCE/TASK-102/*` | Creato/aggiornato | Evidence pack, DoR S102-A, matrice, traceability, note |
| `docs/TASKS/TASK-102-release-polish-ux-ios.md` | Aggiornato | Campi globali + sezione Execution |
| `docs/MASTER-PLAN.md` | Aggiornato | Stato storico execution/review TASK-102; handoff READY FOR FINAL REVIEW, poi chiusura DONE nel pass finale |

Conferma scope S102-A: nessun Android/Kotlin, nessun Supabase SQL/RLS/migration, nessun `project.pbxproj`, nessun `Package.resolved`, nessun modello SwiftData, nessuna nuova dipendenza, nessun TASK-103.

## S102-B result

| File | Azione | Simboli toccati |
|------|--------|-----------------|
| `iOSMerchandiseControl/InventoryHomeView.swift` | Modificato | `unsupportedFileDescription(for:)`, `handleImportFailure(_:)`, `loadSelectedFiles(_:requiresSecurityScopedAccess:)`, `loadExternalFile(_:)`, `fileImporter` completion |

Conferma scope S102-B: nessun Android/Kotlin, nessun Supabase SQL/RLS/migration, nessun parser `ExcelAnalyzer`, nessun `project.pbxproj`, nessun `Package.resolved`, nessun modello SwiftData, nessuna nuova dipendenza, nessun TASK-103.

## S102-C result

| File | Azione | Simboli toccati |
|------|--------|-----------------|
| `iOSMerchandiseControl/PreGenerateView.swift` | Modificato | `body` preview/columns/generate section, `columnBulkActions`, `ColumnRecognitionBadge.body` |

Conferma scope S102-C: nessun Android/Kotlin, nessun Supabase SQL/RLS/migration, nessun `ExcelAnalyzer`, nessun `ExcelSessionViewModel`, nessun `project.pbxproj`, nessun `Package.resolved`, nessun modello SwiftData, nessuna nuova dipendenza, nessun TASK-103.

## S102-D result

| File | Azione | Simboli toccati |
|------|--------|-----------------|
| `iOSMerchandiseControl/GeneratedView.swift` | Modificato | `inventoryStatusView`, `inventoryBulkCompletionButton`, `inventoryHeaderView`, `inventoryRowView(_:)`, `rowBorderColor(...)`, `rowBorderWidth(...)` |

Conferma scope S102-D: nessun Android/Kotlin, nessun Supabase SQL/RLS/migration, nessun modello SwiftData, nessun servizio sync/import/export, nessuna nuova dipendenza, nessun TASK-103.

## S102-E result

| File | Azione | Simboli toccati |
|------|--------|-----------------|
| `iOSMerchandiseControl/GeneratedView.swift` | Modificato | `ManualEntrySheet.body`, row detail actions section |

Conferma scope S102-E: nessun Android/Kotlin, nessun Supabase SQL/RLS/migration, nessun modello SwiftData, nessun servizio sync/import/export, nessuna nuova dipendenza, nessun TASK-103.

## S102-F result

| File | Azione | Simboli toccati |
|------|--------|-----------------|
| `iOSMerchandiseControl/BarcodeScannerView.swift` | Modificato | `ScannerView` fallback API, `ScannerFallbackView`, `handleFallbackRequested()` |
| `iOSMerchandiseControl/GeneratedView.swift` | Modificato | Scanner callsite inventario, manual entry, search sheet |
| `iOSMerchandiseControl/DatabaseView.swift` | Modificato | Scanner callsite database |
| `iOSMerchandiseControl/*.lproj/Localizable.strings` | Modificato | `scanner.action.enter_manually` |

Conferma scope S102-F: nessun Android/Kotlin, nessun Supabase SQL/RLS/migration, nessun cambio ad AVCapture session engine, nessun modello SwiftData, nessuna nuova dipendenza, nessun TASK-103.

## Review finale / fix mirati 2026-05-12 15:52 -0400

| File | Azione | CA/M102 collegati | Motivo |
|------|--------|-------------------|--------|
| `iOSMerchandiseControl/GeneratedView.swift` | Review-fix | CA-T102-06, CA-T102-10, CA-T102-15; M102-07, M102-13, M102-17 | Fallback scanner principale reso realmente azionabile: input manuale per entry manuali, ricerca manuale per inventari importati, nessun conflitto con reopen dettaglio riga. |
| `iOSMerchandiseControl/DatabaseView.swift` | Review-fix | CA-T102-10, CA-T102-11, CA-T102-15; M102-09, M102-13 | Row prodotto usa `.contain` invece di `.combine` per preservare le azioni interne accessibili. |
| `iOSMerchandiseControl/EditProductView.swift` | Review-fix | CA-T102-05, CA-T102-06, CA-T102-10; M102-09, M102-13 | Validazione barcode non dipende piu dal confronto fragile con testo localizzato. |

Conferma scope review-fix: nessun Android/Kotlin, nessun Supabase SQL/RLS/policy/grant/migration, nessuna nuova dipendenza, nessun modello SwiftData, nessun TASK-103.

## Chiusura finale / fix mirati 2026-05-12 16:46 -0400

| File | Azione | CA/M102 collegati | Motivo |
|------|--------|-------------------|--------|
| `iOSMerchandiseControl/ProductPriceHistoryView.swift` | Final-fix | CA-T102-07, CA-T102-08, CA-T102-10, CA-T102-15; M102-10, M102-13, M102-15, M102-17 | Aggiunta chiusura toolbar esplicita allo storico prezzi aperto come sheet, evitando un blocco UX/a11y durante il CRUD smoke. |
| `iOSMerchandiseControl/ContentView.swift` | Final-fix | CA-T102-06, CA-T102-10, CA-T102-15, CA-T102-17; M102-01, M102-09, M102-13, M102-15, M102-17 | Evitato overlay del banner root `blockedAuth` sulla toolbar Database a Dynamic Type extra-large; il recupero sign-in resta nella card sync di Opzioni. |
| `docs/TASKS/EVIDENCE/TASK-102/*` | Aggiornato | CA-T102-01, CA-T102-13, CA-T102-14, CA-T102-17; M102-01...17 | Evidenze riallineate all'ultimo pass manuale Simulator e alla chiusura DONE. |

Conferma scope final-fix: nessun Android/Kotlin, nessun Supabase SQL/RLS/policy/grant/migration, nessuna nuova dipendenza, nessun modello SwiftData, nessun TASK-103.
