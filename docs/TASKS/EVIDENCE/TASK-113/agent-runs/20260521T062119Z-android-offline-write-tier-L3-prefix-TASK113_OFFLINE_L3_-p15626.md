# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260521T062119Z-android-offline-write-tier-L3-prefix-TASK113_OFFLINE_L3_-p15626
- **Task**: TASK-113
- **Command**: `android offline-write --tier L3 --prefix TASK113_OFFLINE_L3_`
- **Platform**: android
- **Safety**: live-write
- **Result**: refused (exit 4)
- **Duration**: 106 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: 10f5bdd
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: L3
- **Cleanup plan ID**: n/a

## Summary

Android offline-write L3 FAIL/BLOCKED for TASK113_OFFLINE_L3_. Detail: Live operation refused. MC_ALLOW_LIVE=1 is required.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-113/agent-runs/20260521T062119Z-android-offline-write-tier-L3-prefix-TASK113_OFFLINE_L3_-p15626.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-113/agent-runs/20260521T062119Z-android-offline-write-tier-L3-prefix-TASK113_OFFLINE_L3_-p15626.json`
- Log: `docs/TASKS/EVIDENCE/TASK-113/agent-runs/20260521T062119Z-android-offline-write-tier-L3-prefix-TASK113_OFFLINE_L3_-p15626.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Set MC_ALLOW_LIVE=1 only for intentional scoped live tests.