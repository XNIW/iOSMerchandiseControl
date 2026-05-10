# TASK-098 — Cross-platform smoke Android ↔ Supabase ↔ iOS

## Informazioni generali

- **Task ID:** TASK-098
- **Titolo:** **Cross-platform smoke Android ↔ Supabase ↔ iOS**
- **File task:** `docs/TASKS/TASK-098-cross-platform-smoke-android-supabase-ios.md`
- **Stato:** **DONE**
- **Fase attuale:** **Chiusura — REVIEW PASS**
- **Responsabile attuale:** **Nessuno / Chiusura**
- **Data creazione:** 2026-05-10
- **Ultimo aggiornamento:** 2026-05-10 17:24 -0400 — **REVIEW PASS; TASK-098 DONE**
- **Ultimo agente che ha operato:** Codex / Reviewer+Fixer

**Flag:** **`TASK-098_REVIEW_PASS_DONE`** — Planning Review completata; execution runtime cross-platform PASS; review completa PASS; Android → Supabase → iOS PASS; iOS → Supabase → Android PASS; ProductPrice current/previous parity PASS; evidenze privacy-safe; vietati e non rilevati TASK-099, service role/admin path, SQL/backend/migration, cleanup distruttivo e refactor ampi.

---

## Dipendenze

- **Dipende da:** **TASK-097 DONE / Chiusura — REVIEW PASS** — smoke runtime **iOS-first** iOS→Supabase→iOS con dataset **`TASK097_*`** ed evidenze in `docs/TASKS/EVIDENCE/TASK-097/`; dimostra pull/apply/push, ProductPrice current/previous, pending aggregato e lifecycle nel contesto Release **senza** Android obbligatorio.
- **Contesto tecnico cumulativo:** **TASK-096** acceptance composita Release; **TASK-095** RunGate/lifecycle; **TASK-094** push aggregato ProductPrice; **TASK-093** `LocalPendingChange`; **TASK-091** semi-auto review confermata.
- **Sblocca (non aperti):** **TASK-099…TASK-102** — restano backlog fino a init separato; TASK-098 **non** apre i loro file task.
- **Riferimento storico:** **TASK-087** ha già documentato smoke piccolo Android↔Supabase↔iOS con `TASK087_*`; TASK-098 ripete il **principio** con prefisso **`TASK098_*`**, allineato allo stack Release post-TASK-091 e alle lezioni TASK-097 (collision suffix, tolleranza prezzi, evidenze).

---

## Scopo

In **EXECUTION futura** (non in questo planning): dimostrare uno **smoke minimo cross-platform** tra **Android**, **Supabase sandbox** e **iOS** usando **solo** dati sintetici **`TASK098_*`**, con read-back remoto e locale **privacy-safe**, **senza** claim production-ready globale.

---

## Non incluso

Come **§7 Out-of-scope** sotto; in sintesi: refactor ampio, TASK-099–102, dataset grande, audit RLS completo, UX polish finale, feature business, background/realtime/worker, SQL/migration, cleanup distruttivo, dati reali.

---

## 1. Obiettivo

Verificare — nella sola **futura EXECUTION** autorizzata — che:

1. **Android scrive** (catalogo + **ProductPrice** con current/previous coerenti) → **iOS** **legga/applichi** correttamente dal cloud nello stesso progetto Supabase e owner-scope.
2. **iOS scrive** (catalogo + ProductPrice tramite **flusso Release** già esistente: pending → push aggregato dove applicabile) → **Android** **legga/pull** e mostri parity **minima** su catalogo e storico prezzi.
3. **ProductPrice** **purchase/retail** **current** e **previous** risultino **allineati** tra le due piattaforme e il remoto, entro **tolleranza** e **effectiveAt** documentati (stesso approccio TASK-097: timestamp deterministici, confronto monetario documentato).
4. Le **evidenze** seguano il **formato privacy-safe** (hash/redazione owner/session/progetto; nessun segreto; solo prefisso `TASK098_`).

**Questo documento (PLANNING):** definisce manifest, slice, matrice **M98**, criteri **CA-T098-***, rischi **R98-***, gate e handoff — **nessuna** esecuzione runtime.

---

## 2. Stato attuale post-TASK-097

- **TASK-097** ha chiuso con **REVIEW PASS**: ciclo **iOS→Supabase→iOS** reale su sandbox, dataset **`TASK097_*_R1778437271`**, ProductPrice current/previous verificati (tolleranza assoluta **≤ 0.005** nel resoconto evidenze), lifecycle e UX Release bounded, harness XCTest gated opzionale, **nessuna** patch Swift produzione obbligatoria.
- **Gap dopo TASK-097:** validato il percorso **iOS-first** isolato; **non** è ancora obiettivo di quel task la **verifica sistematica** Android↔iOS sullo **stesso** sandbox con prefisso dedicato **`TASK098_*`** e doppio ciclo write/read bidirezionale.
- **Progetto (pre-init TASK-098):** era **IDLE** con ultimo completato TASK-097; TASK-098 passa ad **ACTIVE / PLANNING** solo per redazione planning.

---

## 3. Contesto da TASK-097 / TASK-096 / TASK-095 / TASK-094 / TASK-093 / TASK-091

| Fonte | Cosa TASK-098 riusa / assume |
|-------|-------------------------------|
| **TASK-097** | Formato evidenze (`manifest`, `scenario-matrix`, read-back remoto/locale, `test-build-summary`, `anti-scope-checks`); **collision scan** prima della prima write; suffisso run (**es.** `R…`) se prefisso esatto occupato; tolleranza prezzi ed **effectiveAt** deterministici. |
| **TASK-096** | Matrice MUST bounded; **una** action primaria Release; review prima di mutazioni; anti-scope finale. |
| **TASK-095** | Preflight lifecycle: auth/owner/rete/app; niente success ottimistico su write incerta. |
| **TASK-094** | Push aggregato ProductPrice; fingerprint/idempotenza; outbox/sync activity **solo** se già nel flusso Release confermato. |
| **TASK-093** | Pending dopo commit confermati; snapshot prima del push pianificato. |
| **TASK-091** | Cooldown, review sheet, conferma utente prima di push/apply. |

---

## 4. Riferimento Android *(solo pianificazione runtime cross-platform — nessuna modifica Kotlin in questo turno)*

- **Ruolo:** in EXECUTION futura, Android effettua **write** sul dataset **A** (prodotto **Android→iOS**) e **read-back** dopo **write iOS** sul prodotto **B** (**iOS→Android**), usando i flussi sync/catalogo **già presenti** nel repo Android (come riferimento funzionale — **nessun** refactor architetturale pianificato qui).
- **Vincoli:** stesso **progetto Supabase** dell’iOS; stessa **sessione/owner** verificabile in modo privacy-safe; **nessun** service role nel percorso smoke **normale** utente (cfr. **R98-08** / **M98-08**).
- **Questo turno:** zero edit Kotlin/XML/Gradle; solo testo di pianificazione.

---

## 5. Supabase *(solo read-only per questo planning)*

- **PLANNING corrente:** vietate query/mutazioni live, seed, DDL, RLS changes; si può leggere **solo documentazione** / schema concettuale **fuori** obbligo di esecuzione.
- **EXECUTION futura:** sandbox concordato; tutte le righe dichiarabili sotto prefisso **`TASK098_%`** nel manifest; **collision scan read-only** obbligatorio prima della prima insert/update mirata.

---

## 6. Gap specifico da chiudere

| ID | Gap |
|----|-----|
| **G98-01** | TASK-097 **non** richiede Android in catena; serve prova **minima** che **un altro client** (Android) e iOS convergano su **catalogo + ProductPrice** per `TASK098_*`. |
| **G98-02** | Serve verifica **bidirezionale**: **A2I** (Android→Supabase→iOS) e **I2A** (iOS→Supabase→Android), non solo un verso. |
| **G98-03** | Allineamento **current/previous** purchase/retail tra **Room** (Android), **SwiftData** (iOS) e righe remote, con **effectiveAt** e tolleranza espliciti nella doc evidenze. |
| **G98-04** | Confine netto: niente **TASK-099** (recovery avanzato), **TASK-100** (dataset grande), **TASK-101** (audit sicurezza completo), **TASK-102** (polish UX) dentro TASK-098. |

---

## 7. Scope esplicito *(obiettivo EXECUTION quando autorizzato)*

- Preflight **condiviso**: iOS, Android e Supabase puntano allo **stesso** progetto; **auth/session/owner** coerenti e **redatti** nelle evidenze (**M98-01**).
- **Collision scan** su **`TASK098_*`** (read-only) = zero righe attese prima del seed controllato (**M98-02**); se occupato, strategia suffisso run come TASK-097 (**non** sovrascrivere).
- **Ciclo 1 — Android→Supabase→iOS:** Android crea/aggiorna **prodotto A** + **supplier/category** manifest + **ProductPrice** (purchase/retail current/previous per A); iOS esegue pull/apply (Release) e read-back locale (**M98-03**, **M98-04**).
- **Ciclo 2 — iOS→Supabase→Android:** iOS crea/modifica **prodotto B** + ProductPrice tramite **pending → push aggregato** (stesso stack TASK-091…097); Android pull/read-back verifica B e prezzi (**M98-05**, **M98-06**).
- Verifica **parity** current/previous su **entrambe** le piattaforme (**M98-07**).
- Smoke **owner/RLS** in contesto app normale (**M98-08**); **UX** smoke minimo allineato TASK-097 (**M98-09**).
- **Anti-scope/privacy** finale (**M98-10**).
- Cartella evidenze prevista: **`docs/TASKS/EVIDENCE/TASK-098/`** (creata solo in EXECUTION), con stesso spirito TASK-097.

---

## 8. Out-of-scope esplicito

- **Refactor Android ampio** o riscrittura sync Android.
- **Refactor iOS** sync/Release/ViewModel oltre fix **minimi** se bloccante CA (default: **no** refactor nel perimetro TASK-098).
- **Dataset grande / performance:** **TASK-100**.
- **Conflict/recovery avanzato, merge campo-per-campo:** **TASK-099**.
- **Security / RLS production audit completo:** **TASK-101**.
- **Polish UX finale** copy/accessibility: **TASK-102**.
- **Dati reali** negozio; **claim production-ready globale 100%**.
- **Nuove feature business** (fuori smoke).
- **BackgroundTasks**, **Timer**, **polling**, **Realtime**, **worker** sempre-on.
- **SQL / migration / RLS / backend** nel perimetro salvo eccezione minima documentata e **non** distruttiva (default: **NO**).
- **Cleanup distruttivo** (truncate/wipe fuori da record `TASK098_*` mirati): preferire **lasciare righe come evidenza**; cleanup solo se documentato, sicuro, approvato.
- **Apertura** file task **TASK-099…TASK-102** in questo initiative.
- **Modifiche** `project.pbxproj`, churn **`Localizable.strings`** salvo correzione tecnica post-review strettamente indispensabile (default **NO** durante smoke).

---

## 9. Manifest dati sandbox `TASK098_*` *(pianificazione soltanto — nessun dataset creato in questo turno)*

Oggetti logici **obbligatori** (valori sintetici; possibile suffisso run **`TASK098_*_R<id>`** dopo collision scan in EXECUTION):

| Chiave manifest | Ruolo |
|-----------------|-------|
| `TASK098_SUPPLIER_CROSS_PLATFORM` | Supplier unica sandbox cross-platform |
| `TASK098_CATEGORY_CROSS_PLATFORM` | Categoria unica sandbox |
| `TASK098_PRODUCT_ANDROID_TO_IOS` | Prodotto **A** — scritto prima da **Android** |
| `TASK098_PRODUCT_IOS_TO_ANDROID` | Prodotto **B** — creato/modificato da **iOS** poi letto da Android |
| Barcode **`TASK098_BAR_A2I`** | Barcode sintetico prodotto A (Android → iOS) |
| Barcode **`TASK098_BAR_I2A`** | Barcode sintetico prodotto B (iOS → Android) |
| **ProductPrice A** | **Purchase** e **retail**, ciascuno con riga **previous** e **current** (4 righe price per A alla fine del setup Android, salvo esecuzione che decida cardinalità minima equivalente documentata). |
| **ProductPrice B** | Baseline + modifiche dopo edit iOS (current/previous coerenti con transizione documentata). |
| **sync_events / outbox** | Solo se il flusso Release/Android **già** registra attività — niente nuovo trasporto dedicato TASK-098. |

**Evidenza:** `owner_hash`, `session` / progetto = **solo hash redatti**; **no** JWT, email, service role, connection string.

**Collision scan (EXECUTION):** conteggi read-only su `TASK098_%` per supplier/category/product/barcode/product_prices (o equivalente schema) **prima** di qualsiasi write.

**Cleanup:** preferenza **non distruttiva**; righe `TASK098_*` lasciate come evidenza salvo piano di cleanup mirato approvato.

### 9.1 Valori manifest proposti *(da congelare in Planning Review — non creati ora)*

| Campo | Valore proposto | Note |
|-------|-----------------|------|
| Supplier name | `TASK098_SUPPLIER_CROSS_PLATFORM` | Sintetico |
| Category name | `TASK098_CATEGORY_CROSS_PLATFORM` | Sintetico |
| Product A name | `TASK098_PRODUCT_ANDROID_TO_IOS` | Baseline Android-first |
| Product B name | `TASK098_PRODUCT_IOS_TO_ANDROID` | Baseline/modifica iOS-first |
| Barcode A2I | `TASK098_BAR_A2I` | Univoco manifest |
| Barcode I2A | `TASK098_BAR_I2A` | Univoco manifest |
| Prezzi A | *(vedi* **§9.3** *)* | Decimali ed effectiveAt concreti |
| Prezzi B | *(vedi* **§9.3** *)* | Baseline, edit e effectiveAt concreti |
| Toll confronto | **≤ 0.005** assoluto *(allineato evidenza TASK-097)* | Alternativa solo se review congelà diverso |
| Format timestamp | canonico accordato iOS/Android/DB *(es. `yyyy-MM-dd HH:mm:ss` locale TASK-097)* | Ordinamento deterministico previous < current |

### 9.2 Regole effectiveAt *(solo pianificate)*

- Timestamp **deterministici**, **UTC o formato unico** concordato; **no** dipendenza dal fuso del device per l’ordine logico.
- **previous** cronologicamente prima di **current** per ogni tipo (purchase/retail).
- **No** stesso `effectiveAt` per due righe che competono come current per stesso prodotto+tipo (salvo vincolo UNIQUE remoto che imponga scelta documentata).

### 9.3 Valori ProductPrice/effectiveAt proposti *(da congelare in Planning Review)*

Questi valori sono sintetici e servono solo a rendere la futura Execution ripetibile. Se il runtime Android/iOS richiede un formato diverso, la Execution deve convertire mantenendo ordinamento logico e documentare la conversione.

| Riga | Prezzo | `effectiveAt` proposto | Origine attesa |
|------|--------|------------------------|----------------|
| A purchase previous | `41.11` | `2026-05-10T11:00:00Z` | Android seed/write |
| A purchase current | `42.22` | `2026-05-10T11:05:00Z` | Android seed/write |
| A retail previous | `81.11` | `2026-05-10T11:10:00Z` | Android seed/write |
| A retail current | `84.44` | `2026-05-10T11:15:00Z` | Android seed/write |
| B purchase baseline | `51.11` | `2026-05-10T11:20:00Z` | iOS baseline/local create |
| B purchase current | `55.55` | `2026-05-10T11:30:00Z` | iOS edit/push |
| B retail baseline | `101.11` | `2026-05-10T11:25:00Z` | iOS baseline/local create |
| B retail current | `111.10` | `2026-05-10T11:35:00Z` | iOS edit/push |

**Tolleranza confronto:** default **≤ 0.005** assoluto, allineata a TASK-097, salvo Planning Review congeli una regola più severa coerente con entrambe le piattaforme.

### 9.4 Regole write sandbox / owner-scope *(solo pianificate)*

TASK-098 deve dimostrare runtime cross-platform reale, non aggirarlo con scorciatoie backend:

- preferire flussi app/SDK autenticati con lo stesso owner/sessione o owner coerente verificabile su entrambi i client;
- vietato usare `service_role`, token admin o SQL diretto per far passare il normale smoke Android/iOS;
- eventuale SQL/PostgREST diretto è ammesso solo come setup/read-back controllato, owner-scoped, prefisso `TASK098_*`, senza dati reali e documentato in `manifest.md`;
- read-back remoto deve distinguere dati creati da Android, dati creati da iOS e dati seed/setup;
- nessun `DELETE`, `TRUNCATE`, reset o cleanup distruttivo; cleanup solo su chiavi esatte `TASK098_*` se approvato e documentato;
- se owner/sessione non sono verificabili su entrambe le piattaforme, fermare in `BLOCKED_ENV` invece di forzare PASS.

### 9.5 Regole runtime Android/iOS e no-code-needed *(solo pianificate)*

TASK-098 deve verificare i flussi esistenti, non creare codice preventivo:

- **no-code-needed** e' un esito valido se Android e iOS passano lo smoke con i flussi gia' disponibili;
- eventuali helper/runner per smoke devono restare **test-only/debug-only**, mai produzione, e devono essere documentati nelle evidenze;
- Android Studio/emulatore o device devono essere disponibili in futura Execution, ma l'assenza temporanea di emulatore non giustifica bypass SQL/service-role;
- se serve installare/lanciare Android, usare variante debug/test e non modificare codice Kotlin salvo fix minimo motivato da fallimento reale del MUST;
- se serve aprire l'app iOS, usare Simulator/debug o Release secondo gate, senza modificare `project.pbxproj` salvo motivo tecnico esplicito;
- eventuale `no-refactor-needed` deve essere supportato da read-back Android, read-back iOS e remote read-back, non da sola analisi statica.

### 9.6 Regole identita' / mapping cross-platform *(solo pianificate)*

Per evitare falsi mismatch tra Room, SwiftData e Supabase, la futura Execution deve confrontare entita' usando chiavi logiche stabili, non ID locali:

- **Product identity:** il barcode sintetico `TASK098_BAR_A2I` / `TASK098_BAR_I2A` e' la chiave logica primaria di confronto; `productName` e' solo supporto leggibile nelle evidenze.
- **Remote ID:** se disponibile, usare `remoteID`/id Supabase come conferma secondaria, redatta nelle evidenze; non esporre UUID completi se non necessario.
- **Local ID:** ID Room Android e ID SwiftData/iOS non devono essere confrontati tra piattaforme; possono comparire solo come redatti/hash o conteggi locali.
- **Supplier/category:** confrontare per nome sintetico normalizzato + eventuale remote id redatto; non usare ID locali come prova cross-platform.
- **ProductPrice identity:** confrontare per prodotto logico/barcode + tipo (`PURCHASE`/`RETAIL`) + `effectiveAt`; il prezzo da solo non identifica una riga.
- **Evidence mapping:** `cross-platform-parity.md` deve includere una tabella mapping per A/B con barcode, remote id redatto, presenza su iOS, presenza su Android, current/previous purchase/retail.
- **No fuzzy match:** vietato dichiarare PASS usando solo match parziale su nome prodotto o valori prezzo senza barcode/effectiveAt coerenti.

---

## 10. Micro-slice operativi **S98-A … S98-J** *(future EXECUTION)*

| ID | Slice | Contenuto minimo |
|----|--------|------------------|
| **S98-A** | Preflight ambiente | Stesso progetto Supabase; auth/owner verificabili; evidenze redatte. |
| **S98-B** | Collision scan | `TASK098_*` read-only; eventuale suffisso run. |
| **S98-C** | Seed/write Android lato A | Supplier/category/product A + ProductPrice A (Android→cloud). |
| **S98-D** | iOS pull/apply A | Release pull/apply; read-back SwiftData A + prezzi. |
| **S98-E** | iOS edit/push B | Modifica/prodotto B + ProductPrice via Release confermato; push aggregato. |
| **S98-F** | Android read B | Pull/read Room (o flusso documentato) per B e prezzi. |
| **S98-G** | Parity audit | Confronto current/previous su iOS, Android, remoto; tolleranza applicata. |
| **S98-H** | Evidence pack | `manifest.md`, `scenario-matrix.md`, read-back notes, build summary, anti-scope. |
| **S98-I** | Ledger runtime | Distinguere Android write, iOS pull/apply, iOS push, Android pull/read-back, remote/local read-back e attore di ogni step. |
| **S98-J** | Freeze Planning Review | Congelare manifest, sequenza, evidenze e cutline prima dell’override Execution. |

### 10.1 Sequenza runtime MVP proposta *(per futura Execution)*

La futura Execution deve seguire una sequenza lineare, con stop sicuro a ogni gate:

1. **Preflight iOS/Android/Supabase:** branch, working tree, simulator/emulator disponibili, config iOS/Android, stesso project hash redatto.
2. **Preflight auth/owner:** sessione/owner verificabili su entrambi i client, owner redatto nelle evidenze.
3. **Collision scan `TASK098_*`:** nessuna write se collisioni non gestite.
4. **Android write A:** creare/aggiornare supplier/category/product A + ProductPrice A usando flusso Android normale.
5. **Remote read-back A:** verificare Supabase per record A e ProductPrice A.
6. **iOS pull/apply A:** leggere/applicare A tramite flusso Release iOS esistente.
7. **Local read-back iOS A:** verificare SwiftData/catalogo/ProductPrice current/previous.
8. **iOS create/edit/push B:** creare/modificare B tramite flusso Release iOS, pending/push aggregato dove previsto.
9. **Remote read-back B:** verificare Supabase post-push iOS per catalogo/ProductPrice.
10. **Android pull/read-back B:** leggere B su Android tramite flusso normale e verificare Room/current/previous.
11. **Parity audit:** confrontare remoto, iOS e Android per A/B, purchase/retail, current/previous, tolleranza prezzo.
12. **UX smoke minimo:** verificare che eventuali stati sync osservabili non siano invasivi e non mostrino copy tecnico.
13. **Evidenze + anti-scope:** completare evidence pack e grep finale.

**Stop rule:** se un gate cross-platform fallisce in modo non correggibile localmente, fermare prima di nuove mutazioni, documentare `BLOCKED_ENV` o follow-up onesto e non procedere con scenari dipendenti da dati incerti.

Se EXECUTION risulta troppo ampia: **restringere** a **S98-A–D** + **S98-E–F** essenziali e **S98-G** ridotto al minimo verificabile.

---

## 11. Matrice scenari **M98-01 … M98-10** *(massimo 10 MUST)*

| ID | Scenario | MUST |
|----|----------|------|
| **M98-01** | Preflight cross-platform: iOS, Android e Supabase stesso progetto; auth/sessione/owner verificabili e **redatti** in evidenza | **SÌ** |
| **M98-02** | Collision scan `TASK098_*` su Supabase (read-only) prima della prima write | **SÌ** |
| **M98-03** | Android crea/aggiorna **prodotto A** + **ProductPrice** su Supabase | **SÌ** |
| **M98-04** | iOS pull/apply legge **prodotto A** e ProductPrice **Android→iOS** | **SÌ** |
| **M98-05** | iOS crea/modifica **prodotto B** + ProductPrice tramite flusso Release (pending/push aggregato dove già supportato) | **SÌ** |
| **M98-06** | Android pull/read-back legge **prodotto B** e ProductPrice **iOS→Android** | **SÌ** |
| **M98-07** | Verifica **current/previous** purchase/retail coerenti su **entrambe** le piattaforme e remoto | **SÌ** |
| **M98-08** | Verifica **owner/RLS/write sandbox** senza **service role** / admin token nel percorso smoke **normale** | **SÌ** |
| **M98-09** | UX smoke minimo: nessuna modal automatica invasiva; **una** action principale per mutazione; copy **non tecnico** dove osservabile | **SÌ** |
| **M98-10** | Anti-scope/privacy finale: no dati reali, no segreti, no apertura TASK-099 file, no refactor ampio | **SÌ** |

---

## 12. Criteri di accettazione **CA-T098-01 … CA-T098-17**

- **CA-T098-01** — File task creato e **MASTER-PLAN** allineato al task attivo **TASK-098 ACTIVE / PLANNING** e ultimo completato **TASK-097**.
- **CA-T098-02** — Manifest **`TASK098_*`** completo in planning, **privacy-safe** (nessun segreto nel task file).
- **CA-T098-03** — Scenari **M98-01…10** definiti, bounded, cross-platform minimi, **non più di 10 MUST** (esattamente 10 MUST elencati).
- **CA-T098-04** — Gate **auth/sessione/owner/progetto/collision scan** documentati **prima** di ogni futura write.
- **CA-T098-05** — Planning copre **Android→Supabase→iOS** per **catalogo + ProductPrice**.
- **CA-T098-06** — Planning copre **iOS→Supabase→Android** per **catalogo + ProductPrice**.
- **CA-T098-07** — **ProductPrice** current/previous: **effectiveAt** deterministici e **tolleranza** confronto documentata (≥ coerenza con TASK-097 salvo decisione review esplicita).
- **CA-T098-08** — Nessun **refactor ampio** Android/iOS **richiesto** dal planning (solo voci esplicite out-of-scope).
- **CA-T098-09** — **TASK-099…TASK-102** **non** aperti (nessun file task creati per essi durante INIT TASK-098).
- **CA-T098-10** — **Nessun** claim **production-ready globale** nel planning.
- **CA-T098-11** — PASS cross-platform richiede read-back remoto, read-back locale iOS e read-back locale Android quando applicabile; un solo lato non basta.
- **CA-T098-12** — Ogni scenario **M98-01…10** deve avere `evidence_ref`, risultato esplicito e ledger step/actor privacy-safe in futura Execution.
- **CA-T098-13** — ProductPrice PASS richiede `effectiveAt` deterministici, previous/current ordinati e tolleranza prezzo documentata su iOS, Android e remoto.
- **CA-T098-14** — Se il runtime passa senza patch Swift/Kotlin, `no-code-needed` è un esito valido e preferibile; eventuali fix devono essere minimi e motivati da fallimento reale.
- **CA-T098-15** — Eventuali harness/helper runtime restano test-only/debug-only e non entrano in produzione; se non servono patch Swift/Kotlin, documentare esplicitamente **no-code-needed**.
- **CA-T098-16** — Prima del READY FOR REVIEW, i gate runtime Android/iOS devono indicare ambiente usato, variante build, device/simulator/emulator e se ogni read-back deriva da flusso reale o test harness controllato.
- **CA-T098-17** — PASS parity richiede mapping identita' esplicito: barcode come chiave primaria, remote id redatto come conferma se disponibile, ID locali iOS/Android non confrontati come chiavi cross-platform.

*(CA execution/review futuri aggiungeranno esiti RUNTIME/BUILD con evidenze.)*

---

## 13. Rischi **R98-01 … R98-17**

| ID | Rischio |
|----|---------|
| **R98-01** | iOS e Android **non** puntano allo stesso progetto Supabase. |
| **R98-02** | Sessione/auth/owner **non** coerenti tra piattaforme. |
| **R98-03** | **Collisione** con dati `TASK098_*` preesistenti (run precedenti). |
| **R98-04** | Android write **passa** ma iOS **non** pulla per mapping/schema drift. |
| **R98-05** | iOS push **passa** ma Android **non** legge ProductPrice current/previous correttamente. |
| **R98-06** | **effectiveAt** / timezone / precisione prezzi **divergono** tra Room / SwiftData / Supabase. |
| **R98-07** | Smoke **si allarga** a performance / dataset grande (scope creep → TASK-100). |
| **R98-08** | Uso di **service role** / SQL diretto **falsifica** il runtime reale (**false PASS**). |
| **R98-09** | Evidenze con **dati reali** o **segreti**. |
| **R98-10** | Fix in EXECUTION diventa **refactor** Android/iOS **ampio** (anti-pattern TASK-098). |
| **R98-11** | Android write o iOS push passano solo via scorciatoie setup/SQL, non tramite flusso client reale. |
| **R98-12** | Evidenze non distinguono attore Android/iOS/setup, rendendo il PASS non revisionabile. |
| **R98-13** | Differenze di formato data/prezzo fanno sembrare incoerente ProductPrice pur con dati corretti. |
| **R98-14** | Test Android/emulatore instabile porta a falso BLOCKED; mitigare con log/evidenze e retry ragionevole, non con bypass. |
| **R98-15** | Helper debug/test per smoke finisce per diventare codice produzione non necessario. |
| **R98-16** | PASS dichiarato da analisi statica/no-code senza dimostrare runtime reale sui due client. |
| **R98-17** | Falso mismatch o falso PASS per confronto su ID locali diversi tra Room e SwiftData, o per match solo su nome/prezzo. |

---

## 14. Piano test e verifiche future **T98-01 … T98-20** *(solo pianificato; non eseguito in questo turno)*

| ID | Verifica |
|----|----------|
| **T98-01** | `xcodebuild -list` (iOS) |
| **T98-02** | Build **Debug** iOS |
| **T98-03** | Build **Release** iOS |
| **T98-04** | XCTest regressivi famiglie **TASK-091…097** collegate (sync/Release/ProductPrice/lifecycle/pending) |
| **T98-05** | Android `assembleDebug` (se EXECUTION Android abilitata) |
| **T98-06** | Test mirati Android sync/catalogo/ProductPrice **se necessari** |
| **T98-07** | Smoke runtime **Android→Supabase→iOS** |
| **T98-08** | Smoke runtime **iOS→Supabase→Android** |
| **T98-09** | Supabase read/write sandbox **solo** `TASK098_*` post-preflight |
| **T98-10** | **Remote** read-back (seed + post-push) |
| **T98-11** | **Local** read-back iOS (SwiftData) |
| **T98-12** | **Local** read-back Android (Room) |
| **T98-13** | Parity **ProductPrice** current/previous |
| **T98-14** | Anti-scope grep / **secret+privacy scan** evidenze |
| **T98-15** | Ledger audit: ogni mutazione/read-back ha step, actor, target, result ed `evidence_ref` |
| **T98-16** | Owner/RLS audit: no service role/admin token nel normale smoke; owner/sessione redatti e coerenti |
| **T98-17** | ProductPrice timestamp/precision audit su iOS, Android e remoto |
| **T98-18** | Runtime environment audit: variante build, simulator/emulator/device, app launch e sessione redatti per iOS e Android |
| **T98-19** | No-code-needed / debug-only audit: nessun helper smoke in produzione, nessuna patch Swift/Kotlin preventiva non motivata |
| **T98-20** | Identity mapping audit: barcode/remote id redatto/ProductPrice key (`product+type+effectiveAt`) coerenti tra remoto, iOS e Android; ID locali non usati come chiave cross-platform |

---

## 15. Gate **Go / No-Go** per futura **EXECUTION**

**GO** solo se tutti veri (da rivalutare subito prima di EXECUTION):

1. Planning review congelata: manifest **§9**, **M98**, **CA**, **T98**, slice **S98** approvati o aggiornati in modo tracciato.
2. **Stesso** progetto Supabase e **owner** operativo su **entrambi** i client (verificabile).
3. **Collision scan** `TASK098_*` **pulito** (o suffisso run applicato e ri-scansionato).
4. **Override utente** esplicito per EXECUTION (workflow progetto).
5. **Nessun** obbligo di refactor ampio emergente come prerequisito.
6. **TASK-099…102** restano non promossi ad ACTIVE salvo decisione separata.
7. Sequenza runtime **§10.1** approvata e nessuna scorciatoia setup non tracciata resta necessaria per dichiarare PASS.
8. Regole owner/RLS **§9.4** confermate: no service-role/admin token nel normale smoke, distinzione Android/iOS/setup pronta per le evidenze.
9. Regole runtime/no-code **§9.5** confermate: eventuali helper sono test-only/debug-only e non e' richiesta patch preventiva Swift/Kotlin.

**No-Go:** uno qualsiasi tra mismatch progetto, owner non verificabile, collisione non risolta, ambiente Android/iOS non disponibile per il minimo smoke, necessità di usare service role per “sbloccare” il percorso che dovrebbe essere Android/iOS reale (**R98-08**), richiesta implicita di refactor ampio, o necessità di introdurre helper/runner in produzione per completare lo smoke.

---

## 16. Cutline MVP anti feature-creep

- **Due cicli** massimi definiti: **(1) Android→Supabase→iOS** su **A**; **(2) iOS→Supabase→Android** su **B**.
- **Due prodotti**, **due barcode**, **supplier/category unici** manifest.
- **Niente** stress test N grande, **niente** editor conflitti, **niente** nuovo motore sync.
- **Niente** cambio schema backend nel task; se schema drift blocca, **BLOCKED** documentato o follow-up **fuori** TASK-098.
- Riduzione ammessa: solo **catalogo+prezzi** per A; B con cardinalità prezzi minima ancora sufficiente a provare **current vs previous**.

---

## 17. Formato evidenze privacy-safe *(target `docs/TASKS/EVIDENCE/TASK-098/`)*

Obbligatori in EXECUTION (nomi file come sotto salvo variazione review):

- `manifest.md` — prefisso dataset, suffisso run, ledger passi, hash owner/progetto redatti.
- `scenario-matrix.md` — **M98-01…10** con tipo verifica ed `evidence_ref`.
- `remote-readback-notes.md` — query/read-back cloud senza segreti, distinguendo A Android-first e B iOS-first.
- `local-readback-ios.md` — read-back SwiftData/iOS per A/B e ProductPrice.
- `local-readback-android.md` — read-back Room/Android per A/B e ProductPrice.
- `cross-platform-parity.md` — confronto remoto/iOS/Android per current/previous e tolleranza prezzi; **tabella mapping A/B** come da **§9.6** (barcode, remote id redatto, presenza piattaforme, purchase/retail current/previous).
- `test-build-summary.md` — comandi e risultati build/test iOS/Android.
- `anti-scope-checks.md` — grep/lista divieti; conferma no TASK-099 file, no SQL/backend/migration, no dati reali/segreti.
- Opzionale: `ux-acceptance.md` se UX osservabile rilevante.
- Opzionale: `optional-cleanup-notes.md` solo se cleanup mirato e sicuro viene eseguito.

**Mai:** email, token, JWT, refresh, service role, connection string, URL backend completo, barcode/nome prodotto **reali**.

### 17.1 Ledger operazioni runtime *(solo evidenza, non nuova feature)*

Ogni mutazione o read-back significativo in futura Execution deve avere una riga ledger privacy-safe con:

| Campo | Regola |
|-------|--------|
| `step` | `preflight`, `collision_scan`, `android_write_a`, `remote_readback_a`, `ios_pull_apply_a`, `ios_local_readback_a`, `ios_write_b`, `remote_readback_b`, `android_pull_readback_b`, `parity_audit`, `ux_smoke` |
| `actor` | `android_release_flow`, `ios_release_flow`, `setup`, `test_harness`, `manual_review` |
| `mutation` | `none`, `insert`, `update`, `readback`, `apply_local`, `push_remote` |
| `target` | `supplier`, `category`, `product`, `product_price`, `sync_event`, `ios_local_store`, `android_room` |
| `result` | `PASS`, `FAIL`, `BLOCKED_ENV`, `SKIPPED_NICE`, `PARTIAL_ACCEPTED` |
| `evidence_ref` | percorso evidenza, test name, comando redatto o read-back notes |

Regole:

- una riga `setup` non basta per dichiarare PASS Android→iOS o iOS→Android;
- Android→iOS richiede almeno `android_write_a`, `remote_readback_a`, `ios_pull_apply_a`, `ios_local_readback_a`;
- iOS→Android richiede almeno `ios_write_b`, `remote_readback_b`, `android_pull_readback_b`;
- il ledger non deve contenere token, email, user id in chiaro, barcode reali o nomi prodotto reali.

### 17.2 Definizione sintetica di PASS cross-platform

TASK-098 può essere dichiarato **READY FOR REVIEW** solo se:

- M98-01…10 hanno esito esplicito e `evidence_ref`;
- Android→Supabase→iOS e iOS→Supabase→Android sono entrambi dimostrati con ledger completo;
- ProductPrice current/previous è coerente su remoto, iOS e Android, con **chiavi identità** come da **§9.6** / **CA-T098-17**;
- owner/RLS non sono bypassati nel normale percorso smoke;
- anti-scope/privacy check sono PASS;
- eventuale `no-code-needed` o “no refactor needed” è supportato da evidenze runtime, non da assunzione teorica.

---

## 18. Checklist **Planning Review / freeze**

- [ ] Manifest **§9**, **§9.1**, **§9.3** coerenti con **M98** e **S98**; **§9.2–9.6** allineati.
- [ ] **CA-T098-01…17** coprono obiettivo + anti-scope backlog **099–102**.
- [ ] **R98** mitigati nel testo (preflight, collision, no service role, tolleranza prezzi).
- [ ] **Gate §15** letto e accettato per promozione EXECUTION.
- [ ] §9.3 effectiveAt/prezzi e tolleranza congelati o convertiti in formato runtime equivalente.
- [ ] §9.4 owner/RLS/write sandbox approvato: no service role/admin token per normale smoke.
- [ ] §10.1 sequenza runtime approvata.
- [ ] §17.1 ledger e §17.2 definizione PASS cross-platform approvati.
- [ ] §9.5 runtime/no-code-needed approvato: no patch preventiva, helper solo test/debug e no produzione.
- [ ] §9.6 identita'/mapping cross-platform approvato: barcode chiave primaria, remote id redatto, ID locali non confrontati.
- [ ] **Handoff** sotto compilato; **NON READY FOR EXECUTION** finché review non passa a handoff execution.

---

## 19. Decisione finale di planning *(freeze)*

Il piano TASK-098 è considerato **sufficientemente completo per Planning Review**. Da questo punto in poi non vanno aggiunte nuove aree funzionali: sono ammesse solo correzioni di coerenza, refusi o allineamento puntuale a nomi reali di test/strumenti durante la Planning Review.

### 19.1 Cosa resta da fare in Planning Review

- Congelare valori manifest e ProductPrice/effectiveAt §9.1–9.3 e regole §9.4–9.6 (sandbox, owner, runtime/no-code, identita'/mapping).
- Confermare sequenza runtime §10.1.
- Confermare che **M98-01…10** coprano il MVP cross-platform senza superare la cutline.
- Confermare evidence pack §17, ledger §17.1 e PASS cross-platform §17.2.
- Confermare che eventuale no-code-needed/no-refactor-needed sia un esito valido se supportato da evidenze runtime.
- Confermare che eventuali helper smoke siano test-only/debug-only e che non servano patch preventive Swift/Kotlin.
- Confermare regole identita'/mapping §9.6 per evitare confronti errati tra ID locali Room/SwiftData e remote id Supabase.

### 19.2 Cosa NON va più aggiunto a TASK-098

- Conflict/recovery avanzato: appartiene a **TASK-099**.
- Dataset grande/performance: appartiene a **TASK-100**.
- Audit RLS/security production: appartiene a **TASK-101**.
- Polish UX finale: appartiene a **TASK-102**.
- Nuova logica sync, nuovo coordinator, nuova state machine dati, BackgroundTasks, Timer, polling, Realtime o worker.

### 19.3 Prossima azione corretta


La prossima azione è **Planning Review**, non altra espansione del piano. Dopo Planning Review PASS e override utente esplicito, si potrà avviare EXECUTION TASK-098.

### 19.4 Freeze operativo finale

Il planning TASK-098 non richiede ulteriori integrazioni funzionali prima della **Planning Review**. Da questo punto sono ammesse solo:

- correzioni di refusi;
- allineamento ai nomi reali di test/strumenti;
- chiarimenti puntuali richiesti dalla review;
- aggiornamenti di tracking coerenti con MASTER-PLAN.

Qualunque nuova idea fuori da manifest, sequenza runtime, ledger, PASS cross-platform, runtime/no-code gate o identity mapping **§9.6** deve essere spostata a follow-up, non aggiunta a TASK-098.

---

## Planning (Claude)

### Analisi

TASK-097 ha ridotto il rischio su **iOS→Supabase→iOS**; il rischio residuo principale è **interpretazione incrociata** tra client eterogenei (tipi numerici, timezone, selezione current/previous, mapping colonne). TASK-098 deve restare **smoke**, non parità funzionale totale Android=iOS.

### Approccio proposto

1. Congelare manifest **§9.1–9.3**, regole **§9.4–9.6**, matrice **M98**, criteri **CA-T098**, test **T98**, slice **S98**, sequenza **§10.1** e ledger **§17.1** in Planning Review.
2. In EXECUTION: preflight parallelo due device/emulatori; collision scan; esecuzione **S98** in ordine; evidenze **§17**.
3. Se **R98-04/R98-05/R98-17**: stop documentato, **non** espandere scope — escalation TASK-099 o fix minimo iOS/Android **solo** se dentro CA.

### File coinvolti *(futura EXECUTION — non modificati in questo turno)*

- iOS: servizi Release/sync già usati in TASK-097 pathway; test opzionali sotto `iOSMerchandiseControlTests/` se necessario e gated.
- Android: moduli sync/catalogo esistenti *(solo riferimento; nessuna modifica in INIT)*.
- Docs: `docs/TASKS/EVIDENCE/TASK-098/*` *(creazione in EXECUTION)*.

### Rischi identificati

Vedi **§13** (**R98-01…17**).

### Criteri di accettazione (planning)

Vedi **§12** (**CA-T098-01…17**).

### Handoff *(PLANNING freeze — questo turno)*

- **READY FOR PLANNING REVIEW:** **SÌ** — piano sufficientemente completo per revisione/chiusura planning (**§19**).
- **NON READY FOR EXECUTION:** **SÌ** — nessuna EXECUTION autorizzata da questo solo documento.
- **TASK-098 NON DONE:** **SÌ**.
- **Matrice aggiornata:** **M98-01…10** proposta e bounded; da congelare in Planning Review.
- **Manifest/effectiveAt:** §9.1…9.6 definiti; nessun dato creato ora.
- **Sequenza runtime proposta:** §10.1 aggiunta; stop rule esplicita.
- **Ledger/PASS cross-platform:** §17.1/§17.2 definiti per distinguere Android/iOS/setup e impedire falsi PASS.
- **Runtime/no-code gate:** §9.5 definisce no-code-needed, helper test/debug-only e divieto di patch preventive non motivate.
- **Identity mapping gate:** §9.6 definisce barcode/remote id/ProductPrice key come base del confronto, vietando PASS basati su ID locali o fuzzy match.
- **Freeze operativo finale:** §19.4 chiarisce che non servono ulteriori espansioni funzionali prima della Planning Review.
- **Prossima fase:** eseguire **PLANNING REVIEW** → congelare eventuali correzioni puntuali → preparare **handoff EXECUTION** verso **Codex** solo con override utente esplicito.
- **Prossimo agente (post-review planning):** **Claude / Planner** (chiusura planning) poi **Codex / Executor** solo con handoff esplicito.
- **Azione consigliata:** eseguire **§18 Checklist**; congelare valori **§9.1–9.3**, regole **§9.4–9.6** e sequenza **§10.1**; poi promuovere EXECUTION solo se **§15 GO**.

---

## Execution (Codex)

### Obiettivo compreso

Eseguire smoke runtime minimo cross-platform **Android → Supabase → iOS** e **iOS → Supabase → Android** usando solo dati sintetici `TASK098_*`, con catalogo + ProductPrice current/previous, owner/RLS reale, evidenze privacy-safe e anti-scope PASS. Non dichiarare DONE e non aprire TASK-099.

### Planning Review interna

Completata prima dell'execution. Validati: manifest **§9.1**, ProductPrice/effectiveAt **§9.3**, owner/RLS/write sandbox **§9.4**, runtime/no-code **§9.5**, identity mapping **§9.6**, sequenza runtime **§10.1**, **M98-01…10**, evidence pack **§17**, ledger **§17.1**, definizione PASS cross-platform **§17.2** e freeze **§19.4**. Nessun refuso/coerenza markdown bloccante rilevato.

### File controllati

- iOS config/auth/client/owner, Release/manual sync, pending/push/ProductPrice services e test TASK-091…097 collegati.
- Android repo `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView`: Supabase config/auth manager, repository, catalog/ProductPrice remote data sources, Room/ProductPrice summary, flussi push/pull.
- Evidence pack TASK-097 e task TASK-096…093 prima di avviare mutazioni.

### Modifiche fatte

- Fix mirato produzione Android in `SupabaseAuthManager.kt`: il pulsante Google usa l'opzione Google Sign-In esplicita con fallback alla precedente Google ID option. Questo risolveva `NoCredentialException`/assenza account picker sul simulatore Google.
- Harness test-only iOS `Task098CrossPlatformSmokeTests.swift` per preflight, pull/apply A, push B, read-back B e ProductPrice parity.
- Harness test-only Android `Task098CrossPlatformSmokeTest.kt` con datasource scoped `TASK098_*` per evitare scan completo dello storico account mantenendo client app/RLS autenticati.
- Evidence pack aggiornato in `docs/TASKS/EVIDENCE/TASK-098/`.
- Nessun SQL/backend/migration/RLS, nessun service role/admin token, nessun cleanup distruttivo, nessun TASK-099.

### Esito runtime

Runtime PASS completo:

- Android → Supabase → iOS: PASS.
- iOS → Supabase → Android: PASS.
- ProductPrice current/previous: PASS remoto + iOS + Android con tolleranza `<= 0.005`.
- project_hash: `42a5d0119a30`.
- owner_hash canonico: `ad3d747e936c`.

### Matrice M98

| ID | Esito |
|----|-------|
| M98-01 | PASS — iOS/Android/Supabase stesso project hash; owner hash canonico verificato e redatto. |
| M98-02 | PASS — collision scan read-only `TASK098_*` prima della prima write. |
| M98-03 | PASS — Android write/read-back A con ProductPrice A. |
| M98-04 | PASS — iOS pull/apply A e local read-back SwiftData. |
| M98-05 | PASS — iOS write/push B tramite Release services e pending/ProductPrice aggregato. |
| M98-06 | PASS — Android pull/read-back B in Room con current/previous. |
| M98-07 | PASS — ProductPrice current/previous parity remoto+iOS+Android. |
| M98-08 | PASS — owner/RLS/write sandbox senza bypass. |
| M98-09 | PASS — UX smoke minimo non invasivo; Google picker ripristinato. |
| M98-10 | PASS — anti-scope/privacy finale. |

### Check eseguiti

- ✅ ESEGUITO — `git status --short` iniziale iOS/Android.
- ✅ ESEGUITO — `git diff --check` iOS e Android: PASS.
- ✅ ESEGUITO — `xcodebuild -list -project iOSMerchandiseControl.xcodeproj`: PASS.
- ✅ ESEGUITO — build Debug iOS simulator: PASS tramite `xcodebuild test`.
- ✅ ESEGUITO — build Release iOS simulator: PASS.
- ✅ ESEGUITO — iOS TASK-098 selected live tests: PASS (`test02`, `test03`, `test04`; `test01` pre-write PASS iniziale).
- ✅ ESEGUITO — Android `:app:assembleDebug`: PASS.
- ✅ ESEGUITO — Android `:app:assembleDebugAndroidTest`: PASS.
- ✅ ESEGUITO — Android instrumentation TASK-098: PASS (`test01`, `test02`, `test03`; `test02` idempotent rerun PASS).
- ✅ ESEGUITO — Supabase read/write sandbox solo `TASK098_*`: PASS.
- ✅ ESEGUITO — remote/local read-back A/B e parity ProductPrice/timestamp/precision/identity: PASS.
- ✅ ESEGUITO — owner/RLS audit: PASS, nessun service role/admin path.
- ✅ ESEGUITO — UX smoke: PASS.
- ✅ ESEGUITO — anti-scope/privacy/no SQL/backend/migration diff: PASS.
- ⚠️ NON ESEGUIBILE — full XCTest iOS/Android come runner unico post-smoke: i live smoke TASK-098 sono harness selezionati e mutativi; produzione iOS non modificata.

### Rischi rimasti

- I test live TASK-098 sono harness runtime selezionati, non suite regressiva generica.
- I record `TASK098_*` restano in Supabase come evidenza; nessun cleanup eseguito.

### Handoff post-execution

- **TASK-098:** **ACTIVE / REVIEW**.
- **Review state:** **READY FOR REVIEW**.
- **Completion state:** **TASK-098 NON DONE**.
- **Responsabile attuale:** **Claude / Reviewer**.
- **TASK-099…TASK-102:** TODO / Planning — non aperti.
- **Evidenze:** `docs/TASKS/EVIDENCE/TASK-098/`.

---

## Review (Claude)

### Override operativo

Review eseguita da **Codex / Reviewer+Fixer** su richiesta esplicita dell'utente. Il workflow standard prevedeva reviewer Claude; l'override e' tracciato qui e nel MASTER-PLAN.

### Esito

**REVIEW PASS** — TASK-098 e' corretto, completo rispetto al plan, privacy-safe, rappresentativo del runtime reale **Android → Supabase → iOS** e **iOS → Supabase → Android**, senza scope creep e senza helper finiti in produzione. La review chiude TASK-098 come **DONE / Chiusura — REVIEW PASS**.

### Fix review applicati

- `scenario-matrix.md`: aggiunta struttura esplicita `Type`, `Result`, `evidence_ref` per M98-01…M98-10; nessuna riga TBD; ogni PASS rimanda a manifest/read-back/test pertinenti.
- `Task098CrossPlatformSmokeTests.swift`: aggiunto gate live opt-in (`TASK098_LIVE_SMOKE`, `SIMCTL_CHILD_TASK098_LIVE_SMOKE` o `/tmp/TASK098_LIVE_SMOKE`), collision scan idempotente dopo evidenze, write/read-back B idempotente, read-back remoto iOS scoped su owner + fixture `TASK098_*`.
- `Task098CrossPlatformSmokeTest.kt`: aggiunto gate instrumentation `task098LiveSmoke=true` e collision scan idempotente dopo evidenze.
- Evidence pack aggiornato con review rerun, anti-scope/privacy scan finali e stato finale.

### Google Sign-In Android

Fix approvato come minimo e corretto: `SupabaseAuthManager.kt` usa `GetSignInWithGoogleOption` per ripristinare l'account picker e mantiene fallback a `GetGoogleIdOption` in caso di `NoCredentialException`. Non introduce segreti, log sensibili, service role, regressioni intenzionali o workaround TASK-098-only.

### No-code-needed / no-refactor-needed

- iOS produzione/sync core: **no-code-needed / no-refactor-needed** confermato; modificato solo harness XCTest test-only.
- Sync core Android/iOS/Supabase: **no-refactor-needed** confermato; la sola patch produzione e' il fix auth Android per bug reale emerso dallo smoke.
- SQL/backend/migration/RLS: **no-code-needed** confermato; nessun file modificato.

### Check rieseguiti in review

| Check | Stato | Evidenza |
|-------|-------|----------|
| iOS `git status --short` | ✅ ESEGUITO | Solo modifiche TASK-098 attese: tracking/evidence/test. |
| Android `git status --short` | ✅ ESEGUITO | Solo auth fix Android e androidTest TASK-098 attesi. |
| iOS `git diff --check` | ✅ ESEGUITO | PASS. |
| Android `git diff --check` | ✅ ESEGUITO | PASS. |
| `xcodebuild -list` | ✅ ESEGUITO | PASS, scheme `iOSMerchandiseControl`. |
| Build Debug iOS / harness gated | ✅ ESEGUITO | `xcodebuild test` TASK-098 selezionato senza opt-in: 4 skipped / 0 failures, `** TEST SUCCEEDED **`. |
| Build Release iOS simulator | ✅ ESEGUITO | `xcodebuild build -configuration Release`: `** BUILD SUCCEEDED **`. |
| iOS TASK-098 live selected read-back | ✅ ESEGUITO | `test04RemoteReadBackB` con sentinel `/tmp/TASK098_LIVE_SMOKE`: PASS; senza sentinel: skipped/PASS. |
| Android `:app:assembleDebug` | ✅ ESEGUITO | PASS con Android Studio JBR; primo tentativo senza Java locale non eseguibile. |
| Android `:app:assembleDebugAndroidTest` | ✅ ESEGUITO | PASS con Android Studio JBR. |
| Android instrumentation TASK-098 targeted | ✅ ESEGUITO | `test03AndroidPullReadBackB`: 1 test, 0 failures/errors/skipped. |
| Secret/privacy scan evidence + harness | ✅ ESEGUITO | PASS; nessun token/JWT/email/user id/service role/admin secret. |
| Grep anti-scope | ✅ ESEGUITO | PASS; match solo in testo anti-scope/tracking. |
| No SQL/backend/migration diff | ✅ ESEGUITO | PASS. |
| Regressioni iOS TASK-091…097 complete | ⚠️ NON ESEGUIBILE | Non necessarie/ragionevoli in review: produzione iOS non modificata; harness TASK-098 e build Release/Debug coprono il perimetro. |
| Full XCTest / Android full suite | ⚠️ NON ESEGUIBILE | Non rieseguite perche' i live smoke sono selettivi e mutativi; i MUST sono coperti da build e targeted live/read-back. |

### Matrice M98 finale

| ID | Esito finale |
|----|--------------|
| M98-01 | PASS — preflight cross-platform stesso project hash e owner redatto. |
| M98-02 | PASS — collision scan read-only prima della prima write, post-evidence idempotente. |
| M98-03 | PASS — Android write A + ProductPrice A tramite client autenticato. |
| M98-04 | PASS — iOS pull/apply A e read-back SwiftData. |
| M98-05 | PASS — iOS create/edit/push B via Release/pending/push aggregato. |
| M98-06 | PASS — Android pull/read-back B in Room. |
| M98-07 | PASS — ProductPrice current/previous parity remoto+iOS+Android. |
| M98-08 | PASS — owner/RLS/write sandbox senza service role/admin/SQL. |
| M98-09 | PASS — UX smoke minimo, Google picker ripristinato, nessuna UX invasiva. |
| M98-10 | PASS — anti-scope/privacy, no TASK-099, no dati reali/segreti. |

### Conferme review

- **Android → Supabase → iOS:** confermato da Android write A, remote read-back A, iOS pull/apply A e local read-back iOS A.
- **iOS → Supabase → Android:** confermato da iOS write/push B, remote read-back B e Android pull/read-back B; review ha rieseguito i read-back mirati.
- **ProductPrice/effectiveAt/tolleranza:** A purchase `41.11/42.22`, A retail `81.11/84.44`, B purchase `51.11/55.55`, B retail `101.11/111.10`; `effectiveAt` ordinati previous < current; tolleranza documentata `<= 0.005`.
- **Identity mapping:** barcode sintetico come chiave primaria, remote id redatto/hash come conferma, ProductPrice key `product/barcode + type + effectiveAt`; ID Room/SwiftData non usati cross-platform; nessun fuzzy match nome/prezzo.
- **Owner/RLS/privacy:** owner_hash e project_hash redatti, nessun account/email/user id in chiaro, nessun JWT/token/service_role/admin, nessun bypass RLS, seed/setup/android_release_flow/ios_release_flow distinti nel ledger.
- **Anti-scope:** nessun TASK-099 aperto, nessun SQL/backend/migration, nessun BackgroundTasks/Timer/polling/Realtime/worker, nessun redesign o refactor ampio.

### Rischi residui

- I record `TASK098_*` restano nel sandbox come evidenza, come documentato; nessun cleanup eseguito.
- TASK-098 dimostra smoke cross-platform minimo, non claim production-ready globale 100%.

---

## Fix (Codex)

Nessuna fase FIX separata aperta. I fix applicati durante la review sono mirati, nel perimetro e documentati nella sezione **Review**.

---

## Decisioni

| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|-------|
| 1 | Prefisso dataset dedicato **`TASK098_*`** distinto da TASK-097 | Riutilizzo `TASK097_*` | Evita confusione evidenze e collisioni con smoke precedente | attiva |
| 2 | Massimo **10** scenari MUST (**M98-01…10**) | Matrice più ampia | Anti scope-creep; allinea richiesta utente | attiva |
| 3 | Tolleranza prezzi default **≤ 0.005** come TASK-097 | Tolleranza più ampia senza review | Continuità metrologia smoke | attiva finché review non congela altro |

---

## Chiusura / stato *(REVIEW PASS — DONE)*

- **TASK-098:** **DONE / Chiusura — REVIEW PASS**; **Planning Review PASS**; **EXECUTION runtime cross-platform PASS**; **REVIEW PASS**.
- **TASK-099…TASK-102:** **TODO / Planning** — **nessun** file task creato in questo turno.
- **Ultimo completato progetto:** **TASK-098 DONE / Chiusura — REVIEW PASS**.

## Registro turno — solo markdown *(2026-05-10)*

- Planning iniziale TASK-098 creato: scope cross-platform minimo Android↔Supabase↔iOS, manifest `TASK098_*`, micro-slice S98-A…H, matrice M98-01…10, CA-T098-01…10, rischi R98-01…10, test T98-01…14, gate Go/No-Go, cutline MVP e formato evidenze.
- Integrazione planning review: aggiunti ProductPrice/effectiveAt concreti **§9.3**, regole write owner/RLS **§9.4**, sequenza runtime **§10.1**, micro-slice **S98-I/J**, acceptance criteria **CA-T098-11…14**, rischi **R98-11…14**, test **T98-15…17**, evidence pack iOS/Android/parity, ledger **§17.1**, definizione PASS cross-platform **§17.2**, checklist freeze e decisione finale di planning **§19**. Stato invariato: **ACTIVE / PLANNING**, **READY FOR PLANNING REVIEW**, **NON READY FOR EXECUTION**, **TASK-098 NON DONE**.
- Rifinitura runtime/no-code: aggiunta sezione **§9.5** per runtime gate Android/iOS, no-code-needed, helper test/debug-only e divieto di patch preventive; aggiunti **CA-T098-15…16**, **R98-15…16**, **T98-18…19**, GO/NO-GO aggiornati, checklist e handoff. Nessuna execution, nessun codice, nessun Supabase live write, nessun TASK-099.
- Rifinitura identity mapping: aggiunta sezione **§9.6** per confronto cross-platform basato su barcode, remote id redatto e ProductPrice key (`product+type+effectiveAt`), evitando ID locali Room/SwiftData o fuzzy match; aggiunti **CA-T098-17**, **R98-17**, **T98-20**, checklist e handoff. Nessuna execution, nessun codice, nessun Supabase live write, nessun TASK-099.
- Freeze operativo finale: aggiunta sezione **§19.4** per fermare ulteriori espansioni funzionali prima della Planning Review e corretto handoff da “pianificare Planning Review” a “eseguire Planning Review”. Stato invariato: **ACTIVE / PLANNING**, **READY FOR PLANNING REVIEW**, **NON READY FOR EXECUTION**, **TASK-098 NON DONE**, **TASK-099…TASK-102 non aperti**.
- Planning Review interna Codex completata: validati manifest **§9.1**, ProductPrice/effectiveAt **§9.3**, owner/RLS/write sandbox **§9.4**, runtime/no-code **§9.5**, identity mapping **§9.6**, sequenza runtime **§10.1**, matrice **M98-01…10**, evidence pack **§17**, ledger **§17.1**, definizione PASS **§17.2** e freeze **§19.4**. Nessun refuso/coerenza markdown bloccante rilevato. Su override utente TASK-098 passa a **ACTIVE / EXECUTION**, responsabile **Codex / Executor**. TASK-098 **NON DONE**; TASK-099…TASK-102 non aperti.
- Execution TASK-098 completata dopo ripresa auth Android: fix mirato Google Sign-In Android per ripristinare account picker; smoke **Android → Supabase → iOS** PASS; smoke **iOS → Supabase → Android** PASS; ProductPrice current/previous parity PASS; owner/project redatti; nessun service_role/admin/SQL/backend/migration/session-transfer; nessun cleanup; evidence pack aggiornato in `docs/TASKS/EVIDENCE/TASK-098/`. TASK-098 **ACTIVE / REVIEW**, responsabile **Claude / Reviewer**, **READY FOR REVIEW**, **TASK-098 NON DONE**.
- Review finale TASK-098 completata da Codex su override utente: fix mirati a evidence matrix, guard/idempotenza harness live iOS/Android e read-back iOS scoped; Google Sign-In Android approvato; build/test mirati e privacy/anti-scope PASS; no SQL/backend/migration, no service_role/admin, no TASK-099. TASK-098 **DONE / Chiusura — REVIEW PASS**; progetto da riportare **IDLE**; ultimo completato **TASK-098**.

**Stato finale obbligatorio:**

- TASK-098 è **DONE / Chiusura — REVIEW PASS**
- **Planning Review PASS**
- **REVIEW PASS**
- **TASK-098 DONE**
- **TASK-099…TASK-102** non aperti
- Nessun TASK-099
