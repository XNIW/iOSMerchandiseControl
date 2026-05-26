# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260526T004703Z-ios-device-auth-preflight-live-task-TASK-125-p33432
- **Task**: TASK-125
- **Command**: `ios device-auth-preflight --live --task TASK-125`
- **Platform**: ios
- **Safety**: live-readonly
- **Result**: BLOCKED_EXTERNAL (exit 2)
- **Duration**: 170 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: e4eb3a47
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

iOS physical device-auth-preflight BLOCKED: MC_IOS_DEVICE_UDID is not set.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T004703Z-ios-device-auth-preflight-live-task-TASK-125-p33432.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T004703Z-ios-device-auth-preflight-live-task-TASK-125-p33432.json`
- Log: `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T004703Z-ios-device-auth-preflight-live-task-TASK-125-p33432.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Set MC_IOS_DEVICE_UDID for the physical device 'iPhone di Min', unlock/trust it, then rerun ios device-auth-preflight.