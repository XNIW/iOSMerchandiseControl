# iOS Physical Cache Spike

- status: `PASS_WITH_NOTES`
- task: `TASK-126`
- safety: safe-readonly / privacy-redacted

## Evidence
- SwiftData-facing metadata now carries store/localStore/protocol/epoch fields.
- Physical multi-store database opening is not enabled in TASK-126 MVP because backend runtime is not store-aware.

## Referenced agent reports
- `docs/TASKS/EVIDENCE/TASK-126/agent-runs/20260527T011816Z-ios-test-cache-memory-task-TASK-126-p19149.json`
