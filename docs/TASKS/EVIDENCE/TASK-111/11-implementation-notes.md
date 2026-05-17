# TASK-111 — 11 Implementation Notes

## OBSERVED — Files changed

- `iOSMerchandiseControl/ProductImportCore.swift`
  - Robust numeric parser for localized separators, spaces, currency, percent-like fields, scientific barcode support.
  - Header alias fallback in import core.
  - Row validation for barcode/name/purchase/retail/quantity/discount.
  - Duplicate policy: warning, last row base, quantity aggregation.
  - Old/current purchase/retail ProductPrice creation and idempotence guard.
  - Supplier/category resolver case-insensitive/diacritic-insensitive.
- `iOSMerchandiseControl/ImportAnalysisView.swift`
  - ProductDraft old price fields.
  - Summary total/ready rows, filters, sticky CTA, warning export, duplicate policy copy.
  - Edit sheet preserves old price metadata.
- `iOSMerchandiseControl/ProductPriceHistoryView.swift`
  - Display label for `IMPORT_PREV`.
- `iOSMerchandiseControl/*.lproj/Localizable.strings`
  - EN/IT/ES/ZH localization for new import UI and previous import source.
- `iOSMerchandiseControlTests/Task111ExcelImportParityTests.swift`
  - New targeted regression tests.
- `iOSMerchandiseControlTests/Fixtures/TASK-111/*`
  - Privacy-safe fixture notes and synthetic HTML fixture.

## INFERRED — Refactor scope

- No new dependency added.
- No deployment target change.
- No model/schema migration.
- No DAO/repository/server refactor.
- Business logic stays outside SwiftUI rows.
