# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260522T062803Z-ios-runtime-ui-counts-live-task-TASK-114-p48243
- **Task**: TASK-114
- **Command**: `ios runtime-ui-counts --live --task TASK-114`
- **Platform**: ios
- **Safety**: live-write
- **Result**: pass (exit 0)
- **Duration**: 15704 ms
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

- Markdown: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T062803Z-ios-runtime-ui-counts-live-task-TASK-114-p48243.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T062803Z-ios-runtime-ui-counts-live-task-TASK-114-p48243.json`
- Log: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T062803Z-ios-runtime-ui-counts-live-task-TASK-114-p48243.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Compare with Supabase/Android and run iOS live smoke Options/History.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-114
- source: ios.runtime-store-counts
- status: PASS
- products: active=19696 deleted=2 all=19698 dirty=0 pending=0 localOnly=0 userVisible=None
- suppliers: active=59 deleted=0 all=59 dirty=0 pending=0 localOnly=0 userVisible=None
- categories: active=28 deleted=0 all=28 dirty=0 pending=0 localOnly=0 userVisible=None
- product_prices: active=41111 deleted=0 all=41111 dirty=0 pending=0 localOnly=0 userVisible=None
- history_entries: active=11 deleted=5 all=16 dirty=0 pending=0 localOnly=0 userVisible=11
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None