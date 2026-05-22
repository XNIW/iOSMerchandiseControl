# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260522T170635Z-live-reconcile-counts-task-TASK-114-prefix-TASK114_RECON_-p52150
- **Task**: TASK-114
- **Command**: `live reconcile-counts --task TASK-114 --prefix TASK114_RECON_`
- **Platform**: live
- **Safety**: live-write
- **Result**: pass (exit 0)
- **Duration**: 8052 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: c1ee078
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

- Markdown: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T170635Z-live-reconcile-counts-task-TASK-114-prefix-TASK114_RECON_-p52150.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T170635Z-live-reconcile-counts-task-TASK-114-prefix-TASK114_RECON_-p52150.json`
- Log: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T170635Z-live-reconcile-counts-task-TASK-114-prefix-TASK114_RECON_-p52150.log`
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
  - supabase: products=active:19732/deleted:18/all:19750/pending:0/localOnly:0/userVisible:None; suppliers=active:89/deleted:0/all:89/pending:0/localOnly:0/userVisible:None; categories=active:58/deleted:0/all:58/pending:0/localOnly:0/userVisible:None; product_prices=active:41217/deleted:0/all:41233/pending:0/localOnly:0/userVisible:None; history_entries=active:47/deleted:22/all:69/pending:0/localOnly:0/userVisible:47
  - android: products=active:19732/deleted:0/all:19732/pending:0/localOnly:0/userVisible:None; suppliers=active:89/deleted:0/all:89/pending:0/localOnly:0/userVisible:None; categories=active:58/deleted:0/all:58/pending:0/localOnly:0/userVisible:None; product_prices=active:41217/deleted:0/all:41217/pending:0/localOnly:0/userVisible:None; history_entries=active:48/deleted:4/all:52/pending:0/localOnly:0/userVisible:47
  - ios: products=active:19732/deleted:15/all:19747/pending:0/localOnly:0/userVisible:None; suppliers=active:89/deleted:0/all:89/pending:0/localOnly:0/userVisible:None; categories=active:58/deleted:0/all:58/pending:0/localOnly:0/userVisible:None; product_prices=active:41217/deleted:14/all:41231/pending:0/localOnly:0/userVisible:None; history_entries=active:47/deleted:19/all:66/pending:0/localOnly:0/userVisible:47
- drift: none
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=1 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None