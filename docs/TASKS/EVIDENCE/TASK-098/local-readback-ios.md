# TASK-098 Local Read-Back iOS

## Environment

- simulator: `iPhone 15 Pro Max`
- destination id: `459C668B-7CE8-443B-BAB3-7D3D5FFC9143`
- owner_hash: `ad3d747e936c`

## Product A Android -> iOS

`Task098CrossPlatformSmokeTests.test02PullApplyAndroidProductAAndLocalReadBack` PASS:

- remote Product A selected by barcode `TASK098_BAR_A2I`
- SwiftData apply inserted 1 catalog product
- ProductPrice apply inserted 4 rows
- local read-back asserted all purchase/retail previous/current rows by `type + effectiveAt`

## Product B iOS -> Supabase

`Task098CrossPlatformSmokeTests.test03IOSWriteProductBUsingReleaseServices` PASS:

- Product B was created in the Release-style local context with supplier/category remote links
- Local pending catalog batch pushed successfully
- ProductPrice pending batch contained 4 ready candidates
- ProductPrice push inserted/verified 4 rows and reconciled 4 verified payloads

## Local ID Policy

SwiftData local IDs were not used for cross-platform identity. Identity was barcode + redacted remote id + ProductPrice key (`product + type + effectiveAt`).
