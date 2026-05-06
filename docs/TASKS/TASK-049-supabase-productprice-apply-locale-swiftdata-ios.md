# TASK-049: Supabase ProductPrice pull → apply locale controllato SwiftData iOS — **no push remoto**

## Informazioni generali
- **Task ID**: TASK-049
- **Titolo**: Supabase ProductPrice pull → apply locale controllato SwiftData iOS, **nessun push remoto**
- **File task**: `docs/TASKS/TASK-049-supabase-productprice-apply-locale-swiftdata-ios.md`
- **Stato**: DONE
- **Fase attuale**: —
- **Responsabile attuale**: —
- **Data creazione**: 2026-05-06
- **Ultimo aggiornamento**: 2026-05-06 *(REVIEW APPROVED su override utente: fix mirati applicati su chiave logica ProductPrice via `Product.remoteID`, copertura test rafforzata, build/test/plutil/audit zero-write verdi; TASK-049 chiuso DONE.)*
- **Ultimo agente che ha operato**: Claude / Reviewer

## Dipendenze
- **Dipende da**:
  - **TASK-048** — **DONE** — fondazione read-only: gate DDL `inventory_product_prices`, `SupabaseProductPricePreviewService` (o equivalente), fetch paginato deterministico, UI DEBUG `OptionsView`, localizzazioni IT/EN/ES/ZH-Hans, XCTest; **nessuna** persistenza preview, **nessun** push/apply ProductPrice.
  - **TASK-040** — **DONE** — `Product.remoteID` per join logico `product_id` remoto → prodotto SwiftData.
  - **TASK-038** — **DONE** — client/sessione Supabase esistente (**nessuna** auth nuova richiesta da TASK-049).
  - **TASK-033** / audit schema — **DONE** — semantica `inventory_product_prices` (tipo `PURCHASE`/`RETAIL`, timestamp testuali, unique owner/product/type/effective_at).
  - Catena **TASK-039/043/044/045/046/047** — **DONE** — contesto pull/apply catalogo e baseline; TASK-049 **non** ridefinisce baseline salvo handoff esplicito futuro.
- **Sblocca** *(non attivare senza review/user override)*:
  - Eventuale **ProductPrice push** remoto (task dedicato, fuori da TASK-049).
  - `record_sync_event` / `sync_events` / outbox / sync incrementale (es. parity Android avanzata) — **espostamente fuori scope**.

### Confine TASK-049 vs TASK-048 *(obbligatorio)*
- **TASK-048** = preview **campione** read-only con cap rigidi (`truncated` possibile) — **non** contratto per apply completo.
- **TASK-049** = **pull controllato** verso un piano **`prepareApplyPlan` / `apply` locale** SwiftData, con **dry-run** in UI DEBUG e **apply solo dopo conferma esplicita**, sotto la **Policy fail-closed definitiva** *(nessun apply se una sola condizione fallisce; CTA disabilitata + motivo visibile)*.

---

## 1. Obiettivo

Implementare uno **slice minimo e sicuro** che:
1. Legge da Supabase la tabella **`inventory_product_prices`** (read-only, sessione esistente).
2. Collega ogni riga remota al **prodotto locale** tramite **`Product.remoteID`** (UUID `product_id` remoto) — **nessuna inferenza barcode** solo dalla riga prezzo.
3. Costruisce un **piano applicabile** puro e testabile (`Sendable`/value types dove coerente col progetto).
4. Mostra in **UI DEBUG** (`OptionsView`, sezione esistente) una **preview / dry-run** con summary e campioni (chiaro che il dry-run riflette il **dataset effettivamente letto** per l’operazione di apply).
5. Applica **solo in SwiftData** dopo **conferma esplicita** dell’utente.
6. Aggiorna lo **storico prezzi locale** in modo **idempotente** (nessun duplicato logico; dedupe documentato).
7. **Non scrive nulla su Supabase** (zero POST/PATCH/UPSERT/delete su `inventory_product_prices` e ogni altra tabella).

---

## 2. Stato attuale iOS *(rilevato / ereditato da TASK-048 e repo — da ri-verificare in EXECUTION sul codice reale)*

Fonte primaria per l’execution: **repository iOS** (clone allineato a GitHub); **non** copiare Kotlin Android.

Elementi attesi *(TASK-048)*:
- **`ProductPrice`** SwiftData: `PriceType`, `effectiveAt`/`createdAt` `Date`, relazione `product`; **`remoteID` sulla riga storico** — **se assente**, TASK-049 usa **dedupe logico** senza migration (*D49-08*); **se presente**, riusarlo.
- **`RemoteInventoryProductPriceRow`**: `type` `String`, timestamp `String`, `productID: UUID`, `price: Double`, PK remota `id` UUID.
- **`SupabaseProductPricePreviewService`** (nome esatto da confermare): wrapper read-only con cap TASK-048; TASK-049 deve definire se **estendere** lo stesso servizio, introdurre un **fetch “full controlled”** separato per apply, o composizione esplicita — **senza rompere** il comportamento read-only TASK-048 (card preview campione può restare indipendente).
- **`SupabasePullPreviewService` / `SupabasePullApplyService`**: logica storico e guard **`priceHistoryIncomplete`** sul catalogo; TASK-049 deve **coordina** o **isolare** apply prezzi per **non** violare invarianti esistenti né creare doppi apply.

**Nota PLANNING**: prima di EXECUTION, **leggere i file Swift effettivi** nel branch/repo aggiornato (obbligo utente); il presente paragrafo **non** sostituisce quella lettura.

---

## 3. Riferimento Android usato *(funzionale, non copia codice)*

- Ruolo: confermare **semantica** storico prezzi cloud (campi, ordinamenti UX, dedupe concettuale), orchestrazione già presente su Android con `inventory_product_prices`.
- Vincolo: **nessun** file Kotlin modificato; **nessuna** dipendenza di build; usare solo come confronto comportamentale.
- Avvertenza: **TASK-068 Android PARTIAL** e parity bulk **non** sono contratto iOS.

Fonti documentali nel workspace iOS (se presenti): `docs/SUPABASE/TASK-033-schema-audit.md`, task Android citati negli audit. **MASTER-PLAN Android** allegato dall’utente: riferimento di stato **solo se fornito** nel workspace; se assente, non bloccare TASK-049 ma registrare il divario in review.

---

## 4. Riferimento Supabase usato

- Tabella **`inventory_product_prices`**: PK `id`, `product_id` → `inventory_products`, `type` CHECK, `price` `float8`, `effective_at`/`created_at` **text** canonico, unique `(owner_user_id, product_id, type, effective_at)`, RLS owner-scoped, modello **append-only** lato client (delete policy tipicamente revocata) — come da **TASK-033** e migrazioni reali.
- **DDL**: in EXECUTION, **rileggere** il file migration effettivo nel repo Supabase (come gate TASK-048) prima di codificare; TASK-049 **non** aggiunge SQL/RLS/RPC.

**MASTER_PLAN Supabase** allegato: stato feature completate; TASK-049 **non** modifica Supabase.

---

## 5. Gap rispetto ad Android / Supabase

| Area | Android / Supabase | iOS post TASK-048 | Gap TASK-049 |
|------|--------------------|-------------------|--------------|
| Storico prezzi cloud | lettura + sync storico (per task Android completati) | solo **preview campione** read-only | **pull completo controllato** + **apply locale** con conferma |
| Join prodotto | `product_id` | `Product.remoteID` | unicità locale `remoteID` (*D49-11*); apply solo mapping non ambiguo |
| Idempotenza remota | vincolo unique lato DB | storico SwiftData locale | dedupe **logico** *(D49-08)* o `ProductPrice.remoteID` **se già nel modello** |
| Sync metadata | `sync_events` / outbox (Android avanti) | assente | **fuori scope** TASK-049 |

---

## 6. Scope preciso TASK-049

- Nuovo (o esteso) flusso: **`fetch ProductPrice remoto controllato`** → **`prepareApplyPlan`** (puro) → **UI DEBUG dry-run** → **`apply` SwiftData** su conferma.
- Inserimento **idempotente** e **insert-only** (**D49-12**): solo nuovi `ProductPrice` mancanti; nessun update/delete su righe esistenti.
- Estensione UI DEBUG in **`OptionsView`**: **due sezioni** distinte (TASK-048 vs TASK-049), summary, policy fail-closed, stati VM (*idle…failed*), **CTA** conformi alla *Policy fail-closed definitiva* — vedi §9.9 *(strumento DEBUG/developer, non feature consumer)*.
- **XCTest puri** per piano/dedupe/guardrail/stati VM/cancellation/post-save *(pattern esistente progetto)*.
- **Localizzazioni** nuove stringhe UI: **IT / EN / ES / ZH-Hans** (pianificate in EXECUTION).
- Verifica **zero write Supabase** (dettaglio §11): ammesse **solo** chiamate **read-only** sul client; `.select` / `.from` **solo** per **`inventory_product_prices`** e per eventuali **lookup strettamente necessari** già presenti nel client esistente *(nessun nuovo perimetro remoto senza planning)*. Review **grep/static** sui file toccati per **API scrittura/indiretta**: `.insert`, `.upsert`, `.update`, `.delete`, `.rpc`, `.functions`, `.storage`, e stringhe/verb **`POST`**, **`PATCH`**, **`DELETE`** ove applicabile al client; **ogni falso positivo** va **documentato in review**.

---

## 7. Fuori scope esplicito

- **Push** `ProductPrice` remoto; **qualsiasi write** su `inventory_product_prices`.
- **`record_sync_event`**, **`sync_events`**, outbox, watermark incrementale.
- **Realtime**, **background sync**, polling automatico.
- **Tombstone outbound**, delete remoto, cleanup cloud.
- **Migration Supabase / SQL / RLS / RPC**; modifiche **Android**.
- **Nuova auth** (OAuth, JWT manuale, ecc.) — usare sessione **esistente**.
- **Nuova migration SwiftData** per introdurre `ProductPrice.remoteID` (o altro schema) **vietata** in TASK-049 salvo che il campo **esista già** nel modello alla lettura del codice o **override utente** esplicito in *Decisioni* (*D49-08*).
- **Update, delete o «correzione»** di righe **`ProductPrice`** già persistite per risolvere conflitti — **vietati**; solo **insert** / `skippedExisting` / `conflict` (**D49-12**).
- Parità con **outbox/sync_events** Android in questo task.

---

## Policy fail-closed definitiva *(gating Apply)*

L’**apply locale** di righe `ProductPrice` da cloud è **consentito** solo se **tutte** le condizioni seguenti sono vere **nel piano / nel summary del dry-run immediatamente precedente** all’azione utente:

| # | Condizione | Se falsa |
|---|------------|----------|
| P1 | **Fetch completo**: tutte le pagine lette fino a **fine dataset naturale** (ultima pagina vuota / criterio documentato in EXECUTION), **senza** errore che renda il risultato parziale | Apply **vietato** |
| P2 | **`partial == false`** | Apply **vietato** |
| P3 | **`truncated == false`** *(incluso hit di safety cap memoria/tempo — vedi §9.10)* | Apply **vietato** |
| P4 | **`sourceError == nil`** | Apply **vietato** |
| P5 | **`unmappedProductCount == 0`** *(nessun `product_id` remoto senza `Product.remoteID` locale)* | Apply **vietato** |
| P6 | **`invalidRowCount == 0`** *(tipo/**prezzo**/`effectiveAt`/prodotto non validabili; **D49-10**: vietato `Double == Double`; NaN, ±inf, negativo o non canonizzabile → invalid)* | Apply **vietato** |
| P7 | **`conflictCount == 0`** *(incluso: stessa chiave **prodotto + tipo + `effectiveAt` canonico** ma **prezzo canonico diverso** — **D49-10**; **D49-11**: più `Product` con stesso `remoteID` → mapping ambiguo; nessun merge silenzioso — **D49-08**)* | Apply **vietato** |
| P8 | **Sessione/utente Supabase invariata** tra il dry-run su cui si basa la UI e il momento dell’`apply` *(stesso snapshot logico: user id / session token o equivalente rilevabile dal client — dettaglio tecnico in EXECUTION)* | Apply **vietato**; piano **invalidato** |
| P9 | **Nessuna riga** nel piano richiede **merge silenzioso ambiguo** | Apply **vietato** |

**Regola UX**: se **anche una sola** condizione fallisce → **CTA «Applica…» disabilitata** e la UI deve mostrare **il motivo** (stato `applyBlocked(reason)` o lista motivi / summary leggibile, non solo disabilitazione muta).

**Nota**: «fetch completo» + `truncated == false` sono correlati: un safety cap raggiunto prima della fine naturale implica **`truncated = true`** e quindi **P1/P3** falliscono.

---

## 8. Modelli / servizi iOS da leggere prima dell’EXECUTION *(lista di lavoro)*

Ordine consigliato (percorsi da confermare sul filesystem reale):
- `Models.swift` — `Product`, `ProductPrice`, `PriceType`, relazioni cascade.
- `SupabaseInventoryDTOs.swift` — `RemoteInventoryProductPriceRow`.
- `SupabaseInventoryService.swift` — fetch/page/range client.
- `SupabaseProductPricePreviewService.swift` *(o nome effettivo post TASK-048)* — riuso vs nuovo servizio «full pull apply».
- `SupabasePullPreviewService.swift`, `SupabasePullPreviewModels.swift` — normalizer tipo/data, chiavi logical; eventuale **normalizzazione prezzo** esistente *(priorità per **D49-10**)*.
- `SwiftDataInventorySnapshotService.swift` — snapshot storico per confronti.
- `SupabasePullApplyService.swift` — interazione con guard `priceHistoryIncomplete` / apply catalogo.
- `OptionsView.swift` — sezione DEBUG Supabase / ProductPrice.
- Test esistenti: `SupabasePullPreviewDiffEngineTests`, `SupabasePullApplyServiceTests`, test TASK-048 ProductPrice preview.

**Obbligo**: allineare il planning tattico ai file **reali** letti dal clone GitHub aggiornato prima di scrivere codice.

---

## 9. Strategia tecnica proposta

### 9.1 ProductPrice remote DTO
- **Riutilizzare** `RemoteInventoryProductPriceRow` dove possibile; estendere **solo** se il gate DDL o il client richiedono campi aggiuntivi **già presenti** in migration (es. `source`/`note`) e solo se servono a dedupe/idempotenza — **senza** ampliare perimetro a push.

### 9.2 Fetch completo controllato *(ordine stabile, coerenza pagine)*

- **Non** riusare i cap «campione» TASK-048 come base per apply **senza** adeguamento: per TASK-049 definire un **fetch dedicato** con paginazione **deterministica**.
- **Ordinamento remoto obbligatorio**: **totale** e **stabile**, includendo **`id` PK come tie-breaker finale** (es. `product_id`, `type`, `effective_at`, **`id`** asc). Se il client/API **non** consente un ordine totalmente deterministico documentato → **TASK-049 non può apply** in quella configurazione; in planning/review segnalare **blocco** (*T49-37*).
- **Anomalie di lettura**: ripetizione inattesa dello stesso **`id` remoto** tra pagine (overlap), **gap** evidente tra finestre consecutive, o altre incoerenze di paginazione → classificare come **`partial`** o **`sourceError`** → Apply **vietato** (*P2/P4*; *T49-36*).
- Il piano deve tracciare **ID remoti unici** (o chiavi logiche uniche) in modo **efficiente** in RAM — senza conservare payload raw enormi; se il controllo supera budget memoria → **safety cap** → **`truncated = true`** → Apply bloccato.
- **Safety**: se si introduce un **tetto assoluto** (memoria / tempo) e si raggiunge prima della fine naturale, il run deve risultare **`truncated` = true** → **apply vietato**.
- Gestire **`partial`** / **`sourceError`** (rete/parsing/paginazione): **nessun apply**.

### 9.3 Mapping `product_id` remoto → prodotto locale
- Lookup **`Product.remoteID == remote.productID`** (UUID).
- **D49-11**: se **più di un** `Product` locale condivide lo **stesso** `remoteID` → mapping **ambiguo** — contare come **`mappingConflict`** (assorbito in `conflictCount` o contatore dedicato che blocca Apply) → **nessun** «primo match vince»; Apply **vietato** finché `conflictCount > 0`.
- Se **nessun** prodotto locale per il `product_id` remoto: incrementare **unmapped**; con **D49-05** → Apply **vietato** finché `unmappedProductCount > 0`.

### 9.4 Normalizzazione `effectiveAt` *(unica fonte di verità)*

- In **EXECUTION** usare **un solo** normalizzatore/canonicalizer per `effective_at` remoto (text) → confronto con locale / chiave logica: **stesso codice** per dry-run e apply *(niente due parser divergenti)*.
- **Vietato** il confronto su **stringa raw** non normalizzata per decidere uguaglianza di data efficace.
- Test (XCTest) con timezone/formati **già previsti dal progetto** / fixture allineate a TASK-033 e al client esistente.
- Se `effectiveAt` **non** è normalizzabile → riga **`invalid`** → `invalidRowCount > 0` → Apply bloccato (*Policy fail-closed*).

### 9.4a Prezzo canonico *(D49-10 — **no** `Double == Double`)*

- Introducere in EXECUTION un **`PriceCanonicalizer`** (o nome equivalente) **unico** per dry-run e apply: **vietato** decidere uguaglianza/conflitto con uguaglianza **grezza** `Double`.
- **Preferenza**: confronto su **`Decimal`** e/o **rounding canonico** (scala/regole documentate, allineate al dominio prezzi dell’app). Se il progetto ha già helper di normalizzazione prezzo — **riusarli**.
- Regole: **stesso valore canonico** → stesso prezzo → ammette `skippedExisting` se anche la chiave logica coincide; **canonico diverso** con **stessa chiave** prodotto/tipo/`effectiveAt` → **`conflict`**; prezzo **non normalizzabile**, **NaN**, **±inf**, **negativo** → **`invalid`**; `invalidRowCount > 0` → Apply bloccato.

### 9.5 Piano apply puro / testabile
- Struttura tipo: righe `ApplicableProductPriceLine` + `ExcludedRowReason` + flags `isTruncated`, `hasSourceError`, `isPartial`.
- `prepareApplyPlan(snapshotLocale:preconditions:remoteRows:)` **senza** side effect (test in-memory).

### 9.6 Insert locale *(D49-08, D49-10, **D49-12 insert-only**)*

- **D49-12**: TASK-049 è **insert-only**: può **inserire** nuovi `ProductPrice` quando mancano; **non** `update` su `ProductPrice` esistenti; **non** `delete`. Stessa chiave logica + **prezzo canonico** diverso → **`conflict`**, mai UPDATE silenzioso. Stessa chiave + **stesso prezzo canonico** → **`skippedExisting`**.
- **Se** `ProductPrice` ha **già** un campo **`remoteID`**: usarlo per idempotenza «stessa riga remota» ove applicabile *(sempre dentro il perimetro insert-only)*.
- **Se** `ProductPrice.remoteID` **non** esiste: **nessuna migration** (*D49-08*) — chiave logica **`(prodotto risolto, tipo, `effectiveAt` canonico §9.4)`** + **D49-10** per il prezzo.

### 9.7 Dedup e conflitti *(chiave logica + prezzo canonico)*

- Chiave: **prodotto SwiftData** (risolto **senza ambiguità** — *D49-11*) + **tipo normalizzato** + **`effectiveAt` canonico** (*§9.4*).
- **`skippedExisting`**: stessa chiave + **stesso prezzo canonico** (*§9.4a*).
- **`conflict`**: stessa chiave + **prezzo canonico diverso**; **mapping duplicato** locale su `Product.remoteID`; incoerenze non risolvibili senza merge silenzioso.
- Righe remote anomale (overlap `id`, …) — vedi **§9.2** / *T49-36*.

### 9.8 Partial / errori *(classificazione esito)*
- **Partial** dopo errore inter-pagina: stato terminale **non apply-safe**.
- Conflitto prezzo su **stessa chiave logica** — vedi §9.7; **mai** silent merge.

### 9.9 UI DEBUG in OptionsView *(stile iOS nativo, due sezioni distinte)*

**Ruolo prodotto** *(obbligatorio)*:
- TASK-049 resta funzione **DEBUG / sviluppatore / strumenti Supabase** — **non** feature pensata per l’utente finale in flusso «consumer».
- Integrare nella **sezione Supabase / DEBUG già presente** in `OptionsView` se esiste; **non** promuovere a schermata principale o tab standard.
- Se in alcune build la sezione è **visibile anche al di fuori di `#if DEBUG`**, il copy e i badge devono comunque renderla **chiaramente tecnica** (azioni **solo locali**, **nessuna scrittura cloud**).

**Scelta UX** *(obbligatoria in EXECUTION)*:
- Componenti **nativi iOS**: `Form`, `Section`, `DisclosureGroup`, `Button`, `confirmationDialog`, eventuale `ProgressView` durante fetch/apply.
- **Due sezioni separate**:
  - **A** — preview read-only **TASK-048**;
  - **B** — dry-run / apply **TASK-049**.
- **Non** copiare pattern Android.

**Copy tecnico obbligatorio** *(localizzare in EXECUTION; tono **neutro**, non allarmistico)*:
- **Strumento tecnico** / perimetro sviluppatore.
- **Solo locale** (modifiche SwiftData).
- **Inserisce solo storico prezzi mancante** *(insert-only)*.
- **Non aggiorna il prezzo corrente del prodotto** (*D49-04*).
- **Non scrive su Supabase**.
- **Ricalcola dry-run** se cambi account, sessione o dati catalogo rilevanti.

**Sezione B — contenuto minimo**:
- **Stato** piano *(allineato a §9.12)*.
- **Conteggi**: `remoteRead`, `included`, `skippedExisting`, `unmapped`, `invalid`, `conflicts`.
- **Badge / chip** *(localizzare in EXECUTION)*: **«Solo locale»**, **«DEBUG»**, **«Nessuna scrittura cloud»**.
- **CTA primaria** — wording prudente: **«Applica storico prezzi locale»** — solo se *Policy fail-closed* OK.
- **CTA secondaria**: **«Ricalcola dry-run»**.
- **`DisclosureGroup`**: dettagli / sample limitati (unmapped · invalid · conflict).
- **`applyBlocked`**: motivi in **linguaggio semplice** oltre a codici interni — non solo label tecniche opache.
- **`confirmationDialog`**: deve dire esplicitamente che si **modifica solo SwiftData locale**, **non si scrive su Supabase**, **non** si aggiorna **direttamente** il prezzo corrente su `Product` (*D49-04*), e mostrare **conteggi** inserite vs saltate coerenti col piano.
- **Dopo `save()` + verifica post-save** (*D49-09*): mostrare `inserted` / `skippedExisting` / `totalConsidered` **confermati**, non ottimistici.

**Confusione UX** *(mitigazione)*: sample UI limitati; conteggi totali = piano — §12 T49-21.

### 9.10 Apply SwiftData: atomicità, **insert-only** *(D49-12)*, save unico, verifica post-save *(D49-09)*

- **D49-12**: solo **`insert`** di `ProductPrice` nuovi; **nessun** `delete` / **nessun** campo-update su `ProductPrice` esistenti.
- **Nessun** salvataggio **riga-per-riga** intermedio: `prepareApplyPlan` (puro) → insert validati → **un** `modelContext.save()` ove coerente col progetto.
- Se **`save()` fallisce**: **`failed(error)`**; **vietato** `applied(summary)` o successo parziale narrativo.
- **D49-09**: dopo `save()` senza throw, **verifica locale** (readback / conteggio affidabile sul contesto SwiftData o equivalente documentato). `inserted`, `skippedExisting`, `totalConsidered` **non** solo ottimistici; se la verifica fallisce → **`failed(error)`**, **non** `applied(summary)`.
- **Rollback SwiftData**: se non garantito, documentare limite in EXECUTION/Review; nessun `save()` intermedio in TASK-049.

### 9.11 Fetch paginato e impronta memoria *(dataset grande)*

- Il fetch **può** essere **paginato** a livello rete; il **piano in memoria** deve restare **compatto**:
  - righe **applicabili** normalizzate (non l’intero blob raw per riga se evitabile);
  - **contatori** aggregati;
  - **sample limitati** solo per UI/debug;
  - **motivi di blocco** / prime N cause — non l’elenco infinito in RAM se non necessario.
- **Non** conservare **l’intero payload remoto grezzo** se non necessario — derivare strutture lean; tracciare **insieme di `id` remoti** visti (o contatori di unicità) per rilevare overlap anomalo senza memoria ingestibile; se il controllo richiede troppa RAM → **cap** → **`truncated = true`**.
- Se si raggiunge un **safety cap** documentato (pagine, righe, byte stimato): **`truncated = true`** → apply **bloccato** (*Policy fail-closed definitiva*).

### 9.12 Stati UI/ViewModel e concorrenza *(async)*

Stati previsti *(enum o equivalente testabile)*:

| Stato | Significato | UI |
|-------|-------------|-----|
| `idle` | Nessuna operazione in corso | CTA abilitate secondo policy |
| `preparingDryRun` | Fetch + build piano | `ProgressView` opzionale; **disabilitare** CTA che mutano stato |
| `dryRunReady` | Piano safe e summary pronto | Mostra conteggi; Apply solo se fail-closed PASS |
| `applyBlocked(reason)` | Policy fail-closed o guard fallito | Apply disabilitato; **motivo visibile** |
| `applying` | Persistenza SwiftData in corso | Tutte le CTA mutanti **disabilitate**; anti **doppio tap** |
| `applied(summary)` | `save()` OK **e** verifica post-save (*D49-09*) OK | Summary **confermato** inserted/skipped/total |
| `failed(error)` | Errore rete/SwiftData/post-save/validazione | Nessun successo dichiarato; recovery via «Ricalcola» o reset |

**Regole**:
- Durante **`preparingDryRun`** e **`applying`**: bottoni rilevanti **disabilitati**; nessuna seconda invocazione concurrent dello stesso flusso senza cancellazione esplicita.
- **Invalidazione piano**: su **logout**, **cambio account/sessione Supabase**, o **refresh catalogo** che renda obsoleto il mapping `remoteID` usato nel dry-run *(evento definito in EXECUTION)* → **cancellare** o **invalidare** il piano; stato → `idle` o `applyBlocked` con motivo «sessione/catalogo cambiato»; **vietato** riusare piani tra **utenti diversi** o sessioni diverse.
- Snapshot **user/session** legato al piano: in `apply` verificare coerenza con dry-run; mismatch → **errore / piano invalidato**, mai apply silenzioso.

---

## Cancellation / lifecycle safety

- **Durante fetch / dry-run** (`preparingDryRun`): **lecito** invalidare/cancellare il piano se l’utente **esce**, **logout**, **cambia account/sessione** — **zero** side effect SwiftData dal dry-run annullato.
- **Subito prima** di entrare in `applying`: **ultimo** check snapshot sessione + *Policy fail-closed*; fallimento → **no** `applying` / `failed` o `applyBlocked`.
- **Durante `applying`**: evitare **cancellation** a metà che produca UI **ambigua**; se Task/async è cancellabile, in EXECUTION definire → **`failed`**, mai successo parziale presentato come completo.
- **Nessun successo parziale** dichiarato: solo `applied` (con *D49-09*) o `failed` / `applyBlocked`.
- Se app/view **scompare** durante `applying`, al ritorno **non** affidarsi a piano volatile: ripartire da **idle** / **ricalcolo dry-run** o verifica su store persistente.

---

## Piano volatile / non persistente

- Il **piano dry-run** (strutture VM/UI prodotte da `preparingDryRun`) è **volatile**: **non** si salva in SwiftData, **non** in `UserDefaults`/file di progetto TASK-049.
- **Non** sopravvive a **restart app** / **relaunch**; dopo cold start l’utente deve **«Ricalcola dry-run»**.
- **Non** è riusabile dopo **logout**, **cambio account**, **cambio sessione** Supabase, **refresh catalogo** che invalidi i mapping, né dopo **invalidazione** esplicita (*§9.12*, *Cancellation*).
- Dopo ogni invalidazione: stato → `idle` / `applyBlocked` con invito al **ricalcolo** — **mai** apply da piano «stale» in RAM.

---

## 10. Strategia dati

- **SwiftData** resta cache / source locale per uso offline (allineato al resto dell’app).
- **Supabase** è fonte remota condivisa **solo in lettura** per questo task.
- **Decisione D49-04**: TASK-049 applica **solo** lo storico locale tramite entità **`ProductPrice`**. **Non** aggiorna direttamente **`Product.purchasePrice`** né **`Product.retailPrice`** — anche se altre parti dell’app potessero in futuro derivare la «current price» dallo storico, ciò è **fuori** da questo slice. Eventuale task futuro dedicato al riallineamento «current price» se il prodotto lo richiede.
- **D49-08**: **evitare migration SwiftData** in TASK-049 salvo che `ProductPrice.remoteID` **esista già** nel modello. Se assente → dedupe **logico** *(prodotto via `Product.remoteID`, tipo ed `effectiveAt` canonico §9.4)* — **nessun** campo nuovo obbligatorio in questo slice; eventuale `ProductPrice.remoteID` persistito per push/sync futuro = **task futuro**.

---

## 10a. Guardrail anti-overengineering per EXECUTION futura

TASK-049 è già **delicato** perché introduce **persistenza locale** da dati remoti. In **EXECUTION** futura deve restare uno **slice minimo**:

- Preferire **funzioni pure** e **piccoli value type** per piano / dedupe / guardrail.
- **Evitare nuovi layer architetturali** se i servizi **TASK-048** sono **estendibili** in modo pulito.
- **Evitare** nuovi **scheduler**, **background task**, **cache persistenti** dedicate o **code retry** per questo slice.
- **Evitare UI nuova** fuori da **`OptionsView`** / area **DEBUG Supabase** esistente.
- **Evitare refactor ampi** del catalog pull/apply esistente salvo **indispensabile** e documentato.
- **Evitare migration SwiftData** salvo **override esplicito** già tracciato (*D49-08* / *Decisioni*).
- Se una scelta tecnica richiede **refactor largo** → **fermarsi** e riportare in **REVIEW / PLANNING** invece di procedere.

**Scopo:** mantenere TASK-049 come passaggio **controllato** da preview read-only ad **apply locale insert-only**, **non** come avvio della **sync bidirezionale** o di un motore sync generico.

---

## 11. Criteri di accettazione

### Prontezza alla EXECUTION *(planning completo)*

Il task sarà considerato **pronto per EXECUTION** *(transizione solo con user override)* solo se nel file task risultano **esplicitamente** presenti e stabili:

- [ ] **Policy fail-closed definitiva** (*gating Apply* — sezione dedicata).
- [ ] Decisione **current price** — **D49-04**.
- [ ] **D49-08** — evitare migration; dedupe logico se `ProductPrice.remoteID` assente.
- [ ] **D49-09** — summary post-save **non ottimistico** (§9.10).
- [ ] **Strategia atomica SwiftData** + verifica post-save (§9.10).
- [ ] **Cancellation / lifecycle safety** (sezione dedicata).
- [ ] **Normalizzazione `effectiveAt` unica** (§9.4).
- [ ] **Invalidazione piano** su cambio sessione/account/catalogo (*§9.12*).
- [ ] **UX DEBUG nativa iOS** — ruolo sviluppatore, badge, copy non-cloud (*§9.9*).
- [ ] **D49-10** — prezzo canonico; **no** `Double == Double`.
- [ ] **D49-11** — `Product.remoteID` duplicato locale blocca apply.
- [ ] **D49-12** — `ProductPrice` apply **insert-only**.
- [ ] **Piano volatile** (sezione dedicata); non persistente.
- [ ] **Paging/ordine** stabile con tie-breaker **`id`**; anomalie → partial/sourceError (*§9.2*).
- [ ] **UX** copy «strumento tecnico / solo locale / …» (*§9.9*).
- [ ] **Matrice test** (*§12*, **T49-30…T49-37** oltre alle righe precedenti).
- [ ] **Zero write Supabase** — audit grep/static **esteso** in review (*§6*, *Contratto*).
- [ ] **Slice minimo** — **§10a**: nessun scheduler, cache persistente nuova, background sync, refactor ampio non giustificato, sync bidirezionale (*governance planning/review*).
- [ ] **Ordine EXECUTION** — **test-first** documentato: piano puro / XCTest → apply SwiftData → UI DEBUG (*§14*, *Handoff → Execution*).

### Contratto implementation / review

- [ ] **Confronto prezzo canonico** documentato (*§9.4a*); **vietato** dedupe/conflict con **`Double == Double`** grezzo.
- [ ] **Mapping locale duplicato** (`Product.remoteID`) → apply bloccato (*D49-11*).
- [ ] **Insert-only** `ProductPrice` (*D49-12*): nessun update/delete storico per «risolvere» conflitti.
- [ ] **Piano dry-run volatile** — non SwiftData, non sopravvive a relaunch (*sezione dedicata*).
- [ ] **Fetch paginato** con ordinamento **totale stabile** + **`id`** finale; incoerenze → `partial`/`sourceError`.
- [ ] UI: testi **strumento tecnico**, **solo locale**, **nessuna scrittura cloud**, **ricalcolo** dopo cambio account/catalogo (*§9.9*).
- [ ] **Nessuna migration SwiftData** in TASK-049 **salvo** `ProductPrice.remoteID` **già presente** nel modello alla lettura del codice, o **override utente esplicito** documentato nelle *Decisioni*.
- [ ] **Dedupe logico** documentato (*D49-08* + *D49-10*): stessa chiave + stesso **prezzo canonico** → `skippedExisting`; stessa chiave + **canonico diverso** → `conflict` → Apply bloccato.
- [ ] **`applied(summary)`** solo dopo verifica locale post-`save()` (*D49-09*); altrimenti **`failed(error)`**.
- [ ] **Lifecycle/cancellation**: comportamento § *Cancellation / lifecycle safety* verificato (test dove fattibile).
- [ ] UI chiaramente **DEBUG/developer** — **non** presentata come scrittura cloud.
- [ ] **Dry-run** mostra conteggi **remoteRead / included / skippedExisting / unmapped / invalid / conflicts** *(o etichette localizzate equivalenti)*.
- [ ] **CTA Apply disabilitata** se **una sola** condizione della *Policy fail-closed definitiva* fallisce; UI mostra **motivo**.
- [ ] **Apply idempotente**; **nessun duplicato** logico per chiave documentata.
- [ ] **Apply non modifica** `Product.purchasePrice` / `Product.retailPrice` — verificabile con test/assert su modello dopo apply (**no-current-price-change** obbligatorio in review).
- [ ] **Zero write Supabase**: solo **read paths**; review con grep/static su file modificati per `.insert`, `.upsert`, `.update`, `.delete`, `.rpc`, `.functions`, `.storage`, e riferimenti **HTTP** **`POST`/`PATCH`/`DELETE`** ove pertinenti al client; **solo** `.select`/`.from` ammessi come in *§6*; **ogni falso positivo** documentato in review.
- [ ] **Review futura**: checklist sezione **Review (Claude)** completata ove applicabile; scelte fuori planning riportate in **PLANNING**, non implementate implicitamente.
- [ ] **Localizzazioni** IT / EN / ES / ZH-Hans per nuove stringhe DEBUG *(in EXECUTION, non in questo turno planning)*.
- [ ] **XCTest puri**: piano, prezzo canonico, dedupe, **mapping duplicato**, fail-closed, insert-only, pagination anomaly, ordinamento, conflitto prezzo, effectiveAt canonico, post-save, cancellation dry-run, relaunch piano, stati UI/VM, mismatch sessione, anti doppio tap.

---

## 12. Matrice test proposta *(XCTest / naming da fissare in EXECUTION)*

| ID | Scenario | Esito atteso |
|----|----------|--------------|
| T49-01 | Preview/remoto **0 righe** | success **no-op**; apply non applicabile o no-op sicuro |
| T49-02 | Prezzi remoti **validi**, prodotti mappati | piano incluso; apply (test) crea N righe |
| T49-03 | Prezzo con **product_id** senza `Product.remoteID` locale | **unmapped > 0** → CTA Apply **disabilitata** |
| T49-04 | **Duplicato** stessa riga remota (ri-applicazione) | **idempotenza** — nessun insert in più |
| T49-05 | **Tipo** non normalizzabile / invalido | **invalid > 0** → CTA Apply **disabilitata** |
| T49-06 | **Prezzo** negativo / non numerico | **invalid > 0** → CTA **disabilitata** |
| T49-07 | **Partial** fetch (errore dopo alcune pagine) | **no apply**; CTA **disabilitata** |
| T49-08 | **truncated** *(cap raggiunto)* | CTA Apply **disabilitata** |
| T49-09 | **sourceError** (es. parsing) | CTA Apply **disabilitata** |
| T49-10 | **Apply due volte** con stesso dataset | conteggio `ProductPrice` invariato dopo la prima apply |
| T49-11 | **Logout** / cambio account / sessione invalida | piano invalidato / stato reset; **nessun** riuso tra utenti |
| T49-12 | Dry-run **safe** (tutte condizioni fail-closed OK) | CTA Apply **abilitata** |
| T49-13 | **unmapped > 0** | CTA Apply **disabilitata** |
| T49-14 | **invalid > 0** | CTA Apply **disabilitata** |
| T49-15 | **conflict > 0** | CTA Apply **disabilitata** |
| T49-16 | **partial / truncated / sourceError** | CTA Apply **disabilitata** |
| T49-17 | **User/session mismatch** tra snapshot dry-run e tentativo apply | piano invalidato o apply rifiutato; **nessun** insert |
| T49-18 | **Doppio tap** / invocazione concurrent | stato VM / UI impedisce seconda apply |
| T49-19 | Dopo apply | **`Product.purchasePrice` / `retailPrice`** **invariati** *(D49-04)* |
| T49-20 | **`save()` fallisce** o **verifica post-save fallisce** (*D49-09*) | **`failed(error)`**; **nessun** `applied(summary)` |
| T49-21 | Sample UI limitato ma conteggi totali | count summary = aggregati reali del piano |
| T49-22 | **`ProductPrice.remoteID`** assente nel modello | dedupe **logico** senza migration (*D49-08*); apply coerente |
| T49-23 | Stessa chiave prodotto/tipo/**effectiveAt** canonico + **stesso prezzo canonico** (*§9.4a*) | `skippedExisting`; nessun insert duplicato |
| T49-24 | Stessa chiave + **prezzo canonico diverso** | `conflict`; **conflictCount > 0** → CTA **disabilitata** |
| T49-25 | Post-save verification **fallisce** | `failed(error)`; **nessun** summary `applied` |
| T49-26 | **Cancellation** durante dry-run | piano invalidato; **nessun** side effect SwiftData |
| T49-27 | Cancellation / **cambio account prima** di apply | apply **rifiutato** o piano invalidato |
| T49-28 | UI DEBUG | badge **Solo locale** / **Nessuna scrittura cloud** *(e DEBUG ove previsto)* visibili |
| T49-29 | `effective_at` **raw diverso** ma **canonico uguale** (§9.4) | dedupe/skippedExisting corretto; nessun falso conflict |
| T49-30 | **`Double` remoto raw diverso**, **stesso prezzo canonico** (*§9.4a*) | `skippedExisting`; nessun conflict spurio |
| T49-31 | Stessa chiave logica, **prezzo canonico diverso** | `conflict`; CTA **disabilitata** |
| T49-32 | Prezzo **NaN** / **±inf** / non canonizzabile | **invalid**; CTA **disabilitata** |
| T49-33 | **Due** `Product` con stesso **`remoteID`** | mapping conflict (*D49-11*); CTA **disabilitata** |
| T49-34 | Riga locale esistente stessa chiave, prezzo canonico diverso | **nessun** update `ProductPrice`; resta `conflict`/bloccato (*D49-12*) |
| T49-35 | Dopo **app relaunch** | piano precedente **non** riusabile; serve **Ricalcola dry-run** |
| T49-36 | **Overlap** `id` remoto o gap pagine durante fetch | `partial` o `sourceError`; CTA **disabilitata** |
| T49-37 | Ordinamento remoto **senza** tie-breaker **`id`** stabile | configurazione **non ammessa** per apply — fail planning/review |

---

## 13. Rischi

- **Duplicazione** storico prezzi locale per dedupe insufficiente o chiave sbagliata.
- **Mismatch** prodotto remoto/locale (remoteID mancante o duplicati locali — mitigare con guard esistenti TASK-040).
- **Timezone** / parsing `effective_at` text vs `Date` locale — riusare normalizer unico; test con fixture noti.
- **Floating point / confronto `Double`**: mitigazione **D49-10**; test T49-30/31.
- **Duplicati `Product.remoteID`**: **D49-11** + T49-33.
- **Dataset grande**: memoria, tempo, cancellazione task async — paginazione, optional progress DEBUG, tetto safety con `truncated`.
- **Apply SwiftData non atomico / save parziale**: mitigazione §9.10; documentare limiti framework in review se pertinenti.
- **Cambio sessione durante dry-run/apply**: mitigazione §9.12 + § *Cancellation / lifecycle safety*.

---

## 14. Handoff futuro per EXECUTION

- **EXECUTION** **solo** dopo **user override esplicito** e handoff PLANNING → EXECUTION firmato in questo file.

**Ordine consigliato** *(motivo: evitare UI prima di logica dati sicura)*:

1. Leggere i **file Swift reali** elencati in §8 dal repository aggiornato.
2. **Gate DDL / schema** Supabase **read-only** (come TASK-048); nessuna modifica server.
3. Confermare se **estendere** i servizi **TASK-048** o introdurre un **helper minimo** dedicato — senza nuovi layer se non necessario (*§10a*).
4. Implementare **prima** gli **XCTest puri** (piano senza side effect): **`PriceCanonicalizer`**; **effectiveAt** canonicalizer; **dedupe/conflict**; **mapping duplicato**; **fail-closed**; **session mismatch**; **post-save verification** *(e resto §12 ove prioritario)*.
5. Poi implementare il **servizio apply** SwiftData **insert-only** (**§9.10**, **D49-12**).
6. **Solo alla fine** integrare la **UI DEBUG** in **`OptionsView`** (**§9.9**, **§9.12**).

Chiusura: **Policy fail-closed**; **D49-08/09**; localizzazioni; **audit zero-write esteso** (*§6*, *Contratto §11*).

---

## Non incluso *(riassunto anti-scope)*

Vedi §7; in sintesi: **nessun** push remoto ProductPrice, **nessuna** write Supabase, **nessun** sync metadata Android-style, **nessuna** auth nuova.

---

## Scopo *(sintesi operativa)*

Portare iOS da **preview read-only** (TASK-048) ad **apply locale controllato** dello storico `inventory_product_prices` in SwiftData, con **dry-run**, **guardrail rigidi** e **idempotenza**, senza modificare il cloud.

---

## Planning (Claude) — solo documentale *(turno corrente)*

### Analisi

TASK-048 ha validato lettura sicura a **campione**; TASK-049 introduce **persistenza** storico con **fail-closed unificato**, **prezzo canonico** (**D49-10**), **mapping locale non ambiguo** (**D49-11**), **insert-only** (**D49-12**), **piano volatile**, **paginazione deterministica**, **D49-08/09** e lifecycle esplicito.

### Approccio proposto

Servizio/fasi **in visione d’insieme**: **fetch** (*§9.2* ordine stabile + *§9.11* RAM/unicità `id`) → **`prepareApplyPlan`** (*§9.4a* prezzo + §9.4 date) → UI **§9.9** + stati **§9.12** → **`confirmationDialog`** → **apply insert-only** **§9.10**. Piano **solo volatile** (*sezione dedicata*). Session snapshot; mismatch → invalidazione.

In **EXECUTION**, rispettare **§10a** (anti-overengineering) e l’**ordine operativo test-first** in **§14** (XCTest / piano puro prima del servizio apply; **UI DEBUG per ultima**).

### File da modificare *(previsti — confermare in EXECUTION)*

- Servizi Supabase / SwiftData sopra elencati; `OptionsView.swift`; **`Models.swift`** solo lettura — **nessuna** modifica schema TASK-049 salvo `ProductPrice.remoteID` **già presente** o override documentato (*D49-08*).
- Test target esistente; `Localizable.xcstrings` o `Localizable.strings` secondo convenzione progetto *(stringhe solo in EXECUTION, non in questo turno planning)*.

### Rischi identificati

Vedi §13; aggiungere in EXECUTION: limite rollback SwiftData se `save()` fallisce a metà; race su cambio sessione durante fetch.

### Handoff → Execution

- **Prossima fase**: EXECUTION *(solo su **user override** esplicito)*
- **Prossimo agente**: Codex / Executor
- **Azione consigliata**: seguire l’**ordine numerato** in **§14** (Swift reali → gate DDL → estensione TASK-048 vs helper → **XCTest puri** → apply SwiftData → **UI per ultima**); **§10a**; **D49-10…D49-12**; **`ProductPrice.remoteID`** solo se già nel modello (**D49-08**).

---

## Execution (Cursor) — COMPLETED / HANDOFF TO REVIEW

### Avvio EXECUTION controllata

- **Data**: 2026-05-06
- **Autorizzazione**: l'utente ha autorizzato esplicitamente il passaggio di TASK-049 da PLANNING a EXECUTION.
- **Scope iniziale**: execution controllata e test-first per pull/dry-run/apply locale `ProductPrice`; ordine operativo: leggere Swift reali aggiornati, confermare architettura, implementare test puri, poi servizio SwiftData insert-only, UI DEBUG in `OptionsView` solo alla fine.
- **File letti finora**:
  - `docs/MASTER-PLAN.md`
  - `docs/TASKS/TASK-049-supabase-productprice-apply-locale-swiftdata-ios.md`
- **Decisione riuso servizi TASK-048 vs helper minimo**: da confermare dopo la lettura obbligatoria dei file Swift reali in FASE 1; fino a tale conferma non si modifica logica runtime.
- **Vincoli confermati**: nessuna write Supabase; nessun apply reale automatico; nessun push remoto `ProductPrice`; nessun uso di `record_sync_event` / `sync_events`; nessun outbox/realtime/background sync; nessun update di `Product.purchasePrice` / `Product.retailPrice`; nessun update/delete di `ProductPrice` esistenti.
- **Esclusioni confermate**: nessuna modifica Android; nessuna modifica Supabase, SQL, migration, RLS, RPC, Edge Functions o backend.

### FASE 1 — Lettura codice reale

- **Modelli SwiftData letti**:
  - `iOSMerchandiseControl/Models.swift`
  - `Product` ha `remoteID: UUID?`, metadata remote update/delete, `purchasePrice`, `retailPrice`, relazione cascade `priceHistory`.
  - `ProductPrice` contiene `type: PriceType`, `price: Double`, `effectiveAt: Date`, `source`, `note`, `createdAt`, relazione `product`; **non contiene `remoteID`**.
  - `PriceType` esiste come enum `.purchase` / `.retail`.
- **Servizi Supabase/TASK-048 letti**:
  - `iOSMerchandiseControl/SupabaseInventoryDTOs.swift`
  - `iOSMerchandiseControl/SupabaseInventoryService.swift`
  - `iOSMerchandiseControl/SupabaseProductPricePreviewService.swift`
  - `RemoteInventoryProductPriceRow` esiste già per `inventory_product_prices` con `id`, `owner_user_id`, `product_id`, `type`, `price`, `effective_at`, `source`, `note`, `created_at`.
  - TASK-048 ha `SupabaseProductPricePreviewService` read-only con fetch paginato a cap campione; `SupabaseInventoryService.fetchProductPricesPreviewPage` usa `.select` e ordinamento stabile totale `product_id`, `type`, `effective_at`, `id`.
  - Il gate DDL operativo non è un file SQL locale in questa repo; la sorgente reale disponibile nel branch iOS è il servizio read-only TASK-048 e la documentazione task/schema già letta. TASK-049 non modifica SQL.
- **Servizi catalogo/pull/apply letti**:
  - `iOSMerchandiseControl/SupabasePullPreviewModels.swift`
  - `iOSMerchandiseControl/SupabasePullPreviewService.swift`
  - `iOSMerchandiseControl/SwiftDataInventorySnapshotService.swift`
  - `iOSMerchandiseControl/SupabasePullApplyService.swift`
  - `SwiftDataInventorySnapshotService` già costruisce mapping `Product.remoteID` e rileva duplicati remoteID; lo storico prezzo esistente è mappato per barcode/tipo/effectiveAt.
  - `SupabasePullPreviewService` tratta `inventory_product_prices` come preview/diff catalogo e usa guard `priceHistoryIncomplete` per bloccare apply catalogo; `SupabasePullApplyService` non crea `ProductPrice` e può aggiornare `Product.purchasePrice` / `retailPrice`, quindi non va riusato per TASK-049.
- **UI OptionsView letta**:
  - `iOSMerchandiseControl/OptionsView.swift`
  - Esiste una sezione DEBUG Supabase in `#if DEBUG` con auth, diagnostica, preview catalogo, card preview `ProductPrice` read-only TASK-048, baseline, preflight/push manuale.
  - Lo stile esistente usa `Form`, `Section`, `DisclosureGroup`, `Button`, `confirmationDialog`, `ProgressView`, `Label`, `LabeledContent`, `SectionHeader`; TASK-049 va inserito come tool DEBUG locale accanto alla preview TASK-048, non come feature primaria.
- **Test/localizzazioni letti**:
  - `iOSMerchandiseControlTests/SupabaseProductPricePreviewServiceTests.swift`
  - `iOSMerchandiseControlTests/SupabasePullApplyServiceTests.swift`
  - `iOSMerchandiseControl/it.lproj/Localizable.strings`
  - Convenzione test: XCTest puri/in-memory SwiftData; root group Xcode file-system-synchronized, quindi nuovi file Swift/test vengono inclusi senza patch manuale `project.pbxproj`.

### FASE 2 — Decisione architetturale

- **Decisione servizio**: creare un helper minimo dedicato `SupabaseProductPriceApplyService` per piano/apply locale `ProductPrice`, riusando il protocollo/fetch read-only TASK-048 (`SupabaseProductPricePreviewFetching` / `fetchProductPricesPreviewPage`) per evitare nuove API Supabase e mantenere zero-write.
- **`ProductPrice.remoteID`**: assente nel modello reale; TASK-049 userà dedupe logico senza migration SwiftData.
- **Dedupe logico**: chiave `Product.remoteID` risolta senza ambiguità → prodotto locale/barcode, `PriceType`, `effectiveAt` canonico; stessa chiave + prezzo canonico uguale = `skippedExisting`, stessa chiave + prezzo canonico diverso = `conflict`.
- **Normalizzazione `effectiveAt`**: usare un canonicalizer unico che produce `Date` e stringa UTC `yyyy-MM-dd HH:mm:ss` per dry-run e apply; raw diversi ma stesso istante canonico deduplicano.
- **Normalizzazione prezzo canonica**: introdurre `PriceCanonicalizer` dedicato basato su `Decimal`/rounding a scala documentata; niente decisioni con `Double == Double`; NaN, infinito, negativo o non canonizzabile = `invalid`.
- **Test**: aggiungere XCTest puri mirati in `iOSMerchandiseControlTests/SupabaseProductPriceApplyServiceTests.swift` prima della logica runtime/UI.
- **Servizio SwiftData**: aggiungere `iOSMerchandiseControl/SupabaseProductPriceApplyService.swift`; apply `ProductPrice` insert-only, un solo `modelContext.save()` per run, verifica post-save prima del result.
- **UI DEBUG**: estendere solo `iOSMerchandiseControl/OptionsView.swift` nella sezione Supabase DEBUG esistente, dopo la preview read-only TASK-048; aggiungere localizzazioni IT/EN/ES/ZH-Hans.
- **File da modificare previsti**:
  - `iOSMerchandiseControl/SupabaseProductPriceApplyService.swift`
  - `iOSMerchandiseControlTests/SupabaseProductPriceApplyServiceTests.swift`
  - `iOSMerchandiseControl/OptionsView.swift`
  - `iOSMerchandiseControl/it.lproj/Localizable.strings`
  - `iOSMerchandiseControl/en.lproj/Localizable.strings`
  - `iOSMerchandiseControl/es.lproj/Localizable.strings`
  - `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`
  - `docs/TASKS/TASK-049-supabase-productprice-apply-locale-swiftdata-ios.md`
  - `docs/MASTER-PLAN.md` solo per fase/handoff finale.
- **Conferme anti-scope**: nessuna incompatibilità col planning emersa; nessun Android/Supabase/SQL; nessun push remoto; nessuna migration SwiftData; nessun update di current price prodotto.

### FASE 3 — Test-first

- **File test aggiunto**: `iOSMerchandiseControlTests/SupabaseProductPriceApplyServiceTests.swift`.
- **Copertura implementata prima della UI**:
  - prezzo canonico senza `Double == Double`;
  - raw price diverso ma prezzo canonico uguale → `skippedExisting`;
  - stessa chiave logica + prezzo canonico diverso → `conflict`;
  - prezzo NaN / infinito / negativo / non normalizzabile → `invalid`;
  - `effectiveAt` raw diverso ma canonico uguale → dedupe;
  - `effectiveAt` non normalizzabile → `invalid`;
  - prodotto remoto senza `Product` locale → `unmapped`;
  - due `Product` locali con stesso `remoteID` → mapping conflict;
  - `partial` / `truncated` / `sourceError` → apply bloccato;
  - session mismatch → apply rifiutato;
  - doppio apply → nessun duplicato;
  - `ProductPrice` esistente stessa chiave ma prezzo diverso → conflict, nessun update;
  - apply non modifica `Product.purchasePrice` / `Product.retailPrice`.

### FASE 4 — Servizio SwiftData insert-only

- **File aggiunto**: `iOSMerchandiseControl/SupabaseProductPriceApplyService.swift`.
- **Implementazione**:
  - `prepareApplyPlan` puro/testabile con `ProductPriceApplyLocalSnapshot`;
  - fetch controllato read-only via protocollo TASK-048 `SupabaseProductPricePreviewFetching`;
  - normalizzazione prezzo con `PriceCanonicalizer` (`Decimal`, scala 3) e normalizzazione `effectiveAt` UTC `yyyy-MM-dd HH:mm:ss`;
  - dedupe logico senza migration perché `ProductPrice.remoteID` non esiste;
  - apply SwiftData **insert-only** su `ProductPrice`;
  - nessun `save()` riga-per-riga: un solo `modelContext.save()` quando ci sono insert;
  - verifica post-save tramite nuovo piano prima di restituire `ProductPriceApplyResult`;
  - fallimento verifica → `ProductPriceApplyError.verificationFailed`;
  - nessun update/delete di `ProductPrice` esistenti;
  - nessuna modifica a `Product.purchasePrice` / `Product.retailPrice`.

### FASE 5 — UI DEBUG OptionsView

- **File modificato**: `iOSMerchandiseControl/OptionsView.swift`.
- **Implementazione**:
  - card TASK-049 aggiunta nella sezione Supabase DEBUG esistente, subito dopo la preview read-only TASK-048;
  - separazione visiva/copy tra preview cloud read-only TASK-048 e dry-run/apply locale TASK-049;
  - stati UI locali `idle/loading/ready/applying/applied/failed`;
  - CTA primaria `options.supabase.priceApply.button.apply` (“Applica storico prezzi locale” in IT);
  - CTA secondaria `options.supabase.priceApply.button.dryRun` (“Ricalcola dry-run” in IT);
  - `confirmationDialog` obbligatoria prima dell'apply;
  - apply abilitato solo se `plan.isApplyAllowed`;
  - motivi di blocco e issue sample mostrati in `DisclosureGroup`;
  - reset/cancel su `onDisappear`, cambio account e sign-out.
- **Localizzazioni aggiornate**:
  - `iOSMerchandiseControl/it.lproj/Localizable.strings`
  - `iOSMerchandiseControl/en.lproj/Localizable.strings`
  - `iOSMerchandiseControl/es.lproj/Localizable.strings`
  - `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`
  - `iOSMerchandiseControlTests/LocalizationCoverageTests.swift`

### File modificati

- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-049-supabase-productprice-apply-locale-swiftdata-ios.md`
- `iOSMerchandiseControl/SupabaseProductPriceApplyService.swift`
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/it.lproj/Localizable.strings`
- `iOSMerchandiseControl/en.lproj/Localizable.strings`
- `iOSMerchandiseControl/es.lproj/Localizable.strings`
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`
- `iOSMerchandiseControlTests/SupabaseProductPriceApplyServiceTests.swift`
- `iOSMerchandiseControlTests/LocalizationCoverageTests.swift`

### Check eseguiti

- ✅ **ESEGUITO — Build compila**: `xcodebuild build -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,id=4CE85775-BEF1-44D5-9BBF-B180EDF09D0B'` → **BUILD SUCCEEDED**.
- ✅ **ESEGUITO — Test mirati TASK-049**: `xcodebuild test ... -only-testing:iOSMerchandiseControlTests/SupabaseProductPriceApplyServiceTests -only-testing:iOSMerchandiseControlTests/LocalizationCoverageTests/testTask049ProductPriceApplyLocalizationKeysExistInSupportedLanguages` → **TEST SUCCEEDED**.
- ✅ **ESEGUITO — Test esistenti TASK-048**: `xcodebuild test ... -only-testing:iOSMerchandiseControlTests/SupabaseProductPricePreviewServiceTests` → **TEST SUCCEEDED**.
- ✅ **ESEGUITO — Localizzazioni parseabili**: `plutil -lint` su IT/EN/ES/ZH-Hans → **OK**.
- ✅ **ESEGUITO — Modifiche coerenti con planning**: ordine rispettato (lettura Swift → decisione architettura → test puri → servizio SwiftData → UI DEBUG).
- ✅ **ESEGUITO — Criteri di accettazione verificati**: coperti da test mirati + audit statico; apply fail-closed, idempotente, insert-only, session-bound, senza current price update.
- ✅ **ESEGUITO — Nessun warning nuovo introdotto**: build/test non mostrano warning Swift nei file TASK-049; l'unico warning Xcode osservato è `Metadata extraction skipped. No AppIntents.framework dependency found`, già presente nei run precedenti e non legato alla diff TASK-049.
- ⚠️ **NON ESEGUIBILE / NON RICHIESTO — Test Simulator manuale UI**: non eseguito perché task/utente non richiedono verifica manuale Simulator; UI verificata tramite build, compilazione SwiftUI e static review.

### Audit zero-write Supabase

- ✅ **ESEGUITO — grep/static audit** sui file TASK-049:
  - pattern: `.insert`, `.upsert`, `.update`, `.delete`, `.rpc`, `.functions`, `.storage`, `POST`, `PATCH`, `DELETE`;
  - nessuna chiamata Supabase write trovata;
  - falsi positivi documentati:
    - `context.insert(ProductPrice(...))` = insert SwiftData locale richiesto dal task;
    - `context.insert(...)` nei test = setup SwiftData locale;
    - `Set.insert(...)` / dictionary `insert(...)` = strutture dati locali;
    - `preview.updateCandidates` / `result.updated` in `OptionsView` = codice catalogo preesistente, non TASK-049 Supabase write.
- ✅ **ESEGUITO — audit anti-scope**: nessun `.upsert`, `.delete`, `.rpc`, `.functions`, `.storage`, `record_sync_event`, `sync_events`, outbox, realtime/background introdotto nei file TASK-049.
- ✅ **Conferma**: nessun Android modificato; nessun Supabase SQL/migration/RLS/RPC/Edge/backend modificato; nessun push remoto `ProductPrice`; nessuna scrittura cloud.
- ✅ **Conferma**: `Product.purchasePrice` / `Product.retailPrice` solo letti nello snapshot/test, non modificati dal servizio.

### Rischi rimasti

- DDL SQL reale non è presente come file modificabile/leggibile in questa repo iOS; l'execution ha usato i servizi read-only TASK-048 e i task/schema già presenti come fonte locale, senza modifiche Supabase.
- UI DEBUG compilata ma non validata manualmente nel Simulator; nessun manual test era richiesto esplicitamente.
- Follow-up candidate fuori scope: eventuale `ProductPrice.remoteID` persistente richiede migration SwiftData/task dedicato; TASK-049 ha usato dedupe logico come previsto.

### Handoff post-execution (Cursor → Claude)

- **Prossima fase**: REVIEW
- **Prossimo agente**: Claude / Reviewer
- **Stato task al momento dell'handoff**: ACTIVE *(non DONE; superato dalla Review APPROVED / DONE sotto)*
- **Review richiesta**:
  - verificare diff `SupabaseProductPriceApplyService.swift` per fail-closed e insert-only;
  - verificare che `OptionsView` resti tool DEBUG e che copy/CTA non suggeriscano sync cloud;
  - verificare audit zero-write e falsi positivi documentati;
  - verificare che nessuna modifica Android/Supabase/SQL sia entrata nella diff;
  - decidere se richiedere test manuale Simulator prima di chiusura utente.

---

## Review (Claude) — APPROVED / DONE

### Review tecnica severa

- **Data**: 2026-05-06
- **Autorizzazione**: override esplicito utente per eseguire REVIEW, applicare fix piccoli se necessari e marcare TASK-049 come DONE se verde.
- **File controllati**:
  - `docs/MASTER-PLAN.md`
  - `docs/TASKS/TASK-049-supabase-productprice-apply-locale-swiftdata-ios.md`
  - `iOSMerchandiseControl/SupabaseProductPriceApplyService.swift`
  - `iOSMerchandiseControl/OptionsView.swift`
  - `iOSMerchandiseControl/it.lproj/Localizable.strings`
  - `iOSMerchandiseControl/en.lproj/Localizable.strings`
  - `iOSMerchandiseControl/es.lproj/Localizable.strings`
  - `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`
  - `iOSMerchandiseControlTests/SupabaseProductPriceApplyServiceTests.swift`
  - `iOSMerchandiseControlTests/LocalizationCoverageTests.swift`
- **Diff reale verificato**: `git status --short` include correttamente file untracked TASK-049; servizio e test nuovi letti direttamente perché non presenti in `git diff`.

### Esito controlli

- **Servizio**: `prepareApplyPlan` ha overload puro su snapshot locale; fetch remoto riusa `SupabaseProductPricePreviewFetching` / `fetchProductPricesPreviewPage` read-only TASK-048 con ordine stabile `product_id/type/effective_at/id`; paginazione fail-closed su cap, duplicati `id`, errori e cancellazione; `PriceCanonicalizer` evita confronto raw `Double == Double`; NaN/infinito/negativo/non normalizzabile → invalid; `effectiveAt` usa canonicalizer unico; mapping remoto via `Product.remoteID`; duplicati `remoteID` locali → conflict; partial/truncated/sourceError/session mismatch bloccano apply.
- **Apply SwiftData**: insert-only su `ProductPrice`; nessun update/delete righe esistenti; nessuna modifica a `Product.purchasePrice` / `Product.retailPrice`; un solo `modelContext.save()` quando ci sono insert; verifica post-save reale prima del result; verification failure → errore, non success.
- **UI DEBUG**: resta in `OptionsView` nella sezione Supabase DEBUG; preview TASK-048 read-only e dry-run/apply locale TASK-049 sono separati; CTA apply abilitata solo con `plan.isApplyAllowed`; confirmation dialog dichiara SwiftData locale, nessuna scrittura Supabase, nessun update current price, insert-only storico mancante; bottoni disabilitati durante run/apply e reset su sign-out/account change/onDisappear.
- **Localizzazioni**: chiavi TASK-049 presenti in IT/EN/ES/ZH-Hans; `plutil -lint` OK; duplicate-key scan OK; copy coerente con “solo locale” e “nessuna scrittura cloud”.
- **Scope**: nessuna modifica Android; nessuna modifica Supabase SQL/migration/RLS/RPC/Edge/backend; nessun push remoto ProductPrice; nessun `record_sync_event`, `sync_events`, outbox, realtime/background; nessuna migration SwiftData.

### Check eseguiti in review

- ✅ **ESEGUITO — Build compila**: `xcodebuild build -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,id=4CE85775-BEF1-44D5-9BBF-B180EDF09D0B'` → **BUILD SUCCEEDED**.
- ✅ **ESEGUITO — Test TASK-049 + TASK-048 + localization coverage**: `xcodebuild test ... -only-testing:iOSMerchandiseControlTests/SupabaseProductPriceApplyServiceTests -only-testing:iOSMerchandiseControlTests/SupabaseProductPricePreviewServiceTests -only-testing:iOSMerchandiseControlTests/LocalizationCoverageTests/testTask049ProductPriceApplyLocalizationKeysExistInSupportedLanguages` → **TEST SUCCEEDED**.
- ✅ **ESEGUITO — Localizzazioni parseabili**: `plutil -lint` su IT/EN/ES/ZH-Hans → **OK**.
- ✅ **ESEGUITO — Duplicate localization keys**: scan su IT/EN/ES/ZH-Hans → **nessun duplicato**.
- ✅ **ESEGUITO — Nessun trailing whitespace nei file TASK-049**: `rg "[ \t]+$"` sui file toccati → **nessun match**.
- ✅ **ESEGUITO — Modifiche coerenti con planning**: REVIEW conferma slice minimo, insert-only, fail-closed, zero-write Supabase.
- ✅ **ESEGUITO — Criteri di accettazione verificati**: copertura test e review statica confermano dedupe logico, prezzo/effectiveAt canonici, mapping duplicato, unmapped, invalid type/price/date, partial/truncated/sourceError, session mismatch, doppio apply, no current price update, insert-only, post-save verification, localizzazioni.
- ✅ **ESEGUITO — Nessun warning nuovo introdotto**: build/test non mostrano warning Swift TASK-049; warning Xcode `Metadata extraction skipped. No AppIntents.framework dependency found` già noto/non legato alla diff.

### Audit zero-write Supabase

- ✅ **ESEGUITO — grep/static audit** sui file modificati per `.insert`, `.upsert`, `.update`, `.delete`, `.rpc`, `.functions`, `.storage`, `POST`, `PATCH`, `DELETE`, `record_sync_event`, `sync_events`, `outbox`.
- **Falsi positivi classificati**:
  - `context.insert(ProductPrice(...))` = insert SwiftData locale ammesso/richiesto;
  - `context.insert(...)` nei test = setup SwiftData locale;
  - `Set.insert(...)` / dictionary insert = collezioni locali;
  - stringhe localizzate/documentali `delete/update/insert` = copy preesistente o TASK-049 locale, non chiamate Supabase;
  - `preview.updateCandidates` / `result.updated` in `OptionsView` = flusso catalogo preesistente, non write Supabase TASK-049.
- **Verdetto audit**: nessuna `.insert`/`.upsert`/`.update`/`.delete`/`.rpc`/`.functions`/`.storage` Supabase reale o indiretta nei file TASK-049; nessun POST/PATCH/DELETE verso Supabase.

### Rischi residui

- UI DEBUG compilata e verificata staticamente, ma non validata manualmente nel Simulator; non era richiesta dal task/utente.
- DDL SQL reale resta fuori da questa repo iOS; nessuna modifica SQL/Supabase è stata introdotta.
- Follow-up candidate fuori scope: eventuale `ProductPrice.remoteID` persistente richiede task/migration SwiftData dedicati.

### Verdetto

**APPROVED / DONE**. TASK-049 soddisfa planning e vincoli utente dopo fix mirati; tracking allineato a DONE e progetto riportato a IDLE.

---

## Decisioni

| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|----------------------|-------------|--------|
| D49-01 | Apply vietato se `truncated` / `partial` / `sourceError` | Allow partial apply | Allineato a vincoli utente e sicurezza dati | attiva |
| D49-02 | Join solo via `Product.remoteID` | Inferenza barcode da prezzo | Evita merge silenzioso errato; coerenza TASK-040 | attiva |
| D49-03 | ~~Chiave: preferire `remoteID` su `ProductPrice` se migration possibile~~ | — | **OBSOLETA** — sostituita da **D49-08** (evitare migration TASK-049) | **OBSOLETA** |
| **D49-04** | Solo storico **`ProductPrice`**; **non** `purchasePrice`/`retailPrice` su `Product` | Allineare current price qui | Slice minimo; task futuro se serve | attiva |
| **D49-05** | `unmapped`/`invalid`/`conflict` tutti **0** per Apply | Apply con esclusioni >0 | Fail-closed; no merge silenzioso | attiva |
| **D49-06** | Piano legato a snapshot sessione; invalidare su logout/account/catalogo | Piano persistente cross-session | Correttezza mapping | attiva |
| **D49-07** | Due sezioni UI TASK-048/049; iOS nativo | Pattern Android | Chiarezza DEBUG | attiva |
| **D49-08** | **Evitare migration SwiftData** TASK-049 salvo necessità stretta; se `ProductPrice.remoteID` **esiste** → usarlo; se **non** esiste → dedupe su **prodotto** (join `Product.remoteID`, mapping **non ambiguo** — *D49-11*) + **tipo** + **`effectiveAt` canonico**; stessa chiave + **stesso prezzo canonico** (*D49-10*) → `skippedExisting`; stessa chiave + **canonico diverso** → `conflict` → Apply bloccato (P7) | Migration solo per comodità idempotenza | Riduce rischio schema; slice piccolo; `remoteID` persistito su `ProductPrice` = **task futuro** | attiva |
| **D49-09** | `applied(summary)` basato su **stato locale confermato**: dopo `save()`, readback/conteggio affidabile sul contesto; **`inserted`/`skippedExisting`/`totalConsidered` non solo ottimistici**; verifica fallita → `failed(error)`, non `applied` | Summary solo da contatori pre-save | Evita successo falso | attiva |
| **D49-10** | **No** `Double == Double` per dedupe/conflict: **`PriceCanonicalizer`** (o equivalente) **unico** dry-run+apply; preferire **`Decimal`/rounding canonico**; riuso helper prezzo esistente se presente; non canonizzabile/NaN/±inf/negativo → **invalid** | Confronto float grezzo | Evita conflict/skipped falsi; coerenza test/UI | attiva |
| **D49-11** | Più `Product` con lo stesso **`remoteID`** → mapping **ambiguo** → `mappingConflict` (assorbito in `conflictCount` o contatore dedicato) **> 0**; **vietato** «primo match»; Apply bloccato | Silently pick first | Evita storico sul prodotto sbagliato | attiva |
| **D49-12** | Apply **insert-only**: solo **insert** `ProductPrice` mancanti; **no** update/delete esistenti; stessa chiave + canonico diverso → **conflict**, non UPDATE | Merge/update storico | Slice minimo; no merge silenzioso | attiva |

---

## Fix (Claude / Reviewer)

- **Fix F49-R1 — chiave logica locale via `Product.remoteID`**: `ProductPriceApplyLogicalKey` ora usa l'UUID remoto prodotto invece del barcode come identità logica; il barcode resta solo display/sort. Questo evita duplicati se il barcode locale cambia tra dry-run e apply e allinea meglio D49-02/D49-08.
- **Fix F49-R2 — test coverage rafforzata**: aggiunti test per tipo remoto invalido, duplicati remoti stessa chiave con prezzo canonico diverso, apply dopo cambio barcode locale, e failure di verifica post-save.
- **Esito fix**: build/test/plutil/audit zero-write verdi; nessun Android/Supabase/SQL modificato; nessun current price update; nessun update/delete di `ProductPrice`.
