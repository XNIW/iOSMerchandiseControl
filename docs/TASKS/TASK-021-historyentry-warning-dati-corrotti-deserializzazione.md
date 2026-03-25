# TASK-021: HistoryEntry — warning su dati corrotti / deserializzazione fallita

## Informazioni generali
- **Task ID**: TASK-021
- **Titolo**: HistoryEntry: warning su dati corrotti / deserializzazione fallita
- **File task**: `docs/TASKS/TASK-021-historyentry-warning-dati-corrotti-deserializzazione.md`
- **Stato**: ACTIVE
- **Fase attuale**: PLANNING
- **Responsabile attuale**: CLAUDE
- **Data creazione**: 2026-03-25
- **Ultimo aggiornamento**: 2026-03-25 (bootstrap file task + attivazione da MASTER-PLAN; planning operativo da completare)
- **Ultimo agente che ha operato**: CLAUDE *(tracking)*

## Dipendenze
- **Dipende da**: nessuno (TASK-014 gap **N-12** / debito **DT-07**).
- **Sblocca**: visibilità utente su sessioni inventario con JSON `data`/`editable`/`complete` illeggibili; riduzione silenzio su errori di decodifica.

## Scopo
Quando la decodifica JSON di `dataJSON`, `editableJSON` o `completeJSON` su **`HistoryEntry`** fallisce, l’app oggi può restituire array vuoti **senza spiegazione**. Il task introduce **logging diagnostico**, un **flag di corruzione** persistito dove appropriato, e **feedback visivo** in elenco cronologia e in **`GeneratedView`** per le entry interessate.

## Contesto
Origine: **TASK-014** (gap **N-12**, **DT-07**, VERIFICATO_IN_CODICE). I computed property che espongono griglia/editable/complete usano pattern tipo `(try? JSONDecoder().decode(...)) ?? []` senza log né segnalazione utente.

## Non incluso
- Tentativo di recupero automatico dei dati corrotti o migrazione del formato JSON.
- Cancellazione automatica delle entry corrotte.
- Refactor di ampio formato al di fuori del perimetro HistoryEntry / viste citate nel planning definitivo.

## File potenzialmente coinvolti
- `iOSMerchandiseControl/HistoryEntry.swift` — modello, computed property JSON, eventuale campo `isCorrupt` (o equivalente documentato in planning).
- `iOSMerchandiseControl/HistoryView.swift` — indicatore/badge entry corrotte.
- `iOSMerchandiseControl/GeneratedView.swift` — banner o messaggio in apertura sessione corrotta.
- `iOSMerchandiseControl/*.lproj/Localizable.strings` (o meccanismo `L(...)` / xcstrings già in uso) — stringhe utente nuove.

## Criteri di accettazione
*(Bootstrap da TASK-014; CLAUDE rifinisce nel planning operativo prima dell’handoff a EXECUTION.)*

- [ ] **CA-1**: Se la decodifica di `dataJSON`, `editableJSON` o `completeJSON` fallisce con eccezione, viene emesso `debugPrint` tracciabile (es. prefisso `[HistoryEntry …]` + id/identificativo + errore) oltre al fallback a array vuoto.
- [ ] **CA-2**: `HistoryEntry` espone un campo persistito (es. `isCorrupt: Bool?`) impostato a `true` al primo fallback di deserializzazione fallita (semantica esatta in planning).
- [ ] **CA-3**: In **HistoryView**, le entry con corruzione segnalata mostrano un indicatore distintivo (icona/badge) comprensibile per l’utente.
- [ ] **CA-4**: Aprendo in **GeneratedView** una entry marcata come corrotta, compare un messaggio/banner esplicito (testo localizzato) invece di una griglia vuota silenziosa.

## Decisioni
| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|-------|
| 1 | Bootstrap da TASK-014 senza planning tecnico completo in questo turno | Planning completo immediato | Attivazione backlog + file reale; planning dettagliato a CLAUDE in fase PLANNING | attiva |

---

## Planning (Claude)

### Obiettivo
*(Da completare: obiettivo operativo allineato ai CA e al modello SwiftData attuale.)*

### Analisi
*(Da completare: leggere `HistoryEntry.swift`, punti di decodifica, `HistoryView` / `GeneratedView`.)*

### Approccio proposto
*(Da completare: strategia minima per CA-1..CA-4, migrazione SwiftData se necessaria.)*

### File da modificare
*(Lista definitiva dopo analisi.)*

### Rischi identificati
*(Da completare: migrazione modello, falsi positivi, performance.)*

### Handoff → Execution
- **Prossima fase**: EXECUTION *(solo dopo planning operativo completo: analisi, approccio, rischi, CA finali, handoff esplicito)*
- **Prossimo agente**: CODEX
- **Azione consigliata**: implementare secondo planning approvato; build + verifiche richieste dal task.

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
