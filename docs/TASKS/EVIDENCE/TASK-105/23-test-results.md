# TASK-105 Evidence 23 - Test Results

## Build

| Comando | Stato | Sintesi |
|---------|-------|---------|
| `xcodebuild build -quiet -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Release -destination 'platform=iOS Simulator,id=<redacted>'` | PASS | Exit 0. |
| XcodeBuildMCP Release build/run simulator | PASS | Build, install, launch e screenshot smoke su iPhone 17 Pro simulator. |
| Physical iPhone Debug build/install/launch | PASS | Build, `devicectl install`, `devicectl launch` exit 0 su iPhone reale redatto. |

## Test automatici

| Suite | Stato | Sintesi |
|-------|-------|---------|
| `Task105RealOpsClosureTests` simulator | PASS | 5 pass + 1 skip atteso camera fisica: small import 30 righe, ExcelSessionViewModel load, export round-trip, large import 5.000, SwiftData batched apply. |
| `Task105RealOpsClosureTests` physical iPhone | PASS | 6/6: include camera autorizzata + capability metadata barcode su hardware reale. |
| `ExcelAnalyzerHTMLParsingTests` selezionati | PASS | Parser regressions PASS. |
| `Task089LargeDatasetBenchmarkTests` selezionati | PASS | Export medium products/full DB PASS. |
| `Task100LargeDatasetAcceptanceTests` import/export medium | PASS | Medium import/export benchmarks PASS. |

## Simulator smoke

| Flusso | Stato | Sintesi |
|--------|-------|---------|
| Launch Home | PASS | Home e tab principali presenti. |
| Database tab | PASS | Search/import/export/new/scanner/empty state presenti. |
| Scanner unavailable | PASS | Fallback manuale visibile. |
| Scanner fallback focus | PASS_AFTER_FIX | Dopo tap fallback, search field e keyboard visibili. |
| Options | PASS | Theme/Language e layout base visibili senza overlap evidente. |

## Mini-run reale finale owner/operatore

| Flusso | Stato | Sintesi |
|--------|-------|---------|
| Live scan iPhone fisico | PASS | Owner/operator confirmation received, identity redacted. |
| Scanner app flow | PASS | Barcode trovato/non trovato e fallback manuale confermati. |
| Import Files | PASS | Confermato da owner/operatore; dettagli file redatti. |
| iCloud Drive / Share Sheet / destinazione equivalente | PASS_NA | PASS se usata nel flusso reale; N/A accettata se non usata. |
| Export destinazione reale negozio | PASS | Confermato da owner/operatore; destinazione redatta. |
| Apertura/reimport/verifica integrita' export | PASS | Confermato da owner/operatore; harness automatico gia' PASS. |
| Annulla/retry dove applicabile | PASS | Confermato da owner/operatore. |
| Accettazione operatore finale | PASS | Owner/operator confirmation received, identity redacted. |

## Supabase

| Check | Stato |
|-------|-------|
| Project/schema/RLS/policy read-only | PASS |
| Security/performance advisors read-only | PASS_WITH_NOTES |
| Prefix counts TASK104/TASK105 read-only | PASS |
| Mutazioni DB | NOT_RUN per scelta safety; nessuna necessaria |

Review read-only: `TASK105%` remoto osservato a 0 su supplier/category/product; TASK104_PASS2 retention confermata su supplier/category/product.

## Warnings

Regression slice ha mostrato warning legacy in test non modificati da TASK-105. Nessun warning nuovo attribuito ai file TASK-105 modificati. Un primo rerun regression e' fallito per lock build.db dovuto a due `xcodebuild` concorrenti; rerun seriale PASS.

## Stato

PASS / DONE_ACCEPTANCE_CONFIRMED.
