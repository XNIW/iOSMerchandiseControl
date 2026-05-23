# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260523T034412Z-android-auth-preflight-live-task-TASK-115-p94316
- **Task**: TASK-115
- **Command**: `android auth-preflight --live --task TASK-115`
- **Platform**: android
- **Safety**: live-write
- **Result**: blocked (exit 2)
- **Duration**: 20132 ms
- **Repo**: <HOME_REDACTED>/AndroidStudioProjects/MerchandiseControlSplitView
- **Branch**: main
- **Git SHA**: b3f65de
- **Dirty**: clean
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

- Markdown: `docs/TASKS/EVIDENCE/TASK-115/agent-runs/20260523T034412Z-android-auth-preflight-live-task-TASK-115-p94316.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-115/agent-runs/20260523T034412Z-android-auth-preflight-live-task-TASK-115-p94316.json`
- Log: `docs/TASKS/EVIDENCE/TASK-115/agent-runs/20260523T034412Z-android-auth-preflight-live-task-TASK-115-p94316.log`
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