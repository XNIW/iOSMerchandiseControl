# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260522T050854Z-android-cleanup-scoped-task-TASK-114-prefix-TASK114_REALTIME_-execute-p12559
- **Task**: TASK-114
- **Command**: `android cleanup-scoped --task TASK-114 --prefix TASK114_REALTIME_ --execute`
- **Platform**: android
- **Safety**: cleanup-execute
- **Result**: refused (exit 4)
- **Duration**: 135 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: c1ee078
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

Cleanup execute refused. MC_ALLOW_CLEANUP=1 is required.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T050854Z-android-cleanup-scoped-task-TASK-114-prefix-TASK114_REALTIME_-execute-p12559.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T050854Z-android-cleanup-scoped-task-TASK-114-prefix-TASK114_REALTIME_-execute-p12559.json`
- Log: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T050854Z-android-cleanup-scoped-task-TASK-114-prefix-TASK114_REALTIME_-execute-p12559.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Run cleanup dry-run first, then set MC_ALLOW_CLEANUP=1 with a matching cleanup_plan_id.