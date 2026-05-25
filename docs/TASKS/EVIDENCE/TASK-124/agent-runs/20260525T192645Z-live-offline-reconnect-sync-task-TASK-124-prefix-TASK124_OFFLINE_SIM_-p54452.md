# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260525T192645Z-live-offline-reconnect-sync-task-TASK-124-prefix-TASK124_OFFLINE_SIM_-p54452
- **Task**: TASK-124
- **Command**: `live offline-reconnect-sync --task TASK-124 --prefix TASK124_OFFLINE_SIM_`
- **Platform**: android
- **Safety**: live-write
- **Result**: FAIL (exit 1)
- **Duration**: 147549 ms
- **Repo**: <HOME_REDACTED>/AndroidStudioProjects/MerchandiseControlSplitView
- **Branch**: main
- **Git SHA**: 2085c3d
- **Dirty**: clean
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

Live offline-reconnect-sync FAIL/BLOCKED: Android offline reconnect leg did not pass.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-124/agent-runs/20260525T192645Z-live-offline-reconnect-sync-task-TASK-124-prefix-TASK124_OFFLINE_SIM_-p54452.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-124/agent-runs/20260525T192645Z-live-offline-reconnect-sync-task-TASK-124-prefix-TASK124_OFFLINE_SIM_-p54452.json`
- Log: `docs/TASKS/EVIDENCE/TASK-124/agent-runs/20260525T192645Z-live-offline-reconnect-sync-task-TASK-124-prefix-TASK124_OFFLINE_SIM_-p54452.log`
- xcresult: `/tmp/mc-agent-ios-task114-test114IOSOfflineReconnectProductPriceHistoryMatrix-20260525T192645Z.xcresult`
- screenshot: `n/a`

## Next Action

Inspect Android offline reconnect instrumentation and rerun offline-reconnect-sync.

## Reconciliation Detail

- android.selectedTargetType: emulator
- android.availableAdbDevices: 1
- android.adbState: device
- android.bootCompleted: 1
- android.appInstalled: True
- android.foregroundPackage: None
- android.screenOn: True
- android.locked: False