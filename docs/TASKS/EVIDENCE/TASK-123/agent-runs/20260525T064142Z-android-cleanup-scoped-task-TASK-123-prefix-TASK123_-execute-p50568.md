# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260525T064142Z-android-cleanup-scoped-task-TASK-123-prefix-TASK123_-execute-p50568
- **Task**: TASK-123
- **Command**: `android cleanup-scoped --task TASK-123 --prefix TASK123_* --execute`
- **Platform**: android
- **Safety**: cleanup-execute
- **Result**: FAIL (exit 1)
- **Duration**: 3634 ms
- **Repo**: <HOME_REDACTED>/AndroidStudioProjects/MerchandiseControlSplitView
- **Branch**: main
- **Git SHA**: 1307d64
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

Android instrumentation FAIL for com.example.merchandisecontrolsplitview.Task103CrossPlatformAcceptanceTest#test114AndroidCleanupLocalHistoryResidue; adb exit=0 (state=device boot_completed=1).

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-123/agent-runs/20260525T064142Z-android-cleanup-scoped-task-TASK-123-prefix-TASK123_-execute-p50568.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-123/agent-runs/20260525T064142Z-android-cleanup-scoped-task-TASK-123-prefix-TASK123_-execute-p50568.json`
- Log: `docs/TASKS/EVIDENCE/TASK-123/agent-runs/20260525T064142Z-android-cleanup-scoped-task-TASK-123-prefix-TASK123_-execute-p50568.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Inspect instrumentation output/logcat and rerun after fixing the reported failure.

## Reconciliation Detail

- android.selectedTargetType: emulator
- android.availableAdbDevices: 1
- android.adbState: device
- android.bootCompleted: 1
- android.appInstalled: True
- android.foregroundPackage: None
- android.screenOn: True
- android.locked: False