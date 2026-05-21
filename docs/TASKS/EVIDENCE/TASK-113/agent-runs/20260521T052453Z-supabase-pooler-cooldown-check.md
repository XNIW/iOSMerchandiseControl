# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260521T052453Z-supabase-pooler-cooldown-check
- **Task**: TASK-113
- **Command**: `supabase pooler-cooldown-check`
- **Platform**: supabase
- **Safety**: safe-readonly
- **Result**: pass_with_notes (exit 0)
- **Duration**: 124 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: 10f5bdd
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

Pooler cooldown check PASS_WITH_NOTES: harness documents backoff; no remote query needed.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-113/agent-runs/20260521T052453Z-supabase-pooler-cooldown-check.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-113/agent-runs/20260521T052453Z-supabase-pooler-cooldown-check.json`
- Log: `docs/TASKS/EVIDENCE/TASK-113/agent-runs/20260521T052453Z-supabase-pooler-cooldown-check.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Use fewer repeated linked queries if pooler returns rate-limit/circuit-breaker.