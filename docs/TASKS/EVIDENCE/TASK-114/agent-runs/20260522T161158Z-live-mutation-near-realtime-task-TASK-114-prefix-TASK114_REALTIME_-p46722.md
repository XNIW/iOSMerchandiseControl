# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260522T161158Z-live-mutation-near-realtime-task-TASK-114-prefix-TASK114_REALTIME_-p46722
- **Task**: TASK-114
- **Command**: `live mutation-near-realtime --task TASK-114 --prefix TASK114_REALTIME_`
- **Platform**: ios
- **Safety**: live-write
- **Result**: fail (exit 1)
- **Duration**: 215612 ms
- **Repo**: <HOME_REDACTED>/AndroidStudioProjects/MerchandiseControlSplitView
- **Branch**: main
- **Git SHA**: 8f6c04f
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

Live sync wait FAIL: ios did not receive android_to_ios within 30s.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T161158Z-live-mutation-near-realtime-task-TASK-114-prefix-TASK114_REALTIME_-p46722.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T161158Z-live-mutation-near-realtime-task-TASK-114-prefix-TASK114_REALTIME_-p46722.json`
- Log: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T161158Z-live-mutation-near-realtime-task-TASK-114-prefix-TASK114_REALTIME_-p46722.log`
- xcresult: `/tmp/mc-agent-ios-task114-test114IOSWriteProductHistoryMatrix-20260522T161158Z.xcresult`
- screenshot: `n/a`

## Next Action

Inspect foreground app auto-sync/realtime logs and rerun after fixing push/pull trigger.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-114
- source: ios.runtime-store-counts
- status: PASS
- products: active=19724 deleted=9 all=19733 dirty=0 pending=0 localOnly=0 userVisible=None
- suppliers: active=83 deleted=0 all=83 dirty=0 pending=0 localOnly=0 userVisible=None
- categories: active=52 deleted=0 all=52 dirty=0 pending=0 localOnly=0 userVisible=None
- product_prices: active=41193 deleted=12 all=41205 dirty=0 pending=0 localOnly=0 userVisible=None
- history_entries: active=37 deleted=12 all=49 dirty=0 pending=0 localOnly=0 userVisible=37
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None