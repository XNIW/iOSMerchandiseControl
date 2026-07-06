# TASK-135 Final Delete Smoke

Verdict: CHANGES_REQUIRED

## History delete/tombstone

- iOS -> Supabase -> Android: PASS
  - Fixture: `TASK135_DELETE_HISTORY_IOS_20260618T152426Z`
  - Remote id: `3b92fec8-ca29-40d1-979d-7d9370beefee`
  - Supabase `deleted_at`: `2026-06-18 15:28:01+00`
  - Android Room row has `deletedAt=2026-06-18T15:28:01+00:00`

- Android -> Supabase -> iOS: PASS
  - Fixture: `TASK135_DELETE_HISTORY_ANDROID_20260618T153334Z`
  - Remote id: `5fcc2ac6-dbce-457c-8eb6-f79515787ff3`
  - Supabase `deleted_at`: `2026-06-18 15:40:00+00`
  - iOS SwiftData row has `ZREMOTEDELETEDAT=803490000`

## Product delete/tombstone

- iOS create Product + 2 ProductPrice rows: PASS
  - Fixture: `TASK135_DELETE_PRODUCT_IOS_20260618T152426Z`
  - Supabase create observed: product active = 1, price rows = 2
  - Android received product row.

- iOS delete Product: FAIL
  - iOS local state after delete: Product row removed, linked ProductPrice rows removed, pending `product/delete/tombstone` remained.
  - Supabase after 18 polls: Product still active, `deleted_at=null`; ProductPrice rows still present.
  - Android after delete: Product still visible locally.
  - Local pending evidence: iOS had one pending `product/delete`.

Observed root cause candidate:

- `iOSMerchandiseControl/Sync/Automatic/Catalog/CatalogPushService.swift` fetches a local `Product` before handling `change.operation == .delete`.
- The UI delete path in `DatabaseView.confirmDeleteProducts()` records the pending delete and then `context.delete(product)`.
- Therefore the automatic push cannot find the deleted local Product and skips the pending tombstone instead of sending `deleted_at`.

## Android product branch

- Direct Room seed for Android Product was not accepted as a valid product-create smoke:
  - History seed pushed, but Product seed stayed local with missing remote ref and 2 price rows missing refs.
  - Runtime only ran `sync_events_drain`; no catalog push was triggered by the out-of-band DB seed.
  - This branch was not used to judge Android Product delete.

## Cleanup

- Remote cleanup removed the failed iOS Product fixture residue:
  - Supabase tombstoned 1 Product fixture.
  - Supabase deleted 2 ProductPrice fixture rows.
- Local cleanup removed fixture products/pending:
  - iOS pending after cleanup: empty.
  - Android pending after cleanup: `pending_tombstones=0`, `product_pending=0`, `price_missing_refs=0`.
- Clean reopen wait:
  - `sync_events` remained `1852`, max id `3104`.
  - Supabase active products restored to `19704`; ProductPrice rows restored to `41133`.

