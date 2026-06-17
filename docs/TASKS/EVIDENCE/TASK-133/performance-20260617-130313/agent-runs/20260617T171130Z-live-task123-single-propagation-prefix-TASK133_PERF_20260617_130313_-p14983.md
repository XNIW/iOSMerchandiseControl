# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260617T171130Z-live-task123-single-propagation-prefix-TASK133_PERF_20260617_130313_-p14983
- **Task**: TASK-133
- **Command**: `live task123-single-propagation --prefix TASK133_PERF_20260617_130313_`
- **Platform**: ios
- **Safety**: live-write
- **Result**: PASS (exit 0)
- **Duration**: 604622 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: 98a01d19
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

TASK-123 single propagation PASS: 10/10 warm per direction within p50/p95/max budget.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-133/performance-20260617-130313/agent-runs/20260617T171130Z-live-task123-single-propagation-prefix-TASK133_PERF_20260617_130313_-p14983.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-133/performance-20260617-130313/agent-runs/20260617T171130Z-live-task123-single-propagation-prefix-TASK133_PERF_20260617_130313_-p14983.json`
- Log: `docs/TASKS/EVIDENCE/TASK-133/performance-20260617-130313/agent-runs/20260617T171130Z-live-task123-single-propagation-prefix-TASK133_PERF_20260617_130313_-p14983.log`
- xcresult: `/tmp/mc-agent-ios-task114-test123IOSSingleCatalogCreatePropagation-1781716846249-20260617T171130Z.xcresult`
- screenshot: `n/a`

## Next Action

Run cold-ish, no-op, burst-10 and cleanup/residue.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-133
- source: live.task123-single-propagation
- status: PASS
- products: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- suppliers: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- categories: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- product_prices: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- history_entries: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None