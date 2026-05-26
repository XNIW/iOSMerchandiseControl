# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260526T043910Z-live-real-device-realtime-task-TASK-125-prefix-TASK125_RT_-p86082
- **Task**: TASK-125
- **Command**: `live real-device-realtime --task TASK-125 --prefix TASK125_RT_`
- **Platform**: ios
- **Safety**: live-write
- **Result**: FAIL (exit 1)
- **Duration**: 143764 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: e4eb3a47
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

iOS TASK-114 matrix step test123IOSSingleCatalogCreatePropagation FAIL/BLOCKED for prefix TASK125_RT_SINGLE_20260526T043910Z_IOS_1_. xcresult=/tmp/mc-agent-ios-task114-test123IOSSingleCatalogCreatePropagation-20260526T043910Z.xcresult

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T043910Z-live-real-device-realtime-task-TASK-125-prefix-TASK125_RT_-p86082.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T043910Z-live-real-device-realtime-task-TASK-125-prefix-TASK125_RT_-p86082.json`
- Log: `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T043910Z-live-real-device-realtime-task-TASK-125-prefix-TASK125_RT_-p86082.log`
- xcresult: `/tmp/mc-agent-ios-task114-test123IOSSingleCatalogCreatePropagation-20260526T043910Z.xcresult`
- screenshot: `n/a`

## Next Action

Inspect xcresult/log; verify app-auth session, RLS and scoped remote rows.

## Reconciliation Detail

- android.selectedTargetType: physical
- android.availableAdbDevices: 2
- android.adbState: device
- android.bootCompleted: 1
- android.appInstalled: True
- android.foregroundPackage: None
- android.screenOn: True
- android.locked: False