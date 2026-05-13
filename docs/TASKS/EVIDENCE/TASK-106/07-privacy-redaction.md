# TASK-106 Privacy Redaction

## Data policy
- No real shop/customer/supplier data was intentionally used.
- The simulator app was cleared before the before-screenshot flow.
- Populated-list validation used synthetic values prefixed with `TASK106`.

## Screenshot content
- `01-before-current-database.png`: empty Database state, no product data.
- `03-after-fixed-database.png`: synthetic product data only.
- `03-after-fixed-database-dynamic-type-large.png`: synthetic product data only at larger Dynamic Type.

## Synthetic values exercised
- Short product name: `TASK106 Short`.
- Long product name: `TASK106 Product With A Very Long Display Name That Should Wrap Cleanly Without Crushing The Row`.
- Long barcode: `LONG-BARCODE-106-003-ABCDEFGHIJKLMN`.
- Long item code: `TASK106-ARTICLE-CODE-WITH-LONG-VALUE`.
- Supplier/category values: `TASK106 ...`.

## Notes
- The small-device simulator reused the synthetic SwiftData store from the large simulator for visual validation only.
- Evidence does not include secrets, real barcodes, real supplier names, or real inventory values.
