# Master Plan — iOSMerchandiseControl

## Progetto
iOSMerchandiseControl — app iOS per controllo merce e inventario

## Obiettivo attuale
Nessun task attivo. TASK-004 completato. Prossimo task da attivare: TASK-005 (ImportAnalysis error export) o altro task HIGH nel backlog.

## Stato globale
IDLE — Nessun task attivo in lavorazione
> TASK-002 bloccato, TASK-003 completato, TASK-004 completato.

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
Nessuno.

Task bloccato non attivo:
- Task ID: TASK-002
- Titolo: External file opening (document handoff via CFBundleDocumentTypes)
- File task: `docs/TASKS/TASK-002-external-file-opening.md`
- Stato: BLOCKED
- Motivo: `Condividi / Invia copia` funziona, ma `Apri con` non e` affidabilmente disponibile per file `.xlsx` da alcune app di terze parti; le fix minime tentate su `Info.plist` non hanno chiuso il criterio di accettazione in modo verificabile e il comportamento residuo sembra dipendere anche dall'app sorgente / dal flusso esposto da iOS
- Ultimo aggiornamento: 2026-03-19

## Pipeline standard del task
1. PLANNING (Claude) → definisce obiettivo, approccio, file coinvolti, criteri di accettazione
2. EXECUTION (Codex) → implementa secondo il planning, lavora contro i criteri
3. REVIEW (Claude) → verifica contro i criteri, classifica problemi, emette esito
4. FIX (Codex) → corregge quanto richiesto nella review → torna a REVIEW
5. Conferma finale utente → DONE

## Backlog
(Task futuri ordinati per priorità — aggiornabile solo da Claude o dall'utente, con motivazione esplicita)
Motivazione: proposti dal gap audit TASK-001 come risultato dell'analisi iOS vs Android.

| ID | Titolo | Stato | Priorità |
|----|--------|-------|----------|
| TASK-002 | External file opening (document handoff) | BLOCKED | CRITICAL |
| TASK-003 | PreGenerate append/reload parity | DONE | HIGH |
| TASK-004 | GeneratedView editing parity (revert, delete, mark all, search nav) | DONE | HIGH |
| TASK-005 | ImportAnalysis error export + inline editing | TODO | HIGH |
| TASK-006 | Database full import/export (multi-sheet) | TODO | HIGH |
| TASK-007 | History advanced filters | TODO | MEDIUM |
| TASK-008 | Generated manual row dialog + calculate | TODO | MEDIUM |
| TASK-009 | Product model old prices + price backfill | TODO | LOW |
| TASK-010 | Localizzazione UI multilingua | TODO | LOW |

## Task completati
| ID | Titolo | Data completamento |
|----|--------|--------------------|
| TASK-001 | Gap Audit iOS vs Android — Censimento funzionalità mancanti | 2026-03-19 |
| TASK-003 | PreGenerate append/reload parity | 2026-03-20 |
| TASK-004 | GeneratedView editing parity (revert, delete, mark all, search nav) | 2026-03-20 |

## Blocchi e dipendenze
- TASK-002 bloccato.
  Motivo: il flusso `Condividi / Invia copia` e` funzionante, ma il flusso `Apri con` non e` affidabilmente disponibile per file `.xlsx` da alcune app di terze parti. Le fix minime tentate su `Info.plist` non hanno chiuso il criterio di accettazione in modo verificabile. Il comportamento residuo sembra dipendere anche dall'app sorgente / dal flusso esposto da iOS.
  Nota criteri: soddisfatti il document handoff di base e il flusso `Condividi / Invia copia`; ancora non chiuso il criterio di disponibilita` affidabile di `Apri con` cross-app.
  Follow-up candidate: task dedicato per chiarire la differenza tra document handoff supportato nei flussi Files/system e vero supporto `Apri con` cross-app, con decisione esplicita su eventuale open-in-place/coordinazione file.

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

## Criterio di aggiornamento
Questo file va aggiornato SOLO quando cambia almeno uno di:
- Task attivo (nuovo, cambiato, rimosso)
- Fase attuale del task attivo
- Stato di un task (TODO → ACTIVE → BLOCKED → DONE)
- Blocchi o dipendenze
- Avanzamento reale del progetto
- Backlog o priorità (solo Claude o utente, con motivazione)
NON aggiornare per note operative, dettagli di implementazione, o micro-progressi.
