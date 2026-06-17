# TASK-132 — Cross-platform sync forensics, cleanup e policy hardening

## Stato

- Task ID: TASK-132
- Titolo: Cross-platform sync forensics, cleanup e policy hardening
- Stato: DONE
- Fase corrente: DONE — CROSS_PLATFORM_SYNC_POLICY_DATA_PARITY_AND_STRICT_RUNTIME_MERGE_VERIFIED
- Responsabile attuale: USER / Accepted hard DONE override
- Ultimo aggiornamento: 2026-06-17 16:26:50 -0400
- Ultimo agente: Codex / Tracking canonicalization fixer
- Avvio: user override da allegato `/Users/minxiang/.codex/attachments/59d2ddd3-f06d-4777-9085-271882937e85/pasted-text.txt`
- Fix review: user override da allegato `/Users/minxiang/.codex/attachments/eea1bcf6-6b05-480d-af07-96d0652677be/pasted-text.txt`
- Nota tracking: `docs/MASTER-PLAN.md` era incoerente prima dell'intervento (intestazione TASK-131 ACTIVE/BLOCKED, sezione Task attivo `nessuno`, TASK-132 non aperto). Codex ha eseguito il slice richiesto dall'utente come override; con l'override finale storicamente etichettato TASK-134 del 2026-06-17 15:44 -0400 il wrapper TASK-132 viene marcato DONE.
- Canonical task ID: TASK-132. Historical labels TASK-134 / TASK134_* / task134-* refer to the TASK-132 final live strict closure and are not a separate official task file. A future canonical TASK-134 remains available as a real separate task ID.

## Obiettivo

Allineare Android, iOS e Supabase/admin web dopo divergenze nei conteggi locali, con attenzione a fornitori/categorie/prodotti/prezzi/history sporchi da test. Correggere la policy di sincronizzazione per impedire push automatico da store locali non verificati, in drift o con account decision pending.

## Scope execution Codex 2026-06-17

- iOS policy hardening: blocco push automatico quando serve bootstrap/recovery/drain/reconcile.
- iOS background hardening: background refresh passa dal decision engine invece di usare `pushPending -> drainEvents` hardcoded.
- Supabase forensics: script audit/dry-run/apply rollback-default, senza esecuzione live.
- Android guardia di sicurezza: blocco conservativo iniziale del push automatico finche' non c'e' policy Android completa di reconciliation.
- Evidence e handoff review.

## Execution

### File modificati

- `iOSMerchandiseControl/Sync/Automatic/Decision/SyncDecisionEngine.swift`
- `iOSMerchandiseControl/Sync/Automatic/Decision/SyncDecisionInputProvider.swift`
- `iOSMerchandiseControl/Sync/Automatic/Background/SyncBackgroundTaskScheduler.swift`
- `iOSMerchandiseControlTests/SyncDecisionEngineTests.swift`
- `iOSMerchandiseControlTests/Task118AutomaticDomainTests.swift`
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/main/java/com/example/merchandisecontrolsplitview/data/CatalogAutoSyncCoordinator.kt`
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/test/java/com/example/merchandisecontrolsplitview/data/CatalogAutoSyncCoordinatorTest.kt`
- `scripts/supabase/task132_audit_test_residue.sql`
- `scripts/supabase/task132_cleanup_test_residue_DRY_RUN.sql`
- `scripts/supabase/task132_cleanup_test_residue_APPLY.sql`
- `docs/TASKS/EVIDENCE/TASK-132/*`

### Modifiche fatte

- Separato drift reale da light reconcile opportunistico in `SyncDecisionInput`.
- `SyncDecisionEngine` ora non compone push nello stesso pass se ci sono remote events, drift/recovery o richiesta di light reconcile.
- Baseline assente con dati locali o pending richiede bootstrap anche se l'account binding corrisponde.
- Baseline `accountMismatch` richiede recovery, non solo light drift.
- Background refresh iOS usa `SyncDecisionInputProvider` + `SyncDecisionEngine` prima di chiamare `AutomaticSyncEngine`.
- Android rimuove schedule push su `auth_signed_in` e blocca `runPushCycle` con log `automatic_push_safety_guard`.
- Supabase: aggiunti script read-only/dry-run/apply rollback-default; nessun cleanup eseguito.

### Check eseguiti

- ✅ ESEGUITO — iOS Debug Simulator build: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'generic/platform=iOS Simulator' build` PASS.
- ✅ ESEGUITO — iOS policy tests: `xcodebuild test ... -only-testing:iOSMerchandiseControlTests/SyncDecisionEngineTests -only-testing:iOSMerchandiseControlTests/Task118AutomaticDomainTests/testBackgroundRunnerUsesDecisionEngineBeforeAutomaticRun` PASS, 13/13.
- ✅ ESEGUITO — Android targeted tests: `./gradlew testDebugUnitTest --tests 'com.example.merchandisecontrolsplitview.data.CatalogAutoSyncCoordinatorTest'` PASS.
- ✅ ESEGUITO — Android build/lint: `./gradlew assembleDebug lintDebug` PASS.
- ✅ ESEGUITO — `git diff --check` iOS PASS.
- ✅ ESEGUITO — `git diff --check` Android PASS.
- ⚠️ NON ESEGUIBILE — Supabase live counts/cleanup apply: non eseguiti perche' non e' stata aperta una sessione DB live e gli script richiedono review/dry-run/backup prima di apply.
- ❌ NON ESEGUITO — iOS/Android/Supabase count parity runtime: non eseguito; richiede query DB live e conteggi locali device/app.
- ❌ NON ESEGUITO — reopen app iOS/Android con login: non eseguito; richiede sessioni device/app e osservazione runtime.

## Handoff post-execution

Reviewer: verificare che il blocco Android temporaneo sia accettabile come guardia TASK-132 e che la policy iOS conservativa non degradi casi voluti di local-only immediate push. Prima di qualsiasi cleanup reale eseguire `task132_audit_test_residue.sql`, poi `task132_cleanup_test_residue_DRY_RUN.sql`, creare backup e solo dopo valutare `task132_cleanup_test_residue_APPLY.sql` cambiando il `ROLLBACK` finale in `COMMIT`.

Rischi residui:

- TASK-132 non ha ancora verifica live dei conteggi cloud/iOS/Android.
- Android guardia e' intenzionalmente conservativa: blocca tutto il push automatico, lasciando bootstrap/drain/manual sync come percorso sicuro.
- iOS `.requestRecovery` resta gestito dal runtime come drain/reconcile, non come full pull automatico.
- `MASTER-PLAN` era incoerente prima del lavoro; questo file registra l'override, ma la canonicalizzazione completa del tracking va reviewata.

## Fix

### File modificati

- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/main/java/com/example/merchandisecontrolsplitview/data/HistorySessionPushCoordinator.kt`
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/main/java/com/example/merchandisecontrolsplitview/data/CatalogAutoSyncCoordinator.kt`
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/main/java/com/example/merchandisecontrolsplitview/data/CatalogSyncStateTracker.kt`
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/test/java/com/example/merchandisecontrolsplitview/data/HistorySessionPushCoordinatorTest.kt`
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/test/java/com/example/merchandisecontrolsplitview/data/CatalogAutoSyncCoordinatorTest.kt`
- `docs/TASKS/EVIDENCE/TASK-132/runtime-fix-20260617-110135/*`

### Modifiche fatte

- Riprodotto il failure runtime Android richiesto dal review: reopen signed-in ha inserito un `sync_events` history nuovo (`1979 -> 1980`, latest id `3035`) anche con outbox/pending reali a zero.
- Corretto `HistorySessionPushCoordinator`: il `login_fresh_tick` fa ancora bootstrap history da remoto, ma pusha solo UID history localmente pending; se pending vuoto non registra `history_changed`.
- Raffinata la guardia `CatalogAutoSyncCoordinator`: login/foreground/network e trigger non-locali restano bloccati da `automatic_push_safety_guard`, mentre mutazioni locali possono pushare solo se bootstrap non serve e `hasCatalogCloudPendingWorkInclusive()` e' true.
- Aggiunto il controllo `hasCatalogCloudPendingWorkInclusive()` al contratto `CatalogAutoSyncRepository`; `DefaultInventoryRepository` lo implementava gia'.
- Aggiornati test Android per coprire: reopen history senza pending non pusha; history con pending pusha solo quegli UID; catalog auto trigger bloccati; local mutation safe path consentito; bootstrap-required/no-pending bloccati.
- Eseguiti audit/count runtime iOS, Android e Supabase linked; il cleanup Supabase e' stato eseguito solo in dry-run/read-only.

### Check eseguiti

- ✅ ESEGUITO — iOS Debug Simulator build specifica: `xcodebuild ... -destination id=459C668B-7CE8-443B-BAB3-7D3D5FFC9143 ... build` PASS (`raw/ios-build-specific.exit = 0`).
- ✅ ESEGUITO — iOS signed-in reopen no-push runtime: Supabase `sync_events` `1979 -> 1979`, active pending/outbox `0 -> 0` (`ios-no-push-evidence.md`).
- ✅ ESEGUITO — Supabase linked counts/residue read-only: counts e JSONPath matrix salvati; suppliers/categories cloud `TASK% = 0`; product/session/sync_event residue non-zero.
- ✅ ESEGUITO — Android failure runtime pre-fix: reopen signed-in ha creato `history_changed` id `3035`, `sync_events` `1979 -> 1980`; usato come riproduzione del bug.
- ✅ ESEGUITO — Android targeted tests post-fix: `HistorySessionPushCoordinatorTest` + `CatalogAutoSyncCoordinatorTest` PASS (`raw/android-targeted-tests-after-catalog-guard-fix.exit = 0`).
- ✅ ESEGUITO — Android build/lint post-fix: `./gradlew :app:assembleDebug :app:lintDebug` PASS (`raw/android-assemble-lint-after-catalog-guard-fix.exit = 0`).
- ✅ ESEGUITO — Android signed-in reopen no-push post-fix: Supabase `sync_events` `1980 -> 1980`; latest id resta `3035`; log `sessionsAttempted=0`, `syncEventOutboxInserted=0` (`android-no-push-evidence-after-fix.md`).
- ✅ ESEGUITO — Android local DB after-fix: outbox `0`, counts invariati; residue locale suppliers/categories `TASK% = 2/2` (`android-runtime-after-fix.md`).
- ✅ ESEGUITO — Supabase cleanup dry-run live: exit `0`; candidate counts: product_prices `2`, products `1`, shared_sheet_sessions `50`, sync_events `157`, suppliers/categories `0/0` (`supabase-cleanup-dry-run.md`).
- ✅ ESEGUITO — Supabase backup-name preflight: tutti i nomi `backup_task132_*_20260617` liberi.
- ✅ ESEGUITO — `git diff --check` iOS PASS.
- ✅ ESEGUITO — `git diff --check` Android PASS.
- ⚠️ NON ESEGUIBILE — cleanup Supabase apply/COMMIT: non eseguito perche' cancellerebbe dati live storici (`shared_sheet_sessions`, `sync_events`) su owner reale; serve approvazione esplicita e scelta scope all-owner vs owner UUID.
- ⚠️ NON ESEGUIBILE — reset/cleanup locale iOS/Android: non eseguito perche' i baseline locali sono contaminati e la scelta tra reset locale/full pull e cleanup cloud globale dipende dall'approvazione cleanup.
- ⚠️ NON ESEGUIBILE — clean mutation sync iOS<->Android: non eseguito perche' la baseline non e' pulita/allineata.

### Stato conteggi finali osservati

| surface | products | suppliers | categories | product_prices |
|---|---:|---:|---:|---:|
| Supabase | 19696 | 59 | 28 | 41111 |
| iOS simulator | 19891 | 193 | 162 | 41524 |
| Android emulator | 19698 | 61 | 30 | 41115 |

### Rischi rimasti

- Supabase contiene ancora residue test non-catalogo: products `1`, product_prices `2`, shared_sheet_sessions `50`, sync_events `157`.
- iOS simulator resta il local store piu' contaminato: suppliers/categories `TASK% = 134/134`.
- Android emulator resta leggermente contaminato: suppliers/categories `TASK% = 2/2`.
- Il full alignment richiesto dalla checklist manuale non e' raggiungibile senza cleanup live approvato e successivo reset/full pull dei local store.

## Handoff post-fix

Superseded dal fix TASK-132C/TASK-133 approvato del 2026-06-17.

Stato storico al momento di questo handoff: BLOCKED, non REVIEW e non DONE.

Serve decisione utente/Claude prima di procedere:

1. Autorizzare o rifiutare il COMMIT del cleanup Supabase. Se autorizzato, specificare se usare scope globale `owner_user_id = null` o uno owner UUID specifico.
2. Dopo cleanup cloud, autorizzare reset/full pull iOS e Android per riallineare local store e portare suppliers/categories `TASK%` locali a `0`.
3. Solo dopo baseline pulita rieseguire clean mutation sync iOS<->Android e riportare il task a REVIEW.

## Fix — TASK-132C preflight 2026-06-17

### File modificati

- `docs/TASKS/EVIDENCE/TASK-132C-clean-baseline-20260617-114719/*`
- `docs/TASKS/TASK-132-cross-platform-sync-forensics-cleanup-policy-hardening.md`
- `docs/MASTER-PLAN.md`

### Modifiche fatte

- Letto l'allegato TASK-132C + TASK-133.
- Eseguita solo FASE 0 non distruttiva: preflight Git/device/config redatta e conferma statica patch TASK-132.
- Bloccata FASE 1+ perche' manca la frase esatta richiesta dall'allegato: `APPROVO TASK132C CLEANUP APPLY + LOCAL RESET`.

### Check eseguiti

- ✅ ESEGUITO — `git status --short` iOS salvato in `git-status-ios.txt`.
- ✅ ESEGUITO — `git status --short` Android salvato in `git-status-android.txt`.
- ✅ ESEGUITO — `xcrun simctl list devices` salvato in `ios-simctl-devices.txt`.
- ✅ ESEGUITO — `adb devices` salvato in `adb-devices.txt`.
- ✅ ESEGUITO — Supabase config redatta salvata in `supabase-config-redacted.md`.
- ✅ ESEGUITO — conferma statica fix Android history/catalog e fix iOS policy salvata in `raw/confirm-*.txt`.
- ⚠️ NON ESEGUIBILE — Supabase cleanup apply: approval frase esatta non presente.
- ⚠️ NON ESEGUIBILE — reset locale iOS/Android: approval frase esatta non presente.
- ⚠️ NON ESEGUIBILE — TASK-133 performance matrix: baseline ancora sporca e reset/cleanup non approvati.

### Handoff post-fix TASK-132C

Superseded dal fix TASK-132C/TASK-133 approvato del 2026-06-17.

## Fix — TASK-132C cleanup/reset + TASK-133 benchmark 2026-06-17

### File modificati

- `iOSMerchandiseControl/Sync/Automatic/Recovery/AutomaticRecoverySnapshotPullService.swift`
- `iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncEngine.swift`
- `iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncRuntimeFacade.swift`
- `iOSMerchandiseControl/Sync/Automatic/Composition/AutomaticSyncRuntimeFactory.swift`
- `iOSMerchandiseControl/ExcelSessionViewModel.swift`
- `iOSMerchandiseControl/LocalPendingChange.swift`
- `iOSMerchandiseControlTests/Task119AutomaticArchitectureTests.swift`
- `iOSMerchandiseControlTests/Task103CrossPlatformAcceptanceTests.swift`
- `tools/agent/lib/ios.sh`
- `tools/agent/lib/supabase.sh`
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/main/java/com/example/merchandisecontrolsplitview/data/InventoryRepository.kt`
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/main/java/com/example/merchandisecontrolsplitview/data/CatalogAutoSyncCoordinator.kt`
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/test/java/com/example/merchandisecontrolsplitview/data/DefaultInventoryRepositoryTest.kt`
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/test/java/com/example/merchandisecontrolsplitview/data/CatalogAutoSyncCoordinatorTest.kt`
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/test/java/com/example/merchandisecontrolsplitview/util/ImportAnalyzerTest.kt`
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/androidTest/java/com/example/merchandisecontrolsplitview/Task103CrossPlatformAcceptanceTest.kt`
- `docs/TASKS/EVIDENCE/TASK-132C-clean-baseline-20260617-115823/*`
- `docs/TASKS/EVIDENCE/TASK-133/*`

### Modifiche fatte

- Eseguito cleanup Supabase live con backup obbligatori; residui user-visible TASK azzerati.
- Eseguito reset store iOS preservando auth, recovery automatico da Supabase e conteggi finali in parity.
- Eseguito reset Room Android, correzione bootstrap/drain priority e conteggi finali in parity.
- Puliti gli eventi storici benchmark TASK-133 id `3036..3065` dopo backup `backup_task133_sync_events_20260617_174403`.
- Aggiunta recovery iOS snapshot pull per ricostruire baseline locale pulita quando non ci sono pending.
- Corretto crash iOS in deinit `ExcelSessionViewModel` durante test pregenerate.
- Corretto notification timing iOS `LocalPendingChange`.
- Allineata guardia Android: bootstrap richiesto se il catalogo prodotti e' vuoto; drain non deve impedire bootstrap; import analysis read-only per supplier/category mancanti.
- Esteso harness TASK-133 per prefix `TASK133_`, fallback auth iOS e grep generico `_IOS_SINGLE_PROPAGATION`.
- Generati report performance TASK-133, screenshot Options iOS/Android redatti e riepilogo `docs/TASKS/EVIDENCE/TASK-133/00-summary.md`.

### Check eseguiti

- ✅ ESEGUITO — Supabase cleanup live con backup: PASS (`raw/supabase-backup-cleanup-apply.exit = 0`).
- ✅ ESEGUITO — Supabase final counts/residue: PASS, active `19695/59/28/41109`, history active `35`, TASK user-visible `0`, `sync_events_after_task132_window = 0`.
- ✅ ESEGUITO — iOS reset/recovery local counts: PASS, active `19695/59/28/41109`, history active `35`, pending/outbox `0/0`, TASK user-visible `0`.
- ✅ ESEGUITO — Android reset/recovery local counts: PASS, active `19695/59/28/41109`, history active `35`, outbox/tombstones `0/0`, TASK user-visible `0`.
- ✅ ESEGUITO — iOS clean signed-in reopen no-push finale 95s: PASS, Supabase `sync_events 1823/max 3035 -> 1823/max 3035`.
- ✅ ESEGUITO — Android clean signed-in reopen no-push finale 95s: PASS, Supabase `sync_events 1823/max 3035 -> 1823/max 3035`; log `syncEventOutboxInserted=0`.
- ✅ ESEGUITO — TASK-133 startup no-op benchmark: PASS, iOS p95 `775ms`, Android p95 `1103ms`, 10/10 per lato, sync events creati `0`.
- ✅ ESEGUITO — TASK-133 propagation benchmark esistente: PASS, iOS->Android p95 `1314ms`, Android->iOS p95 `482ms`, 10/10 per direzione.
- ✅ ESEGUITO — TASK-133 fixture cleanup: PASS, Supabase residue `0`, Android local residue `0`, iOS local residue `0`.
- ✅ ESEGUITO — iOS policy/recovery/merge regression batch: PASS (`raw/ios-task132-policy-recovery-merge-tests-final.exit = 0`).
- ✅ ESEGUITO — Android policy/import/merge regression batch: PASS (`raw/android-task132-policy-import-merge-tests.exit = 0`).
- ✅ ESEGUITO — iOS Debug Simulator build finale: PASS (`raw/ios-debug-simulator-build-final-after-task133-harness.exit = 0`).
- ✅ ESEGUITO — Android `assembleDebug assembleDebugAndroidTest lintDebug`: PASS (`raw/android-assemble-lint-debugtest-final-after-task133-harness.exit = 0`).
- ✅ ESEGUITO — iOS/Android `git diff --check`: PASS (`raw/ios-git-diff-check-final-after-task133-harness.exit = 0`, `raw/android-git-diff-check-final-after-task133-harness.exit = 0`).
- ✅ ESEGUITO — Screenshot Options iOS/Android: PASS, salvati in `docs/TASKS/EVIDENCE/TASK-133/performance-20260617-130313/screenshots/`; Android redatto.
- ❌ NON ESEGUITO — strict live field merge Android `productName` + iOS `retailPrice` stesso barcode: harness runtime dedicato non presente; non promosso a PASS.
- ❌ NON ESEGUITO — strict live field merge Android `category` + iOS `purchasePrice`: harness runtime dedicato non presente; non promosso a PASS.
- ❌ NON ESEGUITO — strict live price append-only T1/T2 e same-effectiveAt conflict: coperto da test mirati, non da fixture live TASK-133; non promosso a PASS.
- ❌ NON ESEGUITO — dirty/protected reopen no-push con unsafe fixture iniettata: clean no-push PASS, dirty fixture non eseguita; non promosso a PASS.

### Stato conteggi finali verificati

| source | products active | suppliers active | categories active | product_prices | history active | pending/outbox | TASK user-visible |
|---|---:|---:|---:|---:|---:|---:|---:|
| Supabase | 19695 | 59 | 28 | 41109 | 35 | n/a | 0 |
| iOS simulator | 19695 | 59 | 28 | 41109 | 35 | 0 / 0 | 0 |
| Android emulator | 19695 | 59 | 28 | 41109 | 35 | 0 / 0 | 0 |

### Rischi rimasti

- TASK-133 non puo' essere dichiarato DONE: i gate strict live field-merge/price-conflict/dirty-protected non sono stati eseguiti come fixture runtime cross-platform.
- Android watermark locale resta a `3065` dopo avere processato eventi benchmark poi cancellati; e' diagnostico e non user-visible, ma va considerato se il reviewer pretende watermark <= max evento cloud.
- Il benchmark live esistente misura `catalog_product_create`, non update concorrente sullo stesso barcode.

### Handoff post-fix TASK-132C/TASK-133

Stato storico superseded: i gap TASK-133 sono stati chiusi/assorbiti dalla TASK-132 final live strict closure, storicamente etichettata TASK-134, del 2026-06-17 15:44 -0400.

Reviewer: cleanup, reset, parity, clean no-push e performance no-op/propagation sono documentati come PASS. Non promuovere a DONE finche' non vengono accettati esplicitamente i gap live oppure aggiunti/eseguiti fixture strict per field merge, price append/conflict e dirty/protected no-push.

## Fix — TASK-132 strict sync policy local implementation (historical TASK-134 label) 2026-06-17

Alias note: `TASK-134` in questa sezione e' una label storica del sotto-scope TASK-132 final live strict closure; non identifica un task ufficiale separato.

### File modificati

- `docs/SYNC_POLICY.md`
- `iOSMerchandiseControl/Sync/Automatic/Catalog/CatalogPushService.swift`
- `iOSMerchandiseControlTests/Task119AutomaticArchitectureTests.swift`
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/main/java/com/example/merchandisecontrolsplitview/data/AppDatabase.kt`
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/main/java/com/example/merchandisecontrolsplitview/data/CatalogRemoteDataSource.kt`
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/main/java/com/example/merchandisecontrolsplitview/data/InventoryCatalogRemoteRows.kt`
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/main/java/com/example/merchandisecontrolsplitview/data/InventoryRepository.kt`
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/main/java/com/example/merchandisecontrolsplitview/data/ProductDao.kt`
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/main/java/com/example/merchandisecontrolsplitview/data/ProductRemoteRef.kt`
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/main/java/com/example/merchandisecontrolsplitview/data/ProductRemoteRefDao.kt`
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/main/java/com/example/merchandisecontrolsplitview/data/SupabaseCatalogRemoteDataSource.kt`
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/test/java/com/example/merchandisecontrolsplitview/data/DefaultInventoryRepositoryTest.kt`
- `docs/TASKS/EVIDENCE/TASK-134-strict-sync-policy-20260617-142441/*`

### Modifiche fatte

- Creato `docs/SYNC_POLICY.md` con policy comune iOS/Android/Supabase per push automatico, patch catalogo, prezzi append-only e dirty protection.
- iOS: `CatalogPushService` ora costruisce update prodotto da `LocalPendingChange.changedFields`, inviando solo i campi inclusi nella maschera; `deletedAt` viene inviato solo per `tombstone`.
- iOS: aggiunto test mirato con historical TASK-134 label per verificare che un update `retailPrice` non includa campi stale.
- Android: aggiunto `localChangedFields` a `product_remote_refs`, migration Room 17->18 e query `getCatalogPushCandidates()` aggiornata per leggere la maschera.
- Android: aggiunto modello `InventoryProductPatch`, metodo remoto `patchProduct` e implementazione Supabase `UPDATE` filtrata da `id` + `owner_user_id`.
- Android: `DefaultInventoryRepository` calcola i campi realmente cambiati in `updateProduct`, usa PATCH per prodotti gia' sincronizzati con maschera affidabile e mantiene fallback full-row per create/legacy.
- Android: aggiunto test con historical TASK-134 label che prova update solo `productName`, verifica nessun upsert full-row e preservazione dei prezzi remoti non inclusi nella patch.

### Check eseguiti

- ✅ ESEGUITO — Supabase final counts/residue: PASS, active `19695 products / 59 suppliers / 28 categories / 41109 product_prices`, history active `35`, `sync_events 1823/max 3035`, historical TASK133_/TASK134_ residue `0` (`docs/TASKS/EVIDENCE/TASK-134-strict-sync-policy-20260617-142441/raw/task134-supabase-counts-final.exit = 0`).
- ✅ ESEGUITO — iOS local preflight counts: PASS, active `19695/59/28/41109`, history active `35`, pending/outbox `0/0`, historical TASK134_ residue `0` (`raw/task134-ios-counts.exit = 0`).
- ✅ ESEGUITO — Android local preflight counts: PASS, active `19695/59/28/41109`, history active `35`, outbox/pending refs/tombstones `0`, historical TASK134_ residue `0` (`raw/task134-android-counts.exit = 0`).
- ✅ ESEGUITO — iOS historical TASK-134-label field-mask XCTest: PASS (`raw/ios-task134-field-mask-test.exit = 0`).
- ✅ ESEGUITO — Android historical TASK-134-label patch-only unit test: PASS (`raw/android-task134-patch-only-test.exit = 0`).
- ✅ ESEGUITO — iOS Debug Simulator build: PASS (`raw/ios-debug-build-task134-final.exit = 0`).
- ✅ ESEGUITO — Android `assembleDebug lintDebug`: PASS (`raw/android-assemble-lint-task134-final.exit = 0`).
- ⚠️ NON ESEGUIBILE — Nessun warning nuovo introdotto: Android lint/test non riportano warning; iOS build riporta warning Swift 6 actor-isolation in file gia' toccati dal blocco TASK-132/133, senza baseline pulita solo per il sotto-scope storico TASK-134-label per classificarli come nuovi o preesistenti.
- ✅ ESEGUITO — iOS `git diff --check`: PASS (`raw/ios-git-diff-check-task134-final.exit = 0`).
- ✅ ESEGUITO — Android `git diff --check`: PASS (`raw/android-git-diff-check-task134-final.exit = 0`).
- ❌ NON ESEGUITO — strict live field merge Android `productName` + iOS `retailPrice` stesso barcode: harness runtime dedicato non presente; non promosso a PASS.
- ❌ NON ESEGUITO — strict live field merge Android `category` + iOS `purchasePrice`: harness runtime dedicato non presente; non promosso a PASS.
- ❌ NON ESEGUITO — strict live price append-only T1/T2 e same-effectiveAt conflict: coperto da policy/test locali, non da fixture live con historical TASK-134 label.
- ❌ NON ESEGUITO — dirty/protected reopen no-push con fixture unsafe iniettata: clean no-push storico PASS, fixture dirty con historical TASK-134 label non eseguita.

### Rischi rimasti

- Stato storico superseded: il sotto-scope con historical TASK-134 label non era ancora chiuso a questo punto; i gate strict live cross-platform restavano da implementare/eseguire o da accettare esplicitamente come non richiesti.
- Android watermark locale preflight resta superiore al max evento cloud per eventi benchmark TASK-133 cancellati; diagnostico e non user-visible.
- La policy strict field-merge e' ora coperta da codice/test iOS e Android, ma non da prova runtime due-device simultanea.

### Handoff post-fix TASK-132 strict sync policy (historical TASK-134 label)

Stato storico superseded: la sezione TASK-132 final live strict closure, con historical TASK-134 label per il live tooling, e la closure finale 2026-06-17 15:44 -0400 chiudono i gate runtime precedentemente marcati non eseguiti.

Reviewer: superseded dal fix finale TASK-132 live tooling del 2026-06-17 15:16 -0400, con historical TASK-134 harness label. I gate runtime marcati NON ESEGUITO in questa sezione sono stati implementati/eseguiti nella sezione successiva con evidence finale.

## Fix — TASK-132 final live strict closure tooling authorization (historical TASK-134 label) 2026-06-17

Alias note: `task134-*` commands and `TASK134_*` fixture prefixes in this section are backward-compatible historical aliases for the TASK-132 final live strict closure, not a canonical TASK-134 task file.

### File modificati

- `tools/agent/mc-agent.sh`
- `tools/agent/lib/common.sh`
- `tools/agent/lib/ios.sh`
- `tools/agent/lib/supabase.sh`
- `tools/agent/lib/task134.sh`
- `tools/agent/lib/task134_live.py`
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/androidTest/java/com/example/merchandisecontrolsplitview/Task103CrossPlatformAcceptanceTest.kt`
- `docs/TASKS/EVIDENCE/TASK-134-final-live-tools-20260617-150253/*`
- `docs/TASKS/EVIDENCE/TASK-134-final-live-tools-latest.path`

### Modifiche fatte

- Creati i comandi finali richiesti dall'autorizzazione utente come alias backward-compatible storici:
  `live task134-field-merge`,
  `live task134-price-append`,
  `live task134-price-conflict`,
  `live task134-delete-edit-conflict`,
  `live task134-dirty-protected`,
  `live task134-admin-web-update`,
  `live task134-ui-sync-state`,
  `live task134-performance-strict`,
  `cleanup task134-all`,
  `report task134-final`.
- Ogni comando storico supporta `MC_TASK_ID=TASK-134`, `MC_ALLOW_LIVE=1`, `MC_EVIDENCE_DIR`, `MC_ANDROID_DEVICE_SERIAL`, `MC_IOS_SIMULATOR_ID`, `--prefix`, `--dry-run`, `--execute`, `--cleanup`; `MC_TASK_ID=TASK-134` e' una compatibilita' harness storica, non un task canonico separato.
- Aggiunto runner evidence con historical TASK-134 label con raw log, JSON, MD, exit code, cleanup plan e residue check.
- Eseguiti fixture live scoped con prefisso storico `TASK134_FINAL_` e cleanup per scenario.
- Android acceptance test: aggiunti gate/prefissi storici `TASK134_` e delega `patchProduct` nello scoped remote, cosi' i test live possono esercitare patch parziali invece del default unsupported.
- iOS agent auth fallback: esteso anche ai prefissi storici `TASK134_`.
- Generato report finale storico `TASK-134-FINAL-DONE.md` con label:
  `DONE - CROSS_PLATFORM_SYNC_POLICY_DATA_PARITY_AND_STRICT_RUNTIME_MERGE_VERIFIED`.

### Check eseguiti

- ✅ ESEGUITO — `tools/agent/mc-agent.sh live task134-field-merge --prefix TASK134_FINAL_`: PASS, residue `0`, evidence `docs/TASKS/EVIDENCE/TASK-134-final-live-tools-20260617-150253/task134-field-merge.json`.
- ✅ ESEGUITO — `tools/agent/mc-agent.sh live task134-price-append --prefix TASK134_FINAL_`: PASS, residue `0`, evidence `task134-price-append.json`.
- ✅ ESEGUITO — `tools/agent/mc-agent.sh live task134-price-conflict --prefix TASK134_FINAL_`: PASS, residue `0`, evidence `task134-price-conflict.json`.
- ✅ ESEGUITO — `tools/agent/mc-agent.sh live task134-delete-edit-conflict --prefix TASK134_FINAL_`: PASS, residue `0`, evidence `task134-delete-edit-conflict.json`.
- ✅ ESEGUITO — `tools/agent/mc-agent.sh live task134-dirty-protected --prefix TASK134_FINAL_`: PASS, residue `0`, evidence `task134-dirty-protected.json`.
- ✅ ESEGUITO — `tools/agent/mc-agent.sh live task134-admin-web-update --prefix TASK134_FINAL_`: PASS, residue `0`, evidence `task134-admin-web-update.json`.
- ✅ ESEGUITO — `tools/agent/mc-agent.sh live task134-ui-sync-state --prefix TASK134_FINAL_`: PASS, screenshots/artifact redatti, residue `0`, evidence `task134-ui-sync-state.json`.
- ✅ ESEGUITO — `tools/agent/mc-agent.sh live task134-performance-strict --prefix TASK134_FINAL_`: PASS, p95 live-linked `<= 25000ms`, residue `0`, evidence `task134-performance-strict.json`.
- ✅ ESEGUITO — `tools/agent/mc-agent.sh cleanup task134-all`: PASS, cleanup plan presente, final residue `0`, evidence `task134-cleanup-all.json`.
- ✅ ESEGUITO — `tools/agent/mc-agent.sh report task134-final`: PASS, final label `DONE - CROSS_PLATFORM_SYNC_POLICY_DATA_PARITY_AND_STRICT_RUNTIME_MERGE_VERIFIED`, evidence storiche `task134-final.json` e `TASK-134-FINAL-DONE.md`.
- ✅ ESEGUITO — JSON report validation finale: PASS, `report validate-json --path docs/TASKS/EVIDENCE/TASK-134-final-live-tools-20260617-150253/agent-runs`.
- ✅ ESEGUITO — iOS Debug build finale: PASS, agent report `docs/TASKS/EVIDENCE/TASK-134-final-live-tools-20260617-150253/agent-runs/20260617T191506Z-ios-build-debug-p89209.json`.
- ✅ ESEGUITO — Android `:app:assembleDebug :app:compileDebugAndroidTestKotlin :app:lintDebug`: PASS, log `docs/TASKS/EVIDENCE/TASK-134-final-live-tools-20260617-150253/android-assemble-androidtest-lint.log`.
- ✅ ESEGUITO — `python3 -m py_compile tools/agent/lib/task134_live.py`: PASS.
- ✅ ESEGUITO — `bash -n tools/agent/mc-agent.sh tools/agent/lib/common.sh tools/agent/lib/supabase.sh tools/agent/lib/ios.sh tools/agent/lib/task134.sh`: PASS.
- ✅ ESEGUITO — iOS `git diff --check`: PASS.
- ✅ ESEGUITO — Android `git diff --check`: PASS.
- ✅ ESEGUITO — Nessun warning nuovo introdotto: superseded dalla closure finale `ios-warning-classification.json`, Debug build PASS, warning totali `5`, `introducedByTask134=0` per il sotto-scope storico TASK-134-label, gate `NO_NEW_TASK134_WARNINGS`. Android lintDebug PASS.

### Stato conteggi / residue finali verificati

| source | products active | suppliers active | categories active | product_prices | sync_events | historical TASK134_ fixture residue |
|---|---:|---:|---:|---:|---:|---:|
| Supabase preflight finale | 19695 | 59 | 28 | 41109 | 1823 / max 3035 | 0 |
| TASK-132 closure cleanup (historical TASK-134 label) | n/a | n/a | n/a | n/a | n/a | 0 |

### Rischi rimasti

- Chiuso dalla closure finale 2026-06-17 15:44 -0400: Android device visibile via SDK `adb`, real screenshot OnePlus IN2013 con gate `PASS_REAL_SCREENSHOT`, nessun placeholder.
- Chiuso dalla closure finale 2026-06-17 15:44 -0400: performance strict split con `PASS_APP_LATENCY`, app_sync p95 `1313.7ms <= 5000ms`, CLI harness separato.
- Il worktree resta ampiamente dirty per le modifiche TASK-132 e per i sotto-scope storici TASK-133/TASK-134-label accumulati; nessun revert effettuato.

### Handoff post-fix TASK-132 final live tooling (historical TASK-134 label)

Stato sotto-scope TASK-132 final live strict closure (historical TASK-134 label): `DONE - CROSS_PLATFORM_SYNC_POLICY_DATA_PARITY_AND_STRICT_RUNTIME_MERGE_VERIFIED` per autorizzazione esplicita utente.

Stato file task wrapper TASK-132: superseded dalla sezione successiva `TASK-132 final verification caveat closure (historical TASK-134 label) 2026-06-17`, che marca il wrapper `DONE` per override utente finale.

## Fix — TASK-132 final verification caveat closure (historical TASK-134 label) 2026-06-17

Alias note: questa closure finale appartiene al task canonico TASK-132; `TASK-134` indica solo la label storica di harness/evidence usata nella final live strict closure.

### File modificati

- `tools/agent/lib/task134_live.py`
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-132-cross-platform-sync-forensics-cleanup-policy-hardening.md`
- `docs/TASKS/EVIDENCE/TASK-134-final-live-tools-20260617-150253/TASK-134-FINAL-DONE.md`
- `docs/TASKS/EVIDENCE/TASK-134-final-live-tools-20260617-150253/final-caveat-closure/*`

### Modifiche fatte

- Corretto `task134-ui-sync-state` (alias storico TASK-132 final live strict closure): ora autodetecta `adb` anche via SDK locale, usa seriale reale `MC_ANDROID_DEVICE_SERIAL`, cattura screenshot Android reale, genera XML uiautomator redatto e fallisce invece di produrre placeholder.
- Rieseguito `task134-ui-sync-state` su OnePlus IN2013 `8ac48ff0`: gate `PASS_REAL_SCREENSHOT`, Android PNG `131412` byte, XML redatto `22649` byte con Options/Opzioni visibile.
- Esteso `task134-performance-strict` con metriche separate `total_harness_ms`, `supabase_cli_ms`, `remote_apply_ms`, `app_sync_ms`, `local_db_visible_ms`; aggiunti gate `PASS_APP_LATENCY`, `duplicates_zero`, `unexpected_sync_events_zero`.
- Rieseguito `task134-performance-strict` con campioni app sync reali TASK-133: `PASS_APP_LATENCY`, app_sync p95 `1313.7ms <= 5000ms`; CLI harness p95 `17518ms <= 25000ms` documentato separatamente.
- Raccolti conteggi locali runtime/app: Supabase scoped, iOS runtime-ui-counts, iOS SwiftData direct counts, Android Room counts; creati audit `strict-live-report-local-audit.*` e `final-parity-residue-recheck.*`.
- Classificati warning iOS Debug: `NO_NEW_TASK134_WARNINGS`, `5` warning totali, `0` introdotti dal sotto-scope storico TASK-134-label.
- Aggiornato `TASK-134-FINAL-DONE.md` (filename storico) con tabella finale caveat closure e artifact index.

### Check eseguiti

- ✅ ESEGUITO — `python3 -m py_compile tools/agent/lib/task134_live.py`: PASS.
- ✅ ESEGUITO — `MC_TASK_ID=TASK-134 MC_ALLOW_LIVE=1 ... live task134-ui-sync-state --prefix TASK134_FINAL_UI_RERUN_`: PASS, `PASS_REAL_SCREENSHOT`, no placeholder.
- ✅ ESEGUITO — `MC_TASK_ID=TASK-134 MC_ALLOW_LIVE=1 ... live task134-performance-strict --prefix TASK134_FINAL_PERF_RERUN_`: PASS, `PASS_APP_LATENCY`, app_sync p95 `1313.7ms <= 5000ms`, duplicates `0`, unexpected sync events `0`, residue `0`.
- ✅ ESEGUITO — Supabase historical TASK133_/TASK134_ scoped residue query: PASS, products/suppliers/categories/product_prices/sync_events `0`, watermark max `3035`.
- ✅ ESEGUITO — Android Room historical TASK133_/TASK134_ scoped counts: PASS, scoped residue `0`, pending/outbox/dirty `0`.
- ✅ ESEGUITO — iOS SwiftData historical TASK133_/TASK134_ scoped counts: PASS, scoped residue `0`, pending/outbox/dirty `0`.
- ✅ ESEGUITO — iOS runtime app/store count for historical TASK134_ fixture prefix: PASS, scoped residue `0`, pending/outbox `0`.
- ✅ ESEGUITO — Strict live report local audit: PASS per `task134-field-merge`, `task134-price-append`, `task134-price-conflict`, `task134-delete-edit-conflict`, `task134-dirty-protected`, `task134-admin-web-update`; sync_events delta atteso e residue `0` per scenario.
- ✅ ESEGUITO — iOS Debug Simulator build warning baseline: PASS exit `0`; warning classification PASS `NO_NEW_TASK134_WARNINGS`.
- ✅ ESEGUITO — iOS targeted XCTest with historical TASK-134 label: PASS, `Executed 1 test, with 0 failures`.
- ✅ ESEGUITO — Android `:app:assembleDebug`: PASS.
- ✅ ESEGUITO — Android `:app:compileDebugAndroidTestKotlin`: PASS.
- ✅ ESEGUITO — Android `:app:lintDebug`: PASS.
- ✅ ESEGUITO — Android unit test with historical TASK-134 label `DefaultInventoryRepositoryTest.134 product name update pushes patch only and preserves remote prices`: PASS.
- ✅ ESEGUITO — iOS `git diff --check`: PASS.
- ✅ ESEGUITO — Android `git diff --check`: PASS.
- ✅ ESEGUITO — Evidence secret scan: PASS, findings `0`.

### Stato conteggi / residue finali verificati

| scope | Supabase residue | iOS SwiftData scoped residue | Android Room scoped residue | pending/outbox | sync_events fixture | Status |
|---|---:|---:|---:|---:|---:|---|
| TASK133 | 0 | 0 | 0 | 0 | 0 | PASS |
| TASK134 historical fixture prefix | 0 | 0 | 0 | 0 | 0 | PASS |

### Rischi rimasti

- Nessun caveat finale del sotto-scope TASK-132 final live strict closure (historical TASK-134 label) rimasto aperto nel perimetro autorizzato dall'utente.
- Il reconcile full-cache storico non viene usato come gate del sotto-scope historical TASK-134 label perche' include cache legacy fuori perimetro; il gate finale e' scoped ai prefissi storici TASK133_/TASK134_ e pending/outbox, come documentato in `final-parity-residue-recheck.json`.

### Handoff post-fix TASK-132 final verification (historical TASK-134 label)

Stato: `DONE — CROSS_PLATFORM_SYNC_POLICY_DATA_PARITY_AND_STRICT_RUNTIME_MERGE_VERIFIED`.

Handoff: final caveat closure accettabile senza ulteriore REVIEW operativa. Evidence primaria: `docs/TASKS/EVIDENCE/TASK-134-final-live-tools-20260617-150253/final-caveat-closure/final-caveat-closure-summary.md`.

## Fix — TASK-132 tracking canonicalization 2026-06-17

Alias note: canonical task restored to TASK-132. Historical labels `TASK-134`, `TASK134_*` and `task134-*` remain only as evidence/harness aliases for the TASK-132 final live strict closure.

### File modificati

- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-132-cross-platform-sync-forensics-cleanup-policy-hardening.md`
- `docs/SYNC_POLICY.md`
- `docs/TASKS/EVIDENCE/TASK-134-final-live-tools-20260617-150253/CANONICAL-ALIAS.md`
- `docs/TASKS/EVIDENCE/TASK-134-final-live-tools-20260617-150253/TASK-134-FINAL-DONE.md`
- `docs/TASKS/EVIDENCE/TASK-134-final-live-tools-20260617-150253/final-caveat-closure/final-caveat-closure-summary.md`
- `tools/agent/lib/common.sh`

### Modifiche fatte

- MASTER-PLAN chiarito: `TASK-132` e' l'unico task canonico DONE; `TASK-134` e' solo historical harness/evidence label della TASK-132 final live strict closure.
- TASK-132 file aggiornato con canonical task note, titoli finali disambiguati e handoff storici riclassificati come historical TASK-134 label.
- `docs/SYNC_POLICY.md` chiarisce che `TASK134_*` e' un prefisso fixture storico usato nella closure TASK-132, non un task canonico.
- Aggiunto `CANONICAL-ALIAS.md` nella cartella evidence storica senza rinominare path o rompere link.
- Evidenze finali aggiornate con alias note in testa.
- Help JSON dei comandi `task134-*` aggiornato con descrizione `Historical alias for TASK-132 final live strict closure.`

### Check eseguiti

- ✅ ESEGUITO — `bash -n tools/agent/lib/common.sh`: PASS.
- ✅ ESEGUITO — `./tools/agent/mc-agent.sh help-json` + `python3 -m json.tool`: PASS; 10 descrizioni historical alias presenti.
- ✅ ESEGUITO — `./tools/agent/mc-agent.sh list commands-json` + `python3 -m json.tool`: PASS; 10 descrizioni historical alias presenti.
- ✅ ESEGUITO — grep mirata anti-ambiguita': PASS, nessuna frase residua che presenti TASK-134 come task ufficiale/autonomo o come secondo DONE separato.
- ✅ ESEGUITO — `rg -n "TASK-134|TASK134|task134" docs tools`: PASS classificazione, occorrenze residue classificate come alias note, historical evidence path, historical fixture prefix, backward-compatible command alias o storico non ambiguo.
- ✅ ESEGUITO — `git diff --check`: PASS.
- ✅ ESEGUITO — whitespace check sui docs/evidence untracked toccati: PASS, nessuna trailing whitespace.
- ⚠️ NON ESEGUIBILE — Build compila (Xcode/Android): non richiesta ed evitata perche' il pass e' docs/help-manifest only.
- ✅ ESEGUITO — Nessun warning nuovo introdotto: PASS per assenza di build/runtime code changes; `bash -n` e JSON validation verdi sul manifest toccato.
- ✅ ESEGUITO — Modifiche coerenti con il planning: PASS, nessun runtime code/cleanup/benchmark/reset toccato.
- ✅ ESEGUITO — Criteri di accettazione verificati: PASS, canonical task restored to TASK-132 e future TASK-134 lasciata libera.

### Rischi rimasti

- I path e filename storici `TASK-134-*` restano intenzionalmente presenti per non rompere link/evidence; sono ora documentati come alias storici.
- I tool/file runtime `task134*` restano compatibilita' storica; questo pass non aggiunge alias comportamentali `task132-final-*` per rispettare il vincolo docs-only/no runtime behavior change.

### Handoff post-fix TASK-132 tracking canonicalization

Stato: `DONE — TRACKING_CANONICALIZATION_PASS`.
