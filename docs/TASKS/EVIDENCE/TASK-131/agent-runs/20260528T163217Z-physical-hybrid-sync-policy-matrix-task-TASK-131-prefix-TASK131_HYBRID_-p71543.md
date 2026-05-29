# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260528T163217Z-physical-hybrid-sync-policy-matrix-task-TASK-131-prefix-TASK131_HYBRID_-p71543
- **Task**: TASK-131
- **Command**: `physical hybrid-sync-policy-matrix --task TASK-131 --prefix TASK131_HYBRID_`
- **Platform**: ios
- **Safety**: live-write
- **Result**: BLOCKED_EXTERNAL (exit 2)
- **Duration**: 78780 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: 96b900ef
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

TASK-131 hybrid-sync-policy-matrix did not pass in available scope.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-131/agent-runs/20260528T163217Z-physical-hybrid-sync-policy-matrix-task-TASK-131-prefix-TASK131_HYBRID_-p71543.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-131/agent-runs/20260528T163217Z-physical-hybrid-sync-policy-matrix-task-TASK-131-prefix-TASK131_HYBRID_-p71543.json`
- Log: `docs/TASKS/EVIDENCE/TASK-131/agent-runs/20260528T163217Z-physical-hybrid-sync-policy-matrix-task-TASK-131-prefix-TASK131_HYBRID_-p71543.log`
- xcresult: `/tmp/mc-agent-ios-auth-preflight-20260528T163217Z.xcresult`
- screenshot: `n/a`

## Next Action

Inspect live mutation-near-realtime details, fix app/harness blocker, and rerun.

## Reconciliation Detail

- source: physical.hybrid-sync-policy-matrix
- matrix: hybrid-sync-policy-matrix
- iosPhysicalAvailable: True
- androidPhysicalAvailable: True
- caseStatus: NOT_RUN
- cleanupStatus: NOT_RUN
- residueStatus: NOT_RUN