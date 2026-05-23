# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260523T040852Z-live-mutation-near-realtime-task-TASK-115-prefix-TASK115_REALTIME_-p17814
- **Task**: TASK-115
- **Command**: `live mutation-near-realtime --task TASK-115 --prefix TASK115_REALTIME_`
- **Platform**: ios
- **Safety**: live-write
- **Result**: fail (exit 1)
- **Duration**: 184651 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: f6efc84
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

Live mutation-near-realtime FAIL/BLOCKED: iOS write leg did not pass.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-115/agent-runs/20260523T040852Z-live-mutation-near-realtime-task-TASK-115-prefix-TASK115_REALTIME_-p17814.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-115/agent-runs/20260523T040852Z-live-mutation-near-realtime-task-TASK-115-prefix-TASK115_REALTIME_-p17814.json`
- Log: `docs/TASKS/EVIDENCE/TASK-115/agent-runs/20260523T040852Z-live-mutation-near-realtime-task-TASK-115-prefix-TASK115_REALTIME_-p17814.log`
- xcresult: `/tmp/mc-agent-ios-task114-test114IOSWriteProductHistoryMatrix-20260523T040852Z.xcresult`
- screenshot: `n/a`

## Next Action

Inspect iOS write matrix step and rerun mutation-near-realtime.

## Reconciliation Detail

- android.selectedTargetType: physical
- android.availableAdbDevices: 2
- android.adbState: device
- android.bootCompleted: 1
- android.appInstalled: True
- android.foregroundPackage: None
- android.screenOn: True
- android.locked: False