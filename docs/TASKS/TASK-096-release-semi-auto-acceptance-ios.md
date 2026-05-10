# TASK-096 — Acceptance finale sync semi-automatica

## Informazioni generali

- **Task ID:** TASK-096
- **Titolo:** **Acceptance finale sync semi-automatica** *(roadmap iOS TASK-091…095 — verifica composita Release)*
- **File task:** `docs/TASKS/TASK-096-release-semi-auto-acceptance-ios.md`
- **Stato:** **DONE**
- **Fase attuale:** **Chiusura — REVIEW PASS**
- **Responsabile attuale:** **Nessuno / Chiusura**
- **Data creazione:** 2026-05-10
- **Ultimo aggiornamento:** 2026-05-10 12:52 -0400 — **REVIEW PASS; TASK-096 DONE**.
- **Ultimo agente che ha operato:** Codex / Reviewer

**Flag:** **`TASK-096_REVIEW_PASS_DONE`** — acceptance composita M96-01...09 verificata; build/test/static checks PASS; **DONE / Chiusura — REVIEW PASS**; **TASK-097 non aperto**.

**Motivazione titolo (allineamento MASTER-PLAN):** la tabella backlog (`docs/MASTER-PLAN.md`, riga TASK-096) definisce esplicitamente l’obiettivo come *Acceptance finale sync semi-automatica* dopo TASK-091…095. Questo file mantiene quel titolo e lo rende operativo con una **cutline MVP iOS-first** (vedi §14), per evitare che “acceptance finale” diventi un monolite non reviewabile.

---

## Dipendenze

- **Dipende da:** **TASK-095 DONE / Chiusura — REVIEW PASS** — `SupabaseManualSyncLifecycleRunGate`, single-flight root/Opzioni/sheet Release, preflight/budget, UX interrupt/ripresa foreground-first. **TASK-094 DONE** — push aggregato su `LocalPendingChange`. **TASK-093 DONE** — dirty set / snapshot provider. **TASK-092 DONE** — check foreground leggero. **TASK-091 DONE** — semi-auto Release (cooldown, review, no mutazioni silenziose).
- **Sblocca (non aperti):** eventuali follow-up documentati solo come *candidate* (es. estensione smoke cross-device, dataset medio); **nessun file TASK-097** in questo turno.
- **Non aprire qui:** execution Swift, Kotlin/SQL live, write Supabase non autorizzati, **TASK-097+** file task.

---

## 1. Obiettivo

Chiudere in **EXECUTION** il **gap di accettazione composita** della sync **semi-automatica** iOS sulla catena **TASK-091 → TASK-095**: dimostrare con **evidenze privacy-safe** e **regressioni automatizzate** che i componenti già implementati **coesistono** in modo sicuro nel flusso Release (foreground check, pending locale, push aggregato guidato, lifecycle/interrupt, drain attività dove previsto), **senza** introdurre un nuovo motore sync, **senza** sync mutativa silenziosa e **senza** claim **production-ready globale 100%**.

In questo turno l'EXECUTION ha prodotto tracking ed evidenze; non sono state necessarie modifiche Swift.

---

## 2. Stato attuale iOS *(repo-grounded — sintesi post TASK-095)*

- **Release / semi-auto:** `SupabaseManualSyncViewModel`, coordinator/factory Release, policy semi-auto TASK-091, stati presentazionali review/summary documentati nei task chiusi.
- **Foreground:** hook root / dedupe TASK-092; niente automazione mutativa.
- **Pending:** `LocalPendingChange`, snapshot read-only, stati fail-closed TASK-093.
- **Push aggregato:** planner bounded/cap/fingerprint TASK-094 integrato negli adapter Release catalogo/ProductPrice; outbox telemetry con follow-up tecnico già annotato in TASK-094.
- **Lifecycle:** RunGate minimale TASK-095 (`SupabaseManualSyncLifecycleRunGate`), single-flight, preflight auth/owner/rete/stato app, budget bounded, priorità mutazione interrotta vs check read-only.

**Cosa manca per “accettazione”:** una **matrice verificabile** che leghi scenari utente Release a: suite XCTest esistenti, eventuali smoke Simulator opzionali, manifest evidenze `TASK096_*` (solo dopo EXECUTION autorizzata). TASK-090 resta **PARTIAL_ACCEPTED**; TASK-083 ha preflight manifest incompleto — TASK-096 non ripete quell’ambito ma può **riusare le lezioni** (manifest prima del runtime mutativo).

---

## 3. Contesto da TASK-095 e task precedenti

- **TASK-095** ha reso esplicita la **policy di processo** (lifecycle) separata dallo stato dati `LocalPendingChange`. L’acceptance TASK-096 deve verificare che **interrupt/ripresa** non producano UX “successo finto” né doppie run, in linea con CA-T095-14/16.
- **TASK-094** ha vincolato push aggregato a snapshot/guard; acceptance deve includere almeno uno scenario **pending → review → invio batch** con esito coerente (terminale vs blocked/stale) senza duplicare logica planner in test manuali.
- **TASK-093** impone privacy sugli aggregati; evidenze TASK-096 non devono contenere elenchi di catalogo reale.
- **TASK-092/091** definiscono che il check automatico resta **read-only** e competizione con mutazioni è **governata**; la matrice S96 deve includere un caso **mutativa interrotta ha priorità visiva** (coerente TASK-095).

---

## 4. Riferimento Android *(solo confronto funzionale)*

- Android resta **ispirazione** per ordine operativo dirty set / batch / retry (task storici e TASK-084 matrice documentale). **Nessun** porting Kotlin, **nessun** obbligo di runtime Android dentro TASK-096 salvo decisione esplicita futura e task separato. Se in fase EXECUTION servisse confronto read-back, va documentato come **opzionale** e **non bloccante** per chiusura iOS-only.

---

## 5. Riferimento Supabase *(solo read-only / sandbox controllata in futura execution)*

- Contratti già noti alla roadmap: catalogo owner-scoped, ProductPrice/`effective_at`, `sync_events` / idempotenza (task 055–059, 071, 081, 086). **In questo planning:** nessuna query live, nessuna DDL/RLS. In **futura EXECUTION**, eventuali verifiche remote devono seguire prefissi sandbox tipo **`TASK096_*`**, sessione/owner verificati e **nessun** dato reale di negozio.

---

## 6. Gap specifico da chiudere

| Gap | Descrizione |
|-----|-------------|
| **G96-01 — Composizione sistemi** | Esistono moduli forti e testati singolarmente, ma manca un **contratto di accettazione integrato** (tabella scenario → prova → esito) che un reviewer possa seguire senza leggere tutti i task 091…095. |
| **G96-02 — Evidenze ripetibili** | TASK-090 è PARTIAL; TASK-083 bloccato su manifest. Serve **formato evidenza minimo** TASK-096 per non ripetere STOP per manifest incompleto. |
| **G96-03 — Regressione esplicita** | Dichiarare quali **famiglie XCTest** sono gate per “non rompere la semi-auto” quando si tocca Release/lifecycle/pending/push. |
| **G96-04 — Confine MVP vs follow-up** | Separare nettamente smoke **iOS Release minimo** da desiderata “cross-platform fresh / dataset médio / import-export UI completa” (fuori da questa cutline). |

---

## 7. Scope esplicito *(futura EXECUTION — non attiva ora)*

- Definire e poi eseguire (solo dopo handoff) una **matrice di accettazione** per il flusso Release semi-auto: scenari cardinali su check/preview, apply confermato, pending+push aggregato, interrupt lifecycle, drain attività manuale, retry/cancel.
- Produrre **evidenze privacy-safe** (cartella task `EVIDENCE` o struttura equivalente concordata in planning review) con prefisso **`TASK096_*`** per eventuali record sandbox.
- Mantenere **regressioni XCTest** come gate primario; smoke Simulator solo dove il task lo richiederà esplicitamente post-review.
- Allineamento tracking `docs/MASTER-PLAN.md` / file task solo nelle fasi consentite dal workflow.

---

## 8. Out-of-scope esplicito *(anti feature-creep)*

- **Nuove** automazioni: Timer, BGTask/BackgroundTasks, Realtime, polling/worker, sync mutativa silenziosa.
- **Refactor ampi** di `SupabaseManualSyncViewModel`, coordinator, planner TASK-094, o modelli SwiftData salvo fix mirato strettamente necessario per un CA TASK-096 (da valutare in review).
- **SQL/migration/RLS/backend**, modifiche **Kotlin/Android**, **`project.pbxproj`**, churn massivo **`Localizable.strings`**.
- **Write Supabase live** come obiettivo implicito: solo sandbox **`TASK096_*`** e solo dopo gate auth/owner/collision in EXECUTION.
- Claim **production-ready globale 100%** o chiusura “tutto verde su negozio reale”.
- **Apertura file task TASK-097** o successivi in questo turno.
- Qualunque **nuova** feature prodotto non necessaria alla verifica (es. redesign card, nuove schede).

---

## 9. Micro-slice *(S96-A … — planning; execution le consuma)*

| ID | Titolo | Output atteso prima di EXECUTION |
|----|--------|----------------------------------|
| **S96-A** | Matrice scenario × tipo verifica | Tabella MUST: ogni riga = scenario Release, **STATIC** / **BUILD** / **XCTest** / **SIM** / **MANUAL** (da barrare in review), stato iniziale NOT RUN. |
| **S96-B** | Manifest evidenze `TASK096_*` | Regole: prefisso, colonne obbligatorie (data, ambiente, esito, owner hash redatto), divieto segreti/barcode reali. |
| **S96-C** | Percorso end-to-end minimo iOS | Sequenza testabile: *Controlla cloud* → *Rivedi* → *Aggiorna dispositivo* (se applicabile) → *Invio modifiche locali* (aggregato) → *Registra attività* (se nel perimetro) con punto di controllo **lifecycle** (simulato o manuale). |
| **S96-D** | Gate XCTest nominale | Elenco suite/file di test **già esistenti** da tenere verdi (es. ViewModel Release, planner TASK-094, RunGate TASK-095, snapshot TASK-093, UI Release mirata) — numeri esatti aggiornati in EXECUTION. |
| **S96-E** | Gestione residui TASK-090 / TASK-083 | Cosa rientra in TASK-096 vs cosa resta **follow-up** documentale (senza nuovo task file ora). |
| **S96-F** | Smoke opzionali | Elenco minimo Simulator **facoltativi** (cold start, background durante operazione lunga) — solo se EXECUTION lo autorizza e senza dati reali. |
| **S96-G** | UX acceptance Release | Verifica che stati semi-auto/lifecycle usino una sola card/action principale, copy breve e non modale, senza disturbare import/export/scanner/editing. |
| **S96-H** | Freeze review | Checklist finale per impedire che TASK-096 diventi TASK-090 bis o acceptance production-ready globale. |

### 9.1 Matrice MVP proposta *(da congelare in PLANNING REVIEW)*

Questa matrice rende TASK-096 eseguibile senza trasformarlo in un task monolitico. Gli scenari sono **iOS Release-first**, fakeable dove possibile, e non richiedono dati reali.

| ID | Scenario MUST | Verifica primaria | Evidenza attesa | Note cutline |
|----|---------------|-------------------|-----------------|--------------|
| **M96-01** | Foreground check read-only senza mutazioni | XCTest + static | Stato UI/check coerente, nessun apply/push automatico | Copre TASK-091/092 |
| **M96-02** | Review/apply confermato con piano non stale | XCTest | Apply solo dopo conferma, summary coerente | Nessun editor conflitti nuovo |
| **M96-03** | Pending locale → push aggregato confermato | XCTest planner/ViewModel | Batch bounded, no duplicati, stato terminale verificato | Copre TASK-093/094 |
| **M96-04** | Push/ProductPrice con remote write incerto | XCTest fake | Nessun `acknowledged` senza verifica/read-back | Copre rischio lifecycle TASK-095 |
| **M96-05** | Mutazione interrotta durante lifecycle | XCTest RunGate/ViewModel | Stato `interrupted/readyToRetry`, una sola CTA principale | Niente modal automatica |
| **M96-06** | Preflight auth/owner/rete fallisce | XCTest fake | Run bloccata fail-closed, copy chiaro | Nessun retry silenzioso |
| **M96-07** | Drain attività manuale dove previsto | XCTest/fake adapter | Outbox conservata se non ack, retry manuale | Solo Release path esistente |
| **M96-08** | UX non invasiva durante flussi attivi | UX smoke/static | Import/export/scanner/editing/review non coperti da modal sync | Se simulator non disponibile: static + test UI |
| **M96-09** | Anti-scope finale | Static grep | No BGTask/Timer/polling/Realtime/worker/TASK-097 | Gate obbligatorio |

**Regola di freeze:** se durante Planning Review vengono aggiunte righe, la matrice deve restare entro **10 scenari MUST**. Scenari cross-device, dataset medio e runtime negozio reale restano follow-up.

### 9.2 Manifest evidenze `TASK096_*` *(formato minimo)*

In futura EXECUTION, se vengono prodotte evidenze runtime/sandbox, usare un formato minimo privacy-safe:

| Campo | Regola |
|-------|--------|
| `scenario_id` | Uno tra `M96-01…M96-09` |
| `timestamp` | Data/ora locale o ISO, senza token/sessioni |
| `environment` | Simulator/local/fake/live-sandbox; non includere URL completo se contiene dettagli sensibili |
| `owner_hash` | Solo hash/redazione, mai user id/email/token in chiaro |
| `dataset_prefix` | Solo `TASK096_*` se si usa Supabase sandbox |
| `result` | PASS / FAIL / BLOCKED_ENV / PARTIAL_ACCEPTED |
| `evidence_ref` | Percorso file, test name o comando redatto |
| `notes` | Solo conteggi/outcome, nessun barcode/nome prodotto reale |

**Decisione planning:** i test fake/XCTest sono fonte primaria; Supabase live/sandbox e Simulator smoke sono secondari e non devono diventare prerequisito implicito per chiudere TASK-096 se i MUST sono coperti da test affidabili.

### 9.3 Test gate nominale candidato *(da verificare contro repo in PLANNING REVIEW)*

Questi nomi rendono S96-D piu' operativo. In Planning Review vanno confermati contro i file reali e aggiornati se il naming nel repo differisce:

| Area | Suite/file candidato | Copertura attesa |
|------|----------------------|------------------|
| Release ViewModel | `SupabaseManualSyncViewModelTests` | Check/apply/push/drain, summary, stale/block, no mutazioni silenziose |
| Lifecycle TASK-095 | `SupabaseManualSyncLifecycleRunGateTests` | Single-flight, interrupted/readyToRetry, preflight, time budget |
| Push aggregato TASK-094 | `LocalPendingAggregatedPushPlannerTests` | Batch bounded, cap, ProductPrice dedupe, fingerprint/idempotenza |
| Snapshot TASK-093 | `SupabaseManualSyncLocalPendingSnapshotProviderTests` + `LocalPendingChangeAccumulatorTests` | Dirty set, owner scoping, privacy-safe logical key |
| Release UI/copy | `SupabaseManualSyncReleaseUITests` | Una sola card/action principale, CTA coerenti, no modal automatica |
| Localizzazioni | `LocalizationCoverageTests` o controllo equivalente | Chiavi IT/EN/ES/zh-Hans se in EXECUTION vengono toccate stringhe |

**Regola S96-D:** se una suite nominale non esiste o ha nome diverso, la futura EXECUTION deve aggiornare questa tabella con il nome reale prima di dichiarare READY FOR REVIEW.

### 9.4 Struttura evidenze consigliata

Se in futura EXECUTION vengono prodotti artefatti, usare una struttura piccola e navigabile:

```text
docs/TASKS/EVIDENCE/TASK-096/
  manifest.md
  scenario-matrix.md
  test-build-summary.md
  ux-acceptance.md
  anti-scope-checks.md
  optional-runtime-smoke.md   # solo se davvero eseguito
```

- `manifest.md`: ambiente, commit, simulator, owner/sessione redatti, nessun segreto.
- `scenario-matrix.md`: righe M96-01…09 con PASS/FAIL/BLOCKED_ENV/PARTIAL_ACCEPTED.
- `test-build-summary.md`: comandi, suite, conteggi, warning noti/fuori scope.
- `ux-acceptance.md`: evidenza copy/card/CTA e non interferenza con flussi attivi.
- `anti-scope-checks.md`: grep/checklist no BGTask/Timer/polling/Realtime/worker/TASK-097/SQL/Android.
- `optional-runtime-smoke.md`: solo se simulator/Supabase sandbox sono usati; mai obbligatorio se XCTest coprono i MUST.

### 9.5 UX copy acceptance *(linee guida minime)*

TASK-096 non deve introdurre redesign, ma deve verificare che la UX esistente sia chiara. Copy accettabile:

- Stato read-only: **Controllo cloud disponibile** / **Ricontrolla**.
- Mutazione interrotta: **Operazione interrotta** / **Rivedi e riprendi**.
- Preflight bloccato: **Serve ricontrollare l’accesso** / **Accedi di nuovo** o **Ricontrolla**, secondo capability reale.
- Pending pronto: **Modifiche locali pronte da inviare** / **Rivedi prima di inviare**.

Regole:

- una CTA primaria;
- massimo una CTA secondaria;
- niente gergo tecnico come idempotenza, RunGate, lifecycle, stale baseline;
- niente modal automatica;
- nessun messaggio di successo se lo stato e' incerto o non verificato.

---

## 10. Criteri di accettazione *(CA-T096-xx — bozza contratto; verifica in EXECUTION/REVIEW)*

- **CA-T096-01 — Matrice pubblicata:** Il file task contiene la matrice S96-A completa di scenari MUST prima dell’handoff a EXECUTION (nessuna riga “TBD” su scenari cardinali).
- **CA-T096-02 — No nuovo motore sync:** L’EXECUTION non introduce un sostituto di coordinator/planner/push/RunGate; solo verifiche, patch minime motivato, tracking.
- **CA-T096-03 — Regressione XCTest:** Tutte le suite nominate in **S96-D** risultano **PASS** al termine EXECUTION (numeri riportati in Execution; in planning restano “da determinare”).
- **CA-T096-04 — Privacy evidenze:** Eventuali artefatti `TASK096_*` / log redatti: nessun segreto, nessun catalogo reale, nessun JWT/service_role.
- **CA-T096-05 — Lifecycle coerente:** Almeno uno scenario verifica che mutazione interrotta / preflight fallito non porti a **completamento** UX ingiustificato (allineato TASK-095).
- **CA-T096-06 — Pending coerente:** Almeno uno scenario verifica transizioni pending/planner **fail-closed** su blocked/stale (riferimento TASK-093/094).
- **CA-T096-07 — Anti-scope statico:** Grep o checklist conferma assenza di BGTask/Timer/polling/Realtime/worker **nuovi** introdotti per “completare” acceptance.
- **CA-T096-08 — Esito onesto:** Se un MUST resta BLOCKED per ambiente, CA esplicita **PARTIAL** con motivazione (stile TASK-090), non mascherata come PASS.
- **CA-T096-09 — Tracking coerente:** `docs/MASTER-PLAN.md` e questo file restano allineati su stato/fase/file task a ogni transizione consentita.
- **CA-T096-10 — UX acceptance:** Gli scenari M96 verificano che la sync semi-auto resti non invasiva: una sola card/action principale, niente modal automatiche, copy breve e nessun blocco dei flussi import/export/scanner/editing.
- **CA-T096-11 — Matrice bounded:** La matrice MUST resta entro 8–10 scenari; qualunque scenario extra diventa NICE/follow-up e non blocca REVIEW PASS se fuori cutline.
- **CA-T096-12 — Evidenza non ambigua:** Ogni scenario MUST ha un esito esplicito PASS/FAIL/BLOCKED_ENV/PARTIAL_ACCEPTED; vietato chiudere con righe “TBD” o “non controllato” non motivate.
- **CA-T096-13 — Fix solo se necessario:** In futura EXECUTION sono ammessi fix mirati se un MUST fallisce, ma non refactor ampi o nuove feature mascherate da acceptance.
- **CA-T096-14 — Test gate nominale:** Prima del READY FOR REVIEW, la tabella §9.3 deve riportare nomi reali delle suite eseguite o motivare eventuali sostituzioni equivalenti.
- **CA-T096-15 — Evidenze navigabili:** Se viene creata cartella `docs/TASKS/EVIDENCE/TASK-096/`, deve contenere almeno manifest, matrice scenari, summary test/build e anti-scope checks; niente evidenze sparse o non linkabili.
- **CA-T096-16 — Copy acceptance:** Gli stati UX verificati devono rispettare §9.5: CTA primaria chiara, niente gergo tecnico, niente successo su esito incerto.

---

## 11. Rischi *(R96-xx)*

- **R96-01:** Confondere TASK-096 con **rifacimento TASK-090** → mitigazione: cutline §14 e S96-E.
- **R96-02:** Scope creep verso parità Android runtime completa → mitigazione: Android solo **§4**; follow-up separato.
- **R96-03:** Smoke con dati reali o URL/keys nei log → mitigazione: manifest §9 S96-B + review severa.
- **R96-04:** Ambiente auth/owner instabile rende MUST non riproducibili → mitigazione: CA-T096-08 PARTIAL documentato; fixture sintetiche.
- **R96-05:** Matrice troppo ampia → ritardo e impossibilità review → mitigazione: MUST ≤ **8–10** righe in MVP (vedi §14).
- **R96-06:** Dipendenza da Supabase live non pianificata → mitigazione: preferenza XCTest fakeable + sandbox `TASK096_*` solo se gate OK.
- **R96-07:** Acceptance troppo teorica senza scenari concreti → mitigazione: matrice MVP M96-01…09 gia’ proposta e da congelare in review.
- **R96-08:** Falso senso di completamento se si usano solo build/test generici → mitigazione: ogni MUST deve avere evidenza scenario-specifica.
- **R96-09:** UX acceptance trascurata perche’ “non e’ codice nuovo” → mitigazione: S96-G e CA-T096-10 rendono UX non invasiva un gate esplicito.
- **R96-10:** Fix in execution allargano scope → mitigazione: CA-T096-13 e cutline §14 impongono patch minime o follow-up.
- **R96-11:** Nomi suite/test non congelati causano execution dispersiva → mitigazione: §9.3 con nomi candidati e obbligo di riallineamento ai nomi reali.
- **R96-12:** Evidenze sparse rendono difficile la review → mitigazione: struttura §9.4 e scenario-matrix con link/esiti espliciti.
- **R96-13:** Copy tecnici o rumorosi peggiorano UX anche se i test passano → mitigazione: §9.5 e CA-T096-16.

---

## 12. Piano test futuro *(non eseguito in questo turno)*

| ID | Tipo | Note |
|----|------|------|
| **T96-01** | XCTest | Esecuzione aggregata suite S96-D (ViewModel, coordinator factory fake, planner, RunGate, snapshot). |
| **T96-02** | XCTest / SIM | Lifecycle: interrupt simulato su fase mutativa; verifica stato presentazionale + assenza auto-push. |
| **T96-03** | XCTest | Pending + piano aggregato: blocked/stale/t cap coerenti con summary. |
| **T96-04** | MANUAL / SIM | Solo se autorizzato: background durante operazione lunga; verifica copy e assenza completamento falso. |
| **T96-05** | STATIC | Checklist grep anti-scope (BGTask, Timer, worker, Realtime). |
| **T96-06** | BUILD | Build Debug/Release come gate regressioni (solo EXECUTION). |
| **T96-07** | UX smoke/static | Una sola card/action principale, nessuna modal automatica, copy breve e flussi import/export/scanner/editing non disturbati. |
| **T96-08** | STATIC | Manifest/evidence audit: nessun segreto, owner redatto, nessun barcode/nome prodotto reale. |
| **T96-09** | REVIEW checklist | Ogni scenario M96 ha esito esplicito e link a test/evidenza; niente righe TBD. |
| **T96-10** | STATIC/REVIEW | Verifica tabella §9.3: nomi suite reali, sostituzioni motivate, nessun gate generico non eseguibile. |
| **T96-11** | STATIC/REVIEW | Verifica struttura evidenze §9.4: manifest, scenario matrix, test/build summary, UX, anti-scope. |
| **T96-12** | UX review | Copy acceptance §9.5: CTA primaria chiara, niente gergo tecnico, nessun successo su stato incerto. |

---

## 13. Gate Go / No-Go per futura EXECUTION

**Go** solo se:

1. **S96-A / M96** approvata: matrice MUST completa, bounded entro 8–10 scenari, con tipi di verifica assegnati e nessuna riga TBD.
2. **S96-B** approvato: regole manifest `TASK096_*` chiare.
3. **S96-D** congelato: elenco suite XCTest gate definito come nomi file/test, includendo almeno ViewModel Release, RunGate TASK-095, planner TASK-094, snapshot TASK-093 e Release UI mirata.
4. **§9.3** verificata: nomi suite candidati confermati o sostituiti con nomi reali equivalenti.
5. **§9.4/§9.5** approvate: formato evidenze e copy acceptance non introducono nuovi requisiti UI o dati live obbligatori.
6. **S96-E** chiarisce residui TASK-090/083 senza assorbire tutto il cross-platform.
7. Override utente esplicito per EXECUTION secondo `AGENTS.md` / workflow progetto.
8. **CA-T096-xx** rivisti in **PLANNING REVIEW** senza contraddizioni con anti-scope TASK-091…095.

**No-Go** se: la matrice include scenari che richiedono **nuove** automazioni background, claim 100% production-ready, dataset negozio reale obbligatorio, o rewrite coordinator/planner. **No-Go** se manca handoff esplicito verso Codex.

---

## 14. Cutline MVP anti feature-creep

- **MUST in MVP:** al massimo **8–10** scenari Release che coprono: (1) check read-only semi-auto, (2) review/apply dove già previsto, (3) pending visibile + push aggregato **confermato**, (4) interrupt + ripresa/blocked RunGate, (5) drain attività **manuale** se nel perimetro Release documentato, (6) regressione XCTest S96-D **PASS**.
- **NICE / follow-up (non MUST):** smoke cross-device Android↔iOS, dataset medio, import/export file round-trip UI completo, benchmark performance, pulizia record sandbox storici.
- **Chiusura ammessa:** **REVIEW PASS** con **PARTIAL** documentato su NICE, come per TASK-090, **senza** riaprire TASK-095/094.
- **Divieto:** espandere MUST oltre la cutline senza nuovo task o senza planning review.
- **Freeze UX:** TASK-096 puo’ migliorare copy/evidenza UX solo se serve a rendere chiara l’acceptance; non deve introdurre nuove schermate o redesign.
- **Freeze test:** se un MUST e’ gia’ coperto da XCTest affidabile, non renderlo obbligatoriamente manuale/Simulator solo per “sembrare piu’ reale”.

---

## 15. Handoff finale *(PLANNING freeze — questo turno)*

| Voce | Valore |
|------|--------|
| **Handoff** | **READY FOR PLANNING REVIEW** |
| **READY FOR EXECUTION** | **NO — NON READY FOR EXECUTION** |
| **TASK-096 DONE** | **NO** |
| **Prossima fase consigliata** | **PLANNING REVIEW** (validare/congelare M96-01…09, nomi test reali, regole evidenze e CA/gate) |
| **Prossimo agente** | **Claude / Planner** (o reviewer designato) |
| **Prossima azione** | Eseguire solo **PLANNING REVIEW**: confermare matrice/test/evidenze/copy; poi richiedere override utente per EXECUTION |
| **Matrice MVP proposta** | **M96-01…09 aggiunta; da validare/congelare in PLANNING REVIEW** |
| **Manifest evidenze** | **Formato minimo `TASK096_*` aggiunto; privacy-safe e test-first** |
| **UX acceptance** | **S96-G / CA-T096-10 / T96-07 aggiunti; niente redesign o modal automatiche** |
| **Test gate nominale** | **§9.3 aggiunta con suite candidate da confermare in PLANNING REVIEW** |
| **Evidence folder** | **§9.4 aggiunta con struttura consigliata `docs/TASKS/EVIDENCE/TASK-096/`** |
| **UX copy acceptance** | **§9.5 aggiunta; CTA primaria, no gergo tecnico, no successo su stato incerto** |
| **Freeze finale** | **Piano sufficiente per Planning Review; ammesse solo correzioni di coerenza/refusi/allineamento test reali** |

## 16. Checklist Planning Review / freeze

Prima di autorizzare EXECUTION, la review del planning deve confermare:

- **PR96-01:** M96-01…09 coprono i MUST senza superare 10 scenari.
- **PR96-02:** ogni scenario ha verifica primaria e fallback se Simulator/Supabase non e’ disponibile.
- **PR96-03:** S96-D contiene nomi reali dei test/suite da eseguire.
- **PR96-04:** evidenze `TASK096_*` sono privacy-safe e non richiedono dati reali.
- **PR96-05:** UX acceptance e’ esplicita ma non genera redesign o nuove feature.
- **PR96-06:** NICE/follow-up non bloccano REVIEW PASS se fuori cutline.
- **PR96-07:** nessun TASK-097 viene creato durante planning/execution TASK-096.
- **PR96-08:** se un MUST fallisce in execution, si corregge con patch mirata oppure si documenta PARTIAL/BLOCKED_ENV senza claim falso.
- **PR96-09:** tabella §9.3 confermata con nomi test reali o sostituzioni motivate.
- **PR96-10:** struttura evidenze §9.4 accettata come formato massimo, non come obbligo di runtime live.
- **PR96-11:** copy acceptance §9.5 coerente con stile Release e senza redesign.

**Decisione planning integrata:** dopo questa checklist, il piano e’ abbastanza concreto per Planning Review. Ulteriori aggiunte devono essere solo correzioni di coerenza o allineamento ai file reali, non nuove aree funzionali.

---

## 17. Decisione finale di planning *(freeze)*

Il piano TASK-096 e' considerato **sufficientemente completo per Planning Review**. Da questo punto in poi non vanno aggiunte nuove aree funzionali: sono ammessi solo correzioni di coerenza, refusi o allineamento ai nomi reali dei file/test durante la Planning Review.

### 17.1 Cosa deve essere congelato in Planning Review

- **Matrice MUST:** M96-01…09, massimo 10 scenari.
- **Test gate:** nomi reali delle suite in §9.3, con eventuali sostituzioni motivate.
- **Formato evidenze:** §9.2/§9.4 come formato massimo, non obbligo di runtime live.
- **UX acceptance:** §9.5, senza redesign e senza nuove schermate.
- **Cutline:** niente production-ready globale, niente cross-device obbligatorio, niente dataset negozio reale, niente refactor sync.

### 17.2 Cosa NON va piu' aggiunto a TASK-096

- Nuovi scenari MUST oltre la cutline 8–10.
- BackgroundTasks, Timer, polling, Realtime o worker.
- Nuove feature UI o redesign della card Release.
- Nuovo task TASK-097 o preparazione anticipata di TASK successivi.
- Obbligo di Supabase live/sandbox se gli XCTest fake coprono gia' i MUST.
- Nuova logica sync, nuova state machine dati o coordinator alternativi.

### 17.3 Prossima azione corretta

La prossima azione e' **Planning Review**, non altra espansione del piano. In review si deve solo:

1. validare o correggere puntualmente M96-01…09;
2. confermare i nomi reali dei test/suite;
3. congelare CA/gate;
4. preparare l'override utente per EXECUTION.

---

## Planning (Claude)

### Analisi

Dopo TASK-095 la roadmap iOS ha tutti i mattoni **semi-auto** previsti dalla sequenza 091→095. Il rischio principale non è più “cosa manca in codice” ma **come si dimostra** in modo **reviewabile** che il sistema composto è coerente, senza nuove automazioni e senza claim irrealistici. Il backlog MASTER-PLAN chiama questo **Acceptance finale sync semi-automatica**: qui viene interpretato come **acceptance composita iOS-first con cutline stretta**, non come nuova ondata di feature.

### Approccio proposto

1. Validare in **PLANNING REVIEW** la matrice MVP **M96-01…09** proposta in §9.1, correggendo solo celle ambigue e senza superare la cutline 8–10 MUST.
2. Congelare S96-D contro i file di test reali nel repo: ViewModel Release, RunGate TASK-095, planner TASK-094, snapshot TASK-093, Release UI/localizzazioni mirate.
3. Solo dopo Go §13, **Codex** esegue XCTest/smoke consentiti e compila evidenze `TASK096_*`, applicando solo fix mirati se un MUST fallisce.

### File da modificare *(solo elenco ipotetico — EXECUTION)*

Nessun file in questo turno. In futura EXECUTION candidati tipici: `SupabaseManualSyncViewModel.swift`, `SupabaseManualSyncLifecycleRunGate.swift`, test `SupabaseManualSyncViewModelTests`, `LocalPendingAggregatedPushPlannerTests`, `SupabaseManualSyncLifecycleRunGateTests`, `SupabaseManualSyncReleaseUITests`, eventuali file evidenza sotto `docs/TASKS/EVIDENCE/TASK-096/` — **da confermare in review**.

### Handoff → Execution *(non attivo)*

- **Prossima fase:** **EXECUTION** — **solo dopo** PLANNING REVIEW + override utente.
- **Prossimo agente:** **Codex / Executor**.
- **Azione consigliata:** Dopo Planning Review e override utente, leggere matrice M96-01…09 congelata; eseguire T96-*; aggiornare solo sezioni Execution/Fix, evidenze e handoff verso Review.

---

## Execution (Codex)

### Avvio EXECUTION — 2026-05-10 12:30 -0400

**Obiettivo compreso:** completare acceptance composita iOS Release della sync semi-automatica TASK-091...095 con evidenze privacy-safe, build/test e anti-scope; nessuna nuova feature, nessun nuovo motore sync, **TASK-096 NON DONE**.

**PLANNING REVIEW interna completata:**

| Gate | Esito | Nota |
|------|-------|------|
| PR96-01 / PR96-02 | PASS | Matrice MVP **M96-01...09** validata e congelata; nessun scenario extra aggiunto. |
| PR96-03 / PR96-09 | PASS | Suite reali confermate: `SupabaseManualSyncViewModelTests`, `SupabaseManualSyncLifecycleRunGateTests`, `LocalPendingAggregatedPushPlannerTests`, `SupabaseManualSyncLocalPendingSnapshotProviderTests`, `LocalPendingChangeAccumulatorTests`, `SupabaseManualSyncReleaseUITests`, `LocalizationCoverageTests`. |
| PR96-04 / PR96-10 | PASS | Struttura evidenze §9.4 confermata: manifest, scenario matrix, test/build summary, UX acceptance, anti-scope checks. |
| PR96-05 / PR96-11 | PASS | UX copy acceptance §9.5 confermata come gate: una CTA primaria, massimo una secondaria, niente gergo tecnico, niente modal automatica, niente successo su stato incerto. |
| PR96-06 | PASS | Cutline iOS Release-first confermata; XCTest/fake come fonte primaria; smoke Simulator/Supabase solo opzionali. |
| PR96-07 | PASS | Criteri CA-T096-01...16 coerenti e congelati per EXECUTION. |
| PR96-08 | PASS | `docs/MASTER-PLAN.md` coerente con TASK-096 come unico task attivo in PLANNING prima della promozione; `TASK-097` non presente come file task. |

**File controllati prima dell'EXECUTION:** `docs/MASTER-PLAN.md`; `docs/TASKS/TASK-096-release-semi-auto-acceptance-ios.md`; `docs/TASKS/TASK-095-policy-lifecycle-background-ios.md`; `docs/TASKS/TASK-094-smart-aggregated-push-ios.md`; `docs/TASKS/TASK-093-local-change-accumulation-ios.md`; `docs/TASKS/TASK-092-lightweight-auto-pull-foreground-ios.md`; `docs/TASKS/TASK-091-supabase-smart-semi-automatic-sync-ios.md`; `SupabaseManualSyncViewModel.swift`; `SupabaseManualSyncLifecycleRunGate.swift`; `SupabaseManualSyncReleaseFactory.swift`; `SupabaseManualSyncCoordinator.swift`; `SupabaseManualSyncCoordinatorModels.swift`; `LocalPendingChange.swift`; `LocalPendingAggregatedPushPlanner.swift`; `SupabaseManualSyncLocalPendingSnapshotProvider.swift`; `SupabaseManualSyncAggregatedPushOutboxProducer.swift`; `ContentView.swift`; `OptionsView.swift`; test Release/manual sync/TASK-093/TASK-094/TASK-095/localization.

**Piano minimo di intervento:** aggiornare tracking ed evidenze TASK-096; eseguire build/test/check richiesti; applicare solo eventuali fix mirati se un MUST fallisce; chiudere con handoff **ACTIVE / REVIEW**, **READY FOR REVIEW**, **TASK-096 NON DONE**.

**File previsti da modificare:** `docs/TASKS/TASK-096-release-semi-auto-acceptance-ios.md`, `docs/MASTER-PLAN.md`, `docs/TASKS/EVIDENCE/TASK-096/*`. Nessuna modifica Swift prevista in avvio; eventuali patch codice/test solo se richieste da failure reali.

**Stato:** **TASK-096 ACTIVE / EXECUTION**; responsabile **Codex / Executor**.

### Completamento EXECUTION — 2026-05-10 12:40 -0400

**Modifiche fatte:**

- Corretta §9.3 con i nomi reali delle suite snapshot/pending: `SupabaseManualSyncLocalPendingSnapshotProviderTests` + `LocalPendingChangeAccumulatorTests`.
- Creati artefatti privacy-safe in `docs/TASKS/EVIDENCE/TASK-096/`: `manifest.md`, `scenario-matrix.md`, `test-build-summary.md`, `ux-acceptance.md`, `anti-scope-checks.md`.
- Aggiornati tracking TASK-096 e MASTER-PLAN per transizione **PLANNING -> EXECUTION -> REVIEW**.
- Nessuna modifica Swift, XCTest, localizzazioni, project file, SQL/backend o Android/Kotlin.

**Matrice M96 finale:**

| Scenario | Esito | Evidenza |
|----------|-------|----------|
| M96-01 | PASS | Foreground dry-run read-only in `SupabaseManualSyncViewModelTests`; root/card static review; nessun apply/push automatico. |
| M96-02 | PASS | Apply solo dopo conferma, staging non stale e invalidazione stale/owner in ViewModel tests. |
| M96-03 | PASS | Pending/snapshot/planner PASS; batch bounded e terminal state verificati. |
| M96-04 | PASS | ProductPrice/unverified remote write non diventa completedVerified; Release factory ack solo su verified success. |
| M96-05 | PASS | RunGate/ViewModel interruption -> interrupted/readyToRetry; UI senza modal automatica. |
| M96-06 | PASS | Preflight auth/owner/network/app context fail-closed; nessun retry silenzioso. |
| M96-07 | PASS | Drain attività solo manuale/adapter-owned; outbox retry conservativo se non ack. |
| M96-08 | PASS | Release UI/root foreground busy gating; una card/action principale, copy breve, flussi attivi non disturbati. |
| M96-09 | PASS | Anti-scope statico e diff checks PASS; nessun TASK-097. |

**Check eseguiti:**

| Check | Stato | Esito |
|-------|-------|-------|
| `git status --short` iniziale | ✅ ESEGUITO | `M docs/MASTER-PLAN.md`; `?? docs/TASKS/TASK-096-release-semi-auto-acceptance-ios.md` prima delle modifiche TASK-096. |
| `git diff --check` | ✅ ESEGUITO | PASS. |
| `xcodebuild -list` | ✅ ESEGUITO | PASS; scheme `iOSMerchandiseControl`, target app/test, Debug/Release. |
| Build Debug simulator | ✅ ESEGUITO | PASS su iPhone 17 Pro iOS 26.4.1. Prima invocazione con `OS=26.4` fallita solo per destination inesistente, rerun corretto PASS. |
| Build Release simulator | ✅ ESEGUITO | PASS su iPhone 17 Pro iOS 26.4.1. |
| `SupabaseManualSyncViewModelTests` | ✅ ESEGUITO | PASS 87/0. |
| `SupabaseManualSyncLifecycleRunGateTests` | ✅ ESEGUITO | PASS 6/0. |
| `LocalPendingAggregatedPushPlannerTests` | ✅ ESEGUITO | PASS 11/0. |
| Snapshot/pending TASK-093 | ✅ ESEGUITO | `SupabaseManualSyncLocalPendingSnapshotProviderTests` PASS 13/0; `LocalPendingChangeAccumulatorTests` PASS 12/0. |
| `SupabaseManualSyncReleaseUITests` | ✅ ESEGUITO | PASS 24/0. |
| `LocalizationCoverageTests` | ✅ ESEGUITO | PASS 8/0. |
| Regressione TASK-091...095 | ✅ ESEGUITO | PASS 364/0 source-counted test methods, exit code 0, suite sync collegate. |
| Full XCTest | ✅ ESEGUITO | PASS 626/0 source-counted test methods, exit code 0. |
| `plutil -lint` Localizable IT/EN/ES/zh-Hans | ✅ ESEGUITO | PASS tutti OK; nessuna stringa modificata. |
| Grep anti-scope app source | ✅ ESEGUITO | PASS; nessun match per BGTaskScheduler/BGAppRefreshTask/BGProcessingTask/Timer/polling/Realtime/worker in sorgenti app Swift. |
| TASK-097 | ✅ ESEGUITO | PASS; nessun file task TASK-097, nessuna menzione in sorgenti app/test. |
| No Android/Kotlin diff | ✅ ESEGUITO | PASS. |
| No SQL/backend/migration diff | ✅ ESEGUITO | PASS. |
| Privacy evidenze/log | ✅ ESEGUITO | PASS; nessun JWT/token/service role/URL/email/UUID-like raw id nelle evidenze TASK-096. |
| Supabase live/sandbox smoke | ⚠️ NON ESEGUIBILE | Non necessario per i MUST: gli scenari sono coperti da XCTest/fake e static review; nessun dato live/sandbox usato. |

**Warning/rumore residuo:** il primo test build ha mostrato quattro warning non-Sendable in `SyncEventOutboxDrainDebugViewModelTests.swift`, già noti dai task precedenti e non introdotti da TASK-096. Le build Debug/Release `-quiet` non hanno emesso warning.

**Rischi rimasti:** smoke runtime live/sandbox resta follow-up candidate opzionale, non gate TASK-096; non sono emersi bug da patchare. Nessun claim production-ready globale 100%.

### Handoff post-execution -> Review

- **Stato task:** **ACTIVE**
- **Fase:** **REVIEW**
- **Responsabile prossimo:** **Claude / Reviewer**
- **Handoff:** **READY FOR REVIEW**
- **Policy:** **TASK-096 NON DONE**; chiusura DONE solo in Review.
- **Evidenze:** `docs/TASKS/EVIDENCE/TASK-096/`.

---

## Review

### REVIEW PASS — 2026-05-10 12:52 -0400

**Esito review:** **PASS**. TASK-096 viene chiuso come **DONE / Chiusura — REVIEW PASS**. La review ha verificato `docs/MASTER-PLAN.md`, questo file task, tutte le evidenze `docs/TASKS/EVIDENCE/TASK-096/`, i task collegati TASK-091...095 e il diff corrente. La cutline e' rimasta iOS Release-first, test/fake-first, senza nuove feature o nuovo motore sync.

**Fix applicati in review:**

- Fix documentale di tracking in `docs/MASTER-PLAN.md`: la sezione finale "Task attivo" era rimasta stale su **ACTIVE / PLANNING** mentre top-level/task/evidenze erano gia' **ACTIVE / REVIEW**. Riallineata a **progetto IDLE**, **TASK-096 ultimo completato**, **TASK-097 non aperto**.
- Compilata questa sezione Review e aggiornati i metadati TASK-096 a **DONE / Chiusura — REVIEW PASS**.
- Nessuna modifica Swift, XCTest, localizzazioni, `project.pbxproj`, SQL/backend, Android/Kotlin o evidenze runtime.

**Matrice M96 reviewata:**

| Scenario | Esito review | Evidenza |
|----------|--------------|----------|
| M96-01 — Foreground check read-only | PASS | `SupabaseManualSyncViewModelTests`, root/card static review; nessun apply/push automatico. |
| M96-02 — Review/apply confermato non stale | PASS | ViewModel tests su conferma, stale/owner invalidation e summary. |
| M96-03 — Pending locale -> push aggregato | PASS | Snapshot/pending TASK-093 + `LocalPendingAggregatedPushPlannerTests`; batch bounded e terminal state. |
| M96-04 — ProductPrice/write incerto | PASS | ViewModel/factory ProductPrice: nessun `acknowledged` senza verifica/read-back; no successo ottimistico. |
| M96-05 — Mutazione interrotta lifecycle | PASS | `SupabaseManualSyncLifecycleRunGateTests` + Release UI; stato retry/interrupted, niente modal automatica. |
| M96-06 — Preflight fail-closed | PASS | Auth/owner/network/app context tests; run bloccata, copy chiaro, no retry silenzioso. |
| M96-07 — Drain manuale dove previsto | PASS | Outbox/drain regressions; outbox conservata se non ack, retry manuale, solo Release path esistente. |
| M96-08 — UX non invasiva | PASS | `SupabaseManualSyncReleaseUITests`, `ContentView`, `OptionsView`; busy gating e una sola azione primaria. |
| M96-09 — Anti-scope finale | PASS | Grep/diff anti-scope, no TASK-097, no Android/Kotlin, no SQL/backend, privacy scan evidenze. |

**Check rieseguiti in review:**

| Check | Stato | Esito |
|-------|-------|-------|
| `git status --short` | ✅ ESEGUITO | Solo tracking/evidenze TASK-096: `docs/MASTER-PLAN.md`, task file TASK-096 ed evidenze TASK-096. |
| `git diff --check` | ✅ ESEGUITO | PASS anche dopo il fix documentale finale. |
| `xcodebuild -list` | ✅ ESEGUITO | PASS; scheme `iOSMerchandiseControl`, Debug/Release. |
| Build Debug simulator | ✅ ESEGUITO | PASS su iPhone 17 Pro iOS 26.4.1. |
| Build Release simulator | ✅ ESEGUITO | PASS su iPhone 17 Pro iOS 26.4.1. |
| `SupabaseManualSyncViewModelTests` | ✅ ESEGUITO | PASS 87/0. |
| `SupabaseManualSyncLifecycleRunGateTests` | ✅ ESEGUITO | PASS 6/0. |
| `LocalPendingAggregatedPushPlannerTests` | ✅ ESEGUITO | PASS 11/0. |
| Snapshot/pending TASK-093 | ✅ ESEGUITO | `SupabaseManualSyncLocalPendingSnapshotProviderTests` PASS 13/0; `LocalPendingChangeAccumulatorTests` PASS 12/0. |
| `SupabaseManualSyncReleaseUITests` | ✅ ESEGUITO | PASS 24/0. |
| `LocalizationCoverageTests` | ✅ ESEGUITO | PASS 8/0. |
| Regressione TASK-091...095 | ✅ ESEGUITO | PASS 364/0 source-counted test methods, exit code 0. |
| Full XCTest | ✅ ESEGUITO | PASS 626/0 source-counted test methods, exit code 0. |
| `plutil -lint` IT/EN/ES/zh-Hans | ✅ ESEGUITO | PASS tutti OK. |
| Anti-scope app source | ✅ ESEGUITO | PASS; nessun BGTaskScheduler/BGAppRefreshTask/BGProcessingTask/Timer/polling/Realtime/worker nelle sorgenti app Swift. |
| Anti-scope test source | ✅ ESEGUITO | PASS; match solo in guard/assertion/source-scan test. |
| TASK-097 | ✅ ESEGUITO | PASS; nessun file TASK-097 e nessuna apertura. |
| No Android/Kotlin diff | ✅ ESEGUITO | PASS. |
| No SQL/backend/migration diff | ✅ ESEGUITO | PASS. |
| Privacy evidence scan | ✅ ESEGUITO | PASS; nessun token/JWT/service role/connection string/URL sensibile/email/user id/barcode o prodotto reale. |
| Supabase live/sandbox smoke | ⚠️ NON ESEGUIBILE | Non necessario per i MUST: XCTest/fake e static review coprono la cutline; nessun dato live/sandbox usato. |

**Warning:** la prima build execution con `OS=26.4` e' documentata come errore di destination corretto da rerun su `OS=26.4.1`, non regressione. I quattro warning non-Sendable in `SyncEventOutboxDrainDebugViewModelTests.swift` sono preesistenti/fuori scope e non introdotti da TASK-096. Non sono emersi warning nuovi TASK-096 o codice morto da correggere.

**UX acceptance:** PASS. Una sola card/action principale e massimo una secondaria; niente modal automatica; niente copy utente tecnico; niente successo su write incerto; busy gating per import/export/scanner/editing/review; stile coerente con OptionsView/manual sync Release.

**Privacy e anti-scope:** PASS. Nessun dato reale del negozio, nessun segreto, nessun Supabase live/sandbox write, nessun BGTask/Timer/polling/Realtime/worker, nessuna sync mutativa silenziosa, nessun TASK-097, nessun SQL/backend/migration/RLS, nessun Android/Kotlin, nessuna modifica `project.pbxproj`, nessun churn `Localizable.strings`.

**Stato finale:** **TASK-096 DONE / Chiusura — REVIEW PASS**; progetto **IDLE**; ultimo completato **TASK-096**; **TASK-097 non aperto**.

---

## Registro turno — solo markdown *(2026-05-10)*

- Creato **`docs/TASKS/TASK-096-release-semi-auto-acceptance-ios.md`** con obiettivo, stato iOS post-095, contesto, Android/Supabase read-only, gap, scope, out-of-scope, micro-slice iniziali, CA iniziali, rischi, piano test, gate §13, cutline §14, handoff §15.
- **Vietato in questo turno:** Swift/Kotlin/SQL/migration/RLS, write Supabase live, build/test obbligatori, Timer/BGTask/Realtime/worker, sync automatica mutativa, `project.pbxproj`, churn `Localizable.strings`, apertura TASK-097, dati reali/segreti.
- **TASK-096:** **ACTIVE / PLANNING**, **NON READY FOR EXECUTION**, **NON DONE**.
- Integrazione planning review: aggiunta matrice MVP concreta **M96-01…09**, manifest evidenze `TASK096_*`, micro-slice **S96-G/H**, acceptance criteria **CA-T096-10…13**, rischi **R96-07…10**, test **T96-07…09**, checklist **PR96-01…08** e handoff aggiornato. Stato invariato: **ACTIVE / PLANNING**, **READY FOR PLANNING REVIEW**, **NON READY FOR EXECUTION**, **TASK-096 NON DONE**.
- Rifinitura planning operativa: aggiunti test gate nominali candidati **§9.3**, struttura evidenze **§9.4**, linee guida **UX copy acceptance §9.5**, acceptance criteria **CA-T096-14…16**, rischi **R96-11…13**, test **T96-10…12**, checklist **PR96-09…11** e handoff aggiornato. Nessuna execution, nessun codice, nessun TASK-097.
- Freeze finale planning: corretto ultimo riferimento `dataset medio`; aggiunta sezione **Decisione finale di planning** per fermare ulteriori espansioni scope, congelare matrice/test/evidenze/UX/cutline e indicare come prossima azione solo **Planning Review**. Stato invariato: **ACTIVE / PLANNING**, **READY FOR PLANNING REVIEW**, **NON READY FOR EXECUTION**, **TASK-096 NON DONE**, **TASK-097 non aperto**.
- Rifinitura coerenza freeze: aggiornati flag, titolo handoff, prossima fase/azione, note Execution/Review e registro iniziale per evitare ambiguita' tra planning init e planning freeze. Nessuna execution, nessun codice, nessun TASK-097.
- 2026-05-10 12:30 -0400 — Planning Review interna completata da Codex; TASK-096 promosso a **ACTIVE / EXECUTION**; suite reali/evidenze/UX/CA/cutline congelate; TASK-097 non aperto.
- 2026-05-10 12:40 -0400 — EXECUTION completata: build Debug/Release PASS, XCTest mirati PASS, regressione sync PASS, full XCTest PASS, anti-scope/privacy PASS. **TASK-096 ACTIVE / REVIEW**, **READY FOR REVIEW**, **TASK-096 NON DONE**.
- 2026-05-10 12:52 -0400 — REVIEW completata: fix documentale tracking MASTER-PLAN, check review PASS, evidenze privacy-safe confermate. **TASK-096 DONE / Chiusura — REVIEW PASS**; progetto **IDLE**; **TASK-097 non aperto**.
