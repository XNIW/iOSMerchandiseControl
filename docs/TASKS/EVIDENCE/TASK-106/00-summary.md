# TASK-106 Evidence Summary

## Scope
- Task: TASK-106 Database screen layout regression fix iOS.
- Date: 2026-05-13.
- Repo source: `origin/main` fetched before execution.
- Local HEAD and `origin/main`: `a4e2e20b01fcffa78608d651fb2da62387082c02`.
- Active implementation file: `iOSMerchandiseControl/DatabaseView.swift`.

## Strategy
- Chosen strategy: **C - Hybrid**.
- Rationale: TASK-102 introduced the larger layout drift, while TASK-105 added a useful scanner fallback focus fix. The patch keeps useful TASK-102/TASK-105 behavior and rebuilds the Database row/header layout with iOS-native SwiftUI primitives.

## User-visible result
- Search/scanner header is visually balanced and keeps minimum tap targets.
- Product rows are more readable and compact: title, prices/stock/history, barcode/item identity, and supplier/category have clearer hierarchy.
- Prices and stock are integrated in compact metric pills instead of floating trailing chips.
- The visible `Edit` button was removed because the whole product card opens editing.
- `Price history` now lives next to the price/stock metrics, with a vertical fallback at larger Dynamic Type.
- Barcode and item code are inline again, with middle truncation for long values.
- Supplier/category rows show direct names without `Supplier:` / `Category:` prefixes.
- Scanner button is lighter and the gap between search bar and the product card is tighter.
- Long names/barcodes/item codes/supplier/category values truncate or wrap predictably.
- List uses grouped iOS styling with bottom scroll content margin so the last row is not trapped under the tab bar.

## Functional non-changes
- No SwiftData model/schema/query changes.
- No Supabase/sync/networking changes.
- No import/export parser or business logic changes.
- No scanner logic changes beyond preserving presentation/fallback behavior.
- No new dependency and no deployment target change.

## Evidence index
- `01-before-current-database.png`
- `02-history-candidate.md`
- `03-after-fixed-database.png`
- `03-after-fixed-database-dynamic-type-large.png`
- `review-database-default-2026-05-13.jpg`
- `review-database-xxl-bottom-2026-05-13.jpg`
- `04-checks.md`
- `05-regression-risk.md`
- `06-design-decision.md`
- `07-privacy-redaction.md`
- `08-visual-qa.md`
- `09-compatibility.md`
- `10-performance-scope.md`
- `11-reviewer-playbook-result.md`
- `12-final-review.md`

## Final review update - 2026-05-13
- Reviewer: Codex, on explicit user override for final review/closure.
- Verdict: **PASS_WITH_NOTES**.
- Direct fix applied during review: `Price history` button tap target increased to 44 pt minimum while preserving compact visual layout.
- Direct fix applied during review: Database CRUD sheet text fields gained explicit accessibility labels.
- Direct stability fix applied during review: `LocalPendingAggregatedPushStateStore` converted from identity-less `final class` to `struct` after a targeted pending-change test exposed a deterministic deallocation crash.
- Final state: TASK-106 can be marked **DONE**; no blocker remains.
