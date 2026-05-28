# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260528T004330Z-android-test-broad-task-TASK-130-p82453
- **Task**: TASK-130
- **Command**: `android test broad --task TASK-130`
- **Platform**: android
- **Safety**: safe-readonly
- **Result**: FAIL (exit 1)
- **Duration**: 47254 ms
- **Repo**: <HOME_REDACTED>/AndroidStudioProjects/MerchandiseControlSplitView
- **Branch**: main
- **Git SHA**: cdb22534
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

Android broad unit suite non-green via :app:testDebugUnitTest: tests=498, failures=143, errors=0, skipped=2, classifications={'BYTEBUDDY_ATTACH_ENV': 143}.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-130/agent-runs/20260528T004330Z-android-test-broad-task-TASK-130-p82453.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-130/agent-runs/20260528T004330Z-android-test-broad-task-TASK-130-p82453.json`
- Log: `docs/TASKS/EVIDENCE/TASK-130/agent-runs/20260528T004330Z-android-test-broad-task-TASK-130-p82453.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Run android test quarantine-report --task TASK-130; fix REAL_REGRESSION/UNKNOWN_NEEDS_FIX before REVIEW.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-130
- source: android.test.broad
- status: PASS_WITH_NOTES_CANDIDATE
- gradleTask: :app:testDebugUnitTest
- gradleExitCode: 1
- totals: tests=498 failures=143 errors=0 skipped=2 failedOrErroredCases=143
- classificationCounts: {'BYTEBUDDY_ATTACH_ENV': 143}
- quarantineAcceptableCandidate: True
- stableCiAlternative:
  - `MC_TASK_ID=TASK-129 ./tools/agent/mc-agent.sh android build debug --task TASK-129`
  - `MC_TASK_ID=TASK-129 ./tools/agent/mc-agent.sh android test sync --task TASK-129`
- failedTests sample:
  - BYTEBUDDY_ATTACH_ENV: com.example.merchandisecontrolsplitview.data.HistorySessionPushCoordinatorTest#040 runPushCycle uses precise pending uid set
  - BYTEBUDDY_ATTACH_ENV: com.example.merchandisecontrolsplitview.data.HistorySessionPushCoordinatorTest#110 login fresh tick bootstraps then runs full reconciliation push
  - BYTEBUDDY_ATTACH_ENV: com.example.merchandisecontrolsplitview.data.HistorySessionPushCoordinatorTest#040 failed push cycle logs classification and pending uid sample
  - BYTEBUDDY_ATTACH_ENV: com.example.merchandisecontrolsplitview.data.HistorySessionPushCoordinatorTest#040 signed out push cycle skips without querying repository
  - BYTEBUDDY_ATTACH_ENV: com.example.merchandisecontrolsplitview.data.SyncErrorClassifierTest#ktor response exception exposes reliable status
  - BYTEBUDDY_ATTACH_ENV: com.example.merchandisecontrolsplitview.util.ExcelUtilsTest#readAndAnalyzeExcel null input stream throws localized empty file error
  - BYTEBUDDY_ATTACH_ENV: com.example.merchandisecontrolsplitview.util.ImportAnalyzerTest#analyze does not add supplier when it is already cached from repository
  - BYTEBUDDY_ATTACH_ENV: com.example.merchandisecontrolsplitview.util.ImportAnalyzerTest#analyzeStreamingDeferredRelations exposes pending relation maps for missing names
  - BYTEBUDDY_ATTACH_ENV: com.example.merchandisecontrolsplitview.util.ImportAnalyzerTest#analyzeStreaming processes a basic new product chunk
  - BYTEBUDDY_ATTACH_ENV: com.example.merchandisecontrolsplitview.util.ImportAnalyzerTest#analyze does not create update when price difference stays within tolerance
  - BYTEBUDDY_ATTACH_ENV: com.example.merchandisecontrolsplitview.util.ImportAnalyzerTest#analyze preserves existing category id when equivalent category name accompanies another change
  - BYTEBUDDY_ATTACH_ENV: com.example.merchandisecontrolsplitview.util.ImportAnalyzerTest#analyze truncates product names beyond the maximum length
  - BYTEBUDDY_ATTACH_ENV: com.example.merchandisecontrolsplitview.util.ImportAnalyzerTest#analyze adds update when price difference exceeds tolerance
  - BYTEBUDDY_ATTACH_ENV: com.example.merchandisecontrolsplitview.util.ImportAnalyzerTest#analyze keeps missing supplier and category deferred without preview writes
  - BYTEBUDDY_ATTACH_ENV: com.example.merchandisecontrolsplitview.util.ImportAnalyzerTest#analyze caps duplicate warning samples while preserving total occurrences and winner row
  - BYTEBUDDY_ATTACH_ENV: com.example.merchandisecontrolsplitview.util.ImportAnalyzerTest#analyze treats trim case and blank differences as semantic no-op
  - BYTEBUDDY_ATTACH_ENV: com.example.merchandisecontrolsplitview.util.ImportAnalyzerTest#analyze treats item number comparison as case insensitive
  - BYTEBUDDY_ATTACH_ENV: com.example.merchandisecontrolsplitview.util.ImportAnalyzerTest#analyze treats product name comparison as case insensitive
  - BYTEBUDDY_ATTACH_ENV: com.example.merchandisecontrolsplitview.util.ImportAnalyzerTest#analyze skips supplier changed field when supplier names match ignoring case
  - BYTEBUDDY_ATTACH_ENV: com.example.merchandisecontrolsplitview.util.ImportAnalyzerTest#analyzeStreaming uses last duplicate row number for post merge validation errors
  - BYTEBUDDY_ATTACH_ENV: com.example.merchandisecontrolsplitview.util.ImportAnalyzerTest#analyzeStreaming unexpected row error hides technical exception text
  - BYTEBUDDY_ATTACH_ENV: com.example.merchandisecontrolsplitview.util.ImportAnalyzerTest#analyze merges duplicate rows with last row wins and aggregated quantity
  - BYTEBUDDY_ATTACH_ENV: com.example.merchandisecontrolsplitview.util.ImportAnalyzerTest#analyze maps prev purchase and retail aliases into old prices
  - BYTEBUDDY_ATTACH_ENV: com.example.merchandisecontrolsplitview.util.ImportAnalyzerTest#analyze does not add category when find lookup resolves it
  - BYTEBUDDY_ATTACH_ENV: com.example.merchandisecontrolsplitview.util.ImportAnalyzerTest#analyzeStreaming merges cross chunk duplicates with last row wins and aggregated quantity