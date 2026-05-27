# Domain Invariant Merge Policy

- status: `PASS`
- task: `TASK-126`
- safety: safe-readonly / privacy-redacted

## Evidence
- Field-level merge is allowed only when business invariants remain valid.
- Invariant violation is explicit conflict reason on both platforms.
- Batch review summary preserves reasons for recovery.

## Referenced agent reports
- `docs/TASKS/EVIDENCE/TASK-126/agent-runs/20260527T011809Z-ios-test-conflict-review-task-TASK-126-p18646.json`
- `docs/TASKS/EVIDENCE/TASK-126/agent-runs/20260527T012312Z-android-test-conflict-review-task-TASK-126-p24270.json`
