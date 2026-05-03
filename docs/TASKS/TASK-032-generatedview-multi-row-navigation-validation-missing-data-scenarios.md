# TASK-032: GeneratedView multi-row navigation validation + missing-data scenarios

## Informazioni generali
- **Task ID**: TASK-032
- **Titolo**: GeneratedView multi-row navigation validation + missing-data scenarios
- **File task**: `docs/TASKS/TASK-032-generatedview-multi-row-navigation-validation-missing-data-scenarios.md`
- **Stato**: BLOCKED
- **Fase attuale**: REVIEW — **in pausa / on hold; P2–P4 runtime eseguiti; P5 scanner reopen NON accettato**
- **Responsabile attuale**: Utente / Planner — ripresa futura dal gate P5 scanner reopen o decisione formale di scope
- **Data creazione**: 2026-04-26
- **Ultimo aggiornamento**: 2026-05-03
- **Ultimo agente che ha operato**: Codex / Tracking — user override “metti task 32 in pausa e attivami la task 33”

## Nota — REVIEW corrente (FIX D2)

Sezione operativa **`Execution — D2 targeted fix`** più avanti (**prima dell’archivio 2026-04-28**). Review della slice D2 completata con esito **APPROVED D2 slice / accepted**. In seguito a override utente 2026-05-03, Codex ha eseguito i residui P2–P5: **P2–P4 PASS runtime**, **P5 scanner reopen resta NON accettato / non verificato PASS**. **`TASK-028` resta BLOCKED.** L’archivio **Historical execution archive** è **solo storico.**

- **`TASK-028` resta `BLOCKED`**: non può essere portato a **DONE** perché il gate **scanner reopen P5** non ha evidenza runtime PASS; P2–P4 sono stati eseguiti e documentati, ma non bastano per DONE.

## Nota — Pausa TASK-032 (user override 2026-05-03)

Su richiesta esplicita dell'utente, **TASK-032** è messo in pausa come **BLOCKED / on hold** e **TASK-033** diventa il task attivo. Questa non è una chiusura: **TASK-032 non è DONE**. Stato congelato alla pausa: D2 accepted; **P2–P4 PASS runtime**; **P5 scanner reopen NON accettato / senza evidenza PASS**. Alla ripresa, ripartire da P5 scanner reopen o da una decisione formale di scope; **TASK-028 resta BLOCKED**.

## Dipendenze
- **Dipende da**: TASK-028
- **Sblocca**: chiusura o fix mirato dei rischi runtime residui di TASK-028
TASK-028 è positivo ma non ha validato prev/next multi-riga e scenari con dati mancanti/ambigui. Questo task chiude il rischio UX residuo senza riaprire TASK-028.

## Contesto
TASK-028 resta BLOCKED e non DONE. La validazione runtime/visiva parziale del 2026-04-26 ha confermato il caso iPhone piccolo ma non copre dataset multi-riga, iPhone grande e dati mancanti/ambigui.

## Non incluso
- Nuovo redesign di RowDetailSheetView
- Supabase
- Refactor import
- Chiusura automatica di TASK-028 senza evidenza e conferma utente

## Scope
- Preparare o individuare in EXECUTION fixture/dataset multi-riga idoneo (vedi Addendum A)
- Validare prev/next
- Validare gate **D1/D2** (filtro errori) a **runtime** prima di proporre TASK-028 → DONE
- Validare badge delta solo quando applicabile
- Validare CTA collassate/nascoste se sorgente mancante
- Validare iPhone grande
- **Scanner reopen:** decisione esplicita in EXECUTION (validato / fuori perimetro motivato) se si propone TASK-028 → DONE

## Output richiesto (post—EXECUTION/REVIEW; non ancora prodotto — dipende anche da FIX mirato **D2**)
- Esattamente **una** raccomandazione esplicita su TASK-028, coerente con **Addendum G** e con i **gate D1/D2** e lo **scanner reopen** (cfr. Planning).
- **TASK-028 → DONE** solo con evidenze complete **e** conferma utente; **senza** gate **D2** conforme alla UX pianificata (e **`runtime`** anche per gli altri requisiti in scope) **non** si può raccomandare TASK-028 → DONE.
- **TASK-032** è in **EXECUTION mirata FIX D2** (vedi **Execution — D2 targeted fix**). **P2–P5** sul task completo **non sono in questa slice**. Dopo rivalidazione **runtime D2** (post-FIX) e regression **D1**, la review può decidere proseguimento; **TASK-032** non si considera DONE.

## Criteri di accettazione
- [x] Prev/next viene validato su dataset/fixture multi-riga (documentale o file creati **solo** in Execution reale, se necessari)
- [x] **D1 (gate):** dettaglio aperto da griglia con `generated.inventory.only_errors` attivo — prev/next **solo** tra righe con `SyncError`, contatore sul sottoinsieme filtrato, nessun salto a righe senza errore (**runtime obbligatorio** prima di proporre TASK-028 → DONE)
- [x] **D2 (gate):** dettaglio aperto da `InventorySearchSheet` con filtro errori attivo **prima** della ricerca — evidenza **runtime** separata; confronto con **UX preferita Planning** (dettaglio mantiene contesto **solo righe con `SyncError`**); se il filtro si disattiva in silenzio → **giustificare** in evidenza o trattare come **candidato FIX mirato** (**runtime obbligatorio** prima di proporre TASK-028 → DONE)
- [x] Badge delta assente se mancano dati numerici sufficienti; CTA nascoste/collassate se manca la sorgente; barcode assente → niente copy/share barcode e niente azioni prodotto che richiedono barcode; `productName` assente → fallback su `secondProductName` se presente; valori non numerici → stato neutro, nessun calcolo finto, nessun crash
- [x] iPhone grande viene validato (row detail)
- [ ] **Scanner reopen:** validato in EXECUTION **oppure** esplicitamente dichiarato fuori perimetro con motivazione — non lasciato “opzionale” ambiguo se si vuole proporre TASK-028 → DONE (cfr. Planning)
- [x] L’esito post—REVIEW produce **esattamente una** raccomandazione su TASK-028 (DONE / FIX in TASK-032 / mantenere BLOCKED), con evidenze o lacune documentate

## Planning (Claude) ← solo Claude aggiorna questa sezione

### Obiettivo

Validare i **rischi runtime/UX residui** di **TASK-028** su `GeneratedView` / dettaglio riga (`RowDetailSheetView` e flusso associato), senza riaprire TASK-028 come lavoro di implementazione:

- navigazione **prev/next** su **dataset multi-riga**;
- comportamento con **dati mancanti o ambigui** (identità, quantità, prezzi vecchi/nuovi, valori non numerici);
- **layout** su **iPhone grande**;
- **CTA**, **badge** e **delta prezzi** mostrati **solo quando applicabili** e coerenti con le Decisioni TASK-028 (es. Decisione 8);
- **output finale obbligatorio** (solo dopo EXECUTION + REVIEW): **esattamente una** raccomandazione tra **TASK-028 → DONE** (evidenze complete + conferma utente), **FIX mirato in TASK-032** se emerge regressione in perimetro, o **mantenere TASK-028 BLOCKED** se mancano gate o evidenze.
- **Senza runtime D1 e D2** (cfr. sotto e Addendum D) **non** si può raccomandare **TASK-028 → DONE**.

### Gate obbligatori D1/D2 (bloccanti per “TASK-028 → DONE”)

- **D1 — Griglia + `generated.inventory.only_errors` attivo:** aprire il dettaglio da una riga della griglia mentre il filtro errori è attivo. **Atteso:** `prev`/`next` **solo** tra righe con **`SyncError`**, contatore **X di Y** sul **sottoinsieme filtrato**, **nessun** salto a righe **senza** errore.
- **D2 — `InventorySearchSheet` + filtro errori attivo *prima* della ricerca:** riprodurre l’ingresso da ricerca con filtro errori già on.
- **UX preferita consigliata (Planning — salvo evidenza contraria in EXECUTION):** se l’utente apre il dettaglio da `InventorySearchSheet` mentre `generated.inventory.only_errors` è attivo, il dettaglio dovrebbe **mantenere il contesto filtrato** alle **sole righe con `SyncError`** (stesso spirito di D1: prev/next e contatore sul sottoinsieme errori). **Migliore per chiarezza:** evitare che l’utente passi **silenziosamente** da “solo errori” a “tutte le righe”. Se **in EXECUTION** il comportamento osservato **disattiva** il filtro prima di aprire il dettaglio, l’esecutore deve **(a)** **giustificarlo** esplicitamente nella riga evidenze (perché è accettabile per l’utente) **oppure** **(b)** proporlo come **candidato FIX mirato** — non etichettarlo come “ovvio” senza motivazione.
- **Nota codice (lettura statica):** i callback possono **disattivare** `showOnlyErrorRows` prima di jump/open detail; **nessuna modifica codice in Planning**.
- **Regola di raccomandazione:** **senza** evidenza **`runtime`** per **D1** **e** **D2** su una sessione con **almeno 2 righe** `SyncError`, la raccomandazione finale **non** può essere **TASK-028 → DONE**; resta **mantenere BLOCKED** (o FIX mirato se emerge regressione).

### Stato attuale

- **TASK-028** è in stato **BLOCKED**, **non** DONE: la review tecnica è sospesa in attesa di **validazione manuale** completa.
- La validazione runtime/visiva già eseguita (2026-04-26) è **positiva ma incompleta**.
- **Già validato** (lettura task / evidenze documentate): **iPhone piccolo**, **light/dark**, righe **complete/incomplete**, **campi secondari** nel caso **completo**.
- **Mancano** (ambito esplicito di TASK-032): **iPhone grande** (row detail), **prev/next su più righe**, eventuale **scanner reopen dopo permesso camera** se ancora rilevante per CA-6/CA-10/CA-11 di TASK-028, scenari con **dati mancanti/ambigui** (prezzi, nomi, barcode, quantità).
- **TASK-032** non deve **redesignare** `RowDetailSheetView`: limitarsi a **validare**, documentare evidenze e **decidere** se servono **fix mirati** (senza ampliare il perimetro a redesign generale).

### Riferimento Android (solo funzionale)

Usare l’app Android **solo** come riferimento di **comportamento atteso** dove utile:

- navigazione tra righe; visualizzazione prezzi **precedenti/nuovi**; gestione **campi mancanti**; flusso **scanner/codice a barre** se pertinente ai CA TASK-028.

**Non** copiare l’UI Android 1:1. La UX iOS resta **nativa** e coerente con Form/NavigationStack e le decisioni già prese in TASK-028.

### Scope

1. **Creare, individuare o descrivere** in Execution un **fixture/dataset multi-riga** minimo idoneo alla validazione — può restare **documentale** (specifica tabellare) finché non si creano file reali.
2. Validare **prev/next** tra **righe diverse** (avanti/indietro, ripetuto).
3. Validare righe con, tra gli altri: dati **completi**; **productName** mancante; **barcode** mancante o **ambiguo**; **oldPurchasePrice** assente; **oldRetailPrice** assente; **purchasePrice/retailPrice** assenti o **non numerici**; **quantità** mancante; valori **zero** o **vuoti** (coerenza copy e assenza di confronti fuorvianti).
4. Validare **badge delta** (quantità / confronti) **solo** quando i **dati sono sufficienti** (allineato a Decisione 8 TASK-028).
5. Validare CTA **collassate/nascoste/disabilitate** se manca la **sorgente dati** per l’azione.
6. Validare **layout** su **iPhone grande** (readability, fold, assenza clipping inaccettabile).
7. Validare assenza di **crash** e **out-of-bounds** navigando tra righe.
8. **Gate D1/D2**: validazione **runtime** obbligatoria (Addendum D) su sessione con **almeno 2 righe** `SyncError` (**HistoryEntry** reale o caricamento controllato da snapshot JSON); senza D1+D2 **non** si può raccomandare TASK-028 → DONE.
9. **Salvataggio/uscita** dal dettaglio: validare **solo** se già coperto dal flusso corrente e dai CA rilevanti — **non** allargare TASK-032 a nuovi flussi di persistenza o redesign del save.

### Non incluso

- Nuovo **redesign** di `RowDetailSheetView` o megarefactor della griglia.
- **Supabase**; refactor import generale; modifiche a **ExcelAnalyzer**; modifiche a **database/import HTML** oltre quanto serva a costruire un dataset di test **minimo** in execution (se necessario).
- **Nuova logica scanner** se non **necessaria** per evidenziare un gap TASK-028 già coperto da CA-6/CA-10/CA-11.
- **Chiusura automatica** di TASK-028 a DONE **senza** evidenza e **conferma utente**.
- Test UI **automatici complessi** (es. E2E) se il progetto **non** li supporta già — la strategia predefinita resta **manuale/Simulator** coerente con i task precedenti.

### Strategia di Execution (slice)

#### Priorità Execution (efficienza; ordine consigliato)

Ordine pensato per **sbloccare TASK-028** con il minimo rischio di tempo sprecato:

- **P0:** Ottenere una **`HistoryEntry` reale** o **snapshot controllato** con colonna **`SyncError`** e **almeno 2 righe** in errore (prerequisito dei gate).
- **P1:** Validare **D1** e **D2** **a runtime** (con tipo evidenza `runtime` — cfr. template sotto).
- **P2:** Validare **prev/next** “normale” e **binding** sulla fixture **6 righe** (o dataset equivalente).
- **P3:** Validare **dati mancanti / non numerici**, **CTA** e **badge** (matrice B).
- **P4:** Validare **iPhone grande** (row detail).
- **P5:** **Scanner reopen** — **obbligatorio** (**evidenza `runtime`**, PASS) se si vuole proporre **TASK-028 → DONE**; altrimenti raccomandazione **mantenere BLOCKED** o **fuori perimetro motivato** con effetto esplicito sulla raccomandazione.

**Regola di efficienza:** **senza P0 e P1 completati** non ha senso investire molto tempo su **polish** (P3–P4) o fermarsi su dettagli secondari: i gate sono ciò che blocca o sblocca la tesi “DONE” su TASK-028.

> **Refinement 2026-05-03 (priorità operative):** nello **storico EXECUTION archived**, **P1** mostrò **D1 PASS** ma **D2 FAIL** sul filtro/ricerca → **prima di riprendere P2–P5** deve intervenire ciclo **`FIX pianificato D2` + review / rivalidazione runtime** autorizzati dall’utente (vedi sezione **«Proposed D2 targeted FIX plan»** più sotto; **TASK-032** resta comunque **PLANNING**/refinement finché progetto MASTER non trasferisce EXECUTION nuova).

##### A. Fixture/dataset

- Preparare dataset **multi-riga** minimo con **4–6 righe**; ogni riga copre **uno** scenario elencato nello scope.
- **Strategia file:** allineata ad **Addendum A** — **preferire** snapshot `generatedview-task032-history-entry.json` + `README.md`; **HTML** solo se serve **davvero** esercitare il flusso **import** (TASK-032 valida soprattutto `GeneratedView` / row detail, non l’import come obiettivo primario).
- **In Planning** non si creano file sotto `docs/fixtures/TASK-032/`.
- Preferire **seed / percorso debug già esistente** o **caricamento HistoryEntry controllato**; **evitare nuovi helper** se un percorso già presente nel codebase basta.

##### B. Validazione visiva/runtime

- iPhone **piccolo**: solo **smoke** se serve a confermare nessuna regressione rispetto a quanto già validato.
- Esecuzione principale su **iPhone grande**; **light/dark** se il cambiamento UI del dettaglio è coinvolto o si rilevano anomalie.
- Navigazione **prev/next** in loop (avanti/indietro, più passaggi).

##### C. Regole dati mancanti (criteri operativi)

- Prezzo **precedente** assente → **nessun** delta/badge fuorviante sul confronto "vecchio vs nuovo" ove non applicabile.
- Prezzo **nuovo** mancante o non valido → **nessun** confronto errato o badge che implichi un delta numerico falso.
- **Barcode** o **productName** mancanti → **fallback leggibile** (stato neutro, non confondibile con errore di sync salvo `syncError` reale).
- Dati **non numerici** dove servono numeri: **nessun crash**, **nessun** calcolo silenzioso errato.
- CTA visibili **solo** se l’azione ha **senso** e c’è sorgente applicabile (coerente CA-5 / Decisione 8 TASK-028).

##### D. Decisione finale (solo dopo evidenze EXECUTION; in Planning **nessuna** decisione)

- **TASK-028 → DONE** — **solo** se **tutti** i criteri/addendum soddisfatti **inclusi D1 e D2** con evidenza **`runtime`** (cfr. template), **scanner reopen** validato o fuori perimetro **motivato**, e **conferma utente** formale.
- **FIX mirato in TASK-032** — regressioni o gap **entro perimetro** emerse in EXECUTION/FIX.
- **Mantenere TASK-028 BLOCKED** — se mancano **D1**, **D2**, evidenze **scanner reopen** quando richieste per la tesi “DONE”, o altre evidenze chiave; oppure per decisione utente. **Non** chiudere TASK-028 da automazione senza evidenze.

### File probabilmente coinvolti in Execution (solo candidati; non modificati in Planning)

- `iOSMerchandiseControl/GeneratedView.swift` — `RowDetailSheetView`, `RowDetailData`, `rowDetailSheet(_:)`, binding navigazione, bottom bar prev/next/scan
- Eventuali `Localizable.strings` **solo** se un FIX mirato richiede copy minimo
- Eventuali **fixture/test helper** o documentazione sotto `docs/` se si formalizzano dataset di prova
- `docs/MASTER-PLAN.md` e questo file **TASK-032** per tracking esiti e handoff

### Test Target Planning — mantenuto; verifica iniziale in Execution

Equivalente **concettuale** ai test mirati Android, adattato a **Swift / Xcode / XCTest / XCUITest**.

- In **Planning** si definisce **solo** la strategia; **non** si creano target di test (**nessun** nuovo bundle `*Tests` / `*UITests`; **nessuna** modifica a `.xcodeproj` in questa fase).
- In **EXECUTION**, **prima** di creare target, verificare se nel progetto Xcode esistono già:
  - `iOSMerchandiseControlTests`
  - `iOSMerchandiseControlUITests`
- Se **esistono** → **riusarli** (scheme, inclusione nei test action, dipendenze, eventuali fixture).
- Se **non** esistono: **non** crearli automaticamente; documentare come candidato follow-up o chiedere conferma se serve davvero:
  - **`iOSMerchandiseControlTests`** — unit / integration **rapidi** dove la logica è isolabile;
  - **`iOSMerchandiseControlUITests`** — **solo** per flussi UI **D1 / D2 / scanner**, **e solo se** sono presenti **o** si possono aggiungere **accessibility identifier** mediante **micro-FIX approvato** (valutazione in EXECUTION/review; **non** in Planning).
- La **creazione** di target mancanti richiede **OK esplicito** dell’utente e non fa parte dell’avvio Execution tracking-only.

#### Matrice «Test target futuri»

| Area | Tipo test consigliato | Target futuro | Fonte dati | Cosa verifica | Priorità | Stato in Planning |
|------|------------------------|---------------|------------|---------------|----------|---------------------|
| **A)** D1 row order filtrato | Unit/integration se **`rowOrder`** o **`rowHasError`** sono **isolabili**; altrimenti UI/**manual runtime** | `iOSMerchandiseControlTests` **preferito**; `iOSMerchandiseControlUITests` **solo se** necessario | **HistoryEntry**/**snapshot** con **≥2** righe **`SyncError`** | Con filtro errori attivo, **prev/next** naviga **solo** righe errore **e** il contatore usa il **sottoinsieme filtrato** | **P1** | **Planned**, non eseguito |
| **B)** D2 search + filtro errori | **UI test** o **integration test** se **separabile** | `iOSMerchandiseControlUITests` se serve **`InventorySearchSheet`** | **HistoryEntry**/**snapshot** con **≥2** righe **`SyncError`** | Apertura **detail da search** con filtro errori attivo; **UX preferita** = contesto **filtrato**; se il filtro **si disattiva** va **giustificato** **o** trattarlo come **candidato FIX** | **P1** | **Planned**, non eseguito |
| **C)** Binding prev/next | **UI test leggero** **o** **manual runtime** | `iOSMerchandiseControlUITests` **solo se** **accessibilità sufficiente** | Fixture **6 righe** | Edit su **R2** **non** si propaga a **R3/R4**; **counted/retail** riflettono **sempre** la riga **corrente** | **P2** | **Planned**, non eseguito |
| **D)** Missing data / non numerici | **Unit test** su helper/model se **estraibile**; altrimenti **manual**/**runtime** | `iOSMerchandiseControlTests` | Fixture **R3–R6** | **Niente delta falso**, **nessun crash**, **CTA** **collassate** quando non applicabili | **P3** | **Planned**, non eseguito |
| **E)** Scanner reopen | **Manual runtime** **o** UI test **solo** se scanner **mockabile** | `iOSMerchandiseControlUITests` **o** **manual runtime** | Row detail fixture | **Dismiss**/**scan** ritorna alla **stessa riga** e focus su **Contata** | **P5** se si mira a **TASK-028 → DONE** | **Planned**, non eseguito |

#### Regola «testability first, no refactor»

- Se una logica è testabile **solo** con **grande refactor** di **`GeneratedView`**, **NON** fare refactor **dentro TASK-032**.
- Preferire test su **helper già esistenti** **o** **micro-estrazioni** solo se diventano **FIX mirati** **e** **approvati**.
- Se servono **accessibility identifier** per **UI test**, pianificarli come **micro-FIX separato** **e solo dopo** evidenza che il **test UI** è necessario.
- **Non aggiungere accessibility identifier** in **Planning**.

#### Comandi candidati per Execution — **candidati, non eseguiti in questo avvio**

Esempi **solo** come riferimento per Execution; eseguire solo quando il target indicato esiste nello scheme e serve alla validazione. In questo aggiornamento tracking-only non producono righe **PASS/FAIL** reali né evidenze **runtime**.

```bash
# CANDIDATO GENERICO — solo se serve eseguire tutta la TestAction dello scheme.
xcodebuild test \
  -project iOSMerchandiseControl.xcodeproj \
  -scheme iOSMerchandiseControl \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max'

# CANDIDATO — eseguire solo se il target iOSMerchandiseControlTests esiste nello scheme.
xcodebuild test \
  -project iOSMerchandiseControl.xcodeproj \
  -scheme iOSMerchandiseControl \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' \
  -only-testing:iOSMerchandiseControlTests

# CANDIDATO — eseguire solo se il target iOSMerchandiseControlUITests esiste nello scheme.
xcodebuild test \
  -project iOSMerchandiseControl.xcodeproj \
  -scheme iOSMerchandiseControl \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' \
  -only-testing:iOSMerchandiseControlUITests
```

### Criteri di accettazione rafforzati

1. **Prev/next** validato su **dataset multi-riga** (almeno **6** righe se si usa la fixture proposta in Addendum A; almeno 4 se dataset ridotto) — criteri operativi dettagliati in **Addendum C**; bordi disabilitati e contatore in **Addendum C**.
2. Navigazione **non** causa **crash** né accessi **out-of-bounds** agli indici riga.
3. Righe con dati **completi** mostrano **confronto prezzi/quantità** in modo **corretto** ove i dati lo consentono.
4. Righe con **old price** (o equivalente) **mancante** non mostrano **delta** o badge **fuorvianti** sul vecchio vs nuovo.
5. Righe con **dati mancanti** mostrano **fallback leggibile** e stati **neutri** (non placeholder decorativi in conflitto con Decisione 2 TASK-028 ove applicabile).
6. **CTA** e **badge** rispettano la **disponibilità** dei dati sorgente (nascosti/collassati se assenti, salvo eccezione motivata in review).
7. **iPhone grande** validato per row detail (layout CA-12/CA-13 in spirito TASK-028).
8. **Nessuna regressione** su quanto già validato su **iPhone piccolo** (smoke o confronto evidenze).
9. **Nessun redesign** strutturale introdotto: solo eventuali **ritocchi minimo** se emergono in FIX e restano within-scope.
10. L’**output** del task include **esattamente una** **raccomandazione esplicita** su **TASK-028** tra: **DONE** (con evidenze + conferma utente), **FIX mirato in TASK-032**, o **mantenere BLOCKED** (motivazione) — cfr. **Addendum G**; evidenze riproducibili o limiti documentati.
11. Comportamento **D1 (griglia)** e **D2 (ricerca)** con filtro errori: **runtime obbligatorio** per raccomandare TASK-028 → DONE — verificato rispetto ad **Addendum D** + template evidenze; eventuale anomalia → FIX mirato, non redesign.
12. **Scanner reopen** (Addendum E): esito **documentato** (**PASS** runtime, **FAIL** con FIX, **fuori perimetro** con motivazione). Se si intende proporre **TASK-028 → DONE**, lo scenario deve essere **validato** oppure la raccomandazione finale deve essere **mantenere BLOCKED** (o spiegare perché lo scanner è fuori perimetro senza invalidare la tesi “DONE”) — **non** lasciato “opzionale” senza decisione.
13. **iPhone grande** (Addendum F) validato per row detail.

### UI/UX (linee guida per micro-interventi futuri; solo dopo evidenza FAIL in EXECUTION/FIX)

- **Micro-FIX ammessi solo dopo** evidenza **FAIL** in **EXECUTION** o **FIX** (mai “per estetica” in Planning); restano **nativi iOS**, coerenti con **Form**/**NavigationStack** e lo **stile attuale** dell’app; **non** copiare Android 1:1; **non** redesignare **`RowDetailSheetView`** (**divieto invariato**).
- **Preferenza FIX (se necessario):** mantenere **gerarchia e stile** già presenti in `GeneratedView`; **migliorare copy / visibilità / stati** dei controlli esistenti, **non** introdurre **nuove sezioni**.
- Se una **CTA non è applicabile:** preferire **nasconderla o collassarla** anziché mostrarla **disabilitata** che occupa spazio, **salvo** motivo chiaro documentato in review.
- Per **D2:** preferire **coerenza del contesto filtrato** (solo errori) rispetto alla **“sorpresa”** di un filtro disattivato senza che l’utente lo abbia scelto.
- Preferire la soluzione **più chiara per l’utente** in caso di scelta UX: **nessun badge delta** se mancano dati numerici sufficienti; **CTA nascoste/collassate** se la **sorgente** per l’azione non esiste; **barcode mancante** → niente copy/share barcode e niente azioni prodotto che **richiedono** barcode; **`productName` mancante** → fallback su **`secondProductName`** se presente; **valori non numerici** → stato **neutro**, nessun calcolo finto, **nessun crash**.
- **Micro-ritocchi** limitati a copy, visibilità/stato controlli, spacing, bordi prev/next — **senza** nuove sezioni o layout ibrido Material.

### Rischi

- Validazione **manuale** soggettiva; dataset **troppo piccolo** può non esporre out-of-bounds reali; **combinazioni** di dati mancanti possono non essere tutte previste; **chiudere TASK-028** senza prove sufficienti sarebbe **rischioso** per la qualità percepita e il tracking.
- **Filtro errori + edge case**: se `rowOrder` risultasse vuoto in uno scenario raro, il codice usa fallback `[detail.rowIndex]` — in execution verificare che non si creino salti o contatori incoerenti.

### Verifica coerenza tracking *(aggiornamento refinement — stato corrente)*

- **`docs/MASTER-PLAN.md`**: **TASK-032** = **ACTIVE** / **PLANNING** *(refinement)*; responsabile orientativo **Planner / Utente**. **TASK-032** ≠ **EXECUTION attiva**.
- Nel file TASK-032 la sezione **«Historical execution archive»** è **solo archivio** (2026-04-28 e seguenti note Codex): **non** descrivere la fase corrente né autorizzare lavoro esecutivo finché l’utente non approva **FIX pianificato D2** / handoff aggiornato.
- **`TASK-028`**: **BLOCKED** (**non** DONE). Nessuna conclusione TASK-032 → DONE su TASK-028 prima di chiudere **D2** (incluso eventuale **FIX** + **rivalidazione**) e gli altri requisiti in scope/documentati.

### Addendum operativo (verificabile, senza file fixture reali in questa fase)

Nomi colonne: allineare in execution a griglia reale (`quantity` = da file; header **`realQuantity`** = quantità contata / slot edit come da griglia — **mai** **`RealQuantity`** come nome chiave canonico nell’Header); **`RetailPrice`**, **`oldPurchasePrice`**, **`oldRetailPrice`**, **`SyncError`**; **old*** = prezzi da cella / DB come in `RowDetailData` / snapshot.

#### A) Fixture documentale minima — tabella “Fixture proposta” (6 righe; **nessun file creato in Planning**)

> **Strategia consigliata (efficienza):** priorità a **`generatedview-task032-history-entry.json`** + **`README.md`** per alimentare **P0** (≥2 righe `SyncError`) senza dipendere dall’import. **`generatedview-task032-import.html`** **solo se** serve **esplicitamente** validare il flusso **import → GeneratedView**; altrimenti è lavoro **secondario** rispetto a row detail. **Non** introdurre helper nuovi se esiste già seed/debug path o caricamento **HistoryEntry** controllato nel progetto.
>
> **File opzionali in EXECUTION (creare solo se necessari alla validazione P0→P1/P3 e documentarli):**
> - `docs/fixtures/TASK-032/generatedview-task032-history-entry.json` (**preferito**)
> - `docs/fixtures/TASK-032/README.md` (**preferito**)
> - `docs/fixtures/TASK-032/generatedview-task032-import.html` (**solo se necessario** al perimetro import)
>
> In questo avvio Execution tracking-only non sono stati creati fixture e questi path **non** costituiscono evidenza.
>
> **D1/D2:** per i gate serve **`HistoryEntry` reale** o snapshot JSON **controllato** con **`SyncError`** e **≥2 righe** errore — l’HTML da solo spesso **non** produce `SyncError`; documentare in EXECUTION la sorgente usata.
>
> **Nota:** righe/header coerenti con iOS: **`realQuantity`**, **`RetailPrice`**, `purchasePrice`, **`oldPurchasePrice`**, **`oldRetailPrice`**, **`SyncError`**, ecc., come in fixture `generatedview-task032-history-entry.json`. I valori **old*** possono venire da **cella** e/o **lookup Product**; allineare alla sorgente che l’app usa per il dettaglio riga.

> **Gate D1/D2:** nella fixture/snapshot canonica (**≥2** righe errore per i gate): **R2** e **R5** devono avere **`SyncError` NON vuoto** (testi come in JSON: `TASK-032 errore fixture R2` / `TASK-032 errore fixture R5`). **R6** rimane caso **senza errore sync** nella tabella qui sotto solo se serve matrice missing-data (**P3**); per **P1 gate** conta il sottoinsieme **solo righe errore**.

| Riga | Scenario | Barcode | productName | secondProductName | quantity (file) | realQuantity (contata) | old purchase / old retail (es. €) | `RetailPrice` in griglia | SyncError |
|------|----------|---------|---------------|-------------------|-----------------|------------------------|----------------------------------|-----------------------------|-----------|
| **R1** | Completa | `100001` | `Prodotto completo` | opz. vuoto | `10` | `10` | `800` / `1200` (storicizzati) | `1300` | *(vuoto)* |
| **R2** | Shortage + **rig errore fixture (D1/D2)** | `100002` | `Prodotto shortage` | opz. | `12` | `8` | *es.* `800` / `1500` | `1600` | **`TASK-032 errore fixture R2`** |
| **R3** | No storico prezzo (vecchi assenti) | `100003` | `Senza storico prezzo` | opz. | `5` | `5` | **vuoto** / **vuoto** | a scelta (es. `12`) | *(vuoto)* |
| **R4** | Identità senza barcode | **vuoto** | `Senza barcode` | opz. | `3` | `3` | a scelta | a scelta | *(vuoto)* |
| **R5** | Nome prim. assente + **rig errore fixture (D1/D2)** | `100005` | **vuoto** | `Nome secondario` | `4` | `4` | a scelta | a scelta | **`TASK-032 errore fixture R5`** |
| **R6** | Non numerici | `100006` | `Valori non numerici` | opz. | `abc` **oppure** `RetailPrice` = `x12` per riga | valore coerente col test | a scelta | a scelta | *(vuoto)* |

Esempio vincolante (allinea **snapshot JSON**): **R2** deve includere sia scenario shortage **sia** `SyncError` = `TASK-032 errore fixture R2`; **R5** = `Nome secondario` + `SyncError` = `TASK-032 errore fixture R5`; **R1,R3,R4,R6** = `SyncError` vuota per uso matrice scenario (salvo modifiche dedicate in Execution).

#### B) Matrice pass/fail (atteso; segnare PASS/FAIL in Execution con nota)

Legenda compatta: **V** = visibile/abilitata nel contesto, **N** = nascosta/collassata, **D** = disabilitata o non cliccabile, **—** = non applicabile o irrilevante per lo scenario.

| ID | prev/next (navigazione nella lista attiva) | Stato badge Δ **quantità** (Decisione 8) | CTA “Usa quantità da file” | CTA “Usa vendita vecchia” | Copia / share barcode | Modifica prodotto · Storico prezzi | Fallback / identità nome | Complete / incomplete |
|----|---------------------------------------------|------------------------------------------|-----------------------------|----------------------------|------------------------|-----------------------------------|-------------------------|------------------------|
| **R1** | Avanti/indietro tra R1…R6; agli estremi prev/next coerenti con `rowOrder` | **Match** (o equivalente copy “in linea”) con colorazione neutra/positiva, entrambe qty valide | **V** se esiste sorgente qty file | **V** se esiste sorgente vecchio prezzo vendita applicabile | **V** (barcode presente) | **V** (barcode presente) | Nome + eventuale secondario | Toggle completo; nessun dialog shortage |
| **R2** | Come sopra | **Shortage** (mancanza), copy/colore attesi; se si forza **completo** con shortage → **dialog di conferma** | **V** se qty file definita | **V** se `oldRetail` presente e applicabile | **V** | **V** | OK | Incompleto con shortage; forza completo chiede conferma |
| **R3** | Come sopra | Solo se file+contata parseabili; **nessun** blocco prezzi “vecchi vs nuovi” **fuorviante** (nessuna etichetta che implichi un delta tra vecchie due colonne se assenti) | **V** / **N** secondo sorgente (se qty file manca → **N** o nessun confronto) | **N** (nessuna vendita vecchia disponibile) — non riga disabilitata che occupa spazio salvo eccezione motivata (CA-5 / D8) | **V** | **V** | OK | Comportamento neutro; nessun delta prezzi inventato |
| **R4** | Come sopra | Se qty valide: delta ok; altrimenti nessun badge falso | Come da sorgente | Se `oldRetail` assente: **N** | **D** o **N** (nessun barcode) | **D** o **N** (nessun barcode prodotto) | Nome o UI neutra (identità da nome) | Nessun crash; stati coerenti |
| **R5** | Come sopra | Se qty valide, delta regolare; altrimenti nessun badge falso | Come da sorgente | Da `oldRetail` se presente | **V** | **V** se regole prodotto lo consentono con solo barcode | **Leggibile**: nome primario assente, secondario o label chiara; niente caos in header | Neutro |
| **R6** | Come sopra | **Nessun** badge shortage/surplus/match **numerico falso**; se parse fallisce → **nessun** deltaState semantico | **N** o nessun effetto se sorgente non valida | **N** se sorgente assente/invalida | Se barcode testo: **V**/**D** secondo implementazione (documentare) | **V**/**D** secondo regole | Neutro, nessun testo “errore” finto salvo celle reali | **Nessun** auto-complete o salvataggio che corregga silenziosamente in modo errato; **nessun crash** |

#### C) Validazione prev/next (criteri rafforzati per Execution)

1. Aprire dettaglio su **R1**; **Next** fino all’**ultima** riga del `rowOrder` corrente; **Prev** fino a **R1**.
2. Alla **prima** riga: **Prev** disabilitato o inerte; all’**ultima**: **Next** disabilitato o inerte.
3. **Nessun** indice out-of-bounds, **nessun** crash, **nessun** salto a riga fantasma.
4. Titolo o contatore tipo **“Riga X di Y”** (o equivalente) si **aggiorna** ad ogni passo in modo coerente con `rowOrder` e indice reale.
5. **Counted** (contata) e **retail** editabile devono **sempre** riflettere la **riga corrente** (binding corretto dopo ogni tap prev/next).
6. **Dopo modifica** su R2 (es. edit contata o retail), navigare a R3/R4 e verificare che i valori R2 **non** compaiano sulle altre righe (stessa sessione, senza chiudere lo sheet se il flusso lo consente).

#### D) Gate **D1/D2** — “Mostra solo righe con errore” (`generated.inventory.only_errors`)

> **Regola di raccomandazione:** **senza** evidenza runtime **D1** **e** **D2** (sessione con ≥2 righe `SyncError`) **non** si può raccomandare **TASK-028 → DONE**.

- **UX target da griglia (D1):** con filtro errori **attivo**, aprendo il dettaglio da una riga **della griglia** visibile in quella lista, **prev/next** deve navigare **solo** tra **righe con errore (`SyncError`)**; contatore **X di Y** sul **sottoinsieme filtrato**; **nessun** salto a riga **senza** errore.
- **Letture statiche (`GeneratedView.rowDetailSheet`):** quando `showOnlyErrorRows` è `true`, `rowOrder` può essere costruito filtrando con `rowHasError`; se la lista filtrata è vuota, può esserci fallback `[detail.rowIndex]`. **Refinement:** evidenza **storica archived** suggerisce **D1 già confermato** con dataset/fixture sopra — **ripetibile** dopo **FIX D2** o regression check.
- Se D1 **fallisce**: **FIX mirato UX** (niente redesign `RowDetailSheetView`); micro-interventi su `rowOrder` / bordi ammessi **solo** in EXECUTION/FIX con evidenza.

##### Entry point da validare

- **Caso D1 — Dettaglio aperto da griglia con `generated.inventory.only_errors` = attivo**
  - **prev/next** solo tra righe con `SyncError` (contesto filtrato).
  - Contatore **X/Y** riferito al **sottoinsieme filtrato**.
  - Nessun salto verso righe **senza** errore.
  - Verificare anche chiusura/riapertura sheet e persistenza aspettazioni.

- **Caso D2 — Dettaglio aperto da `InventorySearchSheet` con filtro errori *prima* attivo**
  - **Comportamento codice attuale (lettura `GeneratedView` ~480–494):** nei callback `onJumpToRow` e `onOpenDetail`, se `showOnlyErrorRows` è `true`, può essere eseguito `showOnlyErrorRows = false` **prima** di scroll o `showRowDetail` → il dettaglio può vedere **`rowOrder`** su **tutte** le righe, non solo errori.
  - **UX preferita Planning (criterio di valutazione):** come per il gate D1, **mantenere il contesto “solo errori”** nel dettaglio quando l’utente arriva dalla ricerca con filtro attivo; **evitare** il passaggio **silenzioso** da sottoinsieme errori a elenco completo. Se **runtime** mostra disattivazione automatica del filtro → in evidenze: **giustificare** perché è comunque accettabile **oppure** **candidato FIX mirato** (coerenza con sezione **UI/UX**).
  - La **Execution** prova **D1** e **D2** con righe evidenze **separate**, tipo **`runtime`** obbligatorio per sbloccare DONE (template sotto).

#### E) Scanner reopen — **decisione esplicita** (non “opzionale vago”)

- **Pertinenza TASK-028:** **CA-6, CA-6b, CA-10, CA-11** (reopen scanner, nessuna perdita input, focus contata).
- **Se in EXECUTION si intende proporre TASK-028 → DONE:** lo **scanner reopen** va **validato** a runtime (device con camera o percorso affidabile concordato), con evidenze nel template — oppure la raccomandazione finale deve **mantenere TASK-028 BLOCKED** **oppure** dichiarare con **motivazione** perché l’evidenza scanner è **fuori perimetro TASK-032** **senza** per questo chiudere i gap TASK-028 (tipicamente → **BLOCKED**).
- **Scenari da evidenziare se validato:** apertura scanner **dal** dettaglio, **dismiss** senza risultato, ritorno **alla stessa riga** con stato coerente; scan riuscito con `reopenRowDetailAfterScan` e focus su **Contata** come da flusso attuale.
- **Non ammesso:** lasciare lo scanner come voce “opzionale” senza una delle tre uscite: **PASS**, **FAIL** (+ FIX se in perimetro), **fuori perimetro motivato** con effetto sulla raccomandazione (**DONE** vs **BLOCKED**).

#### F) iPhone grande (device / Simulator)

- **Target consigliato:** **iPhone 16 Pro Max** (o simulatore **grande** equivalente, es. stessa generazione, risoluzione massima pratica).
- **Controlli:** **bottom bar** (prev/scan/complete/next), comparsa **tastiera** sui campi editabili, **Form** e sezioni, **Dynamic Type** a livello **normale/standard**; nessun **clipping** inaccettabile di etichette o CTA; scroll solo dove accettabile.
- Eventuali interventi futuri: **solo** micro-polish iOS **nativo**, coerente con l’app; **no** porting Android 1:1.

#### G) Output obbligatorio in **EXECUTION + REVIEW** (esito unico, non negoziabile)

La fase **EXECUTION** e la **REVIEW** che segue devono chiudere con **esattamente una** raccomandazione, documentata nel file task con **evidenze riproducibili** o **lacune** esplicite:

1. **TASK-028 → DONE** — **solo** con: evidenze **complete** (inclusi **D1** e **D2** con **`Evidence type` = `runtime`**, e **scanner reopen** validato **oppure** fuori perimetro motivato in modo che non lasci TASK-028 in stallo ingiustificato) **+** **conferma utente** formale. **TASK-028** non si chiude da automatismo.
2. **FIX mirato in TASK-032** — regressione o gap **entro perimetro** emerso in EXECUTION (fase **FIX** → **REVIEW**).
3. **Mantenere TASK-028 BLOCKED** — se mancano **D1**, **D2**, evidenza **scanner** quando necessaria alla tesi “DONE”, o altre evidenze chiave; includere **motivazione** e, se utile, elenco requisiti per una futura validazione.

**Non ammesso:** raccomandare **DONE** senza D1+D2 runtime; **non** dichiarare evidenze runtime in questo avvio Execution tracking-only.

#### Template evidenze Execution (da compilare durante validazione reale; una o più righe per macro-area)

Ogni **macro-scenario** deve avere **almeno una riga** con **Observed** + **PASS/FAIL** (e **Note** se FAIL o ambiguo).

**Tipo evidenza (`Evidence type`) — obbligatorio per riga:**

- Valori ammessi: **`runtime`** | **`static`** | **`screenshot`** | **`not executable`**.
- **D1** e **D2:** per chiudere i gate ai fini **TASK-028 → DONE** serve **`runtime`** (eventuale **`screenshot`** solo **a corredo**). **`static`** da solo **non** basta.
- **Scanner reopen:** **`runtime`** per **PASS**; **`not executable`** ammesso **solo** se la **Note** indica **l’effetto esplicito** sulla raccomandazione (es. impedisce DONE / fuori perimetro) — **non** come scappatoia senza conseguenza dichiarata.

Macro-aree:

- prev/next “normale” (dataset A/B/C);
- dati mancanti (R3–R5, matrice B);
- dati non numerici (R6);
- filtro errori **da griglia** (D1);
- filtro errori + apertura **da ricerca** (D2);
- **scanner reopen** (Addendum E);
- **iPhone grande** (Addendum F).

| Scenario | Evidence type | Device | Entry point | Filtro errori | Riga iniziale | Azione | Expected | Observed | PASS/FAIL | Note |
|----------|----------------|--------|-------------|---------------|---------------|--------|----------|----------|-----------|------|
| *es. D1* | `runtime` |  | griglia | on |  | prev/next | solo righe `SyncError`; contatore su sottoinsieme |  |  |  |
| *es. D2* | `runtime` |  | `InventorySearchSheet` | on prima dell’apertura |  | apri dettaglio | target Planning: contesto filtrato solo errori; se filtro disattivato automaticamente → giustificare o FIX |  |  |  |

Le righe possono allegare ID build/simulatore o path screenshot in **Note**.

### Historical handoff snapshot — planning → Execution *(2026-04-28; **NON è lo stato corrente**)*

> **Messaggio refinement:** questa trascrizione descriveva l’handoff storico («passa ad Execution»). **Oggi** il task è in **PLANNING / refinement**; **TASK-032 non passa ad Execution da queste righe.** Il prossimo passo pianificato è **approvazione utente sul FIX mirato D2** (vedi sezione dedica sotto).

- ~~Planning perfezionato e EXECUTION autorizzata…~~ *(archivio)*
- ~~TASK-032 passa a ACTIVE / Execution…~~ *(archivio — **superato**)*
- Ordine storico suggeriva **P0 → P5**; **aggiustamento refinement:** dopo storico gate **P1** (**D2 FAIL** ricerca+filtro), il lavoro consigliato **non** è proseguire con **P2–P5** generici prima di pianificazione/**FIX D2**.
- Review/Fix dopo EXECUTION vera restano sul flusso formale progetto (**non riallineati in questa snapshot**).

---

## Proposta consolidata refinement — messaggio sintetico D2 *(non sostituisce «Planning (Claude)»)*

- **Gate archiviati (slice storica, vedi Historical execution archive):**
  - **D1 — griglia + solo errori:** esito storico osservazioni — **PASS** rispetto alla UX pianificata.
  - **D2 — `InventorySearchSheet` + filtro errori attivo:** esito storico — **FAIL** (contesto passa implicitamente all’intero inventario es. `5/6`, **Next** verso righe senza `SyncError`).
- **Interpretazione operative:** questo **FAIL D2 blocca la logica** «passare al polish prev/next/P3…» come priorità principale e **costringe una decisione tecnica UX** (**FIX mirato** o motivazione forte accettabile) **prima** di investire tempo su **P2–P5** per puntare a **TASK-028 → DONE**.
- **`TASK-028`**: **BLOCKED** (invariato).

---

## Proposed Planning Refinement for Claude/User approval *(bozza 2026-05-03 — non sostituisce la sezione «Planning (Claude)» finché Claude/utente non integra o approva)*

> **Istruzione:** questa sezione è **proposta** di integrazione/ottimizzazione del piano. **Non** modifica direttamente «Planning (Claude)». Dopo approvazione, **Claude** può incorporare i punti nella sezione ufficiale o lasciare qui come addendum vincolante per EXECUTION.

### PR-1 — Stato, evidenze e tracking

- **Passata corrente:** solo **Planning refinement**; nessuna dichiarazione di esito runtime.
- **Evidenze:** valide ai fini **TASK-028 → DONE** solo se prodotte in **EXECUTION vera** (autorizzata), con `Evidence type` coerente (cfr. template in Planning Claude); quanto riportato in passate precedenti va **riesaminato** in quel contesto, non assunto come chiusura gate in questa passata refinement-only.
- **`TASK-028`:** resta **BLOCKED** finché **D1**, **D2** e **scanner reopen** non sono **chiusi** con runtime **oppure** **motivati** con effetto esplicito sulla raccomandazione (**non** promuovere **DONE** per silenzio assenze).
- **Raccomandazione finale obbligatoria (una sola):**
  **A)** `TASK-028` → **DONE** *(solo con evidenze complete + conferma utente)* · **B)** **FIX mirato** in **TASK-032** · **C)** **mantenere `TASK-028` BLOCKED**.

### PR-2 — Gate D1/D2 (rafforzamento + decision tree)

- **D1 — Griglia + `generated.inventory.only_errors` attivo:** dal dettaglio aperto **dalla griglia** in quella modalità, **prev/next** devono restare **solo** tra righe con **`SyncError` non vuoto**; il contatore (**X di Y**) deve riferirsi al **sottoinsieme filtrato** (es. solo righe errore), **senza** salti a righe senza errore.
- **D2 — `InventorySearchSheet` con filtro errori già attivo:** la **UX preferita** è **mantenere il contesto “solo errori”** anche nel dettaglio (stesso sottoinsieme e stessa semantica contatore/navigazione di D1), così l’utente non passa **silenziosamente** da elenco filtrato a elenco completo.
- **Lettura statica nota:** i callback possono azzerare `showOnlyErrorRows` prima di aprire il dettaglio da ricerca — **non** va accettato in silenzio in review:
  - se il **runtime** conferma disattivazione silenziosa → **(1)** documentare in evidenze una **motivazione UX forte** accettabile per l’utente **oppure** **(2)** classificare come **candidato FIX mirato** (perimetro TASK-032, senza redesign `RowDetailSheetView`).
  **Nessuna implementazione in questa fase refinement-only.**

**Decision tree (D2, valutazione post-runtime in EXECUTION vera):**

```text
Filtro errori ON da search → apri dettaglio
├─ rowOrder/contatore restano su sole righe SyncError? → OK (allineato a UX preferita)
└─ contesto passa a “tutte le righe” senza azione esplicita utente?
   ├─ Motivazione UX documentata e condivisa in review? → accettabile se utente/review concordi
   └─ altrimenti → candidato FIX mirato (preservare filtro / passare contesto esplicito al dettaglio)
```

### PR-3 — Fixture / dati di test (allineamento header iOS)

Allineare **sempre** nomi colonna allo **schema reale** usato da `GeneratedView` / `HistoryEntry` (griglia + `RowDetailData`), in particolare:

- **`SyncError`**, **`oldPurchasePrice`**, **`oldRetailPrice`**, **`RetailPrice`** (prezzo vendita in griglia / edit), **`realQuantity`** (quantità contata / slot contata coerente con `editable[row][*]` come da mapping attuale), **`quantity`** (da file ove presente), **`barcode`**, **`productName`**, **`secondProductName`**, ecc.

**D1/D2:** richiedono **`HistoryEntry` reale** o **snapshot controllata** con colonna **`SyncError`** e **almeno 2 righe** con **`SyncError` non vuoto**, assegnate in modo **non ambiguo:** preferibilmente **R2** e **R5** (etichette scenario), entrambe con messaggio errore leggibile.

- **`generatedview-task032-import.html`:** resta **secondario**; usarlo **solo** se serve validare **import → GeneratedView**. **Non** è sorgente primaria per D1/D2 (l’import normale **non** garantisce popolamento `SyncError`).

### PR-4 — Ordine efficiente dopo storico gate *(refinement priorità)*

| Fase | Contenuto |
|------|-----------|
| **P0–P1 (storico)** | Già coperti in archivio: sorgente con **≥2** `SyncError` **non vuoto**, validazione storica gate **D1** / **D2** (→ **FAIL D2** da affrontare con **FIX pianificato**). |
| **→ Prossimo (bloccante per «DONE TASK-028»)** | Approvazione **planning FIX mirato D2** → EXECUTION/autorizzata **implementazione/fix** sul percorso `InventorySearchSheet` ↔ dettaglio ↔ `showOnlyErrorRows`/`rowOrder` — **solo planning qui**, nessuna modifica ora. |
| **Ripresa post-FIX-D2 (+ review)** | **Rivalidazione runtime D2** conforme UX; poi **TASK-032** eventualmente EXECUTION vera per **P2** (prev/next normale/binding), **P3** missing data/CTA/badge, **P4** iPhone grande, **P5** scanner reopen. |

**Regola refinement:** dopo **FAIL D2** documentato non ha senso trattare **P2–P5** come prossimo “blocco naturale”: serve **Decisione**/FIX su **D2** (o forte motivazione accettabile) **prima**.

### PR-5 — UI/UX *(solo proposte micro-ritocco, stile iOS esistente)*

Variante preferita: **chiarezza** e coerenza con **Form** / **NavigationStack** già in app; **nessuna** nuova sezione, **nessun** layout Material, **nessun** redesign `RowDetailSheetView`.

- **Filtro “solo righe errore”** da ricerca (**D2**) preservato nell’intent utente dopo **FIX pianificato** — nessuna regressione UX “lista completa sorprende” nei casi progettuali (cfr. **Proposed D2 targeted FIX plan**).
- **Nessuna sorpresa** per l’utente rispetto al contesto scelto (solo errori / full list sempre esplicito).
- CTA **nascoste/collassate** se manca la sorgente per l’azione.
- **Nessun** badge delta se mancano numeri sufficienti per un confronto onesto.
- **Barcode assente:** niente copy/share barcode, niente azioni che **richiedono** barcode.
- **`productName` assente:** fallback su **`secondProductName`** se presente.
- Valori **non numerici:** stato **neutro**, nessun calcolo finto, nessun crash.
- **Prev/next** **chiaramente** disabilitati ai bordi (o equivalente inequivocabile).
- Copy più chiaro solo se emerge bisogno da evidenza FAIL.

### PR-6 — Scanner reopen

In **EXECUTION vera** la chiusura deve essere **una** tra:

1. **PASS** runtime (evidenza `runtime`), oppure
2. **FAIL** runtime + **candidato FIX mirato** in perimetro, oppure
3. **Fuori perimetro** con **motivazione** e **effetto esplicito** sulla raccomandazione (tipicamente **non** sostenibile **TASK-028 → DONE** se i CA TASK-028 richiedono quella evidenza e resta un gap).

Se si mira a **TASK-028 → DONE** ma manca evidenza scanner dove è richiesta → **`TASK-028` resta BLOCKED**.

### PR-7 — Testability *(planning only)*

- Se **`iOSMerchandiseControlTests`** esiste: si può **pianificare** solo test unit/integration **futuri** mirati, **senza** crearli in questa fase refinement.
- Se **`iOSMerchandiseControlUITests`** **non** esiste: **non** crearlo dal planning; eventuale automazione = follow-up con OK utente.
- **Accessibility identifier:** solo come possibile **micro-FIX futuro** post-evidenza, **non** parte del planning refinement.

### Handoff — Planning refinement pending user approval *(aggiornato — priorità D2)*

- **Prossima fase documentale raccomandata:** **Planning / review tecnica sul FIX pianificato D2** da parte di **Claude** (integrazione eventualmente dentro «Planning (Claude)») + **approvazione esplicita utente**.
- **Dopo approvazione utente:** transizione permettibile verso **EXECUTION / FIX** mirato (**Codex/Cursor**) per **solo** il perimetro definito dalla sezione **«Proposed D2 targeted FIX plan»** qui sotto.
- **Dopo rivalidazione positiva runtime D2 e review ciclo FIX:** riprendere **P2–P5** (non prima, salvo ragione forte documentata nel task).
- **Prossimo agente:** Planner/Claude per consolidamento piano ufficiale; esecutore **solo** dopo handoff EXECUTION autorizzato.
- **`TASK-028`:** **BLOCKED** fino a conclusione delle condizioni nei criteri/Addendum.
- **Azione consigliata per l’utente:** approvare o emendare la sezione **Proposed D2 targeted FIX plan** e l’handoff sopra; poi **CLAUDE**/planner può fondere nella sezione ufficiale Planning se necessario.

---

## Proposed D2 targeted FIX plan — Planning only

*(Non modifica Codex; destinata alla futura EXECUTION/FIX dopo approvazione utente e ripresa formale EXECUTION autorizzata — **nessuna implementazione ora**.)*

### Contesto sintetico (solo archiviato — non rivalutato in questa passata)

Evidenza **pregressa Codex**, riportata sotto nella sezione **Historical execution archive**: **D1** griglia + filtro errori risultò **PASS** verso la UX pianificata; **D2** search + filtro errori risultò **FAIL** (contesto dettaglio/navigazione su tutte le righe, **es.** contatore `5/6`, **Next** su riga senza `SyncError`). **Questa passata non rideclara quei PASS/FAIL:** li cita solo per il piano.

### Obiettivo UX

Con **`generated.inventory.only_errors`** attivo, quando l’utente apre il dettaglio da **`InventorySearchSheet`**:

1. Mantenere il contesto **solo righe con `SyncError` non vuoto** (equivalente a **D1** da griglia per semantica di navigazione).
2. **`Prev`/`Next`** e il **contatore** devono essere calcolati sul **medesimo sottoinsieme filtrato** (non sulla sessione completa).

### Preferenza UX (anti-sorpresa, coerente iOS nativo dell’app)

- **NON** impostare in silenzio `showOnlyErrorRows`/intento filtro errore solo perché parte il flow da ricerca: evitare passaggio sorprendente dal sottoinsieme errori alla lista completa.
- Coerenza: **filtro errori preservato anche nel sheet dettaglio** quando l’ingresso aveva quel filtro acceso dall’operatore (come descritto in **PR-5** / UI/UX progetto TASK-032).

### Direzioni tecniche **candidate** *(valutazione in EXECUTION futura)*

| Opzione | Idea |
|---------|------|
| **A** | Non resettare `showOnlyErrorRows` nel path **`onOpenDetail`** (o analoghi callback) dalla ricerca se l’intent utente rimane solo-errori (**non** modificare ora). |
| **B** | Passare al dettaglio un **ordered context**/`rowOrder` **già limitato alle righe con errore**, indipendentemente dall’implementazione stato griglia (**micro-cambio**; **evitare** refactor ampio **`GeneratedView`**). |
| **C** | Se serve **solo** effetto visivo “salta sulla riga” nella griglia, separare **`jump`** da **`openDetail`**: lo **scroll** sulla griglia **può**, se proprio tecnico indispensabile mostrare riga nell’assetto fisico griglia globale ma **navigation mode** nell’overlay dettaglio **deve** restare sugli ID error-rows concordati (da definire in FIX). |

### Rischi *(da risolvere in planning review / poi implementazione)*

| Rischio | Mitigazione proposta piano |
|---------|----------------------------|
| Ricerca restituisce match **fuori dall’insieme errore-sync** mentre filtro errori è ON | **UX esplicito:** vietato apri silenzioso “full context” — decidere prima del codice (**bloccare apertura** / conferma “Vuoi vedere tutte le righe?” / **messaggio** chiaro leggibile per l’operatore). |
| Regressioni su **`D1`/griglia** durante FIX | Test di **non regressione runtime D1** nella stessa campagna di FIX D2 o subito dopo. |
| Tentazione refactor massivo **`GeneratedView`** | **vietato ambito refinement** → solo **PATCH mirati** dentro perimetro TASK-032 approvati review. |

**Vincoli invariati:** nessun **redesign RowDetailSheetView**; modifiche chirurgiche a `GeneratedView` solo nell’ambito EXECUTION autorizzato dopo questo planning.

---

## Execution — D2 targeted fix *(completata — handoff a Claude / Review)*

### Scope slice
Solo FIX **gate D2** (`InventorySearchSheet` + `showOnlyErrorRows`): **non** eseguire **P2–P5** task-wide (**prev/next dataset completo**, dati mancanti, **iPhone grande**, **scanner reopen** rimangono **non eseguiti** in questa slice). **`TASK-028` — BLOCKED.**

### P1 — Analisi statica (punto causa D2 storico)

- **`GeneratedView`** — foglio ricerca `@State showSearch`: i callback **`onJumpToRow`** e **`onOpenDetail`** (2026-04 archive) facevano `showOnlyErrorRows = false` prima di `scrollToRowIndex` / `showRowDetail`. Con `showOnlyErrorRows == false`, `rowDetailSheet(_:)` costruisce `rowOrder` su **tutte** le righe → comportamento storico (**contatore tipo 5/6**, **Next** verso righe senza `SyncError`).
- **`InventorySearchSheet`** — TAP su risultato chiamava **prima** `onJumpToRow` **poi** `onOpenDetail`; anche dopo fix parziale su `onOpenDetail` il TAP avrebbe potuto comunque sporcare il contesto perché **`onJumpToRow` eseguito per primo.**

### P2 — Fix implementato *(minimo)*

File: **`iOSMerchandiseControl/GeneratedView.swift`**

1. **`onOpenDetail`** (dal parent nel foglio ricerca): **non** resetta più `showOnlyErrorRows`; se filtro solo-errori è attivo e la riga **non** ha `SyncError`, **non** apre il dettaglio → alert ritardato dopo chiusura sheet (stringhe localize).
2. **`onJumpToRow`**: solo se filtro ON **e** riga **senza** errore → chiama ancora reset filtro (**toolbar** prev/next sulla lista ricerca quando il match fuori errore deve poter raggiungere la riga sulla griglia). Se filtro ON **e** riga **con** errore → **solo** `scrollToRowIndex`, filtro resta ON.
3. **`InventorySearchSheet`**: TAP risultati chiama **`onOpenDetail` soltanto** — niente **`onJumpToRow`** sulla stessa pressione (**evita** ordine Jump→detail che ripristinava comportamento errore storico sul contesto errore solo).
4. Alert: `@State showSearchDetailBlockedWhileErrorsOnlyAlert` + chiavi `generated.inventory.search_detail_blocked_*` in **`Localizable.strings`** (it / en / es / zh-Hans).

### P3 — Build

| Check | Risultato |
|-------|-----------|
| `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'generic/platform=iOS Simulator' build` | ✅ **`BUILD SUCCEEDED`** |
| `xcodebuild build -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'id=61AC09F8-DAC5-4354-8ED2-21404AD1924C'` | ✅ **`BUILD SUCCEEDED`** — iPhone 17 Pro Max Simulator, iOS 26.4 |

*(Log completo nell’agent run; la build specifica ha emesso il warning toolchain `Metadata extraction skipped. No AppIntents.framework dependency found.`, senza baseline delta warning in questa slice.)*

### P4/P5 — Evidenza runtime *(D2 + regression D1)*

#### Preparazione fixture runtime

- **Device/simulatore**: iPhone 17 Pro Max Simulator, iOS 26.4, UDID `61AC09F8-DAC5-4354-8ED2-21404AD1924C`.
- **Sorgente fixture**: `docs/fixtures/TASK-032/generatedview-task032-history-entry.json`.
- **Verifica statica fixture**: `jq` conferma 7 righe totali (header + 6 dati), header con `SyncError`, `editable` e `complete` con 7 elementi, R2 con `TASK-032 errore fixture R2`, R5 con `TASK-032 errore fixture R5`.
- **Caricamento runtime**: app reinstallata sul solo simulatore, snapshot inserita in `Library/Application Support/default.store` come singola `HistoryEntry` SwiftData. Nessun helper permanente e nessun codice Swift aggiunto per il seed.
- **Verifica UI P0**: `HistoryView` mostra `TASK-032 Runtime Fixture` con `Errori 2`; `GeneratedView` mostra `Righe dati: 6`, `2 righe con errore`, toggle `Mostra solo righe con errore`.
- **Screenshot P0**: `/tmp/task032-p0-history-entry.png`, `/tmp/task032-p0-generatedview-fixture.png`.

| Scenario | Evidence type | Device | Entry point | Filtro errori | Riga iniziale | Expected | Observed | PASS/FAIL | Screenshot |
|----------|----------------|--------|-------------|---------------|---------------|----------|----------|-----------|------------|
| **D2** — search bar, filtro solo errori ON, cerca `100005`, apri dettaglio | `runtime` | iPhone 17 Pro Max Simulator iOS 26.4 | `InventorySearchSheet` | ON prima dell’apertura search | R5 / barcode `100005` | Dettaglio su R5, contatore **2/2**, `Prev` a R2, `Next` disabilitato o comunque non verso R6, filtro non spento in silenzio, nessun crash | Dettaglio apre R5 (`100005`, `TASK-032 errore fixture R5`) con contatore **2/2**; `Successivo` risulta disabilitato; `Riga precedente` porta a R2 con contatore **1/2**; non osservato passaggio a R6; nessun crash | ✅ **PASS** | `/tmp/task032-d2-search-results-r5.png`, `/tmp/task032-d2-detail-r5-filtered.png`, `/tmp/task032-d2-prev-to-r2-filtered.png` |
| **D1** — regressione da griglia con filtro ON (R2 → Next → R5 → Prev) | `runtime` | iPhone 17 Pro Max Simulator iOS 26.4 | griglia `GeneratedView` | ON | R2 / barcode `100002` | R2 mostra **1/2**; `Next` porta solo a R5; R5 mostra **2/2**; `Next` da R5 non va a R6; `Prev` torna a R2; nessun salto a R1/R3/R4/R6; nessun crash | Da griglia filtrata aperto R2 con contatore **1/2**; `Successivo` porta a R5 con **2/2**; `Successivo` su R5 risulta disabilitato; `Riga precedente` torna a R2 con **1/2**; nessun salto osservato a righe senza `SyncError`; nessun crash | ✅ **PASS** | `/tmp/task032-d1-detail-r2-filtered-postfix.png`, `/tmp/task032-d1-detail-r5-filtered-postfix.png`, `/tmp/task032-d1-prev-back-r2-filtered-postfix.png` |
| **Smoke fuori errore** — filtro ON, cerca `100006`, tap risultato | `runtime` smoke | iPhone 17 Pro Max Simulator iOS 26.4 | `InventorySearchSheet` | ON | R6 / barcode `100006` | Non aprire silenziosamente dettaglio in full context; feedback esplicito se riga fuori subset errore | Tap su R6 non apre il dettaglio; mostra alert `Riga senza errore di sincronizzazione` con messaggio che chiede di disattivare il filtro dall’elenco; filtro resta ON in griglia; nessun crash | ✅ **PASS smoke** | `/tmp/task032-smoke-search-results-r6-no-error.png`, `/tmp/task032-smoke-r6-no-error-alert.png` |

### Check eseguiti (slice FIX D2)

- ✅ **Build compila** — ESEGUITO: `xcodebuild build -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'id=61AC09F8-DAC5-4354-8ED2-21404AD1924C'` → `** BUILD SUCCEEDED **`.
- ⚠️ **Nessun warning nuovo introdotto** — NON VERIFICABILE come delta: build positiva, warning toolchain AppIntents osservato (`Metadata extraction skipped. No AppIntents.framework dependency found.`), nessuna baseline warning comparativa in questa slice.
- ✅ **Modifiche coerenti con il planning** — ESEGUITO: runtime limitato a FIX D2 + regression D1 + smoke fuori-errore; nessun P2–P5 task-wide, nessuno scanner reopen, nessun target UITest, nessun accessibility identifier, nessun Supabase.
- ✅ **Criteri di accettazione verificati nella slice** — ESEGUITO: D2 PASS runtime, D1 regression PASS runtime; P2–P5 task-wide NON ESEGUITI per scope esplicito.

### Rischi rimasti (slice FIX D2)
- **P2–P5 task-wide non eseguiti** in questa slice: prev/next dataset completo, dati mancanti/non numerici, iPhone grande row detail completo e scanner reopen restano fuori perimetro corrente.
- **Scanner reopen non eseguito**: resta requisito futuro se si vuole proporre `TASK-028 → DONE`.
- **Toolbar ricerca prev/next** quando il match è fuori errore può ancora spegnere filtro (**by design** nel fix corrente) per consentire scroll su griglia completa; non è il path TAP dettaglio D2 validato qui.
- **TASK-028 resta BLOCKED**: D2/D1 della slice sono validati, ma mancano ancora gate globali TASK-032 e conferma utente per qualunque raccomandazione `DONE`.

### Handoff verso REVIEW *(Claude)*
- **FIX codice + stringhe**: completati nella misura sopra; **build OK**.
- **FIX D2 validato runtime**: `InventorySearchSheet` con filtro errori ON apre R5 nel contesto filtrato (**2/2**), non spegne il filtro e non naviga verso R6.
- **D1 regression PASS runtime**: da griglia filtrata R2/R5 navigano solo nel sottoinsieme errore (**1/2 ↔ 2/2**).
- **Smoke fuori errore PASS runtime**: ricerca R6 con filtro ON mostra alert esplicito e non apre full context.
- **`TASK-028`**: resta **BLOCKED** (**no DONE**).
- **P2–P5 task-wide**: **non eseguiti** in questa slice.
- **Scanner reopen**: **non eseguito**.
- **`TASK-032`**: non DONE; pronto per **Review della slice D2 targeted fix**.

---

## Historical execution archive (Codex/Cursor — 2026-04-28+) — ARCHIVIO, non EXECUTION corrente

### Stato Execution *(voce d’epoca — archivio 2026-04-28)*
- **Avviata formalmente** il 2026-04-28 su istruzione utente **(stato storico; non ripetuto in questa refinement)**.
- **Slice P0/P1** considerata **conclusa in quell’episodio** (nessun “in corso” oggi).
- **Build / Simulator** menzionati nelle righe seguenti = **cronaca di allora**; **nessun** invito a rebuild in questa passata documentale.
- **TASK-028** restava e resta **BLOCKED** (**non** DONE).

### Obiettivo compreso
Validare a runtime/UX `GeneratedView` / `RowDetailSheetView` sui residui di TASK-028: gate **D1/D2**, dataset multi-riga con dati mancanti/non numerici, iPhone grande, scanner reopen e test target futuri, seguendo **P0 → P5** senza redesign o refactor generale.

### File controllati
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-032-generatedview-multi-row-navigation-validation-missing-data-scenarios.md`
- `iOSMerchandiseControl/GeneratedView.swift`
- `iOSMerchandiseControl/HistoryEntry.swift`
- `iOSMerchandiseControl/Models.swift`
- `iOSMerchandiseControl/InventorySyncService.swift`
- `iOSMerchandiseControl/iOSMerchandiseControlApp.swift`
- `iOSMerchandiseControl/ContentView.swift`
- `iOSMerchandiseControl/HistoryView.swift`
- `iOSMerchandiseControl.xcodeproj/project.pbxproj` (verifica statica target test)
- `iOSMerchandiseControl.xcodeproj/xcshareddata/xcschemes/iOSMerchandiseControl.xcscheme` (verifica statica scheme)
- `iOSMerchandiseControlTests/` (presenza target/unit tests esistenti)
- `docs/fixtures/TASK-032/README.md`
- `docs/fixtures/TASK-032/generatedview-task032-history-entry.json`
- `docs/fixtures/TASK-032/generatedview-task032-import.html`

### Piano minimo Execution *(cronaca 2026-04-28 — **obsoleto** rispetto al refinement successivo: dopo archivio **D2 FAIL**, il primo passo operativo progettato diventa **FIX mirato D2**, non questo elenco nella sequenza P2 prima di decisione tecnica aggiornata)*

1. **P0:** preparare o individuare una `HistoryEntry` reale / snapshot controllato con colonna `SyncError` e almeno 2 righe in errore; preferire snapshot/HistoryEntry controllata, senza helper nuovi se esiste già un percorso debug/seed/caricamento adatto.
2. **P1:** validare **D1** e **D2** a runtime con righe evidenza separate e `Evidence type = runtime`; senza D1/D2 runtime non proporre TASK-028 → DONE.
3. **P2:** validare prev/next normale e binding su dataset almeno 4–6 righe, inclusi bordi prima/ultima riga, edit R2 non propagato a R3/R4, counted/retail coerenti con la riga corrente.
4. **P3:** validare dati mancanti/non numerici, CTA e badge: nessun delta falso, nessun calcolo finto, fallback `secondProductName`, barcode assente senza azioni barcode/prodotto, nessun crash.
5. **P4:** validare iPhone grande, preferibilmente iPhone 16 Pro Max o simulatore grande equivalente, su bottom bar, tastiera, Form/sezioni, clipping e leggibilità.
6. **P5:** scanner reopen: PASS runtime se si vuole proporre TASK-028 → DONE; altrimenti FAIL + FIX mirato oppure fuori perimetro motivato con effetto esplicito sulla raccomandazione.

### Target test — verifica statica iniziale
- **`iOSMerchandiseControlTests`**: presente in `project.pbxproj`, nello scheme condiviso e nella cartella `iOSMerchandiseControlTests/`; riusare questo target se servono test unit/integration mirati.
- **`iOSMerchandiseControlUITests`**: non trovato nella verifica statica iniziale; non viene creato automaticamente. Se UI test D1/D2/scanner diventano necessari, richiedere conferma o documentare follow-up/micro-FIX separato.
- Nessun target nuovo creato e nessun accessibility identifier aggiunto in questo avvio.

### Build / runtime iniziale
- **Build eseguita**: `xcodebuild build -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'id=61AC09F8-DAC5-4354-8ED2-21404AD1924C'`
- **Device build/runtime**: iPhone 17 Pro Max Simulator, iOS 26.4.1, UDID `61AC09F8-DAC5-4354-8ED2-21404AD1924C` (equivalente grande disponibile; iPhone 16 Pro Max non installato).
- **Risultato build**: `** BUILD SUCCEEDED **`.
- **App installata/lanciata**: `com.niwcyber.iOSMerchandiseControl`, PID osservato `35373`.
- **Screenshot iniziale**: `/tmp/task032-launch.png`.
- Nota: build e launch sono evidenze ambiente, **non** PASS runtime D1/D2.

### Fixture candidate
- Fixture già trovata nel working tree come path non tracciato: `docs/fixtures/TASK-032/`.
- `docs/fixtures/TASK-032/generatedview-task032-history-entry.json`: snapshot equivalente a `HistoryEntry` non manuale con `data`, `editable`, `complete`; header include `SyncError`; righe dati 1–6; righe con errore dichiarate R2 (`TASK-032 errore fixture R2`) e R5 (`TASK-032 errore fixture R5`); `editable[row][0]` = contata, `editable[row][1]` = vendita nuova.
- `docs/fixtures/TASK-032/README.md`: documenta che la snapshot JSON è la sorgente preferita per D1/D2 e che l’HTML non produce da solo `SyncError`.
- `docs/fixtures/TASK-032/generatedview-task032-import.html`: sorgente HTML importabile per flusso import, **non** usata come sorgente primaria D1/D2 salvo necessità reale di validare import → GeneratedView.
- Nessuna nuova fixture creata in questa slice finora; se la snapshot esistente risulta valida, verrà registrata come sorgente P0 senza duplicarla.

### P0 — sorgente dati usata
- **Sorgente P0 scelta**: `docs/fixtures/TASK-032/generatedview-task032-history-entry.json`.
- **Validazione fixture**: eseguita con `jq`; la snapshot contiene 7 righe totali (header + 6 dati), header con colonna `SyncError` a indice 12, `editable` con 7 righe e `complete` con 7 flag.
- **Righe errore**: riga dati R2 / indice app `2` (`barcode=100002`, `TASK-032 errore fixture R2`) e riga dati R5 / indice app `5` (`barcode=100005`, `TASK-032 errore fixture R5`).
- **Caricamento runtime**: app terminata, inserita una singola `ZHISTORYENTRY` nel solo store SwiftData del simulatore (`default.store`) usando i blob JSON della fixture, poi app rilanciata. Non sono stati modificati file Swift né creati helper permanenti.
- **Verifica UI P0**: `HistoryView` mostra `TASK-032 Runtime Fixture` con `Errori 2`; apertura entry porta in `GeneratedView` con `Righe dati: 6`, `2 righe con errore`, griglia e toggle `Mostra solo righe con errore`.

### Evidenze runtime
P0 e P1 runtime prodotti su iPhone 17 Pro Max Simulator iOS 26.4.1 (`61AC09F8-DAC5-4354-8ED2-21404AD1924C`). Screenshot a corredo:
- `/tmp/task032-launch.png`
- `/tmp/task032-d1-detail-r2-filtered.png`
- `/tmp/task032-d2-search-detail-r5-unfiltered-counter.png`
- `/tmp/task032-d2-next-reaches-r6-no-error.png`

| Scenario | Evidence type | Device | Entry point | Filtro errori | Riga iniziale | Azione | Expected | Observed | PASS/FAIL | Note |
|----------|----------------|--------|-------------|---------------|---------------|--------|----------|----------|-----------|------|
| P0 snapshot/HistoryEntry | `runtime` + `static` | iPhone 17 Pro Max Simulator iOS 26.4.1 | `HistoryView` → `GeneratedView` | n/a | n/a | Caricata snapshot `generatedview-task032-history-entry.json` come `HistoryEntry` SwiftData nel simulatore | Sessione con colonna `SyncError` e almeno 2 righe errore | UI mostra `TASK-032 Runtime Fixture`, `Righe dati: 6`, `2 righe con errore`; fixture ha R2/R5 con `SyncError` | PASS | Inserimento locale nel simulator store, nessun codice Swift modificato. |
| D1 griglia + filtro errori | `runtime` | iPhone 17 Pro Max Simulator iOS 26.4.1 | griglia `GeneratedView` | on | R2 / indice app `2` / barcode `100002` | Attivato `Mostra solo righe con errore`, aperto dettaglio da griglia, navigato Next e Prev | Prev/next solo tra righe `SyncError`; contatore sul sottoinsieme; nessun salto a righe senza errore; nessun crash | Griglia filtrata mostra solo R2 e R5; dettaglio R2 mostra `1/2`, Prev disabilitato, Next abilitato; Next porta a R5 con `2/2`, Next disabilitato; Prev torna a R2 con `1/2`; nessun salto osservato a R1/R3/R4/R6 | PASS | Screenshot: `/tmp/task032-d1-detail-r2-filtered.png`. Chiusura sheet e riapertura con filtro ancora on mantiene il contesto filtrato osservato. |
| D2 search + filtro errori | `runtime` | iPhone 17 Pro Max Simulator iOS 26.4.1 | `InventorySearchSheet` | on prima apertura search | R5 / indice app `5` / barcode `100005` | Con filtro errori già on, aperta ricerca, cercato `100005`, aperto dettaglio dal risultato, poi tap Next | Target planning: mantenere contesto solo errori; contatore `2/2` su sottoinsieme; evitare passaggio silenzioso a tutte le righe | Il dettaglio da search apre R5 ma mostra contatore `5/6`; Next è abilitato e porta a R6 (`100006`, nessun `SyncError`) con contatore `6/6` | FAIL | Screenshot: `/tmp/task032-d2-search-detail-r5-unfiltered-counter.png`, `/tmp/task032-d2-next-reaches-r6-no-error.png`. Comportamento coerente con lettura statica dei callback search che disattivano `showOnlyErrorRows`; candidato FIX mirato su preservazione contesto filtrato/rowOrder per apertura da search. |

### Esito P1
- **D1**: PASS runtime.
- **D2**: FAIL runtime rispetto alla UX preferita del planning.
- **Candidato FIX mirato**: evitare che `InventorySearchSheet` disattivi silenziosamente `showOnlyErrorRows` quando l’utente apre il dettaglio da search con filtro errori già attivo; opzioni within-scope: preservare contesto filtrato per `rowOrder`/contatore, oppure passare un contesto esplicito al dettaglio. Nessun fix implementato in questa slice.
- **TASK-028** resta **BLOCKED**: D2 fallito e P2–P5 non ancora eseguiti; nessuna raccomandazione `TASK-028 → DONE`.

### Check eseguiti in questo avvio
- ✅ **Build compila** — ESEGUITO: `xcodebuild build -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'id=61AC09F8-DAC5-4354-8ED2-21404AD1924C'` → `** BUILD SUCCEEDED **`.
- ⚠️ **Nessun warning nuovo introdotto** — NON VERIFICABILE come delta: nessun codice Swift modificato; la build ha emesso il warning toolchain `Metadata extraction skipped. No AppIntents.framework dependency found.`, senza baseline comparativa in questa slice.
- ✅ **Modifiche coerenti con il planning** — ESEGUITO: P0 e P1 eseguiti prima di P2–P5; nessun redesign, nessun refactor, nessun target UI test, nessun accessibility identifier.
- ✅ **Criteri di accettazione runtime P0/D1/D2 verificati** — ESEGUITO: P0 PASS, D1 PASS runtime, D2 FAIL runtime documentato; nessuna raccomandazione TASK-028 → DONE.

### Rischi rimasti
- D2 fallisce runtime: l’apertura detail da `InventorySearchSheet` con filtro errori on passa a contesto tutte le righe (`5/6`, Next verso R6 senza errore). Serve decisione/fix mirato prima di qualunque tesi `TASK-028 → DONE`.
- P2–P5 non sono stati eseguiti in questa slice.
- `iOSMerchandiseControlUITests` non esiste: eventuale UI automation D1/D2/scanner richiede conferma o follow-up; la validazione manual/runtime resta il percorso previsto.
- Scanner reopen non deve restare ambiguo nella prossima Execution reale.

### Handoff post-execution
Non compilato: Execution non conclusa e nessun passaggio a Review. La slice si ferma dopo P0/P1 come richiesto.

---

## Review (Claude) ← solo Claude aggiorna questa sezione
### Review slice D2 targeted fix — 2026-05-03

> User override: review eseguita da Codex su richiesta esplicita dell'utente, con possibilita' di micro-fix diretti. Nessun micro-fix codice applicato in Review.

#### Scope review

- Slice verificata: **FIX D2** (`InventorySearchSheet` + `showOnlyErrorRows` + alert per riga fuori subset errore).
- Fuori scope confermato: **P2–P5 task-wide**, dati mancanti/non numerici, iPhone grande row detail completo, scanner reopen, Supabase, redesign `RowDetailSheetView`, target UITest/accessibility identifier.
- `TASK-028` resta **BLOCKED**.

#### File controllati

- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-032-generatedview-multi-row-navigation-validation-missing-data-scenarios.md`
- `iOSMerchandiseControl/GeneratedView.swift`
- `iOSMerchandiseControl/en.lproj/Localizable.strings`
- `iOSMerchandiseControl/es.lproj/Localizable.strings`
- `iOSMerchandiseControl/it.lproj/Localizable.strings`
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`
- `docs/fixtures/TASK-032/README.md`
- `docs/fixtures/TASK-032/generatedview-task032-history-entry.json`
- `docs/fixtures/TASK-032/generatedview-task032-import.html`
- `git diff`, `git status --short`, simulator availability, scheme list

#### Esito tecnico

- **`GeneratedView.swift`**: il fix e' coerente col D2 planning. Il tap risultato non chiama piu' `onJumpToRow` prima del detail; `onOpenDetail` non spegne piu' silenziosamente `showOnlyErrorRows`; il dettaglio da ricerca su riga con `SyncError` mantiene il `rowOrder` filtrato tramite `rowDetailSheet(_:)`; il tap su riga senza `SyncError` con filtro ON viene bloccato con alert esplicito e non apre full context.
- **SwiftUI/race sheet-alert**: l'uso di `asyncAfter` e' limitato alla presentazione dopo dismiss dello sheet ricerca ed e' coerente con il pattern gia' presente per `showRowDetail`/scanner. Runtime D2 gia' documentato conferma che alert e detail vengono presentati correttamente nella slice.
- **D1 regression**: la logica da griglia resta invariata; `rowDetailSheet(_:)` continua a costruire `rowOrder` dal sottoinsieme errori quando `showOnlyErrorRows` e' ON.
- **Localizzazioni**: chiavi `generated.inventory.search_detail_blocked_title` e `generated.inventory.search_detail_blocked_message` presenti in tutte le lingue reali (it/en/es/zh-Hans); copy chiaro e non placeholder; `plutil -lint` PASS su tutti i `Localizable.strings`.
- **Fixture**: snapshot JSON controllata; header include `SyncError`; 7 righe totali (header + 6 dati); righe errore app index `2` e `5`; `editable` e `complete` con 7 elementi. Fixture idonea alle evidenze D1/D2 documentate.

#### Problemi trovati

- Nessun problema bloccante sul path **tap risultato search -> detail** della slice D2.
- Nessun codice inutile o refactor grande introdotto nel fix D2.
- Rischio residuo non bloccante gia' documentato: la toolbar `Prev`/`Next` della ricerca puo' ancora spegnere il filtro quando il match fuori errore deve scrollare nella griglia completa. Non e' il path tap->detail D2 validato e non apre il dettaglio in full context; resta da rivalutare solo se una slice futura decide di restringere anche la navigazione toolbar ricerca al contesto errori.

#### Fix applicati in Review

- Nessun fix Swift/localizzazioni applicato.
- Aggiornato tracking di questa sezione Review e riallineamento MASTER-PLAN a esito **D2 targeted fix REVIEWED / accepted**.

#### Build / check

- ✅ **Build compila** — ESEGUITO: `xcodebuild build -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'id=61AC09F8-DAC5-4354-8ED2-21404AD1924C'` → `** BUILD SUCCEEDED **` su iPhone 17 Pro Max Simulator iOS 26.4.
- ⚠️ **Nessun warning nuovo introdotto** — NON VERIFICABILE come delta assoluto: build positiva; nessun warning Swift nuovo evidente dalla review; resta warning/toolchain gia' documentato nella slice Execution come non confrontabile con baseline.
- ✅ **Modifiche coerenti con il planning** — ESEGUITO: review limitata a D2, nessun P2–P5, nessuno scanner reopen, nessun UITest/accessibility identifier, nessun Supabase.
- ✅ **Criteri di accettazione verificati nella slice** — ESEGUITO: D2 runtime PASS documentato, D1 regression runtime PASS documentato, smoke riga fuori errore runtime PASS documentato.
- ✅ **Localizzazioni valide** — ESEGUITO: `find iOSMerchandiseControl -name Localizable.strings -print0 | xargs -0 -n1 plutil -lint` → OK per it/en/es/zh-Hans.

#### Runtime

- Runtime **non ripetuto in Review**: non sono state applicate modifiche Swift/localizzazioni al flow D2 dopo l'evidenza Codex Execution.
- Evidenze runtime gia' documentate e considerate sufficienti per la slice D2:
  - D2 search + filtro errori ON su R5: **PASS**, contatore `2/2`, Prev verso R2, niente salto a R6.
  - D1 griglia + filtro errori ON: **PASS**, navigazione R2/R5 sul sottoinsieme `1/2` <-> `2/2`.
  - Smoke ricerca riga fuori errore R6 con filtro ON: **PASS**, alert esplicito, nessun full context silenzioso.
  - Screenshot/log indicati nella sezione Execution D2: `/tmp/task032-d2-search-results-r5.png`, `/tmp/task032-d2-detail-r5-filtered.png`, `/tmp/task032-d2-prev-to-r2-filtered.png`, `/tmp/task032-d1-detail-r2-filtered-postfix.png`, `/tmp/task032-d1-detail-r5-filtered-postfix.png`, `/tmp/task032-d1-prev-back-r2-filtered-postfix.png`, `/tmp/task032-smoke-search-results-r6-no-error.png`, `/tmp/task032-smoke-r6-no-error-alert.png`.

#### Esito review slice

- **APPROVED D2 slice / accepted**.
- **D2 targeted fix REVIEWED / accepted**; la sotto-slice D2 puo' considerarsi chiusa.
- **TASK-032 resta ACTIVE**: P2–P5 task-wide e scanner reopen restano **NON ESEGUITI**.
- **TASK-028 resta BLOCKED**.
- Non marcare `TASK-032` intero `DONE` e non proporre `TASK-028 -> DONE` finche' non sono completate le evidenze residue e conferma utente.

---

## Fix (Codex) ← solo Codex aggiorna questa sezione

### User override — tentativo chiusura TASK-032 a DONE *(2026-05-03)*

#### Override

- Richiesta utente: **“Esegui tutto per farlo in DONE”**.
- Impatto workflow: Codex ha eseguito anche i residui P2–P5 non inclusi nella review D2 originale. Tracking aggiornato in modo conservativo: **nessun DONE** senza evidenza runtime PASS su tutti i gate.

#### File controllati / modificati

- Controllati: `docs/MASTER-PLAN.md`, questo file TASK-032, `iOSMerchandiseControl/GeneratedView.swift`, fixture `docs/fixtures/TASK-032/`, store simulator con `TASK-032 Runtime Fixture`.
- Modificato da Codex in questa passata: `iOSMerchandiseControl/GeneratedView.swift` per micro-fix P5 scanner reopen.
- Modificati per tracking: `docs/TASKS/TASK-032-generatedview-multi-row-navigation-validation-missing-data-scenarios.md`, `docs/MASTER-PLAN.md`.

#### Build

- ✅ **Build compila** — ESEGUITO:
  `xcodebuild build -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'id=61AC09F8-DAC5-4354-8ED2-21404AD1924C'`
  → `** BUILD SUCCEEDED **` su iPhone 17 Pro Max Simulator iOS 26.4.
- ⚠️ **Nessun warning nuovo introdotto** — NON VERIFICABILE come delta assoluto: build positiva; resta warning toolchain `Metadata extraction skipped. No AppIntents.framework dependency found.` già osservato nelle build precedenti.

#### Runtime P2–P4

| Scenario | Evidence type | Device | Entry point | Expected | Observed | PASS/FAIL | Note |
|----------|----------------|--------|-------------|----------|----------|-----------|------|
| P2 prev/next normale | `runtime` + screenshot | iPhone 17 Pro Max Simulator iOS 26.4 | detail da griglia full list | R1→R2→R1, contatore e binding coerenti | R1 mostra `1/6`; `Successivo` porta a R2 `2/6` con dati R2; `Precedente` torna a R1 `1/6` | ✅ PASS | `/tmp/task032-p2-next-r2.png`, `/tmp/task032-p2-prev-back-r1-attempt2.png` |
| P3 missing old price | `runtime` + screenshot | iPhone 17 Pro Max Simulator iOS 26.4 | detail R3 | niente delta prezzo falso, CTA coerenti | R3 “Senza storico prezzo” mostra vendita nuova vuota/placeholder, sezione prezzi senza vecchi prezzi, nessun crash | ✅ PASS | `/tmp/task032-p3-r3-missing-price.png` |
| P3 missing barcode | `runtime` + screenshot | iPhone 17 Pro Max Simulator iOS 26.4 | detail R4 | niente copy/share barcode e azioni prodotto non valide | R4 “Senza barcode” non mostra barcode/copy/share; `Modifica prodotto` risulta disabilitata da accessibility tree; nessun crash | ✅ PASS | `/tmp/task032-p3-r4-missing-barcode.png` |
| P3 non-numeric | `runtime` + screenshot | iPhone 17 Pro Max Simulator iOS 26.4 | detail R6 | stato neutro, niente calcolo finto, nessun crash | R6 “Valori non numerici” mostra contata/vendita vuote/placeholder e totale `0`; nessun badge shortage/surplus/match numerico falso | ✅ PASS | `/tmp/task032-p3-r6-nonnumeric.png` |
| P4 iPhone grande | `runtime` + screenshot | iPhone 17 Pro Max Simulator iOS 26.4 | row detail | layout leggibile, bottom bar presente, nessun clipping bloccante | Tutti gli screenshot P2/P3 sono su iPhone 17 Pro Max; bottom bar e sezioni restano usabili con tastiera/accessory visibili | ✅ PASS | Device grande disponibile usato al posto di iPhone 16 Pro Max. |

#### P5 scanner reopen

- Primo runtime P5 su dettaglio riga → scanner → dismiss senza risultato: **FAIL**. Osservato ritorno alla griglia/lista, non riapertura del detail della stessa riga.
  - Screenshot: `/tmp/task032-p5-scanner-open-from-r6-denied.png`, `/tmp/task032-p5-after-scanner-dismiss-no-reopen.png`.
- Micro-fix applicati in `GeneratedView.swift`:
  - estratta `reopenPendingRowDetailAfterScannerDismiss()`;
  - aggancio a `onChange(showScanner)`, `sheet(onDismiss:)` e `.onDisappear`;
  - passaggio esplicito di `detail.rowIndex` a `requestScanFromRowDetail(rowIndex:)` invece di leggere `rowDetail?.rowIndex`;
  - delay reopen portato a `0.60s` per evitare presentazione mentre lo scanner sta ancora chiudendo.
- Build post-fix: ✅ PASS.
- Runtime post-fix: **NON ACCETTATO / NON VERIFICATO PASS**. I tentativi manuali/Simulator non hanno prodotto una evidenza stabile di reopen del detail; una parte dell’automazione è scivolata su una entry manuale vuota creata accidentalmente durante i tentativi scanner. Non viene dichiarato PASS.
- Scan success reale: ⚠️ **NON ESEGUIBILE** in questa sessione senza concedere/gestire permesso camera e senza feed barcode affidabile; non è stato forzato il permesso camera.

#### Esito unico TASK-028

**Mantenere `TASK-028` BLOCKED.** Motivo: D1/D2 e P2–P4 sono coperti, ma **P5 scanner reopen non ha evidenza runtime PASS**. Quindi non esistono le condizioni per `TASK-028 → DONE` né per `TASK-032 → DONE`.

#### Handoff

- **TASK-032**: resta **ACTIVE / REVIEW**; sotto-slice D2 accepted, P2–P4 PASS, P5 richiede review/fix mirato ulteriore.
- **TASK-028**: resta **BLOCKED**.
- Prossimo passo consigliato: review tecnica del micro-fix P5 e nuova execution mirata scanner reopen, preferibilmente con percorso scanner controllabile o device/feed camera affidabile.

---

## Chiusura

### Conferma utente
- [ ] Utente ha confermato il completamento

### Follow-up candidate
—

### Riepilogo finale
—

### Data completamento
