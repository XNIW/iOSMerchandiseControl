# 03 - Dataset Manifest

## Setup

| Campo | Valore |
|-------|--------|
| run_id | `TASK103_REAL_R1778622799_` |
| prefix run | `TASK103_REAL_R1778622799_` |
| owner hash | `ad3d747e936c` |
| timezone policy | deterministic UTC-style `effectiveAt` strings |
| cleanup policy | scoped only to run prefix; no global delete/truncate/drop/reset |

## Collision Scan

### Steps

Pre-write SQL read-back was scoped to `TASK103_REAL_R1778622799_%`.

### Expected

All counts zero before first write.

### Observed

| table_name | row_count |
|------------|-----------|
| `inventory_suppliers` | 0 |
| `inventory_categories` | 0 |
| `inventory_products` | 0 |
| `inventory_product_prices` | 0 |

### Result

`PASS`

## Golden Expected Table

| direction | set | canary | barcode | supplier | category | expected_purchase_previous | expected_purchase_current | expected_retail_previous | expected_retail_current | expected_final_platforms |
|-----------|-----|--------|---------|----------|----------|----------------------------|---------------------------|--------------------------|-------------------------|--------------------------|
| iOS_to_Android | SMOKE | `TASK103_REAL_R1778622799_CANARY_IOS_01` | `TASK103_REAL_R1778622799_IOS_0001` | `TASK103_REAL_R1778622799_SUP_IOS_01` | `TASK103_REAL_R1778622799_CAT_IOS_01` | `11.10 @ 2026-05-12 13:00:00` | `12.35 @ 2026-05-12 13:15:00` | `18.90 @ 2026-05-12 13:00:00` | `20.50 @ 2026-05-12 13:15:00` | iOS, Supabase, Android |
| Android_to_iOS | SMOKE | `TASK103_REAL_R1778622799_CANARY_ANDROID_01` | `TASK103_REAL_R1778622799_ANDROID_0001` | `TASK103_REAL_R1778622799_SUP_ANDROID_01` | `TASK103_REAL_R1778622799_CAT_ANDROID_01` | `21.10 @ 2026-05-12 14:00:00` | `22.35 @ 2026-05-12 14:15:00` | `31.90 @ 2026-05-12 14:00:00` | `33.50 @ 2026-05-12 14:15:00` | Android, Supabase, iOS |
| iOS_import_to_Android | MEDIUM | `TASK103_REAL_R1778622799_MEDIUM_PRODUCT_001` | `TASK103_REAL_R1778622799_MEDIUM_001` | `TASK103_REAL_R1778622799_SUP_MEDIUM_001` | `TASK103_REAL_R1778622799_CAT_MEDIUM_001` | `40.01 @ 2026-05-12 15:00:00` | `41.01 @ 2026-05-12 15:15:01` | `60.01 @ 2026-05-12 15:00:00` | `61.01 @ 2026-05-12 15:15:01` | iOS import/export, Supabase, Android |
| conflict_catalog | CONFLICT | `TASK103_REAL_R1778622799_CANARY_CONFLICT_G1` | `TASK103_REAL_R1778622799_CONFLICT_0001` | `TASK103_REAL_R1778622799_SUP_CONFLICT_G1` | `TASK103_REAL_R1778622799_CAT_CONFLICT_G1` | n/a | `42.00` | n/a | `52.00` | iOS stale/recovery, Supabase read-back |
| conflict_price | CONFLICT | `TASK103_REAL_R1778622799_CANARY_CONFLICT_G2` | `TASK103_REAL_R1778622799_CONFLICT_0002` | `TASK103_REAL_R1778622799_SUP_CONFLICT_G2` | `TASK103_REAL_R1778622799_CAT_CONFLICT_G2` | `61.00 @ 2026-05-12 16:00:00` | `62.00 @ 2026-05-12 16:15:00` | `71.00 @ 2026-05-12 16:00:00` | `72.00 @ 2026-05-12 16:15:00` | ProductPrice fail-closed/read-back |
| offline_retry | OFFLINE | `TASK103_REAL_R1778622799_CANARY_OFFLINE_01` | `TASK103_REAL_R1778622799_OFFLINE_0001` | `TASK103_REAL_R1778622799_SUP_OFFLINE_01` | `TASK103_REAL_R1778622799_CAT_OFFLINE_01` | n/a | `82.00` | n/a | `92.00` | iOS retry, Supabase read-back |

## Dataset Sets

- SMOKE: 2 products, 4 ProductPrice rows per direction.
- MEDIUM: 50 products, 5 suppliers, 5 categories, 102 ProductPrice rows.
- CONFLICT: catalog stale product and ProductPrice conflict product.
- OFFLINE: one retry product.

## Pre-cleanup Scoped Read-back

| scope | observed |
|-------|----------|
| products | 55 |
| suppliers | 10 |
| categories | 10 |
| product_prices | 114 |
| distinct_product_barcodes | 55 |

Canary SQL read-back verified the iOS, Android, MEDIUM, CONFLICT_G2 and OFFLINE rows by synthetic barcode, name, current prices and ProductPrice row counts.

## Result

`PASS` for CA-103-04 and source evidence for CA-103-14.

## Notes/Redactions

All values are synthetic and under the run prefix. Owner is recorded only as hash.
