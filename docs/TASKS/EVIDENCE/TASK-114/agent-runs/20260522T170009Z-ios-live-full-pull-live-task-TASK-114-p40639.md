# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260522T170009Z-ios-live-full-pull-live-task-TASK-114-p40639
- **Task**: TASK-114
- **Command**: `ios live-full-pull --live --task TASK-114`
- **Platform**: ios
- **Safety**: live-write
- **Result**: fail (exit 1)
- **Duration**: 91122 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: c1ee078
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

iOS live-full-pull FAIL/BLOCKED. xcresult=/tmp/mc-agent-ios-live-full-pull-20260522T170009Z.xcresult

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T170009Z-ios-live-full-pull-live-task-TASK-114-p40639.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T170009Z-ios-live-full-pull-live-task-TASK-114-p40639.json`
- Log: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T170009Z-ios-live-full-pull-live-task-TASK-114-p40639.log`
- xcresult: `/tmp/mc-agent-ios-live-full-pull-20260522T170009Z.xcresult`
- screenshot: `n/a`

## Next Action

Inspect xcresult/log; verify app-auth session and persistent SwiftData store.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-114
- source: ios.live-full-pull
- status: FAIL
- products: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- suppliers: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- categories: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- product_prices: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- history_entries: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- prune: wouldPrune=0 didPrune=2 skippedDirty=0 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=True