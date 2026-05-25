# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260525T054843Z-live-task123-single-propagation-task-TASK-123-prefix-TASK123_SINGLE_-p37688
- **Task**: TASK-123
- **Command**: `live task123-single-propagation --task TASK-123 --prefix TASK123_SINGLE_`
- **Platform**: ios
- **Safety**: live-write
- **Result**: FAIL (exit 1)
- **Duration**: 182887 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: cd31c09e
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

Live sync wait FAIL: android did not receive task123_ios_to_android_single within 15s.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-123/agent-runs/20260525T054843Z-live-task123-single-propagation-task-TASK-123-prefix-TASK123_SINGLE_-p37688.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-123/agent-runs/20260525T054843Z-live-task123-single-propagation-task-TASK-123-prefix-TASK123_SINGLE_-p37688.json`
- Log: `docs/TASKS/EVIDENCE/TASK-123/agent-runs/20260525T054843Z-live-task123-single-propagation-task-TASK-123-prefix-TASK123_SINGLE_-p37688.log`
- xcresult: `/tmp/mc-agent-ios-task114-test123IOSSingleCatalogCreatePropagation-20260525T054843Z.xcresult`
- screenshot: `n/a`

## Next Action

Inspect foreground app auto-sync/realtime logs and rerun after fixing push/pull trigger.

## Reconciliation Detail

- android.selectedTargetType: emulator
- android.availableAdbDevices: 1
- android.adbState: device
- android.bootCompleted: 1
- android.appInstalled: True
- android.foregroundPackage: None
- android.screenOn: True
- android.locked: False