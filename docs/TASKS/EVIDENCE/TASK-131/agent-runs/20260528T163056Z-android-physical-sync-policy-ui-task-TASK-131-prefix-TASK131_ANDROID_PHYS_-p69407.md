# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260528T163056Z-android-physical-sync-policy-ui-task-TASK-131-prefix-TASK131_ANDROID_PHYS_-p69407
- **Task**: TASK-131
- **Command**: `android physical sync-policy-ui --task TASK-131 --prefix TASK131_ANDROID_PHYS_`
- **Platform**: android
- **Safety**: live-write
- **Result**: BLOCKED_EXTERNAL (exit 2)
- **Duration**: 600 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: 96b900ef
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

BLOCKED_ANDROID_TARGET_UNSPECIFIED: live Android commands require MC_ANDROID_DEVICE_SERIAL.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-131/agent-runs/20260528T163056Z-android-physical-sync-policy-ui-task-TASK-131-prefix-TASK131_ANDROID_PHYS_-p69407.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-131/agent-runs/20260528T163056Z-android-physical-sync-policy-ui-task-TASK-131-prefix-TASK131_ANDROID_PHYS_-p69407.json`
- Log: `docs/TASKS/EVIDENCE/TASK-131/agent-runs/20260528T163056Z-android-physical-sync-policy-ui-task-TASK-131-prefix-TASK131_ANDROID_PHYS_-p69407.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Set MC_ANDROID_DEVICE_SERIAL to the physical device or emulator serial, then rerun.

## Reconciliation Detail

- android.selectedTargetType: None
- android.availableAdbDevices: 2
- android.adbState: None
- android.bootCompleted: None
- android.appInstalled: False
- android.foregroundPackage: None
- android.screenOn: None
- android.locked: None