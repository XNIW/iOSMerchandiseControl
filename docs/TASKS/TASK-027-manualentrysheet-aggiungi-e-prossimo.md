# TASK-027: ManualEntrySheet — modalità «Aggiungi e prossimo» (rapid entry)

## Informazioni generali
- **Task ID**: TASK-027
- **Titolo**: ManualEntrySheet: modalità «Aggiungi e prossimo» (rapid entry)
- **File task**: `docs/TASKS/TASK-027-manualentrysheet-aggiungi-e-prossimo.md`
- **Stato**: ACTIVE
- **Fase attuale**: PLANNING
- **Responsabile attuale**: CLAUDE
- **Data creazione**: 2026-03-25
- **Ultimo aggiornamento**: 2026-03-25 *(attivazione da backlog **MASTER-PLAN** dopo sospensione **TASK-026**; file task creato per coerenza path; **planning operativo da completare** prima di **EXECUTION**)*
- **Ultimo agente che ha operato**: CLAUDE *(bootstrap tracking)*

## Dipendenze
- **Dipende da**: nessuno (origine: audit iOS vs Android 2026-03-25 — gap funzionale su entry manuale rapida).
- **Sblocca**: parità UX con Android su inserimenti consecutivi da **`ManualEntrySheet`** (`GeneratedView.swift`).

## Scopo
Introdurre una modalità (es. **«Aggiungi e prossimo»** o equivalente documentato in planning) che permetta, dopo l’aggiunta di una riga manuale all’inventario, di **preparare immediatamente** l’inserimento della **riga successiva** con meno attrito rispetto al flusso attuale che richiede di **chiudere e riaprire** il foglio per ogni articolo — **senza** rimuovere il comportamento **salva e chiudi** esistente salvo decisione esplicita in planning.

## Contesto
- Su Android è prevista una modalità di **rapid entry** nell’aggiunta manuale; su iOS **`ManualEntrySheet`** è definito in **`GeneratedView.swift`** e oggi non espone un flusso equivalente documentato nel backlog.
- Task inserito in tabella backlog **MASTER-PLAN** (2026-03-25); questo file materializza il path canonico richiesto dal workflow progetto.

## Non incluso
- Refactor non necessario di **`GeneratedView`** oltre al perimetro che il **planning** definirà esplicitamente.
- Nuove dipendenze SPM senza richiesta esplicita.
- Parità riga-per-riga col codice Kotlin (solo riferimento funzionale).

## File potenzialmente coinvolti
- `iOSMerchandiseControl/GeneratedView.swift` — **`ManualEntrySheet`** e call site `.sheet` collegati (da confermare in planning).

## Criteri di accettazione
Questi criteri sono il contratto del task; il **planning** può rifinirli ma non rimuoverne la verificabilità senza aggiornamento esplicito.

- [ ] **CA-1** (da rifinire in planning): L’utente può usare una modalità **rapid entry** su **`ManualEntrySheet`** (dettaglio UX e stringhe da definire) che riduce i passaggi per **inserimenti consecutivi** rispetto al solo flusso attuale chiudi→riapri, **senza regressioni** al percorso **salva e chiudi** oggi disponibile (salvo decisione registrata nelle **Decisioni**).
- [ ] **CA-2**: Build **Debug** compila senza errori; nessun nuovo warning **evitabile** introdotto.

## Decisioni
| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|-------|
| — | *(nessuna ancora — da compilare in planning)* | — | — | — |

---

## Planning (Claude) ← solo Claude aggiorna questa sezione

### Stato bootstrap (2026-03-25)
Il **planning operativo completo** (obiettivo dettagliato, analisi, approccio, file coinvolti definitivi, rischi, criteri di accettazione rifiniti, **handoff valido verso EXECUTION**) **non è ancora compilato** in questo turno — è il **prossimo passo** del responsabile **CLAUDE**.

### Handoff post-planning → EXECUTION (Codex)
- **Prossima fase**: *(da impostare dopo planning completo — tipicamente **EXECUTION**)*
- **Prossimo agente**: *(tipicamente **CODEX** dopo handoff valido)*
- **Azione consigliata**: *(da compilare quando il planning sarà completo e coerente con i criteri di accettazione)*

---

## Execution (Codex) ← solo Codex aggiorna questa sezione

_(vuoto — non avviare senza handoff valido da **Planning**.)_

---

## Review (Claude) ← solo Claude aggiorna questa sezione

_(vuoto)_

---

## Fix (Codex) ← solo Codex aggiorna questa sezione

_(vuoto)_

---

## Chiusura

### Conferma utente
- [ ] Utente ha confermato il completamento

### Follow-up candidate
- _(eventuale — da aggiornare in chiusura)_

### Riepilogo finale
_(al DONE)_

### Data completamento
_(al DONE)_
