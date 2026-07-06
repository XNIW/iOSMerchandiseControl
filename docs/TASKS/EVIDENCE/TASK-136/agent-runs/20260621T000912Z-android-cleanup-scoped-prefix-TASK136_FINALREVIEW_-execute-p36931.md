# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260621T000912Z-android-cleanup-scoped-prefix-TASK136_FINALREVIEW_-execute-p36931
- **Task**: TASK-136
- **Command**: `android cleanup-scoped --prefix TASK136_FINALREVIEW_ --execute`
- **Platform**: android
- **Safety**: cleanup-execute
- **Result**: UNSAFE_OPERATION_REFUSED (exit 4)
- **Duration**: 167 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: 3b21bb76
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

- Markdown: `docs/TASKS/EVIDENCE/TASK-136/agent-runs/20260621T000912Z-android-cleanup-scoped-prefix-TASK136_FINALREVIEW_-execute-p36931.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-136/agent-runs/20260621T000912Z-android-cleanup-scoped-prefix-TASK136_FINALREVIEW_-execute-p36931.json`
- Log: `docs/TASKS/EVIDENCE/TASK-136/agent-runs/20260621T000912Z-android-cleanup-scoped-prefix-TASK136_FINALREVIEW_-execute-p36931.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Run cleanup dry-run first, then set MC_ALLOW_CLEANUP=1 with a matching cleanup_plan_id.