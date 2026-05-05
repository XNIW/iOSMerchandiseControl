# TASK-039: Supabase preview → apply locale controllato SwiftData

## Informazioni generali
- **Task ID**: TASK-039
- **Titolo**: Supabase preview → apply locale controllato SwiftData
- **File task**: `docs/TASKS/TASK-039-supabase-preview-apply-locale-controllato-swiftdata.md`
- **Stato**: DONE
- **Fase attuale**: DONE
- **Responsabile attuale**: Claude / Reviewer
- **Data creazione**: 2026-05-05
- **Ultimo aggiornamento**: 2026-05-05
- **Ultimo agente che ha operato**: Claude / Reviewer

## Dipendenze
- **Dipende da**: TASK-038 (DONE — Google Auth iOS, client Supabase session-aware, preview auth-gated), TASK-035 (DONE — preview dry-read-only `SyncPreview`), TASK-034 (DONE — foundation client/DTO readonly), TASK-033 (DONE — audit schema/mapping Supabase ↔ iOS/Android)
- **Sblocca**: bridge `remoteId` / push manuale tombstone-compliant / sync avanzata (resolver conflitti, watermark, realtime) — fuori scope TASK-039; da backlog dopo DONE esplicito utente

## Scopo
Pianificare una slice sicura per applicare a **SwiftData** solo risultati **affidabili** della preview Supabase (`SyncPreview`), dopo **conferma esplicita** dell’utente, con **anti-perdita dati**, **nessuna scrittura remota**, **nessun sync automatico**, e **blocco rigido** quando la preview è **parziale** o non qualificabile.

## Contesto obbligatorio
- TASK-038 è **DONE**: OAuth Google, `SupabaseClientProvider` condiviso con sessione, preview solo se autenticati, test live OK.
- TASK-035 è **DONE**: `SupabasePullPreviewService.generatePreview` costruisce `SyncPreview` via fetch paginato read-only + diff (`SupabasePullPreviewDiffEngine`); **nessun apply**.
- Durante test live TASK-038 la preview è risultata **parziale** (cap catalogo **10 000** righe prodotti): es. remoti ≈ **10 000**, locali ≈ **16 789**, molti bucket diff; **storico prezzi remoto non verificabile completamente** (`maxProductPriceRows`, cap/errori → warning `priceHistoryIncomplete` / `sourceError`).
- **`SyncPreviewOutcome.partial`** e/o **`sourceErrors` non vuoti** e/o **`priceHistoryIncomplete`** devono essere trattati come **guardrail**: per TASK-039 **slice 1** si adotta **Strategia A** (apply **vietato**, solo visualizzazione dry-run). Follow-up futuro: fetch completo / paginazione controllata **senza cap** prima di consentire apply (task separato).

## Non incluso in TASK-039
- Nessun **push** verso Supabase.
- Nessun **sync automatico**, background o realtime.
- Nessun bridge **`remoteId`** persistente salvo emerge indispensabile → in quel caso solo **follow-up task** dedicato.
- Nessuna **cancellazione locale** da tombstone remoti.
- Nessun **backfill massivo** storico prezzi da preview incompleta.
- Nessuna modifica **schema Supabase** / migrazioni SQL.
- Nessuna **auth** nuova (coperta da TASK-038); nessun Sign in with Apple.
- Nessun redesign ampio UI (solo incremento DEBUG/sheet preview coerente con TASK-035/038).

## File potenzialmente coinvolti (execution futura — non autorizzata in questo turno)
- Nuovo probabile: `iOSMerchandiseControl/SupabasePullApplyService.swift`
- Eventuale estensione tipi: `SupabasePullPreviewModels.swift`
- UI DEBUG: `OptionsView.swift`, sheet preview (`SupabasePullPreviewSheet` se già estratto nel modulo preview)
- Localizzazioni: `iOSMerchandiseControl/*/Localizable.strings`
- Test: `iOSMerchandiseControlTests/*` (nuovi test apply puri + fixture `SyncPreview`)
- Tracking: questo file + `docs/MASTER-PLAN.md`
- **Evitare** `Models.swift` salvo stretta necessità (preferire servizio + opzioni).
- **Non** toccare `project.pbxproj` salvo aggiunta file necessaria in EXECUTION.
- **Non** toccare schema Supabase.

## Criteri di accettazione (contratto TASK-039 — da verificare in EXECUTION/REVIEW)
- [x] Build **Debug** e **Release** verdi.
- [x] **XCTest** previsti PASS (vedi sezione *Test automatici / manuali pianificati* nel Planning).
- [x] **Apply disabilitato** se `preview.outcome == .partial` **oppure** `!preview.sourceErrors.isEmpty` **oppure** è presente warning `priceHistoryIncomplete` (o policy equivalente documentata che copre «price history not fully verified»).
- [x] **Apply disabilitato** se esistono **conflitti** applicabili nella preview (lista `conflicts` non vuota per kinds bloccanti: duplicati barcode remoti, barcode vuoto remoto, supplier/category mancanti quando il fetch catalogo non è fallito, duplicati barcode locali, ecc. — allineare alla stessa semantica TASK-035).
- [x] **Apply disabilitato** con **sessione assente / non valida** al momento dell’azione (guardia esplicita lato UI + validazione servizio).
- [x] **Nessuna scrittura remota** dall’apply (nessuna chiamata write Supabase dal percorso apply).
- [x] **Nessun delete locale** da `remoteTombstones`.
- [x] Architettura API: **`prepareApplyPlan`** (puro: **nessuna mutazione persistente SwiftData**, **nessun `save()`**, **nessuna rete**; uso **`ModelContext` consentito solo in lettura** `fetch` se serve alla validazione del piano) + **`apply(plan:)`** (mutazioni locali + **un solo `context.save()`** + stale guard prima delle mutazioni).
- [x] **Payload applicabile completo** obbligatorio per **ogni `newProduct`** e per **ogni `updateCandidate` che entri nel piano di apply**; **vietato** costruire valori da applicare usando **solo** `SyncPreviewFieldChange.remoteDisplay` o la summary — gli update devono leggere dalla stessa **fonte applicabile** (payload / fingerprint allineato al DTO preview) usata per i new.
- [x] **Stale preview guard**: ricostruzione `LocalInventorySnapshot` corrente e confronto con fingerprint/`localDisplay` attesi nel piano; errore **`previewStale`** + UX «Rigenera preview» se mismatch (**non** basarsi solo su `generatedAt`).
- [x] UI: **`SupabasePullApplyDisabledReason`** → footer localizzato per pulsante disabilitato; **`isApplyingLocalPreview`** + **ProgressView** durante apply (anti doppio tap); servizio/documentazione **non re-entrant** o serializzazione UI obbligatoria.
- [x] Su **preview completa** (fixture di test / scenario controllato): **nuovi prodotti** applicabili con nome (**Decisione #4**); **update candidates** applicabili in modo **conservativo**; **mai** cambiare barcode su **Product** esistenti.
- [x] **Supplier/category**: risoluzione per nome normalizzato (`SupabasePullPreviewNormalizer.normalizedLookupName`) con **create-or-reuse** senza duplicati visibili rispetto vincoli `@Attribute(.unique)` SwiftData.
- [x] Copy UX: pulsante **«Applica al database locale»**; messaggio successo **«Applicato localmente: X nuovi, Y aggiornati.»** (localizzato) **solo dopo `save()` riuscito**; dialog che chiarisce solo SwiftData locale, nessuna scrittura Supabase, nessuna eliminazione prodotti locali; **vietato** linguaggio «sync cloud», «cloud completato», «Supabase aggiornato».
- [x] **`context.save()`** fallisce → **mai** messaggio di successo né conteggi «applicati»; errore **localizzato** con suggerimento rigenerare preview / verificare DB locale (dettaglio in *Errore durante save SwiftData*).
- [x] Localizzazioni complete per nuove stringhe (IT / EN / **ZH-Hans** come da convenzione app).
- [x] Nessun segreto in repo; TASK-038 resta **DONE** e non va riaperto.
- [x] TASK-039 **non** passa a **EXECUTION** senza **approvazione esplicita utente** sul planning.

## Decisioni
| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|-------|
| 1 | **Strategia A (slice 1)**: apply **vietato** se preview `partial`, `sourceErrors` non vuoti, o affidabilità storico prezzi non garantita (`priceHistoryIncomplete` / outcome non success). Messaggio UI chiaro; nessun apply parziale «best effort». | B: permettere apply subset dopo fetch completo/paginazione senza cap — rimandato a **follow-up task** | Sicurezza e semplicità; evita merge su dataset incompleto (cap 10 000 osservato live). | attiva |
| 2 | **Slice 1 — no import storico `ProductPrice` da remoto**; aggiornare solo **prezzi correnti** su `Product` se validi e diversi (tolleranza **0.001** come `SupabasePullPreviewNormalizer.doubleTolerance`). Storico remoto → task dedicato se/when preview prezzi è completa e progettata. | Scrivere `ProductPrice` per ogni diff `priceHistory` | Preview prezzi spesso incompleta (cap righe); rischio storico inconsistente. | attiva |
| 3 | **`stockQuantity`**: aggiornamento da remoto solo se **opt-in** esplicito in `SupabasePullApplyOptions` (default **false**) per ridurre overwrite inventario locale involontarie. | Sempre allineare stock remoto | Allinea a cautela inventario offline-first. | attiva |
| 4 | **Nome prodotto obbligatorio per nuovi `Product`**: per inserire un nuovo prodotto serve **`productName`** oppure **`secondProductName`** semanticamente valido (`semanticString` / non vuoto dopo trim). **Nessun placeholder barcode-only** in TASK-039 slice 1. Se entrambi assenti → `missingRequiredField`, riga non applicabile; se nel piano «safe» non resta lavoro valido → fallimento coerente (`noApplicableChanges` o errore prepare a seconda della policy scelta in execution). | Placeholder nome da solo barcode | Coerenza con validazione Android **ImportAnalyzer** (almeno uno tra nome principale e secondario); evita catalogo illeggibile e divergenza piattaforme. | attiva |

---

## Planning (Claude) ← solo Claude aggiorna questa sezione

### Obiettivo (dettaglio)
Definire una slice sicura (**TASK-039 slice 1**) che:
1. Validi `SyncPreview` **prima** di qualsiasi mutazione SwiftData (incluso payload applicabile e guard anti-stale).
2. Costruisca un **`SupabasePullApplyPlan`** determinista tramite **`prepareApplyPlan`** — **puro**, senza mutazioni SwiftData e senza rete.
3. Esegua mutazioni tramite **`apply(plan:)`** — **solo piano già validato**, **nessuna rete**, **un solo `context.save()`** a fine percorso felice; metriche in **`SupabasePullApplyResult`**.
4. Integrazione UI DEBUG: pulsante **«Applica al database locale»**, motivo disabilitazione localizzato (`SupabasePullApplyDisabledReason`), serializzazione apply, `confirmationDialog`, summary, feedback post-apply.

### Addendum planning — dati applicabili e anti-stale preview
Oggi **`SyncPreviewProductSummary`** è una **summary UI/diff**: espone barcode, `productName` (singolo campo), `remoteID`, `fieldChanges`, ecc. **Non contiene** un modello completo dei campi remoti necessari per costruire un `Product` SwiftData né garantisce `secondProductName`, prezzi, stock, supplier/category risolti come snapshot applicabile.

**Regola**: non si devono **inventare** valori di `Product` né per insert né per update derivando solo dalla summary o dai soli `remoteDisplay` nei `SyncPreviewFieldChange`.

**Prima dell’EXECUTION** va scelta una **fonte dati completa** per l’apply:
- **Preferenza (consigliata)**: estendere il risultato preview con un **payload applicabile locale**, es. `SyncPreviewProductApplyPayload` (o `remoteProductPayload`) **per ogni riga** da inserire/aggiornare, contenente almeno i campi remoti necessari: `barcode`, `itemNumber`, `productName`, `secondProductName`, `purchasePrice`, `retailPrice`, `stockQuantity`, `supplierName`, `categoryName` (tipi nullable coerenti con DTO/read path TASK-035). Il payload va popolato **durante la fase preview** (stesso fetch già usato dal diff), così `prepareApplyPlan` e `apply(plan:)` restano **no-network**.
- **Alternativa**: re-fetch remoto dentro l’apply — **sconsigliata e scartata per slice 1** perché viola il vincolo **no-network / no Supabase** sul percorso apply e aumenta superficie errori (sessione/RLS).

**Blocchi espliciti**: senza payload completo affidabile per **newProducts** e per **ogni `updateCandidate` da applicare**, l’apply deve essere **bloccato** / la riga esclusa con errore tipo **`missingApplicablePayload`** / **`missingRequiredField`** (policy: es. fallimento prepare globale se manca payload per una qualsiasi riga inclusa nel piano — da rendere deterministica nei test).

**Update**: anche per gli update il piano non deve inferire importi dai soli `fieldChanges` UI; **`remoteDisplay`** resta diagnostica/preview, non fonte canonica di merge.

Nota codice attuale (`SupabasePullPreviewModels.swift`): la struct summary non include `secondProductName`; il diff engine opera su `RemoteInventoryProductRow` completo — il payload va progettato come **proiezione stabile** da quella fonte, non dalla summary da sola.

### Analisi — stato attuale iOS (post lettura sorgenti)
- **Auth**: `SupabaseAuthViewModel` + client condiviso `SupabaseClientProvider` (session-aware, `emitLocalSessionAsInitialSession`, refresh); preview e diagnostica in `OptionsView` gated su `isSignedIn`.
- **Preview**: `SupabasePullPreviewService` fetch paginato con **cap** (`maxCatalogRows` 10 000, `maxProductPriceRows` 2 000); se cap/errore → `partialCatalog` → `SyncPreviewOutcome.partial` + `sourceErrors`; `SupabasePullPreviewViewState.partial` vs `success`.
- **Modelli**: `SyncPreview` include `newProducts`, `updateCandidates`, …; ogni **`SyncPreviewProductSummary`** è solo summary (vedi Addendum payload). `LocalProductSnapshot` in `SwiftDataInventorySnapshotService` espone già tutti i campi confrontabili per diff/anti-stale.
- **SwiftData**: `Product` (barcode unique, relazioni `Supplier`/`ProductCategory`, `priceHistory` cascade), `ProductPrice` (`PriceType` lowercase, `effectiveAt`/`createdAt` Date) — `Models.swift`.
- **Snapshot locale**: `SwiftDataInventorySnapshotService.makeSnapshot()` — allineato al diff engine.
- **Manca**: servizio apply dedicato; UI apply; regole unify su `partial`/`sourceErrors`/conflitti; strategia merge campo-per-campo e test XCTest apply.

### Riferimento Android (solo funzionale — non copia 1:1)
Percorsi tipici nel repo SplitView (TASK-033): `InventoryRepository.applyImport` / `applyImportAtomically` con mutex; `ProductDao.applyImport`; `DatabaseViewModel` orchestrazione; analisi import (`ImportAnalyzer` / modelli analisi); `ProductPrice` / `ProductPriceSummary`; `PriceBackfillWorker`; `AppDatabase` con bridge remote refs. Pattern utili concettuali:
- Separazione **analisi** vs **apply atomico** / serializzazione apply.
- Registrazione storico prezzi quando cambiano purchase/retail (qui **rimandato** per slice 1 iOS salvo decisione futura).
Su **iOS**: SwiftData, conferma nativa SwiftUI, validazione pura + singolo save, senza Room transaction né remote refs obbligatori.

### Decisione fondamentale — apply vietato su preview partial (**Strategia A**)
Condizioni **blocco apply** (tutte da implementare come helper es. `SyncPreview.isSafeForApply` + validazione servizio):
- `outcome == .partial`
- `!sourceErrors.isEmpty`
- Conflitti presenti nella lista `conflicts` (non applicare mai righe in conflitto)
- Warning **`priceHistoryIncomplete`** presente (storico remoto truncato / fetch fallito — non affidabile per slice che tocchi prezzi storici; coerente con scelta di non importare storico in slice 1)
- Duplicati barcode **remoti attivi** già esclusi dal diff ma presenti come **`SyncPreviewConflict.remoteDuplicateBarcode`**
- **`sessionMissing`** / utente non autenticato al tap apply (difesa in profondità)
- Righe **`classification == .warning`** non applicare (solo visualizzazione)

**Follow-up (task futuro)**: aumentare budget fetch / rimuovere cap / paginazione completa fino a `reachedCap == false` per tutte le tabelle coinvolte; solo allora rivalutare Strategia B.

### Apply scope consigliato — slice 1
**Consentito** (solo se preview «safe» sopra):
- Inserimento **`newProducts`** con barcode valido, **payload applicabile completo** (Addendum), e almeno uno tra **`productName`** / **`secondProductName`** semanticamente valido (**Decisione #4** — nessun placeholder barcode-only).
- **`updateCandidates`** senza conflitto associato al barcode: aggiornamento **campo-per-campo** solo se il valore remoto è **semanticamente presente** (`semanticString` / numeri validi) e diverso oltre tolleranza dove pertinente.
- Creazione **`Supplier`** / **`ProductCategory`** per nome referenziato dai prodotti inclusi nel piano (match **`normalizedLookupName`** → reuse canonical stored name da snapshot locale o primo visto).
- Prezzi correnti: aggiorna `purchasePrice`/`retailPrice` solo se validi e non uguali entro **0.001**.

**Vietato**:
- Applicare **`conflicts`**, **`remoteTombstones`** (no delete locale), righe **`warning`**, subset «parziale» dei new/update quando preview unsafe.
- Applicare se **`localDuplicateBarcode`** presente nei conflitti (DB locale inconsistente — bloccare apply globale o perimetro documentato; raccomandazione: **blocco globale** con errore `localDuplicateBarcode`).
- Sovrascrivere campo locale «pieno» con remoto nil/stringa vuota (**mai cancellare dati locali** in questa slice).

### Servizio da pianificare — `SupabasePullApplyService`
File probabile: `iOSMerchandiseControl/SupabasePullApplyService.swift`

**Design**: **`SupabasePullApplyService`** **non** deve ricevere **`SupabaseInventoryService`** né nel **`prepareApplyPlan`** né nel **`apply(plan:)`**; **nessuna dipendenza di rete** su questi percorsi. Il client Supabase resta nella pipeline **`SupabasePullPreviewService`** (TASK-035).

API concettuale (due fasi):
```swift
@MainActor
final class SupabasePullApplyService {
    func prepareApplyPlan(
        preview: SyncPreview,
        context: ModelContext,
        options: SupabasePullApplyOptions,
        isAuthenticated: Bool
    ) throws -> SupabasePullApplyPlan

    func apply(plan: SupabasePullApplyPlan, context: ModelContext) throws -> SupabasePullApplyResult
}
```

Comportamento richiesto:
- **`prepareApplyPlan`**: **puro** — **nessuna mutazione persistente** (vietati insert/update/delete e **`save()`**), **nessuna rete**; **`ModelContext`** ammesso **solo per letture** (`fetch`) coerenti col piano/stale fingerprints se necessario; valida sessione (`isAuthenticated`), preview safe, payload applicabile, regole campo; incapsula nel **`SupabasePullApplyPlan`** i valori **`localDisplay`/snapshot attesi** per barcode coinvolti così **`apply`** può confrontarli con uno snapshot fresco (Guard stale).
- **`apply(plan:)`**: accetta **solo** un `SupabasePullApplyPlan` già validato; esegue **stale preview guard** **subito all’ingresso**, **prima** di qualunque insert/update/delete sui modelli; poi mutazioni locali e **un solo `try context.save()`** nel percorso felice (vedi sotto).
- Errori tipizzati `SupabasePullApplyError` (throw) vs `ApplyValidationWarning` in result dove non bloccante.

**Re-entrancy / concorrenza servizio**: progettare la classe come **non re-entrant** (documentare «non chiamare apply in parallelo sullo stesso context») **oppure** documentare che **solo la UI** serializza — minimo: **una apply alla volta** obbligatoria.

**Nota transazioni SwiftData**: resta valida la **fase prepare (pura)** vs **fase apply + save singolo**; rollback pre-save è implicito se save fallisce.

### Guard stale preview (obbligatorio)
Al tap conferma apply / ingresso in **`apply(plan:)`**, **prima** di mutare dati persistenti:
1. Ricostruire uno **`LocalInventorySnapshot`** fresco via **`SwiftDataInventorySnapshotService.makeSnapshot()`** sullo stesso `ModelContext`.
2. Verificare **compatibilità** tra lo stato locale attuale e quanto assunto nel piano / nella preview (es. per ogni barcode in update: valori locali devono ancora coincidere con i **`localDisplay`/snapshot attesi** registrati nel piano al momento di `prepare`, salvo equivalenza normalizzata definita).
3. **`generatedAt`** di `SyncPreview`: usare solo per **copy/debug** («preview generata alle …»), **non** come unico criterio di stale.

Se prodotti / supplier / category coinvolti sono cambiati dopo la generazione preview → **`previewStale`** → bloccare apply, **nessun save**, messaggio UI che invita a **«Rigenera preview»**.

### Modelli / tipi da introdurre (planning)
- **`SyncPreviewProductApplyPayload`** (nome indicativo): struct per riga applicabile con tutti i campi remoti necessari (Addendum).
- `SupabasePullApplyOptions`: `applyStockQuantity: Bool` (default false), eventuale `Set<SyncPreviewFieldKey>` per updates, flag debug opzionali.
- `SupabasePullApplyPlan`: snapshot dei barcode coinvolti, payload per insert/update, expected local fingerprints per stale-check, conteggi, supplier/category da creare.
- `SupabasePullApplyResult`: `inserted`, `updated`, `supplierCreated`, `categoryCreated`, esclusioni, ecc.

**Enum UI — `SupabasePullApplyDisabledReason`** (motivo pulsante disabilitato / footer primario):
- `sessionMissing`
- `partialPreview`
- `sourceErrorsPresent`
- `priceHistoryIncomplete`
- `conflictsPresent`
- `localDuplicateBarcode`
- `missingApplicablePayload`
- `previewStale`
- `noApplicableChanges`

La UI deve risolvere `reason → chiave Localizable.strings` (IT / EN / ZH-Hans) e mostrare **footer breve** coerente, **non** solo toggle generico del pulsante.

- `SupabasePullApplyError` (throw da prepare o apply), include almeno:
  - `partialPreviewBlocked`, `sourceErrorsPresent`, `conflictsPresent`, `sessionMissing`
  - `noApplicableChanges`
  - `localDuplicateBarcode`
  - `missingRequiredField`
  - `missingApplicablePayload`
  - `invalidPrice`
  - **`previewStale`**
  - `saveFailed(underlying:)` — per collisioni `@Attribute(.unique)` dopo fetch-before-insert, considerare wrapping / recovery documentato (vedi policy supplier/category)

- `ApplyProductFieldChange` — audit per metriche/test.
- `ApplyValidationWarning` — esclusioni non fatali dove previsto.

### UI/UX — stato apply e polish (solo planning)
- **`OptionsView`** e/o **`SupabasePullPreviewSheet`**: stato **`isApplyingLocalPreview`** (o equivalente); durante apply: pulsante **«Applica al database locale»** disabilitato, **`ProgressView`** locale, **nessuna seconda apply concorrente** (guard anche `guard !isApplyingLocalPreview`).
- Pulsante disabilitato: footer con **`SupabasePullApplyDisabledReason`** principale; se motivo **`previewStale`** o **`partialPreview`** (o altri dove ha senso), mostrare testo/link azione **«Rigenera preview»** (chiude sheet / richiama `generatePreview`).
- **`confirmationDialog`**: deve includere esplicitamente: **aggiorna solo SwiftData locale**, **non scrive su Supabase**, **non elimina prodotti locali**.
- Success: **«Applicato localmente: X nuovi, Y aggiornati.»** (parametri localizzati).
- Vietati copy «sync cloud», «cloud completato», «Supabase aggiornato».

### Sicurezza / guardrail dati
- Nessuna scrittura remota; nessun apply partial quando outcome/errors lo vietano.
- Nessun delete da tombstone.
- Regola **nil/empty remote**: non modifica campo locale.
- Barcode obbligatorio per insert (normalizzato come preview).
- **Nome nuovo prodotto**: **Decisione #4** — almeno uno tra `productName` e `secondProductName` valido; altrimenti `missingRequiredField`.
- `context.save` solo dopo stale-check + piano validato; fallimento validazione → **throw** prima di mutazioni persistenti.

### Policy dettagliata campi — slice 1
- **`barcode`**: per **`Product` esistenti**, **mai** mutare il barcode in TASK-039 (identità locale resta il barcode creato all’insert).
- **`productName` / `secondProductName` / `itemNumber`**: aggiorna solo se valore remoto nel piano/payload è **semanticamente presente** (`semanticString`); nil/vuoto **non** cancella mai il locale.
- **`purchasePrice` / `retailPrice`**: aggiorna solo se remoti **finiti**, **non NaN**, **non infinite**, **≥ 0**, e diversi dal locale oltre tolleranza **0.001** (`SupabasePullPreviewNormalizer.doubleTolerance`).
- **`stockQuantity`**: solo se `options.applyStockQuantity == true`; valore remoto deve essere **finito** e **≥ 0**; altrimenti blocco/tratto righe escluso con errore validazione.
- **`supplier` / `category`**: **create-or-reuse** tramite **`normalizedLookupName`**; pattern **fetch-before-insert** per riuso case-insensitive coerente con snapshot; se collisione **`@Attribute(.unique)`** SwiftData durante insert, ripetere fetch; se ancora fallisce → **`saveFailed`** (o errore dedicato recoverable documentato).
- **Remoto nil/vuoto**: non cancella mai dati locali (già sopra).

Campi candidati update **default** (ove consentiti dalla policy): `itemNumber`, `productName`, `secondProductName`, `purchasePrice`, `retailPrice`, `supplier`, `category`, opzionale `stockQuantity` solo con flag.

### Price history
Slice 1: **non** creare righe `ProductPrice` da dati remoti; aggiornare solo snapshot corrente su `Product`. Follow-up: task storico + preview completa.

### Tombstones
Mostrare in UI preview (già in lista); **non** cancellare né marcare deleted locale.

### Test automatici / manuali pianificati
**XCTest puri** (ModelContainer in-memory + `ModelContext`):
- **`prepareApplyPlan`** fallisce / blocca se manca **payload applicabile** per righe **newProducts** o per **updateCandidates** inclusi nel piano
- **`prepareApplyPlan`**: `missingRequiredField` se **`productName`** e **`secondProductName`** sono entrambi vuoti per un new previsto nel piano
- **`apply(plan:)`** fallisce con **`previewStale`** se lo stato locale cambia tra preview/prepare e apply (simulare mutazione SwiftData intermediaria vs fingerprint atteso)
- **Doppio tap / reentrancy**: con **`isApplyingLocalPreview`** (o equivalente testabile), seconda invocazione apply non parte mentre la prima è in corso
- **Barcode esistente**: dopo insert/update, barcode **`Product` locale** invariato per update candidate
- **Prezzi**: NaN / infinite / negativi → blocco / errore prepare o apply
- **Stock**: con `applyStockQuantity == true`, stock remoto negativo → blocco
- **Supplier/category**: reuse **case-insensitive** tramite chiave normalizzata (due casing diversi → un solo `Supplier`/`ProductCategory`)
- **No network**: `SupabasePullApplyService` apply/prepare **non** riceve `SupabaseInventoryService` e test che compilando il tipo non esponga dipendenze remote sul apply path
- **No `ProductPrice`**: slice 1 — nessuna insert `ProductPrice` da apply (asserzione count pre/post)
- **`samePlanSecondApplyDoesNotDuplicateAndDoesNotMutate`**: dopo un apply riuscito con uno stesso `SupabasePullApplyPlan` conservato in test, una seconda invocazione **`apply(plan:)`** non deve creare supplier/category duplicati né mutare ulteriormente i prodotti già allineati; esito atteso **`previewStale`** **oppure** **`noApplicableChanges`** — scegliere una policy unica in EXECUTION e documentarla nei test (coerente con §Idempotenza / riuso piano).
- Copertura già pianificata: partial, sourceErrors, conflicts, insert/update validi, nil remoto non cancella locale, duplicati barcode locale, save solo dopo validazione, metriche corrette

**Manuali**: login Google → preview → partial → apply disabilitato + footer motivo; scenario completo → apply → stale simulato → rigenera preview; dialog copy; Database locale; nessuna modifica Supabase remota.

### File iOS probabilmente toccati in EXECUTION futura
Come §«File potenzialmente coinvolti». Aggiungere test bundle e stringhe IT/EN/zh-Hans.

### Rischi
- **Payload preview insufficiente** per apply reale senza inventare dati (summary-only).
- **`previewStale`** tra generazione preview e conferma utente (modifiche DB locale nel frattempo).
- **Doppio tap / concorrenza UI** durante `context.save()` lenta.
- **`@Attribute(.unique)`** su `Supplier`/`ProductCategory` **`name`**: sensibilità casing SwiftData vs match **`normalizedLookupName`** — collisioni e insert duplicati apparenti.
- **Dataset grande**: UI apparentemente bloccata durante **`context.save()`** su migliaia di righe — considerare feedback progress locale solo come follow-up se CA lo richiedono.
- Preview partial sistemica per cataloghi > **10 000** righe finché il cap resta (Strategia A).
- Sessione scaduta tra preview e apply — `sessionMissing` / retry login.
- SwiftData «transazione» limitata — prepare pura + save singolo apply.

### Determinismo apply plan
Il **`SupabasePullApplyPlan`** deve essere costruito e consumato in modo **deterministico** per barcode/chiavi stabili:
- **Supplier/category da creare**: ordinati per **`normalizedLookupName`** (chiave lexicografica stabile sul nome normalizzato).
- **Prodotti da inserire / aggiornare**: ordinati per **barcode normalizzato** (`SupabasePullPreviewNormalizer.normalizedBarcode`).
- **`SupabasePullApplyResult`** (metriche `inserted`, `updated`, ecc.): valori **riproducibili** sullo stesso input piano + snapshot compatibile — utile per **XCTest**, debug e review.

### Idempotenza / riuso piano
- Ripresentare lo **stesso** `SupabasePullApplyPlan` dopo un **apply riuscito** **non** deve duplicare **`Supplier`** / **`ProductCategory`** già creati nel primo passaggio (create-or-reuse deve prevalere sul grafo aggiornato).
- Una **seconda** `apply(plan:)` con identico piano su DB già mutato deve concludere con **`previewStale`** **oppure** **`noApplicableChanges`**, a seconda della **policy scelta e documentata in EXECUTION** (es. stale se i fingerprint locali non coincidono più con il piano; no-op se il piano è ancora «valido» ma senza delta applicabile — decidere un solo comportamento canonico per slice 1).
- Test pianificato dedicato: **`samePlanSecondApplyDoesNotDuplicateAndDoesNotMutate`** (vedi elenco XCTest).

### Errore durante save SwiftData
- Se **`context.save()`** fallisce: **mai** mostrare messaggio di **successo** (né conteggi «applicati»).
- UI: errore **localizzato**, con suggerimento di **rigenerare la preview** e/o **verificare il database locale**; nessun copy che implichi sync cloud o Supabase aggiornato.
- TASK-039 slice 1: **nessun «successo parziale»** narrativo — o save OK con metriche finali coerenti, o fallimento chiaro.
- Recovery avanzato (rollback granulare, ripresa transazione): **follow-up**, fuori slice minima.

### Evidence checklist futura per Execution
Quando TASK-039 passerà formalmente ad **EXECUTION**, il responsabile execution deve **documentare nel file task** (sezione Execution / handoff) le evidenze minime:
- Build **Debug** e **Release** (esito).
- **`xcodebuild test`** / XCTest inclusi **apply** (esito).
- Scenario **preview partial**: apply **disabilitato** + footer motivo (tipo verifica STATIC/UI breve descritta).
- Scenario **fixture / preview completa**: apply locale riuscito (cosa è stato mutato in SwiftData).
- Scenario **preview stale**: blocco + UX «Rigenera preview».
- Verifica **manuale** che **Supabase non riceva scritture** (dashboard / osservazione progetto / second device — descritta sinteticamente, senza inventare PASS).
- **Screenshot**: solo **se** necessario per review UX (non obbligatorio di default).

### Handoff finale planning (questo turno)
- **Stato**: resta **ACTIVE / PLANNING**.
- **Nessuna EXECUTION** autorizzata senza **approvazione esplicita utente** sul planning e aggiornamento handoff → EXECUTION nel file task.
- **Nessuna approvazione implicita** al passaggio EXECUTION (silenzio assenso / merge da solo ≠ OK).
- **Nessun codice Swift** modificato in questo prompt (solo refinement documentale TASK-039).

---

## Execution (Codex) ← solo Codex aggiorna questa sezione
### Avvio EXECUTION — 2026-05-05
- User override esplicito ricevuto per avviare EXECUTION di TASK-039 seguendo il planning già approvato.
- Obiettivo compreso: applicare localmente in SwiftData solo preview Supabase complete/sicure, con piano puro, apply no-network, nessuna scrittura Supabase, nessun delete locale da tombstone e nessun import remoto di `ProductPrice`.
- File letti prima di modificare: `docs/MASTER-PLAN.md`, questo file task, `SupabasePullPreviewModels.swift`, `SupabasePullPreviewService.swift`, `SwiftDataInventorySnapshotService.swift`, `OptionsView.swift`, `Models.swift`, `iOSMerchandiseControlApp.swift`, `SupabaseInventoryDTOs.swift`, `SupabaseInventoryService.swift`, `ContentView.swift`, localizzazioni IT/EN/ZH-Hans, test esistenti in `iOSMerchandiseControlTests`.
- File previsti in modifica: `SupabasePullPreviewModels.swift`, `SupabasePullPreviewService.swift`, nuovo `SupabasePullApplyService.swift`, `OptionsView.swift`, localizzazioni IT/EN/ZH-Hans, nuovo XCTest apply, tracking task/master. `Models.swift` resta fuori dalle modifiche salvo necessità reale.
- Piano minimo di intervento: aggiungere payload applicabile alla preview usando i dati già presenti in `RemoteInventoryProductRow`; introdurre servizio apply con `prepareApplyPlan` puro e `apply(plan:)` no-network con stale guard immediata e un solo `context.save()` nel percorso felice; integrare UI DEBUG nativa nella sheet; aggiungere test in-memory; eseguire build/test disponibili.
- Decisione implementativa iniziale: idempotenza canonica = una seconda `apply(plan:)` dello stesso piano dopo un primo apply riuscito deve fallire con `previewStale`, senza duplicare supplier/category e senza mutare ulteriormente prodotti.

### Execution completata — 2026-05-05

#### File modificati
- `iOSMerchandiseControl/SupabasePullPreviewModels.swift`
- `iOSMerchandiseControl/SupabasePullPreviewService.swift`
- `iOSMerchandiseControl/SupabasePullApplyService.swift` (nuovo)
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/SwiftDataInventorySnapshotService.swift`
- `iOSMerchandiseControl/it.lproj/Localizable.strings`
- `iOSMerchandiseControl/en.lproj/Localizable.strings`
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`
- `iOSMerchandiseControlTests/SupabasePullApplyServiceTests.swift` (nuovo)
- `docs/TASKS/TASK-039-supabase-preview-apply-locale-controllato-swiftdata.md`
- `docs/MASTER-PLAN.md`

#### Modifiche implementate
- Aggiunto `SyncPreviewProductApplyPayload` con payload applicabile completo per prodotti nuovi/update, generato durante preview da `RemoteInventoryProductRow` e snapshot remoto già in memoria. `remoteDisplay` resta solo diagnostica/UI, non fonte canonica di apply.
- Aggiunto `SupabasePullApplyService` stateless con `prepareApplyPlan(preview:context:options:isAuthenticated:)` e `apply(plan:context:)`.
- `prepareApplyPlan` resta read-only: usa `ModelContext` solo per snapshot locale, non inserisce/modifica/elimina e non chiama `context.save()`.
- `apply(plan:)` esegue subito stale guard su snapshot locale fresco; se la preview è stale non muta niente. Nel percorso felice prepara lookup deterministici, applica insert/update locali SwiftData e fa un solo `try context.save()`.
- Implementati blocchi richiesti: `sessionMissing`, `partialPreview`, `sourceErrorsPresent`, `priceHistoryIncomplete`, `conflictsPresent`, `localDuplicateBarcode`, `missingApplicablePayload`, `missingRequiredField`, `invalidPrice`, `invalidStockQuantity`, `previewStale`, `noApplicableChanges`.
- Implementate policy campo: barcode obbligatorio per insert e mai aggiornato su Product esistente; stringhe remote nil/vuote non cancellano il locale; nuovo Product richiede `productName` o `secondProductName`; prezzi finiti/non negativi con tolleranza 0.001; stock applicato solo con `applyStockQuantity == true`; supplier/category create-or-reuse via `normalizedLookupName`.
- Nessun delete locale da `remoteTombstones`, nessun import remoto di `ProductPrice`, nessuna scrittura Supabase, nessun sync automatico/background/realtime, nessuna auth nuova, nessuna modifica schema Supabase.
- UI DEBUG in `OptionsView`/preview sheet: pulsante localizzato "Applica al database locale", footer con motivo disabilitazione, `confirmationDialog`, `isApplyingLocalPreview`, `ProgressView`, blocco doppio tap, successo solo post-save, errore localizzato con invito a rigenerare preview/verificare DB locale.
- Localizzazioni nuove aggiunte in IT/EN/ZH-Hans con prefisso `options.supabase...`.

#### Decisioni implementative
- Idempotenza canonica scelta: una seconda `apply(plan:)` dello stesso piano dopo un primo apply riuscito fallisce con `previewStale`. Questo evita no-op ambigui su piani già consumati e protegge da riuso involontario della preview; test dedicato verifica che non duplichi supplier/category e non muti prodotti.
- `SupabasePullApplyService` è una `struct` stateless `@MainActor`, non una classe: il servizio non mantiene stato, non espone dipendenze rete, e la forma value-type evita deinit/ARC non necessari nel runner XCTest.
- `SwiftDataInventorySnapshotService` è stato reso `struct` stateless per lo stesso motivo: è solo un wrapper read-only del `ModelContext`; nessuna API pubblica o schema dati è cambiato.
- Nei test SwiftData in-memory i container/context sono trattenuti staticamente per la durata del processo test, per evitare crash di teardown SwiftData osservati nel runner; non impatta runtime app.

#### Test e build eseguiti
- ✅ ESEGUITO — Build Debug: `xcodebuild build -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'` → **PASS / BUILD SUCCEEDED**.
- ✅ ESEGUITO — Build Release: `xcodebuild build -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Release -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'` → **PASS / BUILD SUCCEEDED**.
- ✅ ESEGUITO — XCTest: `xcrun simctl shutdown all && xcodebuild test -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' -parallel-testing-enabled NO` → **PASS / 37 test**, inclusi 18 nuovi `SupabasePullApplyServiceTests`.
- ✅ ESEGUITO — Localizzazioni: `plutil -lint` su IT/EN/ZH-Hans → **OK**.
- ✅ ESEGUITO — Diff hygiene: `git diff --check` → **PASS**.
- ✅ ESEGUITO — Verifica statica no-network apply: grep su `SupabasePullApplyService.swift`/test per `SupabaseInventoryService`, `SupabaseClientProvider`, `SupabaseClient`, `.from(`, `upsert`, `rpc`, remote `delete/update` → nessuna occorrenza.
- ✅ ESEGUITO — Verifica statica no `ProductPrice` apply: grep `ProductPrice(` nel servizio apply → nessuna occorrenza.
- ✅ ESEGUITO — Verifica copy vietato: grep app/test per "sync cloud completata", "Supabase aggiornato", "cloud completato", "cloud completata", "sync cloud" → nessuna occorrenza.
- ⚠️ NON ESEGUIBILE — "Nessun warning nuovo introdotto" non dimostrabile al 100% senza baseline warning precedente; nelle build non risultano warning Swift dai file modificati. Resta il warning toolchain AppIntents "Metadata extraction skipped" già non riconducibile al codice TASK-039.
- ❌ NON ESEGUITO — Verifica manuale live su dashboard Supabase/second device: non eseguita perché l'apply implementato è locale e non ho eseguito uno scenario live con backend/dashboard. Coperta staticamente dall'assenza di dipendenze Supabase nel servizio apply.

#### Criteri / evidenze principali
- ✅ STATIC/XCTest — Preview partial bloccata: `testPrepareApplyPlanBlocksPartialPreview`.
- ✅ STATIC/XCTest — `sourceErrors` bloccati: `testPrepareApplyPlanBlocksSourceErrors`.
- ✅ STATIC/XCTest — `priceHistoryIncomplete` bloccato: `testPrepareApplyPlanBlocksPriceHistoryIncomplete`.
- ✅ STATIC/XCTest — conflitti/sessione mancante/payload mancante/campi richiesti/prezzi invalidi/stock negativo coperti dai test apply.
- ✅ STATIC/XCTest — preview stale blocca prima delle mutazioni: `testApplyFailsPreviewStaleIfLocalDatabaseChangesBetweenPrepareAndApply`.
- ✅ STATIC/XCTest — barcode esistente non cambia, nil/vuoto remoto non cancella locale, stock ignorato di default, supplier/category reuse case-insensitive, nessun `ProductPrice`, seconda apply stesso piano = `previewStale`.
- ✅ BUILD/STATIC — UI DEBUG compila con pulsante, dialog, stato applying, footer disabilitazione e copy localizzato.

#### Rischi residui / follow-up candidate
- Scenario manuale Simulator/UI non eseguito: la copertura UI è build/static, non screenshot/runtime.
- Verifica manuale dashboard Supabase non eseguita; il guardrail no-write è verificato staticamente dal design no-network dell'apply service.
- Su dataset molto grandi, `prepareApplyPlan`/footer UI ricostruiscono snapshot locali in DEBUG: accettabile per slice 1, ma possibile follow-up se emergono latenze.
- Collisioni SwiftData `@Attribute(.unique)` su supplier/category dopo fetch-before-insert sono wrappate in `saveFailed`; recovery granulare resta follow-up.
- Fetch completo/paginazione senza cap per consentire apply su preview oggi `partial` resta follow-up fuori scope.

#### Handoff post-execution — verso REVIEW
- Stato task: **ACTIVE**.
- Fase aggiornata a: **REVIEW**.
- Responsabile attuale: **Claude / Reviewer**.
- Ultimo agente che ha operato: **Cursor / Executor**.
- Handoff: implementazione TASK-039 completata secondo planning approvato; build Debug, build Release e XCTest principali passano; limiti manuali documentati sopra. TASK-039 **non** è marcato DONE.

---

## Review (Claude) ← solo Claude aggiorna questa sezione
### Review finale + fix diretto — 2026-05-05

#### File controllati
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-039-supabase-preview-apply-locale-controllato-swiftdata.md`
- `iOSMerchandiseControl/SupabasePullApplyService.swift`
- `iOSMerchandiseControl/SupabasePullPreviewModels.swift`
- `iOSMerchandiseControl/SupabasePullPreviewService.swift`
- `iOSMerchandiseControl/SwiftDataInventorySnapshotService.swift`
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/Models.swift`
- `iOSMerchandiseControl/iOSMerchandiseControlApp.swift`
- `iOSMerchandiseControl/SupabaseInventoryService.swift`
- `iOSMerchandiseControl/SupabaseInventoryDTOs.swift`
- `iOSMerchandiseControl/it.lproj/Localizable.strings`
- `iOSMerchandiseControl/en.lproj/Localizable.strings`
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`
- `iOSMerchandiseControl/es.lproj/Localizable.strings`
- `iOSMerchandiseControlTests/SupabasePullApplyServiceTests.swift`
- `iOSMerchandiseControlTests/SupabasePullPreviewDiffEngineTests.swift`
- `iOSMerchandiseControl.xcodeproj/project.pbxproj`

#### Problemi trovati
- **P1 fixed directly** — `SupabasePullPreviewDiffEngine` generava conflitti `missingRemoteSupplier` / `missingRemoteCategory` solo dopo aver identificato un prodotto locale esistente. Di conseguenza un **new product** con `supplierID` o `categoryID` remoto non risolvibile, quando il fetch supplier/category non era fallito, poteva entrare in `newProducts` con payload senza relazione invece di bloccare l'apply tramite `conflictsPresent`.
- **P3 fixed directly** — le nuove chiavi apply erano complete per IT/EN/ZH-Hans, ma mancavano in `es.lproj`; l'app supporta Español e avrebbe mostrato fallback italiano per quel blocco UI.

#### Fix applicati
- Spostato il controllo dei lookup remoti non risolti prima della classificazione new/update e introdotto helper `unresolvedLookupConflicts(...)`, così supplier/category mancanti bloccano sia new sia update quando il fetch catalogo è affidabile.
- Aggiunto XCTest `testNewProductWithMissingRemoteSupplierOrCategoryIsConflictAndNotNewProduct`.
- Aggiunte le 23 stringhe apply anche in `es.lproj/Localizable.strings`, mantenendo il copy solo-locale / no Supabase write / no delete.

#### Verifiche no Supabase write / no ProductPrice
- ✅ STATIC — `SupabasePullApplyService.swift` non importa Supabase e non contiene `SupabaseInventoryService`, `SupabaseClientProvider`, `SupabaseClient`, `.from(`, `upsert`, `rpc`, `.update(` o `.delete(`.
- ✅ STATIC — `SupabasePullApplyService.swift` contiene un solo `try context.save()` e nessuna costruzione `ProductPrice(`.
- ✅ STATIC — nessun delete locale da `remoteTombstones`; il servizio apply consuma solo `newProducts` e `updateCandidates`.
- ✅ STATIC — nessun copy vietato: grep su "sync cloud completata", "Supabase aggiornato", "cloud completato", "cloud completata", "sync cloud" senza occorrenze.

#### Risultati build/test
- ✅ ESEGUITO — `git diff --check` → PASS.
- ✅ ESEGUITO — `plutil -lint` su IT/EN/ZH-Hans/ES `Localizable.strings` → OK.
- ✅ ESEGUITO — parità chiavi localizzazione IT/EN/ZH-Hans/ES → OK.
- ✅ ESEGUITO — test mirati apply/preview: `xcodebuild test ... -only-testing:SupabasePullPreviewDiffEngineTests -only-testing:SupabasePullApplyServiceTests -parallel-testing-enabled NO` → PASS, 28/28.
- ✅ ESEGUITO — Build Debug: `xcodebuild build -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'` → PASS / BUILD SUCCEEDED.
- ✅ ESEGUITO — Build Release: `xcodebuild build -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Release -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'` → PASS / BUILD SUCCEEDED.
- ✅ ESEGUITO — XCTest completo: `xcodebuild test -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' -parallel-testing-enabled NO` → PASS / 38 test.
- ⚠️ NON ESEGUIBILE — garanzia assoluta "nessun warning nuovo" senza baseline storica; le build mostrano solo warning toolchain AppIntents "Metadata extraction skipped. No AppIntents.framework dependency found", non riconducibile ai file TASK-039.
- ⚠️ NON ESEGUIBILE — verifica dashboard/second device Supabase: non eseguita perché il path apply è locale/no-network e non è stato lanciato scenario live con backend; coperta staticamente dall'assenza di dipendenze Supabase nel servizio apply.

#### Giudizio finale
- **APPROVED_FIXED_DIRECTLY / DONE**. Dopo i fix mirati, TASK-039 rispetta il planning: apply solo locale SwiftData, guardrail conservativi, stale guard prima delle mutazioni, un solo save nel percorso felice, nessuna scrittura remota, nessun `ProductPrice` remoto, nessun delete da tombstone, UI/copy/localizzazioni coerenti. L'utente ha autorizzato esplicitamente la chiusura DONE in questo turno; TASK-038 resta DONE.

---

## Fix (Codex) ← solo Codex aggiorna questa sezione
### Fix diretto durante REVIEW — 2026-05-05
- Corretto `SupabasePullPreviewService.swift`: i conflitti `missingRemoteSupplier` / `missingRemoteCategory` vengono ora calcolati per ogni prodotto attivo prima della separazione tra `newProducts` e `updateCandidates`.
- Aggiunto test in `SupabasePullPreviewDiffEngineTests.swift` per garantire che un new product con supplier/category remoto non risolvibile sia classificato come conflitto e non come prodotto applicabile.
- Aggiunte localizzazioni ES mancanti per il blocco apply locale.
- Verifiche post-fix: test mirati PASS 28/28; build Debug PASS; build Release PASS; XCTest completo PASS 38/38; localizzazioni lint/parity OK.

---

## Chiusura
- **Stato finale**: DONE.
- **Chiusura**: TASK-039 chiuso con esito **APPROVED_FIXED_DIRECTLY** su istruzione esplicita dell'utente. L'apply resta locale SwiftData, bloccato su preview non sicure, senza write Supabase, senza delete locale da tombstone e senza import remoto `ProductPrice`.
- **Follow-up candidate fuori scope**: fetch completo/paginazione senza cap per cataloghi grandi; bridge `remoteId`; push manuale tombstone-compliant; sync avanzata con resolver/background/realtime/watermark.
