# TASK-033: Supabase schema audit and iOS/Android model mapping

## Informazioni generali
- **Task ID**: TASK-033
- **Titolo**: Supabase schema audit and iOS/Android model mapping
- **File task**: `docs/TASKS/TASK-033-supabase-schema-audit-ios-android-model-mapping.md`
- **Stato**: ACTIVE
- **Fase attuale**: PLANNING
- **Responsabile attuale**: Planner / Claude — compilare planning operativo prima di execution
- **Data creazione**: 2026-04-26
- **Ultimo aggiornamento**: 2026-05-03
- **Ultimo agente che ha operato**: Codex / Tracking — user override “metti task 32 in pausa e attivami la task 33”

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

## Nota — Attivazione task (user override 2026-05-03)

TASK-033 è stato promosso da **TODO** ad **ACTIVE / PLANNING** su richiesta esplicita dell'utente, mettendo **TASK-032** in pausa come **BLOCKED / on hold**. Nessuna execution è stata avviata in questo aggiornamento; prima di lavorare sullo schema Supabase serve planning operativo.

## Planning (Claude) ← solo Claude aggiorna questa sezione
Non avviato.

---

## Execution (Codex) ← solo Codex aggiorna questa sezione
Non avviata.

### Tracking attivazione — 2026-05-03
- User override: TASK-032 messo in pausa come BLOCKED / on hold; TASK-033 promosso da TODO ad ACTIVE / PLANNING.
- Nessuna execution avviata in questo aggiornamento.
- Nessun codice iOS, Android o Supabase modificato.
- Prossimo passo coerente: compilare Planning prima di qualunque audit operativo o modifica.

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
