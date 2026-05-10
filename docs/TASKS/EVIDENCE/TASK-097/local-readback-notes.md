# TASK-097 Local Read-Back Notes

- **Dataset prefix:** `TASK097_*`
- **Final suffix:** `R1778437271`
- **Owner:** `owner_hash=81a269773be6`
- **Store:** iOS local SwiftData store through existing Release pull/apply and pending/push services

## Pull Apply Read-Back

Release pull/apply path imported the remote seed into local SwiftData:

| Scope | Expected | Result |
|-------|----------|--------|
| Supplier | `TASK097_SUPPLIER_RUNTIME_SANDBOX_R1778437271` | PASS |
| Category | `TASK097_CATEGORY_RUNTIME_SANDBOX_R1778437271` | PASS |
| Product A | synthetic name/barcode A | PASS |
| Product B | synthetic name/barcode B | PASS |
| Catalog insert count | 2 products | PASS |
| ProductPrice insert count | 6 rows | PASS |
| Catalog baseline | valid | PASS |

## ProductPrice Audit

Price comparisons used absolute delta `<= 0.005`. Local effectiveAt values used the app canonical `yyyy-MM-dd HH:mm:ss` format.

| Product | Type | Previous/baseline | Current | Result |
|---------|------|-------------------|---------|--------|
| A | purchase | 11.11 at `2026-05-10 10:00:00` | 12.34 at `2026-05-10 10:05:00` | PASS |
| A | retail | 22.22 at `2026-05-10 10:10:00` | 24.68 at `2026-05-10 10:15:00` | PASS |
| B | purchase | 33.33 at `2026-05-10 10:20:00` | 35.55 at `2026-05-10 10:30:00` after local edit | PASS |
| B | retail | 66.66 at `2026-05-10 10:25:00` | 70.70 at `2026-05-10 10:35:00` after local edit | PASS |

The effectiveAt values are unique per product/type and ordered so previous/current selection is deterministic.

## Local Edit And Pending

Product B was edited locally through the existing confirmed path. The smoke then observed real pending rows:

| Pending scope | Count | Result |
|---------------|-------|--------|
| Total pending | 3 | PASS |
| Catalog pending | 1 | PASS |
| ProductPrice pending | 2 | PASS |

The aggregated push used existing planner and push services. Pending rows reached acknowledged state only after remote read-back verified the pushed catalog and ProductPrice state.
