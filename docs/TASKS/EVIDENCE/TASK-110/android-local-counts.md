# TASK-110 — Android Local Counts

Checkpoint: 2026-05-15 12:15 -0400.

Dispositivo: Android fisico `8ac48ff0` (OnePlus IN2013).

Database Room copiato temporaneamente in:
`/tmp/task110_android_8ac48ff0/app_database`

## Counts

| Tabella | Count |
|---|---:|
| `history_entries` | 7 |
| `history_entry_remote_refs` | 6 |
| `products` | 19695 |
| `product_remote_refs` | 19695 |
| `suppliers` | 78 |
| `supplier_remote_refs` | 78 |
| `categories` | 42 |
| `category_remote_refs` | 42 |
| `product_prices` | 39498 |
| `product_price_remote_refs` | 39498 |
| `pending_catalog_tombstones` | 0 |
| `sync_event_outbox` | 0 |
| `sync_event_watermarks` | 0 |

## History sync state

| Classificazione locale | Count |
|---|---:|
| History total | 7 |
| Con remote ref | 6 |
| Senza remote ref | 1 |
| Ref dirty (`localChangeRevision > lastSyncedLocalRevision` o mai applicata) | 0 |
| Ref clean secondo metadata locale | 6 |

## Delta rispetto a Supabase/iOS

- Supabase `shared_sheet_sessions`: 1.
- iOS `HistoryEntry`: 1.
- Android `history_entries`: 7.
- Quindi Android contiene 6 sessioni locali extra rispetto al remoto/iOS.
- Almeno 5/6 sessioni con remote ref risultano clean localmente ma non sono presenti in Supabase: questo crea sessioni invisibili al push perché la logica attuale spinge solo dirty/pending.

## Catalog/prices

- Products allineati a Supabase: 19695.
- Suppliers/categories locali Android superiori al remoto/iOS: 78 vs 57 suppliers, 42 vs 27 categories.
- Product prices Android inferiori al remoto/iOS: 39498 vs 41109.
- Questo conferma drift catalog/prices Android, separato dal mismatch progetto.
