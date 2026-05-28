# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260528T002154Z-android-test-broad-task-TASK-130-p37277
- **Task**: TASK-130
- **Command**: `android test broad --task TASK-130`
- **Platform**: android
- **Safety**: safe-readonly
- **Result**: FAIL (exit 1)
- **Duration**: 45185 ms
- **Repo**: <HOME_REDACTED>/AndroidStudioProjects/MerchandiseControlSplitView
- **Branch**: main
- **Git SHA**: cdb22534
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

Android broad unit suite non-green via :app:testDebugUnitTest: tests=498, failures=150, errors=0, skipped=2, classifications={'BYTEBUDDY_ATTACH_ENV': 143, 'REAL_REGRESSION': 7}.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-130/agent-runs/20260528T002154Z-android-test-broad-task-TASK-130-p37277.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-130/agent-runs/20260528T002154Z-android-test-broad-task-TASK-130-p37277.json`
- Log: `docs/TASKS/EVIDENCE/TASK-130/agent-runs/20260528T002154Z-android-test-broad-task-TASK-130-p37277.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Run android test quarantine-report --task TASK-130; fix REAL_REGRESSION/UNKNOWN_NEEDS_FIX before REVIEW.

## Reconciliation Detail

- schemaVersion: 1.1
- taskId: TASK-130
- source: android.test.broad
- status: FAIL_REAL_OR_UNKNOWN
- gradleTask: :app:testDebugUnitTest
- gradleExitCode: 1
- totals: tests=498 failures=150 errors=0 skipped=2 failedOrErroredCases=150
- classificationCounts: {'BYTEBUDDY_ATTACH_ENV': 143, 'REAL_REGRESSION': 7}
- quarantineAcceptableCandidate: False
- stableCiAlternative:
  - `MC_TASK_ID=TASK-129 ./tools/agent/mc-agent.sh android build debug --task TASK-129`
  - `MC_TASK_ID=TASK-129 ./tools/agent/mc-agent.sh android test sync --task TASK-129`
- failedTests sample:
  - REAL_REGRESSION: com.example.merchandisecontrolsplitview.data.DefaultInventoryRepositoryTest#recordPriceIfChanged ignores unchanged value and getLastPrice returns latest
  - REAL_REGRESSION: com.example.merchandisecontrolsplitview.data.DefaultInventoryRepositoryTest#getCurrentPricesForBarcodes returns current prices for requested barcodes
  - REAL_REGRESSION: com.example.merchandisecontrolsplitview.data.DefaultInventoryRepositoryTest#043 bootstrap pull applies remote catalog and prices without outbound upserts
  - BYTEBUDDY_ATTACH_ENV: com.example.merchandisecontrolsplitview.data.HistorySessionPushCoordinatorTest#040 runPushCycle uses precise pending uid set
  - BYTEBUDDY_ATTACH_ENV: com.example.merchandisecontrolsplitview.data.HistorySessionPushCoordinatorTest#110 login fresh tick bootstraps then runs full reconciliation push
  - BYTEBUDDY_ATTACH_ENV: com.example.merchandisecontrolsplitview.data.HistorySessionPushCoordinatorTest#040 failed push cycle logs classification and pending uid sample
  - BYTEBUDDY_ATTACH_ENV: com.example.merchandisecontrolsplitview.data.HistorySessionPushCoordinatorTest#040 signed out push cycle skips without querying repository
  - BYTEBUDDY_ATTACH_ENV: com.example.merchandisecontrolsplitview.data.SyncErrorClassifierTest#ktor response exception exposes reliable status
  - REAL_REGRESSION: com.example.merchandisecontrolsplitview.util.DatabaseExportWriterTest#writeDatabaseExport writes products sheet current prices from price summary
  - BYTEBUDDY_ATTACH_ENV: com.example.merchandisecontrolsplitview.util.ExcelUtilsTest#readAndAnalyzeExcel null input stream throws localized empty file error
  - REAL_REGRESSION: com.example.merchandisecontrolsplitview.util.FullDbExportImportRoundTripTest#RT-PART keeps real price history without synthetic rows when represented
  - REAL_REGRESSION: com.example.merchandisecontrolsplitview.util.FullDbExportImportRoundTripTest#RT-LOCALE localized Products headers stay importable
  - REAL_REGRESSION: com.example.merchandisecontrolsplitview.util.FullDbExportImportRoundTripTest#RT-FULL round trip keeps products suppliers categories and non synthetic price history
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