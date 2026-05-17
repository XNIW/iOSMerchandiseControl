# TASK-111 — Review post-fix column default selection

**Data:** 2026-05-17  
**Verdict:** **POST-REVIEW MICRO-FIX PASS WITH NOTES**  
**Scope:** review indipendente del micro-fix post-review su selezione default colonne PreGenerate / preview Excel, iOS + Android.

## Preflight / tracking

- `docs/MASTER-PLAN.md` letto: progetto **IDLE**, **TASK-111 DONE / Chiusura — REVIEW PASS WITH NOTES**.
- `docs/TASKS/TASK-111-excel-analysis-parity-ios.md` letto: TASK-111 resta chiuso; micro-fix post-review registrato.
- `docs/TASKS/EVIDENCE/TASK-111/18-post-review-column-default-selection.md` letto.
- `find docs/TASKS -maxdepth 1 -iname '*112*'`: nessun TASK-112 creato.
- **TASK-109:** resta **BLOCKED / SOSPESO**.
- **TASK-110:** resta **DONE**.
- **MASTER-PLAN:** resta **IDLE**.

## Dirty state osservato

### iOS

Worktree gia' dirty prima della review, con pacchetto TASK-111 non tracciato/storico e modifiche a:

- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-111-excel-analysis-parity-ios.md` e `docs/TASKS/EVIDENCE/TASK-111/`
- `iOSMerchandiseControl/ExcelSessionViewModel.swift`
- `iOSMerchandiseControl/PreGenerateView.swift`
- `iOSMerchandiseControl/ProductImportCore.swift`
- `iOSMerchandiseControl/ImportAnalysisView.swift`
- `iOSMerchandiseControl/DatabaseView.swift`
- `iOSMerchandiseControl/ProductPriceHistoryView.swift`
- `iOSMerchandiseControl/*.lproj/Localizable.strings`
- `iOSMerchandiseControlTests/Task111ExcelImportParityTests.swift`
- `iOSMerchandiseControlTests/Fixtures/TASK-111/`

La review non ha revertito ne' sovrascritto modifiche non pertinenti.

### Android

Worktree gia' dirty prima della review:

- `ExcelUtils.kt` con alias `discount` aggiuntivo `折` gia' presente nel diff; non modificato da questa review.
- `ExcelViewModel.kt` con micro-fix default selection; revisionato, non modificato da questa review.
- `ExcelViewModelTest.kt` gia' modificato dal micro-fix; questa review ha aggiunto un test mirato sul helper `defaultIsColumnIncluded`.

### Supabase

Nessun repo/servizio Supabase mutato. Review limitata a codice iOS/Android e verifiche locali.

## Problemi trovati

### P1 — iOS includeva solo i ruoli editabili, non tutte le colonne riconosciute

Il micro-fix iOS usava `uniqueRoles` come fonte per `defaultIsIncluded`. Questo lasciava fuori colonne riconosciute dal parser/import (`discount`, `realQuantity`, `oldPurchasePrice`, `oldRetailPrice`) o le mostrava con labeling ambiguo. Effetto potenziale: colonne riconosciute potevano non rispettare la regola "identified ON by default" e alcune colonne ON potevano apparire come "unknown" nella lista colonne.

### Note non bloccanti

- I test iOS mirati mostrano warning Swift preesistenti in test fuori scope (`Task097RuntimeSmokeTests`, `SyncEventOutboxDrainDebugViewModelTests`); Debug/Release build finali non riportano warning.
- Android continua a mostrare warning Gradle/AGP/Kotlin plugin di configurazione gia' presenti; nessun warning Kotlin nuovo dal codice modificato.

## Fix applicati

### iOS

- `ExcelSessionViewModel.swift`
  - aggiunto `defaultIncludedColumnKeys` separato dai ruoli editabili;
  - `isRecognizedColumnKey` ora copre le colonne riconosciute nel perimetro import, incluse `discount`, `realQuantity`, `oldPurchasePrice`, `oldRetailPrice`;
  - aggiunto `discount` ai ruoli manualmente assegnabili;
  - `roleKeyForColumn` riconosce anche colonne non editabili ma note, evitando il label "unknown" su colonne riconosciute.
- `Localizable.strings` EN/IT/ES/ZH
  - aggiunto `pregenerate.role.discount`.
- `Task111ExcelImportParityTests.swift`
  - esteso il test micro-fix per coprire `discount`, `realQuantity`, `oldPurchasePrice`, `oldRetailPrice`, labeling ruolo, unknown OFF, preview full e generazione senza unknown OFF.

### Android

- `ExcelViewModelTest.kt`
  - aggiunto test mirato su `defaultIsColumnIncluded` per colonne riconosciute, alias/pattern/inferred e unknown/generated OFF.

## Verifica comportamentale

| Requisito | iOS | Android |
|---|---|---|
| Unknown / non identificata OFF default | PASS | PASS |
| Required ON e protette | PASS | PASS |
| Identified / alias / pattern / inferred ON default | PASS | PASS |
| Preview mostra anche colonne OFF | PASS | PASS |
| Generazione usa solo selected | PASS | PASS |
| Toggle manuale unknown funziona | PASS | PASS |
| Cambio unknown a tipo riconosciuto porta ON | PASS | PASS |
| Nessun reset continuo a render/recomposition | PASS | PASS |
| Nessun crash con lunghezze header/selected divergenti | PASS iOS fallback testabile; Android state init/griglia revisionati senza nuovo rischio nel path normale | PASS_WITH_NOTES |

## Test eseguiti

### iOS

| Check | Esito |
|---|---|
| `git diff --check` | PASS |
| `plutil -lint` EN/IT/ES/ZH `Localizable.strings` | PASS |
| Debug build simulator | PASS, 0 warnings/errors — `build_sim_2026-05-17T18-50-08-797Z_pid2446_e7bd677c.log` |
| Release build simulator | PASS, 0 warnings/errors — `build_sim_2026-05-17T18-50-27-955Z_pid2446_0d45efde.log` |
| `Task111ExcelImportParityTests` | PASS 9/9 — `test_sim_2026-05-17T18-51-55-065Z_pid2446_9b83958f.log` |
| `ExcelAnalyzerHTMLParsingTests` | PASS 9/9 — `test_sim_2026-05-17T18-52-36-665Z_pid2446_62b26ed6.log` |

### Android

| Check | Esito |
|---|---|
| `git diff --check` | PASS |
| `./gradlew assembleDebug` | PASS — BUILD SUCCESSFUL |
| `./gradlew testDebugUnitTest --tests 'com.example.merchandisecontrolsplitview.viewmodel.ExcelViewModelTest'` | PASS — BUILD SUCCESSFUL |
| `./gradlew testDebugUnitTest --tests 'com.example.merchandisecontrolsplitview.util.ExcelUtilsTest'` | PASS — BUILD SUCCESSFUL |
| `./gradlew lint` | PASS — BUILD SUCCESSFUL |

## Supabase status

- **NO SUPABASE MUTATION**
- **NO SYNC IMPACT**
- **NO DATA IMPACT**
- Nessun SQL, migration, RLS, RPC, Edge Function, Storage o dato remoto modificato.

## Tracking finale

- **TASK-111:** resta **DONE / Chiusura — REVIEW PASS WITH NOTES**; **post-review micro-fix column default selection validated**.
- **TASK-109:** resta **BLOCKED / SOSPESO**.
- **TASK-110:** resta **DONE**.
- **MASTER-PLAN:** resta **IDLE**.
- **TASK-112:** non aperto.

## Limiti residui

- Nessun nuovo smoke manuale Files picker/device reale; non richiesto per questo micro-fix ViewModel/preview statico.
- La review Android su `ZoomableExcelGrid` conferma che la preview mostra tutte le colonne; il reset difensivo su mismatch di lunghezza resta comportamento preesistente e non e' stato ampliato.
