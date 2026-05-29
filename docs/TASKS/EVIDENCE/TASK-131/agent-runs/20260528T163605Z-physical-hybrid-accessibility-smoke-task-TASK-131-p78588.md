# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260528T163605Z-physical-hybrid-accessibility-smoke-task-TASK-131-p78588
- **Task**: TASK-131
- **Command**: `physical hybrid-accessibility-smoke --task TASK-131`
- **Platform**: android
- **Safety**: safe-readonly
- **Result**: FAIL (exit 1)
- **Duration**: 3002 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: 96b900ef
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

TASK-131 hybrid-accessibility-smoke FAIL: basic smoke hooks ran where available, but real Dynamic Type/VoiceOver/TalkBack traversal is not fully automated/operator-certified yet.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-131/agent-runs/20260528T163605Z-physical-hybrid-accessibility-smoke-task-TASK-131-p78588.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-131/agent-runs/20260528T163605Z-physical-hybrid-accessibility-smoke-task-TASK-131-p78588.json`
- Log: `docs/TASKS/EVIDENCE/TASK-131/agent-runs/20260528T163605Z-physical-hybrid-accessibility-smoke-task-TASK-131-p78588.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Capture structured operator-assisted accessibility checklist or implement real traversal automation before REVIEW.

## Reconciliation Detail

- source: physical.hybrid-accessibility-smoke
- matrix: hybrid-accessibility-smoke
- iosPhysicalAvailable: True
- androidPhysicalAvailable: True
- caseStatus: NOT_RUN
- cleanupStatus: NOT_RUN
- residueStatus: NOT_RUN