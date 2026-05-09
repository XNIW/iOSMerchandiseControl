# TASK088 Preflight Schema

Data: 2026-05-09 12:48 -0400

## Tipo verifica

- `STATIC` / `READ-ONLY`: lettura task, migrazioni Supabase, codice iOS e riferimento Android.
- Nessuna write Supabase, nessun runtime mutativo, nessun dato reale usato.
- Nessun token/JWT/refresh/service_role/connection string riportato.

## Tracking e Go/No-Go iniziale

| Check | Esito | Evidenza |
|---|---|---|
| TASK-088 attivo | PASS | `docs/MASTER-PLAN.md` e file task indicano TASK-088 come task attivo; avvio EXECUTION tracciato con override utente. |
| TASK-087 ultimo completato | PASS | MASTER-PLAN indica TASK-087 **DONE / Chiusura** come ultimo completato. |
| TASK-089 non aperto | PASS | MASTER-PLAN indica TASK-089 **TODO / Planning**; il file TASK-089 non e' stato aperto. |
| Altri ACTIVE incompatibili | PASS | Stato globale corrente: unicamente TASK-088. |
| Go/No-Go §8.4 | PARTIAL | Il file TASK-088 non contiene una sottosezione numerata §8.4; usati §7/§8/§9 del task e prompt utente come handoff operativo esteso. |

## Schema Supabase letto

Fonte primaria: `/Users/minxiang/Desktop/MerchandiseControlSupabase/supabase/migrations/20260417200000_task016_inventory_product_prices.sql`

Tabella reale di riferimento: `public.inventory_product_prices`.

Colonne rilevanti:

- `id uuid PRIMARY KEY`
- `owner_user_id uuid NOT NULL`
- `product_id uuid NOT NULL`
- `type text NOT NULL`
- `price double precision NOT NULL`
- `effective_at text NOT NULL`
- `source text`
- `note text`
- `created_at text NOT NULL`

Constraint e policy rilevanti:

- `CHECK (type IN ('PURCHASE', 'RETAIL'))`
- unique reale: `UNIQUE (owner_user_id, product_id, type, effective_at)`
- RLS owner-scoped su `auth.uid() = owner_user_id`

Migration collegata letta: `/Users/minxiang/Desktop/MerchandiseControlSupabase/supabase/migrations/20260421120000_task038_restrict_authenticated_delete_inventory.sql`

- revoca DELETE authenticated su `inventory_product_prices`
- nessuna colonna `updated_at` / `deleted_at` su `inventory_product_prices`

Chiave logica ProductPrice per TASK-088: `owner_user_id + product_id + type + effective_at`.

## iOS letto

File letti:

- `iOSMerchandiseControl/Models.swift`
- `iOSMerchandiseControl/SupabaseProductPriceManualPushService.swift`
- `iOSMerchandiseControl/SupabaseInventoryService.swift`
- `iOSMerchandiseControl/SupabaseManualSyncViewModel.swift`
- `iOSMerchandiseControl/SupabaseManualSyncReleaseFactory.swift`
- `iOSMerchandiseControl/SupabaseProductPriceApplyService.swift`
- test ProductPrice e ManualSync mirati sotto `iOSMerchandiseControlTests/`

Osservazioni:

- `ProductPrice` SwiftData ha `remoteID: UUID?`.
- Dry-run push salta le righe locali con `ProductPrice.remoteID != nil`.
- Payload push usa UUID deterministico da `ownerUserID + productID + type + effectiveAt`.
- `SupabaseInventoryService.insertProductPriceManualPushPayloads` esegue `.insert(...).select(...)` e riceve righe remote complete.
- `SupabaseProductPriceManualPushService.push` verifica read-back exact-match ma ritorna solo `ProductPriceManualPushResult`, senza mappa righe/payload verso `ProductPrice.remoteID`.
- `SupabaseManualSyncReleaseProductPriceAdapter.push` chiama il servizio e non riconcilia il contesto SwiftData.
- `SupabaseProductPriceApplyService` invece linka `remoteID` locale quando una riga remota corrisponde alla stessa chiave logica e prezzo canonico.

Gap preflight probabile:

- Identity post-push iOS non e' garantita dal path Release corrente: dopo push verificato, il `remoteID` locale puo' restare `nil` fino a un pull/apply successivo.

## Android reference letto

Repo: `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView`

File letti:

- `data/ProductPrice.kt`
- `data/ProductPriceSummary.kt`
- `data/ProductPriceDao.kt`
- `data/InventoryRepository.kt`
- `data/SupabaseProductPriceRemoteDataSource.kt`
- `util/DatabaseExportWriter.kt`

Osservazioni:

- Room `product_prices` ha indice unique `(productId, type, effectiveAt)`.
- `ProductPriceSummary` calcola `lastPurchase`, `prevPurchase`, `lastRetail`, `prevRetail` ordinando per `effectiveAt`.
- Android mantiene bridge `ProductPriceRemoteRef` dopo push/pull.
- Pull Android deduplica per remote id e business key; se esiste la riga locale, inserisce bridge remoto invece di duplicare.
- Export Android usa current/previous da `ProductWithDetails` / summary.

## Decisione preflight

Esito: **GO condizionato** per collision scan e test mirati.

Condizioni prima di qualunque write remoto:

- collisioni `TASK088_*` documentate;
- sessione/auth/owner verificati privacy-safe immediatamente prima della write;
- nessun dato reale o comando distruttivo;
- patch iOS limitata alla riconciliazione identity post-push solo se confermata da test/evidenza.
