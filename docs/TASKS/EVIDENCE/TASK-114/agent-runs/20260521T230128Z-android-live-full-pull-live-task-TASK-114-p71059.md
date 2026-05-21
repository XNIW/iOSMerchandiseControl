# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260521T230128Z-android-live-full-pull-live-task-TASK-114-p71059
- **Task**: TASK-114
- **Command**: `android live-full-pull --live --task TASK-114`
- **Platform**: android
- **Safety**: live-write
- **Result**: fail (exit 1)
- **Duration**: 87355 ms
- **Repo**: <HOME_REDACTED>/AndroidStudioProjects/MerchandiseControlSplitView
- **Branch**: main
- **Git SHA**: eee1f58
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

- Markdown: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260521T230128Z-android-live-full-pull-live-task-TASK-114-p71059.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260521T230128Z-android-live-full-pull-live-task-TASK-114-p71059.json`
- Log: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260521T230128Z-android-live-full-pull-live-task-TASK-114-p71059.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Inspect instrumentation output/logcat and rerun after fixing the reported failure.