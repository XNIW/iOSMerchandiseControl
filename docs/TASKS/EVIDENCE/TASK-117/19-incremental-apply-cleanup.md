# TASK-117 - Incremental Apply Cleanup

Date: 2026-05-23 17:48:36 -0400

## Changes
- `SyncEventIncrementalPullService` conforms only to `SyncIncrementalPullProviding`.
- `SyncEventIncrementalDomainApplyService` returns `SyncIncrementalPullSummary`.
- Catalog, ProductPrice and History incremental summary helpers consume clean summaries.
- Legacy `SupabaseSyncEventIncrementalApplyService` wraps the clean domain service only for compatibility.

## Evidence
- `20260523T212324Z-scan-incremental-apply-contract-task-TASK-117-p55792` PASS
- `20260523T212325Z-scan-swiftdata-mainactor-heavy-task-TASK-117-p55926` PASS
- `20260523T214520Z-ios-test-sync-task-TASK-117-p90749` PASS

