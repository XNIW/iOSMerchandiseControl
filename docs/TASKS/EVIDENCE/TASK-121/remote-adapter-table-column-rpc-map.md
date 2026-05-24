# TASK-121 remote adapter table/column/RPC map

Generated during the final anti-false-positive review/fix pass on 2026-05-24.

Read-only contract evidence: `20260524T190040Z-supabase-contract-sync-schema-task-TASK-121-read-only-p43917`.

No schema, RLS, grant, RPC, migration, or live cleanup change was made.

| Adapter / host | Owner | Tables / RPC | Column contract source |
| --- | --- | --- | --- |
| `CatalogRemoteSupabaseAdapter` | Automatic catalog writes | `inventory_suppliers`, `inventory_categories`, `inventory_products` | Delegates to `SupabaseTransportClient` methods using existing supplier/category/product column strings. |
| `ProductPriceRemoteSupabaseAdapter` | Automatic product price writes | `inventory_product_prices` | Delegates existing automatic product-price insert contract. |
| `HistorySessionRemoteSupabaseAdapter` | History session push/pull | `shared_sheet_sessions` | Delegates existing `sharedSheetSessionColumns`. |
| `SyncEventRemoteSupabaseAdapter` | Automatic incremental pull/reconcile | `sync_events`, `inventory_*`, `shared_sheet_sessions` | Delegates event fetch, catalog/product-price/history fetch and reconciliation methods. |
| `SupabaseTransportClient.swift` | Remote transport host | `inventory_suppliers`, `inventory_categories`, `inventory_products`, `inventory_product_prices`, `shared_sheet_sessions`, `sync_events` | Existing static column selections and typed row DTOs moved under `Sync/Remote`. |
| `SupabaseSyncEventRPCTransport.swift` | Remote event transport | sync-event RPC surface | Moved under `Sync/Remote`; no RPC definition or schema mutation added. |

RPC/schema mutation scanner status:
- `sync_tables_mapped`: PASS
- `no_schema_mutation_in_sources`: PASS

Schema/RLS/grant/RPC/migration status: NOT_RUN for live mutation by design; not counted as PASS.
