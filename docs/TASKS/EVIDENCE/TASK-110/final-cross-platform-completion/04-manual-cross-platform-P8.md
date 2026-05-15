# TASK-110 final cross-platform completion - 04 manual cross-platform P8

Data: 2026-05-15  
Account runtime: `x***@gmail.com`  
Verdict: **PASS**, con note non bloccanti su device fisici non operabili/offline.

## Ambienti usati

- iOS: Simulator `iPhone 15 Pro Max`, iOS 26.1, UDID `459C668B-7CE8-443B-BAB3-7D3D5FFC9143`.
- Android: emulator `emulator-5554`, `Medium_Phone_API_35`, Android 15.
- Supabase linked project redatto: `...kyvm`.
- iOS physical device: **PASS_WITH_NOTES** - `xctrace` lo lista offline.
- Android physical device: **PASS_WITH_NOTES** - `8ac48ff0` rilevato ma bloccato da secure keyguard; non usati passcode o credenziali dispositivo.

## Counts finali di riferimento

| Entita | Supabase | Android | iOS | Esito |
|--------|---------:|--------:|----:|-------|
| History active `TASK110_FINAL_*` | 0 | 0 | 0 | PASS |
| History tombstones `TASK110_FINAL_*` | 3 | 3 | 3 | PASS |
| products | 19696 | 19696 | 19696 | PASS |
| suppliers | 57 | 57 | 58 | PASS_WITH_NOTES |
| categories | 27 | 27 | 27 | PASS |
| product_prices | 41111 | 41111 | 41111 | PASS |
| ProductPrice orphans | 0 | n/a | n/a | PASS |
| duplicate ProductPrice keys | 0 | 0 | 0 | PASS |

Nota supplier iOS: la differenza `+1` e' una voce locale manuale preesistente `Inventario manuale` senza remote id; non e' drift remoto TASK-110 e non coinvolge i record `TASK110_FINAL_*`.

## History matrix

| Step | Evidenza | Esito |
|------|----------|-------|
| Logout Android | UI `Not signed in`, realtime/sync skipped signed-out | PASS |
| Logout iOS | UI `Sign in to use the cloud`, `Sync now` assente | PASS |
| Login Android | UI `Signed in as x***@gmail.com`, owner hash `ad3d747e936c` | PASS |
| Auto sync Android after auth stable | bootstrap History + catalog/prices, `pricesSkippedNoProductRef=0` | PASS |
| Login iOS | UI `Cloud account connected, Signed in as x***@gmail.com` | PASS |
| Auto sync iOS after auth stable | `Checking cloud updates...` dopo account connected | PASS |
| Sync now Android | no overlap bloccante, no stale cancelled | PASS |
| Sync now iOS | no stale review dopo fix preview stock/metadata | PASS |
| Android create | `TASK110_FINAL_ANDROID_CREATE_1611`, remote `2033b0a4-db39-46bc-a613-66d3b6ac31ea` | PASS |
| Android create -> iOS | iOS vede la History dopo sync | PASS |
| iOS create | `TASK110_FINAL_IOS_CREATE_1604`, remote `97b55f33-3676-4f3c-9d31-cffc4ef09fa0` | PASS |
| iOS create -> Android | Android vede la History dopo sync | PASS |
| Android update -> iOS | `TASK110_FINAL_ANDROID_UPDATE_1627` visibile su iOS | PASS |
| iOS update -> Android | `TASK110_FINAL_IOS_UPDATE_1633` visibile su Android | PASS |
| Android delete -> iOS | tombstone propagato; voce non visibile in lista attiva iOS | PASS |
| iOS delete -> Android | tombstone propagato; voce non visibile in lista attiva Android | PASS |
| Sync now ripetuto 3x entrambi | nessun duplicato, nessuna resurrection tombstone | PASS |

## Product/catalog/price matrix

Record test:

```text
barcode=TASK110_FINAL_BARCODE_1652
product_name=TASK110_FINAL_ANDROID_PRODUCT_1652
android_local_product_id=39391
android_local_price_id=82219
supabase_product_remote=c9720d34-a9c0-4fb1-b2a8-f54838210596
android_price_remote=65cbf346-fc7f-4ffc-be1c-6d40b99066cd
ios_price_remote=3561b460-6490-5781-b4d0-4eead9a3984f
```

| Step | Evidenza | Esito |
|------|----------|-------|
| Android create product/price | Supabase product creato con purchase `12.34`, retail `23.45`, stock `7` | PASS |
| Android -> iOS | iOS pulled product and price history | PASS |
| iOS update price | retail `34.56`, ProductPrice append-only `EDIT_PRODUCT` | PASS |
| iOS -> Supabase | mirror finale su `inventory_products.retail_price=34.56` dopo fix push | PASS |
| Supabase -> Android | Android vede retail `34.56` e due price rows `23.45`, `34.56` | PASS |
| Integrity | orphans `0`, duplicate price keys `0`, `pricesSkippedNoProductRef=0` | PASS |

Nota iOS stock: iOS local `ZSTOCKQUANTITY` resta `nil` per policy esistente `applyStockQuantity=false`; il preview non segnala piu' un falso update stock-only perche' iOS non applica stock remoto di default.

## Offline / restore

| Step | Evidenza | Esito |
|------|----------|-------|
| Android offline create | airplane/offline, created `TASK110_FINAL_ANDROID_OFFLINE_181157` | PASS |
| Restore network + sync | remote `713674e7-9609-49f4-8a60-5416ddecccd5` creato | PASS |
| iOS pull offline-created History | inizialmente crash per grid empty; fix applicato e rerun PASS | PASS |
| Android force-stop/launch | session restored, sync not lost | PASS |
| iOS stop/launch | session restored, `Sync now` enabled | PASS |

## Error handling

- `no_auth` signed-out non viene mostrato come `Operation cancelled`: **PASS**.
- Supabase `42501` e' classificato come permission issue nel smoke Data API: **PASS**.
- `Cancelled` non e' rimasto come messaggio stale dopo sync riusciti: **PASS**.
- Sync Android/iOS non si sovrappongono in modo bloccante durante P8: **PASS**.

## Cleanup P8

- Record active `TASK110_FINAL_*` History cleanup: **PASS**, active `0`.
- Tombstone `TASK110_FINAL_*` conservati per prova di propagazione: **PASS**, count `3`.
- Product test `TASK110_FINAL_BARCODE_1652` lasciato intenzionalmente come record di convergenza catalog/ProductPrice: **PASS_WITH_NOTES**, documentato in `09-test-data-cleanup.md`.

