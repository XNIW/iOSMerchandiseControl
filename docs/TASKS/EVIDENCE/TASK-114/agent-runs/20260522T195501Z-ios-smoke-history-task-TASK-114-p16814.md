# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260522T195501Z-ios-smoke-history-task-TASK-114-p16814
- **Task**: TASK-114
- **Command**: `ios smoke history --task TASK-114`
- **Platform**: ios
- **Safety**: live-write
- **Result**: pass_with_notes (exit 0)
- **Duration**: 45507 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: 0352006
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

iOS smoke history PASS_WITH_NOTES: runtime app launched and HistoryView uses the UUID/technical-title display formatter; capture visual/XcodeBuildMCP evidence for strict UI proof.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T195501Z-ios-smoke-history-task-TASK-114-p16814.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T195501Z-ios-smoke-history-task-TASK-114-p16814.json`
- Log: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T195501Z-ios-smoke-history-task-TASK-114-p16814.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Capture iOS History screenshot/accessibility evidence and run live runtime-parity.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-114
- source: ios.runtime-ui-counts
- status: PASS
- products: active=19696 deleted=21 all=19717 dirty=0 pending=0 localOnly=0 userVisible=None
- suppliers: active=59 deleted=0 all=59 dirty=0 pending=0 localOnly=0 userVisible=None
- categories: active=28 deleted=0 all=28 dirty=0 pending=0 localOnly=0 userVisible=None
- product_prices: active=41111 deleted=0 all=41111 dirty=0 pending=0 localOnly=0 userVisible=None
- history_entries: active=11 deleted=24 all=35 dirty=0 pending=0 localOnly=0 userVisible=11
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None