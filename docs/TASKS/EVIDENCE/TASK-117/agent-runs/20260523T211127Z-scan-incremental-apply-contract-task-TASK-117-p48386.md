# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260523T211127Z-scan-incremental-apply-contract-task-TASK-117-p48386
- **Task**: TASK-117
- **Command**: `scan incremental-apply-contract --task TASK-117`
- **Platform**: general
- **Safety**: safe-readonly
- **Result**: fail (exit 1)
- **Duration**: 265 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: e14b433
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

incremental-apply-contract scan FAIL for TASK-117: source/call-graph checks failed.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-117/agent-runs/20260523T211127Z-scan-incremental-apply-contract-task-TASK-117-p48386.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-117/agent-runs/20260523T211127Z-scan-incremental-apply-contract-task-TASK-117-p48386.json`
- Log: `docs/TASKS/EVIDENCE/TASK-117/agent-runs/20260523T211127Z-scan-incremental-apply-contract-task-TASK-117-p48386.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Fix failing checks and rerun incremental-apply-contract.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-117
- source: scan.incremental-apply-contract
- status: FAIL
- products: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- suppliers: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- categories: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- product_prices: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- history_entries: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None