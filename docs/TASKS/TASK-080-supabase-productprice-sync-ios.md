# TASK-080 — ProductPrice sync completa iOS ↔ Supabase

## Informazioni generali

| Campo | Valore |
|-------|--------|
| **Task ID** | TASK-080 |
| **Titolo** | ProductPrice sync completa — pull/apply/push storico prezzi, coerenza Android/Supabase |
| **File task** | `docs/TASKS/TASK-080-supabase-productprice-sync-ios.md` |
| **Stato** | DONE |
| **Fase attuale** | Chiusura |
| **Responsabile attuale** | Claude / Reviewer |
| **Data creazione** | 2026-05-08 |
| **Ultimo aggiornamento** | 2026-05-08 17:24 -0400 — REVIEW/FIX/CHIUSURA completata; fix conteggi summary/stale apply applicati; build/test/lint/grep PASS; TASK-080 DONE / Chiusura. |
| **Ultimo agente** | Claude / Reviewer |

## Dipendenze

- **Dipende da:** **TASK-078 DONE / Chiusura** (pull apply catalogo guidato Release); **TASK-079 DONE / Chiusura** (push catalogo guidato Release); **TASK-076 DONE / Chiusura** (audit: ProductPrice classificato PARTIAL); infrastruttura storica apply/preview/push prezzi (`SupabaseProductPriceApplyService`, `SupabaseProductPricePreviewService`, `SupabaseProductPriceManualPushService`, dry-run, XCTest).
- **Sblocca:** dopo execution/review futura, allineamento naturale con **TASK-081** (drain outbox anche per eventi dominio `prices`), **TASK-082** (policy conflitti se apply/push prezzi espone conflitti non risolti oggi), **TASK-083** (smoke E2E), **TASK-084** (parità Android).

## Scopo

Completare in **Release**, con lo **stesso spirito manuale e confermato** di TASK-078/079, la sincronizzazione dello **storico prezzi** (`ProductPrice` SwiftData ↔ tabella remota `inventory_product_prices`), inclusi:

- **Pull / preview** (gia' parzialmente nel diff catalogo tramite `SupabasePullPreviewService` e segnali `priceHistoryIncomplete`);
- **Apply locale** dopo conferma (servizio dedicato `SupabaseProductPriceApplyService` esistente ma **non** nel flusso Release unificato);
- **Push remoto** controllato (servizio `SupabaseProductPriceManualPushService` + dry-run; oggi **DEBUG-heavy** via `ProductPriceManualPushDebugViewModel`, non card Release).

Obiettivo prodotto: l’utente puo’ **portare sul dispositivo** le variazioni di prezzo registrate sul cloud e **inviare al cloud** le proprie registrazioni di prezzo, con **batch limitati**, **controllo delle duplicazioni**, e messaggi **senza termini tecnici** (niente riferimenti visibili a codici interni, RPC, o nomi di tabelle).

## Criteri di accettazione *(contratto planning-only — questo turno)*

- [x] Questo file creato con sezioni obbligatorie (gap, decisioni **D80-xx**, micro-slice **S80-x**, strategia dati, fuori perimetro, test pianificati, grep anti-scope, rischi, DoR/DoD planning, handoff).
- [x] Integrazione **2026-05-08**: efficienza batch/mappe, idempotenza (**D80-09…13**), current/previous, UX «Prezzi da aggiornare», partial/retry/recovery, **Execution gates**, micro-slice **S80-a…f** raffinate.
- [x] Stato **ACTIVE / PLANNING**, responsabile **Claude / Planner**; **TASK-080 NON DONE**; **NON READY FOR EXECUTION**.
- [x] Riassunto **repo-grounded** dello stato iOS su ProductPrice/sync (nessun codice modificato in questo task-planning).
- [x] Schema Supabase citato solo da migrazioni lette in **`/Users/minxiang/Desktop/MerchandiseControlSupabase`** (nessuna inferenza oltre il file).
- [x] Review **2026-05-08**: coerenza MASTER-PLAN, acceptance criteria futura, mapping, **effectiveAt** vs **updated_at**, recovery/stale, test **T80-10+**, rischi **R-07+**.
- [x] Riferimento Android **funzionale** (file letti sotto), senza modifiche Kotlin.
- [x] **Hardening finale 2026-05-08:** **H80-01…H80-05** (UX sheet **Rivedi**, dataset grande, piano volatile, acceptance/gate aggiuntivi).
- [x] **Nessuna** execution Swift autorizzata da questo documento fino a handoff esplicito futuro verso **Codex / Executor**.

---

## Coerenza MASTER-PLAN ↔ TASK-080 *(verifica documentale)*

Gli elementi citati nel journal **MASTER-PLAN** su TASK-080 sono coperti nel file task come segue:

| Tema MASTER-PLAN | Dove nel task |
|------------------|---------------|
| Batch bounded | § Raffinamento efficienza dati; **D80-03**; **S80-b/c** |
| Anti-N+1 | § Raffinamento efficienza dati; **R-06**; **S80-b** |
| Dedupe locale/remota | § Raffinamento efficienza; **Idempotenza**; **D80-04, D80-09…D80-11** |
| Idempotenza | § Idempotenza; **D80-09…D80-13** |
| Current/previous price | § Current vs Previous Price; §9 Strategia dati |
| Partial/retry/recovery | § Partial, retry, recovery (esteso con stale/auth) |
| UX «Prezzi da aggiornare» | § UX/UI Release futura; **D80-14**; **S80-d** |
| Execution gates | § Execution gates (esteso); **H80-05** |
| Micro-slice S80-a…f | §7 |
| UX/performance / piano volatile (journal HARDENING) | **§ Hardening H80-01…H80-05** |
| TASK-080 NON DONE / NON READY FOR EXECUTION | Handoff; §15; criteri planning; **H80 chiusura stato** |

---

## 1. Obiettivo operativo *(per fasi future EXECUTION — non attivate qui)*

Portare il perimetro prezzi al pari del catalogo gia’ coperto da TASK-078/079:

1. **Dal cloud al dispositivo:** applicare righe `inventory_product_prices` in `ProductPrice` SwiftData quando l’utente conferma, con **dedupe/idempotenza** coerente con i **vincoli remoti** e con la logica gia’ presente in `SupabaseProductPriceApplyService` (chiave logica `(product_id remoto, tipo, effective_at canonico)`; verifica post-insert).
2. **Dal dispositivo al cloud:** inviare incrementi storici sicuri verso `inventory_product_prices` dopo **preflight/dry-run** e conferma, riusando `SupabaseProductPriceManualPushService` (batch bounded, read-back di verifica), analogamente al push catalogo TASK-079.
3. **Prezzo corrente vs precedente:** mantenere coerenza tra `Product.purchasePrice` / `Product.retailPrice` (specchio “corrente” nel modello catalogo) e le righe di storico (incluso backfill locale `PriceHistoryBackfillService` e semantica **ultimo/penultimo** lato Android `ProductPriceSummary`).
4. **Allineamento cross-platform:** stessi campi semantici di `RemoteInventoryProductPriceRow` ↔ colonne SQL; stessi tipi `PURCHASE`/`RETAIL`; stessa stringa canonica `effective_at` / `created_at` (formato testuale Room/Android documentato nelle migrazioni iOS come “yyyy-MM-dd HH:mm:ss”).
5. **Conflitti complessi** (es. stessa chiave logica con valori diversi, merge multi-device avanzato): **non** risolvere silenziosamente in TASK-080 — rimandare a **TASK-082** o esplicitare blocco user-facing.

---

## 2. Stato attuale iOS *(repo-grounded)*

### 2.1 Modello SwiftData

- **`Product`:** `remoteID`, `remoteUpdatedAt`, `remoteDeletedAt`, `purchasePrice`, `retailPrice`, relazione `priceHistory` verso `ProductPrice`.
- **`ProductPrice`:** `type` (`PriceType`), `price`, `effectiveAt`, `source`, `note`, `createdAt`, relazione verso `Product`. **Non** esiste un campo **`remoteID`** persistito sulla riga storico locale: l’id UUID della riga Supabase e’ noto ai servizi remoti/DTO ma non ancorato nel modello; l’apply service usa chiavi logiche e **re-prepara** il piano per verifica dopo `save()`.

### 2.2 Preview catalogo e segnale prezzi

- **`SupabasePullPreviewService`:** scarica pagine `inventory_product_prices` insieme al catalogo; su errore o incompletezza possono comparire warning / `sourceErrors` con codice **`priceHistoryIncomplete`**, che **bloccano** l’apply catalogo in **`SupabasePullApplyService`** (`validateGlobalGuards` → `priceHistoryIncomplete`). Effetto: finche’ la storia prezzi remota non e’ leggibile/consistente con le aspettative del preview, **nemmeno** l’apply solo-catalogo e’ permesso — accoppiamento forte da chiarire in execution (TASK-080).

### 2.3 Apply storico prezzi *(servizio verticale)*

- **`SupabaseProductPriceApplyService`:** `prepareApplyPlan` / `apply(plan:)` su `ModelContext`; inserisce `ProductPrice` per linee approvate; **skip** se esiste gia’ una riga locale con stessa chiave logica e stesso prezzo canonico; **blocca** su conflitti (stessa chiave, prezzi diversi). Session snapshot `ProductPriceApplySessionSnapshot` impedisce applicazioni stale.

### 2.4 Push storico prezzi *(servizio verticale + DEBUG UI)*

- **`SupabaseProductPriceManualPushService`:** payload `ProductPriceManualPushPayload` mappato su colonne snake_case; **batchLimit** default max **100**; verifica post-insert paginata.
- **`SupabaseProductPricePushDryRunService`** + **`ProductPriceManualPushDebugViewModel`:** flusso dry-run / snapshot / push in contesto **DEBUG**, non equivalRelease card TASK-079.

### 2.5 Outbox / sync_events *(solo accenno — drain = TASK-081)*

- **`SyncEventOutboxEnqueueService`:** esiste mapping **`productPriceManualPush`** con dominio **`prices`** ed event type **`prices_changed`**, allineato allo schema RPC `record_sync_event` nel clone Supabase. **Nessun** obbligo di drain in TASK-080.

### 2.6 UX Release oggi

- **`SupabaseManualSyncViewModel`:** sezione review **Prezzi** con copy che indica passaggio dedicato (`needsDedicatedStep` / `noAction`) — coerente col fatto che **TASK-078/079** non hanno cablato apply/push prezzi Release.

### 2.7 Test esistenti *(estratti grep)*

`SupabaseProductPriceApplyServiceTests`, `SupabaseProductPricePreviewServiceTests`, `SupabaseProductPriceManualPushServiceTests`, `SupabaseProductPricePushDryRunServiceTests`, oltre a riferimenti incrociati in test manual sync / pull preview / enqueue outbox.

---

## 3. Riferimento Supabase *(solo lettura, repo clone locale)*

**Fonte:** `MerchandiseControlSupabase/supabase/migrations/20260417200000_task016_inventory_product_prices.sql`

| Elemento | Contenuto verificato |
|----------|----------------------|
| Tabella | `public.inventory_product_prices` |
| PK | `id uuid PRIMARY KEY` (generazione lato client come da commento migrazione) |
| Ownership | `owner_user_id uuid NOT NULL REFERENCES auth.users` |
| FK prodotto | `product_id uuid NOT NULL REFERENCES inventory_products(id) ON DELETE CASCADE` |
| Colonne business | `type` (`PURCHASE` \| `RETAIL`), `price` double, `effective_at text NOT NULL`, `source`, `note`, `created_at text NOT NULL` |
| Unicita’ | `UNIQUE (owner_user_id, product_id, type, effective_at)` |
| RLS | policy SELECT/INSERT/UPDATE/DELETE per `authenticated` su `owner_user_id` *(nota: migrazione successiva Task 038 rimuove DELETE grant — vedi sotto)* |

**Fonte:** `20260421120000_task038_restrict_authenticated_delete_inventory.sql`

- Revoca **DELETE** per ruolo `authenticated` su `inventory_products` e `inventory_product_prices`; drop policy `inventory_product_prices_delete_owner`. Implicazione: **tombstone / annullamenti** prezzi lato cloud devono seguire policy aggiornata (es. dominio `prices_tombstone` in `sync_events` / altro meccanismo) — **non** assumere DELETE PostgREST su `inventory_product_prices` in Release.

**Fonte:** `20260424021936_task045_sync_events.sql`

- Dominio MVP **`prices`** con event types **`prices_changed`**, **`prices_tombstone`** (validator RPC). Dipendenza **logica** futura tra push prezzi e outbox; **drain Release = TASK-081**.

**Cosa non compare in Task 016 (e non va inventato):** colonne `updated_at` / `deleted_at` sulla tabella prezzi — il modello remoto e’ centrato su **`effective_at` / `created_at`** testuali + vincolo di unicita’ logico. Per **`inventory_products`**, `updated_at` e tombstone sono documentati in **§ EffectiveAt, created_at e updated_at** e in Task 013/019.

**DTO iOS:** `RemoteInventoryProductPriceRow` in `SupabaseInventoryDTOs.swift` rispecchia il subset colonne sopra (`id`, `owner_user_id`, `product_id`, `type`, `price`, `effective_at`, `source`, `note`, `created_at`).

---

## 4. Riferimento Android *(funzionale — file letti)*

Percorso: `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView`

| File | Utilita’ per TASK-080 |
|------|------------------------|
| `data/ProductPrice.kt` | Entity Room `product_prices`: chiave composta logica `(productId, type, effectiveAt)` unica; tipo stringa PURCHASE/RETAIL; `effectiveAt` / `createdAt` stringhe. |
| `data/ProductPriceSummary.kt` | View `product_price_summary`: per ogni prodotto calcola **ultimo** e **penultimo** prezzo per tipo (acquisto/vendita) ordinando per `effectiveAt`. |
| `data/InventoryCatalogRemoteRows.kt` | Righe catalogo/prezzi lato Kotlin (**es.** `InventoryProductPriceRow`) — utile in **S80-a** per mapping con DTO iOS. |

**Lettura pianificata in S80-a (non bloccante per questo markdown):** `PriceBackfillWorker`, `InventoryRepository`, `DatabaseViewModel`, `ImportAnalyzer` — parita’ import/export storico e backfill rispetto a iOS `PriceHistoryBackfillService`.

---

## 5. Gap principali *(da TASK-076 + lettura codice / schema)*

1. **Nessun wiring Release** per apply/push prezzi dopo **Controlla cloud / Rivedi / Conferma** (alla stessa stregua TASK-078/079).
2. **`SupabasePullApplyService`** rifiuta apply catalogo se il preview segnala **`priceHistoryIncomplete`**: i prezzi remoti possono **bloccare** l’aggiornamento catalogo anche quando l’utente vorrebbe solo catalogo — va **progettato** se separare le policy (risk: incoerenza prezzi vs anagrafica).
3. **UUID riga remota** non persistito su `ProductPrice` SwiftData: idempotenza locale si affida a chiave `(product remote UUID, tipo, effective_at)`; ok per re-apply verificato, ma **debug/correlazione** e **parità Android** potrebbero beneficiare di stored `remoteRowID` in una fase execution (decisione **D80-05**).
4. **Push prezzi** con flusso **DEBUG** (`ProductPriceManualPushDebugViewModel`): duplicazione UX rispetto alla card Release; va **consolidato** dietro le stesse regole di TASK-079 (preflight, snapshot volatile, conferma, summary).
5. **`inventory_product_prices` senza DELETE authenticated:** ogni “rimozione” remota deve rispettare **append-only + eventi**; allineamento iOS/Android da validare con **TASK-084** e smoke **TASK-083**.
6. **Enqueue outbox** post-push prezzi: codice preparato; **drain** non parte del perimetro TASK-080 (**TASK-081**).
7. **Baseline catalogo:** TASK-078 nota che `SupabasePullApplyService` non aggiorna il baseline persistente; dopo mutazioni prezzi remoto/locale va chiarito se serve **refresh baseline** o **nuovo Controlla cloud** (coerenza con TASK-079 post-push catalogo).

---

## Raffinamento efficienza dati *(planning)*

- **Niente sincronizzazione ProductPrice con query per-riga (N+1)** su grandi dataset: tutte le fasi future devono progettarsi su **fetch paginato / batch** gia’ noti nei servizi (preview, push, apply con snapshot locale costruito per scansione controllata), senza loop che ricaricano un prodotto alla volta dal persistence.
- **Prima delle mutazioni**, costruire una **mappa locale in-memory** (o struttura equivalente O(1) lookup), nell’ordine logico di planning, con almeno:
  - identità prodotto locale (persistent ID SwiftData o chiave stabile usata in execution);
  - **barcode**;
  - **remote product id** (`Product.remoteID` se presente);
  - **prezzi correnti operativi** su `Product` (acquisto / vendita);
  - **precedente acquisto / precedente vendita** derivati dallo **storico** (ordinamento `effectiveAt` sulle righe gia’ note o su campione batch), non da campi duplicati ad-hoc.
- **Operazioni future batch bounded:** il piano propone **blocchi piccoli e sicuri**, indicativamente **300–500 righe di prezzo per batch** (ordine di grandezza per execution); la cifra finale e’ **parametro di execution** (deve essere commisurata a memoria, timeout rete e limiti PostgREST). I default codice oggi (**es.** push prezzi max **100** per `ProductPriceManualPushOptions`) restano **vincoli attuali** finche’ un override non sia giustificato in review.
- **Ogni micro-slice (S80-a…f)** deve dichiarare esplicitamente come **evita N+1** (mappe, sort merge, un solo fetch descriptor dove possibile).
- **Dedupe locale** prima di `save()` SwiftData: ridurre in-memory le righe da inserire (stessa osservazione logica → una sola write o skip conteggiato).
- **Dedupe remoto** prima del push Supabase: il dry-run / piano volatile deve escludere candidati gia’ presenti in cloud secondo la **stessa chiave del vincolo reale** (vedi sezione Idempotenza).
- **Nessuna materializzazione enorme in RAM:** non tenere in memoria l’intero storico negozio se evitabile; streaming per pagina + aggregati per summary; per execution gates vedi **dataset grande stimato**.

---

## Product identity e mapping *(rafforzamento planning)*

- **Il prezzo non deve essere ancorato al nome prodotto** (`productName` / stringhe mostrate) come chiave di join: troppo fragile (locale, duplicati, rename).
- **Identità preferita:** `product_id` remoto (**UUID** su `inventory_products`) allineato a **`Product.remoteID`** su SwiftData dopo che il catalogo locale conosce il bridge.
- **Fallback:** **barcode** — solo se **presente**, **non vuoto** e **univoco** nel contesto utente (`Product` `@Attribute(.unique)` su `barcode` a livello modello; resta da rispettare anche coerenza con prodotti remot senza duplicati logici). Se il barcode **manca** o risulta **ambiguo** (duplicati locali o mismatch con piu’ candidati remoti), la riga prezzo deve classificarsi come **`blocked` / `skippedConflict`** nel summary futuro — **mai** applicare/pushare in silenzio.
- **Prezzi orfani** (riga `inventory_product_prices` il cui `product_id` non risolve a un `Product` locale con mapping valido): gia’ segnalati in preview come **orphan** / unmapped nei servizi esistenti; in execution, restano **skipped** o **blocked** con copy user-facing «servono verifiche», non insert „best effort“.
- **Ordine operativo:** costruire / validare il **mapping prodotto locale ↔ remoto** (mappe § Raffinamento) **prima** di congelare il **piano prezzi** (stesso principio del preflight catalogo TASK-079).

---

## Idempotenza ProductPrice *(planning)*

**Requisito:** il flusso prezzi deve essere **idempotente**: la **stessa osservazione di prezzo** (stesso contesto business) **non** deve creare **duplicati** remoto né locale oltre i vincoli consentiti.

**Fonte di verità vincolo remoto (gia’ in schema Supabase letto):**  
`UNIQUE (owner_user_id, product_id, type, effective_at)` su `inventory_product_prices` (**Task 016**). **Il planning usa questa** come **chiave di dedupe remota autorevole** — **non** introdurre una chiave concorrente se contraddice il DB.

**Chiave logica client (allineamento iOS attuale + estensione concettuale):**  
il codice apply oggi lavora su chiave **`(product_id UUID remoto, tipo normalizzato, effective_at canonico)`** + verifica valore; il push usa **UUID riga** client come PK. Una **osservazione** completamente specificata puo’ includere anche `price` e `source` per **fare matching** con righe gia’ presenti e per **classificare skip**, ma **l’unicita’ persistente** resta quella **SQL** sopra se `effective_at` coincide. Se **due intenzioni** collidono sulla stessa tripletta `(product, type, effective_at)` con **prezzo diverso**, non e’ idempotenza: e’ **conflitto** → **TASK-082** o fail-closed (vedi D80-06).

Le decisioni **D80-09…D80-13** sono consolidate nella **tabella §6** (nessuna tabella duplicata qui).

---

## EffectiveAt, created_at e updated_at — policy *(planning)*

**Tabella prezzi `inventory_product_prices` (Task 016, verificata):**

| Campo schema | Ruolo |
|--------------|--------|
| `effective_at` (text) | **Momento di validità business** del prezzo (osservazione storica). **Fonte primaria** per ordinamento ultimo/penultimo e per dedupe UNIQUE con `(product_id, type)`. |
| `created_at` (text) | **Momento di registrazione** della riga (meta; allineato a convenzioni Room/Android nel progetto). |
| *(assente)* `updated_at` / `deleted_at` | **Non** dichiarati su questa tabella nella migrazione letta — **non** usarli come proxy del prezzo. |

**Tabella catalogo `inventory_products` (Task 013 + Task 019 tombstone):**

| Campo | Ruolo |
|-------|--------|
| `updated_at` (timestamptz) | **Ultima modifica** della riga prodotto lato server (sync/metadato catalogo). **Non** sostituisce `effective_at` dello storico prezzi. |
| `purchase_price` / `retail_price` | **Specchio corrente** sul catalogo remoto; va tenuto distinto dalle righe `inventory_product_prices` ma può informare l’allineamento del **current** locale (**§ Current vs Previous**). |
| `deleted_at` | Tombstone catalogo — non confondere con cancellazione riga prezzo (Task 038). |

**Decisioni:**

- **D80-17:** Per lo **storico prezzi**, **`effective_at`** (normalizzato/canonico come oggi nei normalizer iOS) è la **semantica del prezzo**; **non** usare `updated_at` di `inventory_products` come sostituto del timestamp di una voce storico-prezzo.
- **D80-18:** Se in una migrazione futura comparissero nomi o tipi diversi o ambiguità (es. due colonne data in conflitto), trattare come **execution gate bloccante** fino a aggiornamento esplicito di questo planning e del codice.

---

## Current vs Previous Price *(raffinamento)*

- **`ProductPrice` (SwiftData) = storico** delle osservazioni di prezzo nel tempo (tipicamente PURCHASE / RETAIL con `effectiveAt`).
- **`Product.purchasePrice` / `Product.retailPrice` = valore corrente operativo** mostrato e usato nel flusso anagrafica; non sostituiscono lo storico.
- **Previous (penultimo) price:** deve **derivare dallo storico** (ordine per `effectiveAt`, stesso tipo), analogamente alla view Android `ProductPriceSummary` (ultimo / penultimo per tipo). **Evitare** campi duplicati “previous_*” fragili salvo compatibilita’ legacy gia’ presente e documentata.
- **Pull remoto (futuro wiring Release):**
  - applicare **storico** come righe `ProductPrice` coerenti con il vincolo remoto;
  - aggiornare **`Product` current** solo se **policy documentata** (es. allineare agli ultimi valori noti dalla riga catalogo remota **e/o** dall’ultima voce storica) e **solo** quando non si viola una regola anti-sovrascrittura: **non** sovrascrivere silenziosamente un prezzo locale **piu’ recente** o in **conflitto non risolvibile** nel perimetro TASK-080 → segnalazione utente o blocco → **TASK-082** per policy globale.
- **Push locale (futuro):**
  - inviare **solo** righe storiche **mancanti** in cloud secondo dedupe remoto;
  - **no duplicati** intenzionali;
  - **nessuna promessa** di risoluzione conflitti avanzati: **TASK-082**.

*(Coerenza con § Strategia dati: la tabella in §9 resta valida; questa sezione ne fissa le regole prodotto/tecnica.)*

---

## 6. Decisioni provvisorie *(D80-xx)*

| ID | Decisione | Nota |
|----|-----------|------|
| D80-01 | TASK-080 copre **pull preview + apply + push** prezzi in **Release manuale**, **senza** sync automatica/background | Allinea a roadmap TASK-076–085. |
| D80-02 | Riutilizzare **servizi esistenti** (`SupabaseProductPriceApplyService`, `SupabaseProductPriceManualPushService`, preview paging) con **DI minimale** dalla `SupabaseManualSyncReleaseFactory` / ViewModel | No rewrite esteso. |
| D80-03 | **Batch bounded:** oltre ai default codice attuali, il planning **target** per execution include blocchi **~300–500 righe prezzo** dove sicuro; rivalutare limiti push attuali (**100**) in review se coerente con memoria/timeout | Parametro finale in execution + test. |
| D80-04 | **Dedupe/idempotenza:** vedi **D80-09…D80-13** e sezione **Idempotenza ProductPrice** | Conflitti valore vs chiave → **TASK-082** o fail-closed. |
| D80-05 | **Opzionale (execution):** valutare aggiunta **`remoteRowID`** opzionale su `ProductPrice` SwiftData per correlazione e tombstone future — **non** deciso nel planning iniziale; se assente, restare sulla chiave logica attuale | Richiede migration modello SwiftData → solo dopo approvazione esplicita. |
| D80-06 | **Separation of concerns TASK-082:** conflitti multi-device, LWW globale, merge interattivo — fuori da TASK-080 salvo messaggistica “servono decisioni” | Fail-safe: blocco + copy chiaro. |
| D80-07 | **Domain sync_events**: push prezzi puo’ produrre enqueue **solo se** gia’ previsto dal codice e accettato dal product owner; **drain** sempre **TASK-081** | Non implementare drain qui. |
| D80-08 | **Ordine operazioni suggerito** (come TASK-079): se ci sono sia modifiche remote catalogo/prezzi sia invii locali, preferire **prima aggiornare il dispositivo**, **poi inviare** — salvo review product che inverta | Riduce conflitti. |
| D80-09 | Idempotenza obbligatoria apply/push | Vedi sezione Idempotenza. |
| D80-10 | Dedupe = UNIQUE Supabase `(owner_user_id, product_id, type, effective_at)` | Vedi sezione Idempotenza. |
| D80-11 | Chiave logica operativa per skip/summary | Prodotto + tipo + effectiveAt + price + source (subset coerente col DB). |
| D80-12 | Stessa chiave SQL, metadata diversa → non merge silenzioso | Conflitto / skip esplicito. |
| D80-13 | Drift schema unico → gate execution | Aggiornare planning prima di procedere. |
| D80-14 | **Ordine UX catalogo+prezzi:** le azioni **Aggiorna questo dispositivo** / **Invia modifiche al cloud** restano **macro-flusso**; i prezzi compaiono come **dettaglio nella review**, non come flusso parallelo separato | Allinea a § UX/UI Release futura. |
| D80-15 | **Identità prodotto per prezzi:** primario **`Product.remoteID`** ↔ `product_id` remoto; fallback **barcode** solo se univoco/validato; **no** join su nome display | § Product identity. |
| D80-16 | **Orfani / barcode mancante o duplicato:** classificare **`blocked` / skippedConflict**; nessuna write silenziosa | Allinea a preview orphan esistente. |
| D80-17 | **effectiveAt** = validità prezzo; **`updated_at` catalogo** ≠ storico prezzo | § Timestamp policy. |
| D80-18 | **Drift naming/ambiguità date** su schema → gate bloccante | Execution + planning refresh. |

---

## 7. Micro-slice future *(S80-a … S80-f — solo planning, zero implementation ora)*

| ID | Descrizione concreta |
|----|----------------------|
| **S80-a** | **Inventory / mapping** ProductPrice **iOS ↔ Supabase ↔ Android:** tabella equivalenze campi (`RemoteInventoryProductPriceRow`, migrazioni `inventory_products` / `inventory_product_prices`, Room `ProductPrice` / `InventoryProductPriceRow` Kotlin); regole `owner_user_id`, `effective_at` testuale, tipo prezzo; aggiornare questo documento + eventuale diagramma interno task. |
| **S80-b** | **Pull / apply ProductPrice** locale: integrare nel percorso manuale **dopo conferma**, **fakeable** in test, **batch bounded** + mappe locali (sezione efficienza), **nessun N+1**; risolvere o convivere con `priceHistoryIncomplete` vs catalogo (vedi R-01). |
| **S80-c** | **Push ProductPrice** verso Supabase: **preflight read-only** + **piano volatile** + conferma (stile TASK-079); **dedupe remoto** prima della write; read-back/verifica gia’ previsti dal servizio; **nessun drain**. |
| **S80-d** | **Review / summary UX** ProductPrice nel flusso esistente: sezione **«Prezzi da aggiornare»** nella sheet **Rivedi**; copy semplice (vedi § UX); conteggi **privacy-safe**; **una** CTA primaria coerente col macro-passo (non mescolare due azioni promosse). |
| **S80-e** | **Test** grandi volumi / **dedupe** / **idempotenza:** pianificare fixture o dataset sintetico grande, stress mappe in-memory + paginazione; regressione apply/push/dry-run; grep anti-scope. |
| **S80-f** | **Review / fix / closure** (fase futura): handoff Claude post-execution, **non** parte di questo planning-only. |

**Nota:** eventuale **enqueue** outbox post-push resta **opzionale** e **mai** accompagnata da drain in TASK-080 (**TASK-081**).

---

## UX/UI Release futura per ProductPrice *(solo planning, nessuna implementazione)*

### Posizione nella navigazione

- La sezione **«Prezzi da aggiornare»** deve stare **dentro la sheet «Rivedi»** gia’ prevista dal flusso TASK-077/078/079 — **non** come flusso separato o nuova gerarchia di schermate.
- **Priorità:** in caso di tensione tra **completezza tecnica** e **chiarezza** per l’utente, vince la **chiarezza UX**; dettaglio tecnico resta in **log/test** (non in copy Release).

### Sheet **Rivedi** — sezione dedicata

- Titolo sezione orientato all’utente: **«Prezzi da aggiornare»** (o equivalente localizzato).
- Frasi semplici proposte (placeholder copy — da passare da **l10n** in execution):
  - **«Nuovi prezzi trovati»**
  - **«Prezzi gia’ presenti sul dispositivo»**
  - **«Prezzi saltati: servono verifiche»** *(equivalente user-facing per blocked/skip non tecnico)*
  - **«Alcuni prezzi non sono stati aggiornati»** *(errore parziale)*

### Termini da **non** mostrare in Release

`ProductPrice`, `RPC`, `outbox`, `sync_events`, `baseline`, `payload`, `idempotenza`, nomi tabelle, UUID grezzi, stack trace.

### Stile

- **SwiftUI** nativo, sezioni compatte, **SF Symbols** semantici, **colori semantici** (`.secondary`, stati success/warning senza jargon).
- **Una sola** CTA **`.borderedProminent`** per stato (come governance TASK-076/079).
- **Summary finale** leggibile: cosa e’ stato applicato / inviato / saltato — senza schermate dense non necessarie.

### Ordine quando **catalogo e prezzi** coesistono *(rafforzato)*

1. **Aggiorna questo dispositivo** — se ci sono modifiche **remote** (catalogo; i prezzi sono spiegati nella stessa review / stesso riepilogo).
2. **Invia modifiche al cloud** — se ci sono modifiche **locali** da inviare (dopo il passo 1 quando entrambe presenti, come TASK-079).
3. I **prezzi** restano **dettaglio** nella **review/summary** (sezione «Prezzi da aggiornare» + riepilogo finale), **non** un terzo percorso navigazionale separato — **D80-14**.

Card/scheda principale **compatta** (stile esistente `OptionsView`); contenuti lunghi restano nella sheet.

---

## Partial, retry, recovery *(planning)*

- **Fallimento parziale:** se solo **alcune** righe prezzo falliscono o sono bloccate, il flusso futuro deve comunque consentire di **completare le righe valide** e presentare un **summary parziale** — la review nel suo insieme **non** deve essere trattata come fallimento totale **solo** perché esistono sotto-insiemi problematici (salvo guard espliciti che bloccano tutto per sicurezza, da documentare in execution). Il summary **non** e’ „successo assoluto“ se restano voci **failed** / **blocked** / **skippedConflict** non risolte nel dominio prezzi.
- Righe problematiche → aggregate in **`skippedDuplicate` / `skippedConflict` / `failed` / `blocked`** (vedi conteggi sotto), **mai** elenco PII in UI.
- **Vietata** la copy «tutto sincronizzato» / equivalente se il dominio prezzi ha **errori**, **skipped** o **blocked** non risolti.
- **Retry solo manuale**, avviato dall’utente (stesso pattern TASK-079); **nessun** retry automatico, **nessun** background worker.
- **Retry / secondo tentativo:** ripartire da **piano o preview ricalcolato** dopo un nuovo **Controlla cloud** o passo di preflight equivalente — **non** rieseguire ciecamente un piano **stale** trattenuto in memoria se lo snapshot locale/remoto è cambiato.
- **Invalidazione piano:** se tra **review** e **conferma** cambiano **sessione auth**, **account**, **owner**, o esiti **baseline** rilevanti (stessa filosofia TASK-079 pre-write), la futura execution deve **invalidare** il piano prezzi e richiedere **nuovo controllo** — non proseguire su piano obsoleto.
- Errori **aggregati** e **privacy-safe**: conteggi e categorie, **senza** elenchi di barcode / prezzi sensibili in UI Release.
- **Conteggi pianificati** per summary (mapping interno → copy user-friendly):
  - `applied` (applicati sul dispositivo)
  - `pushed` (inviati al servizio online)
  - `skippedDuplicate` (gia’ presenti)
  - `skippedConflict` (da controllare — **TASK-082** se policy globale)
  - `failed` (non riusciti)
  - `blocked` (bloccati da regole / precondizioni)
- **Dettagli sensibili** non persistiti in UI Release: niente storage di liste PII in `AppStorage` per questo scopo.

---

## Execution gates *(checklist pre-futura EXECUTION)*

Prima di autorizzare **EXECUTION** Codex (override utente), verificare:

- [ ] **Schema Supabase** `inventory_product_prices` **e** relazione con `inventory_products` **ricontrollato** (PK, FK, **UNIQUE**, assenza `updated_at`/`deleted_at` su prezzi, **Task 038** DELETE revocato).
- [ ] **Unique constraint** / **dedupe policy** allineata al codice (**D80-10**); nessun drift non documentato.
- [ ] **Mapping** prodotto locale / remoto (`Product.remoteID`, barcode fallback) **validato** su casi senza `remoteID`.
- [ ] **Dataset grande** stimato (ordine di grandezza righe prezzo) e **batch size** scelto documentato nel task.
- [ ] **Test fakeable** definiti (`ModelContext` in-memory / mock transport) per apply, push, preview — senza rete obbligatoria dove possibile.
- [ ] **UI copy** Release per sezione prezzi **approvato** (IT/EN/ES/zh-Hans) prima del merge.
- [ ] **Policy effectiveAt vs updated_at** (**D80-17…18**) e normalizzazione stringhe verificata in code review futura.
- [ ] **Mapping identità prodotto** (**D80-15…16**) coperto da test (barcode duplicato, remote mancante, orfano).
- [ ] **Nessuna dipendenza** da **TASK-081** (drain outbox) per completare il minimo **TASK-080**.
- [ ] **Nessuna dipendenza** da **policy conflitti TASK-082**, salvo **fail-closed** e messaggi espliciti documentati qui.

---

## 8. UX Release — visione prodotto *(macro, linguaggio naturale)*

- Dopo **Controlla cloud**, l’utente capisce se ci sono **novita’ sui prezzi** oltre al catalogo.
- Puo’ **applicare** sul dispositivo con conferma, e **inviare** le proprie registrazioni **a blocchi**, con **riepilogo onesto** se qualcosa e’ stato saltato.
- Situazioni **ambig** → messaggio chiaro; **policy fine** → **TASK-082**.

---

## 9. Strategia dati

| Tema | Indirizzo |
|------|-----------|
| **ProductPrice locale (SwiftData)** | Modello `ProductPrice` + relazione da `Product`; backfill storico da campi correnti tramite `PriceHistoryBackfillService` dove applicabile. |
| **ProductPrice remoto (Supabase)** | Tabella `inventory_product_prices`; righe indirizzate da `product_id` → `inventory_products.id`; RLS per `owner_user_id`. |
| **Mapping prodotto locale/remoto** | `Product.remoteID` (UUID) come pivot per join con `product_id` remoto; fallback/vincoli se prodotto senza `remoteID` gia’ gestiti nei servizi apply (unmapped). |
| **Timestamp / effectiveAt** | Remoto prezzi: **`effective_at`**, **`created_at`** (text). Catalogo: **`updated_at`** su `inventory_products` — vedi **§ EffectiveAt, created_at e updated_at**. Locale: `Date` in `ProductPrice`. |
| **updated_at / deleted_at** | **`inventory_product_prices`** in Task 016 **non** definisce questi campi; **`inventory_products`** ha `updated_at`/`deleted_at` (tombstone catalogo). Non applicare semantiche catalogo alle righe prezzo senza evidenza schema. |
| **Dedupe / idempotenza** | Unicita’ SQL `(owner_user_id, product_id, type, effective_at)`; push con UUID riga client; apply con skip se gia’ presente stesso valore per stessa chiave logica. |
| **Current vs previous price** | **Current:** campi `purchasePrice`/`retailPrice` su `Product` + ultima riga storica per tipo. **Previous:** derivabile da ordinamento `effectiveAt` / view tipo Android `ProductPriceSummary` (ultimo vs penultimo). |
| **Conflitti** | Gestione avanzata e merge → **TASK-082**; TASK-080 resta **fail-closed** ogniqualvolta i servizi esistenti rilevano `conflicts` / `priceConflict`. |

---

## 10. Esplicitamente fuori perimetro

| Voce | Task / motivo |
|------|----------------|
| Drain outbox Release / `record_sync_event` live su UI Release | **TASK-081** |
| Policy conflitti globale, LWW interattivo, merge guidato complesso | **TASK-082** |
| Smoke end-to-end controllato multi-dispositivo | **TASK-083** |
| Parità Android completa (repository, import/export, worker) | **TASK-084** |
| Hardening production, osservabilità, performance grandi dataset | **TASK-085** |
| Sync automatica: `Timer`, `BGTask`, Realtime, worker, polling | Roadmap esclusa |
| Modifiche SQL/migration/RPC/RLS su Supabase | Fuori da questo task iOS |
| Refactor ampi di `ExcelSessionViewModel` / `GeneratedView` | Non richiesti |

---

## 11. Test matrix *(pianificata — non eseguita in planning)*

| Area | Verifica suggerita |
|------|-------------------|
| **T80-01** | XCTest `SupabaseProductPriceApplyService` — plan/apply/skip/conflict/session mismatch |
| **T80-02** | XCTest `SupabaseProductPriceManualPushService` / dry-run — batch limit, stale snapshot, verification |
| **T80-03** | XCTest `SupabaseProductPricePreviewService` — paginazione, orphan, cancel |
| **T80-04** | XCTest `SupabasePullPreviewService` — integrazione righe prezzi + warning `priceHistoryIncomplete` |
| **T80-05** | XCTest `SupabaseManualSyncViewModel` — sezioni prezzi, stati post-azione (dopo wiring) |
| **T80-06** | `plutil` su stringhe nuove (solo se si aggiungono chiavi l10n in execution) |
| **T80-07** | Build Release + regressione suite manual sync esistente |
| **T80-08** | Grep anti-scope (vedi §12) |
| **T80-09** | ViewModel/summary: mapping conteggi `applied` / `pushed` / `skippedDuplicate` / `skippedConflict` / `failed` / `blocked` → copy **senza** PII |
| **T80-10** | Dataset **vuoto**: nessun prezzo remoto/locale candidato → summary „nessuna azione“ senza errori fasulli |
| **T80-11** | **Duplicato** logico: stessa chiave UNIQUE / stesso prezzo → `skippedDuplicate` |
| **T80-12** | **Product remoto mancante** / **orfano** → skipped/blocked, no insert locale |
| **T80-13** | **Product locale mancante** per `product_id` → blocked/skipped |
| **T80-14** | **Barcode duplicato** o assente dove serve fallback → `skippedConflict` / blocked |
| **T80-15** | Prezzo **uguale** gia’ presente → skip idempotente |
| **T80-16** | Prezzo **nuovo più recente** (effectiveAt) vs storico → applicazione coerente con policy current (**§ Current vs Previous**) |
| **T80-17** | Prezzo remoto **più vecchio** che **non** deve sovrascrivere current locale più recente → blocked o messaggio esplicito (no silent overwrite) |
| **T80-18** | Stesso **effectiveAt** canonico, **prezzo diverso** → conflitto / fail-closed → **TASK-082** se non fail-closed |
| **T80-19** | **Batch > limite** → blocco o split pianificato; summary onesto |
| **T80-20** | **Partial failure** rete/salvataggio: alcuni batch OK, altri failed |
| **T80-21** | **Retry manuale** dopo partial → nuovo piano, non stale |
| **T80-22** | **Piano stale** / sessione auth cambiata / baseline mismatch → rifiuto applicazione |
| **T80-23** | UI summary misto: successi + skipped + failed visibili come **conteggi**, no „tutto ok“ |

---

## 12. Grep anti-scope *(da eseguire in EXECUTION/REVIEW futuri)*

Comandi indicativi (adattare path):

```bash
rg -n "guidedManual|supportsGuidedManualSync\\s*=\\s*true" iOSMerchandiseControl --glob '*.swift'
rg -n "Timer\\.|BGTask|Realtime|backgroundTask|pollInterval" iOSMerchandiseControl --glob '*.swift'
rg -n "SyncEventOutboxDrainService|confirmDrain" iOSMerchandiseControl --glob '*.swift'  # deve restare fuori perimetro TASK-080 Release
```

Attesi: nessuna nuova sync automatica; **nessun drain** Release; **nessun** task **TASK-081** avviato dentro TASK-080.

---

## 13. Rischi

| ID | Rischio | Mitigazione *(planning)* |
|----|---------|--------------------------|
| R-01 | Accoppiamento **`priceHistoryIncomplete`** ↔ blocco apply catalogo UX | Separare policy in S80-b; comunicare chiaramente in sheet perche’ “Aggiorna dispositivo” e’ disabilitato. |
| R-02 | Volume righe prezzi > cap preview/apply → esperienza **partial** | Bounded batch + summary onesto + retry manuale; allineare messaggi TASK-074 pattern. |
| R-03 | **DELETE** revocato su tabella prezzi → rollback concettuale errato se il client assume rimozione fisica | Documentare append-only; usare dominio eventi per tombstone quando richiesto (**TASK-081/084**). |
| R-04 | Doppia fonte verità **prezzi su riga prodotto** vs **tabella storico** | S80-e; allineare dopo pull/push con regole esplicite (product-oriented). |
| R-05 | Drift executor se **Codex** estende scope a outbox drain | Review severa + grep §12 |
| R-06 | **N+1** o **RAM** su dataset grande se le mappe non sono costruite per batch | Obbligo mappe in-memory + paginazione (§ Raffinamento efficienza); S80-e |
| R-07 | **Mismatch schema** Supabase vs DTO iOS (drift migrazione) | **D80-13**, **D80-18**, execution gates; fail-closed |
| R-08 | **Prezzo orfano** senza product mapping valido | **D80-16**, classificazione skipped/blocked; test T80-12/T80-13 |
| R-09 | **effectiveAt** non normalizzato (stringhe equivalenti ma diverse) → falsi duplicati/conflitti | Normalizer unico; test T80-11/T80-18 |
| R-10 | **Current price** su `Product` **divergente** dallo storico dopo sync | **§ Current vs Previous**, S80-e; messaggio o allineamento documentato |
| R-11 | **UX troppo tecnica** (fuga di termini interni) | Copy-only review; grep no-jargon; **§ UX** |
| R-12 | **Conflitti reali** multi-device oltre fail-closed | **TASK-082**; non mascherare come successo |

---

## 14. Definition of Ready — planning

- [x] TASK-078/079 chiusi; audit TASK-076 consultato.
- [x] File TASK-080 creato con tutte le sezioni obbligatorie + raffinamento efficienza / idempotenza / UX / partial / execution gates.
- [x] Schema prezzi Supabase verificato da migrazione locale (non inventato).
- [x] ANDROID path: `ProductPrice` / `ProductPriceSummary` + nota estensione **S80-a** (InventoryCatalogRemoteRows, worker/repository).
- [ ] Checklist **Execution gates** (sezione dedicata) soddisfatta prima di promuovere **EXECUTION**.
- [ ] Review umana del planning TASK-080 accettata prima di promuovere **EXECUTION**.

---

## 15. Definition of Done — planning *(NON task completo)*

- [x] Handoff verso **planning review** compilato.
- [x] **NON READY FOR EXECUTION** fino a override utente esplicito e aggiornamento fase nel file task / MASTER-PLAN.
- [x] **TASK-080 NON DONE** (nessuna chiusura DONE in questa fase).

---

## Acceptance criteria — futura EXECUTION *(misurabili; non verificati in questo planning)*

Per considerare l’implementazione **TASK-080** conforme al planning (verifica in fase **REVIEW** post-execution), devono esistere evidenze (test e/o review codice) che:

1. **Nessun** accesso persistence **per singola riga prezzo** in loop driver del sync (anti-**N+1**): caricamenti/mappe **batch** o fetch paginati controllati.
2. **Mapping prodotto** locale/remoto costruito e validato **prima** del piano applicativo/push prezzi (ordine § Product identity + § Raffinamento).
3. **Batch size** bounded e **documentato** nel task/handoff execution (valore scelto + motivazione vs default **100** push attuale se diverso).
4. **Dedupe** applicato **prima** di ogni **write** SwiftData significativa e **prima** dell’invio remoto (allineato a **D80-10**).
5. Il **summary** (o modello ad esso sottostante) espone con categorie equivalenti: **applied**, **pushed**, **skippedDuplicate**, **skippedConflict**, **failed**, **blocked** — tradotte in copy **senza** PII.
6. **Nessun** messaggio Release che equivalga a **«tutto sincronizzato» / „completato al 100%“** se `failed` + `blocked` + `skippedConflict` (per prezzi) **> 0** o se il summary dichiara **partial** per il dominio prezzi.
7. **Retry** solo su azione **manuale** utente; **zero** retry automatico/timer/background.
8. Il **minimo** TASK-080 **non richiede** **TASK-081** (drain) né **TASK-082** (merge interattivo) per essere **completo** salvo i casi esplicitamente fail-closed.
9. Conflitti o policy **avanzate** oltre fail-closed restano **TASK-082** con messaggio chiaro all’utente.

---

## Hardening finale planning — UX, performance e piano volatile

Questo raffinamento completa il planning TASK-080 senza autorizzare execution. L’obiettivo è rendere la futura implementazione più sicura, più efficiente e più coerente con la UX Release già costruita in TASK-077, TASK-078 e TASK-079.

### H80-01 — ProductPrice dentro la sheet Rivedi

ProductPrice non deve introdurre un percorso utente separato. La futura sezione **Prezzi da aggiornare** deve stare dentro la sheet **Rivedi**, come sezione compatta o collassabile.

Ordine UX consigliato nella review:

1. **Catalogo**: modifiche prodotto, fornitore e categoria.
2. **Prezzi da aggiornare**: prezzo precedente, nuovo prezzo, direzione del cambio e stato.
3. **Attenzione**: duplicati, conflitti, righe bloccate o non applicabili.
4. **Riepilogo finale**: conteggi semplici e prossima azione.

Regole UX:

- usare SwiftUI nativo, card/sezioni compatte e stile coerente con `OptionsView`;
- usare SF Symbols e colori semantici, non icone o colori tecnici/aggressivi;
- mantenere una sola CTA primaria visibile alla volta;
- quando modifiche remote e locali coesistono, mantenere l’ordine già scelto: prima **Aggiorna questo dispositivo**, poi **Invia modifiche al cloud**;
- non mostrare gergo tecnico nella UI Release: `ProductPrice`, RPC, outbox, `sync_events`, baseline, payload, idempotenza.

### H80-02 — Dataset grande e performance UI

Per dataset grandi, la futura UI non deve renderizzare tutte le righe prezzo nella sheet. La review deve mostrare:

- conteggi aggregati;
- preview limitata e leggibile;
- stato per gruppi: nuovi prezzi, già presenti, saltati, bloccati, falliti;
- nessuna lista completa se rende la sheet lenta o difficile da usare.

La lista completa dei dettagli può restare fuori dalla UI Release o essere demandata a export/log diagnostico in task successivi.

### H80-03 — Piano volatile e invalidazione

Il piano ProductPrice futuro deve essere volatile. Se tra review e conferma cambia uno dei seguenti elementi, la futura execution deve invalidare il piano e chiedere un nuovo **Controlla cloud**:

- sessione auth / `ownerUserID`;
- baseline locale o remota;
- mapping `Product` locale ↔ remoto;
- nuovi pending locali rilevanti;
- dataset prezzi remoto aggiornato dopo la preparazione del piano;
- dedupe ambiguo o identità prezzo non verificabile.

Il retry manuale deve rigenerare il piano, non riusare un piano vecchio.

### H80-04 — Acceptance criteria aggiuntiva

- Nessuna query per singolo ProductPrice in loop.
- Mapping prodotti locale/remoto costruito prima del piano prezzi.
- Batch size bounded e documentata nella futura execution.
- Dedupe prima di ogni write locale/remoto.
- Summary futuro con conteggi `applied`, `pushed`, `skippedDuplicate`, `skippedConflict`, `failed`, `blocked`.
- Nessun messaggio UI “tutto sincronizzato” se esistono errori, skipped, blocked o piano invalidato.
- Retry solo manuale e user-initiated.
- Nessuna dipendenza da TASK-081.
- Conflitti avanzati rimandati a TASK-082.

### H80-05 — Gate aggiuntivi prima di EXECUTION

Prima di promuovere TASK-080 a EXECUTION, verificare:

- policy `effectiveAt` / `updated_at` scritta con i nomi reali dello schema Supabase locale;
- unique constraint o dedupe policy reale di Supabase;
- mapping product locale/remoto con remote id preferito e barcode solo come fallback validato;
- comportamento per barcode mancante, duplicato o product remoto assente;
- piano volatile invalidabile tra review e conferma;
- limiti UI per dataset grande: conteggi aggregati + preview limitata;
- test fakeable per pull/apply locale e push remoto senza Supabase live;
- ogni write futuro dietro conferma utente esplicita, mai dietro semplice apertura della sheet.

**Stato dopo questo hardening:** TASK-080 resta **ACTIVE / PLANNING**, **NON READY FOR EXECUTION**, **NON DONE**.

---

## Handoff

- **READY FOR PLANNING REVIEW:** **sì** — inclusi raffinamento **2026-05-08**, review planning e **hardening H80**.
- **NON READY FOR EXECUTION:** **sì** — nessuna modifica Swift autorizzata; nessun **Codex / Executor** finche’ l’utente non promuove la fase e la checklist **Execution gates** non e’ soddisfatta.
- **Prossima fase prevista:** PLANNING REVIEW → (se approvato) **EXECUTION** futura su micro-slice **S80-a…**
- **Prossimo agente:** Claude / Reviewer *(poi Codex / Executor su override)*.
- **TASK-080 NON DONE.**

---

## Review (Claude) — planning *(iterazione 2026-05-08)*

**Rifinitura documentale** (non review post-execution): integrati elenco coerenza MASTER-PLAN, **Acceptance criteria futura**, **Product identity**, **Timestamp policy** (effectiveAt vs updated_at catalogo), UX/sheet/recovery/stale plan, estensione test matrix **T80-10…T80-23**, rischi **R-07…R-12**, decisioni **D80-15…D80-18**, **hardening H80-01…H80-05**. Stato task invariato: **ACTIVE / PLANNING**, **NON READY FOR EXECUTION**, **NON DONE**.

## Execution (Codex) — 2026-05-08 16:33 -0400

### Override operativo

L'utente ha autorizzato esplicitamente l'EXECUTION completa di TASK-080 mentre il file era ancora in **ACTIVE / PLANNING**. Impatto sul workflow: Codex ha proceduto nel perimetro TASK-080, senza aprire TASK-081…TASK-085, e riporta ora il task a **REVIEW** per controllo Claude. TASK-080 resta **NON DONE**.

### Obiettivo compreso

Implementare ProductPrice nel flusso Release esistente **Controlla cloud → Rivedi → Conferma**, senza percorso separato, includendo:

- pull/preview e apply locale prezzi dopo conferma;
- push locale prezzi verso Supabase dopo preflight/dry-run e conferma;
- dedupe/idempotenza coerenti con unique reale `owner_user_id + product_id + type + effective_at`;
- summary con `applied`, `pushed`, `skippedDuplicate`, `skippedConflict`, `failed`, `blocked`;
- UX sezione **Prezzi da aggiornare** nella sheet **Rivedi**;
- test fakeable senza Supabase live.

### File controllati

- Planning/tracking: `docs/MASTER-PLAN.md`, `docs/TASKS/TASK-080-supabase-productprice-sync-ios.md`, `docs/TASKS/TASK-078-supabase-mutative-sync-pull-apply-ios.md`, `docs/TASKS/TASK-079-supabase-guided-catalog-push-ios.md`.
- iOS: `Models.swift`, `SupabaseInventoryDTOs.swift`, `SupabasePullPreviewService.swift`, `SupabasePullApplyService.swift`, `SupabaseProductPriceApplyService.swift`, `SupabaseProductPricePreviewService.swift`, `SupabaseProductPricePushDryRunService.swift`, `SupabaseProductPriceManualPushService.swift`, `SupabaseManualSyncViewModel.swift`, `SupabaseManualSyncReleaseFactory.swift`, `SupabaseManualSyncCoordinator.swift`, `OptionsView.swift`, baseline reader/writer.
- Test: suite ProductPrice apply/preview/push dry-run/manual push, `SupabaseManualSyncViewModelTests`, `SupabaseManualSyncReleaseUITests`.
- Supabase schema locale solo lettura: `/Users/minxiang/Desktop/MerchandiseControlSupabase` (`inventory_products`, `inventory_product_prices`, `sync_events`).
- Android solo lettura: `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView` (`ProductPrice`, `ProductPriceSummary`, `InventoryCatalogRemoteRows`, riferimenti repository/import/backfill).

### Piano minimo

1. Cablaggio ProductPrice nel ViewModel Release con piani volatili apply/push e summary aggregato.
2. Adapter Release nella factory usando i servizi ProductPrice esistenti.
3. Sezione UX **Prezzi da aggiornare** nella sheet **Rivedi** e localizzazioni.
4. Test fakeable su ViewModel/UI e regressione suite ProductPrice esistente.
5. Build/check e aggiornamento tracking.

### Modifiche fatte

- Aggiunto supporto ProductPrice al `SupabaseManualSyncViewModel` con provider dedicato, staging volatile apply/push, fingerprint anti-stale, invalidazione su sessione/piano cambiato, e summary `SupabaseManualSyncProductPriceSummary`.
- Integrato apply prezzi nel percorso **Aggiorna questo dispositivo** dopo conferma utente, con re-preflight immediato e conservazione del summary post-apply.
- Integrato push prezzi nel percorso **Invia modifiche al cloud**, anche price-only, con dry-run read-only, dedupe remoto, batch limit esistente `ProductPriceManualPushOptions.defaultBatchLimit` (=100), verifica via servizio esistente, e blocco su piano stale.
- Collegata `SupabaseManualSyncReleaseFactory` a `SupabaseProductPriceApplyService`, `SupabaseProductPricePushDryRunService` e `SupabaseProductPriceManualPushService` tramite adapter fakeable; `OptionsView` passa `SupabaseInventoryService` alla factory Release.
- Aggiunta sezione **Prezzi da aggiornare** nella review/summary Release con copy user-facing e conteggi: nuovi/applicati/pronti da inviare/inviati/gia' presenti/da verificare/non aggiornati.
- Aggiornate localizzazioni IT/EN/ES/zh-Hans.
- Aggiornati test ViewModel/UI per ProductPrice Release apply/push/stale e chiavi l10n; aggiornato test anti-scope legacy TASK-069 per il nuovo servizio ProductPrice previsto da TASK-080.

### Check eseguiti

- ✅ ESEGUITO — Build compila: `xcodebuild build -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'` → **BUILD SUCCEEDED**.
- ✅ ESEGUITO — XCTest mirati fakeable: `xcodebuild test ... -only-testing:iOSMerchandiseControlTests/SupabaseManualSyncViewModelTests -only-testing:iOSMerchandiseControlTests/SupabaseManualSyncReleaseUITests -only-testing:iOSMerchandiseControlTests/SupabaseProductPriceApplyServiceTests -only-testing:iOSMerchandiseControlTests/SupabaseProductPricePushDryRunServiceTests -only-testing:iOSMerchandiseControlTests/SupabaseProductPriceManualPushServiceTests` → **TEST SUCCEEDED**.
- ✅ ESEGUITO — Localizable: `plutil -lint` su IT/EN/ES/zh-Hans → **OK**.
- ✅ ESEGUITO — `git diff --check` → **PASS**.
- ✅ ESEGUITO — Modifiche coerenti con planning: ProductPrice resta dentro Release review/confirm, nessun percorso separato, no drain, no background sync.
- ✅ ESEGUITO — Criteri di accettazione verificati staticamente/test: pull/apply e push Release cablati, dedupe usa servizi esistenti allineati al vincolo Supabase, piani volatili e summary presenti, test fakeable senza Supabase live.
- ⚠️ NON ESEGUIBILE — Nessun warning nuovo introdotto in senso assoluto: `xcodebuild` emette warning già noti/fuori perimetro (AppIntents metadata; in test precedenti anche warning outbox preesistenti). Nessun warning osservato nei file modificati TASK-080.
- ⚠️ NON ESEGUIBILE — Simulator/manual UI: non richiesto esplicitamente dal task oltre a build/test; verificata via ViewModel/UI XCTest e sorgente SwiftUI.

### Rischi rimasti

- **TASK-080 NON DONE** fino a review/chiusura: Codex non marca DONE.
- I conflitti multi-device avanzati restano fail-closed / da rimandare a **TASK-082**.
- Il batch push Release conserva il limite esistente del servizio prezzi (**100**) invece del target planning 300–500; scelta conservativa per evitare cambio API/limiti non richiesto.
- Nessuno smoke Supabase live eseguito; coerente con divieto di live write nei test.
- `sync_events` / outbox drain resta fuori perimetro (**TASK-081**).

### Aggiornamenti file di tracking

- `docs/TASKS/TASK-080-supabase-productprice-sync-ios.md`: fase aggiornata a **REVIEW**, execution summary e handoff compilati.
- `docs/MASTER-PLAN.md`: voce giornale execution aggiunta; task attivo aggiornato a **TASK-080 ACTIVE / REVIEW**; ultimo completato resta **TASK-079 DONE / Chiusura**; TASK-081…TASK-085 restano TODO / Planning.

## Handoff post-execution (Codex → Claude)

- **Stato finale execution:** completata.
- **Fase proposta:** **REVIEW**.
- **Responsabile attuale:** Claude / Reviewer.
- **TASK-080:** **NON DONE**.
- **Punti da verificare in review:** cablaggio ProductPrice nel Release flow, copy UX no-jargon, policy stale/sessione, conservazione summary post-apply/push, coerenza anti-scope.
- **Anti-scope confermato:** nessun Android modificato; nessun SQL/backend; nessun Supabase live write; nessun outbox drain; nessuna sync automatica/background; TASK-081 non aperto.

## Review / Fix / Chiusura (Claude) — 2026-05-08 17:24 -0400

Esito review: **FIXED / DONE**.

### Cosa verificato

- Flusso Release **Controlla cloud → Rivedi → Conferma**: ProductPrice resta nella sheet **Rivedi**, senza percorso utente separato.
- Pull/apply prezzi: piano volatile, apply solo dopo conferma, recheck anti-stale prima della write SwiftData, nessuna write all'apertura della sheet.
- Push prezzi: dry-run/preflight read-only, write solo dopo conferma, supporto price-only, limite batch conservativo del servizio (**100**), dedupe remoto tramite servizi esistenti.
- Dedupe/idempotenza: servizi verticali rispettano chiave reale Supabase `owner_user_id + product_id + type + effective_at`; stesso effectiveAt/prezzo uguale viene skipped; prezzo diverso viene conflitto/blocco.
- Performance: nessuna query prodotto-per-prezzo introdotta nel wiring TASK-080; push dry-run usa snapshot/mappe e fetch remoto per batch prodotto; UI mostra solo conteggi compatti.
- UX/copy: sezione **Prezzi da aggiornare** presente, compatta, con SF Symbol e colori semantici; copy Release senza ProductPrice/RPC/outbox/sync_events/baseline/payload/UUID.
- Anti-scope: `confirmDrain`, `SyncEventOutboxDrainService`, `.rpc` e `record_sync_event` trovati solo in codice DEBUG/outbox preesistente fuori dal flusso Release TASK-080; nessun TASK-081 aperto.

### Fix applicati in review

- `SupabaseManualSyncViewModel.swift`: corretto conteggio `blocked` del summary push ProductPrice, evitando doppio conteggio di `blockedNoRemoteID`.
- `SupabaseManualSyncViewModel.swift`: reso il merge dei conteggi ProductPrice additivo per skip/conflitti/blocchi tra apply e push, con reset del piano a ogni preparazione review per evitare accumuli stale.
- `SupabaseManualSyncViewModel.swift`: su apply ProductPrice stale, il piano viene invalidato e non viene eseguita alcuna write; il summary resta onesto con `blocked`.
- `SupabaseManualSyncViewModel.swift`: semplificata la generazione della riga **Nuovi prezzi trovati**.
- `SupabaseManualSyncViewModelTests.swift`: aggiunti test per stale apply senza write e conteggi mixed success/skipped/blocked non duplicati.

### Check finali

- ✅ ESEGUITO — Build compila: `xcodebuild build -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'` → **BUILD SUCCEEDED**.
- ✅ ESEGUITO — XCTest mirati: `SupabaseManualSyncViewModelTests`, `SupabaseManualSyncReleaseUITests`, `SupabaseProductPriceApplyServiceTests`, `SupabaseProductPricePushDryRunServiceTests`, `SupabaseProductPriceManualPushServiceTests` → **TEST SUCCEEDED**.
- ✅ ESEGUITO — Localizable: `plutil -lint` su IT/EN/ES/zh-Hans → **OK**.
- ✅ ESEGUITO — `git diff --check` → **PASS**.
- ✅ ESEGUITO — Anti-scope grep richiesto su `iOSMerchandiseControl/**/*.swift`: solo match preesistenti in outbox DEBUG/RPC (`SyncEventOutboxDrainDebugViewModel`, `SyncEventOutboxDrainService`, `SupabaseSyncEventRPCTransport`, `OptionsView` DEBUG `confirmDrain`), non nel flusso Release TASK-080.
- ✅ ESEGUITO — Anti-jargon Release: nuove chiavi `options.supabase.manualSync.review.prices.*` senza termini vietati; match tecnici residui sono in sezioni DEBUG/legacy non introdotte da TASK-080.
- ⚠️ NON ESEGUIBILE — Test manuale Simulator della sheet: non richiesto come gate esplicito; copertura fornita da build + XCTest ViewModel/UI + static checks.
- ⚠️ NON ESEGUIBILE — “Nessun warning nuovo” in senso assoluto: build/test mostrano warning AppIntents metadata già noto; nessun warning osservato nei file TASK-080 modificati.

### Anti-scope finale

- Nessun Android modificato.
- Nessun SQL/backend/Supabase migration modificato.
- Nessun Supabase live write eseguito nei test.
- Nessun outbox drain implementato.
- Nessuna sync automatica/background, nessun Timer, BGTask, Realtime o polling introdotto.
- TASK-081 resta **TODO / Planning**.
- Conflitti avanzati multi-device restano fuori perimetro e rimandati a **TASK-082**.

### Rischi residui

- Smoke live end-to-end resta fuori da TASK-080 e naturale candidato per **TASK-083**.
- Policy conflitti multi-device resta volutamente fail-closed / da formalizzare in **TASK-082**.
- Il limite push ProductPrice resta **100** per batch perché è il limite sicuro del servizio esistente.

### Chiusura

Tutti i criteri TASK-080 verificabili in questo perimetro risultano soddisfatti dopo review/fix/test. **TASK-080 chiuso DONE / Chiusura**.
