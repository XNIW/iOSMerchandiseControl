# TASK-111: Audit e parity Excel / import — iOS vs Android (riferimento funzionale)

## Informazioni generali
- **Task ID**: TASK-111
- **Titolo**: Audit e parity Excel / import — esecuzione end-to-end (**DONE / Chiusura — REVIEW PASS WITH NOTES**)
- **File task**: `docs/TASKS/TASK-111-excel-analysis-parity-ios.md`
- **Stato**: DONE
- **Fase attuale**: **Chiusura — REVIEW PASS WITH NOTES**
- **Responsabile attuale**: **CODEX / Reviewer-Fixer**

> **User override 2026-05-17 12:20 -0400 — Execution autorizzata.** Il blocco planning-only sotto resta come storico/governance del piano approvato; l'utente ha richiesto esecuzione end-to-end.  
> **Review override 2026-05-17 13:53 -0400 — Chiusura autorizzata dal prompt utente corrente se la review e' verde.** Review indipendente completata con fix diretti, build/test/smoke PASS e note non bloccanti: **TASK-111 DONE / Chiusura — REVIEW PASS WITH NOTES**.
> **Post-review micro-fix 2026-05-17 14:35 -0400 — richiesta utente.** Applicata micro-correzione cross-platform nel perimetro Excel/import parity: colonne non identificate visibili ma OFF di default in PreGenerate. **TASK-111 resta DONE / REVIEW PASS WITH NOTES**, nessun `TASK-112` aperto; **TASK-109 resta BLOCKED / SOSPESO**, **TASK-110 resta DONE**.
> **Post-review micro-fix 2026-05-17 15:22 -0400 — richiesta utente.** Applicata micro-correzione UX supplier/category pending-create in PreGenerate: testo nuovo valido abilita generazione, summary mostra nuovo valore, record creati solo al tap su Generar inventario e dedupe case/trim. Audit Android: stesso problema trovato e patch mirata applicata. **TASK-111 resta DONE / REVIEW PASS WITH NOTES**, nessun `TASK-112` aperto; **TASK-109 resta BLOCKED / SOSPESO**, **TASK-110 resta DONE**.

- **Data creazione**: 2026-05-17
- **Ultimo aggiornamento**: 2026-05-17 15:22 -0400 *(micro-fix post-review supplier/category pending-create UX; TASK-111 resta DONE / REVIEW PASS WITH NOTES)*  
- **Ultimo agente che ha operato**: CODEX / Executor-Fixer *(micro-fix post-review richiesto dall'utente, test iOS/Android, evidence `20`)*  

---

## PLANNING-REFINEMENT vs future EXECUTION-AUDIT vs EXECUTION-IMPLEMENTATION

| Fase | Contenuto |
|------|------------|
| **PLANNING-REFINEMENT** | **Fase storica.** Rifinire piano (contratti, UX decisions, elenco evidence attese, gate, micro-slice); **non** doveva includere lettura codebase sistematica tipo execution; **nessuna patch** runtime in quella fase. |
| **EXECUTION-AUDIT** | **Solo dopo nuovo prompt esplicito.** Lettura repo **read-only** (iOS, Android referenza, Supabase locale nei limiti autorizzati); compilare evidence **00–10** e matrice **M1–M28** evidence-driven (**file/linea/citation** dove richiesto); ancora **nessuna patch funzionale** Swift/Kotlin/SQL. Build/test solo se quel prompt autorizza (**non sono gate del planning refinement**). |
| **EXECUTION-IMPLEMENTATION** | **Solo dopo audit rivisto/autorizzato + prompt esplicito.** Modificare Swift/tests/UI (**micro-slice S111-A…S111-H**); **vietato mega-refactor** trasversale implicito senza pianificazione. |

### REVIEW *(dopo modifiche IMPLEMENTATION — fuori dall’audit read-only)*

Conforme AGENTS/workflow progetto standard: REVIEW (**Claude** / stakeholder) ⇒ eventuale FIX (**CODEX**) ⇒ conferma utente **DONE**.

### Tabella sintetica vincoli (incrociata)

| | **PLANNING-REFINEMENT** | **EXECUTION-AUDIT** | **EXECUTION-IMPLEMENTATION** |
|---|--------------------------|---------------------|-----------------------------|
| **Lettura codice sistematica** | No | **Sì**, nei limiti del prompt audit | Dove necessaria alla slice |
| **Patch** | No | No | **Sì**, mirata slice |
| **Esito atteso / deliverable principale** | Documento TASK-111 stabile (evidence `10-*` **non compilata** in planning) | `10-execution-audit-verdict.md` (**≠ parity / DONE**) | Feature + ciclo REVIEW |

---

## Planning Refinement Charter

- Questa fase è **solo planning** (**PLANNING-REFINEMENT**).
- **Non** deve implementare fix applicativi.
- **Non** deve eseguire build/test runtime **come obbligo** di questo passaggio.
- **Non** deve dichiarare parity, DONE, PASS runtime né esiti Xcode/Gradle/Supabase.
- Serve a rendere il piano abbastanza **rigido** e **non ambiguo** da guidare un audit futuro **EXECUTION-AUDIT** senza scope creep improvvisato.
- **Android** è **riferimento funzionale**; **iOS** resta target **SwiftUI/SwiftData** nativo.
- **UI iOS** deve **migliorare l’esperienza**, **non copiare layout Android** 1:1.
- **Decisioni di prodotto architettura** pertinenti parity Excel/import vanno definite **qui in planning**, **non «scoperte durante patch»**.

---

## Planning Review Findings *(integrazioni aggiunte — ancora planning-only)*

Il piano precedente era corretto sul vincolo principale (**no Execution**) e già copriva contratti, UX, performance, fixture e legacy. Mancavano però alcuni elementi per renderlo realmente governabile quando passerà a EXECUTION-AUDIT / IMPLEMENTATION:

| Area | Gap del piano precedente | Integrazione aggiunta |
|------|---------------------------|------------------------|
| Priorità | P0/P1/P2 presenti ma senza criterio operativo esplicito. | Aggiunta matrice **Priority & Severity Scoring**. |
| UX reale operatore | UX ImportAnalysis descritta, ma non ancora organizzata come flusso decisionale rapido per negozio. | Aggiunto principio **operator-first** e gerarchia azioni. |
| Anti-regressione | Legacy reconciliation presente, ma non bloccante abbastanza. | Aggiunto **Regression Lock List** con gate no-regression. |
| Rollback | Apply atomico citato, ma senza piano di recovery utente. | Aggiunta sezione **Failure / Recovery / Rollback Plan**. |
| KPI audit | Performance gates presenti, ma senza metriche minime di audit. | Aggiunti **Audit KPI** da compilare in EXECUTION-AUDIT. |
| Decisioni future | Micro-slice presenti, ma mancava criterio per evitare mega-task. | Aggiunto **Slice Sizing Rule**. |
| UI polish | Scelte UX presenti, ma mancava policy per densità, accessibility e destructive actions. | Aggiunto **UI Polish Guardrails**. |
| Confini architetturali | Il piano parlava di file/servizi ma non fissava abbastanza i boundary iOS. | Aggiunta sezione **iOS Architecture Boundaries**. |
| Privacy/evidence | Evidence future definite, ma mancava policy redazione/igiene. | Aggiunta sezione **Evidence Hygiene & Privacy Rules**. |
| Prontezza audit | Mancava una Definition of Ready per passare da planning ad audit. | Aggiunta **Definition of Ready for EXECUTION-AUDIT**. |
| Rischi residui | I rischi erano sparsi in varie sezioni. | Aggiunto **Risk Register** centralizzato. |
| Claim parity | Mancava una scala per evitare claim binari prematuri «parity sì/no». | Aggiunta **Parity Claim Ladder** con livelli progressivi. |
| Decisioni ambigue | Alcune policy business future potevano restare implicite. | Aggiunti **Default Decision Rules** per scegliere senza bloccare l’audit. |
| Qualità audit | Evidence future definite, ma mancava un quality bar per dire se l’audit è completo. | Aggiunto **EXECUTION-AUDIT Quality Bar**. |
| UX review finale | UX operator-first presente, ma mancava una checklist finale sintetica. | Aggiunta **UX Acceptance Checklist**. |

**Esito review planning:** il task resta **ACTIVE / PLANNING-REFINEMENT**. Le integrazioni qui sotto non autorizzano audit operativo né implementazione.

---

## Dipendenze
- **`TASK-110`**: **DONE** — **non riaperto**.  
- **`TASK-109`**: **`BLOCKED / SOSPESO`** — **non ripreso**.  
- **Sblocca (ordine suggerito)**: dopo prompt esplicito **EXECUTION-AUDIT** → gap documentati/evidence compilabili; dopo prompt **`EXECUTION-IMPLEMENTATION`** (e ciclo REVIEW) → modifiche Swift per slice autorizzati.

---

## Scopo *(PLANNING-REFINEMENT)*

Consegnare un **documento di pianificazione** completo sulla pipeline **analisi Excel / import / preview / apply**, confrontata con Android come baseline funzionale, includendo contratti (**Unified Import**), **baseline Android comportamentale**, **gate UX/performance/memory**, **matrice parity M1–M28 pronta a compilazione evidence-driven**, **catalogo edge fixture privacy-safe**.

**Fuori scope immediato**: esecuzione vera dell’audit, implementazione Swift/Kotlin, misurazioni obbligatorie.

---

## Contesto tecnico

- **iOS**: `https://github.com/XNIW/iOSMerchandiseControl`  
- **Android**: `https://github.com/XNIW/MerchandiseControlSplitView`  
- **Supabase** (solo mappa/documentazione nei passi futuri): repo clone **MerchandiseControlSupabase** — **non** migration in questa fase.

---

## Non incluso *(fase PLANNING-REFINEMENT + fino al prossimo prompt)*

- Qualsiasi modifica **Swift / Kotlin / SQL / schema / migration / Supabase mutate**.  
- **EXECUTION-AUDIT** operativa o **EXECUTION-IMPLEMENTATION** senza comando esplicito separato dall’utente.  
- **Build/Xcode/Gradle/Test** come obbligo di questo pass planning.  
- Dichiarare **parity Excel**, **DONE**, **PASS runtime**.

---

## Decisioni *(riallinea governance)*  
| # | Decisione | Stato |
|---|-----------|--------|
| D-111-01 | Android = solo riferimento funzionale; iOS SwiftUI/SwiftData | attiva |
| D-111-02 | TASK-109 BLOCKED / SOSPESO; TASK-110 DONE | attiva |
| D-111-03 | Separate **PLANNING-REFINEMENT**, **EXECUTION-AUDIT**, **EXECUTION-IMPLEMENTATION**, **REVIEW post-IMPLEMENTATION** | attiva |
| D-111-04 | ~~TASK-111 ACTIVE EXECUTION-AUDIT~~ → **OBSOLETA**: sostituita da **PLANNING-REFINEMENT** (override utente 2026-05-17) | **OBSOLETA** → vedi **D-111-05** |
| D-111-05 | TASK-111 **ACTIVE / PLANNING-REFINEMENT**, responsabile **CLAUDE / Planner-Reviewer**; EXECUTION-AUDIT **solo su prompt futuro** | **attiva** |
| D-111-06 | Qualsiasi futuro fix deve partire da una riga della matrice M1–M28 già compilata con evidence; niente patch “a intuizione” | **attiva** |
| D-111-07 | La futura UX deve essere **operator-first**: prima capire cosa succede, poi correggere, poi confermare; non massimizzare densità a scapito della chiarezza | **attiva** |
| D-111-08 | Ogni micro-slice futura deve avere rollback/regression guard esplicito prima di modificare persistenza o ProductPrice | **attiva** |
| D-111-09 | Le View SwiftUI future devono restare sottili: mapping, diff, validation, apply e ProductPrice **non** vanno spostati nelle View | **attiva** |
| D-111-10 | Le evidence future devono essere **privacy-safe**: niente dati reali negozio, email, token, path personali non redatti | **attiva** |
| D-111-11 | La promozione a **EXECUTION-AUDIT** richiede **prompt utente esplicito** e **Definition of Ready** soddisfatta; **questo file non la attiva da solo** | **attiva** |
| D-111-12 | «Parity Excel» **non è binaria**: va dichiarata solo secondo la **Parity Claim Ladder** e **mai** prima di audit + implementation + review appropriate | **attiva** |
| D-111-13 | In caso di conflitto fra completezza Android e UX iOS, scegliere **comportamento Android** + **presentazione SwiftUI nativa**, non layout Android | **attiva** |
| D-111-14 | In caso di dubbio su dati/prezzi/apply, preferire comportamento **conservativo**: preview chiara, nessuna scrittura implicita, conferma utente, rollback documentato | **attiva** |
| D-111-15 | Le future decisioni business **non risolte** devono essere registrate come **Decision Needed**, non risolte silenziosamente durante patch | **attiva** |

---

## Unified Import Contract *(modello concettuale — nessun file codice creato)*

> **Obiettivo:** minimizzare **doppia logica divergente** tra `ExcelAnalyzer`, `ExcelSessionViewModel`, `ProductImportCore`, `DatabaseView`, `GeneratedView`, `InventorySyncService`.  
> Nella futura EXECUTION-AUDIT: mappare per ogni concetto una **implementazione/type Swift esistente** o **GAP** dichiarato.  
> **Non** dichiarare allineamento finché gli evidence **`01`/`04`** non compilano cite.

| Concetto | Ruolo nella pipeline | **Output atteso dal futuro audit** |
|----------|----------------------|------------------------------------|
| **RawExcelRow** | Riga post-parser (sheet/HTML), valori grezzi per colonna/indice/HTML cell prima della semantica prodotto. | Verifica formato stringhe; nulla deve saltare blocchi validazione; confine netto dove iniziano regole SKU. |
| **CanonicalHeaderMapping** | Associazione colonna ⇒ campo canonico + **confidence** (Exact / Alias / Manual / Inferred / Ambiguous). | Lista mapping con motivazione (**alias**) e stato ambiguo; input per UX PreGenerate (**badge UX**). |
| **NormalizedImportRow** | Record semantico intermedio dopo normalizza numerico/locale, trim, barcode scientifico ecc. | Confrontabile 1:1 con validazione **`B-xx`** prima di SwiftData; tracciabile per diff. |
| **ImportIssue** | Errore bloccante riga/set che **impedisce inclusione** nell’apply (equiv. errore forte). | Lista issue con riga/colonna/trace; linkage export errori (**UX**); **≠ crash**. |
| **ImportWarning** | Condizione continuabile (**footer**, duplicato sospetto, mapping debole…) | Non bloccare apply righe **valide** (**B-xx** comportamento pianificato). |
| **ImportDiff** | Classificazione `nuovo | aggiornato | invariato | ignorato/escluso` per preview analytics. | Conteggi per **summary ImportAnalysis** (**UX**) e applicazione selettiva (**apply plan**). |
| **ImportApplyPlan** | Insieme **righe eligible** ordinate/constraints; **dry-run**/preview **senza persist** finché utente conferma (**B-xx preview**). | Documentare path side-effect-free; ordine deterministico applicazione. |
| **ProductPriceMutationPlan** | Sequenza storica **`ProductPrice`** (append/update current) prima del commit. | Coerenza con **`B-14`**; idempotenza e chiavi univoche verificabili nel codice (**TASK-087/088**, ecc.). |
| **SupplierCategoryResolution** | Risoluzione nomi (**case-insensitive cache**); creazione se **mancanti** (**policy precisa ⇒ verifica Kotlin nell’audit**). | Nessun dangling refs; comportamento deterministico caso misto. |
| **SwiftDataApplyTransaction** | Commit atomico o equivalente rollback/failure (**un solo transactional boundary** quando possibile). | Verificare dove avviene oggi; gap su doppio flusso Inventario/catalogo. |

---

## iOS Architecture Boundaries *(planning — nessun codice ora)*

Il futuro audit e le future implementation devono preservare una separazione **SwiftUI / SwiftData** pulita. **Android** può suggerire **comportamenti**, non la **struttura** modulare iOS.

| Layer iOS | Responsabilità ammessa | Responsabilità vietata |
|-----------|------------------------|-------------------------|
| **SwiftUI View** | Stato visuale, sheet, alert, toolbar, filtri, rendering summary/card/list. | Parsing Excel pesante, validazione business, apply SwiftData, merge duplicati, ProductPrice history. |
| **ViewModel / Observable state** | Orchestrazione async, progress/cancel, stato schermata, chiamata servizi. | Contenere parser monolitico non testabile o transazioni SwiftData complesse **inline**. |
| **Parser / Analyzer service** | Lettura/normalizzazione file, header mapping, row normalization, issue/warning generation. | UI copy finale, navigazione, accesso diretto a View SwiftUI. |
| **Import Core / Diff service** | Confronto con DB locale, `ImportApplyPlan`, `ProductPriceMutationPlan`, supplier/category resolver. | Rendering UI, side effect **prima** della conferma. |
| **Persistence / SwiftData apply** | Commit atomico o recovery documentato, idempotenza, dedupe ProductPrice. | Parsing file, decisioni UX, chiamate Supabase implicite. |
| **Supabase sync boundary** | Solo **pending/conflict impact map** in TASK-111; eventuale push/pull in **task separato** / gated. | Attivare sync o migration dentro slice Excel locale **senza** prompt dedicato. |

**Regola architetturale:** se una futura patch rende una **View SwiftUI** responsabile della **logica business** (validazione/apply/merge/prezzi), quella patch va **respinta** o **rifattorizzata** prima della review.

---

## Default Decision Rules *(per evitare blocchi inutili durante audit futuro)*

Queste **non sono implementazioni**: sono **default di decisione** per il futuro audit/implementation quando Android e iOS differiscono.

| Caso | Default scelto |
|------|----------------|
| Android ha una capability stabile e iOS non ce l’ha | Pianificare parity iOS, salvo motivazione esplicita documentata. |
| iOS ha UX migliore ma logica incompleta | Preservare UX iOS e integrare logica mancante. |
| Android ha UX più densa ma più completa | **Non** copiare layout; trasformare in sheet/card/filter SwiftUI. |
| Valid rows + invalid rows nello stesso file | Consentire import delle righe valide con errori esclusi ed **exportabili**. |
| Warning non bloccante | **Non** bloccare apply, ma renderlo visibile e tracciabile. |
| Prezzi ambigui o potenzialmente distruttivi | **Non** sovrascrivere silenziosamente; mostrare diff e richiedere conferma. |
| Supplier/category ambiguo | Resolver deterministico + warning o scelta manuale se collisione reale. |
| Duplicati barcode | Seguire comportamento Android se confermato: warning + policy esplicita last-row/qty aggregate. |
| Supabase impact emerso durante audit | Registrare follow-up **S111-H** o task separato; **non** modificare sync dentro audit read-only. |
| Dubbi non risolvibili con codice | Marcare **`Decision Needed`** con opzioni, rischio e raccomandazione. |

---

## Android behavior contract *(baseline da verificare nella futura EXECUTION-AUDIT)*

> **NON PASS:** finché non si citano file/linee Kotlin nell’evidence **`02`**; qui solo **specifica comportamentale** da confrontare Swift.

| # | Comportamento baseline |
|---|------------------------|
| B-01 | Barcode **obbligatorio**. |
| B-02 | Obbligatorio **nome prodotto** **oppure** **secondo nome**. |
| B-03 | Prezzo acquisto **non negativo**. |
| B-04 | Nuovo prodotto: **prezzo vendita obbligatorio** **e** **`> 0`**. |
| B-05 | Esistente: prezzo vendita se **fornito** ⇒ **`> 0`**. |
| B-06 | Quantità **non negativa**. |
| B-07 | Sconto **solo** nell’intervallo **`0 … 100`** (interpretazione `%` confermare in Kotlin). |
| B-08 | **`discountedPrice`** **prevale** su calcolo **`purchasePrice + discount`**. |
| B-09 | Vecchi prezzi da **`oldPurchasePrice`** / **`prevPurchase`**, **`oldRetailPrice`** / **`prevRetail`**. |
| B-10 | Supplier/category risolti per nome, cache **case-insensitive**, creati se mancanti (policy esatta ⇒ audit). |
| B-11 | Duplicati barcode: **`last row wins`** nei dati; qty aggregata: **`realQuantity` se >0 altrimenti `quantity`**; **warning numeri riga**. |
| B-12 | Errori imprevisti ⇒ **row/issue strutturata**, non crash UX. |
| B-13 | Import analysis separa **nuovi**, **aggiornati**, **errori**, **warning**. |
| B-14 | Apply registra **history `ProductPrice`** quando cambiano prezzi (**B parity pricing**). |
| B-15 | **Preview NON scrive** persistenza DB prima **conferma esplicita** utente (**side-effect guard**). |
| B-16 | **Warning non bloccanti** **NON** impediscono apply delle **solo righe valide** (consistent con **UX chips** pianificati). |
| B-17 | **Export disponibile** per **errori** e dove utile (**warning**/diagnostica fuori errore forte) così foglio sorgente può essere corretto offline (**policy parity con Android** ⇒ verifica code). |

---

## Priority & Severity Scoring *(criterio operativo per futura matrice M1–M28)*

La futura EXECUTION-AUDIT deve classificare ogni gap con questi criteri, evitando priorità arbitrarie:

| Priorità | Definizione | Esempi TASK-111 |
|----------|-------------|-----------------|
| **P0** | Può corrompere dati, perdere prezzi/storico, importare prodotti sbagliati, bloccare flusso principale o causare freeze/crash. | Barcode/duplicati, prezzi, ProductPrice, apply non atomico, parsing grandi file, MainActor freeze. |
| **P1** | Funzione importante per operatività ma con workaround accettabile. | Export errori, warning UX, filtri ImportAnalysis, badge mapping. |
| **P2** | Miglioria polish/diagnostica/futuro sync, non bloccante per import locale corretto. | Supabase impact map, microcopy, metriche avanzate, analytics diagnostiche. |

| Severità | Definizione | Azione futura |
|----------|-------------|---------------|
| **Critical** | Rischio perdita/corruzione dati o storico prezzi. | Va risolto prima di dichiarare parity. |
| **High** | Rischio flusso utente rotto o import parziale non spiegato. | Entra nelle prime slice implementation. |
| **Medium** | UX/operatività migliorabile, workaround disponibile. | Pianificare dopo P0/High. |
| **Low** | Polish o chiarezza secondaria. | Opportunistico, solo se non aumenta complessità. |

Regola: un gap **P0/Critical** blocca qualunque claim “Excel parity”. Un gap **P1/High** può consentire avanzamento solo se documentato con workaround e follow-up.

---

## Parity Claim Ladder *(evita claim prematuri)*

La parità Excel/import va trattata come **scala progressiva**, non come dichiarazione unica binaria.

| Livello | Nome | Significato | Claim permesso |
|---------|------|-------------|----------------|
| **L0** | Planning complete | Piano raffinato, ma nessun audit operativo. | «Planning completo», non parity. |
| **L1** | Audit mapped | Evidence `00–10` compilate, matrice M1–M28 riempita, gap prioritizzati. | «Audit completato», non parity. |
| **L2** | Core parity implemented | P0/Critical implementati o motivati con workaround sicuro; test mirati verdi. | «Core parity tecnica proposta», non finale. |
| **L3** | UX/operator parity | Flussi ImportAnalysis/PreGenerate/Generated validati con UX iOS-native e no-regression principali. | «Parity funzionale con note», se restano P1/P2. |
| **L4** | Review accepted | Review severa, regressione, fixture e performance gate adeguati. | «Excel/import parity accepted» nel **perimetro TASK-111**. |

**Regola:** TASK-111 in questo momento è solo **L0 / Planning complete candidate**. Nessun altro livello può essere dichiarato senza prompt e evidence futuri.

---

## Performance / MainActor / Memory Gates *(verifica futura audit — struttura planning)*  

| # | Gate |
|---|------|
| PG-01 | Parsing **Excel/HTML/legacy `.xls`** **fuori MainActor** (**offload/async** dedicate). |
| PG-02 | **Analyze / diff contro DB**: background o chunked; **no spike MainActor** ingest massivo non throttled. |
| PG-03 | **SwiftData apply** con **`ModelContext` corretto**, transazione/recovery **sicura** (**vedi Unified `SwiftDataApplyTransaction`**). |
| PG-04 | **Progress** UI **throttled** — **vietato aggiornare riga-per-riga** salvo chunk documentati. |
| PG-05 | **Cancel cooperativo** parse/analyze/apply (**Task**/flag osservabile). |
| PG-06 | **Memory bounded** — vietate **copie multiple** ingest `[[String]]` se evitabile (**materializzazioni fantasma**). |
| PG-07 | **Chunk sizes** (**parse/apply/export**) osservati e **motivazione** nei doc performance evidence future. |
| PG-08 | Evidence dataset grandi (futura EXECUTION-AUDIT / IMPLEMENTATION) include almeno: **N righe**, durate (**parse/analyze/apply**/dry-run quando misurabile), **memoria** osservabile, **responsiveness** tab/Options (**senza backlog MainActor rumor**). |
| PG-09 | **Tab + Options**: usabilità durante import stress (**no backlog tap** / regressione perceptible). |
| PG-10 | **Nessuna regressione TASK-105 / TASK-108**: offload MainActor / jank starvation rispetto a fix storici (**regression guard**). |

### Audit KPI minimi futuri

Durante EXECUTION-AUDIT, se e solo se autorizzata, non basta dire “sembra veloce”: servono metriche o evidenze strutturate.

| KPI | Minimo richiesto in audit futuro |
|-----|----------------------------------|
| Parser | Tipo file, numero righe, numero colonne, durata parse, eventuale fallback HTML/legacy. |
| Analyze | Numero righe valide/errori/warning/duplicati, durata analyze, eventuale chunking. |
| Apply dry-run | Numero new/update/skip, conferma side-effect-free. |
| Apply reale futura | Durata, record SwiftData toccati, ProductPrice creati/ignorati, rollback/failure behavior. |
| Responsiveness | Evidenza qualitativa o misurata che tab/scroll/Options non accumulano tap durante lavoro pesante. |
| Memoria | Almeno osservazione qualitativa; se disponibile, snapshot memoria prima/dopo dataset grande. |
| Cancel | Punto in cui cancel viene osservato e stato UI finale atteso. |

---

## UX/UI Decisions — iOS-native *(planning UX — EXECUTION-IMPLEMENTATION futura solo dopo audit + prompt)*  

### Principio UX operator-first

La UI futura deve essere ottimizzata per l’uso reale in negozio: l’operatore deve capire in pochi secondi se il file è importabile, quali righe sono sicure, quali richiedono attenzione e quale azione primaria conviene fare.

Gerarchia consigliata:
1. **Stato globale**: importabile / importabile con warning / bloccato.
2. **Conteggi chiave**: validi, nuovi, aggiornati, errori, warning, duplicati.
3. **Correzione rapida**: aprire solo le righe problematiche o filtrate.
4. **Azione primaria**: confermare solo righe valide.
5. **Diagnostica secondaria**: export errori/warning, dettagli tecnici, raw row.

La UI non deve trasformarsi in una tabella densa stile desktop. Su iPhone preferire card compatte, sheet, filtri e progressive disclosure.

### ImportAnalysis iOS

- Summary card in alto: **righe totali**, **righe valide**, **nuovi prodotti**, **aggiornati**, **warning**, **errori**.  
- Sezioni collassabili: **Nuovi**, **Aggiornati**, **Warning**, **Errori**, eventualmente **Invariati/Ignorati** (solo se semanticamente previsti dall’analisi unified).  
- Chip filtro: **Tutti**, **Valide**, **Warning**, **Errori**, **Nuovi**, **Aggiornati**.  
- **CTA sticky bottom** » **Conferma importazione**.  
- CTA **abilitata** quando esistono **righe valide**, **anche se** errore anche presente (**exclude error rows dall’apply**) (**B pianificazione + UX coerenti**).  
- Error rows **VISIBILI** + **EXPORTABILI** (**B-17 / UX export**).  
- **Export errori/warning UX:** export errori sempre se `errors > 0`; export diagnostica warnings **policy parity** ⇒ verifica EXECUTION-AUDIT reale Compose vs SwiftUI (**non decidere tecnico qui**, solo parity target).  
- **Inline edit** sheet / **Form** nativi iOS.  
- Righe/card compatte → titolo, barcode/itemNumber chiave, blocchi pricing, supplier/category badges stato severità/readiness.  
- Ordinamento default consigliato: **Errori → Warning → Aggiornati → Nuovi → Invariati**, ma con filtro rapido per mostrare solo righe applicabili.  
- Badge severità: `Errore`, `Warning`, `Nuovo`, `Aggiorna`, `Invariato`, con colori coerenti Semantic SwiftUI e accessibili anche senza colore.  
- Azione distruttiva o irreversibile: usare `confirmationDialog`/`alert`, mai conferma silenziosa.  
- Copy orientato all’operatore: evitare termini tecnici come “diff object” o “normalized row” nella UI finale; usarli solo nei log/evidence.  
- **Vietato** copiare griglia/tabellone Android fisso 1:1 (**ZoomableExcelGrid** non è target pixel layout SwiftUI).

### PreGenerate iOS  

- Badge qualità mapping: **Exact**, **Alias**, **Manual**, **Inferred**, **Ambiguous**.  
- **Ambiguous** ⇒ **warning** **+** capability **manual override**, **NON blocco ingresso rapido**, salvo **rischio sicurezza/dati gravissimo documentato EXECUTION-AUDIT**.  
- **Colonne mandatory** marcate sobriamente (**accessibility small label / iconografie discrete** pianificabile).  
- **Warning preemptive** quando si rilevano **footer/subtotal**/sentinel da escludere (**prima Generated** dove possibile).  
- NON peggiorare **Inventario → PreGenerate → Generated → Cronologia** (**baseline TASK-105/102** lineage).

### Generated iOS

- NON copia **ZoomableExcelGrid Compose** layouts/physics 1-to-1.  
- Mantenere **scroll SwiftUI naturale leggibile telefono** (**Dynamic Type**/safe area continuano dopo TASK storici UX).  
- Accesso chiaro editing campi/header mapping quando necessario **non invasivo** rispetto griglia (**progressive disclosure**).  
- **Search + barcode scan inventory** deve restare veloce e **decoupled dalla import-catalog pipeline** (**no merge responsabilità** accidentale).

### UI Polish Guardrails

| Area | Guardrail |
|------|-----------|
| Densità | Più righe visibili, ma mai al punto da rendere prezzi/barcode illeggibili. |
| Accessibilità | Dynamic Type, VoiceOver label per stati, touch target minimi su azioni principali. |
| Colore | Colore come rinforzo, non unica informazione; usare testo/badge. |
| Animazioni | Solo feedback leggero; niente animazioni che rallentano import o scroll. |
| Empty state | Messaggio utile + azione successiva chiara. |
| Error state | Motivo + azione: correggi mapping, esporta errori, torna a PreGenerate. |
| Loading | Progress con fase comprensibile: `Lettura file`, `Analisi righe`, `Confronto database`, `Preparazione import`. |

### UX Acceptance Checklist futura

Prima di accettare una futura implementation UX, verificare:

- L’utente capisce in **meno di una schermata** se può importare o deve correggere.
- Gli errori **non** sono nascosti in fondo alla lista.
- La **CTA primaria** non è ambigua e **non** importa righe invalide.
- I warning non bloccanti sono **visibili** ma non spaventano inutilmente.
- Le righe con **prezzi modificati** mostrano chiaramente current/previous quando rilevante.
- L’**export errori** è raggiungibile senza cercare nei menu avanzati.
- **Dynamic Type** non rompe summary card, chip e CTA sticky.
- **VoiceOver** può distinguere errore, warning, nuovo, aggiornato e invariato anche senza colore.
- L’utente può tornare a **PreGenerate** senza perdere contesto inutilmente.
- Nessuna schermata introduce **gergo tecnico interno** come `NormalizedImportRow` o `ApplyPlan`.

*(Numerazione storica UX-01 legacy table **NON** rinumerata integralmente nel testo sopra perché amplificata; future evidence `05-ux-ui-decisions.md` conterrà checklist dettaglio mapping gap.)*

---

## Evidence nominale (**produzione = EXECUTION-AUDIT futura** — durante PLANNING rimangono **non compilate**)  

Creare/compilare sotto **`docs/TASKS/EVIDENCE/TASK-111/`** **solo dopo** autorizzazione **EXECUTION-AUDIT**:

| File | Ruolo pianificato |
|------|--------------------|
| `00-preflight-tracking.md` | HEAD repo, recap governance **TASK-109/110**. |
| `01-ios-code-map.md` | Mappa moduli (**Unified contract** bridging). |
| `02-android-behavior-map.md` | Evidenza **B-01–B-17**. |
| `03-supabase-impact-map.md` | Impatti teorici IMPORT→CLOUD (**read-only**, separazione da TASK-109). |
| `04-parity-matrix-filled.md` | Matrice compilata (**M**) + cite. |
| `05-ux-ui-decisions.md` | Gap questa UX **vs swift code**. |
| `06-edge-case-fixture-plan.md` | Edge⇄fixtures Fxx. |
| `07-performance-risk-plan.md` | PG-01–PG-10 verify con citation codice nell’audit. |
| `08-test-plan.md` | Test futuri slice. |
| `09-followup-slices.md` | Prioritized **S111-A…H backlog**. |
| `10-execution-audit-verdict.md` | Outcome EXECUTION-AUDIT (**≠ parity / DONE**) |

Durante PLANNING — **solo nomi/definizioni**.

---

## Evidence Hygiene & Privacy Rules *(per futura EXECUTION-AUDIT)*

| Regola | Dettaglio |
|--------|-----------|
| **EH-01** | Non usare dati reali del negozio nelle fixture o evidence **senza** consenso esplicito futuro. |
| **EH-02** | Redigere email, token, project ref sensibili se non già pubblici, path personali e barcode reali. |
| **EH-03** | Le screenshot future **non** devono mostrare dati commerciali reali o file personali. |
| **EH-04** | Le evidence devono distinguere chiaramente: `OBSERVED`, `INFERRED`, `ASSUMED`, `NOT_RUN`, `BLOCKED`. |
| **EH-05** | Nessun `PASS` senza comando/evidenza verificabile. |
| **EH-06** | Se una evidence deriva da **Android**, indicare che è **riferimento funzionale**, non prova che iOS sia conforme. |
| **EH-07** | Se una evidence deriva da **iOS**, indicare **file/metodo/linea** o snippet minimo redatto. |
| **EH-08** | Se Supabase è solo mappato, scrivere **`read-only / no mutation`**. |

**Regola:** le evidence TASK-111 devono essere utili per **implementare**, ma **non** devono diventare un archivio di dati reali o segreti.

---

## Fixture Plan *(privacy-safe, sintetiche — no dati negozio reali salvo futuro override esplicito)*  

| # | Profilo sintetico | Note |
|---|-------------------|------|
| F-01 | small clean `.xlsx` | baseline happy |
| F-02 | dirty header `.xlsx` | alias/BOM/multilingua rumor |
| F-03 | duplicated barcode `.xlsx` | **B-11** |
| F-04 | discount / **discountedPrice** `.xlsx` | **B-07,B-08** precedence |
| F-05 | supplier/category mixed case `.xlsx` | **B-10** |
| F-06 | old/current price cols `.xlsx` | **B-09 / history linkage** |
| F-07 | footer / subtotal `.xlsx` | righe parasite |
| F-08 | HTML colspan/rowspan export | parsing HTML stress |
| F-09 | legacy `.xls` **BIFF** | `ExcelLegacyReader` path risk |
| F-10 | large synthetic dataset `.xlsx` | perf/memory (**opt-in TASK harness future**) |
| F-11 | barcode **scientific notation** cells | regressione formato string ⇒ canonical ID |
| F-12 | **mixed locale** numbers EUR/US hybrid columns | regressione normalization EU vs US separators |

Naming convenuto es. `TASK111_FIX_*` — **privacy redaction obbligatoria**.

---

## Definition of Ready for future EXECUTION-AUDIT

TASK-111 può essere promosso da **PLANNING-REFINEMENT** a **EXECUTION-AUDIT** solo quando queste condizioni sono soddisfatte:

- [ ] **Utente** chiede esplicitamente di passare a **`EXECUTION-AUDIT`**.
- [ ] `MASTER-PLAN.md` è coerente: **TASK-111** unico ACTIVE; **TASK-109** resta **BLOCKED/SOSPESO**; **TASK-110** resta **DONE**.
- [ ] Il prompt audit vieta esplicitamente **patch Swift/Kotlin/SQL/Supabase/migration**.
- [ ] Il prompt audit richiede evidence **`00–10`**.
- [ ] Il prompt audit richiede **matrice M1–M28** compilata con **file/linee/snippet** (redatti dove serve).
- [ ] Il prompt audit richiede **Android behavior map B-01…B-17**.
- [ ] Il prompt audit richiede **privacy/evidence hygiene EH-01…EH-08**.
- [ ] Il prompt audit vieta claim **`parity`**, **`DONE`**, **`PASS runtime`** salvo **fase/evidenza appropriate** esplicitamente consentite nel prompt (**nessun PASS inventato**).

Se **uno** di questi punti manca, restare in **PLANNING** e **non avviare** audit operativo.

---

## EXECUTION-AUDIT Quality Bar *(da usare solo nel prossimo step autorizzato)*

Un futuro audit **read-only** TASK-111 sarà considerato **utile** solo se produce questi output minimi:

| Area | Quality bar |
|------|-------------|
| **iOS map** | Ogni feature M1–M28 ha almeno un file/metodo iOS candidato o **`ASSENTE` motivato**. |
| **Android map** | Ogni comportamento B-01…B-17 ha file/riga/snippet Kotlin o **`NOT_FOUND` motivato**. |
| **Supabase map** | Impatto sync/pending/conflict classificato come **`NO_IMPACT`**, **`FOLLOW_UP`**, o **`BLOCKED_DECISION`**. |
| **Gap** | Ogni gap ha priorità, severità, slice proposta e regression guard. |
| **UX** | Ogni gap UI ha scelta **iOS-native**, non «copia Android». |
| **Test plan** | Ogni **P0/Critical** ha almeno un test/fixture/regression guard **futuro** pianificato. |
| **Evidence hygiene** | Ogni evidence distingue **`OBSERVED`**, **`INFERRED`**, **`ASSUMED`**, **`NOT_RUN`**, **`BLOCKED`**. |
| **Verdict** | Il verdict finale **non** usa **`DONE`**, **`PASS`**, **`parity raggiunta`**; usa solo **`AUDIT_READY_FOR_REVIEW`** o **`AUDIT_INCOMPLETE`**. |

---

## Edge Case Catalogue *(≥ 30 scenari pianificatori — compilazione tecnica EXECUTION-AUDIT futura)*

1. Header su più righe / titoli foglio sopra tabella dati effettivi.  
2. Colonne fisiche invertite vs ordine “canonico” atteso tooling Android.  
3. Alias lingua mista (**IT/EN/ES**) stesso header-row.  
4. Header duplicati (due colonne stesso semantic label dopo norm).  
5. BOM UTF-8 + spazio invisibile / NBSP dentro title colonna.  
6. CRLF vs LF header export strani.  
7. Righe completamente vuote intra-body vs sentinel fine tabella differenziabili solo heuristica.  
8. Footer **TOTALE / SUBTOTAL** business labels.  
9. Righe aggregate categoria (**non SKU**) inside export retail.  
10. Barcode assente ma itemNumber forte (dual key policy).  
11. Barcode duplicati stesso worksheet post-normalization.  
12. Barcode **serializzato forma scientifica** (**1,23E+12** ecc).  
13. **Quantità numerica dentro string locale** migliaia (`.`,`’` separators messy).  
14. Prezzo con prefissi valuta (**€**) / suffissi.  
15. Sconto % vs valore monetario dichiarato inconsistenza (**B precedence** expectation).  
16. **discountedPrice** presente mentre purchase+sconto genera altro teorico ⇒ precedence (**B-08 audit** verify).  
17. Sheet workbook non-first / sheet rename localizzato.  
18. `.xls` limite storico BIT col count stretto ⇒ overflow column drop silent risk.  
19. HTML nesting table / rowspan/colspan erratic export vendor.  
20. Numeri italian format vs `en_US` `NumberFormatter` double parse hazard.  
21. Percentuali salvate excel come **fraction 0–1**.  
22. Numeri formato **Accounting** parentheses negative.  
23. Excel **date serial** accidentalmente dentro colonna qty/price textual cell.  
24. workbook quasi vuoto <2 righe contenuto ⇒ UX empty states (**UX plan**).  
25. unzip `.xlsx` **ZIP corrotto** / entry mancanti `sheet1.xml` / **`sharedStrings` sparse**.  
26. **`Celle formula`** con risultato numerico (**cached**) vs stale recalculation states.  
27. **Formula error cell** (**#DIV/0!**) propagates row classification.  
28. **Colonne nascoste** (`hidden`/`width=0`) contengono dati business critici ⇒ mapping ambig (**Ambiguous badges** UX).  
29. **Filtered rows visually hidden** pero ancora fisicamente in file export (**count skew** heuristic).  
30. **Newline dentro cell nome prodotto** / quote escaping CSV-like patterns.  
31. **Celle unite (merged)** nell’area header / body che rompono mapping colonna ⇒ rettangolo tabellare.  
32. Encoding **HTML dichiarato non UTF-8** / missing meta charsets ⇒ mojibake risk.  
33. Dataset huge row count ⇒ cancel mid-parse + memory plateau expectation (**performance planning** coupling **F-10**).  

*(Conteggio: **≥30** unicamente pianificatorio — **PASS/FAIL tecnici vietati ora**).*  

---

## Legacy / previous task reconciliation *(DIVIETO regressione tacita dopo IMPLEMENTATION futura)*

Il **futuro audit + implementazioni** **NON devono regressare**:

| Area Legacy | Checkpoint |
|-------------|-----------|
| Excel/HTML recognition | Harness **TASK storici**, `ExcelAnalyzerHTMLParsingTests.swift`, evidence TASK-104/105/106; **copertura header multi-format** |
| Large import offload | **TASK-105** commenti `ExcelSessionViewModel` offload / non-block MainActor regress |
| TASK-108 / Options jank starvation | starvation fixes **NON** undone accidentally da future import refactor (**PG-09 coupling**) |
| `ProductPrice` uniqueness/idempotenza | **TASK-087/088/080** uniqueness rules / cloud parity tests relevant locally |
| import/export **current/previous** price flows | TASK-030/039/041/070/079 + `ProductImportCore` expectations |
| Doppia logica `ExcelSessionViewModel` VS `ProductImportCore` (**+ frammenti `DatabaseView`**) | Convergenza tramite backlog **Unified Import Contract** nei future slice |
| Database UI polish import surface | regressione TASK-107/106/102 layout/import affordances (**non regress accessibility**) |
| Localizzazioni **EN / IT / ES / ZH(ZH-Hans)** se copy strings nuove import ux (**Localization coverage tests** awareness) |

**Regola:** citare sempre **COSA chiudere/non rompere** nel future doc `09` slices.

---

## Regression Lock List *(blocchi anti-regressione per futura IMPLEMENTATION)*

Questi punti devono diventare check espliciti in ogni futura micro-slice implementation:

| Lock | Non deve regredire |
|------|--------------------|
| RL-01 | Import Excel esistente da Home/Inventario. |
| RL-02 | Apertura file `.xlsx`, `.xls`, HTML già supportati. |
| RL-03 | Cronologia/Generated flow e ritorno navigazione. |
| RL-04 | Current/previous purchase/retail price. |
| RL-05 | ProductPrice idempotenza e dedupe. |
| RL-06 | Offload MainActor e assenza freeze già risolti. |
| RL-07 | Scanner barcode e search in Generated/Database. |
| RL-08 | Export/share Excel esistente. |
| RL-09 | Localizzazioni esistenti. |
| RL-10 | Supabase sync non toccata se la slice non è S111-H. |

---

## Failure / Recovery / Rollback Plan *(planning per futura apply)*

La futura implementation non deve limitarsi al caso felice. Prima di toccare apply/persistenza, il piano di slice deve specificare:

| Scenario | Comportamento atteso |
|----------|----------------------|
| Parser fallisce | Nessuna modifica DB; mostra errore leggibile; possibilità di scegliere altro file. |
| Mapping ambiguo | Nessuna modifica DB; override manuale o ritorno a PreGenerate. |
| Alcune righe invalide | Importare solo righe valide se utente conferma; errori esportabili. |
| Apply fallisce a metà | Transazione rollback o recovery documentato; nessun DB parziale silenzioso. |
| ProductPrice duplicate | Dedup/idempotenza; warning tecnico solo in evidence/log, UI comprensibile. |
| Supplier/category collision | Resolver deterministico; nessun duplicato case-insensitive. |
| Cancel utente | Stato finale coerente: nessuna scrittura o scritture già completate esplicitamente indicate. |

---

## Slice Sizing Rule

Per evitare mega-refactor:

- Ogni futura implementation slice deve toccare il minor numero ragionevole di file.
- Ogni slice deve avere test/regression guard propri.
- Una slice non deve contemporaneamente cambiare parser, UI, SwiftData apply e Supabase.
- Se una modifica richiede più di due aree critiche, dividerla in sub-slice.
- La priorità deve seguire: **correttezza dati → integrità prezzi → performance → UX operativa → polish**.

---

## Risk Register *(planning centralizzato)*

| Risk ID | Rischio | Impatto | Mitigazione pianificata |
|---------|---------|---------|--------------------------|
| R-111-01 | Doppia logica iOS fra Excel session e ProductImportCore. | Bug divergenti fra import inventario e import DB. | Unified Import Contract + evidence `01` / `04`. |
| R-111-02 | Porting Android troppo letterale. | UX non nativa, codice Swift difficile da mantenere. | UX iOS-native + architecture boundaries. |
| R-111-03 | Parser corregge un formato ma rompe `.xls`/HTML esistenti. | Regressione file reali storici. | Fixture F-08/F-09 + Regression Lock RL-02. |
| R-111-04 | ProductPrice duplicato o perso. | Perdita audit prezzi/current-previous. | `ProductPriceMutationPlan` + RL-04 / RL-05. |
| R-111-05 | Apply parziale non spiegato. | DB incoerente e operatore non sa cosa è successo. | Failure / Recovery / Rollback plan. |
| R-111-06 | Large dataset blocca MainActor. | Freeze UI/tap accodati. | PG-01…PG-10 + KPI audit. |
| R-111-07 | UX ImportAnalysis troppo densa. | Operatore non capisce cosa confermare. | Operator-first hierarchy + chips/summary. |
| R-111-08 | Supabase toccato indirettamente. | Regressione sync TASK-109 / TASK-110. | S111-H gated, RL-10, no mutation in TASK-111 planning/audit read-only. |
| R-111-09 | Evidence con dati sensibili. | Privacy/security regression. | EH-01…EH-08. |
| R-111-10 | Mega-refactor durante implementation. | Alto rischio regressione e review difficile. | Slice Sizing Rule. |
| R-111-11 | Claim parity prematuro dopo solo audit. | Falsa sicurezza e regressioni non rilevate. | Parity Claim Ladder L0–L4. |
| R-111-12 | Decisioni business prese implicitamente durante patch. | Comportamenti incoerenti fra iOS/Android. | Default Decision Rules + **Decision Needed**. |
| R-111-13 | UX polish migliora estetica ma rallenta operatività. | Import più bello ma meno efficiente in negozio. | UX operator-first + **UX Acceptance Checklist**. |

---

## File iOS/Android di riferimento *(planning path — dettaglio = evidence `01/02`)*  

**Android modulo base:** `com/example/merchandisecontrolsplitview/…`

`ExcelUtils.kt`, `ExcelViewModel.kt`, `util/ImportAnalysis.kt`, `data/ImportAnalysis.kt`, `ImportAnalysisScreen.kt`, `PreGenerateScreen.kt`, `GeneratedScreen.kt` (+dialogs), `DatabaseViewModel.kt`, `InventoryRepository.kt`, `ProductUpdate.kt`, `RowImportError.kt`, `ProductPriceSummary.kt`, `ZoomableExcelGrid.kt`, `TableCell.kt`, tests: `ExcelUtilsTest`, `ExcelViewModelTest`, `ImportAnalyzerTest`, `FullDbExportImportRoundTripTest`.

**iOS — percorsi chiave pianificatori** (lista non esaustiva):

| Area | Path |
|------|------|
| Home / file picker | `InventoryHomeView.swift` |
| PreGenerate | `PreGenerateView.swift` |
| Parser Excel sessione | `ExcelSessionViewModel.swift` (`ExcelAnalyzer`) |
| Legacy `.xls` | `ExcelLegacyReader.m` / `.h`, bridging header |
| Inventario foglio | `GeneratedView.swift` |
| Import prodotti (Database) | `ImportAnalysisView.swift`, `ProductImportViewModel.swift`, `ProductImportCore.swift` |
| Tab Database shell | `DatabaseView.swift` |
| Sync inventario→catalogo | `InventorySyncService.swift`, `InventoryXLSXExporter.swift` |
| Modelli SwiftData | `Models.swift`, `HistoryEntry.swift`, container `iOSMerchandiseControlApp.swift` |
| Test rilevanti | `ExcelAnalyzerHTMLParsingTests.swift`, harness/Task tests che toccano `ExcelAnalyzer` / `ProductImportCore` |

Dettaglio call graph ⇒ futura **`01-ios-code-map.md`** (EXECUTION-AUDIT).

---

## Matrice parity **M1–M28** *(struttura — valori rimangono **TBD** finché EXECUTION-AUDIT compilata)*

> Tutte le colonne **obbligatorie**:  
> Feature / capability · Stato iOS · Stato Android · Gap · Priorità · Rischio · File iOS candidati · File Android riferimento · **Evidence futura** · Decisione consigliata · Slice · Regression guard

| # | Feature / capability | Stato iOS | Stato Android | Gap | Priorità | Rischio | File iOS candidati | File Android riferimento | Evidence futura | Decisione consigliata | Slice | Regression guard |
|---|----------------------|-----------|---------------|-----|----------|---------|-------------------|---------------------------|----------------|----------------------|-------|------------------|
| M1 | Home avvio foglio Excel | **TBD** | **TBD** | **TBD** | P0 | alto | `InventoryHomeView.swift`, `ExcelSessionViewModel.swift` | `PreGenerateScreen.kt`, VM | `04-parity-matrix-filled.md` (**post audit**) | **TBD** | S111-D | Flusso **Inventario** baseline |
| M2 | FileImporter / reopen / security-scope | **TBD** | **TBD** | **TBD** | P0 | medio | Views + `DatabaseView.swift` | Android picker/nav | ↑ | **TBD** | S111-D | URL bookmark regress |
| M3 | Parse `.xlsx` | **TBD** | **TBD** | **TBD** | P0 | medio | `ExcelSessionViewModel.swift` | `ExcelUtils.kt` | ↑ | **TBD** | S111-A; S111-F | **PG-01** |
| M4 | Parse `.xls` legacy | **TBD** | **TBD** | **TBD** | P0 | legacy | `ExcelLegacyReader.*` | Kotlin utils | ↑ | **TBD** | S111-A; S111-F | Buffer safety |
| M5 | Parse HTML/export | **TBD** | **TBD** | **TBD** | P1 | dati sporci | `ExcelSessionViewModel.swift`, tests HTML | Parser Android | ↑ | **TBD** | S111-A; S111-G | **ExcelAnalyzer HTML tests** lineage |
| M6 | Header canonical + alias ML | **TBD** | **TBD** | **TBD** | P0 | alto parsing | Analyzer | `ExcelUtils.kt` | ↑ | **TBD** | S111-A | **CanonicalHeaderMapping** |
| M7 | Colonne obblig./optional | **TBD** | **TBD** | **TBD** | P0 | blocco | Analyzer + importing cores | Analyzer | ↑ | **TBD** | S111-A; S111-B | **B-01,B-02** |
| M8 | PreGenerate preview/colonne | **TBD** | **TBD** | **TBD** | P1 | medio UX | `PreGenerateView.swift` | `PreGenerateScreen.kt` | ↑ | **TBD** | S111-D | Badge header quality |
| M9 | Toggle colonne inclusive | **TBD** | **TBD** | **TBD** | P1 | medio | `PreGenerateView.swift` | idem | ↑ | **TBD** | S111-D | Stato persisted session |
| M10 | Supplier/category (file/UI) | **TBD** | **TBD** | **TBD** | P1 | medio | Views + importer | Screens | ↑ | **TBD** | S111-E | **B-10 resolver** |
| M11 | Qty/prices/discount/discountPrice | **TBD** | **TBD** | **TBD** | P0 | alto business | `GeneratedView.swift`, analyzer | `TableCell.kt` / excel VM | ↑ | **TBD** | S111-B; S111-C | **B-07,B-08** precedence |
| M12 | Vecchi prezzi ACQ/VEN | **TBD** | **TBD** | **TBD** | P0 | storico | VM + Models | summaries | ↑ | **TBD** | S111-B; S111-E | **B-09** lineage |
| M13 | Nomi / barcode / itemNumber | **TBD** | **TBD** | **TBD** | P0 | ID forte | Analyzer + models | Kotlin models | ↑ | **TBD** | S111-B | barcode sci (**F-11**) |
| M14 | Righe vuote/footer/subtotal | **TBD** | **TBD** | **TBD** | P0 | corruptions | Analyzer + GV | historic Android TASK-043 | ↑ | **TBD** | S111-A; S111-C | PreGenerate sentinel warnings UX |
| M15 | Policy duplicati barcode | **TBD** | **TBD** | **TBD** | P0 | merge | GV + analyzer | Utils | ↑ | **TBD** | S111-C | **B-11** |
| M16 | Merge qty duplicate aggregated | **TBD** | **TBD** | **TBD** | P0 | alto | GV + svc | Repo | ↑ | **TBD** | S111-C; S111-E | qty truth inventories |
| M17 | Errori righe / export UX | **TBD** | **TBD** | **TBD** | P1 | ops UX | Import surface | Errors types (`RowImportError`) | ↑ | **TBD** | S111-C; S111-D | **B-12 / B-17** |
| M18 | Warnings UX / export secondario | **TBD** | **TBD** | **TBD** | P1 | trust UX | importer | Analyzer | ↑ | **TBD** | S111-C; S111-D | **B-16,B-17** |
| M19 | ImportAnalysis new/updated/edit UX | **TBD** | **TBD** | **TBD** | P0 | parity funzionale | `ImportAnalysisView.swift` | `ImportAnalysisScreen.kt` | ↑ | **TBD** | S111-D; S111-E | Summary card UX (**ImportAnalysis**) |
| M20 | Apply preview SE-free (**B-15**) | **TBD** | **TBD** | **TBD** | P0 | data safety critico | Product import core preview | Preview models Kotlin | ↑ | **TBD** | S111-E | **ImportApplyPlan** |
| M21 | Apply atomico/rollback-safe | **TBD** | **TBD** | **TBD** | P0 | integrità | SwiftData transactional path | Repo Kotlin transactional | ↑ | **TBD** | S111-E | **SwiftDataApplyTransaction verify** |
| M22 | `ProductPrice` history post-import (**B-14**) | **TBD** | **TBD** | **TBD** | P0 | audit finanziario | Modelli/tests prezzi Swift | Repo apply Kotlin | ↑ | **TBD** | S111-E | Unique constraints |
| M23 | Supplier/category create/map | **TBD** | **TBD** | **TBD** | P1 | referential integrity | Resolver layer Swift | Repo Kotlin | ↑ | **TBD** | S111-E | Pending vs TASK-109 |
| M24 | Performance grandi dataset | **TBD** | **TBD** | **TBD** | P0 | OOM/lag | `ExcelSessionViewModel.swift`, worker paths | `FullDbImportStreaming.kt`, utilities import | ↑ | **TBD** | S111-F | TASK-100/105; PG-01/PG-08 |
| M25 | Streaming/memory parse apply | **TBD** | **TBD** | **TBD** | P0 | crash | Parser iOS (`ExcelAnalyzer`…) | Streaming Android correlate | ↑ | **TBD** | S111-F | PG-05; PG-06 |
| M26 | Progress/cancel/err states UX | **TBD** | **TBD** | **TBD** | P1 | UX/trust | VM + UI Swift | VM + UI Compose (ref.) | ↑ | **TBD** | S111-D; S111-F | PG-04; PG-09 |
| M27 | Test harness regressione | **TBD** | **TBD** | **TBD** | P0 | meta | `iOSMerchandiseControlTests/` (Excel/import) | `ExcelUtilsTest`, `ImportAnalyzerTest`, ecc. | ↑ | **TBD** | S111-G | Harness TASK legacy |
| M28 | Supabase/sync interplay | pianificatore | pianificatore | roadmap | P2 | arch | tipi pending iOS (**solo read map**) | doc schema/read | `03-supabase-impact-map.md` | gated | S111-H | TASK-109 BLOCKED segregato |

**Regola chiave**: **mai** compilare stato `PASS/` `FAIL` tecnici dentro questa matrice prima EXECUTION-AUDIT — **`TBD` only**.

---

### Micro-slice implementazione (**S111-A … S111-H**) — EXECUTION-IMPLEMENTATION **post-audit autorizzato**

| ID | Contenuto |
|----|-----------|
| S111-A | Parser/canonical/header/HTML/xls |
| S111-B | Numeric/pricing/discounts/history columns |
| S111-C | Duplicates/issue/warning/export |
| S111-D | ImportAnalysis UX + PreGenerate badges + Generated native parity |
| S111-E | Apply preview (B15) atomic history supplier resolver |
| S111-F | Perf PG / chunking throttle cancel SwiftData correctness |
| S111-G | Fixture F01–12 + regress tests |
| S111-H | Supabase interplay **solo** dopo decisione progetto (**TASK-109** OUT unless reopened) |

---

## Acceptance Criteria — **PLANNING-REFINEMENT** *(presente aggiornamento documentale)*

- [x] **PA-111-01**: Android riferimento funzionale, iOS target SwiftUI/SwiftData — **SAT (testo task)**  
- [x] **PA-111-02**: **Fase corrente PLANNING**, non execution operativa sistematica né implementation — **SAT**  
- [x] **PA-111-03**: distinzione formale fra **PLANNING-REFINEMENT**, **EXECUTION-AUDIT**, **EXECUTION-IMPLEMENTATION**, **REVIEW** — **SAT (tabella + charter)**  
- [x] **PA-111-04**: UX iOS-native documentate (**ImportAnalysis/PreGenerate/Generated**) — **SAT struttura** *(gap tecnici TBD EXECUTION)*  
- [x] **PA-111-05**: Android behavior contract (**B-01–B-17**) — **SAT struttura** *(verifica codice dopo prompt audit)*  
- [x] **PA-111-06**: Unified Import Contract (**10 concetti**) + audit expected outputs — **SAT**  
- [x] **PA-111-07**: Gates performance (**PG-01–PG-10**) — **SAT**  
- [x] **PA-111-08**: Matrice **M** con **12 colonne obbligatorie** + skeleton **TBD** — **SAT**  
- [x] **PA-111-09**: Lista evidence **`00–10`** definita (**non compilata / non dichiarati filled**) — **SAT**  
- [x] **PA-111-10**: Edge catalog **≥30** **+ fixture plan** privacy-safe (**F01–F12**) — **SAT**  
- [x] **PA-111-11**: Legacy reconciliation documented — **SAT** *(tab legacy)*  
- [x] **PA-111-12**: Nessun `.swift`/`.kt`/SQL modificato in questo refactor — da verifica `git status` dopo edit (**solo Markdown atteso**)  
- [x] **PA-111-13**: No parity/DONE/PASS dichiarazioni — **SAT** *(testo vietato sopra ripetuto)*  
- [x] **PA-111-14**: MASTER-PLAN coerente con **TASK-111 ACTIVE / PLANNING-REFINEMENT** — **SAT** (patch MASTER applicata in questo batch)
- [x] **PA-111-15**: Priority/severity scoring aggiunto per evitare classificazioni arbitrarie in audit futuro.  
- [x] **PA-111-16**: UX operator-first e UI polish guardrails documentati.  
- [x] **PA-111-17**: Regression Lock List definita.  
- [x] **PA-111-18**: Failure / Recovery / Rollback Plan definito a livello planning.  
- [x] **PA-111-19**: Slice Sizing Rule definita per evitare mega-refactor.  
- [x] **PA-111-20**: Audit KPI minimi definiti per performance/responsiveness futura.  
- [x] **PA-111-21**: iOS Architecture Boundaries documentati per evitare business logic nelle View.  
- [x] **PA-111-22**: Evidence Hygiene & Privacy Rules definite.  
- [x] **PA-111-23**: Definition of Ready per futura EXECUTION-AUDIT definita.  
- [x] **PA-111-24**: Risk Register centralizzato aggiunto.  
- [x] **PA-111-25**: Chiarito che la promozione a Execution richiede prompt futuro esplicito e non deriva da questo piano.  
- [x] **PA-111-26**: Parity Claim Ladder aggiunta per impedire claim prematuri.  
- [x] **PA-111-27**: Default Decision Rules aggiunte per gestire differenze Android/iOS senza blocchi arbitrari.  
- [x] **PA-111-28**: EXECUTION-AUDIT Quality Bar definita.  
- [x] **PA-111-29**: UX Acceptance Checklist futura aggiunta.  
- [x] **PA-111-30**: Risk Register esteso con claim parity, decisioni implicite e UX polish risk.  

*(PA-111-12 verificabile localmente dall’operatore tramite scope diff docs-only)*  

---

## Handoff *(PLANNING-REFINEMENT — stato corrente)*  

| Campo | Valore |
|-------|--------|
| **Gate attuale** | **Planning refinement completo sul documento** — **EXECUTION vietata tacitamente.** |
| **Prossimo passo tecnico AUTORIZZATO solo con nuovo PROMPT UTENTE** | **EXECUTION-AUDIT** read-only (compilazione evidence **`00–10`** + matrice M real values). |
| **Vietato senza nuovo comando** | Modificare Swift/Kotlin; eseguire build/test obbligatori; implementare UX; dichiarare parity. |
| **Nota planning refinement aggiuntiva** | Il piano ora contiene criteri di priorità, anti-regressione, UX operator-first, failure/recovery e KPI audit; resta comunque **non-esecutivo**. |
| **Nota finale integrazione** | Aggiunti anche boundary architetturali iOS, privacy/evidence hygiene, Definition of Ready audit e risk register; TASK-111 resta **PLANNING-REFINEMENT**. |
| **Nota finale qualità** | Aggiunti **Parity Claim Ladder**, **Default Decision Rules**, **EXECUTION-AUDIT Quality Bar** e **UX Acceptance Checklist**; **nessun** passaggio a Execution è implicito. |
| **Responsabile prossima fase (post prompt audit)** tipicamente | **CURSOR / Executor-Auditor** (**read-only**) oppure incaricato dall’owner — **NON pre-assegnato operativamente in questa PLANNING.** |

*(Sezione FORMALE **Execution**/ **Fix**/ **Codex**: **Vuota — fino EXECUTION post-prompt IMPLEMENTATION.**)*  

---

## Execution / Codex

### Esecuzione — 2026-05-17 12:20 -0400

**User override registrato:**
- Il prompt utente corrente autorizza TASK-111 **ACTIVE / EXECUTION end-to-end**, superando il precedente blocco PLANNING-REFINEMENT.
- Responsabile execution: **CURSOR / Executor**.
- TASK-109 resta **BLOCKED / SOSPESO**.
- TASK-110 resta **DONE**.
- Esito finale ammesso: **ACTIVE / REVIEW** oppure **ACTIVE / FIX** se emergono blocker tecnici reali; **non DONE**.

**File modificati finora:**
- `docs/MASTER-PLAN.md` — tracking globale aggiornato a TASK-111 ACTIVE / EXECUTION con override utente e dirty state iniziale.
- `docs/TASKS/TASK-111-excel-analysis-parity-ios.md` — metadati task aggiornati a EXECUTION e override registrato.
- `docs/TASKS/EVIDENCE/TASK-111/README.md` — stato evidence aggiornato da planning-only a execution.
- `docs/TASKS/EVIDENCE/TASK-111/00-preflight-tracking.md` — preflight branch/HEAD/git status/vincoli/dati Supabase/piano onde.

**Azioni eseguite:**
1. Letti MASTER-PLAN iOS, TASK-111 e README evidence TASK-111.
2. Verificato che il task file non e' nel repo Android e che il target operativo corretto e' il repo iOS locale.
3. Letti AGENTS/protocollo iOS e skill SwiftUI/iOS rilevanti.
4. Eseguito preflight git iOS/Android/Supabase locale.
5. Aggiornato tracking documentale prima di modifiche runtime.

**Check obbligatori (stato iniziale):**
| Check | Stato | Note |
|---|---|---|
| Build Xcode | ❌ NON ESEGUITO | Preflight/tracking-only; build da eseguire dopo audit/implementation. |
| Warning nuovi | ⚠️ NON ESEGUIBILE | Nessuna modifica runtime/Swift ancora applicata. |
| Coerenza con planning | ✅ ESEGUITO | Override utente esplicito registrato; tracking coerente con EXECUTION. |
| Criteri di accettazione | ❌ NON ESEGUITO | Verranno verificati dopo audit/implementation/test. |

**Incertezze:**
- Il repo Supabase locale indicato e' una directory senza `.git` nel root; resta utilizzabile come riferimento locale/documentale, ma non ha branch/HEAD.
- Il worktree iOS era gia' dirty con modifiche documentali TASK-111 prima dell'execution; trattate come baseline corrente senza revert.

**Handoff notes provvisorie:**
- Nessun handoff finale ancora: execution in corso.

### Esecuzione — 2026-05-17 12:50 -0400

**Esito execution:**
- TASK-111 passa a **ACTIVE / REVIEW**.
- **Non DONE**: serve review finale e conferma utente.
- TASK-109 resta **BLOCKED / SOSPESO**.
- TASK-110 resta **DONE**.

**File modificati:**
- `iOSMerchandiseControl/ProductImportCore.swift` — parser numerico/header alias, validazioni, duplicati, old/current price history, resolver supplier/category case-insensitive.
- `iOSMerchandiseControl/ImportAnalysisView.swift` — draft old price, summary rows, filter chips, sticky CTA, warning export, duplicate policy, edit preservation.
- `iOSMerchandiseControl/ProductPriceHistoryView.swift` — label UX per source `IMPORT_PREV`.
- `iOSMerchandiseControl/en.lproj/Localizable.strings` — nuove stringhe import/history.
- `iOSMerchandiseControl/it.lproj/Localizable.strings` — nuove stringhe import/history.
- `iOSMerchandiseControl/es.lproj/Localizable.strings` — nuove stringhe import/history.
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings` — nuove stringhe import/history.
- `iOSMerchandiseControlTests/Task111ExcelImportParityTests.swift` — test parser/import/apply/ProductPrice/fixture HTML TASK-111.
- `iOSMerchandiseControlTests/Fixtures/TASK-111/README.md` — note fixture privacy-safe.
- `iOSMerchandiseControlTests/Fixtures/TASK-111/html-colspan-rowspan-import.html` — fixture HTML sintetica.
- `docs/TASKS/EVIDENCE/TASK-111/00-preflight-tracking.md` — preflight.
- `docs/TASKS/EVIDENCE/TASK-111/01-ios-code-map.md` … `12-regression-locks.md` — evidence audit/implementation/test/regression.
- `docs/TASKS/EVIDENCE/TASK-111/README.md` — evidence pack aggiornato.
- `docs/MASTER-PLAN.md` — tracking da aggiornare a REVIEW nel final pass.
- `docs/TASKS/TASK-111-excel-analysis-parity-ios.md` — log execution e stato REVIEW.

**Azioni eseguite:**
1. Audit iOS/Android/Supabase compilato in evidence `01`-`03`.
2. Matrice M1-M28 compilata in `04-parity-matrix-filled.md`.
3. Implementate slice S111-A/B/C/D/E/F/G/H dove applicabili senza migration/scope creep.
4. Aggiunti test TASK-111 privacy-safe e fixture HTML sintetica.
5. Eseguiti build Debug/Release, XCTest mirati, regression baseline, smoke simulator Home/Database/Options.
6. Supabase non mutato; TASK-109 non riaperto.

**Check obbligatori:**
| Check | Stato | Note |
|---|---|---|
| Build Xcode Debug | ✅ ESEGUITO | PASS simulator, 0 warnings (`build_sim_2026-05-17T16-48-35...`). |
| Build Xcode Release | ✅ ESEGUITO | PASS simulator, 0 warnings (`build_sim_2026-05-17T16-41-55...`). |
| Warning nuovi | ✅ ESEGUITO | Warning Swift 6 iniziali eliminati; build/test finali senza warning nel perimetro eseguito. |
| Coerenza con planning | ✅ ESEGUITO | Modifiche limitate a Excel/import iOS, tests, localizzazioni, evidence. |
| Criteri di accettazione | ✅ ESEGUITO | Vedi tabella sotto; review ancora richiesta, non DONE. |

**Criteri finali Execution:**
| Criterio | Stato | Evidenza |
|---|---|---|
| M1-M28 compilate | ESEGUITO | `04-parity-matrix-filled.md`. |
| P0/Critical risolti o motivati | ESEGUITO | Parser/numeri/validazioni/duplicati/history/resolver coperti; `.xls` runtime resta P2 non blocker. |
| Parser/header/numeri/prezzi/duplicati/apply testati | ESEGUITO | `Task111ExcelImportParityTests` 7/7 PASS. |
| ProductPrice history coerente | ESEGUITO | `testProductPriceHistoryRecordsPreviousAndCurrentImportPricesIdempotently`. |
| Preview side-effect-free | ESEGUITO | `testExistingProductPreviewMergesSparseUpdatesWithoutSideEffects`. |
| Apply atomico/recovery documentato | ESEGUITO | `07-performance-risk-plan.md`, `04` M25; SwiftData recovery existing documented. |
| UX ImportAnalysis rifinita | ESEGUITO | Summary/filter/sticky CTA/export warnings/localization. |
| PreGenerate/Generated preservati | ESEGUITO | Audit no regression; no unnecessary patch. |
| Performance/MainActor non regredisce | ESEGUITO | TASK-100/TASK-105 benchmark regressions PASS; background pipeline audit. |
| RL-01…RL-10 | ESEGUITO | `12-regression-locks.md`. |
| Build/test principali | ESEGUITO | Debug/Release + targeted/regression PASS. |
| Evidence completa | ESEGUITO | Evidence `00`-`12`. |
| Nessun dato sensibile esposto | ESEGUITO | Solo synthetic TASK111 data; no Supabase/log secrets. |

**Test eseguiti:**
- Debug build simulator: PASS, 0 warnings.
- Release build simulator: PASS, 0 warnings.
- `Task111ExcelImportParityTests`: PASS 7/7.
- TASK-105 selected import/export/apply/performance: PASS 4/4.
- `ExcelAnalyzerHTMLParsingTests` + TASK-100 medium import/ProductPrice benchmarks: PASS 11/11.
- Simulator smoke: Home, Database, Options reachable/responsive.

**Baseline regressione TASK-004 / equivalente iOS:**
- Non applicabile come label Android TASK-004; per iOS sono stati eseguiti test unitari/SwiftData/HTML/performance equivalenti nel perimetro import/export/ProductPrice.
- Test aggiunti: `Task111ExcelImportParityTests`.
- Limiti residui: full suite, `.xls` runtime e cancel manuale non eseguiti.

**Incertezze / limiti:**
- NOT_RUN: full manual Files picker import, real device, Dynamic Type/VoiceOver manual, live Supabase, Android build/test (nessun Android patch).
- `.xls` legacy path auditato/buildato ma non verificato con fixture binaria TASK-111.

**Handoff notes:**
- Reviewer deve trattare lo stato come **ACTIVE / REVIEW**, non DONE.
- Focus review: `ProductImportCore` semantics, ImportAnalysis UX, ProductPrice idempotence, `.xls`/cancel/Dynamic Type limiti non bloccanti.

---

## Review (CLAUDE)

### Review finale — 2026-05-17 13:53 -0400

**Verdict:** **REVIEW PASS WITH NOTES**  
**Stato finale:** **DONE / Chiusura — REVIEW PASS WITH NOTES**

**Evidence review compilate:**
- `docs/TASKS/EVIDENCE/TASK-111/13-review-preflight.md`
- `docs/TASKS/EVIDENCE/TASK-111/14-review-code-quality.md`
- `docs/TASKS/EVIDENCE/TASK-111/15-review-test-results.md`
- `docs/TASKS/EVIDENCE/TASK-111/16-review-ux-performance.md`
- `docs/TASKS/EVIDENCE/TASK-111/17-review-final-verdict.md`

**Problemi trovati e corretti direttamente:**
1. `DatabaseView` rimappava tutti gli errori row-level a barcode mancante: ora conserva `reasonKeys` reali.
2. `ProductImportCore` esponeva messaggi errore hardcoded in italiano: ora usa localization keys EN/IT/ES/ZH.
3. `totalInputRows` non veniva propagato nei flussi Database import analysis: ora e' incluso nel payload.
4. Summary supplier/category poteva contare duplicati case-insensitive: ora usa `normalizedRelationKey`.
5. Copy nuovo IT/ES rifinito per evitare gergo "warning" e accenti mancanti.

**Test finali review:**
| Check | Stato | Evidenza |
|---|---|---|
| Release build simulator | ✅ ESEGUITO | PASS, 0 diagnostics MCP (`build_sim_2026-05-17T17-55-49-146Z_pid85616_71446b68.log`). |
| Debug build simulator | ✅ ESEGUITO | PASS, 0 diagnostics MCP (`build_sim_2026-05-17T17-55-57-450Z_pid85616_a98ba0b4.log`). |
| Release build + run simulator | ✅ ESEGUITO | PASS, 0 diagnostics MCP (`build_run_sim_2026-05-17T17-56-57-479Z_pid85616_9c74a4bf.log`). |
| `Task111ExcelImportParityTests` | ✅ ESEGUITO | PASS 8/8 (`test_sim_2026-05-17T17-56-19-127Z_pid85616_0b1a4f82.log`). |
| Regressione import/export/ProductPrice/performance selezionata | ✅ ESEGUITO | PASS 17/17 (`test_sim_2026-05-17T17-49-14-770Z_pid85616_ba3af84c.log`). |
| Localizzazioni EN/IT/ES/ZH | ✅ ESEGUITO | `plutil -lint` PASS. |
| Static patch | ✅ ESEGUITO | `git diff --check` PASS. |
| Smoke simulator | ✅ ESEGUITO | Home, Database, import entry point, Options raggiungibili senza crash. |
| Privacy/secret scan | ✅ ESEGUITO | Nessun token/JWT/password/email reale nei file TASK-111 scansionati; match solo policy/evidence. |

**Limiti residui non bloccanti:**
- `.xls` binario reale non eseguito runtime.
- Full Files picker import con file reale non eseguito end-to-end.
- Dynamic Type e VoiceOver manuali non eseguiti; snapshot/accessibility hierarchy base verificata.
- Real device non eseguito.
- Live Supabase non eseguito perche' fuori perimetro locale TASK-111.

**Supabase / Android:**
- Supabase: **NO MUTATION / NO IMPACT**.
- Android: **REFERENCE-ONLY / NO PATCH**.

### Chiusura — REVIEW PASS WITH NOTES

Tutti i blocker emersi in review sono stati corretti e ritestati. I limiti residui sono esplicitamente documentati e non bloccano la chiusura del task nel perimetro TASK-111. TASK-109 resta **BLOCKED / SOSPESO**; TASK-110 resta **DONE**.

---

## FIX / Codex EXECUTION IMPLEMENTATION  

I fix applicati direttamente durante la review sono documentati in `docs/TASKS/EVIDENCE/TASK-111/14-review-code-quality.md` e nella sezione Review sopra.

### Micro-fix post-review — 2026-05-17 14:35 -0400

**User override registrato:**
- TASK-111 era gia' **DONE / Chiusura — REVIEW PASS WITH NOTES**.
- L'utente ha richiesto una micro-correzione coerente con il perimetro Excel/import parity, senza aprire TASK-112.
- Interpretazione operativa: **TASK-111 MICRO-FIX / post-review adjustment**.
- TASK-109 resta **BLOCKED / SOSPESO**.
- TASK-110 resta **DONE**.

**File modificati:**
- `iOSMerchandiseControl/ExcelSessionViewModel.swift` — default selezione colonne testabile: riconosciute/obbligatorie ON, non identificate OFF; cambio ruolo riconosciuto porta ON, clear/unknown porta OFF se non essenziale; preview indices separati dalla selezione.
- `iOSMerchandiseControl/PreGenerateView.swift` — preview rapida su tutte le colonne, non solo su quelle selezionate.
- `iOSMerchandiseControlTests/Task111ExcelImportParityTests.swift` — test micro-fix per default ON/OFF, toggle manuale, cambio tipo, generazione e preview.
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/main/java/com/example/merchandisecontrolsplitview/viewmodel/ExcelViewModel.kt` — default `selectedColumns` iniziale derivato da header/headerSource; essenziali protette; set/restore tipo aggiorna ON/OFF.
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/test/java/com/example/merchandisecontrolsplitview/viewmodel/ExcelViewModelTest.kt` — test Android per default OFF unknown, default ON recognized/required, toggle manuale e generazione senza unknown OFF.
- `docs/TASKS/EVIDENCE/TASK-111/18-post-review-column-default-selection.md` — evidence micro-fix.
- `docs/TASKS/EVIDENCE/TASK-111/README.md` — indice evidence aggiornato con `18`.
- `docs/TASKS/TASK-111-excel-analysis-parity-ios.md` — tracking micro-fix.
- `docs/MASTER-PLAN.md` — tracking globale micro-fix.

**Azioni eseguite:**
1. Controllati i punti PreGenerate iOS/Android in cui viene inizializzato o consumato lo stato colonne.
2. Spostata la regola di default nei ViewModel/helper testabili, non nelle View.
3. Mantenuta la preview visibile per tutte le colonne: iOS ora usa indici preview separati; Android era gia' full-preview e non ha richiesto patch UI.
4. Verificato che la generazione continui a usare solo le colonne selezionate.
5. Aggiornati test mirati e evidence.

**Check obbligatori / richiesti:**
| Check | Stato | Note |
|---|---|---|
| iOS Debug build simulator | ✅ ESEGUITO | PASS, 0 warnings/errors MCP (`build_sim_2026-05-17T18-30-15-066Z_pid95761_a688e4f3.log`). |
| iOS Release build simulator | ✅ ESEGUITO | PASS, 0 warnings/errors MCP (`build_sim_2026-05-17T18-32-14-314Z_pid95761_8a402d2d.log`). |
| iOS `Task111ExcelImportParityTests` | ✅ ESEGUITO | PASS 9/9 (`test_sim_2026-05-17T18-31-36-785Z_pid95761_a382701a.log`). |
| iOS Excel/header tests | ✅ ESEGUITO | `ExcelAnalyzerHTMLParsingTests` PASS 9/9 (`test_sim_2026-05-17T18-33-55-254Z_pid95761_fa1ff99e.log`). |
| iOS `git diff --check` | ✅ ESEGUITO | PASS, exit 0. |
| iOS `plutil -lint` localizzazioni | ✅ ESEGUITO | EN/IT/ES/ZH PASS. |
| Android `assembleDebug` | ✅ ESEGUITO | BUILD SUCCESSFUL in 3s. |
| Android test mirato `ExcelViewModelTest` | ✅ ESEGUITO | BUILD SUCCESSFUL in 13s. |
| Android test header/parser `ExcelUtilsTest` | ✅ ESEGUITO | BUILD SUCCESSFUL in 5s. |
| Android `lint` | ✅ ESEGUITO | BUILD SUCCESSFUL in 40s. Warning Gradle/AGP preesistenti di toolchain, nessun warning Kotlin nuovo dal codice modificato. |
| Android `git diff --check` | ✅ ESEGUITO | PASS, exit 0. |
| Coerenza con planning/perimetro | ✅ ESEGUITO | Solo Excel/PreGenerate/default selection + test/evidence. Nessun DAO/repository/navigation/Supabase. |
| Criteri micro-fix | ✅ ESEGUITO | Vedi evidence `18-post-review-column-default-selection.md`. |

**Criteri micro-fix verificati:**
| Criterio | Stato | Evidenza |
|---|---|---|
| Colonne riconosciute ON default | ESEGUITO | iOS/Android test mirati. |
| Colonne obbligatorie ON/protette | ESEGUITO | iOS/Android test mirati; Android toggle essenziale forza ON. |
| Colonne non identificate OFF default | ESEGUITO | iOS `internalnote`, Android `Internal note`. |
| Colonne non identificate visibili in preview/lista | ESEGUITO | iOS preview indices full; Android preview/lista gia' full. |
| Utente puo' riattivare manualmente | ESEGUITO | iOS `updateColumnSelection`; Android `toggleColumnSelection`. |
| Cambio manuale a tipo riconosciuto seleziona | ESEGUITO | iOS `setColumnRole`; Android `setHeaderType`. |
| Cambio a non identificata spegne se non obbligatoria | ESEGUITO | iOS `clearColumnRole`; Android `restoreOriginalHeader`. |
| Generazione esclude unknown lasciata OFF | ESEGUITO | iOS/Android test su header generato. |

**Baseline regressione TASK-004 / equivalente:**
- iOS: `Task111ExcelImportParityTests` + `ExcelAnalyzerHTMLParsingTests`.
- Android: `ExcelViewModelTest` + `ExcelUtilsTest`; `assembleDebug`, `lint`.
- Test aggiunti/aggiornati: iOS `Task111ExcelImportParityTests`, Android `ExcelViewModelTest`.
- Limiti residui: nessun nuovo smoke manuale Files picker/device reale; non necessario per micro-fix ViewModel/preview statica.

**Handoff notes:**
- TASK-111 resta **DONE / REVIEW PASS WITH NOTES** con micro-fix applicato.
- Post-review micro-fix column default selection validated in `docs/TASKS/EVIDENCE/TASK-111/19-review-post-fix-column-default-selection.md`; resta **DONE / REVIEW PASS WITH NOTES**.
- Nessun nuovo task aperto.
- TASK-109 resta **BLOCKED / SOSPESO**.
- TASK-110 resta **DONE**.
- Android aveva una modifica preesistente in `ExcelUtils.kt` (`discount` alias `折`) non introdotta da questo micro-fix e non revertita.

---

### Micro-fix post-review — 2026-05-17 15:22 -0400 — supplier/category pending create UX

**User override registrato:**
- TASK-111 era gia' **DONE / Chiusura — REVIEW PASS WITH NOTES**.
- L'utente ha richiesto una micro-implementazione post-review dentro TASK-111, senza aprire TASK-112.
- Interpretazione operativa: **TASK-111 MICRO-FIX / supplier-category pending create UX**.
- TASK-109 resta **BLOCKED / SOSPESO**.
- TASK-110 resta **DONE**.
- Supabase fuori scope: **NO SUPABASE MUTATION**, **NO SYNC IMPACT**, **LOCAL SWIFTDATA ONLY**.

**File modificati:**
- `iOSMerchandiseControl/PreGenerateView.swift` — UI pending-create per fornitore/categoria, status sotto i campi e summary che mostra il nuovo valore invece di `Sin seleccionar`; generazione abilitata con valori validi pending.
- `iOSMerchandiseControl/ExcelSessionViewModel.swift` — helper testabili `RelationInputState`, normalizzazione e `ensureSupplierExists` / `ensureCategoryExists` con dedupe case/trim al momento della generazione.
- `iOSMerchandiseControlTests/Task111ExcelImportParityTests.swift` — test pending-create, dedupe e creazione solo al generate.
- `iOSMerchandiseControl/en.lproj/Localizable.strings` — copy EN pending/summary.
- `iOSMerchandiseControl/it.lproj/Localizable.strings` — copy IT pending/summary.
- `iOSMerchandiseControl/es.lproj/Localizable.strings` — copy ES pending/summary.
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings` — copy ZH pending/summary.
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/main/java/com/example/merchandisecontrolsplitview/ui/screens/PreGenerateScreen.kt` — audit Android: stesso problema UX, patch mirata pending-create/deferred-create.
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/main/java/com/example/merchandisecontrolsplitview/data/InventoryRepository.kt` — dedupe `addSupplier` / `addCategory` con chiave normalizzata.
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/main/res/values*/strings.xml` — copy Android pending/summary.
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/test/java/com/example/merchandisecontrolsplitview/ui/screens/PreGenerateEntityResolutionTest.kt` — test helper pending/existing/empty.
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/test/java/com/example/merchandisecontrolsplitview/data/DefaultInventoryRepositoryTest.kt` — test repository dedupe case/trim supplier/category.
- `docs/TASKS/EVIDENCE/TASK-111/20-post-review-pending-supplier-category-create.md` — evidence micro-fix.
- `docs/TASKS/EVIDENCE/TASK-111/README.md` — indice evidence aggiornato con `20`.
- `docs/TASKS/TASK-111-excel-analysis-parity-ios.md` — tracking micro-fix.
- `docs/MASTER-PLAN.md` — tracking globale micro-fix.

**Azioni eseguite:**
1. Verificata la PreGenerate iOS: il testo nuovo non era considerato selezione valida finche' l'utente non premeva manualmente "Aggiungi nuovo...".
2. Implementata risoluzione pending-create derivata da input + liste esistenti, senza side effect durante digitazione/render.
3. Spostata la logica riusabile/testabile nel ViewModel iOS: trim, confronto normalizzato, stato empty/existing/pending e creazione differita.
4. Al tap su **Generar inventario**, iOS risolve o crea supplier/category mancanti e rivaluta il DB per evitare duplicati se il record equivalente esiste gia'.
5. Aggiornata la UI iOS per mostrare "Nuovo/Nueva/New..." sotto i campi e nel summary.
6. Audit statico Android: trovato lo stesso problema UX e applicata patch equivalente mirata; nessun refactor ampio.
7. Aggiornati test, localizzazioni ed evidence.

**Check obbligatori / richiesti:**
| Check | Stato | Note |
|---|---|---|
| iOS Debug build simulator | ✅ ESEGUITO | PASS, 0 warnings/errors MCP (`build_sim_2026-05-17T19-15-32-643Z_pid8749_ea6fc621.log`). |
| iOS Release build simulator | ✅ ESEGUITO | PASS, 0 warnings/errors MCP (`build_sim_2026-05-17T19-16-25-311Z_pid8749_41cbef01.log`). |
| iOS Release build + run smoke simulator | ✅ ESEGUITO | PASS, 0 warnings/errors MCP (`build_run_sim_2026-05-17T19-17-52-320Z_pid8749_92b791ae.log`). |
| iOS `Task111ExcelImportParityTests` | ✅ ESEGUITO | PASS 12/12 (`test_sim_2026-05-17T19-15-48-310Z_pid8749_55f4f85b.log`). |
| iOS Excel/import tests | ✅ ESEGUITO | `ExcelAnalyzerHTMLParsingTests` PASS 9/9 (`test_sim_2026-05-17T19-18-17-523Z_pid8749_26192a50.log`). |
| iOS `git diff --check` | ✅ ESEGUITO | PASS, exit 0. |
| iOS `plutil -lint` localizzazioni | ✅ ESEGUITO | EN/IT/ES/ZH PASS. |
| Android `PreGenerateEntityResolutionTest` | ✅ ESEGUITO | BUILD SUCCESSFUL. |
| Android repository dedupe supplier/category | ✅ ESEGUITO | `DefaultInventoryRepositoryTest` mirati PASS / BUILD SUCCESSFUL. |
| Android baseline `ExcelViewModelTest` | ✅ ESEGUITO | BUILD SUCCESSFUL. |
| Android baseline `ExcelUtilsTest` | ✅ ESEGUITO | BUILD SUCCESSFUL. |
| Android `assembleDebug` | ✅ ESEGUITO | BUILD SUCCESSFUL in 2s. |
| Android `lint` | ✅ ESEGUITO | BUILD SUCCESSFUL in 27s. Warning Gradle/AGP preesistenti di toolchain, nessun warning Kotlin nuovo dal codice modificato. |
| Android `git diff --check` | ✅ ESEGUITO | PASS, exit 0. |
| Coerenza con planning/perimetro | ✅ ESEGUITO | Solo PreGenerate supplier/category UX, resolver locale e test. Nessun TASK-112, nessun Supabase, nessuna modifica sync. |
| Criteri micro-fix | ✅ ESEGUITO | Vedi evidence `20-post-review-pending-supplier-category-create.md`. |

**Criteri micro-fix verificati:**
| Criterio | Stato | Evidenza |
|---|---|---|
| Testo nuovo fornitore diventa pending-create | ESEGUITO | Test iOS `RelationInputState`, UI status/summary; test Android resolver. |
| Testo nuovo categoria diventa pending-create | ESEGUITO | Test iOS `RelationInputState`, UI status/summary; test Android resolver. |
| Nomi esistenti riconosciuti case/trim-insensitive | ESEGUITO | Test iOS e Android; helper normalizzati. |
| Pending-create abilita generazione | ESEGUITO | `canGenerate` iOS e Android usa existing oppure pending valido. |
| Generate crea record mancanti una sola volta | ESEGUITO | Test iOS persistenza pending; repository Android dedupe. |
| Generate non duplica se esiste equivalente | ESEGUITO | Test iOS e Android case/trim. |
| Cancel/back non crea record | ESEGUITO | Creazione solo in `generateHistoryEntry`/tap generate; nessun side effect in render/digitazione. |
| Summary mostra nuovo valore, non `Sin seleccionar` | ESEGUITO | UI summary iOS/Android con `Nuovo/Nueva/New...`. |
| Bottone "Aggiungi nuovo..." continua a funzionare | ESEGUITO | Path mantenuto; create affordance non piu' obbligatoria. |

**Baseline regressione TASK-004 / equivalente:**
- iOS: `Task111ExcelImportParityTests` + `ExcelAnalyzerHTMLParsingTests`; Debug/Release build e smoke simulator.
- Android: `PreGenerateEntityResolutionTest`, mirati `DefaultInventoryRepositoryTest`, `ExcelViewModelTest`, `ExcelUtilsTest`, `assembleDebug`, `lint`.
- Test aggiunti/aggiornati: iOS `Task111ExcelImportParityTests`, Android `PreGenerateEntityResolutionTest`, Android `DefaultInventoryRepositoryTest`.
- Limiti residui: nessun full manual Files picker PreGenerate e nessun device fisico; limiti coerenti con note non bloccanti gia' documentate per TASK-111.

**Handoff notes:**
- TASK-111 resta **DONE / REVIEW PASS WITH NOTES** con micro-fix applicato.
- Nessun `TASK-112` aperto.
- TASK-109 resta **BLOCKED / SOSPESO**.
- TASK-110 resta **DONE**.
- Supabase non toccato: **NO SUPABASE MUTATION**, **NO SYNC IMPACT**, **LOCAL SWIFTDATA ONLY**.
- Android patch necessaria per stesso problema UX staticamente riscontrato; nessun refactor ampio.

---

### Review micro-fix post-review — 2026-05-17 15:38 -0400 — pending supplier/category create UX

**Verdict:** **POST-REVIEW MICRO-FIX PASS WITH NOTES**.

**Esito review indipendente:**
- TASK-111 resta **DONE / REVIEW PASS WITH NOTES**.
- Nessun `TASK-112` aperto.
- TASK-109 resta **BLOCKED / SOSPESO**.
- TASK-110 resta **DONE**.
- MASTER-PLAN resta **IDLE**.
- Supabase non toccato: **NO SUPABASE MUTATION**, **NO SYNC IMPACT**, **LOCAL SWIFTDATA/ROOM ONLY**.

**Problema trovato e corretto:**
- Android `PreGenerateScreen.kt`: il path inline `Aggiungi nuovo...` chiamava ancora `databaseViewModel.addSupplier/addCategory`, creando record Room prima di **Genera inventario**. Fix mirato applicato: il tap ora accetta il valore pending nella UI e chiude la lista; le sole chiamate a `addSupplier/addCategory` in PreGenerate restano nel path `onGenerate`.

**File modificati in review:**
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/main/java/com/example/merchandisecontrolsplitview/ui/screens/PreGenerateScreen.kt` — defer esplicito anche per `Aggiungi nuovo...` inline.
- `docs/TASKS/EVIDENCE/TASK-111/21-review-pending-supplier-category-create.md` — evidence review.
- `docs/TASKS/EVIDENCE/TASK-111/README.md` — indice evidence aggiornato con `21`.
- `docs/TASKS/TASK-111-excel-analysis-parity-ios.md` — tracking review micro-fix.
- `docs/MASTER-PLAN.md` — tracking globale review micro-fix.

**Check review eseguiti:**
| Check | Stato | Note |
|---|---|---|
| iOS `git diff --check` | ✅ ESEGUITO | PASS. |
| iOS `plutil -lint` localizzazioni | ✅ ESEGUITO | EN/IT/ES/ZH PASS. |
| iOS Debug build simulator | ✅ ESEGUITO | PASS su iPhone 17 Pro iOS 26.5. |
| iOS Release build simulator | ✅ ESEGUITO | PASS su iPhone 17 Pro iOS 26.5. |
| iOS Release install + launch smoke | ✅ ESEGUITO | PASS, `simctl launch` pid `21416`. |
| iOS `Task111ExcelImportParityTests` | ✅ ESEGUITO | PASS 12/12. |
| iOS `ExcelAnalyzerHTMLParsingTests` | ✅ ESEGUITO | PASS 9/9. |
| Android `git diff --check` | ✅ ESEGUITO | PASS. |
| Android targeted unit suite | ✅ ESEGUITO | PASS 103 tests, 0 failures/errors/skipped (`PreGenerateEntityResolutionTest`, mirati `DefaultInventoryRepositoryTest`, `ExcelViewModelTest`, `ExcelUtilsTest`). |
| Android `assembleDebug` | ✅ ESEGUITO | BUILD SUCCESSFUL. |
| Android `lint` | ✅ ESEGUITO | BUILD SUCCESSFUL; solo warning Gradle/AGP/toolchain preesistenti. |

**Criteri review verificati:**
| Criterio | Stato | Evidenza |
|---|---|---|
| Nuovo supplier/category valido abilita generazione | ESEGUITO | Resolver iOS/Android + test mirati. |
| Record creato solo al tap su Generate | ESEGUITO | iOS `generateHistoryEntry`; Android PreGenerate ora chiama repository solo in `onGenerate`. |
| Cancel/back non crea record | ESEGUITO | Nessuna scrittura in render/digitazione/blur/back; explicit add Android reso pending-only. |
| No duplicati case/trim | ESEGUITO | iOS ensure/dedupe; Android repository dedupe + test mirati. |
| Summary non mostra `Sin seleccionar` con pending valido | ESEGUITO | Summary iOS/Android usa copy `New/Nuovo/Nueva/新...`. |
| Bottone `Aggiungi nuovo...` resta funzionante | ESEGUITO | Android accetta pending senza persistere; iOS sheet usa valore come pending. |
| Coerenza iOS/Android | ESEGUITO | Entrambe le piattaforme convergono su deferred-create. |

**Evidence:** `docs/TASKS/EVIDENCE/TASK-111/21-review-pending-supplier-category-create.md`.

---

### Prompt EXECUTION-AUDIT suggerito *(storico / superato dalla execution e review 2026-05-17)*
Quando vorrai passare al prossimo step, chiedi esplicitamente ad esempio:

> «Prepara il prompt **EXECUTION-AUDIT read-only per TASK-111**: **Cursor** deve leggere repo **iOS, Android e Supabase locale** in modalità **read-only**, compilare le evidence **`00–10`**, riempire la **matrice M1–M28** con citazioni **file/riga o snippet redatti**, compilare **Android behavior map B-01…B-17**, rispettare **EH-01…EH-08**, proporre micro-slice **S111-A…H prioritizzati**, ma **NON modificare Swift/Kotlin/SQL/Supabase**, **NON fare migration**, **NON dichiarare parity raggiunta**, **NON marcare DONE** e **NON passare a EXECUTION-IMPLEMENTATION**.»  

---

*Fine documento storico: TASK-111 e' ora chiuso DONE / REVIEW PASS WITH NOTES.*
