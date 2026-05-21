# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260521T052617Z-scan-sensitive-tmp-mc-agent-fake-secretslog
- **Task**: TASK-113
- **Command**: `scan sensitive /tmp/mc-agent-fake-secrets.log`
- **Platform**: general
- **Safety**: safe-readonly
- **Result**: fail (exit 1)
- **Duration**: 195 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: 10f5bdd
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

Sensitive scan FAIL: 1 file(s) with unredacted hits.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-113/agent-runs/20260521T052617Z-scan-sensitive-tmp-mc-agent-fake-secretslog.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-113/agent-runs/20260521T052617Z-scan-sensitive-tmp-mc-agent-fake-secretslog.json`
- Log: `docs/TASKS/EVIDENCE/TASK-113/agent-runs/20260521T052617Z-scan-sensitive-tmp-mc-agent-fake-secretslog.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Redact or remove unsafe evidence and rerun.