# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260522T224818Z-ios-physical-sync-acceptance-task-TASK-114-live-p4388
- **Task**: TASK-114
- **Command**: `ios physical-sync-acceptance --task TASK-114 --live`
- **Platform**: ios
- **Safety**: live-readonly
- **Result**: fail (exit 1)
- **Duration**: 55817 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: c932950
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

iOS physical-sync-acceptance FAIL: physical iPhone runtime loop or zero-work spinner signal remains.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T224818Z-ios-physical-sync-acceptance-task-TASK-114-live-p4388.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T224818Z-ios-physical-sync-acceptance-task-TASK-114-live-p4388.json`
- Log: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T224818Z-ios-physical-sync-acceptance-task-TASK-114-live-p4388.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Inspect physicalAcceptance and loopDiagnostics, fix, rerun.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-114
- source: ios.physical-sync-acceptance
- status: FAIL
- products: active=16820 deleted=0 all=16820 dirty=0 pending=0 localOnly=16820 userVisible=None
- suppliers: active=82 deleted=0 all=82 dirty=0 pending=0 localOnly=82 userVisible=None
- categories: active=46 deleted=0 all=46 dirty=0 pending=0 localOnly=46 userVisible=None
- product_prices: active=40083 deleted=0 all=40083 dirty=0 pending=0 localOnly=40083 userVisible=None
- history_entries: active=22 deleted=0 all=22 dirty=0 pending=0 localOnly=0 userVisible=22
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None