# supabase-contract TASK-121 fixture

expected RED status: FAIL
expected GREEN status: PASS
expected exit code: RED non-zero, GREEN zero

RED cases:
- `red-task120-fallback/fixture.txt` represents `supabase contract sync-schema --task TASK-121 --read-only` using TASK-120 fallback scanner logic.

GREEN case:
- `green-task121-reconciliation-pass/fixture.txt` represents TASK-121 reconciliation PASS via `task121_scans.py`.

NEXT_ACTION: fail TASK-121 Supabase contract when routing falls back to TASK-120 or internal reconciliation is not PASS.
