# TASK-135 Catalog/Product Delete Architecture Audit

Evidence root: `docs/TASKS/EVIDENCE/TASK-135-catalog-delete-architecture-20260618-120948/`

## iOS

- `DatabaseView.swift` uses a hard-delete UX path for Product delete: it records a pending catalog delete/tombstone and then deletes the SwiftData `Product` row with `context.delete(product)`.
- `LocalPendingChange` already stores the important bridge data for a remote-linked product delete: entity kind, operation, logical key, `entityRemoteID`, changed fields, change id, and owner-scoped pending state.
- Before this fix, `CatalogPushService` handled product delete only after `findProduct(for:)`. If the Product had already been hard-deleted, the pending delete was skipped and no Supabase tombstone was sent.
- ProductPrice rows are historical/append-only in the current sync contract. Active ProductPrice counts are scoped to active Products; tombstoning a Product must not create a fake ProductPrice pending row.

Answer to audit questions:
- iOS delete model: hard delete locally after pending tombstone registration.
- Pending registration: `DatabaseView.swift` / pending change accumulator.
- Tombstone sender: `CatalogPushService`.
- Local Product required after delete before fix: yes, incorrectly.
- ProductPrice after delete: retained as history; active count excludes deleted Products; no ProductPrice false pending expected.
- Clean reopen recreation risk before fix: yes, because Supabase stayed active and Android/iOS could pull the Product again.

## Android

- Android has first-class `pending_catalog_tombstones` and repository delete flow records tombstones with remote refs before removing/hiding the active Product row.
- The normal catalog sync path drains pending catalog tombstones before active product upserts.
- The fallback quick-sync/realign path in `pushDirtyCatalogDeltaToRemote(...)` did not drain pending tombstones before active product push, so the architecture was mostly correct but one sync path could miss Product delete work.
- ProductPrice remains append-only/historical; active counts and pending checks are guarded so deleted Product rows do not create ProductPrice false pending.

Answer to audit questions:
- Android delete model: first-class tombstone pending plus local non-visible deleted state.
- Pending registration: repository delete path and `pending_catalog_tombstones`.
- Tombstone sender: catalog tombstone drain in repository sync path.
- Local Product required after delete before fix: not for the normal tombstone drain; fallback path missed the drain.
- ProductPrice after delete: retained as history; active count excludes deleted Products; no false pending expected.
- Clean reopen recreation risk before fix: lower than iOS, but fallback realign could leave tombstone work undrained.

## Supabase

- `inventory_products.deleted_at` is the product tombstone source of truth.
- Client RLS/grants allow owner-scoped SELECT/INSERT/UPDATE and deny hard DELETE.
- `inventory_product_prices` is append-only/historical for this scope. Active parity counts join only active products.
- `sync_events` supports `catalog_tombstone`; no service role or RLS bypass is required by the runtime.

## Architecture Drift

iOS and Android both intended delete/tombstone as a pending/outbox operation, but iOS still depended on the local Product row at push time. Android had the correct first-class tombstone model in the normal path, with one fallback quick-sync gap. The fix aligns both platforms on the same invariant: a pending delete with a remote id is sufficient to send an idempotent Product tombstone without recreating the Product.
