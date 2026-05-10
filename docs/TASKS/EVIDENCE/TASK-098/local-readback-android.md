# TASK-098 Local Read-Back Android

## Environment

- emulator/device: `sdk_gphone64_arm64`
- Android: 15 / API 35
- build variant: debug + androidTest
- owner_hash: `ad3d747e936c`

## Product A Android Local + Remote Confirmation

`Task098CrossPlatformSmokeTest.test02AndroidWriteAAndRemoteReadBack` PASS:

- Product A barcode `TASK098_BAR_A2I`
- local ProductPrice rows asserted for all 4 expected points
- remote read-back asserted catalog current purchase/retail and all ProductPrice rows
- idempotent rerun after initial write reported `pushed_catalog=0`, `pushed_prices=0`, confirming no duplicate push was needed

## Product B Supabase -> Android

`Task098CrossPlatformSmokeTest.test03AndroidPullReadBackB` PASS:

- scoped authenticated bootstrap used the normal repository pull/apply path
- `pulled_products=1`
- `pulled_prices=4`
- Room read-back asserted Product B by barcode `TASK098_BAR_I2A`

| Field | Expected | Result |
|-------|----------|--------|
| current purchase | 55.55 | PASS |
| previous purchase | 51.11 | PASS |
| current retail | 111.10 | PASS |
| previous retail | 101.11 | PASS |

## Local ID Policy

Room local IDs were redacted and were not compared to SwiftData IDs.
