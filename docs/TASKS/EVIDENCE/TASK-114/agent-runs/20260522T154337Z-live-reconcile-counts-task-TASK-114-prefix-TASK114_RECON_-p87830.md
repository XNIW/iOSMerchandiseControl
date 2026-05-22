# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260522T154337Z-live-reconcile-counts-task-TASK-114-prefix-TASK114_RECON_-p87830
- **Task**: TASK-114
- **Command**: `live reconcile-counts --task TASK-114 --prefix TASK114_RECON_`
- **Platform**: live
- **Safety**: live-write
- **Result**: fail (exit 1)
- **Duration**: 8550 ms
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

- Markdown: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T154337Z-live-reconcile-counts-task-TASK-114-prefix-TASK114_RECON_-p87830.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T154337Z-live-reconcile-counts-task-TASK-114-prefix-TASK114_RECON_-p87830.json`
- Log: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T154337Z-live-reconcile-counts-task-TASK-114-prefix-TASK114_RECON_-p87830.log`
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
  - supabase: products=active:19720/deleted:12/all:19732/pending:0/localOnly:0/userVisible:None; suppliers=active:81/deleted:0/all:81/pending:0/localOnly:0/userVisible:None; categories=active:50/deleted:0/all:50/pending:0/localOnly:0/userVisible:None; product_prices=active:41179/deleted:0/all:41189/pending:0/localOnly:0/userVisible:None; history_entries=active:35/deleted:16/all:51/pending:0/localOnly:0/userVisible:35
  - android: products=active:19720/deleted:0/all:19720/pending:0/localOnly:0/userVisible:None; suppliers=active:81/deleted:0/all:81/pending:0/localOnly:0/userVisible:None; categories=active:50/deleted:0/all:50/pending:0/localOnly:0/userVisible:None; product_prices=active:41179/deleted:0/all:41179/pending:0/localOnly:0/userVisible:None; history_entries=active:36/deleted:7/all:43/pending:0/localOnly:0/userVisible:35
  - ios: products=active:19700/deleted:7/all:19707/pending:0/localOnly:0/userVisible:None; suppliers=active:61/deleted:0/all:61/pending:0/localOnly:0/userVisible:None; categories=active:30/deleted:0/all:30/pending:0/localOnly:0/userVisible:None; product_prices=active:41125/deleted:0/all:41125/pending:0/localOnly:0/userVisible:None; history_entries=active:13/deleted:14/all:27/pending:0/localOnly:0/userVisible:13
- drift:
  - categories.active: {'android': 50, 'ios': 30, 'supabase': 50}
  - history_entries.userVisible: {'android': 35, 'ios': 13, 'supabase': 35}
  - product_prices.active: {'android': 41179, 'ios': 41125, 'supabase': 41179}
  - products.active: {'android': 19720, 'ios': 19700, 'supabase': 19720}
  - suppliers.active: {'android': 81, 'ios': 61, 'supabase': 81}
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=1 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None