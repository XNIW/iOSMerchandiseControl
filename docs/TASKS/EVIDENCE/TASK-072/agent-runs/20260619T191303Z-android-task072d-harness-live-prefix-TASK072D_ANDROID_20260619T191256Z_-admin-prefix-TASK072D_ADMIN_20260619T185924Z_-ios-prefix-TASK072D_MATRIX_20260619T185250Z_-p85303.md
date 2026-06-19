# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260619T191303Z-android-task072d-harness-live-prefix-TASK072D_ANDROID_20260619T191256Z_-admin-prefix-TASK072D_ADMIN_20260619T185924Z_-ios-prefix-TASK072D_MATRIX_20260619T185250Z_-p85303
- **Task**: TASK-072
- **Command**: `android task072d-harness --live --prefix TASK072D_ANDROID_20260619T191256Z_ --admin-prefix TASK072D_ADMIN_20260619T185924Z_ --ios-prefix TASK072D_MATRIX_20260619T185250Z_`
- **Platform**: android
- **Safety**: live-write
- **Result**: FAIL (exit 1)
- **Duration**: 186721 ms
- **Repo**: <HOME_REDACTED>/AndroidStudioProjects/MerchandiseControlSplitView
- **Branch**: main
- **Git SHA**: 7f408d2
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

Android instrumentation FAIL for com.example.merchandisecontrolsplitview.Task072DAndroidReceiverHarnessTest#androidReceiverCatalogHistoryMatrixDbSnapshotAndOutbox; adb exit=0 (state=device boot_completed=1).

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-072/agent-runs/20260619T191303Z-android-task072d-harness-live-prefix-TASK072D_ANDROID_20260619T191256Z_-admin-prefix-TASK072D_ADMIN_20260619T185924Z_-ios-prefix-TASK072D_MATRIX_20260619T185250Z_-p85303.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-072/agent-runs/20260619T191303Z-android-task072d-harness-live-prefix-TASK072D_ANDROID_20260619T191256Z_-admin-prefix-TASK072D_ADMIN_20260619T185924Z_-ios-prefix-TASK072D_MATRIX_20260619T185250Z_-p85303.json`
- Log: `docs/TASKS/EVIDENCE/TASK-072/agent-runs/20260619T191303Z-android-task072d-harness-live-prefix-TASK072D_ANDROID_20260619T191256Z_-admin-prefix-TASK072D_ADMIN_20260619T185924Z_-ios-prefix-TASK072D_MATRIX_20260619T185250Z_-p85303.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Inspect instrumentation output/logcat and rerun after fixing the reported failure.

## Reconciliation Detail

- android.selectedTargetType: emulator
- android.availableAdbDevices: 1
- android.adbState: device
- android.bootCompleted: 1
- android.appInstalled: True
- android.foregroundPackage: None
- android.screenOn: True
- android.locked: False