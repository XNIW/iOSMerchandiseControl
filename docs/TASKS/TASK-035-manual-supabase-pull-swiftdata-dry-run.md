# TASK-035: Manual Supabase pull to SwiftData dry-run

## Informazioni generali
- **Task ID**: TASK-035
- **Titolo**: Manual Supabase pull to SwiftData dry-run
- **File task**: `docs/TASKS/TASK-035-manual-supabase-pull-swiftdata-dry-run.md`
- **Stato**: TODO
- **Fase attuale**: — *(task in backlog, non ACTIVE)*
- **Responsabile attuale**: — *(nessun agente operativo; da selezionare dal backlog)*
- **Data creazione**: 2026-04-26
- **Ultimo aggiornamento**: 2026-04-26
- **Ultimo agente che ha operato**: CODEX *(creazione tracking su user override)*

## Dipendenze
- **Dipende da**: TASK-034
- **Sblocca**: task futuri di sync applicata con conferma

## Scopo
Prima sync reale sicura: pull manuale remoto → confronto con SwiftData, senza applicare automaticamente.

## Contesto
Il task segue la foundation readonly di TASK-034 e prepara una preview del sync prima di qualsiasi scrittura automatica.

## Non incluso
- Scrittura automatica su SwiftData
- Push verso Supabase
- Risoluzione automatica conflitti
- UI estesa non necessaria al dry-run

## Scope
- Leggere dati da Supabase
- Confrontare con SwiftData locale
- Produrre diff new/update/conflict
- Nessuna scrittura automatica salvo conferma in task futuro

## Output richiesto
- SyncPreview
- Lista conflitti
- Metriche
- UI minima o debug view se necessario

## Criteri di accettazione
- [ ] Il pull remoto produce una preview senza applicare scritture automatiche
- [ ] Diff new/update/conflict e metriche sono disponibili
- [ ] I conflitti sono visibili e non risolti automaticamente
- [ ] Ogni applicazione dati resta fuori scope salvo task futuro confermato

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

