# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260522T184046Z-live-offline-reconnect-sync-task-TASK-114-prefix-TASK114_REVIEW_OFFLINE_-p78759
- **Task**: TASK-114
- **Command**: `live offline-reconnect-sync --task TASK-114 --prefix TASK114_REVIEW_OFFLINE_`
- **Platform**: ios
- **Safety**: live-write
- **Result**: pass (exit 0)
- **Duration**: 186242 ms
- **Repo**: <HOME_REDACTED>/AndroidStudioProjects/MerchandiseControlSplitView
- **Branch**: main
- **Git SHA**: d2b98c8
- **Dirty**: clean
- **Profile**: null
- **Android offline tier**: L3
- **Cleanup plan ID**: n/a

## Summary

Live offline-reconnect-sync PASS for TASK114_REVIEW_OFFLINE_OFF_20260522T184046Z_: offline local-first reconnect applied both directions through targeted sync_events.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T184046Z-live-offline-reconnect-sync-task-TASK-114-prefix-TASK114_REVIEW_OFFLINE_-p78759.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T184046Z-live-offline-reconnect-sync-task-TASK-114-prefix-TASK114_REVIEW_OFFLINE_-p78759.json`
- Log: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T184046Z-live-offline-reconnect-sync-task-TASK-114-prefix-TASK114_REVIEW_OFFLINE_-p78759.log`
- xcresult: `/tmp/mc-agent-ios-task114-test114IOSOfflineReconnectProductPriceHistoryMatrix-20260522T184046Z.xcresult`
- screenshot: `n/a`

## Next Action

Run cleanup/residue for TASK114_REVIEW_OFFLINE_, then rerun near-realtime/runtime parity/final gates.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-114
- source: live.offline-reconnect-sync
- status: PASS
- products: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- suppliers: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- categories: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- product_prices: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- history_entries: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None