# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260525T023727Z-live-mutation-near-realtime-task-TASK-123-prefix-TASK123_SPEED_-p88265
- **Task**: TASK-123
- **Command**: `live mutation-near-realtime --task TASK-123 --prefix TASK123_SPEED_`
- **Platform**: ios
- **Safety**: live-write
- **Result**: FAIL (exit 1)
- **Duration**: 187025 ms
- **Repo**: <HOME_REDACTED>/AndroidStudioProjects/MerchandiseControlSplitView
- **Branch**: main
- **Git SHA**: b3f65de
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

Live sync wait FAIL: ios did not receive android_to_ios within 15s.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-123/agent-runs/20260525T023727Z-live-mutation-near-realtime-task-TASK-123-prefix-TASK123_SPEED_-p88265.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-123/agent-runs/20260525T023727Z-live-mutation-near-realtime-task-TASK-123-prefix-TASK123_SPEED_-p88265.json`
- Log: `docs/TASKS/EVIDENCE/TASK-123/agent-runs/20260525T023727Z-live-mutation-near-realtime-task-TASK-123-prefix-TASK123_SPEED_-p88265.log`
- xcresult: `/tmp/mc-agent-ios-task114-test114IOSWriteProductHistoryMatrix-20260525T023727Z.xcresult`
- screenshot: `n/a`

## Next Action

Inspect foreground app auto-sync/realtime logs and rerun after fixing push/pull trigger.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-123
- source: ios.runtime-store-counts
- status: PASS
- products: active=19886 deleted=0 all=19886 dirty=0 pending=0 localOnly=0 userVisible=None
- suppliers: active=81 deleted=0 all=81 dirty=1 pending=1 localOnly=2 userVisible=None
- categories: active=49 deleted=0 all=49 dirty=1 pending=1 localOnly=2 userVisible=None
- product_prices: active=15386 deleted=0 all=15386 dirty=2 pending=2 localOnly=0 userVisible=None
- history_entries: active=2 deleted=0 all=2 dirty=0 pending=0 localOnly=0 userVisible=2
- prune: wouldPrune=0 didPrune=0 skippedDirty=4 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None