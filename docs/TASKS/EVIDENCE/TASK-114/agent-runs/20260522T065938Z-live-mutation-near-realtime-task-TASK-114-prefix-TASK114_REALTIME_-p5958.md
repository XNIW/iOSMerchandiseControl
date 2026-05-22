# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260522T065938Z-live-mutation-near-realtime-task-TASK-114-prefix-TASK114_REALTIME_-p5958
- **Task**: TASK-114
- **Command**: `live mutation-near-realtime --task TASK-114 --prefix TASK114_REALTIME_`
- **Platform**: ios
- **Safety**: live-write
- **Result**: pass (exit 0)
- **Duration**: 213791 ms
- **Repo**: <HOME_REDACTED>/AndroidStudioProjects/MerchandiseControlSplitView
- **Branch**: main
- **Git SHA**: 8f6c04f
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

Live mutation-near-realtime PASS for TASK114_REALTIME_RT_20260522T065938Z_: both directions applied within 30s receiver budget.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T065938Z-live-mutation-near-realtime-task-TASK-114-prefix-TASK114_REALTIME_-p5958.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T065938Z-live-mutation-near-realtime-task-TASK-114-prefix-TASK114_REALTIME_-p5958.json`
- Log: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T065938Z-live-mutation-near-realtime-task-TASK-114-prefix-TASK114_REALTIME_-p5958.log`
- xcresult: `/tmp/mc-agent-ios-task114-test114IOSWriteProductHistoryMatrix-20260522T065938Z.xcresult`
- screenshot: `n/a`

## Next Action

Run cleanup/residue for TASK114_REALTIME_, then reconcile/runtime-parity/sync-matrix.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-114
- source: live.mutation-near-realtime
- status: PASS
- products: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- suppliers: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- categories: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- product_prices: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- history_entries: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None