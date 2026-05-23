# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260523T044219Z-live-mutation-near-realtime-task-TASK-115-prefix-TASK115_REALTIME_-p55580
- **Task**: TASK-115
- **Command**: `live mutation-near-realtime --task TASK-115 --prefix TASK115_REALTIME_`
- **Platform**: android
- **Safety**: live-write
- **Result**: fail (exit 1)
- **Duration**: 171013 ms
- **Repo**: <HOME_REDACTED>/AndroidStudioProjects/MerchandiseControlSplitView
- **Branch**: main
- **Git SHA**: b3f65de
- **Dirty**: clean
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

- Markdown: `docs/TASKS/EVIDENCE/TASK-115/agent-runs/20260523T044219Z-live-mutation-near-realtime-task-TASK-115-prefix-TASK115_REALTIME_-p55580.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-115/agent-runs/20260523T044219Z-live-mutation-near-realtime-task-TASK-115-prefix-TASK115_REALTIME_-p55580.json`
- Log: `docs/TASKS/EVIDENCE/TASK-115/agent-runs/20260523T044219Z-live-mutation-near-realtime-task-TASK-115-prefix-TASK115_REALTIME_-p55580.log`
- xcresult: `/tmp/mc-agent-ios-task114-test114IOSWriteProductHistoryMatrix-20260523T044219Z.xcresult`
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