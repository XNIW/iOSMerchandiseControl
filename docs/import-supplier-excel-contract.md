# Supplier Excel Import Contract

Android is the canonical source for supplier Excel import behavior. Public import keys are: `barcode`, `productName`, `itemNumber`, `purchasePrice`, `retailPrice`, `quantity`, `supplier`, `category`, `secondProductName`, `totalPrice`, `rowNumber`, `discount`, `discountedPrice`, `oldPurchasePrice`, `oldRetailPrice`, `realQuantity`, `complete`.

Forbidden names such as `stockQuantity`, `supplierName`, `categoryName`, `articleCode`, `unitPrice`, `name`, `name2`, `cost`, `prevPurchase`, and `prevRetail` are allowed only as SwiftData/model boundary details or legacy aliases normalized before preview.

UX workflow: supplier import uses file selection, column analysis/mapping, then editable product/price preview/apply. The preview must allow users to edit `retailPrice` before apply. The bulk helper can calculate `retailPrice` from `purchasePrice` with markup percent, rounding to 10/50/100 CLP, and an apply-only-empty option. `purchasePrice` must never silently auto-fill `retailPrice`; new products without `retailPrice` are blocked until the user fills it or intentionally uses the helper.

Detection policy: normalize headers by trim/lowercase/diacritic removal/space and underscore removal/non-alphanumeric removal; first data row is `numericCount >= 3 && textCount >= 1`; previous row is header when present, otherwise generated columns; each column keeps `headerSource` as `alias`, `pattern`, `generated`, or `unknown`; required `barcode`, `productName`, and `purchasePrice` are generated when missing.

Pattern policy: barcode 8/12/13 digits; itemNumber length 4..12 with letters or digits; quantity and purchasePrice positive numeric in at least 70%; totalPrice matches quantity * purchasePrice within 10% in at least 70%; productName text length at least 3 in at least 50%; headerless files also infer retailPrice, secondProductName, supplier, discount, discountedPrice, and rowNumber.

Rows: filter summary rows with the exact Android token set `合计`, `总计`, `小计`, `汇总`, `合計`, `總計`, `小計`, `總結`, `总额`, `subtotal`, `total`, `totale`, `tot.`, `sommario`, `resumen`, `sum`; parse `1.234,56`, `1,234.56`, `1234,56`, and `1234`; duplicate barcodes keep the last occurrence, warn with row numbers, and do not sum quantity.

Boundary mapping:
- Android: `quantity -> stockQuantity` and other canonical keys map to Room `Product` fields only inside analyzer/repository apply.
- iOS: `quantity -> stockQuantity` and other canonical import keys map to `ProductDraft` and SwiftData `Product` fields only in `ProductImportCore`.
- Admin: canonical preview/import rows map to API/database schema only inside server apply/merge functions.
- Win7POS: canonical keys map to `ImportRow`/SQLite fields only inside the Win7POS import adapter.

Evidence: `Task111ExcelImportParityTests` loads `tests/fixtures/supplier-import/android-canonical-sample.json` and checks metadata/headerless/IT/ES/ZH fixture cases, canonical keys, `headerSource`, no-header pattern detection, duplicate last-wins, summary filtering, parseNumber parity, itemNumber-only products, new-product `retailPrice` blocker, pure bulk retail helper behavior, old price aliases, and legacy forbidden aliases normalized to canonical keys. `ExcelAnalyzerHTMLParsingTests` covers HTML parsing parity.
