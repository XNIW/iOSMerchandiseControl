# TASK-122 Before/After Architecture Map

## Before
- `SupabaseTransportClient.swift`: 1866 LOC, domain protocol conformances, catalog/ProductPrice/history/sync-event/manual/debug query ownership.
- Remote adapters existed but mainly delegated to the transport.

## After
- `SupabaseTransportClient.swift`: 136 LOC, thin transport for client/session/error mapping.
- Catalog adapter owns catalog create/update/fetch/read-back query behavior.
- ProductPrice adapter owns keyset preview, paging, manual push verification, dry-run dedupe and product read-back update behavior.
- History adapter owns shared session upsert/fetch/by-ID behavior.
- SyncEvent adapter owns sync_events incremental fetch, reconciliation counts and composition of incremental domain readers.
- Recovery adapter supplies full-pull preview reads without making the transport a domain protocol owner.

## Net Simplification
The transport no longer conforms to domain protocols and no longer contains table-specific domain methods. Domain ownership is visible in adapter files and enforced by TASK-122 scanners.
