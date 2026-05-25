# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260525T023405Z-live-mutation-near-realtime-task-TASK-123-prefix-TASK123_SPEED_-p83288
- **Task**: TASK-123
- **Command**: `live mutation-near-realtime --task TASK-123 --prefix TASK123_SPEED_`
- **Platform**: ios
- **Safety**: live-write
- **Result**: BLOCKED_EXTERNAL (exit 2)
- **Duration**: 126206 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: 8116de9d
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

- Markdown: `docs/TASKS/EVIDENCE/TASK-123/agent-runs/20260525T023405Z-live-mutation-near-realtime-task-TASK-123-prefix-TASK123_SPEED_-p83288.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-123/agent-runs/20260525T023405Z-live-mutation-near-realtime-task-TASK-123-prefix-TASK123_SPEED_-p83288.json`
- Log: `docs/TASKS/EVIDENCE/TASK-123/agent-runs/20260525T023405Z-live-mutation-near-realtime-task-TASK-123-prefix-TASK123_SPEED_-p83288.log`
- xcresult: `/tmp/mc-agent-ios-task114-test114IOSWriteProductHistoryMatrix-20260525T023405Z.xcresult`
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