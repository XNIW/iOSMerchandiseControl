# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260522T065108Z-live-offline-reconnect-sync-task-TASK-114-prefix-TASK114_OFFLINE_-p92881
- **Task**: TASK-114
- **Command**: `live offline-reconnect-sync --task TASK-114 --prefix TASK114_OFFLINE_`
- **Platform**: android
- **Safety**: safe-readonly
- **Result**: pass_with_notes (exit 0)
- **Duration**: 29310 ms
- **Repo**: <HOME_REDACTED>/AndroidStudioProjects/MerchandiseControlSplitView
- **Branch**: main
- **Git SHA**: 8f6c04f
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: L2
- **Cleanup plan ID**: n/a

## Summary

Live offline-reconnect-sync PASS_WITH_NOTES for TASK114_OFFLINE_: iOS deterministic offline retry and Android L2 reconnect passed; OS network-toggle L3 remains a stated gap.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T065108Z-live-offline-reconnect-sync-task-TASK-114-prefix-TASK114_OFFLINE_-p92881.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T065108Z-live-offline-reconnect-sync-task-TASK-114-prefix-TASK114_OFFLINE_-p92881.json`
- Log: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T065108Z-live-offline-reconnect-sync-task-TASK-114-prefix-TASK114_OFFLINE_-p92881.log`
- xcresult: `/tmp/mc-agent-ios-test-offline-20260522T065108Z.xcresult`
- screenshot: `n/a`

## Next Action

Use mutation-near-realtime for live cross-platform apply evidence; add an OS network-toggle L3 gate before claiming full offline live acceptance.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-114
- source: live.offline-reconnect-sync
- status: PASS_WITH_NOTES
- products: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- suppliers: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- categories: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- product_prices: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- history_entries: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None