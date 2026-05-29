# mc-agent report

- **Schema**: 1.1
- **Run ID**: 20260528T181541Z-ios-physical-sync-policy-ui-task-TASK-131-prefix-TASK131_IOS_PHYS_-p67609
- **Task**: TASK-131
- **Command**: `ios physical sync-policy-ui --task TASK-131 --prefix TASK131_IOS_PHYS_`
- **Platform**: ios
- **Safety**: live-readonly
- **Result**: BLOCKED_EXTERNAL (exit 2)
- **Duration**: 5946 ms
- **Repo**: <HOME_REDACTED>/Desktop/iOSMerchandiseControl
- **Branch**: main
- **Git SHA**: 96b900ef
- **Dirty**: dirty
- **Profile**: null
- **Android offline tier**: none
- **Cleanup plan ID**: n/a

## Summary

iOS physical-auth-store-diagnostics BLOCKED: physical runtime store/session evidence unavailable.

## Counts

- rows_created: 0
- rows_deleted: 0
- residue_count: 0

## Artifacts

- Markdown: `docs/TASKS/EVIDENCE/TASK-131/agent-runs/20260528T181541Z-ios-physical-sync-policy-ui-task-TASK-131-prefix-TASK131_IOS_PHYS_-p67609.md`
- JSON: `docs/TASKS/EVIDENCE/TASK-131/agent-runs/20260528T181541Z-ios-physical-sync-policy-ui-task-TASK-131-prefix-TASK131_IOS_PHYS_-p67609.json`
- Log: `docs/TASKS/EVIDENCE/TASK-131/agent-runs/20260528T181541Z-ios-physical-sync-policy-ui-task-TASK-131-prefix-TASK131_IOS_PHYS_-p67609.log`
- xcresult: `n/a`
- screenshot: `n/a`

## Next Action

Unlock/trust the iPhone, install/open the app, sign in, then rerun diagnostics.

## Reconciliation Detail

- source: ios.physical.sync-policy-ui
- matrix: sync-policy-ui
- iosPhysicalAvailable: True
- androidPhysicalAvailable: True
- caseStatus: NOT_RUN
- cleanupStatus: NOT_RUN
- residueStatus: NOT_RUN