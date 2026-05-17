# TASK-111 — Post-review column default selection micro-fix

**Data:** 2026-05-17 14:35 -0400  
**Tipo:** TASK-111 MICRO-FIX / post-review adjustment  
**Stato TASK-111:** resta **DONE / Chiusura — REVIEW PASS WITH NOTES**  
**Nuovo task:** **non aperto** (`TASK-112` non creato)

## Obiettivo

Allineare iOS e Android sul default delle colonne in PreGenerate / preview Excel:

- colonne riconosciute / alias / pattern / inferred: selezionate di default;
- colonne obbligatorie: selezionate e protette;
- colonne non identificate / da rivedere: visibili ma non selezionate di default;
- toggle manuale ancora disponibile;
- preview rapida ancora comprensiva delle colonne non selezionate.

## File modificati

### iOS

- `iOSMerchandiseControl/ExcelSessionViewModel.swift`
  - aggiunto helper testabile `defaultIsIncluded(for:)` / `defaultColumnSelections(for:)`;
  - `load(from:in:)` inizializza `selectedColumns` con default per mapping, non tutto `true`;
  - `clearColumnRole` porta una colonna non essenziale a OFF;
  - `setColumnRole` porta una colonna riconosciuta a ON;
  - `preGeneratePreviewColumnIndices` espone tutti gli indici per la preview.
- `iOSMerchandiseControl/PreGenerateView.swift`
  - la preview usa tutti gli indici colonne, non solo quelli selezionati.
- `iOSMerchandiseControlTests/Task111ExcelImportParityTests.swift`
  - aggiunto test per default ON/OFF, riattivazione manuale, cambio tipo, generazione e preview.

### Android

- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/main/java/com/example/merchandisecontrolsplitview/viewmodel/ExcelViewModel.kt`
  - aggiunto helper `defaultIsColumnIncluded(headerKey, headerType)`;
  - `initPreGenerateState()` inizializza `selectedColumns` da mapping/header source;
  - le colonne essenziali vengono forzate ON se l'utente prova a togglarle;
  - `setHeaderType` seleziona automaticamente una colonna diventata riconosciuta/manuale;
  - `restoreOriginalHeader` porta OFF una colonna tornata non identificata, salvo essenziale.
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/test/java/com/example/merchandisecontrolsplitview/viewmodel/ExcelViewModelTest.kt`
  - aggiunto test load/generate per default OFF delle colonne non riconosciute e toggle manuale.

## Verifiche funzionali

| Requisito | Esito | Evidenza |
|---|---|---|
| Colonna riconosciuta parte ON | PASS | iOS test `testPreGenerateDefaults...`; Android `loadFromMultipleUris defaults...` |
| Colonna obbligatoria parte ON/protetta | PASS | iOS `barcode/productName/purchasePrice`; Android essenziale forzata ON |
| Colonna non identificata parte OFF | PASS | iOS `internalnote == false`; Android `Internal note == false` |
| Colonna non identificata riattivabile | PASS | iOS `updateColumnSelection`; Android `toggleColumnSelection` |
| Cambio manuale a tipo riconosciuto seleziona | PASS | iOS `setColumnRole(... retailPrice)`; Android `setHeaderType(... retailPrice)` |
| Cambio a non identificata porta OFF se non obbligatoria | PASS | iOS `clearColumnRole`; Android `restoreOriginalHeader` |
| Generazione esclude unknown lasciata OFF | PASS | iOS/Android test verificano header generato senza `internalnote` / `Internal note` |
| Preview mostra ancora unknown | PASS | iOS `PreGenerateView` usa `preGeneratePreviewColumnIndices`; Android `previewData` resta full header/data |

## Test eseguiti

### iOS

| Check | Esito | Evidence |
|---|---|---|
| Debug build simulator | PASS | XcodeBuildMCP `build_sim_2026-05-17T18-30-15-066Z_pid95761_a688e4f3.log`, 0 warnings/errors |
| Release build simulator | PASS | XcodeBuildMCP `build_sim_2026-05-17T18-32-14-314Z_pid95761_8a402d2d.log`, 0 warnings/errors |
| `Task111ExcelImportParityTests` | PASS 9/9 | XcodeBuildMCP `test_sim_2026-05-17T18-31-36-785Z_pid95761_a382701a.log` |
| `ExcelAnalyzerHTMLParsingTests` | PASS 9/9 | XcodeBuildMCP `test_sim_2026-05-17T18-33-55-254Z_pid95761_fa1ff99e.log` |
| `git diff --check` | PASS | exit 0 |
| `plutil -lint` localizzazioni EN/IT/ES/ZH | PASS | tutti i file `Localizable.strings` OK |

Nota: un primo tentativo Debug build MCP con `-configuration Debug` esplicito e default gia' Debug e' fallito subito per doppio argomento `-configuration`; rerun senza argomento PASS. Non era un errore codice.

### Android

| Check | Esito | Evidence |
|---|---|---|
| `./gradlew testDebugUnitTest --tests 'com.example.merchandisecontrolsplitview.viewmodel.ExcelViewModelTest'` | PASS | BUILD SUCCESSFUL in 13s |
| `./gradlew testDebugUnitTest --tests 'com.example.merchandisecontrolsplitview.util.ExcelUtilsTest'` | PASS | BUILD SUCCESSFUL in 5s |
| `./gradlew assembleDebug` | PASS | BUILD SUCCESSFUL in 3s |
| `./gradlew lint` | PASS | BUILD SUCCESSFUL in 40s |
| `git diff --check` | PASS | exit 0 |

Nota: i warning Gradle/AGP/Kotlin plugin osservati sono preesistenti di configurazione toolchain; non emergono warning nuovi dal codice Kotlin modificato.

## Tracking finale

- **TASK-111:** resta **DONE / Chiusura — REVIEW PASS WITH NOTES**, con micro-fix post-review applicato e verificato.
- **TASK-109:** resta **BLOCKED / SOSPESO**, non ripreso.
- **TASK-110:** resta **DONE**, non riaperto.
- **TASK-112:** non creato.

## Limiti residui

- Nessun nuovo smoke manuale Files picker/device reale eseguito; la micro-correzione e' coperta da test ViewModel/parser/build.
- Android `PreGenerateScreen.kt`, `ZoomableExcelGrid.kt` e `TableCell.kt` sono stati controllati: nessuna patch necessaria perche' la preview Android gia' mostra tutte le colonne e la generazione filtra tramite `selectedColumns`.
