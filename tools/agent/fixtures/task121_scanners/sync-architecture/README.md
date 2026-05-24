# sync-architecture TASK-121 fixture

expected RED status: FAIL or MISCONFIGURED
expected GREEN status: PASS or PASS_WITH_NOTES
expected exit code: RED non-zero, GREEN zero
NEXT_ACTION: maintain scanner-specific regression fixtures here.

RED coverage must include a renamed Remote transport that is still a
multi-domain mega-service. GREEN coverage must represent a thin transport host
with domain-specific Supabase operations owned by focused adapters.
