# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260523T034554Z-live-mutation-near-realtime-task-TASK-115-prefix-TASK115_REALTIME_-p96051
- **Task**: TASK-115
- **Command**: `live mutation-near-realtime --task TASK-115 --prefix TASK115_REALTIME_`
- **Platform**: ios
- **Safety**: live-write
- **Result**: blocked (exit 2)
- **Duration**: 69574 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: f6efc84
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

iOS auth-preflight BLOCKED/FAIL. xcresult=/tmp/mc-agent-ios-auth-preflight-20260523T034554Z.xcresult

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-115/agent-runs/20260523T034554Z-live-mutation-near-realtime-task-TASK-115-prefix-TASK115_REALTIME_-p96051.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-115/agent-runs/20260523T034554Z-live-mutation-near-realtime-task-TASK-115-prefix-TASK115_REALTIME_-p96051.json`
- Log: `docs/TASKS/EVIDENCE/TASK-115/agent-runs/20260523T034554Z-live-mutation-near-realtime-task-TASK-115-prefix-TASK115_REALTIME_-p96051.log`
- xcresult: `/tmp/mc-agent-ios-auth-preflight-20260523T034554Z.xcresult`
- screenshot: `n/a`

## Next Action

Open app, complete login, verify session restore, then retry.

## Reconciliation Detail

- android.selectedTargetType: physical
- android.availableAdbDevices: 2
- android.adbState: device
- android.bootCompleted: 1
- android.appInstalled: True
- android.foregroundPackage: None
- android.screenOn: True
- android.locked: False