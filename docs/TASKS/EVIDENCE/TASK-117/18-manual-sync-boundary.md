# TASK-117 - Manual Sync Boundary

Date: 2026-05-23 17:48:36 -0400

## Result
Manual sync remains available as a manual-only boundary, but the normal automatic call graph no longer references its VM, factory, compatibility adapter, protocols, DTOs or result types.

## Boundary details
- `SupabaseManualSyncReleaseFactory.swift` still builds manual VM dependencies.
- `ManualSyncIncrementalPullAdapter` converts clean `SyncIncrementalPullSummary` back to the legacy manual summary only for manual VM consumers.
- `SupabaseSyncEventIncrementalApplyService.swift` remains a compatibility wrapper over `SyncEventIncrementalDomainApplyService`, not an automatic runtime dependency.
- `SupabaseManualSyncCompatibilityAdapter.swift` was deleted after call sites were removed.

## Evidence
- `20260523T212324Z-scan-duplicate-sync-owner-task-TASK-117-p55793` PASS
- `20260523T212324Z-scan-incremental-apply-contract-task-TASK-117-p55792` PASS
- `20260523T214343Z-scan-no-legacy-runtime-path-task-TASK-117-p88591` PASS

