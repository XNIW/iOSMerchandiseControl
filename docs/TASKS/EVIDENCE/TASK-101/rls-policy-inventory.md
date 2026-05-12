# RLS Policy Inventory

Live query source: `pg_class` + `pg_policy` on linked Supabase project.

| Table | RLS | Policies observed | TASK-101 assessment |
|---|---|---|---|
| `inventory_suppliers` | enabled | `select_owner`, `insert_owner`, `update_owner` for `authenticated`, all `auth.uid() = owner_user_id` | PASS |
| `inventory_categories` | enabled | `select_owner`, `insert_owner`, `update_owner` for `authenticated`, all `auth.uid() = owner_user_id` | PASS |
| `inventory_products` | enabled | `select_owner`, `insert_owner`, `update_owner` for `authenticated`, all `auth.uid() = owner_user_id` | PASS |
| `inventory_product_prices` | enabled | `select_owner`, `insert_owner`, `update_owner` for `authenticated`, all `auth.uid() = owner_user_id` | PASS |
| `shared_sheet_sessions` | enabled | owner-scoped `select`, `insert`, `update`, `delete` for `authenticated` | PASS |
| `sync_events` | enabled | owner-scoped `select` for `authenticated` | PASS |
| `products`, `categories`, `suppliers`, `history_entries`, `product_prices` | enabled | none | FAIL-CLOSED for anon/authenticated; legacy least-privilege cleanup remains |

## Notes

- Inventory DELETE remains intentionally unavailable to `authenticated`, matching TASK-038/TASK-100 behavior.
- `product_price_summary` is a view with `security_invoker=true`; it depends on underlying RLS.

