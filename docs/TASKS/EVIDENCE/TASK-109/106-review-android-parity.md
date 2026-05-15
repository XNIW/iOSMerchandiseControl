# TASK-109 — 106 Review Android Parity

Review pass: 2026-05-15 02:25 -0400

Android repo: `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView`

## Stato

- Branch: `main...origin/main`
- Worktree Android: dirty solo in `.idea/deploymentTargetSelector.xml`, non correlato e non toccato.
- Nessuna patch Kotlin applicata in review.
- Nessun Gradle run eseguito perche' Android non e' stato modificato.

## File auditati

- `MerchandiseControlApplication.kt`
- `CatalogAutoSyncCoordinator.kt`
- `CatalogSyncStateTracker.kt`
- `CatalogSyncViewModel.kt`
- `OptionsScreen.kt`
- `SupabaseSessionBackupRemoteDataSource.kt`
- `InventoryRemoteFetchSupport.kt`
- `SharedSheetSessionRecord.kt`
- `SessionRemotePayload.kt`

## Esito parity

- Android ha lifecycle app-scoped: `ProcessLifecycleOwner` avvia foreground coordinators fuori da Options.
- `CatalogSyncStateTracker` centralizza busy/state e impedisce job concorrenti.
- Options Android osserva stato e triggera manual refresh, non possiede un job isolato.
- History push/pull usa `shared_sheet_sessions` con payload v2 compatibile con iOS: `remote_id`, `payload_version`, `display_name`, `timestamp`, `supplier`, `category`, `is_manual_entry`, `data`, `session_overlay`, `owner_user_id`, `updated_at`.
- Fetch remoti Android sono paginati e owner-scoped.

## Note

- Nessuna regressione Android introdotta da TASK-109 perche' nessun file Android e' stato modificato.
- Follow-up non bloccante: se si vuole simmetria runtime piena, rieseguire un Gradle smoke Android app-auth separato. Non blocca la review iOS; il blocker corrente e' iOS app-auth/History live.
