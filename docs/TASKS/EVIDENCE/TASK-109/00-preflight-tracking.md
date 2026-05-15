# TASK-109 — 00 Preflight / Tracking

Data: 2026-05-15 00:33 -0400  
Modalita': EXECUTION DIAGNOSTICA — Wave 1 non mutativa

## Branch / remote / HEAD

- Repo iOS: `/Users/minxiang/Desktop/iOSMerchandiseControl`
- Branch corrente: `main`
- HEAD locale: `48a6956a80ae6fdb8d205359ac78147ad1ac4b78` (`Task 108.2`)
- Remote: `origin https://github.com/XNIW/iOSMerchandiseControl.git`
- `origin/main` dopo `git fetch --prune origin`: `48a6956a80ae6fdb8d205359ac78147ad1ac4b78`

## Stato git redatto

Il worktree era gia' dirty all'ingresso di questa execution. Non ho eseguito revert.

File modificati prima della Wave 1:

- `docs/MASTER-PLAN.md`
- `iOSMerchandiseControl/AppNavigationNotifications.swift`
- `iOSMerchandiseControl/HistoryImportedGridSupport.swift`
- `iOSMerchandiseControl/HistorySessionSyncService.swift`
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/SupabaseManualSyncReleaseFactory.swift`
- `iOSMerchandiseControl/SupabaseManualSyncViewModel.swift`
- `iOSMerchandiseControl/en.lproj/Localizable.strings`
- `iOSMerchandiseControl/es.lproj/Localizable.strings`
- `iOSMerchandiseControl/it.lproj/Localizable.strings`
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`
- `iOSMerchandiseControlTests/HistorySessionSyncServiceTests.swift`
- `iOSMerchandiseControlTests/SupabaseManualSyncViewModelTests.swift`

File/cartelle non tracciati prima della Wave 1:

- `docs/TASKS/EVIDENCE/TASK-109/`
- `docs/TASKS/TASK-109-ios-supabase-sync-lifecycle-ux-regression.md`
- `iOSMerchandiseControlTests/HistoryViewStateTests.swift`
- `iOSMerchandiseControlTests/OptionsLocalDatabaseSummaryTests.swift`

Diff stat preflight: 13 file gia' modificati, 489 insertions, 69 deletions, piu' file non tracciati.

Nota operativa: questa evidence registra la baseline corrente. Per rispettare il workflow, non aggiungo nuove modifiche Swift/Kotlin/SQL prima della Wave 1 diagnostica; le modifiche app gia' presenti verranno lette e trattate come contesto esistente del worktree.

## Tracking reconciliation

Prima del pass:

- `docs/MASTER-PLAN.md`: `TASK-109 ACTIVE / PLANNING`
- file task: `Fase attuale: PLANNING`
- `TASK-108`: storico `DONE / PASS_WITH_NOTES`, non riaperto

Dopo il pass documentale:

- `docs/MASTER-PLAN.md`: `TASK-109 ACTIVE / EXECUTION DIAGNOSTICA`
- file task: `Fase attuale: EXECUTION DIAGNOSTICA — Wave 1`
- `TASK-108`: resta storico `DONE / PASS_WITH_NOTES`

La transizione e' solo tracking/evidence. Nessuna nuova patch Swift/Kotlin/SQL/migration e nessun claim PASS/DONE.

## Device / simulator disponibili

Simulatore booted:

- `iPhone 15 Pro Max`, iOS 26.1, UDID `459C668B-7CE8-443B-BAB3-7D3D5FFC9143`

Altri simulatori disponibili: iPhone 17/17 Pro/17 Pro Max/Air/16e e iPad family su runtime iOS 26.1, 26.2, 26.4, 26.5.

`xcodebuild -list -project iOSMerchandiseControl.xcodeproj`:

- Scheme: `iOSMerchandiseControl`
- Targets: `iOSMerchandiseControl`, `iOSMerchandiseControlTests`
- Configurations: `Debug`, `Release`

## Supabase / backend

- Repo Supabase locale: `/Users/minxiang/Desktop/MerchandiseControlSupabase`
- Project ref redatto da tracking locale: `jpgo…kyvm`
- Stato live non ancora verificato in questa Wave 1.
- Vincoli confermati: niente `service_role` nel client, niente bypass RLS, niente reset globale, eventuali write solo scoped e documentati se necessari nelle fasi successive.

## Decisione Gate 1

Gate 1 soddisfatto per avviare Wave 1 diagnostica:

- task attivo riconciliato nel MASTER-PLAN e nel file TASK-109;
- TASK-108 resta storico;
- evidence folder presente;
- simulator disponibile;
- Supabase project/ref redatto noto da tracking;
- nessuna nuova modifica app introdotta prima della diagnostica.

Decisione: procedo a Wave 1 diagnostica.
