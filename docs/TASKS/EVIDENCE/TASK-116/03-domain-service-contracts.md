# Domain Service Contracts Evidence

## Implemented
- `SyncAutomaticRuntime` owns automatic execution for push/drain/light reconcile decisions.
- `SyncEventIncrementalPullService` owns the incremental pull provider boundary and no longer passes through the legacy `SupabaseSyncEventIncrementalApplyService`.
- `SyncEventIncrementalDomainApplyService` now lives in `iOSMerchandiseControl/Sync/Incremental/SyncEventIncrementalDomainApplyService.swift` and owns event fetch/dispatch/watermark behavior previously hidden behind the legacy service name.
- `CatalogIncrementalApplyService` now lives in `iOSMerchandiseControl/Sync/Incremental/CatalogIncrementalApplyService.swift` and owns targeted Product/Supplier/Category apply plus missing remote tombstone handling.
- `ProductPriceIncrementalApplyService` now lives in `iOSMerchandiseControl/Sync/Incremental/ProductPriceIncrementalApplyService.swift` and owns targeted price fetch/apply, append/link/idempotent behavior and missing remote prune.
- `HistoryIncrementalApplyService` now lives in `iOSMerchandiseControl/Sync/Incremental/HistoryIncrementalApplyService.swift` and owns targeted history/session fetch/apply plus missing remote tombstone handling.
- `SyncEventIncrementalApplyHelpers` now lives in `iOSMerchandiseControl/Sync/Incremental/SyncEventIncrementalApplyHelpers.swift`; the legacy-named file no longer hides Product/Supplier/Category/Price/History helper implementation.
- `SupabaseSyncEventIncrementalApplyService` remains as compatibility wrapper for manual/test legacy callers.

## Domain behavior retained
- Catalog targeted apply still handles product/supplier/category create/update/tombstone, dirty pending protection and missing remote tombstone handling.
- ProductPrice targeted apply remains append/link/idempotent with same effective-at conflict protection and orphan skip behavior.
- History targeted apply still delegates to `HistorySessionSyncService` with remoteId/fingerprint/tombstone handling.
- `WatermarkStore` is still account/store-bound and saves only after the domain apply sequence completes.

## History service decision
Decision A was selected: `HistorySessionSyncService` is retained as an official domain helper for history/session payload mapping, fingerprint/dedupe, remoteId handling and tombstone mechanics. `HistoryIncrementalApplyService` remains the incremental apply facade under `Sync/Incremental` and is the service referenced by the automatic domain dispatcher. `HistorySessionSyncService` is therefore not a competing automatic owner; a future cleanup may move/rename it under `Sync/History` after manual callers are drained.

## Automatic provider cleanup
The automatic runtime boundary now uses `Sync*Providing` protocols and `Sync*` DTO/result wrappers for activity registration/history summary. Compatibility with old manual VM protocols is implemented by the concrete adapters, not by `SyncAutomaticRuntime` itself. The final cleanup removes `SupabaseManualSync*Providing` and `SupabaseManualSyncRelease*Adapter` naming from the automatic runtime dependency surface.

## Tests/gates
- Severe-fix no-legacy-runtime-path PASS with physical service checks: `agent-runs/20260523T183127Z-scan-no-legacy-runtime-path-task-TASK-116-p89574.md`
- Severe-fix iOS sync tests PASS after physical split: `agent-runs/20260523T183345Z-ios-test-sync-task-TASK-116-p91525.md`
- Severe-fix Debug/Release build PASS: `agent-runs/20260523T183154Z-ios-build-debug-task-TASK-116-p90096.md`, `agent-runs/20260523T183216Z-ios-build-release-task-TASK-116-p90756.md`
- Final cleanup Debug/Release build PASS: `agent-runs/20260523T191436Z-ios-build-debug-task-TASK-116-p32264.md`, `agent-runs/20260523T191450Z-ios-build-release-task-TASK-116-p32902.md`
- Final cleanup iOS sync tests PASS: `agent-runs/20260523T191617Z-ios-test-sync-task-TASK-116-p33680.md`
- Review rerun iOS sync tests PASS with canonical suite widened to existing ProductPrice apply and HistorySession tests: `agent-runs/20260523T194020Z-ios-test-sync-task-TASK-116-p53802.md`

## Reviewer note
The severe review found the previous file split insufficient. This FIX addressed that gap by adding physical Catalog/ProductPrice/History services and by hardening the architecture gate so a future DTO-only split cannot pass as domain-service completion. TASK-116 still must not be marked DONE until live/device/account blockers pass or are explicitly accepted by the user as external.

Review rerun note: `ProductPriceIncrementalApplyService` still reports `missingRemotePruned`; this is treated as targeted remote-missing cleanup for requested ids, not a normal foreground full pull or main-thread full ProductPrice scan. It remains a review note, not DONE evidence for live/account/device criteria.
