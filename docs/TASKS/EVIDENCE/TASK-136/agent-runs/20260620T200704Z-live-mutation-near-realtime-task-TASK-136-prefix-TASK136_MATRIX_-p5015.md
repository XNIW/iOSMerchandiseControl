# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260620T200704Z-live-mutation-near-realtime-task-TASK-136-prefix-TASK136_MATRIX_-p5015
- **Task**: TASK-136
- **Command**: `live mutation-near-realtime --task TASK-136 --prefix TASK136_MATRIX_`
- **Platform**: ios
- **Safety**: live-write
- **Result**: BLOCKED_EXTERNAL (exit 2)
- **Duration**: 173841 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: 26a9ad21
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

- Markdown: `docs/TASKS/EVIDENCE/TASK-136/agent-runs/20260620T200704Z-live-mutation-near-realtime-task-TASK-136-prefix-TASK136_MATRIX_-p5015.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-136/agent-runs/20260620T200704Z-live-mutation-near-realtime-task-TASK-136-prefix-TASK136_MATRIX_-p5015.json`
- Log: `docs/TASKS/EVIDENCE/TASK-136/agent-runs/20260620T200704Z-live-mutation-near-realtime-task-TASK-136-prefix-TASK136_MATRIX_-p5015.log`
- xcresult: `/tmp/mc-agent-ios-task114-test114IOSWriteProductHistoryMatrix-1781986152749-20260620T200704Z.xcresult`
- screenshot: `n/a`

## Next Action

Inspect iOS write matrix step and rerun mutation-near-realtime.

## Reconciliation Detail

- android.selectedTargetType: emulator
- android.availableAdbDevices: 1
- android.adbState: device
- android.bootCompleted: 1
- android.appInstalled: True
- android.foregroundPackage: None
- android.screenOn: True
- android.locked: False