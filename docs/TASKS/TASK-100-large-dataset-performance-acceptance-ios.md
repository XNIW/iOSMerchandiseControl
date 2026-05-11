# TASK-100 — Large dataset performance acceptance iOS

## 1. Titolo e stato

| Campo | Valore |
|-------|--------|
| **Task ID** | **TASK-100** |
| **Titolo** | **Large dataset performance acceptance iOS** |
| **File task** | `docs/TASKS/TASK-100-large-dataset-performance-acceptance-ios.md` |
| **Stato task** | **DONE** |
| **Fase attuale** | **Chiusura — REVIEW PASS FINAL** |
| **Responsabile attuale** | **Utente / Claude** — accettazione finale registrata *(2026-05-10)* |
| **Data creazione** | 2026-05-10 |
| **Ultimo aggiornamento** | 2026-05-10 — **Chiusura formale** dopo final acceptance utente/Claude |

**TASK-100 è chiuso come DONE** con esito **Chiusura — REVIEW PASS FINAL**.

**Note di chiusura (2026-05-10):**

- TASK-100 chiuso dopo **final acceptance** utente/Claude (superata la riserva policy-repo che impediva a Codex di marcare DONE).
- **Minimum closure**, **physical device**, **D100-L**, live Supabase **write/read/preview** e **cleanup live scoped** sono tutti verificati (**PASS**).
- Cleanup Supabase eseguito **senza** modifiche a policy/grant/schema, usando **admin/postgres** con delete **solo** sul prefisso test (`TASK100_LIVE_1778463255_*`).
- **Nessun** dato residuo per prefisso `TASK100_LIVE_1778463255_` (0 righe post-verifica).
- **Nessun** claim **production-ready globale 100%** — restano limiti dichiarati nel perimetro TASK-100 / evidence pack.
- Prima di questo turno **TASK-101** e **TASK-102** non erano ancora aperti; **TASK-101** è stato inizializzato nel MASTER come **ACTIVE / PLANNING** dopo la chiusura di TASK-100.

**Flag storico:** **`TASK-100_PLANNING_INIT_ONLY`** — **OBSOLETO** (superato da execution + review + chiusura).

---

## 2. Contesto

| Riferimento | Ruolo per TASK-100 |
|-------------|-------------------|
| **TASK-099** | Chiuso **DONE / Chiusura — REVIEW PASS** — conflict/recovery hardening iOS; definisce tolleranza UX/auth/RLS/stale da non contraddire quando si misura performance su percorsi Release/sync. |
| **TASK-089** | **Riferimento storico** per benchmark large dataset: harness DEBUG `Task089SyntheticBenchmarkHarness`, XCTest `Task089LargeDatasetBenchmarkTests`, dataset sintetico **D89-M** (`TASK089_*`, ordini di grandezza documentati); esiti **LG1–LG3 PARTIAL** motivati, **LG4** PASS su VM/cancel, **LG5/S89-E** SKIPPED senza Go §10 — TASK-100 **non** ripropone quei risultati come acceptance finale né come «production-ready». |
| **TASK-096** | Acceptance composita Release semi-auto (XCTest/fake primari); stabilisce che integrazione moduli esiste ma **non** sostituisce misura volumetrica reale/device. |
| **TASK-097** | Smoke runtime sandbox iOS→Supabase→iOS (`TASK097_*`); modello evidenze privacy-safe e collision scan prima delle write — riuso concettuale se TASK-100 toccherà sandbox **solo dopo** gate espliciti. |
| **TASK-098** | Smoke cross-platform (`TASK098_*`); conferma parity ProductPrice **current/previous** su piccolo dataset — TASK-100 è **iOS-first** e **non** richiede Android in questo planning. |
| **Policy recovery/auth/RLS da TASK-099** | Acceptance grande dataset deve verificare che retry/cancel non mascherino stati bloccanti né violino precedence auth > permission/RLS > stale. |
| **TASK-101** | Dopo chiusura TASK-100: inizializzato **ACTIVE / PLANNING** (solo markdown, audit privacy/RLS/security) — vedi `docs/TASKS/TASK-101-production-readiness-privacy-rls-security-audit.md`. |
| **TASK-102** | Resta **TODO / Planning — non aperto**; **nessun** file task. |

---

## 3. Obiettivo

1. **Definire** un acceptance **reale e misurabile** per performance iOS con **dataset grande** (ordini di grandezza definiti come **D100-S / D100-M / D100-L**, vedi §6), coprendo: import/export Excel (flussi app esistenti), **sync preview / manual sync** Release, **pending / planner** dove impattano volumi, **ProductPrice** e storico locale ampio.
2. **Separare** chiaramente i tipi di prova e il peso delle conclusioni:
   - benchmark **sintetico** (XCTest/harness, come lineage TASK-089);
   - **Simulator** (massimo **PARTIAL** per CPU/memoria/realismo salvo eccezioni documentate);
   - **device fisico** (preferito per PASS su UX/memoria/tempo percepito);
   - **Supabase sandbox** vs **live** — solo con manifest e consenso; read/write dichiarati per scenario;
   - **manual UI smoke** (evidenza screenshot/checklist, non sostituto di tutti i gate automatici).
3. **Evitare** claim **production-ready globale** o **PASS 100%** end-to-end: esiti ammessi dalla matrice §7: **PASS**, **PARTIAL**, **BLOCKED** per area o scenario.
4. Trasformare i risultati **parziali** già noti da TASK-089 in una **catena di acceptance** più solida: prerequisiti manifest, ripetibilità, confronto Simulator/device, e criteri di stop §12.
5. Integrare una acceptance **UX/UI nativa iOS sotto carico**: progress feedback tempestivo, stati loading/empty/error chiari, azioni distruttive protette, navigazione non confusa, coerenza visuale con il resto dell’app e nessun blocco percepito senza spiegazione.
6. Definire un piano **efficiente**: distinguere verifiche **must-run**, verifiche **nice-to-have**, e verifiche **solo se emerge rischio**, così TASK-100 non diventa un audit infinito.

---

## 4. Non-obiettivi / vietati in questo planning-init

- **Nessun** codice **Swift / SwiftUI / SwiftData** e **nessuna** modifica test.
- **Nessun** **Kotlin / Android** (solo riferimento funzionale fuori da questo file se execution futura lo citasse).
- **Nessun** **SQL / migration / RLS / backend**.
- **Nessun** `Localizable.strings`, **nessun** `project.pbxproj`.
- **Nessuna** nuova dipendenza SPM/CocoaPods.
- **Nessun** write **Supabase live**; sandbox write solo se futura execution con manifest + consenso (non parte di questo turno).
- **Nessun** cleanup **distruttivo** (truncate/wipe/repair di massa).
- **Nessun** dato reale di negozio come fixture.
- **Nessun** introduzione di **Timer**, **BGTask**, **Realtime**, **polling** o **worker** come strategia per «completare» l’acceptance.
- **Nessun** lavoro su **TASK-101** o **TASK-102**.
- **Nessuna** implementazione UI/UX in questo turno: le note UX/UI sono criteri di acceptance e linee guida per futura execution, non modifiche SwiftUI.
- **Nessuna** riscrittura visuale estesa: eventuali ritocchi futuri devono essere piccoli, nativi iOS, coerenti con lo stile già presente e motivati da performance/usabilità sotto carico.
- **Nessuna** dichiarazione **TASK-100 DONE** o **READY FOR EXECUTION** nel presente documento init.
- **Nessuna** creazione di artifact runtime reali: eventuali template evidenze dentro questo file sono solo schema markdown, non log o risultati eseguiti.

---

## 5. Fonti da leggere in futura EXECUTION *(repo-grounded)*

Ordine suggerito (non esecutivo finché non autorizzato):

1. **Import/export Excel + UI flussi file** — `ExcelSessionViewModel`, `ExcelAnalyzer`, `GeneratedView`, `DatabaseView`, viste import/preview/generazione/export, export XLSX (`InventoryXLSXExporter`, `makeProductsXLSX`), percorsi inventario vs database, stati loading/error/empty collegati.
2. **Sync manuale / semi-auto Supabase** — `SupabaseManualSyncViewModel`, coordinator/factory Release, preview bounded (es. limite righe catalogo da policies TASK-091+).
3. **Pending / planner** — `LocalPendingChange`, snapshot provider, planner aggregato TASK-094, RunGate TASK-095.
4. **ProductPrice** — modelli storico, apply/push/dedupe, parity current/previous come in TASK-097/098.
5. **SwiftData models** — fetch ampie, relazioni `Product` ↔ `ProductPrice`, impatto memoria.
6. **XCTest / harness TASK-089** — `Task089LargeDatasetBenchmarkTests`, `Task089SyntheticBenchmarkHarness` (DEBUG-only): baseline da citare/estendere, non copiare esiti come PASS globali.
7. **Componenti UX/UI sotto carico** — toolbar, sheet/dialog, progress indicator, disabled state, cancel/retry, snackbar/alert, empty state e navigazione durante operazioni lunghe; confronto con stile iOS già esistente prima di proporre ritocchi.
8. **Android** — solo se serve confronto **funzionale** documentale; **vietato** porting 1:1 obbligatorio in TASK-100.
9. **Schema Supabase** — **solo read-only** nel clone/documentazione se serve capire paginazione/latenza; **nessuna** DDL da questo task salvo futuro task backend esplicito.

---

## 6. Micro-slice pianificate (**S100-A … S100-K**)

| ID | Titolo | Output atteso (post-review / EXECUTION futura) |
|----|--------|-----------------------------------------------|
| **S100-A** | Repo/state preflight e baseline TASK-089 | Branch/commit, elenco file toccati, replay/resilienza harness LG1–LG4, dichiarazione ambiente (Simulator/device); **nessun** PASS ereditato senza nuova evidenza. |
| **S100-B** | Dataset **D100-S / D100-M / D100-L** sintetici privacy-safe | Prefisso **`TASK100_*`** proposto per artifact remoti (solo dopo collision scan in execution); cardinalità prodotti/fornitori/categorie/prezzi coerenti con obiettivi misura; divieto dati reali. |
| **S100-C** | Import Excel large dataset acceptance | Tempo al primo feedback, completamento o errore controllato, memoria osservabile; ripetibilità con file generato offline. |
| **S100-D** | Export prodotti + export full database acceptance | Separazione scenari (come TASK-089 LG2 vs LG3); dimensione file **aggregata** nelle evidenze (no contenuto business); cancel/interrupt se applicabile. |
| **S100-E** | Sync preview + manual sync large dataset acceptance | Preview read-mostly/dry-run bounded; pianificazione apply/push confermati solo con gate utente; misura latenza batch/pagine dove rilevante. |
| **S100-F** | ProductPrice **current/previous** su dataset grande | Coerenza summary dopo operazioni pesanti; tolleranza monetaria come task precedenti (**≤ 0.005** assoluta solo se confermata in execution come ancora valida); storico molto lungo. |
| **S100-G** | UX responsiveness, first feedback, cancel/retry/recovery | Allineamento a policy TASK-099; niente-successo ottimistico; stati loading/disabled documentati. |
| **S100-H** | Memoria, main-thread safety, paging/batching | Segnali OOM/freeze; uso paginazione esistente; ipotesi N+1 / fetch troppo ampie da confermare con strumenti leggeri o profiling dedicato **solo se autorizzato**. |
| **S100-I** | Evidenze privacy-safe e decisione **PASS / PARTIAL / BLOCKED** | Cartella §11 compilata; matrice §7 aggiornata; niente JWT/segreti; owner/project hash redatti. |
| **S100-J** | UX/UI large dataset acceptance | Verificare criteri di qualità percepita: feedback immediato, progress chiaro, stato disabilitato delle azioni durante operazioni lunghe, errori recuperabili, coerenza con stile SwiftUI esistente; eventuali ritocchi futuri devono privilegiare UX migliore senza copiare Android. |
| **S100-K** | Priorità ed efficienza execution | Classificare ogni verifica come **MUST**, **SHOULD**, **OPTIONAL**, con stop rule: se una misura non cambia la decisione PASS/PARTIAL/BLOCKED, non introdurre strumenti o refactor extra. |

### 6.1 Priorità execution proposta *(ancora Planning)*

Questa classificazione serve a rendere TASK-100 chiudibile e non dispersivo. Va confermata in Planning Review prima di qualsiasi execution.

| Priorità | Slice | Motivazione |
|----------|-------|-------------|
| **MUST** | **S100-A** | Senza preflight/baseline non si può sapere cosa si sta misurando. |
| **MUST** | **S100-B** | Senza dataset sintetico privacy-safe non si può fare acceptance large dataset. |
| **MUST** | **S100-C** | Import Excel è flusso core dell’app e va accettato su dataset grande. |
| **MUST** | **S100-D** | Export prodotti/full DB è parte core e va separato per evitare falsi PASS. |
| **MUST** | **S100-F** | ProductPrice current/previous è rischio funzionale alto sotto volume. |
| **MUST** | **S100-G** | UX responsiveness/cancel/retry evita blocchi percepiti e doppie applicazioni. |
| **MUST** | **S100-I** | Evidenze privacy-safe e decisione PASS/PARTIAL/BLOCKED sono obbligatorie per chiusura. |
| **MUST** | **S100-J** | UX/UI sotto carico deve essere verificata almeno con checklist manuale. |
| **MUST** | **S100-K** | Decision-log e priorità evitano audit infinito. |
| **SHOULD** | **S100-E** | Sync preview/manual sync è importante, ma può essere parziale se Supabase/env non è pronto. |
| **SHOULD** | **S100-H** | Memoria/paging/main-thread safety va verificata con strumenti leggeri; profiling pesante solo se emerge rischio. |
| **OPTIONAL** | Supabase sandbox write reale | Solo con manifest, collision scan, consenso esplicito e ambiente isolato; non necessario per chiudere planning. |
| **OPTIONAL** | Screenshot manuali estesi | Utili per UX review, ma non devono bloccare acceptance se checklist/log bastano. |

### 6.2 Classi dataset D100 proposte *(da confermare in Planning Review)*

Le classi sotto sono **ordini di grandezza iniziali**, non fixture definitive. Servono a evitare ambiguità tra “piccolo”, “medio” e “grande” e a rendere confrontabili le evidenze. I valori reali possono essere ridotti o aumentati in execution se device, tempo o Supabase env lo richiedono; ogni cambio va registrato nel `decision-log.md`.

| Classe | Scopo | Cardinalità indicativa | Vincoli privacy |
|--------|-------|------------------------|-----------------|
| **D100-S** | Smoke veloce / sanity check prima dei test pesanti | ~1k prodotti, ~5k prezzi storici, pochi fornitori/categorie | Solo dati sintetici `TASK100_*`; nessun dato negozio |
| **D100-M** | Acceptance principale bilanciata | ~10k prodotti, ~50k prezzi storici, fornitori/categorie distribuiti | Solo dati sintetici; barcode e nomi generati |
| **D100-L** | Stress mirato, non obbligatorio per ogni scenario | ~50k prodotti, ~250k+ prezzi storici, storico profondo | Solo se device/env reggono; altrimenti PARTIAL documentato |

### 6.3 Ordine consigliato di execution futura *(non attivo ora)*

1. **Preflight**: commit, branch, scheme, device/simulator, manifest vuoto.
2. **D100-S**: validare generatore, import/export base, UX feedback.
3. **D100-M**: eseguire acceptance principale per import/export/ProductPrice/UX.
4. **D100-L**: eseguire solo gli scenari a rischio alto o quelli che D100-M non discrimina.
5. **Sync preview/manual sync**: aggiungere solo dopo aver separato chiaramente client, rete e Supabase policy.
6. **Decisione finale**: compilare M100, CA-T100, rischi residui e stop rule.

### 6.4 Percorso minimo consigliato per chiudere TASK-100 *(anti-audit infinito)*

Per evitare che TASK-100 diventi troppo grande, la futura execution dovrebbe seguire questa regola:

| Livello | Cosa include | Decisione attesa |
|---------|--------------|------------------|
| **Minimum closure** | S100-A, S100-B, S100-C, S100-D, S100-F, S100-G, S100-I, S100-J, S100-K su D100-S + D100-M | Sufficiente per PASS/PARTIAL/BLOCKED iOS locale/import/export/ProductPrice/UX |
| **Extended closure** | Minimum closure + S100-E sync preview/manual sync read-mostly o sandbox isolata | Necessario solo se si vuole includere Supabase nel giudizio TASK-100 |
| **Stress closure** | Extended closure + D100-L mirato + S100-H con profiling leggero/pesante se giustificato | Solo se D100-M non discrimina colli di bottiglia o emergono crash/freeze/memory pressure |

Regola operativa futura: se **Minimum closure** produce già una decisione chiara, non aggiungere test opzionali solo per “completezza”. Gli OPTIONAL devono essere eseguiti solo se cambiano l’esito o riducono un rischio concreto.

---

## 7. Matrice acceptance **M100-01 … M100-12**

Stato iniziale di ogni riga: **PLANNED / NOT RUN**. Durante execution si aggiorna con esito scenario.

| ID | Area | Verifica prevista | Fonte / evidenza prevista | Stato iniziale | PASS | PARTIAL | BLOCKED |
|----|------|-------------------|---------------------------|----------------|------|---------|---------|
| **M100-01** | Preflight / baseline | Replay o confronto baseline harness TASK-089 vs stato codice corrente | Log XCTest mirati, commit hash, nota differenze | PLANNED / NOT RUN | Baseline ripetibile e documentata senza contraddizioni critiche | Una leg LG ereditata senza rerun ma gap giustificati | Baseline assente o mismatch non spiegato |
| **M100-02** | Dataset sintetico | D100-S/M/L generabili riproducibilmente | Script/manifest dimensioni (senza segreti), hash file campione | PLANNED / NOT RUN | Tutte le classi necessarie al piano disponibili | Solo S+M per limiti tempo/env | L non generabile o leak privacy |
| **M100-03** | Import Excel grande | Import file grande senza crash; UX non silenziosa | Tempo primo feedback, esito, eventuale Instruments/memory note | PLANNED / NOT RUN | Completamento o errore controllato + metriche | Solo Simulator o solo S size | Crash/OOM o stallo infinito |
| **M100-04** | Export prodotti | Export molti prodotti — tempo e dimensione | Size aggregata, durata, checksum opzionale privacy-safe | PLANNED / NOT RUN | Metriche complete device o Simulator + conferma UX | Solo Simulator o export senza cancel test | Fallimento silenzioso o corruzione formato |
| **M100-05** | Export full DB | Stesso set separato da export prodotti | Come sopra + conteggio fogli/righe aggregato | PLANNED / NOT RUN | Scenario distinto LG3-analogo documentato | Unificato accidentalmente con export prodotti | OOM o timeout senza recovery |
| **M100-06** | Sync preview / manual sync | Preview bounded su catalogo grande; assenza full reload patologico | Log pagine/batch redatti, XCTest o trace manuale | PLANNED / NOT RUN | UI reattiva + bounded rispettato | Latenza alta ma accettata con soglia motivata | Freeze o N+1 grave confermato |
| **M100-07** | ProductPrice storico | Query/UI su storico molto grande | Conteggio aggregato righe prezzo, tempi summary | PLANNED / NOT RUN | Current/previous coerenti post-step pesanti | Solo subset size | Disallineamento o dedupe fallita |
| **M100-08** | Cancel / retry / recovery | Interrupt operazioni lunghe; coerenza stato con TASK-099 | Screenshot o log stato macchina redatti | PLANNED / NOT RUN | Recovery chiaro senza doppia applicazione | Retry richiede passi manuali extra | Stato incoerente o dati applicati doppi |
| **M100-09** | Supabase (sandbox opz.) | Latenza rete + RLS solo come fattore misurato | Manifest env read/write; note latency redatte | PLANNED / NOT RUN | Scenario sandbox isolato **`TASK100_*`** PASS | Live read-only o sandbox latenza alta | Live write non autorizzato o failure auth |
| **M100-10** | Chiusura evidenze | Manifest + decisione globale area | `docs/TASKS/EVIDENCE/TASK-100/` completo §11 | PLANNED / NOT RUN | Tutte le aree nel perimetro hanno esito dichiarato | Almeno una PARTIAL documentata | Evidenze incomplete o segreti leak |
| **M100-11** | UX/UI sotto carico | Verifica che operazioni lunghe mostrino feedback tempestivo, progress/disabled state coerenti, nessun tap multiplo pericoloso, errori recuperabili | Checklist manuale + eventuali screenshot redatti; note su coerenza con stile app | PLANNED / NOT RUN | UX chiara e coerente senza blocchi muti | UX accettabile ma con friction documentata | UI confusa, azioni duplicate o stato bloccato senza recovery |
| **M100-12** | Efficienza piano | Ogni run produce decisione utile; nessun profiling/tooling superfluo se non cambia l’esito | Decision log con MUST/SHOULD/OPTIONAL e motivazione skip | PLANNED / NOT RUN | Piano eseguito con prove mirate e sufficienti | Alcune prove extra ma motivate | Audit dispersivo o impossibile da chiudere |

---

## 8. Acceptance criteria **CA-T100-01 … CA-T100-14**

*(Soglie numeriche proposte sono **iniziali**: da confermare/ricalibrare in Planning Review ed EXECUTION in base a device target.)*

| ID | Criterio | Misurabilità |
|----|----------|--------------|
| **CA-T100-01** | Esiste **manifest scritto** per ogni run (branch, scheme, device/simulator, classe dataset D100-*, privacy OK) prima di dichiarare esiti. | Checklist nel folder evidenze |
| **CA-T100-02** | **Primo feedback** operazioni lunghe (import/export/sync preview) è **osservabile** entro una soglia **iniziale** da confermare *(es. ordine **≤ 5 s** su device target per azione utente → UI non statica)*; se non misurabile → **PARTIAL** esplicito. | Timestamp/log o screen recording manuale |
| **CA-T100-03** | **Import** Excel sintetico large **completa** o fallisce con messaggio/ stato non crash — **nessun** exit silenzioso. | Log + esito UI |
| **CA-T100-04** | **Export prodotti** e **export full DB** sono verificati come **scenari separati** con metriche **dimensione file aggregate** e durata. | Evidenza numerica aggregata |
| **CA-T100-05** | **Sync preview** su catalogo grande non mostra **freeze infinito**; se paginazione/batch esiste, deve essere **utilizzata** senza caricare tutto il grafo in memoria senza motivo *(da verificare in codice)*. | Trace/static analysis + runtime |
| **CA-T100-06** | **Manual sync** post-preview (se nello scope autorizzato) rispetta review prima di mutazioni; **nessuna** applicazione silenziosa — coerenza TASK-091/096/099. | XCTest esistenti + smoke opzionale |
| **CA-T100-07** | **ProductPrice** current/previous dopo step pesanti restano entro **tolleranza concordata** *(iniziale: stessa **≤ 0.005** assoluta dei task smoke **solo se** ancora valida per execution)* oppure deviazione documentata come **BLOCKED/PARTIAL**. | Confronto aggregato redatto |
| **CA-T100-08** | **Cancel/retry**: dopo cancel, stato UI e dati non devono risultare **applicati due volte** per lo stesso intento utente (idempotenza narrativa). | Caso test o repro manuale |
| **CA-T100-09** | Risultati **Simulator-only** non possono essere etichettati **PASS** globale memoria/performance — massimo **PARTIAL** salvo eccezione motivata nel manifest. | Nota nel manifest |
| **CA-T100-10** | **Nessun** claim «production-ready 100%» nel resoconto TASK-100; solo **PASS/PARTIAL/BLOCKED** per area con residui elencati. | Review testuale evidenze |
| **CA-T100-11** | Durante operazioni lunghe, le azioni che potrebbero duplicare lavoro o corrompere stato devono essere disabilitate, confermate o rese idempotenti a livello UX; se non verificabile → **PARTIAL**. | Checklist UI + caso manuale o test mirato |
| **CA-T100-12** | Eventuali ritocchi UI futuri devono seguire lo stile esistente dell’app: SwiftUI nativo, gerarchia chiara, toolbar/sheet/alert coerenti, niente layout Android 1:1. | Review visiva / screenshot redatti |
| **CA-T100-13** | Ogni criterio deve essere marcato **MUST**, **SHOULD** o **OPTIONAL** prima di execution; i **MUST** sono quelli necessari a decidere PASS/PARTIAL/BLOCKED. | Decision log nel manifest |
| **CA-T100-14** | Se un test pesante richiede strumenti invasivi o tempo eccessivo, va eseguito solo se c’è già un sospetto concreto; altrimenti si documenta skip motivato, non si forza execution. | Decision log skip |

### 8.1 Budget provvisori da confermare *(non soglie finali)*

Questi budget sono **placeholder di Planning** per orientare la review. Non diventano PASS/FAIL automatici finché non vengono confermati su device/env target.

| Area | Budget iniziale | Nota |
|------|-----------------|------|
| Primo feedback UI | Ordine ≤ 5 s dopo azione utente | Serve solo a evitare UI statica; da confermare su device fisico. |
| Operazioni lunghe | Progress/Loading visibile e azioni duplicate protette | Se il tempo reale è alto ma lo stato è chiaro, può essere PARTIAL invece di BLOCKED. |
| Import/export large | Durata e dimensione file sempre registrate | Nessun valore assoluto inventato senza baseline device. |
| Sync preview | Bounded/paginata dove previsto | Se Supabase domina la latenza, separare client vs rete. |
| Memoria | Nessun crash/OOM/jetsam ripetuto | Profiling pesante solo se segnali runtime lo giustificano. |

### 8.2 Checklist UX/UI sotto carico *(criteri di review, non implementazione)*

Questa checklist guida eventuali ritocchi futuri. Se serve scegliere tra alternative, prevale la soluzione più nativa iOS, più leggibile e più sicura per lo stato dati.

| Area UX/UI | Criterio atteso | Direzione preferita se serve ritocco futuro |
|------------|-----------------|---------------------------------------------|
| **Feedback immediato** | Dopo tap su import/export/sync l’utente capisce subito che l’azione è partita | Progress overlay o stato inline coerente con schermata esistente; niente spinner anonimi senza testo |
| **Azioni duplicate** | Bottoni critici non permettono doppio submit mentre il task è in corso | Disabled state visibile, testo azione coerente, nessun tap multiplo pericoloso |
| **Errore recuperabile** | Errori grandi dataset spiegano cosa è fallito e cosa può fare l’utente | Alert/snackbar con messaggio breve + recovery path; evitare testo tecnico grezzo |
| **Cancel/retry** | Cancel e retry non creano stato ambiguo | Preferire confirmationDialog/alert nativi quando c’è rischio dati |
| **Layout sotto carico** | Liste/griglie grandi restano navigabili e leggibili | Mantieni gerarchia visiva esistente; non introdurre redesign o layout Android 1:1 |
| **Accessibilità base** | Stato loading/error non dipende solo dal colore | Testi espliciti, label chiare, touch target nativi |

### 8.3 Rubric decisionale PASS / PARTIAL / BLOCKED

| Esito | Quando usarlo | Nota |
|-------|---------------|------|
| **PASS** | Scenario eseguito nel perimetro dichiarato, evidenze complete, nessun rischio critico aperto | Solo per area/scenario, mai come “production-ready globale” |
| **PARTIAL** | Scenario utile ma limitato da Simulator-only, dataset ridotto, Supabase/env non completo o UX con friction non critica | Deve indicare chiaramente cosa manca per passare a PASS |
| **BLOCKED** | Crash/OOM/perdita dati, tabella evidenze incompleta, privacy/env non sicuri, UI con doppie azioni pericolose non mitigabili | Fermare execution e non forzare workaround fuori scope |

### 8.4 Metriche standard da raccogliere *(schema unico evidenze)*

Ogni scenario eseguito in futura execution dovrebbe produrre una riga normalizzata in `performance-summary.md`, anche se l’esito è PARTIAL o BLOCKED.

| Campo | Obbligatorio | Descrizione |
|-------|--------------|-------------|
| `scenario_id` | Sì | Esempio: `M100-03-D100-M-import-excel` |
| `dataset_class` | Sì | `D100-S`, `D100-M`, `D100-L` o `custom` motivato |
| `device_target` | Sì | Simulator/device fisico, modello, OS, build configuration |
| `row_counts` | Sì | Conteggi aggregati: prodotti, prezzi, fornitori/categorie, righe Excel |
| `file_size_mb` | Sì se import/export | Dimensione aggregata, senza contenuto business |
| `time_to_first_feedback_s` | Sì per UX | Tempo percepito prima di loading/progress/stato visibile |
| `total_duration_s` | Sì | Durata totale o tempo fino a errore controllato |
| `result_state` | Sì | `PASS`, `PARTIAL`, `BLOCKED`, `SKIPPED` |
| `failure_mode` | Se applicabile | Crash, OOM, timeout, auth/RLS, validation, UI freeze, altro |
| `notes_redacted` | Sì | Note senza segreti, senza dati reali, senza barcode reali |

### 8.5 Guardrail UI/UX per ritocchi futuri *(scelte già decise)*

Se durante futura execution emergono micro-frizioni UI/UX, l’executor può proporre o applicare solo ritocchi piccoli e coerenti con questi guardrail, dopo autorizzazione execution:

| Tema | Decisione progettuale preferita |
|------|--------------------------------|
| Loading globale | Usare stato/progress chiaro con testo descrittivo; evitare spinner muto se l’operazione può durare più di pochi secondi |
| Toolbar actions | Durante operazioni lunghe, disabilitare azioni concorrenti o renderle chiaramente non disponibili |
| Errori | Messaggi brevi orientati all’utente + dettaglio tecnico solo se utile nel log/evidenza |
| Recovery | Preferire retry/cancel espliciti; se il rischio dati è alto, usare confirmationDialog/alert nativi |
| Liste grandi | Conservare gerarchia visiva SwiftUI esistente; evitare densità eccessiva, scrolling bloccato o layout copiato da Android |
| Stato vuoto/loading/error | Ogni stato deve avere titolo, breve descrizione e azione primaria quando possibile |
| Estetica | Ritocchi ammessi solo se migliorano chiarezza, fluidità o coerenza visiva; niente redesign fuori scope TASK-100 |

---

## 9. Rischi **R100-01 … R100-14**

| ID | Rischio | Mitigazione pianificata |
|----|---------|-------------------------|
| **R100-01** | **Simulator non rappresentativo** (CPU/mem/GC diversi) | Richiedere device fisico per PASS su M100-03…08 o accettare PARTIAL |
| **R100-02** | **Device fisico assente** | Bloccare PASS globale; documentare Simulator-only come PARTIAL |
| **R100-03** | **Dataset reale non utilizzabile** (privacy) | Solo sintetico **`TASK100_*`** / generatori offline |
| **R100-04** | **Memory pressure** / jetsam | Suddividere scenario; Instruments solo se autorizzato; stop su OOM |
| **R100-05** | **Export/import bloccante** (main thread) | Evidenza Instruments/sample; possibile PARTIAL con workaround UX |
| **R100-06** | **N+1 query** o loop accidentalmente quadratico | Code review + trace query count dove possibile |
| **R100-07** | **SwiftData fetch troppo ampie** | Verificare predicate/limit/pagination esistenti |
| **R100-08** | **ProductPrice storico molto grande** | Test dedicato cardinality; paginazione UI/API |
| **R100-09** | **Supabase latency / RLS** alterano misura sync | Separare metrica rete da metrica client; manifest env |
| **R100-10** | **Falsi claim production-ready** | §12 stop + CA-T100-10; review obbligatoria |
| **R100-11** | UX apparentemente “funzionante” ma lenta/confusa sotto carico | Checklist UX sotto carico; priorità a feedback, disabled state e recovery |
| **R100-12** | Migliorie UI troppo grandi mascherano il vero obiettivo performance | Solo piccoli ritocchi futuri, se necessari; niente redesign in TASK-100 |
| **R100-13** | Piano troppo ampio e costoso da chiudere | Classificazione MUST/SHOULD/OPTIONAL e stop rule S100-K |
| **R100-14** | Metriche numeriche inventate diventano vincoli falsi | Soglie provvisorie da confermare su device/env; motivare ogni budget |

---

## 10. Go / No-Go per futura EXECUTION

Prima di autorizzare **EXECUTION** (promozione da PLANNING), devono essere **veri**:

1. **Consenso utente esplicito** all’execution e al perimetro (quali slice S100-* sono IN).
2. **Dataset sintetico** definito (almeno D100-S e target principale D100-M o D100-L) con prefisso **`TASK100_*`** per eventuali righe remote dopo collision scan.
3. **Nessun dato reale** di negozio nelle prove standard.
4. **Ambiente Supabase** — se serve: **read-only** vs **sandbox write** dichiarato scenario per scenario; **vietato** live write salvo override separato documentato.
5. **Device/simulator target** dichiarato nel manifest (modello, OS).
6. **Limiti distruttivi** confermati (no truncate massivo, no cleanup produttivo).
7. **Planning Review** completata sul presente documento (non solo init).

8. **Priorità execution** definite: quali slice sono **MUST**, quali **SHOULD**, quali **OPTIONAL**.
9. **UX policy** confermata: se durante execution serve scegliere tra alternative UI, preferire automaticamente la soluzione più nativa iOS, coerente con lo stile esistente, più chiara per l’utente e meno rischiosa per dati/stato; non chiedere micro-scelte estetiche salvo trade-off funzionali.

Se uno di questi manca → rimanere **PLANNING** o dichiarare **BLOCKED** per execution.

---

## 11. Evidenze previste *(cartella — non popolata in questo turno)*

**Percorso pianificato:** `docs/TASKS/EVIDENCE/TASK-100/`

Contenuto previsto (placeholder solo nel MASTER o checklist qui; **nessun** file binario o log creato in init):

| Artefatto | Scopo |
|-----------|--------|
| `MANIFEST.md` | Branch, device, dataset class, env Supabase, scope mutativo SI/NO |
| `MATRIX-M100-results.md` | Esiti M100-01…12 aggiornati post-run |
| `build-test-summary.md` | Comandi eseguiti, esito XCTest/build *(solo dopo execution)* |
| `privacy-scan-notes.md` | Conferma assenza segreti/dati reali |
| `performance-summary.md` | Tabella tempi/size aggregati |
| `manual-ui/` | Screenshot opzionali smoke manuale (non obbligatori in planning) |
| `ux-under-load-checklist.md` | Feedback, disabled state, retry/cancel, errori, coerenza visiva durante dataset grande |
| `decision-log.md` | Classificazione MUST/SHOULD/OPTIONAL, skip motivati, soglie confermate o ricalibrate |
| `D100-dataset-manifest.md` | Classe dataset usata, cardinalità sintetiche, hash/size aggregati, nessun dato reale |
| `PASS-PARTIAL-BLOCKED-rubric.md` | Motivazione finale degli esiti secondo §8.3 |
| `metrics-schema.md` | Schema metriche standard secondo §8.4, se separato da `performance-summary.md` |
| `ui-ux-guardrails-review.md` | Verifica dei guardrail §8.5, eventuali friction e ritocchi futuri proposti |

---

## 12. Sezione stop *(quando NON forzare PASS)*

**FERMARE** e dichiarare **BLOCKED** se:

- Crash, OOM ripetuto, o perdita dati non spiegata durante import/export/sync.
- Impossibilità a isolare **dataset sintetico** o collision **`TASK100_*`** non risolta prima di write remote.
- Manifest incompleto (TASK-083 lesson) ma si pretende esito PASS su runtime.
- Compare pressione a dichiarare **production-ready globale** senza copertura device/reale.
- La UI permette doppie azioni pericolose durante operazioni lunghe e non è possibile dimostrare idempotenza o recovery.
- Le prove richieste diventano più ampie del perimetro TASK-100 senza cambiare la decisione finale.

**Dichiarare PARTIAL** se:

- Solo Simulator disponibile per metriche pesanti.
- Solo classi D100-S/M coperte ma non L.
- Sync/export/import OK ma ProductPrice storico non stressato al volume dichiarato.
- Latenza Supabase domina e non si può separare colpa client vs rete.
- La UX è funzionale ma mostra friction evidente sotto carico, senza rischio dati, e il fix richiederebbe redesign fuori scope.
- Alcuni test OPTIONAL vengono saltati perché non cambiano la decisione PASS/PARTIAL/BLOCKED.

**PASS** solo per area/scenario specifico quando CA e M100 per quell’area sono soddisfatti **senza** contraddire le regole sopra.

---

## 13. Handoff *(post-chiusura TASK-100)*

| Campo | Valore |
|-------|--------|
| **Stato** | **TASK-100 DONE / Chiusura — REVIEW PASS FINAL** |
| **Evidenze** | `docs/TASKS/EVIDENCE/TASK-100/` |
| **Prossimo lavoro progetto** | **TASK-101 ACTIVE / PLANNING** — audit production-readiness privacy/RLS/security *(file task dedicato; NON READY FOR EXECUTION fino a Planning Review e consenso)* |
| **TASK-102** | **Non aperto** |

*(Nessun handoff verso EXECUTION Codex per TASK-100: il task è chiuso.)*

---

## 14. Decisioni candidate e Planning Review finale *(solo Planning)*

Nessuna decisione è finalizzata in questo refinement. Le righe sotto sono raccomandazioni per la Planning Review finale e non autorizzano execution.

### 14.1 Decisioni candidate per Planning Review finale

Queste decisioni non sono ancora prese; servono come checklist per chiudere il planning senza aprire execution.

| Decisione | Opzione raccomandata | Motivo |
|-----------|----------------------|--------|
| Dataset principale | **D100-M** | Bilancia realismo, tempo e rischio; D100-L resta stress mirato |
| Esito massimo senza device fisico | **PARTIAL** per performance/memoria | Evita falsi PASS da Simulator-only |
| Scope minimo | **Minimum closure §6.4** | Sufficiente per decidere import/export/ProductPrice/UX locale |
| Supabase | **SHOULD, non MUST** | Include solo se env e consenso sono chiari; non blocca local performance acceptance |
| UX/UI | **Ritocchi piccoli e nativi** | Migliora esperienza senza trasformare TASK-100 in redesign |
| Profiling pesante | **Solo se segnali runtime lo giustificano** | Evita tooling invasivo non necessario |

---

## Note di coerenza roadmap

TASK-100 **eredita metriche concettuali** da TASK-089 (LG1–LG4) ma impone **manifest**, **classi D100-***, e **matrice M100** come contratto di chiusura superiore rispetto al solo benchmark sintetico originario.


Nota UX/UI: TASK-100 può proporre piccoli ritocchi futuri se migliorano chiarezza, sicurezza e reattività percepita, ma la regola di prodotto è: **SwiftUI nativo, coerenza con lo stile esistente, meno scelte inutili per l’utente, zero redesign non necessario**.


## 15. Estensioni future coerenti *(solo Planning)*

Se serve estendere ancora questo piano prima della execution, usare una delle seguenti direzioni senza cambiare stato task:

| Estensione | Quando usarla | Vincolo |
|------------|---------------|---------|
| Template evidenze | Quando si vuole preparare struttura di `MANIFEST.md`, `decision-log.md`, checklist UX e performance summary | Solo markdown; non creare log runtime falsi |
| Planning Review finale | Quando il piano sembra completo e serve decidere se è Ready for Execution | Non eseguire test/build; solo coerenza e readiness |
| UX polish planning | Quando emergono frizioni di flusso import/export/sync da risolvere in futura execution | Solo criteri e wire-intent; niente SwiftUI |
| Supabase scope planning | Quando si decide se includere sync sandbox in TASK-100 | Read/write/env devono essere espliciti; niente live write implicito |

Prompt consigliato per estensione coerente:

```text
Estendi TASK-100 restando solo in Planning. Aggiungi template markdown per MANIFEST.md, decision-log.md, performance-summary.md, D100-dataset-manifest.md e ux-under-load-checklist.md. Non creare dati runtime, non eseguire build/test, non modificare Swift/Kotlin/SQL e mantieni TASK-100 NON DONE e NON READY FOR EXECUTION.
```

---

## 16. Template evidenze pianificati *(solo schema, non risultati)*

Questi template servono per la futura execution. Non sono log reali e non devono essere compilati con dati inventati durante Planning.

### 16.1 `MANIFEST.md` template

```markdown
# TASK-100 MANIFEST

## Scope
- Task: TASK-100
- Slice incluse: S100-...
- Closure level: Minimum / Extended / Stress
- Stato execution: NOT RUN / RUNNING / COMPLETED

## Repo
- Branch:
- Commit SHA:
- Working tree clean: yes/no
- File modificati prima della run:

## Target
- Device/simulator:
- Modello:
- iOS version:
- Build configuration:
- Scheme:

## Dataset
- Dataset class: D100-S / D100-M / D100-L / custom
- Generazione sintetica confermata: yes/no
- Dati reali presenti: no obbligatorio
- Prefisso remoto, se applicabile: TASK100_*

## Supabase
- Scope: none / read-only / sandbox write
- Project/env identificato in forma redatta:
- Collision scan richiesto: yes/no
- Live write autorizzato: no salvo override separato

## Privacy
- Segreti redatti: yes/no
- Barcode reali assenti: yes/no
- Screenshot redatti: yes/no/non applicabile
```

### 16.2 `decision-log.md` template

```markdown
# TASK-100 Decision Log

| Timestamp | Decisione | Opzione scelta | Alternative scartate | Motivo | Impatto su PASS/PARTIAL/BLOCKED |
|-----------|-----------|----------------|----------------------|--------|----------------------------------|
| TBD | Dataset principale | D100-M raccomandato | D100-S only / D100-L default | Bilancia realismo e costo | Evita audit infinito |
```

### 16.3 `performance-summary.md` template

```markdown
# TASK-100 Performance Summary

| scenario_id | dataset_class | device_target | row_counts | file_size_mb | time_to_first_feedback_s | total_duration_s | result_state | failure_mode | notes_redacted |
|-------------|---------------|---------------|------------|--------------|--------------------------|------------------|--------------|--------------|----------------|
| TBD | D100-M | TBD | TBD | TBD | TBD | TBD | NOT RUN | n/a | Planning placeholder only |
```

### 16.4 `D100-dataset-manifest.md` template

```markdown
# D100 Dataset Manifest

| Campo | Valore |
|-------|--------|
| Dataset class | D100-S / D100-M / D100-L / custom |
| Products count | TBD |
| ProductPrice count | TBD |
| Suppliers count | TBD |
| Categories count | TBD |
| Excel rows | TBD |
| Synthetic prefix | TASK100_* |
| Contains real store data | NO |
| File/hash aggregate | TBD |
| Notes | TBD |
```

### 16.5 `ux-under-load-checklist.md` template

```markdown
# UX Under Load Checklist

| Area | Check | Esito | Note redatte |
|------|-------|-------|--------------|
| Feedback immediato | Stato visibile dopo azione lunga | NOT RUN | |
| Azioni duplicate | Bottoni critici disabilitati o idempotenti | NOT RUN | |
| Errori | Messaggio chiaro e recuperabile | NOT RUN | |
| Cancel/retry | Stato coerente dopo cancel/retry | NOT RUN | |
| Layout | Lista/griglia resta leggibile | NOT RUN | |
| Accessibilità base | Stato non dipende solo dal colore | NOT RUN | |
```

---

## 17. Checklist Planning Review finale

Questa checklist serve per decidere se il piano può essere promosso a **READY FOR EXECUTION** in un turno separato. Finché non è completata, TASK-100 resta **NON READY FOR EXECUTION**.

| Check | Stato atteso prima di execution |
|-------|---------------------------------|
| Stato task | ACTIVE / PLANNING, NON DONE |
| Scope minimo | Minimum closure §6.4 confermata o modificata esplicitamente |
| Dataset | D100-S e D100-M confermati; D100-L opzionale/stress |
| Supabase | none/read-only/sandbox write deciso chiaramente |
| Device target | Simulator/device fisico dichiarato; limiti Simulator-only accettati |
| Metriche | Schema §8.4 accettato |
| UX/UI | Guardrail §8.5 accettati; nessun redesign implicito |
| Evidenze | Template §16 accettati come schema, non risultati |
| Stop rule | §12 accettata senza eccezioni implicite |
| MASTER-PLAN | Da aggiornare solo quando il planning review cambia stato/handoff |

### Prompt consigliato per Planning Review finale

```text
Esegui Planning Review finale di TASK-100 senza fare execution. Verifica coerenza interna, tabelle markdown, scope Minimum/Extended/Stress, dataset D100, metriche, guardrail UX/UI, template evidenze e stop rule. Se tutto è coerente, prepara l’handoff READY FOR EXECUTION ma non eseguire build/test/codice. Mantieni TASK-100 NON DONE finché l’execution non produce evidenze reali.
```
