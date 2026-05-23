# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260523T032231Z-live-physical-runtime-parity-task-TASK-115-prefix-TASK115_PHYSICAL_-p55423
- **Task**: TASK-115
- **Command**: `live physical-runtime-parity --task TASK-115 --prefix TASK115_PHYSICAL_`
- **Platform**: android
- **Safety**: safe-readonly
- **Result**: fail (exit 1)
- **Duration**: 82220 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: f6efc84
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

Live physical-runtime-parity FAIL for TASK115_PHYSICAL_: count drift remains across runtime sources.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-115/agent-runs/20260523T032231Z-live-physical-runtime-parity-task-TASK-115-prefix-TASK115_PHYSICAL_-p55423.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-115/agent-runs/20260523T032231Z-live-physical-runtime-parity-task-TASK-115-prefix-TASK115_PHYSICAL_-p55423.json`
- Log: `docs/TASKS/EVIDENCE/TASK-115/agent-runs/20260523T032231Z-live-physical-runtime-parity-task-TASK-115-prefix-TASK115_PHYSICAL_-p55423.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Inspect drift, fix apply/push/store binding, then rerun.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-115
- source: live.physical-runtime-parity
- status: FAIL
- products: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- suppliers: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- categories: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- product_prices: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- history_entries: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None