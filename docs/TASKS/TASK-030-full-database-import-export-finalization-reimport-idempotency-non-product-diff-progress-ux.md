# TASK-030: Full-database import/export finalization — reimport idempotency + non-product diff + progress UX

## Informazioni generali
- **Task ID**: TASK-030
- **Titolo**: Full-database import/export finalization: reimport idempotency + non-product diff + progress UX
- **File task**: `docs/TASKS/TASK-030-full-database-import-export-finalization-reimport-idempotency-non-product-diff-progress-ux.md`
- **Stato**: DONE
- **Fase attuale**: Chiusura — VALIDATED_BY_LATER_ACCEPTANCE
- **Responsabile attuale**: Nessuno / Chiuso
- **Data creazione**: 2026-04-26
- **Ultimo aggiornamento**: 2026-05-12 19:18 -0400 — chiusura legacy VALIDATED_BY_LATER_ACCEPTANCE; vedi `docs/TASKS/EVIDENCE/LEGACY-CLOSURE-2026-05-12.md`
- **Ultimo agente che ha operato**: Codex / Reviewer

> **Chiusura legacy 2026-05-12:** il precedente stato `BLOCKED`/sospeso e' superato dall'override utente e dalla matrice `docs/TASKS/EVIDENCE/LEGACY-CLOSURE-2026-05-12.md`. Le sezioni storiche sottostanti restano archivio, ma la fonte di verita' corrente per il tracking e' questo header: `DONE / Chiusura — VALIDATED_BY_LATER_ACCEPTANCE`.

## Dipendenze
- **Dipende da**: TASK-023, TASK-024
- **Sblocca**: chiusura del flusso full database import/export multi-sheet prima di Supabase

## Scopo
TASK-006 è implementato ma dipende dai follow-up TASK-023 e TASK-024. La completezza iOS richiede chiudere il flusso full database import/export multi-sheet prima di Supabase.

## Contesto
TASK-023 e TASK-024 sono sospesi con validazioni/finalizzazioni residue. Questo task serve a riprendere il percorso in modo controllato, decidendo se mantenerlo come task operativo unico o dividerlo se il perimetro risulta troppo grande.

## Non incluso
- Supabase
- Refactor ampi non necessari della pipeline
- Nuove dipendenze
- Modifiche fuori dal percorso full database import/export

## Scope
- Riprendere TASK-023 e TASK-024
- Validare reimport idempotente
- Validare diff Suppliers/Categories/PriceHistory
- Finalizzare progress UX e cancellation
- Nessun Supabase

## Output richiesto
- Task operativo unico o split controllato se troppo grande
- Test manuali mirati
- Eventuali fix minimi

## Criteri di accettazione
- [ ] Il percorso reimport idempotente viene validato o vengono definiti fix minimi tracciati
- [ ] I diff non-product sono verificati per Suppliers/Categories/PriceHistory
- [ ] Progress UX e cancellation hanno esito chiaro e documentato
- [ ] Nessun lavoro Supabase viene introdotto nel task

## Planning (Claude) ← solo Claude aggiorna questa sezione

*Planning iniziale operativo (2026-04-26). Il task resta **TODO/backlog** finche' l'utente non lo promuove ad **ACTIVE**; questo blocco definisce solo il perimetro e i passi successivi.*

Promosso ad ACTIVE / EXECUTION su richiesta esplicita dell’utente. Il Planning resta valido come contratto operativo della fase Execution.

### Stato iniziale rilevato

- **TASK-030**: `TODO`, fase —, nessun agente operativo (coerente con MASTER-PLAN **IDLE**).
- **TASK-023** (`docs/TASKS/TASK-023-…md`): **leggibile**. Stato **BLOCKED**, fase REVIEW **sospesa**. La review codice Claude (2026-03-23) risulta **APPROVED** con rischio residuo: **test manuali TM-1, TM-2, TM-4, TM-5, TM-7, TM-8** (e sottoinsieme checklist post-execution) **non conclusi**; sospensione esplicita per override utente (2026-03-24).
- **TASK-024** (`docs/TASKS/TASK-024-…md`): **leggibile**. Stato **BLOCKED**; execution + fix (Codex/Claude) documentati; sezione **Review (Claude)** ancora da compilare; **TM-1…TM-18** in gran parte **non eseguiti** in sessione agent.
- **Codice iOS (verifica read-only 2026-04-26)**: il flusso full-database e' concentrato in `iOSMerchandiseControl/DatabaseView.swift` (enum `DatabaseImportPipeline`, `prepareFullDatabaseImport`, `applyImportAnalysisInBackground`, `importFullDatabaseFromExcel`, stati progress/cancel, `FullImportResultPayload`, `hasWorkToApply`, `PriceHistoryFingerprint`, `classifyParsedPriceHistoryForFullImport`, `makeFullDatabaseXLSX`, ecc.) e `iOSMerchandiseControl/ImportAnalysisView.swift` (`ImportAnalysisSession`, `NonProductDeltaSummary`, summary UI, apply overlay). **Non esiste** un tipo `DatabaseViewModel` nel repo: la "view model" de facto e' `DatabaseView` + tipi privati nel medesimo file.

### File iOS principali da ispezionare / eventualmente modificare (in execution)

| Area | File | Nota |
|------|------|------|
| Export multi-sheet | `DatabaseView.swift` | `makeFullDatabaseXLSX()` |
| Import multi-sheet + pipeline | `DatabaseView.swift` | `DatabaseImportPipeline`, prepare/apply, payload, logging |
| Analisi / delta non-product | `ImportAnalysisView.swift`, `DatabaseView.swift` | `NonProductDeltaSummary`, `ImportAnalysisSession.refreshNonProductSummary` |
| Lettura XLSX per nome foglio | `ExcelSessionViewModel.swift` | `ExcelAnalyzer` (se servisse verificare parity export/import) |
| Import prodotto "semplice" | `ProductImportViewModel.swift`, `DatabaseView.swift` | Regressione scope: path non-full |
| Stringhe | `*.lproj/Localizable.strings` | Solo se fix copy minimi |

### Riepilogo: cosa resta da validare rispetto a TASK-023 e TASK-024

**Da TASK-023 (dati / idempotenza / trasparenza non-product)** — implementazione dichiarata in Execution; **conferma runtime** ancora aperta:

- Reimport dello **stesso** file full-database: **nessun** nuovo `ProductPrice` atteso; `hasWorkToApply` **false**; Apply disabilitato (allineamento UI + `makeImportApplyPayload`).
- **Primo import** su DB vuoto / file modificato: coerenza conteggi PH (`inserted` / `alreadyPresent` / `unresolved`) tra summary, log e DB.
- **Supplier/Category**: nessuna persistenza in fase prepare; annullamento dopo analisi senza effetti (TM-4).
- **Dedup intra-file** PriceHistory (TM-8); **normalizzazione nomi** fornitore/categoria (CA-9).
- Eventuale edge: prodotto eliminato tra prepare e apply (safety net in apply PH — da smoke se rilevante).

**Da TASK-024 (progress / cancel / esito UX)** — implementazione dichiarata; **conferma runtime** ancora aperta:

- **Cancel** solo su prepare/analyze full-database: nessuna apertura sheet tardiva (run ID / token), esito **annullato** distinto da errore, overlay ripulito, retry pulito (TM-1, TM-2, TM-9, TM-12, TM-13).
- **Apply**: nessun cancel ingannevole; progresso primario su tab Database; sequenza **progresso chiuso → dismiss sheet analisi → result surface** senza doppio canale legacy sul full flow (TM-5, TM-6, TM-14–TM-18).
- **Import non-full** (CSV / Excel semplice): baseline invariata, nessun cancel indesiderato (TM-11, CA-5 TASK-024).
- Limite noto documentato: copia file in temp **prima** del `Task` async resta non interrompibile dal cancel — da accettare o registrare come limite accettato.

### Ipotesi sul perimetro (TASK-030)

- **Obiettivo**: "finalizzare" il percorso **full-database import/export multi-sheet** = **validazione incrociata** dei risultati sospesi di TASK-023 e TASK-024 + **fix minimi** solo se i criteri di accettazione di TASK-030 o dei CA ereditati risultano violati in prova.
- **Export**: TASK-006/TASK-023 assumono export stabile; TASK-030 verifica **round-trip** (export → reimport) come prova principale di coerenza, senza ridisegnare il formato file.
- **Android**: solo confronto funzionale ad alto livello se serve chiarire un dubbio; **nessun porting di codice**.

### Decisione preliminare: task unico vs split controllato

- **Raccomandazione**: mantenere **TASK-030 come task operativo unico** con due tracciati interni chiaramente nominati (**tracciato A — TASK-023**, **tracciato B — TASK-024**), stessa build, stessa sessione di test sul Simulator.
- **Split controllato** (es. TASK-030a solo dati, TASK-030b solo UX) **solo se** emerge lavoro di fix **> piccole modifiche localizzate** o conflitto di priorita' tra i due tracciati: in quel caso documentare nel file task la scissione prima di eseguire.

### Passi operativi proposti (ordine)

1. **Promozione workflow**: quando l'utente attiva TASK-030, allineare MASTER-PLAN (ACTIVE, fase PLANNING → EXECUTION dopo handoff) e impostare responsabile **CODEX** per execution.
2. **Baseline tecnica**: build Debug Simulator; nota eventuali warning (senza baseline storica formale, registrare solo se nuovi rispetto a memoria di sessione).
3. **Matrice di test**: eseguire in ordine **smoke** poi **stress** — derivare da TASK-023 (TM-1, TM-2, TM-4, TM-5, TM-7, TM-8 minimo) e da TASK-024 (TM-1, TM-2, TM-5, TM-9, TM-11–TM-14, TM-16, TM-18 minimo; ampliare se tempo).
4. **Registro esiti**: per ogni riga: scenario, atteso (dal task sorgente), esito PASS/FAIL, note (log, screenshot opzionale).
5. **Fix**: solo se FAIL su criteri TASK-030 o CA ereditati; patch **minime** nei file tabellati sopra; niente refactor della pipeline oltre il necessario.
6. **Chiusura tracciati**: aggiornare (con override utente se serve) TASK-023 / TASK-024 solo a livello **documentale** — es. "validazione TASK-030 conferma …" — **senza** riaprire DONE fantasma; oppure lasciare BLOCKED con nota "chiuso via TASK-030" a cura del planner utente.

### Test manuali mirati (sottoinsieme minimo consigliato)

| ID | Origine | Focus |
|----|---------|--------|
| M-1 | TASK-023 TM-1 | Primo full import su DB vuoto |
| M-2 | TASK-023 TM-2 | Reimport stesso file → no work, no insert PH |
| M-3 | TASK-023 TM-4 | Annulla dopo analisi → nessuna entita' creata |
| M-4 | TASK-023 TM-5 | Import prodotto semplice invariato |
| M-5 | TASK-023 TM-7 / TM-8 | Solo delta S/C; dedup PH intra-file |
| M-6 | TASK-024 TM-1 / TM-2 | Cancel prepare/analyze |
| M-7 | TASK-024 TM-5 / TM-14 | Apply completo + result surface + metriche |
| M-8 | TASK-024 TM-11 | CSV/Excel semplice vs full (no regressione cancel) |
| M-9 | TASK-024 TM-12 / TM-13 | Race cancel vs completamento / retry |
| M-10 | TASK-024 TM-16 / TM-18 | Esito annullato; unica result surface full |

### Rischi principali

- **Apply non atomico**: save a batch — gia' noto; nessuna promessa di rollback se si forzasse interruzione (fuori scope se non si espone cancel in apply).
- **Volumi PriceHistory**: fetch O(n) in prepare — accettabile per ~35k; regressioni memoria/tempo su dataset estremi.
- **Disallineamento documentazione**: TASK-023/TASK-024 in BLOCKED con review incompleta — il registro test di TASK-030 diventa la fonte operativa finche' non si aggiornano gli stati dei task predecessori.
- **Doppio feedback o stale UI**: regressione possibile se si tocca ordine dismiss/result senza test.

### Criteri di stop

- Interrompere execution e tornare a **PLANNING/REVIEW** se: serve **refactor strutturale** della pipeline; emergono requisiti **Supabase** o nuove dipendenze; i fix superano il modello "minimi e localizzati".
- Non dichiarare TASK-030 soddisfatto senza aver **esplicitamente** verificato (o documentato come ⚠️ non eseguibile con motivo) gli elementi dei **criteri di accettazione** nella sezione superiore del file.

### Cosa NON verra' fatto (perimetro esplicito)

- **Nessun Supabase** (client, schema sync, pull/push, ecc.).
- **Nessun refactor ampio** di `DatabaseImportPipeline`, `ExcelAnalyzer`, o split file obbligatorio.
- **Nessuna nuova dipendenza** SPM/CocoaPods.
- **Nessuna modifica** al perimetro "full database" oltre validazione + fix mirati per chiudere i sospesi TASK-023/TASK-024.
- **Nessuna riapertura** di task **DONE** archiviati per riusare lo stesso ID.

### Addendum di Planning richiesto dall'utente — UX, invarianti, fixture, evidenze

*Integrazione 2026-04-26. Precisioni operative per l'execution futura; **nessun** avvio execution da questo addendum.*

#### 1. Decisioni UX/UI

- Modifiche UI/UX **solo** se aumentano chiarezza e coerenza con SwiftUI nativo (NavigationStack, sheet, List/Form, toolbar, `ProgressView`, componenti di sistema).
- Quando **non** c'e' lavoro reale da applicare, la schermata di analisi deve comunicarlo in modo esplicito — es. messaggio del tipo **«nessuna modifica da importare»** (o equivalente **localizzato** in tutte le lingue attive). Se oggi manca copy dedicata, l'execution aggiunge la chiave minima senza redesign.
- Il bottone **Apply** in `ImportAnalysisView` (`.disabled(... !hasWorkToApply())`) deve restare allineato alla semantica **reale** del payload:
  - Apply **disabilitato** solo se non esiste davvero lavoro: nessun nuovo prodotto, nessun prodotto aggiornato, nessun Supplier da creare, nessuna Category da creare, nessuna riga PriceHistory da inserire (coerente con `DatabaseView.hasWorkToApply(session:pendingFullImportContext:)` e `PendingFullImportContext.hasWorkToApply`).
- Se esistono **solo** delta non-product (es. solo Suppliers/Categories/PriceHistory da inserire), **Apply deve restare abilitato** — gia' richiesto dal design TASK-023; validare in prova.
- **Cancel** cooperativo: solo durante **prepare/analyze** del full-database, governato da `DatabaseImportProgressState` / `canCancelPreparation` (non basarsi su stringhe di fase). Import non-full non devono ereditare per errore l'affordance di cancel TASK-024.
- Durante **Apply** non esporre cancel «sicuro» o ingannevole (comportamento atteso: apply senza interruzione cooperativa documentata).
- Dopo Apply sul flusso full: **una sola** result surface per esito — oggi implementata come `.sheet(item: $fullImportResultPayload)` + `FullImportResultView` / `FullImportResultPayload` (`DatabaseView.swift`). Evitare doppio snackbar/dialog/alert nativo **per lo stesso** esito sullo stesso percorso.
- La result surface deve distinguere chiaramente almeno: **successo completo**, **successo parziale** (es. prodotti applicati ma errore/note su PriceHistory — verificare mapping su `kind` + `summary`/`notes` esistenti), **errore**, **annullato** (`FullImportResultKind`: success / error / cancelled).
- Eventuali ritocchi restano nello stile corrente dell'app (materiali, sheet, gerarchia tipografica gia' usata nelle card overlay/sheet).

#### 2. Invarianti dati da verificare

- Reimport dello **stesso** file prodotto da **full database export** non deve creare **nuovi** `ProductPrice` (zero insert netti attesi; conteggio `alreadyPresent` coerente).
- Reimport identico: `hasWorkToApply` **false** se assenti product diff **e** assenti pending Supplier/Category **e** assenti PriceHistory da inserire (allineamento bottone Apply + `makeImportApplyPayload`).
- Fase **prepare/analyze**: nessun `save()` che persista `Product`, `Supplier`, `ProductCategory` o `ProductPrice` prima della conferma utente (baseline TASK-023; re-verificare dopo ogni fix).
- Supplier/Category: normalizzazione **deterministica** condivisa (`normalizedImportNamedEntityName` e affini in `DatabaseView.swift`) — nessun duplicato «banale» per spazi; verificare policy **case** rispetto al DB esistente.
- PriceHistory: dedup **deterministico** in prepare (`PriceHistoryFingerprint` / `classifyParsedPriceHistoryForFullImport`) — barcode, `PriceType`, timestamp normalizzato (epoch secondi), prezzo scalato (`priceFixed4`), `source` normalizzato/canonicizzato come nel codice.
- Allineamento **UI ↔ log ↔ DB** dopo apply (ove applicabile): `productsInserted`, `productsUpdated`, `suppliersCreated`, `categoriesCreated`, `priceHistoryInserted`, conteggi `alreadyPresent` / `unresolved` (terminologia unificata `ImportApplyResult` / summary / log strutturati).
- **Prodotto eliminato tra prepare e apply**: comportamento atteso = sicuro (nessun crash / stato incoerente); documentare in execution esito **PASS** con nota o **FAIL**/limite accettato con riferimento al safety net in `applyPendingPriceHistoryImport` (o equivalente).

#### 3. Fixture / file di test consigliati (strategia deterministica)

*Non creare ora questi file in repo se serve tooling o export manuale: l'**execution** li genera o li allega come artefatti di prova.*

| ID | Descrizione | Scopo |
|----|-------------|--------|
| **Fixture A** | Export full-database da **DB seed pulito** (stesso schema fogli: Products, Suppliers, Categories, PriceHistory). | Baseline primo import / conteggi noti. |
| **Fixture B** | Copia bit-identica o re-export identico di A. | Idempotenza reimport; `hasWorkToApply` false; zero insert PH. |
| **Fixture C** | Variante con **solo** nuovi Suppliers/Categories (nessun delta prodotto rilevante), stesso workbook multi-sheet. | Apply abilitato solo su non-product; nessuna regressione bottone. |
| **Fixture D** | Stesso barcode PriceHistory ripetuto nello stesso foglio (stessa fingerprint). | Dedup intra-file; un solo insert effettivo. |
| **Fixture E** | Righe PriceHistory con barcode **inesistenti** nel file Products. | Bucket `unresolved`; coerenza UI e log. |
| **Fixture F** (opz.) | Stesso scenario di A/B ma con passo manuale: eliminare un `Product` tra prepare e apply. | Edge concurrency documentato (§2 ultimo bullet). |

#### 4. Evidence checklist (obbligatoria in execution per ogni scenario test)

Per ogni riga di matrice (M-1…M-10 o estensioni), registrare:

- **Scenario** (ID + breve nome)
- **File usato** (fixture o path noto)
- **Stato DB prima**: conteggi `Product` / `Supplier` / `ProductCategory` / `ProductPrice` (e note su seed)
- **Stato DB dopo** gli stessi conteggi
- **UI**: valori mostrati in `summarySection` / `NonProductDeltaSummary` (se full import) e payload **result surface** (`FullImportResultPayload`: titolo, summary, metriche, notes)
- **Log** rilevanti (console / tag apply prepare) — in particolare righe price history e apply result se presenti
- **Esito** PASS / FAIL
- **Screenshot** solo se utile per UX (progress overlay, cancel, sheet result, stati ambigui)

#### 5. Efficienza e limiti

- Vietato introdurre **parsing doppio** o letture Excel/DB ripetute **non necessarie**; eventuali fix non devono peggiorare complessita' senza motivazione nel task.
- **No** refactor strutturale «per pulizia»; **no** spostamento di logica tra file salvo stretta necessita' dimostrata da FAIL.
- Fix ammessi: **piccoli e localizzati** (`DatabaseView.swift`, `ImportAnalysisView.swift`, stringhe `.lproj` correlate).
- Se un problema richiede **cambio architetturale** (es. pipeline nuova, atomicita' transazionale globale): **fermarsi**, documentare nel task (Planning/Decisioni o nota execution) e aprire **follow-up** separato — **non** allargare TASK-030.
- Dataset molto grandi: se emergono limiti memoria/tempo, **documentare** soglia osservata e proporre follow-up dedicato (fuori perimetro TASK-030 salvo fix minimi O(n) gia' previsti).

#### 6. Decisione operativa (chiusura addendum)

- **TASK-030 resta task unico** per validazione + fix mirati sui sospesi TASK-023 / TASK-024.
- **Nessuno split** per ora; split **solo** se compaiono fix strutturali o regressioni ampie che superano il modello «minimi e localizzati» (allora rivalutare backlog con planner).
- In caso di dubbio UX: decisione in execution/review affidata all'agente, con priorita' a **chiarezza**, **sicurezza dei dati** e **coerenza SwiftUI nativa**.

### Micro-addendum finale — priorità, ready check e contratto UX no-work

*Rifinitura documentale (2026-04-26). Non sostituisce l'addendum precedente; lo integra prima della futura Execution.*

#### 1. Priorità decisionale in caso di conflitto

Durante la futura Execution, se emerge una scelta ambigua, applicare **in ordine** questa priorità:

1. Integrità dei dati SwiftData.
2. Idempotenza del reimport full-database.
3. Nessuna regressione del flusso import/export esistente.
4. Chiarezza UX e coerenza SwiftUI nativa.
5. Performance ed efficienza, purche' non comprometta i punti precedenti.

Se una scelta UX «piu' bella» rischia di rendere meno chiaro lo stato dati o di nascondere un errore, preferire sempre **chiarezza** e **sicurezza**.

#### 2. Definition of Ready for Execution

Prima di avviare Execution, l'agente operativo deve confermare:

- **TASK-030** e' stato promosso esplicitamente ad **ACTIVE** dall'utente o tramite aggiornamento del **MASTER-PLAN**.
- **TASK-023** e **TASK-024** sono stati **letti**; se un file non e' disponibile, la mancanza e' **documentata** nel task o nel registro di lavoro.
- I file iOS rilevanti sono stati **riletti** dalla versione piu' aggiornata del repo (almeno `DatabaseView.swift`, `ImportAnalysisView.swift`, e dipendenze citate nel Planning).
- E' chiaro **quali fixture** verranno usate o **generate** durante Execution (riferimento: tabella Fixture A-F nell'addendum).
- E' chiaro come misurare **prima/dopo** i conteggi: **Product**, **Supplier**, **ProductCategory**, **ProductPrice** (es. SwiftData fetch nel Simulator, export di controllo, o metodo concordato — da definire in execution senza ambiguita').
- E' chiaro come verificare **`hasWorkToApply`** (allineamento tra `ImportAnalysisView` / closure passata da `DatabaseView` e `makeImportApplyPayload`).
- E' chiaro come distinguere, sul flusso full-database: **no work**, **success**, **partial success**, **error**, **cancelled** (payload `FullImportResultPayload` / `FullImportResultKind` + summary/notes/metriche e assenza di doppio canale legacy).
- **Nessun** requisito Supabase nel task.

Se uno di questi punti **non** e' verificabile, restare in **Planning** e documentare il **blocco** prima di EXECUTION.

#### 3. Contratto UX per stato «no work»

Quando il reimport e' idempotente e **non** c'e' nulla da applicare (comportamento **atteso**, da validare in execution; **nessuna** implementazione in questa fase):

- La UI **non** deve sembrare un **errore**.
- L'utente deve capire che il file e' stato **letto correttamente**.
- Deve essere mostrato un messaggio del tipo **«Nessuna modifica da importare»** (o equivalente **localizzato**).
- La schermata deve indicare, ove i dati lo consentono, che **prodotti**, **fornitori**, **categorie** e **storico prezzi** sono gia' **allineati** con il file.
- Il pulsante **Apply** deve essere **disabilitato**.
- Deve restare disponibile un'azione naturale per **chiudere** / **tornare indietro** (toolbar Cancel / dismiss sheet).
- **Non** mostrare warning inutili se il risultato e' un reimport **pulito**.

#### 4. Localizzazione

Se durante Execution verranno aggiunte nuove stringhe per UX / progress / result surface:

- aggiungere le chiavi in **tutte** le lingue gia' supportate dal progetto;
- mantenere **naming** coerente con le chiavi esistenti (`database.*`, `import.analysis.*`, ecc.);
- evitare testo **hardcoded** nelle View;
- se una traduzione precisa non e' disponibile, usare una formulazione **semplice e chiara** nella lingua di destinazione, evitando fallback inglesi **non intenzionali**.

#### 5. Evidenze minime per chiudere TASK-030

La futura Execution non puo' considerare il task **completato** (lato agente) senza almeno evidenza documentata di:

- un test di **primo** full import;
- un test di **reimport identico**;
- un test con **solo** delta non-product;
- un test **PriceHistory** duplicato o **already-present**;
- un test **cancel** prepare/analyze;
- un test **apply** senza cancel;
- una verifica che l'**import semplice** non sia regredito;
- una nota esplicita: **«Nessun Supabase introdotto»**.

(La **chiusura DONE** resta, come da policy progetto, solo dopo conferma utente.)

#### 6. Nota sul ruolo di Cursor

Questo micro-addendum e' una **rifinitura documentale** richiesta dall'utente. **Non** avvia Execution e **non** cambia l'handoff operativo previsto (EXECUTION → **CODEX** come da sezione Handoff sotto).

### Handoff (post-planning, quando il task sara' ACTIVE)

- **Prossima fase**: EXECUTION  
- **Agente operativo corrente**: CURSOR  
- **Azione consigliata**: eseguire la matrice test M-1…M-10 (estendere con TM completi dei task sorgenti se necessario), registrare evidenze nelle sezioni Execution/Fix, poi handoff a CLAUDE per review.

---

## Execution (Cursor) ← Cursor aggiorna questa sezione

### Avvio Execution controllata — Cursor

- Data avvio: 2026-04-27
- Stato: avviata su richiesta utente
- Scope confermato:
  - validazione reimport idempotente
  - validazione diff Suppliers/Categories/PriceHistory
  - validazione progress UX e cancellation
  - eventuali fix minimi e localizzati
  - nessun Supabase
  - nessuna nuova dipendenza
  - nessun refactor ampio

### Preflight obbligatorio prima di patch codice

Prima di applicare qualsiasi fix, Cursor deve:
- rileggere `DatabaseView.swift` dalla versione più aggiornata del repo;
- rileggere `ImportAnalysisView.swift` dalla versione più aggiornata del repo;
- rileggere eventuali file collegati solo se necessari;
- confermare quali fixture o file di test verranno usati;
- confermare come misurerà i conteggi DB prima/dopo:
  - Product
  - Supplier
  - ProductCategory
  - ProductPrice
- confermare come verificherà `hasWorkToApply`;
- confermare come distinguerà:
  - no work
  - success
  - partial success
  - error
  - cancelled

### Regola di esecuzione

Cursor può procedere con test e fix solo se il problema rientra nei fix minimi e localizzati descritti nel Planning.

Se emerge necessità di:
- refactor strutturale;
- cambio architetturale;
- nuova dipendenza;
- Supabase;
- modifica fuori dal percorso full database import/export;

allora deve fermarsi, documentare il blocco nella sezione Execution e chiedere nuova decisione.

### Prime azioni operative consigliate

1. Build Debug su Simulator.
2. Verifica baseline del flusso database senza modifiche.
3. Preparazione fixture A-F descritte nel Planning, se non già disponibili.
4. Esecuzione matrice minima M-1…M-10.
5. Registrazione evidenze prima/dopo.
6. Solo dopo FAIL verificato, applicare fix minimo.

### Preflight Execution reale — Cursor

- Data: 2026-04-27
- Tracking:
  - `docs/MASTER-PLAN.md` esiste ed è stato riallineato a **TASK-030 / ACTIVE / EXECUTION / CURSOR**.
  - Nessun checkbox di accettazione marcato.
- File letti prima di patch codice:
  - `docs/MASTER-PLAN.md`
  - `docs/TASKS/TASK-030-full-database-import-export-finalization-reimport-idempotency-non-product-diff-progress-ux.md` completo, inclusi Planning, Addendum e Micro-addendum
  - `docs/TASKS/TASK-023-full-db-reimport-idempotency-and-non-product-diff-visibility.md`
  - `docs/TASKS/TASK-024-full-database-import-progress-ux-cancellation.md`
  - `iOSMerchandiseControl/DatabaseView.swift`
  - `iOSMerchandiseControl/ImportAnalysisView.swift`
  - `iOSMerchandiseControl/Models.swift`
  - `iOSMerchandiseControl/ProductImportCore.swift`
  - `iOSMerchandiseControl/ExcelSessionViewModel.swift` solo per API `ExcelAnalyzer`
  - `iOSMerchandiseControl/ProductImportViewModel.swift` solo per baseline import semplice
  - `iOSMerchandiseControl/{it,en,es,zh-Hans}.lproj/Localizable.strings` per verificare lingue supportate e stringhe già presenti
- Metodo build/test scelto:
  - Build baseline: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`.
  - Test automatici disponibili nel repo: nessun target XCTest dedicato rilevato da `xcodebuild -list`.
  - Verifica matrice: build + ispezione statica dei codepath full import/export/cancel/result; test runtime via Simulator/file importer solo se l'ambiente consente interazione e accesso deterministico ai file fixture senza inventare evidenze.
- Metodo conteggi DB prima/dopo:
  - Metodo preferito runtime: app installata su Simulator, operazioni full import da fixture, poi lettura data container SwiftData con `simctl get_app_container` + `sqlite3`/introspezione tabelle per contare `Product`, `Supplier`, `ProductCategory`, `ProductPrice`.
  - Se il runtime Simulator/file picker non è automatizzabile in modo affidabile, i conteggi per M-1…M-10 saranno marcati **⚠️ NON ESEGUIBILE** e non sostituiti da supposizioni.
- Fixture/file:
  - Fixture temporanee A-E da generare fuori repo in directory `/tmp/task030-fixtures` se serve alimentare prove runtime/manuali.
  - Fixture A/B: workbook multi-sheet Products/Suppliers/Categories/PriceHistory identico per primo import e reimport.
  - Fixture C: variante con solo nuovi Suppliers/Categories.
  - Fixture D: PriceHistory duplicato intra-file.
  - Fixture E: PriceHistory con barcode non risolvibile.
  - Fixture F: opzionale/manuale, prodotto eliminato tra prepare e apply.
- Verifica `hasWorkToApply`:
  - Statica: `DatabaseView.hasWorkToApply(session:pendingFullImportContext:)` deve essere la stessa guardia usata da `ImportAnalysisView` per disabilitare Apply e da `makeImportApplyPayload`.
  - Runtime/manuale: in reimport idempotente atteso Apply disabilitato; in delta solo non-product atteso Apply abilitato.
- Distinzione esiti:
  - **no work**: `hasWorkToApply == false`, Apply disabilitato, UI analysis deve comunicare che il file è stato letto ma non ci sono modifiche da importare.
  - **success**: `FullImportResultPayload.kind == .success`, summary success, metriche applicate.
  - **partial success**: `FullImportResultPayload.kind == .success` con summary partial e note/errore PriceHistory.
  - **error**: `FullImportResultPayload.kind == .error`, overlay chiuso, result surface errore.
  - **cancelled**: `FullImportResultPayload.kind == .cancelled`, cancel solo prepare/analyze, nessuna sheet tardiva.

### FASE 1 — Build baseline

- ✅ **ESEGUITO — Build Debug Simulator baseline**
  - Comando: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
  - Esito: **BUILD SUCCEEDED**
  - Warning rilevato: `Metadata extraction skipped. No AppIntents.framework dependency found.` — warning di tooling Xcode/AppIntents già presente nella build baseline, non collegato a TASK-030.
- ✅ **ESEGUITO — App installata e avviata su Simulator**
  - Device: iPhone 16e, iOS 26.2, booted.
  - Bundle: `com.niwcyber.iOSMerchandiseControl`.

### FASE 2 — Fixture temporanee

- ✅ **ESEGUITO — Fixture generate fuori repo**
  - Directory locale: `/tmp/task030-fixtures`
  - Copia per picker Simulator: `.../File Provider Storage/TASK-030-Fixtures`
  - File creati:
    - `fixture-A-full-db-seed.xlsx`
    - `fixture-B-reimport-identical.xlsx`
    - `fixture-C-only-non-product-delta.xlsx`
    - `fixture-D-pricehistory-duplicate-intrafile.xlsx`
    - `fixture-E-pricehistory-unresolved.xlsx`
    - `simple-products.csv`
- ⚠️ **Nota fixture**
  - Le fixture `.xlsx` sono state generate manualmente via zip/XML temporaneo, senza introdurre dipendenze nel repo.
  - Il picker iOS le vede correttamente, ma il probe runtime ha mostrato che la fixture full-database temporanea non viene interpretata come workbook valido per M-1: il foglio Products produce righe senza barcode in analysis. Per evitare false evidences, nessun risultato di apply è stato dichiarato PASS.

### FASE 3 — Matrice minima M-1…M-10

| ID | Stato | Evidenza |
|----|-------|----------|
| M-1 Primo full import su DB vuoto | ⚠️ NON ESEGUIBILE con evidenza valida | Picker full import aperto, Fixture A selezionata. Analysis mostrata, ma fixture temporanea produce `Nuovi prodotti=0`, `Aggiornamenti=0`, `Errori=2`, `PriceHistory unresolved=4`; nessun Apply eseguito. Non considero il risultato una prova del codice app. |
| M-2 Reimport stesso file → no work, no insert ProductPrice | ⚠️ NON ESEGUIBILE | Dipende da M-1/apply riuscito con fixture valida. |
| M-3 Annulla dopo analisi → nessuna entità creata | ⚠️ PARZIALE | Sheet analysis chiusa con `Annulla`; DB dopo probe: `Product=0`, `Supplier=2`, `ProductCategory=2`, `ProductPrice=0`. Mancava baseline DB pulita prima del probe, quindi supplier/category non sono conclusivi. |
| M-4 Import prodotto semplice invariato | ❌ NON ESEGUITO | File CSV temporaneo preparato, ma non completato nel runtime per priorità a full import e per evitare mixing con stato simulator già non pulito. |
| M-5 Solo delta Suppliers/Categories + dedup PriceHistory intra-file | ⚠️ NON ESEGUIBILE | Fixture C/D preparate, ma non applicabili finché M-1 non ha fixture full valida. |
| M-6 Cancel prepare/analyze | ❌ NON ESEGUITO | Non completato: richiede fixture full valida e timing manuale affidabile nel Simulator. |
| M-7 Apply completo + result surface + metriche | ⚠️ NON ESEGUIBILE | Dipende da M-1/apply riuscito. |
| M-8 CSV/Excel semplice vs full, senza regressione cancel | ❌ NON ESEGUITO | Non completato nel runtime; verificato staticamente che cancel resta legato a full prepare/analyze. |
| M-9 Race cancel vs completamento / retry | ❌ NON ESEGUITO | Non automatizzabile in modo affidabile in questo passaggio. |
| M-10 Esito annullato + unica result surface full | ❌ NON ESEGUITO | Non completato runtime; verificato staticamente il canale `FullImportResultPayload.kind == .cancelled`. |

### Verifiche statiche eseguite

- ✅ **ESEGUITO — `hasWorkToApply`**
  - `ImportAnalysisView` disabilita Apply con `.disabled(isApplying || !hasWorkToApply())`.
  - `DatabaseView.makeImportApplyPayload` usa la stessa guardia `hasWorkToApply(session:pendingFullImportContext:)`.
  - La semantica include prodotti nuovi, prodotti aggiornati e `PendingFullImportContext.hasWorkToApply` (PriceHistory da inserire, supplier pending, category pending).
- ✅ **ESEGUITO — diff non-product visibile**
  - `ImportAnalysisSession` e `NonProductDeltaSummary` espongono supplier/category/PriceHistory.
  - Summary mostra sempre PriceHistory to insert / already present / unresolved quando `nonProductSummary` esiste.
- ✅ **ESEGUITO — cancellation UX static**
  - `DatabaseImportProgressState.canCancelPreparation` limita il cancel a `jobKind == .fullDatabaseImport`, fase `.preparing`, overlay visibile e nessuna cancellazione già pendente.
  - Durante apply la fase è `.applying`, quindi il cancel prepare non è esposto.
- ✅ **ESEGUITO — result surface full**
  - Full import usa `FullImportResultPayload` per success/error/cancelled.
  - `deferFullImportResultUntilAnalysisDismiss` + `presentDeferredFullImportResultIfNeeded` gestiscono la sequenza state-driven sheet → result.

### FAIL verificato e fix minimo applicato

#### F-1 — No-work UX assente

- Tipo evidenza: **STATIC**
- FAIL: il Planning/Micro-addendum richiede che, quando `hasWorkToApply == false`, la UI dica chiaramente che il file è stato letto correttamente ma non ci sono modifiche da importare. Prima del fix, `ImportAnalysisView.summarySection` mostrava solo conteggi e disabilitava Apply, senza copy dedicata.
- Fix minimo:
  - Aggiunto `noWorkNotice` in `ImportAnalysisView.swift`.
  - Il notice appare solo quando `!hasWorkToApply()`.
  - Aggiunte stringhe localizzate in `en`, `it`, `es`, `zh-Hans`.
- File modificati:
  - `iOSMerchandiseControl/ImportAnalysisView.swift`
  - `iOSMerchandiseControl/en.lproj/Localizable.strings`
  - `iOSMerchandiseControl/it.lproj/Localizable.strings`
  - `iOSMerchandiseControl/es.lproj/Localizable.strings`
  - `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`

### Build post-fix

- ✅ **ESEGUITO — Build Debug Simulator post-fix**
  - Comando: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
  - Esito: **BUILD SUCCEEDED**
  - Warning: solo warning baseline Xcode/AppIntents (`Metadata extraction skipped. No AppIntents.framework dependency found.`); nessun warning Swift nuovo rilevato nel filtro `warning:`.
- ✅ **ESEGUITO — Build finale dopo riallineamento tracking**
  - Comando: stesso build Debug Simulator.
  - Esito: **BUILD SUCCEEDED**
  - Filtro log finale: nessun `warning:` / `error:` emesso; solo `BUILD SUCCEEDED`.

### Rischi residui / non testato

- ⚠️ Matrice M-1…M-10 non chiusa runtime: il probe ha confermato picker e analysis sheet, ma le fixture `.xlsx` temporanee non hanno prodotto una prova valida di primo full import.
- ⚠️ Conteggi DB prima/dopo non conclusivi per supplier/category nel probe corrente perché il Simulator non era garantito pulito prima dell’avvio runtime.
- ⚠️ Cancel prepare/analyze e race cancel/retry restano da validare manualmente con fixture full valida.
- ⚠️ Apply completo/result surface metriche non validati runtime in questo passaggio.
- Follow-up candidate operativo, non implementato: usare un workbook generato dall’export reale dell’app o da un tooling XLSX equivalente a `xlsxwriter` per completare M-1…M-10 senza ambiguità fixture.
- Conferma: **Nessun Supabase introdotto**.
- Conferma: **Nessuna nuova dipendenza introdotta**.
- Conferma: nessun refactor ampio applicato.

### Handoff post-execution — verso Claude

- Stato consegnato: **REVIEW**.
- Agente destinatario: **CLAUDE**.
- Oggetto review:
  - validare il fix minimo F-1 su UX no-work;
  - valutare se accettare il blocco runtime come gap di evidenza o richiedere nuova execution con fixture canoniche;
  - decidere se la matrice M-1…M-10 debba essere ripetuta su DB pulito con workbook generato da export reale dell’app.
- Non modificati:
  - sezione Review;
  - sezione Fix;
  - sezione Chiusura;
  - criteri di accettazione;
  - scope / non incluso.
- Tracking globale:
  - `docs/MASTER-PLAN.md` riallineato a **TASK-030 / ACTIVE / REVIEW / CLAUDE** dopo handoff.

---

## Review (Claude) ← solo Claude aggiorna questa sezione

### Review tecnica TASK-030 — Claude Code

- Data: 2026-04-27
- Esito: **CHANGES_REQUIRED_FIXED_DIRECTLY** con runtime gap bloccante residuo.
- Decisione finale: **NON DONE**. Il codice reviewato è coerente dopo il fix diretto, ma i criteri di accettazione dati/UX non sono chiudibili senza evidenza runtime canonica M-1…M-10.

#### File verificati

- `git status`
- Diff Cursor completo su:
  - `docs/MASTER-PLAN.md`
  - `iOSMerchandiseControl/ImportAnalysisView.swift`
  - `iOSMerchandiseControl/en.lproj/Localizable.strings`
  - `iOSMerchandiseControl/it.lproj/Localizable.strings`
  - `iOSMerchandiseControl/es.lproj/Localizable.strings`
  - `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-030-full-database-import-export-finalization-reimport-idempotency-non-product-diff-progress-ux.md`
- `iOSMerchandiseControl/ImportAnalysisView.swift`
- `iOSMerchandiseControl/DatabaseView.swift` nei codepath rilevanti:
  - `PendingFullImportContext.hasWorkToApply`
  - `DatabaseView.hasWorkToApply`
  - `makeImportApplyPayload`
  - `canCancelPreparation`
  - full import result payload / deferred result surface
  - PriceHistory classify/apply summary
- `Localizable.strings` in `en`, `it`, `es`, `zh-Hans`

#### Diff review

- ✅ `hasWorkToApply` resta semanticamente corretto:
  - prodotti nuovi;
  - prodotti aggiornati;
  - Supplier pending;
  - Category pending;
  - PriceHistory da inserire.
- ✅ Delta solo non-product resta lavoro applicabile perché passa da `PendingFullImportContext.hasWorkToApply`.
- ✅ Le nuove chiavi `import.analysis.no_work.title/body` sono presenti in tutte le lingue supportate e il formato `.strings` è valido.
- ✅ Nessun testo hardcoded introdotto nella View.
- ✅ Nessun Supabase introdotto.
- ✅ Nessuna nuova dipendenza introdotta.
- ✅ Nessun refactor ampio introdotto.
- ⚠️ Runtime M-1…M-10 non chiuso: il report Cursor è onesto e non dichiara PASS fittizi.

#### Problema trovato in review

**R-1 — Notice no-work troppo permissivo**

- Tipo evidenza: **STATIC**
- Severità: piccola ma reale per UX/sicurezza dati.
- Prima del fix diretto, `noWorkNotice` veniva mostrato con la sola condizione `!hasWorkToApply()`.
- Questo poteva mostrare “database già allineato” anche in analisi senza lavoro applicabile ma con:
  - errori di riga (`session.errors` non vuoto);
  - PriceHistory non risolto (`priceHistoryUnresolved > 0`).
- Esempio coerente con il probe Cursor: fixture non canonica con `Nuovi prodotti=0`, `Errori=2`, `PriceHistory unresolved=4`; in quello stato il notice “file letto correttamente / database allineato” sarebbe stato fuorviante.

#### Fix diretto in review

- File modificato:
  - `iOSMerchandiseControl/ImportAnalysisView.swift`
- Modifica:
  - introdotta `shouldShowNoWorkNotice`;
  - il notice appare solo se:
    - non è in corso Apply;
    - `hasWorkToApply() == false`;
    - `session.errors.isEmpty`;
    - `priceHistoryUnresolved == 0` quando esiste `nonProductSummary`.
- Nessuna nuova stringa necessaria.
- Nessuna modifica a `DatabaseView.swift`.
- Nessuna modifica a localizzazioni oltre quelle già aggiunte da Cursor.

#### Build / lint

- ✅ **ESEGUITO — Build Debug Simulator**
  - Comando: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
  - Esito: **BUILD SUCCEEDED**
  - Warning: `Metadata extraction skipped. No AppIntents.framework dependency found.` — warning baseline/tooling già osservato, non introdotto da TASK-030.
- ✅ **ESEGUITO — Localizable.strings lint**
  - `plutil -lint` OK per `en`, `it`, `es`, `zh-Hans`.
- ✅ **ESEGUITO — whitespace/diff check**
  - `git diff --check` OK sui file toccati da TASK-030.

#### Runtime result / gap

- ⚠️ **Runtime gap bloccante confermato**
  - Non esiste evidenza canonica per M-1…M-10.
  - Le fixture temporanee `.xlsx` costruite manualmente non sono accettabili come workbook canonico perché il parser full import le ha interpretate in modo errato.
  - Non dichiaro PASS per:
    - M-1 primo full import;
    - M-2 reimport idempotente;
    - M-5 delta Suppliers/Categories + dedup PriceHistory;
    - M-6 cancel prepare/analyze;
    - M-7 apply completo + result surface;
    - M-8 import semplice vs full;
    - M-9 race cancel/retry;
    - M-10 esito annullato/result surface.

#### Decisione review

- **NON APPROVED_TO_DONE**: mancano evidenze runtime canoniche richieste dal Planning/Micro-addendum.
- **NON CHANGES_REQUIRED_NEEDS_FIX_PHASE**: il solo problema codice trovato era piccolo ed è stato corretto direttamente in review.
- Stato task aggiornato a **BLOCKED** con fase **REVIEW sospesa / pending runtime validation canonica**.
- Prossimo step corretto:
  1. nuova execution runtime con workbook generato dall’export reale dell’app su DB pulito; oppure
  2. accettazione esplicita dell’utente del runtime gap come non bloccante.

Fino a uno di questi due eventi, TASK-030 non deve essere marcata DONE e i checkbox di accettazione restano non marcati.

---

## Fix (Codex) ← solo Codex aggiorna questa sezione
Non avviato.

---

## Chiusura

### Conferma utente
- [ ] Utente ha confermato il completamento

### Follow-up candidate
—

### Riepilogo finale
—

### Data completamento
