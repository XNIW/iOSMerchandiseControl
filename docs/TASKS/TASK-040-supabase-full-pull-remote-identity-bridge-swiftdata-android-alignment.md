# TASK-040: Supabase full pull + remote identity bridge SwiftData allineato Android/Supabase

## Informazioni generali
- **Task ID**: TASK-040
- **Titolo**: Supabase full pull + remote identity bridge SwiftData allineato Android/Supabase
- **File task**: `docs/TASKS/TASK-040-supabase-full-pull-remote-identity-bridge-swiftdata-android-alignment.md`
- **Stato**: DONE
- **Fase attuale**: Chiusura
- **Responsabile attuale**: Utente / Chiusura
- **Data creazione**: 2026-05-05
- **Ultimo aggiornamento**: 2026-05-05 *(review APPROVED_FIXED_DIRECTLY; fix diretto lookup remoteID; build/test/anti-scope PASS; TASK-040 chiuso DONE; TASK-039 resta DONE)*
- **Ultimo agente che ha operato**: Codex / Reviewer+Fixer

> **Planning polish — Cursor:** Definition of Ready Slice A, acceptance criteria Slice A, rollback/recovery SwiftData metadata, evidence checklist Slice A Execution; **nessuna** EXECUTION.

> **Planning refinement — Cursor**: integrazione sicurezza/efficienza pre-execution (checklist gate, metadata embedded vs ref Room-like, unicità `remoteID`, idempotenza, performance ~20k, policy date/privacy log, struttura Sezioni Options); **nessuna** EXECUTION; **TASK-039** **DONE** invariato.

## Dipendenze
- **Dipende da**: TASK-039 (DONE — preview → apply locale controllato), TASK-038 (DONE — Google OAuth, client session-aware), TASK-035 (DONE — dry-run pull preview), TASK-034 (DONE — foundation DTO readonly), TASK-033 (DONE — audit schema/mapping)
- **Riferimenti funzionali/backend (Android, non codice da copiare)**: TASK-067 (DONE ACCEPTABLE), TASK-068 (PARTIAL), TASK-069 (DONE), TASK-070 (DONE), TASK-071 (DONE)
- **Sblocca**: EXECUTION futura — full pull affidabile, bridge `remoteId` SwiftData, estensioni UX/tests; **non** sblocca push/sync automatico (task successivi)

## Scopo
Produrre **solo planning operativo** (nessuna modifica Swift nel turno corrente) per: (1) superare il limite pratico di cataloghi grandi su iOS tramite fetch completo / paginazione controllata e budget configurabili; (2) introdurre un **bridge stabile** tra UUID remoti Supabase e modelli SwiftData `Product` / `Supplier` / `ProductCategory`; (3) allineare semanticamente i modelli iOS al contratto dati già usato da Android + Postgres `inventory_*`; (4) preparare il terreno per un futuro push manuale **tombstone-compliant** senza implementarlo; (5) documentare rischi di allineamento con `record_sync_event` / `PayloadValidation` e con Android TASK-068 PARTIAL.

## Contesto obbligatorio
- Repository iOS: `https://github.com/XNIW/iOSMerchandiseControl` (fonte codice verificata in workspace locale).
- **TASK-039 iOS è DONE** e **non va riaperto** — resta valida Strategia A su preview unsafe; TASK-040 pianifica il *next step* senza mutare i criteri DONE di TASK-039.
- Android è **riferimento funzionale e di integrazione Supabase**, non sorgente di copy-paste.
- Supabase è backend condiviso; schema verificato tramite migrazioni in `MerchandiseControlSupabase/supabase/migrations/` (workspace locale utente).

## Non incluso (OUT OF SCOPE esecuzione/planning vincolante)
- Nessuna scrittura Supabase; nessun push remoto; nessun sync automatico/background/realtime; nessun delete locale da tombstone remoto in questa fase.
- Nessun apply di `ProductPrice` remoto su SwiftData (resta come TASK-039 / follow-up dedicato).
- Nessuna chiamata `record_sync_event` da iOS in execution.
- Nessuna migration SQL live, `db push`, modifica RLS/policy, redesign UI generale.
- **Questo turno**: nessun file Swift, `pbxproj`, `plist`, `Package.resolved` modificato.

---

## 1. Stato attuale iOS

### TASK-034: foundation Supabase readonly
- SPM Supabase Swift, `SupabaseConfig` plist sicura, `SupabaseInventoryService` actor read-only (`fetchProductsPage`, `fetchSuppliersPage`, `fetchCategoriesPage`, `fetchProductPricesPage`), DTO in `SupabaseInventoryDTOs.swift` con `CodingKeys` allineati a `inventory_*`.

### TASK-035: dry-run pull preview
- `SupabasePullPreviewService.generatePreview` + `SupabasePullPreviewDiffEngine` → `SyncPreview` conservativo; nessun apply.

### TASK-038: Google Auth + session-aware + preview auth-gated
- `SupabaseAuthService` / `SupabaseClientProvider`, preview solo con sessione valida; nessun fallback anonimo post-TASK-038.

### TASK-039: preview → apply locale SwiftData controllato
- `SupabasePullApplyService` (`prepareApplyPlan` / `apply(plan:)`) solo locale; payload applicabile da preview; guard su partial/sourceErrors/priceHistoryIncomplete/conflitti/stale; **nessun** `ProductPrice` storico remoto; **nessuna** scrittura Supabase.

### Limiti residui (motivazione TASK-040)
| Limite | Evidenza codice / comportamento |
|--------|--------------------------------|
| **Cap / pull parziale** | `SupabasePullPreviewService` usa `maxCatalogRows` default **10 000**, `maxProductPriceRows` **2 000**, `pageSize` max 1000; `fetchPaged` si ferma a `reachedCap` → `partialCatalog` + `sourceErrors` → apply bloccato (Strategia A TASK-039). |
| **Remote identity non stabile** | `Models.swift`: `Product` ha solo `barcode` univoco; `Supplier` / `ProductCategory` solo `name` univoco — **nessun** campo `remoteId` / `remoteUpdatedAt` / `deletedAt` locale. I DTO remoti espongono già `id` (UUID) e `updated_at` / `deleted_at`. |
| **Push non sicuro** | Nessun outbox, nessun dirty marking iOS; bridge remoto assente → push futuro richiede identità stabile + contratto eventi (fuori TASK-040). |
| **ProductPrice remoto non applicato** | Deciso esplicitamente in TASK-039; price history remota spesso incompleta per cap. |
| **Nessun sync automatico** | Invariato; TASK-040 non lo introduce. |

---

## 2. Stato attuale Android / Supabase

### Sintesi da `MerchandiseControlSplitView/docs/MASTER-PLAN.md`
| Task | Stato | Nota sintetica |
|------|--------|------------------|
| **TASK-067** | DONE **ACCEPTABLE** | Dirty marking delta-safe post full import; log/UX `CloudSyncIndicator`; limiti smoke live su dataset massimo. |
| **TASK-068** | **PARTIAL** | Bulk product push lato client (batch 100, fallback 50/25/singolo), test JVM; **validazione live** no-op / bulk su delta reale ancora pending. |
| **TASK-069** | DONE | Audit diagnostico outbox / `PayloadValidation` / head-of-line; nessuna modifica schema. |
| **TASK-070** | DONE | Fix retry outbox head-of-line (`listPendingRetryable`), log privacy-safe; nessun cleanup outbox. |
| **TASK-071** | DONE | Documentato mismatch: RPC `record_sync_event` impone `p_changed_count <= 1000` mentre Android può inviare eventi compatti con `changed_count` reale > 1000 → **PayloadValidation**; follow-up backend consigliato (es. TASK-072). |

### Cosa iOS deve **apprendere** dal modello Android (concettuale)
- **Bridge locale ↔ remoto**: Android usa tabelle Room `product_remote_refs`, `supplier_remote_refs`, `category_remote_refs`, `product_price_remote_refs` (UUID remoto ↔ id locale + revisioni sync).
- **Dirty / pending**: marking per push incrementale; ordine operazioni (catalogo prima di prezzi).
- **Tombstone / `deleted_at`**: catalogo Postgres con partial UNIQUE + trigger anti-update post-tombstone (TASK-019 Supabase); Android applica policy documentata in task Supabase (delete inbound con correlazione `remoteId`).
- **`updated_at`**: confronto per conflict / stale lato client.
- **`sync_events`**: tabella remota append-only (dominio `catalog` | `prices`); lettura consentita RLS; **scrittura** via RPC `record_sync_event` con vincoli di payload.
- **Outbox**: `sync_event_outbox` è **tabella Room su device Android**, non risolta in migrazioni Postgres del repo Supabase locale analizzato.
- **Bulk/batch limits**: batch size e fallback (TASK-068); classificazione errori e retry.

### Cosa iOS **non** deve ancora implementare (TASK-040 esplicito)
- Push catalogo/prezzi; outbox; registrazione `sync_events`; chiamata `record_sync_event`; bulk upload; realtime; cleanup code backend.

---

## 3. Obiettivo tecnico
1. **Pull completo affidabile**: paginazione fino a esaurimento dataset (o budget massimo configurabile esplicitamente dall’utente/DEBUG), con stato macchina **complete vs partial** ben definito.
2. **Bridge `remoteId` stabile** su SwiftData per allineare identità con `inventory_* .id` (UUID) senza rompere il vincolo business su `barcode`.
3. **Compatibilità dati** con mapping Android/Supabase: stessi concetti di supplier/category per UUID remoto + nome normalizzato.
4. **Preparazione push manuale futuro**: campi/metadata minimi affinché un push non duplichi righe né confonda `remoteId`; **nessun** implement push in TASK-040 execution.
5. **Zero scritture remote** e zero modifiche schema in questa linea di lavoro fino a nuovo task esplicito.

---

## Execution slicing futura

> **Tutte le slice sono future e non autorizzate in questo turno.** Richiedono **approvazione esplicita utente** e transizione formale **PLANNING → EXECUTION**. Dopo la presente integrazione, **TASK-040 resta ACTIVE / PLANNING**.

| Slice | Contenuto pianificato | Esclusioni esplicite |
|-------|------------------------|----------------------|
| **A — Remote identity metadata SwiftData** | Aggiunta campi opzionali (decisione tipi §6); migrazione SwiftData leggera; test container in-memory per modelli. | **Nessun** cambio al comportamento di fetch remoto “full pull” né rifattor grande di preview/apply: solo persistenza metadati identità dove serve alla migrazione. |
| **B — Full pull / paginazione** | Fetch fino a **complete** o stop **partial** con budget configurabile; stato progressivo (`idle`, `loadingPage`, …); ordinamento deterministico sulle query (§5). | Nessuna RPC snapshot server-side; nessun write Supabase. |
| **C — Apply / link remote identity** | Link record locali esistenti (barcode ↔ `remoteID`); gestione conflitti **`remoteIdConflict`**, **duplicateBarcode**, **`missingRemoteReference`**; ordine **supplier/category** prima dei **product**. | Coerente con policy TASK-039 su apply; nessun push. |
| **D — UX DEBUG + localizzazioni** | Ritocchi in **`OptionsView`** (§9): `Section` / `Form` / `List`, `Label` + `ProgressView`, CTA con motivo disabilitazione; stringhe **IT / EN / ES / ZH-Hans**. | Nessun redesign generale di Options; nessuna azione distruttiva. |
| **E — Push manuale tombstone-compliant** | *Fuori perimetro TASK-040.* Task dedicato successivo; TASK-040 fornisce solo prerequisiti (identità, lettura `deleted_at`, taxonomy). | Push, `record_sync_event`, outbox, dirty globale — **vietati** in TASK-040. |

Ordine consigliato in una futura execution: **A → B → C → D**. La slice **E** è un **task separato**.

> **Prossimo passo consigliato (quando sarà autorizzata la prima EXECUTION):** solo **Slice A**. **Non** miscelare B/C/D nella stessa esecuzione iniziale.

---

## Definition of Ready — futura Slice A

> La **prima** EXECUTION consigliata sotto TASK-040 è **esclusivamente** **Slice A — Remote identity metadata SwiftData**. Lo scope **non** comprende Slice **B**, **C**, **D**, né **E**.

Checklist **Ready** (futura, non eseguita in questo polish):

- [ ] **Autorizzazione**: utente approva esplicitamente **PLANNING → EXECUTION** e conferma che l’incremento è **solo Slice A** (nessun creep su B/C/D).
- [ ] **Repo aggiornata**: working tree riallineata a **`https://github.com/XNIW/iOSMerchandiseControl`** (o branch/commit concordati) prima di modificare i sorgenti.
- [ ] **`Models.swift`**: rilettura e stati attuali (container, version) **prima** di applicare diff.
- [ ] **Deployment target** / **SwiftData** / Xcode: versioni note e coerenti con il modello persistito in produzione/beta.
- [ ] **Comportamento `UUID?` / `Date?`**: verificato con spike o documentazione Apple per il target minimo.
- [ ] **`@Attribute(.unique)` su optional**: rischio **chiuso** (test) o **evitato** — vedi § *Policy unicità `remoteID`*.
- [ ] **`docs/MASTER-PLAN.md`**: conferma **stato ACTIVE**, **TASK-040**, **PLANNING** **prima** del cambio fase nel file task.
- [ ] **Perimetro tecnico Slice A**: nessuna modifica a pull/pagination, apply, UX obbligatoria, servizi remoti — conforme alla tabella *Execution slicing futura*, riga Slice A.

---

## Acceptance criteria futura — Slice A

> Contratto per **revisione post–Slice A**. **Non** equivalgono ai CA di planning §12; non marcare DONE qui finché non c’è execution.

Post–Slice A, l’incremento è accettabile se:

- Sono aggiunti **solo** campi opzionali embedded:
  - `Product.remoteID`, `Product.remoteUpdatedAt`, `Product.remoteDeletedAt`
  - `Supplier.remoteID`, `Supplier.remoteUpdatedAt`, `Supplier.remoteDeletedAt`
  - `ProductCategory.remoteID`, `ProductCategory.remoteUpdatedAt`, `ProductCategory.remoteDeletedAt`
- **Nessuna** tabella SwiftData ref separata (`ProductRemoteRef`, …).
- **Nessun** cambio di comportamento a **pull** / **paginazione** / **preview** / **apply** (nessuna write remota, nessun apply remoto).
- **Nessuna** scrittura Supabase; nessuna UI obbligatoria (ritocchi UI restano **fuori** da Slice A salvo necessità **minima** accettata in review).
- **Migrazione additiva** compatibile con store esistente (campi opzionali = default “assente” per dati vecchi).
- **XCTest** / SwiftData **in-memory**: persistenza e round-trip dei nuovi campi.
- **Duplicato `remoteID` non-nil**: gestito **applicativamente** o via test pianificati — **non** tramite `@Attribute(.unique)` su optional **non verificato**.
- **Build Debug** PASS.
- **Build Release** PASS.
- **XCTest** PASS intero suite rilevante.
- **Localizzazioni**: non toccate **salvo** necessità scoperta in review (improbabile in Slice A).
- **`git diff --check`** PASS.

---

## Rollback / recovery planning per SwiftData metadata

Senza implementare ora:

1. Tutti i campi pianificati sono **opzionali** → migrazione **additiva**; **non** distruttiva per barcode/nome/fornitori esistenti.  
2. **Nessuna** perdita dati locale attesa sul percorso felice; in caso di fallimento migrazione in ambiente dev/test → **fermare** l’EXECUTION slice A, aggiornare planning o passare a **FIX** prima di proseguire con B/C/D.  
3. **Nessuno** reset automatico del ModelContainer / “erase database” come mitigazione di default.  
4. Prima di una futura release con schema SwiftData modificato → valutare **backup/export** manuale se il dataset locale è sensibile (policy utente/documentazione Options, fuori TASK-040 se non già previsto).

---

## Evidence checklist futura — Slice A Execution

Quando Slice A sarà autorizzata, **l’executore documenta nel file TASK-040 § Execution** (non ora):

| Evidenza | Richiesto |
|----------|-----------|
| Commit hash / ambito branch | PASS/FAIL |
| Elenco **file Swift** modificati | elenco |
| Conferma: **zero** modifiche SQL / Supabase repo / plist progetto esterni al minimo Slice A | sì/no |
| Conferma: **nessuna** write Supabase (grep / review) | sì/no |
| Build Debug | PASS/FAIL |
| Build Release | PASS/FAIL |
| XCTest | PASS/FAIL |
| SwiftData in-memory mirato Slice A | PASS/FAIL o N/A motivato |
| `git diff --check` | PASS/FAIL |
| Grep anti-scope (nessuna nuova occorrenza operativa dove vietato): `record_sync_event`, pattern write client Supabase (`insert|update|upsert|delete` su percorsi remoto dove non esisteva), `outbox`, `dirty` marking push | PASS/FAIL |
| Rischi residui | bullet |

---

## Pre-Execution gates / verifiche obbligatorie prima del codice

> Checklist **futura** — da svolgere **prima** della prima modifica Swift quando si aprirà **EXECUTION**. **Non eseguita in questo turno.**

- [ ] **Schema live vs repo**: confronto read-only schema hosted Supabase (`information_schema` / query probe / dashboard) con migrazioni in `MerchandiseControlSupabase/supabase/migrations/` — documentare drift (cfr. TASK-033 G-08/G-09).
- [ ] **DTO ↔ colonne**: verifica che `SupabaseInventoryDTOs` coincidano con `inventory_products`, `inventory_suppliers`, `inventory_categories` (nomi `CodingKeys`, nullability, tipi; incluso `deleted_at`).
- [ ] **Supabase Swift API**: verifica sintassi reale per **`.order(...)`** e range pagination (`from`/`to`) sulla versione SPM in uso; catturare richiesta HTTP di prova se utile.
- [ ] **`Models.swift`**: stato attuale SwiftData, `ModelContainer`, eventuali version; impatto migrazione campi opzionali.
- [ ] **`UUID?` / `Date?`**: spike o conferma documentazione Apple — persistenza attesa per attributi opzionali sui modelli target.
- [ ] **`@Attribute(.unique)` opzionale**: **non** adottare per `remoteID` senza test dedicati — vedi § *Policy unicità `remoteID`*.
- [ ] **`OptionsView`**: confermare presenza sezione **Supabase DEBUG** (TASK-035/038/039) e punti di estensione **Form** / `Section`.
- [ ] **`docs/MASTER-PLAN.md` iOS**: task attivo **TASK-040**, fase **PLANNING**, stato globale **ACTIVE** — vedi § *MASTER-PLAN alignment check*.

---

## Decisione architetturale: embedded remote metadata vs ref tables SwiftData

| Approccio | Decisione TASK-040 |
|-----------|---------------------|
| **Metadati embedded opzionali** (`remoteID`, `remoteUpdatedAt`, `remoteDeletedAt` su `Product` / `Supplier` / `ProductCategory`) | **Adottato** |
| **Tabelle SwiftData dedicate** (`ProductRemoteRef`, `SupplierRemoteRef`, `CategoryRemoteRef`, …) | **Non introdotte in TASK-040** |

**Motivazione**  
1. Android usa **Room ref tables** nel contesto di **dirty marking**, **outbox**, **push** — fuori perimetro iOS attuale.  
2. iOS (TASK-040) deve **pull affidabile**, **apply locale**, **prevenire duplicati** — i campi embedded sono **sufficienti** e più **semplici**.  
3. **Ref tables** restano **candidati** se un task futuro introdurrà push/outbox/revisioni come su Android.

**Rischio**: sync iOS molto complesso → possibile **migrazione** verso ref-dedicated in **task separato** (non ipotecare ora tutta l’UI).

---

## Policy unicità `remoteID`

- **Default**: **non** porre `@Attribute(.unique)` su **`remoteID: UUID?`** senza **prove** SwiftData su optional unique (comportamento versione OS richiesta dall’app).  
- **Enforcement raccomandato** finché non provato il constraint nativo:
  - query/fetch che verificano **al massimo un** `Product` con dato `remoteID` non-nil per UUID;
  - idem `Supplier` / `ProductCategory`.  
- Se in EXECUTION il vincolo unique risulta **sicuro** e testato → **valutare** `@Attribute(.unique)` con documentazione.  
- **Test pianificati**: duplicazione intenzionale stesso `remoteID` non-nil → **errore/conflitto** (allineato taxonomy; nessun silenzioso merge).

---

## Idempotenza pull / apply / relink

**Regole progettuali (execution)**  
1. Ripetere lo **stesso full pull completo** due volte (stesso stato remoto) **non** crea duplicati di `Product`/`Supplier`/`Category`.  
2. Prodotto con `remoteID` già impostato e coerente col remoto → **stabile** tra apply successivi.  
3. Supplier/category già creati e referenziati → **non ricreati** (lookup per `remoteID` + regole nome).  
4. **`linkOnly`**: secondo apply con stesso stato → **no-op** sul legame (nessun duplicato metadata).  
5. Se `remoteUpdatedAt` (o fingerprint campo) **invariato** → **nessun update** inutile.  
6. **Pull partial**: **non** aggiornare `remoteID` in modo **non deterministico** da dataset incompleto — preferire **nessuna modifica** agli ID persistiti rispetto a un full complete successivo (policy da rendere esplicita in codice + test).

**Test pianificati**  
- Catena: full pull **A** → apply → full pull **A** → apply ⇒ **nessun duplicato**, **nessun campo mutato** oltre idempotenza attesa.  
- `linkOnly` prima esecuzione → seconda **no-op** sul link.  
- Due entità con **`remoteID` duplicato non-nil** ⇒ conflitto / `sourceError`.

---

## Performance / memoria / dataset grande

- **Ordine di grandezza**: catalogo **~20k prodotti** (riferimento dataset Android grande).  
- **Page size**: **500** default, **1000** tetto (già in codice).  
- **Progress / UX**: aggiornamenti per **pagina** o **aggregati** — **mai** throttle per singola riga in UI principale.  
- **Preview**: solo **summary**, **conteggi**, lista **conflitti limitata** (es. max 5 esempi + “altri N”) o secondo schermata **dettaglio** piggyback — **no** `List` di 20k righe dettagliate.  
- **Memoria**: se accumulo array in RAM supera soglia → **`partial`** o **`failed`** con messaggio chiaro; **nessun** motore di streaming obbligatorio in TASK-040 — solo **guardrail** e possibile follow-up (chunked processing).  
- **Test**: smoke memoria con fixture grande oppure limite artificiale budget in DEBUG.

---

## Date parsing / timezone policy

- Ingresso: stringhe **ISO-8601** / **timestamptz** Postgres su `updated_at`, `deleted_at`.  
- **Parser robusto** al boundary **DTO → service** (`ISO8601DateFormatter` con opzioni fractional seconds se serve, fallback documentato).  
- **UTC** come riferimento per confronti tra peer (due `Date` in memoria).  
- SwiftData: memorizzare **`Date?`** — non stringhe raw nei model **salvo** fallback documentato altrove.  
- Parse **fallito**: niente date “inventate” → **`sourceError`** o blocco campo critico; **test** stringhe valide / vuote / invalide.

---

## Privacy-safe logging (DEBUG)

Allineamento spirito **Android TASK-070**: log **strutturati**, **privacy-safe**.

| OK | No (log tecnici / `Logger` / OSLog) |
|----|--------------------------------------|
| Fasi, stati pull, **numeri** (righe, pagina k/n), **tipo** conflitto, **conteggi** | Barcode, nomi prodotto, fornitore, categoria, payload JSON intero |
| UUID remoto **solo** troncato / prefisso / hash se necessario al debug | Identificatori completi abbinati a PII |

La **UI** può mostrare contenuti necessari all’utente; i **log** no.

---

## 4. Schema Supabase verificato (repo `MerchandiseControlSupabase`)

Verifica effettuata su file SQL in `supabase/migrations/` (workspace locale). **Non assumere** colonne extra oltre quanto sotto senza riconfermare su ambiente hosted.

| Oggetto | Stato | Colonne / note principali |
|---------|--------|---------------------------|
| **`public.inventory_suppliers`** | **Trovato** (`20260417120000_task013_*` + tombstone `20260418200000_*`) | `id` uuid PK, `owner_user_id` uuid FK `auth.users`, `name` text, `updated_at` timestamptz, `deleted_at` timestamptz nullable (TASK-019). Unique parziale attivo: `(owner_user_id, lower(name)) WHERE deleted_at IS NULL`. |
| **`public.inventory_categories`** | **Trovato** | Stessa struttura di suppliers. |
| **`public.inventory_products`** | **Trovato** | `id` uuid PK, `owner_user_id`, `barcode` text, `item_number`, `product_name`, `second_product_name`, `purchase_price`, `retail_price`, `supplier_id` uuid nullable FK, `category_id` uuid nullable FK, `stock_quantity`, `updated_at`, `deleted_at` nullable. Unique parziale attivo: `(owner_user_id, barcode) WHERE deleted_at IS NULL`. |
| **`public.inventory_product_prices`** | **Trovato** (`20260417200000_task016_*`) | `id` uuid PK, `owner_user_id`, `product_id` uuid FK → `inventory_products`, `type` IN ('PURCHASE','RETAIL'), `price`, **`effective_at` text**, **`created_at` text**, `source`, `note`; unique `(owner_user_id, product_id, type, effective_at)`. |
| **`public.sync_events`** | **Trovato** (`20260424021936_task045_*`) | `id` bigint identity, `owner_user_id`, `store_id`, `domain` in ('catalog','prices'), `event_type`, `changed_count` ≥ 0, `entity_ids` jsonb nullable, `metadata` jsonb, `created_at`, indici; **RLS** select owner; grant SELECT to `authenticated`. |
| **RPC `public.record_sync_event(...)`** | **Trovato** (stessa migrazione) | `SECURITY DEFINER`; valida dominio/tipo; **`p_changed_count` ammesso 0…1000** (eccezione se fuori range); limiti su `entity_ids` (chiavi ammesse, max 250 UUID per array, dimensione payload); `metadata` max 4096 bytes e chiavi vietate — **fonte del mismatch TASK-071** vs payload Android massivi. |
| **`product_remote_refs` / bridge** | **Non trovato in Postgres** | Documentazione progetto: bridge su **Android Room** (`ProductRemoteRef`, ecc.), non tabella cloud nel dump migrazioni esaminato. iOS TASK-040 propone equivalente **solo in SwiftData**. |
| **`sync_event_outbox`** | **Non trovato in migrazioni Postgres** | Presente come tabella **Room** su Android (`AppDatabase` / test migrazione); modello **device-local** per retry RPC, non schema Supabase nel repo esaminato. |

---

## 5. Design fetch completo / paginazione

### Strategia
- **Page size**: default coerente con limite PostgREST (500 già usato; max 1000 come oggi). Configurabile in init servizio / opzioni DEBUG.
- **Range pagination**: mantenere API esistente `from` / `to` (offset window) o evolvere verso **keyset** `(updated_at, id)` in execution se necessario. **Obbligo planning**: ogni pagina deve avere **ordinamento esplicito** nel client Supabase Swift — **vietate** richieste paginate senza `.order` definito (rischio righe duplicate / ordine non stabile tra run).
- **Ordinamento deterministico (decisione consigliata per full pull iniziale)**: per ogni tabella `inventory_*`, usare ordine **stabile** — default raccomandato **`id` ASC** (UUID ordinato lessicograficamente, coerente con PK) **oppure** `(updated_at ASC, id ASC)` se si privilegia ordine temporale; la scelta finale va **riportata nel codice** (`SupabaseInventoryService`) e nei test di paginazione mock. Verificare che la sintassi `.order(...)` del client Swift sia quella effettivamente emessa (execution).
- **Limiti intrinseci offset pagination**: la paginazione per **offset/range** **non** è uno snapshot transazionale del database: tra una pagina e l’altra possono inserirsi o sparire righe → possibili duplicati o salti. **Mitigazione planning**: documentare come *limite noto*; in UX/log opzionale **warning** se il pull dura molto o se si rileva incoerenza di conteggio; **follow-up** possibile: watermark / sync incrementale / keyset — **non** in TASK-040.
- **Dati che cambiano durante il pull**: se il remoto muta mentre il client scarica, classificare come **rischio documentato**; non introdurre RPC di snapshot read-only in TASK-040; eventuale messaggio UI “catalogo potrebbe essere cambiato durante il download” (copy futura, localizzata).
- **Budget massimo**: parametro **`maxRows`** (o budget “illimitato” con guardrail memoria **in task futuro**). Sostituire il concetto “hard cap 10 000” con: **o** fetch fino a fine dataset (**complete**), **o** stop a budget utente (**partial** esplicito).

### Stati pull (macchina a stati logica — design)
| Stato | Significato |
|-------|-------------|
| `idle` | Nessun fetch in corso. |
| `loadingPage(n)` | Pagina n in corso (per UX progress). |
| `complete` | Tutte le tabelle richieste hanno `reachedCap == false` e nessun errore fatale. |
| `partial` | Budget esaurito, cap raggiunto, errore su una tabella secondaria, o abort — **preview marcata partial**; apply locale resta bloccato se policy TASK-039 ancora attiva. |
| `failed` | Errore rete / sessione / decoding non recuperabile. |
| `cancelled` | Solo se in execution si introduce `Task` cancellabile esplicitamente (opzionale; non obbligatorio in TASK-040 planning). |

### Cosa **blocca apply** (coerenza con TASK-039 + estensioni TASK-040)
- `partial` o `sourceErrors` non vuoti (inclusi nuovi codici es. `paginationIncomplete`).
- Schema mismatch decoding (DTO ≠ colonna reale) → errore classificato, no apply.
- **Remote refs incoerenti** preview: es. stesso barcode con due UUID remoti diversi non risolti — conflitto.
- **Supplier/category mancanti** se il grafo FK non è risolvibile dopo fetch ordinato (vedi §7).

### Preview parziale vs completa
| | **Parziale** | **Completa** |
|---|--------------|--------------|
| Catalogo prodotti | `reachedCap` o errore pagina | tutte le pagine fino a `page.count < pageSize` |
| Suppliers / categories | stesso | stesso |
| Prezzi | cap `maxProductPriceRows` o errore → warning `priceHistoryIncomplete` (TASK-039) | tutte le righe o policy “prezzi fuori scope” documentata |
| Outcome `SyncPreview` | `.partial` + errori/warning | `.success` (salvo conflitti di business) |

---

## 6. Design remote identity bridge SwiftData

> **Architettura**: metadati **embedded** (sezione *Decisione architetturale: embedded remote metadata vs ref tables*). Nessuna tabella ref SwiftData in TASK-040.

### Decisione tipi SwiftData (default planning)

| Modello | Campo | Tipo (default) |
|---------|--------|----------------|
| `Product` | `remoteID` | `UUID?` |
| `Product` | `remoteUpdatedAt` | `Date?` |
| `Product` | `remoteDeletedAt` | `Date?` |
| `Supplier` | `remoteID` | `UUID?` |
| `Supplier` | `remoteUpdatedAt` | `Date?` |
| `Supplier` | `remoteDeletedAt` | `Date?` |
| `ProductCategory` | `remoteID` | `UUID?` |
| `ProductCategory` | `remoteUpdatedAt` | `Date?` |
| `ProductCategory` | `remoteDeletedAt` | `Date?` |

**Boundary DTO ↔ modello (obbligo)**  
- I DTO in `SupabaseInventoryDTOs.swift` espongono **`updated_at` / `deleted_at` come `String`** (ISO-8601 dal backend). **`UUID`** per `id` / `owner_user_id` è già tipizzato lato DTO.  
- **Conversione** `String` ISO → `Date` e eventuale validazione **solo** nel perimetro **DTO / servizio fetch / diff / snapshot**, **prima** di assegnare agli attributi SwiftData. I modelli SwiftData **non** dovrebbero conservare stringhe ISO duplicate salvo emergenza.  
- **Fallback**: se in **EXECUTION** emergesse un **blocker reale** SwiftData su `Date` o `UUID` (es. bug runtime limite), la mitigazione **`String?`** per un campo è accettabile **solo nel task di execution** che documenta il motivo — **non** è il default di questo planning.

**Metadati opzionali (non nel modello tabellare)**  
- `lastPulledAt` globale o per-sessione in **`UserDefaults` / AppStorage** (priorità sezione DEBUG) per copy “ultimo pull”.

### Regole business (planning)  
- **Barcode** resta chiave business locale univoca (come oggi).  
- **`remoteID`** (UUID Supabase) è chiave identità **cloud** per stesso owner.  
- Prodotto locale **senza** `remoteID` ma con **stesso barcode** di riga remota attiva → **link** consentito al primo pull/apply completo (merge controllato).  
- Prodotto locale con **`remoteID` A**, arriva riga remota stesso barcode ma **`id` B** → **conflitto** (non applicare silenziosamente; allineare a documentazione Android TASK-019 / merge inbound).  
- Riga remota **senza barcode normalizzabile** → `sourceError` / conflitto.  
- **Ordine apply**: risolvere **supplier/category** (insert locale + `remoteID`) **prima** di collegare prodotti che referenziano `supplier_id` / `category_id` UUID.

**Non introdurre** in TASK-040 execution: colonne dirty revision / outbox / `syncState` push-ready — solo quanto serve a **non duplicare** e a **riconoscere** record remoti.

### Tombstone policy (planning)

- **Consentito in TASK-040 (design / futura execution)**: leggere `deleted_at` dal remoto; mostrarlo in **preview/diff** come segnale; classificare nella taxonomy come **`tombstonePreviewOnly`**.
- **Vietato in TASK-040**: cancellare o nascondere record SwiftData solo perché il remoto ha tombstone; modificare visibilità elenco prodotti locali per tombstone remoto.
- **Delete inbound tombstone-compliant** (allineato Android / decisioni Supabase): **task futuro separato** — TASK-040 ne definisce solo il confine e la classificazione in preview.

---

## Account / owner guard

**Contesto**: i DTO leggono già **`owner_user_id`** (`ownerUserID: UUID` in `SupabaseInventoryDTOs`). Tutte le righe `inventory_*` sono **per owner** Supabase (`auth.uid()`).

**Obiettivo**: evitare **relink** o **apply** incrociati dopo **cambio account** (logout/login altro utente) che mescolerebbe identità locali con catalogo remoto di un altro owner.

**Strategia planning (da implementare nelle slice A/C/D, non ora)**  
1. All’atto del primo collegamento / dopo pull riuscito, persistere **`lastLinkedSupabaseUserID: UUID?`** (o nome equivalente) in **`UserDefaults`** o **AppStorage**, valorizzato da **`session.user.id`** / `SupabaseAuthSessionInfo` (stesso identificatore usato per RLS).  
2. Opzionale: per ogni record, il DTO **`ownerUserID`** deve **coincidere** con la sessione corrente — se la query RLS è corretta, non si leggono righe altrui; il guard locale copre il caso **dati già in SwiftData** da sessioni precedenti.  
3. **Mismatch**: se `currentSessionUserID != lastLinkedSupabaseUserID` (e `lastLinked` non è nil) → **bloccare apply** e **bloccare relink automatico** di `remoteID` fino a **conferma utente esplicita** futura (copy tipo: i dati locali erano associati a un altro account).  
4. **Non** è obiettivo TASK-040: multi-tenant completo o UI “gestione account”; solo **guardia minima** anti-cross-account.

---

## Conflict taxonomy (planning)

Categorie da usare in preview/diff/apply (allineare nomi con enum futuro in codice). Estende i conflitti già noti da TASK-035/039.

| Categoria | Significato | Azione tipica (planning) |
|-----------|-------------|---------------------------|
| **`linkOnly`** | Locale senza `remoteID`, esiste riga remota **attiva** stesso barcode → collegamento ammesso in slice C. | Apply può impostare `remoteID` + aggiornare campi se policy consente. |
| **`createLocal`** | Riga remota attiva, nessun prodotto locale con stesso barcode. | Insert locale (come new product TASK-039). |
| **`updateLocal`** | Locale con `remoteID` coerente; remoto più recente secondo `remoteUpdatedAt` / fingerprint; policy TASK-039 consente update campo. | Update campo-per-campo conservativo. |
| **`remoteIdConflict`** | Stesso barcode ma **`remoteID` locale ≠ `id` remoto** (due identità cloud diverse). | **Non** merge silenzioso; conflitto bloccante fino a risoluzione manuale / task futuro. |
| **`duplicateBarcode`** | Più righe remote **attive** con stesso barcode (incoerenza dati). | Esclusione / conflitto; mai apply “scegli una”. |
| **`missingRemoteReference`** | `supplier_id` / `category_id` sul prodotto remoto non risolvibili nello snapshot supplier/category scaricato. | Errore integrità; blocco riga o apply globale (come policy TASK-039). |
| **`tombstonePreviewOnly`** | Riga remota con `deleted_at != nil`. | Solo informata in preview; **nessun** delete locale in TASK-040; follow-up delete inbound. |
| **`sourceError`** | DTO decode fallito, schema mismatch, barcode non normalizzabile, ecc. | `sourceErrors` / apply disabilitato. |
| **`partialBlocked`** | Pull **partial** o budget esaurito → preview non completa. | Apply disabilitato (Strategia A TASK-039). |

---

## 7. Design mapping Product / Supplier / Category

- **Mapping remoto → SwiftData**: `inventory_suppliers.id` → `Supplier.remoteID`; nome display da `name` con normalizzazione **`SupabasePullPreviewNormalizer.normalizedLookupName`** (stesso stile TASK-039).  
- **FK prodotto**: `supplier_id` / `category_id` UUID remoti → lookup su `Supplier` / `ProductCategory` per `remoteID`; se assente, creare entità locale con nome dalla riga supplier/category **già fetchata** nel `RemoteInventorySnapshot`.  
- **Ordine di arrivo**: se una pagina prodotti arriva prima delle righe supplier necessarie, bufferizzare **in preview** oppure fare **due passate** (fetch suppliers/categories completi prima del diff prodotti) — raccomandazione planning: **passata 1** suppliers+categories completa, **passata 2** prodotti, **passata 3** prices (coerente con gating Android).  
- **Supplier/category mancanti** in snapshot ma referenziati da FK → errore di integrità / conflitto; non inventare nomi.  
- **Duplicati nome**: vincolo SwiftData `@Attribute(.unique) name` — uso **nome canonico** dal remoto (primo visto) + lookup per `remoteID` per evitare creare duplicati visivi.  
- **Allineamento Android**: stessa semantica “lower(name) unique per owner” lato cloud; locale iOS deve evitare divergenze di normalizzazione rispetto a Android (documentare tabella comparativa nome normalizzato vs nome display se necessario).

---

## 8. Compatibilità futura con sync Android

TASK-040 **prepara** (design only): push manuale con prefisso ref; tombstone inbound usando `remoteDeletedAt` / `deleted_at`; dirty marking locale; accodamento eventi verso `record_sync_event`; outbox locale iOS analogo Room; risolutori conflitto; bulk upload.

TASK-040 **non implementa** nessuno di questi.

**Rischi incrociati**
- **TASK-068 PARTIAL**: iOS non deve anticipare bulk push o semantica “no-op” Android finché la validazione live Android non chiude il ciclo — evitare dipendenze hard-coded sul stesso batch size come verità assoluta.  
- **TASK-071**: iOS **non** deve chiamare `record_sync_event` finché backend non riallinea `p_changed_count` (o strategia eventi spezzati **documentata**). Il vincolo **0…1000** è **nel SQL** della funzione `record_sync_event` verificato.

---

## 9. UX planning (DEBUG / Options)

**Dove**: sezione esistente Supabase DEBUG in `OptionsView` (stesso filo TASK-035/038/039).

### Struttura concreta proposta (`Form` + `Section`)

Nessun redesign della root Options — solo **sotto-albero** Supabase.

1. **`Section` — Supabase** (o titolo localizzato equivalente)  
   - Stato **account** (già auth-gated TASK-038): connesso / email o identificativo non sensibile.  
   - **Last pull**: timestamp o “mai” da `UserDefaults` / stato VM.  
   - **Pull mode / stato**: Completo · Parziale · In corso (pagina k) · Fallito — con `Label` + `ProgressView` quando attivo.

2. **`Section` — Preview cloud**  
   - Conteggi **prodotti / fornitori / categorie** (remoti nello snapshot).  
   - Badge stato: **completo** vs **parziale** (se partial → messaggio che apply è disabilitata).  
   - **Warning principali** (1–3 righe): `priceHistoryIncomplete`, `sourceErrors` sintetici senza dump.

3. **`Section` — Identità remota**  
   - **Prodotti collegati** (`remoteID` non-nil) **/ totali** locali pertinenti.  
   - **Supplier / category collegati** / totali.

4. **`Section` — Conflitti**  
   - **Summary** + al massimo **5 esempi** (barcode tronco / tipo conflitto) **oppure** solo summary se troppi — CTA futura “vedi dettagli” / sheet secondaria **se** necessario.  
   - Nessuna lista infinita nella schermata principale.

5. **CTA**  
   - **«Genera preview completa»** (o equivalente localizzato).  
   - **«Applica al database locale»** con **`SupabasePullApplyDisabledReason`** se partial, conflitto bloccante, **account mismatch**, sessione assente.

**Linee guida UI (solo planning)**  
- Componenti **SwiftUI** standard: `NavigationStack` / `Form` / `Section` / `List`; eventuali **card** leggere (`GroupBox`-style) — **no** layout custom complesso.  
- Stato: **`Label`** (icona + titolo) affiancata a **`ProgressView`** durante pull paginato.  
- **CTA principale** (es. “Genera preview”, “Applica al database locale”): se disabilitata, **sempre** motivo visibile sotto (footer / `help`) — stesso pattern `SupabasePullApplyDisabledReason` TASK-039.  
- **Nessuna** azione distruttiva (nessun “Reset database”, “Elimina tutto” senza task dedicato).  
- **Nessun redesign generale** della schermata Options: solo incremento sezione DEBUG Supabase.

**Copy guida (chiave concettuale — stringhe finali IT / EN / ES / ZH-Hans in slice D)**  
| Concetto | Esempio IT (indicativo) |
|----------|-------------------------|
| Pull completo | «Pull completo» / «Catalogo scaricato completamente» |
| Pull parziale + apply off | «Pull parziale: applicazione disabilitata» |
| Identità collegata | «Identità remota collegata» (per riga o conteggio) |
| Conflitti | «Conflitti da risolvere» |
| Account mismatch | «Sessione account diversa dall’ultimo collegamento — apply bloccato» *(conferma futura)* |

**Mostrare** (in aggiunta a quanto già previsto):
- Stato pull: **Completo** / **Parziale** / **Fallito**; progress **Pagina n** durante fetch.
- Conteggi: righe scaricate per tabella; **prodotti con `remoteID` collegato** vs totali.
- Conflitti (vedi **Conflict taxonomy**); messaggio dedicato se **`partialBlocked`**.
- **Apply disabilitato** se preview partial / account mismatch / conflitti bloccanti (footer chiaro).

**Principi**: nessuna UI distruttiva; copy che eviti “sync cloud completato” se solo pull locale (allineamento TASK-039).

---

## 10. Test planning (futura EXECUTION)

### XCTest puri (logica)
- Paginazione: **complete** (mock pagine che terminano prima del cap); **partial** (cap raggiunto).
- **Ordinamento stabile**: mock paginato con **`id` ASC** (o ordine scelto in §5) — assert che due run fetch deterministici producano stessa sequenza con stesso dataset finto.
- Duplicati barcode remoti; barcode vuoto.
- Link `remoteID` su prodotto locale senza ref (**`linkOnly`**); **conflitto** **`remoteIdConflict`** stesso barcode due UUID.
- **`missingRemoteReference`**: prodotto remoto con `supplier_id`/`category_id` assenti dallo snapshot fornito.
- Supplier/category creati **prima** dei product nel piano apply (ordine assertions).
- **`tombstonePreviewOnly`**: righe con `deleted_at` **non** rimuovono e **non** nascondono `Product` locale nei test di invariante.
- **`partialBlocked`**: preview partial mantiene **apply disabilitato** (coerenza `SupabasePullApplyDisabledReason`).
- **Account mismatch**: `lastLinkedSupabaseUserID` ≠ sessione corrente → `prepareApplyPlan` / guard UI **rifiuta** apply.
- Supplier/category missing; duplicate name normalization.
- `updated_at` stale vs snapshot (se introdotto confronto).
- `sourceErrors` bloccano prepare apply (estendere fixture `SyncPreview`).
- ProductPrice: **preview-only** / fuori apply (coerente TASK-039).
- **`remoteID` UUID** persistito e **ripreso** dopo update locale-only che non deve azzerare metadati sync.
- **Duplicato `remoteID` non-nil** su due entità distinte → conflitto / errore (policy § *Policy unicità*).
- **Partial pull** non sovrascrive `remoteID` in modo incoerente (fixture che simula partial dopo full).
- Migrazione leggera con campi opzionali nuovi.
- Apply mantiene `remoteID` dopo insert/update.
- Nessun duplicato `Product` / `Supplier` / `ProductCategory` per invarianti.
- **Idempotenza**: due apply identici / secondo pull A → no duplicati (vedi § *Idempotenza*).

### Parsing date / errori
- Test parser **ISO** per `updated_at` / `deleted_at`: valido, vuoto, invalido → comportamento atteso (vedi § *Date parsing*).

### Privacy / log
- Test che **logger** non riceve stringhe con barcode completi in fixture di log (dove introducibile helper testabile).

### Localizzazioni
- Ogni chiave **nuova** introdotta in slice D presente in **IT, EN, ES, ZH-Hans** (coerenza con convenzione app post-TASK-039).

### Anti-regression
- Build Debug/Release; XCTest; localizzazioni; `git diff --check`; grep statico **nessuna** POST/insert/update RPC / **`record_sync_event`** nei path contrattati read-only.

---

## 11. File iOS candidati (post-verifica repo reale)

| Area | Path |
|------|------|
| Modelli | `iOSMerchandiseControl/Models.swift` |
| DTO | `iOSMerchandiseControl/SupabaseInventoryDTOs.swift` |
| Fetch / preview | `iOSMerchandiseControl/SupabaseInventoryService.swift`, `SupabasePullPreviewService.swift`, `SupabasePullPreviewModels.swift` |
| Apply | `iOSMerchandiseControl/SupabasePullApplyService.swift` |
| Snapshot locale | `iOSMerchandiseControl/SwiftDataInventorySnapshotService.swift` |
| Auth / sessione | `SupabaseAuthViewModel.swift`, `SupabaseAuthService.swift`, `SupabaseClientProvider` *(owner guard / `session.user.id`)* |
| UI DEBUG | `iOSMerchandiseControl/OptionsView.swift` *(Sezioni Supabase / Preview / Identità / Conflitti)* |
| Localizzazioni | `iOSMerchandiseControl/*.lproj/Localizable.strings` (IT, EN, ES, ZH-Hans) |
| Test | `iOSMerchandiseControlTests/*` |

---

## 12. Criteri di accettazione — planning (TASK-040)

- [x] **CA-1**: TASK-040 è **planning-only**; nessuna execution Swift nel perimetro di accettazione di questo task documentale.
- [x] **CA-2**: TASK-039 resta **DONE**; nessuna riapertura nel testo operativo.
- [x] **CA-3**: Planning riassume stato iOS reale post TASK-039 (§1).
- [x] **CA-4**: Planning riassume Android MASTER-PLAN + task 067–071 (§2).
- [x] **CA-5**: Definisce fetch completo / paginazione controllata (§5).
- [x] **CA-6**: Definisce preview **complete vs partial** (§5).
- [x] **CA-7**: Definisce bridge remote identity per Product/Supplier/Category (§6).
- [x] **CA-8**: Barcode = chiave business; `remoteId`/UUID = chiave sync remota (§6).
- [x] **CA-9**: Schema Supabase verificato da migrazioni; **nessuna colonna inventata** (§4).
- [x] **CA-10**: Documenta rischi `record_sync_event` / PayloadValidation (§4, §8).
- [x] **CA-11–CA-14**: Nessuna autorizzazione a scrittura Supabase, push, sync automatico/background/realtime, apply ProductPrice remoto.
- [x] **CA-15**: Matrice test futura presente (§10).
- [x] **CA-16**: MASTER-PLAN iOS aggiornato solo per tracking.
- [x] **CA-17**: Nessun Swift / pbxproj / plist / Package.resolved / SQL modificato in questo turno.
- [x] **CA-18**: Pre-execution gates documentati (checklist § *Pre-Execution gates*).
- [x] **CA-19**: Decisione **embedded remote metadata vs ref tables** documentata.
- [x] **CA-20**: Policy unicità **`remoteID`** documentata (nessun unique opzionale assunto a priori).
- [x] **CA-21**: Idempotenza pull/apply/relink documentata con test pianificati.
- [x] **CA-22**: Performance / memoria / dataset grande documentate.
- [x] **CA-23**: Date parsing / timezone policy documentati.
- [x] **CA-24**: Privacy-safe logging documentato.
- [x] **CA-25**: MASTER-PLAN iOS verificato / allineato (sezione sotto).

---

## MASTER-PLAN alignment check (iOS)

**File canonico repository iOS:** `docs/MASTER-PLAN.md` *(unico MASTER-PLAN dell’app; non confondere con il MASTER-PLAN Android in `MerchandiseControlSplitView`)*.

Verifica **in questo polish** (lettura file):

| Voce | Atteso | Esito (2026-05-06) |
|------|--------|---------------------|
| Stato globale | **ACTIVE** | OK (**Obiettivo attuale** + § Stato globale) |
| Task attivo | **TASK-040** | OK (**Workflow task attivo** + **Task attivo**) |
| Fase | **PLANNING** | OK |
| Responsabile | **Claude / Planner** e/o **Cursor** solo **planning refinement** — non **Executor** | OK |
| TASK-039 | **DONE**, non riaperto | OK |
| Android backlog | Non modificato da questo polish | OK |

**Nota housekeeping:** nella sezione **Blocchi**, la nota sotto TASK-026 che diceva “nessun task attivo” rispetto allo stato globale era **incoerente** con **TASK-040** ACTIVE — è stata aggiornata nel MASTER-PLAN (solo testo storico TASK-026).

---

## 13. Rischi

| Rischio | Mitigazione (planning) |
|---------|-------------------------|
| Duplicati prodotto per divergenza barcode vs `remoteID` | Regole conflitto esplicite; test XCTest; no silent merge. |
| Duplicati supplier/category per normalizzazione diversa da Android | Allineare helper a `normalizedLookupName`; tabella decisione nomi display. |
| Migrazione SwiftData fragile | Campi opzionali; test in-memory; backup / versioning modello. |
| Pull parziale applicato per errore | UI + guard `partial` + CA task-039 finché policy non cambia esplicitamente. |
| Schema hosted diverso da repo migrazioni | Smoke su progetto reale prima di EXECUTION; documentare drift. |
| TASK-068 PARTIAL | Non dipendere da semantica bulk push Android non validata live. |
| TASK-071 / backend `changed_count` | Nessuna chiamata RPC write da iOS fino a fix backend o spezzatura eventi. |
| Cambio account senza owner guard | `lastLinkedSupabaseUserID` + blocco apply/relink; test mismatch (§10). |
| Campi SwiftData non allineati ad Android | Revisione incrociata con `docs/room_current_model.md` / decisioni Supabase. |
| Memoria / RAM su catalogo ~20k righe | Pagination + no dump UI completo; partial/failed con messaggio; test carico opzionale. |
| Log PII (barcode/nomi) in DEBUG | Policy § *Privacy-safe logging*; review grep `Logger` / `print`. |

---

## Non fare nella futura Execution TASK-040 (anti-scope-creep)

- **Slice A (prima EXECUTION)**: non introdurre **B / C / D** (pull full, link/apply identità esteso, UX oltre il minimo necessario in review).
- **Qualsiasi** EXECUTION nel perimetro TASK-040 (fino a ridefinizione esplicita): **non** implementare — nemmeno “piccolo extra” — quanto segue:

- **Dirty marking** push-ready o revisioni tipo Android Room.  
- **Outbox** locale o retry verso RPC.  
- Chiamate **`record_sync_event`** o **`sync_events` write**.  
- **Push** remoto (catalogo/prezzi), **bulk upload**, **realtime** subscription.  
- **Delete inbound** da tombstone remoto (cancellazioni SwiftData guidate da `deleted_at`).  
- **Risolvere** o allinearsi codificando workaround per **Android TASK-068 PARTIAL** (validazione live bulk).  
- **Modifiche schema Supabase**, migration SQL hosted, **RLS/policy**, `supabase db push`.  
- **Apply `ProductPrice`** remoto o storico da `inventory_product_prices` oltre quanto TASK-039 già vieta.

Quanto sopra resta **backlog / task futuri** con ID separati.

---

## 14. Check finali — planning-only

- [x] Creato solo nuovo file task + aggiornamento **MASTER-PLAN** iOS.
- [x] Nessun codice Swift, `project.pbxproj`, `Package.resolved`, `Info.plist`, migration SQL, `supabase db push`.
- [x] TASK-039 resta **DONE**.
- [x] Stato globale progetto iOS impostato ad **ACTIVE** con task **TASK-040 / PLANNING**.

---

## Planning (Claude) — formato obbligatorio

### Obiettivo
Formalizzare il design per superare i cap di preview, introdurre bridge `remoteID` su SwiftData allineato a `inventory_*`, e tracciare rischi con contratto `sync_events` / Android — **senza** implementazione codice in questo turno.

### Analisi
Vedi §1–§4: stato iOS post TASK-039; pipeline Android TASK-067–071; schema Postgres e assenza bridge in SQL; limiti RPC `record_sync_event`.

### Approccio proposto (EXECUTION futura, non autorizzata ora)
Seguire lo **slicing** **A → B → C → D** (§ *Execution slicing futura*). In sintesi:  
1. Estendere modello SwiftData + snapshot locale con metadati identità (**slice A**).  
2. Refactor `SupabasePullPreviewService` / `SupabaseInventoryService` verso budget configurabile, **ordine deterministico**, condizione **complete** misurabile (**slice B**).  
3. Aggiornare diff/apply per link/conflitti FK e **`remoteID`** (**slice C**).  
4. UX DEBUG + localizzazioni (**slice D**).

### File coinvolti (futuri)
Vedi §11.

### Rischi
Vedi §13.

### Criteri di accettazione planning
Vedi §12 (**CA-1**–**CA-25**); soddisfatti con questo documento + aggiornamento MASTER-PLAN ove applicabile.

### Execution futura — non autorizzata in questo turno

- Dopo questa **integrazione del planning**, **TASK-040** resta **ACTIVE / PLANNING**.  
- **Non** si intende alcun avvio automatico di **EXECUTION** né transizione di fase.  
- Per passare a **EXECUTION** serve **approvazione esplicita utente** (override) e aggiornamento formale di Stato/Fase nel file task.  
- **Cursor / esecutore** deve **solo** eseguire il codice quando autorizzato; in fase **PLANNING** può contribuire a **raffinare il piano** su richiesta, **senza** modificare Swift finché non c’è handoff valido verso EXECUTION.

**Sequenza consigliata post-approvazione**: **prima Slice A**, poi quando autorizzati **B → C → D**; slice **E** = altro task.

**Durante Slice A autorizzata:** documentare prove secondo § *Evidence checklist futura — Slice A Execution*.

---

## Execution (Codex)
### 2026-05-05 — Slice A: Remote identity metadata SwiftData

**Obiettivo compreso**
- Esecuzione autorizzata solo per Slice A: aggiungere metadati remoti opzionali embedded ai modelli SwiftData `Product`, `Supplier`, `ProductCategory`.
- Nessun cambio a pull, paginazione, preview, apply, sync, push, Supabase, SQL, Android o UI.
- TASK-039 resta DONE e non riaperto.

**File controllati**
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-040-supabase-full-pull-remote-identity-bridge-swiftdata-android-alignment.md`
- `iOSMerchandiseControl/Models.swift`
- `iOSMerchandiseControl/iOSMerchandiseControlApp.swift`
- `iOSMerchandiseControlTests/SupabasePullApplyServiceTests.swift`
- `iOSMerchandiseControl.xcodeproj/project.pbxproj`
- Test target esistente `iOSMerchandiseControlTests`

**Piano minimo**
- Aggiungere `remoteID: UUID?`, `remoteUpdatedAt: Date?`, `remoteDeletedAt: Date?` con default nil a `Product`, `Supplier`, `ProductCategory`.
- Non usare `@Attribute(.unique)` su `remoteID`.
- Aggiungere XCTest SwiftData in-memory per default nil, valori valorizzati, round-trip e duplicati `remoteID`.
- Aggiornare solo tracking autorizzato.

**Modifiche fatte**
- `iOSMerchandiseControl/Models.swift`: aggiunti i tre campi opzionali embedded a `Product`, `Supplier`, `ProductCategory`; initializer estesi con parametri opzionali default nil e compatibili con le chiamate esistenti.
- `iOSMerchandiseControlTests/RemoteIdentityMetadataSwiftDataTests.swift`: aggiunta suite mirata Slice A con 6 test in-memory su `UUID?` / `Date?`, default nil, persistenza e duplicati `remoteID` non vincolati da unique implicita.
- `iOSMerchandiseControlTests/SupabasePullApplyServiceTests.swift`: microfix test-only del helper esistente da `Supplier.init(name:)` / `ProductCategory.init(name:)` a closure esplicite, necessario per compilare dopo l'estensione degli initializer con default arguments.
- Nessuna modifica a service Supabase, apply, preview, paginazione, UI, localizzazioni, plist, SQL, migration o Android.

**Check eseguiti**
- ✅ ESEGUITO — Build Debug simulator: `xcodebuild -quiet -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' -derivedDataPath /tmp/iOSMerchandiseControlDerivedData-task040 build` PASS.
- ✅ ESEGUITO — Build Release simulator: `xcodebuild -quiet -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Release -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' -derivedDataPath /tmp/iOSMerchandiseControlDerivedData-task040 build` PASS.
- ✅ ESEGUITO — XCTest: `xcodebuild -quiet -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' -derivedDataPath /tmp/iOSMerchandiseControlDerivedData-task040 test` PASS; suite completa PASS, inclusi 6 nuovi test `RemoteIdentityMetadataSwiftDataTests`.
- ✅ ESEGUITO — SwiftData in-memory Slice A: Product/Supplier/ProductCategory default nil, valori valorizzati, round-trip `UUID?`/`Date?`, duplicato `remoteID` non unique PASS.
- ✅ ESEGUITO — Nessun warning nuovo introdotto verificabile: build Debug/Release con `-quiet` non hanno stampato warning.
- ✅ ESEGUITO — `git diff --check` PASS.
- ✅ ESEGUITO — Grep anti-scope Swift diff: nessuna nuova occorrenza operativa `record_sync_event`; nessuna nuova write Supabase `.insert` / `.update` / `.upsert` / `.delete` nei service remoti; nessun outbox; nessun dirty marking push.
- ✅ ESEGUITO — Verifica `remoteID` senza `@Attribute(.unique)` PASS.
- ✅ ESEGUITO — Modifiche coerenti con planning Slice A e criteri di accettazione Slice A verificati staticamente/test.

**Rischi rimasti**
- Migrazione reale su store utente non provata su database persistente di produzione/beta; mitigazione: campi opzionali additivi e test SwiftData in-memory PASS.
- Duplicati `remoteID` sono volutamente consentiti a livello SwiftData in Slice A; enforcement applicativo/conflitti resta fuori da Slice A e dovra' essere trattato in Slice C o task successivo.
- Nessun comportamento di link/apply remoto implementato: i nuovi metadati sono solo prerequisito persistito.

**Aggiornamenti file di tracking**
- Metadata TASK-040 aggiornati a ACTIVE / EXECUTION con responsabile Cursor / Executor per user override Slice A.
- `docs/MASTER-PLAN.md` aggiornato a TASK-040 ACTIVE / EXECUTION, responsabile Cursor / Executor, nota tracking Slice A only.
- Review e Fix lasciate vuote.

### 2026-05-05 — Slice B: Full pull / paginazione

**Obiettivo compreso**
- Superare il cap catalogo fragile della preview e rendere esplicito lo stato **complete** vs **partial**.
- Mantenere Supabase read-only: nessuna RPC snapshot server-side e nessuna write remota.

**Modifiche fatte**
- `SupabaseInventoryService`: verificata API locale Supabase Swift `2.46.0` (`PostgrestTransformBuilder.order` concatenabile; `range(from:to:)` 0-based inclusiva e dipendente dall'ordine query). Aggiunto ordine esplicito stabile `id ASC` anche al probe limitato e mantenuto nelle query paginate.
- `SupabasePullPreviewService`: introdotto `SupabaseInventoryFetching` per test senza rete; sostituito il vecchio cap catalogo default con budget opzionale configurabile (`catalogRowBudget`, `productPriceRowBudget`), page size clamp `1...1000`, fetch fino a pagina finale quando budget assente.
- `SupabasePullPreviewPager`: helper puro/testabile per range contigui inclusivi e risultato `isPartial`.
- Errori recuperabili o budget esaurito su prodotti/supplier/category marcano preview partial con `sourceErrors`; budget/errori su prezzi restano `priceHistoryIncomplete` e non applicano `ProductPrice`.

**Check Slice B**
- ✅ ESEGUITO — XCTest paginazione complete PASS (`testGeneratePreviewFetchesCompletePagedCatalog`).
- ✅ ESEGUITO — XCTest paginazione partial PASS (`testGeneratePreviewMarksCatalogPartialWhenBudgetStopsPaging`).
- ✅ ESEGUITO — XCTest range/ordine stabile PASS (`testPagerUsesContiguousInclusiveRangesAndStableServiceOrderColumn`).
- ✅ ESEGUITO — Apply disabilitato su preview partial invariato e testato.

### 2026-05-05 — Slice C: Apply / link remote identity

**Obiettivo compreso**
- Usare i metadata Slice A per link locale↔remoto sicuro, senza duplicare record e senza push remoto.
- Mantenere `ProductPrice` remoto fuori apply e tombstone remoto preview-only.

**Modifiche fatte**
- `SwiftDataInventorySnapshotService` / `SupabasePullPreviewModels`: snapshot locale arricchito con `remoteID`, `remoteUpdatedAt`, `remoteDeletedAt` per prodotti e lookup; conteggi linked per UI.
- `SupabasePullPreviewDiffEngine`: aggiunti `linkOnly`, `remoteIdConflict`, `missingRemoteReference`; confronto per `remoteID` su stesso barcode e su remoteID già collegato; tombstone remoto resta solo in preview; source errors continuano a bloccare apply.
- `SupabasePullApplyService`: insert/update locali impostano metadata remoti su `Product`; linkOnly aggiorna solo metadata; supplier/category vengono risolti prima dei product e possono ricevere metadata remoti quando risolti; account mismatch bloccante tramite `SupabasePullApplyAccountGuard`.
- Idempotenza: secondo pull/apply dello stesso stato remoto non crea duplicati e produce no-op/no applicable changes.

**Check Slice C**
- ✅ ESEGUITO — XCTest `linkOnly` PASS.
- ✅ ESEGUITO — XCTest `createLocal` con metadata PASS.
- ✅ ESEGUITO — XCTest `updateLocal` conservativo + remote metadata PASS.
- ✅ ESEGUITO — XCTest `remoteIdConflict` PASS.
- ✅ ESEGUITO — XCTest `duplicateBarcode` remoto PASS.
- ✅ ESEGUITO — XCTest `missingRemoteReference` PASS.
- ✅ ESEGUITO — XCTest tombstone preview-only non cancella locale PASS.
- ✅ ESEGUITO — XCTest account mismatch blocca apply/relink PASS.
- ✅ ESEGUITO — XCTest ProductPrice resta preview-only / fuori apply PASS.
- ✅ ESEGUITO — XCTest idempotenza full pull A → apply → full pull A → apply PASS.
- ✅ ESEGUITO — XCTest partial pull non sovrascrive `remoteID` PASS.

### 2026-05-05 — Slice D: UX DEBUG + localizzazioni

**Obiettivo compreso**
- Migliorare la sezione DEBUG Supabase con SwiftUI nativo, senza redesign generale Options e senza copy fuorviante su sync cloud.

**Modifiche fatte**
- `OptionsView`: preview sheet organizzata con sezioni `Form`/`Section` per Preview cloud, Identita remota, Apply locale, Conflitti, gruppi prodotto e warning.
- Mostrati stato completo/parziale/fallito/in corso, conteggi prodotti/fornitori/categorie remoti, conteggi `remoteID` collegati locali e motivo esplicito quando apply è disabilitato.
- Apply locale passa account guard e memorizza `supabaseLastLinkedUserID` dopo apply locale riuscito.
- Conflitti limitati a 5 esempi nella sezione principale con conteggio righe nascoste.
- Nuove stringhe localizzate in IT / EN / ES / ZH-Hans; aggiunto test copertura chiavi.

**Check Slice D**
- ✅ ESEGUITO — Localizzazioni nuove presenti in IT / EN / ES / ZH-Hans PASS (`LocalizationCoverageTests`).
- ✅ ESEGUITO — Build Debug/Release PASS con UI DEBUG compilata.
- ⚠️ NON ESEGUIBILE — Test manuale Simulator UI non richiesto esplicitamente dal task; verifica eseguita via build/test statici.

### Handoff to Review — 2026-05-05

**File modificati**
- `iOSMerchandiseControl/Models.swift`
- `iOSMerchandiseControl/SupabaseInventoryService.swift`
- `iOSMerchandiseControl/SupabasePullPreviewService.swift`
- `iOSMerchandiseControl/SupabasePullPreviewModels.swift`
- `iOSMerchandiseControl/SwiftDataInventorySnapshotService.swift`
- `iOSMerchandiseControl/SupabasePullApplyService.swift`
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/it.lproj/Localizable.strings`
- `iOSMerchandiseControl/en.lproj/Localizable.strings`
- `iOSMerchandiseControl/es.lproj/Localizable.strings`
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`
- `iOSMerchandiseControlTests/RemoteIdentityMetadataSwiftDataTests.swift`
- `iOSMerchandiseControlTests/SupabasePullPreviewPaginationTests.swift`
- `iOSMerchandiseControlTests/SupabasePullPreviewDiffEngineTests.swift`
- `iOSMerchandiseControlTests/SupabasePullApplyServiceTests.swift`
- `iOSMerchandiseControlTests/LocalizationCoverageTests.swift`
- `docs/TASKS/TASK-040-supabase-full-pull-remote-identity-bridge-swiftdata-android-alignment.md`
- `docs/MASTER-PLAN.md`

**Check finali**
- ✅ ESEGUITO — Build Debug simulator: `xcodebuild -quiet -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' -derivedDataPath /tmp/iOSMerchandiseControlDerivedData-task040 build` PASS.
- ✅ ESEGUITO — Build Release simulator: `xcodebuild -quiet -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Release -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' -derivedDataPath /tmp/iOSMerchandiseControlDerivedData-task040 build` PASS.
- ✅ ESEGUITO — XCTest: `xcodebuild -quiet -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' -derivedDataPath /tmp/iOSMerchandiseControlDerivedData-task040 test` PASS.
- ✅ ESEGUITO — `git diff --check` PASS.
- ✅ ESEGUITO — Grep anti-scope PASS: nessuna nuova chiamata operativa `record_sync_event`; nessuna nuova write Supabase `.insert` / `.update` / `.upsert` / `.delete` nei service remoti; nessun outbox; nessun dirty marking push; nessun `ProductPrice` apply remoto; nessun SQL/migration modificato.
- ✅ ESEGUITO — TASK-039 resta DONE e non riaperto.

**Rischi rimasti**
- Validazione live su catalogo Supabase grande non eseguita in questo turno; copertura tramite mock pagination + build/test.
- Migrazione reale su store persistente utente non provata; i campi restano additivi/opzionali e testati in-memory.
- Account guard è minimale (`UserDefaults` ultimo account collegato): gestione multi-account/manual reset resta follow-up futuro se richiesta.
- Il full pull usa offset/range con ordine `id ASC`, non snapshot transazionale server-side; mutazioni remote durante il pull restano limite noto di TASK-040.

## Review (Claude)
### 2026-05-05 — Review tecnica completa Reviewer+Fixer

#### 1. Esito
**APPROVED_FIXED_DIRECTLY**

#### 2. Sintesi
- Verificate Slice A/B/C/D su codice, test, tracking, diff e grep anti-scope.
- Fix diretto applicato: il bridge ora blocca conflitti `remoteID` locali duplicati e lookup supplier/category con stesso nome ma UUID remoto diverso; l'apply non puo' piu' applicare metadata lookup discordanti in modo silenzioso.
- Nessuna scrittura Supabase introdotta; nessun push remoto; nessun `record_sync_event`; nessun outbox/dirty marking; nessun apply remoto `ProductPrice`; nessuna modifica SQL/migration/Android.

#### 3. Matrice controlli

| Area | Esito | Evidenza |
|------|-------|----------|
| Slice A — metadata SwiftData | ✅ PASS | `Product`/`Supplier`/`ProductCategory` hanno solo `remoteID`, `remoteUpdatedAt`, `remoteDeletedAt` opzionali embedded; nessun `@Attribute(.unique)` su `remoteID`; XCTest in-memory PASS. |
| Slice B — full pull / paginazione | ✅ PASS | `SupabaseInventoryService` usa ordine stabile `id ASC`; `.range(from:to:)` inclusivo; page size clamp `1...1000`; budget opzionale; catalog partial blocca apply; ProductPrice resta preview-only. |
| Slice C — apply/link remote identity | ✅ PASS dopo fix | `linkOnly`, `createLocal`, `updateLocal`, `remoteIdConflict`, duplicate barcode, missing reference, tombstone preview-only, account mismatch e idempotenza coperti. Fix diretto su conflitti lookup supplier/category e duplicati `remoteID` locali. |
| Slice D — UX DEBUG / OptionsView | ✅ PASS | UI resta SwiftUI nativa con `Form`/`Section`/`Label`/`ProgressView`; CTA apply disabilitata con footer motivato; conflitti limitati; copy evita “sync completato”. |
| Anti-scope | ✅ PASS | Nessuna write Supabase; nessun push/catalog price apply; nessun realtime/background sync; nessun outbox/dirty; nessun `record_sync_event`/`sync_events` write; nessun SQL/migration. |
| Build/test | ✅ PASS | Build Debug PASS, Build Release PASS, XCTest completo PASS, `git diff --check` PASS. |
| Localizzazioni | ✅ PASS | `LocalizationCoverageTests` PASS; `plutil -lint` OK per IT/EN/ES/ZH-Hans. |
| Tracking | ✅ PASS con nota | TASK-040 era ACTIVE/REVIEW prima della review; MASTER-PLAN coerente; TASK-039 resta DONE; `project.pbxproj` senza diff. Android MASTER-PLAN non presente nel workspace locale (`MerchandiseControlSplitView` assente), quindi non e' stato modificato da questa review. |

#### 4. Comandi eseguiti
- ✅ Build Debug simulator:
  `xcodebuild -quiet -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' -derivedDataPath /tmp/iOSMerchandiseControlDerivedData-task040-review build`
- ✅ Build Release simulator:
  `xcodebuild -quiet -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Release -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' -derivedDataPath /tmp/iOSMerchandiseControlDerivedData-task040-review build`
- ✅ XCTest completo:
  `xcodebuild -quiet -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' -derivedDataPath /tmp/iOSMerchandiseControlDerivedData-task040-review test`
- ✅ Test mirati post-fix:
  `xcodebuild -quiet -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' -derivedDataPath /tmp/iOSMerchandiseControlDerivedData-task040-review test -only-testing:iOSMerchandiseControlTests/SupabasePullPreviewDiffEngineTests -only-testing:iOSMerchandiseControlTests/SupabasePullApplyServiceTests`
- ✅ `git diff --check`
- ✅ Localizzazioni:
  `plutil -lint iOSMerchandiseControl/it.lproj/Localizable.strings iOSMerchandiseControl/en.lproj/Localizable.strings iOSMerchandiseControl/es.lproj/Localizable.strings iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`
- ✅ Grep anti-scope:
  `rg -n "record_sync_event|sync_events|outbox|dirty|\\.upsert\\(|\\.delete\\(|\\.update\\(" ...` → nessuna occorrenza nei file Supabase TASK-040.
- ✅ Grep `.insert(` nei file Supabase TASK-040: solo `context.insert(product|supplier|category)` locale SwiftData in `SupabasePullApplyService`; nessuna insert remota Supabase.
- ✅ SQL/project diff:
  `git diff --name-only -- '*.sql' '*/migrations/*' 'MerchandiseControlSupabase/*' 'Package.resolved' 'iOSMerchandiseControl.xcodeproj/project.pbxproj'` → nessun output.

#### 5. Rischi residui
- Validazione live su catalogo Supabase grande non eseguita.
- Store persistente reale utente non validato dopo migrazione SwiftData additiva.
- Offset/range pagination con `id ASC` non e' snapshot transazionale; mutazioni remote durante il pull possono ancora produrre limiti noti.
- `UserDefaults` `supabaseLastLinkedUserID` resta guardia minima anti-account-mismatch; gestione multi-account/manual reset resta follow-up futuro.
- Android MASTER-PLAN non verificabile nel filesystem locale per assenza del repo/path Android nel workspace di questa review.

#### 6. Decisione finale
- **TASK-040 chiuso a DONE / Chiusura** su autorizzazione esplicita utente, perche' l'esito e' **APPROVED_FIXED_DIRECTLY** e build/test/check finali sono PASS.
- **MASTER-PLAN iOS aggiornato a IDLE**: nessun task attivo dopo la chiusura di TASK-040.
- **TASK-039 resta DONE / Chiusura** e non viene riaperto.
- Follow-up futuri registrati ma **non attivati**: TASK-041 candidato push manuale tombstone-compliant; ProductPrice remote apply / price sync; outbox/sync_events iOS; realtime/background sync; delete inbound da tombstone; validazione live su catalogo Supabase grande.

## Fix (Codex)
### 2026-05-05 — Fix diretto da Review
- `SupabasePullPreviewModels.swift` / `SwiftDataInventorySnapshotService.swift`: aggiunti metadata snapshot locali per rilevare lookup supplier/category per `remoteID`, lookup per nome normalizzato e duplicati `remoteID` locali.
- `SupabasePullPreviewService.swift`: aggiunti conflitti bloccanti `remoteIDConflict` per duplicati `remoteID` locali e per supplier/category con stesso nome o stesso UUID remoto ma identita' non coerente.
- `SupabasePullApplyService.swift`: `resolveSupplier` / `resolveCategory` riusano lookup esistenti per `remoteID` e lanciano `previewStale` se un lookup omonimo ha un `remoteID` diverso, evitando merge silenziosi.
- `SupabasePullPreviewDiffEngineTests.swift` / `SupabasePullApplyServiceTests.swift`: aggiunti test mirati per conflitto lookup omonimo con UUID diverso e duplicato `remoteID` locale.
- Check mirati e suite completa PASS; nessuna transizione FIX formale aperta perche' il fix e' stato applicato direttamente in Review con esito `APPROVED_FIXED_DIRECTLY`.
