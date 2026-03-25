# TASK-019: Robustezza — guardie array GeneratedView + cascade delete ProductPrice + async backfill

## Informazioni generali
- **Task ID**: TASK-019
- **Titolo**: Robustezza: guardie array GeneratedView + cascade delete ProductPrice + async backfill
- **File task**: `docs/TASKS/TASK-019-robustezza-guardie-generatedview-cascade-delete-async-backfill.md`
- **Stato**: ACTIVE
- **Fase attuale**: PLANNING
- **Responsabile attuale**: CLAUDE
- **Data creazione**: 2026-03-25
- **Ultimo aggiornamento**: 2026-03-25 (bootstrap file task + attivazione da backlog; planning tecnico da completare)
- **Ultimo agente che ha operato**: CLAUDE *(bootstrap file task + attivazione backlog)*

## Dipendenze
- **Dipende da**: nessuno (come da TASK-014 / MASTER-PLAN).
- **Sblocca**: riduzione rischio crash/corruzione silenziosa in `GeneratedView`; integrità delete `Product`→`ProductPrice`; avvio app senza freeze su backfill (vedi sotto).

## Scopo
Tre interventi di robustezza raggruppati per efficienza operativa: **(A)** allineamento/guardie tra `data` / `editable` / `complete` in `GeneratedView` dopo mutazioni; **(B)** `deleteRule: .cascade` sulla relazione `priceHistory` di `Product`; **(C)** esecuzione asincrona/non bloccante di `backfillIfNeeded()` all’avvio (thread-safety SwiftData rispettata). Dettaglio CA e file definitivi vanno completati in **Planning**.

## Contesto
Definizione e motivazione in **TASK-014** (sezione «TASK-019 — Robustezza…», 2026-03-22). Evidenza codice citata lì: `GeneratedView.swift`, `Models.swift` (`Product` / `ProductPrice`), `ContentView.swift` + eventuale `PriceHistoryBackfillService.swift`.

## Non incluso
- Auto-riparazione silenziosa degli array in **Fix A** (solo guardie + messaggio/banner come da TASK-014).
- Modifica alla logica di business del backfill (quali record creare) in **Fix C**.
- Scope al di fuori dei tre sotto-perimetri salvo emergenza documentata nel file task.

## File potenzialmente coinvolti
- `iOSMerchandiseControl/GeneratedView.swift` — Fix A
- `iOSMerchandiseControl/Models.swift` — Fix B
- `iOSMerchandiseControl/ContentView.swift` — Fix C
- `iOSMerchandiseControl/PriceHistoryBackfillService.swift` — Fix C solo se necessario per thread-safety

## Criteri di accettazione
*(Bootstrap da TASK-014; rifinire in planning se serve — execution lavora contro la versione finale.)*

**Fix A — GeneratedView**
- [ ] **CA-1A**: Dopo ogni operazione che modifica `data` / `editable` / `complete` (delete, append, revert, init), verificata uguaglianza delle lunghezze.
- [ ] **CA-2A**: Se il check fallisce: `debugPrint` con prefisso coerente (es. `[GeneratedView]`).
- [ ] **CA-3A**: UI con banner/messaggio non bloccante invece di crash.

**Fix B — Cascade ProductPrice**
- [ ] **CA-1B**: `@Relationship(deleteRule: .cascade)` su `priceHistory` in `Product`.
- [ ] **CA-2B**: Delete `Product` elimina `ProductPrice` associati nella stessa transazione.
- [ ] **CA-3B**: Build ok; avvio su DB preesistente; nessun effetto collaterale su `ProductPrice` di altri prodotti.

**Fix C — Backfill async**
- [ ] **CA-1C**: `backfillIfNeeded()` non chiamato in modo sincrono bloccante sul main thread all’avvio.
- [ ] **CA-2C**: UI interattiva subito su DB grande (es. 1000+ prodotti) — verifica manuale o documentata.
- [ ] **CA-3C**: Stesso risultato dati del backfill rispetto al comportamento precedente (foreground/background).

## Decisioni
| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|-------|
| 1 | Bootstrap da TASK-014 senza planning tecnico completo in questo turno | Planning monolitico immediato | Attivazione backlog + file reale; planning a CLAUDE | attiva |

---

## Planning (Claude)

### Analisi
*[Da completare — rileggere `GeneratedView` (mutazioni array), `Product`/`ProductPrice`, `ContentView` + backfill service.]*

### Approccio proposto
*[Da completare — tre sotto-perimetri A/B/C isolabili in execution.]*

### File da modificare
*[Da confermare — lista provvisoria in «File potenzialmente coinvolti».]*

### Rischi identificati
*[Da completare — migrazione SwiftData Fix B; thread-safety Fix C.]*

### Handoff → Execution
- **Prossima fase**: EXECUTION *(solo dopo planning valido: analisi, approccio, file, rischi, CA finali, handoff esplicito — vedi CLAUDE.md)*
- **Prossimo agente**: CODEX
- **Azione consigliata**: attendere completamento Planning obbligatorio; poi implementare A → B → C (o ordine concordato in planning).

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
