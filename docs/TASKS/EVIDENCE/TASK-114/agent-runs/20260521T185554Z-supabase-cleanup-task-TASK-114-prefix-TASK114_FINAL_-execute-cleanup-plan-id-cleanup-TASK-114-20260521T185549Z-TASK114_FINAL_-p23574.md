# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260521T185554Z-supabase-cleanup-task-TASK-114-prefix-TASK114_FINAL_-execute-cleanup-plan-id-cleanup-TASK-114-20260521T185549Z-TASK114_FINAL_-p23574
- **Task**: TASK-114
- **Command**: `supabase cleanup --task TASK-114 --prefix TASK114_FINAL_ --execute --cleanup-plan-id cleanup-TASK-114-20260521T185549Z-TASK114_FINAL_`
- **Platform**: supabase
- **Safety**: cleanup-execute
- **Result**: refused (exit 4)
- **Duration**: 153 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: 4b74773
- **Dirty**: dirty
- **Profile**: linked
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

Cleanup SQL refused by safety scanner.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260521T185554Z-supabase-cleanup-task-TASK-114-prefix-TASK114_FINAL_-execute-cleanup-plan-id-cleanup-TASK-114-20260521T185549Z-TASK114_FINAL_-p23574.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260521T185554Z-supabase-cleanup-task-TASK-114-prefix-TASK114_FINAL_-execute-cleanup-plan-id-cleanup-TASK-114-20260521T185549Z-TASK114_FINAL_-p23574.json`
- Log: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260521T185554Z-supabase-cleanup-task-TASK-114-prefix-TASK114_FINAL_-execute-cleanup-plan-id-cleanup-TASK-114-20260521T185549Z-TASK114_FINAL_-p23574.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Review cleanup scope; global/auth destructive SQL is forbidden.