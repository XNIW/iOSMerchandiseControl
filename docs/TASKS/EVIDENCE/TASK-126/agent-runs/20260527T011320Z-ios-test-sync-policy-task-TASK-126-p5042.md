# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260527T011320Z-ios-test-sync-policy-task-TASK-126-p5042
- **Task**: TASK-126
- **Command**: `ios test sync-policy --task TASK-126`
- **Platform**: ios
- **Safety**: safe-readonly
- **Result**: FAIL (exit 1)
- **Duration**: 5606 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: d7db6732
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

iOS test sync-policy FAIL or BLOCKED by live/auth gate. xcresult=/tmp/mc-agent-ios-test-sync-policy-20260527T011320Z.xcresult

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-126/agent-runs/20260527T011320Z-ios-test-sync-policy-task-TASK-126-p5042.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-126/agent-runs/20260527T011320Z-ios-test-sync-policy-task-TASK-126-p5042.json`
- Log: `docs/TASKS/EVIDENCE/TASK-126/agent-runs/20260527T011320Z-ios-test-sync-policy-task-TASK-126-p5042.log`
- xcresult: `/tmp/mc-agent-ios-test-sync-policy-20260527T011320Z.xcresult`
- screenshot: `n/a`

## Next Action

Inspect xcresult; if sessionMissing, perform app-auth login and retry.