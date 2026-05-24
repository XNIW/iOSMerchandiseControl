# TASK-121 mega-service elimination ledger

Generated during the final anti-false-positive review/fix pass on 2026-05-24.

## SupabaseInventoryService -> SupabaseTransportClient

old_path: `iOSMerchandiseControl/SupabaseInventoryService.swift`
new_path: `iOSMerchandiseControl/Sync/Remote/SupabaseTransportClient.swift`
action: move + rename + adapter split
owner: Remote
reason: root mega-service was still present after the prior `10 -> 0` root-residue claim. The concrete Supabase transport belongs in `Sync/Remote`; automatic/manual/recovery callers should receive protocol-backed adapters instead of using a root service path.
symbols/types affected: `SupabaseInventoryService` -> `SupabaseTransportClient`, `SupabaseInventoryServiceError` -> `SupabaseTransportClientError`, `SupabaseInventoryDiagnosticResult` -> `SupabaseTransportDiagnosticResult`, DEBUG `SupabaseTask087*` / `SupabaseTask088*` support, remote fetch/write methods.
callers before: `ContentView`, `AutomaticSyncRuntimeFactory`, `SupabaseManualSyncReleaseFactory`, product-price/manual/recovery services, live/cross-platform tests.
callers after: automatic/history/incremental paths use `CatalogRemoteSupabaseAdapter`, `ProductPriceRemoteSupabaseAdapter`, `HistorySessionRemoteSupabaseAdapter`, `SyncEventRemoteSupabaseAdapter`; manual product-price protocols remain manual-only; production code no longer references legacy `SupabaseInventoryService`.
Xcode membership before: synchronized_or_unlisted
Xcode membership after: synchronized_or_unlisted; `scan xcode-membership` PASS.
tests required: source-format, root-residue, sync-inventory, sync-architecture, manual-boundary, duplicate-symbols, debug/release build, automatic architecture/domain tests, sync tests, manual sync regression.
rollback command: `git mv iOSMerchandiseControl/Sync/Remote/SupabaseTransportClient.swift iOSMerchandiseControl/SupabaseInventoryService.swift`
scanner checks: `scan root-residue`, `scan sync-inventory`, `scan manual-boundary`, `scan duplicate-symbols`, `scan xcode-membership`
evidence report: `docs/TASKS/EVIDENCE/TASK-121/agent-runs/`

## Additional root rehomes

The anti-false-positive pass also moved root sync-related files that were not in the original ten-file residue list:

- `AutomaticSyncReconnectScheduler.swift` -> `Sync/Automatic/Presentation/`
- `CloudSyncOverviewState.swift` -> `Sync/Manual/`
- `LocalPendingAggregatedPushPlanner.swift` -> `Sync/Manual/`
- `SwiftDataInventorySnapshotService.swift` -> `Sync/Recovery/`
- `SupabaseCatalogBaseline*` and `SupabaseCatalogFingerprintNormalizer.swift` -> `Sync/Manual/`
- `SupabaseInventoryDTOs.swift`, `SupabaseSyncEventDTOs.swift`, `SupabaseSyncEventLiveRecorder.swift`, `SupabaseSyncEventRPCTransport.swift`, `SupabaseSyncEventRealtimeWatcher.swift`, `SyncEventRPCRequestMapper.swift`, `SyncEventRecording.swift` -> `Sync/Remote/`
- `SupabaseProductPriceApplyService.swift`, `SyncCountReconciliation.swift` -> `Sync/Recovery/`
- `SupabaseSyncEventDebug*`, `SupabaseSyncPlanContract.swift`, `SyncEventOutboxDrainDebugViewModel.swift` -> `Sync/Manual/`
- `SyncEventOutboxEntry.swift`, `SyncEventOutboxState.swift` -> `Sync/Outbox/`

Root allowlist remaining:
- `SupabaseAuthService.swift`
- `SupabaseAuthViewModel.swift`
- `SupabaseClientProvider.swift`
- `SupabaseConfig.swift`
