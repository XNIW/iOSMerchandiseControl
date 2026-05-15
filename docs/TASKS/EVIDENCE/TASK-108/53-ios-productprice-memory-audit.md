# TASK-108 Evidence 53 - iOS ProductPrice memory audit

Timestamp: 2026-05-14 13:23 -0400  
Scope: `SupabaseProductPriceApplyService.swift` full ProductPrice pull/apply memory and performance path.

## Findings before patch

The ProductPrice keyset full pull already had good remote paging properties:

- keyset query available through `id > lastID`
- stable `id ASC` ordering
- `pageSize = 900`
- progress published per page/stage, not per row
- privacy-safe redacted UUID logs
- save per page

The expensive local side still retained large structures for the whole run:

1. `productsByRemoteID = [UUID: Product]` held SwiftData model objects globally.
2. `currentPricesByKey` held a global lookup over all local `ProductPrice` history.
3. `seenRemoteIDs = Set<UUID>()` held all remote ProductPrice IDs across the whole run.
4. The long-running apply path reused the app context for the full run, increasing SwiftData retention risk.

## Patch applied

File: `iOSMerchandiseControl/SupabaseProductPriceApplyService.swift`

- Replaced global `Product` model map in paged full pull with global `remote product UUID -> PersistentIdentifier` map, built through a separate lookup context instead of retaining all products in the app context.
- For every remote page, created a short-lived `ModelContext(context.container)`.
- For every remote page, loaded only products referenced by that page.
- Built `currentPricesByKey` only from page-local product price histories.
- Replaced global `seenRemoteIDs` with `pageSeenRemoteIDs`.
- Kept save boundary at page level and retained `Task.yield()` between pages.

Key implementation references:

- `applyPagedFullPull`: page-scoped context and lookup around lines 769, 848-887.
- `fetchUniqueProductIdentifiersByRemoteID`: line 1118.
- `fetchPageProductsByRemoteID`: line 1191.
- `makeCurrentPriceInfosByKey`: line 1212.

## Remaining limits

- `productIDsByRemoteID` is still global, but it stores `PersistentIdentifier`, not full `Product` graphs. It is also built in a separate lookup context. This is a deliberate bounded compromise because ProductPrice rows need fast remote product mapping.
- Tombstoned product IDs are still fetched as a set when the fetcher supports it. Previous live run had only 2 skipped ProductPrice rows tied to tombstoned products; no evidence of a large tombstone set in current data.
- SwiftData does not expose a direct context reset equivalent. The mitigation is page-scoped contexts and no cross-page model object retention.
- No new full live 290k ProductPrice rerun was completed after this patch, so peak RSS improvement is not claimed as measured.

## Verdict

Memory retention issue found and fixed in the ProductPrice full pull apply path. The fix is verified by targeted 30k/idempotence tests, but live memory improvement still requires a fresh authenticated full pull profile.
