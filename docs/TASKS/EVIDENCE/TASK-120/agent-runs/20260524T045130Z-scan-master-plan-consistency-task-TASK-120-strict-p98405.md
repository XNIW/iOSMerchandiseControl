# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260524T045130Z-scan-master-plan-consistency-task-TASK-120-strict-p98405
- **Task**: TASK-120
- **Command**: `scan master-plan-consistency --task TASK-120 --strict`
- **Platform**: general
- **Safety**: safe-readonly
- **Result**: FAIL (exit 1)
- **Duration**: 262 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: b6953a5
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

master-plan-consistency scan FAIL for TASK-120: TASK-120 gate found required work.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-120/agent-runs/20260524T045130Z-scan-master-plan-consistency-task-TASK-120-strict-p98405.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-120/agent-runs/20260524T045130Z-scan-master-plan-consistency-task-TASK-120-strict-p98405.json`
- Log: `docs/TASKS/EVIDENCE/TASK-120/agent-runs/20260524T045130Z-scan-master-plan-consistency-task-TASK-120-strict-p98405.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Fix failing checks and rerun master-plan-consistency.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-120
- source: scan.master-plan-consistency
- status: FAIL
- products: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- suppliers: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- categories: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- product_prices: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- history_entries: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None