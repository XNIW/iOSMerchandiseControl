# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260522T164256Z-live-offline-reconnect-sync-task-TASK-114-prefix-TASK114_OFFLINE_-p2977
- **Task**: TASK-114
- **Command**: `live offline-reconnect-sync --task TASK-114 --prefix TASK114_OFFLINE_`
- **Platform**: ios
- **Safety**: live-write
- **Result**: fail (exit 1)
- **Duration**: 197255 ms
- **Repo**: <HOME_REDACTED>/AndroidStudioProjects/MerchandiseControlSplitView
- **Branch**: main
- **Git SHA**: 8f6c04f
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

Live offline-reconnect-sync FAIL for TASK114_OFFLINE_OFF_20260522T164256Z_: targeted events, timings or full-pull guard failed.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T164256Z-live-offline-reconnect-sync-task-TASK-114-prefix-TASK114_OFFLINE_-p2977.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T164256Z-live-offline-reconnect-sync-task-TASK-114-prefix-TASK114_OFFLINE_-p2977.json`
- Log: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T164256Z-live-offline-reconnect-sync-task-TASK-114-prefix-TASK114_OFFLINE_-p2977.log`
- xcresult: `/tmp/mc-agent-ios-task114-test114IOSOfflineReconnectProductPriceHistoryMatrix-20260522T164256Z.xcresult`
- screenshot: `n/a`

## Next Action

Inspect offline reconnect event coverage/timings and rerun.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-114
- source: live.offline-reconnect-sync
- status: FAIL
- products: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- suppliers: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- categories: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- product_prices: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- history_entries: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None