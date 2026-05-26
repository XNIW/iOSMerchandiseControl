# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260526T030524Z-live-real-device-realtime-task-TASK-125-prefix-TASK125_RT_-p29034
- **Task**: TASK-125
- **Command**: `live real-device-realtime --task TASK-125 --prefix TASK125_RT_`
- **Platform**: ios
- **Safety**: live-write
- **Result**: BLOCKED_EXTERNAL (exit 2)
- **Duration**: 793817 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: e4eb3a47
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

iOS runtime-ui-counts BLOCKED: physical iPhone store copy/counts unavailable.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T030524Z-live-real-device-realtime-task-TASK-125-prefix-TASK125_RT_-p29034.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T030524Z-live-real-device-realtime-task-TASK-125-prefix-TASK125_RT_-p29034.json`
- Log: `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T030524Z-live-real-device-realtime-task-TASK-125-prefix-TASK125_RT_-p29034.log`
- xcresult: `/tmp/mc-agent-ios-task114-test123IOSSingleCatalogCreatePropagation-20260526T030524Z.xcresult`
- screenshot: `n/a`

## Next Action

Unlock/trust iPhone, keep app installed/logged in, then rerun TASK-125 physical matrix.

## Reconciliation Detail

- android.selectedTargetType: physical
- android.availableAdbDevices: 2
- android.adbState: device
- android.bootCompleted: 1
- android.appInstalled: True
- android.foregroundPackage: None
- android.screenOn: True
- android.locked: False