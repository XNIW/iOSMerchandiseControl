# TASK-082 — Conflitti e timestamp (policy cross-device iOS ↔ Supabase ↔ Android)

## Informazioni generali

| Campo | Valore |
|-------|--------|
| **Task ID** | TASK-082 |
| **Titolo** | Conflitti e timestamp — policy sicura per Product, Supplier, Category, ProductPrice |
| **File task** | `docs/TASKS/TASK-082-supabase-conflicts-timestamps-ios.md` |
| **Stato** | **ACTIVE** |
| **Fase attuale** | **PLANNING** |
| **Tipo** | **planning-only** *(questo turno e il perimetro documentale del task)* |
| **Responsabile attuale** | **Claude Code / Planner** |
| **Data creazione** | 2026-05-08 |
| **Ultimo aggiornamento** | 2026-05-08 — avvio planning (solo markdown; **TASK-082 NON DONE**) |
| **Ultimo agente** | Claude Code / Planner |
| **Repo iOS** | `/Users/minxiang/Desktop/iOSMerchandiseControl` |

## Dipendenze

- **Dipende da:** **TASK-078 DONE / Chiusura** (pull apply guidato), **TASK-079 DONE / Chiusura** (push catalogo guidato), **TASK-080 DONE / Chiusura** (ProductPrice apply/push Release; conflitti espliciti rimandati qui), **TASK-081 DONE / Chiusura** (drain outbox Release; semantica eventi/outbox correlata ma policy conflitto dati = questo task).
- **Sblocca:** chiarimento operativo per **TASK-083** (smoke E2E), **TASK-084** (parità Android con regole esplicite), hardening **TASK-085**.
- **Non apre:** TASK-083 / TASK-084 / TASK-085 *(restano backlog fino a decisione separata)*.

## Scopo

Definire una **policy documentata e testabile** per:
- conflitti **locale vs remoto** su catalogo (**Product**, **Supplier**, **ProductCategory**) e **ProductPrice**;
- uso di **`updated_at`** remoto vs metadati locali (**`remoteUpdatedAt`**, assenza di `updated_at` locale esplicito su `Product` oltre i campi già citati in audit);
- **tombstone** **`deleted_at`** su tabelle catalogo Supabase vs **`remoteDeletedAt`** SwiftData;
- **idempotenza** push/apply e **dedupe** (chiavi funzionali barcode / nome lookup / `(product_id, type, effective_at)` per prezzi);
- **UUID locale SwiftData** (persistent identifier) vs **UUID remoto** (`remoteID`);
- scenari **offline**, **manual sync**, **retry** senza risoluzione silenziosa non sicura.

**Fuori scope di questo documento:** execution Swift, SQL/migration, modifiche Android, qualsiasi sync automatica/Timer/BGTask/Realtime/polling/worker, drain/outbox live, cleanup distruttivo.

---

## 1. Obiettivo

Raggiungere un **modello decisionale unico** (per prodotto/owner) che permetta a iOS di:

1. **Non applicare né inviare** in silenzio quando due modifiche concorrenti non sono ordinabili in modo sicuro con le sole informazioni oggi disponibili in schema + client.
2. Usare **`updated_at` remoto** (catalogo) e **`effective_at` / `created_at` testuali** (prezzi) come **anci temporali funzionali** autoritativi lato cloud, confrontati con fingerprint/metadati locali già presenti (**baseline**, **`remoteUpdatedAt`**, snapshot apply).
3. Trattare **`deleted_at`** catalogo come **tombstone definitiva** lato server (con trigger **anti-resurrezione** post-tombstone): nessuna “ripulitura” accidentale via upsert concorrente.
4. Separare cosa è **risolto automaticamente** (no-op, identical remote, dedupe esatta) da cosa richiede **revisione utente** o **blocco controllato** nel summary Release.

---

## 2. Stato attuale iOS *(repo-grounded)*

### Modelli SwiftData (`Models.swift`)

- **`Supplier` / `ProductCategory`:** `name` univoco locale; `remoteID`, `remoteUpdatedAt`, `remoteDeletedAt` opzionali.
- **`Product`:** `barcode` univoco locale; `remoteID`, `remoteUpdatedAt`, `remoteDeletedAt`; campi operativi e relazioni `supplier` / `category`; `priceHistory` → `[ProductPrice]`.
- **`ProductPrice`:** `type`, `price`, `effectiveAt`, `source`, `note`, `createdAt`, relazione `product` — **nessun `remoteID` persistito** sulla riga storico *(TASK-080 documentato)*; correlazione remota avviene via servizi/DTO e chiavi logiche al apply/push.

### Preview / conflitti (`SupabasePullPreviewService`)

- Costruisce `SyncPreviewConflict` (es. **`remoteIDConflict`**, lookup supplier/category, duplicati `remoteID`, conflitti prodotto) e **metriche** `conflicts` / **tombstones** (`deleted_at` remoto).
- Con **conflitti presenti** o guard globali: `SupabasePullApplyService` può rifiutare apply (**`conflictsPresent`**, `priceHistoryIncomplete`, ecc.).

### Apply pull catalogo (`SupabasePullApplyService`)

- `prepareApplyPlan` + `validateNotStale` (fingerprint atteso vs snapshot locale) → **`previewStale`** se i dati locali cambiano tra review e apply.
- **Stock:** opzione `applyStockQuantity` (default coerente con TASK-078 **false**).

### Apply prezzi (`SupabaseProductPriceApplyService`)

- Regole fail-closed su **stessa chiave logica** con **prezzo diverso** → conteggio **conflicts**; dedupe se identico; mappa orphan/unmapped.

### Push catalogo — preflight (`SupabaseManualPushPreflightService`)

- Per **product** e **productPrice:** ramo che imposta **`blockedRemoteConflict`** (no push automatico “conservative block”).
- Per **supplier/category:** confronto **baseline `remoteUpdatedAt`** vs **`local remoteUpdatedAt`**; warning staleness; candidati dry-run update/no-op/link.

### Baseline (`SupabaseCatalogBaselineReader` / `SupabaseCatalogBaselineModels`)

- **`SupabaseCatalogBaselineRecord`:** `remoteID`, `remoteUpdatedAt`, `remoteDeletedAt`, fingerprint, barcode/lookup canonici — **fonte locale di “ultima foto” post-pull** per staleness push e confronti.

### Manual sync UI (`SupabaseManualSyncViewModel`, `OptionsView`)

- Flusso **Controlla cloud → Rivedi → Conferma** con piani volatili e summary **privacy-safe** (nessun raw UUID/JSON in Release per governance storica).
- Sezioni review: cloud→dispositivo, dispositivo→cloud, prezzi, attenzione, passi dedicati (es. registrazione attività TASK-081).

### Outbox / eventi (`sync_events`)

- Dominio **`catalog` / `prices`**, tipi **`catalog_changed`**, **`prices_changed`**, tombstone **`catalog_tombstone`**, **`prices_tombstone`** — utili come **segnali di dominio** e audit, **non** come sostituto della policy di merge righe business *(TASK-081 done — drain come meccanismo separato)*.

---

## 3. Riferimenti Supabase letti *(schema reale, clone locale)*

Percorso: `/Users/minxiang/Desktop/MerchandiseControlSupabase/supabase/migrations/`

| Migrazione | Contenuto rilevante |
|------------|---------------------|
| `20260417120000_task013_inventory_catalog_rls.sql` | Tabelle **`inventory_suppliers`**, **`inventory_categories`**, **`inventory_products`** con **`updated_at timestamptz NOT NULL DEFAULT utc now`**. Unique originario **nome lower** (supplier/category) e **(owner, barcode)** prodotti — **sostituiti** da indici partial in Task 019. |
| `20260418200000_task019_inventory_catalog_tombstone.sql` | Colonne **`deleted_at timestamptz NULL`** su suppliers/categories/products; **partial unique** solo righe **`deleted_at IS NULL`**; trigger **blocca UPDATE** su righe già tombstonate (anti-resurrezione). |
| `20260417200000_task016_inventory_product_prices.sql` | Tabella **`inventory_product_prices`**: PK **`id uuid`**, **`UNIQUE (owner_user_id, product_id, type, effective_at)`**, **`effective_at text NOT NULL`**, **`created_at text NOT NULL`**. **Nessuna** colonna `updated_at` / `deleted_at` in questa migrazione. |
| `20260421120000_task038_restrict_authenticated_delete_inventory.sql` | **Revoca DELETE** su `inventory_products` e **`inventory_product_prices`** per `authenticated` — cancellazione fisica non è il percorso client; coerente con eventi **`prices_tombstone`** / strategie alternative documentate in roadmap. |
| `20260424021936_task045_sync_events.sql` | Tabella **`sync_events`**, RPC **`record_sync_event`**, **`changed_count` ∈ [0,1000]**, idempotenza **`client_event_id`**, domains/events MVP. |

**Implicazioni per la policy**

- **Catalogo:** **`updated_at`** è il campo temporale standard di **mutazione riga**; **`deleted_at`** è **tombstone** semantica; vincoli unique “attivi” ignorano righe cancellate logicamente.
- **ProductPrice:** la verità di **unicità** è **`(product_id, type, effective_at)`** a livello owner; **`effective_at`** è la dimensione temporale **business** della voce (non `updated_at` di `inventory_products` — cfr. **D80-17 / D80-18** TASK-080).

---

## 4. Riferimento Android *(solo funzionale, nessun porting Kotlin)*

- **Storico prezzi / summary:** entity **`ProductPrice`** con chiave logica composita; view **`ProductPriceSummary`** per ultimo/penultimo prezzo per tipo — utile solo per **allineare l’intento “corrente vs storico”**, non per copiare implementazione.
- **Allineamento semantico** con TASK-084: stessi vincoli SQL e stessi campi testuali `effective_at` / `created_at` devono produrre **stessi esiti di dedupe** se i client applicano la stessa policy — dettaglio verifica in smoke dedicato, non in TASK-082 execution.

---

## 5. Problema da risolvere *(analisi)*

| Tema | Descrizione |
|------|-------------|
| **Conflitti local vs remote** | Due device modificano lo stesso **barcode** o lo stesso **`remoteID`** con contenuti divergenti; oppure rename incrociato supplier/category. |
| **`updated_at` locale/remoto** | In SwiftData **non** esiste un **`updated_at` locale** parallelo server per ogni entità: si usa **`remoteUpdatedAt`** (ultima osservazione remota nota) + **baseline fingerprints**; il clock device **non** deve “vincere” da solo senza confronto con la policy. |
| **Tombstone `deleted_at`** | Remoto tombstona un prodotto; locale ha ancora record “attivo” o viceversa; **anti-resurrezione** server impedisce revive accidentale — il client deve classificare **cosa proporre** (soft-delete locale, blocco, o revisione). |
| **Product / Supplier / Category / ProductPrice** | Grado di libertà diverso: lookup **nome** (case-insensitive) vs **barcode** vs chiave prezzo **logica**. |
| **ID locali vs remote** | **`remoteID`** assente vs presente; collisione **`remoteID`** tra locale e remoto (già rilevata come `remoteIDConflict` in preview). |
| **Chiavi funzionali** | **Barcode** (product), **nome** supplier/category (con unique locale e partial unique remoto attivo), **(product ref, type, effective_at canonico)** per prezzi. |
| **ProductPrice dedupe / idempotenza** | Vincolo SQL + confronto valore; duplicati logici locali o remoti prima di insert; **stesso effective_at, prezzo diverso** = conflitto, non dedupe. |
| **Offline / manual sync / retry** | Preview o piano possono diventare **stale**; retry deve **ricalcolare** dai servizi; niente doppio apply senza `prepareApplyPlan` fresco *(già pattern TASK-078)*. |

---

## 6. Policy proposta *(bozza per review e futura execution)*

Legenda azioni: **AUTO** (senza chiedere), **REVIEW** (evidenziato in **Rivedi** / summary), **BLOCK** (non procedere finché ripristino/risoluzione manuale esterna al sync), **SKIP** (saltato con conteggio chiaro).

### 6.1 Catalogo — **Product**

| Scenario | Policy proposta |
|----------|-----------------|
| Stesso **barcode**, stesso **`remoteID`**, payload remoto più recente per **`updated_at`** e fingerprint locale = baseline attesa | **AUTO** apply inbound; aggiornare **`remoteUpdatedAt`**. |
| Stesso barcode, **remoteID** locale ≠ remoto (conflitto identità) | **BLOCK** apply inbound come oggi in preview; **REVIEW** obbligatorio — in TASK-082 execution: testo guida “serve verifica in anagrafica” senza UUID. |
| Locale modificato (vs fingerprint baseline) **e** remoto più recente (**`updated_at`**) | **REVIEW** — non **LWW** cieco sul device: presentare **“modifiche su entrambi i lati”** (copy naturale). |
| Remoto **tombstone (`deleted_at`)**, locale ancora attivo | **REVIEW** + default sicuro: allineare a **non mostrare / non vendere** come da policy prodotto (dettaglio UX TASK-083); **no delete fisico** locale obbligatorio se contraddice vincoli SwiftData — preferire **marca eliminato** / coerenza con data model esistente in execution. |
| Locale-only (no `remoteID`), remoto nuovo con stesso barcode | **AUTO** link + apply se preview già costruito così *(verificare flusso esistente)*; altrimenti **REVIEW**. |

### 6.2 **Supplier** / **Category**

| Scenario | Policy proposta |
|----------|-----------------|
| Stesso **nome canonico**, stesso **`remoteID`**, `updated_at` remoto avanti | **AUTO** aggiornamento campo / metadati. |
| Due remoti o conflitto **remoteID** duplicato (preview già lo segnala) | **BLOCK** / **REVIEW** — mai merge silenzioso su lookup. |
| Rinomina incrociata (A→B su un device, B→A su altro) | **REVIEW** — etichettare come “nome fornitore/categoria non univoco dopo ultimo controllo”. |
| Tombstone remoto vs nome ancora referenziato locale | **REVIEW** + aggiornamento FK / scollegamento — ordine: **lookup prima dei prodotti** (allineato TASK-040 / ordering storico). |

### 6.3 **ProductPrice**

| Scenario | Policy proposta |
|----------|-----------------|
| Stessa chiave **`(product_id remoto, type, effective_at canonico)`**, stesso **price** | **AUTO** skip / idempotente. |
| Stessa chiave, **price** diverso | **REVIEW** / conteggio **conflitto** — **no LWW** automatico sulla sola `effective_at` testuale; richiedere decisione prodotto (TASK-083 può offrire flusso dedicato) o mantenere **blocco** finché non esiste regola esplicita. |
| **`effective_at` diversi**, voci indipendenti | **AUTO** merge se entrambe valide (ordinamento storico); aggiornare **current** su `Product` solo secondo regola **ultimo per tipo** documentata. |
| Orfano remoto / prodotto senza mapping | **SKIP** / **blocked** come oggi — non inserire “best effort” nascosto. |
| DELETE SQL remoto revocato | **Nessun** wipe fisico via API client; eventuali tombstone **`prices_tombstone`** vanno interpretati come **REVIEW**/segmentazione dedicate (coerenza Task 038 + sync_events). |

### 6.4 **Delete / tombstone (catalogo)**

- Remote **`deleted_at` not null** → trattare come **“chiuso lato cloud”**; il device non deve **ripristinare** silenziosamente (allinea a **anti-resurrezione** server).
- Operazioni **locali delete** verso cloud: **non** basarsi su DELETE PostgREST per prezzi (Task 038); per catalogo valutare **pattern tombstone** + evento dominio (fuori da questo planning codice).

### 6.5 **Baseline stale**

- Se **`SupabaseCatalogBaselineReader`** / snapshot pre-push indicano **baseline stale** o mismatch account: **BLOCK** push mutativo; copy user-facing: **“Riallinea dal cloud”** / **“Controlla di nuovo”** *(termini già familiari card)*.

### 6.6 **Remote newer vs local newer**

- **Regola guida:** usare **`updated_at` remoto** (catalogo) e **ordine logic prezzi** per storico; **non** usare solo “timestamp salvataggio locale SwiftData” come autorità.
- Se entrambi risultano “modificati” rispetto all’**ultima baseline comune** nota → **REVIEW**, non vincitore automatico.

### 6.7 **Local-only vs remote-only**

- **Local-only:** candidato push **dopo** preflight; se bloccato per **`blockedRemoteConflict`**, → **REVIEW** con messaggio “modifiche sul cloud dall’ultimo controllo”.
- **Remote-only:** candidato pull apply; se conflitto identità, → **REVIEW/BLOCK**.

### 6.8 **Stesso dato invariato**

- **AUTO** no-op; non incrementare conteggi “modifiche applicate” ingannevoli.

---

## 7. Decisioni *(numerate)*

| ID | Decisione |
|----|-----------|
| **D82-01** | La **source of truth temporale** per **catalogo** è **`updated_at` remoto** (+ `deleted_at` per stato); per **ProductPrice**, la semantica temporale business è **`effective_at`** (+ **`created_at`** come meta), **non** `updated_at` di `inventory_products`. |
| **D82-02** | **No silent LWW** quando **entrambe** le parti hanno modifiche rilevate rispetto all’**ultima baseline nota** → stato **REVIEW** o **BLOCK**. |
| **D82-03** | **Tombstone remoto** (`deleted_at`) **non** può essere ignorato per “convenienza”; aggiornamento locale deve rispettare **anti-resurrezione** concettuale (il server già blocca revive tecnica). |
| **D82-04** | Conflitto **`remoteID`** su stesso barcode o lookup → **mai** overwrite automatica; **BLOCK/REVIEW** con summary privacy-safe. |
| **D82-05** | **ProductPrice:** duplicato logico con **valore diverso** → **conflitto** esplicito (allinea **D80-06 / TASK-080**); risoluzione automatica **vietata** in Release finché non definita una UX di risoluzione (fuori TASK-082 se serve nuovo disegno). |
| **D82-06** | **Dedupe** solo quando **vincolo SQL** e **valore business** coincidono esattamente dopo normalizzazione canonica. |
| **D82-07** | **Prefetch/preview stale** → **rieseguire** piano prima di apply/push (**fail-closed**); niente retry “cieco”. |
| **D82-08** | **`sync_events`** (**catalog_changed**, **prices_changed**, tombstone) sono **audit/segnali**, non sostituti del **merge** righe; il drain (TASK-081) **non** risolve conflitti di contenuto. |
| **D82-09** | **Push preflight** per **product**: oggi **conservative block** — la policy TASK-082 deve **esplicitare** se in futuro si introduce **merge guidato** o sempre **REVIEW** obbligatoria quando `blockedRemoteConflict`. |
| **D82-10** | **DELETE** SQL **non** è il canale primario per prezzi lato client (**Task 038**); ogni “rimozione” va modellata con **evento dominio** / strategia documentata in execution successiva. |

---

## 8. Casi utente / UX Release *(nessun gergo, privacy-safe)*

### Principi

- Non mostrare **UUID**, **JSON**, `sync_events`, `RPC`, `outbox`, `baseline` come parole nella UI Release.
- **Non** dire “**tutto sincronizzato**” se esistono voci in **Attenzione** / conflitti non risolti / passaggi bloccati.
- Summary solo **conteggi** e stati: *aggiornati*, *in attesa*, *non applicabili*, *da controllare*, *parziale*.

### Cosa mostrare nella sheet **Rivedi**

- **Dal cloud:** quante schede **possono aggiornarsi**; quante **non si possono applicare automaticamente** *(senza dettaglio tecnico)*.
- **Dal dispositivo:** quante modifiche **pronte per l’invio**; quante **in sospeso per un controllo** se il cloud è cambiato nel frattempo.
- **Prezzi:** quante **righe di prezzo** da importare / inviare; quante **richiedono un controllo** perché **non coincidono** con quanto già registrato.
- **Attenzione:** frase breve **“Su alcune schede ci sono differenze da verificare prima di procedere.”** se `conflictsPresent` o equivalente push.

### Cosa è **automatico** vs **da rivedere**

| Tipo | Automatico | Da rivedere / bloccato |
|------|------------|-------------------------|
| Product / lookup | Aggiornamento quando **identità chiara** e **nessun conflitto** | **remoteID** incoerenti / duplicati / rename incrociato |
| Supplier/Category | No-op o aggiornamento nome quando match stabile | Stesso nome ma **identità remota diversa** segnalata |
| ProductPrice | Skip idempotente, insert nuove righe senza overlap | Stessa data effetto **valore diverso** |
| Tombstone | Applicazione **coerente** quando policy execution definita | Qualsiasi dubbio su **cancellazioni** o **schede chiuse sul cloud** |

---

## 9. Micro-slice future *(execution — non attivate)*

| Slice | Contenuto |
|-------|-----------|
| **S82-a** | Tipi puri **`ConflictDecision`**, **`TemporalAuthority`**, input/output testabili senza SwiftData. |
| **S82-b** | **Conflict detector** integrato in **`SupabasePullApplyService`** / preparatori preview *(pull/apply)* con classificazione AUTO/REVIEW/BLOCK. |
| **S82-c** | **Conflict detector** in **`SupabaseManualPushPreflightService`** per superare/stati **`blockedRemoteConflict`** in modo **esplicito** e testabile. |
| **S82-d** | **ProductPrice** — unificare dedupe, conflitto valore, orphan in un **unico riepilogo** conforme a D82-05/06. |
| **S82-e** | **UI** sezione **Attenzione** / copy **Rivedi** + summary finale allineati a §8. |
| **S82-f** | **Regression/smoke** — XCTest puri + ViewModel fake; conferma nessuna regressione TASK-078…081. |

---

## 10. Test matrix *(planning)*

| Livello | Obiettivo |
|---------|-----------|
| **Unit puri** | Tabella decisionale §6-7 con casi **remoteID**, barcode, `updated_at`, tombstone, prezzo stessa chiave. |
| **ViewModel fakeable** | Stati **review** / **blocked** / **partial** senza rete. |
| **SwiftData locale** | Snapshot **stale**, **duplicate barcode**, conflitti **ProductPrice** dopo `save()`. |
| **Servizi Supabase fake / dry-run** | Preflight push + preview pull **senza** write cloud obbligatoria. |
| **Live write** | Opzionale in TASK-083 smoke — **non** obbligatorio per **Definition of Ready** sotto. |

---

## 11. Rischi

| ID | Rischio | Mitigazione |
|----|---------|-------------|
| **R82-01** | LWW implicito su campo sbagliato | D82-01, D82-02 + test puri su timestamp. |
| **R82-02** | **ProductPrice** senza `remoteID` locale → debug difficile | Valutare **`remoteRowID`** opzionale in execution ( eco TASK-080 **D80-05** ) — decisione separata in handoff execution. |
| **R82-03** | Baseline non aggiornata dopo apply prezzi | Ricalcolo **Controlla cloud** / refresh baseline — messaggio “**controlla di nuovo**”. |
| **R82-04** | Drift Android/SQL | TASK-084 + smoke; nessun claim parità in TASK-082. |
| **R82-05** | UX sovraccarica | Priorità conteggi + una frase **Attenzione**; dettagli solo in flussi futuri approvati. |

---

## 12. Anti-scope *(immutabile per questo task documentale)*

- Nessun file **Swift**, **`project.pbxproj`**, **`Localizable.strings`**, **SQL**, **Android**, **Supabase db push**, sync automatica, **Timer/BGTask/Realtime/worker/polling**, drain/cleanup outbox **live**, apertura **TASK-083/084/085** nel tracking.

---

## 13. Definition of Ready *(per futura EXECUTION — obiettivo)*

- [ ] Review utente/Claude su §6 **Policy proposta** e §7 **Decisioni** (almeno **D82-01…D82-10**).
- [ ] Conferma che **nessun** scenario critico resta “da definire in codice” senza decisione *(o esplicitamente differito a TASK-083 UX)*.
- [ ] Matrice test §10 approvata per Codex.
- [ ] Allineamento **MASTER-PLAN** / dipendenze TASK-083+ verificato al momento dell’handoff execution *(aggiornamento tracking da workflow, non in questo file salvo nota)*.

---

## 14. Definition of Done *(futura — dopo execution/review reali; **NON ora**)*

- Policy implementata nei punti di decisione pull/push/prezzi con copertura test concordata.
- Copy Release conforme a §8; nessuna promessa “tutto ok” in presenza di conflitti irrisolti.
- Documentazione task aggiornata post-review CODEX/Claude secondo workflow repo.

---

## 15. Handoff

| Campo | Valore |
|-------|--------|
| **Stato handoff** | **READY FOR PLANNING REVIEW** *(revisione documentale della policy proposta)* |
| **Execution** | **NON READY FOR EXECUTION** — nessuna modifica codice autorizzata da questo documento finché la review di planning non chiude i punti aperti. |
| **Prossima fase suggerita** | **PLANNING REVIEW** (Claude / utente) su §6–§8; poi eventuale handoff a EXECUTION Codex con task separato/override. |
| **TASK-082** | **NON DONE** — resta **ACTIVE / PLANNING** fino a chiusura formale del workflow. |

---

## Changelog file

| Data | Nota |
|------|------|
| 2026-05-08 | Creazione planning iniziale TASK-082 (solo markdown). |
