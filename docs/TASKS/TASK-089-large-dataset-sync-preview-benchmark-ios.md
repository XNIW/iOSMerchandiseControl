# TASK-089 — Benchmark dataset grande: preview/sync/export (handoff review)

## 1. Informazioni generali

| Campo | Valore |
|-------|--------|
| **Task ID** | **TASK-089** |
| **Titolo** | Benchmark dataset grande read-only / controllato — preview sync, export, responsività (iOS prima) |
| **File task** | `docs/TASKS/TASK-089-large-dataset-sync-preview-benchmark-ios.md` |
| **Stato** | **DONE** |
| **Fase attuale** | **Chiusura / REVIEW PASS** |
| **Responsabile attuale** | **Nessuno** |
| **Data creazione** | 2026-05-09 |
| **Ultimo aggiornamento** | 2026-05-09 16:39 -0400 — REVIEW+FIX chiusa con REVIEW PASS / DONE; fix test minimo; TASK-090 non aperto |
| **Ultimo agente** | Codex / Reviewer+Fixer |

---

## 2. Dipendenze

| Tipo | Riferimento |
|------|-------------|
| **Dipende da** | **TASK-088 DONE / Chiusura / PASS** — ProductPrice post-push identity e idempotenza su scenario **`TASK088_*`** chiuse senza claim production-ready globale; residui dichiarati: righe **`TASK088_*`** lasciate in DB senza cleanup distruttivo. |
| **Contesto tecnico** | **TASK-087 DONE** — smoke runtime minimo **`TASK087_*`** bidirezionale **VERIFIED_RUNTIME**; non sostituisce misura volumetrica grande. **TASK-085 PARTIAL_ACCEPTED** — checklist hardening ha lasciato **PARTIAL**: dataset grande, benchmark, import/export runtime round-trip non chiusi. **TASK-084 DONE** — parità documentale; performance riga matrice ~~25 puntava a TASK-085/089 senza RUN. |
| **Riferimenti opzionali (outbox/conflitti, non reopen)** | **TASK-080…082** definiscono ProductPrice/sync piani Release, dedupe/conflict baseline; TASK-089 **non** ridefinisce quei contratti salvo incongruenze trovate in measurement plan. |
| **Output verso backlog futuro** | Evidenze quantitative D89-M sintetiche utilizzabili come input per roadmap **TASK-090** (acceptance cross-platform finale), senza aprire TASK-090 e senza claim production-ready globale. |
| **Non apre** | **TASK-090** e task successivi; nessuna promozione a EXECUTION senza override utente e handoff **READY FOR EXECUTION** esplicito. |

---

## 3. Contesto da TASK-088 e roadmap

1. Dopo **TASK-088 PASS**, il gap **ProductPrice post-push identity / `remoteID` / idempotenza** sul namespace **`TASK088_*`** è considerato **chiuso** nel perimetro del task; restano nella roadmap follow-up MASTER-PLAN (**non** attestati PASS da TASK-088): **benchmark dataset grande**, **round-trip runtime import/export**, **TASK-090** acceptance finale.
2. Il MASTER-PLAN («Roadmap follow-up») definisce **TASK-089** come: misurazione **preview / pull / export** su dataset **production-like** con **prime fasi senza mutazioni** (solo lettura/osservabilità dove possibile), **paginazione / memoria / tempi**, **UX cancel/retry**; apply controllato **solo se** gate di sicurezza espliciti.
3. Questo task **NON** deve usare dati negozio reale nominativi né fixture copiate dal cliente (**CA-T089-06**); Android resta solo **riferimento funzionale / confronto**, non target modifiche Kotlin salvo nuovo task.
4. **Nessun** claim «production-ready 100%» globale dopo solo planning o solo misure parziali.

---

## 4. Obiettivo TASK-089

Formalizzare un perimetro eseguibile **futuro** (solo documentazione in questa init) per **caratterizzare** su **iOS** il comportamento con **catalogo voluminoso coerente con ambiente consentito**:

- Percorsi **preview / Controlla cloud** (dry-run/read-mostly dove applicabile) e uso memoria/tempo osservabile.
- **Export** prodotti/database (formati già previsti dall’app) su volume grande — rischio OOM/UI freeze.
- **Cancel / retry / recovery UX** durante operazioni lunghe (misura/evidenza pianificata, non refactoring UI in questo planning-init).
- **Coerenza UI/UX nativa iOS** sotto stress: eventuali polish futuri sono ammessi solo se migliorano chiarezza, feedback, accessibilità o prevenzione errori, senza redesign globale e senza copiare Android 1:1.
- **Apply/pull mutativo locale** dopo preview: **fuori dalla prima micro-slice** salvo quando un Go/No-Go dedicato (**§10**) sia **GO** dopo preflight (**owner/session**, manifest, collision scan se seed dedicato **`TASK089_*`** — da definire in planning review).

Micro-obiettivo **prioritario (ordine suggerito)**: dalla roadmap, la **misura read-only prima** («senza mutazioni iniziali») → poi slice opzionale apply controllata.

---

## 5. Perimetro esatto

- Una **suite di pianificazione** (manifest dimensioni/target, soglie tentative, formato evidenza privacy-safe) per RUN futuri autorizzati.
- Naming dedicato suggerito per eventuali artifact futuri: prefisso **`TASK089_*`** (distinto da **`TASK087_*`**, **`TASK088_*`**, **`TASK085_*`**), **solo dopo** collision scan nel task di EXECUTION autorizzato.
- Inventario repo-grounded **documentale**: quali schermate/servizi iOS toccheranno le misure (es. Release manual sync preview, Database export/XLSX, flussi TASK-074…082 alignment) senza modificare Swift in questo turno.
- **Supabase clone / read-only pianificatorio**: solo per coerenza schema/conteggi di riferimento (nessun DDL/write/secret in questo file).

---

## 6. Fuori perimetro (severo)

- **Swift, Kotlin, SQL live, DDL, migrazioni, `project.pbxproj`, `Localizable.strings`** in questo turno **PLANNING-init**.
- **Build, XCTest obbligatori, Simulator/emulator/smoke/runtime** nel presente messaggio/agent turn (divieto operativo TASK-089 init).
- **Write Supabase** (seed, upsert, delete, truncate, drop, wipe, cleanup massivo), **`migration repair`**, reset account/dati reali.
- **Dataset negozio reale** come sorgente di misura o fixture.
- Stampare **segreti** (JWT, service_role, connection string integralmente).
- Iniziare **TASK-090**, dichiarare production-ready globale, o dichiarare **TASK-089 DONE** senza review/test.

---

## 7. Micro-slice future (**S89-A …**) — pianificazione, non autorizzazione EXECUTION

| ID | Titolo sintetico | Output atteso (solo dopo override EXECUTION futuro) |
|----|-----------------|-----------------------------------------------------|
| **S89-A** | Manifest «grande»: definizione soglie e sorgenti di volume consentite | Criterio numerico/tabellare (ordini di grandezza autorizzati) + policy privacy |
| **S89-B** | Piano misura preview/Controlla cloud read-mostly/dry-run | Profilo tempo/UI freeze/cancel; scala strumentazione evidenza (senza jargon in UX target) |
| **S89-C** | Piano export LARGE (products / full DB) | Memoria, durata completamento/interruzione, file size ridotto nei log pubblici |
| **S89-D** | Matrice UX cancel/retry/recovery vs operazioni lunghe | Pass/Fail soglie tentative + tipo evidenza (STATIC/SIM/MANUAL solo se task lo richiederà in EXECUTION) |
| **S89-E** | *(Gate successivo)* Apply/pull locale dopo preview su grande — **solo** se S89-A–D + **§10 GO** complessivo | Scenario controllato, recheck auth/owner prima di mutazioni; nessuna promessa automatizzata |
| **S89-F** | UX/UI stress review su operazioni lunghe | Definire stati nativi iOS: progress, cancel, retry, empty/error, disabled actions, messaggi non tecnici; nessuna patch UI in planning |
| **S89-G** | Piano strumenti misura leggeri | Definire come raccogliere tempo/memoria/responsività senza log voluminosi né dati reali: timestamp, os_signpost/console redatta, Instruments opzionale |

### 7.0 Ordine operativo raccomandato per futura EXECUTION

Ordine consigliato, salvo override esplicito:

1. **S89-A** — fissare manifest dataset/device/soglie e confermare privacy policy.
2. **S89-B** — misurare preview/read-mostly senza mutazioni.
3. **S89-C** — misurare export prodotti e full DB come scenari separati.
4. **S89-D + S89-F** — verificare cancel/retry/recovery e polish UX minimo, solo se serve per rendere comprensibile lo stato operazione.
5. **S89-G** — raccogliere evidenze leggere e aggregate.
6. **S89-E** — apply/pull controllato solo dopo GO esplicito §10, mai come default.

Regola anti-creep: se durante futura EXECUTION emerge un problema strutturale grande, documentarlo come nuovo backlog invece di trasformare TASK-089 in refactor generale.

### 7.1 Metriche minime da definire prima della EXECUTION futura

TASK-089 deve diventare misurabile prima di qualsiasi RUN. La futura EXECUTION dovrà compilare una tabella con almeno:

| Area | Metrica richiesta | Nota UX/iOS |
|------|-------------------|-------------|
| Preview / Controlla cloud | tempo al primo feedback, tempo totale, numero record stimati/letti, stato cancel/retry | L’utente deve vedere subito che l’operazione è partita; niente schermate bloccate senza feedback. |
| Pull/read-mostly | cardinalità prodotti/fornitori/categorie/prezzi, paginazione, errori recuperabili | Se l’operazione è lunga, preferire stato progressivo e messaggio leggibile. |
| Export prodotti/full DB | durata, dimensione file, esito completato/errore controllato, memoria osservata se disponibile | Export non deve sembrare congelato; share/save devono restare coerenti con UX iOS. |
| Cancel / retry | punto di interruzione, stato dopo annullo, possibilità di ripetere senza dati corrotti | L’utente deve poter riprovare senza dover riavviare l’app. |
| UI responsiveness | evidenza che navigazione/bottoni critici non rimangano in stato ambiguo | Se serve bloccare un’azione, usare disabled state chiaro e progress indicator. |

Soglie numeriche definitive: **da decidere in Planning Review**, non inventate in questa init. Se manca una metrica reale in EXECUTION, l’esito deve essere **PARTIAL** o **NOT_RUN**, non PASS.

### 7.1.1 Soglie tentative da confermare in Planning Review

Queste soglie non autorizzano EXECUTION; servono solo a evitare un PASS vago. La Planning Review può abbassarle/alzarle in base al device reale e alla dimensione dataset.

| Scenario | Soglia UX/performance provvisoria | Esito minimo accettabile |
|----------|----------------------------------|--------------------------|
| Primo feedback operazione lunga | feedback visibile entro pochi secondi dall’azione utente | se non misurato → PARTIAL; se assente → BLOCKED UX |
| Preview/read-mostly | completamento o errore controllato con messaggio leggibile | crash/freeze non recuperabile → BLOCKED |
| Export prodotti | file generato oppure errore controllato senza perdita stato UI | OOM/crash → BLOCKED; solo Simulator → massimo PARTIAL |
| Export full DB | separato da export prodotti, con durata e dimensione file annotate | se unito a export prodotti → PARTIAL per diagnosi incompleta |
| Cancel/retry | annullo o stop sicuro documentato; retry non duplica dati né richiede riavvio app | se non supportato ma UI lo comunica chiaramente → PARTIAL; stato ambiguo → BLOCKED |
| UI responsiveness | nessun overlay infinito senza spiegazione; azioni critiche con disabled/progress coerenti | feedback assente o spinner senza testo → PARTIAL/BLOCKED secondo gravità |

Nota: dove non esiste una vera azione cancel nel codice attuale, la futura EXECUTION deve almeno verificare **recovery/retry** e comunicazione UI; non inventare un redesign solo per soddisfare questo task.

### 7.2 Matrice dataset/device da compilare prima della EXECUTION

La futura EXECUTION deve dichiarare esattamente **dove** e **con quale volume** sta misurando. Nessun risultato “grande dataset” è valido senza questa matrice compilata.

| Dimensione | Dataset consentito | Esempi metriche da dichiarare | Stato iniziale |
|------------|-------------------|-------------------------------|----------------|
| **D89-S** | piccolo/smoke sintetico, solo per verificare che lo scenario parte | tempo primo feedback, esito UI, nessun dato reale | da definire |
| **D89-M** | medio sintetico o clone autorizzato senza dati reali nominativi | cardinalità prodotti/prezzi, durata preview/export | da definire |
| **D89-L** | grande production-like consentito, privacy-safe, preferibilmente generato o anonimizzato | durata totale, memoria indicativa, cancel/retry, error recovery | da definire |

| Target device | Scopo | Nota |
|---------------|-------|------|
| iPhone baseline supportato dal deployment target | rilevare freeze/performance realistica | preferire device fisico se disponibile in EXECUTION futura |
| iPhone recente o Simulator equivalente | confronto prestazione alta | non basta da solo per PASS globale |
| iPad, se il layout database/export è usato anche lì | verificare leggibilità e toolbar/sheet | solo se nel perimetro release iPad |

Se viene usato solo Simulator, il risultato massimo consigliato è **PARTIAL** per performance/memoria; può essere **PASS** solo per coerenza UX statica/read-mostly leggera.

### 7.3 Manifest EXECUTION da compilare in futuro

Prima di qualsiasi futura EXECUTION, l’agente dovrà aggiungere una tabella compilata, non narrativa libera:

| Campo | Valore richiesto |
|-------|------------------|
| Branch/commit iOS | da compilare |
| Build target / schema | da compilare |
| Device o Simulator | da compilare |
| iOS version | da compilare |
| Dataset class | D89-S / D89-M / D89-L |
| Dataset source | sintetico / anonimizzato / clone autorizzato / altro consentito |
| Privacy check | OK / REDACTED / BLOCKED |
| Supabase target | locale / staging / read-only / non usato |
| Scenari LG da eseguire | LG1 / LG2 / LG3 / LG4 / LG5 |
| Scenari esplicitamente skipped | con motivo |
| Mutazioni consentite | NO di default; YES solo con GO §10 e scope scritto |
| Piano rollback/stop | richiesto per ogni scenario mutativo |

Se questo manifest non è compilato, TASK-089 può restare solo in **PLANNING** o al massimo in **STATIC REVIEW**, non in EXECUTION reale.

### 7.4 Policy decisionale UX/UI per futura EXECUTION

Se durante una futura EXECUTION autorizzata emerge una scelta UI/UX minore, l’agente deve decidere in autonomia seguendo questa priorità, senza chiedere all’utente salvo impatto strutturale:

| Priorità | Regola | Scelta preferita iOS |
|----------|--------|----------------------|
| 1 | Chiarezza stato operazione | `ProgressView` con testo breve; progress determinato quando disponibile; fallback indeterminato solo con spiegazione. |
| 2 | Controllo utente | `Cancel`, `Retry` o `Close` solo quando sicuri; se cancel reale non esiste, spiegare recovery/retry invece di mostrare un bottone falso. |
| 3 | Prevenzione errori | Disabilitare azioni pericolose durante operazioni lunghe con motivo visibile; mai lasciare bottoni attivi se creano doppie esecuzioni. |
| 4 | Coerenza app | Riutilizzare stile già presente: `NavigationStack`, toolbar, `sheet`, `alert`, `confirmationDialog`, `List/Form`, `ProgressView`, messaggi brevi. |
| 5 | Accessibilità minima | Label comprensibili per VoiceOver, Dynamic Type non rotto, contrasto nativo, target touch standard; nessun testo solo-colore come unica informazione. |
| 6 | iPad/responsive | Se il layout esiste su iPad, evitare overlay enormi inutili; preferire sheet/form leggibili e toolbar coerenti. |

Sono ammessi solo polish localizzati: testo, stato loading, disabled state, alert/sheet più chiari, retry/cancel sicuro, accessibilità minima. Sono fuori perimetro: redesign completo, nuova navigazione, nuove dipendenze UI, nuove architetture o refactor ViewModel non necessari alla misura.

---

## 8. Acceptance criteria pianificatori / futuri (**CA-T089-xx**)

*(In questa init restano contratto **target** verso EXECUTION/REVIEW; **nessun PASS** ora.)*

- [ ] **CA-T089-01** — Prima di QUALSIASI EXECUTION futura autorizzata, esiste manifest **`TASK089_*`** o equivalente registrato nel task con **collision scan documentato** = 0 sulle chiavi nominate (analog TASK-087/088 philosophy).
- [ ] **CA-T089-02** — Ogni dichiarazione **PASS/PARTIAL** su «grande dataset» include **numeri pubblicabili**: almeno **tempo osservazione** **o** conteggio/cardinalità **o** soglia UX (no «sembra ok» vuoto).
- [ ] **CA-T089-03** — **Preview / path read-mostly**: evidenza di **primo feedback**, **fine operazione**, **cancel** recuperabile dove applicabile (tipi verifica decisi nella EXECUTION, non ora).
- [ ] **CA-T089-04** — **Export LARGE**: dichiarazione coerente con **completamento o errore controllato** (OOM/export parziale) documentata senza blaming utente né dati reali nel log pubblico.
- [ ] **CA-T089-05** — **Apply dopo preview grande** (**S89-E**): se eseguito, solo con **preflight auth/owner/sessione** TASK-082-style e mai come silenzioso autopilot — altrimenti marcare **SKIPPED**.
- [ ] **CA-T089-06** — **Privacy**: zero dati cliente reale, zero segreti nelle evidenze; barcode/nomi **`TASK089_*`** o equivalente inventato.
- [ ] **CA-T089-07** — **No claim**: chiusura task **NON** equivale a production-ready globale né sostituisce **TASK-090** senza EXECUTION/evidenze dedicate.
- [ ] **CA-T089-08** — **Android**: se citato come benchmark comparativo documentale — solo **matching funzionale** o **DIFF accettabile** dichiarato, nessuna patch Kotlin obbligatoria dentro TASK-089 salvo nuovo backlog.
- [ ] **CA-T089-09** — **Metriche minime**: prima di EXECUTION esiste una tabella scenario→metrica→soglia/aspettativa→tipo evidenza; senza numeri o soglia esplicita non si può dichiarare PASS.
- [ ] **CA-T089-10** — **UX/UI nativa**: eventuali ritocchi futuri devono seguire lo stile iOS esistente dell’app (NavigationStack/toolbar/sheet/alert/progress nativi), senza copiare layout Android 1:1.
- [ ] **CA-T089-11** — **Efficienza evidenze**: log e screenshot futuri devono essere piccoli, redatti e aggregati; niente dump di righe grandi, niente file Excel reali allegati al task.
- [ ] **CA-T089-12** — **Decisioni UX delegate**: se durante la futura EXECUTION emerge una scelta UI/UX minore, l’agente può scegliere l’opzione più coerente con l’app iOS esistente, purché documenti la decisione e resti nel perimetro autorizzato.
- [ ] **CA-T089-13** — **Matrice dataset/device**: ogni scenario futuro dichiara dimensione dataset, sorgente consentita, device/simulator, versione app/branch e limitazioni; senza matrice compilata non esiste PASS su performance.
- [ ] **CA-T089-14** — **Polish UX limitato**: eventuali cambi futuri di UI devono essere piccoli e motivati da evidenze TASK-089; redesign, nuove architetture o schermate complesse vanno in task separato.
- [ ] **CA-T089-15** — **Definizione PASS/PARTIAL**: PASS richiede metrica + evidenza + privacy check + assenza crash/freeze evidente; PARTIAL è obbligatorio se manca device reale, volume grande, cancel test o misura memoria.
- [ ] **CA-T089-16** — **Manifest EXECUTION**: prima di futura EXECUTION esiste il manifest §7.3 compilato; se manca, nessuna RUN può essere considerata valida.
- [ ] **CA-T089-17** — **Diagnosi separata**: preview, pull/read-mostly, export prodotti, export full DB e cancel/retry sono valutati come scenari separati; vietato un unico PASS cumulativo non diagnosticabile.
- [ ] **CA-T089-18** — **UI polish non invasivo**: eventuali ritocchi futuri devono essere reversibili/localizzati e non introdurre nuove dipendenze o architetture senza nuovo task.
- [ ] **CA-T089-19** — **Policy UX/UI §7.4**: ogni scelta UI futura deve rispettare la priorità chiarezza → controllo utente → prevenzione errori → coerenza app → accessibilità minima.
- [ ] **CA-T089-20** — **Accessibilità minima**: eventuali polish futuri non devono rompere Dynamic Type, VoiceOver label, contrasto nativo o target touch; se non verificabile, dichiarare PARTIAL.
- [ ] **CA-T089-21** — **No fake cancel**: se il codice non supporta annullo reale sicuro, la UI futura deve mostrare recovery/retry/chiusura controllata invece di promettere un cancel falso.

---

## 9. Rischi (**R89-xx**)

| ID | Rischio | Nota pianificazione |
|----|---------|---------------------|
| R89-env | **Ambiente grande ≠ riproducibile** (pooler/circuit breaker, rete condivisa) | Separare sintomi app da infra; soglie indicative + ripetizioni |
| R89-priv | Misura su DB **production-like shared** anche read-only può correlare volumi senza leakage | Preferire aggregate counts; vietare dumping righe cliente |
| R89-conf | Collisioni **`TASK089_*`** con dati storici TASK085/086/087/088 seed | Mandatory scan prima write futura |
| R89-scope | Creep verso **ottimizzazione codice** senza baseline misura | **No** refactor come deliverable TASK-089 finché pianificazione non mostra bottleneck |
| R89-par | Tentare chiudere **import/export runtime round-trip cross-client** completo dentro 089 vs lasciare parti a TASK-090 | Esplicitare confine in EXECUTION dopo review |
| R89-freeze | Operazioni grandi possono sembrare freeze UI anche se il task backend continua | Pianificare feedback immediato, progressivo o fallback indeterminato; evitare stati ambigui |
| R89-oom | Export XLSX grande può causare memoria alta/OOM | Misura separata export prodotti vs full DB; errore controllato > crash silenzioso |
| R89-log | Evidenze troppo verbose possono diventare lente o rischiose per privacy | Usare conteggi, hash/prefix sintetici, timestamp; vietato dump dataset |
| R89-choice | Troppe micro-decisioni UI bloccano EXECUTION futura | Delegare scelte minori all’agente, con vincolo di coerenza Apple/iOS e documentazione nel task |
| R89-sim | Simulator può nascondere colli di bottiglia reali o falsare memoria | Separare risultati Simulator/device; limitare PASS globale se manca device reale |
| R89-polish | “Abbellire UI” può diventare redesign non misurabile | Consentire solo polish guidato da feedback/cancel/retry/error state; resto nuovo backlog |
| R89-threshold | Soglie troppo vaghe permettono PASS debole | Richiedere soglie tentative prima della EXECUTION e motivare ogni PARTIAL |
| R89-mix | Unire preview/export/cancel in un solo scenario nasconde il collo di bottiglia reale | Evidenze LG separate e PASS/PARTIAL per singolo scenario |
| R89-dep | Aggiungere strumenti logging pesanti può peggiorare performance o complicare release | Preferire misure leggere già disponibili; nuovi helper solo se localizzati |
| R89-fake-cancel | UI mostra un cancel non realmente supportato, creando falsa sicurezza | Vietare fake cancel; preferire retry/recovery dichiarato se cancel reale non esiste |
| R89-a11y | Polish visivo rompe Dynamic Type, VoiceOver o leggibilità | Applicare checklist §7.4/CA-T089-20; usare componenti SwiftUI nativi |

---

## 10. Go / No-Go per **futura** EXECUTION (gate obbligatori)

**GO alla EXECUTION** (Codex/simile) quando **simultaneamente**:

1. **Utente**: override esplicito a promuovere **ACTIVE / EXECUTION** su questo task (non presume da solo il planner init).
2. **File task**: sezione PLANNING compilata dopo **READY FOR PLANNING REVIEW** consumato; collision policy e manifest **`TASK089_*`** (se write) chiari.
3. **Prefetch**: progetto/target Supabase e account test coerenti; **owner/session** verificabile immediatamente prima di mutazioni in S89-E.
4. **Metriche**: tabella §7.1 compilata con soglie/aspettative almeno tentative per gli scenari da eseguire.
5. **UX policy**: confermato che eventuali ritocchi UI/UX futuri sono ammessi solo come polish coerente con l’app, non come refactor o redesign.
6. **Matrice dataset/device**: almeno uno scenario D89-S o D89-M definito per partenza sicura; D89-L richiede sorgente consentita e privacy-safe.
7. **Rollback mentale**: per ogni scenario mutativo futuro esiste piano “stop senza corrompere dati”; se non esiste, S89-E resta SKIPPED.
8. **Manifest EXECUTION §7.3**: compilato e coerente con i gate sopra; senza manifest compilato resta solo PLANNING/STATIC REVIEW.
9. **Policy UX/UI §7.4**: ogni polish futuro deve essere localizzato, nativo iOS, accessibile almeno a livello base e senza fake cancel.

**NO-GO**: assenza elemento sopra → **solo markdown/evidenze STATIC** eventualmente autorizzata; nessuna mutazione/remoto.

**TASK-089 in questo momento init** → implicitamente **NON READY FOR EXECUTION** ai sensi sopra — **solo** PLANNING registrazione.

---

## 11. Evidenze richieste (formato futuro — **non prodotte in Planning-init**)

Matrice suggerita (righe tipo **scenario / client iOS / strumento / metrica chiave / esito PASS-PARTIAL-BLOCKED-NOT_RUN / privacy-check**):

- Scenario **LG1**: preview/dry-run su catalogo alto cardinalità (**read-mostly**) — tempo al primo feedback, tempo totale, responsiveness, interrupt.
- Scenario **LG2**: export LARGE prodotti — tempo, dimensione file, memoria indicativa se disponibile, errore leggibile se fail.
- Scenario **LG3**: export LARGE full DB — separato da LG2 per isolare rischio memoria/tempo.
- Scenario **LG4**: cancel/retry/recovery UX — stato prima/dopo annullo, possibilità di ripetizione senza riavvio app.
- Scenario **LG5**: *(solo se §10 GO)* apply controllato post-preview — rollback policy non distruttiva; recheck stale.

Ogni evidenza futura deve includere un mini-header standard:

- branch/commit iOS misurato;
- tipo target: device fisico / Simulator;
- dimensione dataset: D89-S / D89-M / D89-L;
- scenario LGx;
- metrica osservata;
- esito: PASS / PARTIAL / BLOCKED / NOT_RUN;
- privacy check: OK / REDACTED / BLOCKED.

Formato consigliato per ogni scenario futuro:

| Scenario | Dataset | Target | Metriche | Esito | Motivo esito | Privacy |
|----------|---------|--------|----------|-------|--------------|---------|
| LGx | D89-S/M/L | device/simulator | tempo/cardinalità/memoria/UX | PASS/PARTIAL/BLOCKED/NOT_RUN | breve, verificabile | OK/REDACTED/BLOCKED |

Screenshots/logs: policy censura TASK-074 lineage (no jargon operatore dove possibile nei deliverable pubblici UI).

---

## 12. Planning (Claude) — init

### Obiettivo questo documento

Trasporre backlog MASTER-PLAN TASK-089 in contratto pianificabile: micro-slices **S89-A…G**, CA **CA-T089-01…21**, rischi **R89-xx**, metriche/dataset/device, manifest EXECUTION, gate **§10**, e policy decisionale UX/UI iOS (**§7.4**) per polish futuri sicuri senza fake cancel.

### Analisi

Il gap dopo **TASK-088** non è più l’identity post-push minima (**chiuso** nel suo perimetro): restano volumi/production-like (**TASK-085** matrice riga dataset grande/sync preview) e affidabilità percepita sotto stress.

### Approccio (EXECUTION futura — **non ora**)

Baseline misura osservabile read-only/export → poi valutazione se apply controllato aggiunge valore rischio-accettabile.

Per UX/UI, la regola futura è: migliorare la percezione di controllo dell’utente prima dell’estetica pura. In pratica: progress immediato, messaggi chiari, cancel/retry quando recuperabile, azioni disabilitate in modo comprensibile, nessun overlay infinito senza spiegazione.

### File coinvolti (indicativo — EXECUTION futura)

Da verificare prima di EXECUTION leggendo la repo iOS aggiornata:

- `SupabaseManualSyncViewModel.swift` / servizi preview-pull-sync: misure read-mostly, cancel/retry, stato progress.
- `DatabaseView` / export XLSX: export prodotti/full DB, error state, progress, share/save.
- Coordinator/ViewModel Release manual sync: eventuali stati UI già esistenti da riusare, non duplicare.
- Eventuali helper logging/diagnostics solo se già coerenti con stile repo; evitare introdurre infrastruttura pesante senza nuovo micro-task.

Regola UX: se in futura EXECUTION serve scegliere tra più varianti minori, preferire la soluzione più nativa iOS e coerente con le schermate esistenti: progress visibile, azioni disabilitate solo quando necessario, messaggi brevi e non tecnici, retry esplicito quando recuperabile.

### Handoff PLANNING-init

| Voce | Valore |
|------|--------|
| **READY FOR PLANNING REVIEW** | **Sì** — revisione contenuto TASK-089 e soglie prima di QUALSIASI EXECUTION. |
| **READY FOR EXECUTION** | **No** |
| **TASK-089 DONE** | **No** |
| **Prossimo passo suggerito** | Planning Review su manifest §7.3, metriche §7.1/§7.1.1, matrice §7.2, policy UX/UI §7.4, CA e gate §10 → poi eventualmente utente autorizza EXECUTION (**Codex**). |

---

## 13. Execution / Fix

### 13.1 Avvio EXECUTION — Codex — 2026-05-09 16:19 -0400

**Obiettivo compreso:** eseguire TASK-089 fino a **HANDOFF FOR REVIEW**, senza DONE, con scenari non distruttivi LG1-LG4/LG2-LG3 e S89-G dove possibile; S89-E apply/pull mutativo resta **SKIPPED** salvo gate §10 tutti GO.

**Preflight già eseguito prima di modifiche codice:**

| Check | Esito | Evidenza |
|-------|-------|----------|
| `git status --short` | PASS | Working tree già non pulito prima dell'intervento Codex: `M docs/MASTER-PLAN.md`, `?? docs/TASKS/TASK-089-large-dataset-sync-preview-benchmark-ios.md`. |
| Branch corrente | PASS | `main`. |
| Ultimo commit | PASS | `77a8e4b Task 88`. |
| MASTER-PLAN letto | PASS | TASK-089 indicato come task attivo; TASK-088 ultimo completato; TASK-090 TODO / Planning — non aperto. |
| Task file letto | PASS | Questo file letto integralmente; fase iniziale PLANNING prima dell'override utente. |
| File iOS rilevanti letti | PASS | `SupabasePullPreviewService.swift`, `SupabasePullPreviewModels.swift`, `SupabaseManualSyncViewModel.swift`, `SupabaseManualSyncCoordinator.swift`, `SupabaseManualSyncReleaseFactory.swift`, `DatabaseView.swift`, `InventoryXLSXExporter.swift`, `Models.swift`, test preview/manual sync rilevanti. |
| `xcodebuild -list -project iOSMerchandiseControl.xcodeproj` | PASS | Scheme disponibile: `iOSMerchandiseControl`; target: app + tests. |

**Piano minimo di intervento:**

1. Compilare manifest EXECUTION privacy-safe con dataset sintetico `TASK089_*`.
2. Usare strumenti/test leggeri e sintetici per misurare LG1 preview read-mostly, LG2 export prodotti, LG3 export full DB, LG4 cancel/retry/recovery UX.
3. Eseguire build/test/check statici reali dove disponibili.
4. Documentare metriche, limiti, scenari skipped, rischi residui e handoff verso Review.

### 13.2 Manifest EXECUTION

| Campo | Valore |
|------|--------|
| Branch/commit iOS | `main` / `77a8e4b Task 88` |
| Build target / schema | Project `iOSMerchandiseControl.xcodeproj`, scheme `iOSMerchandiseControl`, target app `iOSMerchandiseControl`, target test `iOSMerchandiseControlTests` |
| Device o Simulator | Simulator disponibili: iPhone 16e iOS 26.2 booted; iPhone 15 Pro Max iOS 26.1 booted. Device fisico non verificato. |
| iOS version | Simulator iOS 26.2 per build/test pianificati; performance senza device reale massimo PARTIAL. |
| Dataset class | D89-M sintetico per misure ripetibili; D89-S coperto da smoke/unit esistenti; D89-L non promesso senza evidenza sostenibile. |
| Dataset source | sintetico `TASK089_*`, generato in test/harness locale; nessun dato reale negozio/cliente. |
| Privacy check | OK — solo prefissi sintetici `TASK089_*`, nessun segreto o dump dataset. |
| Supabase target | non usato per write; LG1 read-mostly via fake fetcher/test locale, nessun network Supabase richiesto. |
| Scenari LG da eseguire | LG1 / LG2 / LG3 / LG4 |
| Scenari skipped | LG5/S89-E apply controllato: SKIPPED finché §10 non è tutto GO; D89-L live/device reale: NOT_RUN se non sostenibile in ambiente locale. |
| Mutazioni consentite | NO |
| Piano rollback/stop | Nessun mutativo previsto; se un comando locale fallisce, stop e documentazione FAIL/PARTIAL senza cleanup distruttivo. |

### 13.3 Modifiche codice / strumenti misura

| File | Tipo | Nota |
|------|------|------|
| `iOSMerchandiseControl/Task089SyntheticBenchmarkHarness.swift` | nuovo helper DEBUG-only | Harness sintetico per scrivere XLSX `Products` e `database_full` con schema coerente alle colonne export esistenti; sotto `#if DEBUG`, nessun codice Release. |
| `iOSMerchandiseControlTests/Task089LargeDatasetBenchmarkTests.swift` | nuovo XCTest | Misure locali D89-M sintetiche per LG1, LG2, LG3, LG4; fake fetcher paginato, nessun network, nessuna mutazione. |
| `docs/MASTER-PLAN.md` | tracking | Promozione EXECUTION e poi handoff REVIEW; TASK-088 ultimo completato, TASK-090 non aperto. |

Nessuna modifica a UI production, `Localizable.strings`, API pubbliche, SQL, Supabase remoto, schema SwiftData, Android, `project.pbxproj` o dipendenze.

### 13.4 Dataset sintetico eseguito

| Campo | Valore |
|-------|--------|
| Dataset class | D89-M |
| Prefisso | `TASK089_*` |
| Prodotti | 2.500 |
| Fornitori | 100 |
| Categorie | 60 |
| Price history rows | 5.000 |
| Sync rows | 0 |
| Page size preview | 500 |
| Source | Generato in XCTest, sintetico, nessun dato cliente |
| Supabase write/read live | Non usato |
| D89-L | NOT_RUN — nessun device reale/dataset grande autorizzato disponibile in modo sostenibile e privacy-safe in questo turno |

### 13.5 Evidenze scenario LG

Metriche canoniche prese dalla suite completa `xcodebuild test ... -parallel-testing-enabled NO` su iPhone 16e Simulator iOS 26.2.

| Scenario | Dataset | Target | Metriche | Esito | Motivo esito | Privacy |
|----------|---------|--------|----------|-------|--------------|---------|
| LG1 Preview / Controlla cloud read-mostly | D89-M | XCTest fake fetcher + `SupabasePullPreviewService` | 2.500 prodotti, 100 fornitori, 60 categorie, 5.000 price rows, page size 500, product pages 6, price pages 11, durata 437,09 ms | PARTIAL | PASS component read-mostly/paginazione/diff; PARTIAL perché non è stato usato Supabase live né UI end-to-end/manuale su device reale. | OK |
| LG2 Export prodotti | D89-M | DEBUG XLSX harness | 2.500 prodotti, durata 43,98 ms, file 169.034 byte, 2.501 righe incl. header validate via `ExcelAnalyzer` | PARTIAL | PASS writer sintetico/validazione file; PARTIAL perché non è stato invocato il pulsante UI `DatabaseView`/ShareSheet su device reale. | OK |
| LG3 Export full DB | D89-M | DEBUG XLSX harness | 2.500 prodotti, 100 fornitori, 60 categorie, 5.000 price rows, durata 88,41 ms, file 304.125 byte, Products 2.501 righe, PriceHistory 5.001 righe | PARTIAL | PASS writer full DB sintetico/validazione file; PARTIAL perché non è stato invocato il flusso UI production e non è stata misurata memoria reale/OOM con D89-L. | OK |
| LG4 Cancel / retry / recovery UX | D89-M | `SupabaseManualSyncViewModel` con coordinator fake cancellabile | primo feedback running 2,22 ms, cancel recovery 0,16 ms, running mostra cancel, post-cancel mostra retry | PASS | ViewModel reale mostra stato running/cancel e recovery retry senza fake success; nessuna mutazione. UI manuale non richiesta/effettuata. | OK |
| LG5 Apply controllato | N/A | N/A | nessuna | SKIPPED | Gate §10 non tutti GO: mutazioni consentite NO, nessun Supabase staging/local target mutativo verificato, nessun rollback mutativo necessario. | OK |

Differenza LG3 vs LG2: full DB sintetico +135.091 byte rispetto export prodotti (+79,9% circa) e +44,43 ms nella generazione XLSX sullo stesso dataset.

### 13.6 Check eseguiti

| Check previsto | Stato | Evidenza |
|----------------|-------|----------|
| Build compila (Xcode / BuildProject) | ESEGUITO | `xcodebuild test ... -parallel-testing-enabled NO` compila Debug e passa; `xcodebuild build -configuration Release ...` PASS. |
| Nessun warning nuovo introdotto | ESEGUITO | `xcresulttool get build-results` mostra 5 warning Swift preesistenti/out-of-scope in `SyncEventOutboxDrainDebugViewModelTests.swift` e `SupabaseManualSyncViewModelTests.swift`; nessun warning nei file TASK-089 nuovi/modificati. |
| Modifiche coerenti con planning | ESEGUITO | Solo harness DEBUG-only + XCTest sintetici + tracking; nessuna UI/SQL/Supabase live/API pubblica/refactor grande. |
| Criteri di accettazione verificati | ESEGUITO | CA principali coperti con esiti per scenario; CA live/device/D89-L/apply restano PARTIAL/SKIPPED documentati. |
| `xcodebuild -list` | ESEGUITO | Scheme `iOSMerchandiseControl`; target app + tests. |
| Test TASK-089 mirati | ESEGUITO | `xcodebuild test ... -only-testing:iOSMerchandiseControlTests/Task089LargeDatasetBenchmarkTests` PASS, 4 test / 0 failure; metriche LG1-LG4 catturate da xcresult. |
| Suite XCTest completa | ESEGUITO | `xcodebuild test ... -parallel-testing-enabled NO` PASS, 567 test / 0 failure. |
| Build Release | ESEGUITO | `xcodebuild build -configuration Release ...` PASS. |
| Verifica statica diff | ESEGUITO | `git diff --check` PASS. |
| Release binary senza artifact TASK089 | ESEGUITO | `strings .../Release-iphonesimulator/iOSMerchandiseControl.app/iOSMerchandiseControl | rg 'TASK089|Task089'` non trova match. |
| Simulator/device manuale UI | NON ESEGUITO | Non richiesto esplicitamente dal task/utente oltre ai test; nessun flusso UI manuale avviato per evitare claim di performance real-device non misurate. |
| Supabase live/read-only collision scan | NON ESEGUITO | Supabase target non usato, mutazioni NO; dataset solo locale sintetico. |
| D89-L | NON ESEGUITO | Nessun device reale o dataset grande autorizzato/sostenibile disponibile in questo turno. |

### 13.7 Acceptance criteria — esito execution

| CA | Esito | Evidenza |
|----|-------|----------|
| CA-T089-01 | PARTIAL | Manifest compilato; collision scan remoto non eseguito perché nessun Supabase target/write usato. Namespace solo locale `TASK089_*`. |
| CA-T089-02 | PASS | Ogni scenario ha numeri pubblicabili: tempi, cardinalità, page/file size. |
| CA-T089-03 | PARTIAL | Primo feedback/cancel misurati via ViewModel; preview cloud live/UI manuale non eseguita. |
| CA-T089-04 | PARTIAL | Export XLSX sintetici completati e validati; UI production export non manual-run, memoria reale non misurata. |
| CA-T089-05 | PASS | Apply S89-E/LG5 SKIPPED per gate §10 non GO. |
| CA-T089-06 | PASS | Solo dati sintetici `TASK089_*`; nessun segreto/dato reale. |
| CA-T089-07 | PASS | Nessun claim production-ready globale; TASK-090 resta non aperto. |
| CA-T089-08 | PASS | Android non toccato. |
| CA-T089-09 | PASS | Tabella scenario/metrica/esito compilata. |
| CA-T089-10...21 | PARTIAL/PASS | Policy rispettata: nessun redesign, nessun fake cancel, nessuna localizzazione toccata; accessibilità/manual UI non misurata su device reale. |

### 13.8 Rischi rimasti

- Performance reale su device fisico non misurata; risultati D89-M Simulator/XCTest non vanno letti come benchmark production definitivo.
- LG2/LG3 usano harness DEBUG-only che riproduce struttura XLSX, non l'interazione utente completa `DatabaseView` + ShareSheet.
- Memoria/OOM non misurati con Instruments o metriche runtime; nessun D89-L.
- LG1 non usa Supabase live/read-only; non misura rete, pooler, RLS, latenza o cardinalità reale.
- I 5 warning Swift rilevati sono preesistenti e fuori perimetro, ma restano nel progetto.

### 13.9 Backlog separati proposti

- TASK futuro: benchmark D89-L su device fisico con Instruments/XCTest metrics, includendo memoria/OOM e UI responsiveness.
- TASK futuro: UI/manual export benchmark che guida `DatabaseView` end-to-end con dataset sintetico pre-caricato, se serve claim su ShareSheet/flusso utente.
- TASK futuro: Supabase staging/read-only `TASK089_*` collision/preflight e preview live, solo con target sicuro e nessuna mutazione.

### 13.10 Handoff post-execution — HANDOFF FOR REVIEW

| Campo | Valore |
|-------|--------|
| Stato finale proposto | **PARTIAL READY FOR REVIEW / HANDOFF FOR REVIEW** |
| Task state/fase | **ACTIVE / REVIEW** |
| Responsabile prossimo | **Claude / Reviewer** |
| Codice modificato | Sì: helper DEBUG-only + XCTest TASK-089 |
| UI/UX polish | Non fatto: esistente sufficiente per componente; nessun testo UI production aggiunto |
| Localizzazione | NOT_TOUCHED |
| Privacy | OK — sintetico `TASK089_*`, nessun dato reale, nessun segreto |
| Mutazioni | NO |
| S89-E / LG5 | SKIPPED con motivo gate §10 non GO |
| TASK-089 DONE | NO |
| TASK-090 aperto | NO |
| Claim production-ready globale | NO |
| Prossimo passo | Review umana/Claude delle evidenze e dei limiti prima di eventuale D89-L/live/device task separato |

### 13.11 Review + fix finale — Codex — 2026-05-09 16:39 -0400

**Esito finale:** **REVIEW PASS / DONE** su user override esplicito. La chiusura vale per il perimetro TASK-089 D89-M sintetico/read-only e non è claim production-ready globale.

**Problemi trovati in review:**

| Area | Severità | Esito |
|------|----------|-------|
| LG2/LG3 XCTest | Minore | I test validavano conteggi/file size ma poco contenuto minimo degli XLSX. |
| LG1 XCTest | Minore | Mancavano assert espliciti su paginazione attesa e segnali ProductPrice. |
| Tracking | Minore | Mancava sezione review finale/DONE dopo handoff execution. |

**Fix applicati:**

| File | Fix |
|------|-----|
| `iOSMerchandiseControlTests/Task089LargeDatasetBenchmarkTests.swift` | Aggiunti assert su paginazione LG1, `priceHistoryDiffs`, payload sintetico `TASK089_*`, header/contenuto minimo `Products`, sheet `Suppliers`, `Categories`, `PriceHistory`, e cleanup dei file XLSX temporanei. |
| `docs/TASKS/TASK-089-large-dataset-sync-preview-benchmark-ios.md` | Stato aggiornato a **DONE / Chiusura — REVIEW PASS** e review finale registrata. |
| `docs/MASTER-PLAN.md` | Progetto riallineato a **IDLE**, TASK-089 ultimo completato, TASK-090 mantenuto **TODO / Planning — non aperto**. |

**Review tecnica codice:**

| Check review | Esito |
|--------------|-------|
| Harness DEBUG-only / escluso Release | PASS — `Task089SyntheticBenchmarkHarness.swift` è interamente sotto `#if DEBUG`; binario Release verificato senza `TASK089|Task089`. |
| Dati reali / segreti | PASS — solo prefissi sintetici `TASK089_*`, nessun token/JWT/service_role/connection string, nessun dump dataset. |
| Supabase write/delete/cleanup/migration | PASS — nessun comando o codice mutativo Supabase; LG5/S89-E SKIPPED. |
| API pubbliche / dipendenze | PASS — nessuna API `public`, nessuna dependency nuova, nessuna modifica `project.pbxproj`; progetto usa synchronized root groups. |
| UI production / Localizable | PASS — non toccati; nessuna UI production o stringa Release aggiunta. |
| Efficienza / memoria | PASS nel perimetro D89-M — dataset 2.500 prodotti / 5.000 price rows in memoria per test, dimensione accettabile; niente caricamenti enormi fuori dal target sintetico. |
| Ridondanza | ACCEPTABLE — il writer DEBUG replica localmente lo schema export perché i metodi reali sono privati in `DatabaseView`; nessun refactor production introdotto per evitare scope creep. |

**Check eseguiti in review:**

| Check | Stato | Evidenza |
|-------|-------|----------|
| `git status` | ✅ ESEGUITO | Working tree con modifiche TASK-089 e tracking; nessun commit/push. |
| `git diff --check` | ✅ ESEGUITO | PASS dopo fix. |
| Check whitespace untracked | ✅ ESEGUITO | PASS via `git diff --no-index --check` sui file nuovi TASK-089. |
| `xcodebuild -list -project iOSMerchandiseControl.xcodeproj` | ✅ ESEGUITO | Scheme `iOSMerchandiseControl`; target app + tests. |
| Test mirati TASK-089 | ✅ ESEGUITO | PASS: `Task089LargeDatasetBenchmarkTests`, 4 test / 0 failure. |
| Full XCTest | ✅ ESEGUITO | PASS: 567 test / 0 failure / 0 skipped da xcresult. |
| Release build | ✅ ESEGUITO | PASS: `xcodebuild build -configuration Release` su iPhone 16e Simulator iOS 26.2. |
| Nessun warning nuovo | ✅ ESEGUITO | PASS: xcresult build-results warningCount 0 nella full XCTest review. |
| Release binary DEBUG-only check | ✅ ESEGUITO | PASS: `strings .../Release-iphonesimulator/iOSMerchandiseControl.app/iOSMerchandiseControl | rg 'TASK089|Task089'` non trova match. |
| Coerenza planning | ✅ ESEGUITO | PASS: solo D89-M sintetico/read-only, nessuna mutazione, nessun D89-L inventato. |
| Criteri di accettazione | ✅ ESEGUITO | PASS/PARTIAL/SKIPPED motivati per scenario sotto. |
| Simulator/manual UI | ❌ NON ESEGUITO | Codice non tocca UI e il task non richiedeva test UI manuale; export UI production non guidato. |
| Supabase live/collision scan | ⚠️ NON ESEGUIBILE | Supabase non usato nel perimetro review; mutazioni consentite NO. |
| D89-L/device fisico/Instruments | ❌ NON ESEGUITO | Nessun device fisico/D89-L/Instruments nel perimetro autorizzato di questa review; residuo documentato. |

**Metriche review aggiornate:**

| Scenario | Esito | Evidenza |
|----------|-------|----------|
| LG1 Preview/read-mostly synthetic | **PARTIAL** | PASS component fake/paginazione/contenuto: 2.500 prodotti, 100 fornitori, 60 categorie, 5.000 price rows, page size 500, 6 product pages, 11 price pages, 454,53 ms. PARTIAL perché non misura Supabase live, rete/RLS/pooler, UI end-to-end o device reale. |
| LG2 Export prodotti synthetic | **PARTIAL** | PASS writer DEBUG/content: 2.500 prodotti, 43,12 ms, 169.034 byte, 2.501 righe, header e valori `TASK089_*` verificati. PARTIAL perché non guida `DatabaseView`/ShareSheet su device reale. |
| LG3 Export full DB synthetic | **PARTIAL** | PASS writer DEBUG/content: 2.500 prodotti, 100 fornitori, 60 categorie, 5.000 price rows, 80,03 ms, 304.126 byte, Products 2.501 righe, PriceHistory 5.001 righe, sheet extra verificati. PARTIAL perché non misura memoria/OOM/Instruments/D89-L. |
| LG4 Cancel/retry/recovery harness | **PASS** | ViewModel reale + coordinator fake cancellabile: primo feedback 3,40 ms, cancel recovery 2,17 ms, cancel visibile durante running e retry post-cancel presente; nessuna mutazione. |
| LG5 Apply controllato | **SKIPPED** | Gate §10 non GO: mutazioni consentite NO, nessun Supabase staging/local mutativo, nessun rollback mutativo necessario. |

**Privacy / safety:** PASS — nessun dato reale, nessun segreto, nessun Supabase write/delete/cleanup/truncate/drop/migration repair, nessun SQL/Android, nessun claim production-ready globale.

**Rischi residui / backlog non bloccanti TASK-089:**

- D89-L su device fisico con Instruments/memoria reale non eseguito.
- Preview Supabase live/read-only non misurata; rete, RLS, pooler e latenza restano fuori perimetro.
- Export UI production `DatabaseView` + ShareSheet non guidato manualmente.
- TASK-090 resta backlog separato per acceptance cross-platform finale; non aperto in questa review.

---

## 14. Decisioni (tracking planner)

| # | Decisione | Stato |
|---|-----------|--------|
| D89-01 | Namespace evidenza/future seed suggerito **`TASK089_*`**, disjoint dai namespace TASK085/086/087/088 | proposal |
| D89-02 | Prima priorità EXECUTION futura → **misura senza mutazioni iniziali** (alline MASTER-PLAN backlog) | proposal |
| D89-03 | Eventuali polish UI/UX futuri sono accettabili solo se migliorano feedback, cancel/retry, progress o messaggi e restano coerenti con lo stile iOS esistente | proposal |
| D89-04 | Separare sempre export prodotti e export full DB come scenari diversi per evitare diagnosi confuse su performance/memoria | proposal |
| D89-05 | Preferire evidenze aggregate e piccole rispetto a log completi per efficienza e privacy | proposal |
| D89-06 | Prima della EXECUTION serve matrice dataset/device; performance PASS senza device reale o senza dataset dichiarato è vietato | proposal |
| D89-07 | UX polish futuro deve privilegiare controllo percepito: progress, cancel/retry, errori leggibili, disabled state chiari | proposal |
| D89-08 | Ogni scenario futuro deve dichiarare PASS/PARTIAL/BLOCKED/NOT_RUN con motivo, non solo descrizione narrativa | proposal |
| D89-09 | Aggiungere un manifest EXECUTION compilabile prima di ogni RUN futura per evitare esecuzioni ambigue | proposal |
| D89-10 | PASS cumulativo vietato: ogni scenario LG deve avere esito e motivo separati | proposal |
| D89-11 | Nuovi strumenti diagnostici devono essere leggeri/localizzati; evitare infrastruttura di logging pesante dentro TASK-089 | proposal |
| D89-12 | Le micro-scelte UI/UX future sono delegate all’agente solo se seguono la policy §7.4 e restano polish localizzati | proposal |
| D89-13 | Vietato mostrare un cancel falso: se l’annullo reale non è sicuro, documentare recovery/retry e messaggio UI onesto | proposal |
| D89-14 | Accessibilità minima è parte del polish: VoiceOver label, Dynamic Type, contrasto nativo e target touch non devono peggiorare | proposal |

---

## 15. Checklist Planning Review prima di promuovere EXECUTION

Prima di chiedere override utente per EXECUTION, verificare:

- [ ] MASTER-PLAN allineato: TASK-089 ancora **ACTIVE / PLANNING**, TASK-088 ultimo completato, TASK-090 non aperto.
- [ ] Manifest §7.3 compilabile senza segreti e senza dati reali.
- [ ] Matrice dataset/device §7.2 compilata almeno per D89-S o D89-M.
- [ ] Soglie §7.1.1 confermate o modificate con motivazione.
- [ ] Scenari LG scelti e scenari skipped dichiarati.
- [ ] Mutazioni Supabase/locali disabilitate di default; S89-E resta SKIPPED senza GO esplicito.
- [ ] Eventuali polish UI/UX limitati a progress, feedback, retry, errori leggibili, disabled state o accessibilità minima.
- [ ] Policy UX/UI §7.4 accettata: nessun fake cancel, nessun redesign, nessuna nuova dipendenza UI, nessuna regressione accessibilità evidente.
- [ ] Nessun refactor, redesign, nuova architettura, nuova dipendenza o cleanup distruttivo nascosto nel task.
- [ ] Evidenze future previste in formato aggregato, privacy-safe e per-scenario.

**Nota storica planning:** prima dell'override execution/review, senza override utente il task sarebbe rimasto **PLANNING / NON READY FOR EXECUTION / TASK-089 NON DONE**.
