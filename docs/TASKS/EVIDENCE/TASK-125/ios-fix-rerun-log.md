# TASK-125 iOS Fix/Rerun Log

- Status: `FAIL`
- Task: `TASK-125`
- Redaction applied: `true`
- Generated: `2026-05-26T00:57:09Z`

iOS Fix/Rerun Log was not completed to PASS. Some supporting build/test/scanner evidence exists, but TASK-125 requires per-contract parity and rerun-to-PASS before real-device acceptance.

## Referenced agent runs
- `PASS` — `android build debug --task TASK-125` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T004056Z-android-build-debug-task-TASK-125-p25553.json`
- `PASS` — `android test offline --task TASK-125` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T004109Z-android-test-offline-task-TASK-125-p26120.json`
- `PASS` — `android test sync --task TASK-125` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T004109Z-android-test-sync-task-TASK-125-p26121.json`
- `PASS` — `scan no-hidden-manual-sync --task TASK-125 --strict` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T003038Z-scan-no-hidden-manual-sync-task-TASK-125-strict-p10969.json`
- `PASS` — `scan no-full-pull-normal-path --task TASK-125 --strict` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T003108Z-scan-no-full-pull-normal-path-task-TASK-125-strict-p13606.json`
- `PASS` — `scan no-service-role-client --task TASK-125 --strict` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T003450Z-scan-no-service-role-client-task-TASK-125-strict-p20017.json`
- `PASS` — `scan no-rls-bypass --task TASK-125 --strict` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T003403Z-scan-no-rls-bypass-task-TASK-125-strict-p16684.json`
- `PASS` — `scan no-mainactor-heavy-sync --task TASK-125 --strict` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T003038Z-scan-no-mainactor-heavy-sync-task-TASK-125-strict-p11003.json`
- `PASS` — `scan no-stale-pbxproj-reference --task TASK-125 --strict` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T003403Z-scan-no-stale-pbxproj-reference-task-TASK-125-strict-p16717.json`
- `PASS` — `scan no-test-fixture-in-app-target --task TASK-125 --strict` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T003403Z-scan-no-test-fixture-in-app-target-task-TASK-125-strict-p16730.json`
- `PASS` — `scan no-root-legacy-sync-service --task TASK-125 --strict` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T003403Z-scan-no-root-legacy-sync-service-task-TASK-125-strict-p16728.json`
- `PASS` — `scan remote-adapter-single-domain --task TASK-125 --strict` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T003108Z-scan-remote-adapter-single-domain-task-TASK-125-strict-p13605.json`
- `PASS` — `scan background-task-registration --task TASK-125 --strict` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T003352Z-scan-background-task-registration-task-TASK-125-strict-p15819.json`
- `PASS` — `scan background-task-no-ui-context --task TASK-125 --strict` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T003352Z-scan-background-task-no-ui-context-task-TASK-125-strict-p15818.json`
- `PASS` — `scan outbox-pending-survives-restart --task TASK-125 --strict` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T003403Z-scan-outbox-pending-survives-restart-task-TASK-125-strict-p16758.json`
- `PASS` — `scan evidence-redaction --task TASK-125 --strict` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T004612Z-scan-evidence-redaction-task-TASK-125-strict-p31683.json`
- `PASS` — `scan source-format --task TASK-125 --strict` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T004537Z-scan-source-format-task-TASK-125-strict-p29963.json`
- `PASS` — `scan dead-code-residue --task TASK-125 --strict` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T004537Z-scan-dead-code-residue-task-TASK-125-strict-p29961.json`

## Next action
Complete per-contract parity audit/fix/rerun and update evidence to PASS only after all open FAILs are zero.
