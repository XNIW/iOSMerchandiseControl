# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260521T222132Z-ios-test-sync-task-TASK-114-p1675
- **Task**: TASK-114
- **Command**: `ios test sync --task TASK-114`
- **Platform**: ios
- **Safety**: safe-readonly
- **Result**: fail (exit 1)
- **Duration**: 10447 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: 4b74773
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

iOS test sync FAIL or BLOCKED by live/auth gate. xcresult=/tmp/mc-agent-ios-test-sync-20260521T222132Z.xcresult

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260521T222132Z-ios-test-sync-task-TASK-114-p1675.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260521T222132Z-ios-test-sync-task-TASK-114-p1675.json`
- Log: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260521T222132Z-ios-test-sync-task-TASK-114-p1675.log`
- xcresult: `/tmp/mc-agent-ios-test-sync-20260521T222132Z.xcresult`
- screenshot: `n/a`

## Next Action

Inspect xcresult; if sessionMissing, perform app-auth login and retry.