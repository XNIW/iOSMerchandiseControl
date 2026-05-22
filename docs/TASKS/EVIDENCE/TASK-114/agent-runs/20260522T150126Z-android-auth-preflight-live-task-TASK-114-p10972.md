# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260522T150126Z-android-auth-preflight-live-task-TASK-114-p10972
- **Task**: TASK-114
- **Command**: `android auth-preflight --live --task TASK-114`
- **Platform**: android
- **Safety**: live-write
- **Result**: blocked (exit 2)
- **Duration**: 14676 ms
- **Repo**: <HOME_REDACTED>/AndroidStudioProjects/MerchandiseControlSplitView
- **Branch**: main
- **Git SHA**: 8f6c04f
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

- Markdown: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T150126Z-android-auth-preflight-live-task-TASK-114-p10972.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T150126Z-android-auth-preflight-live-task-TASK-114-p10972.json`
- Log: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T150126Z-android-auth-preflight-live-task-TASK-114-p10972.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Open the selected Android target, sign in to Supabase, then rerun the same command with MC_ANDROID_DEVICE_SERIAL=<REDACTED_SERIAL>.

## Reconciliation Detail

- android.selectedTargetType: emulator
- android.availableAdbDevices: 2
- android.adbState: device
- android.bootCompleted: 1
- android.appInstalled: True
- android.foregroundPackage: None
- android.screenOn: True
- android.locked: False