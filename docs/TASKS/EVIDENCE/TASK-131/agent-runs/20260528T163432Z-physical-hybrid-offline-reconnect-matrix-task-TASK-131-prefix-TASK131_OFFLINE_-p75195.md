# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260528T163432Z-physical-hybrid-offline-reconnect-matrix-task-TASK-131-prefix-TASK131_OFFLINE_-p75195
- **Task**: TASK-131
- **Command**: `physical hybrid-offline-reconnect-matrix --task TASK-131 --prefix TASK131_OFFLINE_`
- **Platform**: ios
- **Safety**: live-write
- **Result**: BLOCKED_EXTERNAL (exit 2)
- **Duration**: 74914 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: 96b900ef
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

TASK-131 hybrid-offline-reconnect-matrix did not pass in available scope.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-131/agent-runs/20260528T163432Z-physical-hybrid-offline-reconnect-matrix-task-TASK-131-prefix-TASK131_OFFLINE_-p75195.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-131/agent-runs/20260528T163432Z-physical-hybrid-offline-reconnect-matrix-task-TASK-131-prefix-TASK131_OFFLINE_-p75195.json`
- Log: `docs/TASKS/EVIDENCE/TASK-131/agent-runs/20260528T163432Z-physical-hybrid-offline-reconnect-matrix-task-TASK-131-prefix-TASK131_OFFLINE_-p75195.log`
- xcresult: `/tmp/mc-agent-ios-auth-preflight-20260528T163432Z.xcresult`
- screenshot: `n/a`

## Next Action

Inspect offline reconnect evidence, fix blocker, and rerun.

## Reconciliation Detail

- source: physical.hybrid-offline-reconnect-matrix
- matrix: hybrid-offline-reconnect-matrix
- iosPhysicalAvailable: True
- androidPhysicalAvailable: True
- caseStatus: NOT_RUN
- cleanupStatus: NOT_RUN
- residueStatus: NOT_RUN