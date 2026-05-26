# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260526T051932Z-live-real-device-kill-restart-pending-task-TASK-125-prefix-TASK125_RESTART_-p30054
- **Task**: TASK-125
- **Command**: `live real-device-kill-restart-pending --task TASK-125 --prefix TASK125_RESTART_`
- **Platform**: ios
- **Safety**: live-write
- **Result**: PASS (exit 0)
- **Duration**: 253130 ms
- **Repo**: <HOME_REDACTED>/AndroidStudioProjects/MerchandiseControlSplitView
- **Branch**: main
- **Git SHA**: 2896e3c
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: L3
- **Cleanup plan ID**: n/a

## Summary

Live offline-reconnect-sync PASS for TASK125_RESTART_OFF_20260526T051932Z_: offline local-first reconnect applied both directions through targeted sync_events.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T051932Z-live-real-device-kill-restart-pending-task-TASK-125-prefix-TASK125_RESTART_-p30054.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T051932Z-live-real-device-kill-restart-pending-task-TASK-125-prefix-TASK125_RESTART_-p30054.json`
- Log: `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T051932Z-live-real-device-kill-restart-pending-task-TASK-125-prefix-TASK125_RESTART_-p30054.log`
- xcresult: `/tmp/mc-agent-ios-task114-test114IOSOfflineReconnectProductPriceHistoryMatrix-20260526T051932Z.xcresult`
- screenshot: `n/a`

## Next Action

Run cleanup/residue for TASK125_RESTART_, then rerun near-realtime/runtime parity/final gates.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-125
- source: live.offline-reconnect-sync
- status: PASS
- products: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- suppliers: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- categories: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- product_prices: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- history_entries: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None