# TASK-043: Supabase baseline/fingerprint persistence affidabile da ultimo pull completo

## Informazioni generali
- **Task ID**: TASK-043
- **Titolo**: Supabase baseline/fingerprint persistence affidabile da ultimo pull completo
- **File task**: `docs/TASKS/TASK-043-supabase-baseline-fingerprint-persistence-ios.md`
- **Stato**: DONE
- **Fase attuale**: Chiusura
- **Responsabile attuale**: Claude / Reviewer+Fixer
- **Data creazione**: 2026-05-05
- **Ultimo aggiornamento**: 2026-05-05 *(review APPROVED_FIXED_DIRECTLY; fix piccoli applicati; build/test/check PASS; TASK-043 chiuso DONE; no push reale, no write remote)*
- **Ultimo agente che ha operato**: Codex / Reviewer+Fixer

> **Turno corrente:** **CHIUSURA DONE** su override esplicito utente. Vincoli rispettati: **nessun push reale**, **nessuna scrittura remota Supabase**, nessun upsert/delete/RPC `record_sync_event`, nessuna outbox.

## Obiettivo
Implementare (in EXECUTION futura, dopo approvazione) una fondazione locale affidabile che registri cosa e' stato letto e **applicato con successo** dall'ultimo **pull completo** Supabase + **apply locale sicuro**, per supportare il preflight/dry-run TASK-041/TASK-042 senza falsi `noOp`/`update` ne' baseline parziali silenziose.

Questa task e' **foundation per push futuro**, **non** push reale, **non** outbox Android-like.

### Riferimenti lettura (coerenza)
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-040-supabase-full-pull-remote-identity-bridge-swiftdata-android-alignment.md`
- `docs/TASKS/TASK-041-supabase-manual-push-preflight-dry-run-tombstone-compliant-ios.md`
- `docs/TASKS/TASK-042-supabase-manual-push-preflight-ui-optionsview-dry-run-ios.md` *(file canonico TASK-042 in repo)*

## Contesto iOS (sintesi)
- TASK-034 DONE: foundation Supabase read-only.
- TASK-035 DONE: preview pull dry-run.
- TASK-038 DONE: OAuth + session-aware.
- TASK-039 DONE: apply locale controllato da preview sicura (guard su partial/conflicts/ecc.).
- TASK-040 DONE: full pull + `remoteID`/`remoteUpdatedAt`/`remoteDeletedAt` embedded su Product/Supplier/ProductCategory.
- TASK-041 DONE: `SupabaseManualPushPreflightService` + `ManualPushFingerprint` (versione numerica odierna nei tipi TASK-041) — **baseline ancora volatile/in-memory nella UI**.
- TASK-042 DONE: `SupabasePushPreflightViewModel` — oggi costruisce `ManualPushBaseline` **derivando** dai record locali, non da uno snapshot persistente post-pull completo.

## Riferimento Android/Supabase (concettuale)
- TASK-067..071: dirty/refs/outbox/backend limits — solo analogia mentale per iOS; **nessuna copia Kotlin**, nessun `record_sync_event` in TASK-043.

---

## Decisione storage baseline (TASK-043 — vincolante per execution)

### Scelta esplicita
- **Si usano una o piu' entita' SwiftData dedicate** alla baseline e ai fingerprint canonici (**non** dispersi dentro Product/Supplier/ProductCategory come unica strategy).
- **Non si usa `UserDefaults` / `AppStorage`** per snapshot o fingerprint **catalog** (solo eventuali chiavi UX minime fuori TASK-043 se gia' esistenti; **nessun catalog baseline in UD**).
- **Non si mischia** stato baseline/fingerprint dentro i modelli catalog business: i metadata gia' presenti (`remoteID`, `remoteUpdatedAt`, `remoteDeletedAt`) **restano** sui model attuali ma rappresentano **identita'/stato letto dopo apply**, non la **linea di base storica fingerprintata** salvata dopo un run completo.
- **Naming candidato** (solo planning; rinominabile in REVIEW minor):
  - **`SupabaseCatalogBaselineRun`** — un record **per run** di baseline valida dopo `fullPullApply` riuscito: accomuna `baselineRunUUID`, `ownerUserUUID`, `fingerprintSchemaVersion`, `appliedAt`, `status` dell'intero run, conteggi opzionali.
  - **`SupabaseCatalogBaselineRecord`** — **N righe**, una per entita' tipizzata: `product` | `supplier` | `productCategory`; chiave logica **`remoteID` + tipo** nell'ambito di un Run (implementazione SwiftData gestira' relazioni/unique in execution).
  - Alternative coerenti stile repo: `SupabaseSyncBaselineManifest` + `SupabaseSyncBaselineRow` *(se si preferisce evitare "Catalog" lungo)*.

### Contenuto minimo `SupabaseCatalogBaselineRecord` (planning contract)
Campi pianificati (tipi Swift esatti in EXECUTION):

| Concetto | Note |
|---------|------|
| **Owner user/account** | UUID Supabase `auth.users`-aligned (stesso uso RLS TASK-038/039/040); baseline valida **solo** per questo owner. |
| **baselineRunID** | UUID univoco **per questo commit di baseline globale** (tutti i Record del run condividono lo stesso). |
| **fingerprintSchemaVersion** | Intero/obbligatorio; bump invalida baseline vecchia (vedi sotto). |
| **entityType** | `product` / `supplier` / `productCategory`. |
| **remoteID** | UUID PK tabella `inventory_*` Supabase (righe catalogo). |
| **remoteUpdatedAt** | Snapshot del valore **remoto applicato** dopo apply (timezone: come gia' `Date?` dai DTO/parser). |
| **remoteDeletedAt** | Nullable; se presente, tombstone-aware in preflight (**nessun delete/push reale** in TASK-043). |
| **localModelID opzionale** | Solo diagnostica/debug (**non** chiave di verita', non fingerprint key). |
| **fingerprintCanonical** | Stringa canonica stabile (o Blob UTF-8) prodotta dalla serializzazione fissa TASK-043 (**non** `Double.description`). |
| **source** | Valore enum-like: **`fullPullApply`** (unico valorizzato in TASK-043 per baseline validi). |
| **createdAt / updatedAt locale** | Date locali: solo **metadati del record baseline**, non dentro il fingerprint catalog. |
| **status** *(principalmente Run)* | Lifecycle esplicito: vedi sezione **«Lifecycle commit baseline a due fasi»** (`building`, `valid`, `invalidated`, `stale`, `partialRejected`). Opzionale mirror diagnostico a livello Record in EXECUTION se utile. |

### Campi minimi aggiuntivi `SupabaseCatalogBaselineRun` (planning)
Oltre a quanto gia' implicito nel naming (`ownerUserUUID`, `baselineRunID`, `fingerprintSchemaVersion`, `source`, conteggi opzionali):
- **`status` Run**: include **`building`** (o equivalente nominato) come stato iniziale obbligatorio per ogni nuovo commit baseline.
- **`appliedAt`**: timestamp logico «pull completo applicato» (valorizzato quando il Run diventa `valid`, coerente con ultimo `save` riuscito).
- Logica `source == fullPullApply` gia' richiesta per run attendibili preflight.

Relazione suggerita: `Run 1:N Record`. In caso di migrazioni future, mantenere `Run` per audit e invalidazione atomica dell'intero snapshot.

---

## Lifecycle commit baseline a due fasi (`SupabaseCatalogBaselineRun`)

Decisione execution-ready:

1. **Nascita run**: ogni nuovo commit baseline crea un `SupabaseCatalogBaselineRun` in stato **`building`** (o nome equivalente documentato nel codice).
2. **Record**: tutti i `SupabaseCatalogBaselineRecord` previsti dallo snapshot post-apply vengono creati **associati** a quel run (relazione 1:N o FK logica via `baselineRunID` + `recordKey`).
3. **Promozione a `valid`**: il run diventa **`valid` solo dopo** che (a) tutti i record attesi sono stati **persistiti senza errore**, (b) `ModelContext.save()` (o equivalente) **completa con successo**, (c) eventuale verifica di completezza (conteggi attesi vs inseriti) passa.
4. **Fallimento**: se **qualsiasi** step fallisce (insert parziale, save fallito, mismatch conteggi, eccezione writer), il run **non deve mai** diventare `valid`. Stato finale ammesso: `partialRejected` / `invalidated` / resta `building` con flag esplicito di fallimento — **preflight non lo usa** (stesso trattamento di CA-31).
5. **Run falliti su disco**: possono restare per **debug/audit locale** ma il reader preflight li **ignora**; non sostituiscono il «latest valid» finche' non esiste un successore `valid`.
6. **Run precedente valido**: resta **l'unica baseline usabile** finche' il nuovo run **non** ha completato con successo la sequenza sopra (nessun «switch» a un run incompleto).

**Test pianificati (estesi in T-b16, T-b17):** fallimento durante commit baseline ⇒ nessun nuovo latest valid; vecchio latest valid resta selezionato se il nuovo commit fallisce.

---

## Chiavi sintetiche SwiftData (unique / dedup)

- **Non** affidarsi a vincoli unique compositi «impliciti» non documentati; pianificare identita' **esplicita**.
- **Record baseline**: chiave sintetica stringa es.
  `recordKey = "\(baselineRunID.uuidString)|\(entityType)|\(remoteID.uuidString)"`
  (ordine fisso; `entityType` valore canonico `product`|`supplier`|`productCategory`).
- **Run** (opzionale ma utile query/debug):
  `runKey = "\(ownerUserUUID.uuidString)|\(baselineRunID.uuidString)"`.
- **`remoteID` + `entityType` da soli non bastano**: lo stesso record remoto puo' comparire in **run storici** diversi senza collisione logica — la chiave deve includere **`baselineRunID`** (o equivalente stabile per run).
- **Preflight reader**: non naviga «tutti i Record globali»; carica solo i Record il cui `baselineRunID` coincide con il **latest valid run** selezionato (vedi sotto).

**Test pianificati:** T-b18 (due run, stesso `remoteID`, nessuna collisione grazie a `recordKey`), T-b19 (stesso run: duplicato `entityType+remoteID` deve essere **rilevato** o **impedire** commit silenzioso — assert o errore writer).

---

## Selezione «latest valid run» (regola reader preflight)

Il servizio di lettura baseline per il preflight deve selezionare **al piu' un** run che soddisfa **tutte** le condizioni:

| Filtro | Obbligatorio |
|--------|----------------|
| `ownerUserUUID` | Uguale a **`session.user.id`** corrente (autenticato) |
| `status` | `== valid` |
| `source` | `== fullPullApply` |
| `fingerprintSchemaVersion` | `== currentFingerprintSchemaVersion` (costante codice TASK-043 allineata a writer) |

**Ordinamento:** tra i run che passano i filtri, prendere il **più recente** per `appliedAt` **oppure**, se assente/`Date.distantPast`, **`createdAt` locale** (documentare una sola chiave dominante in EXECUTION per evitare tie ambigui).

**Se nessun run soddisfa il set:** risultato conservativo **`blockedMissingBaseline`** **oppure** **`blockedStaleOrPartialBaseline`** (es. quando esistono solo run stale schema — allineare messaggio UX al caso).
**Divieti espliciti:**
- **Mai** ricostruire la baseline dai **record catalogo SwiftData «vivi»** come sostituto dello snapshot TASK-043.
- **Mai** mescolare Record appartenenti a **run diversi** nello stesso confronto preflight.

**Test pianificati:** T-b22 + scenari nella matrice legacy (run vecchio valid + nuovo invalidated ⇒ reader usa vecchio valid; nuovo valid con schema stale ⇒ blocco; altro account ⇒ `blockedAccountMismatch`).

---

## Retention run storici (planning-only)

- **TASK-043** non introduce **delete/cleanup distruttivo** obbligatorio ne' UI reset/purge.
- In EXECUTION si **puo'** prevedere, se semplice e sicuro, di **mantenere** gli ultimi **2–3** run **per account** (inclusi falliti marcati) per audit; in ogni caso il preflight usa **solo** il latest valid che passa i filtri sopra.
- Eventuale **policy di pruning** runner storici oltre soglia ⇒ **follow-up separato** (non bloccante TASK-043).

---

## Atomicità pratica SwiftData (two-phase / staged)

- **Nessuna promessa** di transazioni SQL manuali o API non gia' usate nel progetto: coerenza garantita da **strategia staged** + stati Run espliciti.
- **Sequenza pianificata** (writer dedicato, testabile XCTest):
  1. Creare `SupabaseCatalogBaselineRun` in stato **`building`**.
  2. Inserire tutti i `SupabaseCatalogBaselineRecord` attesi (chiavi `recordKey` uniche nello stesso run).
  3. **Primo `save()`** dopo inserimenti.
  4. Verifiche di completezza (conteggi, dedup, assenza errori).
  5. Solo se OK: impostare Run `valid`, valorizzare `appliedAt`/`source`/`fingerprintSchemaVersion` coerenti.
  6. **Secondo `save()`** dopo transizione stato.
- Se lo **step 5–6 fallisce** (`save` errore, crash intermedio ripreso, ecc.), il reader **non** deve trattare quel run come `valid` (stato residuo `building`/`partialRejected`/`invalidated` — CA-31).
- Incapsulamento in **servizio unico** (`SupabaseCatalogBaselineWriter` o nome equivalente) raccomandato per test e grep anti-write.

**Test pianificati:** T-b20, T-b21 (reader ignora `building` e `partialRejected`); invariante gia' coperta da T-b16–T-b17 per fallimento commit.

---

## Policy baseline globale (no baseline parziale silenziosa)

Regola TASK-043 **(non negoziabile per execution)**:

1. **Solo pull + apply dichiarati completi e sicuri** permettono un **refresh atomico globale** della baseline (nuovo `SupabaseCatalogBaselineRun` in `building` + set completo di `SupabaseCatalogBaselineRecord` previsti; promozione a `valid` solo dopo sezione **Lifecycle** / **Atomicità SwiftData**).
2. **Se anche una sola** delle condizioni fallisce, **non aggiornare** la baseline globale:
   - preview/pull **partial** (catalog incompleto, budget, errore paginazione catalogo prodotti/fornitori/categorie come oggi in `SyncPreview`/TASK-039);
   - **sourceErrors** non vuoti (incluso ogni errore catalogo TASK-039/040 blocca il no-op sulla baseline aggiornata);
   - **conflitti** qualunque inclusi `remoteIdConflict`, `missingRemoteReference`, duplicati catalogo/remoto;
   - **mapping incoerente** supplier/category vs product dopo apply teorico — trattato come **sicurezza < complete run** ⇒ no nuova baseline valida;
   - **apply non completato**, rollback dopo `save` fallito, o `previewStale` durante apply pianificato dalla UI.
3. **Niente baseline parziale "silenziosa"**: mai marcare subset di righe baseline `valid` lasciando residui di run precedenti come se fossero coerenti con un nuovo pull parziale.
4. Preflight conseguenza: preferire **`blockedStaleOrPartialBaseline`** (nome logico TASK-041 estendibile) invece di rischiare `noWork` falso dopo contesto incompleto.

Decisione correlata TASK-039: dopo apply fallito, **run precedente** resta baseline finche' non viene sostituito da un nuovo commit **globale valido**.

---

## Policy `newLocal` (solo dry-run / preflight)

- `newLocal` / `dryRunCreateCandidate` in TASK-041/042 rimangono **classificazioni preflight**, **mai** equivalgono "pronto per push reale".
- Il **push futuro** dovra': collision check **remoto** su barcode/nome/`remoteID` **prima** di qualsiasi upsert; TASK-043 **non implementa** quella query.
- **UX copy** (solo planning): es. italiano «Nuovo locale — push reale non ancora disponibile» (localizzabile IT/EN/ES/ZH-Hans in EXECUTION se si tocca UI).

---

## Fingerprint canonico (precisioni execution-ready)

### Serializzazione
- Ordine campi **fisso e documentato** (array di coppie `chiave→valore` normalizzato o formato `k=v|` con escape come gia' pattern TASK-041, ma **valor numerici** tramite **`Decimal`/stringa canonica dedicata**, **non** `Double.description`).
- Ripetizioni dello **stesso insieme semantico** in ordine diverso ⇒ **stesso fingerprint** (test dedicato TASK-043).
- **Trim** whitespace su stringhe barcode/nomi/item number come allineamento `SupabasePullPreviewNormalizer.semanticString` / `normalizedBarcode`.
- **`nil`** vs **`""` dopo semantic string**: documentare parity con TASK-041 (`string:nil` vs `string:empty` dove applicabile ai campi catalogue).

### Numeri decimali / quantità
- Prezzi (`purchasePrice`, `retailPrice`) e `stockQuantity` → normalizzazione **Decimal-based** poi stringa stabile es. formato posizionale fissato o `NSDecimalNumber` con politica rounding **documentata una tantum** (evitare `1`, `1.0`, `1.00` come tre fingerprint diversi — test CA-21).

### Relazioni Product
- Fingerprint Product usa **`supplierRemoteID`** e **`categoryRemoteID`** (UUID o nil canonico).
- **Mai** usare PersistentIdentifier / objectID SwiftData nel fingerprint.

### Supplier/Category affidabilita'
- Se un Product ha una relazione business a supplier/category **senza `remoteID` remoto disponibile**, il record NON e' affidabile per confronto baseline "post pull completo" finche' quel gap esiste ⇒ classificazione **conservativa** (blocked o escluso dall'aggregato noWork ai fini sicurezza) — dettaglio implementativo in EXECUTION ma **gia' vincolato** nel planning che non deve produrre silently `changedLocally`.

### Campi fingerprint per entità (catalogo TASK-043)

**Product**
- barcode normalizzato
- itemNumber normalizzato optional
- productName normalizzato
- secondProductName normalizzato optional
- purchasePrice canonico Decimal/string optional
- retailPrice canonico Decimal/string optional
- stockQuantity canonico Decimal/string optional
- supplierRemoteID canonico UUID optional
- categoryRemoteID canonico UUID optional

**Supplier**
- remoteID
- name normalizzato

**ProductCategory**
- remoteID
- name normalizzato

### Esclusioni esplicite dal fingerprint TASK-043
- persistent local ID SwiftData (`PersistentIdentifier`/objectIDs)
- timestamp locali ad-hoc/UI
- stato UI locale
- campi diagnostici generici/volatile
- **ProductPrice** (fuori TASK-043)

### Fonte del valore usato per il fingerprint baseline salvato

Decisione vincolante:

- Il **`fingerprintCanonical`** persistito nella baseline deve essere calcolato sullo **stato locale SwiftData dopo apply riuscito e `save()` del catalogo**, **non** sul solo DTO/remoto raw prima dell'apply.
- **Motivazione:** la baseline rappresenta cio' che **iOS ha effettivamente applicato e persistito**; il preflight deve confrontare «cosa c'e' adesso su disco» vs «ultimo commit baseline noto buono».
- Se un campo esiste nel **DTO remoto** ma **non viene applicato** al modello TASK-039/040 (ignorato dal apply), **non entra** nel fingerprint TASK-043.
- Se l'apply **normalizza** o **arrotonda** valori rispetto al wire format, il fingerprint deve riflettere i **valori effettivamente salvati** nei modelli catalogo (lettura dopo save o snapshot value-type ricostruito da quella lettura — mai assumere equivalenza raw DTO).
- Il writer puo' costruire **struct `Sendable` di snapshot** post-fetch/post-save sul `ModelContext` per calcolo fingerprint off-main o batch, evitando di passare `@Model` cross-thread.

**Test pianificati:** T-b23 (equivalenza semantica DTO formati diversi ⇒ fingerprint stabile post-apply); copertura aggiuntiva implicita con T-b10/T-b11 dopo integrazione Reader.

---

## Strategia account / sessione

- Baseline **`valid`** solo se **`ownerUserUUID` del Run** coincide con **`session.user.id` corrente** autenticata.
- Logout/login con **altro account**: il preflight mostra **`blockedAccountMismatch`** (gia' pattern TASK-041; baseline vecchia può rimanere su disco marcata **`invalidated`/`stale`** o lasciare `Run` storico ma **non usabile** per confronti finche' non reconcile — vedi dopo).
- **Non cancellare baseline automaticamente** TASK-043 (preferenza sicurezza/audit locale); uso `status`/`invalidated` più che delete distruttiva.
- **Privacy UI/log**: **mai** UUID completo in debug copy standard; uso **forma abbreviata** (prime 8 chars + `…`) oppure chiave solo conteggio («account collegato») come gia' stile app.
- Sessione **assente** / non auth-gated: come TASK-042 — **preflight blocca** (`accountNotLinked` / `blockedAccountMismatch`/`sessionMissing`), **nessuna baseline considerata attendibile**.

---

## Invalidation e versioning (`fingerprintSchemaVersion`)

- Ogni **`SupabaseCatalogBaselineRun`** porta **`fingerprintSchemaVersion`** obbligatorio (allinea costante Swift condivisa con normalizer TASK-041 o versione TASK-043 dedicata se fork necessario documentato).
- **Bump versione fingerprint** ⇒ tutti i `Run`/`Record` con versione **inferiore** sono **`stale`/`invalidated`** per uso preflight ⇒ **`blockedStaleOrPartialBaseline`** o equivalente (non `changedLocally`).
- **Nessuna migrazione distruttiva catalog** business TASK-043: solo additive SwiftData sulle nuove entity baseline.
- Test: caricare fixture baseline **vecchia schema** ⇒ preflight blocca categoricamente senza falsi unchanged.

---

## Tombstone nella baseline e preflight (TASK-043)

- `remoteDeletedAt` nel **Record baseline** documenta il fatto che **la riga remota** portava un tombstone informativo al momento dell'apply (allineamento TASK-039/041).
- **TASK-043**: nessun **delete locale** guidato solo da baseline; **nessun outbound delete** verso Supabase.
- Se un **Product/Supplier/Categoria locale** ancora referenziato esiste con `remoteID` che nella baseline selezionata ha **`remoteDeletedAt != nil`** (policy record ancora persistito dopo apply TASK-039), il preflight classifica **`blockedTombstoneConflict`** (o path equivalente TASK-041) — **mai** **`dryRunUpdateCandidate`** solo perche' cambia un campo locale accanto al tombstone.
- **UX DEBUG** (slice E): al massimo **conteggio tombstone** nel run corrente; **nessuna** lista dettagliata di righe/barcode.

**Test pianificato:** T-b24 — baseline con `remoteDeletedAt` + modello locale ancora presente ⇒ blocker tombstone, non changedLocally/update candidate.

---

## Performance (catalogo grande)

- Calcolo fingerprint in **servizio `@MainActor` o actor dedicato** + batch (chunks), **mai** nell view body synchronous massivo.
- Usare **`Task`/detached** solo su **value types** dopo snapshot `Sendable` (pattern esistente preflight TASK-042).
- **Zero log** di payload interi o liste barcode; solo **counts**, **tipi errore**, **run id troncato**.
- UI solo **summary** e chip (come card Supabase TASK-042); nessun dump liste 20k.
- XCTest sintetico **medio/grande** (millier di righe in-memory **solo batch logic**, non Simulator stress) — se coerente con CI.

---

## UX / UI DEBUG (solo pianificazione, zero implementazione in questo task documentale turn)

Decisioni UX TASK-043 (slice E opzionale):

- Card **solo read-only**, layout **SwiftUI nativo**, **stesso linguaggio visivo** delle card Supabase gia' in **`OptionsView` DEBUG** (TASK-035/038/042).
- **Niente** `Table`/liste scrollabili pesanti dei Record baseline; solo **summary compatto**.
- Footer fisso sulla card: equivalente localizzato alla riga **Footer push** nella tabella microcopy sotto (**Push reale non ancora disponibile** / …).
- Riassunto suggerito (ordine adattabile):
  1. **Stato baseline:** *Assente* / *Valida* / *Stale* (schema) / *Account diverso* / *Incompleta* (run `building` o commit fallito).
  2. **Ultimo pull completo:** `appliedAt` del latest valid (**non** timeline eventi).
  3. **Account abbreviato** (privacy-safe).
  4. **Conteggi** nel run: Prodotti, Fornitori, Categorie.
  5. **`fingerprintSchemaVersion`** (schema fingerprint).
  6. **Tombstone count** opzionale (solo numero aggregate).
  7. In caso mismatch/stale: messaggio **user-safe** (**non** raw UUID/stack tecnico nella card standard).
- **Vietato in TASK-043 UI**: reset / delete / purge baseline (`CA-33`).
- Preferire layout **SwiftUI più nativo possibile**, coerente con padding/type delle DEBUG card esistenti.

### Microcopy proposta (planning-only; **nessuna** chiave localize aggiunta in questo turno)

| Concetto | IT | EN | ES | ZH-Hans |
|----------|--|--|--|---------|
| Titolo card | Baseline Supabase locale | Local Supabase baseline | Línea base Supabase local | 本地 Supabase 基线 |
| Stato assente | Nessuna baseline salvata | No saved baseline | Sin línea base guardada | 未保存基线 |
| Stato valida | Baseline attiva | Active baseline | Línea base activa | 基线有效 |
| Stato stale schema | Baseline obsoleta (schema) | Outdated baseline (schema) | Línea base obsoleta (esquema) | 基线已过期（架构版本） |
| Account diverso | Account diverso dalla baseline | Account doesn't match baseline | La cuenta no coincide con la línea base | 账户与基线不匹配 |
| Incompleta | Baseline incompleta | Baseline incomplete | Línea base incompleta | 基线未完成 |
| Footer push | Push reale non ancora disponibile | Real push not available yet | El envío real aún no está disponible | 真实推送暂不可用 |
| Errore generico user-safe | Controlla la connessione e ripeti il pull completo | Check your connection and run a full pull again | Comprueba la conexión y repite el pull completo | 请检查网络后重新执行完整同步 |

*(Le chiavi `Localizable` saranno definite solo in EXECUTION slice E.)*

---

## Integrazione preflight / mappa stati (TASK-041 servizio + TASK-042 VM)

**Prerequisito lettura baseline:** tutte le righe della tabella sotto presumono confronto tramite **`SupabaseCatalogBaselineReader`** che carica esclusivamente i Record del **`latest valid run`** definito sopra (**CA-27**, **CA-28**); run `building`/`partialRejected`/`invalidated`/`stale` schema restano ignorati (**CA-31**).

Estensioni `ManualPushBlockedReason` / categorie pianificate *(nomi confermati in EXECUTION, mapping 1:1 con localizzazioni)*:

| Condizione runtime | Risultato preflight TASK-043 |
|--------------------|-------------------------------|
| Nessun run dopo filtro latest-valid (CA-27) | **`blockedMissingBaseline`** — blocco conservativo |
| UUID sessione != owner Run selezionato | **`blockedAccountMismatch`** |
| `fingerprintSchemaVersion` mismatch rispetto a costante codice corrente | **`blockedStaleOrPartialBaseline`** *(o subtype CA-23)* |
| Run `partialRejected` / `invalidated` / `building` / fallito prima di `valid` | **Non selezionabili**; se nessun alternativo ⇒ **`blockedStaleOrPartialBaseline`** o **`blockedMissingBaseline`** |
| Fingerprint locale (post-catalogo) == `fingerprintCanonical` Record stesso remoteID (**stesso Run**) | **`noOpAlreadySynced` / unchanged / noWork** |
| Baseline OK + fingerprint diverso (`remoteID` presente + FK affidabile, no tombstone conflict) | **`dryRunUpdateCandidate`** — **solo dry-run** |
| Nessun `remoteID`, baseline valida, record nuovo conforme policy | **`dryRunCreateCandidate`** + copy **Nuovo locale** |
| Record baseline con **`remoteDeletedAt`** e modello locale ancora esistente con stesso remoteID | **`blockedTombstoneConflict`** — **mai** tratto solo come `dryRunUpdateCandidate` (**CA-32**, T-b24) |
| `remoteID` su model ma nessun Record nel latest valid *(edge perdita coerenza)* | **`blockedMissingBaseline`** / suspicious — (**non** `dryRunUpdateCandidate`) |

Invariante TASK-042: non rompere `completedSafe/completedNoWork/completedBlocked` mapping esistenti; estendere con nuovi blocker/warning dove necessario.

---

## Confine con TASK-044 / push futuro (anticipo solo documentale)

- **TASK-043** si ferma su: **persistenza baseline** affidabile + preflight TASK-041/042 piu' conservativo usando **solo** baseline Run/Record.
- **`TASK-044`** (o task successivo esplicitamente numerato/negoziato) potra' introdurre **push reale** che **consuma** questa baseline per dirty detection / collision / upsert orchestrato — fuori TASK-043.
- **TASK-043 non implementa**: outbox Android-like, retry/backoff, `record_sync_event`, RPC mutate, alcuna Supabase write.
- Android TASK-068 / TASK-070 restano **riferimento concettuale** per «evitare falsi dirty/no-op» — **non** modello da replicare 1:1 in Swift (**CA-34**).

---

## Scope incluso / escluso (ripristino non ambiguo)

**IN**
- Piano + future execution delle entity SwiftData dedite baseline sopra nominate (Run lifecycle, Record + `recordKey`).
- Writer/Reader (**latest valid**) + policy retention non distruttiva.
- Policy global commit snapshot + invalidation versioning.
- Allineamento preflight TASK-041/042 + UX DEBUG read-only optional (summary).

**OUT**
Push **reale**, write remoti, RPC, **`record_sync_event`**, outbox, retry/backoff orchestrati — ambito **TASK-044** o task successivo; fuori TASK-043 (**CA-34**). ProductPrice catalog push / modifiche schema Supabase (`project.pbxproj` solo quando SwiftData registra nuovi `@Model`, **solo in EXECUTION**).

---

## File iOS probabilmente coinvolti (EXECUTION futura)

- Nuovi file `@Model`: `SupabaseCatalogBaselineRun.swift`, `SupabaseCatalogBaselineRecord.swift` *(nomi confermati)*
- `iOSMerchandiseControlApp.swift` — registrazione schema nuovi `@Model`.
- Servizi baseline: **`SupabaseCatalogBaselineWriter`** (commit staged due fasi), **`SupabaseCatalogBaselineReader`** (latest valid run + fetch Record scoped).
- Integrazione dopo `save` felice pull apply: orchestrazione dentro `SupabasePullApplyService`/`OptionsView` coordinator *minimo*.
- Aggiornare `SupabaseManualPushPreflightService.swift`, `SupabaseManualPushPreflightModels.swift`, `SupabasePushPreflightViewModel.swift`
- Tests `iOSMerchandiseControlTests/*`

---

## Planning per slice (EXECUTION ordinata dopo override)

| Slice | Focus |
|-------|--------|
| **A** | Tipi canonici Decimal fingerprint + XCTest pure (senza salvare `@Model`). |
| **B** | SwiftData in-memory `@Model` Run/Record + CRUD/tests. |
| **C** | Hook post-success `fullPullApply`: writer staged (`building`→Record→save→`valid`→save) + **nessun** uso preflight fino a `valid`; invalidazione run vecchi solo dopo successo documentata. |
| **D** | Preflight TASK-041/042 integrazione blocchi/noWork/update/new. |
| **E** | UI DEBUG card baseline (solo se ordinata dopo D). |
| **F** | Suite anti-write grep + regressione localize. |

---

## Matrice test XCTest (TASK-043 ampliata)

| # | Scenario | Atteso |
|---|----------|--------|
|T-b1 | CRUD SwiftData in-memory baseline Run/Record | persistenza ok |
|T-b2 | Preview/pull/apply **partial** | baseline globale NON aggiornata |
|T-b3 | `sourceErrors` presenti dopo fetch | baseline NON aggiornata |
|T-b4 | Conflitto `remoteID` blocca sync safe | baseline NON aggiornata |
|T-b5 | Input semantico uguale, ordine costruzione campi diverso | fingerprint uguale |
|T-b6 | `Decimal` canonico (`1`, `1.0`, `1.00`) | stesso fingerprint |
|T-b7 | Supplier stesso nome, `remoteID` diversi | non unificazione silenziosa (policy preflight/supplier fingerprints differiscono) |
|T-b8 | Account mismatch | `blockedAccountMismatch` |
|T-b9 | `fingerprintSchemaVersion` stale | blocker `blockedStaleOrPartialBaseline` |
|T-b10 | Product locale conforme baseline | noWork/`noOpAlreadySynced` |
|T-b11 | Product locale campo business mutato vs baseline | `dryRunUpdateCandidate` |
|T-b12 | Product locale senza remoteID baseline valid collision-free | `dryRunCreateCandidate`/newLocal copy |
|T-b13 | Product con remoteID baseline record assente (edge sicurezza) | `blockedMissingBaseline`/`suspicious` non upgrade automatico changed |
|T-b14 | Grep/strumentazione codice dopo Swift | zero chiamata write remota ai path Supabase client |
|T-b15 | UI strings / microcopy | IT/EN/ES/ZH-Hans **solo** se slice E confermato |
|T-b16 | Nuovo Run: commit baseline fallisce **prima** che il Run diventi `valid` | Nessun nuovo latest valid — preflight continua sul run precedente se esiste |
|T-b17 | Nuovo Run fallisce; Run precedente ancora **`valid`** | Reader seleziona **solo** il vecchio valid |
|T-b18 | Due Run storici diversi, stesso `remoteID` nei Record | Nessuna collisione: `recordKey` include `baselineRunID` |
|T-b19 | Stesso Run: tentativo insert duplicato `entityType+remoteID` | Rilevato (assert/throw writer) — nessun doppione silenzioso |
|T-b20 | Run `building` rimasto dopo crash simulato | Reader/preflight **non** lo usano (**CA-31**) |
|T-b21 | Run `partialRejected` su disco | Reader **non** lo seleziona (**CA-31**) |
|T-b22 | Mock session/account diversi nel test | Solo run con owner = session (**CA-27**) |
|T-b23 | Stesso semantico: DTO wire diverso, ma apply converge | Fingerprint baseline = fingerprint da stato locale **post-save** (**CA-30**) |
|T-b24 | Record baseline `remoteDeletedAt` ≠ nil + Product locale presente | `blockedTombstoneConflict` (**CA-32**) |
|T-b25 | UI DEBUG baseline (slice E) | Nessun fetch lista completa Record per UI (**CA-33**) |

(Test esistenti TASK-039/040/041/042 restano verdi regressione.)

---

## Criteri di accettazione

- **CA-1**: TASK-043 planning completo; MASTER-PLAN aggiornato tracking.
- **CA-2**: Nessun task DONE riaperto.
- **CA-3..CA-18**: invariati (no write Supabase, no push, no record_sync_event, test build, localize, ecc. come TASK-042 handoff storico CA paralleli).
- **CA-19**: Storage baseline implementato solo come **entita' SwiftData dedicate** (Run + Record pattern), **mai** UD snapshot catalog.
- **CA-20**: Mai baseline parziale `valid` silenziosa dopo pull/apply non global-safe.
- **CA-21**: Fingerprint monetari/qty via **Decimal / string canonica stabile**, **non `Double.description` fragile**.
- **CA-22**: Fingerprint Product usa **solo** supplier/category **remote UUID**, mai local Persistent ID.
- **CA-23**: Baseline/`Run` con `fingerprintSchemaVersion` obsolete **invalidazione + blocco preflight**.
- **CA-24**: `newLocal` / create candidate rimangono **dry-run only** senza pathway push TASK-043.
- **CA-25**: UI DEBUG pianificabile resta **read-only / non distruttiva**.
- **CA-26**: Il **`SupabaseCatalogBaselineRun`** espone lifecycle esplicito: almeno **`building`** prima del completamento, e stati **`valid`** / **`invalidated`** / **`partialRejected`** (e **`stale`** dove applicabile) coerenti con invalidazione versioning; **mai** promozione a `valid` dopo fallimento intermedi.
- **CA-27**: Il preflight/Reader usa **solo** il **latest valid run** che soddisfa **stesso account** + **`source == fullPullApply`** + **`fingerprintSchemaVersion` corrente** + ordinamento temporale definito.
- **CA-28**: **Nessun** confronto baseline mescola Record provenienti da **run diversi**.
- **CA-29**: Ogni **`SupabaseCatalogBaselineRecord`** ha **chiave sintetica pianificata** (es. `recordKey`) per dedup deterministico dentro lo stesso run.
- **CA-30**: Il **`fingerprintCanonical`** nella baseline proveniente dall'writer e' derivato da **stato SwiftData post-apply persistito** (**non** da DTO raw pre-apply per campi non applicati, o non normalizzati come su disco).
- **CA-31**: Run **`building`**, **`partialRejected`**, **`invalidated`**, run **stale schema** ⇒ **mai** selezionati dal Reader per preflight.
- **CA-32**: Tombstone baseline (`remoteDeletedAt`) + modello locale ancorato ⇒ classificazione **conflitto tombstone** (`blockedTombstoneConflict` o equivalente), **mai** solo `dryRunUpdateCandidate`.
- **CA-33**: UI DEBUG TASK-043: solo **summary** compatto, conteggio tombstone eventualmente; senza liste pesanti e senza CTA distruttive.
- **CA-34**: TASK-043 **non** implementa push reale, outbox, sync, repliche Android TASK-068/070; prepara TASK-044 senza anticiparne il codice.

---

## Rischi residuali mitigate dal planning refinement

- Rischio **false no-op** ⇒ mitigato policy globale + latest-valid reader + blocker stale/partial (CA-20, CA-27).
- Rischio **UD corruption / size** ⇒ vietato UD catalog (CA-19).
- Rischio **`Double`** noise ⇒ Decimal canonico test (CA-21).
- Rischio **privacy leakage** ⇒ UUID abbreviati + logs counts-only.
- Rischio **run incompleto promosso valid** ⇒ lifecycle `building` + save doppio + CA-26/T-b16–T-b21.
- Rischio **collisione storici** ⇒ `recordKey` con runID (CA-29, T-b18–T-b19).
- Rischio **mismatch raw DTO vs disco** ⇒ fonte fingerprint post-save (CA-30, T-b23).
- Rischio **tombstone trattati come dirty lineare** ⇒ CA-32, T-b24.
- Complessita' SwiftData migrazioni ⇒ solo modelli additive nuovi `@Model`; no wipe data.

---

## Planning (CLAUDE) — sezione obbligatoria formato

### Obiettivo
Definire storage dedicato SwiftData per baseline lifecycle **`building→valid`** + fingerprint **post-save locale** + reader **latest valid** account/schema-scoped + integrazione conservativa preflight TASK-041/042, **senza** write remota (**TASK-044** separato).

### Analisi
TASK-042 costruisce una pseudo-baseline da stato locale vivo — insufficiente dopo pull parziali o login altro owner. TASK-039/040 gia' garantiscono apply solo snapshot sicuri quando i guard passano: TASK-043 **aggancia solo quei punti** con commit staged Run/Record e chiavi sintetiche.

### Approccio
1. Run + Record con **`recordKey`**, stato Run esplicito, commit **due fasi** (vedi Atomicità SwiftData).
2. Writer calcola fingerprint da **snapshot locale post-apply**.
3. Reader seleziona **solo** latest valid (**CA-27**); mai mix run (**CA-28**).
4. Versionamento `fingerprintSchemaVersion` + invalidazioni non distruttive catalog business.
5. Estendere enum/categorie preflight (**tombstone**, stale baseline, mismatch account).
6. UI DEBUG slice E summary-only (**CA-33**).

### File coinvolti
Vedi sopra "**File iOS**".

### Rischi
Privacy, dataset grande fingerprints, coherence SwiftData (save intermedio), ambiguita' tie temporali Run — mitigare con campo dominante (`appliedAt` vs `createdAt`) documentato in codice Reader.

### Criteri accettazione
CA-1..CA-34.

### Handoff post-planning
- **Prossima fase:** review utente pianificazione; solo dopo **override esplicito** → EXECUTION (**Cursor/Codex** slice A onward).
- **Prossimo agente ora:** Utente approvatore / Planner refinement secondari.
- **Prossima azione:** approvare decisioni CA-19..CA-34 (incluso lifecycle Run, chiavi sintetiche, confine TASK-044) prima di modificare `@Model`/app container.

---

## Execution (Cursor/Codex executor) — 2026-05-05

### Obiettivo compreso
Implementare TASK-043 come foundation locale iOS: baseline/fingerprint persistente SwiftData dall'ultimo full pull/apply locale completato con successo, usabile dal preflight/dry-run TASK-041/TASK-042 in modo conservativo. Perimetro rispettato: nessun push reale, nessuna scrittura remota Supabase, nessun upsert/delete/RPC `record_sync_event`, nessuna outbox.

### File controllati
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-043-supabase-baseline-fingerprint-persistence-ios.md`
- `docs/TASKS/TASK-040-supabase-full-pull-remote-identity-bridge-swiftdata-android-alignment.md`
- `docs/TASKS/TASK-041-supabase-manual-push-preflight-dry-run-tombstone-compliant-ios.md`
- `docs/TASKS/TASK-042-supabase-manual-push-preflight-ui-optionsview-dry-run-ios.md`
- `iOSMerchandiseControl/SupabasePullApplyService.swift`
- `iOSMerchandiseControl/SupabasePullPreviewModels.swift`
- `iOSMerchandiseControl/SupabasePullPreviewService.swift`
- `iOSMerchandiseControl/SupabaseInventoryService.swift`
- `iOSMerchandiseControl/SupabaseManualPushPreflightModels.swift`
- `iOSMerchandiseControl/SupabaseManualPushPreflightService.swift`
- `iOSMerchandiseControl/SupabasePushPreflightViewModel.swift`
- `iOSMerchandiseControl/SwiftDataInventorySnapshotService.swift`
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/Models.swift`
- test Supabase/preflight/apply/remote identity/TASK-039..TASK-042 in `iOSMerchandiseControlTests/`

### Piano minimo
1. Aggiungere normalizzazione fingerprint canonica pura e testabile.
2. Aggiungere Run/Record SwiftData dedicati e registrarli nel container.
3. Implementare writer staged `building` → record → save → verifica → `valid` → save.
4. Implementare reader latest-valid account/schema/source-scoped.
5. Collegare il preflight alla baseline persistente, rimuovendo il fallback da modelli vivi.
6. Agganciare il writer solo dopo apply completo e sicuro.
7. Aggiungere summary DEBUG read-only in `OptionsView` se piccolo e coerente.
8. Verificare build/test/anti-write/localizzazioni e aggiornare tracking a REVIEW.

### Modifiche fatte
- **Slice A**: aggiunto `SupabaseCatalogFingerprintNormalizer` con fingerprint canonico deterministico, normalizzazione stringhe/barcode coerente, numeri via `Decimal`/stringa stabile, Product basato su `supplierRemoteID`/`categoryRemoteID`, esclusi timestamp locali/UI/ProductPrice.
- **Slice B**: aggiunti modelli SwiftData `SupabaseCatalogBaselineRun` e `SupabaseCatalogBaselineRecord`, con `runKey`, `recordKey`, status/source/schema/account/count/tombstone e registrazione nel `ModelContainer`.
- **Slice C**: aggiunto `SupabaseCatalogBaselineWriter` con commit staged a due `save()`, dedup logico per `entityType|remoteID`, conteggi verificati, fallimenti marcati `partialRejected` senza promozione a `valid`.
- **Slice D**: aggiunto `SupabaseCatalogBaselineReader` che seleziona solo latest valid run per owner corrente, source `fullPullApply` e schema fingerprint corrente; integrato `SupabasePushPreflightViewModel` senza ricostruire baseline dai modelli vivi.
- **Slice E**: agganciato il writer dopo `SupabasePullApplyService.apply` riuscito e solo se la preview e' completa/sicura, senza cambiare l'apply locale in push remoto.
- **Slice F**: aggiunta card DEBUG read-only in `OptionsView` con stato baseline, ultimo pull, account abbreviato, conteggi Product/Supplier/Category, schema version, tombstone count e footer "push reale non ancora disponibile"; localizzazioni IT/EN/ES/ZH-Hans.
- **Test**: aggiunti test puri fingerprint, test SwiftData in-memory Run/Record, test writer/reader staged, test integrazione preflight baseline, regressioni localizzazioni e aggiornamenti ai test preflight/viewmodel esistenti.

### File modificati
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-043-supabase-baseline-fingerprint-persistence-ios.md`
- `iOSMerchandiseControl/iOSMerchandiseControlApp.swift`
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/SupabaseCatalogBaselineModels.swift`
- `iOSMerchandiseControl/SupabaseCatalogBaselineReader.swift`
- `iOSMerchandiseControl/SupabaseCatalogBaselineWriter.swift`
- `iOSMerchandiseControl/SupabaseCatalogFingerprintNormalizer.swift`
- `iOSMerchandiseControl/SupabaseManualPushPreflightModels.swift`
- `iOSMerchandiseControl/SupabaseManualPushPreflightService.swift`
- `iOSMerchandiseControl/SupabasePushPreflightViewModel.swift`
- `iOSMerchandiseControl/it.lproj/Localizable.strings`
- `iOSMerchandiseControl/en.lproj/Localizable.strings`
- `iOSMerchandiseControl/es.lproj/Localizable.strings`
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`
- `iOSMerchandiseControlTests/ManualPushFingerprintNormalizerTests.swift`
- `iOSMerchandiseControlTests/SupabaseCatalogBaselineSwiftDataTests.swift`
- `iOSMerchandiseControlTests/SupabaseCatalogBaselineWriterReaderTests.swift`
- `iOSMerchandiseControlTests/SupabaseCatalogBaselinePreflightIntegrationTests.swift`
- `iOSMerchandiseControlTests/SupabaseManualPushPreflightTests.swift`
- `iOSMerchandiseControlTests/SupabasePushPreflightViewModelTests.swift`
- `iOSMerchandiseControlTests/LocalizationCoverageTests.swift`

### Decisioni tecniche prese
- Il reader non ha fallback da catalogo live: baseline assente/stale/incompleta blocca in modo conservativo.
- `recordKey` include `baselineRunID`, `entityType`, `remoteID`; il writer rileva duplicati logici prima del commit.
- Il fingerprint salvato dal writer viene calcolato dallo stato SwiftData locale post-apply/save, non da DTO raw.
- SwiftData non viene trattato come transazione SQL manuale: la coerenza e' garantita da stato staged e reader che usa solo `valid`.
- La UI DEBUG resta solo summary e non espone purge/reset/delete.

### Check eseguiti
- ✅ ESEGUITO — Build Debug Simulator: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'id=4CE85775-BEF1-44D5-9BBF-B180EDF09D0B' CODE_SIGNING_ALLOWED=NO build` → **BUILD SUCCEEDED**.
- ✅ ESEGUITO — Build Release Simulator: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Release -destination 'id=4CE85775-BEF1-44D5-9BBF-B180EDF09D0B' CODE_SIGNING_ALLOWED=NO build` → **BUILD SUCCEEDED**. Nota: Xcode ha emesso il warning toolchain "Metadata extraction skipped. No AppIntents.framework dependency found", non collegato a TASK-043.
- ✅ ESEGUITO — XCTest mirati TASK-043 + regressione preflight TASK-041/TASK-042: suite `ManualPushFingerprintNormalizerTests`, `SupabaseCatalogBaselineSwiftDataTests`, `SupabaseCatalogBaselineWriterReaderTests`, `SupabaseCatalogBaselinePreflightIntegrationTests`, `SupabaseManualPushPreflightTests`, `SupabasePushPreflightViewModelTests` → **TEST SUCCEEDED**.
- ✅ ESEGUITO — XCTest completo: `xcodebuild test -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'id=4CE85775-BEF1-44D5-9BBF-B180EDF09D0B' CODE_SIGNING_ALLOWED=NO` → **TEST SUCCEEDED**.
- ✅ ESEGUITO — Regressione TASK-039/TASK-040/TASK-041/TASK-042: inclusa in XCTest completo; passate suite apply/pull preview/remote identity/manual push/viewmodel.
- ✅ ESEGUITO — `git diff --check` → nessun errore.
- ✅ ESEGUITO — Localizzazioni: `plutil -lint` su IT/EN/ES/ZH-Hans → OK; test `LocalizationCoverageTests.testTask043BaselineLocalizationKeysExistInSupportedLanguages` → PASS.
- ✅ ESEGUITO — Controllo anti-write Supabase: grep su `record_sync_event`, `sync_events`, `outbox`, `.rpc`, `.upsert`, `.update`, `.delete` nei file Supabase/Options → nessun percorso write remoto introdotto; gli unici `context.insert` nuovi sono SwiftData locali per Run/Record baseline.
- ✅ ESEGUITO — Controllo SQL/migrations/dipendenze: nessun file SQL/migration/Package modificato.
- ✅ ESEGUITO — Controllo segreti/config reale: nessuna modifica a `SupabaseConfig.plist`, `SupabaseConfig.example.plist`, `Info.plist`.
- ✅ ESEGUITO — Criteri di accettazione verificati contro CA-19..CA-34: storage dedicato, no baseline parziale valid, Decimal/fingerprint remoteID, latest valid reader, tombstone blocker, UI read-only, no TASK-044/push/outbox.

### Rischi rimasti
- UI DEBUG verificata via build/test/static analysis, non con sessione Simulator manuale: rischio basso ma visual QA live resta utile in review.
- La policy retention/pruning dei run storici resta intenzionalmente fuori scope: follow-up candidate per TASK futuro se serve pulizia non distruttiva.
- SwiftData unique composito non e' usato come garanzia primaria: il writer fa dedup logico esplicito; eventuale hardening DB-level futuro resta follow-up.
- Push reale, collision check remoto outbound e ProductPrice push restano fuori TASK-043 e richiedono task successivo separato.

### Aggiornamenti file di tracking
- TASK-043 aggiornato da EXECUTION a **REVIEW** con handoff post-execution.
- MASTER-PLAN aggiornato a TASK-043 **ACTIVE / REVIEW** con responsabile **Claude / Reviewer**.
- Nessun task DONE riaperto; TASK-042/TASK-041/TASK-040/TASK-039 restano DONE; TASK-032/TASK-028 restano BLOCKED.

## Handoff post-execution
- **Esito execution:** completata; pronta per review.
- **Prossima fase:** REVIEW.
- **Prossimo agente ora:** Claude / Reviewer.
- **Conferma scope:** TASK-043 resta **ACTIVE / REVIEW**, non DONE.
- **Conferma sicurezza:** nessun push reale Supabase, nessuna scrittura remota, nessun upsert/delete/RPC `record_sync_event`, nessuna outbox, nessuna modifica SQL/migration/RLS/RPC, nessun cleanup distruttivo.
- **Suggerimento review:** verificare soprattutto mapping reader/preflight su account/stale/incomplete e UX DEBUG `OptionsView` in una sessione app reale, se il reviewer vuole coprire anche il rendering.

## Review (Claude / Reviewer+Fixer) — 2026-05-05

### Verdetto
**APPROVED_FIXED_DIRECTLY / DONE**

Review tecnica completa eseguita su tracking, diff, codice Swift/SwiftUI/SwiftData, test e grep anti-scope. TASK-043 e' coerente con TASK-039/TASK-040/TASK-041/TASK-042: baseline locale dedicata SwiftData, writer staged, reader latest-valid account/schema/source-scoped, preflight conservativo e UI DEBUG read-only. Nessun push reale e nessuna scrittura remota Supabase introdotti.

### Problemi trovati
- Il preflight UI era ancora vincolato a `supabaseLastLinkedUserID`; una baseline persistente valida poteva non essere usata se quel valore volatile mancava. Fix diretto: il run del preflight ora richiede solo sessione valida/current user, poi lascia decidere al reader baseline persistente; il vecchio `lastLinkedUserID` resta solo fallback/mismatch quando presente.
- Il writer baseline non bloccava difensivamente preview con `priceHistoryIncomplete` se chiamato direttamente. Fix diretto: `commitAfterSuccessfulFullPullApply` ora rifiuta anche quel caso, allineandosi ai guard dell'apply TASK-039/TASK-040.
- Il reader ignorava lo status esplicito `.stale` come segnale di baseline stale. Fix diretto: un run marcato `stale` ora produce blocco stale schema e resta non selezionabile come latest valid.

### Fix applicati direttamente
- `OptionsView.swift`: preflight DEBUG abilitato con sessione valida/current user anche se `supabaseLastLinkedUserID` e' assente, cosi' la baseline persistente e' la fonte di verita' primaria.
- `SupabasePushPreflightViewModel.swift`: rimosso il guard obbligatorio su `lastLinkedUserID`; fallback account coerente quando manca il valore volatile; baseline reader resta responsabile di account/schema/source.
- `SupabaseCatalogBaselineWriter.swift`: aggiunto errore `priceHistoryIncomplete` e blocco difensivo su preview non global-safe.
- `SupabaseCatalogBaselineReader.swift`: stato `.stale` trattato come baseline stale/inutilizzabile.
- Test aggiunti/rafforzati per baseline persistente senza `lastLinkedUserID`, preview unsafe con price history incompleta e run `stale`.

### Note su `project.pbxproj`
- `iOSMerchandiseControl.xcodeproj/project.pbxproj` **non ha diff**.
- La modifica non e' necessaria per i nuovi file perche' il progetto usa `PBXFileSystemSynchronizedRootGroup` per `iOSMerchandiseControl` e `iOSMerchandiseControlTests`; i nuovi Swift/test sono inclusi dai gruppi filesystem-synchronized.
- Non sono stati alterati scheme, build setting o membership non collegati.

### Check eseguiti
- ✅ ESEGUITO — Build Debug Simulator: `xcodebuild -quiet -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'id=4CE85775-BEF1-44D5-9BBF-B180EDF09D0B' -derivedDataPath /tmp/iOSMerchandiseControlDerivedData-task043-review-debug CODE_SIGNING_ALLOWED=NO build` → PASS.
- ✅ ESEGUITO — Build Release Simulator: `xcodebuild -quiet -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Release -destination 'id=4CE85775-BEF1-44D5-9BBF-B180EDF09D0B' -derivedDataPath /tmp/iOSMerchandiseControlDerivedData-task043-review-release CODE_SIGNING_ALLOWED=NO build` → PASS.
- ✅ ESEGUITO — XCTest mirati TASK-043: `ManualPushFingerprintNormalizerTests`, `SupabaseCatalogBaselineSwiftDataTests`, `SupabaseCatalogBaselineWriterReaderTests`, `SupabaseCatalogBaselinePreflightIntegrationTests`, `SupabaseManualPushPreflightTests`, `SupabasePushPreflightViewModelTests` → PASS.
- ✅ ESEGUITO — XCTest completo: `xcodebuild -quiet -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'id=4CE85775-BEF1-44D5-9BBF-B180EDF09D0B' -derivedDataPath /tmp/iOSMerchandiseControlDerivedData-task043-review-full CODE_SIGNING_ALLOWED=NO test` → PASS.
- ✅ ESEGUITO — Regressione TASK-039/TASK-040/TASK-041/TASK-042 inclusa in XCTest completo: `SupabasePullApplyServiceTests`, `SupabasePullPreviewPaginationTests`, `SupabasePullPreviewDiffEngineTests`, `RemoteIdentityMetadataSwiftDataTests`, `SupabaseManualPushPreflightTests`, `SupabasePushPreflightViewModelTests`, `LocalizationCoverageTests` → PASS.
- ✅ ESEGUITO — `git diff --check` → PASS.
- ✅ ESEGUITO — `git diff --check --no-index /dev/null ...` sui nuovi file non tracciati TASK-043 → PASS.
- ✅ ESEGUITO — `plutil -lint` su `Localizable.strings` IT/EN/ES/ZH-Hans → PASS.
- ✅ ESEGUITO — Grep anti-write Supabase: nessun `.upsert`, `.insert`, `.update`, `.delete`, `.rpc`, `record_sync_event`, outbox, retry/backoff o sync background/realtime introdotto verso Supabase; gli unici `context.insert` nuovi sono SwiftData locali Run/Record baseline e test.
- ✅ ESEGUITO — Controllo segreti/config: nessuna modifica a `SupabaseConfig.plist` reale, `SupabaseConfig.example.plist`, `Info.plist`, `Package.resolved`, SQL/migration/RLS/RPC o dipendenze.
- ✅ ESEGUITO — Criteri CA-19..CA-34 verificati: storage SwiftData dedicato, no UserDefaults catalog baseline, no baseline parziale valid, Decimal/fingerprint remoteID, latest valid reader, tombstone blocker, UI summary-only read-only, no TASK-044/push/outbox.

### Rischi residui / follow-up candidate
- Visual QA manuale della card DEBUG baseline in Simulator non eseguita; copertura attuale tramite build/test/static review.
- Pruning/retention dei run storici resta follow-up futuro non distruttivo.
- Push reale Supabase manuale resta **TASK-044 separato**, non attivato in TASK-043.
- ProductPrice push resta fuori scope.

### Chiusura
- TASK-043 chiuso **DONE / Chiusura** con esito **APPROVED_FIXED_DIRECTLY**.
- Conferma sicurezza: **no push reale**, **no write remota Supabase**, **no outbox**, **no `record_sync_event`**, **no SQL/migration/RLS/RPC**, **no cleanup distruttivo**.
