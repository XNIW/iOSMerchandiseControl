# TASK-111 — Post-review pending supplier/category create UX

**Data:** 2026-05-17 15:22 -0400  
**Tipo:** micro-fix post-review richiesto dall'utente  
**Stato task:** TASK-111 resta **DONE / REVIEW PASS WITH NOTES**  
**TASK-112:** **NON aperto**  
**TASK-109:** resta **BLOCKED / SOSPESO**  
**TASK-110:** resta **DONE**

## Scopo

Correggere la UX di `PreGenerateView`: testo valido scritto nei campi fornitore/categoria deve essere considerato selezione valida anche se non ancora presente nel database. La creazione reale resta differita al tap su **Generar inventario**, per evitare record accidentali durante digitazione, blur, keyboard done o cancel/back.

## Supabase / sync

- **NO SUPABASE MUTATION**
- **NO SYNC IMPACT**
- **LOCAL SWIFTDATA ONLY** per iOS.
- Android audit/patch locale su Room/repository; nessuna modifica a sync/cloud.

## File modificati

### iOS

- `iOSMerchandiseControl/PreGenerateView.swift` — stato visuale pending-create, summary fornitore/categoria e enable generazione con testo nuovo valido.
- `iOSMerchandiseControl/ExcelSessionViewModel.swift` — helper testabili di normalizzazione/risoluzione e creazione differita con dedupe case/trim.
- `iOSMerchandiseControlTests/Task111ExcelImportParityTests.swift` — test pending-create, dedupe e creazione solo su generate.
- `iOSMerchandiseControl/en.lproj/Localizable.strings`
- `iOSMerchandiseControl/it.lproj/Localizable.strings`
- `iOSMerchandiseControl/es.lproj/Localizable.strings`
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`

### Android

Audit statico: Android aveva lo stesso problema UX nella schermata PreGenerate; quindi patch mirata applicata.

- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/main/java/com/example/merchandisecontrolsplitview/ui/screens/PreGenerateScreen.kt` — resolver pending-create e summary/status per nuovi fornitore/categoria.
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/main/java/com/example/merchandisecontrolsplitview/data/InventoryRepository.kt` — dedupe `addSupplier` / `addCategory` con chiave normalizzata.
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/main/res/values*/strings.xml` — localizzazioni status/summary pending-create.
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/test/java/com/example/merchandisecontrolsplitview/ui/screens/PreGenerateEntityResolutionTest.kt` — test resolver pending/existing/empty.
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/test/java/com/example/merchandisecontrolsplitview/data/DefaultInventoryRepositoryTest.kt` — test dedupe supplier/category case/trim.

## Comportamento verificato

| Caso | Esito |
|---|---|
| Campo vuoto | Non valido; summary mostra `Sin seleccionar` / not selected. |
| Nome esistente | Riconosciuto con trim/case-insensitive; usa record esistente. |
| Nome nuovo | Stato pending-create valido; status mostra nuovo fornitore/categoria. |
| Summary con nome nuovo | Mostra `Nuevo/Nueva/New/Nuovo...: <nome>` invece di `Sin seleccionar`. |
| Generazione con pending | Crea record mancanti e procede con generazione. |
| Bottone “Aggiungi nuovo...” | Resta disponibile e continua a funzionare. |
| Cambio testo dopo pending | Stato rivalutato da helper; pending/existing/empty aggiornati. |
| Cambio da nuovo a esistente | Usa record esistente, non mantiene pending sporco. |
| Differenze maiuscole/spazi | Non duplicano supplier/category. |
| Reload/append file | Stato pending deriva da testo/query correnti; nessuna creazione implicita. |
| Back/cancel | Non crea record, perche' la persistenza avviene solo in generate. |

## Strategia tecnica

- `normalizedRelationKey` / resolver relation state per separare stato UI da persistenza.
- Stato `pendingCreate` solo derivato dall'input non vuoto senza match normalizzato.
- `Generate` abilitato quando supplier e category sono `existing` oppure `pendingCreate`.
- `ensureSupplierExists` / `ensureCategoryExists` cercano di nuovo nel database al momento della generazione e riusano eventuali record equivalenti creati nel frattempo.
- Creazione DB mai eseguita da `body`, render, blur o digitazione.

## Check iOS

| Check | Esito |
|---|---|
| Debug build simulator | PASS, 0 warnings/errors (`build_sim_2026-05-17T19-15-32-643Z_pid8749_ea6fc621.log`). |
| Release build simulator | PASS, 0 warnings/errors (`build_sim_2026-05-17T19-16-25-311Z_pid8749_41cbef01.log`). |
| Release build + run smoke simulator | PASS, 0 warnings/errors (`build_run_sim_2026-05-17T19-17-52-320Z_pid8749_92b791ae.log`). |
| `Task111ExcelImportParityTests` | PASS 12/12 (`test_sim_2026-05-17T19-15-48-310Z_pid8749_55f4f85b.log`). |
| `ExcelAnalyzerHTMLParsingTests` | PASS 9/9 (`test_sim_2026-05-17T19-18-17-523Z_pid8749_26192a50.log`). |
| `plutil -lint` localizzazioni EN/IT/ES/ZH | PASS. |
| `git diff --check` | PASS. |

Nota: durante la compilazione del target test Xcode ha riportato warning legacy in file non modificati (`Task097RuntimeSmokeTests`, `SyncEventOutboxDrainDebugViewModelTests`). Le build app Debug/Release hanno riportato 0 warnings/errors.

## Check Android

| Check | Esito |
|---|---|
| `PreGenerateEntityResolutionTest` | PASS (`BUILD SUCCESSFUL`). |
| `DefaultInventoryRepositoryTest` supplier/category mirati | PASS (`BUILD SUCCESSFUL`). |
| `ExcelViewModelTest` | PASS (`BUILD SUCCESSFUL`). |
| `ExcelUtilsTest` | PASS (`BUILD SUCCESSFUL`). |
| `./gradlew assembleDebug` | PASS (`BUILD SUCCESSFUL in 2s`). |
| `./gradlew lint` | PASS (`BUILD SUCCESSFUL in 27s`). |
| `git diff --check` | PASS. |

Nota: Gradle/AGP ha emesso warning di configurazione gia' presenti (`android.builtInKotlin`, `android.newDsl`, legacy variant API, plugin Kotlin Android deprecato). Nessun warning Kotlin nuovo introdotto dal codice modificato.

## Limiti residui

- Smoke iOS PreGenerate con file picker reale non eseguito: il flusso e' coperto da build, test mirati e smoke app simulator; la selezione file manuale resta limite gia' documentato in TASK-111.
- Nessun device fisico iOS/Android usato in questo micro-fix.
- Nessuna validazione Supabase, intenzionalmente fuori scope.
