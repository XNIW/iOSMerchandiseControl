# TASK-036: Import HTML advanced table parsing — colspan/rowspan/multi-table hardening

## Informazioni generali
- **Task ID**: TASK-036
- **Titolo**: Import HTML advanced table parsing: colspan/rowspan/multi-table hardening
- **File task**: `docs/TASKS/TASK-036-import-recognition-advanced-html-colspan-rowspan-multi-table.md`
- **Stato**: DONE
- **Fase attuale**: Chiusura
- **Responsabile attuale**: —
- **Data creazione**: 2026-04-27
- **Ultimo aggiornamento**: 2026-04-27
- **Ultimo agente che ha operato**: Claude Code reviewer/fixer

## Nota tracking
- User override 2026-04-27: l'utente ha richiesto `TASK-032` come nuovo follow-up, ma `TASK-032` esiste gia' nel repo per un task GeneratedView. Per preservare coerenza ID/path del MASTER-PLAN, questo follow-up usa il task gia' presente e coerente `TASK-036`, senza riaprire o modificare `TASK-031`.

## Dipendenze
- **Dipende da**: TASK-031
- **Sblocca**: import HTML piu' robusto per export Excel complessi

## Scopo
Hardening mirato del parsing HTML in `ExcelAnalyzer` per ridurre sfasamenti di colonne e scelta tabella errata su export Excel HTML complessi.

## Stato attuale
- TASK-031 ha gia' risolto canonical/snake/localized headers.
- Resta fuori perimetro TASK-031 il parsing HTML avanzato con celle merge o tabelle multiple.
- TASK-031 resta **DONE / Chiusura** e non viene riaperta.

## Scope
- Hardening mirato del parsing HTML in `ExcelAnalyzer`.
- Gestione conservativa di:
  - `colspan`
  - `rowspan`
  - HTML con piu' tabelle
  - righe titolo/decorative prima della tabella dati
- Mantenere il comportamento di TASK-031:
  - header canonici/alias gia' riconosciuti;
  - fallback `colN` quando non c'e' header reale;
  - override manuale sempre disponibile;
  - nessuna euristica aggressiva solo dai dati;
  - append compatibility preservata.

## Non incluso
- Supabase
- `RowDetailSheetView`
- `GeneratedView`
- redesign PreGenerate
- refactor generale dell'import
- nuovo test target se troppo largo
- modifiche UX salvo microcopy davvero necessaria
- copia Kotlin da Android; Android e' solo riferimento funzionale

## File ammessi
- `iOSMerchandiseControl/ExcelSessionViewModel.swift`, solo `ExcelAnalyzer` / HTML parsing
- `docs/fixtures/TASK-036/` con fixture minime
- `docs/MASTER-PLAN.md` per tracking
- questo file task

## Criteri di accettazione
*Chiusura **DONE** (2026-04-27): criteri soddisfatti dopo review tecnica e fix diretti mirati.*
- [x] TASK-031 non regredisce.
- [x] Header reali con `colspan`/`rowspan` restano allineati alle colonne dati.
- [x] In HTML con piu' tabelle viene scelta la tabella dati corretta.
- [x] Tabelle decorative non vengono trattate come dati.
- [x] File senza header reale restano `colN` / manual override.
- [x] Build passa.
- [x] Fixture documentate.

## Planning (Claude) ← solo Claude aggiorna questa sezione

*User override 2026-04-27: il planning operativo iniziale e' stato fornito direttamente dall'utente per avviare Execution senza riaprire TASK-031.*

### Strategia
1. Migliorare `rowsFromHTML` solo se necessario.
2. Scegliere la tabella dati con scoring conservativo:
   - presenza header canonici/alias;
   - numero righe dati compatibili;
   - densita' celle non vuote;
   - penalita' per tabelle piccole/decorative.
3. Supportare `colspan`/`rowspan` espandendo la griglia in modo rettangolare.
4. Mantenere fallback `colN` se non c'e' header reale.

### Fixture da creare in Execution
- `html-colspan-header.html`
- `html-rowspan-data.html`
- `html-multiple-tables.html`
- `html-title-rows-before-header.html`
- `html-negative-decorative-table-only.html`

### Handoff operativo verso Execution
- **Fase corrente**: Execution
- **Responsabile corrente**: Cursor/Codex executor
- **Motivo**: user override esplicito, nessun task attivo nel MASTER-PLAN, task follow-up gia' separato da TASK-031.
- **Vincoli**: nessun Supabase, nessun `RowDetailSheetView`, nessun redesign, nessun refactor generale, nessun nuovo test target se richiede setup largo.

---

## Execution (Codex) ← solo Codex aggiorna questa sezione

### Avvio Execution — 2026-04-27
- Obiettivo compreso: rendere piu' robusto il parsing HTML avanzato in `ExcelAnalyzer` preservando i comportamenti chiusi in TASK-031.
- File da modificare:
  - `docs/MASTER-PLAN.md`
  - `docs/TASKS/TASK-036-import-recognition-advanced-html-colspan-rowspan-multi-table.md`
  - `iOSMerchandiseControl/ExcelSessionViewModel.swift`
  - `docs/fixtures/TASK-036/`
- Piano minimo:
  1. promuovere il task follow-up coerente a `ACTIVE / Execution`;
  2. aggiornare solo il path HTML di `ExcelAnalyzer`;
  3. aggiungere fixture documentali minime;
  4. verificare con build, diff e controllo statico/manuale fixture;
  5. riportare a `REVIEW` con handoff a Claude.

### Execution completata — 2026-04-27

#### Modifiche fatte
- `ExcelAnalyzer.rowsFromHTML`: sostituita la lettura globale dei `tr` con parsing per singola `<table>` e scelta della tabella migliore tramite scoring conservativo.
- Aggiunta espansione rettangolare di `colspan` e `rowspan` nel parser HTML, con padding finale delle righe alla larghezza logica della tabella.
- Aggiunto scoring HTML basato su match canonici/alias gia' esistenti, righe dati compatibili, densita' celle non vuote, larghezza tabella e penalita' per tabelle piccole/decorative.
- Per HTML con sole tabelle decorative senza dati credibili, il parser restituisce nessuna tabella dati invece di promuovere mapping canonici dai valori decorativi.
- Create fixture documentali in `docs/fixtures/TASK-036/`:
  - `html-colspan-header.html`
  - `html-rowspan-data.html`
  - `html-multiple-tables.html`
  - `html-title-rows-before-header.html`
  - `html-negative-decorative-table-only.html`
  - `README.md`

#### Check eseguiti
- ✅ ESEGUITO — `git diff --stat`: eseguito. Nota: lo stat mostra anche modifiche preesistenti di TASK-031 gia' presenti nel worktree; i nuovi file non tracciati sono visibili con `git status --short`.
- ✅ ESEGUITO — `xcodebuild -list -project iOSMerchandiseControl.xcodeproj`: unico target/scheme `iOSMerchandiseControl`; nessun test target esistente.
- ✅ ESEGUITO — Build compila: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'generic/platform=iOS Simulator' build` → PASS (`** BUILD SUCCEEDED **`).
- ⚠️ NON ESEGUIBILE — Nessun warning nuovo introdotto: senza baseline non e' attribuibile storicamente. Il build log contiene il warning Xcode gia' noto `appintentsmetadataprocessor` / `No AppIntents.framework dependency found`; nessun warning Swift sul file modificato e nessun errore.
- ✅ ESEGUITO — Verifica statica/manuale fixture: `rg` su `docs/fixtures/TASK-036/` conferma copertura di `colspan`, `rowspan`, due `<table>`, header canonici/snake_case e caso decorativo-only.
- ✅ ESEGUITO — Modifiche coerenti con planning: scope limitato a `ExcelAnalyzer`/HTML parsing, tracking e fixture; nessun Supabase, nessun `RowDetailSheetView`, nessun `GeneratedView`, nessun redesign PreGenerate, nessuna nuova dipendenza.
- ✅ ESEGUITO — Criteri di accettazione verificati staticamente: header canonici/alias restano delegati alla mappa TASK-031; fallback senza header reale resta nel path `findDataHeaderRow`/`colN`; override manuale non modificato; append compatibility non toccata.

#### Rischi rimasti
- La verifica delle fixture e' statica/manuale per assenza di test target; non e' stato creato XCTest per non allargare il perimetro.
- Il parsing `rowspan` replica il valore nelle righe successive per preservare la griglia; se un export reale usa merge semantici piu' complessi, servira' una fixture reale aggiuntiva.
- La soglia `score > 0` evita decorative-only, ma file HTML estremamente minimali senza header e con pochissime righe potrebbero non essere importati come dati: scelta conservativa coerente con il task.
- `git status` mostra modifiche preesistenti di TASK-031 nel worktree; TASK-031 resta DONE e non e' stata riaperta in questo turno.

#### Handoff post-execution
- **Fase proposta**: REVIEW
- **Responsabile prossimo**: Claude reviewer
- **Focus review**: scoring tabella dati vs decorative-only, correttezza espansione `colspan`/`rowspan`, conservazione fallback `colN` e compatibilita' con i comportamenti TASK-031.

---

## Review (Claude) ← solo Claude aggiorna questa sezione
### Review + fix diretto — 2026-04-27

#### Cosa ho controllato
- Stato worktree e diff richiesti: `git status --short`, `git diff --stat`, diff `docs/MASTER-PLAN.md`, diff `iOSMerchandiseControl/ExcelSessionViewModel.swift`; il file `TASK-036` e le fixture sono nuovi/untracked e sono stati letti direttamente.
- `docs/fixtures/TASK-036/`: presenza file, README, fixture `html-colspan-header.html`, `html-rowspan-data.html`, `html-multiple-tables.html`, `html-title-rows-before-header.html`, `html-negative-decorative-table-only.html`.
- `docs/TASKS/TASK-031-import-recognition-hardening-canonical-headers-html-excel.md`: confermato **DONE / Chiusura**; TASK-031 non riaperta.
- `ExcelAnalyzer` in `ExcelSessionViewModel.swift`: `rowsFromHTML`, parsing per singola table, scelta tabella migliore, scoring tabella dati, `colspan`, `rowspan`, padding finale, interazione con `analyzeRows`, `findDataHeaderRow`, `canonicalHeaderTokenMap`, `normalizeHeaderCell`, fallback `colN`, append compatibility.
- Scope negativo: nessuna modifica a Supabase, `RowDetailSheetView`, `GeneratedView`, redesign PreGenerate, dipendenze o test target.

#### Problemi trovati
- Lo scoring poteva ancora selezionare una tabella decorativa contenente celle con nomi canonici (`barcode`, `productName`, `purchasePrice`) anche senza righe dati compatibili, perche' il peso dei match canonici bastava a produrre score positivo.
- La fixture `html-colspan-header.html` copriva soprattutto una riga titolo con `colspan`, ma non dimostrava abbastanza bene un header tabellare raggruppato.
- Il parsing per tabella usava `table.select("tr")`, che evita il mix globale tra tabelle ma puo' includere righe di tabelle annidate; meglio limitarsi a righe dirette o sezioni dirette (`thead`/`tbody`/`tfoot`).
- `appendValue` era corretto nel flusso attuale ma usava append sequenziale invece di assegnazione per indice logico; un assegnamento indicizzato e' piu' robusto per griglie con celle merge.

#### Fix applicati direttamente
- User override: fix diretti Claude applicati dentro scope, senza ciclo Codex separato.
- `ExcelAnalyzer.rowsFromHTML`: aggiunto helper `htmlRows(in:)` per leggere solo righe dirette della tabella o delle sezioni dirette.
- `parseHTMLRows`: `appendValue` ora assegna il valore all'indice logico dopo aver esteso la riga, riducendo il rischio di shift su griglie sparse.
- `scoreHTMLTable`: penalita' forte quando una tabella ha zero righe dati compatibili, anche se contiene parole/header canonici; questo evita che decorative-only venga scelta solo per nomi simili a header.
- `html-colspan-header.html`: aggiornata a header raggruppato con `colspan` + `rowspan` e header reale allineato ai dati.
- `html-negative-decorative-table-only.html`: rafforzata con celle `barcode` / `productName` / `purchasePrice` ma nessuna riga dati compatibile.
- `README.md` fixture aggiornato con attesi coerenti.

#### Build/check eseguiti
- ✅ ESEGUITO — `git status --short`.
- ✅ ESEGUITO — `git diff --stat`.
- ✅ ESEGUITO — `git diff -- docs/MASTER-PLAN.md`.
- ✅ ESEGUITO — `git diff -- docs/TASKS/TASK-036-import-recognition-advanced-html-colspan-rowspan-multi-table.md` (vuoto perche' il file e' nuovo/untracked; letto con `sed`).
- ✅ ESEGUITO — `git diff -- iOSMerchandiseControl/ExcelSessionViewModel.swift`.
- ✅ ESEGUITO — `ls -la docs/fixtures/TASK-036`.
- ✅ ESEGUITO — lettura `docs/fixtures/TASK-036/README.md`.
- ✅ ESEGUITO — lettura TASK-031 per confermare `DONE / Chiusura`.
- ✅ ESEGUITO — `xcodebuild -list -project iOSMerchandiseControl.xcodeproj`: unico target/scheme `iOSMerchandiseControl`; nessun test target esistente.
- ✅ ESEGUITO — Build: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'generic/platform=iOS Simulator' build` → PASS (`** BUILD SUCCEEDED **`).
- ⚠️ NON ESEGUIBILE — Warning nuovi: senza baseline non e' attribuibile storicamente. Il build log contiene solo il warning Xcode noto `appintentsmetadataprocessor` / `No AppIntents.framework dependency found`, non collegato ai file modificati.
- ✅ ESEGUITO — Verifica statica fixture: copertura `colspan`, `rowspan`, multi-table, title rows, negative decorative-only con parole simili a header.
- ✅ ESEGUITO — Criteri TASK-031 verificati staticamente: canonical headers, snake_case, alias localizzati, fallback no-real-header, override manuale e append compatibility non sono stati indeboliti.

#### Esito review
APPROVED con fix diretti piccoli gia' applicati. TASK-036 chiuso **DONE** su autorizzazione utente esplicita.

---

## Fix (Codex) ← solo Codex aggiorna questa sezione
Non avviato.

*Nota documentale: nessun ciclo **FIX** separato eseguito da Codex; i fix mirati sono documentati nella sezione **Review** (fix diretti Claude / user override).*

---

## Chiusura

### Conferma utente
- [x] Utente ha autorizzato chiusura a DONE se review/build/check risultano OK

### Follow-up candidate
- Eventuale validazione runtime/XCTest futura con export HTML reali anonimizzati; non creata in TASK-036 per assenza di test target e perimetro parser-only.

### Riepilogo finale
TASK-036 ha aggiunto un parser HTML piu' robusto e conservativo per tabelle avanzate: scelta per singola tabella, espansione rettangolare `colspan`/`rowspan`, scoring piu' prudente e fixture dedicate. Build verde; nessuna modifica a Supabase, `RowDetailSheetView`, `GeneratedView` o PreGenerate.

### Data completamento
2026-04-27
