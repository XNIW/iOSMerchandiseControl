# TASK-102 — Release polish UX/UI iOS-native (post TASK-101)

## 1. Titolo e stato

| Campo | Valore |
|-------|--------|
| **Task ID** | **TASK-102** |
| **Titolo** | **Release polish UX/UI iOS-native** *(fase roadmap post TASK-101)* |
| **File task** | `docs/TASKS/TASK-102-release-polish-ux-ios.md` |
| **Stato task** | **DONE** |
| **Fase attuale** | **Chiusura — REVIEW PASS FINAL / PASS WITH NOTES** |
| **Responsabile attuale** | **User / Closed** |
| **Data creazione** | 2026-05-12 |
| **Ultimo aggiornamento** | 2026-05-12 16:46 -0400 — **TASK-102 DONE / REVIEW PASS FINAL / PASS WITH NOTES** |
| **Ultimo agente** | **CODEX** *(Chiusura finale TASK-102 su override/conferma utente)* |

**TASK-102 DONE.**

**EXECUTION AUTORIZZATA DA OVERRIDE UTENTE** — il file era ancora in **PLANNING / NON READY FOR EXECUTION**; l'utente ha fornito autorizzazione esplicita a procedere con **TASK-102** in **EXECUTION** seguendo il piano definitivo approvato. L'override viene tracciato nelle evidenze `docs/TASKS/EVIDENCE/TASK-102/` e in questa sezione Execution.

**Handoff turno corrente:** **TASK-102 DONE / REVIEW PASS FINAL / PASS WITH NOTES** *(TASK-103 non aperto; limiti hardware/manuali residui accettati come non bloccanti)*.

**Flag:** **`TASK-102_EXECUTION_USER_OVERRIDE`** — execution slice-by-slice autorizzata dall'utente; **`TASK-102_REVIEW_USER_OVERRIDE`** — review finale e fix mirati autorizzati dall'utente; **`TASK-102_CLOSE_USER_OVERRIDE`** — chiusura DONE autorizzata dall'utente dopo ultimo pass manuale; **nessun** claim **production-ready globale 100%**; **TASK-103 non aperto**.

---

## 2. Dipendenze e posizionamento roadmap

| Riferimento | Ruolo |
|-------------|--------|
| **TASK-101** | **DONE / Chiusura — REVIEW PASS FINAL** — privacy/RLS/security audit e hardening documentato; fornisce contesto su copy privacy-safe, failure UX e gate sicurezza, **senza** sostituire il perimetro UX di questo task. |
| **TASK-091…TASK-100** | Sync semi-automatica, conflict recovery, performance dataset grande — il polish non ridefinisce la logica sync; limita a presentazionale e coerenza **API SwiftUI** su flussi già esistenti. |
| **TASK-103** | **Non aperto** — qualsiasi estensione oltre polish richiede nuovo task. |

---

## 3. Obiettivo

1. **Definire** un perimetro di **polish finale** per l’app iOS **nativa** (SwiftUI): navigazione, flussi inventario/Excel, griglia generata, dettaglio righe, database, cronologia, scanner, import/export locale, e superficie **Controlla cloud** / sync **manuale e semi-automatica già implementata**, senza grandi refactor architetturali.
2. **Allineare** l’esperienza a convenzioni **iOS moderne**: hierarchy chiara (`NavigationStack` dove utile), `toolbar`, `sheet`, `confirmationDialog`, `alert`, `List`/`Form`, e dove applicabile **`ShareLink`** / **`fileExporter`** (o equivalenti) per condivisione/export coerente con HIG.
3. **Uniformare** stati **vuoto / caricamento / errore / retry** con linguaggio comprensibile, CTA singola primaria quando possibile, e nessun dettaglio tecnico non necessario in Release.
4. **Pianificare** **accessibilità base**: Dynamic Type, etichette VoiceOver utili, target toccabili ≥ circa 44pt, contrasto semantico (`Color` / ruoli SF Symbol).
5. **Pianificare** coerenza **localizzazioni** **IT / EN / ES / zh-Hans** su stringhe toccate dal polish (in **EXECUTION** futura — non in questo planning/refinement).
6. **Non** dichiarare **production-ready globale 100%** né **DONE** alla fine del solo planning.
7. **Ridurre attrito operativo** nei flussi ad alta frequenza: import → preview → generazione → conteggio/scanner → sync/export, privilegiando meno tap, feedback immediato e recupero semplice dagli errori.
8. **Stabilire decisioni UX predefinite** per evitare blocchi in EXECUTION: quando esistono più soluzioni valide, scegliere quella più nativa iOS, meno invasiva e più coerente con l’app esistente.

---

## 4. Stato attuale atteso *(senza execution in questo turno)*

- **Repo iOS:** progetto Xcode single-target, tab principali (Inventario, Database, Cronologia, Opzioni), modelli SwiftData, file di viste grandi (`GeneratedView`, `ExcelSessionViewModel` / analisi, ecc.) — stato funzionale già consolidato da task precedenti; **questo task** mira al **raffinamento visivo/comportamentale**, non a nuove capability business.
- **Tracking progetto:** dopo questo planning/refinement, **MASTER-PLAN** riflette **ACTIVE / PLANNING** su **TASK-102**; ultimo completato resta **TASK-101**.
- **Evidenze TASK-102:** cartella `docs/TASKS/EVIDENCE/TASK-102/` **prevista ma non popolata** finché non inizia EXECUTION autorizzata.


## 4B. Esito review planning e ottimizzazioni integrate

Il piano Claude Code è una buona base: resta prudente, mantiene TASK-102 in **Planning**, evita execution prematura e delimita correttamente Supabase/Android/schema fuori scope. Le integrazioni sotto lo rendono più operativo per una futura execution senza trasformarlo in implementazione.

### Miglioramenti aggiunti

| Area | Ottimizzazione |
|------|----------------|
| **UX decision defaults** | Decisioni progettuali predefinite per ridurre ambiguità in EXECUTION. |
| **Priorità** | Micro-slice pesate per impatto/rischio, così Codex può procedere senza big-bang. |
| **Efficienza** | Introdotto “touch budget” per limitare churn nei file SwiftUI grandi. |
| **Evidenze** | Acceptance matrix estesa con coerenza visiva, performance percepita e smoke regression. |
| **Accessibilità** | Checklist più verificabile: Dynamic Type, VoiceOver, touch target, contrasto e stati non solo colore. |
| **Design polish** | Regole concrete su gerarchia visiva, CTA, sheet, dialog, toolbar, empty state e feedback. |

### Principio operativo

TASK-102 deve produrre una Release più pulita e piacevole, non una nuova architettura. Ogni patch futura deve migliorare la percezione dell’app senza cambiare il modello mentale dell’utente.

---

## 4C. Lacune residue prima di autorizzare EXECUTION

Queste lacune non bloccano il planning, ma devono essere chiuse o accettate esplicitamente prima di passare a CODEX.

| Lacuna | Decisione planning |
|--------|--------------------|
| **Audit repo-grounded non ancora completo** | Prima della execution va congelato l’elenco reale dei file iOS per ogni slice S102-A…S102-I. |
| **Baseline visiva non ancora catturata** | Prima/durante execution vanno raccolti screenshot privacy-safe delle schermate principali per confronto before/after. |
| **Cutline priorità non esplicitata** | Usare la matrice Must/Should/Could §9B per ridurre scope se il task diventa troppo grande. |
| **Component reuse map assente** | Prima di creare nuovi componenti UI, verificare se esiste già un pattern condiviso riutilizzabile. |
| **A11y/l10n da congelare per slice** | Ogni slice futura deve indicare quali stringhe e quali elementi accessibili tocca. |

---

## 5. Scope IN

| Area | Intent di polish *(EXECUTION futura)* |
|------|----------------------------------------|
| **Home / navigazione** | `ContentView` / `TabView`: gerarchia chiara, titoli toolbar coerenti, deep link leggeri se già presenti. |
| **Import Excel / file** | Flusso da `InventoryHomeView` → caricamento file `.xlsx` / `.xls` / HTML — feedback caricamento/analisi, errori file, accesso document picker. |
| **Preview pre-generazione** | `PreGenerateView`: ruoli colonna, toggle, anteprima leggibile, azioni primarie/secondarie chiare. |
| **Foglio generato / griglia** | `GeneratedView`: layout tabella/celle, scroll, header, azioni per riga, coerenza con tastiera/sheet. |
| **Dettaglio riga / modifica** | Sheet o dettaglio riga prodotto (incl. edit inline o modale): campi chiari, salvataggio, annulla. |
| **Inserimento manuale prodotti** | Flussi manual entry collegati a inventario/database — focus order, validazione, feedback. |
| **Scanner barcode** | `BarcodeScannerView` nei contesti inventario + database: permessi camera, stati errore, torcia se prevista, chiusura sicura. |
| **Cronologia** | `HistoryView`: lista sessioni, stati vuoto, dettaglio entry. |
| **Database prodotti** | `DatabaseView` e viste collegate: lista, ricerca, CRUD leggibile. |
| **Fornitori / categorie / storico prezzi** | Superfici per supplier/category e storico `ProductPrice` — navigazione e leggibilità. |
| **Import/export database** | Picker export, share, messaggi di completamento/errore; valutare `fileExporter` / `ShareLink` dove riduce custom UI. |
| **Sync manuale / semi-automatica** | Card e sheet Release in `OptionsView` / `SupabaseManualSyncViewModel`: testi, progress, conferme, **nessuna** nuova logica sync automatica oltre quanto già in TASK-091…096. |
| **Empty / loading / error** | Pattern ripetibili per placeholder, `ProgressView`, messaggi errore con retry dove esiste già. |
| **Accessibilità** | Dynamic Type, `accessibilityLabel`/`Hint` mirati, `accessibilityElement(children:)`, ordine lettura, target touch. |
| **Localizzazioni** | IT/EN/ES/zh-Hans per chiavi toccate dal polish; `plutil` / test copertura come evidenza in EXECUTION. |
| **Coerenza API SwiftUI** | Preferenza `NavigationStack`, toolbars native, `confirmationDialog` per scelta distruttiva o multi-opzione, `alert` per conferme semplici. |


### Decisioni UX/UI predefinite per EXECUTION futura

Queste decisioni sono già approvate a livello planning e non richiedono nuovo blocco decisionale, salvo conflitti reali emersi dal codice.

| Tema | Decisione |
|------|-----------|
| **Azione primaria** | Ogni schermata principale deve avere una sola CTA dominante. Azioni secondarie in toolbar, menu o footer. |
| **Azioni distruttive** | Preferire `confirmationDialog` per scelte multiple o distruttive; `alert` solo per conferme semplici/errori bloccanti. |
| **Sheet** | Usare sheet per modifica/preview contestuale; evitare stack di sheet annidati. |
| **Empty state** | Ogni empty state deve avere titolo breve, testo utile e al massimo una CTA primaria. |
| **Loading** | Preferire `ProgressView` inline o overlay leggero; bloccare l’interfaccia solo per operazioni non interrompibili. |
| **Errori** | Messaggio user-facing prima, dettaglio tecnico solo come nota secondaria se davvero utile. |
| **Scanner** | Sempre uscita chiara, messaggio per permesso negato e fallback a input manuale quando possibile. |
| **Import/export** | Wording coerente: “Importa”, “Esporta”, “Condividi”. Evitare “download/upload” in UI italiana salvo contesto cloud. |
| **Sync cloud** | UI orientata a stato e recupero: “Controlla cloud”, “Sincronizza ora”, “Riprova”, “Risolvi conflitti”; evitare gergo Supabase. |
| **Griglia** | Priorità a leggibilità e orientamento: header chiari, celle tappabili distinguibili, feedback visivo immediato. |
| **Colori** | Usare colori semantici SwiftUI; stato critico non deve dipendere solo dal colore. |
| **Copy** | Frasi brevi, verbi d’azione, niente termini tecnici non necessari. |

---

## 6. Scope OUT

- **Refactor massivi** di `ExcelSessionViewModel` / `ExcelAnalyzer` / estrazione moduli non richiesti dal polish.
- **Nuove dipendenze** SPM o vendor.
- **Modifiche schema SwiftData** o modelli (salvo fix minimo dimostrato **bloccante** per UX e evidenziazionato in review — da valutare come eccezione documentata).
- **Backend Supabase**: SQL, migration, RLS, policy, grant, drift repair — **fuori**.
- **Android / Kotlin** — **fuori**.
- **Nuova sync automatica / background** (Timer, BGTask, Realtime, worker) — **fuori**.
- **Dati reali** come fixture o evidenza — **fuori**; solo sintetici/privacy-safe.
- **TASK-103** o file task successivi — **fuori**.

---

## 7. Non-obiettivi

- Raggiungere parità funzionale **1:1** con Android se richiede feature nuove o refactor grande.
- Risolvere **tutti** i debiti storici nelle viste più grandi in un singolo task — il polish deve restare **incrementale** per slice.
- Ottimizzazioni performance **tipo TASK-100** salvo che emergano come regressione **bloccante** introdotta dal polish (then FIX mirato).
- Ridefinire il **threat model** o audit sicurezza (resta contesto TASK-101).


---

## 7B. Guardrail di efficienza per futura execution

Per evitare che il polish diventi un refactor mascherato, ogni slice futura deve rispettare questi limiti salvo eccezione documentata.

| Guardrail | Regola |
|-----------|--------|
| **Touch budget** | Ogni micro-slice dovrebbe toccare pochi file coerenti con il flusso. Se supera circa 5 file Swift principali, fermarsi e documentare perché. |
| **Patch reversibile** | Ogni modifica UI deve poter essere revertita senza migrazione dati o cambi modello. |
| **No business logic in View** | Ritocchi SwiftUI sì; nuova logica complessa dentro View no. |
| **No big-bang navigation** | Migrare navigazione per area, non tutta l’app insieme. |
| **Stringhe raggruppate** | Localizzazioni da aggiornare per slice, evitando modifiche sparse e duplicati. |
| **Evidenza prima del DONE** | Nessuna slice può essere considerata completata senza nota evidenza in `MATRIX-M102-results.md`. |
| **Performance percepita** | Ogni polish su griglia/import/database deve evitare animazioni pesanti o layout instabili su dataset grandi. |

---

## 8. Rischi *(R102-xx)*

| ID | Rischio | Mitigazione pianificata |
|----|---------|-------------------------|
| **R102-01** | **Scope creep** verso sync/backend | Gate “UX-only”; ogni slice verificata contro Scope OUT. |
| **R102-02** | **Regressione** in `GeneratedView` per dimensioni file | Patch minime, test mirati dove esistono, smoke manuale su griglia. |
| **R102-03** | **Churn localizzazioni** alto | Raggruppare stringhe per slice; duplicate-key scan; `plutil`. |
| **R102-04** | **Accessibilità** rompe layout a Dynamic Type grandi | Test su XL/XXL; truncation accettabile con `scroll` / line limit documentato. |
| **R102-05** | **NavigationStack** vs struttura esistente `NavigationView` legacy | Mappare file per file; migrazione graduale per area, non big-bang salvo necessità. |
| **R102-06** | **Conflitto** con copy “privacy-safe / no jargon” TASK-072…082 | Ripassare CTA Release sync; non reintrodurre termini tecnici in UI utente. |
| **R102-07** | **Export/share** behavior diverso tra iOS versioni | Evidenza per `ShareLink`/`fileExporter` con fallback documentato. |
| **R102-08** | **Tempi** — troppi flussi in un’unica EXECUTION | Rispettare micro-slice **S102-A…S102-I** e ordinare per rischio/impatto. |
| **R102-09** | **Polish soggettivo** senza criteri verificabili | Usare decisioni §5, matrix M102 e screenshot before/after dove utile. |
| **R102-10** | **Animazioni o layout** peggiorano performance percepita su file grandi | Evitare animazioni globali; testare griglia/database con dataset sintetico medio-grande. |
| **R102-11** | **A11y parziale** applicata solo ad alcune schermate | Pass trasversale S102-I con checklist minima obbligatoria. |
| **R102-12** | **Over-polish** rompe familiarità dell’utente esistente | Preferire micro-miglioramenti coerenti al redesign radicale. |

---

## 8B. Principi UX Release da applicare in tutte le slice

| Principio | Applicazione pratica |
|-----------|----------------------|
| **Un flusso, una CTA primaria** | Importa, Genera, Salva, Sincronizza o Esporta devono emergere chiaramente; il resto va in toolbar/menu/secondary button. |
| **Ridurre tap ripetitivi** | Nei flussi frequenti, preferire default ragionevoli, ultimo fornitore/categoria dove già supportato, focus automatico e azioni contestuali. |
| **Feedback immediato** | Ogni azione lenta deve mostrare stato entro il primo secondo percepito: progress, spinner inline o messaggio temporaneo. |
| **Recupero prima del blocco** | Per errori import/sync/export, offrire retry, correzione o export errori prima di lasciare l’utente fermo. |
| **Densità controllata** | Le schermate potenti possono restare dense, ma devono avere gerarchia: titolo, riepilogo, azione, dettagli. |
| **Coerenza iconografica** | Usare SF Symbols semantici in modo stabile: scan, export/share, cloud/sync, warning/error, history. |
| **Niente redesign radicale** | Migliorare leggibilità e fluidità mantenendo familiarità e struttura generale già esistente. |

---

## 9. Micro-slice progressive **S102-A … S102-I**

| ID | Focus principale | Priorità | File / aree indiziative *(da confermare in Planning Review repo-grounded)* | Output atteso |
|----|------------------|----------|----------------------------------------------------------------------------|---------------|
| **S102-A** | Tab shell, **Home inventario**, titoli e navigazione radice | Alta / basso rischio | `ContentView`, `InventoryHomeView` | Gerarchia più chiara, CTA primaria evidente, toolbar coerenti. |
| **S102-B** | **Import file** Excel/HTML, stati analisi, errori picker | Alta / medio rischio | `InventoryHomeView`, `ExcelSessionViewModel` *(solo wiring UI se necessario)* | Flusso import con feedback, retry/errore leggibile, nessuna logica parser cambiata. |
| **S102-C** | **Pre-generazione** colonne, ruoli, preview | Alta / medio rischio | `PreGenerateView` | Colonne essenziali e selezione più comprensibili; azioni generate/annulla chiare. |
| **S102-D** | **Griglia generata**, header, scroll, azioni bulk leggibili | Alta / alto rischio | `GeneratedView` | Migliore orientamento visivo senza rifare la tabella; performance invariata. |
| **S102-E** | **Dettaglio riga**, edit, **entry manuale** | Alta / medio rischio | Sheet/detail collegati a `GeneratedView` / form manuali | Modifica riga più prevedibile, input scanner/manuale coerenti. |
| **S102-F** | **Scanner** (inventario + database) | Media / medio rischio | `BarcodeScannerView`, call site in inventario e `DatabaseView` | Permessi, fallback manuale e feedback scan uniformati. |
| **S102-G** | **Cronologia** sessioni | Media / basso rischio | `HistoryView` | Empty state, lista e dettaglio più leggibili. |
| **S102-H** | **Database**: prodotti, fornitori, categorie, storico prezzi, **import/export** | Alta / alto rischio | `DatabaseView`, `ProductImportViewModel`, viste CRUD correlate | CRUD e import/export più chiari, senza cambiare schema o repository. |
| **S102-I** | **Opzioni** + **sync Release** (manuale/semi-auto esistente), **stati trasversali**, pass **a11y/l10n**, checklist API native | Alta / trasversale | `OptionsView`, `SupabaseManualSyncViewModel`, componenti shared | Coerenza finale, localizzazioni, accessibilità, evidence bundle. |

**Ordine suggerito:** **S102-A → S102-B → S102-C → S102-D → S102-E → S102-F → S102-G → S102-H → S102-I**.

**Regola di efficienza:** se una slice scopre un problema strutturale non risolvibile con patch piccola, non allargarla; documentare come **FOLLOW-UP CANDIDATE** e continuare solo se non blocca la Release polish.

**Spike consentito solo in planning/execution iniziale:** prima di S102-D/H, fare una breve review statica dei file grandi per decidere se intervenire con patch locale o rinviare refactor a task dedicato.

---

## 9B. Cutline Must / Should / Could per controllare lo scope

Se TASK-102 diventa troppo ampio, la futura execution deve tagliare partendo da **Could**, poi **Should**, mantenendo i **Must**.

| Priorità | Elementi |
|----------|----------|
| **Must** | Home/navigation minima, import feedback, PreGenerate chiarezza colonne, GeneratedView leggibilità senza regressione, Database CRUD leggibile, stati empty/loading/error, a11y/l10n per stringhe toccate, smoke regression. |
| **Should** | Scanner fallback migliorato, Cronologia empty/detail polish, import/export database con feedback più chiaro, sync Release copy/status più semplice. |
| **Could** | Micro-animazioni leggere, screenshot before/after estesi, ulteriore polish estetico non necessario alla comprensione, piccoli miglioramenti di icone dove non impattano flusso. |

**Regola:** nessun elemento **Could** deve essere implementato se mette a rischio build, performance percepita, accessibilità o completion dei **Must**.

---

## 10. Matrice acceptance **M102-01 … M102-17**

Stato iniziale di ogni riga: **PLANNED / NOT RUN**.

| ID | Area | Verifica prevista | Evidenza prevista | Stato |
|----|------|-------------------|-------------------|--------|
| **M102-01** | Navigazione shell | Tab e titoli coerenti; nessuna navigazione “morta” | Screenshot + nota in `MATRIX-M102-results.md` | PLANNED / NOT RUN |
| **M102-02** | Import file | Loading/error/empty durante analisi file | Log UX o screenshot | PLANNED / NOT RUN |
| **M102-03** | PreGenerate | Colonne/ruoli comprensibili; CTA chiare | Screenshot | PLANNED / NOT RUN |
| **M102-04** | Griglia generata | Scroll, selezione, editing non ambiguo | Screenshot / breve clip note | PLANNED / NOT RUN |
| **M102-05** | Dettaglio riga | Modifica e annulla prevedibili | Screenshot | PLANNED / NOT RUN |
| **M102-06** | Manual entry | Validazione e messaggi utente | Screenshot | PLANNED / NOT RUN |
| **M102-07** | Scanner | Camera negata / OK / errore comprensibile | Screenshot o lista casi | PLANNED / NOT RUN |
| **M102-08** | Cronologia | Empty state + dettaglio sessione | Screenshot | PLANNED / NOT RUN |
| **M102-09** | Database prodotti | Lista/form coerenti con HIG | Screenshot | PLANNED / NOT RUN |
| **M102-10** | Supplier/category/prezzi | Navigazione e lettura | Screenshot | PLANNED / NOT RUN |
| **M102-11** | Import/export DB | Export/import feedback; share coerente | Screenshot + nota export | PLANNED / NOT RUN |
| **M102-12** | Sync Release | Stati sync, `confirmationDialog`, nessun jargon nuovo | Screenshot | PLANNED / NOT RUN |
| **M102-13** | Accessibilità | VoiceOver campionato; Dynamic Type L/XL; contrasto | `a11y-notes.md` | PLANNED / NOT RUN |
| **M102-14** | Localizzazioni | `plutil` + chiavi nuove/modificate elencate | `l10n-plutil.txt` | PLANNED / NOT RUN |
| **M102-15** | Coerenza visiva | Spacing, gerarchia, CTA, toolbar e sheet coerenti tra schermate | `visual-consistency-notes.md` + screenshot | PLANNED / NOT RUN |
| **M102-16** | Performance percepita | Nessun peggioramento evidente su griglia/database con dataset sintetico | `performance-smoke-notes.md` | PLANNED / NOT RUN |
| **M102-17** | Smoke regression | Import → pregen → generated → sync analysis/export; database CRUD; scanner fallback | `smoke-regression-checklist.md` | PLANNED / NOT RUN |

---

## 11. Acceptance criteria **CA-T102-01 … CA-T102-17**

| ID | Criterio |
|----|----------|
| **CA-T102-01** | Ogni **slice S102-x** ha almeno una riga **M102-y** associata e tracciabilità in `TRACEABILITY-S102-CA-M102.md`. |
| **CA-T102-02** | **Nessun** nuovo flusso sync **silenzioso** o automatico oltre quanto già autorizzato in TASK-091…096. |
| **CA-T102-03** | **Nessuna** modifica **Supabase** SQL/RLS/policy/grant nel perimetro TASK-102. |
| **CA-T102-04** | **Nessuna** modifica **Android/Kotlin**. |
| **CA-T102-05** | Import Excel / pregen / generated / database mantengono **comportamento funzionale** equivalente salvo bug fix **documentati**. |
| **CA-T102-06** | Stati **empty/loading/error** presenti sui flussi principali elencati in §5 senza schermate “silenziose”. |
| **CA-T102-07** | **Toolbar / navigation bar** coerenti; azioni distruttive usano **`confirmationDialog`** o **`alert`** appropriato. |
| **CA-T102-08** | **Sheet** per modali complessi; evitare stacking ingestibile di overlay *(max pragmatico da documentare se inevitabile)*. |
| **CA-T102-09** | **Share/export** usa API native ove applicabile (**`ShareLink` / `fileExporter`**) con fallback giustificato se non applicabile. |
| **CA-T102-10** | **Accessibilità base:** elementi interattivi principali con label/hint utili; **Dynamic Type** non rompe irreversibilmente i flussi *(tolleranze documentate)*. |
| **CA-T102-11** | **Contrasto** e simboli semantici non dipendono solo dal colore per stato critico. |
| **CA-T102-12** | **Localizzazioni** IT/EN/ES/zh-Hans aggiornate per le stringhe toccate; **nessuna** chiave duplicata accidentale. |
| **CA-T102-13** | **Build** e **XCTest** rilevanti **PASS** in EXECUTION *(quando autorizzati)* — regressione non spiegata = **CHANGES_REQUIRED**. |
| **CA-T102-14** | **Evidenze** sotto `docs/TASKS/EVIDENCE/TASK-102/` complete per l’ambito dichiarato **PASS** nella review *(nessun dato reale)*. |
| **CA-T102-15** | **Coerenza visiva:** componenti simili devono usare pattern simili per titolo, descrizione, CTA, errore e azioni secondarie. |
| **CA-T102-16** | **Performance percepita:** nessun polish deve introdurre jank evidente, animazioni eccessive o ricalcoli inutili su liste/griglie grandi. |
| **CA-T102-17** | **Smoke regression:** i flussi core import/generate/sync/export/database/scanner devono essere verificati almeno una volta con dati sintetici prima del DONE. |

---

## 12. Evidenze previste — `docs/TASKS/EVIDENCE/TASK-102/`

*(Cartella creata solo a inizio EXECUTION autorizzata; in questo planning/refinement resta **non popolata**.)*

| Artefatto | Scopo |
|-----------|--------|
| `MANIFEST.md` | Indice evidenze, date, ambiente (simulator/device), branch/commit |
| `MATRIX-M102-results.md` | Stato M102-01…17 |
| `TRACEABILITY-S102-CA-M102.md` | Slice → CA → M → file toccati |
| `a11y-notes.md` | Campionamento VoiceOver / Dynamic Type |
| `l10n-plutil.txt` | Output `plutil` / note copertura |
| `screenshots/` | UI per area *(prefisso privacy-safe)* |
| `static-review-navigation.md` | Note NavigationStack/toolbar/sheet |
| `visual-consistency-notes.md` | Note su spacing, CTA, toolbar, sheet, empty/loading/error |
| `performance-smoke-notes.md` | Note su dataset sintetico e performance percepita |
| `smoke-regression-checklist.md` | Checklist flussi core verificati |
| `before-after-index.md` | Elenco screenshot prima/dopo dove disponibili |


## 12B. Checklist UX/UI per review futura

Questa checklist guida la review post-execution. Non richiede implementazione in questo turno.

### Navigazione e gerarchia

- Titolo schermata coerente con il task dell’utente.
- Back/cancel/save distinguibili e prevedibili.
- Azione primaria visibile senza cercare nei menu.
- Menu overflow usato solo per azioni secondarie o rare.

### Form e input

- Campi obbligatori riconoscibili senza rumore visivo eccessivo.
- Tastiera adatta al contenuto: numerica per prezzi/quantità/barcode dove possibile.
- Validazione vicina al campo o in messaggio sintetico.
- Annulla/salva non ambiguo in sheet di modifica.

### Tabelle e liste dense

- Header leggibile e persistente concettualmente, anche se non tecnicamente sticky.
- Celle tappabili distinguibili.
- Stati selezionato/errore/completo non basati solo su colore.
- Scroll e interazioni non devono “saltare” durante update di stato.

### Feedback e recupero

- Operazioni lunghe mostrano avanzamento o stato.
- Errori recuperabili offrono retry o alternativa.
- Export/share confermano successo in modo non invasivo.
- Sync cloud spiega cosa succede e cosa fare dopo.

### Stile visivo

- Usare SF Symbols coerenti e semantici.
- Spacing coerente con pattern SwiftUI standard.
- Evitare card e bordi eccessivi su schermate già dense.
- Preferire contenuti scansionabili: titolo → descrizione → azione.

## 12C. Definition of Ready per autorizzare CODEX

TASK-102 può passare da Planning a Execution solo quando tutti questi punti sono soddisfatti.

| Check | Stato richiesto |
|-------|-----------------|
| **File target** | Elenco file reali congelato per S102-A…S102-I o almeno per la prima slice autorizzata. |
| **Touch budget** | Confermato per la slice da eseguire; eccezioni documentate prima della patch. |
| **Evidenze** | Cartella evidence e file minimi pianificati per la slice. |
| **Scope** | Confermato che non servono schema SwiftData, Supabase, Android, nuove dipendenze o TASK-103. |
| **UX decision** | Nessun dubbio progettuale aperto che richieda blocco; valgono le decisioni §5 e §8B. |
| **Rollback** | Ogni patch deve essere reversibile senza migrazione dati. |

## 13. Gate Go/No-Go per futura **EXECUTION**

| Esito | Condizione |
|-------|------------|
| **GO** | Planning Review **PASS** o **PASS WITH NOTES**; **Definition of Ready §12C** soddisfatta per la slice (o le slice) autorizzate; elenco file target congelato per slice **S102-A…S102-I**; touch budget accettato; evidenze previste confermate; utente autorizza esplicitamente **EXECUTION**; **TASK-102** resta **NON DONE** fino a review post-implementazione. |
| **NO-GO** | Scope che invade Supabase/Android/schema; dipendenze nuove richieste; mancanza di owner per slice; incertezza su `GeneratedView` senza piano di rischio; **TASK-103** mescolato nel perimetro. |

---

## 14. Stop rules *(EXECUTION)*

1. **Stop** se serve **migration SQL**, **RLS**, o **policy** nuova — aprire task backend dedicato.
2. **Stop** se emerge **refactor** > ~1 file “gigante” senza slice dedicata — ritorno a **PLANNING**.
3. **Stop** su **regressione** XCTest/build non risolvibile in FIX mirato — **CHANGES_REQUIRED** / **BLOCKED** documentato.
4. **Stop** se si richiedono **dati reali** — usare solo fixture sintetiche / dataset privacy-safe.
5. **Stop** prima di dichiarare **DONE** senza **conferma utente** e review **APPROVED**.
6. **Stop** se il polish richiede nuove capability business invece di migliorare flussi esistenti.
7. **Stop** se una scelta estetica riduce chiarezza, accessibilità o performance percepita.
8. **Stop** se una slice richiede modifiche coordinate a localizzazioni, navigazione e ViewModel oltre il touch budget senza nuova mini-review.

---

## 15. Vietati in questo **planning/refinement** (turno 2026-05-12)

- Modifiche **Swift / SwiftUI / SwiftData**.
- Modifiche **Kotlin / Android**.
- Modifiche **Supabase** SQL, migration, RLS, grant.
- Modifiche **`Localizable.strings`** / **`project.pbxproj`**.
- **Build/test** obbligatori per “completare” questo planning/refinement.
- **Write Supabase live** o dati reali.
- Apertura **TASK-103**.
- Dichiarazione **TASK-102 DONE** o **READY FOR EXECUTION** implicita.

---

## 15B. Prompt consigliati per estendere il planning in modo coerente

Usare questi prompt solo se si vuole restare in **Planning**. Non autorizzano execution.

### Estendere con audit repo-grounded

```text
Resta in modalità PLANNING per TASK-102. Leggi la repo iOS aggiornata e integra il file docs/TASKS/TASK-102-release-polish-ux-ios.md con un audit repo-grounded dei file reali da toccare per ogni slice S102-A…S102-I. Non modificare Swift, Localizable.strings, project.pbxproj, Supabase o Android. Aggiorna solo il planning markdown e mantieni TASK-102 NON READY FOR EXECUTION.
```

### Preparare handoff execution senza implementare

```text
Resta in modalità PLANNING. Prepara un handoff per Codex per TASK-102, ordinando le slice S102-A…S102-I per rischio/impatto, con touch budget, file target, test/evidenze attese e stop rules. Non scrivere codice e non dichiarare READY FOR EXECUTION finché non te lo chiedo esplicitamente.
```

### Raffinare solo UX copy/localizzazioni

```text
Resta in modalità PLANNING. Analizza il copy utente previsto per TASK-102 e proponi una matrice di stringhe IT/EN/ES/zh-Hans da aggiungere o correggere in execution futura. Non modificare Localizable.strings e non implementare codice.
```

### Congelare Definition of Ready per la prima slice

```text
Resta in modalità PLANNING per TASK-102. Prendi la slice S102-A come candidata iniziale e integra il piano con Definition of Ready specifica: file reali da toccare, touch budget, evidenze minime, rischi, rollback e stop rules. Non modificare codice e non dichiarare READY FOR EXECUTION.
```

### Raffinare accessibilità

```text
Resta in modalità PLANNING. Estendi TASK-102 con una checklist accessibilità più dettagliata per Dynamic Type, VoiceOver, touch target, contrasto, stato non solo colore e ordine di lettura, collegandola a M102/CA-T102. Non modificare Swift.
```

---

## 16. Handoff

| Voce | Valore |
|------|--------|
| **Stato handoff** | **READY FOR PLANNING REVIEW — REFINED** |
| **NON** | **NON READY FOR EXECUTION** |
| **Prossima azione** | Reviewer (Claude / utente) valida slice, matrice, CA, rischi, evidenze e checklist UX §12B; eventualmente integra file indiziativi §9 con path repo-grounded; poi utente autorizza **EXECUTION** → **CODEX**. |
| **Prossima fase dopo approvazione planning** | **EXECUTION** *(solo dopo override esplicito)* |
| **Prossimo agente EXECUTION** | **CODEX** |

---

## 17. Sezioni riservate *(non compilate in questo planning/refinement)*

### Execution (Codex) — *avviata*

#### 2026-05-12 13:50 -0400 — Avvio execution su override utente

- **Override tracciato:** il task file e `docs/MASTER-PLAN.md` erano ancora in **PLANNING / NON READY FOR EXECUTION**; l'utente ha dichiarato il piano definitivo approvato e autorizzato execution completa TASK-102.
- **Task attivo confermato:** `docs/MASTER-PLAN.md` indica **TASK-102** come task attivo e il campo `File task` corrisponde a `docs/TASKS/TASK-102-release-polish-ux-ios.md`.
- **Protocollo applicato:** execution slice-by-slice in ordine **S102-A → S102-I**, con evidenze sotto `docs/TASKS/EVIDENCE/TASK-102/`.
- **Nota template:** il prompt utente cita un template **§9D**, ma nel file task attuale non esiste una sezione `9D`; per la DoR S102-A sono stati usati i campi richiesti dall'utente e la Definition of Ready **§12C**.
- **Prima slice congelata:** **S102-A — Tab shell, Home inventario, titoli e navigazione radice**.
- **DoR S102-A:** compilata in `docs/TASKS/EVIDENCE/TASK-102/MANIFEST.md` e tracciata in `docs/TASKS/EVIDENCE/TASK-102/TRACEABILITY-S102-CA-M102.md`.

#### 2026-05-12 — S102-A completata / PASS WITH NOTES

- **File Swift modificato:** `iOSMerchandiseControl/InventoryHomeView.swift`.
- **File controllati:** `iOSMerchandiseControl/ContentView.swift`, `iOSMerchandiseControl/InventoryHomeView.swift`, localizzazioni `inventory.home.*` / `tab.*`.
- **Modifiche:** Home inventario riorganizzata con `ScrollView`, CTA primaria import file, azioni secondarie manuale/scanner, stato file/import leggibile con icona semantica, helper `startManualInventory(autoOpenScanner:)` per eliminare duplicazione locale senza cambiare routing.
- **Check:** `git diff --check` PASS; Release build+launch simulator PASS; screenshot privacy-safe `docs/TASKS/EVIDENCE/TASK-102/screenshots/S102-A-home-after.jpg`; `plutil -lint` IT/EN/ES/zh-Hans PASS; `LocalizationCoverageTests` Debug PASS 8/0.
- **Nota test:** tentativo XCTest in Release non utile perché fallisce prima dei test con `unable to resolve Swift module dependency`; rilanciato in Debug con PASS.
- **Esito slice:** **PASS WITH NOTES**. VoiceOver/Dynamic Type manuale rimandati al pass trasversale S102-I; smoke completo core resta pending per le slice successive.

#### 2026-05-12 — S102-B completata / PASS WITH NOTES

- **File Swift modificato:** `iOSMerchandiseControl/InventoryHomeView.swift`.
- **File controllati:** `iOSMerchandiseControl/ExcelSessionViewModel.swift`, `iOSMerchandiseControl/InventoryHomeView.swift`, localizzazioni import.
- **Modifiche:** import da picker e da "Apri con" unificati in `loadSelectedFiles`; validazione formato applicata a tutti i file selezionati; annullamento picker ignorato senza alert; loading/progress e transizione PreGenerate preservati.
- **Check:** `git diff --check` PASS; Release build+launch simulator PASS; screenshot privacy-safe `docs/TASKS/EVIDENCE/TASK-102/screenshots/S102-B-home-import-ready.jpg`; `plutil -lint` IT/EN/ES/zh-Hans PASS; `ExcelAnalyzerHTMLParsingTests` Debug PASS 9/0.
- **Esito slice:** **PASS WITH NOTES**. Picker manuale non interagito; validazione coperta staticamente e da build/test parser HTML esistenti.

#### 2026-05-12 — S102-C completata / PASS WITH NOTES

- **File Swift modificato:** `iOSMerchandiseControl/PreGenerateView.swift`.
- **File controllati:** `PreGenerateView.swift`, helper ruoli in `ExcelSessionViewModel.swift` tramite lettura.
- **Modifiche:** CTA `Genera` resa primaria e full-width; bulk actions colonne con `Label`/SF Symbols; preview orizzontale etichettata per accessibilità; icone badge ruolo rese decorative per VoiceOver.
- **Check:** `git diff --check` PASS; Release build+launch simulator PASS; `plutil -lint` IT/EN/ES/zh-Hans PASS.
- **Esito slice:** **PASS WITH NOTES**. Nessun XCTest diretto per la vista; walkthrough dati sintetici import -> PreGenerate -> Generated resta nel final smoke.

#### 2026-05-12 — S102-D completata / PASS WITH NOTES

- **File Swift modificato:** `iOSMerchandiseControl/GeneratedView.swift`.
- **File controllati:** `GeneratedView.swift` inventory section/grid/header/row/floating actions.
- **Modifiche:** aggiunta azione bulk visibile per marcare tutte le righe complete/incomplete; header griglia reso coerente con radius 8 e label accessibile; righe con stati errore/shortage/completata/highlight ora hanno bordo semantico oltre al colore.
- **Check:** `git diff --check` PASS; Release build+launch simulator PASS; `plutil -lint` IT/EN/ES/zh-Hans PASS.
- **Esito slice:** **PASS WITH NOTES**. Walkthrough griglia con dataset sintetico e performance percepita rimandati al final smoke.

#### 2026-05-12 — S102-E completata / PASS WITH NOTES

- **File Swift modificato:** `iOSMerchandiseControl/GeneratedView.swift`.
- **File controllati:** `ManualEntrySheet`, row detail sheet/actions.
- **Modifiche:** scanner nel form manuale portato a target 44pt; tastiere/submit label più coerenti per barcode, prezzi e quantità; CTA `Aggiungi e continua` resa più leggibile; azione edit riga enfatizzata senza cambiare flussi.
- **Check:** `git diff --check` PASS; Release build+launch simulator PASS; `plutil -lint` IT/EN/ES/zh-Hans PASS.
- **Esito slice:** **PASS WITH NOTES**. Sheet runtime con dati sintetici rimandati al final smoke.

#### 2026-05-12 — S102-F completata / PASS WITH NOTES

- **File Swift modificati:** `BarcodeScannerView.swift`, `GeneratedView.swift`, `DatabaseView.swift`.
- **Localizzazioni:** aggiunta `scanner.action.enter_manually` in IT/EN/ES/zh-Hans.
- **Modifiche:** `ScannerView` ora espone fallback manuale opzionale nei casi permission/camera/session failure; callsite inventario, manual entry, search e database aggiornati con CTA coerente; nessun cambio ad AVCapture/session/torch engine.
- **Check:** `git diff --check` PASS; Release build+launch simulator PASS; `plutil -lint` IT/EN/ES/zh-Hans PASS; duplicate localization keys PASS.
- **Esito slice:** **PASS WITH NOTES**. Runtime camera/permission non interagito; fallback verificato staticamente e con build.

#### 2026-05-12 — S102-G completata / PASS WITH NOTES

- **File Swift modificato:** `iOSMerchandiseControl/HistoryView.swift`.
- **Localizzazioni:** aggiunte `history.empty.filtered_title`, `history.empty.filtered_body`, `history.status.not_attempted`, `history.status.synced`, `history.status.errors` in IT/EN/ES/zh-Hans.
- **Modifiche:** Cronologia vuota usa `ContentUnavailableView`; filtro senza risultati mostra empty state dedicato; row cronologia espone status sync/export come badge testuali; riepilogo sessione usa griglia adattiva; warning JSON corrotto reso testuale.
- **Check:** `git diff --check` PASS; Release build+launch simulator PASS; screenshot privacy-safe `docs/TASKS/EVIDENCE/TASK-102/screenshots/S102-G-history-empty-after.jpg`; `plutil -lint` IT/EN/ES/zh-Hans PASS; duplicate localization keys PASS; `LocalizationCoverageTests` Debug PASS 8/0.
- **Esito slice:** **PASS WITH NOTES**. Runtime lista/dettaglio con entry sintetica rimandato al final smoke; nessun cambio a `HistoryEntry`, export XLSX o routing `GeneratedView`.

#### 2026-05-12 — S102-H completata / PASS WITH NOTES

- **File Swift modificati:** `iOSMerchandiseControl/DatabaseView.swift`, `iOSMerchandiseControl/EditProductView.swift`, `iOSMerchandiseControl/ProductPriceHistoryView.swift`.
- **Localizzazioni:** aggiunte chiavi database/product UI per empty/search/delete/import/export/validazione barcode in IT/EN/ES/zh-Hans.
- **Modifiche:** Database vuoto/filtro vuoto usa `ContentUnavailableView`; search/scanner e toolbar hanno Label/accessibility; row prodotto usa gerarchia piu scansionabile e chip valori; delete passa da swipe immediato a `confirmationDialog`; form prodotto mostra validazione barcode; storico prezzi usa empty state nativi e righe con source/price piu leggibili.
- **Check:** `git diff --check` PASS; Release build+launch simulator PASS; screenshot privacy-safe `docs/TASKS/EVIDENCE/TASK-102/screenshots/S102-H-database-empty-after.jpg`; `plutil -lint` IT/EN/ES/zh-Hans PASS; duplicate localization keys PASS; `LocalizationCoverageTests` Debug PASS 8/0.
- **Esito slice:** **PASS WITH NOTES**. CRUD/import/export runtime con dati sintetici e dataset medio/grande rimandati al final smoke; nessun cambio a schema SwiftData, parser/import core, XLSX writer o backend.

#### 2026-05-12 — S102-I completata / PASS WITH NOTES

- **File Swift modificato:** `iOSMerchandiseControl/OptionsView.swift`.
- **Localizzazioni:** nessuna stringa nuova; copy sync Release esistente preservato.
- **Modifiche:** card sync Release e review sheet mantengono logica esistente ma hanno azioni `.controlSize(.large)`, stato running combinato per accessibilità e label/hint preservate; nessun cambio a `SupabaseManualSyncViewModel`, servizi Supabase, trigger semi-automatici o backend.
- **Check:** `git diff --check` PASS; Release build+launch simulator PASS; screenshot privacy-safe `docs/TASKS/EVIDENCE/TASK-102/screenshots/S102-I-options-sync-after.jpg`; `plutil -lint` IT/EN/ES/zh-Hans PASS; duplicate localization keys PASS.
- **Esito slice:** **PASS WITH NOTES**. Sync reale/manuale cloud non eseguito per evitare dati/backend reali; la patch è UI-only.

#### 2026-05-12 15:27 -0400 — Handoff post-execution / READY FOR FINAL REVIEW

- **Transizione proposta storica:** **EXECUTION → REVIEW** secondo workflow Codex; in quel momento **TASK-102 restava ACTIVE / NON DONE** prima della review e della chiusura finale.
- **Slice completate:** **S102-A, S102-B, S102-C, S102-D, S102-E, S102-F, S102-G, S102-H, S102-I** tutte **PASS WITH NOTES**.
- **Evidenze aggiornate:** `docs/TASKS/EVIDENCE/TASK-102/MANIFEST.md`, `MATRIX-M102-results.md`, `TRACEABILITY-S102-CA-M102.md`, `a11y-notes.md`, `visual-consistency-notes.md`, `performance-smoke-notes.md`, `smoke-regression-checklist.md`, `component-reuse-notes.md`, `definition-of-done-checklist.md`, `l10n-plutil.txt`, `before-after-index.md` e screenshot privacy-safe S102-A/B/G/H/I.
- **Check finali:** `git diff --check` PASS; build finale Release + launch simulator PASS su iPhone 17 Pro con warnings/errors 0; full XCTest Debug PASS **640 passed / 0 failed / 12 skipped**; `plutil -lint` IT/EN/ES/zh-Hans PASS; duplicate localization keys PASS.
- **Performance:** full test include benchmark sintetici `Task089LargeDatasetBenchmarkTests` e `Task100LargeDatasetAcceptanceTests` PASS; nessun dataset reale usato.
- **Limiti dichiarati:** file picker manuale, VoiceOver completo, Dynamic Type OS-level, camera permission runtime e sync live/manuale cloud reale non sono stati interagiti manualmente; le patch relative sono validate staticamente, con build, snapshot privacy-safe e test automatici disponibili.
- **Scope guard:** nessuna modifica Android/Kotlin; nessuna modifica Supabase schema/RLS/policy/grant/migration; nessuna nuova dipendenza; nessun TASK-103 aperto; nessun dato reale salvato nelle evidenze.
- **Prossima azione:** review finale Claude/utente su diff, evidenze, rischi residui e decisione di eventuale FIX o accettazione. Codex non marca il task DONE.

### Review (Codex su override utente) — *completata*

#### 2026-05-12 15:52 -0400 — REVIEW PASS FINAL / READY FOR USER APPROVAL

- **Override tracciato:** l'utente ha richiesto a Codex una review finale completa e ha autorizzato fix diretti coerenti con TASK-102. Questo deroga alla proprietà standard della sezione Review, senza marcare il task DONE.
- **Repository/tracking:** al momento della review, `docs/MASTER-PLAN.md` e questo file erano coerenti su **TASK-102 ACTIVE / REVIEW**; `File task` corrispondeva al path reale; nessun file `TASK-103` aperto; `git status` restava limitato a Swift iOS, localizzazioni e tracking/evidenze TASK-102.
- **Diff review:** letti i diff Swift/localizzazioni per `InventoryHomeView.swift`, `PreGenerateView.swift`, `GeneratedView.swift`, `BarcodeScannerView.swift`, `DatabaseView.swift`, `EditProductView.swift`, `ProductPriceHistoryView.swift`, `HistoryView.swift`, `OptionsView.swift`, `*.lproj/Localizable.strings`, `docs/MASTER-PLAN.md`, questo task file ed evidenze `docs/TASKS/EVIDENCE/TASK-102/*`.
- **Problemi trovati:** fallback scanner principale con CTA "Inserisci manualmente" chiudeva lo scanner senza portare a input manuale/ricerca quando non proveniva da dettaglio riga; row Database combinava tutta la riga per VoiceOver rischiando di nascondere azioni interne come storico prezzi; validazione form prodotto cancellava il messaggio solo confrontando una stringa localizzata.
- **Fix applicati:** `GeneratedView.swift` ora instrada il fallback scanner verso inserimento manuale per entry manuali o ricerca manuale per inventari importati, preservando il reopen del dettaglio riga; `DatabaseView.swift` usa container accessibility invece di combine sulle row prodotto; `EditProductView.swift` cancella la validazione barcode quando il barcode diventa non vuoto senza dipendere dal testo localizzato.
- **Check review:** `git diff --check` PASS; `plutil -lint` IT/EN/ES/zh-Hans PASS; duplicate localization key scan per file PASS; Release build + launch simulator PASS su iPhone 15 Pro Max iOS 26.1, warnings/errors 0; primo full XCTest Debug su iPhone 15 Pro Max fallito per errore infrastrutturale CoreSimulator clone, non per test; retry full XCTest Debug su iPhone 17 Pro PASS **640 passed / 0 failed / 12 skipped**.
- **Limiti residui non bloccanti:** VoiceOver manuale completo, Dynamic Type OS-level, camera permission runtime, file picker manuale, CRUD/import/export manuale con dati sintetici e sync live/manuale cloud reale non sono stati interagiti manualmente. Restano documentati come **PASS WITH NOTES**, non come blocker TASK-102.
- **Scope guard confermato:** nessuna modifica Android/Kotlin; nessuna modifica Supabase schema/RLS/policy/grant/migration; nessuna nuova dipendenza; nessun dato reale nelle evidenze; nessun TASK-103 aperto.
- **Decisione storica review:** **REVIEW PASS FINAL / PASS WITH NOTES / READY FOR USER APPROVAL**. Stato poi superato dalla chiusura finale **TASK-102 DONE** del 2026-05-12 16:46 -0400.

### Fix (Codex) — *review-fix completati*

#### 2026-05-12 15:52 -0400 — Fix mirati review finale

- `iOSMerchandiseControl/GeneratedView.swift`: fallback scanner principale reso azionabile e coerente con S102-F.
- `iOSMerchandiseControl/DatabaseView.swift`: accessibilità row prodotto corretta per preservare le azioni interne.
- `iOSMerchandiseControl/EditProductView.swift`: validazione barcode ripulita da confronto fragile su stringa localizzata.
- **Handoff post-fix storico:** ritorno a review finale già completata in quel turno, esito **REVIEW PASS FINAL / READY FOR USER APPROVAL**; chiusura DONE eseguita nel pass finale successivo su override/conferma utente.

### Chiusura (Codex su override/conferma utente) — *completata*

#### 2026-05-12 16:46 -0400 — TASK-102 DONE / REVIEW PASS FINAL / PASS WITH NOTES

- **Override tracciato:** l'utente ha chiesto l'ultimo pass per chiudere TASK-102 in **DONE** se i controlli manuali residui realisticamente eseguibili in Simulator passavano. Questo supera la regola standard AGENTS "non marcare DONE" ed è annotato come override esplicito.
- **Simulator usato:** iPhone 17 Pro, iOS 26.4, scheme `iOSMerchandiseControl`, configurazione Release per build/launch; Dynamic Type OS-level impostato a `extra-large`.
- **Fixture:** file sintetico privacy-safe generato da fixture canonical headers TASK-031 e usato solo come input temporaneo; nessun barcode/prodotto/fornitore/prezzo/path reale salvato nelle evidenze.
- **Controlli manuali passati:** Home/navigation; file picker surface; import sintetico via handoff file app; PreGenerate; GeneratedView; dettaglio riga; inserimento manuale; scanner permission denied/fallback “Inserisci manualmente”; ricerca manuale alternativa; History; Database CRUD sintetico create/read/update/delete; ProductPrice history; export share sheet; import dialog/file picker surface; Options/sync cloud signed-out surface.
- **Fix finali applicati:** `ProductPriceHistoryView.swift` aggiunge chiusura toolbar per evitare trap modale; `ContentView.swift` non mostra più il banner root `blockedAuth` fuori da Opzioni, evitando overlay della toolbar Database a Dynamic Type extra-large mentre il recupero sign-in resta disponibile nella card sync di Opzioni.
- **Check finali:** Release build + launch simulator PASS con warnings/errors 0; full XCTest Debug PASS **652 tests / 0 failed / 12 skipped**; `git diff --check` PASS; `plutil -lint` IT/EN/ES/zh-Hans PASS; duplicate-key scan localizzazioni PASS.
- **Limiti residui accettati:** scansione camera reale non testabile in Simulator e classificata hardware-device-only; VoiceOver gestuale completo non eseguito, ma campionamento accessibility hierarchy completato sui flussi principali; Files provider Simulator non popolato per selezione host-file diretta, ma il percorso di import app/document handoff è verificato con file sintetico; sync live reale non eseguito per evitare dati/backend reali.
- **Scope guard:** nessuna modifica Android/Kotlin; nessuna modifica Supabase schema/RLS/policy/grant/migration; nessuna nuova dipendenza; nessun TASK-103 aperto.
- **Decisione finale:** **TASK-102 DONE / REVIEW PASS FINAL / PASS WITH NOTES**.

---

## 18. Decisioni

| # | Decisione | Stato |
|---|-----------|--------|
| 1 | Polish **UX/UI solo** sul client iOS; **zero** backend nel perimetro. | attiva |
| 2 | In caso di alternative UI valide, scegliere la soluzione più nativa iOS, meno invasiva e più coerente con l’app esistente. | attiva |
| 3 | Ogni slice futura deve rispettare touch budget, evidenza minima e stop rules anti-refactor. | attiva |
| 4 | Performance percepita e accessibilità sono criteri di qualità del polish, non extra opzionali. | attiva |
| 5 | In caso di scope pressure, preservare prima i Must §9B e tagliare Could/Should. | attiva |
| 6 | Prima di creare nuovi componenti UI, verificare pattern esistenti e preferire riuso leggero. | attiva |
| 7 | TASK-102 può partire in execution anche per singola slice, ma solo dopo Definition of Ready specifica per quella slice. | attiva |
