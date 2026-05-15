# TASK-110 Fix Completion — 42501 Post-Fix

Timestamp: 2026-05-15 13:12 -0400.

## Expected negative tests

After revoking anon access from private app tables, anon Data API requests return `42501`.

This is expected and must be classified by clients as a permission/grant issue, not as network failure or user cancellation.

| Table | Role | Result | Classification |
|---|---|---|---|
| `shared_sheet_sessions` | anon | `42501 permission denied` | permission issue |
| `product_prices` legacy | anon | `42501 permission denied` | permission issue |
| `inventory_products` | anon | `42501 permission denied` | permission issue |

## Client requirement

Android/iOS UI must not show stale `Operation cancelled` for `42501`. The correct user-facing state is `Permission issue`, with technical details in disclosure/log.
