# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260522T041151Z-supabase-cleanup-task-TASK-114-prefix-TASK114_REALTIME_-dry-run-p15569
- **Task**: TASK-114
- **Command**: `supabase cleanup --task TASK-114 --prefix TASK114_REALTIME_ --dry-run`
- **Platform**: supabase
- **Safety**: cleanup-dry-run
- **Result**: blocked (exit 2)
- **Duration**: 163 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: c1ee078
- **Dirty**: dirty
- **Profile**: dry-run-no-db
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

Live/cleanup lock is already held for TASK-114.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T041151Z-supabase-cleanup-task-TASK-114-prefix-TASK114_REALTIME_-dry-run-p15569.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T041151Z-supabase-cleanup-task-TASK-114-prefix-TASK114_REALTIME_-dry-run-p15569.json`
- Log: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T041151Z-supabase-cleanup-task-TASK-114-prefix-TASK114_REALTIME_-dry-run-p15569.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Wait for pid=15568 (2026-05-22T04:11:51Z) or inspect docs/TASKS/EVIDENCE/TASK-114/agent-runs/.mc-agent-live.lock.