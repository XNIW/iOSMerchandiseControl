# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260522T152320Z-live-offline-reconnect-sync-task-TASK-114-prefix-TASK114_OFFLINE_-p43214
- **Task**: TASK-114
- **Command**: `live offline-reconnect-sync --task TASK-114 --prefix TASK114_OFFLINE_`
- **Platform**: android
- **Safety**: live-write
- **Result**: fail (exit 1)
- **Duration**: 174668 ms
- **Repo**: <HOME_REDACTED>/AndroidStudioProjects/MerchandiseControlSplitView
- **Branch**: main
- **Git SHA**: 8f6c04f
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

Live offline-reconnect-sync FAIL/BLOCKED: Android offline reconnect leg did not pass.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T152320Z-live-offline-reconnect-sync-task-TASK-114-prefix-TASK114_OFFLINE_-p43214.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T152320Z-live-offline-reconnect-sync-task-TASK-114-prefix-TASK114_OFFLINE_-p43214.json`
- Log: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T152320Z-live-offline-reconnect-sync-task-TASK-114-prefix-TASK114_OFFLINE_-p43214.log`
- xcresult: `/tmp/mc-agent-ios-task114-test114IOSOfflineReconnectProductPriceHistoryMatrix-20260522T152320Z.xcresult`
- screenshot: `n/a`

## Next Action

Inspect Android offline reconnect instrumentation and rerun offline-reconnect-sync.

## Reconciliation Detail

- android.selectedTargetType: physical
- android.availableAdbDevices: 2
- android.adbState: device
- android.bootCompleted: 1
- android.appInstalled: True
- android.foregroundPackage: None
- android.screenOn: True
- android.locked: False