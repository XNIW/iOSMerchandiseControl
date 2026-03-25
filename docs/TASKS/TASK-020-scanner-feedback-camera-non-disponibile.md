# TASK-020: Scanner — feedback camera non disponibile

## Informazioni generali
- **Task ID**: TASK-020
- **Titolo**: Scanner: feedback camera non disponibile
- **File task**: `docs/TASKS/TASK-020-scanner-feedback-camera-non-disponibile.md`
- **Stato**: ACTIVE
- **Fase attuale**: PLANNING
- **Responsabile attuale**: CLAUDE
- **Data creazione**: 2026-03-25
- **Ultimo aggiornamento**: 2026-03-25 (bootstrap file task + attivazione da MASTER-PLAN; planning operativo da completare)
- **Ultimo agente che ha operato**: CLAUDE *(tracking)*

## Dipendenze
- **Dipende da**: nessuno (TASK-014 gap N-10).
- **Sblocca**: chiusura percepita del gap «schermo vuoto» scanner su simulatore / permesso negato / hardware assente.

## Scopo
Quando la camera non è disponibile o il permesso è negato, `BarcodeScannerView` non deve mostrare uno schermo vuoto: serve un fallback UX con messaggio chiaro e, se applicabile, accesso rapido alle impostazioni iOS dell’app.

## Contesto
Origine: **TASK-014** (gap **N-10**, VERIFICATO_IN_CODICE). Evidenza indicativa: `BarcodeScannerView.swift` — assenza di branch esplicito dopo fallimento di `AVCaptureDevice.default()`; esperienza utente degradata su simulatore o con permesso negato.

## Non incluso
- Cambio di framework di scansione o logica di parsing barcode.
- Richiesta proattiva del permesso camera (resta comportamento iOS / flussi esistenti salvo quanto già previsto nel codice).
- Modifiche oltre il perimetro UI/feedback dello scanner salvo necessità minima documentata in planning.

## File potenzialmente coinvolti
- `iOSMerchandiseControl/BarcodeScannerView.swift` — punto primario (TASK-014: file unico atteso).
- Stringhe localizzate (es. `*.lproj/Localizable.strings` o meccanismo `L(...)` già in uso) se si introducono testi utente.

## Criteri di accettazione
*(Bootstrap da TASK-014; CLAUDE può rifinirli nel planning operativo prima dell’handoff a EXECUTION.)*

- [ ] **CA-1**: Se la camera non è disponibile o il permesso è negato, la view mostra un **fallback** con messaggio descrittivo invece dello schermo vuoto.
- [ ] **CA-2**: Se il motivo è permesso negato, è presente un’azione (es. bottone) **«Apri Impostazioni»** che apre la pagina permessi dell’app su iOS (`UIApplication.shared.open` verso URL impostazioni).
- [ ] **CA-3**: Con camera disponibile e permesso concesso, il comportamento di scansione resta **equivalente** all’attuale (nessuna regressione funzionale).

## Decisioni
| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|-------|
| 1 | Bootstrap da TASK-014 senza planning tecnico completo in questo turno | Planning completo immediato | Attivazione backlog + file reale; planning dettagliato a CLAUDE in fase PLANNING | attiva |

---

## Planning (Claude)

### Obiettivo
Definire l’intervento minimo su `BarcodeScannerView` per coprire i casi «no camera» / «permesso negato» con UI esplicita e CA-1..CA-3 verificabili.

### Analisi
*(Da completare in PLANNING operativo: leggere `BarcodeScannerView.swift` e mappare rami attuali su `AVCaptureDevice`, sessione di cattura, stati permesso.)*

### Approccio proposto
*(Da dettagliare: branch `else` o equivalente dopo controllo disponibilità; view fallback con icona + testo localizzato; bottone impostazioni solo quando il permesso è negato — allineato a TASK-014.)*

### File da modificare
- Lista definitiva dopo analisi; atteso almeno `BarcodeScannerView.swift` e file di localizzazione se necessario.

### Rischi identificati
- Regressioni su percorso «happy path» con camera OK; copy/localizzazione incoerente con il resto dell’app.

### Handoff → Execution
- **Prossima fase**: EXECUTION *(solo dopo planning operativo completo: analisi, approccio definitivo, rischi, CA finali, handoff esplicito)*
- **Prossimo agente**: CODEX
- **Azione consigliata**: implementare secondo planning approvato; verificare CA-1..CA-3 (build + verifiche richieste dal task).

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
