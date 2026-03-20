# TASK-XXX: [Titolo del task]

> ⚠️ Questo file è un TEMPLATE. Non è un task reale. Non deve mai essere il task attivo.
> Per creare un nuovo task: copiare questo file in `TASK-NNN-slug.md`
> Esempio: `docs/TASKS/TASK-001-login-session.md`
> Naming: ID sempre a 3 cifre (001, 002...) + slug descrittivo. ID mai riutilizzati.

## Informazioni generali
- **Task ID**: TASK-XXX
- **Titolo**: [titolo]
- **File task**: `docs/TASKS/TASK-XXX-slug.md`
- **Stato**: TODO | ACTIVE | BLOCKED | DONE
- **Fase attuale**: PLANNING | EXECUTION | REVIEW | FIX
- **Responsabile attuale**: CLAUDE | CODEX ← chi deve agire ORA nella fase corrente
- **Data creazione**: YYYY-MM-DD
- **Ultimo aggiornamento**: YYYY-MM-DD
- **Ultimo agente che ha operato**: CLAUDE | CODEX

> I campi Stato, Fase, Responsabile, Ultimo aggiornamento e Ultimo agente possono essere aggiornati
> dall'agent che sta operando, purché il cambiamento sia coerente con la propria fase e le transizioni valide.

## Dipendenze
- **Dipende da**: [TASK-NNN o "nessuno" — task che devono essere completati prima di questo]
- **Sblocca**: [TASK-NNN o "nessuno" — task che dipendono dal completamento di questo]

## Scopo
[Cosa deve ottenere questo task, in 2-3 frasi]

## Contesto
[Perché serve questo task, cosa lo ha generato]

## Non incluso
[Cosa esplicitamente NON fa parte di questo task — anti scope-creep]

## File potenzialmente coinvolti
- [elenco file da analizzare/modificare]

## Criteri di accettazione
Questi criteri sono il contratto del task. Execution e review lavorano contro di essi.
Se cambiano in corso d'opera, aggiornare QUI prima di proseguire.
- [ ] [criterio 1]
- [ ] [criterio 2]

## Decisioni
Decisioni superate o cambiate non vanno cancellate: marcarle come OBSOLETA con nota esplicita.
| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|-------|
| 1 | — | — | — | attiva / OBSOLETA (sostituita da #N) |

---

## Planning (Claude) ← solo Claude aggiorna questa sezione

### Analisi
[Comprensione del problema e del codice esistente]

### Approccio proposto
[Strategia di implementazione minima]

### File da modificare
[Lista definitiva con motivazione]

### Rischi identificati
[Rischi e mitigazioni]

### Handoff → Execution
- **Prossima fase**: EXECUTION
- **Prossimo agente**: CODEX
- **Azione consigliata**: [cosa deve fare Codex per primo]

---

## Execution (Codex) ← solo Codex aggiorna questa sezione

### Obiettivo compreso
[Riformulazione sintetica dell'obiettivo]

### File controllati
[File letti prima di modificare]

### Piano minimo
[Elenco ordinato delle modifiche pianificate]

### Modifiche fatte
[Elenco delle modifiche effettivamente fatte]

### Check eseguiti
Per ogni check: ✅ ESEGUITO | ⚠️ NON ESEGUIBILE (motivo) | ❌ NON ESEGUITO (motivo)
- [ ] Build compila: [stato]
- [ ] Nessun warning nuovo: [stato]
- [ ] Modifiche coerenti con planning: [stato]
- [ ] Criteri di accettazione verificati: [stato]

### Rischi rimasti
[Eventuali rischi residui o follow-up candidate emersi fuori scope]

### Handoff → Review
- **Prossima fase**: REVIEW
- **Prossimo agente**: CLAUDE
- **Azione consigliata**: [cosa deve verificare Claude]

---

## Review (Claude) ← solo Claude aggiorna questa sezione

### Problemi critici
[Bloccanti]

### Problemi medi
[Da correggere]

### Miglioramenti opzionali
[Non richiesti ora, segnalati per futuro]

### Fix richiesti
- [ ] [fix 1]
- [ ] [fix 2]

### Esito
- APPROVED = criteri soddisfatti, nessun fix necessario → conferma utente
- CHANGES_REQUIRED = fix mirati necessari → FIX
- REJECTED = fuori perimetro o incoerente → nuovo PLANNING

Esito: [APPROVED | CHANGES_REQUIRED | REJECTED]

### Handoff → Fix (se CHANGES_REQUIRED)
- **Prossima fase**: FIX
- **Prossimo agente**: CODEX
- **Azione consigliata**: [cosa deve correggere Codex]

### Handoff → nuovo Planning (se REJECTED)
- **Prossima fase**: PLANNING
- **Prossimo agente**: CLAUDE
- **Azione consigliata**: [cosa va ripensato]

---

## Fix (Codex) ← solo Codex aggiorna questa sezione

### Fix applicati
- [ ] [fix 1 — fatto/non fatto]
- [ ] [fix 2 — fatto/non fatto]

### Check post-fix
Per ogni check: ✅ ESEGUITO | ⚠️ NON ESEGUIBILE (motivo) | ❌ NON ESEGUITO (motivo)
- [ ] Build compila: [stato]
- [ ] Fix coerenti con review: [stato]
- [ ] Criteri di accettazione ancora soddisfatti: [stato]

### Handoff → Review finale
- **Prossima fase**: REVIEW ← dopo FIX si torna SEMPRE a REVIEW, mai a DONE
- **Prossimo agente**: CLAUDE
- **Azione consigliata**: Verificare i fix applicati

---

## Chiusura

### Conferma utente
- [ ] Utente ha confermato il completamento

### Follow-up candidate
[Eventuali follow-up emersi — non bloccano la chiusura salvo che siano criteri non soddisfatti]

### Riepilogo finale
[Cosa è stato fatto, limiti noti, note per il futuro]

### Data completamento
YYYY-MM-DD
