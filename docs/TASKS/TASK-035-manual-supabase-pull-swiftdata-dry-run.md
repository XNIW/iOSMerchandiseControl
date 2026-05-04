# TASK-035: Manual Supabase pull to SwiftData dry-run

## Informazioni generali
- **Task ID**: TASK-035
- **Titolo**: Manual Supabase pull to SwiftData dry-run
- **File task**: `docs/TASKS/TASK-035-manual-supabase-pull-swiftdata-dry-run.md`
- **Stato**: DONE
- **Fase attuale**: DONE
- **Responsabile attuale**: Claude / Review — completed
- **Data creazione**: 2026-04-26
- **Ultimo aggiornamento**: 2026-05-04
- **Ultimo agente che ha operato**: Claude / Review TASK-035

## Dipendenze
- **Dipende da**: TASK-034
- **Sblocca**: task futuri di sync applicata con conferma

## Scopo
Prima sync reale sicura: pull manuale remoto → confronto con SwiftData, senza applicare automaticamente.

## Contesto
Il task segue la foundation readonly di TASK-034 e prepara una preview del sync prima di qualsiasi scrittura automatica.

## Non incluso
- Scrittura automatica su SwiftData
- Push verso Supabase
- Risoluzione automatica conflitti
- UI estesa non necessaria al dry-run

## Scope
- Leggere dati da Supabase
- Confrontare con SwiftData locale
- Produrre diff new/update/conflict
- Nessuna scrittura automatica salvo conferma in task futuro

## Output richiesto
- SyncPreview
- Lista conflitti
- Metriche
- UI minima o debug view se necessario

## Criteri di accettazione
- [ ] Il pull remoto produce una preview senza applicare scritture automatiche
- [ ] Diff new/update/conflict e metriche sono disponibili
- [ ] I conflitti sono visibili e non risolti automaticamente
- [ ] Ogni applicazione dati resta fuori scope salvo task futuro confermato

**Nota sui criteri (priorità per Execution/Review)**

- I checkbox sopra sono un **riepilogo sintetico** (visione d’insieme).
- Il **contratto operativo** per implementazione e review sono **§L** (criteri raffinati) e **§L-bis** (guardrails anti-scrittura).
- In caso di **ambiguità o conflitto di interpretazione** tra checklist breve e Planning dettagliato → prevalgono **§L** e **§L-bis**.

## Planning (Claude) ← solo Claude aggiorna questa sezione

*Rifinitura planning-only (2026-05-04, iterazione 3: ordine fetch/parallelo, scope storico prezzi, test consigliati, DEBUG vs Release, logging). Nessuna Execution; nessuna modifica codice/SPM/progetto; nessun file app aggiunto o implementato.*

### Verifica prerequisiti

- **TASK-034** (foundation Supabase iOS) è **DONE**: `SupabaseConfig`, DTO `RemoteInventory*Row`, `SupabaseInventoryService` read-only, diagnostica **DEBUG** in `OptionsView`, errori tipizzati (`configMissing`, `invalidConfig`, `permissionDeniedOrRLS`, `decodingError`, `schemaDrift`, ecc.).
- **TASK-033** (`docs/SUPABASE/TASK-033-schema-audit.md`) resta fonte schema: tabelle `inventory_*`, RLS owner-scoped, `deleted_at` su catalogo, `inventory_product_prices` con `type` PURCHASE/RETAIL e timestamp **text**.
- **Vincoli globali TASK-035**: nessun nuovo package; nessuna modifica schema SwiftData in questo task; nessun push/upsert/delete verso Supabase; nessun `context.insert` / **`delete`** / `save` durante preview; nessuna auth/login/multiutente; nessun `service_role` o segreti nel client; **non** riusare `InventorySyncService` per il dry-run (vedi §A).

---

### A. Stato attuale iOS (linea di base post-TASK-034)

- **Foundation già presente**: `SupabaseConfig.swift` (load plist, `makeClient()`), `SupabaseInventoryDTOs.swift`, `SupabaseInventoryService` (`fetchProducts` / `fetchSuppliers` / `fetchCategories` / `fetchProductPrices`, `limit` clamp 1…1000, **nessun** SwiftData), sezione DEBUG Supabase in `OptionsView` (`testConnection` / catalog probe).
- **Modelli SwiftData** (`Models.swift`): `Supplier`, `ProductCategory`, `Product`, `ProductPrice`. Nessun `remoteId`, `ownerUserId`, `updatedAt` locale dedicato al sync, `deletedAt` locale per catalog mirror.
- **Chiavi locali**: `Product.barcode` unico globale sul device; `Supplier` / `ProductCategory` con `name` `@Attribute(.unique)`; `ProductPrice` usa `PriceType` **lowercase** (`.purchase` / `.retail`) e `Date` per `effectiveAt` / `createdAt`.
- **Divergenze semantiche rispetto al remoto**: Supabase espone `owner_user_id`, UUID PK, `type` storico **PURCHASE/RETAIL** e `effective_at` / `created_at` come **String** nel DTO; catalogo ha `updated_at` / `deleted_at` (tombstone) dove previsto dallo schema.
- **`InventorySyncService`**: `@MainActor`, legge `HistoryEntry`, **scrive** `Product`, `ProductPrice`, griglia `SyncError` — è “inventario locale → SwiftData”. **Non** va invocato né esteso per il pull preview Supabase: il dry-run deve essere un percorso separato in memoria (`SyncPreview`), senza condividere logica di apply locale.

---

### B. Obiettivo preciso TASK-035

Implementare (in **Execution futura**, non ora) un **pull manuale read-only** da Supabase che produce **soltanto** un oggetto di preview / diff contro lo stato SwiftData locale:

| Consentito | Escluso |
|------------|---------|
| Lettura remota (SELECT via client già esistente) | Scrittura locale (insert/update/delete/save) |
| Confronto in memoria, classificazione | Scrittura remota (insert/update/upsert/delete/RPC mutanti) |
| UI “dry-run” / “nessuna modifica applicata” | Merge automatico, risoluzione conflitti, sync periodico |
| Messaggi errore classificati (RLS, rete, decode) | Auth, JWT manuale, `service_role` |
| | Pulsanti o copy che implichino “applicato” / “sincronizzato” |

---

### C. Modello logico `SyncPreview` (da implementare in Execution)

Tipi **logici** (nomi indicativi; file dedicati in §K). Obiettivo: strutturare il report senza legarlo a SwiftData nei layer puri di diff.

**`SyncPreview`**

- `generatedAt` — `Date` (momento generazione report)
- `remoteCounts` — conteggi righe utili per tabella/dominio dopo fetch (es. prodotti attivi vs tombstone, fornitori, …)
- `localCounts` — conteggi dallo snapshot locale
- `newProducts` — novità remote (barcode non presente localmente, vedi §E)
- `updateCandidates` — prodotto locale trovato + uno o più campi divergenti dopo normalizzazione (§G); **mai** chiamarli “update sicuri” senza `updatedAt` locale — etichettare come *candidate* / *requires review*
- `conflicts` — ambiguità o impossibilità di classificare senza decisione umana (duplicati, collisioni nomi, FK mancanti, ecc.)
- `unchangedProducts` — chiavi/principali campi equivalenti post-normalizzazione
- `remoteTombstones` — righe catalogo remote con `deleted_at != nil`; **solo segnalazione** — nessun delete locale in TASK-035
- `supplierDiffs` — delta nominali fornitore (preview), inclusi mismatch nome normalizzato vs lookup `supplier_id`
- `categoryDiffs` — analogo per categorie
- `priceHistoryDiffs` — **solo preview** per `inventory_product_prices`: confronto contro storico locale oppure rilevazione drift senza creare righe `ProductPrice` locali (TASK-035 non popola storico)
- `warnings` — dati incompleti, casing ambiguo, prezzi non parseabili, FK remote assenti
- `metrics` — riepilogo numerico (conteggi per categoria, tempi approssimativi se raccolti, righe processate)
- `sourceErrors` — errori di fetch parziale / pagina fallita / classificazione errore primario se il preview è incompleto

**Tipi di supporto (logici)**

- `SyncPreviewMetric` — es. `{ label, value }` o metriche strutturate per UI
- `SyncPreviewConflict` — `{ kind, barcodeOrKey?, detail, relatedRemoteIds?, hint }`
- `SyncPreviewFieldChange` — `{ fieldKey, remoteDisplay, localDisplay, normalizedEqual? }`
- `SyncPreviewWarning` — `{ code, messageKey?, detail }` (testi UI via `L(...)` in Execution)

---

### Snapshot model (Execution futura — struct pure `Sendable`)

Il **diff engine** deve operare **solo** su snapshot immutabili, **mai** su istanze SwiftData `@Model` o sul client Supabase “vivo” riga per riga durante il confronto. I DTO remoti (`RemoteInventory*Row`) entrano nello snapshot remoto; dal `ModelContext` si estrae una sola passata verso struct locali.

**`RemoteInventorySnapshot`**

| Campo | Contenuto previsto |
|--------|---------------------|
| `products` | `[RemoteInventoryProductRow]` — corpus letto (o sottoinsieme se budget DEBUG) |
| `suppliersByID` | dizionario `UUID → RemoteInventorySupplierRow` (o equivalente lookup per `supplier_id`) |
| `categoriesByID` | dizionario `UUID → RemoteInventoryCategoryRow` |
| `productPrices` | `[RemoteInventoryProductPriceRow]` |
| `activeProducts` | sottoinsieme / vista derivata: prodotti con `deleted_at == nil` (per dedupe/classificazione) |
| `tombstonedProducts` | righe con `deleted_at != nil` (per sezione tombstone **informativa**) |
| `duplicateBarcodeGroups` | gruppi barcode duplicati tra righe **attive** remoto (chiave → più UUID/metadati per `conflict`) |
| `sourceErrors` | errori accumulati da pagine fallite o fetch secondari incompleto (vedi §I-bis) |

**`LocalInventorySnapshot`**

| Campo | Contenuto previsto |
|--------|---------------------|
| `productsByBarcode` | `String` (barcode normalizzato) → `LocalProductSnapshot` |
| `suppliersByNormalizedName` | lookup opzionale per diagnostiche su naming |
| `categoriesByNormalizedName` | idem |
| `priceHistoryByLogicalKey` | chiave logica stabile (es. barcode + tipo normalizzato + effectiveAt string/Comparable) → rappresentazione minima dello storico locale per confronto **preview** |
| `counts` | conteggi locali (prodotti, fornitori, categorie, righe storico campionate, …) |

**`LocalProductSnapshot`**

- `barcode`, `itemNumber`, `productName`, `secondProductName`
- `purchasePrice`, `retailPrice`, `stockQuantity`
- `supplierName`, `categoryName` (stringhe “display” già risolte dalle relazioni locali allo snapshot)

**Regole**: costruzione snapshot su **MainActor** se serve lettura `ModelContext`, poi passaggio a struct **Sendable** al motore di diff; **vietato** tenere riferimenti a `@Model` dentro le struct di diff.

---

### D. Regole di matching remoto ↔ locale (senza `remoteId`)

- **Product**: match **primario** su `barcode` dopo **trim**. Barcode vuoto lato remoto dopo trim → **non** classificare come `newProduct`: → **conflict** o **warning** (mai “nuovo” anonimo).
- **Supplier**: match su **name** dopo trim + **lowercase** (allineato a intento DDL `lower(name)` per unicità per owner remoto). Collisioni post-normalizzazione (più righe remote attive stesso nome) → **conflict** / **warning**.
- **Category**: stesso schema del supplier (trim + lowercase).
- **Risoluzione nomi da FK**: costruire mappe `remoteSupplierByID`, `remoteCategoryByID` dai fetch; confrontare i **nomi risolti** con i nomi locali normalizzati per i campi prodotto in §F.
- **ProductPrice (TASK-035)**: **solo preview** — join logico `product_id` remoto → prodotto remoto → **barcode**; poi tripla chiave logica `(barcode normalizzato, type normalizzato PURCHASE/RETAIL ↔ purchase/retail, effectiveAt)` confrontando con snapshot locale oppure segnalando assenza/parsing. **Non** creare o aggiornare `ProductPrice` in SwiftData.
- **Duplicati barcode remoto attivi** (più righe con stesso barcode, `deleted_at` null): **conflict**.
- **Duplicati locali**: non attesi per vincolo `unique`, ma se anomalie di fetch/snapshot: **conflict**.
- **`ownerUserId`**: non è chiave utente in UI; eventualmente solo diagnostica interna / metrica, mai come campo “da allineare” in copy verso l’utente finale per TASK-035.

---

### E. Classificazione del diff (conservativa)

| Etichetta | Significato |
|-----------|-------------|
| `newProduct` | Prodotto remoto **attivo** (`deleted_at` null) il cui barcode non esiste in locale |
| `updateCandidate` | Prodotto locale esiste; dopo normalizzazione almeno un campo confrontato in §F diverge |
| `conflict` | Situazione non applicabile automaticamente o ambigua (duplicati, FK mancanti, più match possibili) |
| `unchanged` | Campi principali equivalenti dopo normalizzazione §G |
| `remoteTombstone` | `deleted_at` remoto valorizzato su catalogo — **solo avviso**; vietato cancellare o modificare SwiftData in risposta |
| `warning` | Dati incompleti, parse falliti, naming ambiguo, prezzi non confrontabili |

**Terminologia**: evitare “update sicuro” / “sync completata”; usare **candidate**, **requires review**, **dry-run**, **nessuna modifica applicata**.

---

### F. Campi prodotto da confrontare (minimo)

Per ogni coppia matched per barcode, confrontare almeno:

- `barcode` (già chiave match; ri-verifica uguaglianza normalizzata)
- `item_number` ↔ `itemNumber`
- `product_name` ↔ `productName`
- `second_product_name` ↔ `secondProductName`
- `purchase_price` ↔ `purchasePrice`
- `retail_price` ↔ `retailPrice`
- `stock_quantity` ↔ `stockQuantity`
- **Nome fornitore** risolto da `supplier_id` remoto vs `Product.supplier?.name`
- **Nome categoria** risolto da `category_id` remoto vs `Product.category?.name`

Opzionale in preview successiva: `updated_at` remoto informativo (non confronto “vince chi più recente” senza campo locale equivalente).

---

### G. Normalizzazione (helper puri, senza SwiftData)

Pianificare **funzioni pure** (stesso file servizio preview o modulo dedicato) che:

- **Stringhe**: trim; stringa vuota trattata come **nil** per uguaglianza semantic
- **Supplier / category names**: lowercase per confronto (coerente con §D)
- **Double / prezzi**: uguaglianza con **tolleranza** assoluta piccola (es. **0.001**) per float
- **Tipo prezzo remoto**: `PURCHASE` / `RETAIL` ↔ `purchase` / `retail` **solo** nel layer di preview
- **Date**: parsing `Date` da stringhe remote **solo se necessario**; per TASK-035 è accettabile mantenere `effective_at` / `created_at` come **String** nel diff se sufficiente a mostrare drift o warning, per ridurre ambiguità timezone

---

### H. Performance, paginazione e concorrenza

**Ordine fetch e parallelismo (Execution)**

- **`inventory_products` per primo** — è il **dataset master** del catalogo; tutto il diff prodotti dipende da questo fetch paginato.
- Se il fetch **`inventory_products`** fallisce in modo **fatale** (nessuna pagina utilizzabile) → **nessuna** preview “finta”: stato **`failed`** (vedi §I-bis); non costruire `SyncPreview` vuoto/passaggio come successo.
- Se **`inventory_products`** è stato caricato con successo (almeno una pagina coerente), proseguire con **`inventory_suppliers`**, **`inventory_categories`** e, **se abilitato nel flusso**, **`inventory_product_prices`** in **parallelo logico** (in Execution: `async let` / `TaskGroup` / equivalente) per ridurre latenza — **senza** bloccare indefinitamente la UI.
- **`suppliers`** / **`categories`**: se uno o entrambi falliscono → ammissibile **`partialPreview`** catalogo (prodotti confrontabili) con FK/resolve nomi **non verificabili** + `warnings` / `sourceErrors` (coerente §I-bis).
- **`inventory_product_prices`**: **non** deve bloccare il completamento della **preview catalogo**; se il fetch fallisce, va in **timeout** o supera **budget dedicato** (vedi §H-ter) → **`warnings`** + `sourceErrors`, sezione storico **marcata incompleta**, ma il risultato resta **success** o **partial** sui prodotti (mai mascherare un fallimento **prodotti** come successo).

**Paginazione fetch (concreta, Execution)**

- **`pageSize`**: fisso in codice o costante di servizio, es. **500** o **1000** (≤ limite Supabase/service già usato, es. clamp 1…1000 in TASK-034). Stessa `pageSize` di base per tutte le tabelle; per **`inventory_product_prices`** la `pageSize` effettiva o il **cap totale righe** può essere **più bassa** (§H-ter).
- **Meccanica**: usare API Supabase Swift **range** (`range(from:to:)` / offset-limit equivalente PostgREST) per ogni pagina: `offset = pageIndex * pageSize`, `limit = pageSize`.
- **Terminazione loop**: continuare finché la risposta ha **`count == pageSize`**; se **`count < pageSize`** → ultima pagina, stop.
- **Budget DEBUG (opzionale)**: limite massimo righe totali caricabili per sessione preview (es. cap assoluto 10_000 o configurabile solo `#if DEBUG`) per evitare freeze su cataloghi enormi; se il cap scatta → `warnings` + eventuale `partialPreview` (vedi §I-bis).
- **Pagina fallita**: non silenziare — append a `RemoteInventorySnapshot.sourceErrors` (o errore fatale se tabella “master” prodotti illeggibile, vedi §I-bis).
- **Vietato**: un solo fetch “leggi tutto” senza bound né loop controllato.

**Altri vincoli**

- **Snapshot locale**: una passata che legge `Product`, `Supplier`, `ProductCategory`, `ProductPrice` e produce **`LocalInventorySnapshot`** / `LocalProductSnapshot` **Sendable** (§ Snapshot model).
- **Indici in memoria** prima del diff: allineati a snapshot — `productsByBarcode`, mappe ID remote, join prezzi, ecc.; **vietato** query SwiftData nel loop per ogni riga dopo lo snapshot.
- **Actor / isolation**: rete + assemblaggio snapshot remoto + diff su executor non-UI; **MainActor** solo per costruzione snapshot da `ModelContext` e per **`SupabasePullPreviewViewState`** (§J-bis).

---

### H-ter. Decisione: scope `inventory_product_prices` (storico — **secondario**)

- **Priorità TASK-035**: il **catalogo prodotti** (`inventory_products` + confronto campi §F); lo storico remoto è **preview opzionale / secondaria**.
- La tabella **`inventory_product_prices`** può essere **molto grande** → **vietato** fetch illimitato o caricamento completo obbligatorio per considerare la preview “valida”.
- Prevedere un **cap/budget dedicato** (righe totali, byte stimato o timeout) **solo** per lo storico; al superamento: **`warning`** localizzato (es. *“Storico prezzi non completamente verificato”*) + dettaglio in `warnings` / `metrics`, **mai** fallback che simuli storico completo.
- **Non** creare, **non** aggiornare, **non** backfillare mai righe **`ProductPrice`** SwiftData in TASK-035; il task **non** diventa un task di **backfill storico** — eventuale allineamento storico = **follow-up** dedicato.
- Il diff storico in preview resta **best-effort** entro budget; campi prodotto snapshot (§F) restano la fonte principale di `updateCandidate`.

---

### I. Errori, RLS e classificazione

Allinearsi alla tassonomia esistente `SupabaseInventoryServiceError` dove possibile.

- **401/403 / RLS / permission denied**: **non** considerare fallimento di prodotto — mostrare preview **non disponibile** con messaggio localizzato, errore classificato (es. `permissionDeniedOrRLS`), zero crash.
- **Rete / timeout / decode / schema drift**: distinti in UI e in `sourceErrors` / stato preview.
- **Nessun workaround** con JWT incollato, chiavi server, o ruoli non pubblici.

---

### I-bis. Preview parziale vs fallimento (decisione)

| Scenario | Comportamento |
|----------|----------------|
| **`inventory_products` non leggibile** (errore fatale su fetch principale del catalogo) | **Nessuna** preview catalogo significativa — UI in stato **failed** con errore **classificato** (`SupabaseInventoryServiceError` mappato). Nessun tentativo di “diff” su liste vuote mascherate come successo. |
| **`inventory_products` OK** ma falliscono **solo** **`suppliers`** e/o **`categories`** | **`partialPreview`**: diff **prodotti** dove possibile; campi dipendenti da **FK** (nomi fornitore/categoria) marcati **non verificabili**; `warnings` / `sourceErrors`. |
| **`inventory_products` OK** ma fallisce o supera budget **`inventory_product_prices`** | **Non** degradare l’intera preview a `failed` solo per lo storico: mantenere esito **success** o **partial** sul catalogo; **`warnings`** + `sourceErrors`; messaggio esplicito storico incompleto (allineato §H-ter). |
| **Errori sempre distinguibili** | **RLS** vs **auth/config** vs **rete** vs **decode** vs **schema drift** — messaggi e/o badge coerenti con enum esistente + dettaglio sanitizzato già in servizio. |

---

### J. UI/UX minima (DEBUG, scalabile) e **Release safety**

**Visibilità Release vs DEBUG (decisione)**

- L’entry point e la sheet di preview devono restare sotto **`#if DEBUG`** **oppure** dietro flag **dev-only** inequivocabile — **non** presentare la preview come **funzione finale** di sync per l’utente negozio.
- In **Release**, se nessun **task futuro** abilita esplicitamente la feature a utenti finali, la **UI di preview non deve essere visibile** (nessun pulsante/sezione in Opzioni visibile in produzione).
- **Vietati** badge, titoli o copy che suggeriscano **sync completata**, **allineato al cloud**, **merge eseguito**, ecc.

**Contenitore (decisione UX)**

- Entry point: pulsante nella sezione **DEBUG Supabase** in `OptionsView` (stesso pattern della diagnostica TASK-034).
- **Sheet** a tutto schermo o large detachment con **`NavigationStack`** **interno**: titolo tipo “Preview” / “Dry-run”, toolbar solo chiusura/indietro; il `Form` delle Opzioni resta leggero.

**Layout**

- **Summary in alto**: “cards” o **sezioni compatte** (`Section` + metriche chiave: conteggi, eventuale flag **Partial preview**, messaggio **Nessuna modifica applicata**).
- **Ordine gruppi** (verticale fisso): **1 Conflicts** → **2 Update candidates** → **3 New** → **4 Tombstones** → **5 Warnings** → **6 Unchanged** (ordine scelto per dare priorità a ciò che richiede attenzione prima del “rumore” unchanged).
- **Ordinamento stabile** dentro ogni gruppo: per **barcode** alfanumerico, oppure **nome prodotto** normalizzato se barcode assente in una riga di warning (definire una chiave display stabile in Execution).
- **Liste lunghe**: mostrare inizialmente al massimo **~100** righe per gruppo; sotto, testo localizzato tipo **“Altri N non mostrati”** oppure `DisclosureGroup` “Mostra tutto” solo se la performance resta accettabile — obiettivo evitare scroll di migliaia di righe in DEBUG.

**Copy e vincoli**

- Solo termini **Preview**, **Dry-run**, **Nessuna modifica applicata**; **mai** “sincronizzato”, “allineato”, “completato”.
- **Nessun** pulsante **Apply** / **Merge** / **Sync** / azioni che suggeriscano mutazione dati.
- **Localizzazione**: tutte le stringhe tramite **`L(...)`** e `*.lproj` esistenti.

**Componenti**: `Form`, `Section`, `SectionHeader`, `Label`, `ProgressView`, `List`, `DisclosureGroup` per dettaglio campo-per-campo dove serve.

---

### J-bis. Stato UI dedicato (modello logico, no implementazione ora)

Per evitare molteplici `@State` sparsi in `OptionsView`, centralizzare in un unico tipo somma (nome indicativo):

**`SupabasePullPreviewViewState`**

- `idle`
- `loading(progressMessage: String?)` — messaggio opzionale per sottofase (“Scarico prodotti…”, “Pagina k…”) via chiavi `L(...)`
- `success(SyncPreview)`
- `partial(SyncPreview, warnings/sourceErrors)` — equivalente UI a **partialPreview** §I-bis
- `failed(SupabaseInventoryServiceError)` **oppure** `PreviewError` dedicato future-sealed (solo se serve distinguere errori di **solo-diff** da errori di rete — definizione in Execution)

La view entry-level imposta questo stato sul **MainActor** al completamento dell’async; il **sheet** interno legge lo stesso stato o una copia immutabile passata alla sheet.

---

### J-ter. Logging e privacy (guardrail Execution/Review)

- **Non** loggare: chiavi Supabase, header **`Authorization`**, JWT, **`apikey`** completa, URL con query segrete.
- **Non** loggare dump integrali di risposte JSON (catalogo / prodotti / prezzi); se serve diagnostica, limitarsi a **conteggi**, **HTTP status**, codici errore **sanitizzati** (coerente `safeDiagnosticDetail` in TASK-034), eventuali **barcode/nomi** solo in build DEBUG e solo se necessario al debug locale.
- I **`sourceErrors` / messaggi mostrati in UI** devono restare **privi di segreti** e **privi di payload sensibili** massicci; nessuna esposizione di dati che replichino l’intero dataset.

---

### K. File iOS probabilmente toccati in Execution futura *(elenco; nessuna modifica in questo planning-only)*

**Nomi type/servizi (anti-ambiguità)**

- Orchestrazione fetch + diff in memoria: preferire **`SupabasePullPreviewService`** **oppure** **`SupabaseDryRunPreviewService`** (stesso ruolo, un solo tipo in Execution).
- **Evitare** nomi che suggeriscono merge/sync applicata: niente `SyncService`, `ApplyService`, `MergeService`, `CloudSyncService` generico, ecc.
- **`InventorySyncService`**: resta **esclusivo** del flusso “griglia inventario locale → `Product` / `ProductPrice`”; **non** va modificato né usato per la preview Supabase.
- Modelli snapshot/report: restano `SyncPreview`, `RemoteInventorySnapshot`, `LocalInventorySnapshot`, `SupabasePullPreviewViewState` come da §C / § Snapshot model / §J-bis.

| File | Ruolo |
|------|--------|
| `SupabaseInventoryService.swift` | Paginazione / fetch “full catalog” controllato; nessuna API con nome che implichi scrittura |
| `SupabaseInventoryDTOs.swift` | Solo se mancano campi per preview (valutare contro schema TASK-033) |
| *nuovo* `SupabasePullPreviewModels.swift` | Struct `SyncPreview` e tipi di supporto §C |
| *nuovo* `SupabasePullPreviewService.swift` (o `SupabaseDryRunPreviewService.swift` se si adotta l’altro nome §K) | Orchestrazione fetch + diff puro in memoria |
| *nuovo* `SwiftDataInventorySnapshotService.swift` (o nome equivalente) | Costruzione snapshot Sendable da `ModelContext` |
| `OptionsView.swift` | Entry DEBUG + sheet/lista preview |
| `Localizable.strings` (tutte le lingue usate dall’app) | Nuove chiavi |
| Test automatici | Eventuale **task successivo**; non obbligatorio se TASK-035 resta manuale/DEBUG |

**Esplicitamente fuori da questo elenco per il dry-run**: `InventorySyncService.swift` (no riuso).

---

### L. Criteri di accettazione (raffinati per review/Execution)

- [ ] **Pull manuale** (azione utente in DEBUG) produce un `SyncPreview` **senza** alcuna scrittura SwiftData.
- [ ] **Nessuna** chiamata HTTP che muti dati remoti (insert/update/upsert/delete/RPC write).
- [ ] **Nessun** `context.insert` / `delete` / `save` durante il flusso preview.
- [ ] Visibili in UI (o export in-memory consultabile nella stessa sessione) le liste **New** / **updateCandidate** / **conflict** / **remoteTombstone** / **warning** e **metric** sintetiche; ordinamento gruppi come §J; preview parziale §I-bis quando applicabile.
- [ ] Errori **RLS** / auth / config / rete / decode / **schema drift** sono **distinguibili** nella presentazione (messaggio o codice mappato).
- [ ] Copy UI chiaro: **Preview** / **Dry-run** / **nessuna modifica applicata** (nessun testo che implichi sync completata).
- [ ] **Build verde**.
- [ ] Con **config mancante** o invalida: nessun crash; messaggio controllato.
- [ ] Con dati remoti **vuoti** (ma fetch riuscito): preview in stato **empty** valido.
- [ ] Con **duplicati barcode** remoti attivi: **conflicts** visibili.
- [ ] Con `deleted_at` remoto: categorizzazione **tombstone**; **nessuna** cancellazione locale.
- [ ] **Nessun segreto** committato; `SupabaseConfig.example.plist` resta template; plist reale fuori git.
- [ ] Paginazione remota conforme a §H; nessun fetch illimitato; budget DEBUG opzionale documentato se attivo.
- [ ] **`inventory_product_prices`**: conforme **§H-ter** (cap/budget, **nessun** fetch illimitato, warning se storico non completamente verificato, **nessuna** riga `ProductPrice` locale creata/aggiornata, **nessun** backfill storico).
- [ ] **UI**: conforme **§J** — preview in **`#if DEBUG`** o dev-only; in **Release** non visibile se nessun task futuro la abilita; nessun copy/badge “sync completata”.
- [ ] **Nessuna Execution** avviata nel periodo **solo planning**; passaggio a EXECUTION solo dopo promozione ad **ACTIVE** e autorizzazione utente (coerente con header § informazioni generali).

---

### L-bis. Review guardrails (checklist anti-scrittura per Claude in Review)

In **Review**, verificare esplicitamente (grep / lettura mirata) che il codice TASK-035 **non**:

- [ ] Chiama `context.insert` nel flusso preview.
- [ ] Chiama `context.delete` nel flusso preview.
- [ ] Chiama `context.save` (o equivalente salvataggio batch) nel flusso preview.
- [ ] Usa client Supabase `.insert`, `.update`, `.upsert`, `.delete` su qualunque tabella.
- [ ] Invoca **RPC mutanti** o Edge Functions di scrittura.
- [ ] Modifica o estende **`InventorySyncService`** per il pull preview.
- [ ] Introduce **auth/login**, JWT persistito manuale, **`service_role`**, o segreti non pubblici.
- [ ] Altera **modelli SwiftData** (`@Model`) o la registrazione **`modelContainer`** per questo task.
- [ ] Log/diagnostica conformi **§J-ter**: nessuna chiave/Authorization/JWT/apikey in chiaro; nessun dump massiccio catalogo/prezzi; messaggi utente senza dati sensibili ingestibili.

*(Questa lista è il prolungamento operativo dei criteri §L; un FAIL su una voce ⇒ **CHANGES_REQUIRED** salvo user override documentato.)*

---

### L-ter. Test consigliati (Execution/Review — **non obbligatori** se manca target test)

Se in futuro esiste un target unit/UI test, **preferire** test **puri / in-memory** sul motore di diff (input = snapshot costruiti a mano, **senza** SwiftData/Supabase live):

| Scenario | Atteso |
|----------|--------|
| Prodotto remoto **nuovo** (barcode mai visto in locale) | classificazione **new** / `newProducts` |
| **`updateCandidate`** | divergenza su prezzo o nome (dopo normalizzazione §G) |
| **Più righe remote attive** stesso barcode | **conflict** |
| **`deleted_at`** remoto valorizzato | **tombstone**; nessuna operazione che implichi delete SwiftData nel test |
| **Products OK** + fetch **suppliers/categories** fallito | **partialPreview** + campi FK non verificabili |
| Storico prezzi oltre **budget** | **warning** “storico non completamente verificato” (§H-ter), senza fallire il catalogo |
| Normalizzazione | stringa vuota ↔ **nil**, **lowercase** supplier/category |
| Double prezzi | uguaglianza con tolleranza **0.001** |

**Nota**: se il progetto **non** ha ancora un bundle di test idoneo, questi restano **raccomandazioni** — non blocco di accettazione per TASK-035 finché documentato in Execution.

---

### M. Rischi residui (breve)

| Rischio | Impatto / mitigazione in TASK-035 |
|---------|-------------------------------------|
| Nessun `remoteId` iOS | Matching solo barcode / nome normalizzato — **ponte temporaneo**; unioni/err FK se dati sporchi → **conflict** / **warning**. |
| Nessun `updatedAt` locale | `updateCandidate` **non** equivale a “update sicuro” — solo **richiede revisione** umana futura. |
| Collisioni **case/spazi** supplier/category | Dedup remoto usa `lower(name)` per owner; locale senza stessa semantica → **warning**/diff nome. |
| **`deleted_at` remoto** vs assenza `deletedAt` locale | Solo flag **tombstone** in preview; **vietato** delete locale automatico. |
| **Date** `ProductPrice` vs **string** remote `effective_at` / `created_at` | Drift o parsing parziale — confronto conservativo; **warning** se non confrontabile. |
| Dataset **grande** | Paginazione §H + limite UI ~100 righe/gruppo §J + budget DEBUG opzionale. |
| **RLS / auth**: solo publishable | Preview **non disponibile** o **partial** senza sessione `authenticated` — errore classificato, nessun bypass (§I, §I-bis). |

---

### N. Follow-up documentati (fuori scope TASK-035)

- Task futuro: **apply locale** dopo conferma utente (merge controllato, backup, eventuali `remote_refs`).
- Task futuro: **bridge `remoteId` / refs SwiftData** per allineamento stabile con UUID Supabase.
- Task futuro: **push manuale** tombstone-compliant.
- Task futuro: **auth reale** (sessione `authenticated`) se RLS lo richiede per catalogo completo.
- Task futuro: **sync avanzata** (background, resolver conflitti, eventi, realtime).

---

### Handoff (post-planning refinement)

| Campo | Valore |
|-------|--------|
| **Stato tracking** | **Stato `TODO` / backlog** con planning consolidato nel file — **non** promosso ad **ACTIVE**. La **fase EXECUTION del workflow** **non** è iniziata; **Execution (Codex)** resta **“Non avviata”**. |
| **Prossima fase (process)** | Fino a promozione ad **ACTIVE** da parte dell’utente: **nessuna** fase **EXECUTION**. Il contenuto **Planning** nel file equivale a fase **PLANNING documentale** (≠ `ACTIVE` + `PLANNING` formale del workflow, se il task non è attivato). |
| **Prossimo agente** | **Utente** per decidere se **attivare** il task (`ACTIVE` + handoff verso Codex) **oppure** lasciarlo in backlog; **Codex** solo dopo autorizzazione esplicita a **EXECUTION**. |
| **Prossima azione** | **Nessuna** modifica a codice Swift, Xcode, SPM, `project.pbxproj`, né creazione file app reali — finché l’utente **non** autorizza esplicitamente l’**Execution**. |

**Blocco operativo (testo unico):**

> **Planning refinement only — Execution non autorizzata.** Dopo questa rifinitura TASK-035 resta **TODO/backlog** con planning consolidato, **oppure** **ACTIVE** solo in fase **PLANNING** se il team lo promuove formalmente. In ogni caso **non** passare a **EXECUTION**, **non** modificare codice app, **non** creare file Swift e **non** toccare Xcode/SPM finché l’utente **non** autorizza esplicitamente **Execution**.

*Planning validated — no Execution authorized. TASK-035 remains TODO/backlog with consolidated planning.*

---


## Execution (Codex) ← solo Codex aggiorna questa sezione
### Avvio Execution — 2026-05-04

- Autorizzazione utente ricevuta in chat: Execution di TASK-035 autorizzata esplicitamente.
- Planning letto e assunto come contratto operativo: prevalgono §L e §L-bis.
- Scope dry-run confermato: preview Supabase → SwiftData solo in memoria, senza apply/merge/backfill/sync reale.
- Nessuna scrittura locale/remota ammessa: vietati `context.insert`, `context.delete`, `context.save` nel flusso preview e vietate chiamate Supabase `.insert`, `.update`, `.upsert`, `.delete`, RPC mutanti o push.
- Fonti lette prima dell'avvio codice: TASK-035, TASK-034, schema audit TASK-033, `SupabaseConfig.swift`, `SupabaseInventoryDTOs.swift`, `SupabaseInventoryService.swift`, `Models.swift`, `OptionsView.swift`, `InventorySyncService.swift`.
- Prossimi passi tecnici: creare modelli/snapshot preview Sendable, snapshot locale SwiftData read-only, fetch remoto paginato read-only, diff engine conservativo, UI DEBUG in `OptionsView`, localizzazioni e check anti-scrittura/build.

### Execution completata — 2026-05-04

#### Obiettivo compreso

Implementata la preview manuale **Supabase → SwiftData dry-run** pianificata per TASK-035: fetch remoto paginato read-only, snapshot locale SwiftData read-only, diff in memoria su struct Sendable, UI DEBUG in `OptionsView` e test puri del diff engine. La preview non applica dati, non risolve conflitti, non fa merge, non fa backfill e non scrive localmente o remotamente.

#### File controllati

- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-035-manual-supabase-pull-swiftdata-dry-run.md`
- `docs/TASKS/TASK-034-supabase-ios-foundation-client-config-dto-readonly.md`
- `docs/SUPABASE/TASK-033-schema-audit.md`
- `iOSMerchandiseControl/SupabaseConfig.swift`
- `iOSMerchandiseControl/SupabaseInventoryDTOs.swift`
- `iOSMerchandiseControl/SupabaseInventoryService.swift`
- `iOSMerchandiseControl/Models.swift`
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/InventorySyncService.swift`
- `iOSMerchandiseControl/LocalizationManager.swift`
- `iOSMerchandiseControlTests/ExcelAnalyzerHTMLParsingTests.swift`
- localizzazioni `it/en/es/zh-Hans`

#### Piano minimo

- Aggiungere modelli preview/snapshot puri e Sendable.
- Costruire snapshot locale da SwiftData senza mantenere riferimenti a `@Model`.
- Estendere il service Supabase solo con fetch paginati read-only.
- Orchestrare fetch remoto: prodotti per primi, poi suppliers/categories/prezzi in parallelo logico; prezzi con budget dedicato.
- Implementare diff engine conservativo: new/updateCandidate/conflict/unchanged/tombstone/warning.
- Aggiungere UI DEBUG in `OptionsView` con sheet `NavigationStack`, gruppi ordinati e copy dry-run.
- Aggiungere test puri in-memory per i casi richiesti.

#### Modifiche fatte

- Nuovo `iOSMerchandiseControl/SupabasePullPreviewModels.swift`: `SyncPreview`, metriche, conflitti, field changes, warning, snapshot remoti/locali, normalizzatore, stato UI `SupabasePullPreviewViewState`.
- Nuovo `iOSMerchandiseControl/SwiftDataInventorySnapshotService.swift`: lettura controllata di `Product`, `Supplier`, `ProductCategory`, `ProductPrice` e conversione in `LocalInventorySnapshot` senza scritture.
- Nuovo `iOSMerchandiseControl/SupabasePullPreviewService.swift`: orchestrazione preview, fetch paginato con page size 500, cap catalogo 10.000 righe, cap storico prezzi 2.000 righe, diff engine puro, warning/sourceErrors sanitizzati.
- Aggiornato `iOSMerchandiseControl/SupabaseInventoryService.swift`: aggiunti solo metodi read-only paginati `fetch*Page(from:to:)` con `.select`, `.order`, `.range`; nessuna API write.
- Aggiornato `iOSMerchandiseControl/OptionsView.swift`: entry point `#if DEBUG`, sheet preview con `NavigationStack`, `Form`, `SectionHeader`, `Label`, `ProgressView`, summary e gruppi: Conflicts, Update candidates, New, Tombstones, Warnings, Unchanged. Nessun pulsante Apply/Merge/Sync.
- Aggiornate localizzazioni `it/en/es/zh-Hans`: nuove chiavi preview e ritoccato il messaggio diagnostico Supabase esistente per evitare copy "completato/completed" nella sezione Supabase.
- Nuovo `iOSMerchandiseControlTests/SupabasePullPreviewDiffEngineTests.swift`: test in-memory per new product, update candidate, duplicati barcode, tombstone, partial supplier error, budget storico prezzi, normalizzazione stringhe/lowercase/tolleranza Double.
- Aggiornato tracking in `docs/MASTER-PLAN.md` e in questo file task.

#### Conferme dry-run / read-only

- Nessuna scrittura automatica SwiftData introdotta nel flusso preview.
- Nessun `context.insert`, `context.delete`, `context.save` nei file preview/UI.
- Nessuna chiamata Supabase `.insert`, `.update`, `.upsert`, `.delete`, `.rpc` nei file Supabase/preview/UI toccati.
- Nessun push verso Supabase, nessuna auth/login/JWT manuale, nessun `service_role`, nessun segreto in git.
- `InventorySyncService.swift`, `Models.swift` e `iOSMerchandiseControlApp.swift` non modificati.
- Nessuna modifica a modelli SwiftData `@Model` o `modelContainer`.

#### Check eseguiti

- ✅ ESEGUITO — Build compila: `xcodebuild -quiet -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'generic/platform=iOS Simulator' build` → exit code `0`.
- ✅ ESEGUITO — Build Release compila: `xcodebuild -quiet -configuration Release -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'generic/platform=iOS Simulator' build` → exit code `0`.
- ✅ ESEGUITO — Nessun warning nuovo introdotto verificabile: build Debug quiet finale e build Release quiet senza output; test log contiene solo warning Xcode preesistente `Metadata extraction skipped. No AppIntents.framework dependency found.`.
- ✅ ESEGUITO — Test XCTest: `xcodebuild test -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.1'` → **TEST SUCCEEDED**; 12 test PASS (5 esistenti + 7 nuovi TASK-035).
- ✅ ESEGUITO — Modifiche coerenti con il planning: implementati snapshot/preview/diff/UI DEBUG/localizzazioni/test, senza apply/merge/backfill/sync reale.
- ✅ ESEGUITO — Criteri di accettazione verificati staticamente e con test puri per new/update/conflict/tombstone/partial/warning/normalizzazione/tolleranza.
- ✅ ESEGUITO — Anti-scrittura locale: `rg "context\\.insert|context\\.delete|context\\.save" iOSMerchandiseControl/SupabasePullPreviewModels.swift iOSMerchandiseControl/SupabasePullPreviewService.swift iOSMerchandiseControl/SwiftDataInventorySnapshotService.swift iOSMerchandiseControl/OptionsView.swift` → nessun match.
- ✅ ESEGUITO — Anti-scrittura remota: `rg "\\.insert\\(|\\.update\\(|\\.upsert\\(|\\.delete\\(|\\.rpc\\(" iOSMerchandiseControl/Supabase*.swift iOSMerchandiseControl/OptionsView.swift` → nessun match.
- ✅ ESEGUITO — Nessuna modifica a `InventorySyncService`, modelli SwiftData/modelContainer: `git diff -- iOSMerchandiseControl/InventorySyncService.swift iOSMerchandiseControl/Models.swift iOSMerchandiseControl/iOSMerchandiseControlApp.swift` → nessun output.
- ✅ ESEGUITO — Localizzazioni valide: `plutil -lint iOSMerchandiseControl/*.lproj/Localizable.strings` → OK per `it/en/es/zh-Hans`.
- ✅ ESEGUITO — `git diff --check` → PASS.
- ✅ ESEGUITO — Nessun `SupabaseConfig.plist` reale presente o tracciato: `find ...` e `git ls-files -- iOSMerchandiseControl/SupabaseConfig.plist` → nessun output.

#### Rischi rimasti

- Preview live non provata contro Supabase reale: `SupabaseConfig.plist` reale non è presente nel workspace; con config assente lo stato previsto è `failed(.configMissing)` senza crash.
- RLS/auth live non verificato: coerente con TASK-034/TASK-033; eventuale blocco con chiave pubblica resta errore classificato, senza workaround JWT/service_role.
- Storico prezzi resta best-effort entro budget dedicato: se dataset supera cap o fetch fallisce, warning "Storico prezzi non completamente verificato"; nessun backfill storico in TASK-035.
- Follow-up candidate: task futuro per apply/merge locale confermato dall'utente, bridge remoteId, auth reale e/o push manuale tombstone-compliant.

#### Aggiornamenti file di tracking

- `docs/TASKS/TASK-035-manual-supabase-pull-swiftdata-dry-run.md`: avvio Execution, riepilogo Execution, check e handoff.
- `docs/MASTER-PLAN.md`: task attivo aggiornato da `EXECUTION` a `REVIEW`.

### Handoff post-execution — verso Claude Review

- **Transizione richiesta**: `EXECUTION → REVIEW`.
- **Prossimo responsabile**: Claude / Review.
- **Stato task**: resta `ACTIVE`, non `DONE`.
- **Review richiesta su**:
  - coerenza dry-run/read-only e assenza scritture locali/remoti;
  - correttezza paginazione e budget storico prezzi;
  - classificazione diff e test puri;
  - UI DEBUG, copy e localizzazioni;
  - completezza dei check §L / §L-bis.

---

## Review (Claude) ← solo Claude aggiorna questa sezione
### Review completata — 2026-05-04

- **Review status**: APPROVED
- **Decisione finale**: APPROVED / DONE
- **Perimetro verificato**: TASK-035 implementa una preview manuale **Supabase → SwiftData dry-run** senza apply, merge, backfill, sync reale, push remoto o scrittura locale. L'entry point UI resta sotto `#if DEBUG`; in Release la preview non è visibile.
- **File letti / controllati prima della review**:
  - `docs/TASKS/TASK-035-manual-supabase-pull-swiftdata-dry-run.md`
  - `docs/TASKS/TASK-034-supabase-ios-foundation-client-config-dto-readonly.md`
  - `docs/SUPABASE/TASK-033-schema-audit.md`
  - `docs/MASTER-PLAN.md`
  - `iOSMerchandiseControl/SupabaseConfig.swift`
  - `iOSMerchandiseControl/SupabaseInventoryDTOs.swift`
  - `iOSMerchandiseControl/SupabaseInventoryService.swift`
  - `iOSMerchandiseControl/SupabasePullPreviewModels.swift`
  - `iOSMerchandiseControl/SupabasePullPreviewService.swift`
  - `iOSMerchandiseControl/SwiftDataInventorySnapshotService.swift`
  - `iOSMerchandiseControl/OptionsView.swift`
  - `iOSMerchandiseControl/Models.swift`
  - `iOSMerchandiseControl/InventorySyncService.swift`
  - `iOSMerchandiseControlTests/SupabasePullPreviewDiffEngineTests.swift`
  - localizzazioni `it/en/es/zh-Hans`
- **Architettura verificata**:
  - `SyncPreview`, snapshot e diff engine sono struct/enum puri `Sendable` e non mantengono riferimenti a SwiftData `@Model`.
  - `SwiftDataInventorySnapshotService` legge SwiftData in una passata controllata e produce snapshot locali immutabili; nessuna query SwiftData nel loop di diff.
  - `SupabasePullPreviewService` orchestra fetch remoto, snapshot locale e diff; `OptionsView` resta UI/state, senza business logic pesante.
  - `InventorySyncService.swift`, `Models.swift` e `iOSMerchandiseControlApp.swift` non risultano modificati per TASK-035.
- **Fetch remoto / performance verificati**:
  - `inventory_products` è fetchato per primo; un fallimento products resta fatale e non genera preview finta.
  - Dopo products OK, suppliers/categories/productPrices sono fetchati con `async let`.
  - Fetch paginato via `.range`, `pageSize` clampato a 1...1000, stop quando pagina < pageSize.
  - `inventory_product_prices` resta secondario con budget dedicato; fallimento/cap produce warning/sourceErrors senza fallire il catalogo.
- **Diff correctness verificata**:
  - Classificazioni coperte: new product, update candidate, duplicato barcode remoto attivo, tombstone, unchanged, warning/sourceErrors, partial preview, barcode remoto vuoto, normalizzazione supplier/category trim+lowercase, tolleranza Double 0.001, ProductPrice solo in preview.
  - I ProductPrice remoti `PURCHASE` / `RETAIL` sono normalizzati solo nel layer preview e non generano `ProductPrice` locali.
- **UI/UX verificata**:
  - Entry point e sheet sotto `#if DEBUG`.
  - UI coerente con `OptionsView`: `Form`, `Section`, `SectionHeader`, `Label`, `ProgressView`, `NavigationStack`, sheet.
  - Ordine gruppi rispettato: Conflicts → Update candidates → New → Tombstones → Warnings → Unchanged.
  - Liste limitate a 100 righe per gruppo con messaggio localizzato per righe nascoste.
  - Copy coerente con Preview / Dry-run / nessuna modifica applicata; nessun bottone Apply/Merge/Sync e nessun testo di sync completata/allineamento/merge.
- **Logging / privacy verificati**:
  - Nessun `print`, `NSLog`, `Logger` o dump massiccio nei file Supabase/preview/UI.
  - Nessun logging di chiavi Supabase, `Authorization`, JWT, apikey completa o payload catalogo/prezzi.
  - `sourceErrors` usano dettagli sanitizzati e bounded.
- **Fix diretti applicati in Review**:
  - `SupabasePullPreviewService.fetchPaged`: il budget ora è rispettato anche quando `maxRows` è minore del `pageSize`, evitando fetch oltre cap.
  - `SupabasePullPreviewDiffEngineTests`: aggiunti test puri per barcode remoto vuoto (conflict/warning, non `newProduct`) e ProductPrice remoto trattato solo come diff preview.
  - Localizzazioni `it/es/zh-Hans`: rifinite label gruppi/metriche della preview per evitare copy misto non necessario.
- **Check eseguiti**:
  - ✅ ESEGUITO — Build Debug: `xcodebuild -quiet -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'generic/platform=iOS Simulator' build` → exit code `0`.
  - ✅ ESEGUITO — Build Release: `xcodebuild -quiet -configuration Release -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'generic/platform=iOS Simulator' build` → exit code `0`.
  - ✅ ESEGUITO — Test: `xcodebuild test -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.1'` → **TEST SUCCEEDED**, 14 test PASS (5 esistenti + 9 TASK-035).
  - ✅ ESEGUITO — Nessun warning nuovo verificabile: build Debug/Release quiet senza output; nel test resta solo warning Xcode preesistente `Metadata extraction skipped. No AppIntents.framework dependency found.`
  - ✅ ESEGUITO — Anti-scrittura locale: `rg "context\\.insert|context\\.delete|context\\.save" ...` sui file preview/UI → nessun match.
  - ✅ ESEGUITO — Anti-scrittura remota: `rg "\\.insert\\(|\\.update\\(|\\.upsert\\(|\\.delete\\(|\\.rpc\\(" iOSMerchandiseControl/Supabase*.swift iOSMerchandiseControl/OptionsView.swift` → nessun match.
  - ✅ ESEGUITO — Verifica file esclusi: `git diff -- iOSMerchandiseControl/InventorySyncService.swift iOSMerchandiseControl/Models.swift iOSMerchandiseControl/iOSMerchandiseControlApp.swift` → nessun output.
  - ✅ ESEGUITO — Localizzazioni: `plutil -lint iOSMerchandiseControl/*.lproj/Localizable.strings` → OK per `en/es/it/zh-Hans`.
  - ✅ ESEGUITO — `git diff --check` → PASS.
  - ✅ ESEGUITO — Segreti/config: `git ls-files -- iOSMerchandiseControl/SupabaseConfig.plist` e `find iOSMerchandiseControl -name 'SupabaseConfig.plist' -print` → nessun output; `.gitignore` esclude plist reale e xcconfig locali/segreti; scan diff senza chiavi reali/JWT/Authorization/Bearer/service_role.
- **Criteri di accettazione verificati**:
  - ✅ ESEGUITO — Pull manuale produce preview in memoria senza scritture SwiftData.
  - ✅ ESEGUITO — Diff new/update/conflict/tombstone/warning/unchanged e metriche disponibili.
  - ✅ ESEGUITO — Conflitti visibili e non risolti automaticamente.
  - ✅ ESEGUITO — Ogni applicazione dati resta fuori scope; nessun apply/merge/backfill/sync reale introdotto.
- **Rischi residui**:
  - Preview live non provata contro Supabase reale perché `SupabaseConfig.plist` reale non è presente/tracciato nel workspace; con config assente il flusso resta controllato e non crasha.
  - RLS/auth live non verificato per assenza config/sessione reale; eventuale blocco RLS resta errore classificato senza workaround JWT/service_role.
  - Storico prezzi resta best-effort entro budget dedicato; allineamento/backfill storico è fuori scope.
  - Follow-up candidate: apply locale controllato, bridge `remoteId`/refs SwiftData, auth reale se necessaria, push manuale, sync avanzata.

---

## Fix (Codex) ← solo Codex aggiorna questa sezione
Non avviato.

---

## Chiusura

### Conferma utente
- [x] Utente ha autorizzato la chiusura con override esplicito: se la Review passa, portare TASK-035 a DONE e allineare MASTER-PLAN.

### Follow-up candidate
- **Apply locale controllato** dopo conferma utente, con backup/log e nessun merge implicito.
- **Bridge `remoteId` / refs SwiftData** per mappare UUID Supabase e identità locali in modo stabile.
- **Auth reale Supabase** se serve una sessione `authenticated` per superare RLS owner-scoped.
- **Push manuale** tombstone-compliant, separato dal pull preview.
- **Sync avanzata** futura: resolver conflitti, background/realtime, watermark/eventi.

### Riepilogo finale
Preview manuale Supabase → SwiftData dry-run approvata tecnicamente e chiusa: fetch remoto paginato read-only, snapshot SwiftData read-only, diff engine puro, UI DEBUG localizzata, test in-memory e build/test/check verdi. Nessuna scrittura locale/remota, nessun apply/merge/backfill/sync reale, nessun auth/JWT/service_role o segreto introdotto.

### Data completamento
2026-05-04
