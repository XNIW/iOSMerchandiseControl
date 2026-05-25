# TASK-124 file inventory

- Generated: 2026-05-25T15:37:30+00:00
- Swift files inventoried: 131

## Candidate Matrix

| File | LOC | Classification | Reason |
| --- | ---: | --- | --- |
| none | 0 | KEEP | No static residue candidate found by scanner. |

## Inventory

| File | LOC | Manual | Recovery | Remote domains |
| --- | ---: | --- | --- | --- |
| `iOSMerchandiseControl/ContentView.swift` | 435 | False | False | - |
| `iOSMerchandiseControl/OptionsView.swift` | 1049 | False | False | - |
| `iOSMerchandiseControl/Sync/Account/AccountBindingStore.swift` | 92 | False | False | - |
| `iOSMerchandiseControl/Sync/Account/AccountSwitchPolicy.swift` | 166 | False | False | - |
| `iOSMerchandiseControl/Sync/Account/AccountSyncDecision.swift` | 140 | False | False | - |
| `iOSMerchandiseControl/Sync/Account/AccountSyncDecisionView.swift` | 162 | False | False | - |
| `iOSMerchandiseControl/Sync/Account/LocalStoreIdentity.swift` | 31 | False | False | - |
| `iOSMerchandiseControl/Sync/Automatic/Catalog/CatalogPushPayloads.swift` | 81 | False | False | - |
| `iOSMerchandiseControl/Sync/Automatic/Catalog/CatalogPushService.swift` | 338 | False | False | catalog |
| `iOSMerchandiseControl/Sync/Automatic/Catalog/CatalogRemoteWriting.swift` | 10 | False | False | - |
| `iOSMerchandiseControl/Sync/Automatic/Catalog/SyncCatalogPushModels.swift` | 50 | False | False | - |
| `iOSMerchandiseControl/Sync/Automatic/Composition/AutomaticSyncRuntimeFactory.swift` | 50 | False | False | catalog |
| `iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncCancellationPolicy.swift` | 19 | False | False | - |
| `iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncEngine.swift` | 225 | False | True | catalog |
| `iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncRetryPolicy.swift` | 55 | False | False | - |
| `iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncRuntimeFacade.swift` | 77 | False | False | catalog |
| `iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncSingleFlight.swift` | 24 | False | False | - |
| `iOSMerchandiseControl/Sync/Automatic/Core/SyncAutomaticRunResult.swift` | 61 | False | False | - |
| `iOSMerchandiseControl/Sync/Automatic/Decision/AutomaticDecisionBoundary.swift` | 4 | False | False | - |
| `iOSMerchandiseControl/Sync/Automatic/Decision/SyncAutomaticTriggerSource.swift` | 9 | False | False | - |
| `iOSMerchandiseControl/Sync/Automatic/Decision/SyncDecisionEngine.swift` | 139 | False | True | - |
| `iOSMerchandiseControl/Sync/Automatic/Decision/SyncDecisionInputProvider.swift` | 269 | False | True | options |
| `iOSMerchandiseControl/Sync/Automatic/Decision/SyncTrigger.swift` | 13 | False | False | - |
| `iOSMerchandiseControl/Sync/Automatic/History/HistorySessionAutomaticPushService.swift` | 158 | False | False | - |
| `iOSMerchandiseControl/Sync/Automatic/History/HistorySessionRemoteWriting.swift` | 8 | False | False | - |
| `iOSMerchandiseControl/Sync/Automatic/History/SyncHistorySessionPushModels.swift` | 63 | False | False | - |
| `iOSMerchandiseControl/Sync/Automatic/Outbox/AutomaticSyncEventOutboxWriter.swift` | 88 | False | False | - |
| `iOSMerchandiseControl/Sync/Automatic/Outbox/SyncActivityRegistrationModels.swift` | 54 | False | False | - |
| `iOSMerchandiseControl/Sync/Automatic/Outbox/SyncActivityRegistrationService.swift` | 98 | False | False | options |
| `iOSMerchandiseControl/Sync/Automatic/Presentation/AutomaticPresentationBoundary.swift` | 4 | False | False | - |
| `iOSMerchandiseControl/Sync/Automatic/Presentation/AutomaticSyncReconnectScheduler.swift` | 118 | False | False | - |
| `iOSMerchandiseControl/Sync/Automatic/Presentation/OptionsSyncSummaryProvider.swift` | 330 | False | False | - |
| `iOSMerchandiseControl/Sync/Automatic/Presentation/SyncState.swift` | 54 | False | False | - |
| `iOSMerchandiseControl/Sync/Automatic/Presentation/SyncStateStore.swift` | 136 | False | True | - |
| `iOSMerchandiseControl/Sync/Automatic/Presentation/SyncStatusPresenter.swift` | 48 | False | False | - |
| `iOSMerchandiseControl/Sync/Automatic/ProductPrice/ProductPricePushPayloads.swift` | 25 | False | False | - |
| `iOSMerchandiseControl/Sync/Automatic/ProductPrice/ProductPricePushService.swift` | 267 | False | False | - |
| `iOSMerchandiseControl/Sync/Automatic/ProductPrice/ProductPriceRemoteWriting.swift` | 5 | False | False | - |
| `iOSMerchandiseControl/Sync/Automatic/ProductPrice/SyncProductPricePushModels.swift` | 38 | False | False | - |
| `iOSMerchandiseControl/Sync/Automatic/Pull/AutomaticPullBoundary.swift` | 4 | False | False | - |
| `iOSMerchandiseControl/Sync/Automatic/Pull/CatalogIncrementalApplyService.swift` | 209 | False | False | catalog |
| `iOSMerchandiseControl/Sync/Automatic/Pull/CatalogIncrementalApplySummary.swift` | 35 | False | False | catalog |
| `iOSMerchandiseControl/Sync/Automatic/Pull/HistoryIncrementalApplyService.swift` | 244 | False | False | - |
| `iOSMerchandiseControl/Sync/Automatic/Pull/HistoryIncrementalApplySummary.swift` | 24 | False | False | - |
| `iOSMerchandiseControl/Sync/Automatic/Pull/ProductPriceIncrementalApplyService.swift` | 175 | False | False | - |
| `iOSMerchandiseControl/Sync/Automatic/Pull/ProductPriceIncrementalApplySummary.swift` | 25 | False | False | - |
| `iOSMerchandiseControl/Sync/Automatic/Pull/SyncEventIncrementalApplyHelpers.swift` | 421 | False | False | - |
| `iOSMerchandiseControl/Sync/Automatic/Pull/SyncEventIncrementalContracts.swift` | 48 | False | True | - |
| `iOSMerchandiseControl/Sync/Automatic/Pull/SyncEventIncrementalDomainApplyService.swift` | 268 | False | True | catalog |
| `iOSMerchandiseControl/Sync/Automatic/Pull/SyncEventIncrementalPullService.swift` | 41 | False | False | - |
| `iOSMerchandiseControl/Sync/Automatic/Pull/SyncIncrementalPullSummary.swift` | 68 | False | True | catalog |
| `iOSMerchandiseControl/Sync/Automatic/Pull/WatermarkStore.swift` | 98 | False | False | - |
| `iOSMerchandiseControl/Sync/AutomaticPushServices.swift` | 1 | False | False | - |
| `iOSMerchandiseControl/Sync/Manual/CloudSyncOverviewState.swift` | 337 | True | False | catalog |
| `iOSMerchandiseControl/Sync/Manual/HistorySessionPayloadSnapshotFactory.swift` | 26 | False | False | - |
| `iOSMerchandiseControl/Sync/Manual/HistorySessionSyncService.swift` | 400 | False | False | - |
| `iOSMerchandiseControl/Sync/Manual/LocalPendingAggregatedPushPlanner.swift` | 1222 | False | False | catalog, options |
| `iOSMerchandiseControl/Sync/Manual/ManualSyncBoundary.swift` | 4 | True | False | - |
| `iOSMerchandiseControl/Sync/Manual/ProductPriceManualPushDebugViewModel.swift` | 381 | False | False | - |
| `iOSMerchandiseControl/Sync/Manual/SupabaseCatalogBaselineModels.swift` | 134 | False | False | - |
| `iOSMerchandiseControl/Sync/Manual/SupabaseCatalogBaselineReader.swift` | 331 | False | False | - |
| `iOSMerchandiseControl/Sync/Manual/SupabaseCatalogBaselineWriter.swift` | 296 | False | False | - |
| `iOSMerchandiseControl/Sync/Manual/SupabaseCatalogFingerprintNormalizer.swift` | 79 | False | False | - |
| `iOSMerchandiseControl/Sync/Manual/SupabaseManualPushPreflightModels.swift` | 537 | False | False | options |
| `iOSMerchandiseControl/Sync/Manual/SupabaseManualPushPreflightService.swift` | 872 | False | False | catalog |
| `iOSMerchandiseControl/Sync/Manual/SupabaseManualPushService.swift` | 1149 | False | False | catalog |
| `iOSMerchandiseControl/Sync/Manual/SupabaseManualSyncBaselineCommitter.swift` | 77 | True | False | - |
| `iOSMerchandiseControl/Sync/Manual/SupabaseManualSyncCoordinating.swift` | 9 | True | False | - |
| `iOSMerchandiseControl/Sync/Manual/SupabaseManualSyncCoordinator.swift` | 650 | True | False | catalog, options |
| `iOSMerchandiseControl/Sync/Manual/SupabaseManualSyncCoordinatorModels.swift` | 106 | True | False | catalog, options |
| `iOSMerchandiseControl/Sync/Manual/SupabaseManualSyncLifecycleRunGate.swift` | 303 | True | False | - |
| `iOSMerchandiseControl/Sync/Manual/SupabaseManualSyncLocalPendingSnapshotProvider.swift` | 314 | True | False | catalog, options |
| `iOSMerchandiseControl/Sync/Manual/SupabaseManualSyncOutboxProducerConversions.swift` | 77 | False | False | catalog |
| `iOSMerchandiseControl/Sync/Manual/SupabaseManualSyncReleaseActivityRegistrationAdapter.swift` | 147 | True | False | options |
| `iOSMerchandiseControl/Sync/Manual/SupabaseManualSyncReleaseFactory.swift` | 846 | True | False | catalog, options |
| `iOSMerchandiseControl/Sync/Manual/SupabaseManualSyncRemotePreview.swift` | 337 | True | False | options |
| `iOSMerchandiseControl/Sync/Manual/SupabaseManualSyncSemiAutomaticPolicy.swift` | 86 | True | False | - |
| `iOSMerchandiseControl/Sync/Manual/SupabaseManualSyncViewModel.swift` | 6550 | True | True | catalog, options, product_price |
| `iOSMerchandiseControl/Sync/Manual/SupabaseProductPriceManualPushService.swift` | 746 | False | False | product_price |
| `iOSMerchandiseControl/Sync/Manual/SupabaseProductPricePreviewService.swift` | 361 | False | False | - |
| `iOSMerchandiseControl/Sync/Manual/SupabaseProductPricePushDryRunService.swift` | 882 | False | False | - |
| `iOSMerchandiseControl/Sync/Manual/SupabasePushPreflightViewModel.swift` | 441 | False | False | - |
| `iOSMerchandiseControl/Sync/Manual/SupabaseSyncEventDebugFormatting.swift` | 206 | False | False | - |
| `iOSMerchandiseControl/Sync/Manual/SupabaseSyncEventDebugViewModel.swift` | 171 | False | False | - |
| `iOSMerchandiseControl/Sync/Manual/SupabaseSyncEventIncrementalApplyService.swift` | 219 | False | True | catalog |
| `iOSMerchandiseControl/Sync/Manual/SupabaseSyncEventPreviewService.swift` | 183 | False | False | sync_events |
| `iOSMerchandiseControl/Sync/Manual/SupabaseSyncPlanContract.swift` | 203 | False | False | - |
| `iOSMerchandiseControl/Sync/Manual/SyncEventOutboxDrainDebugViewModel.swift` | 343 | False | False | options |
| `iOSMerchandiseControl/Sync/Outbox/LocalOutboxStore.swift` | 34 | False | False | - |
| `iOSMerchandiseControl/Sync/Outbox/PendingChangeCoalescer.swift` | 59 | False | False | - |
| `iOSMerchandiseControl/Sync/Outbox/SyncEventOutboxDrainService.swift` | 471 | False | True | - |
| `iOSMerchandiseControl/Sync/Outbox/SyncEventOutboxDrainer.swift` | 29 | False | False | - |
| `iOSMerchandiseControl/Sync/Outbox/SyncEventOutboxEnqueueService.swift` | 517 | False | False | catalog |
| `iOSMerchandiseControl/Sync/Outbox/SyncEventOutboxEntry.swift` | 546 | False | True | options |
| `iOSMerchandiseControl/Sync/Outbox/SyncEventOutboxRecorder.swift` | 15 | False | False | - |
| `iOSMerchandiseControl/Sync/Outbox/SyncEventOutboxState.swift` | 523 | False | True | - |
| `iOSMerchandiseControl/Sync/Recovery/BootstrapPullService.swift` | 20 | False | True | - |
| `iOSMerchandiseControl/Sync/Recovery/DriftReconciliationService.swift` | 21 | False | True | - |
| `iOSMerchandiseControl/Sync/Recovery/FullRecoveryService.swift` | 20 | False | True | - |
| `iOSMerchandiseControl/Sync/Recovery/InventorySyncService.swift` | 287 | False | True | - |
| `iOSMerchandiseControl/Sync/Recovery/RecoveryRemoteSupabaseAdapter.swift` | 27 | False | True | catalog |
| `iOSMerchandiseControl/Sync/Recovery/SupabaseProductPriceApplyService.swift` | 1783 | False | False | options, product_price |
| `iOSMerchandiseControl/Sync/Recovery/SupabasePullApplyService.swift` | 1752 | False | False | - |
| `iOSMerchandiseControl/Sync/Recovery/SupabasePullPreviewModels.swift` | 627 | False | False | options |
| `iOSMerchandiseControl/Sync/Recovery/SupabasePullPreviewService.swift` | 1018 | False | False | catalog, options, product_price |
| `iOSMerchandiseControl/Sync/Recovery/SwiftDataInventorySnapshotService.swift` | 341 | False | False | options |
| `iOSMerchandiseControl/Sync/Recovery/SyncCountReconciliation.swift` | 226 | False | False | - |
| `iOSMerchandiseControl/Sync/Remote/CatalogRemoteSupabaseAdapter.swift` | 159 | False | False | catalog |
| `iOSMerchandiseControl/Sync/Remote/HistorySessionRemoteSupabaseAdapter.swift` | 132 | False | False | - |
| `iOSMerchandiseControl/Sync/Remote/OptionsRemoteCountSupabaseAdapter.swift` | 47 | False | False | catalog, product_price |
| `iOSMerchandiseControl/Sync/Remote/ProductPriceManualPushRemoteSupabaseAdapter.swift` | 106 | False | False | catalog, product_price |
| `iOSMerchandiseControl/Sync/Remote/ProductPricePreviewRemoteSupabaseAdapter.swift` | 116 | False | False | product_price |
| `iOSMerchandiseControl/Sync/Remote/ProductPriceReleaseRemoteSupabaseAdapter.swift` | 67 | False | False | - |
| `iOSMerchandiseControl/Sync/Remote/ProductPriceRemoteSupabaseAdapter.swift` | 64 | False | False | product_price |
| `iOSMerchandiseControl/Sync/Remote/SupabaseInventoryDTOs.swift` | 96 | False | False | - |
| `iOSMerchandiseControl/Sync/Remote/SupabaseRemoteQueryExecutor.swift` | 183 | False | False | - |
| `iOSMerchandiseControl/Sync/Remote/SupabaseSyncEventDTOs.swift` | 238 | False | False | - |
| `iOSMerchandiseControl/Sync/Remote/SupabaseSyncEventLiveRecorder.swift` | 293 | False | False | - |
| `iOSMerchandiseControl/Sync/Remote/SupabaseSyncEventRPCTransport.swift` | 44 | False | False | - |
| `iOSMerchandiseControl/Sync/Remote/SupabaseSyncEventRealtimeWatcher.swift` | 72 | False | False | sync_events |
| `iOSMerchandiseControl/Sync/Remote/SupabaseTransportClient.swift` | 117 | False | False | - |
| `iOSMerchandiseControl/Sync/Remote/SyncEventRPCRequestMapper.swift` | 221 | False | False | catalog |
| `iOSMerchandiseControl/Sync/Remote/SyncEventRecording.swift` | 633 | False | False | - |
| `iOSMerchandiseControl/Sync/Remote/SyncEventRemoteSupabaseAdapter.swift` | 104 | False | False | catalog, sync_events |
| `iOSMerchandiseControl/Sync/Shared/AutomaticSharedBoundary.swift` | 4 | False | False | - |
| `iOSMerchandiseControl/Sync/Shared/HistorySessionSyncShared.swift` | 297 | False | False | - |
| `iOSMerchandiseControl/Sync/Shared/SyncStringCollectionHelpers.swift` | 7 | False | False | - |
| `iOSMerchandiseControl/Sync/SyncAutomaticRuntimeProviders.swift` | 2 | False | False | - |
| `iOSMerchandiseControl/Sync/SyncOrchestrator.swift` | 472 | False | True | - |
| `iOSMerchandiseControl/Sync/SyncRecoveryPolicy.swift` | 68 | False | True | - |
| `iOSMerchandiseControl/iOSMerchandiseControlApp.swift` | 134 | False | True | catalog |
