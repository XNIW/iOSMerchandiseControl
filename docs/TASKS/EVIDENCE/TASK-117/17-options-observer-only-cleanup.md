# TASK-117 - Options Observer-Only Cleanup

Date: 2026-05-23 17:48:36 -0400

## Changes
- Removed public Options dependency on the manual sync VM/factory.
- Removed unused DEBUG manual sync release card from `OptionsView.swift`.
- `SupabaseAutomaticSyncStatusCard` now observes auth/baseline/pending state and uses `SyncStatusPresenter` to avoid spinner `0/0`.

## Evidence
- `20260523T212313Z-scan-options-observer-only-task-TASK-117-p54523` PASS
- `20260523T214249Z-scan-release-cta-task-TASK-117-p82078` PASS
- `20260523T212356Z-scan-l10n-sync-keys-task-TASK-117-p58046` PASS
- `20260523T212856Z-ios-smoke-options-task-TASK-117-p61742` BLOCKED: macOS Accessibility/osascript prerequisite.

