# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260527T223738Z-android-test-quarantine-report-task-TASK-129-p79706
- **Task**: TASK-129
- **Command**: `android test quarantine-report --task TASK-129`
- **Platform**: android
- **Safety**: safe-readonly
- **Result**: FAIL (exit 1)
- **Duration**: 415 ms
- **Repo**: <HOME_REDACTED>/AndroidStudioProjects/MerchandiseControlSplitView
- **Branch**: main
- **Git SHA**: cdb22534
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

Android quarantine report FAIL: broad failures include REAL_REGRESSION, UNKNOWN_NEEDS_FIX or MISCONFIGURED classifications. classifications={'UNKNOWN_NEEDS_FIX': 1}.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-129/agent-runs/20260527T223738Z-android-test-quarantine-report-task-TASK-129-p79706.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-129/agent-runs/20260527T223738Z-android-test-quarantine-report-task-TASK-129-p79706.json`
- Log: `docs/TASKS/EVIDENCE/TASK-129/agent-runs/20260527T223738Z-android-test-quarantine-report-task-TASK-129-p79706.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Fix or narrow the real/unknown Android failures, then rerun android test broad.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-129
- source: android.test.quarantine-report
- status: FAIL_REAL_OR_UNKNOWN
- gradleTask: :app:testDebugUnitTest
- gradleExitCode: 1
- totals: tests=4 failures=0 errors=0 skipped=0 failedOrErroredCases=1
- classificationCounts: {'UNKNOWN_NEEDS_FIX': 1}
- quarantineAcceptableCandidate: False
- stableCiAlternative:
  - `MC_TASK_ID=TASK-129 ./tools/agent/mc-agent.sh android build debug --task TASK-129`
  - `MC_TASK_ID=TASK-129 ./tools/agent/mc-agent.sh android test sync --task TASK-129`
- failedTests sample:
  - UNKNOWN_NEEDS_FIX: gradle#:app:testDebugUnitTest