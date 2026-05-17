# TASK-111 — 01 iOS Code Map

Data: 2026-05-17  
Fase: EXECUTION

## OBSERVED — File audit obbligatori

| File | Ruolo osservato | Stato TASK-111 |
|---|---|---|
| `InventoryHomeView.swift` | Entry import file Excel/HTML e manual inventory. | Smoke simulator Home OK. Nessuna patch necessaria. |
| `PreGenerateView.swift` | Mapping/confidence/override colonne prima della generazione. | Esistono validation snapshot, ignore warnings, selection/override; nessuna patch runtime necessaria. |
| `ExcelSessionViewModel.swift` | Lettura `.xlsx`, HTML Excel, fallback `.xls`, alias, header/data analysis, background loading. | Audit: gia' background (`Task.detached`), alias estesi, HTML table selection. Gap numerico/apply gestito in core import. |
| `ExcelLegacyReader.m/.h` | Bridge libxls per `.xls` legacy. | Audit: percorso legacy presente; copertura runtime legacy non rieseguita in questo pass. |
| `GeneratedView.swift` | Griglia generata, search/scanner, modifica/export inventory. | Smoke statico non patchato; preservate feature Android/iOS esistenti. |
| `ImportAnalysisView.swift` | Preview import, warnings/errors, edit sheet, apply UX. | PATCH: summary rows, filter chips, sticky CTA, export warnings, duplicate policy copy, old price fields nel draft. |
| `ProductImportViewModel.swift` | Adapter legacy/import mapped rows verso `ProductImportCore`. | Usa core condiviso; nessuna patch necessaria. |
| `ProductImportCore.swift` | Parser/analyzer/apply core SwiftData. | PATCH principale: numeri locali/currency/scientific, validazioni, duplicati, old/current price, resolver case-insensitive/idempotenza ProductPrice. |
| `DatabaseView.swift` | Import full DB/products, pipeline background, apply batch, pending changes. | Audit: `Task.detached`, save batch 250, progress throttled, cancel points; nessuna patch necessaria. |
| `InventorySyncService.swift` | Sync inventory quantity/history. | Audit no direct TASK-111 patch. |
| `InventoryXLSXExporter.swift` | Export XLSX grid. | Regression export PASS via TASK-105. |
| `Models.swift` | SwiftData Product/Supplier/Category/ProductPrice. | Audit: unique name/barcode; resolver patched senza migration. |
| `HistoryEntry.swift` | Inventory history model. | Audit no direct TASK-111 patch. |
| `iOSMerchandiseControlTests/*` | Regression and fixture coverage. | PATCH: `Task111ExcelImportParityTests.swift`, TASK-111 fixture notes/HTML. |

## OBSERVED — Hotspots post-patch

- `ProductImportCore.swift:33` robust numeric parser.
- `ProductImportCore.swift:66` import analyzer.
- `ProductImportCore.swift:268` ProductPrice history create with previous/current sources.
- `ProductImportCore.swift:349` supplier/category relation key.
- `ProductImportCore.swift:512` local alias map.
- `ProductImportCore.swift:828` SwiftData resolver.
- `ImportAnalysisView.swift:236` filter model.
- `ImportAnalysisView.swift:421` sticky apply bar.
- `ImportAnalysisView.swift:503` filter chips.
- `ImportAnalysisView.swift:863` warning export.

## INFERRED — MainActor/performance boundary

- Parse/analyze/apply heavy paths already run off MainActor in `DatabaseView.swift:380`, `DatabaseView.swift:577`.
- Apply saves in chunks (`importSaveBatchSize = 250`) and reports progress with throttling (`DatabaseView.swift:1283`).
- TASK-111 patch keeps business logic in `ProductImportCore`, not in SwiftUI rows.

## NOT_RUN

- Real `.xls` shop file runtime smoke: not run; legacy reader path audited and existing build covers bridge compilation.
- Full manual import from Files picker: not run; simulator smoke stayed inside launched app Home/Database/Options.
