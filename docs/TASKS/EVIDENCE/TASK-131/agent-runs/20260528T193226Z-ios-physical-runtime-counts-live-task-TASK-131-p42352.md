# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260528T193226Z-ios-physical-runtime-counts-live-task-TASK-131-p42352
- **Task**: TASK-131
- **Command**: `ios physical-runtime-counts --live --task TASK-131`
- **Platform**: ios
- **Safety**: live-readonly
- **Result**: PASS (exit 0)
- **Duration**: 64070 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: 96b900ef
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

- Markdown: `docs/TASKS/EVIDENCE/TASK-131/agent-runs/20260528T193226Z-ios-physical-runtime-counts-live-task-TASK-131-p42352.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-131/agent-runs/20260528T193226Z-ios-physical-runtime-counts-live-task-TASK-131-p42352.json`
- Log: `docs/TASKS/EVIDENCE/TASK-131/agent-runs/20260528T193226Z-ios-physical-runtime-counts-live-task-TASK-131-p42352.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Run ios physical-sync-loop-diagnostics or physical-sync-acceptance.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-131
- source: ios.physical-runtime-counts
- status: PASS
- products: active=19781 deleted=7 all=19788 dirty=0 pending=0 localOnly=0 userVisible=None
- suppliers: active=135 deleted=0 all=135 dirty=0 pending=0 localOnly=0 userVisible=None
- categories: active=104 deleted=0 all=104 dirty=0 pending=0 localOnly=0 userVisible=None
- product_prices: active=41313 deleted=14 all=41327 dirty=0 pending=0 localOnly=0 userVisible=None
- history_entries: active=98 deleted=4 all=102 dirty=0 pending=0 localOnly=0 userVisible=98
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None