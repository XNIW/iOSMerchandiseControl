# Live Validation Limitations

- Supabase local read-only checks PASS:
  - `docs/TASKS/EVIDENCE/TASK-122/agent-runs/20260525T005918Z-supabase-status-redacted-task-TASK-122-p6091.md`
  - `docs/TASKS/EVIDENCE/TASK-122/agent-runs/20260525T005920Z-supabase-verify-schema-profile-local-task-TASK-122-p6459.md`
  - `docs/TASKS/EVIDENCE/TASK-122/agent-runs/20260525T005927Z-supabase-verify-rls-profile-local-task-TASK-122-p6980.md`
  - `docs/TASKS/EVIDENCE/TASK-122/agent-runs/20260525T005929Z-supabase-verify-grants-profile-local-task-TASK-122-p7338.md`
- Supabase live scoped write acceptance: `BLOCKED_EXTERNAL`.
- No `MC_ALLOW_LIVE=1` live TASK122_* write flow was executed in this hardening pass.
- No live rows were created, modified, or deleted.
- Cleanup data test: not applicable; no live test data was created.
- NEXT_ACTION: run scoped live acceptance with authenticated app session, `MC_ALLOW_LIVE=1`, prefix `TASK122_*`, before/after evidence, and cleanup scoped to that prefix only.
