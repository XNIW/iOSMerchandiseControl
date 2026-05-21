# TASK-112 - Audit Offline Dependency Graph

Timestamp: 2026-05-20 20:34 -0400

## Required order

1. supplier/category
2. product
3. ProductPrice
4. History/session
5. watermarks/baselines

## Audit state

| Platform | Stato | Evidence |
|---|---|---|
| Android | parziale | Repository sync paths push catalog before prices and has remote refs. History is separate coordinator. |
| iOS | parziale | Manual sync run/apply plan has catalog/ProductPrice/History phases, but not a unified offline queue. |
| Supabase | coperto | FK `inventory_product_prices.product_id -> inventory_products.id`. |

## Gap

- No explicit `blockedDependency` queue state.
- ProductPrice offline before product remote ref not tested.
- History queued before catalog refs ready not tested.

## Verdict

**PARTIAL**: ordering exists in sync flows, not as a complete offline-first dependency scheduler.
