# TASK-090 — Release acceptance cross-platform finale (planning-init + refinement UX/EFF)

## Stato

- **Stato:** **DONE / Chiusura — PARTIAL_ACCEPTED**
- **Responsabile:** Claude / Reviewer
- **Tipo:** review finale acceptance cross-platform iOS-first, chiusa con residui runtime accettati
- **Ultimo aggiornamento:** 2026-05-09 17:26 -0400 — REVIEW completata; TASK-090 chiuso DONE / Chiusura — PARTIAL_ACCEPTED
- **Ultimo task completato:** **TASK-089 DONE / Chiusura — REVIEW PASS** (`docs/TASKS/TASK-089-large-dataset-sync-preview-benchmark-ios.md`)
- **Task successivi:** non aperti (**TASK-091** e oltre **non** inizializzati)

---

## Execution log

### 2026-05-09 16:57 -0400 — Avvio EXECUTION con override utente

- **Override esplicito:** l'utente ha richiesto di promuovere TASK-090 da **ACTIVE / PLANNING** a **ACTIVE / EXECUTION** ed eseguire il perimetro del piano fino a handoff finale per REVIEW.
- **Responsabile attuale:** **Claude / Executor**.
- **Perimetro confermato:** iOS target principale; Android solo riferimento funzionale; Supabase backend condiviso solo secondo schema reale; evidenze privacy-safe; nessun dato reale come fixture; nessun segreto; nessun cleanup distruttivo; nessuna sync automatica/background; nessuna patch Kotlin o SQL/migration/RLS dentro TASK-090.
- **File tracking iniziali modificati:** `docs/MASTER-PLAN.md` e questo file task.
- **Prossimo step:** preflight statico/read-only, mappatura repo iOS reale, schema Supabase locale read-only, poi compilazione matrice S90-F prima delle run finali.
- **Stato di sicurezza:** **TASK-090 NON DONE**; **TASK-091 non aperto**; ultimo completato resta **TASK-089 DONE / Chiusura — REVIEW PASS**.

### 2026-05-09 17:03 -0400 — Preflight read-only e matrice iniziale

- **Repo:** branch `main`, commit `8264c96`; working tree gia' modificato dai tracking docs (`docs/MASTER-PLAN.md`, questo task file untracked/modificato).
- **Xcode:** `xcodebuild -list -project iOSMerchandiseControl.xcodeproj` riuscito; scheme `iOSMerchandiseControl`, target app e test, configurazioni Debug/Release.
- **File iOS letti/mappati:** `OptionsView.swift`, `SupabaseManualSyncViewModel.swift`, `SupabaseManualSyncReleaseFactory.swift`, `SupabaseManualSyncCoordinator.swift`, `SupabasePullPreviewService.swift`, `SupabasePullApplyService.swift`, `SupabaseManualPushService.swift`, `SupabaseManualPushPreflightService.swift`, `SupabaseProductPriceApplyService.swift`, `SupabaseProductPriceManualPushService.swift`, `SupabaseProductPricePushDryRunService.swift`, `DatabaseView.swift`, `Localizable.strings`, XCTest manual sync/ProductPrice/pull/export benchmark.
- **Schema Supabase letto solo da filesystem:** `inventory_suppliers`, `inventory_categories`, `inventory_products`, `inventory_product_prices`, `sync_events`; vincoli/RLS verificati sui file migration locali, senza query live e senza segreti.
- **Android:** usato solo come riferimento documentale da TASK-087/TASK-088; nessun file Kotlin aperto in write e nessuna patch Android.
- **Gate mutativo TASK090_*:** **BLOCKED_ENV per write live in questa execution slice**; owner/session live/collision scan DB non sono stati verificati in modo sufficiente per seed/write sicuro. Nessun write cieco eseguito.
- **Evidenze create:** `docs/TASKS/EVIDENCE/TASK-090/manifest_acceptance.md`, `matrix_s90_f_initial.md`, `static_preflight_mapping.md`, `supabase_schema_readonly.md`, `static_ui_copy_audit.md`, `scenario_graph.md`, `privacy_boundary_log.md`.

### 2026-05-09 17:10 -0400 — Execution completata / handoff REVIEW

- **Stato al termine execution (storico pre-review):** **ACTIVE / REVIEW**, responsabile **Claude / Reviewer**. **TASK-090 NON DONE**; **TASK-091 non aperto**; ultimo completato resta **TASK-089 DONE / Chiusura — REVIEW PASS**.
- **Patch codice:** nessuna patch Swift, Kotlin, SQL/migration/RLS o Localizable applicata. Intervento limitato a tracking ed evidenze.
- **Evidenze finali create:** `matrix_s90_f_final.md`, `must_ca_evidence.md`, `test_build_results.md`, `supabase_readback_aggregated.md`, `retry_idempotence.md`, `decision_final.md`.
- **Check principali:** build Debug PASS, build Release PASS, XCTest mirati PASS (299 test case nel log mirato), full XCTest PASS (567 passed / 0 failed / 0 skipped), `plutil` localizzazioni PASS, `git diff --check` PASS, Release binary senza stringhe `TASK090`.
- **Supabase live `TASK090_*`:** **BLOCKED_ENV / PARTIAL** per nuova mutazione: owner/session/collision scan DB non verificati immediatamente prima di write sicuro; nessun insert/update live eseguito.
- **Decisione proposta pre-review:** **PARTIAL_READY_FOR_REVIEW**.

### 2026-05-09 17:26 -0400 — Review finale / chiusura PARTIAL_ACCEPTED

- **Decisione finale:** **DONE / Chiusura — PARTIAL_ACCEPTED**.
- **Motivo:** i Must documentali/statici sono soddisfatti o motivati; ProductPrice current/previous e UI/copy sono PASS; gli scenari runtime non rieseguiti restano esplicitamente **PARTIAL / BLOCKED_ENV** e non vengono trasformati in PASS.
- **Fix review applicato:** solo documentale, per chiarire che l'handoff planning-init e le sezioni "futura execution" sono storiche/superate dall'handoff post-execution e da questa review.
- **Non claim:** nessuna garanzia production-ready globale 100%; nessun nuovo smoke live `TASK090_*`; nessun Android runtime fresh; nessun round-trip UI manuale import/export app -> file -> app.
- **Boundary confermati:** nessuna patch Swift/Kotlin/SQL/RLS/Localizable, nessun dato reale, nessun segreto, nessun comando distruttivo, nessuna sync automatica/background, **TASK-091 non aperto**.

---

## Execution — S90-F matrice iniziale

| Scenario | Direzione | Dataset | Oggetti | Evidenza iniziale | Esito iniziale | Stop gate |
|----------|-----------|---------|---------|-------------------|----------------|-----------|
| Catalog pull Supabase -> iOS | Supabase -> iOS | STATIC + prior runtime `TASK087_*`; `TASK090_*` solo proposto | Supplier / Category / Product | Wiring Release letto: preview -> review -> conferma -> apply; schema catalogo letto; XCTest da eseguire | PARTIAL | Owner/session/collision live non verificati per nuova mutazione `TASK090_*` |
| ProductPrice current/previous Supabase <-> iOS | Supabase <-> iOS | STATIC + prior runtime `TASK088_*` | ProductPrice purchase/retail current/previous | Schema unique `(owner_user_id, product_id, type, effective_at)`; apply/push/reconciler letti; test mirati da eseguire | PARTIAL | Nuovo read-back live `TASK090_*` non eseguito senza gate owner/session |
| Cross-platform Android -> Supabase -> iOS | Android -> Supabase -> iOS | Prior runtime `TASK087_*`; no nuovo Android runtime | Catalogo + prezzi dove disponibili | TASK-087 documenta MIN-A verified con runner scoped; iOS Release globale resta valutato staticamente | PARTIAL | Android runtime non forzato; no patch Kotlin; no nuovo seed live |
| Cross-platform iOS -> Supabase -> Android | iOS -> Supabase -> Android | Prior runtime `TASK087_*`/`TASK088_*`; no nuovo write | Catalogo + ProductPrice | TASK-087 MIN-I verified scoped; TASK-088 ProductPrice read-back/Android reference PASS | PARTIAL | Nessun nuovo write live senza collision/owner/session |
| Import/export runtime iOS app -> file -> app | iOS local | Sintetico/local fakeable da test | Products / Suppliers / Categories / ProductPrice | `DatabaseView` export products/full DB e import full DB letti; TASK-089 synthetic export evidence | PARTIAL | UI runtime app-file-app non ancora ripetuto in questa execution |
| UI truthfulness/copy Release | iOS Release UI | STATIC | Copy / CTA / summary / a11y labels | Localizable 4 lingue: 222 manualSync keys ciascuna; copy separa check/apply/push e no automatic send | PASS_CANDIDATE | Se grep/test copy fallisce -> CHANGES_REQUIRED |
| Retry/idempotenza | iOS/Supabase logic | STATIC + XCTest | Catalog/ProductPrice | Stale guards, fingerprint snapshot, deterministic ProductPrice IDs, read-back verification letti | PARTIAL | Serve conferma test finale; nuovo runtime opzionale bloccato da env |
| Privacy/anti-distruttivo | Repo/processo | STATIC | Evidenze/tracking | Nessun dato reale fixture; nessun secret; nessun comando distruttivo; nessun SQL/Kotlin patch | PASS_CANDIDATE | Qualsiasi segreto/dump/drop/delete/reset -> BLOCKED |

---

## Obiettivo

Definire, in modo progressivo e verificabile, il perimetro della **review / smoke finale cross-platform** per l’integrazione Supabase sull’app iOS **dopo** la chiusura di TASK-086…TASK-089, come da **MASTER-PLAN** (backlog «Roadmap follow-up», riga **TASK-090**):

- **Release acceptance cross-platform finale:** evidenze e criteri per dichiarare chiusura controllata su **cicli bidirezionali** (riferimento funzionale Android ↔ Supabase ↔ iOS ove applicabile), copertura **Product / Supplier / Category / ProductPrice**, **current/previous** price coerenti dove previsti dal perimetro release, **import/export runtime** end-to-end (ove inclusi nel contratto di acceptance), **UI/copy veritiera** (nessuna promessa «tutto sincronizzato» senza apply/push verificati), **nessun duplicato** e **nessun conflitto silenzioso** nel perimetro definito dal task.

Nota storica: le sezioni di planning sotto restano il contratto originario da cui e' partita l'execution. Lo stato corrente e la decisione finale sono quelli nelle sezioni **Stato**, **Execution log**, **Handoff post-execution** e **Review finale — Chiusura**.

---

## Contesto

### Cosa ha chiuso TASK-089

- Benchmark **read-only / controllato** su dataset sintetico **D89-M** (`TASK089_*`): scenari **LG1–LG4** eseguiti in ambito review (preview read-mostly/fakeable, export prodotti/full DB via harness **DEBUG-only**, cancel/retry/recovery ViewModel); **LG5 / S89-E** **SKIPPED** per gate §10 non GO e mutazioni non autorizzate.
- Evidenze quantitative e vincoli privacy rispettati; **TASK-089 DONE / Chiusura — REVIEW PASS** con limitazioni esplicite (vedi sotto).

### Limitazioni ancora aperte (ufficiali)

- **LG5** e apply/pull mutativo post-preview **grande**: non chiusi in TASK-089; restano **documentati**, non implicitamente PASS.
- **D89-L**, **device fisico**, **Supabase live** strumentale, **Instruments**: non obbligatoriamente coperti dentro TASK-089; restano **PARTIAL / NOT_RUN** come classe di rischio per la roadmap finale.
- **Round-trip runtime import/export** «app ↔ file ↔ app» e acceptance **cross-platform** completa: esplicitamente in backlog per **TASK-090**, non sostituiti dal benchmark TASK-089.

### Perché TASK-090 è il passo logico successivo

- TASK-086…089 hanno progressivamente coperto policy catalogo, smoke piccolo bidirezionale, identity ProductPrice post-push, e caratterizzazione volumetrica/UX controllata; manca un **contenitore di acceptance finale** che tenga insieme i fili, definisca **criteri PASS/PARTIAL/BLOCKED** per l’intero perimetro release senza **claim globale** non motivato.

### Confronto iOS / Android / Supabase (se pertinente)

- **iOS:** obiettivo di verifica sui flussi Release già implementati (manual sync, apply/push, ProductPrice, export database, copy localizzata).
- **Android:** solo **riferimento funzionale** e confronto comportamenti/valori (es. read-back aggregati, last/prev), salvo futuro task dedicato su Kotlin.
- **Supabase:** coerenza schema/constraints/RLS **solo** come lettura documentale dai repository autorizzati (**nessuna** colonna o tabella inventata in questo planning); eventuali verifiche runtime solo in **futura** EXECUTION con gate.

---

## Fonti da leggere in futura execution

### iOS (prima di qualsiasi patch)

- Coordinator / ViewModel manual sync: file che contengono `SupabaseManualSyncViewModel`, factory Release, adapter preview/pull/apply/push (nomi esatti da elencare dopo `git grep` / lettura repo al preflight EXECUTION).
- Servizi verticali già citati in roadmap: `SupabasePullPreviewService`, `SupabasePullApplyService`, push catalogo / ProductPrice, drain outbox Release ove in scope acceptance.
- UI Release: `OptionsView` e sheet manual sync (copy `Localizable.strings` IT/EN/ES/zh-Hans).
- Export: `DatabaseView` / export XLSX prodotti e full DB (perimetro import/export runtime se incluso in TASK-090).
- Test esistenti: XCTest su manual sync, ProductPrice, regressioni coordinator (elenco mirato da aggiornare al preflight).

### Android (solo se serve confronto funzionale)

- Repository / datasource / test unitari nel **repository Android di riferimento** (path esterno al workspace iOS): da identificare a EXECUTION senza assumere struttura file non verificata.

### Supabase (solo lettura documentale / schema locale)

- Clone / cartella progetto Supabase locale (**solo** file presenti nel workspace utente, es. `MerchandiseControlSupabase/supabase/migrations/`): leggere **solo** migrazioni effettivamente nel repo; **non** inventare nomi colonne/tabelle.

---

## Fuori perimetro (TASK-090 in fase PLANNING-init)

- Modifiche a **Swift**, **Kotlin**, **SQL**, **migration**, **RLS**, dati remoti, `project.pbxproj`, `Localizable.strings` in questo turno.
- **Build**, **test**, **simulator**, **emulator**, smoke runtime **obbligatori** in questo turno.
- **Sync automatica**, **background**, **Timer**, **BGTask**, **Realtime**, **polling**, **worker** (nuovi o estesi).
- **Cleanup/reset/delete/truncate/drop/wipe/backfill massivo**; dataset **negozio reale** come fixture; **segreti** in evidenze.
- **Apertura TASK-091** o task successivi.
- **Claim** production-ready **globale** o **100%** senza matrice di acceptance e evidenze future dedicate.
- Trasformare questo planning in **DONE** o **READY FOR EXECUTION** senza review esplicita del documento e **override utente** per EXECUTION.
- **Nessuna execution dopo questa integrazione:** TASK-090 resta **ACTIVE / PLANNING**.
- **Nessun ritocco UI/UX** applicato in Swift durante il planning: solo **pianificazione** documentale.
- **Nessuna modifica** a `Localizable.strings`, asset, colori, navigation o layout runtime in questo turno.
- **Nessun** benchmark aggiuntivo, run simulator/device, **Supabase live write**, SQL/migration o patch Android in questo turno.

---

## Priorità release acceptance (Must / Should / Could / Out)

Questa sezione evita che TASK-090 diventi troppo grande durante la futura execution. La review finale deve distinguere chiaramente tra ciò che è necessario per chiudere il task e ciò che può diventare follow-up.

### Must — necessario per dichiarare TASK-090 completabile in futura review

- Matrice acceptance compilata con scenari, dataset, evidenze minime, esito ammesso e stop gate.
- Almeno un percorso verificabile per catalogo + ProductPrice, con current/previous coerenti e zero duplicati logici nel perimetro scelto.
- Stato chiaro per cicli Android ↔ Supabase ↔ iOS: PASS, PARTIAL, BLOCKED_ENV, SKIPPED o OUT_OF_SCOPE, senza ambiguità narrativa.
- UI/copy veritiera: nessuna promessa di sync completa se apply/push/pull non sono confermati.
- Nessun dato reale, nessun segreto, nessun cleanup distruttivo e nessuna nuova sync automatica/background.

### Should — raccomandato se l’ambiente lo consente

- Smoke runtime piccolo con prefisso TASK090_*, dopo collision scan e owner/session verificati.
- Round-trip import/export iOS app ↔ file ↔ app, oppure esclusione esplicita con motivo.
- Evidenza di retry/idempotenza: doppia esecuzione senza duplicati logici.
- Audit UX statico o screenshot redatti degli stati principali se runtime autorizzato.

### Could — utile ma non bloccante

- Benchmark leggero su tempi aggregati, senza duplicare TASK-089.
- Piccoli ritocchi UI futuri se riducono attrito e restano coerenti con lo stile esistente.
- Evidenze aggiuntive Android come riferimento funzionale, senza trasformare TASK-090 in patch Kotlin.

### Out — fuori perimetro salvo nuovo task o override esplicito

- Redesign UI ampio.
- Patch Kotlin non strettamente necessarie alla review iOS.
- SQL/migration/RLS o cambi schema Supabase.
- Device farm, Instruments completo, benchmark grande dataset nuovo.
- Claim production-ready globale al 100%.

---

## Micro-slice proposte

### S90-A — Manifest acceptance e namespace evidenza

- **Scopo:** Definire prefisso evidenza proposto (**`TASK090_*`**, da sottoporre a collision scan prima di qualsiasi write futura), matrice scenario → metrica minima → tipo evidenza (STATIC / BUILD / SIM / MANUAL) → esito ammesso (PASS / PARTIAL / BLOCKED / SKIPPED).
- **File potenzialmente coinvolti (futuri):** `docs/TASKS/TASK-090-*.md`, `docs/MASTER-PLAN.md`, eventuali `docs/TASKS/EVIDENCE/TASK-090/` (solo dopo EXECUTION autorizzata).
- **Rischi:** ambiguità tra benchmark TASK-089 e acceptance TASK-090; doppio uso di prefissi.
- **Criteri di stop:** manifest incomplete o prefisso non disjoint da TASK085…089 → **no EXECUTION**.
- **Test/check futuri:** revisione checklist manifest; grep collision `TASK090_` su DB di test prima di seed.

### S90-B — Scenario graph: cicli bidirezionali e dati minimi

- **Scopo:** Descrivere (documentale) i cicli **Android → Supabase → iOS** e **iOS → Supabase → Android** richiesti per PASS, inclusi oggetti dominio (product, supplier, category, price rows) e **current/previous** ove nel contratto.
- **File potenzialmente coinvolti:** task file TASK-090; riferimenti incrociati TASK-084 manifest M* se ancora validi (solo lettura).
- **Rischi:** drift rispetto a TASK-087 smoke minimo; ambiente non ripetibile.
- **Criteri di stop:** assenza account/owner verificabile → scenario marcato **BLOCKED_ENV** o **PARTIAL**, non PASS silenzioso.
- **Test/check futuri:** evidenze runtime privacy-safe con hash/redazione owner; confronto aggregati read-back.

### S90-C — Import/export runtime (se in scope)

- **Scopo:** Se incluso nel contratto finale, definire percorso iOS **app ↔ export file ↔ re-import** (o equivalente già presente in app) e criteri di **round-trip** senza duplicati fantasmi; altrimenti esplicitare **OUT OF SCOPE** formalmente.
- **File potenzialmente coinvolti:** `DatabaseView` / ViewModel export import, test round-trip esistenti.
- **Rischi:** OOM su file grandi; differenza export prodotti vs full DB (lezione TASK-089).
- **Criteri di stop:** scenario non ripetibile o file non generato → **NOT_RUN** o **PARTIAL**, non PASS.
- **Test/check futuri:** XCTest o manuale documentato; dimensioni file e conteggi righe aggregati.

### S90-D — UI copy e veridicità Release

- **Scopo:** Allineare criteri «copy veritiera» alle stringhe Release esistenti: nessun messaggio che implichi sync completa senza conferma di apply/push verificati.
- **File potenzialmente coinvolti:** `Localizable.strings` (quattro lingue), `SupabaseManualSyncViewModel` mapping summary.
- **Rischi:** churn localizzazioni; regressioni a11y.
- **Criteri di stop:** grep anti-jargon / anti-false-claim fallisce → **CHANGES_REQUIRED** in review.
- **Test/check futuri:** `plutil`, XCTest copy, grep statici già usati in task precedenti.

### S90-E — Duplicati e conflitti non silenziosi

- **Scopo:** Formalizzare attese su **dedupe/conflict** ProductPrice e catalogo in linea con TASK-080…082 / TASK-088; esito atteso quando match ambiguo (fail-closed documentato).
- **File potenzialmente coinvolti:** servizi apply/push ProductPrice, reconciler identity, test regressione.
- **Rischi:** divergenza comportamento iOS vs Android su edge case.
- **Criteri di stop:** conflitto risolto «in silenzio» senza traccia in UI/summary → **BLOCKED** per acceptance.
- **Test/check futuri:** XCTest mirati + read-back aggregato `TASK090_*` se write consentita in EXECUTION.

### Nota — slice integrazione UX / efficienza / recovery

Le slice **S90-UX-A**, **S90-UX-B**, **S90-EFF-A**, **S90-REC-A** sono definite nella sezione **«Integrazione review planning — UX/UI, efficienza e decisioni operative»** più avanti in questo file. Questo evita duplicazione e mantiene un'unica fonte di dettaglio.

### S90-F — Matrice acceptance unica e ordine di esecuzione futuro

- **Scopo:** evitare che la futura EXECUTION diventi una lista vaga di smoke manuali; ogni scenario deve avere una riga tracciabile nella matrice acceptance prima di qualsiasi run.
- **Ordine futuro consigliato:**
  1. **STATIC / READ-ONLY:** lettura file, schema, wiring, copy e test esistenti senza mutazioni.
  2. **LOCAL / FAKEABLE:** test o harness controllati senza Supabase write live.
  3. **SANDBOX SMALL `TASK090_*`:** solo dopo collision scan, owner/session verificati e override utente.
  4. **OPTIONAL RUNTIME / DEVICE:** solo se l’ambiente è disponibile; se manca, segnare **PARTIAL / BLOCKED_ENV**, non forzare workaround rischiosi.
- **Template matrice da compilare in futura execution:**

| Scenario | Direzione | Dataset | Oggetti | Evidenza minima | Esito ammesso | Stop gate |
|----------|-----------|---------|---------|-----------------|---------------|-----------|
| Catalog pull | Supabase → iOS | STATIC / TASK090_* | Supplier / Category / Product | conteggi + zero duplicati | PASS / PARTIAL / BLOCKED | owner/session non verificati |
| ProductPrice current/previous | Supabase ↔ iOS | STATIC / TASK090_* | ProductPrice | last/prev coerenti + zero duplicate key | PASS / PARTIAL / BLOCKED | schema/constraint non verificabili |
| Cross-platform A→I | Android → Supabase → iOS | TASK090_* | catalogo + prezzi | read-back aggregato redatto | PASS / PARTIAL / BLOCKED_ENV | Android runtime non disponibile |
| Cross-platform I→A | iOS → Supabase → Android | TASK090_* | catalogo + prezzi | read-back aggregato redatto | PASS / PARTIAL / BLOCKED_ENV | iOS/Android session non verificabile |
| Import/export runtime | iOS app ↔ file ↔ app | sintetico | prodotti + prezzi | conteggi righe/file size/zero duplicati | PASS / PARTIAL / OUT_OF_SCOPE | file non ripetibile o scenario escluso |
| UI truthfulness | iOS Release UI | STATIC | copy / CTA / summary | grep/review copy + screenshot se runtime | PASS / CHANGES_REQUIRED | copy promette sync completa non verificata |

- **File potenzialmente coinvolti:** task file TASK-090; eventuale evidence folder solo in futura EXECUTION; ViewModel/UI/test da elencare al preflight.
- **Rischi:** acceptance troppo ampia, dati non confrontabili, smoke duplicati tra TASK-087 e TASK-090.
- **Criteri di stop:** matrice incompleta o scenari senza esito ammesso → TASK-090 resta **PLANNING / NOT READY**.
- **Test/check futuri:** la review finale deve poter leggere la matrice e capire cosa è PASS, cosa è PARTIAL e cosa resta fuori scope senza interpretazioni.

### S90-G — Budget UX/performance e anti-main-thread work

- **Scopo:** rendere espliciti i criteri minimi di qualità percepita per la futura acceptance, senza trasformare TASK-090 in un nuovo benchmark grande dataset.
- **Budget futuri consigliati:**
  - primo feedback UI percepibile entro circa **250 ms** per azioni lunghe;
  - progress/counter visibile per operazioni multi-step;
  - cancel/retry sempre disponibili dove l’operazione può durare o fallire per rete;
  - nessun loop pesante, parsing XLSX, dedupe o read-back aggregato sul `MainActor`;
  - nessun N+1 noto su Product / Supplier / Category / ProductPrice quando basta una mappa indicizzata o batch query.
- **File potenzialmente coinvolti:** ViewModel manual sync/export/import, servizi Supabase, adapter preview/apply, UI sheet di sync.
- **Rischi:** ottimizzare troppo presto o introdurre refactor non necessario.
- **Criteri di stop:** se per rispettare il budget serve refactor ampio, creare follow-up e mantenere TASK-090 focalizzato sulla acceptance.
- **Test/check futuri:** log privacy-safe con tempi aggregati e conferma che il primo feedback non arriva solo a fine operazione.

### S90-H — Policy decisionale UX/UI per la futura execution

- **Scopo:** chiarire come scegliere tra alternative UI senza bloccare il lavoro su micro-decisioni.
- **Decisione:** quando ci sono più soluzioni equivalenti, scegliere automaticamente quella più coerente con stile iOS già presente nell’app: `NavigationStack`, toolbar native, sheet/bottom sheet quando serve review, `ProgressView`, `List`/`Form`, `confirmationDialog` per azioni distruttive o irreversibili, summary chiaro a fine operazione.
- **Preferenze UX:**
  - preferire una schermata/sheet di review leggibile a un alert troppo denso;
  - usare CTA specifiche: **Rivedi**, **Applica**, **Invia al cloud**, **Aggiorna da cloud**, **Riprova**, **Annulla**;
  - evitare CTA generiche tipo **Sync** quando l’azione reale è pull, push, apply o retry;
  - mostrare partial success e righe saltate come stato normale gestibile, non come errore misterioso;
  - mantenere gerarchia visuale coerente con le schermate esistenti: azione primaria evidente, destructive action separata, stati vuoti e loading non ambigui.
  - rispettare accessibilità di base: Dynamic Type leggibile, target touch comodi, contrasto sufficiente e VoiceOver label non fuorvianti quando si toccano CTA/stati;
  - preferire componenti SwiftUI nativi e già usati nell’app rispetto a componenti custom nuovi, salvo necessità evidente;
  - se un miglioramento richiede nuove stringhe localizzate, pianificarle come futura execution e non modificarle in planning.
- **Fuori perimetro:** nessuna patch Swift/UI in planning; queste sono regole per futura execution dopo override.
- **Criteri di stop:** se una scelta UI richiede nuova navigazione principale o redesign strutturale, spostarla a task separato.

### S90-I — Idempotenza, duplicati e retry non distruttivo

- **Scopo:** rendere verificabile che retry e riapertura dello stesso scenario non creino duplicati o stati ambigui.
- **Invarianti future:**
  - ripetere lo stesso push/apply su `TASK090_*` non deve creare duplicati logici;
  - `ProductPrice` deve mantenere current/previous coerenti con schema reale e chiavi logiche effettive;
  - `remoteID`/identity reconciliation non deve persistere match ambigui;
  - conflitti e skipped rows devono comparire in summary/evidenza, non sparire nei log tecnici.
- **File potenzialmente coinvolti:** servizi push/apply ProductPrice, reconciler identity, test ProductPrice/manual sync.
- **Rischi:** un retry riuscito può nascondere un primo tentativo parziale.
- **Criteri di stop:** qualunque duplicato logico non spiegato → scenario **BLOCKED** o **CHANGES_REQUIRED**, non PASS.

### S90-J — Boundaries Android/Supabase/iOS per evitare scope creep

- **Scopo:** mantenere iOS come target principale, Android come riferimento funzionale e Supabase come schema condiviso, senza trasformare TASK-090 in refactor cross-repo.
- **Regole future:**
  - patch Swift solo se necessaria e dopo override EXECUTION;
  - patch Kotlin solo se un task separato o override esplicito lo autorizza;
  - patch SQL/migration solo se TASK-090 dimostra un blocker schema e l’utente apre esplicitamente execution backend;
  - Android può fornire confronto comportamentale e read-back, ma non va usato per copiare UI o architettura su iOS.
- **Criteri di stop:** se la acceptance richiede cambiare schema Supabase o comportamento Android, fermare TASK-090 come **PARTIAL / FOLLOW-UP_REQUIRED** invece di allargare il task in silenzio.

---

## Acceptance criteria futuri (CA-T090-xx)

*(Contratto per **futura** EXECUTION / review; **nessun** PASS applicato in questo turno.)*

- **CA-T090-01** — Esiste **manifest acceptance** (scenario, device/target, dataset class, privacy, scope mutazione) compilato **prima** di qualunque RUN definita «finale».
- **CA-T090-02** — Ogni scenario critico ha esito **PASS / PARTIAL / BLOCKED / SKIPPED** con **motivo** verificabile, non narrativa vaga.
- **CA-T090-03** — **Cicli bidirezionali** (perimetro TASK-090): evidenza di almeno un flusso **Android → Supabase → iOS** e **iOS → Supabase → Android** su dati **`TASK090_*`** o equivalente privacy-safe, **salvo** stop documentato **BLOCKED_ENV** (che non può essere nascosto come PASS).
- **CA-T090-04** — **ProductPrice / current/previous:** coerenza aggregata tra iOS, Supabase read-back e riferimento Android ove incluso nello scenario; **zero** duplicati logici per le chiavi dichiarate nello schema reale (verificato su read-back, non supposizioni).
- **CA-T090-05** — **Import/export runtime** (se in scope): round-trip dichiarato con conteggi/file size aggregati; **fuori scope** esplicitato nel task se non eseguito.
- **CA-T090-06** — **UI copy:** assenza di messaggi Release che promettano stato «completamente sincronizzato» senza evidenza di apply/push confermati (allineamento a TASK-074…TASK-082).
- **CA-T090-07** — **Nessun conflitto silenzioso:** summary o stato UI espone skipped/blocked/conflict secondo policy TASK-082.
- **CA-T090-08** — **Privacy:** evidenze senza dati reali negozio, senza segreti; prefissi **`TASK090_*`** per artifact mutativi futuri dopo collision scan.
- **CA-T090-09** — **No claim globale:** chiusura TASK-090 **non** equivale automaticamente a production-ready **100%** se restano **PARTIAL** non spiegati o **SKIPPED** non motivati.
- **CA-T090-10** — **Anti-automation:** nessuna nuova sync automatica/background/Timer/BGTask/Realtime/polling/worker introdotta per «completare» l’acceptance.
- **CA-T090-UX-01** — Il planning identifica almeno un **controllo UX/UI statico** sui flussi utente toccati da TASK-090, oppure spiega perché non è pertinente.
- **CA-T090-UX-02** — Le **future** scelte tra alternative equivalenti sono risolte dal Planner scegliendo l’opzione più **iOS-native**, coerente con lo stile esistente e meno rischiosa per l’utente.
- **CA-T090-UX-03** — Ogni **CTA futura** ha significato chiaro e non ambiguo; evitare «sync» generico dove l’azione reale è pull, push, review, apply o retry.
- **CA-T090-EFF-01** — Il planning descrive come evitare **N+1**, **full scan** ripetuti o lavoro pesante sul **main thread** nelle slice interessate.
- **CA-T090-EFF-02** — Se TASK-090 tocca dataset **medio/grande**, il planning include **feedback rapido**, **cancel/retry** e **progress/counter** privacy-safe.
- **CA-T090-SAFE-01** — Il planning conferma che **nessuna** decisione UX autorizza execution, write Supabase, migrazioni, cleanup o patch Swift **in questo turno**.
- **CA-T090-MATRIX-01** — La futura EXECUTION compila una matrice scenario × direzione × dataset × oggetti × evidenza × esito; nessuno scenario critico può essere dichiarato PASS solo tramite descrizione narrativa.
- **CA-T090-MATRIX-02** — Ogni scenario escluso dal contratto finale è marcato **OUT_OF_SCOPE** con motivo; ogni scenario non eseguito è **NOT_RUN / BLOCKED / SKIPPED** con motivo.
- **CA-T090-PERF-01** — Le operazioni lunghe future mostrano feedback percepibile entro un tempo ragionevole e non bloccano il main thread con parsing, dedupe, export o read-back pesante.
- **CA-T090-RETRY-01** — Retry, riapertura e doppia esecuzione degli scenari `TASK090_*` non generano duplicati logici o identity mapping ambiguo.
- **CA-T090-BOUNDARY-01** — Se per chiudere TASK-090 servono patch Kotlin, SQL/migration o redesign iOS ampio, la review deve segnare **FOLLOW-UP_REQUIRED** invece di allargare TASK-090 in silenzio.
- **CA-T090-PRIORITY-01** — La futura review distingue Must / Should / Could / Out; un elemento Should o Could mancante non può bloccare TASK-090 se i Must sono soddisfatti e il motivo è documentato.
- **CA-T090-A11Y-01** — Qualunque ritocco UI futuro deve preservare leggibilità, target touch, contrasto e label/accessibility text coerenti con l’azione reale.
- **CA-T090-DOD-01** — TASK-090 può essere chiuso solo con handoff finale che separa chiaramente PASS, PARTIAL, BLOCKED_ENV, SKIPPED, OUT_OF_SCOPE e FOLLOW_UP_REQUIRED.

---

## Rischi

- **R90-01 — Regressioni iOS:** modifiche future per acceptance potrebbero rompere manual sync / ProductPrice / export.
- **R90-02 — Divergenza Android:** comportamenti diversi su Room vs SwiftData o timing rete; confronto solo come **DIFF accettabile** documentato.
- **R90-03 — Supabase/schema:** drift RLS o unique constraint non allineati alle assunzioni dei client.
- **R90-04 — Dati reali:** tentazione di usare catalogo negozio per «validazione finale» → vietato senza consenso e task separato.
- **R90-05 — Performance:** accettazione finale confusa con benchmark TASK-089; mantenere separazione scenari.
- **R90-06 — UX:** copy troppo ottimistico o spinner infiniti percepiti.
- **R90-07 — Sync/offline/conflitti:** scenari senza rete o sessione invalida devono essere **BLOCKED** o **PARTIAL** espliciti, non fallimenti silenziosi.
- **R90-08 — Scope creep:** TASK-090 assorbe refactor grandi → da spostare in backlog / task futuri.
- **R90-UX-01 — Redesign da «miglioramento UI»:** miglioramenti UI troppo grandi possono trasformare una slice tecnica in redesign. *Mitigazione:* interventi piccoli, nativi e reversibili.
- **R90-UX-02 — Gergo in UI:** copy troppo tecnico può confondere. *Mitigazione:* UI Release senza gergo tipo DTO, baseline, outbox, RPC, `sync_events` (allineamento task 072…082).
- **R90-EFF-01 — Premature optimization:** ottimizzazioni premature possono complicare il codice. *Mitigazione:* misure semplici, fakeable e verificabili prima di refactor ampi.
- **R90-EFF-02 — Solo metriche tempo:** dataset grande può mascherare bug UX se ci si concentra solo sui tempi. *Mitigazione:* includere anche feedback, cancellazione e recovery.
- **R90-MATRIX-01 — Acceptance vaga:** senza matrice, la review finale rischia di mescolare PASS reali, PARTIAL e NOT_RUN. *Mitigazione:* S90-F obbliga una riga per scenario con esito ammesso e stop gate.
- **R90-RETRY-01 — Retry non idempotente:** una seconda esecuzione può creare duplicati o nascondere un primo errore parziale. *Mitigazione:* S90-I richiede read-back aggregato e zero duplicati logici.
- **R90-BOUNDARY-01 — Scope creep cross-repo:** acceptance finale può diventare refactor Android/Supabase/iOS. *Mitigazione:* S90-J separa i boundary e forza FOLLOW-UP_REQUIRED per cambi backend/Android/redesign ampi.
- **R90-PRIORITY-01 — Tutto diventa bloccante:** senza Must/Should/Could/Out, dettagli utili ma secondari possono impedire la chiusura. *Mitigazione:* sezione priorità release acceptance e CA-T090-PRIORITY-01.
- **R90-A11Y-01 — Polish visivo che peggiora usabilità:** abbellire la UI può ridurre leggibilità o chiarezza. *Mitigazione:* ogni ritocco futuro deve rispettare Dynamic Type, contrasto, target touch e label coerenti.

---

## Integrazione review planning — UX/UI, efficienza e decisioni operative

Questa integrazione rafforza il planning **senza** autorizzare execution. L’obiettivo è evitare una futura patch solo tecnica: ogni **futura** modifica dovrebbe migliorare o preservare l’esperienza **iOS nativa**, restare coerente con lo stile attuale dell’app e ridurre lavoro inutile su dataset grandi.

### Decisioni aggiuntive

- **D90-UX-01 — Scelte UX delegate al Planner/Reviewer:** se durante il planning emergono alternative equivalenti, scegliere l’opzione con migliore **UX iOS nativa**, minore attrito per l’utente e maggiore coerenza con `OptionsView`, `DatabaseView`, `GeneratedView` e i flussi già presenti. Non fermare il planning per micro-scelte visive non rischiose.

- **D90-UX-02 — UI polish consentito solo come piano:** sono ammessi ritocchi **pianificati** di gerarchia visiva, copy, spacing, progress feedback, empty/loading/error state, sheet, toolbar e CTA, ma **in questo turno** non va modificato codice Swift né `Localizable.strings`.

- **D90-UX-03 — Nessun redesign disruptive:** la futura execution non deve copiare Android 1:1 e non deve cambiare drasticamente navigazione, colori o componenti se la UI iOS esistente è già coerente. Preferire miglioramenti piccoli, progressivi e reversibili.

- **D90-EFF-01 — Efficienza prima del polish costoso:** dove possibile, pianificare batch bounded, paginazione, lazy loading, streaming, cancellazione e feedback rapido prima di aggiungere UI complessa.

- **D90-EFF-02 — Evitare N+1 e lavoro ripetuto:** ogni **futura** slice che legge prodotti, prezzi, fornitori o categorie deve indicare come evita query ripetute, caricamenti completi non necessari e recompute pesanti in `MainActor`.

- **D90-SAFE-01 — Mutazioni sempre dietro conferma:** se TASK-090 riguarda flussi mutativi o semi-mutativi, il piano deve mantenere **preview → review → conferma → apply/push → summary** come cutline utente, senza apply silenzioso.

- **D90-SAFE-02 — Planning resta planning:** questa integrazione **non** rende TASK-090 ready for execution e **non** autorizza build/test/runtime/Supabase write.

### Slice aggiuntive da integrare

- **S90-UX-A — Audit statico UX/UI iOS-native**
  - **Scopo:** identificare piccoli miglioramenti di chiarezza visiva e riduzione attrito nel flusso TASK-090.
  - **File da leggere in futura execution:** le View iOS coinvolte dal task, più eventuali ViewModel/adapter già usati dal flusso.
  - **Output atteso:** lista di interventi piccoli, ordinati per impatto utente, **senza patch in planning**.
  - **Stop:** se serve redesign ampio o nuova architettura UI, spostare a task separato.

- **S90-UX-B — Copy e CTA user-facing**
  - **Scopo:** garantire che CTA, warning, summary e stati non usino gergo tecnico visibile all’utente.
  - **Regola:** preferire copy concreto tipo «Rivedi», «Aggiorna questo dispositivo», «Invia modifiche al cloud», «Riprova», «Annulla», coerente con i task 072…082.
  - **Stop:** non modificare localizzazioni in planning.

- **S90-EFF-A — Piano efficienza dataset medio/grande**
  - **Scopo:** indicare come il **futuro** codice eviterà blocchi UI, N+1, full reload inutili e scritture non necessarie.
  - **Tecniche da valutare:** chunking, paging, mappe indicizzate per barcode/remoteID, dedupe preventivo, cancellazione cooperativa, progress feedback entro pochi millisecondi (primo feedback percepito).
  - **Stop:** se serve benchmark reale o device fisico, marcarlo come **evidenza futura**, non come requisito del planning.

- **S90-REC-A — Recovery, cancel e retry**
  - **Scopo:** pianificare stati chiari per successo parziale, errore recuperabile, annullamento e retry.
  - **Regola:** nessuna promessa «tutto sincronizzato» se restano righe saltate, conflitti, rete assente o baseline stale.
  - **Stop:** se recovery richiede nuove policy dati o schema Supabase, spostare a task separato.

### Acceptance criteria aggiuntivi

*(Riflessi anche in § **Acceptance criteria futuri** per tracciabilità unica.)*

- **CA-T090-UX-01** — Il planning identifica almeno un controllo UX/UI statico sui flussi utente toccati da TASK-090, oppure spiega perché non è pertinente.

- **CA-T090-UX-02** — Le future scelte tra alternative equivalenti sono risolte dal Planner scegliendo l’opzione più iOS-native, coerente con lo stile esistente e meno rischiosa per l’utente.

- **CA-T090-UX-03** — Ogni CTA futura ha un significato chiaro e non ambiguo; evitare «sync» generico dove l’azione reale è pull, push, review, apply o retry.

- **CA-T090-EFF-01** — Il planning descrive come evitare N+1, full scan ripetuti o lavoro pesante sul main thread nelle slice interessate.

- **CA-T090-EFF-02** — Se TASK-090 tocca dataset medio/grande, il planning include feedback rapido, cancel/retry e progress/counter privacy-safe.

- **CA-T090-SAFE-01** — Il planning conferma che nessuna decisione UX autorizza execution, write Supabase, migrazioni, cleanup o patch Swift in questo turno.

### Rischi aggiuntivi

*(Riflessi anche in § **Rischi**.)*

- **R90-UX-01:** miglioramenti UI troppo grandi possono trasformare una slice tecnica in redesign. **Mitigazione:** interventi piccoli, nativi e reversibili.

- **R90-UX-02:** copy troppo tecnico può confondere l’utente. **Mitigazione:** UI Release senza gergo come DTO, baseline, outbox, RPC, `sync_events`.

- **R90-EFF-01:** ottimizzazioni premature possono complicare il codice. **Mitigazione:** pianificare misure semplici, fakeable e verificabili prima di introdurre refactor.

- **R90-EFF-02:** dataset grande può mascherare bug UX se ci si concentra solo sui tempi. **Mitigazione:** includere anche feedback, cancellazione e recovery.

---

## Go / No-Go per futura EXECUTION

**GO** solo se **simultaneamente**:

1. **Override esplicito dell’utente** per passare a **ACTIVE / EXECUTION** su **TASK-090** (questo documento resta **NON READY FOR EXECUTION** fino a revisione + override).
2. **Manifest** S90-A e matrice scenario compilati; prefisso **`TASK090_*`** sottoposto a **collision scan** prima di write/seed.
3. **Ambiente:** account/owner/session verificabili **prima** di mutazioni; nessun write «cieco».
4. **Scope:** import/export e cicli Android inclusi o esclusi **esplicitamente** (no ambiguità).
5. **Rollback/stop:** per ogni scenario mutativo, piano stop senza corruzione dati o con cleanup minimo documentato (mai distruttivo massivo non autorizzato).
6. **Matrice S90-F pronta:** ogni scenario ha evidenza minima, esito ammesso e stop gate.
7. **UX decision policy accettata:** eventuali micro-scelte UI sono delegate al criterio iOS-native/coerenza app, senza chiedere conferma su dettagli minori.
8. **Budget efficienza dichiarato:** eventuali operazioni lunghe hanno piano feedback/cancel/retry e nessun lavoro pesante previsto sul `MainActor`.
9. **Boundary chiari:** qualunque necessità di patch Kotlin, SQL/migration o redesign ampio produce FOLLOW-UP_REQUIRED, non ampliamento automatico di TASK-090.

**NO-GO** → resta **PLANNING** o solo evidenze statiche; nessuna promozione a DONE.

---

## Evidenze richieste in futura execution

- Log **aggregati** (tempi, conteggi, esiti), screenshot **redatti**, read-back SQL/parametri **senza** segreti.
- Tabella **scenario × dataset × device × esito × privacy-check** (formato analogo a TASK-087…089).
- Per ogni write: prefisso **`TASK090_*`**, conferma collision scan, sessione/owner recheck.
- **Nessun** dump di righe cliente; **nessun** secret in chiaro.
- Matrice S90-F compilata con esito per scenario, inclusi **OUT_OF_SCOPE**, **PARTIAL**, **BLOCKED_ENV** e **SKIPPED** quando applicabili.
- Per UX/UI: screenshot o descrizione redatta dei principali stati utente solo se prodotti durante futura execution autorizzata; altrimenti audit statico documentato.
- Per performance percepita: tempi aggregati e primo feedback/cancel/retry documentati senza trasformare TASK-090 in benchmark grande dataset.
- Per retry/idempotenza: read-back aggregato che dimostri zero duplicati logici o motivi CHANGES_REQUIRED.
- Per priorità: mini-tabella Must / Should / Could / Out aggiornata con esito finale e motivi dei non eseguiti.
- Per accessibilità/UX: conferma statica che eventuali ritocchi futuri non peggiorano leggibilità, contrasto, target touch o label.

---

## Handoff storico (planning-init — superato da execution/review)

Questa sezione documenta lo stato del solo planning-init. Dopo l'override utente del 2026-05-09 e la review finale, non rappresenta piu' lo stato corrente del task.

| Voce | Valore |
|------|--------|
| **TASK-090** | **ACTIVE / PLANNING** |
| **READY FOR EXECUTION** | **No** — richiede revisione contenuto + **override utente** esplicito |
| **TASK-090 DONE** | **No** |
| **TASK-091** | **non aperto** |
| **Integrazione UX/UI + efficienza** | Aggiunta al planning (sezione *Integrazione review planning*, decisioni **D90-*** , slice **S90-UX/EFF/REC-*** , CA/Rischi aggiuntivi); **resta documentale** e **non** autorizza execution |
| **Refinement aggiuntivo** | Aggiunte slice **S90-F…S90-J** per matrice acceptance, budget UX/performance, policy decisionale UI, idempotenza/retry e boundary iOS/Android/Supabase; **solo planning**, **nessuna execution** |
| **Refinement finale** | Aggiunte priorità Must / Should / Could / Out, guard accessibilità/UX, correzioni Markdown/refusi e criteri DoD; TASK-090 resta PLANNING |
| **Prossimo passo suggerito** | Review del piano (slice, CA, rischi, fuori perimetro, integrazione UX/EFF); aggiornamento MASTER-PLAN se cambia solo tracking; poi eventualmente richiesta override per EXECUTION futura |

**Chiusura voci obbligatorie storiche di planning:** in quel momento TASK-090 restava **ACTIVE / PLANNING**; **NON READY FOR EXECUTION**; **NON DONE**; **TASK-091 non aperto**. Lo stato corrente e' quello della review finale sotto.

---

## Handoff post-execution — TASK-090

Questa sezione fotografa lo stato al termine dell'execution Codex, prima della review finale. La sezione **Review finale — Chiusura** sotto prevale per lo stato corrente.

| Voce | Valore |
|------|--------|
| **TASK-090** | **ACTIVE / REVIEW** |
| **Responsabile attuale** | **Claude / Reviewer** |
| **Decisione proposta pre-review** | **PARTIAL_READY_FOR_REVIEW** |
| **TASK-090 DONE** | **No** |
| **TASK-091** | **non aperto** |
| **Ultimo completato** | **TASK-089 DONE / Chiusura — REVIEW PASS** |

### Modifiche fatte

- Aggiornati tracking e stato fase TASK-090 da EXECUTION a REVIEW.
- Creata/aggiornata evidence folder `docs/TASKS/EVIDENCE/TASK-090/`.
- Compilate matrice S90-F finale, tabella Must/Should/Could/Out, CA evidence, risultati test/build, read-back Supabase aggregato, retry/idempotenza e decisione finale proposta.
- Nessuna patch Swift, Kotlin, SQL/migration/RLS, `Localizable.strings` o UI production.

### Patch applicate

| Area | Patch | Motivo |
|------|-------|--------|
| Swift/iOS | Nessuna | Audit statico, build e test non hanno evidenziato copy falso o bug piccolo necessario per CA-T090 |
| Kotlin/Android | Nessuna | Android solo riferimento funzionale nel perimetro TASK-090 |
| SQL/migration/RLS | Nessuna | Schema letto solo da migration reali; nessun cambio backend autorizzato |
| Localizzazioni | Nessuna | `Localizable.strings` valide e copy Release veritiera |

### File controllati

- Tracking: `docs/MASTER-PLAN.md`, `docs/TASKS/TASK-090-release-acceptance-cross-platform-ios.md`, `docs/TASKS/TASK-089-large-dataset-sync-preview-benchmark-ios.md`, `docs/TASKS/TASK-086-*`, `docs/TASKS/TASK-087-*`, `docs/TASKS/TASK-088-*`.
- iOS manual sync/ProductPrice/export/import: `OptionsView.swift`, `DatabaseView.swift`, `SupabaseManualSyncViewModel.swift`, `SupabaseManualSyncReleaseFactory.swift`, `SupabaseManualSyncCoordinator.swift`, `SupabasePullPreviewService.swift`, `SupabasePullApplyService.swift`, `SupabaseManualPushService.swift`, `SupabaseManualPushPreflightService.swift`, `SupabaseProductPriceApplyService.swift`, `SupabaseProductPriceManualPushService.swift`, `SupabaseProductPricePushDryRunService.swift`, `Localizable.strings`, XCTest correlati.
- Supabase locale read-only: migration reali in `/Users/minxiang/Desktop/MerchandiseControlSupabase/supabase/migrations`.
- Android: solo evidenze/task precedenti TASK-087/TASK-088 come riferimento funzionale; nessuna patch.

### Scenari finali S90-F

| Scenario | Esito | Evidenza |
|----------|-------|----------|
| Catalog pull Supabase -> iOS | PARTIAL | Static review iOS + build/test correnti + TASK-087 prior runtime; nessun nuovo write `TASK090_*` per gate owner/session |
| ProductPrice current/previous Supabase <-> iOS | PASS | TASK-088 runtime + test correnti ProductPrice/manual sync; zero duplicati logici e current/previous coerenti nel perimetro verificato |
| Android -> Supabase -> iOS | PARTIAL | TASK-087 prior runtime; Android runtime fresh non rieseguito |
| iOS -> Supabase -> Android | PARTIAL | TASK-087/TASK-088 prior runtime/reference; nuovo write live non eseguito |
| Import/export runtime iOS app -> file -> app | PARTIAL | Static review `DatabaseView` + TASK-089 synthetic export; round-trip UI manuale non rieseguito |
| UI truthfulness/copy Release | PASS | Audit copy/statico + `plutil` + test; nessuna promessa di sync completa senza apply/push/pull |
| Retry/idempotenza | PARTIAL | ProductPrice PASS; cross-platform fresh retry non rieseguito |
| Privacy/anti-distruttivo | PASS | No dati reali, no segreti, no comandi distruttivi, no sync automatica, no patch fuori scope |

### Must / Should / Could / Out finale

| Priorità | Esito |
|----------|-------|
| Must | PASS/PARTIAL documentato: matrice, copy, privacy e ProductPrice soddisfatti; cross-platform catalogo marcato PARTIAL senza claim falso |
| Should | PARTIAL/BLOCKED_ENV: smoke live `TASK090_*` e import/export UI runtime non eseguiti per gate/costo-beneficio |
| Could | SKIPPED: benchmark extra, UI polish e Android runtime extra non necessari per questa review |
| Out | PASS: nessun redesign, Kotlin, SQL/RLS, full benchmark nuovo o claim 100% |

### CA-T090 finale

| CA | Esito |
|----|-------|
| CA-T090-01 | PASS |
| CA-T090-02 | PASS |
| CA-T090-03 | PARTIAL |
| CA-T090-04 | PASS |
| CA-T090-05 | PARTIAL |
| CA-T090-06 | PASS |
| CA-T090-07 | PASS |
| CA-T090-08 | PASS |
| CA-T090-09 | PASS |
| CA-T090-10 | PASS |
| CA-T090-UX-01 | PASS |
| CA-T090-UX-02 | PASS |
| CA-T090-UX-03 | PASS |
| CA-T090-EFF-01 | PASS |
| CA-T090-EFF-02 | PARTIAL |
| CA-T090-SAFE-01 | PASS |
| CA-T090-MATRIX-01 | PASS |
| CA-T090-MATRIX-02 | PASS |
| CA-T090-PERF-01 | PARTIAL |
| CA-T090-RETRY-01 | PARTIAL |
| CA-T090-BOUNDARY-01 | PASS |
| CA-T090-PRIORITY-01 | PASS |
| CA-T090-A11Y-01 | PASS |
| CA-T090-DOD-01 | PASS |

### Check eseguiti

| Check | Stato | Esito |
|-------|-------|-------|
| Build compila — Debug | ✅ ESEGUITO | PASS, `BUILD SUCCEEDED` |
| Build compila — Release | ✅ ESEGUITO | PASS, `BUILD SUCCEEDED` |
| Nessun warning nuovo introdotto | ⚠️ NON ESEGUIBILE | Verifica assoluta non determinabile senza baseline warning storica; log mostrano solo warning tooling AppIntents e nessuna patch codice e' stata applicata |
| Modifiche coerenti con planning | ✅ ESEGUITO | PASS, intervento limitato a tracking/evidenze |
| Criteri di accettazione verificati | ✅ ESEGUITO | PASS/PARTIAL documentato nella tabella CA e nelle evidence |
| `xcodebuild -list` | ✅ ESEGUITO | PASS |
| XCTest mirati manual sync/ProductPrice/pull/export/localization | ✅ ESEGUITO | PASS, 299 test case nel log mirato, 0 failure |
| Full XCTest | ✅ ESEGUITO | PASS, 567 passed / 0 failed / 0 skipped |
| `git diff --check` | ✅ ESEGUITO | PASS |
| `plutil` Localizable | ✅ ESEGUITO | PASS su IT/EN/ES/zh-Hans |
| Grep `TASK090` su source/test iOS | ✅ ESEGUITO | PASS, nessun match |
| Grep `TASK090` su Release binary | ✅ ESEGUITO | PASS, nessun match |
| Secret scan evidence/tracking | ✅ ESEGUITO | PASS, nessun match token/JWT/service_role/connection string |
| Supabase live read-back `TASK090_*` | ⚠️ NON ESEGUIBILE | BLOCKED_ENV: owner/session/collision scan DB non verificati prima di write sicuro |
| Android runtime fresh | ⚠️ NON ESEGUIBILE | Android fuori target primario; usato solo riferimento TASK-087/TASK-088 |
| Import/export UI manuale app -> file -> app | ⚠️ NON ESEGUIBILE | PARTIAL: static review + TASK-089 evidence, nessuna patch export/import che giustificasse nuovo runtime UI |

### Evidenze prodotte

- `docs/TASKS/EVIDENCE/TASK-090/manifest_acceptance.md`
- `docs/TASKS/EVIDENCE/TASK-090/matrix_s90_f_initial.md`
- `docs/TASKS/EVIDENCE/TASK-090/matrix_s90_f_final.md`
- `docs/TASKS/EVIDENCE/TASK-090/static_preflight_mapping.md`
- `docs/TASKS/EVIDENCE/TASK-090/supabase_schema_readonly.md`
- `docs/TASKS/EVIDENCE/TASK-090/static_ui_copy_audit.md`
- `docs/TASKS/EVIDENCE/TASK-090/scenario_graph.md`
- `docs/TASKS/EVIDENCE/TASK-090/privacy_boundary_log.md`
- `docs/TASKS/EVIDENCE/TASK-090/must_ca_evidence.md`
- `docs/TASKS/EVIDENCE/TASK-090/test_build_results.md`
- `docs/TASKS/EVIDENCE/TASK-090/supabase_readback_aggregated.md`
- `docs/TASKS/EVIDENCE/TASK-090/retry_idempotence.md`
- `docs/TASKS/EVIDENCE/TASK-090/decision_final.md`

### Rischi residui

- Nuovo smoke live `TASK090_*` non eseguito: resta **BLOCKED_ENV/PARTIAL** finche' owner/session/collision scan DB non sono verificabili in modo privacy-safe.
- Cross-platform Android runtime fresh non rieseguito in TASK-090: evidenza basata su TASK-087/TASK-088 come riferimento.
- Import/export manuale UI app -> file -> app non rieseguito: evidenza statica + TASK-089, non PASS runtime completo.
- Warning tooling AppIntents presente nei build log; non attribuibile a TASK-090, ma resta rumore di ambiente.

### Conferme boundary

- Nessun dato reale usato come fixture.
- Nessun segreto stampato.
- Nessun drop/truncate/delete/reset/wipe/backfill massivo.
- Nessuna patch Kotlin.
- Nessuna patch SQL/migration/RLS.
- Nessuna sync automatica/background introdotta.
- Al termine dell'execution, prima della review finale, TASK-090 era **ACTIVE / REVIEW**.
- Lo stato corrente post-review e' documentato sotto come **DONE / Chiusura — PARTIAL_ACCEPTED**.
- TASK-091 **non aperto**.

---

## Review finale — Chiusura

| Voce | Valore |
|------|--------|
| **Decisione finale** | **DONE / Chiusura — PARTIAL_ACCEPTED** |
| **Responsabile** | **Claude / Reviewer** |
| **TASK-090 DONE** | **Si, come acceptance finale documentata con residui runtime accettati** |
| **TASK-091** | **non aperto** |
| **Claim production-ready globale 100%** | **No** |

### File reviewati

- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-090-release-acceptance-cross-platform-ios.md`
- Tutte le evidenze in `docs/TASKS/EVIDENCE/TASK-090/`
- Diff corrente dei tracking/evidence TASK-090
- Check statici su source/test iOS per assenza di harness `TASK090`

### Fix applicati in review

- Chiarito che l'handoff planning-init e le sezioni "futura execution" sono storiche/superate.
- Aggiornata la decisione finale da proposta `PARTIAL_READY_FOR_REVIEW` a chiusura **PARTIAL_ACCEPTED / DONE**.
- Riallineato il tracking in MASTER-PLAN a progetto **IDLE** e ultimo completato **TASK-090**.

### Test/check rieseguiti in review

| Check | Esito |
|-------|-------|
| `git status --short` | PASS, working tree limitato a tracking/evidence TASK-090 non ancora staged |
| `git diff --check` | PASS |
| `xcodebuild -list -project iOSMerchandiseControl.xcodeproj` | PASS |
| Build Debug iPhone 16e iOS 26.2 | PASS, `BUILD SUCCEEDED` |
| Build Release iPhone 16e iOS 26.2 | PASS, `BUILD SUCCEEDED` |
| XCTest mirati manual sync/ProductPrice/pull/export/localization | PASS, 314 test / 0 failure |
| Full XCTest | PASS, 567 test / 0 failure |
| `plutil -lint` Localizable IT/EN/ES/zh-Hans | PASS |
| Grep `TASK090` su source/test iOS | PASS, nessun match |
| Grep `TASK090` su Release binary | PASS, nessun match |
| Secret scan evidence/tracking | PASS, nessun pattern token/JWT/service_role/connection string |
| Warning nuovi | PARTIAL, solo warning tooling AppIntents gia' non attribuito a TASK-090 |

### Decisione

TASK-090 viene chiuso come **PARTIAL_ACCEPTED / DONE** perche':

- la matrice acceptance e' compilata e auditabile;
- ProductPrice current/previous ha evidenza forte da TASK-088 e regressioni correnti;
- UI/copy Release non promette sync completa non verificata;
- privacy, anti-distruttivo e anti-automation sono rispettati;
- gli scenari non rieseguiti sono dichiarati **PARTIAL / BLOCKED_ENV / SKIPPED** con motivo, non come PASS.

### Residui accettati

- Nuovo smoke live `TASK090_*`: **BLOCKED_ENV/PARTIAL** per owner/session/collision scan DB non verificati prima di write sicuro.
- Cross-platform Android runtime fresh: **PARTIAL/SKIPPED**, Android resta riferimento funzionale.
- Import/export UI manuale app -> file -> app: **PARTIAL**, coperto solo da review statica e TASK-089 synthetic evidence.
- Warning tooling AppIntents nei build log: non attribuito a TASK-090.

### Cosa non e' claimato

- Non e' un claim production-ready globale 100%.
- Non e' una validazione live nuova su `TASK090_*`.
- Non e' una prova Android runtime fresh.
- Non e' un round-trip manuale completo import/export tramite UI.

### Stato finale tracking

- TASK-090 **DONE / Chiusura — PARTIAL_ACCEPTED**.
- Progetto riallineato a **IDLE** in MASTER-PLAN.
- **TASK-091 non aperto**.

*File canonico:* `docs/TASKS/TASK-090-release-acceptance-cross-platform-ios.md`
