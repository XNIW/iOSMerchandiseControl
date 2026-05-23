# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260523T033040Z-ios-physical-sync-acceptance-live-task-TASK-115-p60569
- **Task**: TASK-115
- **Command**: `ios physical-sync-acceptance --live --task TASK-115`
- **Platform**: ios
- **Safety**: live-readonly
- **Result**: blocked (exit 2)
- **Duration**: 48014 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: f6efc84
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

iOS physical-sync-acceptance BLOCKED: physical iPhone auth/session is not ready for acceptance.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-115/agent-runs/20260523T033040Z-ios-physical-sync-acceptance-live-task-TASK-115-p60569.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-115/agent-runs/20260523T033040Z-ios-physical-sync-acceptance-live-task-TASK-115-p60569.json`
- Log: `docs/TASKS/EVIDENCE/TASK-115/agent-runs/20260523T033040Z-ios-physical-sync-acceptance-live-task-TASK-115-p60569.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Open the physical iPhone app, complete login/session restore, then rerun physical-sync-acceptance.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-115
- source: ios.physical-sync-acceptance
- status: BLOCKED
- products: active=16820 deleted=0 all=16820 dirty=0 pending=0 localOnly=16820 userVisible=None
- suppliers: active=82 deleted=0 all=82 dirty=0 pending=0 localOnly=82 userVisible=None
- categories: active=46 deleted=0 all=46 dirty=0 pending=0 localOnly=46 userVisible=None
- product_prices: active=40083 deleted=0 all=40083 dirty=0 pending=0 localOnly=40083 userVisible=None
- history_entries: active=22 deleted=0 all=22 dirty=0 pending=0 localOnly=0 userVisible=22
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None