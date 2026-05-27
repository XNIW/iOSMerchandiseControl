# Cache Option Risk Decision

- status: `PASS`
- task: `TASK-126`
- safety: safe-readonly / privacy-redacted

## Evidence
- Risk decision: logicalScope now, physicalStore later under feature flag and migration plan.
- Dirty inactive cache cannot be deleted without backup/export safety and strong confirmation.
- Cache manifest redacts owner/store/local identifiers.

## Referenced agent reports
- `docs/TASKS/EVIDENCE/TASK-126/agent-runs/20260527T011739Z-scan-cache-active-store-only-task-TASK-126-strict-p17117.json`
