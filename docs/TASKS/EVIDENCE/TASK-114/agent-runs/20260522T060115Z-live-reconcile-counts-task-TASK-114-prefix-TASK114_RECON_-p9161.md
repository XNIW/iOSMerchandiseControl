# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260522T060115Z-live-reconcile-counts-task-TASK-114-prefix-TASK114_RECON_-p9161
- **Task**: TASK-114
- **Command**: `live reconcile-counts --task TASK-114 --prefix TASK114_RECON_`
- **Platform**: live
- **Safety**: live-write
- **Result**: fail (exit 1)
- **Duration**: 8945 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: c1ee078
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

- Markdown: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T060115Z-live-reconcile-counts-task-TASK-114-prefix-TASK114_RECON_-p9161.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T060115Z-live-reconcile-counts-task-TASK-114-prefix-TASK114_RECON_-p9161.json`
- Log: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T060115Z-live-reconcile-counts-task-TASK-114-prefix-TASK114_RECON_-p9161.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Inspect drift table in report, repair sync/apply/prune, then rerun.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-114
- source: live.reconcile-counts
- status: FAIL
- products: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- suppliers: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- categories: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- product_prices: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- history_entries: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- source counts:
  - supabase: products=active:19696/deleted:0/all:19696/pending:0/localOnly:0/userVisible:None; suppliers=active:59/deleted:0/all:59/pending:0/localOnly:0/userVisible:None; categories=active:28/deleted:0/all:28/pending:0/localOnly:0/userVisible:None; product_prices=active:41111/deleted:0/all:41111/pending:0/localOnly:0/userVisible:None; history_entries=active:11/deleted:4/all:15/pending:0/localOnly:0/userVisible:11
  - android: products=active:19696/deleted:0/all:19696/pending:0/localOnly:0/userVisible:None; suppliers=active:59/deleted:0/all:59/pending:0/localOnly:0/userVisible:None; categories=active:28/deleted:0/all:28/pending:0/localOnly:0/userVisible:None; product_prices=active:41111/deleted:0/all:41111/pending:0/localOnly:0/userVisible:None; history_entries=active:12/deleted:0/all:12/pending:0/localOnly:0/userVisible:11
  - ios: products=active:19700/deleted:2/all:19702/pending:0/localOnly:0/userVisible:None; suppliers=active:61/deleted:0/all:61/pending:0/localOnly:0/userVisible:None; categories=active:30/deleted:0/all:30/pending:0/localOnly:0/userVisible:None; product_prices=active:41117/deleted:0/all:41117/pending:0/localOnly:0/userVisible:None; history_entries=active:13/deleted:5/all:18/pending:0/localOnly:0/userVisible:13
- drift:
  - categories.active: {'android': 28, 'ios': 30, 'supabase': 28}
  - history_entries.userVisible: {'android': 11, 'ios': 13, 'supabase': 11}
  - product_prices.active: {'android': 41111, 'ios': 41117, 'supabase': 41111}
  - products.active: {'android': 19696, 'ios': 19700, 'supabase': 19696}
  - suppliers.active: {'android': 59, 'ios': 61, 'supabase': 59}
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=1 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None