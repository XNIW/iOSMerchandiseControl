# 11 - Cleanup

## Setup

Run id: `TASK103_REAL_R1778622799_`.

## Steps

1. Run pre-cleanup SQL read-back scoped to `TASK103_REAL_R1778622799_%`.
2. Delete only ProductPrice rows linked to scoped products.
3. Delete only scoped products.
4. Delete only scoped suppliers/categories by name prefix.
5. Run post-cleanup SQL read-back scoped to the same prefix.

## Expected

Either zero scoped residue or documented scoped residue. No global cleanup, no truncate/drop/reset.

## Observed

Pre-cleanup scoped counts:

| scope | observed |
|-------|----------|
| products | 55 |
| suppliers | 10 |
| categories | 10 |
| product_prices | 114 |

Cleanup deleted:

| scope | deleted |
|-------|---------|
| product_prices | 114 |
| products | 55 |
| suppliers | 10 |
| categories | 10 |

Post-cleanup scoped counts:

| scope | observed |
|-------|----------|
| products | 0 |
| suppliers | 0 |
| categories | 0 |
| product_prices | 0 |

## Result

`PASS` for CA-103-14.

## Notes/Redactions

Cleanup used linked SQL with explicit `TASK103_REAL_R1778622799_%` filters because authenticated DELETE is intentionally revoked by TASK-038. No schema, grant, RLS or migration was changed.
