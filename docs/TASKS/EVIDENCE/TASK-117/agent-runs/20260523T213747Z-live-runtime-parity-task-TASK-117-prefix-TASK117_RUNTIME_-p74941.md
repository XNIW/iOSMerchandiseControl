# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260523T213747Z-live-runtime-parity-task-TASK-117-prefix-TASK117_RUNTIME_-p74941
- **Task**: TASK-117
- **Command**: `live runtime-parity --task TASK-117 --prefix TASK117_RUNTIME_`
- **Platform**: ios
- **Safety**: live-write
- **Result**: blocked (exit 2)
- **Duration**: 60639 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: e14b433
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

Live runtime-parity BLOCKED for TASK117_RUNTIME_: one or more runtime count sources unavailable.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-117/agent-runs/20260523T213747Z-live-runtime-parity-task-TASK-117-prefix-TASK117_RUNTIME_-p74941.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-117/agent-runs/20260523T213747Z-live-runtime-parity-task-TASK-117-prefix-TASK117_RUNTIME_-p74941.json`
- Log: `docs/TASKS/EVIDENCE/TASK-117/agent-runs/20260523T213747Z-live-runtime-parity-task-TASK-117-prefix-TASK117_RUNTIME_-p74941.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Resolve app/device/store blocker, then rerun runtime-parity.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-117
- source: live.runtime-parity
- status: BLOCKED
- products: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- suppliers: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- categories: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- product_prices: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- history_entries: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None