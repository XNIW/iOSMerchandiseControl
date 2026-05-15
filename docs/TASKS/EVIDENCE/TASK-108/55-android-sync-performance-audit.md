# TASK-108 Evidence 55 - Android sync performance audit

Timestamp: 2026-05-14 13:23 -0400  
Repo: `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView`

## ProductPrice pull before patch

Files:

- `InventoryRepository.kt`
- `ProductPriceRemoteDataSource.kt`
- `SupabaseProductPriceRemoteDataSource.kt`

Finding:

- Production remote data source fetched `inventory_product_prices` through the generic all-pages helper, then returned a full `List<InventoryProductPriceRow>`.
- Repository `pullProductPricesFromRemote` then applied the complete list in one pass.
- This meant Android could materialize the whole ProductPrice remote list in memory before Room apply.

This was less memory-efficient than the iOS keyset/page apply path after the TASK-108 iOS fixes.

## Patch applied

Android now has a paged ProductPrice pull API:

- `ProductPriceRemoteDataSource.fetchProductPricesPage(afterId, limit)` with default fallback for fakes.
- `SupabaseProductPriceRemoteDataSource.fetchProductPricesPage` uses PostgREST:
  - `gt("id", afterId)` when present
  - `order("id", ASCENDING)`
  - `range(0, limit - 1)`
  - limit capped to `INVENTORY_REMOTE_PAGE_SIZE`
- `InventoryRepository.pullProductPricesFromRemote` loops pages, applies each page, advances `lastRemoteId`, and logs `pageSize` / `pageCount`.

## Current Android sync traits

| Area | Observation |
|---|---|
| Page size | Uses shared `INVENTORY_REMOTE_PAGE_SIZE` (`900`) for remote table paging. |
| Keyset vs offset | ProductPrice pull is now keyset by remote `id`; previous complete-list path still exists as interface fallback/testing compatibility. |
| Threading | Repository sync paths use `Dispatchers.IO`. |
| Room batching | Page apply is wrapped in Room transaction per page. |
| Progress | `CatalogSyncProgressReporter` receives running phase/count; ProductPrice total is unknown in streamed mode. |
| Logging | Existing `sync_start`, `sync_stage`, `sync_finish`, and `phase_metrics`; ProductPrice pull now logs page size/count. |
| Memory behavior | Remote ProductPrice list is no longer materialized as one complete production list. Per-page Room work remains 900 rows. |
| Outbox | Retry/backoff and head-of-line retryable logic already exist from prior tasks. No schema/RPC change here. |
| History/session | Existing sync paths remain unchanged; this pass did not alter History/session behavior. |
| Options local status | Already added in previous TASK-108 pass; no new UI change in this pass. |

## Remaining limits

- ProductPrice apply still does DAO lookups per row within a 900-row transaction. This is bounded but not fully bulk-indexed.
- Live Android app-auth sync was not rerun, so Android ProductPrice duration/rows/sec remains unmeasured in this pass.

