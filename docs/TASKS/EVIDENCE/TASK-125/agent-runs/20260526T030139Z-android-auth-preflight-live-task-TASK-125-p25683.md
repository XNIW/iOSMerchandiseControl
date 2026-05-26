# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260526T030139Z-android-auth-preflight-live-task-TASK-125-p25683
- **Task**: TASK-125
- **Command**: `android auth-preflight --live --task TASK-125`
- **Platform**: android
- **Safety**: live-write
- **Result**: BLOCKED_EXTERNAL (exit 2)
- **Duration**: 1879 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: e4eb3a47
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

BLOCKED_DEVICE_LOCKED: Android target appears locked.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T030139Z-android-auth-preflight-live-task-TASK-125-p25683.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T030139Z-android-auth-preflight-live-task-TASK-125-p25683.json`
- Log: `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T030139Z-android-auth-preflight-live-task-TASK-125-p25683.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Unlock the selected Android target, then retry; or rerun with an explicit emulator serial.

## Reconciliation Detail

- android.selectedTargetType: physical
- android.availableAdbDevices: 2
- android.adbState: device
- android.bootCompleted: 1
- android.appInstalled: True
- android.foregroundPackage: None
- android.screenOn: False
- android.locked: True