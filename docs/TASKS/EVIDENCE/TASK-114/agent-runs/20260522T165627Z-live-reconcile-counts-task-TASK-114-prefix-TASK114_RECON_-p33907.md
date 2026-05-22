# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260522T165627Z-live-reconcile-counts-task-TASK-114-prefix-TASK114_RECON_-p33907
- **Task**: TASK-114
- **Command**: `live reconcile-counts --task TASK-114 --prefix TASK114_RECON_`
- **Platform**: live
- **Safety**: live-write
- **Result**: blocked (exit 2)
- **Duration**: 6292 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: c1ee078
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

Live reconcile-counts BLOCKED for TASK114_RECON_: one or more local/live count sources unavailable.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T165627Z-live-reconcile-counts-task-TASK-114-prefix-TASK114_RECON_-p33907.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T165627Z-live-reconcile-counts-task-TASK-114-prefix-TASK114_RECON_-p33907.json`
- Log: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T165627Z-live-reconcile-counts-task-TASK-114-prefix-TASK114_RECON_-p33907.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Resolve device/auth/local store blockers and retry.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-114
- source: live.reconcile-counts
- status: BLOCKED
- products: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- suppliers: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- categories: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- product_prices: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- history_entries: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- source counts:
  - supabase: products=active:19732/deleted:18/all:19750/pending:0/localOnly:0/userVisible:None; suppliers=active:89/deleted:0/all:89/pending:0/localOnly:0/userVisible:None; categories=active:58/deleted:0/all:58/pending:0/localOnly:0/userVisible:None; product_prices=active:41217/deleted:0/all:41233/pending:0/localOnly:0/userVisible:None; history_entries=active:47/deleted:22/all:69/pending:0/localOnly:0/userVisible:47
  - android: products=active:None/deleted:None/all:None/pending:None/localOnly:None/userVisible:None; suppliers=active:None/deleted:None/all:None/pending:None/localOnly:None/userVisible:None; categories=active:None/deleted:None/all:None/pending:None/localOnly:None/userVisible:None; product_prices=active:None/deleted:None/all:None/pending:None/localOnly:None/userVisible:None; history_entries=active:None/deleted:None/all:None/pending:None/localOnly:None/userVisible:None
  - ios: products=active:19736/deleted:7/all:19743/pending:0/localOnly:0/userVisible:None; suppliers=active:91/deleted:0/all:91/pending:0/localOnly:0/userVisible:None; categories=active:60/deleted:0/all:60/pending:0/localOnly:0/userVisible:None; product_prices=active:41231/deleted:0/all:41231/pending:0/localOnly:0/userVisible:None; history_entries=active:49/deleted:14/all:63/pending:0/localOnly:0/userVisible:49
- drift:
  - categories.active: {'android': None, 'ios': 60, 'supabase': 58}
  - history_entries.userVisible: {'android': None, 'ios': 49, 'supabase': 47}
  - product_prices.active: {'android': None, 'ios': 41231, 'supabase': 41217}
  - products.active: {'android': None, 'ios': 19736, 'supabase': 19732}
  - suppliers.active: {'android': None, 'ios': 91, 'supabase': 89}
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None