# Master Plan — iOSMerchandiseControl

## Progetto
iOSMerchandiseControl — app iOS per controllo merce e inventario

## Obiettivo attuale
TASK-023 ACTIVE — Full-database reimport idempotency + non-product diff visibility (PLANNING in corso, responsabile: CLAUDE).

## Stato globale
ACTIVE
> TASK-023 in PLANNING (full-database reimport idempotency + non-product diff visibility). TASK-022 e' stato chiuso in DONE il 2026-03-23 su conferma esplicita utente dopo test manuali finali riusciti: il full-database import grande completa correttamente e il crash conferma -> apply non si riproduce piu' sul build aggiornato. Il follow-up emerso sui reimport full-database viene separato in TASK-023 per correttezza/performance dei delta e visibilita' dei cambiamenti non-product; TASK-024 viene aperto separatamente come backlog TODO per progress UX + cancellation. TASK-011 resta BLOCKED come umbrella storico sospeso; i follow-up residui sono ora scorporati. TASK-014 completato (global audit & backlog refresh, 2026-03-22). TASK-002 chiuso come DONE parziale (2026-03-22): "Condividi/Invia copia" funziona; "Apri con" cross-app documentato come limite iOS noto. TASK-015 WONT_DO (2026-03-22). TASK-010 bloccato (review tecnica finale APPROVED, test manuali finali sospesi per decisione utente), TASK-003 completato, TASK-004 completato, TASK-005 bloccato in attesa di test manuali completi, TASK-006 bloccato (implementazione multi-sheet completata; follow-up pratico residuo sul reimport affidabile estratto in TASK-023), TASK-008 bloccato (review codice superata, validazione UI end-to-end sospesa — test manuali), TASK-009 bloccato (implementazione completata, review codice APPROVED, test manuali sospesi per decisione utente), TASK-012 completato, TASK-013 bloccato (sospeso per decisione utente: workflow SIM UI rimosso dal processo standard).

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
- Task ID: TASK-023
- Titolo: Full-database reimport idempotency + non-product diff visibility
- File task: `docs/TASKS/TASK-023-full-db-reimport-idempotency-and-non-product-diff-visibility.md`
- Stato: ACTIVE
- Fase attuale: PLANNING
- Responsabile attuale: CLAUDE
- Ultimo aggiornamento: 2026-03-23

Task bloccati non attivi:
- Task ID: TASK-011
- Titolo: Large import stability, memory e progress UX
- File task: `docs/TASKS/TASK-011-large-import-stability-and-progress.md`
- Stato: BLOCKED
- Motivo: sospeso per decisione utente; il crash specifico conferma -> apply e' stato chiuso in TASK-022, mentre i follow-up residui vengono separati in TASK-023 (idempotency + non-product diff visibility) e TASK-024 (progress UX + cancellation) senza riaprire l'umbrella.
- Ultimo aggiornamento: 2026-03-23
- Task ID: TASK-010
- Titolo: Localizzazione UI multilingua
- File task: `docs/TASKS/TASK-010-localizzazione-ui-multilingua.md`
- Stato: BLOCKED
- Motivo: review tecnica finale APPROVED; test manuali finali ancora pendenti (CA-2, CA-3, CA-6). Task sospesa per decisione utente in attesa di futura ripresa. Alla ripresa: eseguire solo test manuali finali, poi confermare DONE o aprire FIX se emergono regressioni.
- Ultimo aggiornamento: 2026-03-22
- Task ID: TASK-009
- Titolo: Product model old prices + price backfill
- File task: `docs/TASKS/TASK-009-product-model-old-prices-price-backfill.md`
- Stato: BLOCKED
- Motivo: implementazione completata e review codice APPROVED da Claude (2026-03-22); test manuali VM-1..VM-9 non ancora eseguiti; task sospeso per decisione utente in attesa di validazione manuale futura. Alla ripresa: eseguire VM-1..VM-9, poi confermare DONE o aprire FIX se emergono regressioni.
- Ultimo aggiornamento: 2026-03-22
- Task ID: TASK-013
- Titolo: sim_ui.sh performance — batch mode, timeout reale, cache device frame
- File task: `docs/TASKS/TASK-013-sim-ui-performance.md`
- Stato: BLOCKED
- Motivo: sospeso per decisione utente (2026-03-22) — wrapper SIM UI rimosso dal workflow standard del progetto per latenza/prestazioni non adeguate ai test rapidi. Nessun ulteriore lavoro di ottimizzazione previsto.
- Ultimo aggiornamento: 2026-03-22
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
- Motivo: implementazione completata e review emessa APPROVED da Claude; il crash di apply su dataset grande e' stato chiuso in TASK-022, ma dai test reali e' emerso un follow-up pratico sul reimport full-database invariato (idempotency + visibilita' delta) estratto in TASK-023
- Ultimo aggiornamento: 2026-03-23
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
Motivazione: TASK-002..013 proposti da TASK-001 (gap audit originale). TASK-015..021 proposti da TASK-014 (global audit approfondito, 2026-03-22).

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
| TASK-010 | Localizzazione UI multilingua | BLOCKED | LOW |
| TASK-011 | Large import stability, memory e progress UX | BLOCKED | HIGH |
| TASK-012 | Simulator automation — dual-agent wrapper + adapter (sblocca TASK-008) | DONE | HIGH |
| TASK-013 | sim_ui.sh performance — batch mode, timeout reale, cache device frame | BLOCKED | HIGH |
| TASK-014 | Global Audit & Backlog Refresh | DONE | — |
| TASK-015 | Calculate dialog in GeneratedView (GAP-15 residuo) | WONT_DO | LOW |
| TASK-016 | Deduplicazione logica import DatabaseView/ProductImportViewModel | TODO | LOW |
| TASK-017 | PreGenerate: validazione esplicita colonne obbligatorie | TODO | MEDIUM |
| TASK-018 | GeneratedView: secondo livello revert (ai dati originali import) | TODO | MEDIUM |
| TASK-019 | Robustezza: guardie array GeneratedView + cascade delete ProductPrice + async backfill | TODO | MEDIUM |
| TASK-020 | Scanner: feedback camera non disponibile | TODO | LOW |
| TASK-021 | HistoryEntry: warning su dati corrotti / deserializzazione fallita | TODO | LOW |
| TASK-022 | Full-database large import: apply crash after analysis (EXC_BAD_ACCESS) | DONE | HIGH |
| TASK-023 | Full-database reimport idempotency + non-product diff visibility | ACTIVE | HIGH |
| TASK-024 | Full-database import progress UX + cancellation | TODO | MEDIUM |

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

## Blocchi e dipendenze
- TASK-011 bloccato.
  Motivo: sospeso per decisione utente; TASK-022 ha chiuso il crash specifico conferma -> apply, mentre i follow-up residui vengono scorporati in TASK-023 e TASK-024 senza riaprire l'umbrella.
  Nota tracking: il planning/execution storico di TASK-011 resta documentato nel suo file task, ma il lavoro residuo e' ora tracciato nei task separati piu' stretti.
- TASK-006 bloccato.
  Motivo: implementazione multi-sheet completata, review emessa APPROVED da Claude. Il crash specifico nell'apply su dataset grande e' stato chiuso in TASK-022, ma durante i test reali e' emerso un follow-up sul reimport invariato del full database (idempotency + visibilita' delta non-product). Sblocco pratico subordinato al completamento di TASK-023.
  Nota criteri: CA-1/CA-12 e CA-14 verificati; il follow-up pratico corrente sul reimport full-database e' TASK-023. TASK-011 resta solo come contesto storico secondario.
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

## Criterio di aggiornamento
Questo file va aggiornato SOLO quando cambia almeno uno di:
- Task attivo (nuovo, cambiato, rimosso)
- Fase attuale del task attivo
- Stato di un task (TODO → ACTIVE → BLOCKED → DONE)
- Blocchi o dipendenze
- Avanzamento reale del progetto
- Backlog o priorità (solo Claude o utente, con motivazione)
NON aggiornare per note operative, dettagli di implementazione, o micro-progressi.
