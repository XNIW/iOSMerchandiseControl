# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260525T192348Z-live-offline-reconnect-sync-task-TASK-124-prefix-TASK124_OFFLINE_SIM_-p49625
- **Task**: TASK-124
- **Command**: `live offline-reconnect-sync --task TASK-124 --prefix TASK124_OFFLINE_SIM_`
- **Platform**: ios
- **Safety**: live-write
- **Result**: BLOCKED_EXTERNAL (exit 2)
- **Duration**: 138301 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: 6e8ee53b
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

Live offline-reconnect-sync FAIL/BLOCKED: iOS offline reconnect leg did not pass.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-124/agent-runs/20260525T192348Z-live-offline-reconnect-sync-task-TASK-124-prefix-TASK124_OFFLINE_SIM_-p49625.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-124/agent-runs/20260525T192348Z-live-offline-reconnect-sync-task-TASK-124-prefix-TASK124_OFFLINE_SIM_-p49625.json`
- Log: `docs/TASKS/EVIDENCE/TASK-124/agent-runs/20260525T192348Z-live-offline-reconnect-sync-task-TASK-124-prefix-TASK124_OFFLINE_SIM_-p49625.log`
- xcresult: `/tmp/mc-agent-ios-task114-test114IOSOfflineReconnectProductPriceHistoryMatrix-20260525T192348Z.xcresult`
- screenshot: `n/a`

## Next Action

Inspect iOS offline reconnect XCTest and rerun offline-reconnect-sync.

## Reconciliation Detail

- android.selectedTargetType: emulator
- android.availableAdbDevices: 1
- android.adbState: device
- android.bootCompleted: 1
- android.appInstalled: True
- android.foregroundPackage: None
- android.screenOn: True
- android.locked: False