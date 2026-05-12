# Owner Scope Matrix

| Resource | Owner source | Server policy | Client defense-in-depth | Result |
|---|---|---|---|---|
| `inventory_suppliers` | `session.user.id` / payload owner | `auth.uid() = owner_user_id` | iOS fetch/update/read-back/debug TASK-045 queries add owner filter; create payload owners are validated against the authenticated session | PASS |
| `inventory_categories` | `session.user.id` / payload owner | `auth.uid() = owner_user_id` | iOS fetch/update/read-back/debug TASK-045 queries add owner filter; create payload owners are validated against the authenticated session | PASS |
| `inventory_products` | `session.user.id` / payload owner | `auth.uid() = owner_user_id` | iOS fetch/update/read-back/debug TASK-045 queries add owner filter; create payload owners are validated against the authenticated session | PASS |
| `inventory_product_prices` | `session.user.id` / payload owner | `auth.uid() = owner_user_id` | iOS price preview page now adds owner filter | PASS |
| `shared_sheet_sessions` | Android/iOS auth user | owner RLS for CRUD | No iOS production write changed in TASK-101 | PASS |
| `sync_events` | RPC derives `auth.uid()` | owner SELECT RLS; direct writes unavailable to `authenticated` | iOS outbox owner required and sanitized; plan-derived `client_event_id` values hash raw catalog fingerprints | PASS |

Legacy tables without owner columns are fail-closed by RLS-no-policy for ordinary client roles and should remain out of app consumer paths.
