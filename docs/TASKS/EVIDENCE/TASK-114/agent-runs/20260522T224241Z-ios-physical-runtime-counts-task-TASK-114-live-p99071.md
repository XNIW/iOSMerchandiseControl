# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260522T224241Z-ios-physical-runtime-counts-task-TASK-114-live-p99071
- **Task**: TASK-114
- **Command**: `ios physical-runtime-counts --task TASK-114 --live`
- **Platform**: ios
- **Safety**: live-readonly
- **Result**: pass (exit 0)
- **Duration**: 102088 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: c932950
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

iOS physical-runtime-counts PASS: launched physical iPhone app and read copied runtime SwiftData store.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T224241Z-ios-physical-runtime-counts-task-TASK-114-live-p99071.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T224241Z-ios-physical-runtime-counts-task-TASK-114-live-p99071.json`
- Log: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T224241Z-ios-physical-runtime-counts-task-TASK-114-live-p99071.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Run ios physical-sync-loop-diagnostics or physical-sync-acceptance.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-114
- source: ios.physical-runtime-counts
- status: PASS
- products: active=16820 deleted=0 all=16820 dirty=0 pending=0 localOnly=16820 userVisible=None
- suppliers: active=82 deleted=0 all=82 dirty=0 pending=0 localOnly=82 userVisible=None
- categories: active=46 deleted=0 all=46 dirty=0 pending=0 localOnly=46 userVisible=None
- product_prices: active=40083 deleted=0 all=40083 dirty=0 pending=0 localOnly=40083 userVisible=None
- history_entries: active=22 deleted=0 all=22 dirty=0 pending=0 localOnly=0 userVisible=22
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None