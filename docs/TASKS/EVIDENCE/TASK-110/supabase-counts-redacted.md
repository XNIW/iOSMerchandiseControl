# TASK-110 — Supabase Counts Redacted

Checkpoint: 2026-05-15 12:15 -0400.

Owner osservato: `bf727712...257e`

| Oggetto | Total | Active | Deleted/Tombstone |
|---|---:|---:|---:|
| `shared_sheet_sessions` | 1 | n/a | schema senza `deleted_at` |
| `inventory_suppliers` | 57 | 57 | 0 |
| `inventory_categories` | 27 | 27 | 0 |
| `inventory_products` | 19695 | 19695 | 0 |
| `inventory_product_prices` | 41109 | n/a | n/a |
| `sync_events` | 0 | n/a | n/a |
| `product_prices` legacy senza owner | 0 | n/a | n/a |

## Note
- `shared_sheet_sessions` non ha `deleted_at`: delete History cross-platform non può essere tombstone-based senza migration o altra policy remota.
- `inventory_*` hanno `deleted_at` dove necessario per catalogo.
- `inventory_product_prices` è append-only/idempotente con vincolo unico owner/product/type/effective_at.
