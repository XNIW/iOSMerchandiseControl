# 09 - Import / Export

## Setup

Run id: `TASK103_REAL_R1778622799_`.

## Steps

1. Generate synthetic MEDIUM workbook with 50 products, 5 suppliers, 5 categories and 102 ProductPrice rows.
2. Import workbook on iOS physical-device XCTest path through the same analyzer/import core.
3. Push imported catalog and ProductPrice rows.
4. Pull MEDIUM data on Android physical device.
5. Export iOS spot-check workbook and inspect canary/current/previous fields.

## Expected

MEDIUM canary survives import, push, Android read-back and export spot-check with purchase 40.01/41.01 and retail 60.01/61.01.

## Observed

- iOS MEDIUM output: `TASK103_IOS_MEDIUM_IMPORT_EXPORT owner_hash=ad3d747e936c products=50 prices=102 catalog_status=completed price_inserted=102 price_batches=2 remote_medium_products=50 export_spotcheck=true duration_s=4.16`.
- Android MEDIUM logcat output: `TASK103_ANDROID_PULL_MEDIUM owner_hash=ad3d747e936c medium_products=50 pulled_products=50 pulled_prices=102 room_detail=true`.
- Scoped SQL canary read-back: `TASK103_REAL_R1778622799_MEDIUM_001`, product name `TASK103_REAL_R1778622799_MEDIUM_PRODUCT_001`, purchase `41.01`, retail `61.01`, four ProductPrice rows, effectiveAt range `2026-05-12 15:00:00` to `2026-05-12 15:15:01`.

## Result

`PASS` for CA-103-12.

## Notes/Redactions

No real spreadsheet or store data was used. Export evidence is a synthetic spot-check, not a retained customer file.
