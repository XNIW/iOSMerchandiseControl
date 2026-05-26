# TASK-125 Sync Responsibility Map

- Status: `PASS`
- Task: `TASK-125`
- Redaction applied: `true`
- Generated: `2026-05-26T00:57:09Z`

iOS sync responsibilities are separated across Orchestrator, Automatic engine/providers, Outbox, Realtime, Recovery, Manual and Background scheduler boundaries. Static gate passed, but full executable invariant suite remains open.

## Referenced agent runs
- `PASS` — `ios test automatic-architecture --task TASK-125` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T003720Z-ios-test-automatic-architecture-task-TASK-125-p22882.json`
- `PASS` — `scan no-root-legacy-sync-service --task TASK-125 --strict` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T003403Z-scan-no-root-legacy-sync-service-task-TASK-125-strict-p16728.json`
- `PASS` — `scan remote-adapter-single-domain --task TASK-125 --strict` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T003108Z-scan-remote-adapter-single-domain-task-TASK-125-strict-p13605.json`
