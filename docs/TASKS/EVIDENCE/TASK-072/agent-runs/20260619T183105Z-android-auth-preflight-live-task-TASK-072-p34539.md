# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260619T183105Z-android-auth-preflight-live-task-TASK-072-p34539
- **Task**: TASK-072
- **Command**: `android auth-preflight --live --task TASK-072`
- **Platform**: android
- **Safety**: live-write
- **Result**: BLOCKED_EXTERNAL (exit 2)
- **Duration**: 21250 ms
- **Repo**: <HOME_REDACTED>/AndroidStudioProjects/MerchandiseControlSplitView
- **Branch**: main
- **Git SHA**: 7f408d2
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

- Markdown: `docs/TASKS/EVIDENCE/TASK-072/agent-runs/20260619T183105Z-android-auth-preflight-live-task-TASK-072-p34539.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-072/agent-runs/20260619T183105Z-android-auth-preflight-live-task-TASK-072-p34539.json`
- Log: `docs/TASKS/EVIDENCE/TASK-072/agent-runs/20260619T183105Z-android-auth-preflight-live-task-TASK-072-p34539.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Open the selected Android target, sign in to Supabase, then rerun the same command with MC_ANDROID_DEVICE_SERIAL=<REDACTED_SERIAL>

## Reconciliation Detail

- android.selectedTargetType: emulator
- android.availableAdbDevices: 1
- android.adbState: device
- android.bootCompleted: 1
- android.appInstalled: True
- android.foregroundPackage: None
- android.screenOn: True
- android.locked: False