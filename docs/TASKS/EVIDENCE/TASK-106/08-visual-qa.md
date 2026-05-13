# TASK-106 Visual QA

## Before
- `01-before-current-database.png` captures the current Database screen before the fix after simulator data reset.
- It is an empty-state capture to avoid real data exposure.

## After
- `03-after-fixed-database.png` captures the fixed Database screen with synthetic populated data on iPhone 15 Pro Max iOS 26.1.
- The current after screenshot reflects review feedback: lighter scanner button, reduced search-to-list spacing, compact product card, inline barcode/item code, supplier/category names without textual prefixes, no visible `Edit` button, and `Price history` placed in the price/stock row.

## Large device
- Device: iPhone 15 Pro Max simulator, iOS 26.1.
- Header: search field and compact scanner button align as a single native search/scanner row.
- Header spacing: product card starts closer to the search row with a balanced grouped-background gap.
- Rows: prices, stock, and price history sit together below the title; inline barcode/item code and supplier/category names remain visible and ordered.
- Edit affordance: full-card tap opens the edit sheet; no redundant visible `Edit` button remains in the card.
- Tab bar: final row can be scrolled above the tab bar.

## Small device
- Device class: iPhone 16e simulator.
- Synthetic rows remain readable.
- Long product name wraps cleanly.
- Long barcode and item code truncate in the middle while staying inline.
- Supplier/category long values truncate without prefixes and without forcing horizontal overflow.
- Final row/action remains scrollable above the tab bar.

## Dynamic Type
- Default content size (`large`) checked.
- Larger content size (`extra-extra-large`) checked and captured in `03-after-fixed-database-dynamic-type-large.png`.
- At larger text, rows expand vertically and remain scrollable; metric/history labels fall back vertically instead of being split mid-word or clipped.

## Interaction QA
- Search, clear search, scanner fallback, full-card edit sheet, metric-row price history sheet, import menu, export menu, and list scrolling were exercised.

## Final review QA - 2026-05-13
- `review-database-default-2026-05-13.jpg` captures the final reviewed Database list at default/medium content size.
- `review-database-xxl-bottom-2026-05-13.jpg` captures the final reviewed Database list at `extra-extra-large` after scrolling to the bottom position.
- Full-card tap still opens `Edit product`.
- The visible `Edit` button remains absent, with the edit affordance preserved through tap and accessibility action.
- `Price history` remains near Purchase/Retail/Stock and opens history without also opening edit.
- Toolbar import/export/add actions remain visible and accessible from Database.
