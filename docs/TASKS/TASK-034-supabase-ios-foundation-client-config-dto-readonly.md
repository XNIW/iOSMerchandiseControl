# TASK-034: Supabase iOS foundation — client config + DTO readonly

## Informazioni generali
- **Task ID**: TASK-034
- **Titolo**: Supabase iOS foundation: client config + DTO readonly
- **File task**: `docs/TASKS/TASK-034-supabase-ios-foundation-client-config-dto-readonly.md`
- **Stato**: TODO
- **Fase attuale**: — *(task in backlog, non ACTIVE)*
- **Responsabile attuale**: — *(nessun agente operativo; da selezionare dal backlog)*
- **Data creazione**: 2026-04-26
- **Ultimo aggiornamento**: 2026-04-26
- **Ultimo agente che ha operato**: CODEX *(creazione tracking su user override)*

## Dipendenze
- **Dipende da**: TASK-033
- **Sblocca**: TASK-035

## Scopo
Prima integrazione codice Supabase lato iOS dopo schema audit. Solo foundation e DTO, senza sync automatico.

## Contesto
Questo task può partire solo dopo il mapping schema/model di TASK-033. Il perimetro è readonly e non introduce push o sync automatico.

## Non incluso
- Push verso Supabase
- Sync automatico
- Auth/multiutente se non richiesta
- Modifiche distruttive a SwiftData

## Scope
- Aggiungere dependency Supabase Swift
- Configurazione URL/key sicura
- DTO remoti per Product, Supplier, Category, ProductPrice
- Servizio readonly iniziale
- Nessun push
- Nessuna auth/multiutente se non richiesta

## Output richiesto
- Build verde
- Fetch remoto controllato
- Nessuna modifica distruttiva a SwiftData

## Criteri di accettazione
- [ ] Dependency e configurazione sono introdotte secondo decisioni di TASK-033
- [ ] DTO readonly compilano e mappano lo schema auditato
- [ ] Fetch remoto controllato funziona o ha blocker documentato
- [ ] Nessuna scrittura locale o remota automatica viene introdotta

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

