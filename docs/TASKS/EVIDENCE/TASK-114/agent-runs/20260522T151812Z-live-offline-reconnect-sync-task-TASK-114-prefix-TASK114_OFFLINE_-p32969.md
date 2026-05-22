# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260522T151812Z-live-offline-reconnect-sync-task-TASK-114-prefix-TASK114_OFFLINE_-p32969
- **Task**: TASK-114
- **Command**: `live offline-reconnect-sync --task TASK-114 --prefix TASK114_OFFLINE_`
- **Platform**: ios
- **Safety**: live-write
- **Result**: fail (exit 1)
- **Duration**: 172690 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: c1ee078
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

Live mutation-near-realtime FAIL: android did not receive ios_offline_to_android within 30s.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T151812Z-live-offline-reconnect-sync-task-TASK-114-prefix-TASK114_OFFLINE_-p32969.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T151812Z-live-offline-reconnect-sync-task-TASK-114-prefix-TASK114_OFFLINE_-p32969.json`
- Log: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T151812Z-live-offline-reconnect-sync-task-TASK-114-prefix-TASK114_OFFLINE_-p32969.log`
- xcresult: `/tmp/mc-agent-ios-task114-test114IOSOfflineReconnectProductPriceHistoryMatrix-20260522T151812Z.xcresult`
- screenshot: `n/a`

## Next Action

Inspect foreground app auto-sync/realtime logs and rerun after fixing push/pull trigger.

## Reconciliation Detail

- android.selectedTargetType: physical
- android.availableAdbDevices: 2
- android.adbState: device
- android.bootCompleted: 1
- android.appInstalled: True
- android.foregroundPackage: None
- android.screenOn: True
- android.locked: False