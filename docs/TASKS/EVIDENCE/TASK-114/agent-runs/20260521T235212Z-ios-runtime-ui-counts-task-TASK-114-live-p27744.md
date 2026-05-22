# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260521T235212Z-ios-runtime-ui-counts-task-TASK-114-live-p27744
- **Task**: TASK-114
- **Command**: `ios runtime-ui-counts --task TASK-114 --live`
- **Platform**: ios
- **Safety**: live-write
- **Result**: pass (exit 0)
- **Duration**: 56625 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: c1ee078
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

iOS runtime-ui-counts PASS: launched app, read runtime default.store, and captured counts/baseline metadata.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260521T235212Z-ios-runtime-ui-counts-task-TASK-114-live-p27744.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260521T235212Z-ios-runtime-ui-counts-task-TASK-114-live-p27744.json`
- Log: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260521T235212Z-ios-runtime-ui-counts-task-TASK-114-live-p27744.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Compare with Supabase/Android and run iOS live smoke Options/History.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-114
- source: ios.runtime-ui-counts
- status: PASS
- products: active=19886 deleted=0 all=19886 dirty=0 pending=0 localOnly=0 userVisible=None
- suppliers: active=81 deleted=0 all=81 dirty=1 pending=1 localOnly=2 userVisible=None
- categories: active=49 deleted=0 all=49 dirty=1 pending=1 localOnly=2 userVisible=None
- product_prices: active=15386 deleted=0 all=15386 dirty=2 pending=2 localOnly=0 userVisible=None
- history_entries: active=2 deleted=0 all=2 dirty=0 pending=0 localOnly=2 userVisible=2
- prune: wouldPrune=0 didPrune=0 skippedDirty=4 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None