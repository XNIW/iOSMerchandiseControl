# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260528T233939Z-physical-sync-policy-matrix-task-TASK-131-prefix-TASK131_POLICY_FIX5_-p10227
- **Task**: TASK-131
- **Command**: `physical sync-policy-matrix --task TASK-131 --prefix TASK131_POLICY_FIX5_`
- **Platform**: ios
- **Safety**: live-write
- **Result**: FAIL (exit 1)
- **Duration**: 123560 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: 96b900ef
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

TASK-131 sync-policy-matrix blocked/failed before no-op/burst because near-realtime bidirectional sync did not pass.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-131/agent-runs/20260528T233939Z-physical-sync-policy-matrix-task-TASK-131-prefix-TASK131_POLICY_FIX5_-p10227.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-131/agent-runs/20260528T233939Z-physical-sync-policy-matrix-task-TASK-131-prefix-TASK131_POLICY_FIX5_-p10227.json`
- Log: `docs/TASKS/EVIDENCE/TASK-131/agent-runs/20260528T233939Z-physical-sync-policy-matrix-task-TASK-131-prefix-TASK131_POLICY_FIX5_-p10227.log`
- xcresult: `/tmp/mc-agent-ios-task114-test114IOSWriteProductHistoryMatrix-20260528T233939Z.xcresult`
- screenshot: `n/a`

## Next Action

Inspect near-realtime report, fix the first blocker, then rerun sync-policy-matrix.

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