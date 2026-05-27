# Conflict Resolution Policy

- status: `PASS`
- task: `TASK-126`
- safety: safe-readonly / privacy-redacted

## Evidence
- Different-field local+remote changes auto-merge.
- Same-field and delete-vs-edit route to Review.
- Domain invariant violations route to Review even if fields are disjoint.

## Referenced agent reports
- `docs/TASKS/EVIDENCE/TASK-126/agent-runs/20260527T011809Z-ios-test-conflict-review-task-TASK-126-p18646.json`
- `docs/TASKS/EVIDENCE/TASK-126/agent-runs/20260527T012312Z-android-test-conflict-review-task-TASK-126-p24270.json`
