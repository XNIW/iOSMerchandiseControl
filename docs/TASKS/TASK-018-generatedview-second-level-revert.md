# TASK-018: GeneratedView — secondo livello revert (ai dati originali import)

## Informazioni generali
- **Task ID**: TASK-018
- **Titolo**: GeneratedView: secondo livello revert (ai dati originali import)
- **File task**: `docs/TASKS/TASK-018-generatedview-second-level-revert.md`
- **Stato**: ACTIVE
- **Fase attuale**: PLANNING
- **Responsabile attuale**: CLAUDE
- **Data creazione**: 2026-03-24
- **Ultimo aggiornamento**: 2026-03-24 (file task creato; bootstrap da TASK-014 GAP-03; planning dettagliato da completare)
- **Ultimo agente che ha operato**: CLAUDE *(bootstrap file task + tracking workflow su richiesta utente 2026-03-24)*

## Dipendenze
- **Dipende da**: nessun blocco duro (nota TASK-014: idealmente post-TASK-008 DONE per ridurre conflitti su `GeneratedView`; TASK-008 resta BLOCKED per test manuali — non prerequisito formale nel backlog MASTER-PLAN).
- **Sblocca**: chiusura GAP-03 (parity revert Android); vedi audit TASK-014.

## Scopo
Implementare un **secondo livello** di revert in `GeneratedView` che riporti i dati allo stato dell’**import originale** (prima di modifiche utente, incluse sessioni autosalvate precedenti). Il livello attuale (`originalData`) riflette solo l’inizio della **sessione corrente**.

## Contesto
Origine: **TASK-014** (GAP-03 parziale da TASK-001). Su Android esistono due livelli di revert; iOS dopo TASK-004 ha un solo livello. Evidenza: `GeneratedView.swift` — `originalData` al load della sessione corrente, non al momento di `generateHistoryEntry()`.

## Non incluso
- Modifica al revert di livello 1 esistente.
- UI fuori da `GeneratedView` salvo necessità emersa in planning e documentata.

## File potenzialmente coinvolti
- `Models.swift` — campo `originalDataJSON` su `HistoryEntry` (opzionale; entry legacy `nil`).
- `ExcelSessionViewModel.swift` — `generateHistoryEntry()`.
- `GeneratedView.swift` — seconda azione revert + logica + conferma utente.

## Criteri di accettazione
- [ ] **CA-1**: In `generateHistoryEntry()`, `HistoryEntry.originalDataJSON` contiene i dati griglia dell’import originale e **non** viene mai modificato da autosave o operazioni successive.
- [ ] **CA-2**: In `GeneratedView` esiste un secondo controllo revert (“Ripristina import originale”) **distinto** dal revert di livello 1.
- [ ] **CA-3**: Al secondo revert, la griglia torna ai dati di `originalDataJSON`, con autosave; **conferma utente** obbligatoria prima dell’azione (irreversibile rispetto alle modifiche correnti).
- [ ] **CA-4**: Se `originalDataJSON == nil` (entry pre-task), il secondo revert **non** è disponibile (nascosto o disabilitato con messaggio tipo snapshot non disponibile).

## Decisioni
| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|-------|
| 1 | Bootstrap tracking da TASK-014 senza planning tecnico completo in questo turno | Planning completo immediato | Richiesta utente: solo passaggio operativo; planning a CLAUDE | attiva |

---

## Planning (Claude)

### Analisi
*[Da completare — leggere `GeneratedView.swift`, `HistoryEntry`, `generateHistoryEntry(in:)`, confronto Android documentato in TASK-014.]*

### Approccio proposto
*[Da completare dopo analisi — allineato a CA-1..CA-4 e nota migrazione SwiftData TASK-014.]*

### File da modificare
*[Da confermare in planning — lista provvisoria in sezione "File potenzialmente coinvolti".]*

### Rischi identificati
*[Da completare — includere migrazione `originalDataJSON` opzionale e fallback nil.]*

### Handoff → Execution
- **Prossima fase**: EXECUTION *(solo dopo planning valido: obiettivo, analisi, approccio, file, rischi, criteri, handoff completi — vedi CLAUDE.md)*
- **Prossimo agente**: CODEX
- **Azione consigliata**: attendere completamento sezioni Planning obbligatorie da CLAUDE; poi implementare secondo criteri di accettazione.

---

## Execution (Codex)
*(Non avviata.)*

---

## Review (Claude)
*(Non avviata.)*

---

## Fix (Codex)
*(Non applicabile.)*

---

## Chiusura
### Conferma utente
- [ ] Utente ha confermato il completamento

### Follow-up candidate
[Da compilare se necessario]

### Riepilogo finale
[Da compilare in chiusura]

### Data completamento
YYYY-MM-DD
