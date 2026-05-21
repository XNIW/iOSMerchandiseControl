# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260521T052435Z-supabase-cleanup-task-TASK-113-prefix-TASK113_DRYRUN_-execute
- **Task**: TASK-113
- **Command**: `supabase cleanup --task TASK-113 --prefix TASK113_DRYRUN_ --execute`
- **Platform**: supabase
- **Safety**: cleanup-execute
- **Result**: refused (exit 4)
- **Duration**: 129 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: 10f5bdd
- **Dirty**: dirty
- **Profile**: linked
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

Cleanup execute refused. MC_ALLOW_CLEANUP=1 is required.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-113/agent-runs/20260521T052435Z-supabase-cleanup-task-TASK-113-prefix-TASK113_DRYRUN_-execute.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-113/agent-runs/20260521T052435Z-supabase-cleanup-task-TASK-113-prefix-TASK113_DRYRUN_-execute.json`
- Log: `docs/TASKS/EVIDENCE/TASK-113/agent-runs/20260521T052435Z-supabase-cleanup-task-TASK-113-prefix-TASK113_DRYRUN_-execute.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Run cleanup dry-run first, then set MC_ALLOW_CLEANUP=1 with a matching cleanup_plan_id.