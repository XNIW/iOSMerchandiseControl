# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260522T022937Z-live-mutation-near-realtime-task-TASK-114-prefix-TASK114_REALTIME_DIAG3_-p58560
- **Task**: TASK-114
- **Command**: `live mutation-near-realtime --task TASK-114 --prefix TASK114_REALTIME_DIAG3_`
- **Platform**: android
- **Safety**: live-write
- **Result**: fail (exit 1)
- **Duration**: 234061 ms
- **Repo**: <HOME_REDACTED>/AndroidStudioProjects/MerchandiseControlSplitView
- **Branch**: main
- **Git SHA**: 8f6c04f
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

Live mutation-near-realtime FAIL: ios did not receive android_to_ios within 30s.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T022937Z-live-mutation-near-realtime-task-TASK-114-prefix-TASK114_REALTIME_DIAG3_-p58560.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T022937Z-live-mutation-near-realtime-task-TASK-114-prefix-TASK114_REALTIME_DIAG3_-p58560.json`
- Log: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T022937Z-live-mutation-near-realtime-task-TASK-114-prefix-TASK114_REALTIME_DIAG3_-p58560.log`
- xcresult: `/tmp/mc-agent-ios-task114-test114IOSWriteProductHistoryMatrix-20260522T022937Z.xcresult`
- screenshot: `n/a`

## Next Action

Inspect foreground app auto-sync/realtime logs and rerun after fixing push/pull trigger.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-114
- source: ios.runtime-ui-counts
- status: PASS
- products: active=19696 deleted=0 all=19696 dirty=0 pending=0 localOnly=0 userVisible=None
- suppliers: active=59 deleted=0 all=59 dirty=0 pending=0 localOnly=0 userVisible=None
- categories: active=28 deleted=0 all=28 dirty=0 pending=0 localOnly=0 userVisible=None
- product_prices: active=41111 deleted=0 all=41111 dirty=0 pending=0 localOnly=0 userVisible=None
- history_entries: active=23 deleted=5 all=28 dirty=0 pending=0 localOnly=0 userVisible=23
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None