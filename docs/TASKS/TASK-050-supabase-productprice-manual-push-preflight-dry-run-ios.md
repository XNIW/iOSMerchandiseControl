# TASK-050: Supabase ProductPrice manual push — **preflight + dry-run iOS**, **no sync_events**

## Informazioni generali *(metadata tracking)*
- **Task ID**: TASK-050
- **Titolo**: Supabase ProductPrice manual push — preflight locale + dry-run zero-write iOS (**no sync_events/outbox**)
- **File task**: `docs/TASKS/TASK-050-supabase-productprice-manual-push-preflight-dry-run-ios.md`
- **Stato**: DONE
- **Fase attuale**: Chiusura
- **Responsabile attuale**: Codex / Reviewer+Fixer
- **Data creazione**: 2026-05-06
- **Ultimo aggiornamento**: 2026-05-06 *(REVIEW severa completata su override esplicito utente; esito APPROVED_FIXED_DIRECTLY / DONE dopo fix mirati, build/test/audit PASS e divieti zero-write/live push invariati.)*
- **Ultimo agente che ha operato**: Codex / Reviewer+Fixer

> **Regola di fase (storico Planning Freeze):** il task era **ACTIVE / PLANNING** fino a override esplicito. Override utente ricevuto il 2026-05-06: TASK-050 passa a **ACTIVE / EXECUTION** in modalità controllata/progressiva, con divieti zero-write invariati.

## Dipendenze
- **Dipende da**:
  - **TASK-048** — **DONE** — read-only `inventory_product_prices`, `SupabaseProductPricePreviewService`, ordinamento deterministico, UI DEBUG base, XCTest; **nessun** push.
  - **TASK-049** — **DONE** — pull controllato → apply locale SwiftData **insert-only**, `SupabaseProductPriceApplyService`, normalizzazione/chiave logica/PriceCanonicalizer concettuale, policy fail-closed; **nessun** push remoto. **Non riaprire TASK-049.**
  - **TASK-040/043/044** — **DONE** — `Product.remoteID`, baseline persistente, push manuale catalogo (supplier/category/product) con gate baseline/auth.
  - **TASK-038** — **DONE** — sessione Supabase; gate account per mismatch.
- **Sblocca** *(solo dopo review + override utente su task futuri, non attivare qui)*:
  - Task separato: **push live manuale** `inventory_product_prices` (upsert/insert controllato, conferma, read-back) — **esplicitamente fuori da TASK-050**.
  - Task separato: `record_sync_event` / `sync_events` / outbox / retry / realtime — **fuori da TASK-050** (allineamento Android post **TASK-071** solo come contesto).

### Nota su piani Android/Supabase allegati
- In questo ambiente **non risultano leggibili** i file `/mnt/data/MASTER-PLAN Android.md` e `/mnt/data/MASTER_PLAN Supabase.md` (path assente dal workspace).
- In **EXECUTION** il team deve usare i **clone reali** Android/Supabase dell’utente come riferimento funzionale/schema; il presente planning integra il contesto fornito dall’utente (TASK-068 PARTIAL bulk, TASK-071 `record_sync_event`/PayloadValidation).

---

## Planning Freeze / stop criteria

Dopo questa rifinitura, il documento TASK-050 si considerava **completo per planning** e **pronto per una futura EXECUTION** (solo con **override esplicito** utente).
**Annotazione 2026-05-06:** override esplicito utente ricevuto; il freeze resta storico, ma l'esecuzione è stata avviata seguendo l'ordine vincolante §13.

- **Non** aggiungere nuovi requisiti funzionali al task salvo **nuova evidenza reale** da **migration/schema** o da **codice iOS** già mergeato (es. drift TASK-048/049) — in tal caso documentare la modifica come **adeguamento vincolato**, non come scope creep.
- Evitare ulteriore **crescita testuale** del task per preferenze estetiche o ipotesi non verificate: il default resta **attendere EXECUTION** o **restare in ACTIVE / PLANNING senza implementare**.
- **Prossimi passi validi**:
  1. **Restare** in **ACTIVE / PLANNING** (nessun codice), oppure
  2. Passare a **EXECUTION** solo dopo **override esplicito** dell’utente, seguendo l’ordine **§13**.

---

## Prompt da usare in Cursor per avviare EXECUTION e risolvere l’ambiguità tra Planning e Execution

**Prompt consigliato per Cursor:**

> Avvia la fase di EXECUTION per TASK-050 secondo le regole di governance del planning. Aggiorna lo stato della task a EXECUTION e produci solo il primo passo previsto dal piano (lettura e conferma delle migration Supabase rilevanti e dei file Swift esistenti TASK-048/049, senza ancora implementare engine, orchestratore o UI). Non implementare codice oltre questo primo passo e non modificare la UI, ma assicurati che la transizione di stato sia chiara e tracciata nel file della task. Documenta nel file task lo sblocco di EXECUTION e il fatto che i passi successivi dovranno seguire l’ordine vincolante del §13 (engine/test prima, UI solo dopo), lasciando traccia dell’autorizzazione esplicita utente.

---

## 1. Obiettivo

Progettare e poi (in fase **EXECUTION**, solo dopo override esplicito) implementare la **prima slice iOS prudente** che prepara il **push remoto manuale e controllato** dello **storico prezzi locale** (`ProductPrice` SwiftData) verso Supabase **`inventory_product_prices`**, attraverso:

1. **Preflight** puramente locale (snapshot SwiftData + vincoli business) → **payload candidato remoto** (value types / DTO in-memory).
2. **Dry-run** con **zero scrittura** su Supabase (nessun `insert`/`upsert`/`update`/`delete`, nessuna RPC di scrittura).
3. **Summary testabile**: candidati (**pronti** per un push futuro, solo se dedupe remoto **completo e safe**), esclusi, **già presenti** in cloud, **bloccati**, **conflitti**, più **stato dedupe remoto** (completo vs `unsafePartialRemoteDedupe` / equivalente tipizzato).

**Non** è sync automatico, **non** è outbox, **non** è telemetria `sync_events`: è solo il **ponte documentato** dopo TASK-049 (pull→apply locale), prima di un eventuale task futuro di **push live manuale**.

---

## 2. Stato attuale iOS *(da ri-verificare integralmente in EXECUTION sul branch reale)*

Elementi già presenti nel repo iOS (lettura rapida planning; obbligo EXECUTION: file completi):

| Area | Stato rilevato / atteso |
|------|-------------------------|
| **`Product`** | `remoteID: UUID?` per join logico con `product_id` remoto; campi prezzi correnti `purchasePrice`/`retailPrice` — **TASK-050 non li modifica**. |
| **`ProductPrice`** | Storico locale: `type`, `price`, `effectiveAt` `Date`, `source`, `note`, `createdAt`, relazione `product`. **Nessun `remoteID` sul modello** nel sorgente attuale — idempotenza push andrà progettata su chiave logica + eventuale fetch read-only remoto (*vedi Design*). |
| **`SupabaseProductPricePreviewService`** | Preview read-only a **cap** TASK-048; ordine `product_id/type/effective_at/id`; **non** contratto per «full mirror» né per push. |
| **`SupabaseProductPriceApplyService`** | Flusso **cloud → locale**; pattern `ProductPriceApplyLocalSnapshot`, summary, blocchi `partial`/`truncated`/conflitti, normalizzazione condivisa con pull — **riuso concettuale** per specchiare **locale → candidato remoto** senza copiare apply inverso alla cieca. |
| **Baseline TASK-043** | Reader/writer run validi; integrazione preflight push catalogo (TASK-044) — TASK-050 deve **riallineare** gate *stale/missing/partial* al nuovo perimetro prezzi. |
| **Auth** | Sessione Supabase; mismatch account / assenza sessione = **fail-closed** (come pattern manual push). |
| **Test** | `SupabaseProductPriceApplyServiceTests`, test TASK-048 preview — regressione obbligatoria in EXECUTION. |

---

## 3. Riferimento Android usato *(solo funzionale — cosa NON portare ora)*

- **Foundation storico prezzi cloud** e **E2E prezzo storico**: confermano che il dominio remoto è **`inventory_product_prices`** con vincoli di unicità per tenant e append-only lato client.
- **Policy «current price summary-first»**: utile per **non** confondere snapshot `inventory_products` con righe storiche — TASK-050 **non** aggiorna prezzi correnti su `Product` né sul cloud.
- **`sync_events` / outbox / retry**: Android è più avanti; **TASK-050 non introduce** nulla di equivalente. **TASK-068** (PARTIAL su validazione live bulk) e **TASK-071** (mismatch `record_sync_event` / PayloadValidation) motivano il **divieto** di toccare RPC/sync in questa slice.

*Nessun file Kotlin modificato; nessuna dipendenza di build da Android.*

---

## 4. Riferimento Supabase usato *(schema reale — lettura migration locale, nessuna nuova migration in TASK-050)*

Fonte primaria nel progetto documentale iOS: `docs/SUPABASE/TASK-033-schema-audit.md` e clone **`MerchandiseControlSupabase`** (path tipico sotto macchina dev, es. `.../MerchandiseControlSupabase/supabase/migrations/`).

Tabella **`inventory_product_prices`** (sintesi audit):
- Colonne rilevanti: `id` (uuid PK, spesso generato client lato insert), `owner_user_id`, `product_id` → `inventory_products`, `type` CHECK `PURCHASE`/`RETAIL`, `price` float8, `effective_at` **text**, `created_at` **text**, `source`, `note`.
- **UNIQUE** `(owner_user_id, product_id, type, effective_at)` — implicazioni: il dry-run deve calcolare la **stessa chiave logica** che il DB applicherebbe (normalizzazione `effective_at` stringa canonica vs `Date` locale).
- **RLS** owner-scoped; **DELETE** tipicamente revocato su authenticated (migrazione restrict) — modello append-only lato client.
- **Obbligo EXECUTION**: rileggere il file migration effettivo (`20260417200000_task016_inventory_product_prices.sql` + successive che toccano prices) **prima** di codificare mapping; **TASK-050 non aggiunge** SQL/RLS/RPC.

---

## 5. Differenze trovate *(iOS vs Android vs Supabase — implicazioni TASK-050)*

| Tema | Supabase / Android | iOS attuale | Implicazione TASK-050 |
|------|-------------------|-------------|------------------------|
| Chiave upload | `product_id` uuid + `type` + `effective_at` text canonico | `ProductPrice` lega `Product`; `Product.remoteID` opzionale | Senza `remoteID` → **blocco** prodotto (non inferire solo da barcode verso cloud). |
| Timestamps | text remoto | `Date` locale | Un solo **serializzatore** text per payload candidato + confronto con righe remote in lettura. |
| Prezzo | float8 | `Double` | Riuso **PriceCanonicalizer** / `Decimal` come TASK-049 — **no** uguaglianza grezza `Double`. |
| Idempotenza remota | unique DB | Storico locale senza `ProductPrice.remoteID` | Dry-run: dedupe vs righe lette da **SELECT batchato** su `inventory_product_prices` *(vedi §8.3 — D50-01)*; **vietato** fallback «locale-only sicuro». |
| Sync metadata | outbox + `sync_events` | assente | **Fuori scope** — nessun `record_sync_event`. |
| Baseline catalogo | usata per push supplier/product | esiste TASK-043 | Push prezzi deve essere **baseline-gated** coerente con TASK-044 (assente/stale/partial → blocco). |

---

## 6. Scope *(TASK-050)*

1. **Lettura codice** (in EXECUTION; lista minima):
   - `Models.swift` — `Product`, `ProductPrice`
   - `SupabaseProductPricePreviewService.swift`
   - `SupabaseProductPriceApplyService.swift` (+ normalizer/DTO condivisi)
   - `OptionsView.swift` — sezione DEBUG Supabase
   - Servizi esistenti: `SupabaseInventoryService`, baseline reader/writer, eventuali gate manual push catalogo
   - Test: `SupabaseProductPriceApplyServiceTests`, test TASK-048, preflight/dry-run catalogo se riusabili come pattern
2. **Engine preflight + dry-run** (logica pura dove possibile):
   - Input: snapshot locale serializzabile (`Product` con `remoteID`, lista `ProductPrice` per prodotto, user/session id per gate).
   - Output: struttura **Sendable** con bucket: `localDuplicateSameKey`, `localConflictSameKeyDifferentPrice`, `candidates` *(solo se dedupe remoto **completo e non** `unsafePartialRemoteDedupe` e pipeline locale §8.2a OK)*, `excludedLocal`, `blockedNoRemoteID`, `blockedNoAuth`, `blockedAccountMismatch`, `blockedBaselineMissing`, `blockedBaselineStale`, `blockedBaselinePartial`, `alreadyPresentRemote`, `conflictSameKeyDifferentPrice` *(remoto)*, più **stato esplicito dedupe remoto** (es. `unsafePartialRemoteDedupe` / completed).
3. **Mapping** `ProductPrice` locale → riga candidata `inventory_product_prices`:
   - `owner_user_id` — **§8.4b** *(payload logico; sessione; nessuna write)*
   - `product_id` = `Product.remoteID`
   - `type` = `PURCHASE`/`RETAIL` uppercase coerente con CHECK
   - `price`, `effective_at` text canonico, `created_at` text (timezone / formato **stabile**: **§8.4**, **CA50-21**), `source`/`note` opzionali — **sanitizzazione deterministica** **§8.4c** (**CA50-23**)
4. **Lettura remota consentita**: solo **SELECT read-only** su `inventory_product_prices` secondo **D50-01** (§8.3–§8.3.2): filtro **`product_id`** candidati +, se schema/coerenza RLS lo consentono (**§8.3 / §8.4b**), **`owner_user_id == session.user.id`**; **mai** row-by-row; **batch** **100** `product_id`; **budget** lettura **§8.3.2**; **nessuna** write.
5. **UI**: solo **`OptionsView` DEBUG** — specifica §9 (**card dedicata**, CTA «Calcola anteprima» / «Aggiorna», chip summary, disclosure con **max 20** esempi per bucket); **vietati** pulsanti/live copy «Push», «Invia», «Sincronizza» e wording equivalente ambiguo.
6. **Localizzazioni**: **IT / EN / ES / zh-Hans** per stringhe nuove (inclusi titoli chip, stati dedupe, etichette Accessibilità).
7. **XCTest** *(in EXECUTION, non ora)*: test puri su engine + ViewModel (se introdotto) secondo §10; **nessun** test aggiunto in questa fase PLANNING.

---

## 7. Out of scope esplicito *(vietato TASK-050)*

- Qualsiasi **scrittura Supabase reale**: `insert`/`upsert`/`update`/`delete` su `inventory_product_prices` o altre tabelle.
- **`record_sync_event`**, **`sync_events`**, **outbox**, watermark telemetry.
- **Realtime**, **background sync**, retry automatico.
- **Nuove migration SQL**, **RLS**, **RPC**, **Edge Functions**, **backend**.
- Modifica **Android**.
- **`Product.purchasePrice` / `Product.retailPrice`**: non aggiornare.
- **Cancellare o modificare** righe **`ProductPrice`** esistenti in SwiftData.
- **`service_role`** / segreti nel client.
- Trasformare il task in **sync automatico** o push live — il push confermato è **task futuro**.

### 7.1 Mutazioni vietate durante il solo dry-run *(rafforzamento — review obbligatoria post-EXECUTION)*

Il dry-run, per definizione TASK-050, **non effetta alcun effetto collaterale**:
- **Nessuna** mutazione **SwiftData** (nessun insert/update/delete su `Product`, `ProductPrice`, `Supplier`, `ProductCategory`, `HistoryEntry`, modelli baseline TASK-043, né altri `@Model`).
- **Nessun** aggiornamento a **`Product.purchasePrice` / `Product.retailPrice`**.
- **Nessuna** scrittura o riscrittura **baseline** (Run/Record) né hook che la marcano stale/non valida.
- **Nessuna** creazione/modifica **`HistoryEntry`** o campi **`syncStatus`** / stati sync locali.
- L’unico effetto ammesso è stato **volatile in RAM** (+ eventuale cache UI) del risultato dry-run — **mai** persistente come «piano push» salvo diverso task futuro.

---

## 8. Design tecnico

### 8.1 Componenti suggeriti *(nomi indicativi, solo a EXECUTION autorizzata)*
- **Engine dry-run / preflight**: tipo **pure** / testabile — input: snapshot locale (+ righe remote per dedupe già accumulate o fornite mocked in test); output: summary tipizzato incluso stato dedupe remoto.
- **Orchestratore** (thin, **fuori dalla View**): legge SwiftData snapshot read-only → invoca SELECT batchati → chiama engine; **MainActor** dove serve; **nessun** lavoro pesante (JOIN vasti, sort di migliaia di righe per la UI) nella `View`.

### 8.2 Gate obbligatori *(fail-closed)*
Ordine suggerito (affine TASK-041/044/049):
1. **Sessione assente** → `blockedNoAuth`.
2. **Account mismatch** (user id sessione ≠ baseline linked / policy esistente) → `blockedAccountMismatch`.
3. **Baseline assente / non valida / stale / partial** → bucket dedicati *(riusare reader TASK-043; non duplicare logica in modo incoerente)*.
4. **`Product.remoteID == nil`** per il `Product` legato al `ProductPrice` → riga **bloccata** (non inviare candidato).
5. Normalizzazione **tipo** / **`effectiveAt`** / **prezzo**: se invalido → `excludedInvalidLocal` o blocco aggregato *(policy numerica §8.4a; **CA50-19**)*.

### 8.2a Fase locale preliminare — duplicati / conflitti **prima** del dedupe remoto

Ordine elaborazione obbligatorio: **normalizzazione locale** → **classificazione duplicati locali** → solo dopo righe residue idonee → **fetch remoto batch** §8.3 → join dedupe remoto.

- **Chiave logica locale**: `(productRemoteID`, `tipo_canonico`, `effective_at_testo_canonico)` dove `productRemoteID` = `Product.remoteID` UUID; **`tipo`** e **`effective_at`** dai soli percorsi canonici TASK-049 / **§8.4**.
- **Due o più** `ProductPrice` locali con **stessa chiave** e **stesso prezzo canonico** → bucket **`localDuplicateSameKey`** (nome equivalente tipizzato ammesso). **Non** promuovere più di **una** rappresentativa a candidato remoto finché la policy sulla riga «vincente» non è definita in EXECUTION (es. scegliere `createdAt` min/max documentato — **stabile**, non casuale). Le altre rimangono duplicate locali nel summary / disclosure.
- **Due o più** `ProductPrice` locali con **stessa chiave** ma **prezzo canonico diverso** → bucket **`localConflictSameKeyDifferentPrice`**. Queste righe **non** sono candidate remote sicure → **non** proseguire con dedupe remoto **per tale chiave** come «pronta» (blocco / esclusione aggregata coerente con fail-closed).
- **Non** affidarsi al vincolo **UNIQUE** Supabase futuro come unica forma di discovery: i duplicati/conflitti locali devono emergere **nel dry-run**.
- Test pianificati: **T50-21**, **T50-22**; conformità review **CA50-14**.

### 8.3 Decisione D50-01 — Dedupe remoto *(default obbligatorio)*

| Regola | Contenuto |
|--------|-----------|
| **Modalità** | **Solo** SELECT read-only su **`inventory_product_prices`**. |
| **Filtro chiavi** | Risultati ristretti ai **`product_id`** che compaiono nei **Prodotti locali** che hanno almeno un `ProductPrice` considerato nel dry-run (dopo gate §8.2 e pipeline §8.2a). |
| **Filtro owner** | Se migration/schema confermano **`owner_user_id`** queryabile e coerente con **RLS** (nessuna contraddizione, nessuna ridondanza che rompa la query pianificata), la SELECT deve includere **`.eq(owner_user_id, sessionUserUUID)`**. **RLS resta primaria**; il filtro esplicito migliora **performance** e **chiarezza** — **vietato** dedupe su righe di **account diverso**. Se policy/schema rendono il filtro **impossibile o inutile** (documentabile), annotare motivo in **Execution/Review** (**CA50-22**, **T50-31**). **Mismatch account** → **blocked** prima di qualsiasi SELECT (**§8.2**). |
| **Batch** | Una o più query con **insieme di `product_id` per richiesta**, **mai** una SELECT per singola riga prezzo né N query lineari sul numero di righe `ProductPrice`. |
| **Batch size** | **100** UUID `product_id` per batch (**default**). Smussare **solo verso il basso** se vincoli reali URL/query length o client Supabase lo richiedono — documentare in review il valore effettivo. |
| **Completamento** | Tutti i batch devono avere esito determinato (**success** con dataset atteso **oppure** errore/per partial gestito). Se **fallimento rete**, **timeout**, **paginazione parziale non risolta**, superamento **budget righe**/tempo di sicurezza, **o** errore PostgREST/RLS: impostare lo stato **`unsafePartialRemoteDedupe`** (nome equivalente ammesso se tipizzato) sul risultato. |
| **Semantica `unsafePartialRemoteDedupe`** | **Zero** interpretazione dei candidati come «sicuri» per un push futuro: i conteggi **«pronti»** devono essere **azzerati** o mascherati come **non attendibili**; la UI deve mostrare stato dedupe remoto **non completo / non sicuro**. |
| **Fallback** | **Vietato** qualsiasi fallback **silenzioso** «solo locale» etichettato come sicuro. Se non si leggono le righe remote necessarie alla dedupe, il dry-run resta **non safe**. |

#### 8.3.1 Paginazione interna alla SELECT *(per batch `product_id`)*

- Un batch **100 `product_id`** **non implica** risposta unica sempre completa: un singolo `product_id` può avere **molte** righe in `inventory_product_prices`; la risposta può eccedere i limiti **PostgREST** / **`max-rows`** client / memoria pianificata.
- **Obbligatorio**: per ogni batch, dopo filtro `.in(product_id, batch)`, applicare **`order`** deterministico **`product_id, type, effective_at, id`** (allineamento TASK-048/049) poi **`range` / paging** ripetuto fino a coprire tutte le righe per quel batch **oppure** fino a errore/budget.
- Se una **pagina interna** fallisce o manca prima di aver letto **tutto** previsto senza errore dichiarabile → **`unsafePartialRemoteDedupe`** (non safe).
- **Vietato** assumere «100 product_id ⇒ fetch completo». Test pianificati: **T50-23**, **T50-24**; **CA50-15**.

#### 8.3.2 Budget lettura remota *(anti loop / dataset anomali)*

- Oltre a **batch 100 `product_id`** e **paginazione interna** §8.3.1, definire un **budget massimo** configurabile (EXECUTION dopo lettura limiti client/PostgREST): es. **cap pagine interne per batch**, **cap righe totali remote** lette nell’intero dry-run prima di fermarsi.
- Se il budget viene **superato** prima di dichiarare completo il dedupe previsto → **`unsafePartialRemoteDedupe`** — conteggi **«Pronte»** **non** attendibili (**CA50-24**, **CA50-10**, **T50-33**).
- Il **valore numerico** preciso non è fisso nel planning: va **documentato nella Review** dopo scelta EXECUTION ragionata.

Deduzione logica in RAM dopo fetch:
- **Chiave dedupe/remoto**: **`(owner_user_id, product_id, tipo normalizzato, effective_at_testo_canonico)`** quando il contesto richiede colonna tenant; altrimenti almeno `(product_id, tipo, effective_at canonico)` sotto dominio SELECT già owner-scoped — allineamento **UNIQUE** Supabase §4 e **§8.10**.
- **Strutture**: `Set` / `Dictionary` sulla chiave logica per JOIN locale↔remoto in **O(1)** amortizzato; **no** scansione quadratica sulle migliaia di righe dove evitabile.
- **Già presente**: stessa chiave + **prezzo canonico uguale** (§8.4) → bucket **già presenti** (`alreadyPresentRemote`).
- **Conflitto**: stessa chiave + prezzo canonico diverso → **conflitto** (`conflictSameKeyDifferentPrice`).

### 8.4 Canonicalizzazione `effective_at` e prezzo *(allineamento TASK-049 / DDL)*

- **`ProductPrice.effectiveAt`** in Swift è **`Date`**; su Supabase **`effective_at`** è **text**. In **EXECUTION** verificare **come TASK-049** converte/remappa (UTC assoluto vs convenzione storico Android/doc audit, `Calendar`/`TimeZone` impliciti nei test).
- **Vietati** formatter **impliciti legati alla sola lingua/locale dell’impostazioni UI device** (`DateFormatter()` default, `locale: .current`) per produrre la **stringa canonica di chiave** remota — la chiave deve restare **stabile** ai cambi lingua/calendario UI.
- Distinguere con nettezza nel codice pianificato:
  - **(A)** *formato canonico per chiave* (`effective_at_testo_canonico` per UNIQUE/confronto/remoto/PK logica §8.10);
  - **(B)** *formato solo visualizzazione* nell’UI (può essere user-friendly/localizzabile **senza** alimentare la chiave né i test assertion sulla chiave).
- **`effective_at`**: un **solo percorso** per produrre **(A)**, **condiviso** con TASK-049: Normalizer/formatters esistenti o helper unico — **vietate** due implementazioni divergenti tra pull e dry-run push.
- **Fonte finale del formato stringa**: file **migration** reale **`effective_at`** (repo locale) — **CA50-21**.
- **Checklist Review anti-drift timezone**: leggere migrazione + TASK-049 + una fixture fisso ora nota (≥2 `TimeZone` simulati in test se previsto dall’infra test) — **non** affidarsi solo a «test passano sul Simulator corrente».
- **Prezzo**: solo **`PriceCanonicalizer`** / **`Decimal`** route TASK-049 — **vietato** `Double ==` grezzo.

#### Identità timezone — non confondere

| Uso | Requisito |
|-----|-----------|
| Chiave logica candidato/dedupe | Stringa (**A**) invariante lingua/timezone UI |
| Label disclosure / messaggi data | (**B**) localizzabile; **non** usata come fonte chiave |

Test pianificati: **T50-30**.

#### 8.4a Policy valori numerici — `NaN`, infinito, negativo, zero *(solo planning; verifica EXECUTION)*

- **NON** decidere in PLANNING se **`price == 0`** sia business-valido senza DDL: in **EXECUTION** rileggere **migration effettiva** `inventory_product_prices` (CHECK/not null/`float8` commenti) **e** allinearsi alla logica TASK-049 esistente (invalid rows, `invalidPrice`).
- **`NaN`**, **`infinity`**, valori non serializzabili / non canonizzabili dall’canonicalizer → **sempre** escluso o gate aggregato (**invalid** / blocco) — test **dedicati**.
- **`Prezzo negativo`** → conforme DDL: se PostgreSQL/consistenza progetto **non** lo ammettono → **`excludedInvalidLocal`** o equivalente; **non** passare candidato remoto falsificato.
- **`Prezzo zero`** → decidere solo **dopo** verifica migration + parity TASK-049:
  - se lo **schema lo ammette** ma UX/business sconsiglia, documentare **`warning`** discreto (**non** blocco silenzioso arbitrario in PLANNING);
  - se CHECK/migration vietano zero, trattare come invalid documentato.
- Test pianificati separati (non accorpabile senza documentazione): granularità tipo **zero / negativo / NaN-inf** (**T50-26**, estensioni a **T50-10** in EXECUTION se opportuno ma **preferenza nuova riga T50**). **CA50-19**.

#### 8.4b `owner_user_id` nel payload logico *(nessuna write)*

- Prima di EXECUTION: dalla **migration reale**, verificare se `owner_user_id` è **sempre** richiesto dal client all’INSERT, se esiste **default/gen_random**, trigger, o inferenza **`auth.uid()`** via RLS/policy.
- Nel dry-run il valore **può** essere **derivato dalla sessione** Supabase (**UUID** auth) nel modello solo in-memory, **mai** persisted; **zero** INSERT.
- Il mapping (`owner_user_id` + FK `product_id` + UNIQUE key) deve essere il **predicato** fedele di quel che un futuro task di push vorrebbe inviare: se DDL/policy restano **ambigue** dopo lettura migrazioni, conservare comportamento **safe** (dry-run conservativo / messaggio sintetico) e documentare gap in **EXECUTION/Review**, con stato tipo **«mapping insert remoto non confermato — stop push futuro»** e disclosure UI breve (**CA50-18**, messaggio genericizzato, non **errore tecnico** grezzo).
- SELECT dedupe (**§8.3**): ove applicabile (**CA50-22**, **T50-31**), filtrare sempre anche per **`owner_user_id`** della sessione; **non deduplicare** su righe attribuibili a **altro proprietario**.

#### 8.4c Sanitizzazione `source` / `note` *(mapping candidato)*

- **Trim** deterministico degli spazi; **stringa vuota dopo trim** → **`nil`/assente** nel modello payload candidato (equivalente null remoto dove previsto da schema/client).
- **Nessuna** leaking voluto in **sample UI** §9: truncation/masking coerenti con TASK-049; **nessun campo sensibile espanso**.
- **Limiti DDL**: EXECUTION deve verificare lunghezza/CHECK/note su migrazioni; allinearsi a parity **TASK-049**/Android dove documentato.
- In **assenza di limite rigido DB**, prevedere comunque tetto conservativo solo per **campione Disclosure** DEBUG (ellipsis) così da non inundare Voce/accessibilità (**T50-32**, **CA50-23**).
- Test pianificati separati: `source`/`note` vuoti dopo trim; stringhe lunghissime; spazi bordo.

### 8.5 Performance guardrails

- Nessuna SELECT **per riga** `ProductPrice`; solo batch per **insieme `product_id`** (§8.3) **+ filtro owner ove §8.3** **+ budget §8.3.2**.
- Dedupe/conflict risolti in **memoria** con `Set`/`Dictionary` su chiave canonica §8.3–8.4.
- La **UI** mostra solo **campione limitato** (§9); il modello risultato completo resta in struttura **testabile/ad uso ViewModel**, non **`ForEach`** su migliaia di elementi nella View.
- **View**: sottile; **async**/`Task` orchestrato da observable/VM/service — **vietato** calcolo pesante nella body della View.

### 8.6 Invalidazione risultato dry-run *(sessione / baseline)*

- **Logout**, **cambio account**, **`unsafePartialRemoteDedupe`**, **`blockedAccountMismatch`**, **`blockedNoAuth`**: azzerare risultato dry-run precedente **o** marcarlo **`stale`/invalid con messaggio chiaro** — **mai** riusare summary calcolati con altro utente come ancora validi.
- **Cambio baseline** dopo il calcolo *(nuova baseline valid salvata / refresh)*: il risultato dry-run deve essere **invalidato automaticamente** o marcato stale finché l’utente non ricalcola — **vietato** presentare chip «pronte» obsolete senza ricalcolo.
- Coerenza con TASK-048/049: uscendo da `OptionsView` o perdendo sessione, comportamento volatile coerente con le card storiche *(nessun salvataggio del piano push)*.

### 8.7 Relazione con TASK-049
- Condividere **Normalizer + PriceCanonicalizer** come §8.4; garantire equivalenza chiavi pull vs dry-run push.
- Nessuna interferenza con apply TASK-049: stati/UI separati o VM dedicate.

### 8.8 Privacy / logging
- Sample UI limitato; **vietato** in **Release** logging completo di barcode o prezzi; stringhe TASK-048/049.

### 8.9 Ordinamento deterministico *(bucket risultato + UI sample)*

- Ogni lista/bucket nella struttura risultato (engine) deve essere **ordinata stabile** prima di XCTest/UI: ordine suggerito **`productDisplay` / barcode** (o barcode + `productName` secondario), poi **`type` canonico**, poi **`effective_at` canonico**, poi **`createdAt` locale** o identificatore locale stabile (es. ordinamento deterministico sugli UUID string se nient’altro).
- Campioni UI **≤ 20** (**§9.5**) = **primi 20 elementi dopo** questo sort — **vietato** usare ordine iterazione SwiftData, `Set` non ordinato o hash casuale.
- **CA50-16**; test **T50-27**.

### 8.10 Identità candidato dry-run *(nessun UUID remoto sintetico casuale)*

- Il dry-run **non** deve **`UUID()` random**/`gen_random`-simulazioni client per fingere **`id`** PK remota di righe ancora da inserire.
- L’identità stabile dell’**elemento** «candidato push futuro» nel piano è la **chiave logica naturale**: **`(owner_user_id, product_id, type canonico, effective_at canonico)`** — coerente con il **UNIQUE** Supabase §4.
- L’ **`id`** UUID remoto (**PK riga**) per righe nuove è **solo** responsabilità del **task futuro di push live** (generazione server-side o client conforme DDL); nel dry-run: **omit** o marcatura esplicita **«id: da allocare nel push futuro»** senza valorizzazioni casuali nei test/UI.
- **XCTest/assert**: predicati su chiave logica **e** contenuti campo, **mai** dipendenti da UUID random generati a runtime (**T50-29**, **CA50-20**) — elimina snapshot/diff/UI instabile.

### 8.11 Anti-overengineering e riuso *(EXECUTION)*

- **Preferire riuso** di helper, normalizer, DTO e percorsi canonici già presenti in **TASK-048** / **TASK-049** (preview, apply, `PriceCanonicalizer`, chiavi `effective_at`, gate baseline/sessione ove applicabile) — **vietata** duplicazione parallela di **PriceCanonicalizer**, **date formatter per chiave (A)**, o **logica baseline** solo per «comodità» nel dry-run.
- **Non** introdurre architettura ampia per un dry-run: perimetro **massimo** pianificato = **1** nuovo modulo **engine/service** dedicato al dry-run +, se strettamente necessario, **1** piccolo **ViewModel** o **state holder** sottile; il resto = composizione di tipi esistenti.
- Ogni funzione che può restare **pura e testabile** (normalizzazione, dedupe, mapping bucket) **non** vive nella `View` — **§8.1** resta vincolante.

---

## 9. UI/UX DEBUG *(solo OptionsView)*

### 9.1 Posizione e struttura
- Area **DEBUG Supabase** esistente in `OptionsView`: **nuova card / sezione separata**, **dopo** la card preview storico TASK-048 **e** dopo la sezione pull/apply TASK-049 (ordine: lettura cloud → apply locale → **questa** anteprima push).
- Stile **nativo SwiftUI**: `Form` / `List` / `Section`, spaziatura e gerarchia **Apple-like**, coerente con le altre card DEBUG già presenti.

### 9.2 Titolo, badge, copy *(terminologia vincolata)*

Usare sempre lessico **«Anteprima»** / **«Dry-run»** / **«Solo anteprima»** nei copy utente dove applicabile alla card §9 *(non titoli tecnici ingestibili)*.

| Lingua | Esempi obbligatori / equivalenti |
|--------|----------------------------------|
| **Italiano** | «Solo anteprima», «Non scrive su Supabase», CTA «Calcola anteprima» |
| **English** | **«Preview only»**, **«Does not write to Supabase»** |
| **Español** | **«Solo vista previa»**, **«No escribe en Supabase»** |
| **简体中文 (zh-Hans)** | **「仅预览」**, **「不写入 Supabase」** (equivalente chiaro dell’intent, non letterale errata) |

**Vietato** in stringhe UI TASK-050: *Sync*, *Sincronizza*, *Invia*, *Push*, *Carica*, *Upload* (e traduzioni che evochino upload/sync live). **CA50-11** / **T50-28**.

- **Titolo card** *(localizzabile)* es.: **«Dry-run push storico prezzi»** (o equivalenza idiomatica **senza** verbi vietati sopra).
- **Badge sempre visibile** sulla card o accanto al titolo: **«Solo anteprima»** (o traduzione tabella).
- **Sottotesto obbligatorio** visibile: **«Non scrive su Supabase»** (o traduzione tabella).

### 9.3 CTA *(ammissibili vs vietate)*

| Tipo | Wording suggerito (IT; tradurre) | Ruolo |
|------|----------------------------------|--------|
| **Primaria** | **«Calcola anteprima»** | Avvia/arriva alla fine dry-run orchestrato §8. |
| **Secondaria opz.** | **«Aggiorna»** | Alias di ricalcolo (stesso percorso, reset risultati stale §8.6). |
| **Vietato** | «Push», «Invia», «Sincronizza», **«Sync»**, **«Upload»**, **«Carica»**, «Aggiorna il cloud», ecc. | **Non** implementare né come bottone né come link; **no** CTA disabled che suggerisce feature imminente (solo copy task futuro **fuori TASK-050** se assolutamente necessario — preferenza: assenza totale). |

### 9.4 Summary compatta *(chip / conteggi)*
Visualizzazione riga prima dei disclosure (valori tipizzati sottostanti, **non** stringhe localizzate come unica verità nei test):

- **Pronte** *(candidates safe — solo se **non** `unsafePartialRemoteDedupe` e **senza** conflitto/duplicate locali non risolti che bloccano la chiave §8.2a)*
- **Già presenti**
- **Dup. locali** / **Conflitti locali** *(bucket §8.2a; disclosure §9.5)*
- **Bloccate** *(aggregato no remoteID/auth/baseline/etc. con possibile breakdown in disclosure)*
- **Conflitti (remote)** *(stessa chiave remota, prezzo diverso)*
- **Stato dedupe remoto** *(es.: Completato / Non completato — non sicuro)*

Se `unsafePartialRemoteDedupe`: stato dedupe remoto deve essere **chiaramente errore/avviso**, e i conteggi «pronte» **non attendibili** (CA50-10).

### 9.5 Disclosure ed esempi
- **`DisclosureGroup`** (o equivalente nativo) per bucket (blocchi, conflitti, ecc.).
- **Massimo 20 righe campione per bucket** in UI (+ indicazione tipo «mostrando N di M» se M > 20).
- **VoiceOver**: `accessibilityLabel` / `hint` obbligatori su badge «Solo anteprima», CTA primaria, e sulla riga stato dedupe remoto.

### 9.6 Dynamic Type
- Testi summary e footer devono **re-layout** correttamente sotto Dynamic Type medio-grande (senza truncation critica degli stati di sicurezza); preferire `lineLimit(nil)` dove appropriato su spiegazioni.

### 9.7 Stati UX
- **Empty state**: quando non ci sono `ProductPrice` locali eleggibili (o tutti fuori dopo filtri minimi): messaggio chiaro *«Nessuno storico locale da anteprima»* (tradotto).
- **Error/auth/baseline/sub remoteID**: messaggi distinti, coerenti con VM (§8.2) — no schermata muta.
- **Loading**: `ProgressView` o placeholder **compatto**, non-blocking dell’intera `OptionsView`; coerenza con TASK-048/049.
- Distinguere in UI stato **«Calcolo anteprima in corso»** vs **«Risultato non più attuale (ricalcolare)»** (*stale* §8.6) vs esito errore recuperabile (**§9.8**).

### 9.8 Messaggi errore *(non tecnici grezzi)*

- **Non** mostrare all’utente stringhe PostgREST/HTTP/UUID grezze dai layer di networking.
- Superficie **breve**, **localizzata**, **privacy-safe**: es. problema di connessione, permesso, sessione non valida (**CA50-18**, **T50-28**).
- Dettagli tecnici eventualmente solo in **`#if DEBUG`** / copy secondario sintetico, **senza** dati sensibili (JWT, query complete, elenchi prezzi).
- Nessun **`print`**/`os_log` in Release con barcode o prezzo completo (**§8.8**).

### 9.9 Lifecycle async, cancel, race *(VM/UI)*

- Ogni «Calcola anteprima» / «Aggiorna» deve usare **`Task` cancellabile** o pattern **generation token / run-ID** tale che:
  - uscendo da **`OptionsView`**, **logout**, **cambio account**, o nuovo tap **durante fetch** precedente → il risultato del **task più vecchio** viene **scartato** e **non** aggiorna la UI pubblicata.
  - risultati **più vecchi** non devono **sovrascrivere** risultati **più nuovi** dopo **«Aggiorna»** (**T50-25**, **CA50-17**).
- Se un run viene invalidato mentre era in-flight, preferire stato **silent discard** + eventuale **stale badge** chiaro (**non** mescolare conteggi di due sessioni logiche).

### 9.10 Libertà di polish estetico *(solo EXECUTION futura Codex/Cursor)*

- In **EXECUTION** l’implementatore può **abbellire** liberamente in stile **iOS nativo**, ma la superficie deve restare **semplice**: preferire **una card compatta** con **summary in evidenza** + **`DisclosureGroup`** per i bucket — **no** tabelle dense, griglie, pannelli tecnici o layout **Android-like**.
- Coerenza con le **card Supabase** già in `OptionsView`: tra layout equivalenti, scegliere la variante **più leggibile** e **Apple-like** (`Section`, `Label`, `Badge`/pill, spaziatura tipica; **Dynamic Type**, **VoiceOver** §9).
- **Prima vista**: **pochi** dettagli tecnici; dettagli operativi o campioni **solo** dentro disclosure **DEBUG**, **privacy-safe** (troncamento/mascheramento §8.8, §8.4c).
- **Evitare** griglie dense / «admin panel» sulla stessa superficie.
- Permanenti i vincoli: **solo anteprima**, **CA50-11**/§9.2/9.3, **nessuna** CTA/live disabilitata che sembri prossima all’uso, **preferire soluzione più semplice** se alternative equivalenti (**CA50-25**, **T50-34**).

---

## 10. Matrice test *(pianificata — esecuzione in EXECUTION)*

| ID | Descrizione |
|----|-------------|
| T50-01 | Engine: prodotto senza `remoteID` → tutte le righe prezzo figlie → `blockedNoRemoteID` |
| T50-02 | Engine: baseline `missing` → dry-run blocca con `blockedBaselineMissing` |
| T50-03 | Engine: baseline `stale` / `partial` → bucket attesi (mock reader) |
| T50-04 | Engine: auth assente → `blockedNoAuth` |
| T50-05 | Engine: account mismatch → `blockedAccountMismatch` |
| T50-06 | Mapping: `effectiveAt` locale → stringa canonica uguale a vincolo DB atteso |
| T50-07 | Dedupe: remoto vuoto → tutti i validi sono `candidates` |
| T50-08 | Dedupe: remoto con stessa chiave + stesso prezzo canonico → `alreadyPresentRemote` |
| T50-09 | Conflitto: stessa chiave + prezzo diverso → `conflictSameKeyDifferentPrice` |
| T50-10 | Prezzo non canonizzabile / NaN / negativo → escluso o blocco globale *(policy unica in codice)* |
| T50-11 | Regressione: suite **TASK-048** invariata |
| T50-12 | Regressione: suite **TASK-049** invariata |
| T50-13 | `plutil` su **IT/EN/ES/zh-Hans** per nuove chiavi |
| T50-14 | Grep audit sul **diff TASK-050**: **zero** `.insert`/`.upsert`/`.update`/`.delete`/`.rpc` **nel codice nuovo** legato al dry-run push prezzi (estensione CA50-03 / CA50-09) |
| T50-15 | Dedupe remoto **fallito** / **parziale** / `unsafePartialRemoteDedupe` → **nessun** candidato «safe»; summary coerente CA50-10 |
| T50-16 | Dopo dry-run: **snapshot SwiftData** (conteggi / hash modello o fetch controllo) **invariato** — nessun insert/update/delete |
| T50-17 | **Logout** o **cambio account** → risultato dry-run precedente **cancellato** o **stale**; UI non mostra conteggi validi pre-switch |
| T50-18 | Dataset grande: verificare **solo batch** `product_id` (chunk 100 o documentato), **zero** chiamate di rete lineari sulle righe `ProductPrice` |
| T50-19 | UI: per ogni bucket disclosure, **≤ 20** righe campione con M > 20 totali |
| T50-20 | Nessuna modifica **`HistoryEntry`**, **`syncStatus`**, né **baseline** (record TASK-043) dopo dry-run — test di non-regressione o snapshot |
| T50-21 | **Duplicati locali**: stessa chiave logica + stesso prezzo canonico → `localDuplicateSameKey`; una sola linea-guida può essere candidata remota dopo policy EXECUTION (**CA50-14**) |
| T50-22 | **Conflitto locale**: stessa chiave + **prezzo canonico diverso** → `localConflictSameKeyDifferentPrice`; chiave non «pronta» per push sicuro (**CA50-14**) |
| T50-23 | Dedupe SELECT su batch `product_id` con **multiple pagine interne** `range` successive → lettura **completa**, esito safe |
| T50-24 | Paginazione interna **incompleta** (errore a metà dataset batch) → `unsafePartialRemoteDedupe`; conteggi pronte non attendibili (**CA50-15**) |
| T50-25 | Due run async: dopo **Aggiorna** più rapido della fine del precedente → UI mostra solo **risultato run nuovo**, il vecchio viene ignorato (**CA50-17**) |
| T50-26 | **`NaN`/±inf**, **negativo**, **zero** — comportamento allineato a migration + TASK-049 + **policy §8.4a documentata**, test separati granulari (**CA50-19**) |
| T50-27 | Snapshot risultato: array bucket ordinati **identicamente** tra due invocazioni con stessi input (§8.9, **CA50-16**) |
| T50-28 | Simulazione errore rete/PostgREST: UI mostra **messaggio localizzato breve**, **non** stringa grezza Supabase (**CA50-18**) |
| T50-29 | Nessun **`UUID()` random** / PK remota sintetica nel dry-run; identità tramite **`(owner, product_id, type, effective_at)`**; assert stabili (**CA50-20**) |
| T50-30 | **`effective_at` canonico (A)** invariato sotto cambio **lingua/UI locale / display timezone** mock (o fixture fisse) — chiave stabile (**CA50-21**) |
| T50-31 | SELECT dedupe quando schema/team conferma: predicato **`owner_user_id`** + `product_id` batch; mai righe altro tenant (**CA50-22**) |
| T50-32 | **`source` / `note`**: trim, vuoto→nil, sample UI senza contenuti sensibili/lunghi non troncati in Disclosure (**CA50-23**) |
| T50-33 | Budget lettura §8.3.2 superato mid-run → **`unsafePartialRemoteDedupe`**; «Pronte» non attendibili (**CA50-24**) |
| T50-34 | Post polish §9.10: sempre **solo anteprima**; wording/CTA coerenti §9 (**CA50-25**) |

---

## 11. Criteri di accettazione

- [ ] **CA50-01** — Build **Debug** e **Release** compilano senza errori dopo le modifiche.
- [ ] **CA50-02** — **XCTest** coprono engine/VM pertinenti **T50-01…T50-34** (accorpamenti ammessi se la logica resta equivalente — documentare in Execution).
- [ ] **CA50-03** — **Audit zero-write Supabase**: nessuna API di scrittura nel codice **nuovo TASK-050**; review/grep su `Supabase*.swift` toccati (inclusi `.functions`, `.storage`, verbi `POST`/`PATCH`/`DELETE` ove applicabile). **Nel codice nuovo TASK-050**: **zero** `.insert`, `.upsert`, `.update`, `.delete`, **`.rpc`** (allineamento T50-14).
- [ ] **CA50-04** — **`plutil -lint`** (o equivalente progetto) su tutti i `Localizable.strings` modificati **IT/EN/ES/zh-Hans**.
- [ ] **CA50-05** — **`git diff --check`** pulito sui file tracciati toccati.
- [ ] **CA50-06** — **Regressione** test **TASK-048** e **TASK-049** — verde.
- [ ] **CA50-07** — UI DEBUG: badge **solo anteprima** visibile; **nessuna** azione che esegua push live nel task corrente.
- [ ] **CA50-08** — Nessun uso `service_role` / segreti; nessuna modifica `Product` prezzi correnti; nessuna mutazione `ProductPrice` locale esistente.
- [ ] **CA50-09** — Dedupe remoto **batchato** su `product_id` (default **100** per batch, salvo limite documentato); **nessun** pattern row-by-row network per prezzi.
- [ ] **CA50-10** — Se la SELECT dedupe **non** completa con successo → risultato **`unsafePartialRemoteDedupe`** (o equivalente) e **nessun** conteggio «pronte» presentato come attendibile per un push futuro.
- [ ] **CA50-11** — UI: **nessun** bottone/wording ambiguo di sync (**tabella vietati §9.3**) né CTA Push/Invia/Upload/Carica; chiavi copy coerenti con **§9.2** (IT/EN/ES/zh-Hans «Preview only» / «Does not write…» ecc.).
- [ ] **CA50-12** — **Logout** / **cambio account**: risultato dry-run **invalidato** (§8.6).
- [ ] **CA50-13** — Verificato: dry-run **non** muta SwiftData né **baseline** né **HistoryEntry** né **`syncStatus`** (coerente §7.1, T50-16/T50-20).
- [ ] **CA50-14** — **Duplicati / conflitti locali** (§8.2a) classificati e risolti **prima** di considerare candidati sicuri per dedupe remoto; nessuna dipendenza dal solo UNIQUE cloud.
- [ ] **CA50-15** — Dedupe remoto: oltre al batch `product_id`, supporta **paginazione interna** deterministica (`order` + `range`) fino a completezza o `unsafePartialRemoteDedupe`.
- [ ] **CA50-16** — **Ordinamento deterministico** di tutti i bucket + campioni UI = primi 20 post-sort (**§8.9**).
- [ ] **CA50-17** — **Lifecycle async**: cancel/token; risultati obsoleti non sovrascrivono UI; loading vs stale distinguibili (**§9.7 / §9.9**).
- [ ] **CA50-18** — Errori UI **localizzati**, **non grezzi**; nessun dato sensibile in copy debug; conforme **§9.8** / **T50-28**.
- [ ] **CA50-19** — Policy **`NaN`/inf**, **negativo**, **zero** verificata su **migration reale** + **TASK-049** (**§8.4a**); test **T50-26**.
- [ ] **CA50-20** — Identità candidato **solo** chiave deterministica **§8.10**: **zero** UUID random per simulare `id` remoto; test non dipendono da accidentalità.
- [ ] **CA50-21** — **`effective_at` canonico**: stabilità linguistic/timezone-independent per chiave (**§8.4**, **T50-30**, checklist Review).
- [ ] **CA50-22** — SELECT dedupe **owner-scoped** esplicitamente **ove** DDL/RLS coerenti; mismatch account ⇒ blocco ante-fetch; doc se filtro omit (**T50-31**).
- [ ] **CA50-23** — **`source`/`note`** sanitizzati §8.4c; disclosure privacy-safe.
- [ ] **CA50-24** — **Budget remoto §8.3.2** scelto e documentato in Review; superamento ⇒ **non-safe** (**T50-33**).
- [ ] **CA50-25** — Polish UI §9.10 **Apple-native**, **solo anteprima**, niente CTA live ambigue dopo iterazione grafica (**T50-34**).

### 11.1 Review (Claude) — checklist documentale *(post-EXECUTION, pre-approve)*

- [ ] **Evidenza lettura schema**: elencare i **file migration Supabase** (repo locale) letti per **`inventory_product_prices`** (path commit o nome file migration).
- [ ] **Evidenza lettura iOS**: elencare i **file Swift** rilevanti **TASK-048** / **TASK-049** effettivamente consultati per allineare normalizer/chiavi/comportamento.
- [ ] **Riuso vs duplicati**: elencare **quali helper** sono stati **riusati**; se esistono **nuovi file**, indicare **perché** sono necessari (non sostituibili con estensione minima di codice esistente) — coerente **§8.11**.
- [ ] Dedupe conforme **D50-01** + **budget §8.3.2** (batch **100**, no row-by-row, **`unsafePartialRemoteDedupe`** su incompletezza pagine o budget superato).
- [ ] Un solo cammino **`effective_at` + prezzo** con TASK-049 / migration (**no** formatter duplicati).
- [ ] UI conforme §9 (titolo, badge, CTA «Calcola anteprima»/«Aggiorna», chip, **20** righe max, VoiceOver/Dynamic Type).
- [ ] **`unsafePartialRemoteDedupe`** incluso caso **paginazione interna** incompleta — **T50-24** / CA50-15.
- [ ] Pipeline **§8.2a** duplicati locali + ordinamento §8.9 + **§9.8–9.9** copertura **T50-21**, **T50-27**, **T50-28**, **T50-25**.
- [ ] **CA50-19** / **T50-26**: evidenza lettura migration + parity TASK-049 in Review.
- [ ] **Zero-write**: evidenza **grep / audit** su codice TASK-050 (e `Supabase*.swift` toccati) per **`.insert`**, **`.upsert`**, **`.update`**, **`.delete`**, **`.rpc`** — allineamento **CA50-03** / **T50-14**; annotare **falsi positivi** se presenti.
- [ ] **Copy UI non ambigua**: evidenza (screenshot o elenco stringhe chiave) che **nessun** wording/CTA suggerisce **push/sync live** oltre quanto vietato **§9.3** / **CA50-11** / **T50-34**.
- [ ] CA50-12: prova manuale o test **T50-17** copre invalidazione sessione.
- [ ] **Timezone / §8.4**: evidenza che la stringa (**A**) non usa formatter locale-dependent; confronto migrazione + TASK-049 — **CA50-21**.
- [ ] CA50-22 / **T50-31**: diff query (owner filter) giustificato se omesso.
- [ ] CA50-24 / budget + **T50-33**.
- [ ] CA50-20 / CA50-23 / CA50-25 — **T50-29**, **T50-32**, **T50-34**.

---

## 12. Rischi

| Rischio | Mitigazione |
|---------|-------------|
| Fetch dedupe pesante con molti `product_id` **o molte righe per prodotto** | **Batch 100** (D50-01) + **§8.3.1** range ripetuti; cutoff budget → **`unsafePartialRemoteDedupe`** — **mai** «locale-only sicuro». |
| Drift **`effective_at` / timezone** vs DB / TASK-049 | §8.4 + checklist Review (**CA50-21**, **T50-30**); fixture con orari TZ fissati in test dove possibile. |
| Confusione UX con apply TASK-049 | Tre card distinte: preview / apply pull / dry-run push; copy esplicito. |
| Tentativo scope creep verso push live | CA50-07 + grep anti-scope + review; task futuro dedicato. |
| Ripening Android `sync_events` | Resta **fuori**; non implementare RPC finché TASK-071 non è risolto lato backend Android/Supabase in un task dedicato. |

---

## 13. Piano execution futuro *(non eseguito in PLANNING)*

Ordine **vincolante** per Cursor/Codex: **non partire dalla UI**. Prima **engine + test**, poi orchestratore, **poi** superficie DEBUG.

1. Leggere le **migration Supabase** pertinenti **`inventory_product_prices`** nel repo locale (**`effective_at`**, **`owner_user_id`**, `source`/`note`, `price` / CHECK + limiti **deducibili** PostgREST), i file iOS indicati in **§6**, **e** il codice effettivo **TASK-048** / **TASK-049** (normalizer, chiavi, fetch read-only, apply insert-only da non violare).
2. Definire (o confermare) **normalizer**, **chiave logica**, **canonicalizer `effective_at`/prezzo** **riusando** il codice esistente ove possibile (**§8.4**, **§8.11**) — **zero** seconda implementazione divergente senza motivazione in Review.
3. Implementare l’**engine puro** dry-run/preflight (output tipizzato §8) con **XCTest** **T50-01…T50-34** dove applicabile (**CA50-02**).
4. Implementare l’**orchestratore read-only** (snapshot SwiftData + SELECT batchati + budget §8.3.2) **fuori dalla View** (**§8.1**).
5. Solo **dopo** engine + test verdi: implementare la **UI DEBUG** in `OptionsView` conforme **§9** / **§9.10** (card compatta + disclosure).
6. Aggiungere / aggiornare **localizzazioni** **IT/EN/ES/zh-Hans** per le nuove stringhe.
7. Eseguire **audit zero-write** (grep **CA50-03** / **T50-14**), **regressioni** TASK-048 / TASK-049 (**CA50-06**), matrice §10, criteri §11, checklist **§11.1**; poi **handoff a REVIEW** (Claude) con log evidenze.

---

## 14. Handoff a Cursor/Codex

**NON attivo in questo turno.**
Passaggio ad **EXECUTION** solo dopo **override esplicito dell’utente** e dopo eventuale **review planning** concordata.
Fino ad allora: **nessun Swift**, **nessun build/test obbligatorio**.

**Planning Freeze** (sezione omonima): nessun ampliamento requisiti senza evidenza reale; prossimo passo valido = restare in PLANNING **oppure** EXECUTION con override. In EXECUTION seguire **§13** nell’ordine indicato (**UI per ultima**).

---

## Planning (Claude) — sintesi operativa per EXECUTION futura

### Analisi
Dopo TASK-049 lo storico può essere arricchito localmente da cloud ancora una volta **solo in pull**; il passo naturale è valutare **cosa sarebbe pushato** senza scrivere, sotto gli stessi gate di sicurezza del catalogo manuale e della baseline.

### Approccio proposto
**D50-01** + **§8.3.1–8.3.2** (interna+budget); filtro **`owner_user_id`** ove §8.3–8.4b; **§8.2a** local duplicate; **§8.4** timezone-independent canonical `effective_at`; **§8.4a–c** numeri + owner payload + sanitize `source`/`note`; **§8.9** sort; **§8.10** identità chiave senza UUID random; **§8.11** riuso minimo surface; engine **pure** + orchestratore **thin**; **§9** + **§9.10** polish semplice; **`unsafePartialRemoteDedupe`** se incompleto; ordine **§13**.

### File da modificare *(probabilmente, solo post-override EXECUTION)*

- **Massimo** 1 nuovo file **engine/service** dry-run + eventualmente 1 **ViewModel**/state holder (**§8.11**); **no** moltiplicazione layer.
- `OptionsView.swift` (DEBUG) — **solo dopo** engine/test (**§13**).
- `en|es|it|zh-Hans.lproj/Localizable.strings`
- `iOSMerchandiseControlTests/*ProductPricePush*` (nome definitivo in EXECUTION)
- Eventuale `project.pbxproj` se nuovo file Swift

### Rischi identificati
Vedi §12.

### Handoff → Execution *(condizionato)*
- **Prossima fase**: EXECUTION *(solo dopo user override)*
- **Prossimo agente**: Cursor / Codex executor
- **Azione consigliata**: leggere **Planning Freeze**, **§8.2a**, **§8.3.1–8.3.2**, **§8.4–8.4c**, **§8.9–8.11**, **§9.8–9.10**, **§11.1**, **§13**, migration `effective_at` / `owner_user_id` / `source`/`note` / price; poi implementare (solo se autorizzato), **mai** prima UI (**§13**).

---

## Execution (Codex)
### 2026-05-06 — Avvio controllato su override utente

- **EXECUTION avviata su override esplicito utente. Primo step: schema/code audit prima di engine/UI.**
- **Stato fase in questo step storico**: TASK-050 portato a **ACTIVE / EXECUTION** in modalità controllata/progressiva; stato finale aggiornato sotto in **Review/Fix**.
- **Divieti confermati**: nessuna write Supabase, nessun push live, nessuna migration SQL/RLS/RPC, nessun Android, nessun `sync_events`/outbox, nessun `service_role`, nessuna CTA live “Push / Sync / Upload / Invia / Carica”.

### Audit schema/codice prima del codice

**File Swift letti / verificati:**
- `iOSMerchandiseControl/Models.swift` — `Product`, `ProductPrice`, relazione e campi `remoteID`, `purchasePrice`, `retailPrice`.
- `iOSMerchandiseControl/SupabaseProductPricePreviewService.swift` — TASK-048 preview read-only, paging/range/order, zero write.
- `iOSMerchandiseControl/SupabaseProductPriceApplyService.swift` — TASK-049 normalizzazione, `PriceCanonicalizer`, `ProductPriceEffectiveAtCanonicalizer`, apply locale insert-only.
- `iOSMerchandiseControl/SupabasePullPreviewModels.swift`, `iOSMerchandiseControl/SupabaseInventoryDTOs.swift`, `iOSMerchandiseControl/SupabaseInventoryService.swift` — DTO remote price + client read-only.
- `iOSMerchandiseControl/SupabaseCatalogBaselineReader.swift`, `iOSMerchandiseControl/SupabaseCatalogBaselineModels.swift` — gate baseline valido/latest owner-scoped.
- `iOSMerchandiseControl/SupabaseManualPushPreflightModels.swift`, `iOSMerchandiseControl/SupabaseManualPushPreflightService.swift` — pattern gate account/baseline/manual push catalogo.
- `iOSMerchandiseControl/OptionsView.swift` — sezione DEBUG Supabase, pattern async/cancel/reset e card esistenti.
- Test letti: `iOSMerchandiseControlTests/SupabaseProductPricePreviewServiceTests.swift`, `iOSMerchandiseControlTests/SupabaseProductPriceApplyServiceTests.swift`, `iOSMerchandiseControlTests/SupabaseManualPushPreflightTests.swift`.

**Migration Supabase lette / verificate:**
- `../MerchandiseControlSupabase/supabase/migrations/20260417200000_task016_inventory_product_prices.sql`
- `../MerchandiseControlSupabase/supabase/migrations/20260421120000_task038_restrict_authenticated_delete_inventory.sql`
- Grep migration su `inventory_product_prices`, `record_sync_event`, `sync_events` solo come audit scope; nessuna migration modificata.

**Decisioni tecniche documentate prima del codice:**
- `effective_at`: riuso obbligato `ProductPriceEffectiveAtCanonicalizer`; formato canonico TASK-049 `"yyyy-MM-dd HH:mm:ss"`, calendario gregoriano, `en_US_POSIX`, UTC, non lenient. UI separata dal canonico.
- Prezzo: riuso `PriceCanonicalizer`; `NaN`, infinito e negativo invalidi; prezzo `0` ammesso. La migration ha `price double precision NOT NULL` ma non un CHECK `price >= 0`; policy applicativa conservativa allineata TASK-049.
- `owner_user_id`: la migration richiede colonna esplicita e non mostra default/trigger DB; dry-run deriva `owner_user_id` dalla sessione in RAM, filtra SELECT con `owner_user_id == session.user.id` e si affida comunque a RLS owner-scoped.
- Helper riusati: `PriceCanonicalizer`, `ProductPriceEffectiveAtCanonicalizer`, `SupabasePullPreviewNormalizer`, `SupabaseCatalogBaselineReader`, `RemoteInventoryProductPriceRow`, pattern request/reset di `OptionsView`.
- Nuovo file engine/service giustificato: TASK-048 è remote-preview e TASK-049 è pull→apply locale; TASK-050 richiede local→remote candidate dry-run, dedupe remoto read-only e bucket specifici. Per §8.11 è stato creato **un solo** nuovo file engine/service.

### Slice implementata

- Aggiunto `iOSMerchandiseControl/SupabaseProductPricePushDryRunService.swift`:
  - engine puro/testabile `SupabaseProductPricePushDryRunEngine`;
  - snapshot value-type locale e remoto;
  - identità candidato deterministica da chiave logica, **nessun UUID random**;
  - gate globali no-auth / account mismatch / baseline missing-stale-partial;
  - mapping locale `ProductPrice` → payload candidato in RAM (`owner_user_id`, `product_id`, `type`, `price`, `effective_at`, `created_at`, `source`, `note`);
  - dedupe remoto read-only con stato `.complete` / `.notNeeded` / `.unsafePartialRemoteDedupe`;
  - bucket: candidati, già presenti remoto, conflitti remoto, duplicati locali, conflitti locali, no remoteID, invalidi;
  - se dedupe remoto è incompleto/non safe, nessun candidato viene marcato safe.
- Esteso `iOSMerchandiseControl/SupabaseInventoryService.swift` con `fetchProductPricesForPushDryRunDedupePage(...)`: SELECT read-only owner-scoped su `inventory_product_prices`, filtro batch `product_id`, ordine `product_id/type/effective_at/id`, range/paginazione.
- Aggiunto `iOSMerchandiseControlTests/SupabaseProductPricePushDryRunServiceTests.swift` con test engine/orchestratore/budget/audit source.
- UI DEBUG aggiunta solo alla fine in `iOSMerchandiseControl/OptionsView.swift`: card compatta “solo anteprima”, copy “Non scrive su Supabase”, CTA “Calcola anteprima” / “Aggiorna”, chip summary, disclosure max 20 esempi per bucket, reset su logout/cambio sessione, nessuna CTA live.
- Aggiunte localizzazioni IT/EN/ES/zh-Hans per nuova card DEBUG e stati dry-run.

### Check eseguiti

- ✅ **Build compila** — `xcodebuild build -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'` → **BUILD SUCCEEDED**.
- ⚠️ **Nessun warning nuovo introdotto** — verificabile solo parzialmente: output build mostra warning generico Xcode `Metadata extraction skipped. No AppIntents.framework dependency found`; nessun warning Swift visibile sui file TASK-050, ma manca baseline warning precedente per dichiarare “nuovo/non nuovo” con certezza.
- ✅ **XCTest engine + regressione TASK-048/TASK-049** — `xcodebuild test ... -only-testing:SupabaseProductPricePushDryRunEngineTests -only-testing:SupabaseProductPricePreviewServiceTests -only-testing:SupabaseProductPriceApplyServiceTests` su iPhone 16e iOS 26.2 → **TEST SUCCEEDED**; engine 17/17 PASS, preview/apply regressione PASS.
- ✅ **plutil localizzazioni** — `plutil -lint` su `en/it/es/zh-Hans.lproj/Localizable.strings` → OK.
- ✅ **git diff --check** — PASS; nuovi file untracked controllati anche con `git diff --no-index --check` → nessun output whitespace.
- ✅ **Audit zero-write codice nuovo TASK-050** — grep sui soli diff aggiunti per `.insert(`, `.upsert(`, `.update(`, `.delete(`, `.rpc(`, `record_sync_event`, `sync_events`, `outbox` → nessun match. Grep intero file ha solo falsi positivi/preesistenti non TASK-050 (`Set.insert` e baseline writer UI già esistente fuori dalla card).
- ✅ **Nessuna modifica `Product.purchasePrice` / `Product.retailPrice`** — grep su diff aggiunti per assegnazioni → nessun match.
- ✅ **Nessuna mutazione `ProductPrice` locale** — nessun `modelContext.insert`, `modelContext.save` o creazione persistente `ProductPrice` nei diff TASK-050.
- ✅ **Nessuna mutazione `HistoryEntry` / `syncStatus` / baseline** — nessun writer baseline, `HistoryEntry`, `syncStatus` o commit baseline nei diff TASK-050.
- ✅ **Coerenza planning / criteri accettazione** — ordine §13 rispettato: audit schema/codice → engine/test → orchestratore read-only → audit zero-write → UI DEBUG ultima.

### Handoff operativo della slice

- Stato storico della slice: TASK-050 consegnato allora in **ACTIVE / EXECUTION** su richiesta esplicita utente; chiusura finale aggiornata sotto in **Review/Fix**.
- Stato consegnato: prima slice minima implementata e verificata; push live ProductPrice resta task futuro separato.
- Rischi residui / follow-up candidate: eventuale task futuro dovrà definire write live controllata con conferma/read-back separati; questa slice non include scritture remote né persistenza di piani dry-run.

## Review (Claude)
### 2026-05-06 — REVIEW severa su override utente *(eseguita da Codex / Reviewer+Fixer)*

- **Esito finale**: **APPROVED_FIXED_DIRECTLY / DONE**.
- **Scope diff verificato**: i file principali modificati sono quelli attesi per TASK-050; nuovi file attesi presenti e non dimenticati: `docs/TASKS/TASK-050-supabase-productprice-manual-push-preflight-dry-run-ios.md`, `iOSMerchandiseControl/SupabaseProductPricePushDryRunService.swift`, `iOSMerchandiseControlTests/SupabaseProductPricePushDryRunServiceTests.swift`. Il progetto usa file system synchronized groups, quindi il nuovo file app e il nuovo file test risultano inclusi nei rispettivi target tramite build/test.
- **Schema/migration ricontrollate**: `20260417200000_task016_inventory_product_prices.sql` e `20260421120000_task038_restrict_authenticated_delete_inventory.sql`; confermati `owner_user_id`, unique key `(owner_user_id, product_id, type, effective_at)`, `price double precision NOT NULL`, `effective_at` canonico testuale, RLS owner e restrizione delete.
- **Zero-write / safety**: audit su codice TASK-050 e file Supabase toccati: zero `.upsert(`, `.update(`, `.delete(`, `.rpc(`, `record_sync_event`, `sync_events`, `outbox`, `service_role`; `.insert(` compare solo come falso positivo nei test in-memory SwiftData e `Set.insert` preesistente/read-only, non come Supabase write. Nessuna mutazione persistente generata dal dry-run su `ProductPrice`, `Product.purchasePrice`, `Product.retailPrice`, `HistoryEntry`, `syncStatus` o baseline.
- **Engine/service**: identità candidato deterministica su `(owner_user_id, product_id, type, effective_at)`, nessun `UUID()` random dry-run; riuso `PriceCanonicalizer`, `ProductPriceEffectiveAtCanonicalizer` e normalizer TASK-049; `effective_at` stabile UTC/POSIX; NaN/infinito/negativo invalidi e zero ammesso; `source`/`note` trim + empty-to-nil; duplicati/conflitti locali e remoti classificati; dedupe remoto batch/paginato/budget/fail-closed; `unsafePartialRemoteDedupe` non espone candidati safe; ordinamento deterministico e strutture `Dictionary`/`Set` ragionevoli per dataset grande.
- **Orchestratore / SupabaseInventoryService**: SELECT read-only owner-scoped su `inventory_product_prices`, filtro batch `product_id`, range/pagination e order deterministico `product_id/type/effective_at/id`; error handling fail-closed; nessuna query row-by-row e nessuna lettura non necessaria di `source`/`note` dopo fix.
- **UI/UX OptionsView**: card DEBUG semplice e Apple-native, badge “Solo anteprima” sempre visibile, copy “Non scrive su Supabase”, CTA solo “Calcola anteprima” / “Aggiorna” / annulla caricamento, nessun wording live ambiguo nelle nuove stringhe TASK-050, disclosure max 20 sample per bucket, stati empty/loading/error/stale/blocked chiari, reset su logout/cambio account/disappear, guard requestID contro risultati async vecchi; VoiceOver migliorato sullo stato dedupe remoto.
- **Localizzazioni**: IT/EN/ES/ZH-Hans lint OK, nessuna chiave TASK-050 mancante o duplicata, wording coerente con “preview only / does not write” e cinese “仅预览 / 不写入 Supabase”.
- **Test**: suite TASK-050 rinominata/coerente con comando richiesto; coperti engine, duplicati/conflitti locali, already-present remoto, conflict remoto, unsafe partial remote dedupe, budget, ordering deterministico, canonical `effective_at`, invalid price, sanitize source/note, regressioni TASK-048/TASK-049.

**Comandi REVIEW eseguiti:**
- ✅ `git diff --check` → PASS; nuovi file untracked controllati anche con `git diff --no-index --check /dev/null <file>` → PASS.
- ✅ `plutil -lint iOSMerchandiseControl/{en,it,es,zh-Hans}.lproj/Localizable.strings` → OK.
- ✅ `xcodebuild build -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'` → **BUILD SUCCEEDED**.
- ✅ `xcodebuild test -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' -only-testing:iOSMerchandiseControlTests/SupabaseProductPricePushDryRunServiceTests -only-testing:iOSMerchandiseControlTests/SupabaseProductPricePreviewServiceTests -only-testing:iOSMerchandiseControlTests/SupabaseProductPriceApplyServiceTests` → **TEST SUCCEEDED**.
- ✅ Build Release extra → **BUILD SUCCEEDED**.
- ⚠️ Warning residuo non attribuito a TASK-050: build Release mostra warning Swift 6 preesistente in `SupabaseProductPriceApplyService.swift` su `issueLimit` actor-isolated; non è stato introdotto dai file TASK-050 e resta fuori perimetro. Presente anche warning generico Xcode AppIntents metadata extraction, non legato a TASK-050.

## Fix (Codex)
### 2026-05-06 — Fix diretti dentro REVIEW

- Corretto bug di paginazione/budget nel dry-run: un batch che completa esattamente sull'ultima pagina consentita non viene più marcato erroneamente `unsafePartialRemoteDedupe`.
- Ridotto il SELECT dedupe ProductPrice ai soli campi necessari, rimuovendo `source`/`note` dalla lettura remota della preview push.
- Aggiunti messaggi globali nel disclosure “Bloccati” per no auth, account mismatch, baseline missing/stale/partial, così il motivo di blocco non sparisce quando non ci sono righe locali campione.
- Migliorata accessibilità della riga dedupe remoto con `accessibilityValue`.
- Rinominata la classe test TASK-050 a `SupabaseProductPricePushDryRunServiceTests` per allinearla al comando REVIEW richiesto.
- Aggiunti test regressione per completamento sull'ultima pagina consentita e superamento budget righe.

**Chiusura:** TASK-050 marcato **DONE / Chiusura** su conferma utente esplicita nel prompt REVIEW, con esito **APPROVED_FIXED_DIRECTLY**.
