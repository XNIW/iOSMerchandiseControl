# Multistore Cache Option Decision

- status: `PASS_WITH_NOTES`
- task: `TASK-126`
- safety: safe-readonly / privacy-redacted

## Evidence
- Chosen MVP cache mode: `logicalScope` with active-store-only manifest policy.
- Physical multi-store cache remains disabled by feature flag until remote runtime tables become store-aware.
- List/store metadata does not require opening all inactive caches.

## Referenced agent reports
- `docs/TASKS/EVIDENCE/TASK-126/agent-runs/20260527T011739Z-scan-cache-active-store-only-task-TASK-126-strict-p17117.json`
- `docs/TASKS/EVIDENCE/TASK-126/agent-runs/20260527T011816Z-ios-test-cache-memory-task-TASK-126-p19149.json`
- `docs/TASKS/EVIDENCE/TASK-126/agent-runs/20260527T012314Z-android-test-cache-memory-task-TASK-126-p24640.json`
