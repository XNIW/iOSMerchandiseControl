# TASK-135 Catalog/Product Delete Target Architecture

Evidence root: `docs/TASKS/EVIDENCE/TASK-135-catalog-delete-architecture-20260618-120948/`

## Contract

Catalog create/update may depend on the complete local Product row. Catalog delete/tombstone must not.

A Product delete is a first-class pending/outbox operation. The pending delete must contain enough data to send and acknowledge the remote tombstone without requiring the local Product to still exist:

- owner/user scope
- entity kind = product
- operation = delete
- remote id when the Product is cloud-linked
- logical key
- change id/idempotency context
- changed fields containing `tombstone`
- baseline fingerprint/version if available
- tombstone timestamp or server-side deleted_at payload

## Push Rules

- If the delete has a remote id, send an owner-scoped Supabase update that sets `inventory_products.deleted_at`.
- Handle the delete branch before any local Product lookup.
- Do not recreate the Product during delete push.
- If the local Product still exists, apply the returned remote tombstone metadata to it; if it is already hard-deleted, still ack the pending delete.
- If the delete is local-only and has no remote id, ack it without a remote call.
- If a remote-linked Product should have a remote id but it is missing, keep the pending/conflict visible to the sync system rather than pushing a blind create.

## Platform Mapping

- iOS: `CatalogPushService` owns automatic Product tombstone push. It now handles `.delete` before `findProduct`, uses `entityRemoteID` or a remote id recovered from logical key, sends `deleted_at`, and acknowledges success even when the SwiftData Product is already gone.
- Android: repository tombstone drain is the canonical delete push path. The fallback `pushDirtyCatalogDeltaToRemote(...)` realign path now drains pending catalog tombstones before active product push, matching the normal path.
- Supabase: `inventory_products.deleted_at` is the tombstone. No client hard DELETE, no service role, no RLS bypass.

## ProductPrice

ProductPrice rows remain append-only/historical in this task. Product tombstone must not create ProductPrice pending work. Active ProductPrice counts are calculated only for active Products, so historical prices linked to tombstoned Products do not count as active parity drift.

## Clean Reopen Invariant

After a Product tombstone is acknowledged:

- local pending delete is zero
- Supabase Product has `deleted_at != null`
- receiver platform hides or tombstones the Product
- ProductPrice creates no false pending
- clean reopen does not recreate the Product
- `sync_events` does not grow without a real mutation

This architecture was verified with repository/XCTest/instrumentation harnesses, not direct DB seed.
