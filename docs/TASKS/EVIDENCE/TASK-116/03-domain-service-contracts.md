# Domain Service Contracts Evidence

## Implemented
- `SyncAutomaticRuntime` owns automatic execution for push/drain/light reconcile decisions.
- `SyncEventIncrementalPullService` owns the incremental pull provider boundary and no longer passes through the legacy `SupabaseSyncEventIncrementalApplyService`.
- `SyncEventIncrementalDomainApplyService` owns event fetch/apply/watermark behavior previously hidden behind the legacy service name.
- `SupabaseSyncEventIncrementalApplyService` remains as compatibility wrapper for manual/test legacy callers.

## Domain behavior retained
- Catalog targeted apply still handles product/supplier/category create/update/tombstone, dirty pending protection and missing remote tombstone handling.
- ProductPrice targeted apply remains append/link/idempotent with same effective-at conflict protection and orphan skip behavior.
- History targeted apply still delegates to `HistorySessionSyncService` with remoteId/fingerprint/tombstone handling.
- `WatermarkStore` is still account/store-bound and saves only after the domain apply sequence completes.

## Tests/gates
- iOS sync tests PASS after refactor: `agent-runs/20260523T162955Z-ios-test-sync-task-TASK-116-p21120.md`
- Debug build PASS: `agent-runs/20260523T162939Z-ios-build-debug-task-TASK-116-p20511.md`
- Release build PASS: `agent-runs/20260523T163013Z-ios-build-release-task-TASK-116-p21745.md`

## Reviewer note
The large apply implementation is now under the new operational type `SyncEventIncrementalDomainApplyService`, but full file-level decomposition into separate Catalog/ProductPrice/History files is intentionally left as review-visible residual cleanup before DONE. The automatic runtime is legacy-free by gate; TASK-116 must not be marked DONE until reviewer accepts or requests deeper physical file split.
