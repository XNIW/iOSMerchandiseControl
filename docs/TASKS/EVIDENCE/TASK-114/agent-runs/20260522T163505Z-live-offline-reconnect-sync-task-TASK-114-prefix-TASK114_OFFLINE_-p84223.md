# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260522T163505Z-live-offline-reconnect-sync-task-TASK-114-prefix-TASK114_OFFLINE_-p84223
- **Task**: TASK-114
- **Command**: `live offline-reconnect-sync --task TASK-114 --prefix TASK114_OFFLINE_`
- **Platform**: ios
- **Safety**: live-write
- **Result**: fail (exit 1)
- **Duration**: 221924 ms
- **Repo**: <HOME_REDACTED>/AndroidStudioProjects/MerchandiseControlSplitView
- **Branch**: main
- **Git SHA**: 8f6c04f
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

Live sync wait FAIL: ios did not receive android_offline_to_ios within 30s.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T163505Z-live-offline-reconnect-sync-task-TASK-114-prefix-TASK114_OFFLINE_-p84223.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T163505Z-live-offline-reconnect-sync-task-TASK-114-prefix-TASK114_OFFLINE_-p84223.json`
- Log: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T163505Z-live-offline-reconnect-sync-task-TASK-114-prefix-TASK114_OFFLINE_-p84223.log`
- xcresult: `/tmp/mc-agent-ios-task114-test114IOSOfflineReconnectProductPriceHistoryMatrix-20260522T163505Z.xcresult`
- screenshot: `n/a`

## Next Action

Inspect foreground app auto-sync/realtime logs and rerun after fixing push/pull trigger.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-114
- source: ios.runtime-store-counts
- status: PASS
- products: active=19728 deleted=12 all=19740 dirty=0 pending=0 localOnly=0 userVisible=None
- suppliers: active=87 deleted=0 all=87 dirty=0 pending=0 localOnly=0 userVisible=None
- categories: active=56 deleted=0 all=56 dirty=0 pending=0 localOnly=0 userVisible=None
- product_prices: active=41203 deleted=12 all=41215 dirty=0 pending=0 localOnly=0 userVisible=None
- history_entries: active=43 deleted=15 all=58 dirty=0 pending=0 localOnly=0 userVisible=43
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None