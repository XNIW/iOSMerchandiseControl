# Cleanup / Retention Policy

## Policy

- Synthetic runtime datasets should use task-specific prefixes such as `TASK101_*` and must be collision-checked before writing.
- Evidence should store only counts, hashes and scoped IDs; no full catalog dumps.
- Client `authenticated` role should not receive broad DELETE on inventory tables.
- Cleanup requiring DELETE should be executed through an explicit operator/admin workflow with a scoped predicate and a pre/post count.
- Retention for test data should be reviewed before release; automated retention is future Ops hygiene and was not required because TASK-101 created no rows.

## TASK-101 Result

No test data rows were created or deleted. Cleanup policy is sufficient for TASK-101 closure; automated retention remains a non-blocking Ops improvement.
