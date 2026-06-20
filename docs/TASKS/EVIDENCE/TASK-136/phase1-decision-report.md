# TASK-136 Phase 1 Source-of-Truth Decision

Generated: 2026-06-20

## Decision

**CASO B — il catalogo cloud corretto e' circa 19.7k.**

Admin Products `11+` / `51+` / `61+` / `71+` is not an exact total and must not be read as "Admin has 11 products." The browser route uses `getShopInventoryProductsPage({ includeExactTotals: false })`, so page navigation fetches lightweight `pageSize + 1` slices and renders a growing lower-bound/pagination signal while exact totals are deferred. This paging strategy is valid for performance, but the UX must label the values as a loaded lower bound/current page range and keep exact cloud/read-model totals separate. The exact Admin read-model owner scope is `19710` active products; Supabase canonical selected shop has `19705` active products plus `5` active legacy `shop_id IS NULL` owner rows.

Android Room live `11/10/9/15` is a partial local subset, not a Supabase source-of-truth scope and not a value inherited from Admin pagination. The local refs all still exist in Supabase and all belong to the current owner, but they are mixed: selected Admin shop + legacy null-shop.

Source-of-truth policy: mobile sync must use Supabase/direct read models and sync-event contracts, never a rendered Admin table counter. Admin Products should continue server-side pagination/search over the full catalog while clearly separating exact total, filtered total, current page, and loaded lower bound.

## Phase 1 Matrix

| Source | runtime/env/project ref | account hash | shop_id hash | owner_user_id hash | device hash/status | storeScope/watermark | products | suppliers | categories | price_history | history_sessions | note |
|---|---|---:|---:|---:|---|---|---:|---:|---:|---:|---:|---|
| Supabase direct by current Admin shop_id | Admin Web `.env.local`, `jpgo...yvm` | `bf727712f2b9` via mapping | `da11551e7968` | `bf727712f2b9` | n/a | n/a | 19705 active / 6 deleted | 66 active / 2 deleted | 35 active / 2 deleted | 41133 | 39 active / 60 deleted | Canonical selected shop rows. |
| Supabase direct by current owner_user_id | Same project | `bf727712f2b9` | mixed | `bf727712f2b9` | n/a | n/a | 19710 active / 45 deleted | 70 active / 24 deleted | 39 active / 24 deleted | 41218 | 45 active / 81 deleted | Admin mobile-owner bridge exact scope. |
| Supabase legacy shop_id IS NULL by owner_user_id | Same project | `bf727712f2b9` | legacy null (`20533d99ceb7`) | `bf727712f2b9` | n/a | n/a | 5 active / 39 deleted | 4 active / 22 deleted | 4 active / 22 deleted | 85 | 6 active / 21 deleted | Legacy residue still visible to owner-only bridge. |
| Admin Web runtime browser selected shop | Safari authenticated tab `localhost:3055/shop/products?shop_id=...`, `platform:cloud:dev`, `jpgo...yvm` | `bf727712f2b9` | `da11551e7968` | `bf727712f2b9` | n/a | n/a | UI loaded lower bound starts `11+` and grows with page (`51+`, `61+`, `71+` observed); exact owner active `19710` | exact owner active `70` | exact owner active `39` | exact owner `41218` | History page active `22` visible page / direct active `45` owner | Products page is server-side paginated. First paint fetches 11 rows, shows 10, exact totals deferred. |
| Android emulator runtime + local Room + cloud target | Installed APK project `jpgo...yvm`; Room main+WAL | `bf727712f2b9` | selected refs `da11551e7968` + legacy null | `bf727712f2b9` | `13303daf85ca`, remote `active` | empty storeScope, watermark `3219` | 11 | 10 | 9 | 15 | 41 user-visible | All local refs exist in Supabase: products 6 selected shop + 5 legacy null; not a cloud total. |
| iOS simulator runtime + local SwiftData + cloud target | Installed app project `jpgo...yvm`; SwiftData live store | `bf727712f2b9` | no local shop scope | `bf727712f2b9` | `ab1a6e7ebe07`, remote `active` | anonymous, watermark `3266` | 19710 | 68 | 38 | 28746 live store / prefs reconcile 41137 | 105 physical / 41 user-facing prefs | iOS is owner-scoped and has stale/inconsistent sync UI state (`completed` + stale error/block reason). |

## Android Remote Refs Answers

- A. The 11 Android products still exist in Supabase: **11/11 found**, **0 deleted**.
- B. They do not all belong to one selected shop scope: **6 selected Admin shop**, **5 legacy `shop_id IS NULL`**.
- C. They all belong to the same current owner hash as iOS/Android: **11/11 current owner**.
- D. They are partly legacy/null-shop: **5/11 products**, **4/10 suppliers**, **4/9 categories**, **6/15 price rows**, **6/45 history sessions**.
- E. The other ~19.7k rows are excluded from Android because the installed app currently has a partial local Room subset and an empty `storeScope` watermark. Runtime logcat showed a concrete race: catalog bootstrap/drain was blocked by transient device-status `JobCancellationException`; the device then became `active`; follow-up bootstrap/drain could be lost behind `sync_busy` unless explicitly queued/drained after the busy flight. A non-empty partial DB must not be treated as proof that full reconciliation is unnecessary.

## Admin Pagination Interpretation

- Admin Products is server-side paginated and must remain lightweight; it should not render all ~19.7k products into the browser.
- Labels like `11+`, `51+`, `61+`, or `71+` mean "loaded lower bound / at least N rows reachable by current pagination", not an exact cloud/catalog total.
- Exact total, filtered exact total, current page range, and loaded lower bound must be visually distinct.
- Search must run against the full server/cloud read model, not only rows already loaded in the current page.
- No mobile runtime may use Admin UI lower-bound counters as sync input or source of truth.

## Evidence Files

- `phase1-supabase-scope-audit.json`
- `phase1b-android-remote-refs-vs-supabase.json`
- `phase1c-admin-products-read-model.json`
- `phase1c-device-sync-state.json`
