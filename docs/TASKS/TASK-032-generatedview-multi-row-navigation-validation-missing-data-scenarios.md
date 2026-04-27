# TASK-032: GeneratedView multi-row navigation validation + missing-data scenarios

## Informazioni generali
- **Task ID**: TASK-032
- **Titolo**: GeneratedView multi-row navigation validation + missing-data scenarios
- **File task**: `docs/TASKS/TASK-032-generatedview-multi-row-navigation-validation-missing-data-scenarios.md`
- **Stato**: TODO
- **Fase attuale**: — *(task in backlog, non ACTIVE)*
- **Responsabile attuale**: — *(nessun agente operativo; da selezionare dal backlog)*
- **Data creazione**: 2026-04-26
- **Ultimo aggiornamento**: 2026-04-26
- **Ultimo agente che ha operato**: CODEX *(creazione tracking su user override)*

## Dipendenze
- **Dipende da**: TASK-028
- **Sblocca**: chiusura o fix mirato dei rischi runtime residui di TASK-028

## Scopo
TASK-028 è positivo ma non ha validato prev/next multi-riga e scenari con dati mancanti/ambigui. Questo task chiude il rischio UX residuo senza riaprire TASK-028.

## Contesto
TASK-028 resta BLOCKED e non DONE. La validazione runtime/visiva parziale del 2026-04-26 ha confermato il caso iPhone piccolo ma non copre dataset multi-riga, iPhone grande e dati mancanti/ambigui.

## Non incluso
- Nuovo redesign di RowDetailSheetView
- Supabase
- Refactor import
- Chiusura automatica di TASK-028 senza evidenza e conferma utente

## Scope
- Creare fixture multi-riga idonea
- Validare prev/next
- Validare badge delta solo quando applicabile
- Validare CTA collassate/nascoste se sorgente mancante
- Validare iPhone grande

## Output richiesto
- Se tutto OK: raccomandare chiusura TASK-028 a DONE
- Se regressione: aprire FIX mirato su TASK-028 o nuovo follow-up

## Criteri di accettazione
- [ ] Prev/next viene validato su fixture multi-riga
- [ ] Badge delta e CTA rispettano dati mancanti/ambigui
- [ ] iPhone grande viene validato
- [ ] L'esito produce raccomandazione esplicita su TASK-028

## Planning (Claude) ← solo Claude aggiorna questa sezione
Non avviato. Da compilare solo quando il task viene promosso ad ACTIVE.

---

## Execution (Codex) ← solo Codex aggiorna questa sezione
Non avviata.

---

## Review (Claude) ← solo Claude aggiorna questa sezione
Non avviata.

---

## Fix (Codex) ← solo Codex aggiorna questa sezione
Non avviato.

---

## Chiusura

### Conferma utente
- [ ] Utente ha confermato il completamento

### Follow-up candidate
—

### Riepilogo finale
—

### Data completamento

