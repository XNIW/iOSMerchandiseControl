# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260522T082046Z-android-auth-preflight-live-task-TASK-114-p33089
- **Task**: TASK-114
- **Command**: `android auth-preflight --live --task TASK-114`
- **Platform**: android
- **Safety**: live-write
- **Result**: refused (exit 4)
- **Duration**: 107 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: c1ee078
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

Live operation refused. MC_ALLOW_LIVE=1 is required.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T082046Z-android-auth-preflight-live-task-TASK-114-p33089.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T082046Z-android-auth-preflight-live-task-TASK-114-p33089.json`
- Log: `docs/TASKS/EVIDENCE/TASK-114/agent-runs/20260522T082046Z-android-auth-preflight-live-task-TASK-114-p33089.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Set MC_ALLOW_LIVE=1 only for intentional scoped live tests.