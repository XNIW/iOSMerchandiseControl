# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260525T195241Z-live-task123-noop-task-TASK-124-prefix-TASK124_SPEED_SIM_-p13484
- **Task**: TASK-124
- **Command**: `live task123-noop --task TASK-124 --prefix TASK124_SPEED_SIM_`
- **Platform**: ios
- **Safety**: live-write
- **Result**: FAIL (exit 1)
- **Duration**: 97548 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: 6e8ee53b
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

TASK-123 no-op matrix FAIL: inspect counts/events per iteration.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-124/agent-runs/20260525T195241Z-live-task123-noop-task-TASK-124-prefix-TASK124_SPEED_SIM_-p13484.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-124/agent-runs/20260525T195241Z-live-task123-noop-task-TASK-124-prefix-TASK124_SPEED_SIM_-p13484.json`
- Log: `docs/TASKS/EVIDENCE/TASK-124/agent-runs/20260525T195241Z-live-task123-noop-task-TASK-124-prefix-TASK124_SPEED_SIM_-p13484.log`
- xcresult: `/tmp/mc-agent-ios-auth-preflight-20260525T195241Z.xcresult`
- screenshot: `n/a`

## Next Action

Fix no-op trigger/pending behavior and rerun task123-noop.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-124
- source: live.task123-noop-matrix
- status: FAIL
- products: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- suppliers: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- categories: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- product_prices: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- history_entries: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None