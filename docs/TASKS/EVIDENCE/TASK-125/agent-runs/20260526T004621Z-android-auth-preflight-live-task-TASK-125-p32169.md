# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260526T004621Z-android-auth-preflight-live-task-TASK-125-p32169
- **Task**: TASK-125
- **Command**: `android auth-preflight --live --task TASK-125`
- **Platform**: android
- **Safety**: live-write
- **Result**: BLOCKED_EXTERNAL (exit 2)
- **Duration**: 247 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: e4eb3a47
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

- Markdown: `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T004621Z-android-auth-preflight-live-task-TASK-125-p32169.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T004621Z-android-auth-preflight-live-task-TASK-125-p32169.json`
- Log: `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T004621Z-android-auth-preflight-live-task-TASK-125-p32169.log`
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