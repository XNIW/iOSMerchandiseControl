# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260525T062225Z-live-task123-burst-10-task-TASK-123-prefix-TASK123_BURST_-p12861
- **Task**: TASK-123
- **Command**: `live task123-burst-10 --task TASK-123 --prefix TASK123_BURST_`
- **Platform**: ios
- **Safety**: live-write
- **Result**: FAIL (exit 1)
- **Duration**: 407555 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: cd31c09e
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

TASK-123 burst-10 FAIL: inspect burst deltas/duplicates.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-123/agent-runs/20260525T062225Z-live-task123-burst-10-task-TASK-123-prefix-TASK123_BURST_-p12861.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-123/agent-runs/20260525T062225Z-live-task123-burst-10-task-TASK-123-prefix-TASK123_BURST_-p12861.json`
- Log: `docs/TASKS/EVIDENCE/TASK-123/agent-runs/20260525T062225Z-live-task123-burst-10-task-TASK-123-prefix-TASK123_BURST_-p12861.log`
- xcresult: `/tmp/mc-agent-ios-task114-test123IOSSingleCatalogCreatePropagation-20260525T062225Z.xcresult`
- screenshot: `n/a`

## Next Action

Fix burst behavior and rerun task123-burst-10.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-123
- source: live.task123-burst-10
- status: FAIL
- products: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- suppliers: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- categories: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- product_prices: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- history_entries: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None