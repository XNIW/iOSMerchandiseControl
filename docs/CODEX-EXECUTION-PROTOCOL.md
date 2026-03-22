# Codex Execution Protocol

Protocollo universale per execution, self-test e handoff nei task eseguiti da Codex.
Si applica a **tutti** i task che toccano UI, navigazione, o comportamento visibile nel Simulator.

## 1. Quando si applica

### Task con obbligo di self-test Simulator

Codex **deve** eseguire self-test nel Simulator quando il task soddisfa **almeno una** di queste condizioni:

- Modifica o aggiunge una View SwiftUI visibile all'utente
- Modifica navigazione, presentazione sheet/alert/popover, o transizioni tra schermate
- Modifica logica che impatta direttamente l'output visivo (formattazione, ordinamento lista, stato bottone)
- I criteri di accettazione o i test case del task includono verifiche UI/interattive (es. T-NN)

### Task esenti da self-test Simulator

- Modifiche solo a logica backend/model/data senza effetti visivi diretti
- Modifiche a file di configurazione, documentazione, script di build
- Refactor interni che non cambiano comportamento osservabile

In caso di dubbio: **eseguire il self-test**. Se l'ambiente Simulator non è disponibile, documentare come BLOCKED (non come PASS).

## 2. Tipi di verifica

Ogni evidenza prodotta da Codex deve dichiarare esplicitamente il proprio tipo.

| Tipo | Codice | Definizione | Cosa conta come "eseguito" |
|------|--------|-------------|---------------------------|
| **Statica** | `STATIC` | Analisi del codice sorgente senza esecuzione | Lettura del file, verifica di pattern, assenza di riferimenti vietati |
| **Build** | `BUILD` | Compilazione del progetto | Comando build eseguito con output (successo o errore) riportato letteralmente |
| **Simulator** | `SIM` | Verifica interattiva nel Simulator iOS tramite `tools/sim_ui.sh` | Wrapper invocato, exit code riportato, screenshot catturato se rilevante |
| **Manuale** | `MANUAL` | Verifica che richiede giudizio umano o interazione non automatizzabile | Codex dichiara `NOT RUN [MANUAL]` — solo l'utente o Claude possono eseguirla |

### Regola fondamentale: eseguito ≠ inferito

- **Eseguito**: il comando è stato lanciato, l'output è stato osservato, l'esito è riportato
- **Inferito**: l'esito è dedotto dalla lettura del codice senza esecuzione
- Codex **non può** riportare una verifica `BUILD` o `SIM` come PASS se non ha effettivamente eseguito il comando
- Se il tipo è `STATIC`, la verifica è per definizione inferita — va dichiarata come tale
- Una verifica `STATIC` **non può sostituire** una verifica `SIM` richiesta dai criteri

## 3. Formato standard risultati test

### Stati possibili

| Stato | Significato | Quando usare |
|-------|-------------|--------------|
| `PASS` | Verifica superata | Il comando/check ha prodotto il risultato atteso |
| `FAIL` | Verifica fallita | Il comando/check ha prodotto un risultato diverso da quello atteso |
| `NOT RUN` | Non eseguito | L'ambiente non era disponibile, oppure la verifica è di tipo `MANUAL` |
| `BLOCKED` | Bloccato da fattore esterno | Permission dialog, Simulator crash, focus loss, prerequisito mancante |

### Regole per NOT RUN e BLOCKED

- Ogni `NOT RUN` richiede **motivazione precisa** (non "non eseguibile" generico)
- Ogni `BLOCKED` richiede: **causa** + **cosa è stato tentato** + **cosa serve per sbloccare**
- `NOT RUN` e `BLOCKED` non equivalgono a PASS — non possono essere usati per dichiarare un criterio soddisfatto
- Un task con test `SIM` tutti `NOT RUN` o `BLOCKED` **non può passare a REVIEW** — resta in EXECUTION con blocco documentato

### Template per test case

```
T-NN: STATO [TIPO] — nota
```

Esempi:
```
T-01: PASS  [SIM]    — tap su "Conferma" → sheet chiuso, riga visibile in lista
T-02: FAIL  [SIM]    — tap su "Annulla" → sheet non si chiude (exit 1 da wait-for)
T-03: NOT RUN [SIM]  — Simulator non booted, nessun device disponibile
T-04: BLOCKED [SIM]  — permission dialog Accessibility blocca osascript; tentato grant manuale, persiste
T-05: PASS  [STATIC] — nessun riferimento a schermate specifiche nel wrapper (grep confermato)
T-06: NOT RUN [MANUAL] — richiede giudizio umano su layout visivo
```

## 4. Mappatura obbligatoria

### 4a. Acceptance Criteria → Evidenza

Per **ogni** criterio di accettazione del task, Codex deve produrre una riga:

```
| CA-N | Tipo verifica | Esito | Evidenza / nota |
```

Esempio:
```
| CA-1 | BUILD  | PASS | `xcodebuild -scheme iOSMerchandiseControl` exit 0, nessun warning nuovo |
| CA-2 | SIM    | PASS | `./tools/sim_ui.sh tap-name "Conferma"` exit 0, screenshot: /tmp/ca2.png |
| CA-3 | STATIC | PASS | Grep confermato: nessun riferimento a ManualEntrySheet in sim_ui.sh |
| CA-4 | SIM    | BLOCKED | Permission dialog Accessibility — causa: primo run dopo reboot |
```

Regole:
- Nessun CA può restare senza riga
- Se un CA richiede verifica `SIM` ma Codex riporta solo `STATIC` → inadeguato, Claude lo segnalerà in review
- Se un CA è `BLOCKED` o `NOT RUN` → il task non è considerato completato per quel criterio

### 4b. Test Cases → Esito

Per **ogni** test case definito nel task (T-NN), Codex deve produrre una riga:

```
| T-NN | Stato | Tipo | Nota |
```

Regole:
- Nessun T-NN può restare senza riga
- Se tutti i T-NN di tipo `SIM` sono `NOT RUN` → il task **non avanza a REVIEW**

## 5. Evidenze minime richieste nell'handoff

Codex **deve** compilare tutte queste sezioni prima di restituire il controllo a Claude:

### 5a. File e simboli toccati

Tabella con ogni file modificato/creato e i simboli (funzioni, struct, enum, variabili) aggiunti o modificati:

```
| File | Azione | Simboli toccati |
|------|--------|-----------------|
| GeneratedView.swift | Modificato | ManualEntrySheet, addRowAction(), validateBarcode() |
| tools/sim_ui.sh | Creato | (intero file) |
```

### 5b. Comando build eseguito

Copia **letterale** del comando e dell'esito:

```
Comando: xcodebuild -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16' build
Esito: BUILD SUCCEEDED (exit 0)
Warning nuovi: nessuno
```

Se il build non è stato eseguito (es. nessun file Swift modificato): dichiarare esplicitamente `N/A — nessun file Swift modificato in questo task`.

### 5c. Tabella CA → evidenza

(Formato sezione 4a)

### 5d. Tabella T-NN → esito

(Formato sezione 4b)

### 5e. Conferma scope

Dichiarazione esplicita obbligatoria:

```
Conferma scope: non ho modificato file o comportamenti fuori dal perimetro del task.
```

Oppure, se ci sono state deviazioni:

```
Deviazioni dallo scope:
- [file]: [motivazione] — [era necessario per CA-N / è un fix collaterale / richiede review]
```

### 5f. Rischi rimasti

Qualsiasi rischio, limitazione, o follow-up candidate emerso durante l'execution.

### 5g. Handoff

```
- Prossima fase: REVIEW
- Prossimo agente: CLAUDE
- Azione consigliata: [cosa deve verificare Claude prioritariamente]
```

## 6. Regole per blocchi e interruzioni

### Cause di blocco riconosciute

| Causa | Codice | Azione richiesta |
|-------|--------|-----------------|
| Permission dialog (Accessibility, Screen Recording) | `PERM` | Documentare, tentare grant, se persiste → BLOCKED |
| Focus loss (Simulator perde foreground) | `FOCUS` | Retry con `show` + `wait 1`, se persiste → BLOCKED |
| AX tree non disponibile | `AX` | `dump-names` come smoke test, se 0 righe → BLOCKED |
| Simulator crash / non booted | `SIM_ENV` | Verificare con `xcrun simctl list devices booted`, se vuoto → BLOCKED |
| Timeout su wait-for | `TIMEOUT` | Riportare elemento atteso e timeout usato, screenshot post-timeout |
| Prerequisito mancante (app non installata, dati non presenti) | `PREREQ` | Documentare cosa manca e come riprodurlo |

### Regola stop-on-failure

Se `wait-for` ritorna exit 1 (NOT_FOUND) o exit 2 (AX non disponibile):

1. **Non continuare** il test corrente
2. Catturare screenshot: `./tools/sim_ui.sh capture /tmp/debug_T-NN.png`
3. Eseguire `./tools/sim_ui.sh dump-names` per documentare lo stato AX
4. Riportare il test come `FAIL` o `BLOCKED` con causa e artefatti
5. Proseguire al test successivo **solo se indipendente** dal test fallito

### Fallback per automazione bloccata

Se l'intero ambiente Simulator è inutilizzabile (nessun device booted, permessi non concedibili, Simulator non installato):

1. Eseguire tutte le verifiche `STATIC` e `BUILD` possibili
2. Marcare tutti i test `SIM` come `NOT RUN [SIM_ENV] — [causa]`
3. **Non avanzare a REVIEW** — il task resta in EXECUTION con stato BLOCKED
4. Documentare nel handoff cosa serve per sbloccare
5. Se il blocco persiste, Codex può proporre il passaggio a BLOCKED nel task tracking

## 7. Convenzioni per artefatti diagnostici

### Screenshot

- **Quando catturare**: dopo ogni test `SIM` significativo (PASS o FAIL), e sempre dopo un FAIL/BLOCKED
- **Comando**: `./tools/sim_ui.sh capture <path>`
- **Naming**: `/tmp/sim_T-NN_<descrizione>.png` (es. `/tmp/sim_T-03_after_confirm.png`)
- **Referenza**: citare il path nella colonna "Nota" della tabella test
- **Regola**: uno screenshot **non è** un'asserzione di successo — è diagnostica. Un test è PASS solo se il `wait-for` o la verifica logica lo confermano

### Log e stderr

- Se un comando fallisce, riportare il messaggio stderr letterale (prefisso `[sim_ui]`)
- Non parafrasare l'errore — copia esatta

### Video

- Opzionale, non richiesto dal protocollo standard
- Utile per: animazioni, transizioni, timing issues
- Se usato: `xcrun simctl io booted recordVideo <path>`, riportare path nell'handoff

## 8. Transizione EXECUTION → REVIEW: gate di uscita

Un task **può passare a REVIEW** solo se tutte queste condizioni sono soddisfatte:

1. La tabella CA → evidenza è **completa** (nessun CA senza riga)
2. La tabella T-NN → esito è **completa** (nessun T-NN senza riga)
3. Nessun test `SIM` obbligatorio è `NOT RUN` senza causa ambientale documentata
4. Il build è PASS (o N/A se nessun file compilabile modificato)
5. La conferma scope è presente
6. L'handoff è compilato

Se anche **una sola** condizione non è soddisfatta, il task **non avanza**:
- Se il blocco è ambientale (Simulator non disponibile) → task resta EXECUTION con stato BLOCKED
- Se il blocco è logico (test fallisce per bug nel codice) → Codex deve correggere prima di dichiarare handoff
- Se il blocco è di scope (serve modifica fuori perimetro) → documentare e chiedere indicazioni a Claude

## 9. Come Claude usa l'evidenza in review

Questa sezione è informativa per Codex — descrive cosa Claude verificherà.

1. **Completezza**: ogni CA e T-NN ha una riga? Nessuno è stato saltato?
2. **Coerenza tipo**: i CA che richiedono `SIM` sono stati verificati con `SIM`? (non solo `STATIC`)
3. **Qualità evidenza**: gli esiti riportati sono plausibili? I comandi citati corrispondono al wrapper?
4. **Stop-on-failure rispettato**: dopo un FAIL, Codex ha continuato test dipendenti? (non dovrebbe)
5. **Scope**: la conferma scope è presente? Ci sono file toccati non nel piano?
6. **Artefatti**: gli screenshot citati esistono e sono coerenti con gli esiti?
7. **NOT RUN / BLOCKED giustificati**: le motivazioni sono precise e verificabili?

Se l'evidenza è incompleta o incoerente, Claude emetterà `CHANGES_REQUIRED` anche se il codice è corretto — il protocollo di consegna è parte del contratto.

## 10. Regole di integrità

1. **Eseguito ≠ inferito**: mai riportare un test `SIM` come PASS senza aver eseguito il comando
2. **Non inventare esiti**: se il test non è stato eseguito, è `NOT RUN`, non `PASS`
3. **Non mascherare NOT RUN come PASS**: Claude lo tratterà come violazione del protocollo
4. **Non procedere dopo BLOCKED senza documentare**: ogni blocco richiede causa, tentativo, e richiesta di sblocco
5. **Non omettere CA o T-NN dalla tabella**: l'assenza è trattata come `NOT RUN` non giustificato
6. **Screenshot è diagnostica, non asserzione**: "ho fatto screenshot" non equivale a "il test è passato"
7. **Il protocollo è parte del contratto**: un handoff incompleto viene rifiutato in review indipendentemente dalla qualità del codice
