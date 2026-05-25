# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260525T015718Z-android-auth-preflight-live-task-TASK-123-p62901
- **Task**: TASK-123
- **Command**: `android auth-preflight --live --task TASK-123`
- **Platform**: android
- **Safety**: live-write
- **Result**: BLOCKED_EXTERNAL (exit 2)
- **Duration**: 253 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: 8116de9d
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

- Markdown: `docs/TASKS/EVIDENCE/TASK-123/agent-runs/20260525T015718Z-android-auth-preflight-live-task-TASK-123-p62901.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-123/agent-runs/20260525T015718Z-android-auth-preflight-live-task-TASK-123-p62901.json`
- Log: `docs/TASKS/EVIDENCE/TASK-123/agent-runs/20260525T015718Z-android-auth-preflight-live-task-TASK-123-p62901.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Set MC_ANDROID_DEVICE_SERIAL to the physical device or emulator serial, then rerun.

## Reconciliation Detail

- android.selectedTargetType: None
- android.availableAdbDevices: 1
- android.adbState: None
- android.bootCompleted: None
- android.appInstalled: False
- android.foregroundPackage: None
- android.screenOn: None
- android.locked: None