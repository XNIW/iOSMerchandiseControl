# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260527T224008Z-android-test-quarantine-report-task-TASK-129-p81677
- **Task**: TASK-129
- **Command**: `android test quarantine-report --task TASK-129`
- **Platform**: android
- **Safety**: safe-readonly
- **Result**: FAIL (exit 1)
- **Duration**: 457 ms
- **Repo**: <HOME_REDACTED>/AndroidStudioProjects/MerchandiseControlSplitView
- **Branch**: main
- **Git SHA**: cdb22534
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

Android quarantine report FAIL: broad failures include REAL_REGRESSION, UNKNOWN_NEEDS_FIX or MISCONFIGURED classifications. classifications={'BYTEBUDDY_ATTACH_ENV': 143, 'REAL_REGRESSION': 8}.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-129/agent-runs/20260527T224008Z-android-test-quarantine-report-task-TASK-129-p81677.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-129/agent-runs/20260527T224008Z-android-test-quarantine-report-task-TASK-129-p81677.json`
- Log: `docs/TASKS/EVIDENCE/TASK-129/agent-runs/20260527T224008Z-android-test-quarantine-report-task-TASK-129-p81677.log`
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
- totals: tests=494 failures=151 errors=0 skipped=2 failedOrErroredCases=151
- classificationCounts: {'BYTEBUDDY_ATTACH_ENV': 143, 'REAL_REGRESSION': 8}
- quarantineAcceptableCandidate: False
- stableCiAlternative:
  - `MC_TASK_ID=TASK-129 ./tools/agent/mc-agent.sh android build debug --task TASK-129`
  - `MC_TASK_ID=TASK-129 ./tools/agent/mc-agent.sh android test sync --task TASK-129`
- failedTests sample:
  - REAL_REGRESSION: com.example.merchandisecontrolsplitview.data.DefaultInventoryRepositoryTest#pull product price links bridge when local business key already exists
  - REAL_REGRESSION: com.example.merchandisecontrolsplitview.data.DefaultInventoryRepositoryTest#032 breakdown surfaces local catalog rows missing remote refs and sync reconciles them
  - REAL_REGRESSION: com.example.merchandisecontrolsplitview.data.DefaultInventoryRepositoryTest#syncCatalogWithRemote reports deferred prices when product has no remote ref
  - REAL_REGRESSION: com.example.merchandisecontrolsplitview.data.DefaultInventoryRepositoryTest#041 realign skips non-matching rows without creating bridges
  - REAL_REGRESSION: com.example.merchandisecontrolsplitview.data.DefaultInventoryRepositoryTest#019 inbound tombstone without bridge does not delete local suppliers
  - REAL_REGRESSION: com.example.merchandisecontrolsplitview.data.DefaultInventoryRepositoryTest#product price full pull streams remote prices by page
  - REAL_REGRESSION: com.example.merchandisecontrolsplitview.data.DefaultInventoryRepositoryTest#042 incremental catalog push evaluates only dirty product candidates
  - REAL_REGRESSION: com.example.merchandisecontrolsplitview.data.DefaultInventoryRepositoryTest#syncCatalogWithRemote pushes product prices when product_remote_refs exists
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