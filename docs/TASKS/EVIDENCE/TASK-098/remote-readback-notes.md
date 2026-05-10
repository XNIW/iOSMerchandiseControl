# TASK-098 Remote Read-Back Notes

## Preflight / Collision Scan

- actor: `test_harness`
- mutation: none
- project_hash: `42a5d0119a30`
- owner_hash: `ad3d747e936c`
- dataset_prefix: `TASK098_*`
- result: PASS before first write

Initial read-only scan found no active supplier/category/Product A/Product B rows and no ProductPrice rows for fixture products.

## A Android-First Remote Read-Back

- actor: `android_release_flow`
- product_hash: `cc8d8823dec7`
- result: PASS

Android created/updated Product A and ProductPrice A through the normal repository/sync path, then read back remote catalog and prices. A later idempotent rerun reported `pushed_catalog=0`, `pushed_prices=0` because rows were already aligned, while remote assertions still passed.

| Product | Type | Role | Price | effectiveAt |
|---------|------|------|-------|-------------|
| A | PURCHASE | previous | 41.11 | 2026-05-10 11:00:00 |
| A | PURCHASE | current | 42.22 | 2026-05-10 11:05:00 |
| A | RETAIL | previous | 81.11 | 2026-05-10 11:10:00 |
| A | RETAIL | current | 84.44 | 2026-05-10 11:15:00 |

## B iOS-First Remote Read-Back

- actor: `ios_release_flow`
- product_hash: `0a377e6fe3fc`
- result: PASS

iOS created Product B through Release catalog services, pushed 4 ProductPrice rows through ProductPrice Release services, linked verified payloads, and read back the remote rows.

| Product | Type | Role | Price | effectiveAt |
|---------|------|------|-------|-------------|
| B | PURCHASE | baseline | 51.11 | 2026-05-10 11:20:00 |
| B | PURCHASE | current | 55.55 | 2026-05-10 11:30:00 |
| B | RETAIL | baseline | 101.11 | 2026-05-10 11:25:00 |
| B | RETAIL | current | 111.10 | 2026-05-10 11:35:00 |

## Privacy

Remote IDs are recorded only as hashes. No full project URL, raw user id, email, token, service role, or connection string is recorded.
