# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260525T052759Z-live-task123-single-propagation-task-TASK-123-prefix-TASK123_SINGLE_-p3616
- **Task**: TASK-123
- **Command**: `live task123-single-propagation --task TASK-123 --prefix TASK123_SINGLE_`
- **Platform**: ios
- **Safety**: live-write
- **Result**: FAIL (exit 1)
- **Duration**: 153227 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: cd31c09e
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

iOS TASK-114 matrix step test123IOSSingleCatalogCreatePropagation FAIL/BLOCKED for prefix TASK123_SINGLE_SINGLE_20260525T052759Z_IOS_1_. xcresult=/tmp/mc-agent-ios-task114-test123IOSSingleCatalogCreatePropagation-20260525T052759Z.xcresult

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-123/agent-runs/20260525T052759Z-live-task123-single-propagation-task-TASK-123-prefix-TASK123_SINGLE_-p3616.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-123/agent-runs/20260525T052759Z-live-task123-single-propagation-task-TASK-123-prefix-TASK123_SINGLE_-p3616.json`
- Log: `docs/TASKS/EVIDENCE/TASK-123/agent-runs/20260525T052759Z-live-task123-single-propagation-task-TASK-123-prefix-TASK123_SINGLE_-p3616.log`
- xcresult: `/tmp/mc-agent-ios-task114-test123IOSSingleCatalogCreatePropagation-20260525T052759Z.xcresult`
- screenshot: `n/a`

## Next Action

Inspect xcresult/log; verify app-auth session, RLS and scoped remote rows.

## Reconciliation Detail

- android.selectedTargetType: emulator
- android.availableAdbDevices: 1
- android.adbState: device
- android.bootCompleted: 1
- android.appInstalled: True
- android.foregroundPackage: None
- android.screenOn: True
- android.locked: False