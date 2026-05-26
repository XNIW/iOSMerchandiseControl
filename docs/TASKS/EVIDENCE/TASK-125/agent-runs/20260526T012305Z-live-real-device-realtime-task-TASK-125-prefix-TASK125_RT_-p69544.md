# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260526T012305Z-live-real-device-realtime-task-TASK-125-prefix-TASK125_RT_-p69544
- **Task**: TASK-125
- **Command**: `live real-device-realtime --task TASK-125 --prefix TASK125_RT_`
- **Platform**: ios
- **Safety**: live-write
- **Result**: FAIL (exit 1)
- **Duration**: 391824 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: e4eb3a47
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

Live sync wait FAIL: ios did not receive task123_android_to_ios_single within 30s.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T012305Z-live-real-device-realtime-task-TASK-125-prefix-TASK125_RT_-p69544.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T012305Z-live-real-device-realtime-task-TASK-125-prefix-TASK125_RT_-p69544.json`
- Log: `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T012305Z-live-real-device-realtime-task-TASK-125-prefix-TASK125_RT_-p69544.log`
- xcresult: `/tmp/mc-agent-ios-task114-test123IOSSingleCatalogCreatePropagation-20260526T012305Z.xcresult`
- screenshot: `n/a`

## Next Action

Inspect foreground app auto-sync/realtime logs and rerun after fixing push/pull trigger.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-125
- source: ios.physical-runtime-counts
- status: PASS
- products: active=16820 deleted=0 all=16820 dirty=0 pending=0 localOnly=16820 userVisible=None
- suppliers: active=82 deleted=0 all=82 dirty=0 pending=0 localOnly=82 userVisible=None
- categories: active=46 deleted=0 all=46 dirty=0 pending=0 localOnly=46 userVisible=None
- product_prices: active=40083 deleted=0 all=40083 dirty=0 pending=0 localOnly=40083 userVisible=None
- history_entries: active=23 deleted=0 all=23 dirty=0 pending=0 localOnly=1 userVisible=23
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None