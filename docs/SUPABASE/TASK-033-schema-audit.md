# TASK-033 Supabase schema audit

Audit e mapping prodotti/fornitori/categorie/prezzi/history/metadata sync tra **repository Supabase** (`MerchandiseControlSupabase`), **iOS** (`iOSMerchandiseControl`) e **Android** (`MerchandiseControlSplitView`, riferimento funzionale).
**Scope**: solo lettura delle sorgenti e documentazione. Nessuna implementazione di client Supabase, nessuna dipendenza aggiunta, nessuna modifica a `.swift`, `.kt`, migrazioni SQL o schema live.

---

## 1. Scope

- Sintetizzare lo **schema reale** dalle migrazioni SQL presenti nel repo Supabase locale.
- Sintetizzare i **modelli iOS SwiftData** e **Android Room** da file sorgente letti in locale.
- Produrre **matrice di mapping**, **decision log**, **gap list**, **rischi** e **proposta follow-up**.
- **Non** eseguire query contro un progetto Supabase remoto, **non** push/pull dati reali.

---

## 2. Sources inspected

| Source | Path | Status | Notes |
|--------|------|--------|-------|
| Supabase repo root | `/Users/minxiang/Desktop/MerchandiseControlSupabase` | read | Repo accessibile in lettura; nessuna modifica eseguita. |
| Supabase migrations / schema source | `/Users/minxiang/Desktop/MerchandiseControlSupabase/supabase/migrations/*.sql` | read | 8 migrazioni SQL lette: `shared_sheet_sessions`, ownership/RLS, `inventory_*`, `inventory_product_prices`, tombstone catalogo, delete restriction, payload v2, `sync_events`/RPC. |
| Supabase RLS / policies | `supabase/migrations/*.sql` | read | Policy RLS incorporate nelle migrazioni; nessuna directory separata `policies/` o `RLS/` trovata nel tree ispezionato. |
| Supabase trigger / RPC / functions / views | `supabase/migrations/*.sql`, `supabase/functions/README.md` | read | Trigger Postgres catalog tombstone e RPC `record_sync_event` letti dalle migrazioni. `supabase/functions/README.md` dichiara nessuna Edge Function anticipata; nessun file funzione Edge reale letto. Nessuna view Postgres creata dalle migrazioni Supabase lette. |
| Supabase seed | repo Supabase | not found | Nessun `seed.sql` / `*seed*.sql` trovato nei path cercati. |
| Supabase env/example | repo Supabase | not found / not read | Nessun `.env`, `.env.*`, `.env.example` o `*env*` trovato al livello ispezionato. `supabase/.temp/*` esiste ma non è fonte audit e non è stato aperto per evitare metadati/valori locali non necessari. |
| Supabase SQL candidate/legacy | `MerchandiseControlSupabase/sql/*.sql` | listed / partial | Presenti bozze/candidate (`products`, `suppliers`, `categories`, `product_prices`, `inventory_product_prices_candidate`). Non usate come fonte schema reale: la sintesi tabellare usa solo `supabase/migrations/`. |
| Supabase docs interni repo | `MerchandiseControlSupabase/docs/*`, `TASKS/*` | partial | Letti/consultati per contesto decisionale: `docs/decisions.md`, `id_strategy.md`, `mapping_room_to_supabase.md`, `room_current_model.md`, `supabase_target_model.md`, task RLS/conflict/ownership. Non sostituiscono le migrazioni come fonte DDL. |
| Supabase hosted/live DB | dashboard / database remoto | not accessed | Nessun confronto live eseguito; eventuale drift tra repo e ambiente hosted resta gap operativo. |
| iOS codebase | `/Users/minxiang/Desktop/iOSMerchandiseControl` | read | Target principale. Letti `Models.swift`, `HistoryEntry.swift`, `InventorySyncService.swift`, `PriceHistoryBackfillService.swift`; `DatabaseView.swift` ispezionato per import/export full DB e normalizzazione supplier/category. |
| iOS Supabase client/dependency search | `iOSMerchandiseControl/`, `iOSMerchandiseControl.xcodeproj/project.pbxproj` | read | Ricerca `Supabase`/`supabase` senza match: nessun client Supabase o SDK rilevato nel progetto iOS letto. |
| GitHub iOS aggiornato | `https://github.com/XNIW/iOSMerchandiseControl` | not accessed | Nessun fetch/remoto nel corso di TASK-033; audit basato sul clone locale. |
| Android codebase | `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView` | read | Riferimento funzionale. Letti `AppDatabase.kt`, entity Room richieste, `*RemoteRef*`, `SyncEventModels.kt`; `InventoryRepository.kt` ispezionato con grep/sezioni mirate solo per capire bridge/sync mapping. |
| GitHub Android | `https://github.com/XNIW/MerchandiseControlSplitView` | not accessed | Nessun fetch/remoto nel corso di TASK-033; audit basato sul clone locale. |

---

## 3. Supabase schema summary

Dati estratti unicamente dai file di migrazione elencati. Le bozze in `sql/*.sql` sono considerate candidate/legacy e non fonte di verità per questa sintesi. La migrazione Supabase `20260421120000_task038_restrict_authenticated_delete_inventory.sql` indica delete-restrict con gate operativo; si documenta il **target** DDL del repo, ma l’applicazione su DB hosted/live non è stata verificata.

| Table/View | Kind | Purpose inferred | Important columns | PK | FK | Unique/index | RLS/policy summary | Notes |
|------------|------|------------------|-------------------|-----|-----|--------------|---------------------|-------|
| `inventory_suppliers` | table | Fornitori per utente (`owner_user_id`) | id, owner_user_id, name, updated_at, **deleted_at** (019) | id uuid default gen_random_uuid() | owner_user_id → auth.users ON DELETE CASCADE | partial UNIQUE `(owner_user_id, lower(name))` WHERE deleted_at IS NULL (019) | authenticated: SELECT/INSERT/UPDATE; migrazione **038** rimuove policy DELETE su catalog e **`REVOKE DELETE`** su catalog+prices incl. questo — verificare applicazione ambiente live | Tombstone trigger anti-update dopo tombstone (019). anon: REVOKE ALL |
| `inventory_categories` | table | Categorie per utente | come suppliers | id | → auth.users | partial UNIQUE nome lower active | come sopra | idem |
| `inventory_products` | table | Prodotti catalogo remoti | id, owner_user_id, barcode, item_number, product_name, second_product_name, purchase_price, retail_price, supplier_id, category_id, stock_quantity, updated_at, deleted_at | id | supplier_id, category_id nullable → inventario FK; owner → auth.users | partial UNIQUE `(owner_user_id, barcode)` WHERE deleted_at IS NULL | come sopra | Barcode univoco **per owner**, non globale senza tenant |
| `inventory_product_prices` | table | Storico prezzi remoto user-scoped | id (uuid PK, generato client), owner_user_id, product_id, **type** CHECK ('PURCHASE','RETAIL'), price, effective_at **text**, source, note, created_at **text** | id | product_id → inventory_products CASCADE; owner → auth.users | UNIQUE (owner_user_id, product_id, type, effective_at); INDEX owner+product | SELECT/INSERT/UPDATE; DELETE revocato su authenticated (038) | Allineamento esplicito a stringa canonica tipo Room (commento migrazione 016). **Nessun** deleted_at su questa tabella nelle migrazioni lette |
| `shared_sheet_sessions` | table | Sessioni foglio inventario/remoto realtime | Evoluzione 010→012→040: remote_id (**text PK**), payload_version, `"timestamp"` text, supplier, category, is_manual_entry, **data** jsonb (array rows), updated_at timestamptz, **owner_user_id** uuid (012), **display_name** (040 default ''), **session_overlay** jsonb (040 + check shape/size) | remote_id text | owner_user_id → auth.users CASCADE | Constraint JSON session_overlay quando non null | 010: select pubblico anon+auth; **012**: TRUNCATE, owner obbligatorio, policy SELECT/INSERT/UPDATE/DELETE **solo owner** authenticated; REVOKE anon | Non è mirror 1:1 di tutta la History Room (commento 010) |
| `sync_events` | table | Telegraph/incrementale sync catalog/prices | id bigint GENERATED ALWAYS AS IDENTITY, owner_user_id uuid, store_id uuid null, domain, event_type, source, source_device_id, batch_id, client_event_id, changed_count, entity_ids jsonb, created_at timestamptz, expires_at, metadata jsonb | id | Nessun FK esplicito a catalog in DDL | UNIQUE (owner_user_id, client_event_id) WHERE not null; indici owner+created_at, domain id | anon/auth REVOKE ALL table; **GRANT SELECT** authenticated only; INSERT via RPC `record_sync_event` security definer | Funzione RPC valida dominio/event_type/metadata; realtime publication opzionale su tabella |

**Oggetti aggiuntivi**

- Funzione **`public.inventory_catalog_block_update_when_tombstoned`** + trigger BEFORE UPDATE su catalog (019): impedisce update su righe già tombstonate.
- Funzione **`public.record_sync_event`** (045): sicurezza, validazione UUID in entity_ids, idempotenza client_event_id.

---

## 4. iOS model summary

| iOS file | Model/type | Persistence | Key fields | Relationships | Used by screens/services | Notes |
|----------|------------|-------------|------------|---------------|---------------------------|-------|
| `Models.swift` | `Supplier` | SwiftData `@Model` | `name` (**unique**) | — | CRUD/import DB, `ExcelSessionViewModel`, `InventorySyncService` indiretto | Nessun owner_user_id né remote UUID; nominale come su Android storico ma senza collation NOCASE esplicito |
| `Models.swift` | `ProductCategory` | SwiftData | `name` (**unique**) | — | idem | idem |
| `Models.swift` | `Product` | SwiftData | `barcode` (**unique** globale sul device), optional prices, stock, item names | `supplier`, `category`, `priceHistory[]` cascade | GeneratedView, DatabaseView, import, InventorySyncService | PK tecnica PersistentIdentifier SwiftData ≠ UUID remota |
| `Models.swift` | `ProductPrice` | SwiftData | `type` PriceType (**purchase / retail** string Codable lowercase), `price` Double, `effectiveAt` **Date**, `source`, `note`, `createdAt` **Date** | `product` | Price history UI, InventorySync (`INVENTORY_SYNC`) | Divergenza: Supabase/`Room` usa stringhe **yyyy-MM-dd HH:mm:ss** e tipo **PURCHASE/RETAIL** maiuscolo remoto |
| `PriceHistoryBackfillService.swift` | service | SwiftData | backfill sorgente `BACKFILL`, data fissa `2000-01-01 UTC` (`Date(timeIntervalSince1970: 946684800)`) | `Product` → `ProductPrice` | Backfill storico da prezzi correnti esistenti | Rilevante per rapporto prezzo corrente vs storico; non è sync remoto |
| `HistoryEntry.swift` | `HistoryEntry` | SwiftData | `id` nome file (**non** uniqueness documentata UUID), `uid` UUID, `timestamp` Date, blob JSON grids, `supplier`/`category` string, aggregates, **`syncStatus`**, `wasExported` | — | Cronologia inventari, GeneratedView, export XLSX | Granularità diverso da `shared_sheet_sessions.remote_id` **text**: mapping cross-device è **needs decision**. `originalDataJSON`, `hasPersistedJSONDecodeFault` solo locale |
| `InventorySyncService.swift` | service | SwiftData `ModelContext` | Applica griglia inventario su `Product`; scrive retail + `ProductPrice` retail | Prodotti DB | GeneratedView dopo inventario | “Sync” nome = applicazione locale inventario ≠ Supabase |
| `DatabaseView.swift` | import/export service/UI | SwiftData + XLSX | Full export/import `Products`, `Suppliers`, `Categories`, `PriceHistory`; lookup supplier/category con trim e match esatto | Product/Supplier/Category/ProductPrice | Full DB import/export locale | Non esporta `remote_id`; normalizzazione locale non equivale a unique `lower(name)` Supabase |

---

## 5. Android Room model summary

| Android file | Entity/View/DAO | Table/view | Key fields | Relationships | Business role | Notes |
|--------------|-------------------|------------|------------|---------------|----------------|-------|
| `AppDatabase.kt` | `AppDatabase` | Room v15 | entities + `ProductPriceSummary` view + remote refs + tombstone pendenti + sync event local tables | DAO vari | Persistenza locale + bridge remoto | `exportSchema = true`; migrazioni documentano storico DDL |
| `Product.kt` | Entity | products | PK Long autogenerate; unique **barcode**; FK supplierId, categoryId; oldPurchase/oldRetail snapshot | Supplier, Category | Catalogo offline | Mirror campi verso inventario_products con ID locale Long |
| `Supplier.kt` / `Category.kt` | Entity | suppliers / categories | Long PK; name unique (**Category**: name **NOCASE**) | FK da Product | Lookup catalogo | Unicità sensibile case differs da Supabase **`lower(name)`** per tenant |
| `HistoryEntry.kt` | Entity | history_entries | Long uid; id string nome file; **timestamp**: String; Liste data/editable/complete; syncStatus enum | Remote ref table separata (`HistoryEntryRemoteRef`) | UI inventario e push remoto orchestrato nel repo Android | Divergenza iOS **Date**/JSON Data vs lista + string timestamp |
| `ProductPrice.kt` | Entity | product_prices | String type PURCHASE/RETAIL; **effectiveAt**, **createdAt** string formato fisso | FK product id Long | Audit trail prezzi locale | Direttamente omologabile semanticamente a `inventory_product_prices` (tipo + colonne text) |
| `ProductPriceSummary.kt` | DatabaseView | product_price_summary | Subquery ultimi/penultimi PURCHASE & RETAIL | — | Lettura consolidata prezzi storici | Equivalente SwiftData sarebbe derivato/query; non tabella fisica sul cloud nelle migrazioni lette |
| `ProductRemoteRef.kt`, `SupplierRemoteRef.kt`, … | bridge | *_remote_refs | remoteId **String**, revision counters, fingerprint opzionale | FK su entità locali | Mapping stable verso UUID Supabase già progettato lato Android | **Assente su iOS** attuale nella lettura TASK-033 |
| `SyncEventModels.kt` + DAO companion | watermark/outbox/state | tabelle Room sync event | Allineamento struttura a `sync_events` remoto (`SyncEventRemoteRow` con createdAt String da API) | — | Orchestrazione pull/push eventi | iOS non ha equivalente in swift letti |
| `InventoryRepository.kt` | repository | — | coordina fetch/push catalog, prezzi, history | Supabase data sources nel package | Business logic sync funzionale | File molto grande; audit concettuale: Android già integrate le policy remote |
| `ImportAnalysis.kt` / `ExcelViewModel.kt` etc. | util/viewmodel | — | campi analisi Excel | — | Derivazione colonne/griglia import | Solo se serve estendere mapping “campi generati”: non ricostruito riga-per-riga in questo audit |

---

## 6. Mapping matrix

Dominio sintetizzato sulle chiavi operative. Tipi/colonne Supabase dai DDL citati.

| Dominio | Supabase table | Supabase column | Supabase type | nullable/default | constraint/index/policy rilevante | iOS model/property | Swift/SwiftData type | Android entity/property | Kotlin/Room type | note/gap/decision needed |
|---------|----------------|-----------------|---------------|------------------|-----------------------------------|--------------------|----------------------|---------------------------|-----------------|----------------------------|
| Supplier | inventory_suppliers | id | uuid | NOT NULL PK | FK owner→auth.users; partial unique lower(name)+owner | Supplier.name (`@Attribute.unique`) non ha id remota | Supplier | Supplier.id Long; name | FK opzionale su Product | iOS/Android: chiave tecnica locale ≠ uuid; bridge ref solo Android (**gap iOS**) |
| Supplier tombstone | inventory_suppliers | deleted_at | timestamptz | nullable | tombstone triggers | — | — | PendingCatalogTombstone + refs (Android push) | varie | Nessun deleted_at Supplier su SwiftData nei file letti |
| Category | inventory_categories | id, name | uuid, text | come suppliers | partial unique nome | ProductCategory.name | ProductCategory | Category.name **NOCASE** | differs da iOS collation |
| Product | inventory_products | barcode | text | NOT NULL | UNIQUE (owner, barcode) active | Product.barcode | String | Product.barcode | String | Unicità iOS locale globale vs per-tenant Supabase (**decision**) |
| Product identità remota | inventory_products | id | uuid PK | gen_random_uuid() | Policies owner | PersistentIdentifier SwiftData implicito | — | Product.id Long | Gap: strategia UUID remota iOS (**proposed**) |
| Product campo | inventory_products | item_number | text | NULL | — | Product.itemNumber | String? | Product.itemNumber | String? | allineabile |
| Product prezzi «correnti» | inventory_products | purchase_price, retail_price | float8 | NULL | — snapshot remoto vs storico append-only prices | Product.purchasePrice, retailPrice | Double? | Product.purchasePrice, retailPrice + old* | Double? | `old*` Android solo locale |
| Stock | inventory_products | stock_quantity | float8 | NULL | — | Product.stockQuantity | Double? | Product.stockQuantity | Double? | |
| FK supplier/category remoti | inventory_products | supplier_id, category_id | uuid | NULL FK | ON DELETE SET NULL | Product.supplier / category refs | Persistent model ref | supplierId/categoryId Long? | FK Room | tipo PK diverso (**gap**) |
| updated_at catalog | inventory_products | updated_at | timestamptz | default utc now | — | implicit update via app | Product non ha campo esplicito | Product | Nessun campo updated_at locale esplicito in entity lette (**gap sync**) |
| Price history rigo | inventory_product_prices | type | text CHECK | NOT NULL PURCHASE\|RETAIL | | ProductPrice.type | PriceType `.purchase`/`.retail` | ProductPrice.type | String | Conversione casing/locale (**decision**) |
| Price history rigo | inventory_product_prices | price | float8 | NOT NULL | — | ProductPrice.price | Double | ProductPrice.price | Double | Precisione IEEE / display euro (**risk**) |
| Price history timestamps | inventory_product_prices | effective_at, created_at | **text** | NOT NULL | UNIQUE + type + product | ProductPrice.effectiveAt, createdAt | **Date** (ISO persisted) | String Room | String | Parsing round-trip iOS⇄Supabase (**gap**) |
| Price history FK | inventory_product_prices | product_id | uuid | NOT NULL | ON DELETE CASCADE | Product via relationship | — | ProductPrice.productId Long | FK | Join solo tramite barcode/remote_uuid (**defer**) |
| History sheet remoto minimale | shared_sheet_sessions | remote_id | text PK | — | realtime | HistoryEntry.uid / id naming diversi | UUID / filename String | HistoryEntry.uid Long; id filename | Gap modello pubblico anon vs poi owner-only (**decision sicurezza**) |
| History payload | shared_sheet_sessions | data / session_overlay | jsonb | overlay nullable chk | overlay max 524288 bytes | dataJSON blobs + computed arrays | JSON Data | Serialized lists Room | Divergenza struttura v1 vs v2 overlay (**unknown / needs decision** su parità fidelity) |
| History meta | shared_sheet_sessions | `"timestamp"` | text | NOT NULL | | HistoryEntry.timestamp | **Date** | HistoryEntry.timestamp | String | |
| Metadata sync/eventi | sync_events | domain, event_type, entity_ids jsonb… | vedere migrazione 045 | | SELECT auth only; INSERT RPC | Nessun counterpart iOS nei file letti | — | watermark/outbox Room | Solo Android implementato (**gap alto iOS**) |
| Import/export full DB iOS | — | — | — | — | — | DatabaseView.fullDatabaseImport/Export flows | SQLite bundle | FullDb utilities Android | — | Formati file diversi (**gap interoperability**) |

---

## 7. Decision log

| ID | Topic | Decision | Status | Rationale | Evidence/source | Follow-up |
|----|-------|----------|--------|-----------|-----------------|-----------|
| D-01 | ID locale vs remote | Catalogo deve usare UUID remota `inventory_*`.`id` per sync; chiavi Long/ PersistentIdentifier restano offline-only | proposed | Pattern già espresso in DDL Supabase e bridge Android (`*RemoteRef`) | migrazioni 013, `ProductRemoteRef.kt` | TASK-038+ progettare bridge iOS o equivalente; non riusare TASK-036/TASK-037 già assegnati |
| D-02 | UUID remota | Aggiungere/tenere campo ref UUID lato SwiftData quando si integrerà | proposed | Supabase usa uuid ovunque per FK | migrazioni 013/016 | TASK-034+ |
| D-03 | barcode business key | barcode = chiave naturale ricerca/dedupe; PK remota resta uuid; unique per **owner_user_id** in cloud | accepted | DDL partial unique + iOS uniqueness globale sul device crea semantic divergenza tra tenant | migrazioni 013, Models.swift | Documentare comportamento multi-user iOS (**needs user decision** quando auth introdotta) |
| D-04 | Timestamp | Catalog `updated_at` timestamptz UTC; storico prezzi **text canonica Room** sul cloud | accepted | DDL 016 commento esplicito | `inventory_product_prices.sql`, `ProductPrice.kt` | TASK-035 iOS normalization layer |
| D-05 | Soft delete | Catalog supporta **`deleted_at`** + trigger; storico prezzi senza tombstone DDL letto | accepted | migrazioni 019 vs assenza su prices | migrazioni 019/016 | Nessun soft delete storico remote — delete revocato (038): modello tombstone/obsolescenza |
| D-06 | Conflict policy | Conservativa futura: read-only / pull dry-run prima merge; niente last-write-wins implicito senza audit | proposed | Coerente con planning TASK-033 (conflict policy documentale) | File task Planning §9 | TASK-035, poi TASK-038+ |
| D-07 | Precisione prezzi | `double precision` remoto ⇄ `Double` Swift/Kotlin — arrotondamenti UI vs persistenza EU `,` | proposed | DDL + Models | ExcelSessionViewModel / NumberFormat esterni | QA import/export TASK futuro |
| D-08 | Supplier/category normalization | Remote: **`lower(name)`** unique scoped per owner; Android Category NOCASE; iOS uniqueness string SwiftData senza collation documentata | needs user decision | confronto DDL vs Room vs SwiftData | 013 migrations, Category.kt | Allineare regole casing prima del primo push catalogo da iOS |
| D-09 | Prezzo corrente vs storico | Prodotto mantiene `purchase_price`/`retail_price` snapshot; storico append-only (`inventory_product_prices`) + policy delete revoca | proposed | DDL + comment Android summary view | Migrazioni, ProductPriceSummary | Coerenza backfill quando prezzi cambiano offline |
| D-10 | History/generated sheets sync | Android integra realtime + refs remote; supabase sessions non equivalgono campo-per-campo a HistoryEntry.complete grid iOS locale | defer to future task | Commenti migrazioni 010 + estrusione overlay 040 | shared_sheet_sessions*, HistoryEntry.kt/iOS | TASK-038+ fidelity / volumi |
| D-11 | RLS / security | Catalog + prices scoped `auth.uid()=owner_user_id`; `sync_events` insert solo RPC hardened; anon senza grants su inventario | accepted | migrazioni 013/045 | — | TASK-034: integrare auth/session iOS stabile (**non TASK-033**) |
| D-12 | Auth multi-tenant | Schema Supabase **presuppone auth.users**; iOS TASK-033 **non introduce** login | defer to future task | FK owner uuid | DDL | Allineamento prodotto iOS quando abilitato Supabase auth |
| D-13 | Sync metadata iOS | iOS non deve inventare metadata sync in TASK-033; watermark/outbox/refs sono gap da task dedicato | defer to future task | Android ha `sync_event_*` + `*_remote_refs`; iOS non li ha nei file letti | `SyncEventModels.kt`, `AppDatabase.kt`, `Models.swift` | TASK-038+ o task design SwiftData refs |
| D-14 | Cosa sincronizzare subito | Primo perimetro futuro consigliato: client read-only, poi pull dry-run catalogo/prezzi; history/generated sheets rimandati per payload/volume/fidelity | proposed | Planning TASK-033 e rischio payload JSONB su `shared_sheet_sessions` | migrazioni 040, HistoryEntry.swift | TASK-034/035; TASK-038+ per history |
| D-15 | Timezone client | Catalog remoto usa `timestamptz`; price/history usano text. Prima del merge iOS serve regola esplicita di parsing/formattazione UTC vs locale UI | needs user decision | iOS `Date`, Room text, Supabase mixed `timestamptz`/text | Models.swift, ProductPrice.kt, migrations 013/016 | TASK-035 normalizzazione date |

---

## 8. Gap list

| ID | Area | Gap | Severity | Impact | Proposed follow-up | Blocker? |
|----|------|-----|----------|--------|--------------------|----------|
| G-01 | iOS SwiftData | Nessuna tabella bridge `*_remote_refs` né `remote_id` su modelli nel codice auditato | high | Nessun modo nativo SwiftData-ready per FK uuid Supabase osservabile | TASK-038+ design + migrazioni SwiftData (**after** D-01 user buy-in) | blocca sync catalogo affidabile senza modeling |
| G-02 | timestamps | Conversione ProductPrice Date↔︎text `yyyy-MM-dd HH:mm:ss` e PURCHASE casing | medium | Divergenze sorting / dedupe storico prezzi cross-platform | TASK-035 normalizer utility | no |
| G-03 | Supplier/category uniqueness | Collisioni casing/spazi tra iOS (`trim` + match esatto), Android supplier case-sensitive/category NOCASE e remote `lower(name)` | medium | Upsert/remoto può rigettare, fondere o duplicare nomi apparentemente uguali | Regole import + normalizzazione esplicita | no |
| G-04 | Soft delete parity | Tombstone remoti non rispecchiati in SwiftData attuale | medium | resurrect risk / orphans | Modeling deletedAt locale + UI | no |
| G-05 | Sync metadata iOS | Assenza watermark/outbox equivalente Android per `sync_events` | high | Nessun parity orchestrazione event-driven iOS vs Android | TASK-038+ infra | blocca parità realtime iOS/Android |
| G-06 | seed / staging data | Nessun seed SQL incluso nell’audit | low | onboarding dev lungo | Repo ops | no |
| G-07 | GitHub freshness | Repo remoti non fetchati durante audit | low | drift trascurato | Periodic diff | no |
| G-08 | Migrazioni non applicazione live | Nessun confronto contro DB Supabase hosted/live; file 019/038 hanno note/gate operativi | medium | Possibile divergenza tra repo e ambiente reale | Operational checklist Supabase progetto owner | finché ambiente ≠ repo |
| G-09 | RLS/security live | RLS/policy risultano dai file repo, non da introspection live | medium | Un client iOS potrebbe ricevere 401/403 o posture diversa rispetto al report | TASK-034 health/read-only + verifica auth separata | no |
| G-10 | Barcode | iOS/Android hanno unicità locale su barcode; Supabase unique solo `(owner_user_id, barcode)` attivo | medium | Duplicati cross-account legittimi; dedupe primo push da device multi-account richiede policy esplicita | TASK-035 report duplicati e decisione auth/onboarding | no |
| G-11 | Storico prezzi | Supabase/Android allineano type maiuscolo + timestamp text; iOS usa enum lowercase + `Date` e backfill locale | medium | Dedupe `inventory_product_prices` non perfettamente allineato senza normalizer | TASK-035 dry-run report storico prezzi | no |
| G-12 | History/generated sheets | iOS conserva blob JSON full-fidelity; Supabase `shared_sheet_sessions` ha `data` array e overlay max 524288 byte | high | Sync iniziale history può essere pesante o perdere fidelity se push naive | TASK-038+ dedicato history/session sync | no |
| G-13 | SQL legacy/candidate | `sql/*.sql` contiene bozze non equivalenti alle migrazioni reali (`products` vs `inventory_products`) | low | Confusione fonte schema se usate per implementare client | Continuare a usare `supabase/migrations` come source of truth | no |

---

## 9. Risk list

- **Mismatch ID**: Long Room / PersistentIdentifier SwiftData vs UUID Postgres → rischio join errati senza bridge.
- **Barcode duplicati cross-tenant**: unicità diverso locale vs `(owner_user_id, barcode)` remoto quando introdotti più account.
- **Precisione/prezzi floating**: double su tutta la pipeline; discrepanza centesimi dopo import/export.
- **Timezone**: storico usa stringhe naive `yyyy-MM-dd HH:mm:ss` vs `timestamptz` catalogo aggiorna — inconsistent interpretation se non UTC esplicitamente concordato.
- **RLS / auth bypass**: cliente read-only comunque deve rispettare JWT; errore configurazione ⇒ 401/403 silenziosamente interpretato male.
- **DELETE revocati (038)** su catalog/prices remoti ⇒ delete client legacy fallisce finché non migrato a tombstone — rischio regressione SDK vecchio Android **non osservabile iOS**.
- **Storico prezzi voluminoso**: import massivo ⇒ payload RPC / limiti Postgres.
- **History sheets JSONB size / overlay constraint** ⇒ export iOS blobs potrebbero violare constraint `<=524288` se push naive.
- **Supplier/category fuzzy duplicates** maiuscole/spazi.
- **Prezzo snapshot vs storico**: utente modifica offline solo `purchasePrice` campo prodotto senza append storico ⇒ drift cloud quando push.

---

## 10. Follow-up proposal

### TASK-034 — Supabase Swift dependency + skeleton client read-only

Task futuro dedicato, non creato qui: aggiungere Supabase Swift solo con approvazione esplicita, configurazione sicura senza segreti hardcoded e client/service minimale **read-only**. Niente push, niente merge, niente scrittura locale/remota.

### TASK-035 — Pull dry-run mapping

Fetch remoto read-only confrontato con SwiftData export snapshot o diff log; report file; mai scrivere SQLite.

### TASK-038 — Local merge controllato

Task futuro candidate, non creato qui. Nota tracking: `TASK-036` e `TASK-037` sono già usati nel progetto per import/XCTest HTML; il primo ID libero corrente è `TASK-038`.

Applicare merge locale controllato solo dopo report dry-run approvato: backup/log prima di ogni write, rollback definito, refs locali/remote tracciabili.

### TASK-039 — Push manuale controllato

Workflow esplicito utente tombstone-compliant; conflict logging; niente delete distruttive; push solo su azione manuale confermata.

### TASK-040+ — Sync avanzata

Sync avanzata, UI sync nativa iOS, background sync, conflitti avanzati, realtime/shared sheets parity e watermark iOS condiviso con backend `sync_events`.

---

## 11. Final confirmation

- **Nessun** codice Swift modificato in TASK-033.
- **Nessun** codice Kotlin modificato in TASK-033.
- **Nessuna** migrazione o schema SQL del repository Supabase alterato dall’audit.
- **Nessun** client Supabase implementato nell’app iOS durante TASK-033.
- **Nessuna** nuova dipendenza SPM Xcode aggiunta.
- **Output** unicamente questo documento e aggiornamento tracking del file task `TASK-033-*.md` / `docs/MASTER-PLAN.md`.
- **Stato review**: APPROVED; TASK-033 chiusa su autorizzazione utente esplicita dopo review documentale.
