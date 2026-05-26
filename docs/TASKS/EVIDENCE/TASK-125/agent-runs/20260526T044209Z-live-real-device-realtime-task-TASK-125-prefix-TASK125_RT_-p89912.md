# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260526T044209Z-live-real-device-realtime-task-TASK-125-prefix-TASK125_RT_-p89912
- **Task**: TASK-125
- **Command**: `live real-device-realtime --task TASK-125 --prefix TASK125_RT_`
- **Platform**: ios
- **Safety**: live-write
- **Result**: PASS_WITH_NOTES (exit 0)
- **Duration**: 713929 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: e4eb3a47
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

TASK-125 single propagation PASS_WITH_NOTES_NETWORK_VARIANCE: all mutations arrived, p95 <= 5s and max <= 15s; one or more real-device p50 samples exceeded the ideal 3s target.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T044209Z-live-real-device-realtime-task-TASK-125-prefix-TASK125_RT_-p89912.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T044209Z-live-real-device-realtime-task-TASK-125-prefix-TASK125_RT_-p89912.json`
- Log: `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T044209Z-live-real-device-realtime-task-TASK-125-prefix-TASK125_RT_-p89912.log`
- xcresult: `/tmp/mc-agent-ios-task114-test123IOSSingleCatalogCreatePropagation-20260526T044209Z.xcresult`
- screenshot: `n/a`

## Next Action

Continue TASK-125 real-device matrices; keep final drift/residue/pending checks strict.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-125
- source: live.task123-single-propagation
- status: PASS_WITH_NOTES_NETWORK_VARIANCE
- products: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- suppliers: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- categories: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- product_prices: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- history_entries: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None