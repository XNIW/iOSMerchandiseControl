# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260620T223143Z-live-mutation-near-realtime-task-TASK-136-prefix-TASK136_RETRYFIX4_-p55348
- **Task**: TASK-136
- **Command**: `live mutation-near-realtime --task TASK-136 --prefix TASK136_RETRYFIX4_`
- **Platform**: android
- **Safety**: live-write
- **Result**: FAIL (exit 1)
- **Duration**: 227513 ms
- **Repo**: <HOME_REDACTED>/AndroidStudioProjects/MerchandiseControlSplitView
- **Branch**: main
- **Git SHA**: 678ef17
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

Live mutation-near-realtime FAIL/BLOCKED: Android write leg did not pass.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-136/agent-runs/20260620T223143Z-live-mutation-near-realtime-task-TASK-136-prefix-TASK136_RETRYFIX4_-p55348.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-136/agent-runs/20260620T223143Z-live-mutation-near-realtime-task-TASK-136-prefix-TASK136_RETRYFIX4_-p55348.json`
- Log: `docs/TASKS/EVIDENCE/TASK-136/agent-runs/20260620T223143Z-live-mutation-near-realtime-task-TASK-136-prefix-TASK136_RETRYFIX4_-p55348.log`
- xcresult: `/tmp/mc-agent-ios-task114-test114IOSWriteProductHistoryMatrix-1781994800100-20260620T223143Z.xcresult`
- screenshot: `n/a`

## Next Action

Inspect Android write matrix step and rerun mutation-near-realtime.

## Reconciliation Detail

- android.selectedTargetType: emulator
- android.availableAdbDevices: 1
- android.adbState: device
- android.bootCompleted: 1
- android.appInstalled: True
- android.foregroundPackage: None
- android.screenOn: True
- android.locked: False