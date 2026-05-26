# TASK-125 Supabase Cross-platform Contract

- Status: `BLOCKED_EXTERNAL`
- Task: `TASK-125`
- Redaction applied: `true`
- Generated: `2026-05-26T00:57:09Z`

Linked schema was reachable, but linked RLS/grants contract could not be fully verified due pooler/auth circuit breaker. Local contract checks passed.

## Referenced agent runs
- `PASS` — `supabase verify-schema --task TASK-125 --profile linked` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T004148Z-supabase-verify-schema-task-TASK-125-profile-linked-p27203.json`
- `BLOCKED_EXTERNAL` — `supabase verify-rls --task TASK-125 --profile linked` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T004148Z-supabase-verify-rls-task-TASK-125-profile-linked-p27204.json`
- `BLOCKED_EXTERNAL` — `supabase verify-grants --task TASK-125 --profile linked` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T004148Z-supabase-verify-grants-task-TASK-125-profile-linked-p27211.json`
- `PASS` — `supabase verify-rls --task TASK-125 --profile local` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T004516Z-supabase-verify-rls-task-TASK-125-profile-local-p29138.json`
- `PASS` — `supabase verify-grants --task TASK-125 --profile local` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T004516Z-supabase-verify-grants-task-TASK-125-profile-local-p29139.json`

## Next action
Resolve linked Supabase pooler/auth and rerun cross-platform contract gate.
