# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260523T044614Z-live-mutation-near-realtime-task-TASK-115-prefix-TASK115_REALTIME_-p60777
- **Task**: TASK-115
- **Command**: `live mutation-near-realtime --task TASK-115 --prefix TASK115_REALTIME_`
- **Platform**: ios
- **Safety**: live-write
- **Result**: pass (exit 0)
- **Duration**: 204034 ms
- **Repo**: <HOME_REDACTED>/AndroidStudioProjects/MerchandiseControlSplitView
- **Branch**: main
- **Git SHA**: b3f65de
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

Live mutation-near-realtime PASS for TASK115_REALTIME_RT_20260523T044614Z_: both directions applied within 30s receiver budget.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-115/agent-runs/20260523T044614Z-live-mutation-near-realtime-task-TASK-115-prefix-TASK115_REALTIME_-p60777.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-115/agent-runs/20260523T044614Z-live-mutation-near-realtime-task-TASK-115-prefix-TASK115_REALTIME_-p60777.json`
- Log: `docs/TASKS/EVIDENCE/TASK-115/agent-runs/20260523T044614Z-live-mutation-near-realtime-task-TASK-115-prefix-TASK115_REALTIME_-p60777.log`
- xcresult: `/tmp/mc-agent-ios-task114-test114IOSWriteProductHistoryMatrix-20260523T044614Z.xcresult`
- screenshot: `n/a`

## Next Action

Run cleanup/residue for TASK115_REALTIME_, then reconcile/runtime-parity/sync-matrix.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-115
- source: live.mutation-near-realtime
- status: PASS
- products: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- suppliers: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- categories: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- product_prices: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- history_entries: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None