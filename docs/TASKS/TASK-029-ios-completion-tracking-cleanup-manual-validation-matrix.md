# TASK-029: iOS Completion Tracking Cleanup + Manual Validation Matrix

## Informazioni generali
- **Task ID**: TASK-029
- **Titolo**: iOS Completion Tracking Cleanup + Manual Validation Matrix
- **File task**: `docs/TASKS/TASK-029-ios-completion-tracking-cleanup-manual-validation-matrix.md`
- **Stato**: DONE
- **Fase attuale**: —
- **Responsabile attuale**: —
- **Data creazione**: 2026-04-26
- **Ultimo aggiornamento**: 2026-04-26 *(review APPROVED; completamento documentale/tracking-only)*
- **Ultimo agente che ha operato**: CLAUDE *(review documentale richiesta dall'utente)*

## Dipendenze
- **Dipende da**: nessuno
- **Sblocca**: scelta ordinata del prossimo task operativo di completamento iOS; riduzione ambiguita' di tracking (matrice e test pack) prima di **TASK-030+** o validazioni manuali coordinate

## Scopo
Raccogliere in un'unica matrice e in liste operative tutti i task implementati o parzialmente validati, distinguendo: implementato ma non validato; review-APPROVED ma non DONE; blocco per test manuali; riprendibile con FIX mirato; superato; non piu' utile; funzionalita' ancora mancanti. **Questo file resta l'output documentale** — nessun codice.

## Contesto
Creato da user override 2026-04-26 dopo sospensione di **TASK-028**: l'utente ha scelto di mettere in pausa test residui e proseguire con cleanup tracking / completamento iOS in modo ordinato. *(Stato globale progetto: vedi `MASTER-PLAN` — **TASK-029** e' completato come audit documentale/tracking-only; non confondere con execution a codice.)*

## Non incluso
- Modifiche codice Swift
- Supabase
- Chiusura automatica di task diversi da **TASK-029** in **DONE** senza conferma utente
- Riapertura o modifica sostanziale di task DONE
- Esecuzione di test manuali o runtime in questo task (la matrice e i test pack sono **piani**, non run)

## Scope (task da classificare)
- **Primari**: TASK-005, TASK-006, TASK-008, TASK-009, TASK-016, TASK-017, TASK-018, TASK-019, TASK-020, TASK-021, TASK-023, TASK-024, TASK-025, TASK-026, TASK-027, TASK-028
- **Contesto (DONE / SUPERSEDED / WONT_DO)**: TASK-002, TASK-010, TASK-011, TASK-013, TASK-014, TASK-022

## Criteri di accettazione
- [x] Matrice unica: tutti i task nello **Scope primario** hanno almeno una riga in tabella con Area e categoria proposta
- [x] Sono prodotti gli output 1–9 sotto *Output richiesto dal planning* (sezioni sotto nello stesso file, 2026-04-26)
- [x] **TASK-029** passa a **EXECUTION** solo documentale/tracking-only, senza codice Swift/Supabase.
- [x] La matrice resta fonte di riferimento per scegliere il prossimo task.
- [x] Il prossimo task operativo consigliato resta **TASK-030**, ma non viene attivato in questo intervento.
- [x] Nessun task esistente diverso da **TASK-029** viene segnato **DONE**.
- [x] Stati DONE dei task nello scope **non** mutati; **nessun** DONE automatico
- [x] **Nessun** file Swift o Supabase modificato in TASK-029

## Planning (Claude) ← solo Claude aggiorna questa sezione

### Obiettivo del planning
Costruire una vista affidabile dello **stato reale** della completezza iOS, separando:
- task gia' implementati ma **non** validati (manualmente o per review formale)
- task **review-approved** ma **non** DONE
- task **bloccati** per test manuali
- task da riprendere con **FIX** mirato
- task **superseded** o non piu' utili
- funzionalita' che risultano **ancora mancanti** o solo coperte in backlog (es. **TASK-031+**)

### Principio guida
**TASK-029** e' un **task documentale**: non produce codice. Il suo valore e' ridurre ambiguita' di **tracking** prima di continuare con nuovi sviluppi iOS o Supabase, e collegare test manuali ripetitivi a **pacchetti** (test pack) per efficienza.

### Nota terminologia — EXECUTION documentale per user override 2026-04-26
Nel workflow ordinario del repository, **EXECUTION (fase task)** = lavoro **operativo** di implementazione, di norma a carico di **Codex** (codice Swift, build). Normalmente quindi non e' un sinonimo di «scrivere/aggiornare documenti».

Per **user override 2026-04-26**, **TASK-029** entra in **EXECUTION** solo in senso **documentale/tracking-only**:
- questa execution **non** autorizza modifiche Swift;
- questa execution **non** autorizza modifiche Supabase;
- l'obiettivo e' produrre/finalizzare output documentali e tracking: matrice task, tassonomia, test pack, raccomandazione del prossimo task operativo e politica UI/UX futura;
- **TASK-030** resta la raccomandazione default per il prossimo task operativo, ma **non** viene attivato in questo intervento.

### Tassonomia stato reale
Usare queste categorie nelle tabelle e nelle raccomandazioni (etichette fisse):

1. **`IMPLEMENTED_APPROVED_PENDING_TEST`**: implementazione e review (quando presente) **APPROVED**; mancano test manuali o **conferma esplicita utente** (non si assume DONE).
2. **`IMPLEMENTED_PARTIAL_VALIDATION`**: implementazione sostanzialmente completa; **qualche** prova (build, static, smoke) passata, ma **copertura** incompleta o review formale mancante / non allineata.
3. **`NEEDS_FIX`**: review o validazione hanno gia' trovato problema **reale** che richiede **FIX** (o FIX proposto e non eseguito).
4. **`NEEDS_PLANNING_REFRESH`**: task **vecchio** o scope percepito **non** allineato allo stato attuale del prodotto/backlog; serve rivedere il file task prima di **EXECUTION** o **FIX** (Codex) su quel task.
5. **`SUPERSEDED`**: superato da task successivi; **proposta** di etichettatura, **no** modifica autonoma dello stato file senza conferma utente.
6. **`WONT_DO_OR_NOT_USEFUL`**: non piu' utile nel workflow attuale.
7. **`DONE_CANDIDATE_AFTER_USER_CONFIRM`**: molto probabile chiusura **DONE** con sola **conferma** utente dopo check-list minima; **nessun** DONE automatico.
8. **`KEEP_BLOCKED`**: lasciare **BLOCKED** perche' i test residui sono **reali** e ancora **rilevanti**; non forzare sblocco senza run.

### Regole decisionali
- **Non** segnare mai **DONE** automaticamente in questo documento o aggiornando altri file task in modo autonomo.
- Se la review e' **APPROVED** e mancano solo test manuali **minimi**, classificare come **`DONE_CANDIDATE_AFTER_USER_CONFIRM`** oppure **`IMPLEMENTED_APPROVED_PENDING_TEST`**.
- Se mancano test su **device reale** o **casi critici** (es. torcia, permessi, dataset grande), usare **`IMPLEMENTED_PARTIAL_VALIDATION`** o **`KEEP_BLOCKED`**.
- Se un task e' gia' **coperto** da task successivi, proporre **`SUPERSEDED`**, ma **non** applicare senza conferma utente.
- Se emerge **regressione** o **bug concreto**, proporre **nuovo task FIX** o **riapertura mirata** — **non** eseguire in TASK-029.
- Miglioramenti **solo** UI/UX polish → **follow-up** separato; stile **SwiftUI / iOS nativo**; **no** copy layout Android.
- Se **due o piu' task** condividono **stessi** test manuali → raggrupparli in un **test pack** unico.

### Matrice obbligatoria
Legenda abbreviata colonne: **Rischio** = Rischio residuo se si ignora la validazione; **Cat.** = Categoria proposta.

| Task | Area | Stato tracking attuale | Implementazione reale | Review | Test manuali / runtime | Rischio residuo | Cat. proposta | Raccomandazione | Note |
|------|------|------------------------|------------------------|--------|------------------------|-----------------|-----------------|----------------|------|
| **TASK-005** | ImportAnalysis | BLOCKED; review finale rinviata | presente in codebase (perimetro ImportAnalysis + caller) | non formalizzata **APPROVED** nel file; static/build secondo note storiche | matrice T non chiusa in task | import utente con errori/inline non verificato end-to-end | `IMPLEMENTED_PARTIAL_VALIDATION` | Eseguire **Test pack C** (subset ImportAnalysis); poi review formale o CHANGES | Snapshot applicazione da verificare con file task |
| **TASK-006** | FullDatabaseImportExport | BLOCKED | multi-sheet export/import in **DatabaseView**; crash grande coperto da **TASK-022** | **APPROVED** (Claude) in storico; CA-13+ round-trip da confermare | test reali/round-trip sospesi | reimport/integrita' percepita | `IMPLEMENTED_APPROVED_PENDING_TEST` | **Test pack C** + round-trip; poi **DONE** solo con conferma | Allineare esito con **TASK-023/024** |
| **TASK-008** | GeneratedView | BLOCKED; REVIEW sospesa | `ManualEntrySheet` + calcolo in **GeneratedView** | code review **OK** (CA static); CA interattivi no | T-1..T-28 non eseguiti | divergenze vs Android su dialog manuale | `IMPLEMENTED_APPROVED_PENDING_TEST` | **Test pack A** (subset righe) + **Test pack B** (entry+scanner) | Con **TASK-027** su stesso file |
| **TASK-009** | ProductModelPriceHistory | BLOCKED | backfill + label storico + hook avvio | **APPROVED** (2026-03-22) | VM-1..VM-9 **non** eseguiti | prodotti senza history visibile | `IMPLEMENTED_APPROVED_PENDING_TEST` | **Test pack E**; conferma **DONE** utente | Data fissa bootstrap documentata |
| **TASK-016** | ImportAnalysis | BLOCKED | dedup core **ProductImport** / **DatabaseView** | **APPROVED** | test manuali non completati | drift futuro se solo parzialmente testato | `IMPLEMENTED_APPROVED_PENDING_TEST` | **Test pack C** (import prodotti) | Vincolo no-regression full-import |
| **TASK-017** | PreGenerate | BLOCKED | validazione colonne + snapshot VM | **APPROVED** | T-1..T-10 **non** eseguiti | file senza colonne minime silenziosi | `IMPLEMENTED_APPROVED_PENDING_TEST` | **Test pack D** | `ExcelAnalyzer` fuori perimetro (task) |
| **TASK-018** | GeneratedView | BLOCKED | secondo livello revert + snapshot | **APPROVED**; nessun fix | CA-7 **S-1, M-1..M-10, M-12** pendenti | ripristino dati import | `IMPLEMENTED_APPROVED_PENDING_TEST` | **Test pack A** (revert L2) | Attenzione a **HistoryImportedGridSupport** |
| **TASK-019** | Robustezza | BLOCKED | guardie array + cascade + async backfill | **APPROVED**; nessun fix | CA store/delete, dataset grande **non** eseguiti | incoerenza `data`/`editable` | `IMPLEMENTED_APPROVED_PENDING_TEST` | **Test pack A** + **E** (stress); device opzionale | Combinato con 009 su backfill |
| **TASK-020** | Scanner | BLOCKED | stati `ScannerView` + fallback | **APPROVED** | T-1..T-6 **non** eseguiti | schermo nero/permessi | `IMPLEMENTED_APPROVED_PENDING_TEST` | **Test pack B** (permesso, sim vs device) | Combinare con 026 (torcia) su device |
| **TASK-021** | History | BLOCKED | fault JSON + banner | **APPROVED** post **F-1** | T-5, T-1..T-3, T-7 noti / non conclusi | entry corrotte invisibili | `DONE_CANDIDATE_AFTER_USER_CONFIRM` | Conferma utente dopo **Test pack E** (warning) o smoke mirato | **User override** focus su 025 in passato |
| **TASK-023** | FullDatabaseImportExport | BLOCKED | idempotency PH + non-product diff | **APPROVED** in storico; run parziale | test manuali **parziali** / **non** conclusi | duplicati PH su reimport | `IMPLEMENTED_PARTIAL_VALIDATION` | Completare **Test pack C**; poi rivalutare **DONE** | Evidenza log `alreadyPresent` / `unresolved` |
| **TASK-024** | FullDatabaseImportExport | BLOCKED | progress/cancel (stato sospeso) | sospensione; UI non final | non conclusa | long-running apply senza feedback chiaro | `NEEDS_FIX` | Alla ripresa: review/fix perimetro 024 prima di promuovere DONE. | **Non** mescolare con logica 023 |
| **TASK-025** | GeneratedView | BLOCKED | `paymentTotal` / `missingItems` / **History** card | **APPROVED** | T-0..T-15 **non** eseguiti | totali errati in cronologia | `IMPLEMENTED_APPROVED_PENDING_TEST` | **Test pack A** + **E** | **TASK-030** puo' raccogliere stesso filone DB |
| **TASK-026** | Scanner | BLOCKED | toggle torcia | **APPROVED** | T-1..T-9 **non** eseguiti | feature inutile in buio reale se non provata | `IMPLEMENTED_APPROVED_PENDING_TEST` | **Test pack B** su **device reale** | Richiede hardware |
| **TASK-027** | ManualEntry | BLOCKED | «Aggiungi e continua» | **APPROVED** / OK | T-1..T-13 **non** eseguiti | flusso rapido non verificato | `IMPLEMENTED_APPROVED_PENDING_TEST` | **Test pack B** | Stesso file **GeneratedView** di 008 |
| **TASK-028** | GeneratedView | BLOCKED; validazione 2026-04-26 parziale | **RowDetail** refinement | read-only review **APPROVED**; **nessun** FIX | iPhone piccolo: OK; **residui** sospesi (grande, prev/next, scanner, dati mancanti) | UX dettaglio non completamente validata | `IMPLEMENTED_PARTIAL_VALIDATION` o `KEEP_BLOCKED` | Completare residui in **Test pack A**; **non** DONE senza run | Allineare a **TASK-032** multi-row in backlog se overlap |

**Contesto — task chiusi o non operativi**

| Task | Area | Stato | Categoria (contesto) | Nota |
|------|------|-------|------------------------|------|
| **TASK-002** | Robustezza / document handoff | DONE | riferimento — share vs «Apri con» limite iOS | Parziale come da file |
| **TASK-010** | Localizzazione | DONE | — | hotfix stringhe |
| **TASK-011** | Robustezza | **SUPERSEDED** | `SUPERSEDED` (022+023+024) | umbrella |
| **TASK-013** | TrackingOnly | **WONT_DO** | `WONT_DO_OR_NOT_USEFUL` | `sim_ui` non workflow std |
| **TASK-014** | TrackingOnly | DONE | — | generatore backlog/audit |
| **TASK-022** | FullDatabaseImportExport | DONE | — | apply crash **EXC_BAD_ACCESS** risolto |

### Test pack combinabili
Definizione (scope funzionale). **L'ordine di efficienza consigliato** e' nella sezione *Strategia* e sotto *Output* punto 8.

#### Test pack A — GeneratedView core
**Copre**: TASK-018, TASK-019, TASK-025, TASK-028, **parte** di TASK-008.  
**Validare**: apertura entry da import; dettaglio riga; complete/incomplete; revert (L1/L2 ove applicabile); **paymentTotal** / **missingItems**; delete row; dataset multi-riga; dark/light; **iPhone piccolo e grande**; nav prev/next se nel perimetro 028/032.

#### Test pack B — Manual entry + scanner
**Copre**: TASK-008, TASK-020, TASK-026, TASK-027.  
**Validare**: aggiunta manuale; aggiungi e continua; scanner normale; permesso camera concesso/negato; **torcia** su device reale; feedback **camera unavailable**.

#### Test pack C — ImportAnalysis + database import
**Copre**: TASK-005, TASK-006, TASK-016, TASK-023, TASK-024.  
**Validare**: import prodotti; export errori; inline editing; full database import; reimport idempotente; diff supplier/category/price history; **progress** e **cancellazione** (accetta imperfezioni note se 024 non final).

#### Test pack D — PreGenerate / header
**Copre**: TASK-017; **follow-up** potenziale **TASK-031** (header HTML/canonici) non in esecuzione ora.  
**Validare**: colonne obbligatorie; file con header coerenti; **HTML** Excel; override ruolo colonne; messaggi errore comprensibili.

#### Test pack E — History / prezzi / dati corrotti
**Copre**: TASK-009, TASK-021, **parte** TASK-025.  
**Validare**: storico prezzi; backfill; **HistoryEntry** con dati corrotti; **warning** non bloccante; **card** summary cronologia (chip **missing** ecc.).

### Test pack non sono task
- I **Test Pack A–E** sono **checklist** / **campagne** di validazione manuale: organizzano **come** e **cosa** provare, **non** sono task con ID nel `MASTER-PLAN`.
- **Nessun** nuovo `TASK-NNN` va creato *per* un test pack: restano riferimenti operativi dentro **TASK-029** o, in seguito, **riferimenti** dentro un task reale o note utente.
- Un test pack puo' essere usato: in **convalida parallela** durante un task operativo (es. allineare **C** a **TASK-030**); o come **pass** utente unico per chiudere piu' task **BLOCKED** gia' implementati.
- Se un test pack scopre un **bug reale** / regressione, il workflow e': **nuovo giro FIX** (Codex) + **REVIEW** (Claude) sul **task sorgente** gia' esistente, oppure apertura di un **task FIX mirato** secondo le regole del progetto — **non** si «chiude» il fenomeno solo aggiornando la matrice.

### Output richiesto dal planning
1. **Matrice completa** — tabella sopra (comprende contesto 002, 010, 011, 013, 014, 022).
2. **Chiudibili con conferma utente** (proposta): **TASK-006** (dopo pack C+round-trip), **TASK-009** (dopo E), **TASK-016** (C), **TASK-017** (D), **TASK-018** (A), **TASK-019** (A+E), **TASK-020** (B), **TASK-021** (E), **TASK-023** (C; chiudere solo se test idempotency OK), **TASK-025** (A+E), **TASK-026** (B), **TASK-027** (B) — *tutti* richiedono **conferma** esplicita, **nessun** DONE auto.
3. **Da tenere BLOCKED** (finche' i test sotto non siano soddisfatti o non si rischedula): **TASK-024** (incertezza review/fix), **TASK-028** (residui espliciti 2026-04-26), opzionalmente **TASK-023** se i test C non chiudono.
4. **Da riprendere con FIX** (dopo evidenza, non in TASK-029): **TASK-024** se la UX progress/cancel resta insufficiente; altri **solo** se emerge fallimento in test pack (nuovo giro **FIX → REVIEW**).
5. **Da supersedere / merge** (proposta, conferma utente): **TASK-011** gia' **SUPERSEDED**; valutare **accorpamento** narrativo 023+024+006 in **TASK-030** a livello di **pianificazione** (senza toccare file 006/023/024).
6. **Funzionalita' davvero mancanti** (da backlog, non nello scope 005–028): riconoscimento header **hardening** → **TASK-031**; multi-row / dati mancanti → **TASK-032**; **Supabase** 033+ **solo** dopo modello iOS tracciato e stabile.
7. **Prossimo task operativo dopo TASK-029** (vedi sotto *Decisione consigliata da Claude*; non attivare **TASK-030** da questo file).
8. **Test pack in ordine di efficienza** (stima): **A** (massima densita' **GeneratedView** e dipendenze 018/019/025/028) → **B** (device per torcia) → **C** (dataset puo' richiedere tempo) → **D** (file piccoli) → **E** (storico e corruzioni; dataset variabile). *Aggiustare* se l'utente priorita' **Database** (allora **C** prima per sbloccare 006/023/024). I test pack restano **checklist** (sezione *Test pack non sono task*), non sostituiscono un task.
9. **Follow-up candidate UI/UX (solo documentali)**:
   - **TASK-031:** messaggi/alias header HTML-Excel; eventuale micro-miglioramento **PreGenerate** (badge, **Form**) in linea con HIG; **nessun** clone Android.
   - **TASK-032:** se dopo **A** i casi **prev/next** o dati mancanti restano opachi, aprire/mantenere focus **GeneratedView** senza grandi refactor.
   - **Rifiniture RowDetail** post-028: solo micro-pass **spacing** / **gerarchia** (gia' previste da **CA-14** 028) come task piccolo.
   - Unificare **title mapping** `ExcelSessionViewModel.titleForRole` vs **localizedRoleTitle** (nota 017) in task i18n **se** divergenza dolorosa — fuori perimetro 017.

### Decisione consigliata da Claude
*(Raccomandazione documentale; **nessuna** attivazione di **TASK-030** o altri task in questo intervento.)*

| Obiettivo immediato | Partenza consigliata | Perche' |
|---------------------|----------------------|---------|
| **Chiudere il piu' possibile** i task gia' implementati in stato **BLOCKED** | Iniziare da **Test Pack A — GeneratedView core** | Copre **TASK-018**, **019**, **025**, **028** e parte di **008**; massima concentrazione su una singola area (GeneratedView + contesto inventario) |
| **Completare funzionalita' database** e preparare un modello dato piu' solido per **Supabase** | Pianificare come prossima **priorita' operativa** (dopo uscita da questo planning) **TASK-030** — *Full-database import/export finalization* | **TASK-030** consolida import/export full database, reimport idempotency, visibilita' delta **non**-prodotto e **progress/cancel** UX: e' il **ponte** piu' importante **prima** dello *schema audit* Supabase rispetto a un solo giro “sparso” su test manuali *non* accoppiati a quel filone |

- **Raccomandazione default (prossima mossa umana)**: dopo **approvazione** del presente planning, considerare l'attivazione (nel **MASTER-PLAN** e file task) di **TASK-030** come **prossimo task operativo** a codice, mantenendo i **Test Pack** come **checklist** di validazione parallela o manuale (A/B/C/D/E) senza sostituire il perimetro di **TASK-030** con «validare tutto in un colpo solo».
- **Motivazione**: **TASK-030** allinea 006/023/024 nel racconto e nel rischio — piu' utile **prima** di **TASK-033** (Supabase) rispetto a continuate sole validazioni ad hoc, pur necessarie se l'utente chiede di chiudere i **BLOCKED** *solo* a valle della UI.
- **Non** attivare **TASK-030** da questo file: la scelta e' **UTENTE**; qui si **registra** solo la raccomandazione.

### Strategia consigliata
1. **Approvare** **TASK-029** come planning/audit (matrice + tassonomia + test pack) — decisione **UTENTE**.
2. Dopo l'approvazione, per il filone **full database** impostare **TASK-030** come **prossimo task operativo** (fase, handoff, tracking nel `MASTER-PLAN` — *fuori* da questo intervento).
3. **Durante TASK-030**, limitare lo **scope** a **import/export completo** e correlati (idempotency, non-product diff, progress/cancel UX secondo perimetro 030) — **non** “risolvere” in un unico colpo tutte le aree (GeneratedView, scanner, ecc.): restano **checklist** A/B/E.
4. Usare **Test Pack C** come linea guida per **validazione** del lavoro **TASK-030** (import reale, reimport, progress) — oltre ai criteri gia' nel file **TASK-030** quando sara' attivo.
5. **Dopo TASK-030**, **doppia opzione**: **TASK-031** (header recognition) **oppure** **TASK-033** (Supabase schema audit) — a seconda se priorita' = duro import o allineamento cloud; **nessuna** forzatura da TASK-029.
6. **Test Pack A, B, E** utili soprattutto quando l'utente vuole **chiudere formalmente** i **BLOCKED** gia' implementati (Generated / manual+scanner / history & prezzi) — non sono prerequisito obbligatorio per iniziare **TASK-030** se l'utente dichiara **priorita' database first**.

### Politica UI/UX per i prossimi task
*(Si applica ai task di implementazione futuri; **non** a TASK-029, che resta *tracking only*.)*
- I prossimi task possono includere **micro-ritocchi** UI/UX **solo** se migliorano: chiarezza, gerarchia visiva, feedback utente, accessibilita' o coerenza **iOS**.
- Le decisioni UI/UX: preferire **stile Apple** e **SwiftUI** nativo rispetto a **copia 1:1** di layout o pattern Android.
- **Componenti** preferiti: `NavigationStack`, `Form`, `List`, `sheet`, `toolbar`, `confirmationDialog`, `alert`, `ProgressView`, e dove appropriato `ShareLink` / `fileExporter` (o `ShareSheet` gia' usata in app) — in linea con il codice esistente, non con stack nuovi a caso.
- **Evitare** grandi **refactor** UI e layout Android **pixel-replica**; se un miglioramento e' **fuori scope** del task attivo, trattarlo come **follow-up candidate** in quel task o backlog, **non** mescolato in TASK-029.
- Se la scelta e' tra «piu' completo/visivo (stile Android)» e «un po' piu' semplice ma piu' coerente con iOS / HIG» senza **perdere** una funzione importante oggi su Android, **scegliere la variante iOS coerente**; se la funzione andrebbe persa, documentare il **gap** e un task di **parity** minimo, non l'imitazione 1:1.

### Regole UI/UX per follow-up (estratto, task documentale)
- **Non** integrarli in **TASK-029** (v. *Politica* sopra).
- **Nessun** clone layout Android; **HIG**; **micro-task** se necessario.

### Criterio di uscita da TASK-029
**TASK-029** puo' essere considerato pronto per **REVIEW** documentale (e poi eventuale chiusura del **solo** TASK-029 *solo* dopo conferma utente), quando sono vere **tutte** le condizioni sotto:
- la **matrice** (e, se servito, le liste) e' **approvata** dall'utente;
- e' chiara la **prossima mossa** operativa: **attivare TASK-030** **oppure** iniziare una **campagna manuale** (es. **Test Pack A** come prima passata) — o una combinazione concordata;
- il `MASTER-PLAN` e l'utente sanno se si privilegia **database full** o **chiusura BLOCKED** su GeneratedView;
- **nessuna** modifica a codice Swift/Supabase e' avvenuta **nel perimetro** del completamento del planning 029.

Nota storica: l'aggiornamento di execution documentale non segnava **TASK-029** **DONE**. La chiusura e' ammessa solo dopo review **APPROVED** e conferma/override utente.

### Handoff finale del planning
- **Fase al momento dell'handoff**: **EXECUTION** documentale/tracking-only.
- **Prossima fase prevista allora**: **REVIEW**.
- **Prossimo agente**: **CLAUDE**.
- **Azione richiesta**:
  1. Eseguire review documentale del **TASK-029**;
  2. Verificare coerenza della matrice, tassonomia, test pack e raccomandazione default;
  3. Confermare che **TASK-029** resta senza codice e senza Supabase.
- **Raccomandazione Claude (non vincolante)**: vedi *Decisione consigliata da Claude* — default **TASK-030** per portare a regime il filone **full database** prima di **Supabase**, con **Test Pack** in parallelo come checklist.
- **Nessun codice**: questa fase corrente e' documentale/tracking-only; non si attiva **TASK-030** da qui.

---

## Execution (Codex) ← solo Codex aggiorna questa sezione

### Obiettivo compreso
Finalizzare **TASK-029** come audit documentale dello stato iOS, usando il planning gia' approvato: matrice task, tassonomia, test pack, raccomandazione operativa e politica UI/UX futura. Nessun codice.

### Scope execution documentale
- Validare che la matrice includa tutti i task nello scope.
- Confermare che i test pack A–E sono checklist, non nuovi task.
- Confermare che **TASK-030** e' la raccomandazione default come prossimo task operativo.
- Mantenere **TASK-028** **BLOCKED**.
- Non cambiare stati **DONE**/**BLOCKED** degli altri task.
- Non attivare **TASK-030**.

### Modifiche fatte
- Promossa **TASK-029** da **PLANNING** a **EXECUTION** documentale.
- Allineato **MASTER-PLAN** al nuovo stato.
- Chiarito che l'Execution di **TASK-029** non comporta modifiche Swift/Supabase.
- Conservata la raccomandazione default: **TASK-030** dopo approvazione/chiusura di **TASK-029**.

### Check execution
- [x] **MASTER-PLAN** mostra **TASK-029** come unico task **ACTIVE**.
- [x] **MASTER-PLAN** mostra fase **TASK-029** = **EXECUTION**.
- [x] **TASK-029** header mostra fase **EXECUTION**.
- [x] **TASK-028** resta **BLOCKED**.
- [x] Nessun file Swift modificato.
- [x] Nessun file Supabase modificato.
- [x] Nessun task diverso da **TASK-029** segnato **DONE**.
- [x] Nessun nuovo task creato.
- [x] **TASK-030** non attivato.

### Handoff verso Review
- **Prossima fase**: **REVIEW**
- **Prossimo agente**: **CLAUDE**
- **Azione richiesta**: verificare che **TASK-029** sia solo documentale, che la matrice sia coerente e che il prossimo passo consigliato sia chiaro.
- **Raccomandazione finale da verificare**: dopo **TASK-029**, attivare **TASK-030** come prossimo task operativo.

## Review (Claude) ← solo Claude aggiorna questa sezione

### Esito
**APPROVED**

### Problemi critici
Nessuno.

### Problemi medi
Nessuno bloccante. Applicati solo fix documentali minori:
- spuntati i criteri di accettazione soddisfatti dopo la review;
- chiarita la chiusura **DONE** del solo **TASK-029** su richiesta utente;
- resi storici gli handoff che indicavano **EXECUTION → REVIEW**;
- riallineato il tracking finale con `MASTER-PLAN`.

### Verifiche eseguite
- **MASTER-PLAN** verificato: prima della review **TASK-029** era unico task **ACTIVE**, fase **EXECUTION**.
- **TASK-029** verificato: header, execution documentale, handoff verso review e decisioni coerenti.
- **TASK-028** verificato: resta **BLOCKED**.
- **TASK-030** verificato: resta **TODO**, non attivato.
- Task citati dalla matrice verificati a livello di tracking: stati coerenti con matrice e blocchi noti.
- `git status --short` eseguito.
- `git diff -- docs/MASTER-PLAN.md docs/TASKS/TASK-029-ios-completion-tracking-cleanup-manual-validation-matrix.md` eseguito.
- Verificato che nessun file Swift risulti nel diff/status.
- Verificato che nessun file Supabase di schema/codice risulti modificato; presenti solo file task documentali Supabase gia' untracked nel worktree.

### Limiti della review
- Review solo documentale/tracking-only.
- Nessun test runtime, Simulator o build Xcode eseguito.
- Il file **TASK-029** risulta untracked nel worktree, quindi il diff Git standard non mostra le sue modifiche finche' non viene aggiunto a Git; contenuto ispezionato direttamente.

### Handoff post-review
- **Esito**: **APPROVED**
- **Stato finale TASK-029**: **DONE**
- **Stato globale progetto**: **IDLE**
- **Prossimo task consigliato**: **TASK-030** — Full-database import/export finalization.
- **Nota**: **TASK-030** resta **TODO** e non viene attivato in questa review.

## Fix (Codex) ← solo Codex aggiorna questa sezione
Non avviato.

## Chiusura
### Conferma utente
- [x] Utente ha richiesto review e chiusura se **APPROVED**.

### Follow-up candidate
- Vedi *Planning* — sezione *Follow-up candidate UI/UX* e backlog **TASK-030**–**032**.

### Riepilogo finale
**TASK-029** completato come audit documentale/tracking-only: matrice task, tassonomia stato reale, Test Pack A–E, raccomandazione default **TASK-030** e policy UI/UX futura sono stati verificati e approvati. Nessuna modifica Swift/Supabase, nessun test runtime, nessun nuovo task, nessuna attivazione di **TASK-030**, nessuna chiusura **DONE** di task diversi da **TASK-029**.

### Data completamento
2026-04-26

## Decisioni
| # | Decisione | Motivazione | Stato |
|---|-----------|-------------|-------|
| 1 | **TASK-029** restava in **PLANNING** prima dell'override utente | fase **EXECUTION** = Codex/codice nel workflow ordinario; matrice = approvazione/aggiornamento doc | superata da decisione #5 |
| 2 | Categorie tassonomia e test pack vincolano **solo** il documento | test pack **non** son task; nessun nuovo ID per essi | attiva |
| 3 | Prossima implementazione: **default TASK-030**; validazioni: **Test Pack** come checklist (A/B/…) | ponte full DB prima di Supabase; A per chiudere BLOCKED GeneratedView | proposta (scelta **UTENTE**) |
| 4 | No sinonimo pericoloso: «lavoro documentale» ≠ **fase EXECUTION** del workflow | vedi *Nota terminologia* | attiva |
| 5 | User override 2026-04-26: **TASK-029** passa a **EXECUTION** documentale | L'utente ha approvato il planning e vuole finalizzare l'audit/tracking senza codice | attiva |
| 6 | Review documentale 2026-04-26: **TASK-029** **APPROVED** e chiuso **DONE** | Matrice, tassonomia, test pack e raccomandazione default coerenti; utente ha richiesto chiusura se approvato | attiva |

---

## Handoff post-planning *(storico; superato da Review APPROVED)*
- **Fase al momento dell'handoff**: **EXECUTION** documentale/tracking-only.
- **Prossima fase prevista allora**: **REVIEW**.
- **Prossimo agente**: **CLAUDE**.
- **Azione richiesta**: review documentale del **TASK-029**; verificare che matrice, tassonomia, test pack e raccomandazione default siano coerenti.
- **Nessun codice**: nessuna modifica Swift/Supabase, nessuna attivazione di **TASK-030**, nessun task segnato **DONE**.
