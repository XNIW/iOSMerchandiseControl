# TASK-097 Remote Read-Back Notes

- **Dataset prefix:** `TASK097_*`
- **Final suffix:** `R1778437271`
- **Owner:** `owner_hash=81a269773be6`
- **Environment:** Supabase sandbox, redacted project hash `bf02812f63e2`
- **Auth path:** app SDK authenticated session with publishable key; no service_role/admin token used

## Collision Scan

Before the final PASS run, the exact proposed fixture names were already occupied by the earlier TASK-097 smoke attempt:

| Scope | Count |
|-------|-------|
| suppliers | 1 |
| categories | 1 |
| products | 2 |
| ProductPrice rows | 8 |

The final suffix `R1778437271` was then scanned and was clear before write:

| Scope | Count |
|-------|-------|
| suppliers | 0 |
| categories | 0 |
| products | 0 |
| ProductPrice rows | 0 |

## Seed Setup

Seed/setup created only owner-scoped synthetic rows with names/barcodes under `TASK097_*_R1778437271`:

- supplier: `TASK097_SUPPLIER_RUNTIME_SANDBOX_R1778437271`
- category: `TASK097_CATEGORY_RUNTIME_SANDBOX_R1778437271`
- products: Product A and Product B with synthetic barcodes
- ProductPrice seed rows: A purchase previous/current, A retail previous/current, B purchase baseline, B retail baseline

No existing non-TASK097 records were modified.

## Seed Read-Back

Remote read-back immediately after seed:

| Entity | Count | Result |
|--------|-------|--------|
| Supplier | 1 | PASS |
| Category | 1 | PASS |
| Products | 2 | PASS |
| ProductPrice | 6 | PASS |

## Post-Push Read-Back

After iOS local edit and aggregated push:

| Remote target | Expected | Result |
|---------------|----------|--------|
| Product B catalog purchase price | 35.55 | PASS |
| Product B catalog retail price | 70.70 | PASS |
| Product B purchase ProductPrice current | 35.55 at `2026-05-10 10:30:00` | PASS |
| Product B retail ProductPrice current | 70.70 at `2026-05-10 10:35:00` | PASS |
| ProductPrice total for suffix dataset | 8 rows | PASS |

Remote write success was not treated as acknowledged until read-back verified catalog and ProductPrice state.
