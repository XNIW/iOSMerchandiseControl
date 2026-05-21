# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260521T225722Z-live-reconcile-counts-task-TASK-114-prefix-TASK114_RECON_-p62381
- **Task**: TASK-114
- **Command**: `live reconcile-counts --task TASK-114 --prefix TASK114_RECON_`
- **Platform**: live
- **Safety**: live-write
- **Result**: fail (exit 1)
- **Duration**: 6591 ms
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

- Markdown: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260521T225722Z-live-reconcile-counts-task-TASK-114-prefix-TASK114_RECON_-p62381.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260521T225722Z-live-reconcile-counts-task-TASK-114-prefix-TASK114_RECON_-p62381.json`
- Log: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260521T225722Z-live-reconcile-counts-task-TASK-114-prefix-TASK114_RECON_-p62381.log`
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
  - android: products=active:19700/deleted:0/all:19700/pending:0/localOnly:0/userVisible:None; suppliers=active:61/deleted:0/all:61/pending:0/localOnly:0/userVisible:None; categories=active:30/deleted:0/all:30/pending:0/localOnly:0/userVisible:None; product_prices=active:41115/deleted:0/all:41115/pending:0/localOnly:0/userVisible:None; history_entries=active:18/deleted:2/all:20/pending:0/localOnly:0/userVisible:17
  - ios: products=active:19696/deleted:0/all:19696/pending:0/localOnly:0/userVisible:None; suppliers=active:59/deleted:0/all:59/pending:0/localOnly:0/userVisible:None; categories=active:28/deleted:0/all:28/pending:0/localOnly:0/userVisible:None; product_prices=active:41111/deleted:0/all:41111/pending:0/localOnly:0/userVisible:None; history_entries=active:11/deleted:0/all:11/pending:0/localOnly:0/userVisible:11
- drift:
  - categories.active: {'android': 30, 'ios': 28, 'supabase': 28}
  - history_entries.userVisible: {'android': 17, 'ios': 11, 'supabase': 11}
  - product_prices.active: {'android': 41115, 'ios': 41111, 'supabase': 41111}
  - products.active: {'android': 19700, 'ios': 19696, 'supabase': 19696}
  - suppliers.active: {'android': 61, 'ios': 59, 'supabase': 59}
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=1 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None