# TASK-108 Evidence 31 — Android Sync Progress Parity Audit

Date: 2026-05-13 23:45 -0400

Scope: code-level audit of the Android repo at `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView`.

Files inspected:
- `app/src/main/java/com/example/merchandisecontrolsplitview/data/InventoryRepository.kt`
- `app/src/main/java/com/example/merchandisecontrolsplitview/data/CatalogSyncStateTracker.kt`
- `app/src/main/java/com/example/merchandisecontrolsplitview/viewmodel/CatalogSyncViewModel.kt`
- `app/src/main/java/com/example/merchandisecontrolsplitview/ui/components/CloudSyncIndicator.kt`
- `app/src/main/java/com/example/merchandisecontrolsplitview/ui/screens/OptionsScreen.kt`
- `app/src/main/java/com/example/merchandisecontrolsplitview/ui/navigation/NavGraph.kt`
- `app/src/main/java/com/example/merchandisecontrolsplitview/data/SupabaseProductPriceRemoteDataSource.kt`

Android progress model:
- Android already has structured progress via `CatalogSyncProgressState(stage, current, total, isBusy, status)`.
- Stages observed: `IDLE`, `REALIGN`, `PUSH_SUPPLIERS`, `PUSH_CATEGORIES`, `PUSH_PRODUCTS`, `PULL_CATALOG`, `SYNC_PRICES`, `SYNC_PRICES_PUSH`, `SYNC_PRICES_PULL`, `SYNC_EVENTS_DRAIN`, `SYNC_HISTORY`, `COMPLETED`.
- `InventoryRepository.syncCatalogWithRemote` runs on `Dispatchers.IO` and emits `sync_start`, `sync_stage`, and `sync_finish` logs with phase durations and counts.
- `CloudSyncIndicator` surfaces current phase and optional `current / total` count instead of only `In progress`.

Android unified flow:
- Full manual `refreshCatalog()` runs catalog sync, ProductPrice sync and History/session cloud refresh in one operation.
- Catalog push and pull are in the repository flow.
- ProductPrice pull is paged through remote datasource helpers; ProductPrice push is chunked.
- History/session refresh is triggered from the full catalog sync path after catalog/prices.
- Quick/event sync still exists internally, but the public Options surface previously exposed two user actions.

What Android did better:
- Explicit stage enum and `current / total` progress.
- Repository work off the UI dispatcher.
- Structured `sync_start` / `sync_stage` / `sync_finish` logs.
- Full public refresh includes catalog, prices and history/session.
- Root indicator communicates phase without blocking navigation.

What iOS copied/adapted:
- Added `CloudSyncProgressState` / `CloudSyncProgressPhase` / `CloudSyncProgressDomain`.
- Added progress for checking cloud, remote counts, review, catalog apply, ProductPrice paged apply, History/session push/pull and outbox send/drain.
- Root banner and Options now show progress messages/counts.
- Global iOS sync path now calls catalog apply, paged ProductPrice apply and History/session push/pull from the same local-apply flow.

Android change made for parity:
- Public Options cloud section now exposes a single action, `Sync now` / localized equivalent, mapped to the full refresh path.
- The old quick sync code remains available internally for auto/event/retry paths, but it is no longer a second public cloud action.

Evidence:
- Android `assembleDebug`: PASS.
- Android `testDebugUnitTest --tests '*CatalogSync*'`: PASS.
- Android device smoke on OnePlus IN2013: PASS; signed-out Options cloud card shows one `立即同步` action and describes catalog/prices/history/local changes.
- Screenshot: `screenshots/2026-05-13-android-options-single-sync-now.png`.

Post-TASK-108 targeted FIX update 2026-05-14 00:38 -0400:
- Android Options now also includes an iOS-equivalent compact `Local database status` card.
- Data source: `CatalogSyncViewModel` exposes `LocalDatabaseStatusUiState`; `InventoryRepository.getLocalDatabaseStatusSnapshot()` reads counts on `Dispatchers.IO`.
- Displayed metrics: products, suppliers, categories, price history, History sessions, pending local changes, last sync/check and cloud account state when available.
- The card does not add another cloud sync CTA.
- Build/test/device smoke passed after the Android parity addition.
