# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260620T222033Z-live-mutation-near-realtime-task-TASK-136-prefix-TASK136_RETRYFIX2_-p40316
- **Task**: TASK-136
- **Command**: `live mutation-near-realtime --task TASK-136 --prefix TASK136_RETRYFIX2_`
- **Platform**: android
- **Safety**: live-write
- **Result**: FAIL (exit 1)
- **Duration**: 195613 ms
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

- Markdown: `docs/TASKS/EVIDENCE/TASK-136/agent-runs/20260620T222033Z-live-mutation-near-realtime-task-TASK-136-prefix-TASK136_RETRYFIX2_-p40316.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-136/agent-runs/20260620T222033Z-live-mutation-near-realtime-task-TASK-136-prefix-TASK136_RETRYFIX2_-p40316.json`
- Log: `docs/TASKS/EVIDENCE/TASK-136/agent-runs/20260620T222033Z-live-mutation-near-realtime-task-TASK-136-prefix-TASK136_RETRYFIX2_-p40316.log`
- xcresult: `/tmp/mc-agent-ios-task114-test114IOSWriteProductHistoryMatrix-1781994132483-20260620T222033Z.xcresult`
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