# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260617T224849Z-live-task123-single-propagation-task-TASK-135-prefix-TASK135_IOS_LIVE_20260617_1849_-p8484
- **Task**: TASK-135
- **Command**: `live task123-single-propagation --task TASK-135 --prefix TASK135_IOS_LIVE_20260617_1849_`
- **Platform**: ios
- **Safety**: live-write
- **Result**: PASS (exit 0)
- **Duration**: 182853 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: ad599451
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

TASK-123 single propagation PASS: 1/1 warm per direction within p50/p95/max budget.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-135/agent-runs/20260617T224849Z-live-task123-single-propagation-task-TASK-135-prefix-TASK135_IOS_LIVE_20260617_1849_-p8484.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-135/agent-runs/20260617T224849Z-live-task123-single-propagation-task-TASK-135-prefix-TASK135_IOS_LIVE_20260617_1849_-p8484.json`
- Log: `docs/TASKS/EVIDENCE/TASK-135/agent-runs/20260617T224849Z-live-task123-single-propagation-task-TASK-135-prefix-TASK135_IOS_LIVE_20260617_1849_-p8484.log`
- xcresult: `/tmp/mc-agent-ios-task114-test123IOSSingleCatalogCreatePropagation-1781736629782-20260617T224849Z.xcresult`
- screenshot: `n/a`

## Next Action

Run cold-ish, no-op, burst-10 and cleanup/residue.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-135
- source: live.task123-single-propagation
- status: PASS
- products: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- suppliers: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- categories: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- product_prices: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- history_entries: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None