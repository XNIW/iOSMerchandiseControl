# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260529T030217Z-physical-account-switch-matrix-task-TASK-131-prefix-TASK131_REVIEW_ACCOUNT_-p77663
- **Task**: TASK-131
- **Command**: `physical account-switch-matrix --task TASK-131 --prefix TASK131_REVIEW_ACCOUNT_`
- **Platform**: android
- **Safety**: safe-readonly
- **Result**: PASS (exit 0)
- **Duration**: 71467 ms
- **Repo**: <HOME_REDACTED>/AndroidStudioProjects/MerchandiseControlSplitView
- **Branch**: main
- **Git SHA**: 4c08ff8
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

TASK-131 account-switch-matrix PASS: non-B same-account/owner-mismatch/legacy/export policy subcases ran; true A-to-B cases remain BLOCKED_EXTERNAL_SECOND_ACCOUNT when no second account is configured.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-131/agent-runs/20260529T030217Z-physical-account-switch-matrix-task-TASK-131-prefix-TASK131_REVIEW_ACCOUNT_-p77663.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-131/agent-runs/20260529T030217Z-physical-account-switch-matrix-task-TASK-131-prefix-TASK131_REVIEW_ACCOUNT_-p77663.json`
- Log: `docs/TASKS/EVIDENCE/TASK-131/agent-runs/20260529T030217Z-physical-account-switch-matrix-task-TASK-131-prefix-TASK131_REVIEW_ACCOUNT_-p77663.log`
- xcresult: `/tmp/mc-agent-ios-test-sync-policy-20260529T030217Z.xcresult`
- screenshot: `n/a`

## Next Action

Provision a second synthetic account only for C126-14/15/16/17/40, then rerun account-switch-matrix.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-131
- source: task131.physical.account-switch-matrix
- status: PASS
- products: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- suppliers: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- categories: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- product_prices: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- history_entries: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None