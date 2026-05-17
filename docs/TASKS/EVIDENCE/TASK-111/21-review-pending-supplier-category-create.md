# TASK-111 — Review pending supplier/category create UX

**Data:** 2026-05-17 15:38 -0400  
**Tipo:** review indipendente severa del micro-fix post-review `20`  
**Verdict:** **POST-REVIEW MICRO-FIX PASS WITH NOTES**  
**Stato task:** TASK-111 resta **DONE / REVIEW PASS WITH NOTES**  
**TASK-112:** **NON aperto**  
**TASK-109:** resta **BLOCKED / SOSPESO**  
**TASK-110:** resta **DONE**  
**MASTER-PLAN:** resta **IDLE**

## Preflight

File letti prima del fix:

- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-111-excel-analysis-parity-ios.md`
- `docs/TASKS/EVIDENCE/TASK-111/20-post-review-pending-supplier-category-create.md`
- diff corrente iOS
- diff corrente Android
- Android `docs/MASTER-PLAN.md` e `docs/CODEX-EXECUTION-PROTOCOL.md`

Conferme governance:

- TASK-111 risulta **DONE / REVIEW PASS WITH NOTES**.
- TASK-109 risulta **BLOCKED / SOSPESO**.
- TASK-110 risulta **DONE / Chiusura — FINAL CROSS-PLATFORM ACCEPTANCE PASS**.
- Nessun `TASK-112` presente in iOS o Android.
- Supabase locale `/Users/minxiang/Desktop/MerchandiseControlSupabase` controllato come directory locale: non contiene `.git`; nessuna operazione mutativa eseguita.

## Dirty state pre-review

### iOS

`git status --short` mostrava modifiche TASK-111 gia' presenti su:

- `docs/MASTER-PLAN.md`
- `iOSMerchandiseControl/ExcelSessionViewModel.swift`
- `iOSMerchandiseControl/PreGenerateView.swift`
- `iOSMerchandiseControl/ProductImportCore.swift`
- `iOSMerchandiseControl/DatabaseView.swift`
- `iOSMerchandiseControl/ImportAnalysisView.swift`
- `iOSMerchandiseControl/ProductPriceHistoryView.swift`
- localizzazioni EN/IT/ES/ZH
- untracked `docs/TASKS/EVIDENCE/TASK-111/`
- untracked `docs/TASKS/TASK-111-excel-analysis-parity-ios.md`
- untracked fixture/test TASK-111

### Android

`git status --short` mostrava modifiche gia' presenti su:

- `InventoryRepository.kt`
- `PreGenerateScreen.kt`
- `ExcelUtils.kt`
- `ExcelViewModel.kt`
- localizzazioni `values`, `values-en`, `values-es`, `values-zh`
- `DefaultInventoryRepositoryTest.kt`
- `ExcelViewModelTest.kt`
- untracked `app/src/test/java/com/example/merchandisecontrolsplitview/ui/screens/`

Nota review: `PreGenerateScreen.kt` era gia' dirty; la review ha applicato solo un fix mirato nello stesso file. Nessuna modifica non correlata e' stata sovrascritta.

## Codice reviewato

### iOS

- `iOSMerchandiseControl/ExcelSessionViewModel.swift`
- `iOSMerchandiseControl/PreGenerateView.swift`
- `iOSMerchandiseControl/ProductImportCore.swift`
- `iOSMerchandiseControlTests/Task111ExcelImportParityTests.swift`
- `iOSMerchandiseControl/en.lproj/Localizable.strings`
- `iOSMerchandiseControl/it.lproj/Localizable.strings`
- `iOSMerchandiseControl/es.lproj/Localizable.strings`
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`

Esito iOS: pending-create e' stato derivato dall'input; la persistenza avviene solo in `generateHistoryEntry` tramite `ensureSupplierExists` / `ensureCategoryExists`. Nessuna creazione in `body`, `onSubmit`, focus loss, render o picker sheet. Resolver e dedupe sono case/trim-insensitive, con normalizzazione display che preserva input validi inclusi caratteri CJK.

### Android

- `app/src/main/java/com/example/merchandisecontrolsplitview/ui/screens/PreGenerateScreen.kt`
- `app/src/main/java/com/example/merchandisecontrolsplitview/data/InventoryRepository.kt`
- `app/src/main/java/com/example/merchandisecontrolsplitview/viewmodel/DatabaseViewModel.kt`
- `app/src/main/res/values/strings.xml`
- `app/src/main/res/values-en/strings.xml`
- `app/src/main/res/values-es/strings.xml`
- `app/src/main/res/values-zh/strings.xml`
- `app/src/test/java/com/example/merchandisecontrolsplitview/ui/screens/PreGenerateEntityResolutionTest.kt`
- `app/src/test/java/com/example/merchandisecontrolsplitview/data/DefaultInventoryRepositoryTest.kt`
- `app/src/test/java/com/example/merchandisecontrolsplitview/viewmodel/ExcelViewModelTest.kt`
- `app/src/test/java/com/example/merchandisecontrolsplitview/util/ExcelUtilsTest.kt`

## Finding e fix applicato

### P1 — Android explicit create wrote Room before Generate

Prima della review, il path inline `Aggiungi nuovo...` in `PreGenerateScreen.kt` chiamava direttamente `databaseViewModel.addSupplier(...)` / `addCategory(...)`. Questo preservava il vecchio comportamento, ma violava il requisito piu' forte di questa review: nessun record nuovo deve essere creato prima del tap su **Genera inventario**.

Fix applicato:

- introdotti `acceptedPendingSupplierKey` / `acceptedPendingCategoryKey` solo UI;
- il tap su `Aggiungi nuovo...` ora accetta il valore pending e chiude la lista senza chiamare il repository;
- le uniche chiamate PreGenerate a `databaseViewModel.addSupplier` / `addCategory` restano nel path `onGenerate`;
- `Generate` continua a usare `InventoryRepository.addSupplier/addCategory`, che riusa record equivalenti case/trim.

Nessun fix iOS necessario.

## Verifica comportamento

| Criterio | Esito |
|---|---|
| Supplier esistente riconosciuto automaticamente | PASS iOS + Android |
| Category esistente riconosciuta automaticamente | PASS iOS + Android |
| Supplier nuovo valido diventa pending-create | PASS iOS + Android |
| Category nuova valida diventa pending-create | PASS iOS + Android |
| Summary non mostra `Sin seleccionar` / `Not selected` per pending valido | PASS iOS + Android |
| Bottone Generate abilitato con supplier/category validi anche pending | PASS iOS + Android |
| Nessuna creazione durante digitazione, render, blur/focus loss, keyboard done, back/cancel | PASS dopo fix Android |
| Creazione reale solo al tap su Generate | PASS dopo fix Android |
| Nessun duplicato case/trim | PASS iOS + Android |
| Bottone esplicito `Aggiungi nuovo...` resta disponibile | PASS: ora accetta il pending senza persistere prima di Generate |
| Nessun loop di stato SwiftUI/Compose o side effect in recomposition | PASS |
| Nessun impatto Supabase/sync | PASS |

## UI/UX

- iOS: status e summary mostrano `New/Nuovo/Nueva/新...` per i valori pending; copy naturale in EN/IT/ES/ZH; Dynamic Type non peggiorato staticamente.
- Android: stesso modello concettuale; status/summary localizzati; Compose resta locale alla schermata, senza spostare business logic pesante nel composable.
- Nota: nessuna validazione manuale con tastiera/file picker reale e nessun device fisico in questa review; copertura statica/build/test coerente con il perimetro micro-fix.

## Test iOS

Ambiente: iPhone 17 Pro simulator iOS 26.5 (`240F400E-5EFA-486A-9137-FFBBE70F604D`). XcodeBuildMCP aveva defaults non configurati, quindi sono stati usati comandi `xcodebuild` espliciti.

| Check | Esito |
|---|---|
| `git diff --check` | PASS |
| `plutil -lint` EN/IT/ES/ZH | PASS |
| Debug build simulator | PASS |
| Release build simulator | PASS |
| Release install + launch smoke | PASS (`simctl launch` pid `21416`) |
| `Task111ExcelImportParityTests` | PASS 12/12 (`Test-iOSMerchandiseControl-2026.05.17_15-34-38--0400.xcresult`) |
| `ExcelAnalyzerHTMLParsingTests` | PASS 9/9 (`Test-iOSMerchandiseControl-2026.05.17_15-35-24--0400.xcresult`) |

Nota warning iOS: Xcode emette `Metadata extraction skipped. No AppIntents.framework dependency found.` durante build/test. E' warning di configurazione target/toolchain gia' esterno al micro-fix; nessun warning Swift nuovo osservato nei file modificati.

## Test Android

| Check | Esito |
|---|---|
| `git diff --check` | PASS |
| `PreGenerateEntityResolutionTest` | PASS |
| `DefaultInventoryRepositoryTest` mirati supplier/category | PASS |
| `ExcelViewModelTest` | PASS |
| `ExcelUtilsTest` | PASS |
| Combined targeted `testDebugUnitTest` | PASS 103 tests, 0 failures, 0 errors, 0 skipped |
| `./gradlew assembleDebug` | PASS |
| `./gradlew lint` | PASS |

Note Android: warning Gradle/AGP/toolchain preesistenti (`android.builtInKotlin`, `android.newDsl`, legacy variant API, Kotlin Android plugin deprecato) e warning JVM classpath sharing durante test; nessun warning Kotlin nuovo dal codice modificato.

## Supabase / sync

- **NO SUPABASE MUTATION**
- **NO SYNC IMPACT**
- **LOCAL SWIFTDATA/ROOM ONLY**
- Nessun SQL, migration, RLS, grant, RPC, remote write o cleanup eseguito.

## Tracking finale

- **TASK-111:** resta **DONE / REVIEW PASS WITH NOTES**; micro-fix pending supplier/category create UX validato con fix Android mirato.
- **TASK-109:** resta **BLOCKED / SOSPESO**.
- **TASK-110:** resta **DONE**.
- **MASTER-PLAN:** resta **IDLE**.
- **TASK-112:** non aperto.

## Limiti residui

- Nessun smoke manuale completo PreGenerate con file picker reale.
- Nessun test fisico iOS/Android.
- Nessun test Supabase, intenzionalmente fuori scope.
