# TASK-109 — 108 Review Build/Test Results

Review pass: 2026-05-15 02:25 -0400

## Checks

- `git diff --check`: PASS.
- `plutil -lint` EN/IT/ES/ZH `Localizable.strings`: PASS.
- Debug build XcodeBuildMCP: PASS, warnings `0`.
- Release build XcodeBuildMCP: PASS, warnings `0`.

## Build artifacts

- Debug build log: `/Users/minxiang/Library/Developer/XcodeBuildMCP/workspaces/iOSMerchandiseControl-3314632fed98/logs/build_sim_2026-05-15T06-11-00-018Z_pid52866_c40096af.log`
- Release build log: `/Users/minxiang/Library/Developer/XcodeBuildMCP/workspaces/iOSMerchandiseControl-3314632fed98/logs/build_sim_2026-05-15T06-11-16-541Z_pid52866_665ac231.log`
- Runtime build/run log: `/Users/minxiang/Library/Developer/XcodeBuildMCP/workspaces/iOSMerchandiseControl-3314632fed98/logs/build_run_sim_2026-05-15T06-19-56-871Z_pid52866_4a45f1c5.log`

## XCTest

Primo run:

- Simulator: iPhone 15 Pro Max iOS 26.1
- Esito: ambiente failed before tests.
- Errore: CoreSimulator failed to clone booted device.
- Log: `logs/108-review-targeted-xctest.log`

Rerun:

- Simulator: iPhone 17 Pro iOS 26.5
- Esito: PASS.
- Output: `** TEST SUCCEEDED **`
- xcresult: `/Users/minxiang/Library/Developer/Xcode/DerivedData/iOSMerchandiseControl-hipxsmlvmjphcyaknnsmrggoalrx/Logs/Test/Test-iOSMerchandiseControl-2026.05.15_02-16-00--0400.xcresult`
- Log: `logs/108-review-targeted-xctest-rerun-iphone17pro.log`

Suite incluse:

- `SupabaseManualSyncViewModelTests`
- `SupabaseManualSyncReleaseUITests`
- `CloudSyncOverviewStateTests`
- `SupabaseManualSyncCoordinatorTests`
- `SupabaseManualSyncLifecycleRunGateTests`
- `SupabaseManualSyncLocalPendingSnapshotProviderTests`
- `SupabaseManualSyncReleaseActivityRegistrationAdapterTests`
- `SupabaseManualSyncRemotePreviewTests`
- `LocalPendingAggregatedPushPlannerTests`
- `InventorySyncServiceTests`
- `HistorySessionSyncServiceTests`
- `HistoryViewStateTests`
- `OptionsLocalDatabaseSummaryTests`
- `SupabasePullPreviewDiffEngineTests`
- `SupabasePullPreviewPaginationTests`
- `SupabasePullApplyServiceTests`
- `SupabaseProductPriceApplyServiceTests`
- `SupabaseProductPricePreviewServiceTests`
- `SupabaseProductPricePushDryRunServiceTests`
- `SupabaseProductPriceManualPushServiceTests`
- `LocalizationCoverageTests`

## Warning note

The Xcode test log includes the usual AppIntents metadata extraction warning for the test bundle. The actual Debug/Release build diagnostics reported warnings `0`.
