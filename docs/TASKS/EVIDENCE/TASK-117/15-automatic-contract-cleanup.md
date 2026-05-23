# TASK-117 - Automatic Contract Cleanup

Date: 2026-05-23 17:48:36 -0400

## Changes
- `SyncAutomaticRuntimeProviders.swift` now exposes clean runtime DTOs:
  - `SyncCatalogPushResult`
  - `SyncProductPricePushResult`
  - `SyncIncrementalPullSummary`
- Removed automatic provider exposure of:
  - `ManualPushPlan`
  - `SupabaseManualPushResult`
  - `ProductPriceManualPushResult`
  - `SupabaseManualSyncActivityRegistration*`
  - `SupabaseManualSyncHistorySessionSummary`
  - `SupabaseSyncEventIncrementalApplySummary`
- Manual adapters perform explicit conversion at the manual boundary.

## Evidence
- `20260523T212313Z-scan-automatic-contracts-clean-task-TASK-117-p54522` PASS
- `20260523T214343Z-scan-no-legacy-runtime-path-task-TASK-117-p88591` PASS
- `20260523T214344Z-ios-build-debug-task-TASK-117-p88637` PASS
- `20260523T214400Z-ios-build-release-task-TASK-117-p90016` PASS

