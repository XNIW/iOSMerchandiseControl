# TASK-083 — Smoke end-to-end iOS Release (Supabase sync mutativa)

## Informazioni generali

| Campo | Valore |
|-------|--------|
| **Task ID** | TASK-083 |
| **Titolo** | Smoke end-to-end iOS Release — catalogo, prezzi, outbox drain, recovery |
| **File task** | `docs/TASKS/TASK-083-supabase-end-to-end-release-smoke-ios.md` |
| **Stato** | DONE |
| **Fase attuale** | Chiusura — SUPERSEDED_BY_TASK097_TASK103 |
| **Responsabile attuale** | Codex / Reviewer |
| **Data creazione** | 2026-05-08 |
| **Ultimo aggiornamento** | 2026-05-12 19:18 -0400 — legacy alignment: runtime manifest/smoke gap superseded by TASK-097 and final TASK-103 evidence; vedi `docs/TASKS/EVIDENCE/LEGACY-CLOSURE-2026-05-12.md` |
| **Ultimo agente** | Codex / Reviewer |
| **Repo iOS** | `/Users/minxiang/Desktop/iOSMerchandiseControl` |

> **Chiusura legacy 2026-05-12:** le sezioni storiche sottostanti restano archivio; la fonte di verita' corrente e' `Chiusura — SUPERSEDED_BY_TASK097_TASK103` secondo `docs/TASKS/EVIDENCE/LEGACY-CLOSURE-2026-05-12.md`.

## Dipendenze

- **Dipende da:** **TASK-075 DONE / Chiusura** (smoke operativo Controlla cloud read-only evolutosi con fixture piccolo/non distruttivo); **TASK-078 DONE / Chiusura** (pull apply catalogo Release); **TASK-079 DONE / Chiusura** (push catalogo Release); **TASK-080 DONE / Chiusura** (ProductPrice apply/push Release); **TASK-081 DONE / Chiusura** (drain outbox Release **Registra attività sul cloud**); **TASK-082 DONE / Chiusura** (resolver stati/conflitti/timestamp Release iniziale, guard owner/sessione, invarianti piani volatili).
- **Sblocco effettivo:** la chiusura corrente non produce evidenza runtime reale per **TASK-084**/**TASK-085**; certifica solo che lo stop preflight TASK-083 è stato applicato correttamente. Un nuovo smoke runtime richiede prima un manifest sandbox completo.
- **Non apre né promuove:** **TASK-084**, **TASK-085** *(restano TODO / Planning; questa chiusura non li avvia)*.


---

## Obiettivo

Validare su build **Release** (e dove utile confronto **Debug**) un **flusso reale ma controllato** che concatena gli esiti progettuali di **TASK-078…TASK-082**, senza promettere sincronizzazione totale né parità catalogo/pricing globale implicita:

1. Contesto dati dal **sandbox / dataset piccolo** fino eventualmente al **dataset negozio**, solo dopo gate di sicurezza.
2. Esercitare in sequenza ordinata (**non** automatismi in background): **pull apply**, **push catalogo**, **ProductPrice** apply/push, **drain outbox** confermato, **cancel / retry / recovery** nei punti dove la UI Release lo permette.
3. Raccogliere **evidenze privacy-safe** (conteggi, esiti classe, screenshot senza UUID/payload/session token) sia per Release che dove utile Debug strumentato.
4. Chiudere con **summary documentale privacy-safe** e matrice PASS/PARTIAL/SKIPPED con rationale, non con claim «tutto allineato al cloud».

**Nota storica planning:** la versione iniziale di questo file non autorizzava EXECUTION Codex né smoke live; l'execution minima successiva è stata avviata solo con user override esplicito e si è fermata correttamente al preflight manifest.

---

## Stato iniziale e riferimenti letti

| Fonte | Uso nel planning TASK-083 |
|-------|---------------------------|
| `docs/MASTER-PLAN.md` | Roadmap TASK-083 come smoke E2E post TASK-082; sequenza backlog 084/085 ancora chiuse |
| **TASK-075** | Progressive dataset piccolo/grande; cancel/recovery UX; regressioni XCTest; **no cleanup outbox**/backend; DIVERSO perimetro: TASK-075 era prevalentemente preview read-only; TASK-083 aggiunge **mutazioni confermate** Release |
| **TASK-078** | Macro-flusso **Controlla cloud → Rivedi → Conferma → Aggiorna questo dispositivo → Summary**; staging volatile `SyncPreview`; `prepareApplyPlan` prima di apply; cancellation |
| **TASK-079** | Push catalogo post-conferma; preflight/read-only poi write; stato parziale/baseline refresh failed; priorità UX quando coexistono remote + local changes |
| **TASK-080** | Sezione **Prezzi da aggiornare**; apply/push prezzi con piano volatile e conteggi `applied`/`pushed`/`skipped*`/`blocked`/`failed`; accoppiamento `priceHistoryIncomplete` su guard catalog — da osservare in smoke concatenato |
| **TASK-081** | Drain **solo** dopo Rivedi, CTA **Registra attività sul cloud**, summary aggregati (registrate / in attesa / non registrabili); **vietato truncate/reset/delete outbox** |
| **TASK-082** | `SupabaseSyncPlan`/resolver CTA/conteggi/sezioni **Attenzione**; fail-closed su owner/session quando incerti; dedupe/conflict ProductPrice mappati a summary utente |

Riferimento schema Supabase: **solo lettura** sul clone `/Users/minxiang/Desktop/MerchandiseControlSupabase` quando serve chiarezza contrattuale; **nessuna** migrazione live vincolante da questo planning.

---

## Perimetro esatto (solo documentation + futura EXECUTION quando autorizzata)

- Smoke **guidato dall’utente** nella UI Release (**Opzioni → Sincronizzazione cloud** e sheet collegate): stessi percorsi implementati nei task sopra citati.
- Verificare coerenza end-to-end: stati dopo ogni passo rilevanti, **summary volatility** dove definita, ripartenza dopo **cancel** e **retry** esplicito.
- Contrasto Debug vs Release nei limiti consentiti (**evidenze**): Debug può contenere tooling non mostrato in Release solo per diagnostica dell’executor, sempre **privacy-safe**.
- Osservazione **counts** aggregate outbox/sync **senza** dump payload (allineamento **TASK-081** / **TASK-074** governance).
- Rieseguire in fase EXECUTION (non ora) subset **XCTest** indicati nella matrice automatica dopo accordo reviewer.

---

## Fuori perimetro severo

- **Nessuna** migrazione / `db push` / modifica SQL/RLS/RPC/backend **live** non esplicitamente autorizzata fuori questo task futuro e da task separati.
- **Nessun** cleanup distruttivo: **vietato reset/truncate/delete** outbox, wipe tabelle SwiftData né «svuota coda» batch non previsto dai servizi Release.
- **Nessuna** sync automatica, **Timer**, **BGTask**, **Realtime**, **worker**, **polling** per proseguire o completare smoke.
- **Nessuna** modifica **Android**.
- **Nessuna** modifica allo **schema SwiftData**, **`project.pbxproj`**, **`Localizable.strings`**, né codice Swift **in questo turno planning**.
- **Nessun** ritocco **UI/UX implementativo** in questo turno: eventuali miglioramenti estetici o UX emersi dal planning devono restare come **criteri/verifiche** o **follow-up futuri**, non come patch Swift dentro TASK-083 PLANNING.
- **Nessuna** azione nei dati **Supabase** di sola produzione eccetto operazioni dell’app iOS nell’EXECUTION autorizzato ( questo planning **non** esegue write né drain live ).
- TASK-084 (parità Android) e TASK-085 (hardening performance/osservabilità estesa): **solo backlog**, non parti dello smoke E2E iOS pianificato qui salvo prerequisiti espliciti futuri.

---

## Smoke plan progressivo

Ordine suggerito: completare gli step **sicuri** prima di aumentare cardinalità dataset o ambiente produttivo. Ogni literal **Go** per passare al livello successivo è nei **§ Criteri Go/No-Go**.

### (a) Dataset piccolo / sandbox

- Fixture o database locale con **pochi prodotti/fornitori/categorie/prezzi**, utile anche come **surrogate XCTest** quando applicabile (`TASK-075` precedentemente ha sbloccato path test-sandbox).
- Obiettivo: vedere navigazione Completa delle fasi mutate con latenza contenuta e conteggi verificabili a mano.

### (b) Dataset medio

- Ordine migliaio di righe o volume intermedio replicabile sul Simulator/dispositivo di test (**senza** necessità di essere il negozio reale).

### (c) Dataset reale negozio — solo se sicuro

**Condizioni minime suggerite (non autorizzate da solo questo markdown):**

- Account di test proprietario chiaro **o** consenso scritto su owner/progetto Supabase bersaglio.
- Backup / export locale possibile prima del primo apply/push reale (**policy personale**/team fuori repo).
- **STOP** immediato su errori ripetuti, divergenza RLS/sessione (`TASK-082` guard owner), o incompletamenti `priceHistory` che bloccano catalogo (**TASK-080** guard).

### (d) Debug

- Registrare comportamento degli stessi passi Release quando eseguito in Debug (**log console** consentiti dove già disponibili) per diagnosi dell’executor, **mai** inclusi in evidenza utente finale né report esterni senza sanitizzazione.

### (e) Release

- **Fonte primaria PASS/FAIL UX** prodotta dall’Executor: compilazione/installazione conforme distribuzione Release; **grep copy** storico anti-jargon sulla card (**TASK-074/076** governance).

### (f) Cancel / retry / recovery

Casistiche raccomandate (una per tipo se possibile):

- **Durante Controlla cloud / preview lunga**: annullamento; poi **Riprova** dalla card (**TASK-075** pattern).
- **Dopo conferma ma durante apply/pull/push/drain**: se la UI permette interrupt, verificare stato non corrotto e rientrata guidata (**TASK-078/079/081** cancellation pattern).
- **Retry** solo via CTA **Riprova** / **Riallinea dati** / **Accedi** dove previsto dai piani TASK-079/082.
- Osservazioni **recovery** dopo `partial`/`failed`/network: summary onesto (**TASK-079**/`TASK-081` **D81-11**, ecc.) — nessuna retry loop automatico.

### (g) Pull apply — catalogo

- **Controlla cloud** prodotta preview conforme (**TASK-073/078**) → sheet **Rivedi** (`TASK-077+`) → conferma sistema → **Aggiorna questo dispositivo**.
- Evidenziare conteggi applicati/skipped/conflict bloccati coerenti con **TASK-082**.
- Fail atteso conservativo: **`previewStale`**, **`conflictsPresent`**, **`priceHistoryIncomplete`** (blocco anche apply solo-catalogo quando i guard sono attivi — **TASK-080** coupling).

### (h) Push catalogo

- Percorso dopo Rivedi: **Invio modifiche al cloud** secondo TASK-079; verificare pre-write stale/auth recheck quando applicabile (**TASK-082** recap).
- Conteggi `completed` / `partial` / `blockedBeforeWrite` / `failedBeforeWrite` e messaggio priorità quando coexistono modifiche (**TASK-079** journaling MASTER-PLAN).

### (i) ProductPrice — apply + push Release

- Sezione sheet **Prezzi da aggiornare** inclusa nella review unificata (**TASK-080**).
- Scenario minimo sicuro con **effective_at** deterministico locale + conferma dry-run quando presente nell’implementazione (**TASK-080**).
- Conteggi: `skippedDuplicate`, `skippedConflict`, `blocked` senza double-count nei summary riportati dall’implementazione TASK-082 fix review.

### (j) Drain outbox

- Percorso **Registra attività sul cloud** solo dopo aver visto stato coerente in **Rivedi** (**TASK-081** decisioni **D81-01…03**): batch bounded tramite adapter/servizio esistenti, **mai** truncate.
- Osservazione esiti **`sent`** / **`retryScheduled`** / **`blocked`** / **`dead`** / **`partiallyDrained`** come classi privacy-safe, non come dump entry.

### (k) Summary finale privacy-safe

- Tabella sintetica: build (Debug|Release), fase raggiunta, esito classe (SUCCESS|PARTIAL|CANCELLED|FAIL), **solo conteggi o messaggi pubblici stringa Release**, commit hash/versione app, ora esecuzione, note **anonimizzate** (es. «rete cellulare unstable» OK, token/JWT/email no).

### Scenari operativi S83 — ordine consigliato per futura execution

Questi scenari **non sono execution**: servono a rendere il piano più efficiente e meno ambiguo quando verrà autorizzata una fase **EXECUTION** separata.

| ID | Dataset | Build | Scopo | Esito minimo accettabile |
|----|---------|-------|-------|---------------------------|
| S83-01 | Piccolo/sandbox | Release | Sanity end-to-end: Controlla cloud → Rivedi → Summary senza write | PASS o BLOCKED motivato |
| S83-02 | Piccolo/sandbox | Release | Pull apply catalogo confermato | PASS/PARTIAL con conteggi chiari |
| S83-03 | Piccolo/sandbox | Release | Push catalogo confermato dopo ricontrollo sessione/baseline | PASS/PARTIAL senza duplicati |
| S83-04 | Piccolo/sandbox | Release | ProductPrice apply/push con duplicato/conflitto controllato | PASS/PARTIAL, niente doppio storico prezzo |
| S83-05 | Piccolo/sandbox | Release | Drain attività tramite Registra attività sul cloud | PASS/PARTIAL, attività residue separate |
| S83-06 | Piccolo/sandbox | Release | Cancel/retry/recovery su almeno una fase lunga | PASS se nessun write non confermato |
| S83-07 | Piccolo/sandbox | Debug | Diagnostica parallela solo se serve spiegare partial/fail Release | PASS diagnostico, privacy-safe |
| S83-08 | Medio | Release | Performance percepita, progress e summary su volume maggiore | PASS/PARTIAL_EXPECTED documentato |
| S83-09 | Negozio reale | Release | Smoke reale controllato, solo dopo PASS S83-01…08 e consenso/preflight | OPTIONAL, mai prerequisito per chiudere planning |

**Regola di efficienza:** se **S83-01…06** non sono chiari o producono **BLOCKED**, non passare a dataset medio o negozio reale. Aprire invece **follow-up tecnico/UX dedicato**.

---

## Preflight richiesti prima di qualsiasi execution futura

1. Leggere e accettare handoff PLANNING questo file + **incoerenze MASTER-PLAN ↔ file task risolte** prima di EXECUTION (`CLAUDE.md` policy).
2. **Account Supabase** di test configurato nell’app, sessione rinnovabile, **owners** chiari (**TASK-082**).
3. **Baseline** leggibile/coerente dopo eventuali push precedenti; capire comportamento quando baseline refresh fallisce (**TASK-079** stato `completedBaselineRefreshFailed`).
4. Elenco ordinato degli **scenario smoke** (`S83-xx` dalla matrice) approvati dal reviewer; **freeze** delle versioni iOS/OS target usate nell’EXECUTION (**TASK-075** suggerisce documentare Simulator/device).
5. **Backup locale** delle policy quando si lascia sandbox per dataset reale (**fuori automatismo codice**, responsabilità team).
6. Confermare **no** modifiche migration backend richieste dallo smoke: se drift rilevato → **STOP** → task tecnico backend separato.
7. Coordinare **enqueue outbox naturale**: lo smoke deve usare comportamento app — **vietato inject artificiale** di eventi tramite tooling non autorizzati se viola sicurezza/RLS (**fuori questo planning**, decisione progetto).
8. Confermare che la UI Release usi **copy utente** e non gergo tecnico: **attività locali**, **modifiche sul cloud**, **questo dispositivo**, **prezzi**, **riprova**, **ricontrolla**; evitare **outbox**, **sync_events**, **RPC**, **payload**, **owner_user_id**, **RLS**, **baseline**, **dry-run** nella UI Release.
9. Prima di ogni **write remoto** futuro, ricontrollare **sessione/account/owner** e validare che il **piano visualizzato nello sheet** non sia **stale**: se non è certo, **NO-GO**.
10. Definire in anticipo **soglie dataset**: piccolo/sandbox **obbligatorio**, medio **solo dopo** PASS piccolo, negozio reale **solo dopo** PASS piccolo+medio + preflight completi.
11. Stabilire cosa conta come **PASS**, **PARTIAL**, **BLOCKED**, **CANCELLED** per ogni scenario **S83-xx** prima di iniziare la futura execution.
12. Confermare che eventuali **ritocchi UI/UX** desiderati dopo lo smoke siano registrati come **follow-up separati** e **non** applicati dentro TASK-083 planning.

---

## Evidenze da raccogliere

| Tipo | Contenuto | Divieto |
|------|-----------|---------|
| Screenshot/video processo | Solo UI Release pubblica durante smoke | Nessun campo password, OTP, bearer token overlay |
| Log Debug | Path file e timestamp relativi allo step | Nessun campo `Authorization`, URL con query segreti, JSON payload business |
| Conteggi | Aggregati dai summary UI ufficiali | Nessun lista barcode completa cliente reale in report pubblici |
| Remoto osservabile | Lettura tramite Dashboard Supabase *se policy team lo consente* | Nessuna pubblicazione screenshot RLS/policy ID utente esterni |
| Config run | Xcode scheme, destinazione Simulator/device, lingua UI | Nessun contenuto Secrets.plist / xcconfig segreti in chiaro nel report |
| Xcode / test automatici | Log numeri PASS/FAIL (EXECUTION solo autorizzati) | Non mascherare test non eseguiti come PASS (**CODEX protocol** coerenti) |

### Convenzione naming evidenze futura

Per evitare confusione tra run e non mescolare Debug/Release, usare una convenzione tipo:

`TASK-083_S83-xx_<Debug|Release>_<YYYY-MM-DD>_<PASS|PARTIAL|BLOCKED|CANCELLED|FAIL>`

Ogni evidenza deve indicare: scenario **S83-xx**, build, dataset usato, stato finale, conteggi aggregati e note **privacy-safe**. Se una fase non è stata eseguita, scrivere **NOT RUN**, non lasciarla implicita.

---

## Matrice test — manuale e automatica

### Manuale (Release-first; PASS richiede comportamento osservabile)

| ID | Scenario | Dipendenze | Note esito |
|----|----------|------------|-----------|
| M83-01 | Controlla cloud completo sandbox → summary compatto (`TASK-074`) | 075/073 | |
| M83-02 | Rivedi: sezioni cloud↔dispositivo/prezzi/attenzione coerenti al piano (`TASK-077/082`) | 082 | |
| M83-03 | Pull apply catalogo dopo conferma; verifica SwiftData osservabile (UI database o inspector personale autorizzato) | 078 | |
| M83-04 | Push catalogo confermato → verifica remota read-only sicura (**non** questo planning) oppure osservazioni app post-push | 079 | |
| M83-05 | Apply prezzi dopo conferma; push prezzi quando UI lo propone (`TASK-080`) | 080 | |
| M83-06 | Drain: eventi pendenti registrati quando presenti; stato vuoto maneggiato (**TASK-081** **D81-06**) | 081 | |
| M83-07 | Cancel durante long-run + recovery stato card | 075/078 | |
| M83-08 | Retry dopo `partial`/network retryable (**TASK-079/081**) | 079/081 | |
| M83-09 | Caso bloccati conflitto catalogo (**TASK-082**) | 082 | Nessun proseguimento forzato |
| M83-10 | Dataset medio: timeout perceptibile gestito (**PARTIAL_EXPECTED** registrato honestly) | 075 analogue | |
| M83-11 | Micro-smoke UX/UI Release su copy, CTA, sheet Rivedi, progress, summary e accessibilità prima del dataset negozio | 074/076/077/082 | Obbligatorio prima di dataset reale |
| M83-12 | Coesistenza remote + local changes: priorità UX **Aggiorna questo dispositivo** prima di **Invia modifiche al cloud** | 078/079/082 | Evita push sopra baseline potenzialmente vecchia |
| M83-13 | Drain attività locali dopo apply/push: CTA separata **Registra attività sul cloud**, non automatica | 081 | Nessun drain implicito |
| M83-14 | Summary riaperto o ricontrollo dopo partial/cancel: nessuno stato stale presentato come attuale | 079/081/082 | Summary coerente o richiesta ricontrollo |
| M83-15 | Naming evidenze e classificazione PASS/PARTIAL/BLOCKED/CANCELLED/FAIL applicati a ogni scenario S83-xx | Governance TASK-083 | Vietato mascherare NOT RUN come PASS |

### Automatica (non obbligatoria nel planning solo; EXECUTION sceglierà comandi/scheme repo)

Suite orientative (**da rieseguire / estendere** solo se EXECUTION dichiarato):

- `SupabaseManualSyncViewModelTests`, `SupabaseManualSyncReleaseUITests`
- Pull apply / ProductPrice push dry-run/manuale correlati (**TASK-078/080**) come da file test esistenti
- `LocalizationCoverageTests`, `Localization` / `plutil` check coerenti **TASK-076/082**
- `SyncEventOutboxDrain*` + adapter drain Release testati (**TASK-081**)
- Regressioni storiche orchestratore/outbox (**TASK-064…065** lineage) quando toccati da cambi futuri

**Regola**: test automatico **PASS** ≠ smoke E2E PASS; gli automatici fungono gate regressione mentre lo smoke è integrazione comportamentale rete + UI.

---

## Rischi e rollback / recovery

| Rischio | Impatto | Mitigazione pianificata |
|---------|---------|-------------------------|
| Volume negozio reale ⇒ tempi lunghi UI | Esperienza perceived hang o partial | Preferire medio/piccolo; documentare partial onesti (**TASK-075** classifica) |
| Accoppiamento prezzo↔catalogo (`priceHistoryIncomplete`) | Pull apply blocca anche quando utente vuole solo catalogo | Rendere evidente nell’EXECUTION (**TASK-080** coupling) — remediation = fix dati/API — **fuori TASK-083** se richiede SQL |
| Stale tra review e conferma | `previewStale`/push blocked | Rieseguire Controlla cloud manuale (`TASK-078/079` pattern recheck auth) |
| Outbox bloccati **`dead`/payload invalid** | Drain non progredisce | Osservazione conteggio «non registrabili» (**TASK-081**); escalation manuale out-of-band |
| Doppio apply su stress tap | Rischi logici duplicati | Verificare reentrancy guard UI (**TASK-078/079/081**); EXECUTION registra comportamento osservato |
| Data loss sentiment su device tester | Confidence team su dataset reale | Backup locale + account test dedicato (**preflight**) |

### Classificazione esiti standard

| Esito | Significato | Uso corretto |
|-------|-------------|--------------|
| **PASS** | Lo scenario osservato corrisponde al comportamento atteso e i conteggi sono coerenti | Solo quando tutte le verifiche richieste sono state davvero eseguite |
| **PARTIAL** | La funzione principale lavora ma restano skip, blocchi, retry, lentezza o incompletezze spiegate | Da preferire a PASS quando ci sono dubbi o dati non completi |
| **BLOCKED** | Lo scenario non può partire o proseguire per preflight, auth, baseline, ambiente, schema o rischio dati | Non è un fallimento dell'app se il blocco è corretto e fail-closed |
| **CANCELLED** | L'utente/executor annulla prima del completamento | PASS solo per la parte cancel se nessun write non confermato avviene |
| **FAIL** | Crash, duplicazione dati, write non confermato, summary falso/stale, perdita coerenza o violazione anti-scope | Richiede stop e follow-up separato |
| **NOT RUN** | Scenario non eseguito | Deve essere dichiarato esplicitamente, mai omesso |

**Rollback non distruttivo iOS tester:** reinstall app / restore backup SwiftData se policy team (**NESSUN comando script qui** durante planning); **Rollback remoto**: **non** garantito da questo task — fix dati deve essere progetto/backend separati se corruttivi (**Go/No-Go** blocca EXECUTION quando incerto).

---

## Criteri Go / No-Go per EXECUTION futura

**GO EXECUTION Codex/smoke quando tutti gli applicabili:**

- [ ] Handoff PLANNING approvato (review Claude o user override conforme governance).
- [ ] Preflight checklist superata sopra (**§ Preflight**) senza blocchi tecnici sconosciuti.
- [ ] Ambiente Xcode/Simulator/Device e credenziali test disponibili all’executor.
- [ ] Definito ordinatamente gli step **`S83` manuali** prioritari (**minimo sanity path**) vs **stretch** dataset reale (**opzionale**).
- [ ] Backlog TECH bloccanti (drift RPC/RLS) **assenti** o **documentati** come STOP condizionale.

**NO-GO (fermate esplicite):**

- Backend richiede migration non autorizzata per riprodurre evenienze base.
- Rischio per dati cliente reale non mitigabile (assenza backup / assenza consent).
- Stato progetto MASTER-PLAN/task file incoerente su task attivo o fase **EXECUTION** (blocco `CLAUDE.md` / `AGENTS.md`).
- Tentativo implicito di sync automatica o tooling drain/live fuori dalla UI (**anti-scope** sopra).

---

## Criteri di accettazione (contratto EXECUTION/Reviews future — placeholders)

Applicabili **solo dopo** una transizione valida **PLANNING → EXECUTION** tramite progetto/handoff autorizzati.

- [ ] Smoke **sandbox** (**a+b+d+e+f minimal**) documentato PASS o PARTIAL con rationale per ogni classe attesa (**non ora** questo planning).
- [ ] Se eseguito: smoke **dataset reale sicuro** (**c**) con evidenza **(k)** e **privacy-safe** garantita (**non ora** questo planning).
- [ ] Concatenazione **pull apply**, **push catalogo**, **ProductPrice**, **drain outbox**, con **recovery** (**f**) verificata almeno su scenari sintetizzabili sicuri (**non ora** questo planning).
- [ ] Nessuna regressione degli anti-scope sopra dichiarabile come introdotta da questo smoke (**EXECUTION verifier**).
- [ ] XCTest regressione concorde eseguito e PASS documentato nell’HANDOFF EXECUTION (**non ora** questo planning).

---

## Decisioni (Planning)

| # | Decisione | Motivazione | Stato |
|---|-----------|-------------|--------|
| D83-01 | Piano smoke progressivo sandbox → medio → prod condizionale | Riduce blast radius TASK-084/085 | bozza planning |
| D83-02 | Release fonte UX primaria PASS; Debug solo diagnostico | TASK-074/067 governance Release | bozza planning |
| D83-03 | Outbox sempre senza truncate; drain solo dopo Rivedi | TASK-081 vincoli | bozza planning |
| D83-04 | Accoppiamento prezzi/catalogo tratto come osservabile esplicitamente nello EXECUTION reporting | TASK-080/078 coupling | bozza planning |
| D83-05 | Quando coesistono remote changes e local changes, il percorso UX preferito è prima **Aggiorna questo dispositivo**, poi **Invia modifiche al cloud** | Riduce rischio di push sopra baseline remota vecchia | bozza planning |
| D83-06 | **Registra attività sul cloud** resta azione manuale separata da apply/push catalogo/prezzi | Coerenza TASK-081, evita write impliciti | bozza planning |
| D83-07 | La UI Release deve evitare gergo tecnico e usare copy orientato all'utente | Migliora UX e coerenza app iOS | bozza planning |
| D83-08 | Il dataset negozio è vietato finché micro-smoke UX/UI + dataset piccolo + dataset medio non sono PASS o consapevolmente approvati | Riduce blast radius operativo | bozza planning |
| D83-09 | In caso di scelta tra flusso più rapido e flusso più sicuro, prevale sempre la sicurezza dati | Principio guida per smoke mutativo | bozza planning |
| D83-10 | Gli scenari **S83-xx** sono l'unità minima di reporting della futura execution | Riduce ambiguità e migliora confrontabilità Debug/Release | bozza planning |
| D83-11 | Ogni scenario non eseguito deve essere marcato **NOT RUN**, non lasciato implicito | Evita claim di copertura falsi | bozza planning |
| D83-12 | Eventuali polish UI/UX emersi dallo smoke diventano follow-up separati, salvo override esplicito | TASK-083 misura il comportamento, non implementa nuove UI | bozza planning |

---

## Integrazione Planning — UX/UI, efficienza e recovery

Questa integrazione perfeziona il piano senza promuovere TASK-083 a execution. Le regole sotto sono criteri di verifica e decisioni di planning: **non autorizzano codice Swift, smoke live o write Supabase**.

### UX/UI Release da validare

- Flusso principale preferito: **Controlla cloud → Rivedi → Conferma → Aggiorna questo dispositivo / Invia modifiche al cloud / Registra attività sul cloud → Riepilogo finale**.
- Se esistono insieme modifiche remote e locali, scegliere il percorso più sicuro: prima **Aggiorna questo dispositivo**, poi **Invia modifiche al cloud**.
- **Registra attività sul cloud** deve restare azione manuale separata e confermata, non automatica.
- Release UI senza gergo tecnico: evitare `outbox`, `sync_events`, `RPC`, `payload`, `owner_user_id`, `RLS`, `baseline`, `dry-run` nel copy utente.
- Copy preferito: **attività locali**, **modifiche sul cloud**, **questo dispositivo**, **prezzi**, **riprova**, **ricontrolla**.
- Se l'esito è parziale, non usare “tutto sincronizzato”; usare un messaggio tipo **Alcune modifiche richiedono attenzione**.
- Una sola CTA primaria per stato; azioni secondarie meno prominenti o in menu.
- Sheet SwiftUI quando servono dettagli/conteggi/sezioni; `confirmationDialog` solo per conferme brevi.

### Micro-smoke UI obbligatorio prima del dataset negozio

Prima di usare il dataset reale negozio, la futura execution deve validare con dataset piccolo/sandbox:

| Area UI | Verifica richiesta | Esito atteso |
|---------|-------------------|--------------|
| Card Opzioni / Sincronizzazione cloud | Stato iniziale, running, cancel, retry, disabled | Una sola CTA primaria evidente |
| Sheet **Rivedi** | Sezioni cloud→device, device→cloud, prezzi, attività locali, attenzione | Conteggi chiari, nessun gergo tecnico Release |
| Conferme | Apply locale, push remoto, drain attività | Ogni write è esplicito, separato e annullabile prima della conferma |
| Progress | Operazioni lunghe, cancel, recovery | Feedback visibile; cancel non lascia stato ambiguo |
| Summary finale | Successo, partial, blocked, cancelled, failed | Copy onesto e privacy-safe |
| Accessibilità | Dynamic Type, VoiceOver label, contrasto | Nessuna informazione solo colore/icona |
| Localizzazioni | IT / EN / ES / zh-Hans | Nessuna chiave mancante; placeholder coerenti |

### Efficienza operativa dello smoke

- Dataset piccolo/sandbox obbligatorio prima; dataset medio solo dopo PASS piccolo; dataset negozio solo dopo PASS piccolo+medio e preflight completi.
- Ogni run deve dichiarare dataset, build, account/sessione, obiettivo, criterio PASS/PARTIAL/BLOCKED.
- Raccogliere tempi indicativi per preview, apply locale, push catalogo, ProductPrice, drain attività, cancel/retry.
- Preferire evidenze aggregate e campioni anonimi, non dump completi di righe reali.
- Non “forzare” completamento con script, polling, cleanup, reset, Timer, BGTask, Realtime o worker.
- Se emergono problemi di performance/UX, registrarli come follow-up separato, non risolverli dentro TASK-083 planning.

### Failure / recovery da coprire in futura execution

| Scenario | Aspettativa UX/dati |
|----------|---------------------|
| Cancel durante **Controlla cloud** | Stato annullato, CTA **Riprova**, nessun write remoto |
| Cancel prima di apply locale | Nessuna modifica locale applicata |
| Apply locale parziale o bloccato | Summary **Alcune modifiche richiedono attenzione**, retry/ricontrollo manuale |
| Push catalogo con sessione cambiata/stale | Write bloccato fail-closed; richiesta ricontrollo/accesso |
| ProductPrice duplicato o conflitto | Conteggi skip/conflitto, niente crash, niente doppio storico prezzo |
| Drain attività parziale | Attività registrate e ancora in attesa separate chiaramente |
| Retry dopo errore | Non duplica dati già applicati/inviati; idempotenza preservata |
| Riapertura sheet/summary | Stato coerente oppure richiesta esplicita di ricontrollo |

### Criterio di permanenza in Planning (storico)

Al momento di questa integrazione planning:

- Le nuove tabelle **S83-xx**, **esiti standard** e **naming evidenze** servono solo a preparare una **futura execution** più efficiente e controllabile.
- **TASK-083 restava ACTIVE / PLANNING**.
- **TASK-083 restava READY FOR PLANNING REVIEW**.
- **TASK-083 restava NON READY FOR EXECUTION**.
- Nessuna sezione aggiunta può essere interpretata come autorizzazione a eseguire smoke, modificare codice o scrivere su Supabase.

## Planning (Claude)

### Analisi

TASK-082 ha chiuso la cutline iniziale su stati/conflict-aware UI; TASK-078…081 coprono mutate verticali discrete. TASK-083 **non è una nuova feature**: è una **campagna di osservabilità comportamentale reale**, necessaria perché XCTest/unit non sostituiscono ciclo vita complesso su rete, sessione Supabase owner e combinazione apply+push+prices+outbox nell’effettivo uso manuale. TASK-075 fornisce metodologia su dataset sizing e expectation **PARTIAL_EXPECTED**.

### Approccio proposto (documentale questo turno)

1. Freeze planning su questa roadmap micro-step **§ Smoke plan**.
2. Review planning Claude vs user ⇒ eventuale PROMOTION handoff EXECUTION (**non** questo file da solo).

### Rischi documentali identificati

- Eccedenza scope ANDROID/cross-parità → rimandato **TASK-084**.
- Eccedenza performance/osservabilità estesa offline/crash ⇒ **TASK-085**.

---

## Handoff — stato PLANNING TASK-083 (questo sprint)

**READY FOR PLANNING REVIEW.**

**NON READY FOR EXECUTION.**

- **Azione suggerita prossimo reviewer / utente**: validare Preflight (**§**), micro-smoke UX/UI, priorizzazione scenari **`M83-xx`** / **`S83-xx`**, classificazione esiti e decisioni **D83-05…D83-12**; poi solo con override esplicito autorizzare una futura transizione PLANNING→EXECUTION su voce giornale MASTER-PLAN conforme governance.
- **Prossimo agente previsto dopo review OK**: progetto eventualmente EXECUTION affidato a Codex (**non** ora).

---

## Execution

### Avvio EXECUTION — 2026-05-08 20:37 -0400

- **User override / autorizzazione:** l'utente ha autorizzato solo l'execution minima controllata **S83-01**, **S83-02**, **S83-03**, **S83-04**, **S83-05**, **S83-06**. Restano non autorizzati **S83-08** dataset medio, **S83-09** negozio reale, cleanup/reset/truncate/delete, SQL/backend/schema/RLS/RPC, Android, sync automatica, Timer/BGTask/Realtime/worker/polling.
- **Coerenza MASTER-PLAN:** verificata. TASK-083 era task attivo **ACTIVE / PLANNING** e il file task indicato nel MASTER-PLAN corrisponde al file reale. Promozione a **ACTIVE / EXECUTION** eseguita in `docs/MASTER-PLAN.md` e in questo file.
- **Dipendenze lette:** `TASK-075`, `TASK-078`, `TASK-079`, `TASK-080`, `TASK-081`, `TASK-082` letti e verificati come **DONE / Chiusura**.
- **Obiettivo compreso:** eseguire smoke end-to-end iOS **Release** su dataset piccolo/sandbox, privacy-safe e riproducibile, osservando i percorsi **Controlla cloud → Rivedi → Summary**, pull apply catalogo, push catalogo, ProductPrice apply/push, drain attività con CTA separata, cancel/retry/recovery. Nessun claim di completion globale se scenari sono **NOT RUN**, **BLOCKED**, **PARTIAL** o **FAIL**.
- **File controllati finora:** `docs/MASTER-PLAN.md`; questo file TASK-083; task dipendenti `TASK-075`, `TASK-078`, `TASK-079`, `TASK-080`, `TASK-081`, `TASK-082`.
- **File modificati finora:** `docs/MASTER-PLAN.md`; `docs/TASKS/TASK-083-supabase-end-to-end-release-smoke-ios.md`.
- **Piano minimo di intervento:** 1) registrare baseline run; 2) confermare manifest dataset piccolo/sandbox; 3) se manifest e ambiente sono chiari, eseguire **S83-01…S83-06** in ordine; 4) prima di ogni write remoto, recheck sessione/account/owner/baseline e richiedere conferma utente esplicita; 5) fermarsi su qualunque stop condition; 6) aggiornare il report con esiti scenario per scenario.

### Baseline prima run

- **Branch:** `main`
- **Commit:** `68a8f9f3f58a`
- **Working tree:** dirty prima della promozione tracking: `M docs/MASTER-PLAN.md`; `?? docs/TASKS/TASK-083-supabase-end-to-end-release-smoke-ios.md`
- **Xcode:** `Xcode 26.4.1` / `Build version 17E202`
- **Target/device/simulator previsto:** iPhone 16e Simulator, iOS 26.2; dispositivi disponibili rilevati `423B9CA2-9C81-4850-898A-AE064A3A1C09` e `4CE85775-BEF1-44D5-9BBF-B180EDF09D0B`, entrambi `Shutdown` al momento baseline.
- **Configurazione prevista:** Release per S83-01…S83-06.
- **Lingua UI prevista:** da confermare prima della run UI; default atteso Simulator non ancora verificato.
- **Account/sessione Supabase:** non ancora verificato in UI/runtime; non saranno riportati dati sensibili.
- **Run ID provvisorio:** `TASK-083_S83-01_Release_2026-05-08_BLOCKED`

### Dataset manifest — preflight

- **Stato:** **BLOCKED**.
- **Requisito minimo manifest:** prodotto invariato; prodotto nuovo remoto; prodotto locale da inviare; prezzo cambiato; duplicato/conflitto controllato; attività locale registrabile; eventuale attività retryable/non registrabile se già disponibile.
- **Verifica eseguita:** ricerca read-only in documenti, fixture, test e storico task. Trovati solo dataset/strumenti parziali: fixture TASK-075 e dataset storico `TASK045_*` per supplier/category/product; nessun manifest TASK-083 completo e approvato per catalogo + ProductPrice + conflitto controllato + attività outbox.
- **Stop applicato:** il manifest piccolo/sandbox non è chiaro e non copre i requisiti minimi; prepararlo richiederebbe creare/manipolare dati o usare contesto live non autorizzato. La run viene marcata **BLOCKED** e non si procede con UI runtime né write remoti.

### S83-01 — Sanity end-to-end: Controlla cloud → Rivedi → Summary senza write

- **Run ID:** `TASK-083_S83-01_Release_2026-05-08_BLOCKED`
- **Build:** Release build PASS (`xcodebuild build -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Release -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' -derivedDataPath /tmp/task083-release-dd`)
- **Commit:** `68a8f9f3f58a`
- **Ambiente:** iOS Simulator iPhone 16e / iOS 26.2 disponibile; Supabase config plist valido e ignorato da git, account/sessione non verificati in UI per stop preflight
- **Dataset:** **BLOCKED** — manifest piccolo/sandbox TASK-083 mancante/incompleto
- **Stato:** BLOCKED
- **Cosa è stato fatto:** baseline tracking, ricerca manifest read-only, build Release, `git diff --check`, `plutil -lint` localizzazioni. UI runtime non avviata perché il manifest richiesto non è chiaro.
- **Conteggi aggregati:** non disponibili
- **Evidenze privacy-safe:** branch `main`, commit `68a8f9f3f58a`, Xcode `26.4.1`, build Release PASS, `SupabaseConfig.plist` valido e non tracciato; nessun token/URL/account stampato.
- **Errori/cancel/retry:** nessuno
- **Follow-up:** Claude/utente deve fornire o approvare un manifest piccolo/sandbox completo per TASK-083, includendo anche ProductPrice, conflitto controllato e attività registrabile, senza cleanup distruttivo.
- **Note:** nessun write remoto autorizzato o avviato; nessun run UI eseguito.

### S83-02 — Pull apply catalogo confermato

- **Run ID:** da assegnare quando S83-02 parte
- **Build:** Release, non ancora eseguita
- **Commit:** `68a8f9f3f58a`
- **Ambiente:** non ancora verificato runtime
- **Dataset:** piccolo/sandbox non ancora confermato
- **Stato:** NOT RUN
- **Cosa è stato fatto:** non ancora eseguito.
- **Conteggi aggregati:** non disponibili
- **Evidenze privacy-safe:** non disponibili
- **Errori/cancel/retry:** nessuno
- **Follow-up:** richiede PASS/PARTIAL spiegato di S83-01 e recheck sessione/account/owner/baseline prima del write locale.
- **Note:** nessun write remoto previsto; apply locale solo dopo conferma.

### S83-03 — Push catalogo confermato

- **Run ID:** da assegnare quando S83-03 parte
- **Build:** Release, non ancora eseguita
- **Commit:** `68a8f9f3f58a`
- **Ambiente:** non ancora verificato runtime
- **Dataset:** piccolo/sandbox non ancora confermato
- **Stato:** NOT RUN
- **Cosa è stato fatto:** non ancora eseguito.
- **Conteggi aggregati:** non disponibili
- **Evidenze privacy-safe:** non disponibili
- **Errori/cancel/retry:** nessuno
- **Follow-up:** richiede conferma utente esplicita e recheck sessione/account/owner/baseline immediatamente prima della write remota.
- **Note:** stop immediato se il piano sheet è stale o se il write potrebbe partire senza conferma.

### S83-04 — ProductPrice apply/push con duplicato/conflitto controllato

- **Run ID:** da assegnare quando S83-04 parte
- **Build:** Release, non ancora eseguita
- **Commit:** `68a8f9f3f58a`
- **Ambiente:** non ancora verificato runtime
- **Dataset:** piccolo/sandbox non ancora confermato
- **Stato:** NOT RUN
- **Cosa è stato fatto:** non ancora eseguito.
- **Conteggi aggregati:** non disponibili
- **Evidenze privacy-safe:** non disponibili
- **Errori/cancel/retry:** nessuno
- **Follow-up:** manifest deve contenere duplicato/conflitto controllato senza usare dati negozio reali.
- **Note:** nessun doppio storico prezzo deve essere prodotto; stop su duplicazioni dopo retry.

### S83-05 — Drain attività tramite CTA separata “Registra attività sul cloud”

- **Run ID:** da assegnare quando S83-05 parte
- **Build:** Release, non ancora eseguita
- **Commit:** `68a8f9f3f58a`
- **Ambiente:** non ancora verificato runtime
- **Dataset:** piccolo/sandbox non ancora confermato
- **Stato:** NOT RUN
- **Cosa è stato fatto:** non ancora eseguito.
- **Conteggi aggregati:** non disponibili
- **Evidenze privacy-safe:** non disponibili
- **Errori/cancel/retry:** nessuno
- **Follow-up:** richiede attività locale registrabile già disponibile o prodotta dal flusso autorizzato, senza injection/cleanup non autorizzati.
- **Note:** drain implicito vietato; solo CTA separata e confermata.

### S83-06 — Cancel/retry/recovery su fase lunga o retryable

- **Run ID:** da assegnare quando S83-06 parte
- **Build:** Release, non ancora eseguita
- **Commit:** `68a8f9f3f58a`
- **Ambiente:** non ancora verificato runtime
- **Dataset:** piccolo/sandbox non ancora confermato
- **Stato:** NOT RUN
- **Cosa è stato fatto:** non ancora eseguito.
- **Conteggi aggregati:** non disponibili
- **Evidenze privacy-safe:** non disponibili
- **Errori/cancel/retry:** nessuno
- **Follow-up:** scegliere una fase lunga/retryable solo se osservabile senza forzare condizioni distruttive.
- **Note:** PASS solo se nessun write non confermato avviene dopo cancel e CTA **Riprova/Ricontrolla** è coerente.

## TASK-083 EXECUTION REPORT

- **Build:** Release PASS con warning preesistenti/out-of-scope
- **Commit:** `68a8f9f3f58a`
- **Ambiente:** iPhone 16e Simulator / iOS 26.2 disponibile; Supabase config presente ma sessione/account non verificati in UI
- **Dataset:** **BLOCKED** — manifest piccolo/sandbox TASK-083 mancante/incompleto
- **Account/sessione:** verificato no, senza dati sensibili
- **Scenari eseguiti:** nessuna run UI/runtime; S83-01 fermato in preflight come **BLOCKED**
- **Scenari NOT RUN:** S83-02, S83-03, S83-04, S83-05, S83-06

| Scenario | Esito | Conteggi aggregati | Note privacy-safe | Follow-up |
|----------|-------|--------------------|-------------------|-----------|
| S83-01 | BLOCKED | n/d | Build Release PASS; nessuna UI/runtime; manifest TASK-083 non chiaro | Fornire/approvare manifest piccolo/sandbox completo |
| S83-02 | NOT RUN | n/d | Bloccato da S83-01 | Richiede S83-01 e manifest chiaro |
| S83-03 | NOT RUN | n/d | n/d | Richiede conferma write remoto + recheck pre-write |
| S83-04 | NOT RUN | n/d | n/d | Richiede duplicato/conflitto controllato nel manifest |
| S83-05 | NOT RUN | n/d | n/d | Richiede attività locale registrabile disponibile |
| S83-06 | NOT RUN | n/d | n/d | Richiede fase lunga/retryable osservabile |

### Summary

- **Cosa è stato applicato localmente:** nulla
- **Cosa è stato inviato al cloud:** nulla
- **Cosa è stato registrato come attività:** nulla
- **Cosa resta in attesa/bloccato:** manifest dataset piccolo/sandbox TASK-083 completo; sessione/account Supabase runtime da verificare solo dopo manifest chiaro
- **Errori/cancel/retry osservati:** nessuno
- **Differenze Debug vs Release:** non valutate; execution autorizzata Release-first
- **Decisione finale execution:** BLOCKED preflight. La chiusura task in Review/Chiusura certifica lo stop sicuro, non un runtime smoke riuscito.

### Check eseguiti

| Check | Stato | Evidenza / motivo |
|---|---:|---|
| Build compila (Xcode / BuildProject) | ✅ ESEGUITO | Release PASS su iPhone 16e iOS 26.2 con `xcodebuild build ... -configuration Release ... -derivedDataPath /tmp/task083-release-dd`. |
| Nessun warning nuovo introdotto | ✅ ESEGUITO | Nessun codice Swift modificato; warning osservati sono già noti/preesistenti/out-of-scope (`SyncEventOutboxDrainService.swift` actor isolation e AppIntents metadata). |
| Modifiche coerenti con il planning | ✅ ESEGUITO | Solo tracking e preflight/read-only; nessun Swift, nessun Android, nessun SQL/backend, nessun cleanup, nessun write remoto. |
| Criteri di accettazione verificati | ⚠️ NON ESEGUIBILE | Gli scenari S83-01…06 richiedono manifest piccolo/sandbox chiaro e, per S83-03/04/05, write/drain confermati; il manifest manca/incompleto. |
| Manifest dataset piccolo/sandbox | ⚠️ NON ESEGUIBILE | Non esiste nel repo un manifest TASK-083 completo con prodotto invariato, nuovo remoto, locale da inviare, prezzo cambiato, conflitto controllato e attività registrabile. |
| Supabase config privacy-safe | ✅ ESEGUITO | `SupabaseConfig.plist` valido con `plutil -lint` e ignorato da `.gitignore`; valori non stampati. |
| Localizzazioni | ✅ ESEGUITO | `plutil -lint` IT/EN/ES/zh-Hans PASS. |
| Diff whitespace | ✅ ESEGUITO | `git diff --check` PASS. |

### Rischi rimasti

- **BLOCKER:** manifest dataset piccolo/sandbox TASK-083 non definito/approvato. I dataset storici trovati (`TASK045_*`, fixture TASK-075) non coprono ProductPrice, conflitto controllato e attività outbox registrabile richiesti per S83-01…06.
- **BLOCKER:** account/sessione/owner Supabase non verificati in runtime perché lo stop è avvenuto prima dell'apertura UI.
- **Follow-up candidate:** preparare un manifest sandbox esplicito, con record privacy-safe e conteggi attesi, senza cleanup/reset/truncate/delete e senza usare dataset negozio reale.

### Handoff post-execution (Codex → Claude)

- **Stato execution:** bloccata in preflight, nessuna run UI/runtime eseguita.
- **Fase proposta:** REVIEW / chiarimento manifest.
- **Responsabile prossimo:** Claude / Reviewer.
- **TASK-083:** **BLOCKED**, **NON DONE**.
- **Richiesta review:** validare il blocco e fornire un manifest piccolo/sandbox completo o una decisione esplicita su come prepararlo senza violare i divieti. Non aprire TASK-084/TASK-085.
- **Anti-scope confermato:** nessun write remoto, nessun drain live, nessun cleanup/reset/truncate/delete, nessuna migration SQL/backend/schema/RLS/RPC, nessuna modifica Android, nessuna sync automatica/Timer/BGTask/Realtime/worker/polling.

## Review (Codex / Reviewer) — 2026-05-08 20:50 -0400

### Esito review

**APPROVED_FOR_CLOSURE / DONE**, con esito operativo **BLOCKED preflight**.

La review documentale conferma che il blocco è coerente con il contratto del task: la execution minima autorizzata doveva fermarsi se il manifest dataset piccolo/sandbox non era completo e approvato. Lo stop è stato applicato prima di UI runtime, write remoto, drain outbox o cleanup.

### Verifiche documentali

| Verifica | Esito | Evidenza |
|---|---:|---|
| Coerenza MASTER-PLAN ↔ TASK-083 | ✅ ESEGUITO | TASK-083 riallineato a **DONE / Chiusura**; MASTER-PLAN riallineato a progetto **IDLE** con ultimo completato TASK-083. |
| Dipendenze TASK-075/078/079/080/081/082 | ✅ ESEGUITO | Indicate come **DONE / Chiusura** in MASTER-PLAN e nel file task. |
| Claim runtime falsi su S83-01…S83-06 | ✅ ESEGUITO | Nessun claim **S83-01 PASS**; S83-01 resta **BLOCKED**; S83-02…S83-06 restano **NOT RUN**. |
| Build Release documentata | ✅ ESEGUITO | Execution report mantiene build Release PASS su iPhone 16e iOS 26.2. |
| `git diff --check` documentato | ✅ ESEGUITO | Execution report mantiene PASS; rieseguito in chiusura. |
| Documentazione `plutil` localizzazioni e SupabaseConfig | ✅ ESEGUITO | Execution report mantiene localizzazioni IT/EN/ES/zh-Hans PASS e `SupabaseConfig.plist` valido senza stampa di segreti; non rieseguito in chiusura perché plist/stringhe non sono nel diff. |
| Anti-scope runtime/write/drain/cleanup | ✅ ESEGUITO | Documentato: nessuna run UI/runtime, nessun write remoto, nessun drain, nessun cleanup/reset/truncate/delete. |

### Note review

- **DONE** in questa chiusura significa: task eseguito fino al gate di sicurezza e fermato correttamente per manifest incompleto.
- **DONE** non significa: S83-01…S83-06 PASS, sync completata, dataset negozio validato, write remoto riuscito o drain completato.
- **TASK-084** e **TASK-085** non vengono aperti né promossi.

## Chiusura

- **Stato finale:** **DONE**.
- **Fase finale:** **CHIUSURA**.
- **Responsabile chiusura:** **Codex / Reviewer**.
- **Esito di chiusura:** chiuso correttamente come smoke execution bloccato da preflight manifest, senza runtime/write.
- **Cosa è DONE:** la review/chiusura documentale di TASK-083 e la corretta applicazione della stop condition sul manifest sandbox incompleto.
- **Cosa NON è DONE / NON eseguito:** smoke runtime S83-01…S83-06; S83-01 runtime resta **BLOCKED**; S83-02…S83-06 restano **NOT RUN**; nessun write remoto; nessun drain outbox; nessun cleanup/reset/truncate/delete.
- **Follow-up consigliato:** preparare manifest dataset sandbox completo prima di eventuale nuovo smoke runtime.
- **Nota esplicita:** **TASK-083 DONE / Chiusura non equivale a smoke runtime PASS; equivale a chiusura documentale corretta dopo stop preflight sicuro.**

*(Nota storica: la sezione Planning precedente resta conservata; la sezione Execution è stata aperta solo dopo user override esplicito.)*
