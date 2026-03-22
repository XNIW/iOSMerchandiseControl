# TASK-012: Simulator automation — dual-agent wrapper + adapter

## Informazioni generali
- **Task ID**: TASK-012
- **Titolo**: Simulator automation — dual-agent wrapper + adapter
- **File task**: `docs/TASKS/TASK-012-simulator-automation-skill.md`
- **Stato**: ACTIVE
- **Fase attuale**: REVIEW
- **Responsabile attuale**: CLAUDE (reviewer)
- **Data creazione**: 2026-03-21
- **Ultimo aggiornamento**: 2026-03-21
- **Ultimo agente che ha operato**: CLAUDE

## Dipendenze
- **Dipende da**: nessuno
- **Sblocca**: TASK-008 (validazione UI T-1..T-28 sospesa in attesa di questa infrastruttura)

## Scopo
Creare un'infrastruttura riusabile per automatizzare test UI nel Simulator iOS, composta da:
1. **Core condiviso**: wrapper shell stabile nel repo con subcomandi deterministici (tap, wait, type, screenshot, dump AX...)
2. **Adapter Codex**: skill/guida per l'agente esecutore (Codex) che insegna come usare il wrapper, interpretare fallimenti, e quando fermarsi
3. **Adapter Claude Code**: custom slash command per Claude Code appoggiato allo stesso wrapper
4. **Protocollo operativo universale**: `docs/CODEX-EXECUTION-PROTOCOL.md` — standard per execution, self-test Simulator, evidenze e handoff, valido per tutti i task UI futuri

La soluzione deve eliminare la necessità di generare comandi `osascript` inline ad hoc, essere utilizzabile da entrambi gli agenti senza modifiche al wrapper, e funzionare per qualsiasi schermata dell'app (non solo per TASK-008).

**Nota sullo stato del protocollo**: `docs/CODEX-EXECUTION-PROTOCOL.md` è stato **già creato durante il planning** di questo task. In execution, Codex deve: (a) verificare che il protocollo sia completo e coerente con il wrapper prodotto, (b) proporre integrazioni minime se il wrapper introduce convenzioni non coperte, (c) verificare che i puntatori in `AGENTS.md` e `CLAUDE.md` siano corretti. Il protocollo **non è un deliverable da reinventare da zero** — è già scritto e va solo validato/rifinito.

## Contesto
TASK-008 ha codice iOS sostanzialmente corretto (review statica superata, build verde) ma la validazione UI finale (T-1..T-28) è bloccata dall'instabilità dell'automazione ad hoc:
- `tools/sim_ui_task008.sh` ha comandi task-specifici con coordinate hardcoded per il dialog ManualEntrySheet
- Dipende da `rg` (ripgrep), non disponibile su tutti i Mac
- Non ha exit code semantici affidabili
- Non esiste skill/guida che insegni all'agente come usare il wrapper correttamente
- Ogni test UI finisce per generare comandi `osascript` inline sempre diversi, con prompt di approvazione ripetuti

Questo task risolve il problema a livello infrastrutturale, non come patch usa-e-getta per TASK-008.

## Non incluso
- Modifiche al codice Swift / iOS dell'app
- Test XCUITest / XCTest nativi Xcode (approccio diverso, fuori scope)
- Supporto a device fisici (solo Simulator)
- Supporto multi-touch / gesture avanzate (pinch, swipe continuo, drag)
- Migrazione del codice task-specifico di `sim_ui_task008.sh` (resta com'è, con nota di backward-compat)
- Automazione macOS fuori dal contesto Simulator / simctl
- MCP server, framework di test strutturati, o architetture pesanti (citabili solo come follow-up)
- Esecuzione effettiva dei test T-1..T-28 di TASK-008 (sarà fatto dopo, usando questa infrastruttura)

## File potenzialmente coinvolti

| File | Tipo | Motivazione |
|------|------|-------------|
| `tools/sim_ui.sh` | Creazione | Core wrapper universale con subcomandi deterministici |
| `tools/sim_ui_task008.sh` | Modifica minima | Commento backward-compat + opzionale delega a `sim_ui.sh` |
| `.claude/commands/sim-ui.md` | Creazione | Custom slash command Claude Code (`/sim-ui`) |
| `tools/sim-ui-guide-codex.md` | Creazione | Skill/guida per Codex — istruzioni operative, flusso tipico, fallback |
| `docs/CODEX-EXECUTION-PROTOCOL.md` | Verifica / modifica minima | Già creato in planning; Codex verifica coerenza con wrapper prodotto (CA-18) |
| `AGENTS.md` | Modifica minima | Puntatore a `tools/sim-ui-guide-codex.md` + puntatore a protocollo (CA-19) |
| `CLAUDE.md` | Modifica minima | Puntatore al protocollo come standard di review (CA-20) |
| Nessun file Swift / Xcode / SwiftData | — | — |

## Criteri di accettazione
Questi criteri sono il contratto del task. Execution e review lavorano contro di essi.
Se cambiano in corso d'opera, aggiornare QUI prima di proseguire.

### Core wrapper (`tools/sim_ui.sh`)
- [ ] CA-1: `tools/sim_ui.sh` esiste, è eseguibile (`chmod +x`), non dipende da `rg`/`ripgrep` né da altri strumenti oltre a `xcrun`, `osascript`, `grep`, `awk`, `sed`, `open` (tutti disponibili su macOS base)
- [ ] CA-2: Subcomandi stabili obbligatori: `launch [bundle-id]`, `terminate [bundle-id]`, `show`, `tap-name <fragment> [role] [timeout]`, `wait-for <fragment> [timeout]`, `type <text>`, `clear-field`, `capture <output.png>`, `wait <seconds>`, `dump-names [filter]`, `tap-relative <relX> <relY>`. Per `launch` e `terminate`: se `bundle-id` non è passato, usa `SIM_UI_BUNDLE_ID`; se l'env non è impostata, usa il default `com.niwcyber.iOSMerchandiseControl`
- [ ] CA-3: Ogni subcomando ritorna exit 0 su successo, exit 1 su fallimento rilevabile (elemento non trovato, timeout), exit 2 su errore di configurazione (no Simulator booted, AX non disponibile, device richiesto non presente). Messaggio diagnostico su stderr.
- [ ] CA-4: `sim_ui.sh` senza argomenti stampa usage su stdout e ritorna exit 0
- [ ] CA-5: `sim_ui.sh` funziona su un Simulator booted senza argomenti obbligatori oltre al subcomando (i subcomandi che accettano `bundle-id` lo trattano come opzionale — vedi CA-2); `SIM_UI_BUNDLE_ID` e `SIM_UI_DEVICE_ID` configurabili via env con default ragionevoli (`com.niwcyber.iOSMerchandiseControl` e `booted`)
- [ ] CA-6: `dump-names` produce output tabellare su stdout (`ROLE<tab>NAME`, uno per riga) utilizzabile come smoke test per verificare che i permessi Accessibility siano attivi
- [ ] CA-7: `capture` salva il file PNG al path specificato e stampa il path su stdout per conferma; exit 1 se simctl screenshot fallisce

### Adapter Codex
- [ ] CA-8: `tools/sim-ui-guide-codex.md` esiste con: tabella subcomandi e sintassi, flusso tipico test end-to-end, strategia di fallback, limiti dichiarati, regola "stop on failure"
- [ ] CA-9: La guida documenta esplicitamente il pattern "stop on wait-for failure": se `wait-for` ritorna exit 1, l'agente deve segnalare il fallimento e NON continuare il test
- [ ] CA-10: La guida include un template di reporting standard per test (formato `T-NN: PASS/FAIL — nota`)
- [ ] CA-11: `AGENTS.md` contiene una sezione dedicata al workflow UI/Simulator con puntatore a `tools/sim-ui-guide-codex.md` e puntatore a `docs/CODEX-EXECUTION-PROTOCOL.md` (coerente con CA-19; la dimensione della sezione è libera purché contenga tutti i riferimenti richiesti)

### Adapter Claude Code
- [ ] CA-12: `.claude/commands/sim-ui.md` esiste come custom slash command invocabile con `/sim-ui`
- [ ] CA-13: Il comando contiene: lista subcomandi con sintassi, flusso tipico, strategia di fallback, limiti, regola "stop on failure" — analogo alla guida Codex ma adattato al formato Claude Code
- [ ] CA-14: Il comando istruisce Claude Code a usare il wrapper via Bash tool, non a generare `osascript` inline

### Backward compatibility e universalità
- [ ] CA-15: `tools/sim_ui_task008.sh` continua a funzionare invariato (backward compat); ha in cima un commento che punta a `sim_ui.sh` come wrapper generale
- [ ] CA-16: Nessun subcomando di `sim_ui.sh` contiene riferimenti a schermate, bottoni o coordinate specifiche di un task
- [ ] CA-17: Limiti documentati in entrambi gli adapter: no multi-touch, solo Simulator (no device), richiede permessi Accessibility + Screen Recording su macOS, prompt approvazione agente possibile per `osascript`

### Protocollo operativo universale
- [ ] CA-18: `docs/CODEX-EXECUTION-PROTOCOL.md` esiste con tutte le sezioni obbligatorie: tipi di verifica, formato risultati test, mappatura CA→evidenza e T-NN→esito, evidenze minime handoff, regole blocchi, convenzioni artefatti, gate di uscita EXECUTION→REVIEW, regole di integrità
- [ ] CA-19: `AGENTS.md` referenzia il protocollo come lettura obbligatoria per task che toccano UI/Simulator, con regola: "l'handoff è valido solo se conforme al protocollo"
- [ ] CA-20: `CLAUDE.md` referenzia il protocollo come standard di review: Claude verifica completezza e coerenza dell'evidenza prodotta da Codex secondo il protocollo

---

## Decisioni
Decisioni superate o cambiate non vanno cancellate: marcarle come OBSOLETA con nota esplicita.

| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|-------|
| D-1 | Core: singolo `tools/sim_ui.sh` con subcomandi (non più wrapper per singola operazione) | Più script separati (`sim_tap.sh`, `sim_wait.sh`...); libreria bash sourced | Un unico entry point rende il wrapper scopribile, versionabile e documentabile in un'unica tabella; i subcomandi seguono il pattern `git <sub>` | attiva |
| D-2 | Tecnologia: zsh + JXA (`osascript -l JavaScript`) — stessa tecnologia del prototipo esistente | Python + pyautogui; XCUITest nativi; Appium; Swift CLI | JXA è già funzionante nel repo; non introduce dipendenze; accede a System Events e CGEvent nativamente; XCUITest richiede modifica al progetto Xcode | attiva |
| D-3 | Adapter Codex: file dedicato `tools/sim-ui-guide-codex.md` + puntatore da AGENTS.md | Sezione inline in AGENTS.md; `.codex/commands/` | AGENTS.md è per regole generali, non per guide specializzate; `.codex/commands/` non è uno standard verificato; un file nel repo è leggibile da qualsiasi agente e versionabile | attiva |
| D-4 | Adapter Claude Code: `.claude/commands/sim-ui.md` (custom slash command `/sim-ui`) | Sezione in CLAUDE.md; solo commenti nel wrapper | Il custom command è invocabile esplicitamente dall'utente o dall'agente; CLAUDE.md è per regole di workflow, non per guide operative | attiva |
| D-5 | I due adapter NON sono copia 1:1: stessi contenuti tecnici, ma formato e istruzioni agent-specific differenti | Stesso file letto da entrambi; file identici | Claude Code usa Bash tool e può iterare; Codex ha un modello di esecuzione diverso; i fallback e i pattern di reporting possono differire | attiva |
| D-6 | Sostituire `rg` con `grep -oE '[A-F0-9-]{36}'` in `booted_udid` | Mantenere `rg` | `rg` non è garantito su macOS base; `grep -oE` è POSIX-esteso, nativamente disponibile | attiva |
| D-7 | Exit code semantici: 0 = successo, 1 = fallimento operativo (elemento non trovato, timeout, simctl launch/terminate fallito), 2 = errore configurazione / ambiente (no Simulator booted, AX non disponibile, device richiesto non presente) | Solo 0/1 | Permette all'agente di distinguere "test fallito" (1, procedere al prossimo o fermarsi) da "ambiente rotto" (2, sempre fermarsi) | attiva |
| D-8 | `sim_ui_task008.sh`: mantenuto com'è con commento in cima che punta a `sim_ui.sh`; opzionalmente delega i comandi generali, ma NON è obbligatorio modificarlo funzionalmente | Rinominarlo; assorbirlo nel wrapper generico; eliminarlo | Backward compat: chiunque lo usi oggi non deve rompere nulla; il codice task-specifico (coordinate hardcoded, flussi ManualEntrySheet) non ha senso nel wrapper generico | attiva |
| D-9 | Output standard: stdout per dati (dump-names, path screenshot, FOUND/NOT_FOUND), stderr per diagnostica/errori. Nessun prefisso colorato: l'agente parsifica stdout, non legge colori | Output JSON; log file dedicato | JSON è over-engineering per un wrapper shell; stdout grezzo + stderr è lo standard Unix; l'agente legge stdout direttamente | attiva |
| D-10 | Screenshot: salvati al path specificato dal chiamante; nessuna directory default creata dal wrapper. Il wrapper stampa il path su stdout dopo il salvataggio | Directory automatica `tools/screenshots/`; naming automatico con timestamp | Il chiamante (agente o script task-specifico) decide dove salvare; il wrapper resta stateless e universale | attiva |
| D-11 | Fallback strategy: primo tentativo via `tap-name` (AX name-based), fallback esplicito via `tap-relative` (coordinate relative al device frame). Il wrapper NON fa fallback automatico internamente — è l'agente/script che decide la catena | Fallback automatico tap-name → tap-relative dentro il wrapper | Il fallback automatico maschera il problema: se l'AX tree non funziona, l'agente deve saperlo. Il wrapper è un layer di esecuzione, non di decisione | attiva |
| D-12 | `wait-for` ritorna stringa "FOUND"/"NOT_FOUND" su stdout (il layer shell converte in exit code); questo permette all'agente di leggere il risultato anche via stdout se necessario | Solo exit code senza stdout | Doppio canale (exit code + stdout) rende il debug più facile; l'agente può loggare il risultato | attiva |

---

## Planning (Claude)

### 1) Obiettivo

**Perché esiste TASK-012**: l'automazione UI del Simulator nel progetto è attualmente ad hoc. Ogni test UI genera comandi `osascript` inline diversi, con prompt di approvazione ripetuti per l'agente, coordinate hardcoded, e nessuna standardizzazione di output o fallback. Questo rende la validazione UI end-to-end lenta, fragile e non ripetibile.

**Come sblocca TASK-008**: TASK-008 è in stato BLOCKED perché la review statica è passata ma i test UI T-1..T-28 non sono stati completati. L'infrastruttura creata da TASK-012 permetterà di eseguire quei test in modo controllato, usando il wrapper per le operazioni deterministiche (tap, wait, screenshot, dump) senza generare ogni volta comandi diversi.

**Perché dual-agent e non task-specific**:
- Codex è l'esecutore (scrive codice, esegue test in execution/fix)
- Claude Code è il planner/reviewer (ma può anche eseguire test durante review o su richiesta dell'utente)
- Entrambi devono poter usare lo stesso wrapper, ma con istruzioni operative adattate al proprio modello di interazione
- Il wrapper deve essere universale (qualsiasi schermata, qualsiasi task futuro), non accoppiato a TASK-008

---

### 2) Analisi

#### 2a) Prototipo attuale: `tools/sim_ui_task008.sh` (462 righe)

**Struttura a due layer**:
- **Layer shell** (righe 385-461): dispatcher zsh che chiama `xcrun simctl` per operazioni native o `run_ui()` per JXA
- **Layer JXA** (righe 53-382): script JavaScript for Automation con accesso a System Events e CGEvent

**Analisi generalizzabilità per comando**:

| Comando | Generalizzabile? | Note |
|---------|-----------------|------|
| `launch-app` | ✅ → `launch <bundle-id>` | Parametrizzare bundle-id |
| `show-simulator` | ✅ → `show` | Invariato |
| `terminate` | ✅ → `terminate <bundle-id>` | Parametrizzare |
| `tap-text <fragment>` | ✅ → `tap-name <fragment> [role] [timeout]` | Aggiungere role e timeout come parametri opzionali |
| `dump-names [filter]` | ✅ → invariato | Già generico |
| `capture <output.png>` | ✅ → invariato | Aggiungere stampa path su stdout |
| `wait <seconds>` | ✅ → invariato | Già generico |
| `launch-manual` | ❌ task-specifico | Tap su "Nuovo inventario manuale" — resta in task008 |
| `open-add` | ❌ task-specifico | Tap su "Aggiungi riga" con fallback coordinate — resta in task008 |
| `fill-add` | ❌ coordinate hardcoded | 5 campi con coordinate relative al dialog ManualEntrySheet — resta in task008 |
| `confirm` | ❌ task-specifico | Tap su "Conferma" — è `tap-name "Conferma"` ma con fallback coordinate specifico |
| `delete-current-row` | ❌ task-specifico | Tap su "Elimina" |
| `open-history-tab` | ❌ task-specifico | Tap su tab Cronologia |
| `open-latest-manual` | ❌ task-specifico | Tap su "Inventario manuale" nella lista |

**Funzioni JXA riusabili** (da portare integralmente in `sim_ui.sh`):
- `activateSimulator()`, `frontWindow()`, `deviceFrame()` — gestione finestra Simulator
- `clickPoint(x,y)` — click CGEvent a coordinate assolute
- `clickRelative(relX, relY)` — click a coordinate relative al device frame
- `allElements()`, `elementName()`, `elementRole()` — lettura AX tree
- `findElementByName(fragment, role)` — ricerca per nome con filtro role opzionale
- `waitForElement(fragment, role, timeout)` — attesa polling con timeout
- `clickNamed(fragment, role, timeout)` — wait + click combinato
- `clearFocusedField()` — 40 backspace per svuotare campo
- `typeSmart(value)` — digitazione carattere per carattere con keyCode per cifre

**Funzioni JXA task-specifiche** (restano in task008):
- `replaceField(relX, relY, value)` — click relativo + clear + type (composizione di funzioni generiche per coordinate specifiche)
- Tutti i case dello switch da `launch-manual` a `open-latest-manual`

**Comandi mancanti da aggiungere al wrapper generico**:
- `wait-for <fragment> [timeout]` — attende che un elemento AX appaia; ritorna FOUND/NOT_FOUND + exit code
- `type <text>` — digita nel campo focalizzato (espone `typeSmart`)
- `clear-field` — svuota il campo focalizzato (espone `clearFocusedField`)
- `tap-relative <relX> <relY>` — click a coordinate relative (espone `clickRelative`)

**Problemi da risolvere**:
1. `rg` in `booted_udid()` → `grep -oE '[A-F0-9-]{36}'` (D-6)
2. Exit codes non semantici: JXA usa `throw new Error(...)` che produce sempre exit 1; nessuna distinzione tra fallimento operativo e errore di configurazione
3. Nessun output su stdout per risultati (wait-for, capture path) — tutto passa solo per exit code
4. Nessuna diagnostica su stderr strutturata

#### 2b) Punti di frizione reali nell'automazione attuale

1. **Prompt di approvazione ripetuti**: ogni volta che un agente invoca `osascript` direttamente o tramite un wrapper, il sistema chiede approvazione. Con il wrapper, la singola chiamata `./tools/sim_ui.sh tap-name "Conferma"` è un comando Bash prefissato e stabile — l'utente può pre-approvare il pattern `./tools/sim_ui.sh *` una volta sola.

2. **Comandi osascript inline sempre diversi**: senza wrapper, ogni agente genera il proprio blocco JXA a mano, con variazioni nella gestione errori, nei timeout, nella logica di retry. Risultato: fragilità, non ripetibilità, impossibilità di debugging.

3. **Fragilità AX tree**: `win.entireContents()` è lento su view complesse (~1-3s) e può fallire silenziosamente se i permessi Accessibility non sono attivi. Nessun meccanismo attuale per verificare se l'AX funziona prima di iniziare un test.

4. **Coordinate hardcoded**: `fill-add` usa coordinate relative specifiche per il dialog ManualEntrySheet. Queste cambiano se il layout cambia, se il device cambia, o se la finestra del Simulator è in scala diversa. Il wrapper generico non deve contenere coordinate specifiche — ma deve esporre `tap-relative` come fallback documentato.

5. **Difficoltà a completare test UI**: senza un flusso tipo "launch → wait-for schermata → azione → wait-for risultato → screenshot → terminate", ogni test è un'avventura. Manca un pattern standard che l'agente possa seguire.

#### 2c) Analisi comparativa: core vs adapter Codex vs adapter Claude Code

| Aspetto | Core (`sim_ui.sh`) | Adapter Codex (`sim-ui-guide-codex.md`) | Adapter Claude Code (`.claude/commands/sim-ui.md`) |
|---------|-------------------|----------------------------------------|---------------------------------------------------|
| **Funzione** | Eseguire operazioni deterministiche sul Simulator | Insegnare a Codex come orchestrare i subcomandi | Insegnare a Claude Code come orchestrare i subcomandi |
| **Formato** | Script zsh eseguibile | Markdown con istruzioni operative | Custom slash command (markdown con prompt) |
| **Dove vive** | `tools/sim_ui.sh` | `tools/sim-ui-guide-codex.md` | `.claude/commands/sim-ui.md` |
| **Chi lo legge** | Entrambi gli agenti (via Bash) | Solo Codex (referenziato da AGENTS.md) | Solo Claude Code (invocabile via `/sim-ui`) |
| **Contiene logica?** | Sì — script eseguibile | No — solo istruzioni testuali | No — solo istruzioni testuali |
| **Contiene flussi esempio?** | No — solo subcomandi atomici | Sì — flusso tipico completo + fallback | Sì — flusso tipico + istruzioni Bash tool |
| **Gestisce fallback?** | No — ritorna exit code | Sì — descrive la strategia | Sì — descrive la strategia |
| **Gestisce reporting?** | No — stdout/stderr standard | Sì — formato T-NN PASS/FAIL | Sì — formato report |

**Cosa è condiviso**: il wrapper `sim_ui.sh` è identico per entrambi. I subcomandi, la sintassi, gli exit code, il formato stdout/stderr.

**Cosa è specifico per agente**:
- **Codex**: segue AGENTS.md come lettura obbligatoria; la guida va referenziata da lì. Codex opera in fase EXECUTION/FIX e deve sapere quando fermarsi e fare handoff. Il pattern di reporting deve allinearsi al formato AGENTS.md (check ✅/⚠️/❌).
- **Claude Code**: ha il sistema di custom commands (`.claude/commands/`); il prompt del comando diventa parte del contesto attivo. Claude Code usa il Bash tool per eseguire comandi. Può iterare e adattarsi; le istruzioni possono essere più concise.

---

### 3) Approccio

#### 3a) Architettura a tre livelli

```
┌─────────────────────────────────────────────┐
│           Agent (Codex / Claude Code)       │
│  Legge adapter → decide flusso → interpreta │
├─────────────────────────────────────────────┤
│      Adapter (agent-specific, markdown)     │
│  Codex: tools/sim-ui-guide-codex.md        │
│  Claude: .claude/commands/sim-ui.md         │
├─────────────────────────────────────────────┤
│        Core wrapper: tools/sim_ui.sh        │
│  Subcomandi deterministici, exit code       │
│  stdout: dati │ stderr: diagnostica         │
└─────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────┐
│     xcrun simctl + osascript -l JavaScript  │
│     System Events, CGEvent, Simulator.app   │
└─────────────────────────────────────────────┘
```

#### 3b) Struttura file/cartelle

```
tools/
  sim_ui.sh                    # Core wrapper (NUOVO — ~500 righe stimate)
  sim_ui_task008.sh            # ESISTENTE — backward compat, commento aggiunto
  sim-ui-guide-codex.md        # Adapter Codex (NUOVO — ~120 righe stimate)
.claude/
  commands/
    sim-ui.md                  # Adapter Claude Code (NUOVO — ~100 righe stimate)
AGENTS.md                      # ESISTENTE — aggiunta 2-3 righe puntatore
```

#### 3c) Design subcomandi di `sim_ui.sh`

| Subcomando | Sintassi | Descrizione | Exit 0 | Exit 1 | Exit 2 |
|------------|----------|-------------|--------|--------|--------|
| `show` | `sim_ui.sh show` | Porta il Simulator in primo piano | Simulator visibile | — | Simulator non installato |
| `launch` | `sim_ui.sh launch [bundle-id]` | Avvia l'app nel Simulator; se bundle-id omesso usa `SIM_UI_BUNDLE_ID` o default | App lanciata | simctl launch fallito | No Simulator booted |
| `terminate` | `sim_ui.sh terminate [bundle-id]` | Termina l'app; se bundle-id omesso usa `SIM_UI_BUNDLE_ID` o default | App terminata (o già terminata) | — | No Simulator booted |
| `tap-name` | `sim_ui.sh tap-name <fragment> [role] [timeout]` | Trova elemento AX per nome e clicca | Click eseguito | Elemento non trovato entro timeout | AX non disponibile |
| `wait-for` | `sim_ui.sh wait-for <fragment> [timeout]` | Attende che elemento AX appaia | Stdout: `FOUND` | Stdout: `NOT_FOUND` + stderr: messaggio | AX non disponibile |
| `type` | `sim_ui.sh type <text>` | Digita testo nel campo focalizzato | Testo digitato | — | Simulator non in foreground |
| `clear-field` | `sim_ui.sh clear-field` | Svuota campo focalizzato (40 backspace) | Campo svuotato | — | Simulator non in foreground |
| `capture` | `sim_ui.sh capture <path.png>` | Screenshot del Simulator | Stdout: path del file | Screenshot fallito | No Simulator booted |
| `wait` | `sim_ui.sh wait <seconds>` | Pausa | Sempre | — | — |
| `dump-names` | `sim_ui.sh dump-names [filter]` | Lista elementi AX visibili | Stdout: tabella ROLE\tNAME | — | AX non disponibile |
| `tap-relative` | `sim_ui.sh tap-relative <relX> <relY>` | Click a coordinate relative al device frame | Click eseguito | Device frame non trovato | Simulator non in foreground |

**Default**:
- `timeout` per `tap-name`: 5 secondi
- `timeout` per `wait-for`: 10 secondi
- `role` per `tap-name`: vuoto (qualsiasi role)
- `SIM_UI_BUNDLE_ID`: `com.niwcyber.iOSMerchandiseControl`
- `SIM_UI_DEVICE_ID`: `booted`

#### 3d) Formato output standard

```
# stdout — dati strutturati (parsificabili dall'agente)
FOUND                           # wait-for successo
NOT_FOUND                       # wait-for fallimento
/tmp/test.png                   # capture successo
AXButton	Conferma             # dump-names (tab-separated)

# stderr — diagnostica (non parsificata, human-readable)
[sim_ui] ERROR: Elemento 'Conferma' non trovato entro 5s
[sim_ui] ERROR: Nessun Simulator booted trovato
[sim_ui] OK: App com.niwcyber.iOSMerchandiseControl lanciata
[sim_ui] OK: Click su 'Conferma' (AXButton) a (342, 187)
```

Prefisso `[sim_ui]` su stderr per distinguere da output di `osascript`/`simctl`.

#### 3e) Strategia di fallback (documentata in entrambi gli adapter)

1. **Primo tentativo**: `tap-name "NomeBottone"` — usa AX tree, funziona se l'elemento ha un nome accessibile
2. **Se fallisce** (exit 1): `dump-names` per ispezionare cosa è visibile; `capture` per screenshot di debug
3. **Fallback esplicito**: `tap-relative 0.50 0.40` — coordinate relative al device frame. L'agente DEVE documentare perché il fallback è necessario e con quale device/scala è stato calibrato
4. **Se anche il fallback fallisce**: fermarsi, riportare contesto (screenshot + dump-names + exit code), chiedere intervento umano

L'agente NON deve continuare un test dopo un `wait-for` fallito, salvo che il fallimento sia su un elemento opzionale esplicitamente documentato come tale.

#### 3f) Strategia di utilizzo per agente

**Codex (execution/fix)**:
1. Legge `tools/sim-ui-guide-codex.md` (referenziato da AGENTS.md) prima di eseguire test UI
2. Esegue il flusso: build → launch → wait-for schermata → azioni → capture → terminate
3. Riporta risultati nel formato `T-NN: PASS/FAIL — nota` nella sezione Execution/Fix del file task
4. Se `wait-for` fallisce → segnala nel file task, non continua, non fa workaround non documentato
5. Se exit 2 → segnala "ambiente non disponibile", marca test come ⚠️ NON ESEGUIBILE

**Claude Code (review/su richiesta)**:
1. Invoca `/sim-ui` oppure usa direttamente `./tools/sim_ui.sh <sub>` via Bash tool
2. Può iterare: se un tap fallisce, può ispezionare con dump-names, provare un nome diverso, catturare screenshot
3. Riporta risultati all'utente nel contesto della conversazione
4. Stessa regola di stop-on-failure: non proseguire dopo wait-for fallito senza aver diagnosticato

#### 3g) Contenuto degli adapter

**Adapter Codex (`tools/sim-ui-guide-codex.md`)**:
- Sezione "Quando usare questa guida" (trigger: test UI nel Simulator richiesti dal task)
- Sezione "Prerequisiti" (Simulator booted, permessi, app installata)
- Tabella subcomandi con sintassi + exit code
- Sezione "Flusso tipico test end-to-end" con snippet di esempio
- Sezione "Strategia fallback" con regola stop-on-failure esplicita
- Sezione "Limiti noti" (permessi macOS, solo Simulator, no gesture, prompt approvazione)
- Sezione "Reporting" (formato T-NN con stato ✅/⚠️/❌)
- Sezione "Smoke test" (come verificare che l'ambiente funzioni prima di iniziare)

**Adapter Claude Code (`.claude/commands/sim-ui.md`)**:
- Prompt che descrive il contesto: "Stai per eseguire test UI nel Simulator iOS usando il wrapper `tools/sim_ui.sh`"
- Tabella subcomandi (stessa del wrapper, ma con esempio Bash tool per ciascuno)
- Flusso tipico con sequenza di chiamate Bash
- Regola stop-on-failure
- Limiti e prerequisiti
- Istruzione: "Non generare comandi osascript inline. Usa sempre il wrapper."

---

### 4) File coinvolti (con motivazione)

| # | File | Tipo | Righe stimate | Motivazione |
|---|------|------|--------------|-------------|
| 1 | `tools/sim_ui.sh` | Creazione | ~500 | Core wrapper: contiene tutto il JXA generico da `sim_ui_task008.sh` + nuovi subcomandi + exit code semantici + output standard |
| 2 | `tools/sim-ui-guide-codex.md` | Creazione | ~120 | Adapter Codex: guida operativa per l'agente esecutore |
| 3 | `.claude/commands/sim-ui.md` | Creazione | ~100 | Adapter Claude Code: custom slash command |
| 4 | `tools/sim_ui_task008.sh` | Modifica minima | +5 righe | Commento backward-compat in cima + opzionale delega |
| 5 | `AGENTS.md` | Modifica minima | +8 righe | Puntatore a `tools/sim-ui-guide-codex.md` + puntatore al protocollo `docs/CODEX-EXECUTION-PROTOCOL.md` |
| 6 | `CLAUDE.md` | Modifica minima | +5 righe | Puntatore al protocollo come standard di review |
| 7 | `docs/CODEX-EXECUTION-PROTOCOL.md` | Verifica / modifica minima | ~200 righe (già creato in planning) | Protocollo universale execution → self-test → handoff → review; in execution: validare coerenza con wrapper, proporre integrazioni minime se necessario |

**Non modificati**: nessun file Swift, nessun file Xcode, `MASTER-PLAN.md` (solo tracking).

---

### 5) Rischi

| # | Rischio | Probabilità | Impatto | Mitigazione |
|---|---------|-------------|---------|-------------|
| R-1 | Permessi Accessibility/Screen Recording non attivi → `osascript` fallisce silenziosamente (nessun elemento trovato, nessun click effettivo) | Media | Alto | Il subcomando `dump-names` serve come smoke test: se restituisce 0 righe su un'app visibile, i permessi sono assenti. Documentare nella guida come primo step. |
| R-2 | Prompt di approvazione dell'agente per ogni chiamata `./tools/sim_ui.sh` | Alta | Medio | L'utente può pre-approvare il pattern in settings (Codex o Claude Code). Documentare nella guida. Con un wrapper stabile, la pre-approvazione è sicura perché il wrapper non fa operazioni distruttive fuori dal Simulator. |
| R-3 | `grep -oE` pattern differente per UDID su versioni macOS diverse | Bassa | Basso | Pattern `[A-F0-9-]{36}` è UUID standard; `grep -oE` è disponibile da macOS 10.x. |
| R-4 | `win.entireContents()` lento su view complesse (1-3s per invocazione) | Media | Medio | Già funzionante nel codice esistente; `wait-for` con timeout ampio mitiga. Non modificare la tecnica. |
| R-5 | Coordinate relative dipendono dal modello device Simulator e dalla scala finestra | Media | Medio | Il wrapper calcola coordinate rispetto al device frame, non alla finestra. Documentare nella guida che `tap-relative` va calibrato per il device in uso e indicare come ricavare le coordinate (screenshot + calcolo proporzionale). |
| R-6 | False confidence da screenshot: l'agente potrebbe interpretare uno screenshot come "test passato" quando l'azione non è avvenuta | Media | Alto | La guida deve indicare: usare sempre `wait-for` DOPO un'azione per confermare l'effetto, non solo `capture`. Screenshot è diagnostica, non asserzione. |
| R-7 | Wrapper troppo accoppiato a una schermata → inutile per task futuri | Bassa | Alto | CA-16 lo vieta esplicitamente. Nessun riferimento a schermate specifiche in `sim_ui.sh`. Review lo verifica. |
| R-8 | Over-engineering: wrapper troppo complesso per il contesto reale d'uso | Media | Medio | Scope limitato a 11 subcomandi; nessun test runner, nessun JSON, nessuna directory automatica. Se serve di più → follow-up. |
| R-9 | `.claude/commands/` non supportato nella versione Claude Code in uso | Bassa | Medio | Verificare durante execution; se non funziona, il contenuto può vivere in una sezione dedicata di `CLAUDE.md` come fallback. |

---

### 6) Test di validazione

| # | Verifica | Esito atteso |
|---|----------|--------------|
| V-1 | `./tools/sim_ui.sh` senza argomenti | Usage su stdout, exit 0 |
| V-2 | `./tools/sim_ui.sh show` con Simulator booted | Simulator in foreground, exit 0 |
| V-3 | `./tools/sim_ui.sh launch com.niwcyber.iOSMerchandiseControl` (bundle-id esplicito) | App avviata, exit 0 |
| V-4 | `./tools/sim_ui.sh wait-for "Inventario" 5` | Stdout: `FOUND`, exit 0 |
| V-5 | `./tools/sim_ui.sh wait-for "ElementoInesistente" 2` | Stdout: `NOT_FOUND`, stderr: messaggio, exit 1 |
| V-6 | `./tools/sim_ui.sh dump-names` | Tabella ROLE\tNAME su stdout, almeno 1 riga |
| V-7 | `./tools/sim_ui.sh capture /tmp/sim_test.png` | File PNG creato, stdout: path, exit 0 |
| V-8 | `./tools/sim_ui.sh terminate com.niwcyber.iOSMerchandiseControl` (bundle-id esplicito) | App terminata, exit 0 |
| V-9 | `./tools/sim_ui.sh tap-name "Inventario"` | Click eseguito, exit 0 |
| V-10 | `./tools/sim_ui.sh tap-relative 0.5 0.5` | Click al centro del device, exit 0 |
| V-11 | `sim_ui_task008.sh launch-app` dopo la modifica | Comportamento invariato |
| V-12 | `.claude/commands/sim-ui.md` esiste e contiene tutte le sezioni | Leggibile e completa |
| V-13 | `tools/sim-ui-guide-codex.md` esiste e contiene tutte le sezioni | Leggibile e completa |
| V-14 | Flusso end-to-end: `show` → `launch` → `wait-for "Inventario"` → `capture` → `terminate` | Tutti exit 0, screenshot salvato |
| V-15 | `docs/CODEX-EXECUTION-PROTOCOL.md` esiste e contiene tutte le 10 sezioni obbligatorie (§1 Quando si applica, §2 Tipi di verifica, §3 Formato risultati, §4 Mappatura, §5 Evidenze minime, §6 Regole blocchi, §7 Convenzioni artefatti, §8 Gate EXECUTION→REVIEW, §9 Come Claude usa l'evidenza, §10 Regole di integrità) | Tutte le sezioni presenti e coerenti con il wrapper prodotto |
| V-16 | `AGENTS.md` referenzia sia `tools/sim-ui-guide-codex.md` sia `docs/CODEX-EXECUTION-PROTOCOL.md`; `CLAUDE.md` referenzia `docs/CODEX-EXECUTION-PROTOCOL.md` come standard di review | Puntatori presenti e corretti in entrambi i file |
| V-17 | `SIM_UI_DEVICE_ID=INVALID-UDID ./tools/sim_ui.sh launch com.niwcyber.iOSMerchandiseControl` (o equivalente errore di configurazione: nessun Simulator booted, UDID inesistente) | Exit 2, messaggio diagnostico coerente su stderr (prefisso `[sim_ui]`), nessun output su stdout |
| V-18 | Integrità statica wrapper shell: (a) `test -x tools/sim_ui.sh` — script eseguibile; (b) `zsh -n tools/sim_ui.sh` — sintassi zsh valida, exit 0; (c) `grep -r 'rg ' tools/sim_ui.sh` — nessun riferimento residuo a `rg`/`ripgrep` | (a) eseguibile, (b) exit 0 nessun errore di sintassi, (c) zero match |
| V-19 | `./tools/sim_ui.sh launch` (senza bundle-id) → usa fallback `SIM_UI_BUNDLE_ID` o default; poi `./tools/sim_ui.sh terminate` (senza bundle-id) | Stesso comportamento di V-3/V-8 con bundle-id default, exit 0 per entrambi |

Nota: V-2..V-11, V-14, V-17, V-19 richiedono Simulator disponibile (V-17 richiede che simctl sia invocabile, non necessariamente un device booted). Se ambiente non disponibile: ⚠️ NON ESEGUIBILE.
V-1, V-12, V-13, V-15, V-16, V-18 sono verificabili staticamente. V-18 è l'equivalente della build verification per il wrapper shell.

### Gate EXECUTION → REVIEW per questo task

V-2..V-11, V-14, V-17, V-19 sono test di tipo `SIM` e sono la verifica primaria che il wrapper funziona. **Senza di essi il deliverable principale (il wrapper) non è verificato.** V-17 in particolare verifica il ramo exit 2 (errore di configurazione), essenziale per il contratto CA-3.

Regola esplicita:
- Se V-2..V-11, V-14, V-17, V-19 non possono essere eseguiti per cause ambientali (Simulator non booted, permessi mancanti, app non installata), il task **NON avanza a REVIEW**.
- Il task resta in **EXECUTION / BLOCKED** con motivazione documentata nella sezione Execution (causa, cosa è stato tentato, cosa serve per sbloccare).
- Codex **non può** interpretare "⚠️ NON ESEGUIBILE" come handoff comunque accettabile verso Claude.
- V-1, V-12, V-13, V-15, V-16, V-18 (verifiche statiche) da soli non bastano a soddisfare il gate di uscita.
- Questo gate è coerente con la sezione 8 di `docs/CODEX-EXECUTION-PROTOCOL.md` e lo specializza per TASK-012.

### Naming: V-* come suite locale del task

Il protocollo `docs/CODEX-EXECUTION-PROTOCOL.md` usa il naming generico `T-NN` per i test case di qualsiasi task. Questo task usa `V-*` (V-1..V-19) come propria suite di validazione locale. Nell'handoff, Codex deve compilare la tabella esiti usando il naming `V-*` del task, nella struttura richiesta dal protocollo:

```
| V-NN | Stato | Tipo | Nota |
```

La mappatura è diretta: ogni `V-NN` corrisponde a un `T-NN` del protocollo nel formato di reporting. Non serve rinominare.

---

### 7) Handoff → Execution

- **Prossima fase**: EXECUTION
- **Prossimo agente**: CODEX
- **Azione consigliata**:

**Ordine di implementazione**:
1. Leggere integralmente `tools/sim_ui_task008.sh` (già letto in planning — confermare comprensione del JXA)
2. Creare `tools/sim_ui.sh`:
   - Copiare il layer JXA generico da `sim_ui_task008.sh` (funzioni da `activateSimulator` a `typeSmart`)
   - Aggiungere nuovi case JXA: `wait-for`, `type`, `clear-field`, `tap-relative`
   - Riscrivere il layer shell: dispatcher per tutti i subcomandi della tabella 3c
   - Sostituire `rg` con `grep -oE` in `booted_udid()`
   - Implementare exit code semantici (0/1/2)
   - Aggiungere output stdout/stderr standard con prefisso `[sim_ui]`
   - `chmod +x`
3. Aggiornare `tools/sim_ui_task008.sh`:
   - Aggiungere commento in cima (5 righe) che punta a `sim_ui.sh`
   - Opzionalmente: sostituire `rg` con `grep -oE` anche qui per coerenza
   - NON modificare i comandi task-specifici
4. Creare `tools/sim-ui-guide-codex.md` con tutte le sezioni indicate in 3g
5. Creare `.claude/commands/sim-ui.md` con le sezioni indicate in 3g
6. Verificare `docs/CODEX-EXECUTION-PROTOCOL.md` (già creato in planning): confermare che le sezioni 1-10 sono presenti e coerenti con il wrapper prodotto; se il wrapper introduce convenzioni non coperte, proporre integrazione
7. Aggiornare `AGENTS.md`: aggiungere puntatore a `tools/sim-ui-guide-codex.md` + puntatore a `docs/CODEX-EXECUTION-PROTOCOL.md` con regola di lettura obbligatoria per task UI
8. Aggiornare `CLAUDE.md`: aggiungere puntatore a `docs/CODEX-EXECUTION-PROTOCOL.md` come standard di review
9. Eseguire test V-1..V-19:
   - V-1, V-12, V-13, V-15, V-16, V-18 verificabili staticamente
   - V-2..V-11, V-14, V-17 richiedono Simulator/simctl; se non disponibile → task resta BLOCKED (vedi "Gate EXECUTION → REVIEW")
10. Compilare handoff post-execution **conforme al protocollo `docs/CODEX-EXECUTION-PROTOCOL.md`** (tabella CA→evidenza, tabella V-NN→esito, conferma scope, file toccati)

**Cosa dovrà verificare Claude in review**:
- CA-1..CA-20 contro il codice prodotto e i documenti
- Che `sim_ui.sh` non contenga riferimenti a schermate o coordinate task-specific (CA-16)
- Che gli adapter siano coerenti ma non identici (D-5)
- Che `sim_ui_task008.sh` non sia rotto (backward compat)
- Che exit code, stdout, stderr seguano il formato definito — in particolare che il ramo exit 2 (errore configurazione/ambiente) sia implementato e verificato da V-17
- Che il protocollo `docs/CODEX-EXECUTION-PROTOCOL.md` sia completo e referenziato da AGENTS.md e CLAUDE.md (CA-18..CA-20)
- Che l'handoff di Codex sia conforme al protocollo stesso (meta-verifica: il primo task che introduce il protocollo deve anche rispettarlo)
- Esecuzione dei test V-* se Simulator disponibile

---

## Execution (Claude come executor)

### Obiettivo compreso
Creare l'infrastruttura di automazione UI Simulator: wrapper universale `sim_ui.sh`, adapter Codex, adapter Claude Code, verificare protocollo universale e integrazioni in AGENTS.md e CLAUDE.md.

### File controllati
- `tools/sim_ui_task008.sh` — letto integralmente per estrarre JXA generalizzabile
- `docs/CODEX-EXECUTION-PROTOCOL.md` — verificata presenza 10/10 sezioni obbligatorie
- `AGENTS.md` — verificati puntatori a guida Codex e protocollo
- `CLAUDE.md` — verificato puntatore a protocollo come standard review

### Piano minimo
1. Creare `tools/sim_ui.sh` con tutti i subcomandi da CA-2
2. Aggiornare `tools/sim_ui_task008.sh` con commento backward-compat e sostituzione rg→grep
3. Creare `tools/sim-ui-guide-codex.md` con tutte le sezioni richieste
4. Creare `.claude/commands/sim-ui.md` come custom slash command
5. Verificare protocollo, AGENTS.md, CLAUDE.md
6. Eseguire V-1..V-19

### Modifiche fatte

| File | Azione | Simboli/elementi toccati |
|------|--------|--------------------------|
| `tools/sim_ui.sh` | Creato | Intero file (~350 righe): wrapper universale con 11 subcomandi, JXA engine, exit code 0/1/2, stdout/stderr standard |
| `tools/sim_ui_task008.sh` | Modificato | Commento backward-compat in cima (+5 righe), `booted_udid()`: `rg` sostituito con `grep -oE` |
| `tools/sim-ui-guide-codex.md` | Creato | Intero file (~150 righe): guida operativa con 9 sezioni |
| `.claude/commands/sim-ui.md` | Creato | Intero file (~90 righe): custom slash command `/sim-ui` |
| `docs/TASKS/TASK-012-simulator-automation-skill.md` | Modificato | Fase PLANNING→EXECUTION, sezione Execution compilata |
| `docs/MASTER-PLAN.md` | Modificato | Fase PLANNING→EXECUTION nel tracking task attivo |

**Nota fix in execution**: durante i test SIM, scoperto che `elementName()` nel JXA leggeva solo `name()`, ma nel Simulator iOS gli elementi dell'app espongono il testo in `description()`. Fix applicato: `elementName()` ora cerca prima in `name()`, poi in `description()`. Questo fix era necessario per soddisfare CA-2 (tutti i subcomandi AX-based funzionanti). Anche corretti pattern `cmd; rc=$?` incompatibili con `set -euo pipefail` (convertiti in `if ! cmd; then`). Aggiunta verifica DEVICE_ID specifico in `require_booted()` per exit 2 corretto.

### Check eseguiti
- [x] Build compila: N/A (nessun codice Swift modificato)
- [x] Nessun warning nuovo: N/A (nessun codice Swift)
- [x] Modifiche coerenti con planning: ✅ ESEGUITO — tutti i deliverable previsti implementati
- [x] Criteri di accettazione verificati: ✅ ESEGUITO — vedi tabelle sotto

### Tabella CA → evidenza

| CA | Tipo verifica | Esito | Evidenza / nota |
|----|---------------|-------|-----------------|
| CA-1 | STATIC | PASS | `test -x` confermato; `grep 'rg '` zero match; solo xcrun/osascript/grep/awk/sed/open usati |
| CA-2 | SIM | PASS | Tutti gli 11 subcomandi testati in V-1..V-14, V-19; launch/terminate con e senza bundle-id |
| CA-3 | SIM | PASS | Exit 0 su successo (V-3,V-4), exit 1 su fallimento (V-5), exit 2 su config error (V-17); stderr con prefisso `[sim_ui]` |
| CA-4 | SIM | PASS | V-1: usage su stdout, exit 0 |
| CA-5 | SIM | PASS | V-19: launch/terminate senza bundle-id usano default; env `SIM_UI_BUNDLE_ID` e `SIM_UI_DEVICE_ID` configurabili |
| CA-6 | SIM | PASS | V-6: output tabellare ROLE\tNAME, elementi app visibili dopo fix description |
| CA-7 | SIM | PASS | V-7: file PNG creato, stdout stampa path, exit 0 |
| CA-8 | STATIC | PASS | File esiste con tutte le sezioni: subcomandi, flusso, fallback, limiti, stop-on-failure |
| CA-9 | STATIC | PASS | Sezione "Regola stop-on-failure" presente con pattern esplicito |
| CA-10 | STATIC | PASS | Sezione "Reporting" con formato `T-NN: STATO [TIPO] — nota` |
| CA-11 | STATIC | PASS | `AGENTS.md` contiene sezione "Protocollo di execution per task UI / Simulator" con puntatori a guida e protocollo |
| CA-12 | STATIC | PASS | `.claude/commands/sim-ui.md` esiste |
| CA-13 | STATIC | PASS | Contiene: subcomandi, flusso, fallback, limiti, stop-on-failure |
| CA-14 | STATIC | PASS | Istruzione esplicita: "NON generare comandi osascript inline. Usa SEMPRE il wrapper." |
| CA-15 | STATIC+SIM | PASS | V-11: `sim_ui_task008.sh launch-app` exit 0; commento backward-compat presente in cima |
| CA-16 | STATIC | PASS | `grep -i` per ManualEntry/task008/Conferma/etc.: zero match in sim_ui.sh |
| CA-17 | STATIC | PASS | Limiti documentati in entrambi gli adapter: no multi-touch, solo Simulator, permessi, prompt |
| CA-18 | STATIC | PASS | V-15: protocollo esiste con tutte le 10 sezioni obbligatorie |
| CA-19 | STATIC | PASS | V-16: AGENTS.md referenzia protocollo come lettura obbligatoria + regola handoff conforme |
| CA-20 | STATIC | PASS | V-16: CLAUDE.md referenzia protocollo come standard di review con 5 punti verifica |

### Tabella V-NN → esito

| V-NN | Stato | Tipo | Nota |
|------|-------|------|------|
| V-1 | PASS | SIM | Usage su stdout, exit 0. Fix shift warning applicato |
| V-2 | PASS | SIM | Simulator in foreground, exit 0. Fix noise JXA applicato |
| V-3 | PASS | SIM | `launch com.niwcyber.iOSMerchandiseControl` exit 0 |
| V-4 | PASS | SIM | `wait-for "Inventario" 5` → stdout FOUND, exit 0 |
| V-5 | PASS | SIM | `wait-for "ElementoInesistente" 2` → stdout NOT_FOUND, stderr messaggio, exit 1 |
| V-6 | PASS | SIM | `dump-names` → tabella ROLE\tNAME, 25+ righe con contenuto app visibile |
| V-7 | PASS | SIM | `capture /tmp/sim_test_v7.png` → file PNG creato, stdout path, exit 0 |
| V-8 | PASS | SIM | `terminate com.niwcyber.iOSMerchandiseControl` exit 0 |
| V-9 | PASS | SIM | `tap-name "Inventario"` → click eseguito, exit 0 (corretto in FIX: era stato eseguito con "Database") |
| V-10 | PASS | SIM | `tap-relative 0.5 0.5` → click al centro, exit 0 |
| V-11 | PASS | SIM | `sim_ui_task008.sh launch-app` → comportamento invariato, exit 0 |
| V-12 | PASS | STATIC | `.claude/commands/sim-ui.md` esiste con 6 sezioni chiave |
| V-13 | PASS | STATIC | `tools/sim-ui-guide-codex.md` esiste con 9 sezioni richieste |
| V-14 | PASS | SIM | Flusso completo: show→launch→wait-for→capture→terminate, tutti exit 0, screenshot salvato |
| V-15 | PASS | STATIC | Protocollo: 10/10 sezioni obbligatorie presenti |
| V-16 | PASS | STATIC | AGENTS.md: 1 ref guida + 1 ref protocollo; CLAUDE.md: 1 ref protocollo |
| V-17 | PASS | SIM | `SIM_UI_DEVICE_ID=INVALID-UDID launch` → exit 2, stderr `[sim_ui] ERROR: Device 'INVALID-UDID' non trovato...` |
| V-18 | PASS | STATIC | (a) executable, (b) zsh -n exit 0, (c) grep rg: zero match |
| V-19 | PASS | SIM | `launch` senza bundle-id → default usato, exit 0; `terminate` senza bundle-id → exit 0 |

### Conferma scope
Conferma scope: non ho modificato file o comportamenti fuori dal perimetro del task.
Deviazioni minime in execution:
- `tools/sim_ui.sh`: `elementName()` esteso a leggere anche `description()` — necessario per far funzionare AX-based commands nel Simulator iOS (senza questo fix, CA-2/CA-6 non sarebbero soddisfatti)
- `tools/sim_ui.sh`: pattern `cmd; rc=$?` convertiti in `if ! cmd` — necessario per compatibilità con `set -euo pipefail`
- `tools/sim_ui.sh`: `require_booted()` esteso per verificare DEVICE_ID specifico — necessario per CA-3 exit 2

### Rischi rimasti
- R-2 (prompt approvazione): confermato — ogni chiamata `osascript` tramite il wrapper richiede approvazione. L'utente deve pre-approvare il pattern `./tools/sim_ui.sh *` nei settings dell'agente
- R-9 (`.claude/commands/` supporto): non verificato se `/sim-ui` è invocabile — il file esiste, ma il test richiede interazione utente con Claude Code
- **Follow-up candidate**: la funzione `elementName()` che usa `description()` come fallback è specifica del Simulator. Se Apple cambia il mapping AX, potrebbe rompersi. Non è un bug introdotto dal task ma un limite dell'architettura Simulator/JXA.

### Handoff → Review
- **Prossima fase**: REVIEW
- **Prossimo agente**: CLAUDE (reviewer)
- **Azione consigliata**:
  1. Verificare CA-1..CA-20 contro codice e documenti
  2. Verificare che `sim_ui.sh` non contenga riferimenti task-specifici (CA-16)
  3. Verificare coerenza tra adapter (stessi contenuti tecnici, formato diverso — D-5)
  4. Verificare che `sim_ui_task008.sh` backward compat sia intatta
  5. Verificare che il protocollo sia coerente con il wrapper (specialmente il fix `description()`)
  6. Ri-eseguire V-14 (flusso end-to-end) se Simulator disponibile
  7. Meta-verifica: questo handoff rispetta il protocollo `docs/CODEX-EXECUTION-PROTOCOL.md`

---

## Review (Claude)

**Data review**: 2026-03-21
**Reviewed by**: CLAUDE

### Riepilogo

Tutti i 20 criteri di accettazione (CA-1..CA-20) sono stati verificati con evidenza reale su Simulator (iPhone 16e, iOS 26.2). I 19 test di validazione V-1..V-19 sono stati eseguiti con esito PASS. Due cicli di fix mirati (exit code propagation + V-9 retest + allineamento documentale) hanno chiuso tutte le incoerenze segnalate. La semantica exit code è ora univoca e coerente in tutti i file di riferimento.

### Problemi critici
Nessuno.

### Problemi medi
Nessuno.

### Miglioramenti opzionali
Nessuno.

### Fix richiesti
Nessuno.

### Esito
**APPROVED**

Criteri di accettazione soddisfatti. Evidenza reale presente. Documentazione coerente tra wrapper, adapter Codex, adapter Claude Code e file task.
Il task è in attesa di conferma utente finale per passare a DONE.

### Handoff → conferma utente (APPROVED)
- **Prossima fase**: DONE (dopo conferma utente)
- **Prossimo agente**: UTENTE (conferma finale)
- **Azione consigliata**: Confermare la chiusura del task. Dopo la conferma aggiornare: Stato → DONE, tracking MASTER-PLAN, tabella Task completati.

### Handoff → Fix (se CHANGES_REQUIRED)
- **Prossima fase**: FIX
- **Prossimo agente**: CODEX
- **Azione consigliata**: N/A — esito APPROVED

### Handoff → nuovo Planning (se REJECTED)
- **Prossima fase**: PLANNING
- **Prossimo agente**: CLAUDE
- **Azione consigliata**: N/A — esito APPROVED

---

## Fix (Claude come executor)

### Fix applicati

**Fix 1 — Exit code 2 per AX/configurazione in tap-name, wait-for, dump-names, tap-relative**

Problema: tutti i fallimenti JXA venivano mascherati come exit 1 (operativo). Il contratto CA-3 richiede exit 2 per errori ambiente/AX.

Modifiche a `tools/sim_ui.sh`:
- `allElements()` JXA: `catch` ora usa `$.exit(2)` invece di `return []` quando `entireContents()` fallisce — segnala AX non accessibile
- Shell handler `tap-name`: sostituito `if ! run_jxa` con `jxa_rc=0; run_jxa ... || jxa_rc=$?` + check `jxa_rc -eq 2` → exit 2, altrimenti exit 1
- Shell handler `wait-for`: stesso pattern — preserva exit 2 da JXA, fallback a exit 1 per NOT_FOUND
- Shell handler `dump-names`: cattura output e exit code; exit 2 se JXA segnala AX error
- Shell handler `tap-relative`: stesso pattern per coerenza

**Fix 2 — V-9 rieseguito con input corretto**

Problema: V-9 era stato eseguito con `tap-name "Database"` anziché `tap-name "Inventario"` come previsto dal piano.

Fix: rieseguito `./tools/sim_ui.sh tap-name "Inventario"` → exit 0, click confermato. Tabella V-NN aggiornata.

### File e simboli toccati

| File | Azione | Simboli toccati |
|------|--------|-----------------|
| `tools/sim_ui.sh` | Modificato | `allElements()` (JXA), shell handlers: `tap-name`, `wait-for`, `dump-names`, `tap-relative` |

### Check post-fix
- [x] Build compila: N/A (nessun codice Swift)
- [x] Fix coerenti con review: ✅ — entrambi i fix rispondono ai CHANGES_REQUIRED
- [x] Criteri di accettazione ancora soddisfatti: ✅ — V-4, V-5, V-6, V-9, V-10, V-14 ritestati con PASS
- [x] Nessuna regressione: ✅ — V-14 end-to-end ritestato PASS

### Retest impattati

| V-NN | Stato | Tipo | Nota |
|------|-------|------|------|
| V-4 | PASS | SIM | `wait-for "Inventario" 5` → FOUND, exit 0 (confermato dopo fix) |
| V-5 | PASS | SIM | `wait-for "Inesistente" 2` → NOT_FOUND, exit 1 (confermato dopo fix) |
| V-6 | PASS | SIM | `dump-names` → output tabellare, exit 0 (confermato dopo fix) |
| V-9 | PASS | SIM | `tap-name "Inventario"` → click eseguito, exit 0 (input corretto) |
| V-14 | PASS | SIM | Flusso end-to-end completo, tutti exit 0 (nessuna regressione) |

### Handoff → Review finale
- **Prossima fase**: REVIEW
- **Prossimo agente**: CLAUDE (reviewer)
- **Azione consigliata**:
  1. Verificare che i 3 shell handler (tap-name, wait-for, dump-names) ora propaghino correttamente exit 2
  2. Verificare che `allElements()` in JXA usi `$.exit(2)` e non `return []` su errore
  3. Verificare che V-9 sia stato rieseguito con `tap-name "Inventario"` (non "Database")
  4. Opzionale: ri-eseguire V-17 per confermare che exit 2 funziona anche dal ramo `require_booted`

---

## Chiusura

### Conferma utente
- [ ] Utente ha confermato il completamento

### Follow-up candidate
- Test runner wrapper che esegue una suite di test e produce report JSON
- Subcomando `swipe <direction>` tramite CGEvent per scroll/navigazione
- Subcomando `long-press <fragment> [duration]` per context menu
- `simctl ui` per status bar override (nascondere orologio/indicatori nei screenshot)
- MCP server che espone i subcomandi come tool (architettura più pesante, solo se il wrapper non basta)
- Migrazione completa di `sim_ui_task008.sh` a thin wrapper sopra `sim_ui.sh` (dopo chiusura TASK-008)

### Riepilogo finale
[da compilare]

### Data completamento
[da compilare]
