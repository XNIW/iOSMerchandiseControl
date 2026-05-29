# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260528T213349Z-android-cleanup-scoped-prefix-TASK131_-dry-run-p39231
- **Task**: TASK-131
- **Command**: `android cleanup-scoped --prefix TASK131_ --dry-run`
- **Platform**: android
- **Safety**: cleanup-dry-run
- **Result**: BLOCKED_EXTERNAL (exit 2)
- **Duration**: 1968 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: 96b900ef
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

BLOCKED_DEVICE_LOCKED: Android target appears screen-off/asleep.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-131/agent-runs/20260528T213349Z-android-cleanup-scoped-prefix-TASK131_-dry-run-p39231.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-131/agent-runs/20260528T213349Z-android-cleanup-scoped-prefix-TASK131_-dry-run-p39231.json`
- Log: `docs/TASKS/EVIDENCE/TASK-131/agent-runs/20260528T213349Z-android-cleanup-scoped-prefix-TASK131_-dry-run-p39231.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Wake and unlock the selected Android target, then retry; or rerun with an explicit emulator serial.

## Reconciliation Detail

- android.selectedTargetType: physical
- android.availableAdbDevices: 2
- android.adbState: device
- android.bootCompleted: 1
- android.appInstalled: True
- android.foregroundPackage: None
- android.screenOn: False
- android.locked: True