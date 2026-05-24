# TASK-121 root residue resolution ledger

Generated for the continuation fix pass on 2026-05-24.

## Summary

- before: 10 root residues
- target after: 0 root residues
- action model: physical moves only, no root compatibility shims
- Xcode membership model: synchronized groups / no explicit `project.pbxproj` hits for these file names before the move
- final anti-false-positive pass: additional root sync-related files moved/re-homed, including `SupabaseInventoryService.swift` -> `Sync/Remote/SupabaseTransportClient.swift`
- final root allowlist: `SupabaseAuthService.swift`, `SupabaseAuthViewModel.swift`, `SupabaseClientProvider.swift`, `SupabaseConfig.swift`

## Entries

### InventorySyncService.swift

old_path: `iOSMerchandiseControl/InventorySyncService.swift`
new_path: `iOSMerchandiseControl/Sync/Recovery/InventorySyncService.swift`
action: move
owner: Recovery
reason: local `HistoryEntry` inventory apply service with `ModelContext` side effects; it is recovery/import apply behavior and cannot remain in the app root.
symbols/types affected: `InventorySyncService`, `InventorySyncService.SyncResult`
callers before: `iOSMerchandiseControlTests/InventorySyncServiceTests.swift`
callers after: unchanged symbol callers; source path is now under `Sync/Recovery`
Xcode membership before: synchronized_or_unlisted; no explicit `project.pbxproj` path hit
Xcode membership after: synchronized_or_unlisted; verified by `scan xcode-membership`
tests required: source-format, xcode-membership, duplicate-symbols, dead-code, root-residue, iOS build/test matrix
rollback command: `git mv iOSMerchandiseControl/Sync/Recovery/InventorySyncService.swift iOSMerchandiseControl/InventorySyncService.swift`
scanner checks: `scan root-residue`, `scan sync-inventory`, `scan xcode-membership`
evidence report: `docs/TASKS/EVIDENCE/TASK-121/agent-runs/`

## Final anti-false-positive additional moves

### SupabaseInventoryService.swift

old_path: `iOSMerchandiseControl/SupabaseInventoryService.swift`
new_path: `iOSMerchandiseControl/Sync/Remote/SupabaseTransportClient.swift`
action: move
owner: Remote
reason: root mega-service residue remained after the earlier `10 -> 0` claim; concrete Supabase transport belongs in `Sync/Remote`.
symbols/types affected: `SupabaseInventoryService`, `SupabaseInventoryServiceError`, `SupabaseInventoryDiagnosticResult`, remote catalog/product-price/history/sync-event methods
callers before: `ContentView`, automatic runtime factory, manual sync release factory, recovery/product-price services, acceptance tests
callers after: automatic/history/incremental callers use Remote adapters; manual product-price protocols remain manual-only
Xcode membership before: synchronized_or_unlisted
Xcode membership after: synchronized_or_unlisted; verified by `scan xcode-membership`
tests required: source-format, root-residue, sync-inventory, manual-boundary, duplicate-symbols, debug/release build, automatic tests, sync tests, manual regression
rollback command: `git mv iOSMerchandiseControl/Sync/Remote/SupabaseTransportClient.swift iOSMerchandiseControl/SupabaseInventoryService.swift`
scanner checks: `scan root-residue`, `scan sync-inventory`, `scan xcode-membership`, `scan duplicate-symbols`
evidence report: `docs/TASKS/EVIDENCE/TASK-121/agent-runs/`

### Additional categorized root sync files

old_path: `iOSMerchandiseControl/AutomaticSyncReconnectScheduler.swift`
new_path: `iOSMerchandiseControl/Sync/Automatic/Presentation/AutomaticSyncReconnectScheduler.swift`
action: move
owner: Automatic Presentation
reason: reconnect presentation scheduler is sync-related and cannot remain root.
symbols/types affected: `AutomaticSyncReconnectScheduler`
callers before: automatic/domain tests and app wiring
callers after: unchanged symbol callers; path-sensitive tests updated
Xcode membership before: synchronized_or_unlisted
Xcode membership after: synchronized_or_unlisted
tests required: automatic-domain, automatic-architecture, debug/release build
rollback command: `git mv iOSMerchandiseControl/Sync/Automatic/Presentation/AutomaticSyncReconnectScheduler.swift iOSMerchandiseControl/AutomaticSyncReconnectScheduler.swift`
scanner checks: `scan root-residue`, `scan manual-boundary`, `scan xcode-membership`
evidence report: `docs/TASKS/EVIDENCE/TASK-121/agent-runs/`

old_path: `iOSMerchandiseControl/CloudSyncOverviewState.swift`
new_path: `iOSMerchandiseControl/Sync/Manual/CloudSyncOverviewState.swift`
action: move
owner: Manual
reason: release/manual overview state references manual preview categories; automatic boundary scanner rejected automatic placement.
symbols/types affected: `CloudSync*`
callers before: options/manual UI
callers after: unchanged symbol callers
Xcode membership before: synchronized_or_unlisted
Xcode membership after: synchronized_or_unlisted
tests required: manual-boundary, manual sync regression, debug/release build
rollback command: `git mv iOSMerchandiseControl/Sync/Manual/CloudSyncOverviewState.swift iOSMerchandiseControl/CloudSyncOverviewState.swift`
scanner checks: `scan manual-boundary`, `scan root-residue`
evidence report: `docs/TASKS/EVIDENCE/TASK-121/agent-runs/`

Batch moves:
- Manual: `LocalPendingAggregatedPushPlanner.swift`, `SupabaseCatalogBaselineModels.swift`, `SupabaseCatalogBaselineReader.swift`, `SupabaseCatalogBaselineWriter.swift`, `SupabaseCatalogFingerprintNormalizer.swift`, `SupabaseSyncEventDebugFormatting.swift`, `SupabaseSyncEventDebugViewModel.swift`, `SupabaseSyncPlanContract.swift`, `SyncEventOutboxDrainDebugViewModel.swift`
- Recovery: `SupabaseProductPriceApplyService.swift`, `SwiftDataInventorySnapshotService.swift`, `SyncCountReconciliation.swift`
- Remote: `SupabaseInventoryDTOs.swift`, `SupabaseSyncEventDTOs.swift`, `SupabaseSyncEventLiveRecorder.swift`, `SupabaseSyncEventRPCTransport.swift`, `SupabaseSyncEventRealtimeWatcher.swift`, `SyncEventRPCRequestMapper.swift`, `SyncEventRecording.swift`
- Outbox: `SyncEventOutboxEntry.swift`, `SyncEventOutboxState.swift`

Each batch move uses the same rollback pattern: `git mv <new_path> <old_path>`. Callers remain symbol-based in the same Swift module; path-sensitive tests were updated where present.

### SupabaseProductPricePreviewService.swift

old_path: `iOSMerchandiseControl/SupabaseProductPricePreviewService.swift`
new_path: `iOSMerchandiseControl/Sync/Manual/SupabaseProductPricePreviewService.swift`
action: move
owner: Manual
reason: manual/debug product price preview and local lookup support; not automatic runtime ownership.
symbols/types affected: `SupabaseProductPricePreviewFetching`, `SupabaseProductPriceKeysetFetching`, `SupabaseProductPriceDeletedProductFetching`, `ProductPricePreviewOptions`, `ProductPricePreviewSummary`, `SupabaseProductPricePreviewService`
callers before: `iOSMerchandiseControlTests/SupabaseProductPricePreviewServiceTests.swift`
callers after: unchanged symbol callers; path-sensitive test source helper updated
Xcode membership before: synchronized_or_unlisted; no explicit `project.pbxproj` path hit
Xcode membership after: synchronized_or_unlisted; verified by `scan xcode-membership`
tests required: product price preview tests via sync/manual regression matrix, source-format, duplicate-symbols, root-residue
rollback command: `git mv iOSMerchandiseControl/Sync/Manual/SupabaseProductPricePreviewService.swift iOSMerchandiseControl/SupabaseProductPricePreviewService.swift`
scanner checks: `scan root-residue`, `scan manual-boundary`, `scan sync-inventory`
evidence report: `docs/TASKS/EVIDENCE/TASK-121/agent-runs/`

### SupabaseProductPricePushDryRunService.swift

old_path: `iOSMerchandiseControl/SupabaseProductPricePushDryRunService.swift`
new_path: `iOSMerchandiseControl/Sync/Manual/SupabaseProductPricePushDryRunService.swift`
action: move
owner: Manual
reason: manual product-price push dry-run planner and diagnostics; not automatic runtime ownership.
symbols/types affected: `SupabaseProductPricePushDryRunRemoteFetching`, `ProductPricePushDryRun*`, `SupabaseProductPricePushDryRunService`
callers before: `Sync/Manual/ProductPriceManualPushDebugViewModel.swift`, `iOSMerchandiseControlTests/SupabaseProductPricePushDryRunServiceTests.swift`, `iOSMerchandiseControlTests/SupabaseProductPriceManualPushServiceTests.swift`, `iOSMerchandiseControlTests/Task103CrossPlatformAcceptanceTests.swift`
callers after: unchanged symbol callers; path-sensitive test source helper updated
Xcode membership before: synchronized_or_unlisted; no explicit `project.pbxproj` path hit
Xcode membership after: synchronized_or_unlisted; verified by `scan xcode-membership`
tests required: manual sync regression, product price push dry-run tests, source-format, duplicate-symbols, root-residue
rollback command: `git mv iOSMerchandiseControl/Sync/Manual/SupabaseProductPricePushDryRunService.swift iOSMerchandiseControl/SupabaseProductPricePushDryRunService.swift`
scanner checks: `scan root-residue`, `scan manual-boundary`, `scan sync-inventory`
evidence report: `docs/TASKS/EVIDENCE/TASK-121/agent-runs/`

### SupabasePullApplyService.swift

old_path: `iOSMerchandiseControl/SupabasePullApplyService.swift`
new_path: `iOSMerchandiseControl/Sync/Recovery/SupabasePullApplyService.swift`
action: move
owner: Recovery
reason: full pull/local apply service with SwiftData mutations; recovery/apply boundary rather than app root.
symbols/types affected: `SupabasePullApplyOptions`, `SupabasePullApplyPlan`, `SupabasePullApplyResult`, `SupabasePullApplyService`, related apply DTOs/errors
callers before: `Sync/Manual/SupabaseManualSyncReleaseFactory.swift`, `Sync/Manual/SupabaseManualSyncViewModel.swift`, `iOSMerchandiseControlTests/SupabasePullApplyServiceTests.swift`, `iOSMerchandiseControlTests/SupabaseCatalogBaselinePreflightIntegrationTests.swift`, `iOSMerchandiseControlTests/Task098CrossPlatformSmokeTests.swift`, `iOSMerchandiseControlTests/Task103CrossPlatformAcceptanceTests.swift`
callers after: unchanged symbol callers; exact source-path test updated to `Sync/Recovery`
Xcode membership before: synchronized_or_unlisted; no explicit `project.pbxproj` path hit
Xcode membership after: synchronized_or_unlisted; verified by `scan xcode-membership`
tests required: sync tests, manual sync regression, SupabasePullApplyService tests, source-format, duplicate-symbols, root-residue
rollback command: `git mv iOSMerchandiseControl/Sync/Recovery/SupabasePullApplyService.swift iOSMerchandiseControl/SupabasePullApplyService.swift`
scanner checks: `scan root-residue`, `scan sync-architecture`, `scan sync-inventory`
evidence report: `docs/TASKS/EVIDENCE/TASK-121/agent-runs/`

### SupabasePullPreviewModels.swift

old_path: `iOSMerchandiseControl/SupabasePullPreviewModels.swift`
new_path: `iOSMerchandiseControl/Sync/Recovery/SupabasePullPreviewModels.swift`
action: move
owner: Recovery
reason: pull preview/apply DTOs and normalizers support recovery/full pull behavior; no root residue and no Shared side-effect leakage.
symbols/types affected: `SyncPreview*`, `RemoteInventorySnapshot`, `LocalInventorySnapshot`, `SupabasePullPreviewError`, `SupabasePullPreviewViewState`, `SupabasePullPreviewNormalizer`
callers before: pull preview/apply/product-price services, `SwiftDataInventorySnapshotService.swift`, `Sync/Automatic/Pull/*`, related tests
callers after: unchanged symbol callers; file path is under `Sync/Recovery`
Xcode membership before: synchronized_or_unlisted; no explicit `project.pbxproj` path hit
Xcode membership after: synchronized_or_unlisted; verified by `scan xcode-membership`
tests required: sync tests, automatic-domain tests, manual sync regression, source-format, duplicate-symbols, root-residue
rollback command: `git mv iOSMerchandiseControl/Sync/Recovery/SupabasePullPreviewModels.swift iOSMerchandiseControl/SupabasePullPreviewModels.swift`
scanner checks: `scan root-residue`, `scan shared-purity`, `scan sync-inventory`
evidence report: `docs/TASKS/EVIDENCE/TASK-121/agent-runs/`

### SupabasePullPreviewService.swift

old_path: `iOSMerchandiseControl/SupabasePullPreviewService.swift`
new_path: `iOSMerchandiseControl/Sync/Recovery/SupabasePullPreviewService.swift`
action: move
owner: Recovery
reason: full remote snapshot pull preview with SwiftData local snapshot support; recovery/full pull boundary rather than root.
symbols/types affected: `SupabaseInventoryFetching`, `SupabasePullPreviewService`, `SupabasePagedFetchResult`, `SupabasePullPreviewPager`, `SupabasePullPreviewDiffEngine`
callers before: `ContentView.swift`, `OptionsView.swift`, `iOSMerchandiseControlApp.swift`, `Sync/Manual/SupabaseManualSyncRemotePreview.swift`, related tests
callers after: unchanged symbol callers; file path is under `Sync/Recovery`
Xcode membership before: synchronized_or_unlisted; no explicit `project.pbxproj` path hit
Xcode membership after: synchronized_or_unlisted; verified by `scan xcode-membership`
tests required: broad sync tests, manual sync regression, pull preview pagination/remote preview tests, source-format, root-residue
rollback command: `git mv iOSMerchandiseControl/Sync/Recovery/SupabasePullPreviewService.swift iOSMerchandiseControl/SupabasePullPreviewService.swift`
scanner checks: `scan root-residue`, `scan sync-architecture`, `scan sync-inventory`
evidence report: `docs/TASKS/EVIDENCE/TASK-121/agent-runs/`

### SupabasePushPreflightViewModel.swift

old_path: `iOSMerchandiseControl/SupabasePushPreflightViewModel.swift`
new_path: `iOSMerchandiseControl/Sync/Manual/SupabasePushPreflightViewModel.swift`
action: move
owner: Manual
reason: `#if DEBUG` manual push preflight UI view model; manual/debug tooling, not remote adapter ownership.
symbols/types affected: `SupabasePushPreflightViewModel`, `SupabasePushPreflightInputError`
callers before: `iOSMerchandiseControlTests/SupabasePushPreflightViewModelTests.swift`
callers after: unchanged symbol callers; file path is under `Sync/Manual`
Xcode membership before: synchronized_or_unlisted; no explicit `project.pbxproj` path hit
Xcode membership after: synchronized_or_unlisted; verified by `scan xcode-membership`
tests required: manual sync regression, push preflight view model tests, source-format, root-residue
rollback command: `git mv iOSMerchandiseControl/Sync/Manual/SupabasePushPreflightViewModel.swift iOSMerchandiseControl/SupabasePushPreflightViewModel.swift`
scanner checks: `scan root-residue`, `scan manual-boundary`, `scan sync-inventory`
evidence report: `docs/TASKS/EVIDENCE/TASK-121/agent-runs/`

### SupabaseSyncEventPreviewService.swift

old_path: `iOSMerchandiseControl/SupabaseSyncEventPreviewService.swift`
new_path: `iOSMerchandiseControl/Sync/Manual/SupabaseSyncEventPreviewService.swift`
action: move
owner: Manual
reason: `#if DEBUG` sync-event preview/debug service and remote reader; no production automatic owner references found.
symbols/types affected: `SupabaseSyncEventPreviewFetching`, `SyncEventPreviewOptions`, `SyncEventPreviewSummary`, `SupabaseSyncEventPreviewService`, `SupabaseSyncEventRemoteReader`
callers before: `SupabaseSyncEventDebugViewModel.swift`, `SupabaseSyncEventDebugFormatting.swift`, `iOSMerchandiseControlTests/SupabaseSyncEventPreviewServiceTests.swift`, `iOSMerchandiseControlTests/SupabaseSyncEventDebugViewModelTests.swift`
callers after: unchanged symbol callers; path-sensitive test source helper updated
Xcode membership before: synchronized_or_unlisted; no explicit `project.pbxproj` path hit
Xcode membership after: synchronized_or_unlisted; verified by `scan xcode-membership`
tests required: sync event preview/debug tests, source-format, duplicate-symbols, root-residue
rollback command: `git mv iOSMerchandiseControl/Sync/Manual/SupabaseSyncEventPreviewService.swift iOSMerchandiseControl/SupabaseSyncEventPreviewService.swift`
scanner checks: `scan root-residue`, `scan manual-boundary`, `scan sync-inventory`
evidence report: `docs/TASKS/EVIDENCE/TASK-121/agent-runs/`

### SyncEventOutboxDrainService.swift

old_path: `iOSMerchandiseControl/SyncEventOutboxDrainService.swift`
new_path: `iOSMerchandiseControl/Sync/Outbox/SyncEventOutboxDrainService.swift`
action: move
owner: Outbox
reason: shared local outbox drain infrastructure with SwiftData state machine; not a root service and not remote transport.
symbols/types affected: `SyncEventOutboxDrainStatus`, `SyncEventOutboxDrainOutcome`, `SyncEventOutboxDrainError`, `SyncEventOutboxDrainService`
callers before: `Sync/Outbox/SyncEventOutboxDrainer.swift`, `Sync/Manual/SupabaseManualSyncReleaseActivityRegistrationAdapter.swift`, `SyncEventOutboxDrainDebugViewModel.swift`, related tests
callers after: unchanged symbol callers; path-sensitive test source helpers updated
Xcode membership before: synchronized_or_unlisted; no explicit `project.pbxproj` path hit
Xcode membership after: synchronized_or_unlisted; verified by `scan xcode-membership`
tests required: outbox drain tests, manual sync regression, source-format, duplicate-symbols, root-residue
rollback command: `git mv iOSMerchandiseControl/Sync/Outbox/SyncEventOutboxDrainService.swift iOSMerchandiseControl/SyncEventOutboxDrainService.swift`
scanner checks: `scan root-residue`, `scan xcode-membership`, `scan duplicate-symbols`
evidence report: `docs/TASKS/EVIDENCE/TASK-121/agent-runs/`

### SyncEventOutboxEnqueueService.swift

old_path: `iOSMerchandiseControl/SyncEventOutboxEnqueueService.swift`
new_path: `iOSMerchandiseControl/Sync/Outbox/SyncEventOutboxEnqueueService.swift`
action: move
owner: Outbox
reason: shared local outbox enqueue infrastructure used by manual producers and outbox recorder; not a root service and not remote transport.
symbols/types affected: `SyncEventOutboxProducerTerminalStatus`, `SyncEventOutboxProducerResult`, `SyncEventOutboxProducerOutcome`, `SyncEventOutboxEnqueueService`, `SyncEventOutboxProducerMapper`
callers before: `Sync/Outbox/SyncEventOutboxRecorder.swift`, `Sync/Manual/SupabaseManualSyncAggregatedPushOutboxProducer.swift`, `Sync/Manual/SupabaseManualSyncOutboxProducerConversions.swift`, related tests
callers after: unchanged symbol callers; path-sensitive test source helpers updated
Xcode membership before: synchronized_or_unlisted; no explicit `project.pbxproj` path hit
Xcode membership after: synchronized_or_unlisted; verified by `scan xcode-membership`
tests required: outbox enqueue tests, sync event live recorder tests, manual sync regression, source-format, duplicate-symbols, root-residue
rollback command: `git mv iOSMerchandiseControl/Sync/Outbox/SyncEventOutboxEnqueueService.swift iOSMerchandiseControl/SyncEventOutboxEnqueueService.swift`
scanner checks: `scan root-residue`, `scan xcode-membership`, `scan duplicate-symbols`
evidence report: `docs/TASKS/EVIDENCE/TASK-121/agent-runs/`
