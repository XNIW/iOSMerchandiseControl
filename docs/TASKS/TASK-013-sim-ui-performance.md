# TASK-013: sim_ui.sh performance — batch mode, timeout reale, cache device frame

## Informazioni generali
- **Task ID**: TASK-013
- **Titolo**: sim_ui.sh performance — batch mode, timeout reale, cache device frame
- **File task**: `docs/TASKS/TASK-013-sim-ui-performance.md`
- **Stato**: BLOCKED
- **Fase attuale**: —
- **Responsabile attuale**: —
- **Data creazione**: 2026-03-21
- **Ultimo aggiornamento**: 2026-03-22
- **Ultimo agente che ha operato**: CLAUDE
- **Nota**: task sospeso per decisione utente (2026-03-22). Il wrapper SIM UI è stato rimosso dal workflow standard del progetto. Nessun ulteriore lavoro di ottimizzazione previsto. Vedi sezione Decisioni.

## Dipendenze
- **Dipende da**: TASK-012 (wrapper creato, funzionante, DONE)
- **Sblocca**: TASK-008 (i test T-1..T-28 con molte micro-azioni diventano praticabili solo con performance ragionevoli)

## Scopo
Ottimizzare `tools/sim_ui.sh` per eliminare il collo di bottiglia principale: ogni micro-azione (tap, clear, type, wait-for) paga il costo completo di bootstrap JXA + attivazione Simulator + scansione AX tree. Con sequenze di 10+ azioni per test case, il tempo totale diventa proibitivo (minuti per singolo caso).

## Contesto
Il profiling reale eseguito dall'utente ha misurato:
- `activateSimulator()` via JXA: ~0.88s
- `window.entireContents()`: ~3.3s
- Iterazione `name()/description()/role()` su centinaia di elementi AX: >60s in alcuni casi
- `tap-relative` (che deve solo cliccare): ~12s a causa del ricalcolo `deviceFrame()` ogni volta
- `capture`: ~0.34s (veloce, non è il problema)
- Processi `wait-for` e `dump-names` che restano vivi oltre il timeout dichiarato

Il wrapper funziona correttamente ma è inutilizzabile per test con molte azioni seriali. Il problema è nell'infrastruttura, non nell'app.

## Non incluso
- Modifiche al codice Swift / iOS dell'app
- Nuovi subcomandi non legati alla performance (swipe, long-press, etc.)
- Cambio di tecnologia (da JXA a altro)
- Modifiche agli adapter (sim-ui-guide-codex.md, sim-ui.md) salvo documentazione nuovi subcomandi
- Test runner / framework di test strutturati

## File potenzialmente coinvolti

| File | Tipo | Motivazione |
|------|------|-------------|
| `tools/sim_ui.sh` | Modifica | Tutti gli interventi di performance sono qui |
| `tools/sim-ui-guide-codex.md` | Modifica minima | Documentare i nuovi subcomandi batch/replace-field |
| `.claude/commands/sim-ui.md` | Modifica minima | Documentare i nuovi subcomandi |

## Criteri di accettazione
Questi criteri sono il contratto del task. Execution e review lavorano contro di essi.
Se cambiano in corso d'opera, aggiornare QUI prima di proseguire.

### Timeout reale
- [ ] CA-1: Ogni invocazione di `osascript` è protetta da un timeout esterno shell (watchdog subprocess — vedi sezione 3a). Se il processo JXA non termina entro il limite, il watchdog scrive un **file sentinel** (es. `/tmp/sim_ui_timeout.$$`) prima di inviare TERM, poi killa il child (`TERM`, poi `KILL` dopo 2s). Il wrapper controlla l'esistenza del sentinel per determinare la causa della terminazione (vedi CA-1b).
- [ ] CA-1b: **Timeout provenance**: il messaggio `[sim_ui] ERROR: JXA timeout dopo Ns` su stderr viene emesso **solo** se il file sentinel del watchdog esiste al momento del check post-`wait`. Se il child termina con exit 143/137 ma il sentinel non esiste (terminazione esterna: `kill` manuale, SIGTERM dal processo padre, Ctrl-C), il wrapper NON riporta timeout — riporta invece `[sim_ui] ERROR: processo interrotto (signal)` su stderr e ritorna exit 1. Il sentinel viene sempre rimosso dopo il check (sia in caso di timeout che di terminazione esterna). Questo evita diagnosi fuorvianti dove una terminazione esterna viene confusa con un timeout del watchdog.
- [ ] CA-2: Il timeout esterno è configurabile via variabile d'ambiente `SIM_UI_JXA_TIMEOUT` con default 30s.
- [ ] CA-3: Dopo un timeout **o un'interruzione dello shell wrapper** (SIGINT, SIGTERM, EXIT), nessun processo `osascript` orfano resta in vita. Il wrapper installa un `trap` su INT/TERM/EXIT che killa il child `osascript` in corso (se presente) e verifica la terminazione effettiva del processo.

### Batch mode — contratto input/output
- [ ] CA-4: Esiste un subcomando `batch` che accetta una sequenza di azioni su stdin (una per riga) e le esegue in una singola sessione JXA, senza rilanciare `osascript` per ogni azione.
- [ ] CA-5: **Formato input**: ogni riga è un'azione nel formato `subcomando arg1 arg2 ...`, identico alla sintassi CLI dei subcomandi singoli. Gli argomenti con spazi devono essere racchiusi in virgolette doppie (es. `type "ciao mondo"`). Linee vuote e linee che iniziano con `#` vengono ignorate (commenti). Linee con subcomando non riconosciuto causano exit 1 immediato con messaggio che indica il **numero di riga fisico** dello stdin (contando da 1, incluse righe vuote e commenti — non l'indice delle sole azioni valide). **Il parsing delle righe deve usare `/usr/bin/python3 -c 'import shlex,sys,json; print(json.dumps(shlex.split(sys.stdin.readline())))'`** (o equivalente deterministico). È **vietato** usare `eval set --` o qualsiasi forma di `eval` per lo split degli argomenti (vedi D-8).
- [ ] CA-6: Il batch mode riutilizza `activateSimulator()`, `frontWindow()` e `deviceFrame()` calcolati una sola volta all'inizio della sessione.
- [ ] CA-7: Se un'azione nel batch fallisce, il batch si ferma immediatamente (stop-on-failure) e ritorna exit 1 con messaggio `[sim_ui] BATCH FAIL at line N: <subcomando> — <motivo>`.
- [ ] CA-8: Il batch mode supporta almeno: `tap-relative`, `tap-name`, `wait-for`, `type`, `clear-field`, `wait`, `capture`, `replace-field`.

### Cache device frame
- [ ] CA-9: `tap-relative` e `replace-field` dentro una sessione batch NON ricalcolano `deviceFrame()` ad ogni invocazione — usano il frame calcolato all'inizio. **Nota**: la cache è valida per la durata della sessione batch. Se in futuro arrivano subcomandi che cambiano geometria/finestra/orientamento del Simulator, dovranno invalidare la cache e ricalcolare `deviceFrame()`. Documentare questa invariante nel codice.
- [ ] CA-10: Le invocazioni singole (non batch) continuano a funzionare come prima (nessuna regressione).

### Subcomando composto replace-field
- [ ] CA-11: Esiste un subcomando `replace-field <relX> <relY> <value>` che in una singola invocazione JXA fa: tap alle coordinate relative → clear del campo → type del valore.
- [ ] CA-12: `replace-field` è equivalente a `tap-relative <relX> <relY>` + `clear-field` + `type <value>` ma con un solo bootstrap JXA.

### Ricerca AX mirata
- [ ] CA-13: **AGGIORNATO in execution (misurazione preliminare)**: la ricorsione manuale `uiElements()` a profondità ≤4 (e anche ≤8) **non raggiunge** gli elementi iOS nel Simulator. L'AX tree del Simulator espone gli elementi dell'app solo via `entireContents()`, non tramite la gerarchia `uiElements()` standard. Misurazioni: `uiElements()` depth≤4 trova 23 nodi (nessun elemento app) in ~1.5s; `entireContents()` trova 83 nodi (inclusi elementi app) in ~2.8s. Il fast-path è stato **rimosso** dal piano: `tap-name` e `wait-for` continuano a usare `entireContents()` come unico metodo di ricerca. Il guadagno di performance su questo asse viene dal batch mode (singolo bootstrap) e dalla cache activateSimulator/frontWindow.
- [ ] CA-14: `entireContents()` resta l'unico metodo di ricerca (non serve fallback perché non c'è fast-path). Nessuna regressione.
- [ ] CA-14b: **AGGIORNATO**: senza fast-path, il polling di `wait-for` usa `entireContents()` ad ogni iterazione (come oggi). L'ottimizzazione principale viene dal batch mode (singola sessione JXA, nessun re-bootstrap tra poll).

### Skip attivazione ridondante
- [ ] CA-15: Se il Simulator è già frontmost, `activateSimulator()` salta il `delay(0.5)` di attivazione e il `delay(0.2)` post-frontmost. La verifica usa `proc.frontmost()`. **Se il check `proc.frontmost()` risulta costare >0.3s** (vanificando il risparmio), l'executor deve aggiornare questo CA *prima* di procedere, non durante.

### Capture nel batch — contratto
- [ ] CA-18: `capture` nel batch può usare un boundary shell (il JXA si interrompe, lo shell esegue `xcrun simctl io screenshot`, poi le azioni successive riprendono in un nuovo JXA o nello stesso), oppure esecuzione diretta via `NSTask`/ObjC bridge dal JXA. L'approccio scelto dall'executor deve garantire: **(a)** l'ordine delle azioni è preservato — capture avviene nel punto esatto della sequenza; **(b)** stop-on-failure resta corretto — se capture fallisce (exit ≠ 0 da simctl), il batch si ferma con il messaggio standard `BATCH FAIL at line N`; **(c)** la diagnostica batch (numero riga, subcomando, motivo) resta coerente; **(d)** le azioni JXA consecutive che non contengono `capture` continuano a beneficiare della sessione unica (nessun re-bootstrap tra due azioni non-capture consecutive).

### Diagnostica uniforme
- [ ] CA-19: **Tutti** i messaggi di errore del wrapper (timeout, batch fail, parsing fail, validation fail, interruzione) usano il prefisso `[sim_ui]`, vanno su **stderr**, e seguono lo stesso pattern: `[sim_ui] ERROR: <descrizione>` per errori fatali, `[sim_ui] BATCH FAIL at line N: <subcomando> — <motivo>` per errori nel batch. Nessun messaggio diagnostico va su stdout (stdout è riservato all'output del subcomando, es. `dump-names`, `dump-ax`). Il JXA **NON usa `console.log()` per la diagnostica** — usa un helper `stderrPrint(msg)` implementato via ObjC bridge (`$.NSFileHandle.fileHandleWithStandardError`) che scrive direttamente su fd 2 (vedi D-14). Questo garantisce che stderr sia controllato esplicitamente, senza dipendere dal comportamento non documentato di `console.log` in `osascript`.

### Validazione argomenti
- [ ] CA-20: Il batch dispatcher e `replace-field` (sia singolo che in batch) applicano la **stessa validazione** dei subcomandi singoli: **(a)** arity corretta — numero di argomenti atteso per ogni subcomando (es. `tap-relative` richiede esattamente 2, `replace-field` esattamente 3, `type` esattamente 1, `wait` esattamente 1, `capture` esattamente 1); **(b)** valori numerici validi — `relX`, `relY`, timeout di `wait-for`, durata di `wait` devono essere numeri parsabili (il check può avvenire shell-side o JXA-side, ma deve avvenire prima dell'uso); **(c)** messaggi di errore coerenti — nel batch il messaggio include il numero di riga fisico (come da CA-5/CA-7), nelle invocazioni singole il messaggio segue il formato CA-19; **(d)** la validazione dell'arity nel batch avviene **shell-side** (durante il parsing, prima di lanciare il JXA), così un errore di arity non paga il costo del bootstrap JXA.

### Batch grande — fallback temp file
- [ ] CA-21: Se il JSON serializzato delle azioni batch supera una soglia sicura (es. 120000 byte — sotto il limite tipico di ~128KB per env var su macOS), il dispatcher shell **non usa l'env var `BATCH_ACTIONS`** ma scrive il JSON in un file temporaneo (es. `/tmp/sim_ui_batch.$$.json`) e passa il path via env var `BATCH_ACTIONS_FILE`. Il JXA controlla prima `BATCH_ACTIONS_FILE` (legge da file), poi `BATCH_ACTIONS` (legge da env). Il file temporaneo viene rimosso dal dispatcher shell dopo il completamento del JXA (sia in caso di successo che di errore). Il trap cleanup (`_cleanup_jxa`) deve anche rimuovere il temp file se presente.

### Non regressione
- [ ] CA-16: Tutti i subcomandi esistenti (CA-2 di TASK-012) continuano a funzionare invariati quando invocati singolarmente.
- [ ] CA-17: I test V-1..V-19 di TASK-012 passano ancora.

## Decisioni
Decisioni superate o cambiate non vanno cancellate: marcarle come OBSOLETA con nota esplicita.

| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|-------|
| D-1 | Batch mode via stdin: l'agente scrive azioni in formato testuale (una per riga, shell-quoting standard), il dispatcher shell le parsifica e le passa al JXA come array JSON via env var. L'agente non scrive JSON, il wrapper sì internamente. | JSON scritto dall'agente; file di comandi; subcomando multi-arg | stdin è il pattern Unix standard per piping; l'agente usa heredoc con sintassi identica ai subcomandi singoli; il JSON è un dettaglio interno del bridge shell→JXA, non esposto all'utente | attiva |
| D-2 | Timeout esterno shell con `kill` dopo N secondi | `timeout` GNU (non disponibile su macOS base); solo timeout JXA interno | `timeout` richiede coreutils; `kill` + background process è POSIX; il timeout JXA interno non protegge da `entireContents()` bloccato | attiva |
| D-3 | `replace-field` come subcomando dedicato, non come alias batch | Solo batch mode | `replace-field` è il pattern più comune nei test (3 azioni in 1); un subcomando dedicato è più leggibile e non richiede stdin | attiva |
| D-4 | Ricerca AX mirata per role prima di `entireContents()` | Solo `entireContents()`; eliminare `entireContents()` | `entireContents()` resta come fallback robusto; la ricerca per role è un fast-path che evita il costo nella maggioranza dei casi | attiva |
| D-5 | Skip delay solo se `proc.frontmost()` è true | Eliminare delay completamente; cache di stato | Il delay è necessario solo quando il Simulator non è già in primo piano; la verifica è un singolo check AX economico | attiva |
| D-6 | Ricerca AX mirata con ricorsione manuale `uiElements()` limitata a profondità ≤4, non con `.whose()` | `.whose()` di System Events; `entireContents()` con filtro post-hoc | `.whose()` nel contesto Simulator non è documentato come più veloce e potrebbe internamente fare la stessa scansione completa; la ricorsione manuale a profondità limitata dà controllo diretto sul costo e si ferma appena trova il match | attiva |
| D-7 | Il batch parsifica le righe stdin nel dispatcher shell e le passa al JXA come array JSON via env var `BATCH_ACTIONS` | Passare righe raw al JXA; usare file temporaneo | Il parsing shell-side permette di validare subcomandi e quoting prima di lanciare osascript; il JSON è il modo naturale di passare dati strutturati a JXA; l'env var evita problemi di quoting nel heredoc | attiva |
| D-8 | Il parsing delle righe batch usa `/usr/bin/python3` + `shlex.split()` (o parser deterministico equivalente). `eval set --` e qualsiasi forma di `eval` sono **vietati** per lo split degli argomenti. | `eval set --`; parsing regex manuale in bash puro | `eval` è fragile con backslash, `$`, accenti, virgolette annidate; `shlex.split` è il tokenizer POSIX-shell di riferimento, deterministico e testato; `/usr/bin/python3` è presente su macOS dalla 12.3+ (Monterey) ed è la stessa dipendenza usata da Xcode CLI tools | attiva |
| D-9 | `capture` nel batch può usare un boundary shell (split JXA) o `NSTask` dal JXA — l'executor sceglie, ma deve garantire ordine, stop-on-failure, diagnostica coerente e nessun re-bootstrap tra azioni non-capture consecutive | Solo boundary shell; solo NSTask | entrambi gli approcci sono accettabili; il contratto è funzionale (CA-18), non implementativo | attiva |
| D-10 | Il wrapper installa `trap` su INT/TERM/EXIT per killare il child `osascript` in corso, non solo in caso di timeout | Solo cleanup post-timeout | l'utente o il sistema possono interrompere il wrapper in qualsiasi momento (Ctrl-C, kill del processo padre); senza trap, il child osascript resta orfano | attiva |
| D-11 | **Timeout provenance via sentinel file**: il watchdog scrive un file sentinel (`/tmp/sim_ui_timeout.$$`) prima di inviare TERM al child. Il wrapper usa l'esistenza del sentinel per distinguere timeout watchdog da terminazione esterna. Il sentinel viene sempre rimosso dopo il check. | Solo exit code 143/137; flag in-memory tra subshell | Exit code 143/137 è ambiguo: lo produce sia il watchdog che un `kill` esterno. Un flag in-memory non è condivisibile tra la subshell watchdog e il processo padre. Un file sentinel è il meccanismo più semplice e robusto per comunicare tra i due processi. | attiva |
| D-12 | ~~Diagnostica uniforme via `console.log`~~ | — | — | **OBSOLETA** — sostituita da D-14. Il principio (prefisso `[sim_ui]`, stderr, stdout pulito) resta valido, ma il meccanismo cambia da `console.log` a helper ObjC esplicito. |
| D-13 | **Validazione arity shell-side nel batch**: il dispatcher shell verifica il numero di argomenti per ogni subcomando *prima* di lanciare il JXA. Errori di arity costano zero bootstrap. La validazione numerica può avvenire shell-side o JXA-side. | Solo validazione JXA-side; nessuna validazione | Validare prima del JXA evita di pagare ~1-3s di bootstrap per un errore banale come argomenti mancanti; la validazione numerica è meno critica (il costo è nel JXA che gira comunque) ma deve avvenire da qualche parte | attiva |
| D-14 | **Diagnostica JXA via ObjC bridge, non `console.log`**: il JXA definisce un helper `stderrPrint(msg)` che usa `ObjC.import("Foundation")` e `$.NSFileHandle.fileHandleWithStandardError` per scrivere direttamente su fd 2. Tutti i messaggi diagnostici JXA (BATCH FAIL, errori interni) usano questo helper. `console.log` **non** è usato per diagnostica. | `console.log` | Il comportamento di `console.log` in `osascript -l JavaScript` non è documentato come contratto stabile verso stderr; in alcune versioni/contesti potrebbe andare su stdout o essere soppresso. L'ObjC bridge è il modo canonico per controllare esplicitamente fd 2 dal JXA. `ObjC.import("Foundation")` è già necessario se si sceglie NSTask per `capture` (D-9), quindi non aggiunge dipendenze. | attiva |
| D-15 | **Fallback temp file per batch grandi**: se il JSON serializzato delle azioni supera 120000 byte, il dispatcher scrive in un temp file (`/tmp/sim_ui_batch.$$.json`) e passa il path via `BATCH_ACTIONS_FILE`. Il JXA controlla prima `BATCH_ACTIONS_FILE`, poi `BATCH_ACTIONS`. Il temp file è rimosso dal dispatcher e dal trap cleanup. | Solo env var; solo temp file sempre | L'env var è più semplice e copre il 99% dei casi (batch tipici sono <1KB). Il temp file serve solo come safety net per batch eccezionalmente grandi. Usare sempre il temp file aggiungerebbe complessità inutile e un file I/O per ogni batch. | attiva |
| D-16 | **Task sospeso per decisione utente (2026-03-22)**: il wrapper SIM UI (`tools/sim_ui.sh`) e il workflow di auto-test Simulator sono stati rimossi dal workflow standard del progetto. Motivazione: latenza/prestazioni non adeguate ai test rapidi, complessità operativa non giustificata. Il tool resta nel repo come risorsa sperimentale/legacy, non come obbligo. Nessun ulteriore lavoro di ottimizzazione è previsto al momento. | Continuare ottimizzazione; eliminare i file | Decisione esplicita dell'utente: preferisce workflow precedente (build/statiche + test manuali su richiesta) rispetto ad automazione Simulator con latenza elevata | attiva |

---

## Planning (Claude)

### 1) Obiettivo

Ridurre il tempo di esecuzione di sequenze di micro-azioni nel wrapper `sim_ui.sh` da minuti a secondi, intervenendo su 5 colli di bottiglia misurati:

1. **Bootstrap JXA ripetuto**: ogni invocazione lancia un nuovo `osascript`, attiva il Simulator, cerca la finestra — costo fisso ~1-3s/invocazione
2. **Scansione AX tree completa**: `entireContents()` + iterazione `name()/description()/role()` su centinaia di elementi — costo ~3-60s
3. **Ricalcolo device frame**: `deviceFrame()` scansiona `uiElements()` ad ogni `tap-relative` — costo ~3s
4. **Timeout non reale**: il timeout di `wait-for` è solo logico dentro JXA; se `entireContents()` si blocca, il processo resta vivo indefinitamente
5. **Delay di attivazione ridondante**: 0.5s + 0.2s per ogni invocazione anche quando il Simulator è già frontmost

### 2) Analisi del codice attuale

Il file `tools/sim_ui.sh` (540 righe) ha questa struttura:

- **Righe 90-375**: `run_jxa()` — singola funzione che genera tutto il JXA inline via heredoc
  - Righe 142-148: `activateSimulator()` — sempre `delay(0.5)` + `delay(0.2)`
  - Righe 166-183: `deviceFrame()` — chiama `frontWindow().uiElements()` e itera per trovare il frame
  - Righe 212-221: `allElements()` — chiama `frontWindow().entireContents()`
  - Righe 243-259: `findElementByName()` — chiama `allElements()`, itera tutto, confronta `elementName()` + `elementRole()`
  - Righe 261-269: `waitForElement()` — loop che chiama `findElementByName()` ad ogni iterazione (quindi `entireContents()` ripetuto)
  - Righe 296-371: switch/dispatch delle azioni

- **Righe 380-540**: dispatcher shell — un `case` per ogni subcomando che chiama `run_jxa`

**Punto chiave**: `run_jxa()` genera un *intero script JXA monolitico* con tutte le funzioni, e il `switch(action)` alla fine decide quale eseguire. Questo significa che per il batch mode possiamo riusare la stessa struttura: invece di un singolo `action`, passiamo una lista di azioni.

### 3) Approccio proposto

#### 3a) Timeout esterno (CA-1, CA-2)

Aggiungere una funzione shell `run_jxa_with_timeout()` che:
1. Lancia `osascript` in background (`&`)
2. Salva il PID in una variabile globale (es. `_JXA_PID`)
3. Attende con `wait` + timeout
4. Se il processo non termina entro `SIM_UI_JXA_TIMEOUT` (default 30s), lo killa con `kill -TERM` e poi `kill -KILL`
5. Ritorna l'exit code originale o exit 1 + messaggio se killato per timeout
6. Resetta `_JXA_PID` dopo la terminazione

**Cleanup robusto (D-10)**: all'inizio dello script (prima di qualsiasi invocazione), installare un `trap` su INT/TERM/EXIT che:
- Se `_JXA_PID` è definito e il processo esiste (`kill -0`), lo killa con TERM → sleep 2 → KILL
- Se `_WATCHDOG_PID` è definito, lo killa anche (evita che il watchdog sopravviva al child)
- Questo copre: timeout, Ctrl-C dell'utente, kill del processo padre, exit normale

```bash
_JXA_PID=""
_WATCHDOG_PID=""
_SENTINEL_FILE="/tmp/sim_ui_timeout.$$"
_BATCH_TMPFILE=""
_cleanup_jxa() {
  # Kill watchdog se esiste
  if [ -n "$_WATCHDOG_PID" ] && kill -0 "$_WATCHDOG_PID" 2>/dev/null; then
    kill "$_WATCHDOG_PID" 2>/dev/null
    wait "$_WATCHDOG_PID" 2>/dev/null
  fi
  _WATCHDOG_PID=""
  # Kill child osascript se esiste
  if [ -n "$_JXA_PID" ] && kill -0 "$_JXA_PID" 2>/dev/null; then
    kill -TERM "$_JXA_PID" 2>/dev/null
    sleep 2
    kill -KILL "$_JXA_PID" 2>/dev/null
  fi
  _JXA_PID=""
  # Cleanup sentinel orfano (D-11)
  rm -f "$_SENTINEL_FILE"
  # Cleanup temp file batch orfano (D-15, CA-21)
  [ -n "$_BATCH_TMPFILE" ] && rm -f "$_BATCH_TMPFILE"
  _BATCH_TMPFILE=""
}
trap _cleanup_jxa INT TERM EXIT
```

**Meccanismo timeout (watchdog subprocess con sentinel — D-11)**:

`run_jxa_with_timeout()` non usa `wait` con polling. Usa un subprocess watchdog esplicito con **file sentinel** per distinguere timeout dal watchdog vs terminazione esterna (CA-1b):

```bash
_SENTINEL_FILE="/tmp/sim_ui_timeout.$$"

run_jxa_with_timeout() {
  local timeout="${SIM_UI_JXA_TIMEOUT:-30}"
  # 0. Rimuove eventuale sentinel residuo da run precedente
  rm -f "$_SENTINEL_FILE"
  # 1. Lancia osascript in background, salva PID
  osascript -l JavaScript ... &
  _JXA_PID=$!
  # 2. Lancia watchdog: dorme $timeout, poi scrive sentinel e killa il child
  (
    sleep "$timeout"
    if kill -0 "$_JXA_PID" 2>/dev/null; then
      # SENTINEL: marca che la terminazione è causata dal watchdog, non esterna
      touch "$_SENTINEL_FILE"
      kill -TERM "$_JXA_PID" 2>/dev/null
      sleep 2
      kill -KILL "$_JXA_PID" 2>/dev/null
    fi
  ) &
  _WATCHDOG_PID=$!
  # 3. Attende il child osascript (bloccante, nessun polling)
  wait "$_JXA_PID"
  local exit_code=$?
  _JXA_PID=""
  # 4. Cancella il watchdog (il child è terminato — prima del timeout o no)
  if kill -0 "$_WATCHDOG_PID" 2>/dev/null; then
    kill "$_WATCHDOG_PID" 2>/dev/null
    wait "$_WATCHDOG_PID" 2>/dev/null
  fi
  _WATCHDOG_PID=""
  # 5. Distingue timeout watchdog da terminazione esterna (CA-1b, D-11)
  if [ $exit_code -eq 143 ] || [ $exit_code -eq 137 ]; then
    if [ -f "$_SENTINEL_FILE" ]; then
      # Timeout confermato dal watchdog
      rm -f "$_SENTINEL_FILE"
      echo "[sim_ui] ERROR: JXA timeout dopo ${timeout}s" >&2
    else
      # Terminazione esterna (kill manuale, Ctrl-C propagato, SIGTERM dal parent)
      echo "[sim_ui] ERROR: processo interrotto (signal)" >&2
    fi
    return 1
  fi
  # 6. Cleanup sentinel (caso normale: child terminato prima del timeout)
  rm -f "$_SENTINEL_FILE"
  return $exit_code
}
```

Proprietà:
- **Nessuna race**: `wait` è bloccante sul PID del child, non usa polling/sleep loop
- **Watchdog cancellato se non serve**: se il child termina prima del timeout, il watchdog viene killato subito
- **Doppio kill**: TERM → sleep 2 → KILL (allineato con CA-1 e trap)
- **Trap come safety net**: se il wrapper viene interrotto durante il `wait`, il trap uccide sia il child che il watchdog
- **Timeout provenance (D-11)**: il sentinel è scritto dal watchdog *prima* del TERM; il wrapper lo legge *dopo* il `wait`. Se il child è stato killato da un segnale esterno, il sentinel non esiste → il wrapper riporta "processo interrotto", non "timeout". Il sentinel viene sempre rimosso dopo il check.
- **Cleanup sentinel nel trap**: la funzione `_cleanup_jxa()` deve anche fare `rm -f "$_SENTINEL_FILE"` per evitare sentinel orfani in caso di interruzione del wrapper stesso

Tutti i punti del dispatcher shell che oggi chiamano `run_jxa` passeranno a `run_jxa_with_timeout`.

#### 3b) Skip attivazione ridondante (CA-13)

In `activateSimulator()` nel JXA:
```javascript
function activateSimulator() {
  const proc = se.processes.byName("Simulator");
  if (proc.frontmost()) {
    // già in primo piano, skip delay
    return proc;
  }
  sim.activate();
  delay(0.5);
  proc.frontmost = true;
  delay(0.2);
  return proc;
}
```
Costo: da ~0.7s a ~0s quando già frontmost.

#### 3c) Ricerca AX mirata (CA-13, CA-14)

Aggiungere `findElementFast()` con ricorsione manuale a profondità limitata:
```javascript
function findElementFast(fragment, preferredRole, maxDepth) {
  const needle = lower(fragment);
  // Ricorsione manuale sui livelli dell'AX tree
  function searchLevel(parent, depth) {
    if (depth > maxDepth) return null;
    let els;
    try { els = parent.uiElements(); } catch (e) { return null; }
    for (let i = 0; i < els.length; i++) {
      try {
        const name = elementName(els[i]);
        if (name && lower(name).includes(needle)) {
          const role = elementRole(els[i]);
          if (!preferredRole || role === preferredRole) {
            return { element: els[i], role, name };
          }
        }
      } catch (e) { /* skip */ }
    }
    // Scendi nei figli
    for (let i = 0; i < els.length; i++) {
      const found = searchLevel(els[i], depth + 1);
      if (found) return found;
    }
    return null;
  }
  return searchLevel(frontWindow(), 0);
}

function findElementByNameWithFastPath(fragment, preferredRole) {
  // Fast path: ricorsione limitata a profondità 4
  const fast = findElementFast(fragment, preferredRole, 4);
  if (fast) return fast;
  // Fallback: entireContents() (cammina tutto l'albero)
  return findElementByName(fragment, preferredRole);
}
```

**Decisione D-6**: si usa ricorsione manuale `uiElements()`, non `.whose()`. Il costo della ricorsione a profondità 4 è proporzionale al numero di nodi nei primi 4 livelli, non a tutto l'albero.

**Obbligo di misurazione**: prima di integrare il fast-path nel codice finale, l'executor deve misurare il guadagno con un test isolato (tempo fast-path vs tempo `entireContents()` su schermata reale). Se il guadagno è <30%, deve aggiornare CA-13/CA-14 nel file task prima di procedere.

**Strategia di polling `wait-for` (CA-14b)**:

Il problema originale non è solo che la singola ricerca AX è lenta, ma che `wait-for` la ripete N volte nel loop di attesa, moltiplicando il costo. La strategia è:

```javascript
function waitForElementSmart(fragment, timeout) {
  const deadline = Date.now() + timeout * 1000;
  let attempts = 0;
  while (Date.now() < deadline) {
    attempts++;
    // Ogni poll usa il fast-path (ricorsione limitata)
    const fast = findElementFast(fragment, null, 4);
    if (fast) return fast;
    delay(0.5); // intervallo tra poll
  }
  // Ultima chance: un singolo fallback entireContents() prima di dichiarare FAIL
  // Solo se ci sono state ≥3 iterazioni fast-path fallite
  if (attempts >= 3) {
    const full = findElementByName(fragment, null);
    if (full) return full;
  }
  throw new Error("Elemento '" + fragment + "' non trovato entro " + timeout + "s");
}
```

Regole:
- Ogni iterazione di poll usa **sempre** il fast-path (ricorsione ≤4)
- `entireContents()` come fallback è limitato a **una sola volta**, nell'ultima iterazione prima del timeout
- Il fallback scatta solo se ci sono state ≥3 iterazioni fast-path fallite (evita `entireContents()` su timeout molto brevi)

#### 3d) Cache device frame in batch (CA-4, CA-7)

Nel batch mode, calcolare `deviceFrame()` una sola volta e passarlo come variabile:
```javascript
const cachedFrame = deviceFrame();
// poi nelle azioni batch:
function clickRelativeCached(relX, relY, frame) {
  clickPoint(frame.x + frame.width * Number(relX), frame.y + frame.height * Number(relY));
  delay(0.3);
}
```

#### 3e) Subcomando `batch` (CA-4..CA-8)

**Contratto input**:
```
# Formato: una riga = un'azione. Sintassi identica ai subcomandi singoli.
# Argomenti con spazi: racchiusi in virgolette doppie.
# Linee vuote: ignorate.
# Linee che iniziano con #: ignorate (commenti).
# Subcomando non riconosciuto: exit 1 immediato con numero riga.
#
# Esempio heredoc (come lo scrive l'agente):
#   ./tools/sim_ui.sh batch <<'BATCH'
#   tap-relative 0.5 0.3
#   wait 0.5
#   type "ciao mondo"
#   wait-for "Conferma" 5
#   capture /tmp/test.png
#   BATCH
```

**Shell dispatcher** (D-7 + D-8 + D-13 — parsing + validazione shell-side → JSON per JXA):
```bash
batch)
  # 1. Legge stdin riga per riga
  # 2. Ignora righe vuote e commenti (#)
  # 3. Parsifica ogni riga con /usr/bin/python3 + shlex.split (D-8):
  #    tokens=$(/usr/bin/python3 -c 'import shlex,sys,json; print(json.dumps(shlex.split(sys.stdin.readline())))' <<< "$line")
  #    ⚠️ eval set -- è VIETATO (D-8)
  # 4. Estrae cmd (primo token) e args (resto)
  # 5. Valida il subcomando contro lista nota; se non riconosciuto → exit 1 + numero riga
  # 6. Valida ARITY shell-side (D-13, CA-20):
  #    - tap-relative: 2 args | tap-name: 1-2 args | wait-for: 1-2 args
  #    - type: 1 arg | clear-field: 0 args | wait: 1 arg
  #    - capture: 1 arg | replace-field: 3 args
  #    Se arity errata → exit 1 con: [sim_ui] ERROR: riga N: <cmd> richiede N argomenti, ricevuti M
  # 7. Serializza in JSON array: [{"cmd":"tap-relative","args":["0.5","0.5"],"line":1}, ...]
  # 8. Misura dimensione JSON; se >120000 byte (CA-21, D-15):
  #    - Scrive in /tmp/sim_ui_batch.$$.json
  #    - Passa path via env var BATCH_ACTIONS_FILE
  #    - Registra il path nel trap cleanup (_BATCH_TMPFILE)
  #    Altrimenti: passa direttamente via env var BATCH_ACTIONS
  # 9. Lancia run_jxa_with_timeout con ACTION=batch
  # 10. Cleanup: rimuove il temp file se creato (anche su errore)
```

**JXA batch handler**:
```javascript
// Helper stderr via ObjC bridge (D-14, CA-19)
ObjC.import("Foundation");
function stderrPrint(msg) {
  const data = $.NSString.alloc.initWithUTF8String(msg + "\n");
  $.NSFileHandle.fileHandleWithStandardError
    .writeDataError(data.dataUsingEncoding($.NSUTF8StringEncoding), null);
}

// Lettura azioni: prima da file (CA-21), poi da env var
function loadBatchActions() {
  const filePath = $.NSProcessInfo.processInfo.environment.objectForKey("BATCH_ACTIONS_FILE");
  if (filePath && filePath.js) {
    const data = $.NSString.stringWithContentsOfFileEncodingError(filePath.js, $.NSUTF8StringEncoding, null);
    return JSON.parse(data.js);
  }
  return JSON.parse(env("BATCH_ACTIONS"));
}

case "batch": {
  const actions = loadBatchActions();
  const proc = activateSimulator();
  const win = frontWindow();
  const frame = deviceFrame();  // calcolato una volta, riusato per tutti i tap-relative/replace-field
  // INVARIANTE CACHE (CA-9): frame è valido per tutta la sessione batch.
  // Se in futuro arrivano subcomandi che cambiano geometria/finestra/orientamento,
  // dovranno invalidare questa cache e ricalcolare deviceFrame().
  for (let i = 0; i < actions.length; i++) {
    const a = actions[i];
    try {
      switch (a.cmd) {
        case "tap-relative":
          clickPoint(frame.x + frame.width * Number(a.args[0]),
                     frame.y + frame.height * Number(a.args[1]));
          delay(0.3);
          break;
        case "tap-name": /* ... findElementByNameWithFastPath ... */ break;
        case "wait-for": /* ... waitForElementSmart con fast-path ... */ break;
        case "type":     typeSmart(a.args[0]); break;
        case "clear-field": clearFocusedField(); break;
        case "wait":     delay(Number(a.args[0])); break;
        case "capture":  /* ... non gestito in JXA, vedi nota sotto ... */ break;
        case "replace-field":
          clickPoint(frame.x + frame.width * Number(a.args[0]),
                     frame.y + frame.height * Number(a.args[1]));
          delay(0.3); clearFocusedField(); typeSmart(a.args[2]); break;
        default:
          throw new Error("Unknown: " + a.cmd);
      }
    } catch (e) {
      // CA-19 + D-14: diagnostica esplicita su stderr via ObjC bridge
      stderrPrint("[sim_ui] BATCH FAIL at line " + a.line + ": " + a.cmd + " — " + e.message);
      $.exit(1);
    }
  }
  // Nota: `capture` nel batch è gestito come break-out dal JXA:
  // il batch JXA emette un marker stdout "CAPTURE:<path>" e il dispatcher shell
  // esegue `xcrun simctl io screenshot` tra un'azione JXA e la successiva.
  // Alternativa: se troppo complesso, `capture` nel batch fa direttamente
  // screencapture/simctl via ObjC bridge o via shell post-JXA.
  // L'executor sceglie l'approccio più semplice che soddisfa CA-8.
}
```

**Contratto `capture` nel batch (CA-18, D-9)**:

`capture` usa `xcrun simctl io screenshot`, che è un comando shell, non JXA. Due approcci accettabili:
1. **Boundary shell**: il batch JXA si interrompe, lo shell esegue lo screenshot, poi riprende un nuovo JXA per le azioni rimanenti. Il re-bootstrap avviene solo al confine capture, non tra azioni JXA consecutive.
2. **NSTask dal JXA**: `ObjC.import("Foundation")` + `NSTask` per eseguire `xcrun simctl io screenshot` direttamente dal JXA senza uscire.

L'executor sceglie l'approccio che funziona, ma deve garantire (CA-18):
- **(a)** L'ordine delle azioni è preservato — capture avviene nel punto esatto della sequenza
- **(b)** Stop-on-failure resta corretto — se capture fallisce, il batch si ferma con `BATCH FAIL at line N`
- **(c)** La diagnostica batch (numero riga, subcomando, motivo) resta coerente
- **(d)** Le azioni JXA consecutive che non contengono `capture` continuano a beneficiare della sessione unica (nessun re-bootstrap tra due azioni non-capture consecutive)

#### 3f) Subcomando `replace-field` (CA-9, CA-10)

```bash
replace-field)
  # Singola invocazione JXA che fa:
  # 1. clickRelative(relX, relY)
  # 2. clearFocusedField()
  # 3. typeSmart(value)
```

JXA:
```javascript
case "replace-field": {
  clickRelative(args[0], args[1]);
  delay(0.3);
  clearFocusedField();
  typeSmart(args[2]);
  break;
}
```

#### 3g) Documentazione adapter — esempi obbligatori

Entrambi gli adapter (`tools/sim-ui-guide-codex.md` e `.claude/commands/sim-ui.md`) devono essere aggiornati con:

1. **Tabella subcomandi aggiornata** con `batch` e `replace-field` (sintassi + exit code)

2. **Esempio heredoc batch completo**:
```bash
./tools/sim_ui.sh batch <<'BATCH'
# Apri dialog e compila due campi
tap-name "Aggiungi riga"
wait-for "Barcode" 5
replace-field 0.5 0.35 "8001234567890"
replace-field 0.5 0.45 "10"
tap-name "Conferma"
wait-for "Inventario" 5
capture /tmp/after_add.png
BATCH
```

3. **Esempio replace-field singolo**:
```bash
./tools/sim_ui.sh replace-field 0.5 0.35 "8001234567890"
```

4. **Esempio batch stop-on-failure** (cosa succede quando un'azione fallisce):
```bash
# Se "Conferma" non è visibile, il batch si ferma alla riga 3
# e riporta: [sim_ui] BATCH FAIL at line 3: tap-name — Elemento 'Conferma' non trovato entro 5s
./tools/sim_ui.sh batch <<'BATCH'
tap-relative 0.5 0.5
wait 0.5
tap-name "Conferma"
capture /tmp/should_not_reach.png
BATCH
echo "Exit code: $?"  # 1
```

5. **Esempio con valori contenenti spazi**:
```bash
./tools/sim_ui.sh batch <<'BATCH'
type "prezzo unitario"
wait-for "Aggiungi riga" 5
replace-field 0.5 0.4 "valore con spazi"
BATCH
```

6. **Nota su performance**: documentare che il batch mode riduce il tempo di N azioni seriali da N×(bootstrap+azione) a 1×bootstrap+N×azione.

### 4) File da modificare

| # | File | Tipo | Motivazione |
|---|------|------|-------------|
| 1 | `tools/sim_ui.sh` | Modifica | Tutti gli interventi: timeout esterno, batch mode, replace-field, ricerca AX mirata, skip attivazione, cache frame |
| 2 | `tools/sim-ui-guide-codex.md` | Modifica minima | Aggiungere subcomandi `batch` e `replace-field` alla tabella |
| 3 | `.claude/commands/sim-ui.md` | Modifica minima | Aggiungere subcomandi `batch` e `replace-field` |

### 5) Rischi

| # | Rischio | Probabilità | Impatto | Mitigazione |
|---|---------|-------------|---------|-------------|
| R-1 | Ricorsione manuale `uiElements()` a profondità ≤4 non è significativamente più veloce di `entireContents()` nel contesto Simulator | Media | Medio | L'executor deve misurare il fast-path *prima* di integrarlo: se il guadagno è <30% rispetto a `entireContents()`, aggiornare CA-13/CA-14 nel file task (rimuovere il fast-path, documentare la misurazione) *prima* di procedere con il resto dell'implementazione. Il CA non è opzionale in execution — è modificabile solo esplicitamente prima. |
| R-2 | Il batch mode con JSON embedded in env var ha problemi di quoting/dimensione | Media | Medio | Strategia esplicita in CA-21/D-15: se il JSON supera 120000 byte, il dispatcher scrive un temp file e passa il path via `BATCH_ACTIONS_FILE`. Il JXA controlla prima il file, poi l'env var. Il quoting è validato in T-11..T-14, il fallback temp file in T-24. |
| R-3 | `kill -TERM` su `osascript` non lo termina davvero (processi zombie) | Bassa | Alto | `kill -TERM` + sleep 2 + `kill -KILL` + verifica `kill -0` post-mortem. T-2 e T-3 verificano esplicitamente che nessun processo orfano resta. |
| R-4 | Regressione sui subcomandi esistenti dopo refactor interno | Media | Alto | Ri-eseguire V-1..V-19 di TASK-012 come suite di non-regressione (T-1). |
| R-5 | `proc.frontmost()` costa più del delay che risparmia | Bassa | Basso | L'executor deve misurare il costo di `proc.frontmost()`: se >0.3s, aggiornare CA-15 nel file task (rimuovere l'ottimizzazione, documentare la misurazione) *prima* di procedere. Il CA non è opzionale in execution — è modificabile solo esplicitamente prima. |
| R-6 | `/usr/bin/python3` non disponibile su macOS target | Molto bassa | Alto | `/usr/bin/python3` è disponibile da macOS 12.3 (Monterey, marzo 2022) ed è la stessa dipendenza implicita degli Xcode CLI tools. Se per qualche ragione non è presente, il batch mode deve fallire con messaggio chiaro (`[sim_ui] ERROR: /usr/bin/python3 not found — required for batch mode`), non con errore criptico. |

### 6) Test di validazione

#### Non regressione
| # | Verifica | Esito atteso |
|---|----------|--------------|
| T-1 | V-1..V-19 di TASK-012 passano ancora | Tutti PASS |

#### Timeout e cleanup
| # | Verifica | Esito atteso |
|---|----------|--------------|
| T-2 | `SIM_UI_JXA_TIMEOUT=2 ./tools/sim_ui.sh wait-for "ElementoInesistente" 30` | Processo killato dopo ~2s, exit 1, messaggio `[sim_ui] ERROR: JXA timeout dopo 2s` |
| T-3 | Dopo T-2: `ps -axo pid,command \| grep 'osascript -l JavaScript' \| grep -v grep` | Zero righe — nessun processo orfano |

#### Batch mode
| # | Verifica | Esito atteso |
|---|----------|--------------|
| T-4 | Batch via heredoc: `tap-relative 0.5 0.5`, `wait 1`, `capture /tmp/batch_test.png` | Exit 0, screenshot salvato |
| T-5 | Batch con azione fallita al mezzo: `tap-relative 0.5 0.5`, `wait-for "Inesistente" 2`, `capture /tmp/should_not_exist.png` | Exit 1, messaggio `BATCH FAIL at line 2`, screenshot non creato (stop-on-failure) |
| T-6 | Batch vuoto: `./tools/sim_ui.sh batch < /dev/null` | Exit 0, nessun errore |
| T-7 | Batch con linee vuote e commenti: riga vuota, `# commento`, `wait 0.5` | Exit 0, solo `wait` eseguito |
| T-8 | Batch con subcomando non riconosciuto: `invalid-cmd foo` | Exit 1, messaggio con numero riga |

#### replace-field
| # | Verifica | Esito atteso |
|---|----------|--------------|
| T-9 | `replace-field 0.5 0.5 "test123"` | Tap + clear + type in una invocazione, exit 0 |

#### Parsing e quoting
| # | Verifica | Esito atteso |
|---|----------|--------------|
| T-10 | `tap-name "Aggiungi riga"` (nome con spazio) — invocazione singola | Exit 0 o exit 1 (dipende dalla schermata), ma nessun errore di parsing |
| T-11 | `type "ciao mondo"` — invocazione singola | Testo digitato correttamente con lo spazio, exit 0 |
| T-12 | Batch con argomenti contenenti spazi: `type "prezzo unitario"`, `wait-for "Aggiungi riga" 3` | Parsing corretto, exit 0 per type (o exit 1 se wait-for non trova, ma parsing OK) |
| T-13 | `type "caffè"` — valore con accento | Testo digitato correttamente, exit 0 |
| T-14 | `replace-field 0.5 0.5 "valore con spazi"` | Parsing corretto, exit 0 |

#### Performance misurabili
| # | Verifica | Esito atteso |
|---|----------|--------------|
| T-15 | Misura: media di 3 run di 5x `tap-relative 0.5 0.5` singoli (loop shell) vs 1 batch con 5x `tap-relative 0.5 0.5`. Riportare entrambi i tempi medi. | Batch ≥50% più veloce della media delle invocazioni singole |
| T-16 | Misura: media di 3 run di `tap-name "Inventario"` con Simulator già frontmost. Confrontare con baseline TASK-012 (~12s per `tap-relative`, ~0.88s per sola attivazione). Riportare tempo medio. | Tempo medio per `tap-name` ridotto rispetto a baseline (riportare valori esatti) |
| T-17 | Dopo T-2 (timeout): verificare tempo effettivo di ritorno. | Il comando ritorna entro SIM_UI_JXA_TIMEOUT + 3s (margine per KILL + cleanup), non resta bloccato |

#### Sequenza realistica (pattern TASK-008)
| # | Verifica | Esito atteso |
|---|----------|--------------|
| T-18 | Batch con sequenza mista: `tap-name <element>`, `wait-for <element> 5`, `replace-field 0.5 0.35 "valore1"`, `replace-field 0.5 0.45 "valore2"`, `tap-name <element>`, `wait-for <element> 5`. Misurare tempo totale (media di 3 run) e confrontare con equivalente 6 invocazioni singole. | Batch significativamente più veloce; riportare entrambi i tempi medi e il rapporto |

#### Cleanup su interruzione (SIGTERM e SIGINT)
| # | Verifica | Esito atteso |
|---|----------|--------------|
| T-19 | Lanciare `./tools/sim_ui.sh wait-for "ElementoInesistente" 30 &`, poi `kill $!` (SIGTERM) dopo 2s, poi `ps -axo pid,command \| grep 'osascript -l JavaScript' \| grep -v grep` | Zero righe — il trap ha killato il child osascript |
| T-19b | Lanciare `./tools/sim_ui.sh wait-for "ElementoInesistente" 30 &`, poi `kill -INT $!` (SIGINT) dopo 2s. Verificare: **(a)** `ps` non mostra processi `osascript` orfani; **(b)** sentinel `/tmp/sim_ui_timeout.$$` non esiste; **(c)** stderr contiene `processo interrotto (signal)` e **non** contiene `JXA timeout`. | Cleanup completo, diagnostica corretta, nessun orfano, nessun sentinel residuo |

#### Timeout provenance (CA-1b, D-11)
| # | Verifica | Esito atteso |
|---|----------|--------------|
| T-20 | Lanciare `./tools/sim_ui.sh wait-for "ElementoInesistente" 30 &`, poi `kill $!` dopo 2s (prima che scada il timeout di 30s). Catturare stderr. | Exit 1, messaggio su stderr contiene `processo interrotto (signal)` e **non** contiene `JXA timeout`. Il sentinel `/tmp/sim_ui_timeout.$$` non esiste dopo il test. |
| T-20b | `SIM_UI_JXA_TIMEOUT=3 ./tools/sim_ui.sh wait-for "ElementoInesistente" 30`. Catturare stderr. | Exit 1, messaggio su stderr contiene `JXA timeout dopo 3s` (confermato dal sentinel). |

#### Validazione argomenti (CA-20, D-13)
| # | Verifica | Esito atteso |
|---|----------|--------------|
| T-21 | Batch con arity errata: `tap-relative 0.5` (manca un argomento) | Exit 1, messaggio su stderr con numero riga e indicazione dell'arity attesa, nessun lancio di osascript |
| T-22 | Batch con arity errata: `replace-field 0.5 0.5` (manca il valore) | Exit 1, messaggio su stderr con numero riga |
| T-23 | `replace-field 0.5 0.5` (singolo, non batch) — arity errata | Exit 1, messaggio su stderr coerente con CA-19 |

#### Batch grande — fallback temp file (CA-21, D-15)
| # | Verifica | Esito atteso |
|---|----------|--------------|
| T-24 | Generare dinamicamente un batch il cui JSON serializzato superi **sicuramente** 120000 byte (es. righe `type` con payload lungo ripetute, o calcolare il numero di righe necessarie dal peso unitario). **Prima** di eseguire il batch, verificare con un check esplicito che il dispatcher è entrato nel ramo `BATCH_ACTIONS_FILE` (es. controllando che il temp file `/tmp/sim_ui_batch.$$.json` venga creato durante l'esecuzione, oppure aggiungendo un log diagnostico temporaneo, oppure verificando che `BATCH_ACTIONS` NON sia stata settata nell'environment del child `osascript`). Eseguire il batch. Verificare: **(a)** il batch viene eseguito senza errore; **(b)** il temp file `/tmp/sim_ui_batch.$$.json` non esiste dopo il completamento (cleanup avvenuto); **(c)** exit 0 o exit 1 coerente (le azioni possono fallire se il Simulator non è nella schermata giusta — l'importante è che il fallback temp file sia stato usato e il cleanup sia avvenuto). | Fallback temp file **effettivamente usato** (non solo "batch grande"), cleanup corretto |

#### Capture multipli nel batch (CA-18)
| # | Verifica | Esito atteso |
|---|----------|--------------|
| T-25 | Batch con due capture e azioni JXA tra di esse: `tap-relative 0.5 0.5`, `capture /tmp/cap1.png`, `wait 0.5`, `tap-relative 0.5 0.3`, `capture /tmp/cap2.png`. | Exit 0, entrambi i file `/tmp/cap1.png` e `/tmp/cap2.png` esistono. Verificare coerenza con CA-18: **(a)** ordine preservato — `cap1.png` cattura lo stato dopo il primo tap, `cap2.png` dopo il secondo; **(b)** nessun re-bootstrap JXA tra due azioni NON-`capture` consecutive (es. tra `wait 0.5` e `tap-relative 0.5 0.3`). **Nota**: un re-bootstrap tra un'azione JXA e una `capture` adiacente è accettabile (boundary shell — vedi D-9), purché le proprietà (a)-(d) di CA-18 siano rispettate. |
| T-25b | Batch con capture fallita al mezzo: `tap-relative 0.5 0.5`, `capture /nonexistent/path/fail.png`, `tap-relative 0.5 0.3`, `capture /tmp/should_not_exist.png`. | Exit 1, messaggio `BATCH FAIL at line 2: capture`, le righe successive non eseguite (stop-on-failure), `/tmp/should_not_exist.png` non esiste |

#### Line numbering fisico (CA-5, CA-7)
| # | Verifica | Esito atteso |
|---|----------|--------------|
| T-26 | Batch con righe miste: riga 1 = `tap-relative 0.5 0.5`, riga 2 = `` (vuota), riga 3 = `# commento`, riga 4 = `wait 0.5`, riga 5 = `invalid-cmd foo`. Catturare stderr. | Exit 1, messaggio contiene **`line 5`** (riga fisica nello stdin, contando vuote e commenti), **non** `line 3` (indice delle sole azioni valide). Questo verifica che il dispatcher conti le righe fisiche come da CA-5. |

### 7) Handoff → Execution

- **Prossima fase**: EXECUTION (in corso)
- **Esecutore**: CLAUDE (user override — execution diretta, senza passaggio a Codex)
- **Piano di implementazione**:

**Ordine di implementazione**:
1. Leggere integralmente `tools/sim_ui.sh` (già noto da TASK-012 — confermare comprensione)
2. **Misurazioni preliminari obbligatorie** (prima di implementare):
   - Misurare costo `proc.frontmost()` (per CA-15 / R-5) — se >0.3s, aggiornare CA-15 nel task
   - Misurare costo ricorsione `uiElements()` a profondità 4 vs `entireContents()` (per CA-13 / R-1) — se guadagno <30%, aggiornare CA-13/CA-14 nel task
3. Implementare trap cleanup su INT/TERM/EXIT (D-10) — CA-3
4. Implementare timeout esterno (`run_jxa_with_timeout`) con cleanup post-kill — CA-1, CA-2, CA-3
5. Implementare skip attivazione ridondante in `activateSimulator()` — CA-15 (se confermata da misurazione)
6. Implementare subcomando `replace-field` — CA-11, CA-12
7. Implementare ricerca AX mirata in `findElementByName` con strategia di polling wait-for — CA-13, CA-14, CA-14b (se confermata da misurazione)
8. Implementare subcomando `batch` con cache frame e parsing shell-side via python3/shlex (D-8) — CA-4..CA-10, CA-18
9. Eseguire T-1..T-26
10. Aggiornare adapter (`tools/sim-ui-guide-codex.md`, `.claude/commands/sim-ui.md`) con nuovi subcomandi e tutti gli esempi obbligatori (sezione 3g)
11. Compilare handoff post-execution conforme al protocollo `docs/CODEX-EXECUTION-PROTOCOL.md`

**Cosa dovrà verificare Claude in review**:
- CA-1..CA-21 contro il codice
- Che la non-regressione V-1..V-19 sia stata verificata (T-1)
- Che il batch mode gestisca correttamente stop-on-failure (T-5) e linee invalide (T-8)
- Che il timeout esterno funzioni davvero (T-2) e non lasci orfani (T-3)
- **Che il timeout provenance funzioni**: T-20 (kill esterno → "processo interrotto", no "timeout") e T-20b (timeout reale → "JXA timeout") — CA-1b, D-11
- Che il trap cleanup funzioni su interruzione esterna con **sia SIGTERM (T-19) che SIGINT (T-19b)** e rimuova sentinel e temp file — D-11, CA-21
- Che il parsing usi python3/shlex e NON usi `eval` (D-8)
- Che il parsing gestisca correttamente spazi, virgolette e accenti (T-10..T-14)
- **Che la diagnostica JXA usi `stderrPrint()` via ObjC bridge** (non `console.log`): verificare che il codice definisca l'helper e lo usi per tutti i messaggi diagnostici — CA-19, D-14
- **Che la validazione arity funzioni shell-side nel batch**: T-21, T-22, T-23 — CA-20, D-13
- **Che il fallback temp file funzioni per batch grandi**: T-24 — CA-21, D-15
- **Che capture multipli nello stesso batch funzionino**: T-25 (ordine preservato, entrambi i file, nessun re-bootstrap tra azioni non-capture), T-25b (stop-on-failure a metà) — CA-18
- **Che il line numbering nel batch sia fisico** (conta righe vuote e commenti): T-26 — CA-5, CA-7
- Che `wait-for` usi il fast-path per ogni poll e limiti il fallback `entireContents()` (CA-14b)
- Che `capture` nel batch preservi ordine, stop-on-failure e sessione unica tra azioni non-capture (CA-18)
- Che la cache deviceFrame documenti l'invariante di invalidazione (CA-9)
- Misure effettive di performance con valori numerici (T-15, T-16, T-18)
- Che gli adapter contengano tutti gli esempi obbligatori (sezione 3g)
- Che le misurazioni preliminari (R-1, R-5) siano documentate nell'handoff

---

## Execution (Codex)
### Riallineamento execution

- Execution avviata da Claude Code e ripresa da Codex il 2026-03-22 su richiesta utente.
- Tracking riallineato in modo minimo: task resta `ACTIVE`, fase resta `EXECUTION`, responsabile attuale `CODEX`.
- Il task non viene portato a `REVIEW` in questo handoff: evidenza ancora incompleta su non-regressione completa e su alcuni test/casi batch residui.

### File e simboli toccati

| File | Azione | Simboli toccati |
|------|--------|-----------------|
| `tools/sim_ui.sh` | Modificato | `_validate_arg_count()`, `_is_number()`, `_require_numeric_arg()`, `_validate_batch_numeric_args()`, `_run_capture_stdout()`, `_on_signal()`, `run_jxa()`, `stdoutPrint()`, `stderrPrint()`, cache `simulatorProcessCache/simulatorWindowCache/deviceFrameCache`, handler `batch`, handler `capture` |
| `tools/sim-ui-guide-codex.md` | Modificato | Tabella subcomandi, sezione batch, esempi heredoc, nota `SIM_UI_JXA_TIMEOUT`, note su `capture` nel batch |
| `.claude/commands/sim-ui.md` | Modificato | Tabella subcomandi, esempi `batch`/`replace-field`, config timeout, note `capture` nel batch |
| `docs/TASKS/TASK-013-sim-ui-performance.md` | Modificato | Metadata execution, sezione Execution |
| `docs/MASTER-PLAN.md` | Modificato | Responsabile attuale, ultimo aggiornamento, nota Claude Code -> Codex |

### Misurazioni preliminari usate come base

- `proc.frontmost()`: misurazione preliminare ereditata da Claude Code, circa 5 run: cold start ~0.26s, warm ~0.12s. Esito: CA-15 mantenuto.
- Fast-path AX: misurazione preliminare ereditata da Claude Code. `uiElements()` depth <=4 e depth <=8 non raggiungono gli elementi iOS del Simulator; `entireContents()` resta l'unico metodo affidabile. Esito: CA-13/CA-14/CA-14b gia' aggiornati nel task, nessun fast-path integrato.

### Modifiche implementate

- Ripulito il dispatcher shell per evitare abort prematuri dovuti a `set -e` nei rami `run_jxa` e `batch`.
- Separati i canali dati/diagnostica nel JXA: `stdoutPrint()` per output consumabile (`FOUND`, `NOT_FOUND`, `ROLE<TAB>NAME`), `stderrPrint()` via ObjC bridge per errori e batch fail.
- Aggiunta validazione arity e validazione numerica coerente tra subcomandi singoli e batch (`wait`, `wait-for`, `tap-relative`, `tap-name`, `replace-field`).
- Migliorato il trap su INT/TERM: ora emette `[sim_ui] ERROR: processo interrotto (signal)` e pulisce child/watchdog/sentinel/temp file.
- Introdotte cache di sessione JXA per process/window/device frame; il batch riusa la stessa sessione e il frame cached per `tap-relative` e `replace-field`.
- Rafforzato `capture` singolo e `capture` nel batch con post-condizione "file creato davvero"; se `simctl screenshot` ritorna `0` ma il file non esiste, il wrapper fallisce.
- Aggiornata la documentazione operativa per `batch`, `replace-field`, heredoc, timeout watchdog e `capture` in batch.

### Build

- N/A — nessun file Swift / Xcode modificato in TASK-013.

### CA -> evidenza

| CA | Tipo verifica | Esito | Evidenza / nota |
|----|---------------|-------|-----------------|
| CA-1 | SIM | PASS | T-2: `SIM_UI_JXA_TIMEOUT=2 wait-for` termina in 2.37s con watchdog attivo |
| CA-1b | SIM | PASS | T-19b/T-20/T-20b: distinguiti kill esterno vs timeout reale tramite sentinel assente/presente e messaggi corretti |
| CA-2 | SIM | PASS | T-2 e T-20b: `SIM_UI_JXA_TIMEOUT` a 2s/3s rispettato |
| CA-3 | SIM | PASS | T-3/T-19/T-19b: nessun `osascript` orfano dopo timeout o segnale |
| CA-4 | SIM | PASS | T-4/T-6/T-7/T-8/T-26: `batch` operativo su stdin |
| CA-5 | SIM | PASS | T-8/T-21/T-22/T-26: parser shell-side, numero riga fisico corretto, no `eval` introdotto |
| CA-6 | STATIC | PASS | Cache JXA per process/window/frame introdotte; batch non rilancia `osascript` per ogni azione |
| CA-7 | SIM | PASS | T-5: batch si ferma su `wait-for` fallita con `BATCH FAIL at line 2`, screenshot successivo non creato |
| CA-8 | SIM | PASS | T-4/T-5/T-25: supportati `tap-relative`, `wait-for`, `wait`, `capture`; `replace-field` presente nel dispatcher |
| CA-9 | STATIC+SIM | PASS | Cache `deviceFrame` in codice + T-4/T-25 su batch con tap/capture |
| CA-10 | SIM | NOT RUN | Non-regressione completa dei subcomandi singoli non ancora chiusa; evidenza parziale positiva su V-1/V-4/V-5/V-7/V-8/V-17/V-19 |
| CA-11 | STATIC | PASS | `replace-field` esiste come subcomando singolo e nel batch |
| CA-12 | SIM | NOT RUN | Nessun campo testo stabile preparato in questo turno per verificare semanticamente tap+clear+type end-to-end |
| CA-13 | STATIC | PASS | CA gia' aggiornato nel task in execution sulla base delle misurazioni preliminari Claude Code |
| CA-14 | STATIC | PASS | `findElementByName()` continua a usare `entireContents()` come unico path |
| CA-14b | STATIC | PASS | Nessun fast-path introdotto; polling `wait-for` resta su `entireContents()` |
| CA-15 | STATIC | PASS | Misurazione preliminare importata: `proc.frontmost()` ~0.26s cold / ~0.12s warm, quindi check sostenibile |
| CA-18 | SIM | NOT RUN | T-25 successo verificato; T-25b non rieseguito dopo l'ultimo fix per user override |
| CA-19 | STATIC+SIM | PASS | Prefisso `[sim_ui]` uniforme; diagnostica JXA via ObjC bridge; T-2/T-5/T-19/T-20 confermano i messaggi |
| CA-20 | STATIC+SIM | PASS | T-21/T-22/T-23 + validazioni shell-side/numeriche aggiunte |
| CA-21 | STATIC+SIM | PASS | T-24: xtrace conferma `_bn_json_len=145252`, ramo `BATCH_ACTIONS_FILE` preso e cleanup finale eseguito |
| CA-16 | SIM | NOT RUN | Tutti i subcomandi esistenti non sono stati rieseguiti in modo completo su una stessa schermata stabile |
| CA-17 | SIM | NOT RUN | Suite V-1..V-19 di TASK-012 rieseguita solo parzialmente |

### T -> esito

| T | Stato | Tipo | Nota |
|---|-------|------|------|
| T-1 | NOT RUN | SIM | Suite completa V-1..V-19 non rieseguita end-to-end; evidenza solo parziale |
| T-2 | PASS | SIM | `SIM_UI_JXA_TIMEOUT=2 wait-for "ElementoInesistente" 30` -> RC 1, elapsed 2.37s, stdout `NOT_FOUND`, stderr timeout 2s |
| T-3 | PASS | SIM | Dopo T-2: `ps` non mostra processi `osascript -l JavaScript` |
| T-4 | PASS | SIM | Batch semplice -> RC 0, screenshot creato: `/tmp/t4_batch_test.png` |
| T-5 | PASS | SIM | Dopo reset app alla home: batch -> RC 1, stderr `[sim_ui] BATCH FAIL at line 2: wait-for — Elemento 'Inesistente' non trovato entro 2s`, file `/tmp/t5_should_not_exist_home.png` assente |
| T-6 | PASS | SIM | `./tools/sim_ui.sh batch < /dev/null` -> RC 0 |
| T-7 | PASS | SIM | Batch con riga vuota/commento/wait -> RC 0 |
| T-8 | PASS | SIM | `invalid-cmd foo` -> RC 1, numero riga corretto |
| T-9 | NOT RUN | SIM | Nessun campo editabile stabile preparato per verificare `replace-field` end-to-end |
| T-10 | PASS | SIM | `tap-name "Aggiungi riga"` -> RC 1 ma nessun errore di parsing |
| T-11 | NOT RUN | SIM | Nessun campo focalizzato affidabile per verificare il testo digitato |
| T-12 | NOT RUN | SIM | Batch con argomenti contenenti spazi eseguito ma esito dominato dal watchdog AX a 30s; parsing non isolato con confidenza sufficiente |
| T-13 | NOT RUN | SIM | Nessun campo focalizzato affidabile per verificare caratteri accentati |
| T-14 | NOT RUN | SIM | Nessun campo editabile stabile preparato per verificare `replace-field` con spazi |
| T-15 | NOT RUN | SIM | Misura 3x5 singoli vs 3x batch avviata ma non chiusa in tempo utile; costo attuale del path singolo resta troppo alto |
| T-16 | FAIL | SIM | 3 run `tap-name "Inventario"` con app riportata alla home: 30.28s PASS, poi 30.29s/32.31s FAIL (`Elemento 'Inventario' non trovato`) |
| T-17 | PASS | SIM | T-2 ritorna entro timeout+3s (2.37s con timeout 2s) |
| T-18 | NOT RUN | SIM | Sequenza realistica con campi multipli non predisposta in modo deterministico in questo turno |
| T-19 | PASS | SIM | SIGTERM esterno -> RC 1, sentinel assente, stderr `processo interrotto (signal)`, zero orfani |
| T-19b | PASS | SIM | SIGINT esterno -> RC 1, sentinel assente, stderr `processo interrotto (signal)`, zero orfani |
| T-20 | PASS | SIM | Kill esterno prima del timeout -> nessun `JXA timeout`, sentinel assente |
| T-20b | PASS | SIM | `SIM_UI_JXA_TIMEOUT=3 wait-for ...` -> RC 1, elapsed 3.35s, stderr `JXA timeout dopo 3s` |
| T-21 | PASS | SIM | Batch `tap-relative 0.5` -> RC 1, arity shell-side corretta |
| T-22 | PASS | SIM | Batch `replace-field 0.5 0.5` -> RC 1, arity shell-side corretta |
| T-23 | PASS | SIM | Singolo `replace-field 0.5 0.5` -> RC 1, messaggio coerente |
| T-24 | PASS | STATIC+SIM | xtrace del dispatcher: `_bn_json_len=145252`, `_BATCH_TMPFILE=/tmp/sim_ui_batch.65928.json`, `export BATCH_ACTIONS_FILE=...`, cleanup finale eseguito |
| T-25 | PASS | SIM | Batch con due capture -> RC 0, `/tmp/t25_cap1.png` e `/tmp/t25_cap2.png` esistono |
| T-25b | NOT RUN | SIM | Test corrente saltato per user override dopo evidenza parziale; prima del fix invalid-path non produceva failure su `simctl`, poi wrapper irrigidito ma nessun rerun eseguito |
| T-26 | PASS | SIM | Batch con righe miste -> RC 1, messaggio con `line 5` |

### Check obbligatori

- `⚠️ NON ESEGUIBILE` — Build compila: nessun file Swift / Xcode modificato in questo task.
- `⚠️ NON ESEGUIBILE` — Nessun warning nuovo introdotto: nessun build eseguito, task limitato a script/docs/tracking.
- `✅ ESEGUITO` — Modifiche coerenti con il planning: scope limitato a `tools/sim_ui.sh`, adapter docs e tracking di TASK-013.
- `❌ NON ESEGUITO` — Criteri di accettazione verificati completamente: restano aperti CA-10/CA-12/CA-16/CA-17/CA-18.

### Conferma scope

Conferma scope: non ho modificato file o comportamenti fuori dal perimetro del task.

### Limiti residui

- `T-25b` non e' stato rieseguito dopo l'ultimo fix per user override; resta aperta la verifica esplicita del capture-failure path nel batch.
- `T-15`, `T-16`, `T-18` non sono chiusi in modo soddisfacente: la schermata corrente influenza ancora molto i tempi AX e la stabilita' di `tap-name`.
- La non-regressione completa `V-1..V-19` di TASK-012 non e' stata rieseguita integralmente.
- `wait-for` e `dump-names` restano fortemente dipendenti dallo stato UI: sulla home dell'app `wait-for "Inesistente" 2` puo' chiudersi logicamente; su altri stati l'outer watchdog da 30s interviene ancora.
- Follow-up candidate: misurazione performance stabile con schermata controllata dedicata; oggi i numeri oscillano troppo per una chiusura pulita di T-15/T-16/T-18.

### Stato finale di questo turno

- Prossima fase: `EXECUTION`
- Prossimo agente: `CODEX`
- Stato task: `ACTIVE`
- Motivo del non passaggio a REVIEW: evidenza ancora incompleta su non-regressione completa e capture-failure path nel batch.

---

## Review (Claude)

[da compilare]

---

## Fix (Codex)

[da compilare]

---

## Chiusura

### Conferma utente
- [ ] Utente ha confermato il completamento

### Follow-up candidate
[da compilare]

### Riepilogo finale
[da compilare]

### Data completamento
[da compilare]
