# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260521T060549Z-supabase-cleanup-task-TASK-113-prefix-BAD_-dry-run-p34212
- **Task**: TASK-113
- **Command**: `supabase cleanup --task TASK-113 --prefix BAD_ --dry-run`
- **Platform**: supabase
- **Safety**: safe-readonly
- **Result**: refused (exit 4)
- **Duration**: 122 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: 10f5bdd
- **Dirty**: dirty
- **Profile**: dry-run-no-db
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

Prefix must match TASKNNN_* scoped pattern.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-113/agent-runs/20260521T060549Z-supabase-cleanup-task-TASK-113-prefix-BAD_-dry-run-p34212.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-113/agent-runs/20260521T060549Z-supabase-cleanup-task-TASK-113-prefix-BAD_-dry-run-p34212.json`
- Log: `docs/TASKS/EVIDENCE/TASK-113/agent-runs/20260521T060549Z-supabase-cleanup-task-TASK-113-prefix-BAD_-dry-run-p34212.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Example: --prefix TASK113_DRYRUN_ or --prefix 'TASK113_*'.