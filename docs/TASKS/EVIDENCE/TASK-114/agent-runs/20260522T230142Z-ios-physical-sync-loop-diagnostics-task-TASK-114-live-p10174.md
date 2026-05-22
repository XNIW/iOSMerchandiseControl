# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260522T230142Z-ios-physical-sync-loop-diagnostics-task-TASK-114-live-p10174
- **Task**: TASK-114
- **Command**: `ios physical-sync-loop-diagnostics --task TASK-114 --live`
- **Platform**: ios
- **Safety**: live-readonly
- **Result**: pass (exit 0)
- **Duration**: 48960 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: c932950
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

iOS physical-sync-loop-diagnostics PASS: collected physical runtime counts, diagnostics, and loop classification.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T230142Z-ios-physical-sync-loop-diagnostics-task-TASK-114-live-p10174.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T230142Z-ios-physical-sync-loop-diagnostics-task-TASK-114-live-p10174.json`
- Log: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T230142Z-ios-physical-sync-loop-diagnostics-task-TASK-114-live-p10174.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Fix any loop classification, then run ios physical-sync-acceptance.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-114
- source: ios.physical-sync-loop-diagnostics
- status: PASS
- products: active=16820 deleted=0 all=16820 dirty=0 pending=0 localOnly=16820 userVisible=None
- suppliers: active=82 deleted=0 all=82 dirty=0 pending=0 localOnly=82 userVisible=None
- categories: active=46 deleted=0 all=46 dirty=0 pending=0 localOnly=46 userVisible=None
- product_prices: active=40083 deleted=0 all=40083 dirty=0 pending=0 localOnly=40083 userVisible=None
- history_entries: active=22 deleted=0 all=22 dirty=0 pending=0 localOnly=0 userVisible=22
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None