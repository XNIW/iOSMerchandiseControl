# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260526T013611Z-ios-device-auth-preflight-live-task-TASK-125-p76006
- **Task**: TASK-125
- **Command**: `ios device-auth-preflight --live --task TASK-125`
- **Platform**: ios
- **Safety**: live-readonly
- **Result**: BLOCKED_EXTERNAL (exit 2)
- **Duration**: 53440 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: e4eb3a47
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

iOS physical-auth-store-diagnostics BLOCKED: physical app session is not ready for acceptance.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T013611Z-ios-device-auth-preflight-live-task-TASK-125-p76006.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T013611Z-ios-device-auth-preflight-live-task-TASK-125-p76006.json`
- Log: `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T013611Z-ios-device-auth-preflight-live-task-TASK-125-p76006.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Open the app on the physical iPhone, complete login/session restore, then rerun.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-125
- source: ios.physical-auth-store-diagnostics
- status: BLOCKED
- products: active=16820 deleted=0 all=16820 dirty=0 pending=0 localOnly=16820 userVisible=None
- suppliers: active=82 deleted=0 all=82 dirty=0 pending=0 localOnly=82 userVisible=None
- categories: active=46 deleted=0 all=46 dirty=0 pending=0 localOnly=46 userVisible=None
- product_prices: active=40083 deleted=0 all=40083 dirty=0 pending=0 localOnly=40083 userVisible=None
- history_entries: active=50 deleted=0 all=50 dirty=0 pending=0 localOnly=0 userVisible=50
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None