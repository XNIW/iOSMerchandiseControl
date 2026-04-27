# TASK-033: Supabase schema audit and iOS/Android model mapping

## Informazioni generali
- **Task ID**: TASK-033
- **Titolo**: Supabase schema audit and iOS/Android model mapping
- **File task**: `docs/TASKS/TASK-033-supabase-schema-audit-ios-android-model-mapping.md`
- **Stato**: TODO
- **Fase attuale**: — *(task in backlog, non ACTIVE)*
- **Responsabile attuale**: — *(nessun agente operativo; da selezionare dal backlog)*
- **Data creazione**: 2026-04-26
- **Ultimo aggiornamento**: 2026-04-26
- **Ultimo agente che ha operato**: CODEX *(creazione tracking su user override)*

## Dipendenze
- **Dipende da**: nessuno
- **Sblocca**: TASK-034 e task Supabase successivi

## Scopo
Preparazione Supabase. Prima di scrivere codice iOS bisogna leggere lo schema reale nel progetto Supabase locale e allinearlo con SwiftData iOS e Room Android.

## Contesto
Questo task è solo audit e mapping. Non implementa client Supabase e non cambia codice iOS.

## Non incluso
- Implementazione client Supabase
- Dependency Supabase Swift
- Sync automatico
- Modifiche distruttive ai dati locali

## Scope
- Leggere `/Users/minxiang/Desktop/MerchandiseControlSupabase`
- Estrarre migration/schema/policy/seed
- Confrontare con iOS `Models.swift` e `HistoryEntry.swift`
- Confrontare con Android Room `AppDatabase.kt` e modelli
- Non implementare client Supabase

## Output richiesto
- Mapping tabelle/colonne
- Decisioni su id locale/remoto
- Timestamp
- Soft delete
- Conflict policy iniziale
- Piano task Supabase successivi

## Criteri di accettazione
- [ ] Schema Supabase reale letto e sintetizzato
- [ ] Mapping iOS/Android/Supabase documentato
- [ ] Decisioni iniziali su id, timestamp, soft delete e conflict policy sono esplicite
- [ ] Nessun client Supabase viene implementato

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

