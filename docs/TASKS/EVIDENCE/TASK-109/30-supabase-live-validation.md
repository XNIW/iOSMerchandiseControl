# TASK-109 — 30 Supabase Live/Dev Validation

Date: 2026-05-15  
Project: `merchandisecontrol-dev`, ref redacted as `jpgo...kyvm`, region South America (Sao Paulo).  
Mode: read-only validation; no rows created/updated/deleted by this pass.

## Runtime evidence from app-auth simulator

Final iOS runtime log:

```text
[PullPreview] summary complete=true partial=false signals=true failure=none remoteProducts=19695 remoteSuppliers=57 remoteCategories=27 remotePrices=1000 new=0 updates=0 conflicts=0 tombstones=0 warnings=1 sourceErrors=0 supplierDiffs=0 categoryDiffs=0 priceSignals=0
```

Interpretation:

- remote catalog counts match local Options counts for products/suppliers/categories;
- product prices are preview-sampled at `1000`, while local Options count is `41109`;
- the one warning is the bounded ProductPrice preview note, not an actionable delta;
- final UX correctly shows `Sync completed with notes`, not Review.

## Supabase CLI read-only checks

Commands executed in `/Users/minxiang/Desktop/MerchandiseControlSupabase`:

```text
supabase --version -> 2.98.2
supabase projects list -> linked merchandisecontrol-dev, ref redacted
supabase db query --linked "select count(*) as total from public.inventory_product_prices;"
```

Successful query:

```json
{ "total": 41109 }
```

Earlier Wave 1 read-only count for History:

```json
{ "total_shared_sheet_sessions": 0, "owners": 0 }
```

Additional parallel count retries hit Supabase pooler auth circuit breaker:

```text
FATAL: (ECIRCUITBREAKER) too many authentication failures
Connect to your database by setting the env var correctly: SUPABASE_DB_PASSWORD
```

Because the successful Wave 1 History count was `0`, no owner-scoped History delta was available to prove a live remote History pull in this pass. Deterministic `HistorySessionSyncServiceTests` cover the chain and passed in the final targeted regression slice.

## Safety

- No `service_role` key was used or added to client code.
- No RLS bypass was introduced.
- No SQL migration was created.
- No Supabase rows were mutated by this pass.
