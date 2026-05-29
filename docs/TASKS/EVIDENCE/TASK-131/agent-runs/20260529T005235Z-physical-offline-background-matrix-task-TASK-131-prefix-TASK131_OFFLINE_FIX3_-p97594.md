# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260529T005235Z-physical-offline-background-matrix-task-TASK-131-prefix-TASK131_OFFLINE_FIX3_-p97594
- **Task**: TASK-131
- **Command**: `physical offline-background-matrix --task TASK-131 --prefix TASK131_OFFLINE_FIX3_`
- **Platform**: android
- **Safety**: live-write
- **Result**: BLOCKED_EXTERNAL (exit 2)
- **Duration**: 3745 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: 96b900ef
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

TASK-131 offline-background-matrix blocked/failed at offline reconnect.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-131/agent-runs/20260529T005235Z-physical-offline-background-matrix-task-TASK-131-prefix-TASK131_OFFLINE_FIX3_-p97594.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-131/agent-runs/20260529T005235Z-physical-offline-background-matrix-task-TASK-131-prefix-TASK131_OFFLINE_FIX3_-p97594.json`
- Log: `docs/TASKS/EVIDENCE/TASK-131/agent-runs/20260529T005235Z-physical-offline-background-matrix-task-TASK-131-prefix-TASK131_OFFLINE_FIX3_-p97594.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Inspect offline reconnect report, fix blocker, then rerun.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-131
- source: task131.physical.offline-background-matrix
- status: BLOCKED_EXTERNAL
- products: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- suppliers: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- categories: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- product_prices: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- history_entries: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None