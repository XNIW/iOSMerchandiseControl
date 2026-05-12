# Grants Audit

## Table Grants

| Object group | Observed grants | Assessment |
|---|---|---|
| Core inventory tables | `authenticated`: INSERT, SELECT, UPDATE. No DELETE. `service_role`: broad operational privileges. | PASS for client least privilege. |
| `sync_events` | `authenticated`: SELECT only; writes through RPC. | PASS. |
| `shared_sheet_sessions` | `authenticated`: DELETE, INSERT, SELECT, UPDATE. `anon`: SELECT grant exists but RLS owner policy makes anon fail closed. | PASS_WITH_CAVEAT. Prefer revoking anon SELECT later. |
| Legacy public tables/views | Broad grants to anon/authenticated/elevated DB roles on old objects, but RLS has no policies on legacy tables. | CLOSED_NON_BLOCKING_OPS; not a cross-tenant leak under current fail-closed RLS. |

## Function Grants

Before TASK-101 remediation:

- `record_sync_event(...)`: SECURITY DEFINER, EXECUTE for `authenticated`, `postgres`, `service_role`.
- `rls_auto_enable()`: SECURITY DEFINER, EXECUTE for `PUBLIC`, `anon`, `authenticated`, `postgres`, `service_role`.

After TASK-101 remediation:

- `record_sync_event(...)`: unchanged, intentional RPC contract.
- `rls_auto_enable()`: EXECUTE only for `postgres`, `service_role`; verified live after `REVOKE`.

Final linked/local lint rerun with Supabase CLI 2.98.2 returned no schema errors. Migration registry drift remains documented in `supabase-migration-drift-analysis.md` and is not treated as a live privilege regression.

## Live DDL Applied

```sql
do $$
begin
  if to_regprocedure('public.rls_auto_enable()') is not null then
    revoke execute on function public.rls_auto_enable()
      from public, anon, authenticated;
  end if;
end;
$$;
```

Rollback if required:

```sql
grant execute on function public.rls_auto_enable()
  to public, anon, authenticated;
```
