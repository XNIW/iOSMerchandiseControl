# TASK-117 - Dead Code Removal Or Retention

Date: 2026-05-23 17:48:36 -0400

## Removed
- `iOSMerchandiseControl/Sync/SupabaseManualSyncCompatibilityAdapter.swift`
- Unused DEBUG `SupabaseManualSyncReleaseCard` block from `OptionsView.swift`

## Retained with classification
- Manual VM/coordinator/factory files: retained manual-only boundary.
- Full pull/apply helpers: retained manual/bootstrap/recovery/harness boundary.
- Domain incremental services: retained as automatic runtime domain services.

## Evidence
- `rg` call-site audit found no remaining compatibility adapter call site before deletion.
- `20260523T214343Z-scan-no-legacy-runtime-path-task-TASK-117-p88591` PASS
- `20260523T214344Z-ios-build-debug-task-TASK-117-p88637` PASS
- `20260523T214400Z-ios-build-release-task-TASK-117-p90016` PASS

