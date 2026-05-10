# TASK-098 Cross-Platform Parity

Result: PASS

Identity mapping:

| Logical object | Primary identity | Secondary evidence | Local IDs |
|----------------|------------------|--------------------|-----------|
| Product A | `TASK098_BAR_A2I` | product_hash `cc8d8823dec7` | Not compared |
| Product B | `TASK098_BAR_I2A` | product_hash `0a377e6fe3fc` | Not compared |
| Supplier | `TASK098_SUPPLIER_CROSS_PLATFORM` | remote id redacted | Not compared |
| Category | `TASK098_CATEGORY_CROSS_PLATFORM` | remote id redacted | Not compared |
| ProductPrice | barcode/product + type + effectiveAt | remote row ids redacted | Not compared |

Tolerance: absolute `<= 0.005`.

| Product | Direction | Type | Role | Price | effectiveAt | Remote | iOS | Android |
|---------|-----------|------|------|-------|-------------|--------|-----|---------|
| A | Android -> iOS | PURCHASE | previous | 41.11 | 2026-05-10 11:00:00 | PASS | PASS | PASS |
| A | Android -> iOS | PURCHASE | current | 42.22 | 2026-05-10 11:05:00 | PASS | PASS | PASS |
| A | Android -> iOS | RETAIL | previous | 81.11 | 2026-05-10 11:10:00 | PASS | PASS | PASS |
| A | Android -> iOS | RETAIL | current | 84.44 | 2026-05-10 11:15:00 | PASS | PASS | PASS |
| B | iOS -> Android | PURCHASE | baseline | 51.11 | 2026-05-10 11:20:00 | PASS | PASS | PASS |
| B | iOS -> Android | PURCHASE | current | 55.55 | 2026-05-10 11:30:00 | PASS | PASS | PASS |
| B | iOS -> Android | RETAIL | baseline | 101.11 | 2026-05-10 11:25:00 | PASS | PASS | PASS |
| B | iOS -> Android | RETAIL | current | 111.10 | 2026-05-10 11:35:00 | PASS | PASS | PASS |

Date conversion: remote ISO timestamps were canonicalized to UTC `yyyy-MM-dd HH:mm:ss` for comparison while preserving ordering.
