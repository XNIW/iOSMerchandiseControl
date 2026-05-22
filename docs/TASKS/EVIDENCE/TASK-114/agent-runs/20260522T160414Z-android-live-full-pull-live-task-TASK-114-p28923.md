# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260522T160414Z-android-live-full-pull-live-task-TASK-114-p28923
- **Task**: TASK-114
- **Command**: `android live-full-pull --live --task TASK-114`
- **Platform**: android
- **Safety**: live-write
- **Result**: fail (exit 1)
- **Duration**: 35448 ms
- **Repo**: <HOME_REDACTED>/AndroidStudioProjects/MerchandiseControlSplitView
- **Branch**: main
- **Git SHA**: 8f6c04f
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

Android instrumentation FAIL for com.example.merchandisecontrolsplitview.Task114AndroidFullReconciliationTest#fullPullFromSupabaseWithoutClearingLocalData; adb exit=0 (state=device boot_completed=1).

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T160414Z-android-live-full-pull-live-task-TASK-114-p28923.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T160414Z-android-live-full-pull-live-task-TASK-114-p28923.json`
- Log: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T160414Z-android-live-full-pull-live-task-TASK-114-p28923.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Inspect instrumentation output/logcat and rerun after fixing the reported failure.

## Reconciliation Detail

- android.selectedTargetType: physical
- android.availableAdbDevices: 2
- android.adbState: device
- android.bootCompleted: 1
- android.appInstalled: True
- android.foregroundPackage: None
- android.screenOn: True
- android.locked: False