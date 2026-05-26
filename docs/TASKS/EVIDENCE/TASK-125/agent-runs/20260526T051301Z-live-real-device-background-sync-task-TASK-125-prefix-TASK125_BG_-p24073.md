# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260526T051301Z-live-real-device-background-sync-task-TASK-125-prefix-TASK125_BG_-p24073
- **Task**: TASK-125
- **Command**: `live real-device-background-sync --task TASK-125 --prefix TASK125_BG_`
- **Platform**: live
- **Safety**: live-write
- **Result**: BLOCKED_EXTERNAL (exit 2)
- **Duration**: 357 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: e4eb3a47
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

TASK-125 background-sync BLOCKED_EXTERNAL_IOS_SCHEDULER_POLICY: physical BG debug/expiration evidence is incomplete.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T051301Z-live-real-device-background-sync-task-TASK-125-prefix-TASK125_BG_-p24073.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T051301Z-live-real-device-background-sync-task-TASK-125-prefix-TASK125_BG_-p24073.json`
- Log: `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T051301Z-live-real-device-background-sync-task-TASK-125-prefix-TASK125_BG_-p24073.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Collect BGTask debug-trigger/expiration evidence on iPhone or document scheduler-policy acceptance before REVIEW/DONE.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-125
- source: live.real-device-background-sync
- status: BLOCKED_EXTERNAL_IOS_SCHEDULER_POLICY
- products: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- suppliers: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- categories: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- product_prices: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- history_entries: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None