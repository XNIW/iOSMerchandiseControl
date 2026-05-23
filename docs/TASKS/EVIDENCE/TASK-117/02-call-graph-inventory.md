# 02 - Call Graph Inventory

## Current root / UI graph
- `ContentView` constructs `SupabaseManualSyncForegroundRootHost`.
- `ContentView.tabContent` receives `SupabaseManualSyncViewModel` and passes it into `OptionsView`.
- `SupabaseManualSyncForegroundRootHost` constructs `SyncOrchestrator` with:
  - `SupabaseManualSyncCompatibilityAdapter`
  - `SupabaseManualSyncReleaseFactory.makeViewModel`
  - `SyncAutomaticRuntimeFactory.make`
- Root banner uses `SupabaseManualSyncRootPresentationState` and `SupabaseManualSyncPresentationActionID`.

Target: `ContentView` must not instantiate/pass manual sync VM, compatibility adapter, release factory or manual-named root host.

## Current Options graph
- `OptionsView` stores optional `SupabaseManualSyncViewModel`.
- `SupabaseAutomaticSyncStatusCard` owns a `SupabaseManualSyncViewModel` and creates one through `SupabaseManualSyncReleaseFactory` if none is passed.
- DEBUG `SupabaseManualSyncReleaseCard` also owns/creates `SupabaseManualSyncViewModel`.
- `OptionsSyncSummaryProvider` caches local/baseline/remote count summaries, but Options still hosts manual-VM-backed status.

Target: Options is observer-only for automatic sync. Manual action remains explicit and isolated behind `Sync/Manual` or `ManualSync`.

## Current orchestrator graph
- `SyncOrchestrator` owns `manualAdapter: SyncOrchestratorLegacySyncAdapter`.
- `SyncOrchestrator` exposes `manualSyncViewModel`.
- `SyncOrchestrator` reads `manualAdapter.rootPresentationState`, calls `manualAdapter.runMode`, `manualAdapter.start`, `manualAdapter.applyAuthPresentationContext`, and `manualAdapter.requestLifecycleInterruptionForBackground`.
- Foreground source type is still `SupabaseManualSyncSemiAutomaticTriggerSource`.
- Automatic runtime is used for scheduled `SyncAction`, but presentation/retry/lifecycle remains coupled to legacy manual types.

Target: `SyncOrchestrator` receives clean automatic runtime/domain/presentation protocols with zero `SupabaseManualSync*` automatic-path types.

## Current automatic runtime graph
- `SyncAutomaticRuntime` calls catalog, product price, history, incremental pull and activity providers.
- `SyncAutomaticRuntimeProviders` automatic contracts expose manual DTO/result names including `ManualPushPlan`, `SupabaseManualPushResult`, `ProductPriceManualPushResult`, `SupabaseSyncEventIncrementalApplySummary` and legacy activity/history wrappers.
- `SyncAutomaticRuntimeFactory` wires adapters that also conform to manual protocols in `SupabaseManualSyncReleaseFactory.swift`.

Target: automatic runtime provider contracts use domain-named input/output types only. Manual adapters can exist only inside manual boundary.

## Current incremental graph
- `SyncEventIncrementalPullService` conforms to both `SyncIncrementalPullProviding` and `SupabaseManualSyncIncrementalPullProviding`.
- It delegates to `SyncEventIncrementalDomainApplyService.applyNextEvents`.
- `SupabaseSyncEventIncrementalApplyService.swift` defines the summary DTO and compatibility wrapper.
- Catalog/ProductPrice/History apply services exist physically, but roles of legacy apply/full-pull helpers need execution proof.

Target: `SyncEventIncrementalPullService` owns fetch, dispatch and watermark semantics without legacy wrapper dependency in the automatic path.

## Current outbox graph
- Root-level `SyncEventOutbox*` and `SyncEventRecording*` types are used by app composition, manual push telemetry, debug drains and `Sync/Outbox` facades.
- `SupabaseManualSyncAggregatedPushOutboxProducer` still produces outbox events from manual-named code.

Target: owner-bound automatic push/drain lives under `Sync/Outbox` and does not pass through VM legacy.
