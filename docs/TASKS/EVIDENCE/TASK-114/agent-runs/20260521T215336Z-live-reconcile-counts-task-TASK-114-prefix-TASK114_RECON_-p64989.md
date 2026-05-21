# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260521T215336Z-live-reconcile-counts-task-TASK-114-prefix-TASK114_RECON_-p64989
- **Task**: TASK-114
- **Command**: `live reconcile-counts --task TASK-114 --prefix TASK114_RECON_`
- **Platform**: live
- **Safety**: live-write
- **Result**: pass (exit 0)
- **Duration**: 7225 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: 4b74773
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

Live reconcile-counts PASS for TASK114_RECON_: Android, iOS and Supabase count definitions align.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260521T215336Z-live-reconcile-counts-task-TASK-114-prefix-TASK114_RECON_-p64989.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260521T215336Z-live-reconcile-counts-task-TASK-114-prefix-TASK114_RECON_-p64989.json`
- Log: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260521T215336Z-live-reconcile-counts-task-TASK-114-prefix-TASK114_RECON_-p64989.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Run live sync-matrix and cleanup/residue if test data was created.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-114
- source: live.reconcile-counts
- status: PASS
- products: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- suppliers: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- categories: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- product_prices: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- history_entries: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- source counts:
  - supabase: products=active:19696/deleted:0/all:19696/pending:0/localOnly:0/userVisible:None; suppliers=active:59/deleted:0/all:59/pending:0/localOnly:0/userVisible:None; categories=active:28/deleted:0/all:28/pending:0/localOnly:0/userVisible:None; product_prices=active:41111/deleted:0/all:41111/pending:0/localOnly:0/userVisible:None; history_entries=active:11/deleted:4/all:15/pending:0/localOnly:0/userVisible:11
  - android: products=active:19696/deleted:0/all:19696/pending:0/localOnly:0/userVisible:None; suppliers=active:59/deleted:0/all:59/pending:0/localOnly:0/userVisible:None; categories=active:28/deleted:0/all:28/pending:0/localOnly:0/userVisible:None; product_prices=active:41111/deleted:0/all:41111/pending:0/localOnly:0/userVisible:None; history_entries=active:12/deleted:0/all:12/pending:0/localOnly:0/userVisible:11
  - ios: products=active:19696/deleted:0/all:19696/pending:0/localOnly:0/userVisible:None; suppliers=active:59/deleted:0/all:59/pending:0/localOnly:0/userVisible:None; categories=active:28/deleted:0/all:28/pending:0/localOnly:0/userVisible:None; product_prices=active:41111/deleted:0/all:41111/pending:0/localOnly:0/userVisible:None; history_entries=active:11/deleted:0/all:11/pending:0/localOnly:0/userVisible:11
- drift: none
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=1 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None