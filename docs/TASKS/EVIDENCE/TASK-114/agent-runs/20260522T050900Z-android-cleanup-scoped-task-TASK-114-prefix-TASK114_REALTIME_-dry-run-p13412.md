# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260522T050900Z-android-cleanup-scoped-task-TASK-114-prefix-TASK114_REALTIME_-dry-run-p13412
- **Task**: TASK-114
- **Command**: `android cleanup-scoped --task TASK-114 --prefix TASK114_REALTIME_ --dry-run`
- **Platform**: android
- **Safety**: cleanup-dry-run
- **Result**: blocked (exit 2)
- **Duration**: 1901 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: c1ee078
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

BLOCKED_DEVICE_LOCKED: Android target appears screen-off/asleep.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T050900Z-android-cleanup-scoped-task-TASK-114-prefix-TASK114_REALTIME_-dry-run-p13412.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T050900Z-android-cleanup-scoped-task-TASK-114-prefix-TASK114_REALTIME_-dry-run-p13412.json`
- Log: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T050900Z-android-cleanup-scoped-task-TASK-114-prefix-TASK114_REALTIME_-dry-run-p13412.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Wake and unlock the selected Android target, then retry; or rerun with an explicit emulator serial.

## Reconciliation Detail

- android.selectedTargetType: physical
- android.availableAdbDevices: 2
- android.adbState: device
- android.bootCompleted: 1
- android.appInstalled: True
- android.foregroundPackage: None
- android.screenOn: False
- android.locked: True