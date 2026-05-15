# TASK-110 FIX completion — ProductPrice/catalog bridge

Data: 2026-05-15

## Snapshot iniziale

- Supabase live:
  - `inventory_products`: 19695
  - `inventory_suppliers`: 57
  - `inventory_categories`: 27
  - `inventory_product_prices`: 41109
  - remote orphan price rows by `inventory_product_prices.product_id -> inventory_products.id`: 0
- Android fisico pre-live-test:
  - Room `user_version`: 16
  - `products`: 19695
  - `suppliers`: 78
  - `categories`: 42
  - `product_prices`: 39498
  - `product_remote_refs`: 19695
  - `product_price_remote_refs`: 39498
  - `history_entries_total`: 7

## Verifica live Android

Eseguito su device fisico `IN2013` con sessione app-auth già presente:

```text
./gradlew :app:connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=com.example.merchandisecontrolsplitview.Task108AndroidAppAuthLiveTest \
  -Pandroid.testInstrumentationRunnerArguments.task108AndroidLiveSync=true
```

Esito: PASS in 6m27s.

Logcat redatto:

```text
phase=SYNC_PRICES_PULL remotePricesEvaluated=41109 pricesPulled=41109 pricesSkippedNoProductRef=0 pageSize=900 pageCount=46
TASK108_ANDROID_APP_AUTH_PULL_NOOP_PUSH_NOOP products=19695 suppliers=57 categories=27 product_prices=41109 product_refs=19695 price_refs=41109 remote_prices=41109 pushed_noop=0
```

## Root cause finale per il drift osservato

Il drift Android fisico `39498` vs Supabase/iOS `41109` era cache locale non riallineata, non orphan remoto: Supabase ha 0 price rows senza prodotto remoto e il full pull Android corrente importa 41109 righe con 0 `pricesSkippedNoProductRef`.

La pipeline corretta resta:

1. pull/apply suppliers/categories/products;
2. bridge product remote id locale;
3. pull paginato prices;
4. dedupe idempotente via `product_price_remote_refs` e business key locale.

## Nota operativa

`connectedDebugAndroidTest` installa/rimuove il package debug al termine. La prova ha usato e poi rimosso l'app test dal device; non lascia claim su sessione Android persistente dopo il run.
