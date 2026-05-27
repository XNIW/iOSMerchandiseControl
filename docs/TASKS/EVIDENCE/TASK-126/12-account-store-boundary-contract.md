# Account Store Boundary Contract

- status: `PASS`
- task: `TASK-126`
- safety: safe-readonly / privacy-redacted

## Evidence
- Pending/outbox scope carries owner, store, local store, schema/protocol and epoch metadata.
- Outbox drain validates active owner/store before mutation.
- Owner/store mismatch is fail-closed.

## Referenced agent reports
- `docs/TASKS/EVIDENCE/TASK-126/agent-runs/20260527T011737Z-scan-owner-store-scope-task-TASK-126-strict-p16337.json`
- `docs/TASKS/EVIDENCE/TASK-126/agent-runs/20260527T011738Z-scan-no-cross-owner-store-pending-push-task-TASK-126-strict-p16722.json`
- `docs/TASKS/EVIDENCE/TASK-126/agent-runs/20260527T011802Z-ios-test-account-store-boundary-task-TASK-126-p18151.json`
- `docs/TASKS/EVIDENCE/TASK-126/agent-runs/20260527T012306Z-android-test-account-store-boundary-task-TASK-126-p23812.json`
