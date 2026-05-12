# 04 - iOS to Supabase to Android

## Setup

Run id: `TASK103_REAL_R1778622799_`; owner hash `ad3d747e936c`.

## Steps

1. Create iOS SMOKE supplier/category/product in SwiftData test harness.
2. Record purchase/retail previous and current ProductPrice rows with deterministic `effectiveAt`.
3. Execute guided/manual catalog and ProductPrice push through existing iOS services.
4. Read back scoped remote data.
5. Pull/check Android physical device and verify local Room detail.
6. Run iOS no-op planner on the same synced data.

## Expected

The iOS canary appears once remotely and on Android with supplier/category/product plus four ProductPrice rows: purchase 11.10/12.35 and retail 18.90/20.50.

## Observed

- iOS device XCTest: `TASK103_IOS_WRITE_SMOKE owner_hash=ad3d747e936c product_hash=fd6313de4c89 price_inserted=4 no_op=true`.
- Android physical instrumentation: `TASK103_ANDROID_PULL_IOS owner_hash=ad3d747e936c pulled_products=1 pulled_prices=4 room_detail=true`.
- Scoped SQL read-back for `TASK103_REAL_R1778622799_IOS_0001`: product name `TASK103_REAL_R1778622799_CANARY_IOS_01`, purchase `12.35`, retail `20.5`, four ProductPrice rows, effectiveAt range `2026-05-12 13:00:00` to `2026-05-12 13:15:00`.

## Result

`PASS` for CA-103-05 and CA-103-06.

## Notes/Redactions

No raw owner UUID, token or real barcode was recorded. Android UI detail was verified through the physical instrumentation read-back against Room detail fields.
