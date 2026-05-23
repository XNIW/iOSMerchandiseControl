# TASK-117 - Call Graph Execution Audit

Date: 2026-05-23 17:48:36 -0400

## Result
Local call graph `PASS`; live/device validation remains `BLOCKED_EXTERNAL`.

## Mapped paths
- `ContentView -> AppSyncRootHost -> SyncOrchestrator -> SyncAutomaticRuntime`
- `OptionsView -> OptionsSyncSummaryProvider / SyncStatusPresenter` for public observation
- `SyncOrchestrator -> SyncDecisionEngine -> SyncStateStore -> SyncAutomaticRuntime`
- `SyncAutomaticRuntime -> SyncCatalogPushProviding / SyncProductPriceSyncProviding / SyncHistorySessionPushProviding / SyncIncrementalPullProviding / SyncActivityRegistrationProviding`
- `SyncEventIncrementalPullService -> SyncEventIncrementalDomainApplyService -> Catalog/ProductPrice/History incremental apply services`
- `Local pending changes -> SyncOrchestrator.handleLocalPendingChanges -> SyncAutomaticRuntime.pushPending`
- Manual sync explicit VM/factory remains outside the automatic call graph.

## Evidence
- `20260523T214343Z-scan-no-legacy-runtime-path-task-TASK-117-p88591`
- `20260523T214343Z-scan-no-full-pull-normal-path-task-TASK-117-p88592`
- `20260523T214520Z-ios-test-sync-task-TASK-117-p90749`
