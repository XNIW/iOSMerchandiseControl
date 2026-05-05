# TASK-041: Supabase manual push preflight + dry-run tombstone-compliant iOS

## Informazioni generali
- **Task ID**: TASK-041
- **Titolo**: Supabase manual push preflight + dry-run tombstone-compliant iOS
- **File task**: `docs/TASKS/TASK-041-supabase-manual-push-preflight-dry-run-tombstone-compliant-ios.md`
- **Stato**: DONE
- **Fase attuale**: Chiusura
- **Responsabile attuale**: Utente / Chiusura
- **Data creazione**: 2026-05-05
- **Ultimo aggiornamento**: 2026-05-05 *(review APPROVED_FIXED_DIRECTLY; microfix account non collegato + normalizzazione barcode baseline; build/test/anti-scope PASS; TASK-041 chiuso DONE)*
- **Ultimo agente che ha operato**: Codex / Reviewer+Fixer

## Dipendenze
- **Dipende da**: TASK-040 (DONE — full pull + bridge `remoteID` SwiftData), TASK-039 (DONE — apply locale controllato), TASK-038 (DONE — auth), TASK-035 (DONE — pull dry-run), TASK-034 (DONE — foundation readonly)
- **Riferimenti funzionali/Android** *(non codice da copiare 1:1)*: TASK-067 (DONE ACCEPTABLE), TASK-068 (**PARTIAL**), TASK-069 (DONE), TASK-070 (DONE), TASK-071 (DONE); concetti `product_remote_refs` / `supplier_remote_refs` / `category_remote_refs`, dirty marking, outbox, `sync_events`
- **Sblocca**: EXECUTION futura — preflight/dry-run push manuale conservativo; prima **push reale** solo in task successivo esplicito (es. **TASK-042** o slice dedicata) dopo approvazione utente

## Scopo
Produrre **solo planning operativo** per introdurre in futuro un **push manuale iOS** verso Supabase con primo passo prudente: **preflight locale**, **dry-run del payload** (nessuna rete di scrittura), **classificazione conflitti**, **policy tombstone-compliant**, **UX di conferma**, **piano di test**, e **vincoli anti-scope** espliciti. **Questo task non implementa push remoto** né alcuna scrittura Supabase.

## Contesto obbligatorio
- **TASK-040** è **DONE / Chiusura** — non va riaperto; fornisce full pull con paginazione deterministica, embedded `remoteID` / `remoteUpdatedAt` / `remoteDeletedAt` su `Product` / `Supplier` / `ProductCategory`, apply/link locale idempotente, UI DEBUG Options, **nessuna scrittura Supabase / push / `record_sync_event` / outbox / dirty / ProductPrice apply remoto**.
- **TASK-039** resta **DONE** — non va riaperto.
- **Android** è avanti sul sync, ma **non** va replicato 1:1 su iOS.
- **TASK-068 Android** resta **PARTIAL**: bulk product push implementato e testato su JVM; ciclo live/no-op e bulk su delta reale **non** ancora chiusi → **non** vanno trattati come contratto finale «live» per iOS.
- **TASK-070 Android** DONE: retry outbox head-of-line risolto lato app.
- **TASK-071 Android** DONE: mismatch RPC `record_sync_event` / `PayloadValidation` documentato; follow-up backend separato consigliato.
- **Decisione di prodotto**: TASK-041 **non** è «implementa push remoto subito». Percorso pianificato: **stato SwiftData → preflight → dry-run payload → conferma utente → task futuro per write reale**.

## Non incluso (OUT OF SCOPE — questo task e ogni sua futura execution vincolata al planning)
- Push reale; `insert` / `update` / `upsert` / `delete` verso Supabase
- `record_sync_event`; scritture `sync_events`
- Outbox iOS; dirty marking persistente; retry automatici; realtime; background sync
- Delete inbound/outbound reale; tombstone outbound reale
- `ProductPrice` push remoto (solo pianificazione «future / disabled»)
- Modifiche RLS/policy/schema; migration SQL; `supabase db push`
- Copia 1:1 Android; modifiche Android
- **Questo turno (planning-only)**: nessun Swift, `pbxproj`, `plist`, `Package.resolved`, SQL

---

## 1. Stato attuale iOS post TASK-040

| Area | Stato |
|------|--------|
| **Full pull preview** | Disponibile con paginazione deterministica e stato **complete vs partial** (`partialCatalog`, cap, `sourceErrors` come da TASK-039/040). |
| **Remote identity** | `Product` / `Supplier` / `ProductCategory` con `remoteID` (UUID opzionale) + `remoteUpdatedAt` / `remoteDeletedAt` dove definito in modelli. |
| **Apply locale** | `SupabasePullApplyService`: `prepareApplyPlan` / `apply(plan:)` idempotente; conflitti classificabili (`remoteIdConflict`, `missingRemoteReference`, ecc.). |
| **UI DEBUG** | Sezioni Options per pull/preview/apply con copy localizzata e guardrail. |
| **Scrittura Supabase** | **Nessuna** (foundation + pull restano read-only lato sync). |
| **Push / outbox / dirty** | **Non implementati** — corretto per TASK-041 che deve restare conservativo fino a nuovo task. |

*File di riferimento lettura pre-execution (non modificati in questo turno)*: `Models.swift`, `SupabaseInventoryService.swift`, `SupabasePullPreviewService.swift`, `SupabasePullPreviewModels.swift`, `SwiftDataInventorySnapshotService.swift`, `SupabasePullApplyService.swift`, `OptionsView.swift`.

---

## 2. Stato Android / Supabase rilevante

| Task Android | Stato | Rilevanza per iOS |
|--------------|--------|-------------------|
| **TASK-067** | DONE **ACCEPTABLE** | Riferimento per dirty marking delta-safe post import; logging/UX sync indicator. |
| **TASK-068** | **PARTIAL** | Bulk push lato client con batch/fallback JVM; **validazione live** no-op / bulk su delta reale ancora aperta → **non contratto finale** per design iOS push. |
| **TASK-069** | DONE | Audit diagnostico outbox / validazione payload. |
| **TASK-070** | DONE | Head-of-line retry outbox — pattern app-side, non da copiare 1:1 senza outbox iOS. |
| **TASK-071** | DONE | **`record_sync_event`**: vincolo `changed_count` / `PayloadValidation` — **rischio documentato** per futuro event bus; iOS non deve assumere RPC «sicuro» senza contratto backend chiarito. |

**Sintesi concettuale Android**: tabelle ref locali (`product_remote_refs`, …), **dirty marking**, **outbox** Room, **`sync_events`** remota + RPC `record_sync_event`. iOS deve **apprendere i concetti** (identità stabile, ordinamento supplier/category → product, tombstone, limiti batch/evento) ma **non** copiare l’implementazione 1:1.

### Note obbligatorie
1. **TASK-068** non definisce il contratto finale per push live iOS finché la parte live/no-op non è chiusa su Android.
2. **`record_sync_event`** non va chiamato da iOS finché il contratto backend (incluso limite `changed_count` e shape payload) non è **chiaro** o **spezzato in eventi sicuri** (vedi §8 e rischi TASK-071).

---

## 3. Obiettivo tecnico TASK-041

Pianificare (senza implementare push):

1. **Preflight push manuale**: quali record SwiftData sono candidati, quali esclusi, quali conflittuali, quali richiedono pull completo prima del push, quali sensibili a tombstone.
2. **Dry-run payload**: strutture pure in memoria che rappresentano ciò che *verrebbe* inviato — **zero write di rete**.
3. **UX conferma**: conteggi, warning, blocchi safety, copy esplicito «nessuna scrittura eseguita in TASK-041».
4. **Policy tombstone-compliant**: no update su righe tombstonate lato remoto; no delete reale in TASK-041/futurology slice planning-only.
5. **Blocchi safety**: partial pull, account mismatch, conflitti remote, ordine supplier/category.
6. **Test**: matrice XCTest/UI e grep anti-scope per execution future.

**Implementazione push reale** = task successivo (**TASK-042** o slice dedicata) solo dopo approvazione esplicita.

---

## 4. Modello dati e sorgenti locali

| Sorgente | Uso nel preflight |
|----------|-------------------|
| **`Product`** | `barcode`, `remoteID`, `remoteUpdatedAt`, `remoteDeletedAt`, relazioni supplier/category, campi business da confrontare con ultimo snapshot pull. |
| **`Supplier` / `ProductCategory`** | `remoteID`, date remote, nomi; **ordine**: senza `remoteID` su dipendenze, i product non possono essere classificati come push sicuri. |
| **Snapshot / ultima preview** | `SwiftDataInventorySnapshotService` + esito ultimo `SyncPreview` (complete vs partial, timestamp, errori) — input per `blockedPartialPull`. |
| **Guard account** | Sessione Supabase corrente vs `lastLinkedSupabaseUserID` (o equivalente documentato in auth/options) — per `blockedAccountMismatch`. |
| **`remoteUpdatedAt` / `remoteDeletedAt`** | Confronto con copy remota **solo tramite dati già noti da ultimo pull** (non nuove query write); tombstone remotoriflesso locale. |
| **`ProductPrice` (locale)** | Storico prezzi locale: **mai** push in questo perimetro; solo **warning** / candidato futuro. |
| **«Dirty» futuro** | Concetto per slice successive — **nessuna** persistenza dirty in TASK-041. |

### Baseline / fingerprint strategy
- Il preflight **non può** decidere in modo affidabile `noOpAlreadySynced` o `dryRunUpdateCandidate` usando solo `remoteID` / `remoteUpdatedAt`: quei campi descrivono identità e una traccia temporale, **non** il contenuto business completo.
- Strategia prudente: usare **solo** dati derivati da **ultimo pull completo** come baseline remota affidabile.
- Per ogni entità locale, il planning prevede un **fingerprint locale** dei campi business rilevanti, confrontato con fingerprint/snapshot dell’**ultimo stato remoto noto**.
- Se manca una baseline completa e affidabile, la classificazione deve diventare **`blockedMissingBaseline`** e l’azione consigliata è **pull completo prima di qualunque push**.
- TASK-041 **non introduce dirty marking persistente** e **non inventa update candidate** quando non esiste una baseline verificabile.
- `noOpAlreadySynced` **non significa** “sincronizzato col remoto in assoluto”: vale solo rispetto all’**ultimo snapshot completo noto**.

**Campi minimi pianificati nel fingerprint**:
- **Product**: `barcode`, `itemNumber`, `productName`, `secondProductName`, `purchasePrice`, `retailPrice`, `stockQuantity`, `supplier.remoteID`, `category.remoteID`
- **Supplier**: `name`
- **ProductCategory**: `name`
- **`ProductPrice`**: esplicitamente **fuori scope** dal fingerprint catalogo TASK-041

### Baseline persistence strategy
- Il preflight richiede una baseline affidabile derivata da **ultimo pull completo**; una baseline da pull **partial** non è valida per classificare no-op/update.
- Senza baseline completa la categoria corretta resta **`blockedMissingBaseline`**.
- In TASK-041 (planning) **non si decide ancora in modo definitivo** la persistenza finale della baseline.
- Opzioni future possibili (da valutare in execution autorizzata):
  - baseline snapshot persistita in SwiftData;
  - metadata/fingerprint in UserDefaults o AppStorage, solo se sufficiente e verificabile;
  - snapshot in file/cache locale;
  - derivazione da dati già salvati dal pull completo, se disponibili e affidabili.
- La prima execution consigliata (Slice A) resta **solo modelli puri + test**: non introdurre persistenza baseline complessa senza autorizzazione esplicita.
- Se in futuro si persiste baseline, deve essere **versionata** e **invalidabile** (schema/version bump, account change, pull partial/error).

Esempi espliciti di invalidazione baseline (planning):
- account change;
- pull partial;
- `sourceErrors` nel pull;
- schema/version fingerprint cambiato;
- local reset/import full database;
- cambio regole fingerprint;
- remote tombstone conflict.

### Fingerprint normalization policy
- Ordine campi **fisso** e deterministico.
- Stringhe con `trim` coerente; gestione case/locale documentata per evitare falsi delta.
- `nil` e stringa vuota trattati in modo esplicito e consistente.
- Numeri normalizzati in forma stabile (evitare differenze dovute solo a formattazione UI).
- UUID `remoteID` usati in stringa canonical.
- Nel fingerprint Product, supplier/category devono usare `supplier.remoteID` / `category.remoteID`, non solo il nome.
- `ProductPrice` escluso dal fingerprint catalogo TASK-041.
- Se un campo richiesto non è disponibile o non è affidabile: classificare come warning/blocker, **mai** produrre falso no-op.

---

## 5. Preflight rules — categorie

| Categoria | Significato operativo (planning) |
|-----------|----------------------------------|
| **dryRunCreateCandidate** | Entità locale senza `remoteID` coerente, nessun blocco safety, dipendenze (supplier/category) risolvibili o create candidate prima. |
| **dryRunUpdateCandidate** | `remoteID` presente, contenuto locale diverso da baseline sync nota, nessun blocco tombstone/stale/mismatch. |
| **noOpAlreadySynced** | Nessuna delta rilevante rispetto a baseline post-ultimo pull completo e fingerprint uguale allo snapshot remoto noto. |
| **blockedNoRemoteID** | Prodotto senza `remoteID` ma **barcode** già presente in catalogo remoto (ultimo snapshot) → non push diretto: richiede pull/link (allinea TASK-040). |
| **blockedAccountMismatch** | Utente Supabase attuale ≠ `lastLinkedSupabaseUserID` (o account non collegato). |
| **blockedPartialPull** | Ultimo pull catalogo in stato **partial** o con errori sorgente → **nessun** push/preflight «go» fino a pull completo o decisione utente documentata. |
| **blockedMissingBaseline** | Non esiste ultimo pull completo / snapshot affidabile per sapere se il locale è nuovo, aggiornato o già sincronizzato → richiedere pull completo prima del push. |
| **blockedRemoteConflict** | `remoteUpdatedAt` remoto (da ultimo dato noto) **più recente** del locale → bloccare o forzare pull prima. |
| **blockedTombstoneConflict** | Remoto ha `deleted_at` / tombstone e locale considera record attivo → blocco + risoluzione manuale / pull. |
| **blockedMissingSupplierCategoryRemoteID** | Product referenzia supplier/category senza `remoteID` → ordine: risolvere supplier/category prima o classificare come blocked. |
| **warningLocalOnlySupplierCategory** | Supplier/category solo locali usati da prodotti — non bloccante se policy ammette create candidate cascata (futuro); in planning iOS resta **warning** finché ordine non è implementato. |
| **warningStaleRemote** | Locale non allineato ma non ancora «hard conflict» — warning esplicito. |
| **futurePricePushCandidate** | Variazioni `ProductPrice` rilevate — **solo etichetta futura / task E**. |

> Nota di governance: `dryRunCreateCandidate` e `dryRunUpdateCandidate` sono etichette concettuali di **dry-run**. In TASK-041 non implicano “pronto per invio reale”; indicano solo candidati per task futuro. In TASK-041 ogni piano resta non-sendable.

### Regole vincolanti (riassunto)
- Ultimo pull **partial** → **push bloccato** (preflight può comunque *mostrare* stato ma CTA «send» resta disabilitata ovunque sarà definita).
- **Account** corrente ≠ ultimo account legato → **push bloccato**.
- **Nessuna baseline completa affidabile** → **non** dichiarare `noOpAlreadySynced` né `dryRunUpdateCandidate`; usare `blockedMissingBaseline`.
- Prodotto **senza `remoteID`** ma **barcode collision** remota → **no push diretto**; pull/link prima.
- Supplier/category **senza `remoteID`** → preflight indica **ordine**: supplier/category **prima** dei product (o tutti blocked fino a risoluzione).
- **`remoteDeletedAt` / tombstone remoto** → **no update** verso quel record remoto; classificare conflitto tombstone.
- **`remoteUpdatedAt` remoto più recente** (da baseline nota) → blocco o «pull richiesto».
- **`ProductPrice`** changes → solo **warning** / futuro task; non parte del payload push catalogo in TASK-041.

### No baseline = no no-op
- `noOpAlreadySynced` è permesso solo se **tutte** le condizioni sono vere:
  - ultimo pull completo presente;
  - baseline valida;
  - fingerprint locale == fingerprint baseline;
  - account corrente coerente.
- In ogni altro caso usare una categoria esplicita (`blockedMissingBaseline`, `blockedAccountMismatch`, ecc.).
- In UI non mostrare mai “già sincronizzato” quando manca baseline affidabile.

### Local-only data policy
- Product senza `remoteID` e senza baseline affidabile → `blockedMissingBaseline` oppure `blockedNoRemoteID` (in base al contesto noto).
- Supplier/Category senza `remoteID` usati da Product → `warningLocalOnlySupplierCategory` o blocker se impedisce classificazione push product sicura.
- Non inventare `remoteID`.
- Nessun create remoto automatico in TASK-041.
- Il futuro push create richiede task separato e conferma utente.
- Se `barcode` locale collide con remoto nello snapshot noto → bloccare e chiedere pull/link.

### Severity model

| Severity | Significato |
|----------|-------------|
| **blocker** | Impedisce il futuro push; il preflight può calcolare e mostrare il problema ma non deve produrre piano «sendable». |
| **warning** | Non blocca il preflight, ma richiede attenzione o conferma futura. |
| **info** | Solo conteggio / stato informativo. |
| **futureOnly** | Segnalato nel planning e nella preview, ma **non implementabile** nel task corrente. |

Mappatura iniziale raccomandata:
- `blockedPartialPull` = **blocker**
- `blockedAccountMismatch` = **blocker**
- `blockedMissingBaseline` = **blocker**
- `blockedTombstoneConflict` = **blocker**
- `blockedRemoteConflict` = **blocker**
- `warningLocalOnlySupplierCategory` = **warning**
- `warningStaleRemote` = **warning**
- `noOpAlreadySynced` = **info**
- `futurePricePushCandidate` = **futureOnly**

### Sendability invariant
- In TASK-041 ogni `ManualPushPlan` è **dry-run**.
- Nessun `ManualPushPlan` è eseguibile contro Supabase.
- Qualunque proprietà futura tipo `isSendable` (o equivalente) deve restare **false** in TASK-041.
- La transizione da dry-run a write reale richiede task successivo (es. TASK-042), review e autorizzazione utente.

---

## 6. Dry-run payload design (strutture pure — nessuna network write)

Naming esecutivo può cambiare; responsabilità minime:

| Tipo (planning) | Responsabilità |
|-----------------|----------------|
| **`ManualPushPreview`** | Risultato aggregate del preflight: conteggi per categoria, lista blocked/warnings, timestamp, id versione piano. |
| **`ManualPushPlan`** | Ordine operativo proposto (es. suppliers → categories → products), filtri esclusi, riferimenti a candidati. |
| **`PushCandidate`** | Singola riga candidata: tipo entità, id locale, `remoteID` opzionale, azione proposta (create/update), hash o fingerprint campi rilevanti. |
| **`PushBlockedReason`** | Enum/struttura: motivo (partial pull, account, tombstone, stale, missing ref, …), messaggio UX, severità. |
| **`PushWarning`** | Non bloccante: prezzo, stale leggero, dipendenze locali. |
| **`PushPayloadSummary`** | Conteggi per tabella: create/update/no-op/blocked; **bytes stimati** opzionale futuro. |
| **`PushTablePlan`** | Per suppliers / categories / products: slice di candidati e blocked collegati. |
| **`ProductPricePushPreview`** | Solo **future / disabled** — elenco conteggi o «not included». |

**Regole**: calcolo **in-memory** da SwiftData + ultimo snapshot; **nessuna** chiamata RPC di scrittura; eventuali letture read-only già permesse dal foundation **non** sono «push».

### Read-only network policy
- **Slice A futura**: solo **modelli puri + test**; **nessuna rete**.
- **Slice B futura**: la UI preflight deve poter usare **snapshot locale già disponibile** senza dipendere da refresh live obbligatorio.
- Un eventuale **refresh read-only Supabase** prima del preflight deve essere una **slice separata** oppure essere **esplicitamente autorizzato** nel task/turno.
- In ogni caso, TASK-041 resta **zero write remota**.
- Se in futuro servirà controllare dati remoti live, usare **solo** funzioni read-only già esistenti e documentare chiaramente che **non è push**.

---

## 7. Tombstone-compliant policy

1. **Non aggiornare** record remoti marcati tombstone / `deleted_at` nel **futuro** push: pianificazione esplicita.
2. **Non cancellare** record remoti in TASK-041 (né in execution futura vincolata solo a preflight/dry-run).
3. **Delete outbound reale** → task futuro (**Slice F**).
4. Se **locale** intende «eliminare» un prodotto che ha ancora identità remota → TASK-041 documenta solo **«future tombstone outbound candidate»** in preview, senza chiamata API.
5. Se **remoto** ha `deleted_at` e **locale** è ancora **attivo** (non allineato) → **preflight blocca** e richiede pull/risoluzione esplicita.

---

## 8. `record_sync_event` / `sync_events` policy

- **TASK-041** (e la prima execution di preflight/dry-run) **non chiama** `record_sync_event`.
- **TASK-041** può pianificare come, in futuro, calcolare **`changed_count`** per coerenza con eventi (somma create/update esclusi no-op, con regole backend).
- Se **`changed_count` > 1000** → in futuro il task di write dovrà **spezzare eventi** o attendere **fix backend** — collegamento diretto al rischio **Android TASK-071** (`PayloadValidation` / limite RPC).
- **Nessun** insert in `sync_events` in TASK-041.

---

## 9. UX / UI planning (SwiftUI nativo)

**Posizione proposta**: `OptionsView` — nuova **Section «Push manuale»** accanto alle sezioni DEBUG Supabase esistenti (no redesign globale).

| Elemento | Comportamento |
|----------|----------------|
| Stato account | Testo: connesso / non connesso; email o id opaco privacy-safe. |
| Ultimo pull completo | Indicatore complete vs partial + data/ora se disponibile. |
| Stato preflight | Idle / Running (con `ProgressView`) / Completed / Error. |
| Conteggi | create / update / no-op / blocked / warnings (da `ManualPushPreview`). |
| Conflict summary | Lista sintetica o badge numerici con drill-down minimale (futura execution). |
| **CTA «Esegui preflight push»** | Disponibile quando l’utente è autenticato e l’app può leggere lo stato locale necessario; il preflight può produrre blocker/warning/info per spiegare perché un invio futuro è bloccato. Se manca sessione Supabase valida o stato locale minimo, la CTA resta disabilitata con motivo visibile. |
| **CTA futura «Invia a Supabase»** | **Disabilitata** o assente fino a task push reale; sotto: **motivi disabilitazione** (partial pull, conflitti critici, account, «non implementato»). |

**Regole UX**: `Form` / `Section` / `Label` / `ProgressView`; copy chiaro: **preflight**, **dry-run**, **nessuna scrittura eseguita**; nessuna azione distruttiva; localizzazioni IT/EN/ES/ZH-Hans in fase execution.

**Nota esplicita di sicurezza UX**:
- `Esegui preflight push` può essere disponibile anche in presenza di blocker: serve a mostrare motivi di blocco, warning e info.
- Nella **prima UI futura** non mostrare un bottone **attivo** `Invia a Supabase`.
- Se il bottone compare per ragioni di roadmap/trasparenza, deve essere **disabilitato** con spiegazione visibile: **non ancora implementato / task futuro**.
- La copy deve ripetere **preflight**, **dry-run**, **nessuna scrittura eseguita** per evitare che l’utente interpreti il risultato come upload cloud già avvenuto.
- Mostrare banner/footnote esplicita: **“Nessuna scrittura su Supabase verrà eseguita”**.
- Il risultato preflight deve preferire copy: **“pronto per invio futuro”** o **“nessun cambiamento rilevato rispetto alla baseline”**, non “sincronizzato” in senso assoluto.
- Il preflight può produrre output con blocker/warning/info, ma non deve produrre azioni remote.

---

## 10. Execution slicing futura (proposta)

| Slice | Contenuto | Esclusioni |
|-------|-----------|------------|
| **A** | Solo modelli/enum/servizio puro preflight-dry-run + XCTest; nessuna rete, nessuna UI, nessuna persistenza baseline complessa | Push reale, UI, rete |
| **B** | UI `OptionsView` preflight + localizzazioni usando stato locale/snapshot già disponibile | Push reale |
| **C** | Eventuale baseline persistence (se davvero necessaria e autorizzata) con policy versioning/invalidation | Push reale |
| **D** | Write reale supplier/category/products — **task futuro** (es. TASK-042) | `record_sync_event`, prezzi |
| **E** | ProductPrice push — **task futuro** | Catalogo |
| **F** | `record_sync_event` / outbox e tombstone outbound/delete — **task futuro separato** | — |

Ordine consigliato: **A → B** (e solo se necessario **C**) prima di **D**. La prima execution non deve mescolare UI, rete e persistenza baseline complessa.

### Definition of Ready — futura Slice A

> La **prima execution consigliata** sotto TASK-041 deve essere **solo**: **Slice A — modelli puri preflight/dry-run + test**.

Checklist Ready:
- [ ] utente autorizza esplicitamente **PLANNING → EXECUTION**
- [ ] **TASK-040** confermato **DONE**
- [ ] `docs/MASTER-PLAN.md` conferma **TASK-041 ACTIVE / PLANNING** prima della transizione
- [ ] nessuna write Supabase
- [ ] nessun accesso rete
- [ ] nessuna UI
- [ ] nessun service remoto write
- [ ] nessun `record_sync_event`
- [ ] nessun outbox / dirty persistente
- [ ] solo modelli / enum / servizio puro **in-memory**
- [ ] nessuna baseline persistence complessa
- [ ] nessuna modifica a `Models.swift` salvo autorizzazione esplicita
- [ ] nessuna nuova proprietà SwiftData persistente
- [ ] test unitari pronti

### Acceptance criteria futura — Slice A

> Criteri futuri di execution/review. **Non** da marcare DONE ora.

- [ ] creati modelli/enum puri per `ManualPushPreview` / `ManualPushPlan` / `PushCandidate` / `PushBlockedReason` / `PushWarning`
- [ ] nessun accesso rete (e nessun codice di rete write)
- [ ] nessuna UI
- [ ] nessuna modifica SwiftData persistente, salvo motivazione documentata e autorizzata
- [ ] nessuna baseline persistence complessa
- [ ] nessuna modifica a `Models.swift` salvo autorizzazione esplicita
- [ ] tutti i tipi Slice A sono puri/in-memory
- [ ] ogni `ManualPushPlan` resta dry-run/non-sendable
- [ ] test puri su categorie preflight
- [ ] test per `blockedPartialPull`
- [ ] test per `blockedAccountMismatch`
- [ ] test per `blockedMissingBaseline`
- [ ] test su baseline invalidata
- [ ] test per `noOpAlreadySynced` solo con baseline mock valida
- [ ] test per `dryRunCreateCandidate`
- [ ] test per `dryRunUpdateCandidate`
- [ ] test su `sendable=false` (o equivalente concettuale)
- [ ] test fingerprint normalization
- [ ] test local-only supplier/category
- [ ] test per `blockedTombstoneConflict`
- [ ] test per `futurePricePushCandidate`
- [ ] test per `changed_count > 1000` come warning/future split
- [ ] build Debug PASS
- [ ] build Release PASS
- [ ] XCTest PASS
- [ ] `git diff --check` PASS
- [ ] grep anti-scope PASS

---

## 11. Test planning (futura execution)

| # | Scenario | Atteso |
|---|----------|--------|
| T1 | Ultimo pull **partial** | Preflight / CTA push bloccata; messaggio chiaro |
| T2 | **Account mismatch** | Blocco |
| T3 | Nessuna baseline affidabile | `blockedMissingBaseline` |
| T4 | Baseline presente + fingerprint uguale | **`noOpAlreadySynced`** |
| T5 | Baseline presente + fingerprint diverso | **`dryRunUpdateCandidate`** |
| T6 | Create candidate reale senza collisioni | Classificazione **`dryRunCreateCandidate`** corretta |
| T7 | Ordine supplier/category | Prodotti blocked finché manca `remoteID` su dipendenze |
| T8 | Tombstone remoto + locale attivo / `remoteDeletedAt` presente | `blockedTombstoneConflict` |
| T9 | ProductPrice locale modificati | `futurePricePushCandidate`, non payload catalogo |
| T10 | Dry-run | Nessuna API write / nessun `insert` network |
| T11 | `changed_count` > 1000 (simulato) | warning/future event split pianificato |
| T12 | Localizzazioni | Chiavi complete |
| T13 | UI | Motivi disabilitazione visibili e nessuna CTA push attiva |

---

## 12. Anti-scope checks (futura execution — grep / review)

Verificare assenza di:
- `insert` / `update` / `upsert` / `delete` Supabase client verso tabelle inventory
- `record_sync_event`
- Outbox / «dirty» persistito
- Migration SQL / `db push`
- ProductPrice push
- Realtime / background `sync`

---

## 13. Criteri di accettazione (planning — questo task documentale)

- **CA-1**: TASK-041 creato come **ACTIVE / PLANNING**.
- **CA-2**: `docs/MASTER-PLAN.md` iOS aggiornato coerentemente.
- **CA-3**: TASK-040 resta **DONE** (non modificato nel perimetro chiusura).
- **CA-4**: TASK-039 resta **DONE**.
- **CA-5**: Android **TASK-068 PARTIAL** e **TASK-071** rischi documentati (§2, §8).
- **CA-6**: Nessuna execution Swift in questo turno.
- **CA-7**: Nessuna scrittura Supabase in questo turno.
- **CA-8–CA-10**: Preflight rules, dry-run design, tombstone policy documentati (§5–§7).
- **CA-11**: Policy `record_sync_event` documentata (§8).
- **CA-12**: UX planning documentato (§9).
- **CA-13**: Test planning documentato (§11).
- **CA-14**: Slicing futuro documentato (§10).
- **CA-15**: Out-of-scope forte documentato (header + §12).

---

## 14. Rischi

| Rischio | Mitigazione (planning) |
|---------|------------------------|
| Schema hosted ≠ migrations locali | Baseline sempre da ultimo pull completato + log diff in preview; nessuna assunzione raw su DDL |
| TASK-068 Android ancora PARTIAL | Non usare come prova di comportamento live per iOS |
| `record_sync_event` mismatch / `changed_count` | Spezzare eventi o attendere backend; non chiamare RPC finché contratto non è stabile |
| `remoteID` conflitti legacy | Allinearsi a TASK-040 `remoteIdConflict` / link |
| Dati creati prima del bridge | Classificazione `blockedNoRemoteID` / pull-first |
| Supplier/category senza `remoteID` | Ordine e blocked espliciti |
| ProductPrice fuori scope | Warning only |
| UX: utente crede sia già push reale | Copy ripetuto: «preflight / dry-run / nessuna scrittura» |
| Validazione live assente | Nessun GO a push reale senza task + review dedicati |

---

## 15. Check finali — planning-only (questo turno)

- [x] Solo **nuovo file task** + **`MASTER-PLAN`** iOS
- [x] Nessun Swift / `pbxproj` / `plist` / `Package.resolved` / SQL
- [x] Nessun Supabase write
- [x] TASK-041 **ACTIVE / PLANNING**; progetto **ACTIVE**
- [x] Responsabile: **Claude / Planner** (affinamento Cursor consentito; **non** Executor)

---

## Planning (Claude / Planner) — sezione formale

### Obiettivo
Definire un percorso **sicuro** verso push manuale: preflight + dry-run + policy tombstone + conferma UX, **senza** write remota nel task corrente e **senza** implementazione Swift nel turno di creazione.

### Analisi
Dopo TASK-040, iOS ha identità remota embedded e pull/apply affidabili ma **nessun** canale di scrittura catalogo. Android ha outbox e push avanzato ma con lacune live (**TASK-068**) e vincoli RPC (**TASK-071**). Un push iOS «frettoloso» duplicherebbe righe o violerebbe tombstone/RLS. Inoltre, senza una **baseline completa** dell’ultimo remoto noto, iOS non può classificare in modo sicuro `noOpAlreadySynced` o `dryRunUpdateCandidate`: serve strategia fingerprint prudente e blocker esplicito `blockedMissingBaseline`.

### Approccio proposto
1. Formalizzare categorie preflight e mondo di strutture dry-run (§5–§6).
2. Basare `noOp` / `update` solo su fingerprint contro baseline completa nota; senza baseline → blocker.
3. Separare nettamente **preview** da **TASK-042** (write reale).
4. Mantenere grep/review anti-scope per ogni slice execution.

### File da modificare (futura execution — elenco indicativo)
- Nuovo servizio tipo `SupabaseManualPushPreflightService` *(nome TBD)*
- `OptionsView.swift` (Section push)
- `Models.swift`: **non previsto per Slice A**. Contiene modelli SwiftData persistenti; non aggiungere flag o proprietà persistenti in TASK-041 Slice A salvo nuova autorizzazione esplicita.
- Slice A deve usare nuovi tipi puri/in-memory, ad esempio: `ManualPushPreview`, `ManualPushPlan`, `PushCandidate`, `PushBlockedReason`, `PushWarning`, helper fingerprint/normalizer puri.
- Nessuna nuova proprietà SwiftData persistente in TASK-041 Slice A.
- Baseline persistence resta fuori dalla prima Slice A, salvo nuova autorizzazione esplicita.

### Rischi
Vedi §14.

### Handoff — prossimo passo (*dopo approvazione planning utente*)
- **Prossima fase**: EXECUTION *(solo su override esplicito)*
- **Prossimo agente**: Cursor / Codex
- **Azione consigliata**: implementare **Slice A** (modelli + test puri) o chiedere refinement planning se il contratto backend non è ancora chiaro per la fase write

---

## Execution (Codex)

### 2026-05-05 — Slice A: modelli/servizio puro preflight dry-run

**Obiettivo compreso**
- Esecuzione autorizzata solo per **Slice A**: modelli/enum, fingerprint normalizer, servizio puro in-memory e XCTest.
- Ogni `ManualPushPlan` resta dry-run e non-sendable; nessuna azione di invio e nessun payload operativo remoto.
- Regola prudente documentata per prodotto locale senza `remoteID` e senza baseline: `blockedMissingBaseline`, perché senza ultimo snapshot completo non si distingue in modo sicuro create, collisione remota o link mancante.
- **TASK-040** e **TASK-039** restano **DONE** e non riaperti.

**File controllati**
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-041-supabase-manual-push-preflight-dry-run-tombstone-compliant-ios.md`
- `iOSMerchandiseControl/SupabasePullPreviewModels.swift`
- `iOSMerchandiseControl/SupabasePullApplyService.swift`
- `iOSMerchandiseControl/SwiftDataInventorySnapshotService.swift`
- `iOSMerchandiseControl/Models.swift` *(solo lettura; nessuna modifica)*
- `iOSMerchandiseControl/OptionsView.swift` *(solo lettura; nessuna modifica)*
- `iOSMerchandiseControl.xcodeproj/project.pbxproj` *(controllato; nessun diff finale necessario grazie ai filesystem synchronized groups)*
- Test target esistente `iOSMerchandiseControlTests`

**Piano minimo**
- Aggiungere tipi puri per categorie, severity, candidate, plan, preview, blocker/warning e fingerprint.
- Aggiungere `SupabaseManualPushPreflightService` puro senza SwiftData, UI, Supabase o accesso rete.
- Coprire con XCTest in-memory le categorie richieste, baseline missing/invalidation, tombstone, account/partial guard, lookup remoti mancanti, ProductPrice future-only, changed_count > 1000 e fingerprint normalization.
- Aggiornare solo tracking autorizzato.

**Modifiche fatte**
- `iOSMerchandiseControl/SupabaseManualPushPreflightModels.swift`: aggiunti `ManualPushPreview`, `ManualPushPlan`, `PushCandidate`, `PushCandidateAction`, `PushBlockedReason`, `PushWarning`, `PushSeverity`, `PushEntityKind`, `ManualPushFingerprint`, `ManualPushFingerprintNormalizer` e categoria interna `ManualPushPreflightCategory` con severity.
- `iOSMerchandiseControl/SupabaseManualPushPreflightService.swift`: aggiunto servizio puro `SupabaseManualPushPreflightService` con input in-memory, baseline valida/invalidata, guard account/partial/source errors, classificazione create/update/no-op/blocker/warning/future-only e invariant `isSendable == false`.
- `iOSMerchandiseControlTests/SupabaseManualPushPreflightTests.swift`: aggiunti test puri per no baseline, baseline equal/different, local-only senza baseline, account mismatch, partial pull, tombstone, supplier/category senza remoteID, future price, changed_count > 1000, dry-run invariant, create candidate, barcode collision, baseline invalidata, remote conflict.
- `iOSMerchandiseControlTests/ManualPushFingerprintNormalizerTests.swift`: aggiunti test per trim stringhe, nil vs empty esplicito, ordine campi deterministico, UUID canonical lowercase, uso di supplier/category `remoteID` nel fingerprint Product, numeri normalizzati.
- `docs/MASTER-PLAN.md`: aggiornato avvio execution Slice A come richiesto.
- Nessuna modifica a `Models.swift`, `OptionsView.swift`, `project.pbxproj`, SQL/migrations, plist o localizzazioni.

**Cosa NON è stato fatto**
- Nessuna UI.
- Nessuna rete.
- Nessuna chiamata Supabase.
- Nessuna scrittura Supabase (`insert` / `update` / `upsert` / `delete`).
- Nessun push reale.
- Nessuna baseline persistence.
- Nessuna nuova proprietà SwiftData persistente.
- Nessuna modifica a `Models.swift`.
- Nessun `record_sync_event` o scrittura `sync_events`.
- Nessun outbox / dirty marking persistente.
- Nessun ProductPrice push; i prezzi sono solo `futurePricePushCandidate`.
- Nessun SQL, migration o `supabase db push`.
- Nessuna modifica Android.

**Check eseguiti**
- ✅ ESEGUITO — Build Debug simulator: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'id=423B9CA2-9C81-4850-898A-AE064A3A1C09' CODE_SIGNING_ALLOWED=NO build` PASS.
- ✅ ESEGUITO — Build Release simulator: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Release -destination 'id=423B9CA2-9C81-4850-898A-AE064A3A1C09' CODE_SIGNING_ALLOWED=NO build` PASS.
- ✅ ESEGUITO — XCTest: `xcodebuild test -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'id=423B9CA2-9C81-4850-898A-AE064A3A1C09' CODE_SIGNING_ALLOWED=NO` PASS; suite completa PASS, inclusi 21 nuovi test Slice A.
- ✅ ESEGUITO — Nessun warning nuovo introdotto verificabile nei file Slice A: i build log mostrano solo warning toolchain AppIntents “No AppIntents.framework dependency found”, non relativo ai nuovi file.
- ✅ ESEGUITO — `git diff --check` PASS, includendo i nuovi file non tracciati via controllo `--no-index`.
- ✅ ESEGUITO — Grep anti-scope PASS sui nuovi file Swift/test: nessun `record_sync_event`, nessun `sync_events`, nessun outbox, nessun dirty, nessuna chiamata `.insert` / `.update` / `.upsert` / `.delete`, nessun SQL/migration.
- ✅ ESEGUITO — `Models.swift` modified check PASS: nessun diff su `iOSMerchandiseControl/Models.swift`.
- ✅ ESEGUITO — Modifiche coerenti con planning Slice A e criteri di accettazione Slice A verificati da test/static check.

**Rischi rimasti**
- Baseline persistence e collegamento a ultimo pull completo restano fuori Slice A; il servizio accetta baseline in-memory e blocca quando assente/invalidata.
- UI `OptionsView` non integrata: il preflight non è ancora eseguibile dall’app, perimetro intenzionale Slice A.
- Nessuna validazione live Supabase: intenzionale, perché Slice A è zero rete.
- `changed_count > 1000` è solo warning/future-only; nessuna integrazione event bus o backend.
- Le regole create/update sono conservative e dipendono dalla futura fornitura di baseline affidabile.

**Aggiornamenti file di tracking**
- Metadata TASK-041 aggiornati a **ACTIVE / EXECUTION** con responsabile **Cursor / Executor**.
- `docs/MASTER-PLAN.md` aggiornato a **TASK-041 ACTIVE / EXECUTION**, nota “Execution Slice A only — pure preflight/dry-run models and tests; no UI; no network; no Supabase writes; no persistent SwiftData model changes; TASK-040 and TASK-039 remain DONE.”
- Review e Fix lasciate vuote.

### Handoff post-execution verso Review — 2026-05-05

**Esito**
- Slice A implementata e verificata.
- Handoff a **Claude / Reviewer** per review tecnica contro i criteri Slice A.

**File modificati**
- `iOSMerchandiseControl/SupabaseManualPushPreflightModels.swift`
- `iOSMerchandiseControl/SupabaseManualPushPreflightService.swift`
- `iOSMerchandiseControlTests/SupabaseManualPushPreflightTests.swift`
- `iOSMerchandiseControlTests/ManualPushFingerprintNormalizerTests.swift`
- `docs/TASKS/TASK-041-supabase-manual-push-preflight-dry-run-tombstone-compliant-ios.md`
- `docs/MASTER-PLAN.md`

**Nota review**
- Verificare in particolare la policy scelta per local-only senza baseline (`blockedMissingBaseline`) e per supplier/category locali usati da Product (`blockedMissingSupplierCategoryRemoteID` + warning).

---

## Review (Claude)

### Review tecnica Slice A + fix diretto — 2026-05-05

#### 1. Esito
- **APPROVED_FIXED_DIRECTLY / DONE**

#### 2. Sintesi review
- Verificata Slice A contro planning e prompt utente: modelli/enum puri, fingerprint normalizer, servizio puro in-memory e XCTest mirati.
- Nessuna UI, nessuna rete, nessuna scrittura Supabase, nessuna persistenza baseline, nessuna modifica `Models.swift`, nessuna modifica Android.
- Fix diretti applicati:
  - account non collegato ora blocca come `blockedAccountMismatch`, coerente con planning "account mismatch / account non collegato";
  - chiavi barcode della baseline normalizzate con trim prima del collision check `blockedNoRemoteID`;
  - aggiunti test mirati per entrambi i casi.

#### 3. Matrice controlli
| Area | Esito | Evidenza |
|------|-------|----------|
| Governance/tracking | PASS | TASK-041 review eseguita su handoff Slice A; TASK-040 e TASK-039 verificati DONE; chiusura autorizzata dal prompt utente. |
| Scope Slice A | PASS | Solo nuovi file pure Swift/test + tracking; nessuna UI, rete, Supabase write, persistenza baseline o SwiftData persistent model change. |
| Modelli/enum | PASS | `PushSeverity` include `blocker/warning/info/futureOnly`; categorie richieste presenti; `ManualPushPlan.isSendable == false`. |
| Fingerprint | PASS | Ordine deterministico, trim, nil/empty espliciti, UUID canonical lowercase, numeri stabili, Product usa supplier/category `remoteID`, ProductPrice escluso. |
| Servizio preflight | PASS | Input in-memory; baseline missing/invalidata blocca; equal fingerprint no-op; delta update dry-run; account/partial/tombstone/lookup blockers; ProductPrice future-only; changed_count > 1000 future warning. |
| Test | PASS | XCTest copre casi richiesti; aggiunti test per account non collegato e chiavi barcode baseline normalizzate. |
| Anti-scope | PASS | Grep sui nuovi Swift/test senza match per write/network/outbox/dirty/RPC/SQL. |
| Build/check | PASS | Debug PASS, Release PASS, XCTest completo PASS, `git diff --check` PASS. Warning AppIntents toolchain già noto e non introdotto da Slice A. |
| MASTER-PLAN | PASS | Aggiornato a TASK-041 DONE / progetto IDLE; follow-up futuri lasciati non attivi. |

#### 4. Comandi eseguiti
- ✅ ESEGUITO — Build Debug simulator: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'id=423B9CA2-9C81-4850-898A-AE064A3A1C09' CODE_SIGNING_ALLOWED=NO build` → PASS.
- ✅ ESEGUITO — Build Release simulator: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Release -destination 'id=423B9CA2-9C81-4850-898A-AE064A3A1C09' CODE_SIGNING_ALLOWED=NO build` → PASS.
- ✅ ESEGUITO — XCTest completo: `xcodebuild test -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'id=423B9CA2-9C81-4850-898A-AE064A3A1C09' CODE_SIGNING_ALLOWED=NO` → PASS; inclusi 17 test `SupabaseManualPushPreflightTests` e 6 test `ManualPushFingerprintNormalizerTests`.
- ✅ ESEGUITO — `git diff --check -- docs/MASTER-PLAN.md` → PASS.
- ✅ ESEGUITO — `git diff --check --no-index /dev/null ...` sui nuovi file TASK-041 non tracciati → PASS.
- ✅ ESEGUITO — Grep anti-scope sui nuovi Swift/test: `record_sync_event`, `sync_events`, `.insert`, `.update`, `.upsert`, `.delete`, `outbox`, `dirty`, `ProductPrice push`, `URLSession`, `SupabaseClient`, `rpc(`, `migration`, `db push` → PASS, nessun match.
- ✅ ESEGUITO — Verifica `Models.swift`, `OptionsView.swift`, `project.pbxproj`: `git diff -- iOSMerchandiseControl/Models.swift iOSMerchandiseControl/OptionsView.swift iOSMerchandiseControl.xcodeproj/project.pbxproj` → PASS, nessun diff.

#### 5. Rischi residui
- Baseline persistence fuori scope.
- UI `OptionsView` fuori scope.
- Integrazione con ultimo pull completo fuori scope.
- Live Supabase fuori scope.
- `changed_count > 1000` resta future-only; nessun `record_sync_event`/outbox attivato.
- Follow-up futuri NON attivati:
  - **TASK-042 candidato**: UI `OptionsView` preflight;
  - task futuro: baseline persistence;
  - task futuro: push reale supplier/category/products;
  - task futuro: ProductPrice push;
  - task futuro: `record_sync_event`/outbox;
  - task futuro: tombstone outbound/delete.

#### 6. Decisione finale
- **APPROVED_FIXED_DIRECTLY / DONE**. Slice A è corretta, semplice, in-memory e tombstone-compliant per il perimetro autorizzato. I microfix sono piccoli, locali e coperti da test. Build/test/check/anti-scope passano; **TASK-040** e **TASK-039** restano **DONE**.

---

## Fix (Codex)

### Fix diretto durante REVIEW — 2026-05-05

**Fix applicati**
- `iOSMerchandiseControl/SupabaseManualPushPreflightService.swift`: `ManualPushAccountState.hasMismatch` ora blocca anche account corrente o ultimo account collegato assente.
- `iOSMerchandiseControl/SupabaseManualPushPreflightService.swift`: `ManualPushBaseline` normalizza con trim le chiavi `remoteProductIDsByBarcode` in ingresso.
- `iOSMerchandiseControlTests/SupabaseManualPushPreflightTests.swift`: aggiunti test per account non collegato e collisione barcode con baseline key non normalizzata.

**Check post-fix**
- ✅ ESEGUITO — Build Debug simulator PASS.
- ✅ ESEGUITO — Build Release simulator PASS.
- ✅ ESEGUITO — XCTest completo PASS.
- ✅ ESEGUITO — `git diff --check` PASS.
- ✅ ESEGUITO — Grep anti-scope PASS.

**Chiusura**
- TASK-041 chiuso **DONE / Chiusura** su autorizzazione esplicita dell'utente, con esito **APPROVED_FIXED_DIRECTLY**.

---

## Decisioni registrazione

| # | Decisione | Motivazione | Stato |
|---|-----------|-------------|--------|
| 1 | Push reale solo in task successivo (es. TASK-042) | Sicurezza prodotto + dipendenze backend | attiva |
| 2 | Nessuna chiamata `record_sync_event` finché contratto non è chiaro | TASK-071 / limiti `changed_count` | attiva |
| 3 | TASK-068 Android non è prova live per iOS | PARTIAL | attiva |
| 4 | `noOpAlreadySynced` e `dryRunUpdateCandidate` richiedono baseline/fingerprint affidabile | Evitare falsi no-op / falsi update senza dirty persistente | attiva |
