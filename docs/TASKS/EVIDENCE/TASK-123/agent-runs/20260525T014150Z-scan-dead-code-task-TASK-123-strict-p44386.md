# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260525T014150Z-scan-dead-code-task-TASK-123-strict-p44386
- **Task**: TASK-123
- **Command**: `scan dead-code --task TASK-123 --strict`
- **Platform**: general
- **Safety**: safe-readonly
- **Result**: MISCONFIGURED (exit 3)
- **Duration**: 244 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: 8116de9d
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

dead-code scan MISCONFIGURED for TASK-123.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-123/agent-runs/20260525T014150Z-scan-dead-code-task-TASK-123-strict-p44386.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-123/agent-runs/20260525T014150Z-scan-dead-code-task-TASK-123-strict-p44386.json`
- Log: `docs/TASKS/EVIDENCE/TASK-123/agent-runs/20260525T014150Z-scan-dead-code-task-TASK-123-strict-p44386.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Fix TASK-119 scanner command/configuration.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-123
- source: scan.task119
- status: MISCONFIGURED
- products: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- suppliers: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- categories: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- product_prices: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- history_entries: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None