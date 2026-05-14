# TASK-108 Evidence 30 — Large ProductPrice Bootstrap Pagination

Status: PARTIAL LIVE / CODE + TEST PASS, baseline live retry blocked by app-auth.

Timestamp: 2026-05-13 22:45 -0400.

## Limit audit

Found and changed:
- `SupabasePullPreviewService.Configuration.productPriceRowBudget` had been used as a total ProductPrice preview budget. It had already moved through fixed values during the attempted live bootstrap and was the wrong control point.
- `iOSMerchandiseControlApp.swift` wired the Release preview with a bounded ProductPrice cap. This is now a preview sample limit, not a total remote-history limit.
- `SupabaseProductPriceApplyService.ProductPriceApplyFetchOptions` had `maxRows` / `maxPages` for preview/dry-run planning. Those remain only for preview samples; full bootstrap apply now uses the new paged full-pull path.
- Existing `priceHistoryIncomplete` source-error behavior remains for truly incomplete legacy previews, but the normal large-history path now emits `priceHistoryPagedApplyRequired` as a warning and downloads the full price history during apply.

No `25_000` / `100_000` total ProductPrice cap remains in the Release full-pull decision path.

## Code change

Preview:
- Fetches bounded catalog pages as before.
- Fetches only a bounded ProductPrice sample (`1,000`) for signals and blocker detection.
- Adds warning `priceHistoryPagedApplyRequired` when the sample is full.
- Does not fail preview only because the remote ProductPrice history is larger than the sample.

Apply:
- `SupabaseProductPriceApplyService.applyPagedFullPull(...)` fetches `inventory_product_prices` page by page.
- Page size is bounded to `1,000` rows to keep memory and SwiftData batch size controlled.
- Uses stable Supabase ordering already exposed by the transport (`product_id`, `type`, `effective_at`, `id`) and offset/range paging.
- Saves SwiftData after each page with mutations.
- Checks cancellation between pages.
- Treats page fetch/save failures as apply failures; baseline is still written outside this service only after catalog + ProductPrice apply return successfully.

Baseline:
- `SupabaseCatalogBaselineWriter` now writes baseline records in batches (`1,000` default) and verifies persisted count with `fetchCount`, instead of inserting the whole baseline snapshot in one save.

UI:
- Options review can show ProductPrice progress messages such as `Price history: N / total rows downloaded` when total count is available.
- When the baseline is absent and the review is safe to apply, the public CTA is titled `Scarica database dal cloud` / `Download cloud database` while still opening the confirm/review sheet.

## Automated tests

PASS:
- `SupabasePullPreviewPaginationTests/testLargeProductPriceHistorySampleDoesNotMakePreviewPartialOrSourceError`
- `SupabaseProductPriceApplyServiceTests/testPagedFullPullAppliesLargeProductPriceHistoryWithoutFixedTotalLimit`
- `SupabaseProductPriceApplyServiceTests/testPagedFullPullCanCancelLargeProductPriceHistoryWithoutFixedTotalLimit`
- `SupabaseCatalogBaselineWriterReaderTests/testLargeCommitWritesBaselineRecordsInBatches`
- `SupabaseManualSyncViewModelTests/testTask108BaselineAbsentUsesDownloadCopyForApplicableReviewCTA`

Result logs:
- `/tmp/task108-large-price-targeted-final.log`
- `/tmp/task108-baseline-batch-2.log`
- `/tmp/task108-download-copy-2.log`

## Live app-auth observation

After the user completed app-auth manually, authenticated remote preview succeeded:
- Remote catalog preview: 19,888 products, 101 suppliers, 64 categories.
- ProductPrice preview sample: 1,000 rows.
- Preview outcome: complete, not partial, no source errors, one large-history warning.

Local apply was started from the review sheet:
- Catalog applied locally: 19,886 products, 79 suppliers, 47 categories.
- ProductPrice rows present locally after paged apply: 53,022.
- Logical duplicate check on local ProductPrice (`product`, `type`, `effective_at`): 0 duplicate groups.
- ProductPrice rows with duplicate remote IDs: 0 duplicate groups.
- Supabase data created/modified/deleted: none.

Baseline live state:
- Baseline before the new batched writer fix: not written (`0` baseline runs / `0` baseline records).
- The baseline writer was fixed and verified by automated test after this live observation.
- A fresh app-auth retry to complete baseline verification was attempted, but the simulator returned to OAuth/Google credential flow and no authenticated app session was available after rebuild.

Current live verdict:
- Fixed-cap blocker: RESOLVED in code and partially verified live; live apply reached 53,022 ProductPrice rows instead of stopping at a fixed cap.
- Full live bootstrap PASS: NOT CLAIMED because baseline commit with the new batched writer was not re-run under a completed app-auth session.
- Required next live step: sign in again, run `Scarica database dal cloud`, and verify baseline records become valid after the paged apply completes.

## Final keyset/apply live update — 2026-05-14 12:34 -0400

The missing app-auth rerun was completed through the public Options flow.

Changes since the previous partial evidence:
- ProductPrice full apply now uses keyset paging by `id` with page size `900`.
- The UI no longer returns idle without a terminal result.
- Postgres timestamp variants are decoded.
- Tombstoned-product ProductPrice rows are skipped explicitly.
- Baseline is refreshed in Options after manual sync completion.

Live result:
- Remote ProductPrice total: `290,955`.
- ProductPrice rows with remote IDs in local SwiftData after completion: `290,953`.
- Skipped remote ProductPrice rows: `2`, both tied to tombstoned remote products.
- Total local ProductPrice rows after completion: `328,589` because local history includes existing/local rows in addition to remote-linked rows.
- Baseline runs: `1`.
- Baseline records: `20,012` (`19,886 product`, `79 supplier`, `47 productCategory`).
- Final Options card: `Database locale aggiornato`, `Ultimo pull completo: 14 mag 2026, 12:33`.

Verdict:
- Large ProductPrice fixed-cap and silent-exit bug: **PASS live**.
- Global TASK-108 live E2E: **not claimed** in this file.
