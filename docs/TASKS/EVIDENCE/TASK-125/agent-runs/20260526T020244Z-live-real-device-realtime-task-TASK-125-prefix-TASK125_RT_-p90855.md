# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260526T020244Z-live-real-device-realtime-task-TASK-125-prefix-TASK125_RT_-p90855
- **Task**: TASK-125
- **Command**: `live real-device-realtime --task TASK-125 --prefix TASK125_RT_`
- **Platform**: android
- **Safety**: live-write
- **Result**: BLOCKED_EXTERNAL (exit 2)
- **Duration**: 20022 ms
- **Repo**: <HOME_REDACTED>/AndroidStudioProjects/MerchandiseControlSplitView
- **Branch**: main
- **Git SHA**: 2896e3c
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

AUTH_BLOCKED: Android target is reachable but Supabase session is signed out or unavailable.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T020244Z-live-real-device-realtime-task-TASK-125-prefix-TASK125_RT_-p90855.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T020244Z-live-real-device-realtime-task-TASK-125-prefix-TASK125_RT_-p90855.json`
- Log: `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T020244Z-live-real-device-realtime-task-TASK-125-prefix-TASK125_RT_-p90855.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Open the selected Android target, sign in to Supabase, then rerun the same command with MC_ANDROID_DEVICE_SERIAL=<REDACTED_SERIAL>.

## Reconciliation Detail

- android.selectedTargetType: physical
- android.availableAdbDevices: 2
- android.adbState: device
- android.bootCompleted: 1
- android.appInstalled: True
- android.foregroundPackage: None
- android.screenOn: True
- android.locked: False