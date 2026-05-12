# Live Write / Delete Safety Audit

## TASK-101 Live Operations

| Operation | Type | Data rows affected | Scope | Result |
|---|---|---:|---|---|
| Supabase metadata queries | Read-only | 0 | RLS/grants/functions/migrations | PASS |
| `REVOKE EXECUTE` on `rls_auto_enable()` | DDL privilege hardening | 0 | Function grants only | PASS |

No catalog/product/price/session/sync-event test rows were inserted, updated, deleted, truncated or exported in TASK-101.

## Current Policy

- App live writes must use authenticated user session, publishable key, scoped prefix for synthetic datasets when tests are needed, collision scan before first write and redacted evidence.
- Inventory DELETE remains blocked for `authenticated`; cleanup of remote test rows must use documented operator/admin path and scoped predicates.
- Never use service-role/admin material in the consumer app.

## Rollback For DDL Remediation

If the function grant revocation needs rollback:

```sql
grant execute on function public.rls_auto_enable()
  to public, anon, authenticated;
```

