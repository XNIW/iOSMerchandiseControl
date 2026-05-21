# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260521T191220Z-live-reconcile-counts-task-TASK-114-prefix-TASK114_RECON_-profile-linked-p53256
- **Task**: TASK-114
- **Command**: `live reconcile-counts --task TASK-114 --prefix TASK114_RECON_ --profile linked`
- **Platform**: live
- **Safety**: live-write
- **Result**: fail (exit 1)
- **Duration**: 5864 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: 4b74773
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

Live reconcile-counts FAIL for TASK114_RECON_: drift remains between Android, iOS and Supabase.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260521T191220Z-live-reconcile-counts-task-TASK-114-prefix-TASK114_RECON_-profile-linked-p53256.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260521T191220Z-live-reconcile-counts-task-TASK-114-prefix-TASK114_RECON_-profile-linked-p53256.json`
- Log: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260521T191220Z-live-reconcile-counts-task-TASK-114-prefix-TASK114_RECON_-profile-linked-p53256.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Inspect drift table in report, repair sync/apply/prune, then rerun.

## Reconciliation Detail

- schemaVersion: 1.0
- taskId: TASK-114
- source: live.reconcile-counts
- status: FAIL
- products: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- suppliers: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- categories: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- product_prices: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- history_entries: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=0