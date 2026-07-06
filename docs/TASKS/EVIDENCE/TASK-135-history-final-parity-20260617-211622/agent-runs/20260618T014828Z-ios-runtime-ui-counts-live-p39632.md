# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260618T014828Z-ios-runtime-ui-counts-live-p39632
- **Task**: TASK-135
- **Command**: `ios runtime-ui-counts --live`
- **Platform**: ios
- **Safety**: live-write
- **Result**: UNSAFE_OPERATION_REFUSED (exit 4)
- **Duration**: 142 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: 52a1f51c
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

- Markdown: `docs/TASKS/EVIDENCE/TASK-135-history-final-parity-20260617-211622/agent-runs/20260618T014828Z-ios-runtime-ui-counts-live-p39632.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-135-history-final-parity-20260617-211622/agent-runs/20260618T014828Z-ios-runtime-ui-counts-live-p39632.json`
- Log: `docs/TASKS/EVIDENCE/TASK-135-history-final-parity-20260617-211622/agent-runs/20260618T014828Z-ios-runtime-ui-counts-live-p39632.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Set MC_ALLOW_LIVE=1 only for intentional scoped live tests.