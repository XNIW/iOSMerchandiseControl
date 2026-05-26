# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260526T043614Z-ios-runtime-ui-counts-live-task-TASK-125-p83653
- **Task**: TASK-125
- **Command**: `ios runtime-ui-counts --live --task TASK-125`
- **Platform**: ios
- **Safety**: live-write
- **Result**: BLOCKED_EXTERNAL (exit 2)
- **Duration**: 16761 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: e4eb3a47
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

iOS runtime-ui-counts BLOCKED: physical iPhone automatic runtime is gated by account/recovery decision.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T043614Z-ios-runtime-ui-counts-live-task-TASK-125-p83653.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T043614Z-ios-runtime-ui-counts-live-task-TASK-125-p83653.json`
- Log: `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T043614Z-ios-runtime-ui-counts-live-task-TASK-125-p83653.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

On the iPhone, open Options > account sync review/recovery, explicitly bind or recover the local store for the signed-in owner, then rerun TASK-125 iOS device-auth-preflight and real-device matrix.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-125
- source: ios.physical-runtime-counts
- status: BLOCKED
- products: active=19734 deleted=0 all=19734 dirty=0 pending=0 localOnly=0 userVisible=None
- suppliers: active=97 deleted=0 all=97 dirty=0 pending=0 localOnly=0 userVisible=None
- categories: active=66 deleted=0 all=66 dirty=0 pending=0 localOnly=0 userVisible=None
- product_prices: active=41185 deleted=0 all=41185 dirty=0 pending=0 localOnly=0 userVisible=None
- history_entries: active=68 deleted=0 all=68 dirty=0 pending=0 localOnly=0 userVisible=68
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None