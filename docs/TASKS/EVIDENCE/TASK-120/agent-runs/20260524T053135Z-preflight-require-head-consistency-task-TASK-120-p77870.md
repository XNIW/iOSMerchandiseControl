# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260524T053135Z-preflight-require-head-consistency-task-TASK-120-p77870
- **Task**: TASK-120
- **Command**: `preflight --require-head-consistency --task TASK-120`
- **Platform**: general
- **Safety**: safe-readonly
- **Result**: PASS (exit 0)
- **Duration**: 1917 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: b6953a5
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

IOS repo OK: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
ANDROID repo OK: <HOME_REDACTED>/AndroidStudioProjects/MerchandiseControlSplitView
SUPABASE repo OK: <HOME_REDACTED>/Desktop/MerchandiseControlSupabase
xcodebuild OK
xcrun OK
java OK
docker OK
supabase OK
adb OK
gradlew OK
evidence dir OK: docs/TASKS/EVIDENCE/TASK-120

HEAD consistency: HEAD consistency PASS for TASK-120: local HEAD, origin/main, remote main and GitHub rendered main agree.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-120/agent-runs/20260524T053135Z-preflight-require-head-consistency-task-TASK-120-p77870.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-120/agent-runs/20260524T053135Z-preflight-require-head-consistency-task-TASK-120-p77870.json`
- Log: `docs/TASKS/EVIDENCE/TASK-120/agent-runs/20260524T053135Z-preflight-require-head-consistency-task-TASK-120-p77870.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Run build/test commands.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-120
- source: git.head-consistency
- status: PASS
- products: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- suppliers: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- categories: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- product_prices: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- history_entries: active=None deleted=None all=None dirty=None pending=None localOnly=None userVisible=None
- prune: wouldPrune=0 didPrune=0 skippedDirty=0 skippedLocalOnly=0 skippedPendingTombstone=0 skippedScopedSnapshot=0 isCompleteSnapshot=None