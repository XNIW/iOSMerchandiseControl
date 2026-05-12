# Supabase Migration Drift Analysis

## Result

The linked migration registry remains out of sync with the local migration filenames, but read-only schema introspection shows the live objects required by the drifted migrations are present and coherent. No `supabase db push`, `migration repair`, reset, truncate or data mutation was performed.

## Drift Observed

| Migration | Registry state | Live/schema interpretation |
|---|---|---|
| `20260417_task012_ownership_rls.sql` | Local-only in registry list | `shared_sheet_sessions.owner_user_id` and owner CRUD policies exist live. |
| `20260424021936_task045_sync_events.sql` | Local-only; remote has `20260424145010` | Remote registry row name is `task045_sync_events`; live `sync_events`, RPC, policy and realtime-related objects are present. This is timestamp/registry drift, not missing schema. |
| `20260509120000_task086_inventory_catalog_updated_at_triggers.sql` | Local-only in registry list | `set_inventory_catalog_updated_at()` and inventory updated-at triggers exist live. |
| `20260511030000_task101_revoke_rls_auto_enable_public_execute.sql` | Local-only in registry list | Live grants already reflect the remediation: `rls_auto_enable()` EXECUTE remains only for elevated DB roles. |

## Evidence

- `supabase-linked-migration-list.txt`
- `supabase-linked-drift-introspection.txt`
- `supabase-local-drift-introspection.txt`
- `supabase-linked-db-lint.txt`
- `supabase-local-db-lint.txt`

## Decision

F101-02 is closed as non-blocking registry/history drift for TASK-101 production-readiness. A future backend Ops pass may repair migration history deliberately, but that is not required for iOS client readiness and must not be done blindly.
