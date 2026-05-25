# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260525T201237Z-live-runtime-parity-task-TASK-124-prefix-TASK124_RT_SIM_-profile-linked-p55109
- **Task**: TASK-124
- **Command**: `live runtime-parity --task TASK-124 --prefix TASK124_RT_SIM_ --profile linked`
- **Platform**: ios
- **Safety**: live-write
- **Result**: FAIL (exit 1)
- **Duration**: 60276 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: 6e8ee53b
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

Live runtime-parity FAIL for TASK124_RT_SIM_: drift remains in runtime app counts.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-124/agent-runs/20260525T201237Z-live-runtime-parity-task-TASK-124-prefix-TASK124_RT_SIM_-profile-linked-p55109.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-124/agent-runs/20260525T201237Z-live-runtime-parity-task-TASK-124-prefix-TASK124_RT_SIM_-profile-linked-p55109.json`
- Log: `docs/TASKS/EVIDENCE/TASK-124/agent-runs/20260525T201237Z-live-runtime-parity-task-TASK-124-prefix-TASK124_RT_SIM_-profile-linked-p55109.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Inspect runtime parity drift, repair auto-sync/apply/UI store selection, then rerun.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-124
- source: live.runtime-parity
- status: FAIL
- products: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- suppliers: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- categories: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- product_prices: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- history_entries: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None