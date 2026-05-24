# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260523T233226Z-scan-sync-boundaries-task-TASK-118-strict-p83762
- **Task**: TASK-118
- **Command**: `scan sync-boundaries --task TASK-118 --strict`
- **Platform**: general
- **Safety**: safe-readonly
- **Result**: fail (exit 1)
- **Duration**: 459 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: 315c2f1
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

sync-boundaries scan FAIL for TASK-118: source/call-graph checks failed.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-118/agent-runs/20260523T233226Z-scan-sync-boundaries-task-TASK-118-strict-p83762.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-118/agent-runs/20260523T233226Z-scan-sync-boundaries-task-TASK-118-strict-p83762.json`
- Log: `docs/TASKS/EVIDENCE/TASK-118/agent-runs/20260523T233226Z-scan-sync-boundaries-task-TASK-118-strict-p83762.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Fix failing checks and rerun sync-boundaries.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-118
- source: scan.sync-boundaries
- status: FAIL
- products: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- suppliers: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- categories: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- product_prices: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- history_entries: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None