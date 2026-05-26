# TASK-125 Scanner Self Tests

- Status: `PASS`
- Task: `TASK-125`
- Redaction applied: `true`
- Generated: `2026-05-26T00:57:09Z`

TASK-125 static scanners were added/rerun. Latest strict scanner reports are PASS after fixing false positives and adding iOS background registration.

## Referenced agent runs
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

## Checks
- `PASS` — no-hidden-manual-sync: docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T003038Z-scan-no-hidden-manual-sync-task-TASK-125-strict-p10969.json
- `PASS` — no-full-pull-normal-path: docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T003108Z-scan-no-full-pull-normal-path-task-TASK-125-strict-p13606.json
- `PASS` — no-service-role-client: docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T003450Z-scan-no-service-role-client-task-TASK-125-strict-p20017.json
- `PASS` — no-rls-bypass: docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T003403Z-scan-no-rls-bypass-task-TASK-125-strict-p16684.json
- `PASS` — no-mainactor-heavy-sync: docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T003038Z-scan-no-mainactor-heavy-sync-task-TASK-125-strict-p11003.json
- `PASS` — no-stale-pbxproj-reference: docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T003403Z-scan-no-stale-pbxproj-reference-task-TASK-125-strict-p16717.json
- `PASS` — no-test-fixture-in-app-target: docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T003403Z-scan-no-test-fixture-in-app-target-task-TASK-125-strict-p16730.json
- `PASS` — no-root-legacy-sync-service: docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T003403Z-scan-no-root-legacy-sync-service-task-TASK-125-strict-p16728.json
- `PASS` — remote-adapter-single-domain: docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T003108Z-scan-remote-adapter-single-domain-task-TASK-125-strict-p13605.json
- `PASS` — background-task-registration: docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T003352Z-scan-background-task-registration-task-TASK-125-strict-p15819.json
- `PASS` — background-task-no-ui-context: docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T003352Z-scan-background-task-no-ui-context-task-TASK-125-strict-p15818.json
- `PASS` — outbox-pending-survives-restart: docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T003403Z-scan-outbox-pending-survives-restart-task-TASK-125-strict-p16758.json
- `PASS` — evidence-redaction: docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T004612Z-scan-evidence-redaction-task-TASK-125-strict-p31683.json
- `PASS` — source-format: docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T004537Z-scan-source-format-task-TASK-125-strict-p29963.json
- `PASS` — dead-code-residue: docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T004537Z-scan-dead-code-residue-task-TASK-125-strict-p29961.json
