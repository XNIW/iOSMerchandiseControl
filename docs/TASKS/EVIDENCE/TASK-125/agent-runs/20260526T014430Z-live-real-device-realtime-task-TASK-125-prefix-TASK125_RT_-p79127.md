# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260526T014430Z-live-real-device-realtime-task-TASK-125-prefix-TASK125_RT_-p79127
- **Task**: TASK-125
- **Command**: `live real-device-realtime --task TASK-125 --prefix TASK125_RT_`
- **Platform**: ios
- **Safety**: live-write
- **Result**: FAIL (exit 1)
- **Duration**: 382405 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: e4eb3a47
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

TASK-123 single propagation FAIL: inspect per-iteration bottleneck fields.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T014430Z-live-real-device-realtime-task-TASK-125-prefix-TASK125_RT_-p79127.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T014430Z-live-real-device-realtime-task-TASK-125-prefix-TASK125_RT_-p79127.json`
- Log: `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T014430Z-live-real-device-realtime-task-TASK-125-prefix-TASK125_RT_-p79127.log`
- xcresult: `/tmp/mc-agent-ios-task114-test123IOSSingleCatalogCreatePropagation-20260526T014430Z.xcresult`
- screenshot: `n/a`

## Next Action

Fix the measured bottleneck and rerun task123-single-propagation.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-125
- source: live.task123-single-propagation
- status: FAIL
- products: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- suppliers: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- categories: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- product_prices: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- history_entries: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None