# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260522T081221Z-ios-cleanup-scoped-task-TASK-114-prefix-TASK114_REALTIME_-execute-p17962
- **Task**: TASK-114
- **Command**: `ios cleanup-scoped --task TASK-114 --prefix TASK114_REALTIME_ --execute`
- **Platform**: ios
- **Safety**: cleanup-dry-run
- **Result**: refused (exit 4)
- **Duration**: 124 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: c1ee078
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

iOS cleanup-scoped refused: only --dry-run is supported; remote cleanup is Supabase-scoped.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T081221Z-ios-cleanup-scoped-task-TASK-114-prefix-TASK114_REALTIME_-execute-p17962.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T081221Z-ios-cleanup-scoped-task-TASK-114-prefix-TASK114_REALTIME_-execute-p17962.json`
- Log: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T081221Z-ios-cleanup-scoped-task-TASK-114-prefix-TASK114_REALTIME_-execute-p17962.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Run supabase cleanup --dry-run for remote rows.