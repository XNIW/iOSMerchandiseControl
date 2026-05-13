# TASK-107 Implementation Notes

## UI
- Added segmented Database navigation with native SwiftUI `Picker` in segmented style.
- Product search keeps scanner button; supplier/category search removes scanner and uses the full width.
- Supplier/category rows are native list rows with icon, name, linked product count and chevron.
- Add/rename/delete uses a shared SwiftUI `Form` sheet.

## Data Behavior
- Supplier/category creation records local pending changes with `manualCatalogSave`.
- Rename records update changes for remote-linked entities.
- Rename of local-only create changes retargets the existing pending create instead of creating duplicate pending entries.
- Delete without linked products deletes directly after confirmation.
- Delete with linked products offers three explicit choices: replace with an existing supplier/category, create a replacement and move linked products, or remove the assignment before deleting.
- Replacement/removal records product pending updates for the affected relation, then records the supplier/category delete.
- Delete of local-only unsynced create coalesces through existing pending-change behavior.
- Price history can insert a new history row and update the current purchase/retail price from the same sheet.
- Saving a price identical to the current value records only the ProductPrice pending change, not a redundant Product pending update.

## Performance
- Supplier/category linked product counts are precomputed per section and read by row lookup.
- Replacement candidates are filtered from precomputed supplier/category arrays and exclude the item being deleted.
- No new dependencies, no custom layout engine, no schema changes.

## Final review notes - 2026-05-13
- Delete advanced flow preserves products: replace existing, create replacement, and remove assignment all operate on relations before supplier/category deletion.
- Pending changes remain coherent with reviewed behavior: supplier/category create/update/delete are recorded, product relation updates are recorded when reassignment/removal changes linked products, and ProductPrice is recorded when a current price is added from history.
- `Update current price` records a Product pending update only when the current purchase/retail value actually changes; same-price history insertion avoids redundant Product updates.
- `LocalPendingAggregatedPushStateStore` was converted to `struct` because the final targeted pending-change test exposed a deallocation crash and the store has no identity/state semantics.
- Android parity is native-platform equivalent rather than UI-copy: Edit product opens Price history, Price history has one contextual update action, and repository tests cover current-price update plus history insertion.
