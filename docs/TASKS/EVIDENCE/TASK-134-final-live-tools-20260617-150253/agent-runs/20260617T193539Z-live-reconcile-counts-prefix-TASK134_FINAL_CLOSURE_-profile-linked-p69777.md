# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260617T193539Z-live-reconcile-counts-prefix-TASK134_FINAL_CLOSURE_-profile-linked-p69777
- **Task**: TASK-134
- **Command**: `live reconcile-counts --prefix TASK134_FINAL_CLOSURE_ --profile linked`
- **Platform**: live
- **Safety**: live-write
- **Result**: FAIL (exit 1)
- **Duration**: 8404 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: 98a01d19
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

Live reconcile-counts FAIL for TASK134_FINAL_CLOSURE_: drift remains between Android, iOS and Supabase.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-134-final-live-tools-20260617-150253/agent-runs/20260617T193539Z-live-reconcile-counts-prefix-TASK134_FINAL_CLOSURE_-profile-linked-p69777.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-134-final-live-tools-20260617-150253/agent-runs/20260617T193539Z-live-reconcile-counts-prefix-TASK134_FINAL_CLOSURE_-profile-linked-p69777.json`
- Log: `docs/TASKS/EVIDENCE/TASK-134-final-live-tools-20260617-150253/agent-runs/20260617T193539Z-live-reconcile-counts-prefix-TASK134_FINAL_CLOSURE_-profile-linked-p69777.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Inspect drift table in report, repair sync/apply/prune, then rerun.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-134
- source: live.reconcile-counts
- status: FAIL
- products: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- suppliers: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- categories: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- product_prices: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- history_entries: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- source counts:
  - supabase: products=active:19695/deleted:1/all:19696/pending:0/localOnly:0/userVisible:None; suppliers=active:59/deleted:0/all:59/pending:0/localOnly:0/userVisible:None; categories=active:28/deleted:0/all:28/pending:0/localOnly:0/userVisible:None; product_prices=active:41109/deleted:0/all:41109/pending:0/localOnly:0/userVisible:None; history_entries=active:35/deleted:52/all:87/pending:0/localOnly:0/userVisible:35
  - android: products=active:19762/deleted:0/all:19762/pending:0/localOnly:0/userVisible:None; suppliers=active:126/deleted:0/all:126/pending:0/localOnly:0/userVisible:None; categories=active:95/deleted:0/all:95/pending:0/localOnly:0/userVisible:None; product_prices=active:41250/deleted:0/all:41250/pending:0/localOnly:0/userVisible:None; history_entries=active:83/deleted:11/all:94/pending:0/localOnly:0/userVisible:82
  - ios: products=active:19702/deleted:14/all:19716/pending:0/localOnly:0/userVisible:None; suppliers=active:65/deleted:0/all:65/pending:0/localOnly:0/userVisible:None; categories=active:34/deleted:0/all:34/pending:0/localOnly:0/userVisible:None; product_prices=active:41121/deleted:0/all:41121/pending:0/localOnly:0/userVisible:None; history_entries=active:67/deleted:21/all:88/pending:0/localOnly:0/userVisible:67
- drift:
  - categories.active: {'android': 95, 'ios': 34, 'supabase': 28}
  - history_entries.userVisible: {'android': 82, 'ios': 67, 'supabase': 35}
  - product_prices.active: {'android': 41250, 'ios': 41121, 'supabase': 41109}
  - products.active: {'android': 19762, 'ios': 19702, 'supabase': 19695}
  - suppliers.active: {'android': 126, 'ios': 65, 'supabase': 59}
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=1 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None