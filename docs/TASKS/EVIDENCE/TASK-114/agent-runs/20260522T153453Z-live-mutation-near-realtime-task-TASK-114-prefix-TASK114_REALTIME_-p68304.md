# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260522T153453Z-live-mutation-near-realtime-task-TASK-114-prefix-TASK114_REALTIME_-p68304
- **Task**: TASK-114
- **Command**: `live mutation-near-realtime --task TASK-114 --prefix TASK114_REALTIME_`
- **Platform**: android
- **Safety**: live-write
- **Result**: fail (exit 1)
- **Duration**: 229321 ms
- **Repo**: <HOME_REDACTED>/AndroidStudioProjects/MerchandiseControlSplitView
- **Branch**: main
- **Git SHA**: 8f6c04f
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

- Markdown: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T153453Z-live-mutation-near-realtime-task-TASK-114-prefix-TASK114_REALTIME_-p68304.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T153453Z-live-mutation-near-realtime-task-TASK-114-prefix-TASK114_REALTIME_-p68304.json`
- Log: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T153453Z-live-mutation-near-realtime-task-TASK-114-prefix-TASK114_REALTIME_-p68304.log`
- xcresult: `/tmp/mc-agent-ios-task114-test114IOSWriteProductHistoryMatrix-20260522T153453Z.xcresult`
- screenshot: `n/a`

## Next Action

Inspect Android write matrix step and rerun mutation-near-realtime.

## Reconciliation Detail

- android.selectedTargetType: physical
- android.availableAdbDevices: 2
- android.adbState: device
- android.bootCompleted: 1
- android.appInstalled: True
- android.foregroundPackage: None
- android.screenOn: True
- android.locked: False