# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260620T230505Z-live-reconcile-counts-task-TASK-136-prefix-TASK136_RECON_AFTER_CLEANUP_-profile-linked-p7132
- **Task**: TASK-136
- **Command**: `live reconcile-counts --task TASK-136 --prefix TASK136_RECON_AFTER_CLEANUP_ --profile linked`
- **Platform**: live
- **Safety**: live-write
- **Result**: FAIL (exit 1)
- **Duration**: 6521 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: 3b21bb76
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

Live reconcile-counts FAIL for TASK136_RECON_AFTER_CLEANUP_: drift remains between Android, iOS and Supabase.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-136/agent-runs/20260620T230505Z-live-reconcile-counts-task-TASK-136-prefix-TASK136_RECON_AFTER_CLEANUP_-profile-linked-p7132.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-136/agent-runs/20260620T230505Z-live-reconcile-counts-task-TASK-136-prefix-TASK136_RECON_AFTER_CLEANUP_-profile-linked-p7132.json`
- Log: `docs/TASKS/EVIDENCE/TASK-136/agent-runs/20260620T230505Z-live-reconcile-counts-task-TASK-136-prefix-TASK136_RECON_AFTER_CLEANUP_-profile-linked-p7132.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Inspect drift table in report, repair sync/apply/prune, then rerun.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-136
- source: live.reconcile-counts
- status: FAIL
- products: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- suppliers: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- categories: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- product_prices: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- history_entries: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- source counts:
  - supabase: products=active:19831/deleted:45/all:19876/pending:0/localOnly:0/userVisible:None; suppliers=active:71/deleted:24/all:95/pending:0/localOnly:0/userVisible:None; categories=active:40/deleted:24/all:64/pending:0/localOnly:0/userVisible:None; product_prices=active:41137/deleted:0/all:41218/pending:0/localOnly:0/userVisible:None; history_entries=active:46/deleted:81/all:127/pending:0/localOnly:0/userVisible:42
  - android: products=active:19710/deleted:0/all:19710/pending:0/localOnly:0/userVisible:None; suppliers=active:70/deleted:0/all:70/pending:0/localOnly:0/userVisible:None; categories=active:39/deleted:0/all:39/pending:0/localOnly:0/userVisible:None; product_prices=active:41137/deleted:0/all:41137/pending:0/localOnly:0/userVisible:None; history_entries=active:45/deleted:0/all:45/pending:0/localOnly:0/userVisible:41
  - ios: products=active:19754/deleted:8/all:19762/pending:0/localOnly:0/userVisible:None; suppliers=active:90/deleted:0/all:90/pending:0/localOnly:0/userVisible:None; categories=active:59/deleted:0/all:59/pending:0/localOnly:0/userVisible:None; product_prices=active:41274/deleted:16/all:41290/pending:0/localOnly:0/userVisible:None; history_entries=active:70/deleted:61/all:131/pending:0/localOnly:0/userVisible:66
- drift:
  - categories.active: {'android': 39, 'ios': 59, 'supabase': 40}
  - history_entries.userVisible: {'android': 41, 'ios': 66, 'supabase': 42}
  - product_prices.active: {'android': 41137, 'ios': 41274, 'supabase': 41137}
  - products.active: {'android': 19710, 'ios': 19754, 'supabase': 19831}
  - suppliers.active: {'android': 70, 'ios': 90, 'supabase': 71}
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None