# Master Plan — iOSMerchandiseControl

## Progetto
iOSMerchandiseControl — app iOS per controllo merce e inventario

## Obiettivo attuale
**Nessun task ACTIVE** (2026-03-25). **TASK-027** — **ManualEntrySheet** «Aggiungi e continua» (rapid entry) — **BLOCKED**: execution e review **completate** (review **APPROVED**); **test manuali T-1…T-13 non eseguiti**; **non** **DONE**. **Stato globale progetto: IDLE** fino a nuova attivazione esplicita di un task.

## Stato globale
IDLE
> **Tracking 2026-03-25 (aggiornamento post TASK-027):** **TASK-027** messo in **BLOCKED** — implementation **completata**; review **APPROVED** (OK); **test manuali T-1…T-13 non eseguiti**; **non** **DONE**. **In sospensione / pending manual verification**. Alla ripresa: test manuali sul file task → eventuale **FIX** → **REVIEW** → conferma utente → **DONE**. **Nessun** nuovo task **ACTIVE**: nel backlog **non** risultano voci **TODO**; i task aperti restano **BLOCKED** / **WONT_DO** / **SUPERSEDED** — attivazione del prossimo lavoro solo su **scelta utente** (nessun task automaticamente «sbloccato» per execution). **TASK-026** resta **BLOCKED** (test T-1…T-9 pendenti). **User override 2026-03-25:** **TASK-025** messo in **BLOCKED** — review tecnica **APPROVED** acquisita; **test manuali utente** (T-0..T-15) **non eseguiti**; **non** DONE; task congelata in attesa validazione manuale futura. **User override 2026-03-25 (focus TASK-025):** **TASK-021** messo in **BLOCKED** — sospeso temporaneamente per spostare il focus operativo su **TASK-025**; review tecnica **APPROVED** gia' acquisita (post-fix F-1); **non** DONE; in attesa **conferma finale utente** alla ripresa. **User override 2026-03-25:** **TASK-020** e' **BLOCKED**: review **APPROVED**; **nessun fix richiesto**; test manuali **T-1..T-6 non eseguiti** in questo turno; **non** DONE. Alla ripresa: test manuali → eventuale **FIX** se regressioni → **REVIEW** finale → conferma utente → DONE. **TASK-019** resta **BLOCKED** (test manuali pendenti). **User override 2026-03-24:** TASK-016..018 **BLOCKED** (review APPROVED / test manuali pendenti; non DONE). TASK-024 resta **BLOCKED** (review/fix UI non finalizzati). TASK-023 resta **BLOCKED** (test manuali residui). TASK-022 e' DONE (2026-03-23). **TASK-010 e' DONE (2026-03-25).** TASK-011 resta BLOCKED. TASK-014 completato; TASK-002 DONE parziale; TASK-015 WONT_DO; altri bloccati invariati salvo nota sotto.

## Workflow task attivo
_(Nessun task ACTIVE — 2026-03-25.)_

- **Ultimo task lavorato (tracking):** **TASK-027** — planning approvato; execution completata; review **APPROVED**; chiusura **DONE** subordinata a test manuali + conferma utente (task ora **BLOCKED**).
- **Prossimo step operativo:** definito solo dopo **scelta utente** (es. validare TASK-027 manualmente, riprendere un altro **BLOCKED** con lavoro residuo, o creare/attivare un nuovo task — fuori scope di questo aggiornamento).

## Fonti di verità
- Questo file = vista globale, backlog, task attivo, avanzamento generale
- File task attivo = dettaglio operativo, fase corrente, handoff, stato del lavoro
- Se divergono: il file task attivo prevale come riferimento operativo; riallineare questo file di conseguenza

## Regole operative
- Un solo task attivo per volta
- Il task attivo è l'unica unità di lavoro corrente
- **Stato globale progetto**: IDLE (nessun task attivo) | ACTIVE (un task in lavorazione)
- **Stato task**: TODO (nel backlog) | ACTIVE (in lavorazione) | BLOCKED (sospeso) | DONE (completato)
- **Fase task** (solo per ACTIVE): PLANNING | EXECUTION | REVIEW | FIX
- "Responsabile attuale" = chi deve agire ORA (coerente con la fase)
- Criteri di accettazione = contratto del task (definiti in planning, usati in execution e review)
- Il campo `File task` deve sempre corrispondere al file reale nel filesystem — mismatch = incoerenza bloccante
- Task interrotto senza completamento → BLOCKED con motivazione oppure TODO nel backlog, mai lasciato in stato ambiguo
- MASTER-PLAN aggiornato solo se cambia: task attivo, fase, stato, blocchi, avanzamento reale
- Backlog e priorità aggiornabili solo da Claude o dall'utente, mai da Codex, sempre con motivazione esplicita
- Quando il progetto passa da IDLE ad ACTIVE, la sezione "Task attivo" deve essere compilata subito con tutti i campi obbligatori (ID, titolo, file task, stato, fase, responsabile, ultimo aggiornamento)

## Transizioni valide di fase
```
PLANNING → EXECUTION → REVIEW → FIX → REVIEW → ... → conferma utente → DONE
                                  ↓ (se REJECTED)
                               PLANNING
```
- PLANNING → EXECUTION (dopo handoff)
- EXECUTION → REVIEW (dopo handoff)
- REVIEW → FIX (se CHANGES_REQUIRED)
- FIX → REVIEW (sempre, loop obbligatorio)
- REVIEW → DONE (solo dopo conferma utente, se APPROVED)
- REVIEW → PLANNING (se REJECTED)
Qualunque altra transizione è invalida.

## Esiti della review
- **APPROVED** = criteri soddisfatti, nessun fix necessario → conferma utente → DONE
- **CHANGES_REQUIRED** = fix mirati necessari, task recuperabile → FIX
- **REJECTED** = fuori perimetro o incoerente, da rifare in modo sostanziale → nuovo PLANNING

## Task attivo
_(Nessuno — stato **IDLE**; 2026-03-25.)_

Task bloccati non attivi:
- Task ID: TASK-027
- Titolo: ManualEntrySheet: modalità «Aggiungi e continua» (rapid entry)
- File task: `docs/TASKS/TASK-027-manualentrysheet-aggiungi-e-prossimo.md`
- Stato: BLOCKED
- Motivo: execution **completata**; review **APPROVED** (OK); **test manuali T-1…T-13 non eseguiti**; task **non** **DONE**. **Pending manual verification** / on hold. Alla ripresa: test manuali → eventuale **FIX** → **REVIEW** → conferma utente → **DONE**.
- Ultimo aggiornamento: 2026-03-25
- Task ID: TASK-026
- Titolo: Scanner: toggle torcia (flashlight)
- File task: `docs/TASKS/TASK-026-scanner-toggle-torcia-flashlight.md`
- Stato: BLOCKED
- Motivo: review **APPROVED** acquisita; **nessun fix** aperto dalla review; build Debug verde; **test manuali T-1…T-9 non ancora eseguiti**; task **non** DONE. **In sospensione / pending manual validation**. Alla ripresa: eseguire **T-1…T-9** manualmente prima della chiusura finale → eventuale **FIX** se regressioni → **REVIEW** → conferma utente → **DONE**.
- Ultimo aggiornamento: 2026-03-25
- Task ID: TASK-025
- Titolo: GeneratedView: ricalcolo dinamico paymentTotal + missingItems su History card
- File task: `docs/TASKS/TASK-025-generatedview-ricalcolo-paymenttotal-missingitems-history-card.md`
- Stato: BLOCKED
- Motivo: review tecnica **APPROVED** gia' acquisita; **test manuali utente** (T-0..T-15) **non ancora eseguiti**; task **non** DONE. Congelata in attesa di futura validazione manuale. Alla ripresa: test manuali → eventuale **FIX** se regressioni → **REVIEW** finale → conferma utente → DONE.
- Ultimo aggiornamento: 2026-03-25
- Task ID: TASK-021
- Titolo: HistoryEntry: warning su dati corrotti / deserializzazione fallita
- File task: `docs/TASKS/TASK-021-historyentry-warning-dati-corrotti-deserializzazione.md`
- Stato: BLOCKED
- Motivo: **user override 2026-03-25** — sospeso temporaneamente per focus operativo su **TASK-025**; review post-fix **APPROVED** gia' acquisita; **non** DONE; in attesa **conferma finale utente** alla ripresa (eventuali test manuali T-5 / runtime T-1..T-3/T-7 restano rischi noti documentati nel file task).
- Ultimo aggiornamento: 2026-03-25
- Task ID: TASK-020
- Titolo: Scanner: feedback camera non disponibile
- File task: `docs/TASKS/TASK-020-scanner-feedback-camera-non-disponibile.md`
- Stato: BLOCKED
- Motivo: **user override 2026-03-25** — review **APPROVED**; **nessun fix richiesto**; test manuali **T-1..T-6 non eseguiti** in questo turno; task **non** DONE. Alla ripresa: test manuali → eventuale **FIX** solo se regressioni → **REVIEW** finale → conferma utente → DONE.
- Ultimo aggiornamento: 2026-03-25
- Task ID: TASK-019
- Titolo: Robustezza: guardie array GeneratedView + cascade delete ProductPrice + async backfill
- File task: `docs/TASKS/TASK-019-robustezza-guardie-generatedview-cascade-delete-async-backfill.md`
- Stato: BLOCKED
- Motivo: **user override 2026-03-25** — execution **completata**; review tecnica **APPROVED**; **nessun fix richiesto**; **test manuali non eseguiti** in questo turno; task **non** DONE. Alla ripresa: test manuali (CA-2B/CA-3B store/delete, CA-2C dataset grande, smoke Fix A se opportuno) → eventuale **FIX** solo se emergono regressioni → **REVIEW** finale → conferma utente → DONE.
- Ultimo aggiornamento: 2026-03-25
- Task ID: TASK-018
- Titolo: GeneratedView: secondo livello revert (ai dati originali import)
- File task: `docs/TASKS/TASK-018-generatedview-second-level-revert.md`
- Stato: BLOCKED
- Motivo: **user override 2026-03-25** — execution **completata**; review codice **APPROVED**; **nessun fix richiesto**; test manuali **CA-7** (**S-1**, **M-1..M-10**, **M-12**) **non ancora eseguiti**; task **non** DONE. Alla ripresa: test manuali → eventuale **FIX** se regressioni → **REVIEW** → conferma utente → DONE.
- Ultimo aggiornamento: 2026-03-25
- Task ID: TASK-017
- Titolo: PreGenerate: validazione esplicita colonne obbligatorie
- File task: `docs/TASKS/TASK-017-pregenerate-validazione-esplicita-colonne-obbligatorie.md`
- Stato: BLOCKED
- Motivo: **user override 2026-03-24** — implementazione (execution + fix) **completata**; review tecnica **APPROVED**; **test manuali utente (T-1..T-10) non eseguiti in questa fase**; task **non** DONE. Alla ripresa: test manuali → eventuale **FIX** se regressioni → **REVIEW** → conferma utente → DONE.
- Ultimo aggiornamento: 2026-03-24
- Task ID: TASK-016
- Titolo: Deduplicazione logica import DatabaseView/ProductImportViewModel
- File task: `docs/TASKS/TASK-016-deduplicazione-logica-import-databaseview-productimportviewmodel.md`
- Stato: BLOCKED
- Motivo: review **APPROVED** (Claude) e warning build/concurrency sistemati; **test manuali ancora pendenti/non eseguiti**; task **non** DONE. Alla ripresa: test manuali → eventuale **FIX** solo se emergono regressioni → **REVIEW** → conferma utente → DONE. Riprendibile dal punto corrente senza rifare planning da zero.
- Ultimo aggiornamento: 2026-03-24
- Task ID: TASK-024
- Titolo: Full-database import progress UX + cancellation
- File task: `docs/TASKS/TASK-024-full-database-import-progress-ux-cancellation.md`
- Stato: BLOCKED
- Motivo: sospeso temporaneamente per decisione utente; review/fix UI non portati a finalizzazione; nessun DONE. Alla ripresa si continua dal punto corrente (review/fix residuo) senza rifare planning da zero.
- Ultimo aggiornamento: 2026-03-24
- Task ID: TASK-023
- Titolo: Full-database reimport idempotency + non-product diff visibility
- File task: `docs/TASKS/TASK-023-full-db-reimport-idempotency-and-non-product-diff-visibility.md`
- Stato: BLOCKED
- Motivo: **user override 2026-03-24** — sospeso temporaneamente; review codice APPROVED ma **test manuali solo parziali / non conclusi**; **non** DONE. Alla ripresa: test manuali residui + eventuale FIX + conferma utente (**nessun** nuovo planning da zero).
- Ultimo aggiornamento: 2026-03-24
- Task ID: TASK-011
- Titolo: Large import stability, memory e progress UX
- File task: `docs/TASKS/TASK-011-large-import-stability-and-progress.md`
- Stato: SUPERSEDED
- Motivo: umbrella completamente superato da TASK-022 (DONE, crash fix), TASK-023 (reimport idempotency), TASK-024 (progress UX). Nessun lavoro residuo non coperto. Aggiornato da audit 2026-03-25.
- Ultimo aggiornamento: 2026-03-25
- Task ID: TASK-009
- Titolo: Product model old prices + price backfill
- File task: `docs/TASKS/TASK-009-product-model-old-prices-price-backfill.md`
- Stato: BLOCKED
- Motivo: implementazione completata e review codice APPROVED da Claude (2026-03-22); test manuali VM-1..VM-9 non ancora eseguiti; task sospeso per decisione utente in attesa di validazione manuale futura. Alla ripresa: eseguire VM-1..VM-9, poi confermare DONE o aprire FIX se emergono regressioni.
- Ultimo aggiornamento: 2026-03-22
- Task ID: TASK-013
- Titolo: sim_ui.sh performance — batch mode, timeout reale, cache device frame
- File task: `docs/TASKS/TASK-013-sim-ui-performance.md`
- Stato: WONT_DO
- Motivo: wrapper SIM UI rimosso dal workflow standard (2026-03-22); nessun ulteriore lavoro previsto. Aggiornato da BLOCKED a WONT_DO da audit 2026-03-25.
- Ultimo aggiornamento: 2026-03-25
- Task ID: TASK-005
- Titolo: ImportAnalysis error export + inline editing
- File task: `docs/TASKS/TASK-005-importanalysis-error-export-inline-editing.md`
- Stato: BLOCKED
- Motivo: implementazione completata da Codex e task gia` portato in review, ma la validazione manuale e` ancora incompleta; sospeso temporaneamente in attesa dei test manuali residui prima di emettere APPROVED o CHANGES_REQUIRED
- Ultimo aggiornamento: 2026-03-20
- Task ID: TASK-006
- Titolo: Database full import/export (multi-sheet)
- File task: `docs/TASKS/TASK-006-database-full-import-export.md`
- Stato: BLOCKED
- Motivo: implementazione completata e review emessa APPROVED da Claude; il crash di apply su dataset grande e' stato chiuso in TASK-022; follow-up reimport/idempotency in TASK-023 (**BLOCKED** 2026-03-24, test manuali pendenti); UX progress in TASK-024 (**BLOCKED** 2026-03-24, sospeso prima della finalizzazione review/fix UI).
- Ultimo aggiornamento: 2026-03-24
- Task ID: TASK-008
- Titolo: Generated manual row dialog + calculate
- File task: `docs/TASKS/TASK-008-generated-manual-row-dialog-calculate.md`
- Stato: BLOCKED
- Motivo: review codice completata da Claude — nessun problema critico trovato, tutti i CA verificabili staticamente superati. Build verde. Validazione UI end-to-end (T-1..T-28) sospesa: richiede test manuali nel Simulator (l'automazione via wrapper SIM UI non è più parte del workflow standard). Sblocco subordinato a test manuali dell'utente o a decisione esplicita di procedere.
- Ultimo aggiornamento: 2026-03-22

## Pipeline standard del task
1. PLANNING (Claude) → definisce obiettivo, approccio, file coinvolti, criteri di accettazione
2. EXECUTION (Codex) → implementa secondo il planning, lavora contro i criteri
3. REVIEW (Claude) → verifica contro i criteri, classifica problemi, emette esito
4. FIX (Codex) → corregge quanto richiesto nella review → torna a REVIEW
5. Conferma finale utente → DONE

## Backlog
(Task futuri ordinati per priorità — aggiornabile solo da Claude o dall'utente, con motivazione esplicita)
Motivazione: TASK-002..013 proposti da TASK-001 (gap audit originale). TASK-015..021 proposti da TASK-014 (global audit approfondito, 2026-03-22). TASK-025..027 proposti da audit completo iOS vs Android (2026-03-25).

| ID | Titolo | Stato | Priorità |
|----|--------|-------|----------|
| TASK-002 | External file opening (document handoff) | DONE | CRITICAL |
| TASK-003 | PreGenerate append/reload parity | DONE | HIGH |
| TASK-004 | GeneratedView editing parity (revert, delete, mark all, search nav) | DONE | HIGH |
| TASK-005 | ImportAnalysis error export + inline editing | BLOCKED | HIGH |
| TASK-006 | Database full import/export (multi-sheet) | BLOCKED | HIGH |
| TASK-007 | History advanced filters | DONE | MEDIUM |
| TASK-008 | Generated manual row dialog + calculate | BLOCKED | MEDIUM |
| TASK-009 | Product model old prices + price backfill | BLOCKED | LOW |
| TASK-010 | Localizzazione UI multilingua | DONE | LOW |
| TASK-011 | Large import stability, memory e progress UX | SUPERSEDED | HIGH |
| TASK-012 | Simulator automation — dual-agent wrapper + adapter (sblocca TASK-008) | DONE | HIGH |
| TASK-013 | sim_ui.sh performance — batch mode, timeout reale, cache device frame | WONT_DO | — |
| TASK-014 | Global Audit & Backlog Refresh | DONE | — |
| TASK-015 | Calculate dialog in GeneratedView (GAP-15 residuo) | WONT_DO | LOW |
| TASK-016 | Deduplicazione logica import DatabaseView/ProductImportViewModel | BLOCKED | LOW |
| TASK-017 | PreGenerate: validazione esplicita colonne obbligatorie | BLOCKED | MEDIUM |
| TASK-018 | GeneratedView: secondo livello revert (ai dati originali import) | BLOCKED | MEDIUM |
| TASK-019 | Robustezza: guardie array GeneratedView + cascade delete ProductPrice + async backfill | BLOCKED | MEDIUM |
| TASK-020 | Scanner: feedback camera non disponibile | BLOCKED | LOW |
| TASK-021 | HistoryEntry: warning su dati corrotti / deserializzazione fallita | BLOCKED | LOW |
| TASK-022 | Full-database large import: apply crash after analysis (EXC_BAD_ACCESS) | DONE | HIGH |
| TASK-023 | Full-database reimport idempotency + non-product diff visibility | BLOCKED | HIGH |
| TASK-024 | Full-database import progress UX + cancellation | BLOCKED | MEDIUM |
| TASK-025 | GeneratedView: ricalcolo dinamico paymentTotal + missingItems su History card | BLOCKED | MEDIUM |
| TASK-026 | Scanner: toggle torcia (flashlight) | BLOCKED | LOW |
| TASK-027 | ManualEntrySheet: modalità «Aggiungi e continua» (rapid entry) | BLOCKED | LOW |

## Task completati
| ID | Titolo | Data completamento |
|----|--------|--------------------|
| TASK-001 | Gap Audit iOS vs Android — Censimento funzionalità mancanti | 2026-03-19 |
| TASK-003 | PreGenerate append/reload parity | 2026-03-20 |
| TASK-004 | GeneratedView editing parity (revert, delete, mark all, search nav) | 2026-03-20 |
| TASK-007 | History advanced filters | 2026-03-21 |
| TASK-012 | Simulator automation — dual-agent wrapper + adapter | 2026-03-21 |
| TASK-002 | External file opening (document handoff) | 2026-03-22 (DONE parziale: "Condividi/Invia copia" funziona; "Apri con" cross-app documentato come limite iOS noto) |
| TASK-014 | Global Audit & Backlog Refresh | 2026-03-22 |
| TASK-022 | Full-database large import: apply crash after analysis (EXC_BAD_ACCESS) | 2026-03-23 |
| TASK-010 | Localizzazione UI multilingua | 2026-03-25 |

## Blocchi e dipendenze
- TASK-027 bloccato.
  Motivo: implementation **completata**; review **APPROVED** (OK); **test manuali T-1…T-13 pendenti**; **non** **DONE**. **Pending manual verification**. Alla ripresa: test manuali → eventuale FIX → REVIEW → conferma utente → DONE.
  Nota: planning tecnico invariato nel file task; nessun **DONE** finché mancano validazione manuale e conferma utente.
- TASK-026 bloccato.
  Motivo: review **APPROVED** acquisita; **nessun fix** aperto; **test manuali T-1…T-9 pendenti**; **non** DONE. **In sospensione / pending manual validation**. Alla ripresa: test manuali → eventuale FIX → REVIEW → conferma utente → DONE.
  Nota: non invalida execution/review gia' documentati nel file task; **nessun** task **ACTIVE** corrente (stato **IDLE**).
- TASK-025 bloccato.
  Motivo: review tecnica **APPROVED** acquisita; **test manuali utente** (T-0..T-15) **pendenti**; **non** DONE. Task congelata in attesa validazione manuale. Alla ripresa: test → eventuale FIX → REVIEW finale → conferma utente → DONE.
  Nota: non invalida execution/review gia' documentati nel file task.
- TASK-021 bloccato.
  Motivo: **user override 2026-03-25** — sospeso per focus su **TASK-025**; review **APPROVED** (post-fix F-1) gia' acquisita; **non** DONE; alla ripresa: **conferma utente** (e eventuali test manuali documentati nel file task se ancora desiderati) → DONE.
  Nota: non invalida CA-1..CA-4 ne' l'execution/review gia' archiviati nel file task.
- TASK-020 bloccato.
  Motivo: **user override 2026-03-25** — review **APPROVED**; **nessun fix richiesto**; **test manuali T-1..T-6 pendenti**; **non** DONE. Alla ripresa: validazione manuale; se OK conferma utente, altrimenti FIX mirato → REVIEW.
  Nota: sospensione storica per attivare **TASK-021** (ora **TASK-021** e' **BLOCKED**); **TASK-027** ora **BLOCKED**; stato progetto **IDLE** senza task attivo.
- TASK-019 bloccato.
  Motivo: **user override 2026-03-25** — review tecnica **APPROVED**; **nessun fix richiesto**; **test manuali pendenti**; **non** DONE. Alla ripresa: validazione manuale; se OK conferma utente, altrimenti FIX mirato → REVIEW.
  Nota: sospensione per attivare **TASK-020**; non invalida execution/review documentati nel file task.
- TASK-018 bloccato.
  Motivo: **user override 2026-03-25** — review **APPROVED**; test manuali **CA-7** (**S-1**, **M-1..M-10**, **M-12**) **pendenti**; **non** DONE. Alla ripresa: validazione manuale; se OK conferma utente, altrimenti FIX mirato.
  Nota: sospensione per spostare il focus operativo su **TASK-019**; non invalida l'execution/review gia' documentati nel file task.
- TASK-017 bloccato.
  Motivo: **user override 2026-03-24** — review **APPROVED**; test manuali utente **pendenti**; **non** DONE. Alla ripresa: validazione manuale PreGenerate (matrice T-1..T-10 a integrazione); se OK conferma utente, altrimenti FIX mirato.
  Nota: sospensione per spostare il focus operativo su **TASK-018**; non invalida il merge/review gia' documentati nel file task.
- TASK-016 bloccato.
  Motivo: **user override 2026-03-24** — deduplicazione import eseguita e review **APPROVED**; test manuali utente non completati; chiusura **DONE** differita. Alla ripresa: validazione manuale perimetro Excel/simple + consumer collegati; se OK conferma utente, altrimenti FIX mirato.
  Nota: sospensione per avviare TASK-017 su richiesta utente; non invalida il lavoro gia' mergiato in review.
- TASK-011 **SUPERSEDED**.
  Motivo: umbrella task completamente superato; il crash è stato chiuso in TASK-022 (DONE), reimport idempotency in TASK-023, progress UX in TASK-024. Nessun lavoro residuo non coperto dai task derivati. Aggiornato a SUPERSEDED da audit 2026-03-25.
  Nota tracking: il planning/execution storico di TASK-011 resta documentato nel suo file task.
- TASK-006 bloccato.
  Motivo: implementazione multi-sheet completata, review emessa APPROVED da Claude. Il crash specifico nell'apply su dataset grande e' stato chiuso in TASK-022; follow-up reimport/idempotency in TASK-023 (**BLOCKED** dal 2026-03-24 per test manuali pendenti). UX progress/cancel in TASK-024 (**BLOCKED** dal 2026-03-24; sospeso prima della finalizzazione review/fix UI).
  Nota criteri: CA-1/CA-12 e CA-14 verificati; TASK-011 resta contesto storico secondario.
- TASK-008 bloccato.
  Motivo: review codice completata da Claude — nessun problema critico trovato, tutti i CA verificabili staticamente superati. Build verde. Validazione UI end-to-end (T-1..T-28) sospesa: richiede test manuali nel Simulator (l'automazione via wrapper SIM UI non è più parte del workflow standard). Sblocco subordinato a test manuali dell'utente o a decisione esplicita di procedere.
  Nota criteri: CA-1..CA-14, CA-16..CA-20 verificati da code review; CA-15 (autosave/restore round-trip) e test interattivi T-1..T-28 ancora da validare manualmente.
  Ultimo aggiornamento: 2026-03-22

## Note di coordinamento
- Il file `docs/TASKS/TASK-TEMPLATE.md` è un MODELLO, non un task reale — non usarlo come task attivo
- Naming convention: `TASK-NNN-slug-descrittivo.md` (es. `TASK-001-login-session.md`)
- ID sempre a 3 cifre (`001`, `002`, `003`...) — mai riutilizzare un ID già assegnato
- Il nuovo task prende sempre il prossimo ID disponibile (verificare le tabelle Backlog e Task completati)
- Note operative dettagliate → nei file task, non qui
- Lavoro fuori scope emerso durante execution → registrare come follow-up, non inglobare
- I follow-up candidate non bloccano la chiusura del task, salvo che siano criteri di accettazione non soddisfatti
- Task in stato DONE restano archiviati in `docs/TASKS/` — non vanno riusati né modificati (salvo note documentali minime)
- Per nuovo lavoro collegato a un task DONE → creare un nuovo task con riferimento (campo "Dipende da"), non riaprire
- User override: se l'utente dà un'istruzione in conflitto col workflow, gli agent possono seguirla ma devono segnalare l'impatto
- User override 2026-03-21: autorizzato riallineamento minimo del tracking da parte di Codex per evitare il blocco operativo tra file task e MASTER-PLAN durante l'avvio di TASK-008
- User override 2026-03-23: autorizzata da utente la sospensione di TASK-011 e la creazione/attivazione di TASK-022; backlog e tracking riallineati di conseguenza
- User override 2026-03-23: per TASK-022 il planning operativo viene svolto da Codex; il task resta in PLANNING fino all'avvio esplicito dell'execution
- User override 2026-03-23: autorizzata da utente la chiusura di TASK-022 in DONE e lo split dei follow-up in TASK-023 (attivo) e TASK-024 (backlog TODO), con aggiornamento diretto di tracking e backlog da parte di Codex
- User override 2026-03-24: TASK-023 messo in **BLOCKED** (test manuali non conclusi; non DONE); TASK-024 attivato come **task attivo** in **PLANNING** con file canonico `TASK-024-full-database-import-progress-ux-cancellation.md`; planning TASK-024 completato da Claude, execution non avviata
- User override 2026-03-24: TASK-024 sospeso in **BLOCKED** (review/fix UI non finalizzati; non DONE, riprendibile dal punto corrente) e TASK-016 attivato come **task attivo** in **PLANNING** con file canonico `TASK-016-deduplicazione-logica-import-databaseview-productimportviewmodel.md`
- User override 2026-03-24: TASK-016 messo in **BLOCKED** (review APPROVED, test manuali pendenti; non DONE); **TASK-017** attivato come **task attivo** in **PLANNING** con file `TASK-017-pregenerate-validazione-esplicita-colonne-obbligatorie.md`
- User override 2026-03-24: **TASK-017** messo in **BLOCKED** (review APPROVED, test manuali non eseguiti adesso; non DONE); creato file task **TASK-018** `TASK-018-generatedview-second-level-revert.md`; **TASK-018** attivato come **task attivo** in **PLANNING** con responsabile **CLAUDE** (planning dettagliato obbligatorio prima di EXECUTION)
- User conferma 2026-03-24: **TASK-018** planning **approvato**; fase **EXECUTION**, responsabile **CODEX**; vincoli execution/review nel file task (*Vincoli execution / review*)
- Tracking 2026-03-25: **TASK-018** execution completata da **CODEX**; fase **REVIEW**, responsabile **CLAUDE**. Build OK; verifiche manuali `S-1` / `M-1..M-10` / `M-12` non eseguite in questo turno e restano aperte.
- User override 2026-03-25: **TASK-018** messo in **BLOCKED** (review **APPROVED**, test manuali CA-7 pendenti; **non** DONE); **TASK-019** attivato come **task attivo** con file `TASK-019-robustezza-guardie-generatedview-cascade-delete-async-backfill.md` (bootstrap da backlog/TASK-014). Tracking 2026-03-25: planning tecnico TASK-019 completato; execution Codex completata; fase **REVIEW**, responsabile **CLAUDE**. Build Debug iphonesimulator OK; review richiesta su adattamento minimo Fix B per limite macro SwiftData sull'inverse reciproco.
- User override 2026-03-25: **TASK-019** messo in **BLOCKED** (review tecnica **APPROVED**, **nessun fix richiesto**, test manuali **non eseguiti**; **non** DONE); **TASK-020** attivato come **task attivo** in **PLANNING** con file `TASK-020-scanner-feedback-camera-non-disponibile.md` (bootstrap da TASK-014 gap N-10); responsabile **CLAUDE** fino a planning operativo completo e handoff verso EXECUTION.
- Tracking 2026-03-25: **TASK-020** planning operativo completato (stati scanner, architettura `ScannerView`/`BarcodeScannerView`, CA, matrice test, rischi); fase **EXECUTION**, responsabile **CODEX**.
- Tracking 2026-03-25: **TASK-020** execution completata da **CODEX**; fase **REVIEW**, responsabile **CLAUDE**. Build Debug iphonesimulator OK; verifiche statiche sui CA documentate nel file task; test manuali `T-1..T-6` non eseguiti in questo turno.
- Tracking 2026-03-25: **TASK-020** review completata da **CLAUDE**: **APPROVED**, nessun fix richiesto. In attesa **conferma utente** + test manuali `T-1..T-6`.
- User override 2026-03-25: **TASK-020** messo in **BLOCKED** (review **APPROVED**, **nessun fix richiesto**, test manuali **T-1..T-6 non eseguiti**; **non** DONE); **TASK-021** attivato come **unico task attivo** in **PLANNING** con file `TASK-021-historyentry-warning-dati-corrotti-deserializzazione.md` (bootstrap da backlog/TASK-014 gap N-12/DT-07); responsabile **CLAUDE**.
- Tracking 2026-03-25: **TASK-021** execution completata da **CODEX**; fase **REVIEW**, responsabile **CLAUDE**. Build Debug iphonesimulator OK; verifiche statiche su CA-1..CA-4 documentate nel file task; test runtime/manuali e verifica store esistente non eseguiti in questo turno.
- Tracking 2026-03-25: **TASK-021** review completata da **CLAUDE**: **CHANGES_REQUIRED** (un fix: scope creep export blocking). → **FIX** / CODEX.
- Tracking 2026-03-25: **TASK-021** fix **F-1** applicato (rimosso export blocking + `.exportBlocked` + stringhe localizzazione); build OK. → **REVIEW** post-fix / CLAUDE.
- Tracking 2026-03-25: **TASK-021** review post-fix completata da **CLAUDE**: **APPROVED**. CA-1..CA-4 soddisfatti. In attesa **conferma utente**. Test manuali T-5 (store migration) e scenari runtime T-1..T-3/T-7 restano rischi noti non eseguiti.
- User override 2026-03-25: **TASK-021** messo in **BLOCKED** (review **APPROVED** acquisita; **non** DONE; conferma utente differita); **TASK-025** attivato come **unico task attivo** in **PLANNING** con file `TASK-025-generatedview-ricalcolo-paymenttotal-missingitems-history-card.md`; planning tecnico (inclusa formula **paymentTotal** allineata Android, SSOT, UI History, **GeneratedView.summarySection** strategia A, contratto difensivo **RuntimeSummary**) documentato da **CLAUDE**.
- Tracking 2026-03-25: **TASK-025** riallineato in **EXECUTION**; responsabile **CODEX**. Scope confermato: summary runtime (`paymentTotal` / `missingItems` / `totalItems`), SSOT su `saveChanges()`, stato iniziale coerente, chip `missingItems` in `HistoryView`, layout card a due righe, anti-regressione `GeneratedView.summarySection`.
- Tracking 2026-03-25: **TASK-025** execution completata da **CODEX**; fase **REVIEW**, responsabile **CLAUDE**. Build Debug iphonesimulator OK; implementati helper runtime summary, integrazione `saveChanges()`/`generateHistoryEntry`/revert, chip `missingItems` in `HistoryView`, layout card a due righe e anti-regressione `GeneratedView.summarySection`. Verifiche Simulator/manuali non eseguite in questo turno.
- Tracking 2026-03-25: **TASK-025** review tecnica completata da **CLAUDE**: **APPROVED**. CA-1..CA-9 verificati staticamente; formula `paymentTotal` conforme Decisione #1; SSOT su `saveChanges()` coerente; contratto difensivo rispettato; guardrail handoff rispettati; build OK; nessun fix richiesto. In attesa **test manuali utente** (T-0..T-15) e **conferma utente**.
- User override 2026-03-25: **TASK-025** messo in **BLOCKED** (review **APPROVED** acquisita; test manuali **non eseguiti**; **non** DONE). **TASK-026** attivato come **unico task attivo** in **PLANNING** con file `TASK-026-scanner-toggle-torcia-flashlight.md`; bootstrap planning iniziale; responsabile **CLAUDE**.
- Tracking 2026-03-25: **TASK-026** — planning **completato**; handoff **EXECUTION** registrato; stato **ACTIVE**, fase **EXECUTION**, responsabile **CODEX**; parte preparatoria (documentazione + **MASTER-PLAN**) chiusa da **CLAUDE**; **prossimo step = execution Codex** (nessun avvio implementazione in questo aggiornamento).
- Tracking 2026-03-25: **TASK-026** review **APPROVED** (nessun fix); task messo in **BLOCKED** — **test manuali T-1…T-9 non eseguiti**; **pending manual validation**. **TASK-027** attivato come unico **ACTIVE** in **PLANNING** con file `TASK-027-manualentrysheet-aggiungi-e-prossimo.md`; responsabile **CLAUDE** fino a planning completo e handoff verso **EXECUTION**.
- Tracking 2026-03-25: **TASK-027** — planning **completato e approvato** dall'utente; transizione **PLANNING → EXECUTION**; responsabile **CODEX**; handoff post-planning nel file task dichiarato **valido**; aggiornamento **solo tracking** (nessun ripensamento tecnico/UX nel planning).
- Tracking 2026-03-25: **TASK-027** — execution **completata**; review **APPROVED** (OK); test manuali **non eseguiti**; task messo in **BLOCKED** (**pending manual verification**); **non** **DONE**. **Nessun** task **ACTIVE** nel backlog (nessuna voce **TODO**); stato globale **IDLE** fino a nuova scelta operativa dell'utente.
- Tracking 2026-03-25: **TASK-010** chiusa in **DONE** su conferma utente. Regressione localizzazione verificata come risolta: root cause = delimitatori Unicode invalidi in 3 `Localizable.strings` non inglesi; hotfix minimo applicato e verificato, nessun task figlio aperto.
- Audit 2026-03-25: **audit completo iOS vs Android** eseguito su richiesta utente. Confronto granulare di tutte le aree funzionali (inventario, database, cronologia, scanner, import/export, opzioni, sync, storico prezzi). Risultato: iOS copre ~95% delle feature Android. Gap residui: (1) paymentTotal non ricalcolato dinamicamente, (2) assenza toggle torcia nello scanner, (3) rapid entry manuale affrontata da **TASK-027** (copy «Aggiungi e continua»; task **BLOCKED** — validazione manuale pendente). Creati **TASK-025**, **TASK-026**, **TASK-027**. Aggiornati: **TASK-011** → SUPERSEDED, **TASK-013** → WONT_DO.

## Criterio di aggiornamento
Questo file va aggiornato SOLO quando cambia almeno uno di:
- Task attivo (nuovo, cambiato, rimosso)
- Fase attuale del task attivo
- Stato di un task (TODO → ACTIVE → BLOCKED → DONE)
- Blocchi o dipendenze
- Avanzamento reale del progetto
- Backlog o priorità (solo Claude o utente, con motivazione)
NON aggiornare per note operative, dettagli di implementazione, o micro-progressi.
