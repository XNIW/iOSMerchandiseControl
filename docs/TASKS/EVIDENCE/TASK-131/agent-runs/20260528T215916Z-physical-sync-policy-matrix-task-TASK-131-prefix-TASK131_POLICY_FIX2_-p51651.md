# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260528T215916Z-physical-sync-policy-matrix-task-TASK-131-prefix-TASK131_POLICY_FIX2_-p51651
- **Task**: TASK-131
- **Command**: `physical sync-policy-matrix --task TASK-131 --prefix TASK131_POLICY_FIX2_`
- **Platform**: android
- **Safety**: safe-readonly
- **Result**: FAIL (exit 1)
- **Duration**: 1013031 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: 96b900ef
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

TASK-131 sync-policy-matrix FAIL: inspect matrix steps for the first failing/blocking physical gate.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-131/agent-runs/20260528T215916Z-physical-sync-policy-matrix-task-TASK-131-prefix-TASK131_POLICY_FIX2_-p51651.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-131/agent-runs/20260528T215916Z-physical-sync-policy-matrix-task-TASK-131-prefix-TASK131_POLICY_FIX2_-p51651.json`
- Log: `docs/TASKS/EVIDENCE/TASK-131/agent-runs/20260528T215916Z-physical-sync-policy-matrix-task-TASK-131-prefix-TASK131_POLICY_FIX2_-p51651.log`
- xcresult: `/tmp/mc-agent-ios-task114-test123IOSSingleCatalogCreatePropagation-20260528T215916Z.xcresult`
- screenshot: `n/a`

## Next Action

Fix app/harness root cause, rerun sync-policy-matrix, then cleanup scoped TASK131_*.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-131
- source: task131.physical.sync-policy-matrix
- status: FAIL
- products: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- suppliers: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- categories: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- product_prices: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- history_entries: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None