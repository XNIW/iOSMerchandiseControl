# TASK-097 — Runtime sandbox smoke iOS ↔ Supabase

## Informazioni generali

- **Task ID:** TASK-097
- **Titolo:** **Runtime sandbox smoke iOS ↔ Supabase**
- **File task:** `docs/TASKS/TASK-097-runtime-sandbox-smoke-ios-supabase.md`
- **Stato:** **DONE**
- **Fase attuale:** **Chiusura — REVIEW PASS**
- **Responsabile attuale:** **Nessuno / Chiusura**
- **Data creazione:** 2026-05-10
- **Ultimo aggiornamento:** 2026-05-10 14:57 -0400 — **REVIEW PASS; TASK-097 DONE**
- **Ultimo agente che ha operato:** Codex / Reviewer

**Flag:** **`TASK-097_REVIEW_PASS`** — progetto **IDLE**; smoke runtime iOS-first Supabase verificato e chiuso; **TASK-097 DONE / Chiusura — REVIEW PASS**; TASK-098 non aperto.

---

## Dipendenze

- **Dipende da:** **TASK-096 DONE / Chiusura — REVIEW PASS** — acceptance composita iOS Release TASK-091…095 senza smoke runtime Sandbox (XCTest/fake primari); evidenze in `docs/TASKS/EVIDENCE/TASK-096/`; matrice **M96-01…09 PASS**. TASK-097 colma il gap **runtime reale sandbox** iOS-first con prefisso dedicato **`TASK097_*`**.
- **Contesto tecnico:** **TASK-095** lifecycle/RunGate; **TASK-094** push aggregato + ProductPrice bounded; **TASK-093** `LocalPendingChange` / snapshot; **TASK-091** semi-auto Release (cooldown, review confermata, no mutazioni silenziose).
- **Sblocca (non aperti):** **TASK-098…TASK-102** restano backlog; lo smoke cross-platform Android è **TASK-098**, non questo task.
- **Non aprire:** file task **TASK-098**, **TASK-099**, **TASK-100**, **TASK-101**, **TASK-102**.

---

## 1. Obiettivo

In **EXECUTION futura** (non in questo planning): verificare **runtime reale iOS-first** su **Supabase sandbox** usando **solo** dati sintetici prefissati **`TASK097_*`**, **senza** dati reali di negozio.

Comporre una catena minima ma verificabile: **iOS → Supabase → iOS**:

- pull / preview remota dove previsto dal Release path;
- **apply locale confermato** (catalogo incluso supplier/category/product);
- **push confermato** (catalogo e **ProductPrice** inclusi);
- uso dei meccanismi già implementati (**pending**, **push aggregato**, **lifecycle** TASK-095) — **senza** nuovo motore sync.

**Planning corrente:** definisce manifest sandbox, slice, matrice scenari M97, criteri, rischi e gate execution; **non** esegue rete né seed né build obbligatori.

---

## 2. Stato attuale iOS post-TASK-096 *(sintesi)*

- TASK-096 ha confermato con **evidenze privacy-safe** e **XCTest** che la semi-automatica iOS TASK-091…095 è **accettabile** sul piano integrato (**M96-01…09 PASS**): foreground read-only, review/apply, pending → push aggregato, ProductPrice con write verificato/uncertainty gestita, lifecycle interrupt, drain attività dove previsto, anti-scope finale.
- **MANIFEST.md TASK-096** dichiara esplicitamente: *no Supabase sandbox writes started*; fonte primaria = fake/XCTest — corretto per acceptance TASK-096, ma lascia aperto un **GAP runtime**: read-back dal cloud con dataset dedicato **`TASK097_*`** non è ancora obiettivo di quel task.

**Implicazione TASK-097:** il valore è **dimostrabilità end-to-end** su sandbox con **`TASK097_*`**, sempre iOS-first, evidenze stesso formato privacy-safe di TASK-096.

---

## 3. Contesto da TASK-096 / TASK-095 / TASK-094 / TASK-093 / TASK-091

| Fonte | Cosa TASK-097 riusa (no nuovo sync engine) |
|-------|--------------------------------------------|
| **TASK-096** | Formato evidenza minimo (manifest/scenario-matrix/test-summary/anti-scope); lezione TASK-083: **manifest prima** di seed/write; regressioni **famiglie** nominate come gate. |
| **TASK-095** | Preflight lifecycle (auth/owner/rete/context app); interrupted/readyToRetry; niente success ottimistico su write incerta (**M96-04**, **R97-06** analoghi). |
| **TASK-094** | Planner aggregato batch bounded; fingerprint/idempotenza ProductPrice transizioni terminale; outbox/sync activity solo se già nel flusso Release confermato. |
| **TASK-093** | Pending dopo commit confermati locali; owner fail-closed; snapshot prima del push pianificato. |
| **TASK-091** | Cooldown/semi-auto; review sheet; conferma prima di push/apply; check cloud read-only bounded. |

---

## 4. Supabase *(solo read-only per questo planning)*

- **Turno PLANNING TASK-097:** **vietate** qualunque query/remota/live/sandbox/write/seed DDL/RLS; il team può leggere **solo documentazione/cloni schema** eventualmente disponibili **fuori** da questo workspace, senza modificare backend.
- **EXECUTION futura:** Supabase sandbox coerente con config iOS (`SupabaseConfig` / env documentato nell’handoff Codex); prefisso **unico `TASK097_`** tutte righe/modifiche dichiarabili nel manifest; collision scan **read-only prima di prima write**.
- Nessuna obbligo di pubblicare questo planning su progetto diverso dall’override utente futuro.

---

## 5. Gap specifico da chiudere

| ID | Gap |
|----|-----|
| **G97-01** | Acceptance TASK-096 **non** richiedeva Supabase runtime sandbox; TASK-097 fornisce la **prima fase di prova reale isolata**. |
| **G97-02** | Verificabilità che **pull + apply locale + push + ProductPrice current/previous** siano **coerenti** con read-back remoto su righe **`TASK097_*`**. |
| **G97-03** | Comportamento **pending → push aggregato** in ambiente sandbox (non solo fake) con limiti anti-scope TASK-096. |
| **G97-04** | Boundary netto tra **solo iOS TASK-097** vs **TASK-098** Android↔iOS — evitare contaminazione ambito (**R97-03**). |

---

## 6. Scope esplicito *(obiettivo EXECUTION quando autorizzato)*

- Preflight iOS sandbox: configurazione progetto/iOS puntano a progetto sandbox concordato; **auth/session valida**, **owner** coerente, **collision scan `TASK097_*`** = 0 prima del seed/write.
- **Seed controllato** o creazione additive solo **`TASK097_*`** (solo in EXECUTION dopo gate).
- **Pull / read-back remoto**: supplier/category/product coerenti con manifest.
- **ProductPrice**: righe sintetiche purchase/retail con **current/previous** nel modello Summary iOS dopo pull/apply.
- Modifica locale **confermata** (solo path già registrato come commit pending) → **pending** → **push aggregato confermato**.
- Remote read-back post-push catalogo **e** ProductPrice.
- Lifecycle: almeno un ramo retry/cancel su smoke **senza claim success automatico**.
- Smoke UX Release: una card/action primaria già garantita TASK-096; TASK-097 **non redesign** ma verifica comportamento osservabile.
- Produrre **`docs/TASKS/EVIDENCE/TASK-097/`** struttura §16 (manifest, scenario-matrix, build summary, remote/local read-back notes, UX, anti-scope).

---

## 7. Out-of-scope esplicito

- **Android runtime** obbligatorio o validazione TASK-098 in questo task.
- Smoke **cross-platform bidirezionale** — riservato a **TASK-098**.
- **Dataset negozio reale**; claim **production-ready globale 100%**.
- **Nuove feature sync**, refactor largo Release/ViewModel/planner/store.
- **BackgroundTasks**, **Timer**, **polling**, **Realtime**, **worker** sempre-on.
- **SQL/migration/RLS/backend** nel perimetro EXECUTION TASK-097 salvo futura eccezione minima solo se documentata e non distruttiva (default: NO).
- **Cleanup distruttivo** (truncate/wipe/delete massivo fuori dai record `TASK097_*`): preferire **leave rows as evidence** o cleanup documentato sicuro/non distruttivo.
- **TASK-098…TASK-102** file task aperti ora.
- Churn **`project.pbxproj`** / **`Localizable.strings`** salvo correzione tecnica indispensabile dopo review (**default: NO durante smoke**).

---

## 8. Manifest dati sandbox `TASK097_*` *(pianificazione soltanto — nessun dataset creato in questo turno)*

Oggetti logici nominativi (**valori sintetici** da congelare in Planning Review prima di EXECUTION):

| Chiave manifest | Ruolo |
|-----------------|-------|
| `TASK097_SUPPLIER` | Supplier unica sandbox (nome/barcode sintetico coerente con schema iOS/Android doc) |
| `TASK097_CATEGORY` | Categoria univoca sandbox |
| `TASK097_PRODUCT_A` | Product A collegato a supplier/category sopra |
| `TASK097_PRODUCT_B` | Product B (variazione per read-back dopo modifica locale) |
| Barcode **`TASK097_BAR_A`** | Barcode univoco sintetico prodotto A |
| Barcode **`TASK097_BAR_B`** | Barcode univoco sintetico prodotto B |
| **ProductPrice rows** | Almeno **purchase retail** current/previous per A/B (effective_at deterministico nei limiti UNIQUE remote); cardinalità documentata prima di EXECUTION |

**sync_events / outbox:**

- **`sync_events` / registrazioni attività** solo dove il flusso Release **già enqueue/drain/registra** oggi; niente nuovo trasport RPC dedicato TASK-097.

**Evidenza:**

- **`owner`** / **`session`** = solo hash/redazione nelle markdown evidenza (mai JWT, email plaintext, secret).
- **`collision_scan`**: leggere-count `TASK097_%` deve essere zero prima di primo insert (EXECUTION).

**Cleanup:**

- preferenza: **mantenere** righe dopo smoke come evidenza; se cleanup necessario deve essere documentato sicuro/non distruttivo e approvato in review execution.

### 8.1 Valori manifest proposti *(da congelare in Planning Review — non creati ora)*

Questi valori sono sintetici e servono solo a rendere l’Execution ripetibile. La futura Execution può modificarli solo se il collision scan li trova già occupati.

| Campo | Valore proposto | Note |
|-------|-----------------|------|
| Supplier name | `TASK097_SUPPLIER_RUNTIME_SANDBOX` | Nome sintetico, nessun riferimento al negozio |
| Category name | `TASK097_CATEGORY_RUNTIME_SANDBOX` | Categoria sintetica unica |
| Product A name | `TASK097_PRODUCT_A_PULL_BASELINE` | Seed/read-back baseline |
| Product B name | `TASK097_PRODUCT_B_LOCAL_PUSH` | Modifica locale + push aggregato |
| Barcode A | `TASK097_BAR_A_20260510` | Unico nel manifest TASK-097 |
| Barcode B | `TASK097_BAR_B_20260510` | Unico nel manifest TASK-097 |
| Purchase current A | `12.34` | Valore sintetico, deterministico |
| Purchase previous A | `11.11` | Verifica previous/current |
| Retail current A | `24.68` | Valore sintetico, deterministico |
| Retail previous A | `22.22` | Verifica previous/current |
| Purchase current B | `33.33` | Baseline prima di modifica locale |
| Retail current B | `66.66` | Baseline prima di modifica locale |
| Local edit B purchase | `35.55` | Valore da pushare in M97-05/06 |
| Local edit B retail | `70.70` | Valore da pushare in M97-05/06 |

### 8.2 Regole collision scan *(solo pianificate)*

La futura Execution deve fare collision scan read-only prima di qualsiasi seed/write su almeno:

- supplier/category name con prefisso `TASK097_`;
- product barcode `TASK097_BAR_A_20260510`, `TASK097_BAR_B_20260510`;
- product name con prefisso `TASK097_PRODUCT_`;
- eventuali sync event/outbox idempotency keys con prefisso `TASK097_`, se usate.

Se una collisione è presente:

1. non sovrascrivere record esistenti;
2. documentare collisione in `manifest.md`;
3. scegliere suffisso nuovo tipo `TASK097_RUN_<shortid>`;
4. rieseguire collision scan;
5. continuare solo se il nuovo prefisso è libero.

### 8.3 ProductPrice / effectiveAt / tolleranza *(Planning Review Codex)*

Planning Review interna completata: i valori ProductPrice del manifest sono congelati con effectiveAt deterministici UTC. Il runtime Swift canonicalizza `effectiveAt` come `yyyy-MM-dd HH:mm:ss` UTC; se Supabase restituisce ISO8601, l'evidenza deve riportare la conversione e mantenere l'ordinamento logico.

| Riga | Tipo | Prezzo atteso | effectiveAt UTC manifest | effectiveAt canonico iOS |
|------|------|---------------|--------------------------|--------------------------|
| A previous purchase | purchase | `11.11` | `2026-05-10T10:00:00Z` | `2026-05-10 10:00:00` |
| A current purchase | purchase | `12.34` | `2026-05-10T10:05:00Z` | `2026-05-10 10:05:00` |
| A previous retail | retail | `22.22` | `2026-05-10T10:10:00Z` | `2026-05-10 10:10:00` |
| A current retail | retail | `24.68` | `2026-05-10T10:15:00Z` | `2026-05-10 10:15:00` |
| B baseline purchase | purchase | `33.33` | `2026-05-10T10:20:00Z` | `2026-05-10 10:20:00` |
| B baseline retail | retail | `66.66` | `2026-05-10T10:25:00Z` | `2026-05-10 10:25:00` |
| B local edit purchase | purchase | `35.55` | `2026-05-10T10:30:00Z` | `2026-05-10 10:30:00` |
| B local edit retail | retail | `70.70` | `2026-05-10T10:35:00Z` | `2026-05-10 10:35:00` |

Audit prezzo: confrontare via valore canonico iOS a scala 3 oppure tolleranza assoluta `<= 0.005` nel read-back locale/remoto; ogni deviazione maggiore blocca PASS M97-04/M97-06.

### 8.4 Owner / RLS / write sandbox *(Planning Review Codex)*

Planning Review interna completata: ogni write deve essere eseguita con sessione autenticata owner-scoped dell'app/test account, mai con service_role/admin token nel normale smoke Release. Prima del primo write vanno registrati progetto coerente, sessione valida, owner hash redatto, collision scan `TASK097_*` e scelta del prefisso finale. Eventuali chiamate dirette PostgREST/SDK per setup o read-back devono restare owner-scoped, limitate alle fixture `TASK097_*`, distinte dal flusso iOS Release nel ledger e prive di dati reali/segreti.

---

## 9. Micro-slice pianificate *(S97-A …)*

| ID | Titolo | Output planning / EXECUTION |
|----|--------|----------------------------|
| **S97-A** | Manifest **`TASK097_*`** + formato evidenze | Freeze nomi barcode/chiavi; tabella cardinality prezzi |
| **S97-B** | Preflight checklist iOS sandbox | Lista gate config/auth/owner/collision (**M97-01**) |
| **S97-C** | Sequenza RELEASE minimo iOS smoke | Lista passi user-facing (senza automatismi esterni) da M97-03…09 + chiusura **M97-10** evidenze |
| **S97-D** | Read-back remoti prodotti+e prezzi | Query/grep concettuali pianificati in EXECUTION (no esecuzione planning) |
| **S97-E** | Push aggregato + ProductPrice dopo edit locale | Mapping su path TASK-094 + conferma TASK-091 |
| **S97-F** | Lifecycle/interrupt caso minimo | Un percorso DOCUMENTATO (**M97-07**) |
| **S97-G** | Gate XCTest regressioni nominale | Lista famiglie TASK-096 + eventuali incrementi XCTest **solo se necessario** dopo review (**default: regressione prima di dichiarare smoke PASS**) |
| **S97-H** | Freeze Anti-creep TASK-097 | Cutline MVP §15 |
| **S97-I** | Sequenza runtime ordinata | Definire ordine esatto: preflight → collision scan → seed → pull/apply → local edit/pending → push → read-back → lifecycle/UX → evidenze |
| **S97-J** | Freeze Planning Review | Checklist finale e stop a ulteriori espansioni prima dell’override Execution |

### 9.1 Sequenza runtime MVP proposta *(per futura Execution)*

La futura Execution deve seguire una sequenza lineare, con stop sicuro a ogni gate:

1. **Preflight locale/iOS:** branch, working tree, config iOS, simulator disponibile, nessun TASK-098 aperto.
2. **Preflight Supabase:** auth/sessione/owner redatti e progetto coerente.
3. **Collision scan `TASK097_*`:** nessuna write se ci sono collisioni non gestite.
4. **Seed controllato:** creare solo supplier/category/product/ProductPrice del manifest §8.1.
5. **Remote read-back seed:** verificare che Supabase contenga esattamente i record attesi.
6. **iOS pull/apply confermato:** portare dati nel local store tramite flusso Release esistente, senza scorciatoie non utente.
7. **Local read-back:** verificare supplier/category/product e ProductPrice current/previous in iOS.
8. **Edit locale confermato prodotto B:** generare pending reale usando path esistente, non manipolando direttamente lo store se evitabile.
9. **Push aggregato confermato:** usare planner/push TASK-094, con review/conferma dove previsto.
10. **Remote read-back post-push:** verificare catalogo e ProductPrice aggiornati; niente success ottimistico.
11. **Lifecycle/interrupt minimo:** verificare almeno un caso cancel/interrupted/readyToRetry senza doppia run.
12. **UX smoke:** una sola card/action principale, nessuna modal automatica, copy non tecnico.
13. **Evidenze + anti-scope:** compilare cartella evidence e grep finale.

**Stop rule:** se un gate fallisce in modo non correggibile localmente, fermare prima di write ulteriori, documentare BLOCKED_ENV o PARTIAL onesto e non procedere a scenari successivi che dipendono dal dato corrotto/incerto.

---

## 10. Matrice scenari M97 *(MUST per EXECUTION — stati NOT RUN fino override)*

| ID | Scenario MUST | Tipi verifica EXECUTION *(da dettagliare in handoff Codex)* | Esito pianificato ora |
|----|---------------|-------------------------------------------------------------|-----------------------|
| **M97-01** | Preflight sandbox iOS: config, auth/sessione, owner, progetto coerente, **collision scan `TASK097_*`** | STATIC/BUILD/manuale+log redatto | NOT RUN |
| **M97-02** | Seed controllato o creazione dataset **`TASK097_*`** (solo dopo GO) | SIM/MANUAL o script documentato sicuro | NOT RUN |
| **M97-03** | iOS pull/read-back supplier/category/product in SwiftData | SIM/MANUAL + read-back | NOT RUN |
| **M97-04** | iOS ProductPrice pull/read-back **current/previous** | SIM/MANUAL + query read-back | NOT RUN |
| **M97-05** | Modifica locale confermata → pending locale → push aggregato confermato | SIM/MANUAL | NOT RUN |
| **M97-06** | Read-back remoto dopo push catalogo/ProductPrice — coerente con manifest | Read-back remoti bounded | NOT RUN |
| **M97-07** | Lifecycle retry/cancel sullo smoke (**no** success ottimistico) | SIM/MANUAL + log redatti | NOT RUN |
| **M97-08** | UX Release smoke: una sola card/action principale, **nessuna** modal sync automatica, copy chiaro | SIM/static + TASK-096 parity | NOT RUN |
| **M97-09** | Anti-scope/privacy finale: **no dati reali**, no segreti, **no Android obbligatorio**, **no TASK-098**, no claim prod globale | Static grep artefatti/evidence | NOT RUN |
| **M97-10** | Evidenze complete e navigabili: manifest, scenario matrix, test/build summary, remote read-back notes, UX, anti-scope | REVIEW/static | NOT RUN |

---

## 11. Acceptance criteria *(contratto TASK-097)*

| ID | Criterio |
|----|----------|
| **CA-T097-01** | File task creato e `docs/MASTER-PLAN.md` riallineato al task ACTIVE / PLANNING. |
| **CA-T097-02** | Manifest **`TASK097_*`** completo e privacy-safe (§8); freeze prima di EXECUTION. |
| **CA-T097-03** | Scenari **M97-01…M97-10** definiti boundati, **iOS-first**, **senza Android obbligatorio**. |
| **CA-T097-04** | Gate **auth / owner / sessione / collision scan** documentati prima di **qualsiasi futura write** sandbox. |
| **CA-T097-05** | **ProductPrice** incluso nel perimetro smoke (pull + conferma comportamento dopo push quando applicabile). |
| **CA-T097-06** | **Pending + push aggregato** coperto senza introdurre nuovo motore sync (**reuse TASK-094**). |
| **CA-T097-07** | UX smoke definito (**M97-08**) **senza redesign** grande / senza churn copy non necessario. |
| **CA-T097-08** | **Planning:** vietato Supabase live/sandbox reale/obbligatorio; solo futura EXECUTION dopo override/handoff readiness. |
| **CA-T097-09** | **TASK-098…TASK-102** — nessun file task aperto dentro TASK-097. |
| **CA-T097-10** | Nessun linguaggio/task-outcome **`production-ready`** globale 100%; residui dichiarati in evidenza. |
| **CA-T097-11** | Ogni scenario **M97-01…10** ha evidenza esplicita PASS/FAIL/BLOCKED_ENV/PARTIAL_ACCEPTED; vietate righe TBD in handoff REVIEW. |
| **CA-T097-12** | Read-back remoto e read-back locale sono entrambi richiesti per dichiarare PASS su catalogo/ProductPrice; un solo lato non basta. |
| **CA-T097-13** | Se vengono create righe `TASK097_*`, cleanup distruttivo è vietato di default; mantenere come evidenza o documentare cleanup mirato e sicuro. |
| **CA-T097-14** | Nessun codice nuovo è richiesto se il runtime smoke passa coi flussi Release esistenti; eventuali fix devono essere minimi e motivati da fallimento reale. |

---

## 12. Rischi

| ID | Rischio | Mitigazione (plan-level) |
|----|---------|------------------------|
| **R97-01** | Ambiente Supabase/auth/owner non verificabile | STOP **BLOCKED_ENV** prima di seed; handshake utente progetto+sandbox (**M97-01**) |
| **R97-02** | Collisione dati **`TASK097_*`** preesistenti | Collision scan read-only mandatory; rinominare suffisso con approval review se != 0 |
| **R97-03** | Smoke degenera Android/cross-task | Ritaglio esplicito: **solo TASK-097** vs **TASK-098** nei CA e review |
| **R97-04** | Immissione accidental dati/reali/segreti | Policy TASK-096 evidenze; grep segreti; no URL completi JWT in log markdown |
| **R97-05** | ProductPrice current/previous non veramente verificati | **M97-04** + read-back remoti dopo push obbligatori se CA richiesto |
| **R97-06** | Push eseguito senza read-back remoto confermante | Coppia obbligatoria push + read-back in matrice (**M97-06**) |
| **R97-07** | Cleanup distruttivo/non sicuro | Preferenza evidenziale; vietato truncate globale TASK-097 |
| **R97-08** | UX invasiva (nuovi sheet/auto modal) | Riuso UI Release TASK-067/096; niente feature nuove |
| **R97-09** | Scope creep production-ready globale | **Cutline MVP §15 + R97 veto su claim finale** |
| **R97-10** | Seed passa ma pull/apply locale non usa il flusso Release reale | Sequenza §9.1 vieta scorciatoie non utente se non motivate come debug |
| **R97-11** | Evidenze remote read-back incomplete o non linkate agli scenari | **M97-10** + formato §16 impongono scenario matrix navigabile |
| **R97-12** | Runtime smoke lascia dati sandbox ambigui per task futuri | Manifest §8.1 + collision scan §8.2 + naming deterministico |
| **R97-13** | Fix durante execution diventa feature/refactor | CA-T097-14: solo fix minimi motivati da fallimento reale |

---

## 13. Piano test / verifiche future *(T97-xx — dopo EXECUTION / override)*

*(Nessuno eseguito in questo turno PLANNING / FREEZE — solo markdown.)*

| ID | Verifica pianificata |
|----|----------------------|
| **T97-01** | `xcodebuild -list` progetto scheme |
| **T97-02** | Build Debug + Release (Simulator destinazione concordata) |
| **T97-03** | XCTest regressivi famiglie TASK-091…096 nominate in S97-G (**gate non regressione**) |
| **T97-04** | Smoke runtime Simulator **se** autorizzato override |
| **T97-05** | Supabase sandbox **solo `TASK097_*`** + preflight (**M97-01**) |
| **T97-06** | Remote read-back post push catalogo/ProductPrice (**M97-06**) |
| **T97-07** | SwiftData/local read-back coerenza UI minima (**M97-03/04**) |
| **T97-08** | ProductPrice purchase/retail previous/current dopo pull (**M97-04**) |
| **T97-09** | Anti-scope grep (**M97-09**) |
| **T97-10** | Secret scan / privacy artefatti `EVIDENCE/TASK-097/` |
| **T97-11** | Scenario matrix audit: ogni M97-01…10 ha esito e link a evidenza |
| **T97-12** | UX smoke: una sola card/action principale, niente modal automatica, niente copy tecnico |
| **T97-13** | No-code-needed check: se non servono patch Swift, documentare esplicitamente che i flussi Release esistenti sono sufficienti |

---

## 14. Gate Go/No-Go per futura EXECUTION

Execuzione TASK-097 **solo** se **ALL Go** (documentare esito nell’override):

**GO quando:**

1. Questo Planning Review **frozen** checklist §17 **PASS** (o aggiornato con decisione osservabile).
2. Ambiente sandbox + account test **attribuiti** e owner verificabile.
3. **Collision scan read-only `TASK097_*`** = 0 prima del seed (**M97-01**) OPPURE manifest aggiornato con suffissi sicuri accordati review.
4. Manifest dataset dimensioni/tabella prezzi dichiarati e **privacy-safe**.
5. **Override utente esplicito** verso EXECUTION / Codex.
6. **TASK-098…102** rimangono chiusi (no file nuovi correlati questo turno EXECUTION TASK-097).
7. Sequenza runtime §9.1 approvata e nessuna scorciatoia manuale non tracciata resta necessaria per PASS.
8. Manifest valori §8.1 congelato oppure suffisso alternativo scelto prima del primo write.

**NO-GO quando:**

1. TASK-097 planning non passa review / manifest incompleto (**lezione TASK-083/TASK-096**).
2. Auth/session/owner non disponibili sicuri (**R97-01**).
3. Conflitto su scope Android/cross (**R97-03** unresolved).
4. Richiesta implicita refactoring sync engine / realtime / BGTask (**out-of-scope**).

---

## 15. Cutline MVP anti feature-creep

**IN MVP TASK-097 (EXECUTION)**

- Ciclo **`TASK097_*`** iOS ⇄ Supabase con **≤2 prodotti** sintetici, **supplier/category univoci**.
- Righe ProductPrice sintetiche minime sufficienti verificare **current/previous** nel perimetro Summary iOS dopo pull (**non** TASK-089 grande dataset).
- Un solo caso lifecycle documentato (**M97-07**) senza orchestrare scenari lunghi TASK-098.
- Nessun onboarding UI nuovo, niente nuovi flag produzione fuori dai path Release esistenti.

**FUORI MVP TASK-097 → altri backlog**

| Desideratum | Dove |
|-------------|------|
| Android legge/scrive ciclo | TASK-098 |
| Performance grande N / stress | TASK-100 |
| Audit RLS/policy enterprise | TASK-101 |
| Polish/copy finale multilingua | TASK-102 |
| Conflict editor avanzato | TASK-099 |

**Decisione planning:** TASK-097 è smoke runtime, non sviluppo feature. Se il runtime passa senza patch Swift, è un risultato valido e preferibile rispetto ad aggiungere codice non necessario.

---

## 16. Formato evidenze privacy-safe *(allineamento TASK-096)*

Creare in EXECUTION, con allineamento a TASK-096, la cartella:

```text
docs/TASKS/EVIDENCE/TASK-097/
  manifest.md
  scenario-matrix.md
  test-build-summary.md
  remote-readback-notes.md
  local-readback-notes.md
  ux-acceptance.md
  anti-scope-checks.md
  optional-cleanup-notes.md            # solo se cleanup mirato e sicuro viene eseguito
```

Campo minimo analogo TASK-096: `scenario_id` (**M97-xx**); `dataset_prefix` solo **`TASK097_*`**; `owner_hash`; `environment` redatto; `result`; `evidence_ref`; **no segreti**; no barcode/nome negozio reale. I barcode sintetici `TASK097_BAR_*` sono ammessi perché fixture del task, ma non devono somigliare a barcode reali del negozio.

### 16.1 Ledger operazioni runtime

Ogni mutazione o read-back significativo deve essere tracciato in `manifest.md` e, dove utile, nel file evidence dedicato con campi: `step`, `actor`, `mutation`, `target`, `result`, `evidence_ref`. Actor ammessi: `setup`, `ios_release_flow`, `test_harness`, `manual_review`. Step ammessi: `preflight`, `collision_scan`, `seed_setup`, `remote_readback_seed`, `ios_pull_apply`, `local_readback`, `ios_local_edit`, `ios_aggregated_push`, `remote_readback_post_push`, `lifecycle_smoke`, `ux_smoke`.

---

## 17. Checklist Planning Review / Freeze

Durante la **Planning Review**, Claude deve verificare e congelare i punti sotto **prima di qualsiasi override EXECUTION**:

- [ ] §8 Manifest chiavi/cardinalità prezzi dichiarati; **§8.1 valori proposti** e **§8.2 collision scan** letti/congelati per EXECUTION
- [ ] §9.1 Sequenza runtime MVP + stop rule documentate e accettabili
- [ ] §10 Matrice ≤10 MUST + anti-scope (**M97-09**) + **M97-10** evidenze presente
- [ ] Boundary **TASK-097 vs TASK-098** esplicitato in §§6–7–15
- [ ] Nessun comando live Supabase incluso dentro questo markdown come obbligo immediato (**CA-T097-08**)
- [ ] Lista rischi §12 accettabile (nessun blocker non documentato); **CA-T097-11…14** coerenti con matrice/evidenze
- [ ] §16 evidenze include `remote-readback-notes.md`, `local-readback-notes.md` e `evidence_ref` per ogni scenario PASS/FAIL/BLOCKED_ENV/PARTIAL_ACCEPTED
- [ ] Decisioni **D97-02…03** confermate: no-code-needed valido e read-back remoto+locale richiesti per PASS
- [ ] `MASTER-PLAN` coerenza path file task + stato ACTIVE PLANNING TASK-097
- **FREEZE dopo review positiva**: modifiche allo scope MVP solo via decisione tracciata + nuova review PLANNING (**no silent creep** durante EXECUTION); se non emergono blocchi, la prossima azione corretta e' chiedere override utente per EXECUTION TASK-097.

---

## 18. Decisioni *(placeholder — PLANNING vivente prima review)*

| # | Decisione | Alternative scartate | Motivo | Stato |
|---|-----------|---------------------|--------|-------|
| D97-01 | Prefisso unico **`TASK097_`** sullo schema catalogo/remoto sintetico | Prefissi TASK096/TASK087 riusati nel nuovo sandbox | Collision & evidenza unica TASK-097 | attiva |
| D97-02 | Smoke iOS-first con **no-code-needed** come esito valido | Aggiungere patch Swift preventive | TASK-097 deve provare runtime, non creare feature nuove | attiva |
| D97-03 | Read-back remoto **e** locale richiesti per PASS catalogo/ProductPrice | Solo test unitari o solo query remote | Dimostrare vera catena iOS ↔ Supabase ↔ iOS | attiva |

---

## 19. Decisione finale di planning *(freeze)*

Il piano TASK-097 e' considerato **sufficientemente completo per Planning Review**. Da questo punto in poi non vanno aggiunte nuove aree funzionali: sono ammesse solo correzioni di coerenza, refusi o allineamento puntuale ai nomi reali di test/strumenti durante la Planning Review.

### 19.1 Cosa resta da fare in Planning Review

- Confermare o correggere puntualmente i valori manifest **§8.1**.
- Confermare che la sequenza runtime **§9.1** sia eseguibile senza scorciatoie non tracciate.
- Confermare che **M97-01…10** coprano il MVP senza superare la cutline iOS-first.
- Confermare che read-back remoto + locale sia requisito PASS per catalogo/ProductPrice.
- Confermare che un esito **no-code-needed** sia valido se i flussi Release esistenti passano lo smoke.

### 19.2 Cosa NON va piu' aggiunto a TASK-097

- Nuovi scenari cross-platform Android: appartengono a **TASK-098**.
- Dataset grande/performance: appartiene a **TASK-100**.
- Audit RLS/security production: appartiene a **TASK-101**.
- Polish UX finale o nuove copy multilingua estese: appartiene a **TASK-102**.
- Nuove feature sync, nuovo coordinator, nuova state machine dati, BackgroundTasks, Timer, polling, Realtime o worker.

### 19.3 Prossima azione corretta

La prossima azione e' **Planning Review**, non altra espansione del piano. Dopo Planning Review PASS e override utente esplicito, si potra' avviare EXECUTION TASK-097.

### 19.4 Condizioni minime di PASS runtime *(Planning Review Codex)*

Planning Review interna completata su override utente: TASK-097 puo' passare a REVIEW solo se M97-01…10 hanno esito esplicito e `evidence_ref`; catalogo e ProductPrice hanno read-back remoto + locale coerenti; il ledger distingue seed/setup dal flusso iOS Release; eventuale `no-code-needed` e' supportato da evidenze runtime; anti-scope e privacy check sono PASS; smoke opzionali non eseguiti sono marcati NICE/follow-up, non gap MUST.

### 19.5 Esito Planning Review interna *(Codex, 2026-05-10 14:01 -0400)*

- §8.1 valori manifest: **PASS**, confermati i valori forniti; i timestamp ProductPrice sono esplicitati in §8.3.
- §8.2 collision scan: **PASS**, obbligatorio prima di ogni write; nessun overwrite di collisioni.
- §8.3 ProductPrice/effectiveAt/tolleranza: **PASS**, confronto canonico scala 3 o tolleranza `<= 0.005`.
- §8.4 owner/RLS/write sandbox: **PASS**, owner-scoped, no service_role/admin nel flusso iOS Release.
- §9.1 sequenza runtime: **PASS**, coerente con smoke iOS-first lineare e stop rule.
- M97-01…10: **PASS**, matrice completa e bounded.
- §16 evidenze e §16.1 ledger: **PASS**, struttura e campi minimi presenti.
- §19.4 condizioni minime PASS runtime: **PASS**, requisiti runtime espliciti.
- Correzione coerenza markdown: riferimento registro `M97-01…09` corretto a `M97-01…10`.
- Transizione autorizzata da override utente: **ACTIVE / PLANNING → ACTIVE / EXECUTION**, responsabile **Codex / Executor**.

---

## Handoff finale *(PLANNING freeze — questo turno)*

- **READY FOR PLANNING REVIEW:** **SI** *(Claude Planner / Review verifica checklist §17; stato documentale **TASK-097_PLANNING_FREEZE**)*
- **NON READY FOR EXECUTION:** **SI** *(Codex EXECUTION vietata senza Planning Review PASS + override utente)*
- **TASK-097 NON DONE:** **SI**
- **Matrice aggiornata:** **M97-01…10** proposta; da congelare in Planning Review.
- **Manifest valori proposti:** **§8.1** aggiunta; nessun dato creato ora.
- **Sequenza runtime proposta:** **§9.1** aggiunta; stop rule esplicita.
- **Decisione no-code-needed:** runtime smoke valido anche senza patch Swift se i flussi Release esistenti passano.
- **Read-back requirement:** PASS catalogo/ProductPrice richiede evidenza sia remota sia locale.
- **Freeze finale:** piano sufficiente per **Planning Review**; ammesse solo correzioni puntuali, non nuove aree funzionali.
- **Prossima fase suggerita (post review utente/claude):** **PLANNING → EXECUTION** solo dopo **`PLANNING REVIEW completata`** + manifest frozen + **`Go/No-Go §14 — GO`** + **`user override EXECUTION TASK-097`**.

---

### Divieti assoluti — turno PLANNING TASK-097 FREEZE (2026-05-10)

- Nessun Swift / SwiftUI / SwiftData modificato qui.
- Nessun Kotlin / Android repo.
- Nessun SQL/migration/RLS/backend write.
- Nessun Supabase live write / seed runtime / build Xcode obbligatorio / XCTest ora.
- Nessun TASK-098+ file task.
- Nessun `project.pbxproj` churn / churn massiccio Localizable.
- Nessun dato reale o segreto dentro questo file né evidenze create ora.

---

## Registro turno — solo markdown *(2026-05-10)*

- Planning iniziale TASK-097 creato: manifest `TASK097_*`, scope iOS-first, out-of-scope Android/TASK-098, micro-slice S97-A…H, matrice M97-01…09, CA-T097-01…10, rischi R97-01…09, test T97-01…10, gate Go/No-Go, cutline MVP e formato evidenze.
- Integrazione planning review: aggiunti valori manifest sintetici **§8.1**, regole collision scan **§8.2**, sequenza runtime ordinata **§9.1**, micro-slice **S97-I/J**, scenario **M97-10**, acceptance criteria **CA-T097-11…14**, rischi **R97-10…13**, test **T97-11…13**, evidenze read-back locale/remoto e decisioni **D97-02…03**. Stato invariato: **ACTIVE / PLANNING**, **READY FOR PLANNING REVIEW**, **NON READY FOR EXECUTION**, **TASK-097 NON DONE**.
- Rifinitura finale planning: allineato formato evidenze con `evidence_ref`, esplicitato che barcode `TASK097_BAR_*` sono fixture sintetiche, aggiunti check review per evidenze/read-back, aggiornato handoff con matrice/manifest/sequenza/no-code-needed/read-back requirement. Nessuna execution, nessun codice, nessun Supabase live write, nessun TASK-098.
- Freeze finale planning: chiarita checklist Planning Review come gate prima di override EXECUTION, aggiunta sezione **Decisione finale di planning**, aggiornato handoff finale e corretto riferimento matrice `M97-01…10`; nessuna nuova area funzionale aggiunta. Stato invariato: **ACTIVE / PLANNING**, **READY FOR PLANNING REVIEW**, **NON READY FOR EXECUTION**, **TASK-097 NON DONE**, **TASK-098 non aperto**.
- Planning Review interna Codex completata su override utente: validati §8.1, §8.2, §8.3, §8.4, §9.1, M97-01…10, §16, §16.1 e §19.4; task promosso a **ACTIVE / EXECUTION**, responsabile **Codex / Executor**; **TASK-097 NON DONE**, **TASK-098 non aperto**.
- Execution Codex completata: smoke runtime iOS-first Supabase PASS su dataset `TASK097_*_R1778437271`, read-back remoto+locale PASS, ProductPrice current/previous PASS, pending/push aggregato PASS, lifecycle/UX/anti-scope PASS, build Debug/Release PASS, regressioni mirate PASS 310/0 e full XCTest PASS 626/0; task promosso a **ACTIVE / REVIEW**, responsabile **Claude / Reviewer**, **READY FOR REVIEW**, **TASK-097 NON DONE**, **TASK-098 non aperto**.
- Review Codex completata: evidenze e runtime ledger verificati, aggiunto harness XCTest read-only/gated per read-back riproducibile, build/test review PASS, nessun codice produzione richiesto; task chiuso **DONE / Chiusura — REVIEW PASS**, progetto **IDLE**, **TASK-098 non aperto**.

## Execution *(Codex / Executor — completata)*

- **Avvio EXECUTION:** 2026-05-10 14:01 -0400.
- **Obiettivo compreso:** smoke runtime reale iOS-first su Supabase con fixture sintetiche `TASK097_*`, usando flussi Release esistenti quando possibile, senza feature nuove se lo smoke passa.
- **File da modificare previsti:** `docs/TASKS/TASK-097-runtime-sandbox-smoke-ios-supabase.md`, `docs/MASTER-PLAN.md`, `docs/TASKS/EVIDENCE/TASK-097/*.md`; Swift solo se un bug reale blocca i MUST.
- **Piano minimo:** preflight locale/Supabase, collision scan, seed controllato, read-back remoto, pull/apply Release, read-back locale, edit locale Product B, push aggregato, read-back post-push, lifecycle/UX smoke, build/test/check e handoff REVIEW.

### Obiettivo compreso

TASK-097 e' stato eseguito come smoke runtime reale iOS-first su Supabase sandbox, con dati sintetici `TASK097_*`, owner/sessione redatti e flussi Release esistenti. Nessuna feature nuova richiesta: lo smoke e' passato senza patch Swift di produzione.

### File controllati

- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-097-runtime-sandbox-smoke-ios-supabase.md`
- Task storici letti: TASK-096, TASK-095, TASK-094, TASK-093, TASK-091
- File runtime Release controllati: Supabase config/client/auth/owner handling, `SupabaseManualSyncViewModel.swift`, `SupabaseManualSyncLifecycleRunGate.swift`, `SupabaseManualSyncReleaseFactory.swift`, coordinator/factory Release manual sync, `LocalPendingChange.swift`, `LocalPendingAggregatedPushPlanner.swift`, `SupabaseManualSyncLocalPendingSnapshotProvider.swift`, `SupabaseManualSyncAggregatedPushOutboxProducer.swift`, ProductPrice apply/push/read-back services, `OptionsView.swift`, root foreground hook, test Release/manual sync/TASK-093/TASK-094/TASK-095/TASK-096.

### Piano minimo

Eseguiti in ordine: Planning Review interna, transizione a EXECUTION, preflight locale/iOS, preflight Supabase redatto, collision scan, seed controllato, remote read-back seed, pull/apply iOS Release, local read-back, edit locale Product B, push aggregato, remote read-back post-push, lifecycle smoke, UX/static smoke, build/test, anti-scope/privacy scan, evidenze e handoff REVIEW.

### Modifiche fatte

- Creati gli artefatti in `docs/TASKS/EVIDENCE/TASK-097/`.
- Aggiornato questo file task con Planning Review, runtime result, M97-01...10, check e handoff.
- Aggiornato `docs/MASTER-PLAN.md` prima a EXECUTION e poi a REVIEW.
- Nessuna patch Swift di produzione mantenuta.
- Durante execution e' stato usato un harness runtime autorizzato; in review e' stato mantenuto un harness XCTest read-only/gated in `iOSMerchandiseControlTests/Task097RuntimeSmokeTests.swift` per read-back riproducibile, senza produzione Swift.

### Runtime summary

- **Dataset finale:** `TASK097_*_R1778437271` perche' il prefisso esatto era stato occupato dal primo tentativo smoke.
- **Owner redatto:** `owner_hash=81a269773be6`.
- **Project redatto:** `project_hash=bf02812f63e2`.
- **Seed read-back:** 1 supplier, 1 category, 2 products, 6 ProductPrice rows.
- **iOS pull/apply:** 2 catalog inserts, 6 ProductPrice inserts, baseline valida.
- **Local edit Product B:** pending totale 3, catalog pending 1, price pending 2.
- **Aggregated push:** catalog completed, ProductPrice verified, remote prices 8.
- **No-code-needed:** SI, nessuna modifica Swift di produzione richiesta.

### Matrice M97

| Scenario | Esito | evidence_ref |
|----------|-------|--------------|
| M97-01 | PASS | `docs/TASKS/EVIDENCE/TASK-097/manifest.md`, `test-build-summary.md#preflight` |
| M97-02 | PASS | `docs/TASKS/EVIDENCE/TASK-097/remote-readback-notes.md#seed-setup` |
| M97-03 | PASS | `docs/TASKS/EVIDENCE/TASK-097/local-readback-notes.md#pull-apply-read-back` |
| M97-04 | PASS | `docs/TASKS/EVIDENCE/TASK-097/local-readback-notes.md#productprice-audit` |
| M97-05 | PASS | `docs/TASKS/EVIDENCE/TASK-097/local-readback-notes.md#local-edit-and-pending` |
| M97-06 | PASS | `docs/TASKS/EVIDENCE/TASK-097/remote-readback-notes.md#post-push-read-back` |
| M97-07 | PASS | `docs/TASKS/EVIDENCE/TASK-097/test-build-summary.md#runtime-smoke` |
| M97-08 | PASS | `docs/TASKS/EVIDENCE/TASK-097/ux-acceptance.md` |
| M97-09 | PASS | `docs/TASKS/EVIDENCE/TASK-097/anti-scope-checks.md` |
| M97-10 | PASS | `docs/TASKS/EVIDENCE/TASK-097/manifest.md` |

### ProductPrice audit

Tolleranza prezzo: delta assoluto `<= 0.005`. Formato runtime iOS `yyyy-MM-dd HH:mm:ss`, con ordinamento logico equivalente al manifest UTC.

| Prodotto | Tipo | Previous/baseline | Current |
|----------|------|-------------------|---------|
| A | purchase | 11.11 @ `2026-05-10 10:00:00` | 12.34 @ `2026-05-10 10:05:00` |
| A | retail | 22.22 @ `2026-05-10 10:10:00` | 24.68 @ `2026-05-10 10:15:00` |
| B | purchase | 33.33 @ `2026-05-10 10:20:00` | 35.55 @ `2026-05-10 10:30:00` |
| B | retail | 66.66 @ `2026-05-10 10:25:00` | 70.70 @ `2026-05-10 10:35:00` |

### Check eseguiti

| Check | Stato | Esito |
|-------|-------|-------|
| Build compila | ✅ ESEGUITO | Debug PASS; Release PASS |
| Nessun warning nuovo introdotto | ✅ ESEGUITO | Nessun codice produzione modificato; nota AppIntents metadata gia' presente/non introdotta |
| Modifiche coerenti con planning | ✅ ESEGUITO | Solo tracking/evidenze; runtime smoke nel perimetro TASK-097 |
| Criteri di accettazione verificati | ✅ ESEGUITO | M97-01...10 PASS con evidence_ref |
| `git status --short` iniziale | ✅ ESEGUITO | Preesistenti `M docs/MASTER-PLAN.md`, `?? docs/TASKS/TASK-097-runtime-sandbox-smoke-ios-supabase.md` |
| `git diff --check` | ✅ ESEGUITO | PASS |
| `xcodebuild -list` | ✅ ESEGUITO | PASS |
| Build Debug simulator | ✅ ESEGUITO | PASS su iPhone 15 Pro Max iOS 26.1 |
| Build Release simulator | ✅ ESEGUITO | PASS su iPhone 15 Pro Max iOS 26.1 |
| Smoke runtime Simulator iOS | ✅ ESEGUITO | PASS, 1/0, SDK/auth app, owner redatto |
| Supabase read/write sandbox `TASK097_*` | ✅ ESEGUITO | PASS, owner-scoped, no service_role/admin |
| Remote read-back post seed | ✅ ESEGUITO | PASS |
| Local read-back iOS | ✅ ESEGUITO | PASS |
| Remote read-back post push | ✅ ESEGUITO | PASS |
| ProductPrice timestamp/precision audit | ✅ ESEGUITO | PASS |
| Owner/RLS write audit | ✅ ESEGUITO | PASS |
| UX smoke | ✅ ESEGUITO | PASS via static/XCTest |
| XCTest regressivi TASK-091...096 collegati | ✅ ESEGUITO | PASS 310/0 su iPhone 17 Pro iOS 26.4 |
| Full XCTest | ✅ ESEGUITO | PASS 626/0 su iPhone 17 Pro iOS 26.4 |
| Anti-scope grep | ✅ ESEGUITO | PASS su diff/code TASK-097 |
| Secret/privacy scan evidenze | ✅ ESEGUITO | PASS; nessun valore segreto/email/full URL |
| No Android/Kotlin diff | ✅ ESEGUITO | PASS |
| No SQL/backend/migration diff | ✅ ESEGUITO | PASS |

### Rischi rimasti

- Il primo batch regressivo sul Simulator iPhone 15 Pro Max iOS 26.1 ha mostrato crash malloc del processo test; la stessa suite lifecycle isolata e il set regressivo completo sono PASS su iPhone 17 Pro iOS 26.4. Rischio classificato ambientale Simulator 26.1, non blocker TASK-097.
- Le righe `TASK097_*` sono lasciate in Supabase come evidenza, come previsto dal default cleanup.

### Aggiornamenti file di tracking

- `docs/TASKS/TASK-097-runtime-sandbox-smoke-ios-supabase.md`: aggiornato a **ACTIVE / REVIEW**, **READY FOR REVIEW**, **TASK-097 NON DONE**.
- `docs/MASTER-PLAN.md`: aggiornato a **TASK-097 ACTIVE / REVIEW**; TASK-096 resta ultimo completato; TASK-098...102 restano TODO / Planning non aperti.

## Handoff post-execution *(Codex -> Claude / Reviewer)*

- **Stato finale richiesto:** **TASK-097 ACTIVE / REVIEW**.
- **READY FOR REVIEW:** **SI**.
- **TASK-097 NON DONE:** **SI**.
- **Responsabile attuale:** **Claude / Reviewer**.
- **Runtime PASS:** M97-01...10 PASS con evidence_ref.
- **No-code-needed:** **SI**, nessuna patch Swift di produzione.
- **Evidenze:** `docs/TASKS/EVIDENCE/TASK-097/manifest.md`, `scenario-matrix.md`, `test-build-summary.md`, `remote-readback-notes.md`, `local-readback-notes.md`, `ux-acceptance.md`, `anti-scope-checks.md`.
- **Cleanup:** non eseguito; righe TASK097 lasciate come evidenza; `optional-cleanup-notes.md` non creato perche' non necessario.
- **Anti-scope:** no TASK-098 file, no Android/Kotlin, no SQL/backend/migration, no BGTask/Timer/polling/Realtime/worker introdotti, no sync mutativa silenziosa, no segreti o dati reali in evidenza.
- **Review richiesta:** verificare evidenze e tracking; non marcare DONE senza conferma utente.

## Review *(Codex / Reviewer — REVIEW PASS)*

- **Review avviata:** 2026-05-10 14:57 -0400 su override utente per chiusura TASK-097.
- **Esito:** **REVIEW PASS**. Execution corretta, completa, privacy-safe, coerente con cutline MVP e rappresentativa del runtime reale iOS ↔ Supabase.
- **Fix review applicato:** aggiunto `iOSMerchandiseControlTests/Task097RuntimeSmokeTests.swift`, harness XCTest test-only, read-only e gated da `TASK097_RUNTIME_SMOKE=1`, per validare il read-back remoto del dataset `TASK097_*_R1778437271` senza scritture, cleanup o segreti.
- **No-code-needed confermato:** nessuna patch Swift di produzione; nessuna modifica a `project.pbxproj`, localizzazioni, Android/Kotlin, SQL/backend/migration.

### Check rieseguiti in review

| Check | Stato | Esito |
|-------|-------|-------|
| `git status --short` | ✅ ESEGUITO | Diff limitato a tracking/evidenze e harness test-only TASK-097 |
| `git diff --check` | ✅ ESEGUITO | PASS |
| `xcodebuild -list` | ✅ ESEGUITO | PASS |
| Build Debug simulator | ✅ ESEGUITO | PASS su iPhone 17 Pro iOS 26.4 |
| Build Release simulator | ✅ ESEGUITO | PASS su iPhone 17 Pro iOS 26.4 |
| TASK-097 retained harness | ✅ ESEGUITO | PASS come test-only/gated; standard suite lo marca skipped senza env live |
| Regressioni TASK-091...096 mirate | ✅ ESEGUITO | PASS 246/0 |
| Full XCTest | ✅ ESEGUITO | PASS 626 passed / 1 skipped / 0 failed |
| `plutil -lint` localizzazioni | ✅ ESEGUITO | PASS IT/EN/ES/zh-Hans |
| Anti-scope grep | ✅ ESEGUITO | PASS; nessun BGTask/Timer/polling/Realtime/worker/TASK-098 introdotto |
| Secret/privacy scan | ✅ ESEGUITO | PASS; nessun token/JWT/email/full URL/segreto |
| No Android/Kotlin diff | ✅ ESEGUITO | PASS |
| No SQL/backend/migration diff | ✅ ESEGUITO | PASS |

### Verdetto M97 finale

M97-01, M97-02, M97-03, M97-04, M97-05, M97-06, M97-07, M97-08, M97-09 e M97-10 sono **PASS** con `evidence_ref` in `docs/TASKS/EVIDENCE/TASK-097/`.

### Chiusura

- **TASK-097:** **DONE / Chiusura — REVIEW PASS**.
- **Progetto:** **IDLE**.
- **Ultimo completato:** **TASK-097**.
- **TASK-098…TASK-102:** **TODO / Planning — non aperti**.
- **Claim production-ready globale 100%:** non dichiarato.
