# TASK-103 — Final real-device cross-platform acceptance iOS ↔ Supabase ↔ Android

## 1. Titolo e stato

| Campo | Valore |
|-------|--------|
| **Task ID** | **TASK-103** |
| **Titolo** | **Final real-device cross-platform acceptance iOS ↔ Supabase ↔ Android** |
| **File task** | `docs/TASKS/TASK-103-final-real-device-cross-platform-acceptance-ios-supabase-android.md` |
| **Stato task** | **DONE** |
| **Fase attuale** | **Chiusura — REVIEW PASS FINAL** |
| **Responsabile attuale** | **NESSUNO / Chiuso** |
| **Data creazione** | 2026-05-12 |
| **Ultimo aggiornamento** | 2026-05-12 19:05 -0400 — **TASK-103 chiuso DONE / Chiusura — REVIEW PASS FINAL** su override review utente. Review completa su tracking, evidence pack, ledger CA-103-01…18, manifest/run_id, harness iOS/Android, privacy/security, cleanup scoped e build/test realistici. Fix review minimi: hardening collision scan/export/pending-ack iOS, run prefix esplicito iOS/Android, redazione evidence project ref/path personali. Verdict finale in `12-final-verdict.md`: **Supabase iOS cross-platform acceptance 100% PASS**. **Progetto IDLE**. **Ultimo completato TASK-103**. **TASK-104 non aperto**. |
| **Ultimo agente** | **CODEX** |

**Planning Review:** **PASS per override esplicito utente** — piano definitivo approvato per EXECUTION controllata.

**Handoff turno corrente:** **CHIUSO — REVIEW PASS FINAL**.

**Nota execution:** l’override utente abilita build/runtime/write Supabase scoped e patch minime iOS/Android solo se necessarie per P0/P1 secondo §17. Vietati restano dati reali, service_role client, cleanup globale, truncate/drop/reset, modifiche schema/RLS/grant/migration non autorizzate e apertura automatica TASK-104. Nessun claim **100% PASS** è ammesso nel tracking intermedio: il verdict può comparire solo in `12-final-verdict.md` completo e coerente con §9.

---

## 2. Dipendenze e posizionamento roadmap

| Riferimento | Ruolo |
|-------------|--------|
| **TASK-091…TASK-096** | Sync semi-automatica intelligente iOS — baseline funzionale e acceptance composita Release. |
| **TASK-097** | Runtime sandbox smoke iOS ↔ Supabase (`TASK097_*`), evidenze privacy-safe. |
| **TASK-098** | Smoke cross-platform Android ↔ Supabase ↔ iOS (`TASK098_*`), ProductPrice current/previous parity documentata. |
| **TASK-099** | Conflict/recovery hardening iOS — precedence auth > permission/RLS > stale; ProductPrice fail-closed/idempotenza con read-back esatto. |
| **TASK-100** | Large dataset / physical device / live Supabase sintetico — **non** sostituisce il collaudo finale **cross-platform reale** richiesto qui. |
| **TASK-101** | Privacy/RLS/security audit — vincoli least-privilege, no `service_role` client, evidenze redatte. |
| **TASK-102** | Release polish UX/UI — **DONE / PASS WITH NOTES**; residui non bloccanti: camera hardware-only, sync live reale non interagito nell’ultimo pass, VoiceOver gestuale completo non eseguito. **TASK-103** deve chiudere il gap **accettazione finale reale** se possibile, senza dichiarare "100%" se un P0 fallisce. |

**Repository / fonti operative (read-only in PLANNING):**

| Repo | Path |
|------|------|
| **iOS (target principale)** | `/Users/minxiang/Desktop/iOSMerchandiseControl` |
| **Android (runtime riferimento)** | `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView` |
| **Supabase (schema/migration locale)** | `/Users/minxiang/Desktop/MerchandiseControlSupabase` |

---

## 3. Scopo

Collaudo finale **end-to-end su dispositivi fisici** (iPhone + Android), **stesso progetto Supabase** e **account/auth controllato**, con dataset **sintetico** prefissato **`TASK103_REAL_*`** (con sottoprefisso run-specific §6), per decidere se dichiarare **"Supabase iOS cross-platform acceptance 100% PASS"** oppure **PARTIAL** / **BLOCKED** con follow-up mirati. Il target di validazione primario è **iOS**; Android è **runtime di parità** e riferimento funzionale.

**Principio operativo:** TASK-103 **non** deve dimostrare che «qualche sync funziona», ma che i **flussi critici** sono **ripetibili**, **osservabili**, **isolati** e **coerenti tra piattaforme**. Il **100%** è un **verdetto finale**, non un obiettivo dichiarabile in anticipo.

**Ambito del “100%”:** il verdict **100% PASS** riguarda l’**accettazione Supabase iOS cross-platform** nel perimetro P0 di questo task. Non equivale automaticamente a “app intera perfetta” o “production-ready globale senza note”: eventuali P1 non bloccanti (VoiceOver completo, scanner camera reale in condizioni edge, polish visuale avanzato) restano tracciabili senza inquinare il giudizio P0.

**Decisione UX adottata:** per TASK-103 la migliore UX non è aggiungere automazioni aggressive, ma rendere la sync **trasparente, guidata e reversibile**: l’app deve mostrare cosa controlla, cosa ha trovato, cosa verrà applicato/inviato e come recuperare in caso di blocco. Questo mantiene coerenza iOS-native e riduce il rischio di perdita dati cross-platform.

**Policy completion-first:** l’obiettivo operativo di TASK-103 è arrivare a **100% PASS P0** correggendo in modo controllato eventuali problemi **P0** emersi durante il collaudo, invece di accettare subito **PARTIAL**. **PARTIAL** resta consentito solo se il problema è **esterno / non correggibile in sicurezza** nel task, per esempio auth provider non disponibile, device non utilizzabile, policy backend che richiede decisione separata, o requisito che implicherebbe schema/RLS/grant/migration. Se il problema è un **bug client**, una **UX bloccante** o una **lacuna di evidenza correggibile**, EXECUTION deve usare la **FIX lane controllata** §17 e poi **rieseguire i CA impattati** prima del verdict. Il verdict 100% resta finale e solo post-run; completion-first è la disciplina operativa per non chiudere PARTIAL quando il gap è ancora correggibile.

**Separazione P0/P1:** il piano deve massimizzare il **100% P0** senza trasformare TASK-103 in un collaudo infinito. I controlli **P1** (accessibilità estesa, scanner camera reale in condizioni edge, micro-performance osservazionale, screenshot UX completi) vanno pianificati e, dove possibile, osservati; però non devono impedire il **100% P0** se non incidono su sync, dati, sicurezza o capacità reale dell’utente di completare il flusso.

---

## 4. Contesto

- Dopo **TASK-102 DONE**, il progetto iOS era **IDLE** con note residue su hardware camera, sync cloud live non esercitata nell’ultimo manuale Simulator, e VoiceOver gestuale non completo.
- TASK-097…101 hanno coperto sandbox, smoke cross-platform controllato, hardening conflitti, performance grande dataset e sicurezza — ma **non** costituiscono da soli la dichiarazione finale **100%** cross-platform su **due client mobili reali** con lo stesso backend condiviso nel modo richiesto da questo task.

---

## 5. Non incluso (anti-scope)

- Nessuna **nuova feature** prodotti durante TASK-103.
- Nessun **refactor massivo** iOS/Android.
- Nessuna **sync background silenziosa**, **Timer** nuovi obbligatori, **BGTask**, **Realtime subscription**, **polling aggressivo** se non già presenti e necessari al perimetro documentato — il task è **accettazione**, non redesign architetturale.
- Nessun **truncate / drop / reset globale** del database.
- Nessuna modifica **schema / RLS / grant / migration** salvo **blocker** documentato come **follow-up separato** esplicito (non improvisato in execution).
- Nessun **`service_role`** o admin client nei binari/evidenze client.
- Nessun **dato reale del negozio** come fixture.
- Nessuna dichiarazione **production-ready globale** oltre la formula controllata §9 per **integrazione Supabase iOS cross-platform** nel perimetro di questo task.
- Nessuna **ottimizzazione UX invasiva** durante acceptance (TASK-103 non è redesign).
- **Micro-fix** UI/UX ammessi **solo** se **bloccano** o **indeboliscono** un criterio **P0/P1** documentato (vedi §14).
- Se emerge una **mancanza architetturale**, non espandere TASK-103: aprire **follow-up separato** tracciato.
- Nessun tentativo di “far passare” il 100% con workaround manuali non rappresentativi: se un flusso richiede kill app, reinstall, DB reset, SQL ad hoc o refresh fuori UX normale, va classificato come problema o follow-up.
- Nessun uso di screenshot/log come prova unica per dati remoti: per i P0 di sync serve sempre almeno una conferma **read-back scoped** o stato locale/remoto equivalente e rintracciabile.
- Nessuna modifica ai criteri P0 durante EXECUTION per “adattarsi” al risultato: se un criterio risulta troppo severo, tornare in PLANNING/FIX del piano, non degradarlo silenziosamente in runtime.
- Vietato chiudere **PARTIAL** per un **bug client correggibile** con patch minima e test mirato: usare prima la **FIX lane controllata** §17 e rerun CA.
- Vietato usare **BLOCKED** senza aver eseguito almeno una **diagnosi riproducibile** e una **proposta di sblocco sicura**, salvo **indisponibilità fisica** di device / account / backend (evidenza documentata).

---

## 6. Manifest dataset sintetico

**Prefisso base:** `TASK103_REAL_`.

**Sottoprefisso run-specific (obbligatorio):** `TASK103_REAL_R<timestamp>_` — es. `TASK103_REAL_R1737123456_` *(timestamp univoco scelto all’inizio run e ripreso in `03-dataset-manifest.md`)*. Tutti i barcode/nomi/logical key della run devono restare sotto questo prefisso per collision scan e cleanup scoped.

**Prefisso effettivo completo:** `TASK103_REAL_R<timestamp>_…` (nel testo seguenti, «prefisso run» indica questa combinazione).

**Regole:**

- Tutti i record creati/modificati nel corso del collaudo devono essere **etichettabili** tramite prefisso run per **read-back scoped** e cleanup documentato.
- **Collision scan** obbligatorio prima della prima write sul prefisso run (conteggio righe esistenti ≠ 0 → STOP o strategia documentata in `03-dataset-manifest.md`).
- **Nessun cleanup globale:** solo operazioni **scoped** sul prefisso run, tramite policy/client/admin **controllato** e motivato in evidenza §11 (`11-cleanup.md`).
- **Prima di ogni write:** registrare in manifest **timezone / offset** dei device iOS e Android e la **strategia `effectiveAt` deterministica** (es. UTC canonico + istanze manifest-esplicito per purchase/retail current/previous) così ProductPrice non dipende dall’ambiguità dell’orologio locale.
- **Tre set logici di dati** (distinti per entità/prodotto — §S103-B): **SMOKE** (flussi bidirezionali minimi), **MEDIUM** (import/export + push aggregato), **CONFLICT** (stale/conflict). Non riutilizzare lo stesso prodotto/barcode per tutti i test.

**Manifest per ogni entità** *(righe in `03-dataset-manifest.md` o tabella allegata):*

| Campo manifest | Contenuto |
|----------------|-----------|
| `entity_type` | supplier \| category \| product \| product_price \| … |
| `logical_key` | Chiave stabile privacy-safe (es. barcode sintetico) |
| `barcode` / `name` | Valori sintetici prefissati |
| `created_by_platform` | ios \| android \| import_sheet |
| `expected_remote_table` | Tabella Supabase attesa (solo naming da schema già noto — verificare da repo Supabase in EXECUTION read-only) |
| `expected_owner_hash` | Hash owner redatto (mai UUID raw in evidenza) |
| `expected_current_purchase` / `expected_previous_purchase` | Valori attesi |
| `expected_current_retail` / `expected_previous_retail` | Valori attesi |
| `cleanup_status` | pending \| done \| waived_documented |

**Canary records:** per ogni set (**SMOKE**, **MEDIUM**, **CONFLICT**) pianificare almeno un record “canary” facile da riconoscere nel manifest e nelle UI, ad esempio `..._CANARY_IOS_01` e `..._CANARY_ANDROID_01`. I canary servono a ridurre ambiguità durante screenshot, read-back e verifica manuale su device.

---


## 7. Micro-slice pianificate (S103-A … S103-K)

### S103-A — Preflight dispositivi reali

Pianificare verifica:

- **iPhone** rilevato da toolchain Xcode (`xcodebuild -showdestinations` / Devices organiser — comando esatto lasciato a EXECUTION con evidenza redatta in `01-devices.md`).
- **Android** rilevato da `adb devices` (solo device fisico `device`, non solo emulator — salvo override motivato **PARTIAL**).
- Entrambe le app **installabili** e **apribili** (scheme/configuration annotati).
- **Build manifest:** registrare **commit SHA corto**, **branch**, **scheme / build configuration**, **bundle id** (iOS) / **application id** (Android), **versione/build** installata su ogni device — confrontabile con evidenza screenshot o output comando redatto.
- **Baseline locale pre-write:** prima di **ogni** serie di write sul prefisso run, registrare **baseline** iOS e Android dei record `TASK103_REAL_*` già presenti (anche zero righe) così ogni delta è spiegabile.
- **Log:** nessun token JWT grezzo, email reale, UUID utente raw, barcode negozio reale, URL con chiavi — policy redazione in `00-summary.md` / scan §S103-J.
- **Supabase:** stesso progetto confermato tramite **project hash/ref redatto** (come pattern TASK-098 `project_hash` redatto), in `02-supabase-preflight.md`.
- **Auth:** sessione disponibile su **entrambe** le piattaforme con stesso owner atteso (hash owner redatto, non UUID stampato).
- **Clock sanity:** registrare ora locale visibile/UTC stimata di iPhone, Android e ambiente di comando prima delle write ProductPrice; se la differenza apparente è anomala, usare solo `effectiveAt` manifest-esplicito e annotare la discrepanza.
- **Operator script:** scegliere in preflight chi esegue i tap su iPhone/Android e preparare una sequenza lineare di azioni, così le evidenze non dipendono dalla memoria dell’operatore.
- **Readiness freeze:** dopo device/build/auth/project/run_id validati, congelare una riga `EXECUTION_READY_SNAPSHOT` in `00-summary.md` con SHA, build, owner hash, project hash e run id. Qualunque cambio successivo a build/account/backend richiede aggiornare lo snapshot prima di continuare.
- **Device state snapshot:** registrare se le app partono da install pulita, dati locali esistenti o sessione già autenticata. Se non si parte da stato pulito, annotare perché è rappresentativo dell’uso reale e come il prefisso run isola i dati test.

**Preflight failure handling:** se un prerequisito fallisce, **non** classificare subito PARTIAL/BLOCKED. Applicare la sequenza: **diagnosi rapida** → **fix/config sicuro** se disponibile → **retry documentato** → solo dopo **classificazione** motivata. Esempi: reinstall build corretta, refresh auth, conferma rete, nuovo `run_id`, riapertura app, controllo account.


### S103-B — Dataset sintetico `TASK103_REAL_*`

**Run id obbligatorio:** identico al segmento `R<timestamp>_` del sottoprefisso §6 — riportato in ogni evidenza mutativa.

Pianificare dataset privacy-safe con:

- **SMOKE:** subset minimale per **flussi bidirezionali** iOS→Supabase→Android e Android→Supabase→iOS (§S103-C/D).
- **MEDIUM:** righe sufficienti per **import/export** e **push aggregato** (dimensione definita in manifest).
- **CONFLICT:** entità dedicate allo scenario **stale/conflict** §S103-G — **non** riutilizzare gli stessi barcode/prodotti usati in SMOKE/MEDIUM.
- Supplier/category/product con prefisso run; prodotti con barcode sotto prefisso run.
- **≥ 20** prodotti **piccoli** nel complesso dei set + scenario **MEDIUM** (es. 50–200 righe inventario se fattibile senza stress non necessario) — ripartiti tra set senza sovrapporre **logical_key** dove gli scenari richiedono isolamento.
- **≥ 1** scenario con **ProductPrice** **current** e **previous** (purchase + retail) con `effective_at` dalla strategia deterministica §6.
- Casi: **update**, **create**, **no-op**, **duplicate controllato**; **delete/tombstone** solo se già supportato dai client e **sicuro** sotto RLS — altrimenti esplicitare **SKIPPED** con motivazione in manifest.
- **Cleanup finale:** solo prefisso run, solo se consentito; se policy impedisce DELETE, documentare **residui** + query read-back dimostranti isolamento (collegamento **CA-103-14**).
- **Collision policy:** se il prefisso run ha collisioni, preferire nuovo `run_id` rispetto a cleanup immediato. Cleanup pre-run è ammesso solo se scoped, sicuro e documentato; non deve diventare una mutazione non tracciata.
- **Golden expected table:** prima delle write principali, compilare una tabella attesa con canary, barcode, supplier/category e quattro prezzi per ogni direzione. La review finale deve confrontare osservato vs atteso, non solo leggere descrizioni narrative.
- **Golden table minimale:** includere almeno colonne `direction`, `canary`, `barcode`, `supplier`, `category`, `expected_purchase_previous`, `expected_purchase_current`, `expected_retail_previous`, `expected_retail_current`, `expected_final_platforms`. Questo rende veloce confrontare iOS UI, Android UI e read-back remoto.


### S103-C — iOS → Supabase → Android

Flusso pianificato:

1. Creazione/modifica supplier/category/product su **iOS**.
2. Registrazione purchase/retail **current/previous** su **iOS**.
3. Accumulo **pending** locale (SwiftData / `LocalPendingChange` come da TASK-093/094).
4. **Push intelligente guidato** verso Supabase (Release/manuale — nessun push silenzioso).
5. **Read-back remoto** scoped al **prefisso run** §6.
6. **Android:** pull/check equivalente secondo flusso esistente app.
7. Verifica UI/logica: supplier/category/product + prezzi **current/previous**.
8. **Verifica UI Android reale:** almeno **un** prodotto del set deve essere **visibile** in Database / dettaglio Android con **barcode**, **nome**, **supplier/category** e **prezzi** coerenti col manifest (screenshot sintetico o descrizione step redatta).
9. **Secondo push/check iOS no-op** sullo **stesso** set già sincronizzato: **non** deve creare duplicati remoti/locali né lasciare **pending** inattesi (collegamento **CA-103-10**).
10. **Tolleranza monetaria:** `|delta| <= 0.005` tra valori attesi e osservati (allineamento TASK-098).
11. Nessun duplicato logico imprevisto (chiavi barcode + owner).
12. **Read-back minimo richiesto:** per il set SMOKE, confermare almeno conteggio prodotti, supplier/category link e quattro prezzi attesi (purchase current/previous + retail current/previous) usando query/API scoped al prefisso run; screenshot UI da solo non basta.
13. **Exit criteria slice:** S103-C è PASS solo quando esistono insieme: manifest atteso, push iOS completato, read-back remoto scoped, verifica UI Android, secondo no-op, e nessun duplicato/pending inatteso.

**Fix/retry policy slice:** se il flusso fallisce per **bug client**, **UI bloccante**, **pending non pulito** o **read-back incompleto**, aprire **FIX lane controllata** §17, applicare patch minima, ricostruire/reinstallare **solo** il client impattato, **rieseguire S103-C per intero** e aggiornare il ledger CA. **Non** chiudere PARTIAL finché questa strada non è stata tentata o **motivatamente esclusa** (causa esterna / non correggibile nel task) in `12-final-verdict.md`.


### S103-D — Android → Supabase → iOS

1. Creazione/modifica prodotto su **Android** con prefisso manifest.
2. Prezzi current/previous su **Android**.
3. Push/pull Android secondo implementazione esistente (**no** nuovo worker).
4. **iOS** in foreground: auto check leggero (TASK-092) deve **rilevare** cambiamenti senza apply automatico.
5. Utente apre **review** e **apply guidato** su SwiftData.
6. **Database iOS — verifica UI reale:** lista/dettaglio Database devono mostrare dati attesi **senza** kill/reinstall dell’app e **senza** refresh manuale **non previsto** dal flusso normale utente (navigazione naturale / riapertura schermata consentita se è il pattern atteso).
7. Verifica prodotti, supplier/category, prezzi (coerenza manifest).
8. Verifica **baseline / fingerprint / pending**: dopo apply, non devono restare stati **sporchi** inconsistenti con “operazione completata” — evidenza in `05-android-to-supabase-to-ios.md` + estratto stato UI anonimizzato.
9. **Secondo foreground check no-op** dopo apply completato: **non** deve riproporre lo **stesso** piano già applicato come nuova azione richiesta (nessun “ghost review”).

10. **Read-back minimo richiesto:** come S103-C, confermare conteggio prodotti, supplier/category link e ProductPrice current/previous del canary Android prima di dichiarare PASS iOS-side.
11. **Exit criteria slice:** S103-D è PASS solo quando esistono insieme: write/push Android, read-back remoto scoped, foreground check iOS, review/apply guidato, UI iOS coerente, secondo no-op e pending pulito.

**Fix/retry policy slice:** se **iOS** non rileva/applica correttamente dati Android ma il **read-back remoto** è corretto, trattare come **bug iOS** da FIX lane §17. Se **Android** non scrive correttamente ma iOS è pronto, trattare come **bug Android runtime** da FIX lane §17. In **entrambi** i casi **rerun completo** della direzione **Android→Supabase→iOS** prima di qualsiasi verdict PARTIAL.

### S103-E — Pull semi-automatico foreground iOS

- App **chiusa/riaperta** e **background/foreground** senza loop né polling aggressivo.
- Banner/card root non blocca flussi principali (allineamento TASK-102 note se rilevante).
- **“Controlla cloud”** e review sheet **coerenti** con stati ViewModel.
- **No apply silenzioso**, **no push silenzioso**.
- Stato tipo **“tutto sincronizzato”** solo dopo verifica reale nel perimetro definito (non solo dry-run positivo).

**Checklist UX (superfici sync critiche su device reale):**

- **Una CTA primaria** chiara per lo step successivo (nessuna ambiguità tra due azioni «ugualmente primarie»).
- **Messaggio breve** (no wall of text tecnico in Release).
- **Banner/card** non copre **toolbar** né azioni principali delle tab (regressione TASK-102).
- **No apply/push silenzioso** — conferma/recovery espliciti dove il modello lo richiede.
- **Dynamic Type:** verificare **Large** e **Extra Large** sulle superfici sync critiche (banner root, card Opzioni, review sheet, alert/errori recuperabili).
- **Microcopy:** la UI deve distinguere chiaramente tra “controllo completato senza modifiche”, “modifiche trovate da rivedere”, “azione bloccata da accesso/sessione” e “errore recuperabile”. Evitare messaggi equivalenti per stati diversi.

### S103-F — Push incrementale intelligente iOS

- Più modifiche locali consecutive; **dirty set deduplicato**; **batch bounded** (soft/hard cap come da TASK-094).
- Osservazione **no N+1 evidente** (logging strumentale leggero o conteggio richieste — senza segreti).
- **Retry controllato** dopo errore recuperabile.
- **Idempotenza:** ripetere push non crea righe duplicate remote/local.
- **Secondo push/check no-op** (stesso dirty set già inviato): **zero** mutazioni remote non spiegate e **pending** coerenti — accoppiato a **CA-103-10**.
- **ProductPrice dedupe** per `(type, effectiveAt)` coerente con schema unique.
- Pending → **sent/acknowledged** (o equivalente) con summary utente corretto.

**UX durante push (dataset MEDIUM):**

- **Progress** visibile durante operazioni lunghe.
- Stato **operazione in corso** distinguibile da idle/completato.
- **Blocco ragionevole** di azioni **duplicate** o **distruttive** mentre un push è attivo (no doppio tap accidentale — senza introdurre nuovi pattern se già coperti dall’app).
- Annotare in evidenza **durata approssimativa** e **numero indicativo di batch** per il MEDIUM (ordine di grandezza, redatto).
- **Soglia di attenzione performance:** se il MEDIUM produce attese percepite eccessive, UI congelata, spinner senza testo o batch molto più numerosi del previsto, non fallire automaticamente il P0 se i dati sono corretti, ma aprire nota **P1/P2 performance follow-up** in `12-final-verdict.md`.

### S103-G — Conflict / stale / recovery (minimo sicuro)

- Modifica **stesso prodotto** da Android e iOS **prima** di apply/push completati — scenario minimo controllato (**set CONFLICT** §S103-B).
- iOS deve mostrare **stale/conflict** o stato permission/review **corretto** — **nessuna sovrascrittura silenziosa**.
- Precedenza tecnica TASK-099 (**auth > permission/RLS > stale > …**); in UI copy **orientato all’azione**, **senza** termini grezzi tipo **«RLS»** nel messaggio principale visibile all’utente.
- **CTA primaria coerente con causa:** **Accedi di nuovo** solo per radice **auth/sessione**; **Controlla cloud** per **permission/stale** lato cloud dove previsto dal design TASK-099; **Review** / flusso review per **conflitti risolvibili** dall’utente.
- Unique conflict **ProductPrice:** solo **fail-closed** o **idempotenza** con **read-back esatto** (TASK-099).
- **Scenario minimo accettabile:** almeno un conflitto su campo catalogo leggibile dall’utente (es. nome prodotto o supplier/category) e, se fattibile senza rischio, uno su prezzo. Se il conflitto prezzo non è riproducibile in modo sicuro ma quello catalogo passa, verdict massimo **PARTIAL** salvo Planning Review decida esplicitamente che ProductPrice è già coperto da idempotenza/read-back in S103-C/F.

**Piano per evitare waiver:** preparare due varianti **safe** del conflitto: **G1 catalog-only** su nome prodotto / supplier / category; **G2 ProductPrice** con **idempotency + read-back** esplicito. Se **G2** non è sicuro in runtime, dimostrare almeno che **ProductPrice** non viene **sovrascritto silenziosamente** tramite idempotenza/read-back già coperta da **S103-C/F**. Il **waiver** resta **ultima risorsa**, non scelta predefinita.

### S103-H — Import/export e dataset medio

- Import **Excel** su iOS con righe sotto prefisso run (set **MEDIUM**), generazione griglia, salvataggio **history**.
- Push prodotti/prezzi derivati da import dove previsto dal flusso utente.
- Android legge dati coerenti post-sync.
- Export iOS: **non perdere** current/previous (TASK-085/TASK-100 lineage).
- **Empty / loading / error:** stati verificabili durante import/export medio (non solo happy path).
- **Progress** visibile per operazioni import/export di durata non trascurabile.
- **Contesto preservato:** uscita verso **Files** / **Share sheet** e ritorno all’app **senza perdita** del contesto di lavoro atteso (sessione inventario/database ancora coerente).
- Android export/import: **solo opzionale** se già considerato sicuro e non distruttivo — altrimenti **SKIPPED** documentato (non blocca 100% salvo decisione esplicita in Planning Review).
- **Spot-check export:** aprire/validare almeno una volta il file esportato iOS o ispezionarlo con strumento sicuro per verificare presenza dei canary MEDIUM e prezzi current/previous attesi. Non basta che l’export “finisca senza errore”.

### S103-I — Offline / retry leggero

- Rete assente o Supabase temporaneamente irraggiungibile (**solo se fattibile** senza danneggiare ambiente condiviso).
- iOS mantiene pending; UI errore **recuperabile**; ripresa rete → retry **manuale** o check guidato.
- Nessuna perdita dati locale dimostrata; nessuna duplicazione post-retry.
- Se **offline reale** non è riproducibile in modo **sicuro** per l’ambiente condiviso o policy operativa, **waiver** documentato ammesso ma il **verdict massimo** resta **PARTIAL**, **non** **100%** — coerente con **CA-103-13** e §9.

**Piano per evitare waiver:** prima di usare waiver, tentare almeno una **simulazione sicura e reversibile**: disattivare rete **solo sul device iOS**, produrre **pending locale sintetico**, verificare **errore recuperabile**, riattivare rete, **retry guidato** e verifica **no-duplication**. **Non** alterare backend o policy per simulare offline.

### S103-J — Security/privacy final guard

- Evidenze: **no** segreti, **no** dati negozio reali.
- `git diff --check` su **iOS** e **Android** repo coinvolti nei cambi (se zero cambi codice atteso, registrare **N/A** motivato).
- Secret scan su cartella evidenze e su eventuali diff — checklist in task EXECUTION.
- **Evidence minimization:** salvare solo log necessari a dimostrare CA e redigerli subito. Evitare dump lunghi o output non filtrati: aumentano rischio privacy e rallentano review.
- **Command hygiene:** se in EXECUTION vengono usati comandi SQL/CLI/API per read-back, salvare solo query scoped e output minimizzato; vietati output completi di tabelle, dump globale o log auth non filtrati.

**Redaction checklist** *(controllo manuale + grep dove applicabile):*

- Email; **JWT**; refresh token; **API key**; **owner UUID** grezzo; **seriale device completo**; URL con query sensibili; **barcode reali**; **nomi fornitore/categoria reali**; **path personali** non necessari (`/Users/…` salvo redatto).
- **Screenshot/video:** solo dati **sintetici**; se necessario oscurare **status bar** / indicatori **account** / banner sistema.


### S103-K — Evidence pack finale

Struttura directory pianificata (popolamento in EXECUTION):

`docs/TASKS/EVIDENCE/TASK-103/`

| File | Contenuto atteso |
|------|------------------|
| `00-summary.md` | Scope, dispositivi redatti, esito **PASS/PARTIAL/BLOCKED**, link alle altre evidenze |
| `01-devices.md` | Modello/OS redatto, comandi usati, esito install/launch |
| `02-supabase-preflight.md` | Project ref/hash redatto, auth disponibile, no segreti in log |
| `03-dataset-manifest.md` | Inventario righe/barcode/prezzi/effectiveAt, collision scan |
| `04-ios-to-supabase-to-android.md` | Passi, read-back SQL/API redatti, screenshot UI anonimi |
| `05-android-to-supabase-to-ios.md` | Passi simmetrici, stato post-apply |
| `06-foreground-auto-check.md` | Lifecycle, assenza loop/silent apply |
| `07-incremental-push.md` | Dedupe, batch, idempotenza, summary |
| `08-conflict-recovery.md` | Scenario CONFLICT minimo, UX recovery, esito CA-103-11 (PASS stretto o waiver→PARTIAL) |
| `09-import-export.md` | Excel → grid → history → sync → export spot-check |
| `10-offline-retry.md` | Tentativo realistico o waiver (**max PARTIAL** se waiver su CA-103-13) |
| `11-cleanup.md` | Scoped delete o residui documentati + query read-back |
| `12-final-verdict.md` | Decisione motivata **100% PASS / PARTIAL / BLOCKED** coerente con §9 |
| `screenshots/` | Solo UI sintetica, no dati reali |
| `logs-redacted/` | Solo estratti redatti se necessario |


**Ledger CA obbligatorio:** `00-summary.md` deve contenere una tabella `CA -> Result -> Evidence path -> Reviewer note`, includendo dove applicabile **`PASS_AFTER_FIX`** / **`FAIL_AFTER_FIX_ATTEMPT`**. `12-final-verdict.md` non può dichiarare 100% se questa tabella è incompleta o contiene `NOT_RUN`, `FAIL`, `FAIL_AFTER_FIX_ATTEMPT`, `BLOCKED` o `WAIVED_MAX_PARTIAL` su P0 vincolanti.

**Formato consigliato per ogni file evidenza:** usare sempre blocchi brevi `Setup`, `Steps`, `Expected`, `Observed`, `Result`, `Notes/Redactions`. Questo rende la review finale più veloce e riduce il rischio di PASS non motivati.


**Final review template:** `12-final-verdict.md` deve separare chiaramente: `P0 Verdict`, `P1 Notes`, `Fix Lane Summary`, `Residual Risks`, `Cleanup/Residues`, `Recommendation`. In questo modo un eventuale 100% P0 non viene confuso con note P1 non bloccanti.

---

## 8. Matrice accettazione P0 — CA-103-01 … CA-103-18

La matrice operativa per EXECUTION: ogni riga richiede **tipo verifica** (`DEVICE`, `MANUAL`, `READ_BACK`, `SQL_SCOPED`, `STATIC`, ecc.), **esito finale P0** (`PASS` / `PASS_AFTER_FIX` / `FAIL` / `FAIL_AFTER_FIX_ATTEMPT` / `BLOCKED` / `WAIVED_MAX_PARTIAL`), **evidenza** (path file sotto `EVIDENCE/TASK-103/`), **note**. `NOT_RUN` è ammesso solo come stato intermedio durante execution, mai nel verdict finale se si vuole chiudere TASK-103.

| ID | Descrizione sintetica | Slice primaria | Evidenza primaria |
|----|------------------------|----------------|-------------------|
| **CA-103-01** | iPhone reale: install/build/launch PASS | S103-A | `01-devices.md` |
| **CA-103-02** | Android reale: install/build/launch PASS | S103-A | `01-devices.md` |
| **CA-103-03** | Stesso progetto Supabase + auth verificati; no segreti in log | S103-A, S103-J | `02-supabase-preflight.md`, `00-summary.md` |
| **CA-103-04** | Dataset prefisso run §6 creato e tracciato (SMOKE/MEDIUM/CONFLICT) | S103-B | `03-dataset-manifest.md` |
| **CA-103-05** | iOS → Supabase → Android: supplier/category/product | S103-C | `04-ios-to-supabase-to-android.md` |
| **CA-103-06** | iOS → Supabase → Android: ProductPrice current/previous | S103-C | `04-ios-to-supabase-to-android.md` |
| **CA-103-07** | Android → Supabase → iOS: supplier/category/product | S103-D | `05-android-to-supabase-to-ios.md` |
| **CA-103-08** | Android → Supabase → iOS: ProductPrice current/previous | S103-D | `05-android-to-supabase-to-ios.md` |
| **CA-103-09** | Auto check foreground rileva cambiamenti; no silent apply/push | S103-E | `06-foreground-auto-check.md` |
| **CA-103-10** | Push incrementale: dedupe + idempotenza + **secondo no-op** PASS | S103-C, F | `07-incremental-push.md` *(§ anche `04-ios-to-supabase-to-android.md`)* |
| **CA-103-11** | Conflict/stale/recovery minimo **PASS**; **waiver** ammesso solo con **verdict massimo PARTIAL** | S103-G | `08-conflict-recovery.md` |
| **CA-103-12** | Import/export iOS con dati **prefisso run** §6 PASS | S103-H | `09-import-export.md` |
| **CA-103-13** | Offline/retry minimo **PASS**; **waiver** ammesso solo con **verdict massimo PARTIAL** | S103-I | `10-offline-retry.md` |
| **CA-103-14** | Cleanup scoped PASS **oppure** residui documentati + read-back | S103-B, K | `11-cleanup.md` |
| **CA-103-15** | Privacy/security scan evidenze PASS | S103-J | `00-summary.md`, allegati scan |
| **CA-103-16** | No dati reali negozio; no segreti; no `service_role` client | S103-J | `00-summary.md` |
| **CA-103-17** | Nessuna nuova schema/RLS/grant/migration nel task salvo follow-up blocker separato | Tutte | `12-final-verdict.md` |
| **CA-103-18** | Decisione finale **100% PASS / PARTIAL / BLOCKED** motivata e coerente con §9 | S103-K | `12-final-verdict.md` |

**Completion-first retry rule:** per ogni CA con risultato iniziale **`FAIL`** ma causa **correggibile** lato client / UX / evidenza / procedura test, EXECUTION deve passare da **FIX lane §17** prima del verdict finale. Il **risultato finale** del CA nel ledger deve indicare **`PASS_AFTER_FIX`** oppure **`FAIL_AFTER_FIX_ATTEMPT`**, oltre al verdetto sintetico richiesto (`PASS` / `FAIL` / …) come riepilogo leggibile.

**Regola efficienza evidenze:** una singola **run** può coprire **più CA** nello stesso segmento temporale, ma **ogni CA** deve avere **evidenza dedicata** (paragrafo/sezione separata nel file primario **oppure** file satellite esplicitamente citato da `00-summary.md` o dal file primario) — niente **PASS** senza ancoraggio testuale rintracciabile per quel CA.

**Read-back contract:** per CA-103-05…08 e CA-103-10, il PASS richiede evidenza dati oltre alla sola UI: query/API scoped, stato locale verificabile o output app/log redatto che dimostri conteggi, chiavi logiche e ProductPrice attesi. UI e screenshot sono supporto UX, non unica prova di consistenza dati.


**CA owner:** ogni CA deve indicare implicitamente chi lo valida in review: `Codex evidence owner` per raccolta/esecuzione, `Claude review owner` per giudizio finale. Se un CA richiede interazione manuale su device, l’evidenza deve riportare anche `operator action confirmed`.

**Exit criteria per CA:** ogni CA P0 deve avere una delle seguenti conclusioni esplicite: `PASS`, `PASS_AFTER_FIX`, `FAIL`, `FAIL_AFTER_FIX_ATTEMPT`, `BLOCKED`, `WAIVED_MAX_PARTIAL`. Vietato usare formule ambigue tipo “sembra ok”, “probabilmente”, “non riprodotto ma accettabile” senza classificazione finale.

### Checklist contrattuale (stato iniziale PLANNING)

- [ ] CA-103-01 … CA-103-18 verificati in EXECUTION con evidenze — *NON APPLICABILE in PLANNING*

---

## 9. Definizioni PASS / PARTIAL / BLOCKED (vincolanti)

### PASS 100% integrazione cross-platform *(formula consentita)*

Si può scrivere **"Supabase iOS cross-platform acceptance 100% PASS con note non bloccanti"** **solo se**:

- Tutti i **P0 CA-103-01…18** risultano **PASS** al livello **stretto** — equivalgono a **`PASS`** o **`PASS_AFTER_FIX`** nel ledger (mai **`FAIL_AFTER_FIX_ATTEMPT`** su P0 vincolanti per il claim 100%). **Nessun waiver** su **CA-103-11** / **CA-103-13**: waiver ⇒ **verdict massimo PARTIAL** (§8).
- Eventuali bug **P0** emersi durante la run sono stati corretti tramite **FIX lane controllata** §17, con **rerun** dei CA impattati e ledger aggiornato a **`PASS_AFTER_FIX`** dove applicabile (mai mascherare un FAIL rimasto come PASS).
- Il **secondo check/push no-op** richiesto da **CA-103-10** dimostra **idempotenza** senza mutazioni o pending spuri.
- La **UX sync iOS** su device reale è **comprensibile** e **non bloccante** per i flussi P0: soddisfatta la **§14 UX/UI acceptance checklist** sulle superfici critiche (banner, card Opzioni, review sheet, progress, errori recuperabili, Dynamic Type, empty/no-op).
- **Waiver** documentati su altri aspetti non-CA (se presenti) **non** ripristinano il 100% se implichino ancora gap P0 — solo note non bloccanti **senza** toccare CA falliti.
- Cleanup o residui remoti sono **scoped** e **documentati** senza blocker P0 rimasti.
- Nessun errore **RLS/auth** irrisolto che impedisce i flussi P0.
- Eventuali osservazioni **P1** non bloccanti sono separate in `P1 Notes` e non contraddicono i P0: niente issue P1 che impedisca all’utente di completare sync bidirezionale, review/apply, push, import/export o recovery.

**Regola waiver:** **Waiver** su **conflict/offline** (**CA-103-11** / **CA-103-13**) **abbassa automaticamente** il verdict massimo a **PARTIAL**, mai **100%**.

### Vietato usare "100%" se

- Fallisce un flusso **iOS→Android** o **Android→iOS**.
- **ProductPrice** current/previous incoerenti oltre tolleranza definita.
- **Pending/outbox** resta sporco senza spiegazione verificabile.
- Auto check foreground **non** rileva cambiamenti attesi.
- Push incrementale **duplica** righe **oppure** il **secondo no-op** (**CA-103-10**) non è **PASS**.
- Errori **RLS/auth** non risolti nel perimetro del test.
- Restano **dati test remoti non documentati** oltre il prefisso controllato.
- **Segreti** o dati reali compaiono in log/evidenze.
- La **§14 UX checklist** sulle superfici sync critiche fallisce in modo da rendere i flussi P0 **ambigui** o **bloccanti** per un operatore attento.

### PARTIAL

Usare **PARTIAL** se la maggioranza dei P0 passa ma resta almeno un limite **P0 non correggibile in sicurezza dentro TASK-103** oppure un requisito P0 non testabile senza rischio operativo, **oppure** cleanup impedito da policy ma residui isolati e dimostrati tramite read-back. Limiti puramente **P1** come VoiceOver gestuale completo, scanner hardware in condizioni edge o polish visuale avanzato devono andare in `P1 Notes`, non degradare automaticamente il 100% P0.

Prima di dichiarare **PARTIAL**, `12-final-verdict.md` deve contenere una sezione **`Why not fixable inside TASK-103`** con: **causa**, **tentativi effettuati** (incluso FIX lane §17 se applicabile), **rischio residuo**, **follow-up**. Se questa sezione **manca**, la review deve richiedere **FIX / REVIEW** invece di accettare PARTIAL.

Esempi tipici di **PARTIAL accettabile**: offline non riproducibile in sicurezza, conflict ProductPrice non forzabile senza rischio ma catalog conflict PASS, cleanup remoto negato da policy con residui scoped e documentati, P1 accessibilità/scanner non completati **solo se** rivelano un impatto reale su un P0; altrimenti vanno in `P1 Notes`. Esempi **non** accettabili come PARTIAL se si vuole 100%: flusso bidirezionale rotto, prezzi current/previous incoerenti, owner/auth non dimostrati, pending sporchi non spiegati.

### BLOCKED

Usare **BLOCKED** se mancano prerequisiti ambientali P0: auth non disponibile su una piattaforma, dispositivi non collegati, Supabase irraggiungibile, build non installabile, **RLS** impedisce flusso P0, impossibile verificare read-back cross-platform.

Prima di dichiarare **BLOCKED**, il task deve documentare in evidenza: **prerequisito mancante**, **prova osservata**, **tentativo di ripristino sicuro** (diagnosi/retry §S103-A o FIX lane se pertinente), **perché non è correggibile nel task**, e **quale input esterno** è necessario. **BLOCKED** non è una scorciatoia per evitare un **bug client correggibile** senza aver tentato §17.

### WAIVED_MAX_PARTIAL

Usare **WAIVED_MAX_PARTIAL** per singoli CA solo quando il test non è riproducibile in modo sicuro ma il comportamento non blocca l’uso ordinario. Questo stato non è compatibile con **100% PASS** se riguarda **CA-103-11** o **CA-103-13**. Deve sempre indicare: motivo, rischio residuo, perché non è stato forzato, e follow-up suggerito.

---

## 10. Stop conditions (immediate)

EXECUTION deve **fermarsi** e classificare **BLOCKED** (o **PARTIAL** con revisione Planning) se:

1. **Collision scan** sul **prefisso run** §6 indica sovrapposizione non risolta con dati non-test senza piano documentato.
2. Compare **token/chiave/service_role** in log o evidenza non redatta.
3. **Owner/session** non allineato tra i due client nonostante retry auth documentato.
4. Qualsiasi richiesta di **DDL globale**, **truncate**, **migration ad hoc** per “sbloccare” il test — va **task separato**.
5. Impossibilità di **read-back** scoped dopo write (rete/permessi/schema) — bloccare invece di speculare PASS.
6. **Device fisico** mostra **build diversa** dal manifest (bundle/version/SHA atteso) e non si riesce a **riallineare** entro la sessione documentata.
7. Il **secondo no-op** (push/check/foreground) produce **nuove mutazioni**, **duplicati** non spiegati o **pending** incoerenti.
8. La UI propone **apply/push distruttivo** o **non confermato** dove il piano richiede **review guidata** / conferma esplicita — STOP e classificazione **BLOCKED** o **PARTIAL** motivata.
9. Il manifest non è aggiornato prima delle write o non è possibile collegare una mutazione a `run_id`, piattaforma di origine e logical key.
10. Le evidenze contengono dati personali/segreti non redatti e non possono essere sanificate in modo affidabile.

**Stop non significa chiusura automatica:** se la stop condition è causata da **bug client** o **UX correggibile**, passare a **FIX lane controllata** §17 e rerun CA/slice. Se è causata da **ambiente esterno** non correggibile nel task, classificare **BLOCKED** con prova e requisito mancante (non come esca per evitare fix).

---

## 11. Rischi principali (R103-xx)

| ID | Rischio | Mitigazione pianificata |
|----|---------|-------------------------|
| **R103-01** | Ambiente condiviso Supabase con dati sensibili vicini al prefisso test | Prefisso univoco; read-back sempre filtrato; no dump globale |
| **R103-02** | DELETE/test cleanup negato da policy TASK-038+ | Documentare residui + query dimostrative; solo PARTIAL se P0 ancora soddisfatti |
| **R103-03** | Auth Android instabile (storico TASK-098) | Preflight auth obbligatorio; ripetere prima di ogni slice mutativa |
| **R103-04** | Drift schema locale MerchandiseControlSupabase vs linked | EXECUTION: confrontare migration read-only prima delle write; blocker se divergenza non spiegata |
| **R103-05** | Timeout rete / pooler | Slice S103-I + retry manuale; non mascherare come PASS senza evidenza |
| **R103-06** | Conflitto scenario G difficile da riprodurre | Documentazione esplicita in evidenza; **waiver** ⇒ **verdict massimo PARTIAL** (mai 100% se CA-103-11 non PASS stretto) |
| **R103-07** | Log rumorosi su device | Filtrare/ridurre logging prima della sessione; scansione post-hoc |
| **R103-08** | Sessioni di test troppo lunghe / operator fatigue | Suddivisione **SMOKE / MEDIUM / CONFLICT** §S103-B; ordine §12 |
| **R103-09** | Claim **100%** indebolito da **waiver** non qualificabile come «note non bloccanti» | Applicare regola §9: waiver conflict/offline ⇒ **massimo PARTIAL** |
| **R103-10** | UX sync tecnicamente corretta ma **poco chiara** su device | §14 checklist + prove screenshot/step redatti |
| **R103-11** | **Clock device** diverso altera percezione ProductPrice | Manifest con **effectiveAt deterministico** §6; timezone registrato pre-write |
| **R103-12** | Evidenze lunghe ma poco verificabili | Template `Setup/Steps/Expected/Observed/Result` in §S103-K |
| **R103-13** | Screenshot UI scambiati per prova dati | Read-back contract §8 per CA-103-05…08/10 |
| **R103-14** | Collisioni tra run ripetute | `run_id` obbligatorio e preferenza nuovo prefisso rispetto a cleanup pre-run |
| **R103-15** | Criteri P0 reinterpretati durante execution | Exit criteria espliciti §8/§9; se cambiano i criteri, tornare in PLANNING |
| **R103-16** | Operatore cambia app/account/build a metà run | `EXECUTION_READY_SNAPSHOT` e readiness freeze in S103-A |
| **R103-17** | Review finale lenta o inconcludente | Ledger CA obbligatorio in `00-summary.md` e template evidenze §S103-K |
| **R103-18** | Chiusura **PARTIAL** troppo precoce | **Completion-first** §3 e **FIX lane** §17 prima del verdict |
| **R103-19** | Fix durante acceptance introduce regressione | Patch minima; test mirato; **rerun CA impattati**; anti-scope scan |
| **R103-20** | Offline/conflict difficili ma testabili con device fisici | Varianti safe **S103-G** / **S103-I**; waiver solo ultima risorsa |
| **R103-21** | P1 confusi con P0 e verdict 100% reso ambiguo | Separazione P0/P1 §3 e matrice P1 §18 |
| **R103-22** | Fix minimo risolve CA ma rompe flusso vicino | Post-fix regression ring §17 prima del verdict |
| **R103-23** | Read-back remoto troppo libero o rumoroso | Protocollo read-back §19: scoped, minimizzato, redatto |

---

## 12. Trace suggerita TASK-103 → slice (M103 sintetica)

**Ordine execution ottimizzato (run singola consigliata):**

1. Preflight dispositivi / privacy / auth (**S103-A** + avvio checklist **S103-J**).
2. Manifest completo + **collision scan** (**S103-B**, `03-dataset-manifest.md`).
3. **SMOKE** bidirezionale: iOS→Supabase→Android e Android→Supabase→iOS (**S103-C**, **S103-D**).
4. Foreground auto-check + **no-op** / **idempotenza** (**S103-E**, **S103-F**, inclusi secondo no-op **S103-C** dove previsto).
5. **MEDIUM** import/export (**S103-H**) e push aggregato associato.
6. **CONFLICT** e **offline/retry** (**S103-G**, **S103-I**).
7. Se qualunque **P0 correggibile** fallisce: **FIX lane controllata** §17 + **rerun** dei CA/slice impattati prima del verdict.
8. Cleanup scoped + scan evidenze privacy/security + verdict (**S103-K**, **S103-J** completo, `12-final-verdict.md`).

| M103-ID | Slice | CA coperti (primari) |
|---------|-------|----------------------|
| M103-01 | S103-A | 01, 02, 03 |
| M103-02 | S103-B | 04, 14 |
| M103-03 | S103-C | 05, 06 |
| M103-04 | S103-D | 07, 08 |
| M103-05 | S103-E | 09 |
| M103-06 | S103-C, F | 10 |
| M103-07 | S103-G | 11 |
| M103-08 | S103-H | 12 |
| M103-09 | S103-I | 13 |
| M103-10 | S103-J | 15, 16, 17 |
| M103-11 | S103-K | 18 |


### Checklist operatore sintetica per EXECUTION

1. Confermare device fisici e build installate.
2. Confermare auth e project Supabase redatto.
3. Generare `run_id` e compilare manifest prima delle write.
4. Eseguire SMOKE iOS→Android e Android→iOS.
5. Eseguire secondo no-op/idempotenza.
6. Eseguire MEDIUM import/export e spot-check file esportato.
7. Eseguire CONFLICT e offline/retry; se fallisce un **P0 correggibile**, **FIX lane §17** + rerun prima di classificare PARTIAL.
8. Eseguire cleanup scoped o documentare residui.
9. Eseguire privacy scan evidenze.
10. Scrivere verdict finale solo dopo aver compilato CA-103-01…18.

### Script operatore consigliato

Usare uno script lineare, non improvvisato:

1. **Preparazione:** aprire entrambi i device, confermare account, rete, build e prefisso run.
2. **iOS primary:** creare/modificare canary iOS, eseguire push guidato, annotare stato finale.
3. **Android verify:** eseguire pull/check Android, aprire Database/detail, annotare dati osservati.
4. **Android primary:** creare/modificare canary Android, eseguire push/check Android.
5. **iOS verify:** portare iOS in foreground, aprire review/apply, aprire Database/detail.
6. **No-op:** ripetere check/push previsti senza nuove modifiche.
7. **Medium:** import/export e spot-check file.
8. **Conflict/offline:** eseguire solo se prerequisiti sicuri, altrimenti classificare correttamente.
9. **Cleanup:** scoped o residui documentati.
10. **Review pack:** compilare ledger CA e scan privacy.

---

## 13. Decisioni

| # | Decisione | Stato |
|---|-----------|--------|
| 1 | Prefisso base dataset **`TASK103_REAL_`** + sottoprefisso run **`R<timestamp>_`** §6 | attiva |
| 2 | Strategia **completion-first**: prima correggere/rieseguire **P0 correggibili**, poi decidere PASS/PARTIAL/BLOCKED | attiva |
| 3 | **FIX lane controllata** §17 ammessa dentro TASK-103 solo per bug/client/UX/evidenza/procedura **P0/P1**, con patch minima e rerun mirato | attiva |

---

## 14. UX/UI acceptance checklist iOS-native

TASK-103 **non** è redesign né polish UX generalizzato: si osserva il comportamento **attuale** su device reale. **Micro-fix** UI/UX ammessi **solo** se **bloccano** o **indeboliscono** un **P0/P1** documentato (vedi §5).

| Superficie | Verifica minima (device reale) |
|------------|-------------------------------|
| **Home/root sync banner** | Visibilità, CTA, non copre toolbar/azioni critiche; Dynamic Type L/XL |
| **Opzioni / Cloud sync card** | Stati leggibili, primaria chiara, progress/error coerenti |
| **Review sheet** | Piano comprensibile; nessun apply silenzioso; recovery chiaro |
| **Progress** | Operazioni lunghe (push/import/export) mostrano avanzamento o stato «in corso» |
| **Errori recuperabili** | Messaggio breve + azione successiva (retry/check/cloud/sign-in come da causa) |
| **Dynamic Type** | Large / Extra Large sulle superfici sync critiche §S103-E |
| **Empty / no-op state** | Nessun piano fantasma dopo apply/sync completato; no-op non presentato come errore falso |

**Direzione UX scelta per TASK-103:** mantenere uno stile iOS sobrio e operativo: testo breve, una CTA primaria per stato, azioni destructive dietro conferma, diagnostica tecnica solo secondaria. Nei flussi sync, privilegiare chiarezza e sicurezza rispetto a densità informativa: l’utente deve capire se deve controllare, rivedere, applicare, riprovare o accedere di nuovo.

**Ritocchi UX consentiti se necessari:** copy troppo tecnico, CTA ambigua, progress assente su attese medio-lunghe, banner che copre azioni, alert con messaggio non recuperabile, empty/no-op state confuso. La soluzione preferita è sempre il micro-fix più piccolo: cambiare testo, priorità CTA, spacing o stato visivo; non introdurre nuove schermate o flussi complessi durante TASK-103.

**Criterio estetico scelto:** mantenere la gerarchia visiva già iOS-native: card leggere, toolbar pulite, copy breve, progress contestuale, e niente sovraccarico diagnostico nella schermata principale. Gli eventuali dettagli tecnici devono restare in una sezione secondaria o in evidenza, non nella UI primaria dell’utente.

---

## 15. Estensioni future coerenti opzionali

Prompt utili per task successivi **fuori** dal perimetro TASK-103 (solo backlog):

- `Estendi TASK-103 solo in PLANNING aggiungendo una matrice P1 non bloccante per VoiceOver, scanner camera reale, Dynamic Type avanzato e accessibilità completa. Non cambiare P0 e non avviare execution.`
- `Estendi TASK-103 solo in PLANNING aggiungendo un cleanup protocol più dettagliato per TASK103_REAL_*, distinguendo cleanup via client authenticated, SQL admin controllato e caso policy-denied. Non eseguire cleanup.`
- `Estendi TASK-103 solo in PLANNING aggiungendo performance osservazionale sul dataset MEDIUM: durata approssimativa, numero batch, UI freeze percepiti, senza benchmark invasivo. Non implementare codice.`
- `Estendi TASK-103 solo in PLANNING aggiungendo checklist UX screenshot-by-screenshot per Home, Options sync card, review sheet, Database detail, import/export e stati error/no-op. Mantieni TASK-103 come acceptance, non redesign.`
- `Estendi TASK-103 solo in PLANNING aggiungendo un protocollo di evidence review finale con tabella CA→evidenza→verdetto→reviewer notes. Non eseguire test.`

---

## 16. Planning Review Gate — Definition of Ready per EXECUTION

TASK-103 può passare da **PLANNING** a **EXECUTION** solo se Planning Review conferma tutti questi punti:

| Gate | Condizione |
|------|------------|
| **DoR-103-01** | CA-103-01…18 sono stabili e non ambigui. |
| **DoR-103-02** | Regola 100%/PARTIAL/BLOCKED è accettata: waiver conflict/offline ⇒ max PARTIAL. |
| **DoR-103-03** | Manifest run-specific, canary e golden expected table sono definiti. |
| **DoR-103-04** | Read-back contract è obbligatorio per flussi dati P0. |
| **DoR-103-05** | UX checklist §14 è parte della review, ma non diventa redesign. |
| **DoR-103-06** | Evidence pack e ledger CA sono obbligatori. |
| **DoR-103-07** | Stop conditions §10 sono accettate senza eccezioni silenziose. |
| **DoR-103-08** | Device fisici, auth e progetto Supabase saranno verificati prima di ogni write. |
| **DoR-103-09** | Qualunque micro-fix UX/codice richiede evidenza prima/dopo e resta minimo. |
| **DoR-103-10** | Nessun TASK-104 o follow-up viene aperto automaticamente durante execution: eventuali follow-up nascono solo dal verdict. |
| **DoR-103-11** | **FIX lane** §17 è accettata: i **P0 correggibili** vanno corretti e i CA **rieseguiti** prima di PARTIAL/BLOCKED (salvo causa esterna documentata). |
| **DoR-103-12** | Matrice **P1 non bloccante** §18 accettata: P1 osservati senza confondere il verdict P0. |
| **DoR-103-13** | Protocollo **read-back** §19 accettato: prove dati scoped/minimizzate obbligatorie per P0 sync. |
| **DoR-103-14** | `00-summary.md` ledger CA e template `12-final-verdict.md` sono obbligatori e accettati prima di execution (**formato minimo `00-summary.md`** §20). |
| **DoR-103-15** | La distinzione P0/P1 è accettata: P1 non degradano il 100% P0 salvo impatto diretto su un flusso P0. |

**Output atteso dalla Planning Review:** una frase esplicita nel task o nel MASTER: `TASK-103 PLANNING REVIEW PASS — READY FOR EXECUTION`, oppure elenco puntuale di correzioni richieste. **Soddisfatto il 2026-05-12 17:48 -0400 per override esplicito utente; EXECUTION avviata con Codex / Executor.**

---

## 17. FIX lane controllata durante TASK-103

Questa lane serve a massimizzare la possibilità di arrivare a **100% PASS** senza trasformare TASK-103 in feature work. Si attiva solo dopo un fallimento o blocco **P0/P1** osservato in EXECUTION.

### Quando attivarla

Attivare **FIX lane** se il problema è uno di questi:

- bug iOS/Android riproducibile che impedisce CA P0;
- UX sync ambigua/bloccante che impedisce l’uso corretto del flusso;
- pending/outbox/fingerprint locale incoerente ma correggibile nel client;
- read-back/evidenza incompleta per errore di strumentazione o procedura;
- microcopy/progress/CTA che crea rischio di apply/push errato;
- errore test harness o script operatore correggibile senza cambiare feature;
- mismatch tra evidenza raccolta e CA atteso quando il dato reale è corretto ma la prova è insufficiente o mal strutturata.

**Non** attivarla per:

- schema/RLS/grant/migration backend necessari;
- auth provider indisponibile;
- device fisico non funzionante o non collegabile;
- richiesta di redesign o nuova architettura;
- modifica ai criteri P0 per abbassarli.

### Procedura obbligatoria

1. Registrare in evidence il problema: `CA`, slice, expected, observed, screenshot/log redatto se utile.
2. Classificare causa: `ios_client`, `android_client`, `ux_copy`, `test_procedure`, `backend_external`, `device_external`.
3. Se correggibile nel task, applicare patch minima solo ai file necessari.
4. Eseguire check mirato sul fix.
5. Rieseguire per intero il **CA/slice impattato**, non solo il punto che falliva.
6. Eseguire un **post-fix regression ring** minimo: flusso adiacente più vicino, no-op/idempotenza se coinvolta sync, privacy scan del diff/evidenza se sono stati aggiunti log o copy.
7. Aggiornare ledger con `PASS_AFTER_FIX` o `FAIL_AFTER_FIX_ATTEMPT`.
8. Se il fix tocca UI/UX, allegare evidenza prima/dopo e confermare coerenza §14.
9. Se il fix richiede refactor o schema/backend, fermarsi e classificare PARTIAL/BLOCKED con follow-up.

### Vincoli

- Patch minima, nessun refactor massivo.
- Nessuna nuova feature non richiesta da un CA.
- Nessun DDL/RLS/grant/migration dentro TASK-103.
- Nessun service_role/client secret.
- Ogni fix deve avere test/check e rerun CA.

### Output nel verdict

`12-final-verdict.md` deve includere una tabella:

| CA | Problema iniziale | Fix applicato | Check mirato | Rerun CA | Risultato finale |
|----|-------------------|---------------|--------------|----------|------------------|

---

## 18. Matrice P1 non bloccante

Questa matrice evita che TASK-103 diventi infinito, ma mantiene tracciabili gli aspetti di qualità finale. I P1 non bloccano il **100% P0** salvo che rivelino un problema che impedisce un flusso P0.

| P1 ID | Area | Verifica pianificata | Impatto sul verdict |
|-------|------|----------------------|---------------------|
| **P1-103-01** | VoiceOver base | Elementi sync principali hanno label comprensibili; navigazione base possibile | Non blocca 100% P0 se i flussi P0 sono completabili senza VoiceOver completo |
| **P1-103-02** | Scanner camera reale | Verifica apertura camera/fallback manuale su iPhone reale se praticabile | Non blocca 100% P0 se barcode manuale/fallback completa i flussi dati |
| **P1-103-03** | Dynamic Type avanzato | Large/Extra Large già P0 per superfici sync; dimensioni maggiori annotate se osservate | Blocca solo se rompe CTA P0 |
| **P1-103-04** | Performance percepita MEDIUM | Durata approssimativa, UI non congelata, progress comprensibile | Follow-up se lento ma corretto; blocca solo se impedisce completamento P0 |
| **P1-103-05** | Polish visuale | Screenshot sintetici delle superfici sync principali | Non blocca salvo ambiguità UX P0 |
| **P1-103-06** | Export usability | Nome file, ritorno da Files/Share sheet, spot-check leggibile | Blocca solo se export P0 non è verificabile |

`12-final-verdict.md` deve includere una sezione `P1 Notes` con stato `OBSERVED`, `SKIPPED_NON_BLOCKING`, o `FOLLOW_UP_RECOMMENDED`.

---

## 19. Protocollo read-back scoped

Per i CA dati P0, la UI è necessaria ma non sufficiente. Serve almeno una prova dati minimizzata e rintracciabile.

### Regole

- Tutto il read-back deve essere filtrato per **prefisso run** o logical key del manifest.
- Vietati dump globali di tabelle o output non filtrati.
- Vietati segreti, owner UUID raw, email o token in output.
- Preferire conteggi, logical key, barcode sintetici, supplier/category sintetici e prezzi attesi/osservati.
- Ogni read-back deve indicare quale CA supporta.
- Ogni read-back deve confrontare almeno una riga `Expected` dal golden manifest con una riga `Observed`; vietata validazione solo narrativa.
- Se il read-back usa SQL admin controllato per cleanup/verifica, motivare perché il client authenticated non basta e assicurare che non sia parte del flusso client.

### Prove minime per flussi bidirezionali

| Flusso | Prova dati minima |
|--------|-------------------|
| **iOS → Supabase → Android** | conteggio prodotti prefisso run, supplier/category link, ProductPrice previous/current purchase/retail del canary iOS, UI Android coerente |
| **Android → Supabase → iOS** | conteggio prodotti prefisso run, supplier/category link, ProductPrice previous/current purchase/retail del canary Android, UI iOS coerente |
| **No-op/idempotenza** | conteggi invariati prima/dopo secondo check/push; nessun nuovo pending/duplicato |
| **Import/export** | canary MEDIUM presente in export e coerente con manifest |
| **Cleanup/residui** | conteggi zero oppure lista residui scoped e motivata |

### Template read-back evidence

```markdown
#### Read-back CA-103-XX

- Scope: TASK103_REAL_R... / logical keys ...
- Method: SQL scoped / app state / API scoped / local state
- Expected: ...
- Observed: ...
- Result: PASS / FAIL / PASS_AFTER_FIX / FAIL_AFTER_FIX_ATTEMPT
- Redactions: owner hash redacted, no token, no email
```

---

## 20. Template minimi pre-execution per evidenze

Questa sezione **non crea file in PLANNING**: definisce il formato minimo che **EXECUTION** deve compilare dentro `docs/TASKS/EVIDENCE/TASK-103/`. Serve a evitare evidenze narrative difficili da verificare.

### `00-summary.md` — template minimo

```markdown
# TASK-103 Evidence Summary

## Execution Ready Snapshot

| Campo | Valore redatto |
|-------|----------------|
| run_id | TASK103_REAL_R... |
| iOS commit/build | ... |
| Android commit/build | ... |
| Supabase project hash | ... |
| owner hash | ... |
| iPhone device/OS | ... |
| Android device/OS | ... |
| device state | clean install / existing local data / authenticated session |

## CA Ledger

| CA | Result | Evidence path | Evidence owner | Review owner | Reviewer note |
|----|--------|---------------|----------------|--------------|---------------|
| CA-103-01 | PASS / PASS_AFTER_FIX / ... | ... | Codex | Claude | ... |

## P0 Verdict Draft

- Current status: IN_PROGRESS / READY_FOR_REVIEW / 100% PASS / PARTIAL / BLOCKED
- Blocking CA: ...
- Fix lane used: yes/no
- Privacy scan: pending/pass/fail
```

---

## Planning (Claude)

### Analisi

La roadmap TASK-091…TASK-102 ha portato l’integrazione iOS a uno stato **auditabile** con XCTest, smoke sandbox/simulator ed emulator dove applicabile. Manca una **cartella evidenze unica** che dimostri il medesimo comportamento su **due device fisici** con **backend live condiviso**, includendo **foreground check**, **push aggregato**, **ProductPrice current/previous**, **import/export** e **guardrail sicurezza**, senza contraddire TASK-101 (no segreti / no service_role).

### Approccio proposto

1. **Planning Review** formale su questo file (coerenza CA↔slice↔evidenze↔§14↔ordine §12↔DoR §16↔**FIX lane §17**↔P1 §18↔read-back §19↔template evidenze §20).
2. Dopo approvazione utente: promuovere **EXECUTION**, responsabile **Codex**, seguendo **ordine ottimizzato §12**: preflight/privacy → manifest/collision → **SMOKE** bidirezionale → foreground/idempotenza (**no-op**) → **MEDIUM** import/export → **CONFLICT** → **offline/retry** → eventuale **FIX lane §17** per P0 correggibili con **rerun CA** → cleanup / scan evidenze / verdict.
3. Review finale **Claude** contro `docs/CODEX-EXECUTION-PROTOCOL.md` per le righe CA che richiedono **DEVICE/MANUAL/SIM** espliciti, più controllo specifico su read-back contract §19, manifest/run id, no-op idempotenza, UX checklist, **tabella fix §17**, P1 Notes §18, redazioni privacy.

### File da modificare *(tipicamente nessuno in accettazione pura)*

- Salvo bug **bloccante** emerso durante collaudo: solo patch **minime** iOS/Android tramite **FIX lane §17** con decisione tracciata — **non** refactor non motivato.
- Se un micro-fix UX è necessario, documentare: problema osservato, CA impattato, patch minima, test mirato, evidenza dopo. Se richiede refactor, rimandare a task separato.

### Rischi identificati

Vedi §11.

### Handoff → Planning Review *(turno init)*

- **Prossima fase**: rimane **PLANNING** finché **Planning Review** non marca il task **READY FOR EXECUTION**.
- **Prossimo agente**: **CLAUDE / Planner** (review) poi **Utente** (override esplicito EXECUTION).
- **Azione consigliata**: verificare **CA-103** §8 (completion-first retry, `PASS_AFTER_FIX`, owner/evidence owner), **stop conditions** §10, **regola 100%/PARTIAL** §9, **§14 UX checklist**, **manifest/run id**, **operator script**, **DoR §16**, **FIX lane §17**, **P1 §18**, **read-back protocol §19**, **template evidenze §20** (`00-summary.md` minimo), **ledger CA**, **template verdict**, **ordine execution §12**, path evidenze; aggiornare **MASTER** dopo promozione EXECUTION.

### Handoff → Execution *(solo dopo Planning Review PASS + override utente — NON ATTIVO)*

- **Prossima fase**: **EXECUTION**
- **Prossimo agente**: **CODEX**
- **Azione consigliata**: creare `docs/TASKS/EVIDENCE/TASK-103/` partendo dal **`00-summary.md`** minimo §20, eseguire §12 passi (1)–(2) con collision scan e device/build manifest redatti, poi procedere nell’ordine ottimizzato. Se un **P0** fallisce per causa **correggibile**, attivare **FIX lane §17**, **post-fix regression ring**, **rerun** del CA/slice impattato e aggiornamento ledger **`PASS_AFTER_FIX`** / **`FAIL_AFTER_FIX_ATTEMPT`** prima del verdict. Le evidenze dati devono seguire **read-back §19** e le note non bloccanti devono finire in **P1 Notes §18**. **Non** tentare claim **100%** nel tracking intermedio: solo **`12-final-verdict.md`** completo e coerente con §9 può motivare **100% PASS** o alternativa PARTIAL/BLOCKED.

---

## Execution (Codex)

### Avvio EXECUTION — 2026-05-12 17:48 -0400

**Obiettivo compreso:** eseguire il collaudo finale reale iOS ↔ Supabase ↔ Android su dataset sintetico `TASK103_REAL_R<timestamp>_`, con evidenze complete per CA-103-01…18, completion-first policy e FIX lane controllata per P0/P1 correggibili.

**User override / Planning Review PASS:** l’utente ha dichiarato il piano definitivo approvato e ha autorizzato la promozione di TASK-103 da PLANNING a EXECUTION. Il flag di non-readiness è rimosso dal task e dal MASTER-PLAN prima di qualsiasi build/runtime/write.

**File controllati per avvio:**

| File | Motivo |
|------|--------|
| `docs/MASTER-PLAN.md` | Fonte globale task attivo, stato/fase/responsabile, ultimo completato e TASK-104 non aperto |
| `docs/TASKS/TASK-103-final-real-device-cross-platform-acceptance-ios-supabase-android.md` | Fonte primaria del piano operativo, CA, stop conditions, FIX lane, read-back protocol |
| `docs/CODEX-EXECUTION-PROTOCOL.md` | Protocollo evidenze/verifiche/handoff richiesto per UI/runtime |
| `AGENTS.md` | Regole repo per Codex executor |

**Piano minimo di intervento:**

1. Promuovere tracking a **TASK-103 ACTIVE / EXECUTION**, responsabile **Codex / Executor**, senza aprire TASK-104 e senza modificare backlog/priorità.
2. Creare evidence pack `docs/TASKS/EVIDENCE/TASK-103/` con template minimi richiesti, partendo da `00-summary.md`, `03-dataset-manifest.md`, `12-final-verdict.md`.
3. Eseguire preflight non distruttivo: device iOS/Android, build/install/launch, Supabase project/auth/owner hash redatti, device state snapshot, run id e collision scan prima di qualunque write.
4. Procedere per slice S103-C…K secondo ordine task; in caso di P0/P1 correggibile, usare §17 FIX lane con patch minima, check mirato, regression ring e rerun slice/CA.

### Completamento EXECUTION — 2026-05-12 18:51 -0400

**Modifiche fatte:**

- Creato e compilato evidence pack `docs/TASKS/EVIDENCE/TASK-103/` con summary, manifest, evidenze slice, cleanup e verdict finale.
- Aggiunti harness iOS TASK-103 per auth preflight, SMOKE bidirezionale, MEDIUM import/export, conflict/stale/ProductPrice fail-closed e offline/retry.
- Aggiunti harness Android TASK-103 per auth preflight, SMOKE bidirezionale e MEDIUM pull/read-back su device fisico.
- Applicata FIX lane controllata su bug procedurali/test-harness P0: ProductPrice Android deterministic timestamp, parent refs Android dopo cleanup scoped, no-op preview iOS post-apply.
- Eseguito cleanup SQL scoped solo su `TASK103_REAL_R1778622799_%`; post-read-back zero residui.

**Check eseguiti:**

| Check | Stato | Evidenza |
|-------|-------|----------|
| Build compila iOS | ✅ ESEGUITO | `xcodebuild build-for-testing` Debug device PASS; Release device build/install/launch PASS in preflight |
| Build compila Android | ✅ ESEGUITO | `./gradlew assembleDebug assembleDebugAndroidTest` PASS |
| Nessun warning nuovo introdotto | ✅ ESEGUITO | warning Swift nuovo rimosso; residui sono AppIntents/AGP preesistenti o build-system |
| Modifiche coerenti con planning | ✅ ESEGUITO | solo harness/evidenze/tracking, nessuna feature nuova o schema/RLS/grant/migration |
| Criteri CA-103-01…18 | ✅ ESEGUITO | ledger completo in `00-summary.md`, verdict in `12-final-verdict.md` |
| Privacy/security scan | ✅ ESEGUITO | `git diff --check` iOS/Android PASS; scan evidenze/diff senza token/chiavi/owner UUID raw |
| Cleanup scoped | ✅ ESEGUITO | delete scoped 114 ProductPrice, 55 products, 10 suppliers, 10 categories; post-read-back zero |

**Rischi rimasti:**

- La prova foreground/UI si basa su XCTest device + static check del foreground host, non su screenshot tour manuale completo.
- P1 non bloccanti (VoiceOver completo, scanner camera reale, polish visuale screenshot-by-screenshot) restano separati in `12-final-verdict.md`.

**Handoff post-execution → Review:**

- **Prossima fase**: **REVIEW**
- **Prossimo agente**: **CLAUDE / Reviewer**
- **Stato task**: **ACTIVE / REVIEW**, **NON DONE**
- **Verdict proposto**: **Supabase iOS cross-platform acceptance 100% PASS**
- **File chiave review**: `docs/TASKS/EVIDENCE/TASK-103/00-summary.md`, `03-dataset-manifest.md`, `12-final-verdict.md`
- **TASK-104**: non aperto

---

## Review (Codex — user override)

### Review finale — 2026-05-12 19:05 -0400

**Override dichiarato:** il workflow standard indica Claude come reviewer; l’utente ha richiesto esplicitamente a Codex di eseguire la REVIEW completa e di chiudere formalmente TASK-103 solo se tutti i gate reggono.

**Obiettivo compreso:** verificare senza fidarsi automaticamente del report execution che TASK-103 soddisfi CA-103-01…18, evidence pack, manifest/run_id, read-back scoped, cleanup scoped, privacy/security, harness iOS/Android, build/test e coerenza iOS ↔ Supabase ↔ Android.

**File controllati:**

| File/area | Esito review |
|-----------|--------------|
| `docs/MASTER-PLAN.md` | Coerente prima della chiusura: TASK-103 ACTIVE/REVIEW, ultimo completato TASK-102, TASK-104 non aperto |
| `docs/TASKS/TASK-103-final-real-device-cross-platform-acceptance-ios-supabase-android.md` | Handoff EXECUTION → REVIEW presente; closure aggiornata dopo review |
| `docs/TASKS/EVIDENCE/TASK-103/00-summary.md` … `12-final-verdict.md` | Evidence pack completo; ledger CA-103-01…18 completo; nessun `NOT_RUN`, `FAIL`, `BLOCKED`, `WAIVED_MAX_PARTIAL` finale |
| `iOSMerchandiseControlTests/Task103CrossPlatformAcceptanceTests.swift` | Harness completo e gated; fix review su collision scan completo, export spot-check, pending ack e run prefix esplicito |
| `iOSMerchandiseControlTests/SupabaseConfigSecurityTests.swift` | Auth preflight gated; hash owner/project; nessun secret stampato |
| Android TASK-103 harness | Harness gated; fix review su run prefix esplicito; build/test runner verificati |
| Supabase/evidenze cleanup | Cleanup scoped documentato: 114 ProductPrice, 55 prodotti, 10 supplier, 10 category eliminati; residui zero |

**Piano minimo applicato:** solo fix di review test/evidence, senza modifiche a feature production, API pubbliche, dipendenze, schema, RLS, grant, migration, backend o TASK-104.

**Modifiche review/fix fatte:**

- Hardened iOS collision scan: ora copre tutti i supplier/category/barcode del manifest, non solo i canary SMOKE.
- Hardened iOS export spot-check: ora richiede current + previous purchase/retail del canary MEDIUM.
- Hardened iOS push helpers: pending ack solo dopo push catalogo/ProductPrice verificato e identity reconciliation coerente.
- Hardened iOS/Android live acceptance: `TASK103_RUN_PREFIX` / `task103RunPrefix` obbligatorio quando la live acceptance è abilitata.
- Evidence redaction: rimossi project ref Supabase raw e path personali `/Users/...` dalle evidenze TASK-103.
- `12-final-verdict.md` aggiornato da proposed verdict a final review verdict con review fix summary.

**Check eseguiti:**

| Check | Stato | Esito |
|-------|-------|-------|
| Build compila iOS / targeted TASK-103 | ✅ ESEGUITO | `xcodebuild test` mirato PASS: 9 selezionati, 0 failure, 7 skip live-gated attesi |
| Build Release iOS | ✅ ESEGUITO | `xcodebuild build` Release simulator PASS |
| Build compila Android | ✅ ESEGUITO | `./gradlew assembleDebug assembleDebugAndroidTest` PASS con JBR Android Studio |
| Android instrumentation mirata | ✅ ESEGUITO | `connectedDebugAndroidTest` classi TASK-103 su device fisico IN2013 PASS runner/build; test live-gated SKIPPED senza flag mutativi |
| `git diff --check` iOS | ✅ ESEGUITO | PASS |
| `git diff --check` Android | ✅ ESEGUITO | PASS |
| Privacy/security scan evidenze | ✅ ESEGUITO | Nessun JWT, refresh token, API key, raw owner UUID, email reale, project ref raw o path personale nelle evidenze; match residuo solo su testo checklist `secret_key` |
| Modifiche coerenti con planning | ✅ ESEGUITO | Solo harness/evidence/tracking; nessuna feature o schema/RLS/grant/migration |
| Criteri CA-103-01…18 | ✅ ESEGUITO | Tutti PASS/PASS_AFTER_FIX; nessun blocker P0 |

**Rischi rimasti:**

- P1 non bloccanti restano quelli già separati nel verdict: VoiceOver gestuale completo, scanner camera reale edge, screenshot tour UX completo.
- La review non ha rieseguito la mutazione live completa dopo cleanup per non riaprire una run Supabase già chiusa; i live tests sono rimasti gated e i check review hanno verificato compilazione/runner e hardening.
- Warning residui: AppIntents metadata iOS e AGP/Kotlin Android sono preesistenti/build-system, non introdotti da TASK-103.

**Verdict review:** **REVIEW PASS FINAL** — TASK-103 chiuso come **DONE / Chiusura — REVIEW PASS FINAL**. Verdict: **Supabase iOS cross-platform acceptance 100% PASS** nel perimetro P0 TASK-103. **TASK-104 non aperto**.

---

## Fix (Codex)

### Fix review — 2026-05-12 19:05 -0400

Applicati fix minimi durante review, tutti test/evidence-only:

- `iOSMerchandiseControlTests/Task103CrossPlatformAcceptanceTests.swift`: collision scan completo su manifest, export spot-check current+previous, ack pending solo dopo verifica push, run prefix live obbligatorio.
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/app/src/androidTest/java/com/example/merchandisecontrolsplitview/Task103CrossPlatformAcceptanceTest.kt`: `task103RunPrefix` live obbligatorio.
- `docs/TASKS/EVIDENCE/TASK-103/00-summary.md`, `01-devices.md`, `02-supabase-preflight.md`, `12-final-verdict.md`: redazioni e final review verdict.

Check post-fix: iOS targeted tests PASS, iOS Release build PASS, Android assemble PASS, Android instrumentation gated PASS, `git diff --check` iOS/Android PASS, privacy scan evidence PASS.

---

## Chiusura

**TASK-103 DONE / Chiusura — REVIEW PASS FINAL** — 2026-05-12 19:05 -0400.

**Verdict finale:** **Supabase iOS cross-platform acceptance 100% PASS**.

**Stato progetto:** **IDLE**.

**Ultimo completato:** **TASK-103**.

**TASK-104:** non aperto.
