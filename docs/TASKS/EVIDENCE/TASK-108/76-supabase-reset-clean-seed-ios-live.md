# TASK-108 Evidence 76 — Supabase reset, clean seed, iOS real Excel/ProductPrice harness

Data: 2026-05-14 18:07 -0400  
Branch iOS: `task108-sync-reset-clean-seed`  
Project Supabase verificato: `merchandisecontrol-dev` / `jpgoimipbothfgkokyvm`  
Email test usata: `x***@gmail.com`  
USER_UUID: `6425adb0-...-e8257e`

## Verdict

`REVIEW_READY_RESET_CLEAN_SEED_SQL_AND_IOS_HARNESS`

Non e' `DONE`: push/pull app-auth reale dall'app iOS, document picker UI, incrementale iOS -> Supabase -> iOS e Android emulator live non sono stati eseguiti. L'ambiente non esponeva una sessione Gmail/Supabase interattiva riutilizzabile; per evitare un blocco sul seed remoto, il caricamento e' stato eseguito via SQL admin owner-scoped dopo backup/reset verificati. I test iOS aggiunti coprono il parser/importer core reale e `SupabaseProductPriceApplyService.applyPagedFullPull` con il file Excel reale.

## Supabase backup/reset

Utente auth risolto con query esatta case-insensitive su `auth.users`; risultato: 1 riga. Non e' stato cancellato `auth.users`.

Tabelle app owner-scoped rilevate:
- `inventory_suppliers.owner_user_id`
- `inventory_categories.owner_user_id`
- `inventory_products.owner_user_id`
- `inventory_product_prices.owner_user_id`
- `shared_sheet_sessions.owner_user_id`
- `sync_events.owner_user_id`

Conteggi prima reset:
- `inventory_suppliers`: 101
- `inventory_categories`: 64
- `inventory_products`: 19.888
- `inventory_product_prices`: 292.989
- `shared_sheet_sessions`: 13
- `sync_events`: 1.050

Backup creati con timestamp `20260514173049`:
- `backup_task108_inventory_suppliers_20260514173049`: 101
- `backup_task108_inventory_categories_20260514173049`: 64
- `backup_task108_inventory_products_20260514173049`: 19.888
- `backup_task108_inventory_product_prices_20260514173049`: 292.989
- `backup_task108_shared_sheet_sessions_20260514173049`: 13
- `backup_task108_sync_events_20260514173049`: 1.050

Delete eseguite in transazione e filtrate su `owner_user_id = USER_UUID`:
1. `sync_events`
2. `shared_sheet_sessions`
3. `inventory_product_prices`
4. `inventory_products`
5. `inventory_suppliers`
6. `inventory_categories`

Conteggi dopo reset:
- tutte le 6 tabelle sopra: 0

## Indici anti-duplicazione

Verificati, gia' presenti; non e' stata applicata nuova migration:
- `inventory_suppliers_owner_name_lower_active`: unique `(owner_user_id, lower(name)) where deleted_at is null`
- `inventory_categories_owner_name_lower_active`: unique `(owner_user_id, lower(name)) where deleted_at is null`
- `inventory_products_owner_barcode_active`: unique `(owner_user_id, barcode) where deleted_at is null`
- `inventory_product_prices_owner_product_type_effective_uniq`: unique `(owner_user_id, product_id, type, effective_at)`

Nota schema reale: `inventory_product_prices` non ha `deleted_at`; l'indice unique e' pieno sulla chiave logica.

## Excel sorgente

Path usato: `/Users/minxiang/Downloads/Database_2026_04_21_14-06-26.xlsx`  
Motivo: tra le copie trovate da `mdfind`, questa era la piu' recente (`2026-05-14 16:26:28`).

Conteggio reale con bundled Python/openpyxl:
- Sheet names: `Products`, `Suppliers`, `Categories`, `PriceHistory`
- `Products`: 19.695 righe dati
- `Suppliers`: 57 righe dati
- `Categories`: 27 righe dati
- `PriceHistory`: 41.108 righe dati
- righe vuote escluse: 0 nei quattro sheet
- elapsed conteggio: 1.572 ms

Check logici extra:
- barcode prodotti duplicati: 0
- chiavi price history `(barcode,type,timestamp)` duplicate: 0
- price history con barcode non presente nei prodotti: 0
- supplier/category referenziati dai prodotti: 57/27, coerenti con gli sheet dedicati

## Seed remoto

Metodo effettivo: SQL-backed owner-scoped seed generato dal file Excel, eseguito con Supabase CLI sul progetto linked.  
Motivo: la sessione app-auth Gmail/Supabase iOS non era disponibile/automatizzabile in questa sessione; non e' stato usato un seed inventato, ma dati derivati dal file Excel reale con UUID deterministici e chiavi logiche equivalenti.

Generazione SQL:
- directory scratch: `/tmp/task108_seed_20260514`
- file SQL generati: 63 chunk
- tempo generazione: 2.016 ms
- conteggi generati: suppliers 57, categories 27, products 19.695, product_prices 41.108
- duplicati saltati: 0
- riferimenti mancanti: 0

Caricamento remoto:
- `supabase db query --linked -f <chunk>`
- chunk applicati: 63
- elapsed: 401 secondi

Conteggi Supabase dopo seed:
- `inventory_suppliers`: 57
- `inventory_categories`: 27
- `inventory_products`: 19.695
- `inventory_product_prices`: 41.108

Query duplicati Supabase ProductPrice:
- `group by owner_user_id, product_id, type, effective_at having count(*) > 1`
- risultato: 0 righe

No-op remoto:
- il rerun completo dei 63 chunk via CLI e' stato fermato per `ECIRCUITBREAKER`/troppe autenticazioni temporanee del pooler Supabase.
- verifica alternativa MCP/SQL: `insert into ... select ... on conflict do nothing returning 1` sulle quattro tabelle catalog/prices.
- inserted rows: 0 per `inventory_suppliers`, `inventory_categories`, `inventory_products`, `inventory_product_prices`.
- conteggi dopo no-op: invariati 57 / 27 / 19.695 / 41.108.

## iOS import/full pull harness

File test aggiunto: `iOSMerchandiseControlTests/Task100LargeDatasetAcceptanceTests.swift`

Harness 1: `testTask108RealExcelCleanSeedImportCountsWhenEnabled`
- Usa `ExcelAnalyzer` + `ProductImportCore` + `ProductImportNamedEntityResolver`.
- Importa in SwiftData in-memory dal file Excel reale.
- Tempo import harness: 16,119 s nel run finale.
- Conteggi locali:
  - products 19.695
  - suppliers 57
  - categories 27
  - ProductPrice raw 41.108
  - ProductPrice logical 41.108
  - duplicati 0

Harness 2: `testTask108RealExcelProductPricePagedFullPullNoopWhenEnabled`
- Seed locale iniziale: catalogo prodotto con `remoteID`, senza price history.
- Fetcher paginato in-memory con 41.108 righe derivate dal file Excel reale.
- Servizio reale usato: `SupabaseProductPriceApplyService.applyPagedFullPull`.
- Page size: 900
- Pagine: 46
- Primo full pull ProductPrice:
  - inserted 41.108
  - linked 0
  - skipped 0
  - total 41.108
  - elapsed harness: 11,487 s
  - log service: `paged_apply_complete inserted=41108 linked=0 skipped=0 total=41108 elapsedMs=...`
- Secondo pull no-op:
  - inserted 0
  - linked 0
  - skipped 41.108
  - total 41.108
  - elapsed harness: 7,228 s
  - raw/logical finali: 41.108 / 41.108

Safety gate:
- test mirato `SupabaseProductPriceApplyServiceTests.testPagedFullPullBlocksRemoteAboveDefaultSafetyLimit` PASS.
- limite default: 75.000.
- remote sporco osservato prima reset: 292.989, quindi sarebbe bloccato.
- remote pulito dopo seed: 41.108, sotto limite.

## Performance/UI iOS

Simulator smoke sample:
- Bundle: `com.niwcyber.iOSMerchandiseControl`
- PID sample: 4530
- file: `/tmp/task108-ios-launch-sample.txt`
- main thread: campioni quasi interamente in `mach_msg` / run loop.
- nessun marker nel sample per:
  - `SwiftDataInventorySnapshotService.makeSnapshot`
  - `PriceHistoryBackfillService`
  - `DateFormatter` massivo
  - `SupabaseProductPriceApplyService`
  - lavoro sync massivo sul main thread
- physical footprint: 188,5M; peak storico del processo: 999,3M.

Nota: non e' stato eseguito tap latency manuale durante cloud check app-auth reale; il sample e' smoke runtime locale.

## Android minimo

Repo: `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView`

Build/test:
- `./gradlew assembleDebug`: PASS (`BUILD SUCCESSFUL in 741ms`)
- `./gradlew test`: PASS (`BUILD SUCCESSFUL in 20s`)

Audit statico:
- `ProductPrice.kt`: indice unico Room `Index(value = ["productId","type","effectiveAt"], unique = true)`
- `ProductPriceDao.kt`: insert `OnConflictStrategy.IGNORE`; `insertIfChanged` scrive solo se ultimo prezzo diverso oltre soglia
- `ProductPriceDao.kt`: `getAllForCloudPush` esclude righe gia' bridged con `product_price_remote_refs`
- `PriceBackfillWorker.kt`: usa `getProductIdsWithAnyPrice()` e salta prodotti gia' con almeno un prezzo

Android emulator/live pull non eseguito in questa sessione.

## Build/test finali iOS

- Debug simulator build: PASS; unico warning noto AppIntents metadata.
- Release simulator build: PASS; unico warning noto AppIntents metadata.
- Targeted tests finali: PASS, 169 test, 0 failure, 0 unexpected, durata 186,047 s.
  - `HistorySessionSyncServiceTests`: 4/0
  - `SupabaseCatalogBaselineWriterReaderTests`: 9/0
  - `SupabaseManualSyncViewModelTests`: 92/0
  - `SupabaseProductPriceApplyServiceTests`: 29/0
  - `SupabasePullApplyServiceTests`: 29/0
  - `SupabasePullPreviewPaginationTests`: 4/0
  - TASK-108 real Excel/ProductPrice harness: 2/0
- `git diff --check`: PASS.

Warning noti non introdotti dal fix:
- AppIntents metadata skipped.
- Alcuni warning Swift test legacy su actor/sendable in file non toccati dal fix.

## Cose non testate

- Document picker UI iOS reale.
- Login Gmail/Supabase app-auth iOS manuale/automatico.
- Push iOS reale verso Supabase tramite `SupabaseManualPushService`.
- Full pull catalogo iOS da Supabase via client autenticato app.
- Incrementale iOS -> Supabase -> iOS da app reale.
- Android emulator full pull/no-op/live incremental.
- Incrementale Android -> iOS.

## Rischi residui

- Il database remoto ora e' pulito e coerente, ma il seed e' stato SQL-backed e non prova il writer app-auth iOS.
- Gli harness iOS provano importer core e ProductPrice full pull/no-op con dataset reale, ma non provano la rete Supabase/RLS dal client app.
- Il test `Task100LargeDatasetAcceptanceTests` ora include due harness TASK-108 che usano il path default locale del file Excel se presente; se il file manca, skip controllato.

