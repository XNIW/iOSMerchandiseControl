# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260522T154716Z-live-reconcile-counts-task-TASK-114-prefix-TASK114_RECON_-p93390
- **Task**: TASK-114
- **Command**: `live reconcile-counts --task TASK-114 --prefix TASK114_RECON_`
- **Platform**: live
- **Safety**: live-write
- **Result**: pass (exit 0)
- **Duration**: 10203 ms
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

- Markdown: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T154716Z-live-reconcile-counts-task-TASK-114-prefix-TASK114_RECON_-p93390.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T154716Z-live-reconcile-counts-task-TASK-114-prefix-TASK114_RECON_-p93390.json`
- Log: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T154716Z-live-reconcile-counts-task-TASK-114-prefix-TASK114_RECON_-p93390.log`
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
  - supabase: products=active:19720/deleted:12/all:19732/pending:0/localOnly:0/userVisible:None; suppliers=active:81/deleted:0/all:81/pending:0/localOnly:0/userVisible:None; categories=active:50/deleted:0/all:50/pending:0/localOnly:0/userVisible:None; product_prices=active:41179/deleted:0/all:41189/pending:0/localOnly:0/userVisible:None; history_entries=active:35/deleted:16/all:51/pending:0/localOnly:0/userVisible:35
  - android: products=active:19720/deleted:0/all:19720/pending:0/localOnly:0/userVisible:None; suppliers=active:81/deleted:0/all:81/pending:0/localOnly:0/userVisible:None; categories=active:50/deleted:0/all:50/pending:0/localOnly:0/userVisible:None; product_prices=active:41179/deleted:0/all:41179/pending:0/localOnly:0/userVisible:None; history_entries=active:36/deleted:7/all:43/pending:0/localOnly:0/userVisible:35
  - ios: products=active:19720/deleted:8/all:19728/pending:0/localOnly:0/userVisible:None; suppliers=active:81/deleted:0/all:81/pending:0/localOnly:0/userVisible:None; categories=active:50/deleted:0/all:50/pending:0/localOnly:0/userVisible:None; product_prices=active:41179/deleted:10/all:41189/pending:0/localOnly:0/userVisible:None; history_entries=active:35/deleted:12/all:47/pending:0/localOnly:0/userVisible:35
- drift: none
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=1 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None