# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260528T191852Z-live-task123-noop-task-TASK-131-prefix-TASK131_POLICY_-p29579
- **Task**: TASK-131
- **Command**: `live task123-noop --task TASK-131 --prefix TASK131_POLICY_`
- **Platform**: ios
- **Safety**: live-write
- **Result**: BLOCKED_EXTERNAL (exit 2)
- **Duration**: 84447 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: 96b900ef
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

iOS auth-preflight BLOCKED/FAIL. xcresult=/tmp/mc-agent-ios-auth-preflight-20260528T191852Z.xcresult

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-131/agent-runs/20260528T191852Z-live-task123-noop-task-TASK-131-prefix-TASK131_POLICY_-p29579.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-131/agent-runs/20260528T191852Z-live-task123-noop-task-TASK-131-prefix-TASK131_POLICY_-p29579.json`
- Log: `docs/TASKS/EVIDENCE/TASK-131/agent-runs/20260528T191852Z-live-task123-noop-task-TASK-131-prefix-TASK131_POLICY_-p29579.log`
- xcresult: `/tmp/mc-agent-ios-auth-preflight-20260528T191852Z.xcresult`
- screenshot: `n/a`

## Next Action

Open app, complete login, verify session restore, then retry.

## Reconciliation Detail

- android.selectedTargetType: physical
- android.availableAdbDevices: 2
- android.adbState: device
- android.bootCompleted: 1
- android.appInstalled: True
- android.foregroundPackage: None
- android.screenOn: True
- android.locked: False