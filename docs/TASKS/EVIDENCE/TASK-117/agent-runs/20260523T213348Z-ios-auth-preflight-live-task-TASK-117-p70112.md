# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260523T213348Z-ios-auth-preflight-live-task-TASK-117-p70112
- **Task**: TASK-117
- **Command**: `ios auth-preflight --live --task TASK-117`
- **Platform**: ios
- **Safety**: live-write
- **Result**: blocked (exit 2)
- **Duration**: 53979 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: e14b433
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

iOS auth-preflight BLOCKED/FAIL. xcresult=/tmp/mc-agent-ios-auth-preflight-20260523T213348Z.xcresult

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-117/agent-runs/20260523T213348Z-ios-auth-preflight-live-task-TASK-117-p70112.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-117/agent-runs/20260523T213348Z-ios-auth-preflight-live-task-TASK-117-p70112.json`
- Log: `docs/TASKS/EVIDENCE/TASK-117/agent-runs/20260523T213348Z-ios-auth-preflight-live-task-TASK-117-p70112.log`
- xcresult: `/tmp/mc-agent-ios-auth-preflight-20260523T213348Z.xcresult`
- screenshot: `n/a`

## Next Action

Open app, complete login, verify session restore, then retry.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: None
- source: ios.auth-preflight.runtime-fallback
- status: BLOCKED
- products: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- suppliers: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- categories: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- product_prices: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- history_entries: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None