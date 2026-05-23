# TASK-117 - ContentView Root Host Cleanup

Date: 2026-05-23 17:48:36 -0400

## Changes
- Replaced `SupabaseManualSyncForegroundRootHost` with `AppSyncRootHost`.
- `ContentView.swift` no longer instantiates/passes:
  - `SupabaseManualSyncViewModel`
  - `SupabaseManualSyncCompatibilityAdapter`
  - `SupabaseManualSyncReleaseFactory`
  - `SupabaseManualSyncForegroundRootHost`
- Root banner now consumes `SyncRootPresentationState`.

## Evidence
- `20260523T212313Z-scan-root-host-clean-task-TASK-117-p54521` PASS
- `20260523T214343Z-scan-no-legacy-runtime-path-task-TASK-117-p88591` PASS
- `20260523T214344Z-ios-build-debug-task-TASK-117-p88637` PASS

