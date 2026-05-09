# TASK-082 — Conflitti e timestamp (policy cross-device iOS ↔ Supabase ↔ Android)

## Informazioni generali

| Campo | Valore |
|-------|--------|
| **Task ID** | TASK-082 |
| **Titolo** | Conflitti e timestamp — policy sicura per Product, Supplier, Category, ProductPrice |
| **File task** | `docs/TASKS/TASK-082-supabase-conflicts-timestamps-ios.md` |
| **Stato** | **DONE** |
| **Fase attuale** | **Chiusura** |
| **Tipo** | **completion / closure** |
| **Responsabile attuale** | **Claude / Reviewer** |
| **Data creazione** | 2026-05-08 |
| **Ultimo aggiornamento** | 2026-05-08 20:16 -0400 — REVIEW/FIX finale completata; fix minimi applicati; build/test/check PASS; **TASK-082 DONE / Chiusura** |
| **Ultimo agente** | Claude / Reviewer |
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

### 6.9 Normalizzazione e confronto efficiente

Per evitare falsi conflitti e ridurre lavoro inutile in execution:

- **Barcode:** confrontare sempre su valore `trim` non vuoto; non normalizzare rimuovendo zeri iniziali perché nei codici a barre sono significativi.
- **Supplier/Category name:** usare lookup canonico case-insensitive e whitespace-normalized, coerente con unique locale/remoto; mantenere però il nome display originale scelto dall’utente quando non crea conflitto.
- **Timestamp catalogo:** trattare `updated_at` remoto come stringa/Date UTC normalizzata; confronti solo dopo parsing robusto, con fail-closed se il formato non è interpretabile.
- **ProductPrice `effective_at`:** usare canonicalizzazione unica già condivisa dai servizi prezzi; stessa chiave logica significa stesso prodotto remoto, stesso `type`, stesso `effective_at` canonico.
- **Prezzi:** confronto business su valore numerico normalizzato secondo le regole già usate dall’app; se la normalizzazione non è certa, preferire **REVIEW** invece di dedupe.
- **Fingerprint:** calcolare fingerprint stabili escludendo campi puramente tecnici quando non rappresentano contenuto utente; includere invece i campi che cambiano il significato business.

### 6.10 Default UX/UI quando esiste una scelta

Per la prima execution reale, quando più comportamenti sarebbero possibili, la scelta predefinita deve favorire **sicurezza, chiarezza e coerenza con la UI attuale**:

- **Default decisionale:** se il dato può essere applicato in modo inequivocabile → **AUTO**; se può causare perdita dati o merge ambiguo → **REVIEW/BLOCK**.
- **Review sheet:** se ci sono conflitti, mostrare la sezione **Attenzione** prima delle sezioni tecniche di riepilogo; poi mostrare Cloud → Dispositivo, Dispositivo → Cloud, Prezzi.
- **Azioni primarie:** il bottone principale deve essere disponibile solo quando il piano è applicabile in modo sicuro; in caso di conflitti bloccanti, il bottone primario diventa **“Ricontrolla”** o equivalente, non **“Sincronizza tutto”**.
- **Copy:** usare frasi brevi e concrete: “Alcune schede sono cambiate anche sul cloud”, “Controlla prima di continuare”, “Prezzi non coincidenti nello stesso momento”. Evitare gergo come baseline, tombstone, remoteID, outbox.
- **Dettaglio progressivo:** mostrare prima conteggi e stato; rimandare i dettagli riga-per-riga a flussi futuri, salvo casi già presenti nell’app.
- **Coerenza visiva:** mantenere stile SwiftUI già usato in `OptionsView` / manual sync: card compatte, icone non invasive, colori semantici di sistema, nessun layout Android 1:1.
- **Scelta utente minima:** non chiedere all’utente di scegliere tra strategie tecniche di merge; quando serve una decisione reale, bloccare e guidare verso “ricontrolla / apri database / correggi manualmente”.

### 6.11 Efficienza e idempotenza operativa

La futura execution deve evitare implementazioni costose o fragili:

- **No query per riga:** preview/apply/preflight devono usare batch fetch per barcode, remoteID, supplier/category lookup e ProductPrice keys.
- **Piano immutabile:** ogni piano review deve includere fingerprint/snapshot sufficienti per rilevare stale; se stale, ricalcolare invece di mutare il piano esistente.
- **Retry sicuro:** retry = nuova preview/preflight; non riusare un piano mutativo dopo errore parziale senza validazione.
- **ProductPrice batch:** raggruppare per prodotto remoto + `type`; dedupe prima in memoria e poi affidarsi al vincolo SQL come seconda barriera.
- **Conteggi affidabili:** i summary devono distinguere `applied`, `skipped`, `blocked`, `reviewNeeded`; non sommare gli skip ai successi.
- **Outbox/eventi:** registrare eventi solo dopo mutazione riuscita o usare idempotenza `client_event_id`; evitare doppia registrazione in retry.
- **Performance UI:** la sheet di review non deve dipendere da caricamenti riga-per-riga visibili; se mancano dettagli, mostrare summary e CTA “Ricontrolla”.

### 6.12 Ordine operazioni e atomicità percepita

La futura execution deve evitare stati intermedi incoerenti tra catalogo, prezzi e baseline:

- **Ordine pull consigliato:** Supplier/Category → Product → ProductPrice → baseline locale → summary finale. Così i prodotti non puntano a lookup mancanti e i prezzi non vengono applicati prima del mapping prodotto.
- **Ordine push consigliato:** preflight completo → Supplier/Category mancanti → Product → ProductPrice → `sync_events` → refresh baseline. Se una fase fallisce, le fasi successive non partono.
- **Atomicità UI:** anche se tecnicamente la sync può essere a più step, la UI deve presentarla come piano unico: prima **Controlla**, poi **Rivedi**, poi **Applica**. Nessun apply parziale nascosto.
- **Failure parziale:** se una fase fallisce dopo alcune mutazioni riuscite, il summary deve dire chiaramente **“Sincronizzazione parziale”** e proporre **Ricontrolla**; non deve mostrare “Completato”.
- **Baseline:** aggiornarla solo dopo apply/push coerente della parte interessata; mai aggiornare baseline per righe bloccate o saltate per conflitto.
- **Prezzi correnti:** ProductPrice storico può aggiornare il prezzo corrente visualizzato solo tramite regola esplicita “ultimo prezzo per tipo”, non tramite effetto collaterale casuale dell’ordine di fetch.

### 6.13 Dirty-state locale e limiti attuali

Dato che SwiftData non ha ancora un `updatedAt` locale affidabile su tutte le entità business, la policy deve essere conservativa:

- **Dirty locale dedotto:** considerare “locale modificato” quando fingerprint corrente ≠ fingerprint baseline nota, non perché il device clock è più recente.
- **Assenza baseline:** se manca baseline ma esiste `remoteID`, trattare come stato potenzialmente ambiguo: consentire no-op/link sicuri, ma bloccare overwrite mutativi non verificabili.
- **Clock device:** non usare ora locale del telefono come vincitore di conflitto. Il clock può essere sbagliato o diverso tra device.
- **Server timestamp:** per catalogo, `updated_at` remoto resta il riferimento temporale autorevole; per prezzi, la chiave business resta `effective_at` canonico.
- **Future hardening:** se in futuro si aggiunge `localUpdatedAt`/`dirtyFields`, TASK-082 deve restare compatibile: questi campi possono migliorare la diagnosi, ma non autorizzano LWW cieco.

### 6.14 UX dettagliata per la sheet “Rivedi”

Per mantenere UI Apple-style e coerente con il resto dell’app:

- **Layout:** usare una card summary in alto con stato generale, poi sezioni compatte con disclosure: **Attenzione**, **Dal cloud**, **Dal dispositivo**, **Prezzi**, **Attività**.
- **Ordine visivo:** se ci sono conflitti/blocchi, **Attenzione** deve comparire per prima. Se non ci sono problemi, la card summary può mostrare lo stato positivo con toni neutri.
- **CTA:** usare una sola azione primaria per volta. Esempi: **Applica**, **Ricontrolla**, **Apri database**. Evitare doppie primarie affiancate.
- **Colori:** usare colori semantici di sistema (`warning`, `secondary`, `error`, `accent`) senza introdurre palette nuove.
- **Accessibilità:** ogni conflitto deve essere comprensibile anche senza colore: icona + titolo + breve descrizione testuale.
- **Copy finale:** in caso parziale usare “Alcune modifiche sono state applicate. Ricontrolla per completare.”; in caso bloccato usare “Prima di continuare serve un nuovo controllo.”
- **No dettagli tecnici:** UUID, JSON, nomi tabelle, RPC e baseline restano fuori dalla UI Release.

### 6.15 Casi edge da decidere già in planning

Questi casi devono avere default chiaro prima di passare a execution:

| Caso | Default proposto |
|------|------------------|
| Product locale attivo, remoto tombstonato, utente ha modifiche locali | **REVIEW/BLOCK**; non ripristinare remoto e non cancellare locale fisicamente. |
| Supplier/Category tombstonato remoto ma ancora usato da Product locale | **REVIEW**; non creare automaticamente un nuovo lookup con stesso nome senza preflight. |
| ProductPrice stesso `effective_at`, prezzo diverso, sorgente diversa | **REVIEW**; la sorgente non basta per decidere vincitore. |
| ProductPrice stesso prezzo ma nota/source diversa | **AUTO/SKIP** se il valore business coincide; eventuali note/source sono metadati secondari, salvo futura policy diversa. |
| Barcode uguale ma nome prodotto diverso su due device | **REVIEW**, non merge automatico campo-per-campo. |
| Nome supplier/category uguale con spazi/case diversi | **AUTO canonical link** se identità non conflittuale; preservare display name migliore già presente. |
| Preview aperta, dati cambiano prima di applicare | **STALE → Ricontrolla**. |

### 6.16 Contratto minimo per la futura execution

La futura execution deve produrre un piano unico e stabile, usato da servizi, ViewModel e UI, con questi campi concettuali:

| Campo concettuale | Significato |
|-------------------|-------------|
| `state` | Uno tra ready, needsReview, blocked, stale, partial, failed. Determina CTA e copy. |
| `canApply` | true solo se non esistono conflitti bloccanti, piano non stale e preflight valido. |
| `primaryAction` | Una sola azione primaria: Applica, Ricontrolla, Apri database o nessuna se non sicuro. |
| `counters` | Separati per toApply, applied, skipped, reviewNeeded, blocked, stale, failed. |
| `sections` | Sezioni UI ordinate: Attenzione, Dal cloud, Dal dispositivo, Prezzi, Attività. |
| `blockingReasons` | Motivi sintetici e privacy-safe, mai UUID/JSON/RPC/baseline. |
| `planFingerprint` | Snapshot/fingerprint per invalidare il piano se dati locali/remoti cambiano prima dell’apply. |

Regole:

- `canApply == false` quando `state` è needsReview, blocked, stale, partial o failed.
- `primaryAction == Ricontrolla` quando il piano è stale o partial.
- `primaryAction == Applica` solo per piano ready.
- `state == partial` è possibile solo dopo una failure durante apply/push; non durante semplice preview.
- I conteggi skipped non entrano mai in applied.
- La UI deve derivare CTA e copy da questo contratto, non da controlli sparsi nei singoli servizi.

### 6.17 Scalabilità, cancellazione e chunking

- ProductPrice e catalogo devono essere processati a blocchi ragionevoli.
- Evitare duplicazioni inutili dell’intero catalogo in memoria.
- Se l’utente annulla durante preview, non deve partire nessuna mutazione.
- Se l’utente annulla o c’è timeout durante apply, il summary successivo deve forzare Ricontrolla.
- Timeout rete = piano non affidabile; non ritentare mutazioni già partite senza nuova preview/preflight.
- Evitare percentuali di progresso finte quando il totale reale non è noto; usare messaggi di fase: “Controllo…”, “Preparazione…”, “Applicazione…”.
- Se una fase si interrompe, salvare solo summary sicuro e invalidare il piano operativo.

### 6.18 Localizzazione e copy future

Questo task non modifica Localizable.strings, ma la futura execution deve preparare copy localizzabile:

- Nessuna stringa hardcoded dentro servizi business.
- Copy tecnico separato dal copy Release user-facing.
- Testare almeno italiano, inglese, spagnolo e cinese per lunghezza CTA principali.
- Evitare parole tecniche nella UI: remoteID, baseline, tombstone, RPC, outbox, fingerprint, payload.
- Preferire testi brevi:
  - “Serve un nuovo controllo”
  - “Alcuni dati sono cambiati”
  - “Prezzi da verificare”
  - “Sincronizzazione parziale”

### 6.19 Precedenza stati e severità

Per evitare UI incoerenti quando nello stesso piano compaiono più condizioni:

| Priorità | Stato | Regola |
|----------|-------|--------|
| 1 | **failed** | Errore non recuperabile nella fase corrente; nessun apply possibile senza nuovo controllo. |
| 2 | **partial** | Alcune mutazioni sono riuscite e altre no; sempre **Ricontrolla**. |
| 3 | **stale** | Piano non più valido rispetto a snapshot/fingerprint; sempre **Ricontrolla**. |
| 4 | **blocked** | Esistono motivi bloccanti noti; nessun apply finché non risolto. |
| 5 | **needsReview** | Dati applicabili solo dopo revisione futura/esplicita; nella Release iniziale non applicare automaticamente. |
| 6 | **ready** | Nessun blocco, nessuno stale, nessun conflitto review obbligatorio. |

Regole:

- Se sono presenti più stati, vince sempre quello con priorità più alta.
- `failed`, `partial`, `stale`, `blocked`, `needsReview` implicano `canApply == false` nella Release iniziale.
- `ready` richiede contatori coerenti: `blocked == 0`, `reviewNeeded == 0`, `stale == 0`, `failed == 0`.
- La sezione **Attenzione** deve apparire quando lo stato finale non è `ready`.
- Un piano `ready` può comunque avere `skipped > 0`, purché gli skip siano idempotenti e spiegati come “già aggiornati”.

### 6.20 Owner/session/RLS safety

Dato che Supabase usa `owner_user_id` e RLS, la policy deve impedire errori cross-account:

- **Sessione assente o cambiata:** se la sessione Supabase cambia tra preview e apply, il piano diventa **stale** e deve tornare a **Ricontrolla**.
- **Owner mismatch:** qualunque riga remota con owner non coerente con la sessione corrente è **BLOCK/failed**, non va mostrata come conflitto normale.
- **Baseline per account:** baseline/fingerprint devono essere considerati validi solo per lo stesso account/sessione logica; non riusare baseline tra utenti diversi.
- **RLS error:** errori RLS o permission denied devono essere presentati come problema di accesso/sincronizzazione, non come “nessun dato da aggiornare”.
- **Privacy UI:** nessun identificativo owner/user nella UI Release; copy esempio: “Serve accedere di nuovo prima di continuare”.

### 6.21 Audit, eventi e diagnostica privacy-safe

La futura execution deve aiutare il debug senza esporre dati sensibili all’utente:

- **Debug interno:** log tecnici ammessi solo in modalità sviluppo o percorsi diagnostici, mai nella UI Release.
- **Eventi `sync_events`:** registrarli solo dopo mutazioni riuscite o con idempotenza `client_event_id`; se `changed_count` supera il limite SQL, aggregare o segmentare in più eventi coerenti.
- **Summary utente:** mostrare solo conteggi e messaggi sintetici, mai payload, SQL, RPC, UUID, owner o JSON.
- **Correlation locale:** ogni preview/apply può avere un identificatore locale non mostrato all’utente, utile per log e test.
- **No noisy audit:** skip/no-op massivi non devono generare eventi ingannevoli di “modifiche applicate”.

### 6.22 Invarianti dati e validazioni preflight

La futura execution deve validare gli invarianti prima di qualsiasi mutazione, così la policy conflitti non diventa un modo indiretto per salvare dati non validi:

| Area | Invariante |
|------|------------|
| Product | `barcode` non vuoto dopo `trim`; nessuna normalizzazione che rimuove zeri iniziali. |
| Product | `remoteID` presente deve puntare a una sola riga locale e una sola riga remota coerente con owner/sessione. |
| Supplier/Category | nome canonico non vuoto; collisioni case/whitespace risolte solo come link sicuro, non come nuova riga automatica. |
| ProductPrice | `type` ammesso solo tra valori supportati dalla policy corrente; prezzo numerico valido; `effective_at` canonico non vuoto. |
| ProductPrice | chiave logica `(remote product, type, effective_at)` unica nel piano prima di chiamare Supabase. |
| Baseline | fingerprint, `remoteUpdatedAt`, `remoteDeletedAt` e owner/sessione devono riferirsi allo stesso contesto logico. |

Regole:

- Se un invariante fallisce prima dell’apply → `state = blocked` o `failed` secondo gravità; mai tentare “best effort”.
- Gli errori di validazione locale devono essere mostrati come **“Dati da correggere”**, non come conflitti cloud.
- Gli errori di validazione remota/RLS devono restare separati dagli errori business: **accesso/sync** ≠ **dati invalidi**.
- Nessun piano può contenere due operazioni mutative contraddittorie sulla stessa chiave logica.

### 6.23 Recovery UX offline/auth

La UI deve guidare l’utente senza creare retry pericolosi:

| Situazione | Stato/CTA consigliata |
|------------|----------------------|
| Offline durante preview | `failed` o `stale`; CTA **Ricontrolla** quando torna rete. |
| Offline durante apply prima di mutazioni | `failed`; nessuna modifica dichiarata applicata. |
| Offline durante apply dopo mutazioni parziali | `partial`; CTA **Ricontrolla** e summary parziale. |
| Sessione scaduta | `blocked`/`failed`; CTA **Accedi di nuovo** se la UI auth lo supporta, altrimenti **Ricontrolla** dopo login. |
| Permission denied / RLS | `failed`; copy “Serve accedere di nuovo o verificare l’account”. |
| Timeout non deterministico | `stale`; CTA **Ricontrolla**, piano non riutilizzabile. |

UX:

- Non mostrare dialog multipli in cascata; preferire una sola card **Attenzione** con CTA principale.
- Non cancellare il piano visivamente senza spiegazione: se invalidato, mostrare “Serve un nuovo controllo”.
- In caso di auth scaduta, non proporre **Applica** finché la sessione non è valida e il piano non è ricalcolato.
- Per coerenza iOS, usare stati e CTA nella stessa sheet manual sync, non una nuova schermata separata salvo futuro task UI.

### 6.24 Cutline Release iniziale

Il planning TASK-082 contiene molte regole; la futura execution deve però restare piccola, progressiva e verificabile. La prima Release deve implementare solo ciò che serve a evitare perdita dati e CTA incoerenti.

| Area | Release iniziale | Differito |
|------|------------------|-----------|
| Conflict policy | Resolver AUTO/SKIP/BLOCK/REVIEW con precedenza stati e `canApply`. | Risoluzione manuale riga-per-riga avanzata. |
| UI | Summary compatto nella sheet manual sync, sezione **Attenzione**, CTA unica primaria. | Editor visuale completo dei conflitti. |
| Product | Bloccare conflitti identità/barcode/campi business divergenti. | Merge campo-per-campo guidato. |
| Supplier/Category | Link canonico sicuro, blocco su tombstone/identity mismatch. | Flusso dedicato di rinomina/merge lookup. |
| ProductPrice | Dedupe esatto, conflitto su stessa chiave con prezzo diverso, skip idempotente. | Tool per scegliere quale prezzo storico mantenere. |
| Offline/auth | Stati failed/partial/stale e CTA Ricontrolla/Accedi di nuovo. | Sync automatico al ritorno rete. |
| Audit | Eventi idempotenti solo dove già coerenti con TASK-081. | Dashboard diagnostica o log viewer. |

Regole cutline:

- Prima execution = **hardening del piano e summary**, non “risoluzione completa dei conflitti”.
- Se una scelta richiede UI complessa, la Release iniziale deve preferire **BLOCK/REVIEW + copy chiaro**.
- Nessun nuovo schema SQL o SwiftData solo per rendere più comoda la policy, salvo task separato esplicito.
- Nessun cambiamento Android in TASK-082; Android resta riferimento funzionale.
- Nessun tentativo di “aggiustare tutto” dentro OptionsView: mantenere componenti piccoli e testabili.

### 6.25 Guardrail anti schema drift e anti refactor nascosto

La futura execution non deve trasformare TASK-082 in un refactor ampio:

- **No schema drift nascosto:** campi come `remoteRowID`, `localUpdatedAt`, `dirtyFields` o tabelle nuove richiedono task/migration separati.
- **No riscrittura sync:** integrare nei servizi esistenti con funzioni pure e ViewModel adapter, non sostituire il flusso manual sync.
- **No copy hardcoded:** le stringhe user-facing verranno aggiunte in execution solo quando il copy finale è confermato.
- **No regressione TASK-078…081:** pull apply, push guidato, ProductPrice sync e outbox drain devono restare compatibili.
- **No nuovo stato globale singleton:** usare dipendenze/service già coerenti con architettura esistente.
- **No UI Android-style:** niente tabelle dense o schermate tecniche; la Release deve restare SwiftUI/iOS nativa.

### 6.26 Planning freeze e handoff gate

Dopo le integrazioni D82-01…D82-52, il planning è sufficientemente dettagliato. Da questo punto, TASK-082 non deve più crescere in scope salvo correzioni di incoerenze reali.

La prossima fase utile non è aggiungere nuove policy, ma trasformare questo documento in una futura execution piccola e testabile.

| Caso | Azione consigliata |
|------|--------------------|
| Nuova idea UI/UX non necessaria per sicurezza dati | Differire a TASK-083/TASK-085 o nuovo task polish. |
| Nuova regola che richiede schema SQL/SwiftData | Aprire task/migration separato, non estendere TASK-082. |
| Contraddizione tra due decisioni D82 | Correggere il planning prima di execution. |
| Mancanza di test per una decisione già presa | Aggiungere solo test matrix/DoR, non nuova policy business. |
| Dubbi su copy Release | Preparare alternative localizzabili in execution, senza cambiare comportamento. |

Criteri per autorizzare futura execution:

- Il reviewer accetta la **cutline Release iniziale**: hardening piano/summary/blocchi, non editor conflitti completo.
- Le decisioni D82-01…D82-52 non hanno contraddizioni aperte.
- Le slice future vengono ordinate come MVP: resolver/stati → invarianti → owner/session → ProductPrice dedupe → UI summary → smoke regression.
- Qualsiasi richiesta fuori cutline viene spostata fuori TASK-082.

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
| **D82-11** | La normalizzazione è parte della policy, non un dettaglio UI: barcode, nomi lookup, timestamp e prezzi devono essere confrontati in forma canonica prima di decidere AUTO/REVIEW/BLOCK. |
| **D82-12** | Quando la UX dovrebbe chiedere una scelta tecnica di merge, la Release iniziale deve preferire **BLOCK + guida chiara** invece di un dialog complesso; la risoluzione avanzata può essere task futuro. |
| **D82-13** | I piani di sync devono essere costruiti con operazioni **batch**, non con fetch per riga, per restare scalabili su cataloghi grandi e import Excel corposi. |
| **D82-14** | Un piano visto nella sheet **Rivedi** diventa non valido appena cambiano dati locali o remoti rilevanti; l’unica azione sicura è **Ricontrolla**. |
| **D82-15** | I conteggi Release devono separare chiaramente successi, skip idempotenti, conflitti e blocchi; gli skip non devono aumentare il numero di “modifiche applicate”. |
| **D82-16** | La UI di conflitto deve seguire lo stile iOS esistente: summary compatto, sezione **Attenzione**, colori semantici, testo non tecnico, nessuna schermata densa stile Android. |
| **D82-17** | L’ordine operativo deve essere lookup → product → price → baseline/eventi; applicare prezzi prima del mapping prodotto è vietato. |
| **D82-18** | La baseline si aggiorna solo per righe realmente applicate/inviate con successo; righe bloccate, stale o saltate per conflitto non devono aggiornare baseline. |
| **D82-19** | In assenza di un `localUpdatedAt` affidabile, lo stato dirty locale deriva dal confronto fingerprint corrente vs baseline, non dal clock del device. |
| **D82-20** | Un fallimento parziale non può essere presentato come successo: UI e summary devono usare stato **parziale** e CTA **Ricontrolla**. |
| **D82-21** | Per ProductPrice, differenze su `source`/`note` non devono creare conflitto se chiave logica e prezzo coincidono; prezzo diverso sulla stessa chiave resta conflitto. |
| **D82-22** | Supplier/Category tombstonati ma ancora referenziati localmente richiedono REVIEW; non creare automaticamente nuove righe con stesso nome per aggirare il tombstone. |
| **D82-23** | La sheet Rivedi deve essere accessibile: ogni stato critico deve avere testo e icona, non solo colore. |
| **D82-24** | La release iniziale non farà merge campo-per-campo di Product divergenti; se barcode/remoteID sono chiari ma campi business divergono su entrambi i lati, mostra REVIEW. |
| **D82-25** | Tutti i servizi futuri devono produrre un piano con contratto unico: stato, canApply, CTA primaria, conteggi separati, sezioni UI e fingerprint di validità. |
| **D82-26** | La UI non deve decidere autonomamente se applicare: deve derivare stato e CTA dal piano, mantenendo la logica nei servizi/ViewModel. |
| **D82-27** | Preview e preflight su dataset grandi devono supportare chunking/cancellazione senza mutazioni parziali invisibili. |
| **D82-28** | Le percentuali di progresso sono vietate se il totale reale non è noto; meglio usare messaggi di fase stabili e onesti. |
| **D82-29** | Le stringhe Release dei conflitti devono essere localizzabili e non tecniche; Localizable.strings sarà toccato solo in execution futura. |
| **D82-30** | Un piano annullato dall’utente o interrotto dalla rete non è riutilizzabile per apply: deve tornare a Ricontrolla. |
| **D82-31** | Quando un piano contiene più condizioni, lo stato finale segue la precedenza: failed → partial → stale → blocked → needsReview → ready. |
| **D82-32** | `ready` è valido solo se non ci sono blocchi, stale, failure o review obbligatoria; gli skip idempotenti sono ammessi ma non contano come applicati. |
| **D82-33** | Cambio sessione Supabase tra preview e apply invalida sempre il piano e forza Ricontrolla. |
| **D82-34** | Owner/RLS mismatch non è un conflitto business: è blocco di sicurezza/accesso e non deve diventare apply best-effort. |
| **D82-35** | Baseline e fingerprint sono validi solo nello stesso contesto account/sessione; mai riusarli tra owner diversi. |
| **D82-36** | Eventi `sync_events` e log diagnostici devono essere idempotenti, aggregabili e privacy-safe; no-op/skip non devono generare audit ingannevole. |
| **D82-37** | Ogni piano deve validare invarianti dati prima di qualsiasi mutazione; dati invalidi locali sono blocchi di validazione, non conflitti cloud. |
| **D82-38** | Nessun piano può contenere due mutazioni contraddittorie sulla stessa chiave logica; in caso contrario diventa `blocked`. |
| **D82-39** | Offline/timeout durante preview o apply invalida il piano; se l’esito delle mutazioni non è certo, lo stato finale deve essere `partial` o `stale`, mai `ready`. |
| **D82-40** | Sessione scaduta o permission denied deve produrre recovery UX esplicita, non no-op silenzioso e non “catalogo vuoto”. |
| **D82-41** | La UI Release deve separare tre famiglie di problemi: dati da correggere, conflitti cloud, accesso/sincronizzazione. |
| **D82-42** | La recovery UX deve restare dentro il flusso manual sync esistente con una sola CTA primaria, evitando nuove schermate o dialog multipli in cascade nella Release iniziale. |
| **D82-43** | La prima execution di TASK-082 deve essere una Release cutline: hardening del piano, summary, stati e blocchi sicuri; non editor completo di conflitti. |
| **D82-44** | Qualunque risoluzione che richieda scelta riga-per-riga o merge campo-per-campo resta differita; la Release iniziale usa REVIEW/BLOCK con copy chiaro. |
| **D82-45** | TASK-082 non deve introdurre schema SQL/SwiftData nuovo senza task separato; `remoteRowID`, `localUpdatedAt` e `dirtyFields` restano future hardening. |
| **D82-46** | La futura execution deve integrare funzioni pure e adapter nei servizi esistenti, non riscrivere il flusso manual sync. |
| **D82-47** | Ogni modifica UI deve restare nella sheet/flow manual sync esistente, con componenti SwiftUI piccoli e coerenti con OptionsView. |
| **D82-48** | Il completamento futuro del task richiede conferma esplicita che TASK-078…081 non sono regrediti nei loro smoke principali. |
| **D82-49** | Dopo questa planning review, TASK-082 entra in planning freeze: ulteriori aggiunte devono correggere incoerenze o test mancanti, non ampliare scope. |
| **D82-50** | La futura execution deve partire dalla sequenza MVP: resolver/stati → invarianti → owner/session → ProductPrice dedupe → UI summary → smoke regression. |
| **D82-51** | Idee UI/UX non necessarie alla sicurezza dati vanno differite a TASK-083/TASK-085 o task polish separato. |
| **D82-52** | Una contraddizione tra decisioni D82 blocca execution finché non viene risolta nel documento di planning. |

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
| **S82-g** | **UX polish conflitti** — rendere la sheet Rivedi più chiara: sezione Attenzione prioritaria, CTA coerenti, copy non tecnico, conteggi separati per applicati/saltati/bloccati. |
| **S82-h** | **Atomicità e stale plan** — applicare ordine lookup→product→price→baseline/eventi, gestire failure parziale e invalidazione piano con stato Ricontrolla. |
| **S82-i** | **Dirty-state/fingerprint hardening** — centralizzare fingerprint canonici e deduzione dirty locale senza usare clock device come vincitore. |
| **S82-j** | **Plan contract unificato** — introdurre un output unico per stato, CTA, conteggi, sezioni e fingerprint, usato da servizi e ViewModel. |
| **S82-k** | **Chunking/cancellation UX** — gestire dataset grandi, annullamento e timeout con piano invalidato e CTA Ricontrolla. |
| **S82-l** | **Copy/localizzazione Release** — preparare stringhe non tecniche per conflitti, stale, parziale e blocchi senza toccare Localizable in planning. |
| **S82-m** | **State precedence resolver** — centralizzare priorità failed/partial/stale/blocked/needsReview/ready e derivazione `canApply`. |
| **S82-n** | **Owner/session guard** — invalidare piani se cambia sessione, owner o baseline account; mappare errori RLS in copy sicuro. |
| **S82-o** | **Audit privacy-safe** — definire regole per `sync_events`, changed_count, idempotenza e diagnostica senza payload sensibili. |
| **S82-p** | **Data invariant validator** — centralizzare validazioni preflight per Product, lookup, ProductPrice, baseline e chiavi logiche duplicate. |
| **S82-q** | **Offline/auth recovery UX** — mappare offline, timeout, sessione scaduta e RLS in stati/CTA coerenti nella sheet manual sync. |
| **S82-r** | **Release cutline implementation plan** — ordinare le slice future in MVP sicuro vs differiti, evitando editor conflitti completo nella prima execution. |
| **S82-s** | **No-schema/refactor guard tests** — verificare che la policy funzioni senza nuove migration e senza riscrivere servizi TASK-078…081. |
| **S82-t** | **Planning freeze audit** — prima di execution, verificare che D82-01…D82-52 non abbiano contraddizioni e che ogni slice MVP abbia test associato. |

---

## 10. Test matrix *(planning)*

| Livello | Obiettivo |
|---------|-----------|
| **Unit puri** | Tabella decisionale §6-7 con casi **remoteID**, barcode, `updated_at`, tombstone, prezzo stessa chiave. |
| **ViewModel fakeable** | Stati **review** / **blocked** / **partial** senza rete. |
| **SwiftData locale** | Snapshot **stale**, **duplicate barcode**, conflitti **ProductPrice** dopo `save()`. |
| **Servizi Supabase fake / dry-run** | Preflight push + preview pull **senza** write cloud obbligatoria. |
| **Performance/batch** | Testare che preview/preflight non facciano fetch per riga su dataset grandi; verificare raggruppamento barcode/ProductPrice. |
| **UX state tests** | Verificare stati `canApply`, `needsReview`, `blocked`, `stale` e copy/CTA derivati senza rete. |
| **Ordering/atomicità** | Verificare ordine lookup→product→price→baseline/eventi e blocco delle fasi successive dopo errore. |
| **Partial failure** | Simulare errore dopo apply parziale e verificare summary “parziale”, baseline non aggiornata per righe non completate e CTA Ricontrolla. |
| **Dirty fingerprint** | Verificare che fingerprint invariato = no-op e fingerprint divergente + remote newer = REVIEW/BLOCK. |
| **Accessibilità UI** | Verificare che warning/error/conflitti abbiano testo e icona, non solo colore. |
| **Plan contract** | Verificare derivazione coerente di state, canApply, CTA primaria e conteggi separati. |
| **Cancellation/timeout** | Simulare annullamento e timeout durante preview/apply: nessun piano riutilizzabile, CTA Ricontrolla. |
| **Progress honesty** | Verificare che la UI non mostri percentuali quando il totale non è deterministico. |
| **Localizzazione copy** | Verificare che i testi Release previsti siano localizzabili e non tecnici. |
| **State precedence** | Verificare che più condizioni nello stesso piano producano sempre lo stato finale corretto e una sola CTA primaria. |
| **Owner/session safety** | Simulare cambio sessione, owner mismatch e RLS error: piano stale/blocked/failed, mai apply. |
| **Audit/idempotenza eventi** | Verificare che retry e no-op non generino doppio audit o conteggi ingannevoli. |
| **Invarianti dati** | Verificare barcode vuoto, lookup vuoto/collisione, ProductPrice type/effective_at/prezzo invalidi, duplicati logici nel piano. |
| **Recovery offline/auth** | Simulare offline, timeout, sessione scaduta e RLS error; verificare stati, CTA e copy senza apply pericoloso. |
| **Problem taxonomy UX** | Verificare che dati invalidi, conflitti cloud e problemi accesso/sync finiscano in sezioni/copy distinti. |
| **Release cutline** | Verificare che la prima execution blocchi/revisioni i casi complessi senza richiedere editor riga-per-riga. |
| **No schema drift** | Verificare che i test del resolver passino senza aggiungere campi o migration. |
| **Regression TASK-078…081** | Smoke pull apply, push guidato, ProductPrice sync e outbox drain dopo integrazione policy. |
| **Planning freeze audit** | Verificare coerenza D82-01…D82-52 e copertura minima test/slice prima di autorizzare execution. |
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
| **R82-06** | Falsi conflitti per normalizzazione incoerente tra servizi | Centralizzare funzioni canoniche e coprirle con unit test puri. |
| **R82-07** | Preview lenta su cataloghi/import grandi | Batch fetch, mappe in memoria, nessun caricamento riga-per-riga nella sheet. |
| **R82-08** | UI troppo tecnica per l’utente finale | Copy Release non tecnico + sezione Attenzione + CTA Ricontrolla/Apri database. |
| **R82-09** | Baseline aggiornata troppo presto dopo apply parziale | Aggiornare baseline solo per righe mutate con successo; test partial failure. |
| **R82-10** | Clock device usato implicitamente come autorità | Vietare LWW basato su ora locale; usare remote `updated_at` + fingerprint baseline. |
| **R82-11** | Tombstone aggirato creando nuova riga con stesso nome/barcode | REVIEW obbligatoria su lookup/prodotti tombstonati ancora referenziati. |
| **R82-12** | ProductPrice storico altera prezzo corrente in modo non deterministico | Regola esplicita “ultimo prezzo per tipo” e test ordering. |
| **R82-13** | Logica duplicata tra servizi e UI porta a CTA incoerenti | Contratto piano unico §6.16 e test ViewModel. |
| **R82-14** | Dataset grande blocca UI o consuma troppa memoria | Chunking, mappe minime, cancellazione sicura. |
| **R82-15** | Utente interpreta percentuale finta come progresso reale | Vietare percentuali senza totale noto; usare messaggi di fase. |
| **R82-16** | Copy conflitti troppo lungo o non localizzabile | Preparare copy Release breve e localizzabile in execution futura. |
| **R82-17** | Stati combinati producono CTA incoerenti | Resolver unico di precedenza §6.19 e test ViewModel. |
| **R82-18** | Cambio sessione/account applica piano vecchio al contesto sbagliato | Owner/session guard §6.20 e invalidazione piano. |
| **R82-19** | Errori RLS interpretati come catalogo vuoto | Mappare permission denied come blocco accesso/sync, non come no-op. |
| **R82-20** | Audit/eventi rumorosi o duplicati in retry | Idempotenza client_event_id, aggregazione e conteggi separati. |
| **R82-21** | La policy conflitti maschera dati locali invalidi | Validatore invarianti §6.22 prima di ogni mutazione. |
| **R82-22** | Due operazioni sullo stesso record logico si annullano o si sovrascrivono | Deduplicazione piano e blocco su mutazioni contraddittorie. |
| **R82-23** | Offline/timeout lascia l’utente con stato ambiguo | Recovery UX §6.23 con `partial`/`stale` e CTA Ricontrolla. |
| **R82-24** | Auth scaduta viene interpretata come assenza dati | Mappare session/RLS come problema accesso/sync, non come no-op. |
| **R82-25** | TASK-082 cresce in editor conflitti completo e rallenta la release | Cutline §6.24: prima execution solo hardening piano/summary/blocchi. |
| **R82-26** | Si introduce schema drift per risolvere problemi non necessari alla Release | Guardrail §6.25: schema/migration solo con task separato. |
| **R82-27** | Refactor sync ampio rompe TASK-078…081 | Funzioni pure + adapter nei servizi esistenti e smoke regression dedicati. |
| **R82-28** | Planning continua a crescere e ritarda execution | Planning freeze §6.26: ulteriori aggiunte solo per incoerenze o test mancanti. |
| **R82-29** | Execution parte con decisioni contraddittorie | Handoff gate §6.26 e audit D82-01…D82-52 prima di Codex. |

---

## 12. Anti-scope *(immutabile per questo task documentale)*

- Nessun file **Swift**, **`project.pbxproj`**, **`Localizable.strings`**, **SQL**, **Android**, **Supabase db push**, sync automatica, **Timer/BGTask/Realtime/worker/polling**, drain/cleanup outbox **live**, apertura **TASK-083/084/085** nel tracking.

---

## 13. Definition of Ready *(per futura EXECUTION — obiettivo)*

- [ ] Review utente/Claude su §6 **Policy proposta** e §7 **Decisioni** (almeno **D82-01…D82-52**).
- [ ] Conferma che **nessun** scenario critico resta “da definire in codice” senza decisione *(o esplicitamente differito a TASK-083 UX)*.
- [ ] Matrice test §10 approvata per Codex.
- [ ] Confermato il contratto piano §6.16: stato, canApply, CTA primaria, conteggi, sezioni e fingerprint.
- [ ] Confermate le regole chunking/cancellazione §6.17 per dataset grandi e timeout.
- [ ] Confermata la strategia copy/localizzazione §6.18 senza modificare Localizable.strings in planning.
- [ ] Confermata la precedenza stati §6.19: una sola CTA primaria e `canApply` derivato dal resolver.
- [ ] Confermata la sicurezza owner/session §6.20: cambio sessione/account invalida il piano.
- [ ] Confermate le regole audit/eventi §6.21: idempotenza, changed_count coerente e privacy-safe.
- [ ] Confermati gli invarianti dati §6.22: validazioni preflight e blocco mutazioni contraddittorie.
- [ ] Confermata la recovery UX §6.23: offline/auth/timeout/RLS con stati e CTA coerenti.
- [ ] Confermata la cutline Release iniziale §6.24: hardening piano/summary/blocchi, non editor completo conflitti.
- [ ] Confermati i guardrail §6.25: nessuno schema drift/refactor nascosto senza task separato.
- [ ] Confermato il planning freeze §6.26: niente nuovo scope prima di execution, salvo incoerenze o test mancanti.
- [ ] Confermata la sequenza MVP futura: resolver/stati → invarianti → owner/session → ProductPrice dedupe → UI summary → smoke regression.
- [ ] Confermati i default UX/UI §6.10: quando esiste una scelta ambigua, la Release preferisce blocco guidato e ricontrollo, non merge tecnico manuale.
- [ ] Confermata la strategia efficienza §6.11: batch fetch obbligatorio per preview/preflight/apply.
- [ ] Confermato l’ordine operativo §6.12: lookup → product → price → baseline/eventi, con failure parziale esplicita.
- [ ] Confermati i limiti dirty-state §6.13: fingerprint/baseline come fonte locale, nessun LWW basato su clock device.
- [ ] Confermata UX accessibile §6.14: testo + icona per stati critici, CTA unica primaria, nessun dettaglio tecnico in Release.
- [ ] Confermati i casi edge §6.15 prima di autorizzare execution.
- [ ] Allineamento **MASTER-PLAN** / dipendenze TASK-083+ verificato al momento dell’handoff execution *(aggiornamento tracking da workflow, non in questo file salvo nota)*.

---

## 14. Definition of Done

- Policy implementata nei punti di decisione pull/push/prezzi con copertura test concordata.
- Copy Release conforme a §8; nessuna promessa “tutto ok” in presenza di conflitti irrisolti.
- Documentazione task aggiornata post-review CODEX/Claude secondo workflow repo.

---

## 15. Handoff

| Campo | Valore |
|-------|--------|
| **Stato handoff** | **DONE / Chiusura** *(2026-05-08 20:16 -0400; review/fix finale completata e verificata)* |
| **Execution** | **COMPLETATA** — implementati resolver/stati, invarianti, owner/session guard, ProductPrice dedupe/conflict, UI summary e smoke regression TASK-078…081 nel perimetro Release iniziale. |
| **Review finale** | **PASS con fix minimi applicati** — chiusura autorizzata da richiesta utente esplicita. |
| **TASK-082** | **DONE / Chiusura** — nessun task successivo aperto da questo handoff. |

## Execution (Codex)

### Avvio EXECUTION — 2026-05-08 19:35 -0400

- **Obiettivo compreso:** implementare solo la cutline Release iniziale di TASK-082, trasformando il planning approvato in un piano unico/stati/CTA/conteggi privacy-safe, invarianti preflight, guard owner/session/RLS, dedupe/conflitto ProductPrice, UI summary nella sheet manual sync e regression smoke TASK-078…081.
- **Gate handoff:** letti `docs/MASTER-PLAN.md`, questo file task e i task dipendenti `TASK-078`, `TASK-079`, `TASK-080`, `TASK-081`; **D82-01…D82-52** verificati senza contraddizioni operative per la cutline Release iniziale.
- **File target da leggere prima del codice:** modelli SwiftData, `SupabasePullPreviewService`, `SupabasePullApplyService`, `SupabaseManualPushPreflightService`, `SupabaseProductPriceApplyService`, baseline reader/models, `SupabaseManualSyncViewModel`, `OptionsView`, integrazione outbox `sync_events` TASK-081, test Supabase sync esistenti e schema Supabase locale in sola lettura.
- **Piano minimo:** 1) inventario codice/schema; 2) introdurre resolver/contract puro e test; 3) collegare invarianti e guard conservativi ai piani esistenti senza refactor ampio; 4) rafforzare ProductPrice dedupe/conflict; 5) aggiornare summary/CTA UI con localizzazioni; 6) eseguire build/test/smoke e aggiornare tracking.
- **Vincoli confermati:** nessun editor completo conflitti, nessun merge campo-per-campo, nessuna migration SQL, nessun nuovo campo SwiftData, nessuna modifica Android, nessun TASK-083/TASK-084/TASK-085, nessun refactor ampio del sync.

### Completamento EXECUTION — 2026-05-08 20:02 -0400

- **Implementato:** contratto unico `SupabaseSyncPlan` con stati `ready/needsReview/blocked/stale/partial/failed`, `canApply`, CTA primaria, conteggi separati, sezioni Release, motivi privacy-safe e fingerprint; resolver puro con precedenza **failed → partial → stale → blocked → needsReview → ready**.
- **Invarianti dati:** snapshot locale arricchito con barcode prodotto vuoti e nomi lookup vuoti; `SupabasePullApplyService` blocca apply su dati locali invalidi, remoteID duplicate e collisioni lookup prima di qualsiasi mutazione.
- **Owner/session guard:** il piano apply catalogo conserva owner/sessione al momento preview e invalida se l’account cambia prima dell’apply; mismatch owner su ProductPrice remoto è trattato come problema accesso/sync e non come conflitto business.
- **ProductPrice dedupe/conflict:** rafforzato fail-closed su owner mismatch; dedupe remota push non usa righe di altro owner e marca il piano non sicuro.
- **UI Release:** sheet manual sync aggiornata con summary card, sezione Attenzione prioritaria quando il piano non è `ready`, CTA unica derivata dal piano/ViewModel (`Applica`, `Ricontrolla`, `Apri database`, `Accedi di nuovo`) e copy breve localizzato IT/EN/ES/zh-Hans senza UUID/JSON/RPC/baseline/outbox/fingerprint.
- **Outbox/audit:** nessun cambio SQL o drain; compatibilità TASK-081 preservata, nessun audit rumoroso aggiunto per skip/no-op.
- **File Swift toccati:** `AppNavigationNotifications.swift`, `ContentView.swift`, `OptionsView.swift`, `SupabaseManualSyncReleaseFactory.swift`, `SupabaseManualSyncViewModel.swift`, `SupabaseSyncPlanContract.swift`, `SupabasePullPreviewModels.swift`, `SwiftDataInventorySnapshotService.swift`, `SupabasePullApplyService.swift`, `SupabaseProductPriceApplyService.swift`, `SupabaseProductPricePushDryRunService.swift`.
- **File test toccati:** `SupabaseSyncPlanContractTests.swift`, `SupabaseManualSyncViewModelTests.swift`, `SupabasePullApplyServiceTests.swift`, `SupabaseProductPriceApplyServiceTests.swift`, `SupabaseProductPricePushDryRunServiceTests.swift`.
- **Localizzazioni toccate:** `it.lproj/Localizable.strings`, `en.lproj/Localizable.strings`, `es.lproj/Localizable.strings`, `zh-Hans.lproj/Localizable.strings`.
- **Check eseguiti:** ✅ build Release iPhone 16e iOS 26.2 PASS; ✅ XCTest mirati plan/ViewModel/pull apply/ProductPrice PASS; ✅ `SupabaseManualSyncReleaseUITests` PASS; ✅ `LocalizationCoverageTests` PASS; ✅ `plutil -lint` Localizable PASS; ✅ `git diff --check` PASS; ✅ no schema drift iOS (`Models.swift` invariato, nessun file SQL nel repo iOS); ✅ nessuna modifica Android.
- **Warning residui:** build Release PASS con warning preesistenti/out-of-scope in `SyncEventOutboxDrainService.swift` / tooling AppIntents; warning ProductPrice nel file toccato rimosso con `nonisolated` su costante.
- **Rischi residui / differiti:** simulator/manual UI non eseguito perché non richiesto esplicitamente dal task; editor completo conflitti, merge campo-per-campo, `remoteRowID`, `localUpdatedAt`, `dirtyFields`, nuove migration e parità Android restano fuori cutline.

## Handoff post-execution (Codex)

- **Stato:** READY FOR REVIEW.
- **Responsabile prossimo:** Claude / Reviewer.
- **Motivo:** cutline Release iniziale implementata e verificata; secondo workflow Codex non marca TASK-082 DONE e non passa direttamente a Chiusura.
- **Richiesta review:** validare coerenza D82-01…D82-52 rispetto alla patch, accettare o chiedere FIX mirato; non aprire TASK-083/TASK-084/TASK-085 da questo handoff.

---

## Review finale Claude

### Chiusura — 2026-05-08 20:16 -0400

- **Esito review:** **FIX APPLICATI + DONE**. Review completa su diff e codice reale: tracking, contratto `SupabaseSyncPlan`, invarianti dati, owner/session/RLS guard, ProductPrice dedupe/conflict, UI/UX Release, localizzazioni, performance e regressioni TASK-078…081.
- **Fix minimi applicati:** guard apply locale più fail-closed quando owner/sessione non era catturata o cambia tra review e apply; ProductPrice owner/source error classificati come accesso/sync invece che conflitto business; CTA **Accedi di nuovo** usata solo se supportata, con fallback **Ricontrolla**; test mirati aggiunti.
- **Coerenza cutline:** rispettata. Nessun editor completo conflitti, nessun merge campo-per-campo, nessuna risoluzione avanzata riga-per-riga, nessun nuovo schema SQL/SwiftData.
- **Verifiche:** ✅ build Release iPhone 16e iOS 26.2 PASS; ✅ XCTest mirati `SupabaseSyncPlanContractTests`, `SupabaseManualSyncViewModelTests`, `SupabasePullApplyServiceTests`, `SupabaseProductPriceApplyServiceTests`, `SupabaseProductPricePushDryRunServiceTests` PASS; ✅ `SupabaseManualSyncReleaseUITests` PASS; ✅ `LocalizationCoverageTests` PASS; ✅ `plutil -lint` Localizable PASS; ✅ duplicate localization scan PASS; ✅ `git diff --check` PASS.
- **Warning residui:** warning build preesistenti/out-of-scope in `SyncEventOutboxDrainService.swift` (`defaultSendingRecoveryScanLimit` actor isolation) e metadata AppIntents; non introdotti da TASK-082 review.
- **Conferme anti-scope:** nessuna migration SQL; nessuna modifica Android; nessun nuovo campo SwiftData; `Models.swift` e `project.pbxproj` invariati; nessun delete fisico; nessun nuovo task TASK-083/TASK-084/TASK-085 aperto.
- **Differiti fuori scope:** editor conflitti completo, merge campo-per-campo, `remoteRowID`, `localUpdatedAt`, `dirtyFields`, parity Android e smoke E2E live restano candidati futuri nei task previsti, non parte di TASK-082.
- **Tracking:** TASK-082 marcato **DONE / Chiusura** e `MASTER-PLAN` riallineato a **IDLE**. Chiusura eseguita su richiesta utente esplicita di review finale.

---

## Changelog file

| Data | Nota |
|------|------|
| 2026-05-08 | Creazione planning iniziale TASK-082 (solo markdown). |
| 2026-05-08 | Integrazione planning review: normalizzazione, default UX/UI, efficienza batch, decisioni D82-11…D82-16, slice S82-g. |
| 2026-05-08 | Seconda integrazione planning review: atomicità operativa, dirty-state/fingerprint, UX accessibile, casi edge, decisioni D82-17…D82-24. |
| 2026-05-08 | Terza integrazione planning review: fix markdown, contratto piano unico, chunking/cancellazione, progress UI onesta, copy/localizzazione, decisioni D82-25…D82-30. |
| 2026-05-08 | Quarta integrazione planning review: precedenza stati, owner/session/RLS safety, audit/eventi privacy-safe, decisioni D82-31…D82-36. |
| 2026-05-08 | Quinta integrazione planning review: invarianti dati/preflight, recovery UX offline/auth, decisioni D82-37…D82-42. |
| 2026-05-08 | Sesta integrazione planning review: cutline Release iniziale, guardrail anti schema drift/refactor, decisioni D82-43…D82-48. |
| 2026-05-08 | Settima integrazione planning review: planning freeze, handoff gate, sequenza MVP futura, decisioni D82-49…D82-52. |
| 2026-05-08 | Execution cutline Release iniziale completata da Codex; handoff READY FOR REVIEW, TASK-082 NON DONE. |
| 2026-05-08 | Review/fix finale completata; fix minimi applicati; TASK-082 DONE / Chiusura; MASTER-PLAN riallineato a IDLE. |
