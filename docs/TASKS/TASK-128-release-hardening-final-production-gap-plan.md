# TASK-128 — Final release hardening / production gap plan

## 0. Planner-review delta — automation-first integration

Review del piano Claude/Codex: **CHANGES_REQUIRED_APPLIED_IN_PLANNING**.

Motivo: il piano originale copriva bene i gap funzionali e tecnici, ma trattava in modo troppo generico la superficie di automazione gia' presente nel progetto. Questa integrazione rende esplicito che le future execution devono usare `mc-agent` come CLI canonica, produrre report Markdown/JSON, rispettare safety gate live/cleanup, redigere dati sensibili e creare/migliorare harness quando manca un comando stabile.

Decisione di planning:

- non eseguire build/test/runtime/Supabase live in TASK-128;
- non aprire TASK-129;
- non dichiarare REVIEW/DONE automaticamente;
- trasformare i gap P0/P1 in futuri task **automation-first**, non in sequenze manuali fragili;
- ogni futura execution deve preferire un comando canonico del progetto; se manca, il task deve prima aggiungerlo o migliorarlo nel harness.

## 1. Stato

| Campo | Valore |
|-------|--------|
| Task ID | TASK-128 |
| Titolo | Final release hardening / production gap plan |
| Stato | DONE / CLOSED_BY_TASK130_CONSOLIDATED_REVIEW |
| Repo iOS target | `/Users/minxiang/Desktop/iOSMerchandiseControl` |
| Repo Android riferimento | `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView` |
| Supabase locale riferimento | `/Users/minxiang/Desktop/MerchandiseControlSupabase` |
| Data creazione | 2026-05-27 |
| Ultimo aggiornamento | 2026-05-28 |
| Ultimo agente | Codex / Final reviewer-fixer |
| Nota | Piano sorgente chiuso tramite TASK-129 e TASK-130 consolidati; nessun claim production-ready globale. |

Stato globale richiesto dal MASTER-PLAN: **ACTIVE**.

Fase corrente: **PLANNING**.

Responsabile attuale: **USER / Accepted closure with TASK-130 notes**.

Questo task raccoglie i gap finali dopo gli audit iOS, Android e Supabase. Non dichiara stato DONE, REVIEW, PASS o production-ready globale.

## 2. Obiettivo

Definire un piano finale di hardening prima di una release veramente solida, usando iOS come target principale, Android come riferimento funzionale e Supabase locale come fonte schema/migration read-only.

Ambiti da pianificare:

- test health Android;
- contratto prezzi current/previous/old;
- golden corpus import/export cross-platform;
- performance import e SwiftData lookup;
- hardening Supabase reale/offline/background/locked screen;
- UX Options first-sync checklist;
- scanner/accessibility/Dynamic Type;
- cleanup architetturale progressivo senza mega-refactor.

TASK-128 deve chiudersi solo come piano verificabile e pronto per una futura execution. La futura execution dovra' aprire task separati e non puo' essere implicita in questo documento.

## 2A. Chiusura consolidata

2026-05-28: TASK-128 e' chiuso **DONE / CLOSED_BY_TASK130_CONSOLIDATED_REVIEW**.

Il piano sorgente e' stato eseguito attraverso TASK-129 e TASK-130 per override esplicito utente. I gap residui che il piano originariamente avrebbe distribuito su TASK-131/TASK-135 sono stati consolidati nel ledger finale di TASK-130, senza aprire nuovi task.

Evidence finale: `docs/TASKS/EVIDENCE/TASK-130/final-review-done-closure.md`.

Nessun claim production-ready globale.

## 3. Fonti da leggere

Checklist read-only obbligatoria per futura execution. Se un path cambia, aggiornare il task futuro prima di modificare codice.

### iOS target principale

- [ ] `docs/MASTER-PLAN.md`
- [ ] `docs/TASKS/TASK-103-final-real-device-cross-platform-acceptance-ios-supabase-android.md`
- [ ] `docs/TASKS/TASK-123-ios-android-simulator-autosync-speed-acceptance.md`
- [ ] `docs/TASKS/TASK-126-sync-policy-multistore-cache-mvp.md`
- [ ] `docs/TASKS/TASK-127-ios-options-responsiveness-sync-summary-performance.md`
- [ ] `iOSMerchandiseControl/Models.swift`
- [ ] `iOSMerchandiseControl/HistoryEntry.swift`
- [ ] `iOSMerchandiseControl/ContentView.swift`
- [ ] `iOSMerchandiseControl/InventoryHomeView.swift`
- [ ] `iOSMerchandiseControl/ExcelSessionViewModel.swift`
- [ ] `iOSMerchandiseControl/PreGenerateView.swift`
- [ ] `iOSMerchandiseControl/GeneratedView.swift`
- [ ] `iOSMerchandiseControl/DatabaseView.swift`
- [ ] `iOSMerchandiseControl/ProductImportCore.swift`
- [ ] `iOSMerchandiseControl/ProductPriceHistoryView.swift`
- [ ] `iOSMerchandiseControl/OptionsView.swift`
- [ ] `iOSMerchandiseControl/Sync/**`
- [ ] `iOSMerchandiseControl/LocalPendingChange.swift`
- [ ] test iOS esistenti import/sync/ProductPrice/export.

### Android riferimento funzionale

- [ ] `AppDatabase.kt`
- [ ] `InventoryRepository.kt`
- [ ] `ProductPriceSummary.kt`
- [ ] `DatabaseViewModel.kt`
- [ ] `ExcelViewModel.kt`
- [ ] `ExcelUtils.kt`
- [ ] `ImportAnalysis.kt`
- [ ] `ImportAnalyzer` / import analysis equivalente se presente.
- [ ] `DatabaseScreen.kt`
- [ ] `GeneratedScreen.kt`
- [ ] sync/autosync coordinators se presenti, inclusi `CatalogAutoSyncCoordinator.kt`, `SupabaseSyncEventRealtimeSubscriber.kt`, `CatalogSyncViewModel.kt`.
- [ ] Gradle/test config per broad unit tests, inclusi `app/build.gradle.kts`, `gradle.properties`, `settings.gradle.kts`.

### Supabase locale riferimento

- [ ] migrations locali in `/Users/minxiang/Desktop/MerchandiseControlSupabase/supabase/migrations/`
- [ ] SQL reference in `/Users/minxiang/Desktop/MerchandiseControlSupabase/sql/`
- [ ] schema tabelle catalogo/products/suppliers/categories:
  - `inventory_products`
  - `inventory_suppliers`
  - `inventory_categories`
- [ ] schema prezzi/storico/sync:
  - `inventory_product_prices`
  - `shared_sheet_sessions`
  - `sync_events`
- [ ] RLS/grants/RPC solo read-only, inclusi:
  - `20260417120000_task013_inventory_catalog_rls.sql`
  - `20260417200000_task016_inventory_product_prices.sql`
  - `20260421120000_task038_restrict_authenticated_delete_inventory.sql`
  - `20260424021936_task045_sync_events.sql`
  - `20260522032909_task114_sync_events_history.sql`

## 4. Stato attuale sintetico

iOS e' gia' molto avanzato: contiene SwiftData models, import Excel/HTML/XLS/XLSX, PreGenerate, Generated inventory, Database import/export, ProductPrice, HistoryEntry, Supabase manual/automatic sync, account review, pending changes e outbox.

Android e' funzionalmente completo e ora anche sync-aware. In TASK-123 e nei task successivi e' stato usato come riferimento runtime/funzionale, non come sorgente da copiare 1:1 in SwiftUI.

Supabase e' gia' integrato nel perimetro P0 cross-platform. Le migrations locali confermano tabelle catalogo, `inventory_product_prices`, `shared_sheet_sessions`, `sync_events`, RLS owner-scoped e restrizioni su hard delete authenticated.

Il problema residuo non e' "mancano schermate base". Il problema residuo e' release hardening: salute test, contratti dati, corpus ripetibile, performance su dataset grandi e condizioni reali non ancora coperte in modo globale.

### Gia' coperto da TASK-103 / TASK-123 / TASK-127

- TASK-103: perimetro P0 cross-platform Supabase con dati sintetici e acceptance iOS/Supabase/Android; non equivale a production-ready globale dell'app.
- TASK-123: autosync speed su iOS Simulator + Android Emulator + Supabase live/dev same-account, con acceptance di velocita'; non copre real device globale, long background/locked screen, long offline, policy conflitti complessa o multi-account/multi-user.
- TASK-127: performance Options iOS e summary sync, con note accettate; non copre checklist first-sync completa o real-device UX globale.

### Ancora non coperto

- Android broad `testDebugUnitTest` verde/stabile oppure quarantena formale.
- Contratto unico current/last/previous/old price su iOS, Android e Supabase.
- Golden corpus import/export cross-platform, versionato e privacy-safe.
- Benchmark import/pre-generate su dataset grandi e lookup SwiftData non degradanti.
- Hardening real-device lungo: foreground/background 30-60 minuti, locked screen, offline lungo, reconnect, delete/tombstone e conflitti.
- UX first-sync checklist completa in Options.
- Scanner real-device edge cases, accessibilita', Dynamic Type, localizzazioni lunghe.

### Da verificare

- Se il problema Android broad test e' ancora ByteBuddy/attach con la configurazione corrente oppure se esistono regressioni nuove.
- Se `ProductPriceSummary` Android espone solo "last" oppure se serve calcolo esplicito "previous" distinto in UI/export.
- Se iOS PreGenerate old price deve restare snapshot del current DB al momento della generazione o se serve una decisione di prodotto diversa.
- Se lo schema Supabase live corrisponde esattamente alle migrations locali usate come riferimento.
- Se le restrizioni delete/tombstone sono sufficienti per i flussi real-device futuri senza hard delete authenticated.

### Follow-up execution futuro

La execution deve essere spezzata in task piccoli e tracciabili, proposti in sezione 9. TASK-128 non apre quei task e non implementa codice.

## 4A. Strategia automation-first / harness canonico

### 4A.1 Fonte canonica operativa

La fonte canonica per future execution e' `./tools/agent/mc-agent.sh`.

Il piano non deve chiedere a Codex/Cursor/Claude di ricostruire manualmente comandi lunghi se esiste gia' un wrapper. Il harness deve essere usato per:

- preflight e head consistency;
- build iOS/Android;
- test mirati;
- smoke UI;
- verifiche Supabase schema/RLS/grants/RPC/realtime;
- sync counts e drift/reconcile;
- live matrix;
- cleanup scoped;
- residue check;
- report Markdown/JSON;
- redaction e scan sicurezza.

MCP, quando usato, resta wrapper sottile sopra `mc-agent`: non deve duplicare logica di safety, redaction, build/test o cleanup.

### 4A.2 Preflight obbligatorio per ogni task futuro

Ogni task di execution derivato da TASK-128 deve iniziare con questi gate, adattando `TASK-129`, `TASK-130`, ecc. al task reale:

```bash
MC_TASK_ID=TASK-129 ./tools/agent/mc-agent.sh help-json
MC_TASK_ID=TASK-129 ./tools/agent/mc-agent.sh list commands-json
MC_TASK_ID=TASK-129 ./tools/agent/mc-agent.sh config validate
MC_TASK_ID=TASK-129 ./tools/agent/mc-agent.sh git head-consistency --task TASK-129
MC_TASK_ID=TASK-129 ./tools/agent/mc-agent.sh preflight --require-head-consistency --task TASK-129
```

Se uno di questi comandi fallisce:

- `FAIL`: correggere il problema interno o fermare il task in FIX;
- `BLOCKED_EXTERNAL`: documentare next action e non procedere a runtime;
- `MISCONFIGURED`: correggere config/comando, non aggirare con shell manuale;
- `UNSAFE_OPERATION_REFUSED`: rispettare il blocco e cambiare scope/prefix/gate.

### 4A.3 Report/evidence obbligatori

Ogni comando canonico deve produrre:

- `RESULT`
- `EXIT_CODE`
- `REPORT_MD`
- `REPORT_JSON`
- `NEXT_ACTION`

I report devono vivere sotto:

```text
docs/TASKS/EVIDENCE/<TASK-ID>/agent-runs/
```

La chiusura di un futuro task non puo' basarsi solo su testo narrativo. Deve puntare a report JSON/Markdown del harness oppure spiegare perche' il caso e' `NOT_RUN` o `BLOCKED_EXTERNAL`.

Comandi finali minimi per ogni futura execution:

```bash
./tools/agent/mc-agent.sh scan sensitive --task TASK-129 docs/TASKS/EVIDENCE/TASK-129
./tools/agent/mc-agent.sh scan evidence --task TASK-129
./tools/agent/mc-agent.sh report validate-json --task TASK-129 --path docs/TASKS/EVIDENCE/TASK-129/agent-runs
```

Se `report validate-json` non copre un nuovo tipo di JSON prodotto dal task, il task deve aggiornare lo schema/validatore invece di lasciare evidence non validata.

### 4A.4 Regola: comando esistente vs comando mancante

Per ogni scenario futuro, il piano/execution deve classificare lo strumento così:

| Stato strumento | Regola |
|-----------------|--------|
| `EXISTS_REUSE` | usare il comando canonico, non duplicare shell manuale |
| `EXISTS_INCOMPLETE` | migliorare il comando/harness prima di usarlo come evidence finale |
| `MISSING_REQUIRED` | creare nuovo comando nel harness, documentarlo in README/help-json e aggiungere test/scan minimi |
| `MANUAL_ONE_OFF_ALLOWED` | permesso solo se realmente unico, con motivazione `NO_CANONICAL_HARNESS` e output redatto |
| `FORBIDDEN_WORKAROUND` | vietato aggirare safety/live/cleanup/redaction con comandi raw |

Qualsiasi sequenza manuale ripetuta piu' di una volta deve diventare comando `mc-agent` o subcomando MCP allowlisted.

### 4A.5 Comandi gia' riutilizzabili

Comandi gia' esistenti o documentati da riusare nelle future execution:

```bash
./tools/agent/mc-agent.sh ios build debug|release
./tools/agent/mc-agent.sh ios test sync|automatic-domain|automatic-architecture|lifecycle|offline
./tools/agent/mc-agent.sh ios smoke simulator|options|history

./tools/agent/mc-agent.sh android build debug|release
./tools/agent/mc-agent.sh android test sync|offline
./tools/agent/mc-agent.sh android offline-write|reconnect-drain --tier L1|L2|L3 --prefix TASKNNN_OFFLINE_*

./tools/agent/mc-agent.sh supabase status-redacted
./tools/agent/mc-agent.sh supabase verify-schema --profile local|linked|dry-run-no-db
./tools/agent/mc-agent.sh supabase verify-rls --profile local|linked|dry-run-no-db
./tools/agent/mc-agent.sh supabase verify-grants --profile local|linked|dry-run-no-db
./tools/agent/mc-agent.sh supabase verify-rpc --profile local|linked|dry-run-no-db
./tools/agent/mc-agent.sh supabase verify-realtime --profile local|linked|dry-run-no-db

./tools/agent/mc-agent.sh sync counts --task TASKNNN --source supabase|android|ios --profile linked
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh live reconcile-counts --task TASKNNN --prefix TASKNNN_RECON_
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh live sync-matrix --task TASKNNN --prefix TASKNNN_MATRIX_

./tools/agent/mc-agent.sh supabase cleanup --task TASKNNN --prefix TASKNNN_* --dry-run
MC_ALLOW_CLEANUP=1 ./tools/agent/mc-agent.sh supabase cleanup --task TASKNNN --prefix TASKNNN_* --execute --cleanup-plan-id <id>
./tools/agent/mc-agent.sh supabase residue-check --task TASKNNN --prefix TASKNNN_* --profile linked
```

### 4A.6 Comandi/harness da creare o migliorare nei futuri task

TASK-128 non li implementa, ma i futuri task devono prevederli se non esistono ancora:

| Futuro task | Comando/harness richiesto | Motivo |
|-------------|---------------------------|--------|
| TASK-129 | `android test broad --task TASK-129` | evitare comandi Gradle raw per broad suite e ByteBuddy/attach diagnosis |
| TASK-129 | `android test quarantine-report --task TASK-129` | distinguere PASS, FAIL, quarantena tecnica e CI stable command |
| TASK-130 | `scan price-contract --task TASK-130 --strict` | verificare current/last/previous/old su iOS/Android/Supabase |
| TASK-130 | `ios test price-contract --task TASK-130` e `android test price-contract --task TASK-130` | rendere il contratto prezzi testabile su entrambi i client |
| TASK-131 | `harness golden-corpus validate --task TASK-131 --platform ios|android|both` | validare fixture import/export senza sequenze manuali |
| TASK-131 | `harness golden-corpus roundtrip --task TASK-131 --direction ios-to-android|android-to-ios` | evidence cross-platform ripetibile |
| TASK-132 | `ios benchmark import-large --task TASK-132 --fixture <name>` | misurare tempo/memoria/progress/cancel su dataset grandi |
| TASK-132 | `scan swiftdata-fetch-budget --task TASK-132 --strict` | bloccare regressioni fetch-all/MainActor |
| TASK-133 | `live real-device-long-offline --task TASK-133 --prefix TASK133_OFFLINE_` | coprire offline lungo/reconnect con read-back |
| TASK-133 | `live real-device-locked-background --task TASK-133 --prefix TASK133_BG_` | distinguere limiti iOS scheduler da bug app |
| TASK-134 | `ios smoke options-first-sync --task TASK-134` | verificare checklist first-sync e CTA |
| TASK-135 | `ios smoke scanner-edge --task TASK-135` e `ios smoke accessibility --task TASK-135` | rendere scanner/a11y evidence-driven |

Ogni nuovo comando deve:

- comparire in `help-json` e `list commands-json`;
- produrre report schema `1.1`;
- usare exit code canonici;
- redigere token/email/JWT/path/device/project ref;
- avere README o help sintetico;
- essere testabile con fixture RED/GREEN quando e' uno scanner statico.

### 4A.7 UX da operatore/agent

I futuri comandi devono essere agent-friendly:

- output console <= 30 righe salvo `--verbose`;
- errori con `NEXT_ACTION` operativo;
- path report relativi e copiabili;
- niente stacktrace enorme in chat;
- summary ad alto segnale;
- esempi one-line nel task e nel README;
- `PASS_WITH_NOTES` ammesso solo con nota residua esplicita e non per nascondere un P0 fallito.

## 4B. Safety, redaction e tassonomia stati

### 4B.1 Prefissi e dati test

Ogni live test futuro deve usare prefissi scoped:

```text
TASK129_*
TASK130_PRICE_*
TASK131_CORPUS_*
TASK132_LARGE_*
TASK133_OFFLINE_*
TASK134_OPTIONS_*
TASK135_SCANNER_
```

Vietati:

- dati reali del negozio;
- prefissi globali;
- cleanup su wildcard non TASK;
- raw SQL distruttivo;
- reset DB;
- `truncate`;
- `auth.users`;
- `service_role` nel client;
- bypass RLS.

### 4B.2 Gate live e cleanup

Live write/matrix:

```bash
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh live <command> --task TASKNNN --prefix TASKNNN_*
```

Cleanup execute:

```bash
./tools/agent/mc-agent.sh supabase cleanup --task TASKNNN --prefix TASKNNN_* --dry-run
MC_ALLOW_CLEANUP=1 ./tools/agent/mc-agent.sh supabase cleanup --task TASKNNN --prefix TASKNNN_* --execute --cleanup-plan-id <id>
./tools/agent/mc-agent.sh supabase residue-check --task TASKNNN --prefix TASKNNN_* --profile linked
```

Cleanup execute senza dry-run precedente e matching `cleanup_plan_id` deve restare `UNSAFE_OPERATION_REFUSED`.

### 4B.3 Redaction obbligatoria

Evidence committabile non deve contenere:

- token/JWT/Bearer;
- `access_token`, `refresh_token`, `anon_key`, `service_role`;
- email reali;
- project ref raw;
- seriali device raw;
- path personali `/Users/<nome>/...`;
- URL con token/query sensibili;
- dati reali del negozio.

Se un comando produce output non redatto, il task futuro deve correggere `redact.sh` o il report writer, non cancellare manualmente pezzi di log.

### 4B.4 Tassonomia stati

| Stato | Uso corretto |
|-------|--------------|
| `PASS` | criterio verificato da comando/evidence affidabile |
| `FAIL` | bug/regressione interna o acceptance non soddisfatta |
| `BLOCKED_EXTERNAL` | device/auth/Supabase/toolchain esterni non disponibili, con next action |
| `MISCONFIGURED` | comando/config errati, da correggere prima di runtime |
| `UNSAFE_OPERATION_REFUSED` | safety gate ha bloccato operazione pericolosa |
| `PASS_WITH_NOTES` | criterio passa con limite non P0, esplicitamente accettabile |
| `NOT_RUN` | non eseguito; non contribuisce a PASS |
| `SKIPPED_BY_SCOPE` | fuori perimetro documentato, non usabile come prova |
| `PARTIAL` | esiste copertura incompleta; richiede follow-up o accettazione esplicita |

### 4B.5 Condizioni REVIEW/DONE future

Un task futuro puo' andare in `ACTIVE / REVIEW` solo se:

- tutti i P0 del task sono `PASS` oppure `BLOCKED_EXTERNAL` con next action non correggibile nel task;
- tutti i report JSON validano;
- `scan sensitive` e `scan evidence` passano;
- cleanup/residue sono completati o esplicitamente `NOT_APPLICABLE`;
- i limiti residui sono scritti in handoff.

Un task futuro puo' andare in `DONE` solo dopo review/accettazione esplicita e senza trasformare `NOT_RUN`, `PARTIAL` o `PASS_WITH_NOTES` in `PASS`.

TASK-128 stesso resta planning-only e non puo' dichiarare DONE in questa integrazione.

## 4C. Tracking, MASTER-PLAN ed evidence integrity

### 4C.1 Canonical source rule

Prima di qualunque futura execution, l'agente deve distinguere:

- `GITHUB_CANONICAL`: file/task presente su GitHub `origin/main`;
- `LOCAL_CANONICAL`: file locale committato ma non ancora confermato su GitHub;
- `UPLOADED_REVIEW_COPY`: file caricato in chat o sandbox, utile per review ma non automaticamente canonico;
- `STALE_OR_SUPERSEDED`: file storico superato da task/evidence successivi.

Se TASK-128 o un task futuro non e' ancora presente su GitHub, il piano deve dirlo chiaramente e non deve affermare che GitHub contiene quel file. La futura execution deve chiudere il gap local/origin/GitHub prima di modificare codice runtime.

### 4C.2 MASTER-PLAN consistency

Ogni task futuro deve aggiornare `docs/MASTER-PLAN.md` in modo coerente:

- un solo task active alla volta, salvo eccezione esplicita;
- ultimo task completato non deve essere sovrascritto da un task in PLANNING;
- stato/fase/responsabile/data devono corrispondere al file task;
- la roadmap proposta non equivale ad apertura automatica di TASK-129...135;
- ogni chiusura REVIEW/DONE deve avere riferimento a evidence pack e verdict.

Se esiste gia' uno scanner `master-plan-consistency`, usarlo. Se non copre TASK-128/TASK-129, estenderlo invece di fare controllo manuale fragile.

### 4C.3 Evidence ledger obbligatorio

Ogni task futuro deve avere un indice evidence leggibile:

```text
docs/TASKS/EVIDENCE/<TASK-ID>/README.md
```

Contenuto minimo:

- lista report `agent-runs/*.json` e `agent-runs/*.md`;
- matrice scenario → report → risultato;
- elenco `PASS`, `FAIL`, `BLOCKED_EXTERNAL`, `NOT_RUN`, `PASS_WITH_NOTES`;
- note di redaction;
- cleanup plan/residue se applicabile;
- limiti residui accettati o da accettare.

La frase "file controllati" nel task non basta: deve esserci un report o una nota read-only verificabile. Se una lettura e' stata manuale, indicarla come `MANUAL_READ_NOTE`, non come evidence automatica.

### 4C.4 Dirty state e patch boundary

Prima di una futura patch runtime:

- verificare dirty state iOS, Android e Supabase;
- non sovrascrivere modifiche utente non committate;
- se si tocca piu' di una repo, ogni repo deve avere preflight/head/evidence separati;
- se una repo non e' leggibile o non e' allineata con GitHub, il task deve fermarsi in `BLOCKED_EXTERNAL_HEAD_MISMATCH` o `MISCONFIGURED`, non procedere a patch parziali.

## 4D. Template obbligatorio per TASK-129...135

Ogni task futuro derivato da TASK-128 deve includere queste sezioni, prima di EXECUTION:

```text
## Automation contract
- Comandi gia' esistenti da usare
- Comandi mancanti da creare/migliorare
- Report attesi
- Safety gate
- Exit code mapping

## Dataset / prefix policy
- Prefix TASKNNN_*
- Collision scan
- Dati sintetici
- Cleanup/residue strategy

## Scenario matrix
- Scenario
- Comando
- Evidence path
- Expected PASS/FAIL/BLOCKED
- Retry/fix rule

## Acceptance matrix
- P0 criteria
- P1 criteria
- NOT_RUN/SKIPPED/PASS_WITH_NOTES consentiti
- REVIEW gate
- DONE gate

## Risk / rollback / no-op plan
- Come tornare allo stato precedente
- Come non lasciare pending/outbox/residue
- Come evitare patch non necessarie
```

Un task futuro non puo' passare da PLANNING a EXECUTION se questa struttura manca o se rinvia i comandi a "da decidere" senza motivazione.

## 4E. MCP / CLI governance

La CLI `mc-agent` resta fonte canonica. Il wrapper MCP puo' essere usato solo se:

- espone un sottoinsieme allowlisted dei comandi CLI;
- non cambia `MC_ALLOW_LIVE` o `MC_ALLOW_CLEANUP`;
- non accetta shell arbitrary string;
- usa argv array e timeout;
- produce o ritorna path ai report CLI;
- ha test `npm test` quando il wrapper viene modificato.

Se un futuro task aggiunge un comando `mc-agent`, deve valutare se serve anche esposizione MCP. Se si', aggiornare allowlist e documentazione. Se no, indicare `MCP_NOT_REQUIRED` con motivo.

## 4F. UX/UI planning guard

Per task UI/UX futuri, i miglioramenti devono essere nativi iOS e misurabili:

- dichiarare journey utente prima/dopo;
- evitare clone Compose;
- includere empty/loading/error state;
- includere Dynamic Type e testi lunghi;
- includere copy localizzato o piano localizzazione;
- includere smoke/screenshot o fallback manuale redatto;
- dichiarare cosa non cambia funzionalmente.

Per strumenti interni, la UX e' quella dell'operatore/agent:

- comandi one-line;
- summary breve;
- next action utile;
- output non rumoroso;
- README aggiornato;
- esempi Cursor/Codex/Claude;
- errori leggibili e coerenti.

## 5. Gap P0 — release blocker / prima della release solida

### P0.1 Android broad test health

Problema:

- Targeted tests/build passano nel perimetro storico, ma broad `testDebugUnitTest` Android non deve restare rosso/instabile.
- In TASK-123 e audit collegati il broad test Android era rosso/instabile con failure class osservata ByteBuddy/attach, mentre build e targeted sync erano PASS.

Obiettivo:

- Rendere test broad verdi oppure isolare formalmente i test JVM/ByteBuddy/attach non affidabili.

Acceptance futura:

- Android `assembleDebug` PASS.
- Android targeted sync PASS.
- Android broad unit suite PASS oppure quarantena documentata con motivazione tecnica, scope preciso e comando CI alternativo stabile.
- Nessun PASS inventato: se broad resta rosso, il task futuro deve dichiarare quarantena e non mascherarla.

File:

- Android Gradle config: `app/build.gradle.kts`, root `build.gradle.kts`, `gradle.properties`, `settings.gradle.kts`.
- Test JVM sotto `app/src/test/java/**`.
- Test MockK/ByteBuddy/Room coinvolti.
- `AppDatabase.kt`, `InventoryRepository.kt`, sync/autosync tests.

Automation richiesta per TASK-129:

- prima verificare se esiste un comando canonico per broad Android test con `help-json` / `commands-json`;
- se non esiste, creare `android test broad --task TASK-129`;
- il comando deve impostare JBR/ByteBuddy/attach in modo centralizzato, produrre report JSON/Markdown e distinguere:
  - broad PASS;
  - broad FAIL reale;
  - ByteBuddy/attach BLOCKED/MISCONFIGURED;
  - quarantena tecnica esplicita con lista test e comando CI stabile;
- vietato chiudere TASK-129 con comandi Gradle raw sparsi nel testo senza wrapper.

### P0.2 Contratto prezzi current / previous / old

Problema:

- iOS usa `Product.purchasePrice` / `Product.retailPrice` + `ProductPrice`.
- Android espone current price nel prodotto e last/previous via `ProductPriceSummary` o flow collegati.
- Android storicamente ha campi `oldPurchasePrice` / `oldRetailPrice` in alcune migration/flow.
- iOS import legge `oldPurchasePrice` / `oldRetailPrice` e crea history `IMPORT_PREV`, ma serve un contratto unico e testabile.

Regola unica proposta per futura review/execution:

- current price = `Product.purchasePrice` / `Product.retailPrice`;
- last price = ultimo `ProductPrice` per type/effectiveAt;
- previous price = penultimo `ProductPrice` per type/effectiveAt;
- `oldPurchasePrice` / `oldRetailPrice` in griglia/import = snapshot/import input, non fonte primaria remota;
- PreGenerate old price = snapshot del current DB al momento della generazione, salvo decisione esplicita diversa.

Acceptance futura:

- Matrice Android ↔ iOS ↔ Supabase campo-per-campo.
- Test su nuovo prodotto.
- Test update prezzo.
- Test import con `oldPurchasePrice` / `oldRetailPrice`.
- Test export/import full DB.
- Test Supabase round-trip con `inventory_products.purchase_price`, `inventory_products.retail_price`, `inventory_product_prices.price`, `type`, `effective_at`.
- Nessuna modifica schema senza task dedicato.

File:

- iOS: `Models.swift`, `ProductImportCore.swift`, `ExcelSessionViewModel.swift`, `ProductPriceHistoryView.swift`, export/import tests.
- Android: `ProductPriceSummary.kt`, `InventoryRepository.kt`, DAO/Product models, `AppDatabase.kt`.
- Supabase: `20260417120000_task013_inventory_catalog_rls.sql`, `20260417200000_task016_inventory_product_prices.sql`, eventuali migrations successive.

Automation richiesta per TASK-130:

- se non esiste, creare `scan price-contract --task TASK-130 --strict`;
- se non esistono, aggiungere test wrapper `ios test price-contract --task TASK-130` e `android test price-contract --task TASK-130`;
- usare `supabase contract sync-schema --task TASK-130 --read-only` o nuovo `supabase contract price-schema --task TASK-130 --read-only` se serve una verifica piu' specifica;
- ogni report deve includere una matrice:
  - campo locale iOS;
  - campo locale Android;
  - colonna Supabase;
  - semantica;
  - fonte di verita';
  - stato PASS/FAIL/PARTIAL/NOT_RUN.

### P0.3 Golden corpus import/export cross-platform

Obiettivo:

Creare un corpus sintetico, privacy-safe, versionato, per testare:

- XLSX normale;
- HTML Excel;
- legacy XLS;
- barcode scientific notation;
- prezzi punto/virgola;
- discount / discountedPrice;
- duplicati barcode;
- missing barcode;
- missing productName + secondProductName;
- missing/invalid retail price;
- quantita' negative;
- full DB export con Products/Suppliers/Categories/PriceHistory;
- iOS export → Android import;
- Android export → iOS import.

Acceptance futura:

- Corpus documentato.
- Test o harness ripetibile.
- Zero dati reali.
- Risultati attesi per new/update/error/warning/price history.
- Fixture versionate con naming chiaro, ad esempio `fixtures/golden-import-export/TASK131_*` o path equivalente approvato nel task futuro.
- Ogni caso deve dichiarare expected rows, expected warnings/errors, expected price history e expected export sheets.

File:

- iOS import/export tests.
- Android import/export tests.
- iOS `ExcelSessionViewModel.swift`, `ProductImportCore.swift`, `DatabaseView.swift`.
- Android `ExcelUtils.kt`, `ExcelViewModel.kt`, `ImportAnalysis.kt`, `DatabaseViewModel.kt`.
- Fixture directory da proporre nel planning del task futuro.

Automation richiesta per TASK-131:

- definire manifest fixture `fixtures/golden-import-export/README.md`;
- se non esiste, creare comando `harness golden-corpus validate`;
- se non esiste, creare comando `harness golden-corpus roundtrip`;
- ogni fixture deve produrre expected JSON con:
  - input rows;
  - normalized header;
  - expected new/update/error/warning;
  - expected ProductPrice;
  - expected export sheets;
  - expected cross-platform delta;
- le fixture devono essere sintetiche, piccole, deterministiche e prive di dati reali.

### P0.4 Hardening sync reale/offline/background

Obiettivo:

Pianificare una futura execution real-life:

- iPhone fisico + Android fisico;
- app foreground;
- app background 30-60 minuti;
- locked screen;
- offline lungo;
- reconnect;
- doppia modifica stesso prodotto;
- delete/tombstone prodotto/sessione;
- no drift finale iOS ↔ Supabase ↔ Android.

Acceptance futura:

- Zero duplicate logical keys.
- Zero pending/outbox stuck.
- Zero drift scoped.
- Conflict cases non silenziosi.
- UI mostra stato comprensibile.
- Evidenza separata per foreground, background, locked screen, long offline, reconnect e delete/tombstone.
- Nessun claim background iOS PASS se il sistema operativo non concede realmente execution; usare `BLOCKED_EXTERNAL_IOS_SCHEDULER_POLICY` se necessario.

Non implementare in TASK-128.

Automation richiesta per TASK-133:

- riusare i comandi live real-device gia' presenti quando coprono il caso:
  - `real-device-realtime`;
  - `real-device-offline-reconnect`;
  - `real-device-background-sync`;
  - `real-device-kill-restart-pending`;
  - `real-device-network-flapping`;
- se non coprono long offline/background/locked screen 30-60 minuti, estenderli invece di creare sequenze manuali;
- ogni live run deve avere:
  - auth preflight iOS e Android;
  - device state redatto;
  - prefix scoped;
  - collision scan;
  - read-back Supabase;
  - sync counts iOS/Android/Supabase;
  - cleanup dry-run/execute se sono stati creati dati;
  - residue-check finale;
  - final drift matrix.

### P0.5 Harness coverage / automation debt

Problema:

- TASK-128 originale elenca bene i gap, ma senza una mappa completa comando-per-gap i futuri agenti rischiano di usare shell raw, comandi lunghi, output non redatti o evidence non validata.
- Il progetto dispone gia' di `mc-agent`, MCP wrapper, report schema e safety gate; il piano deve obbligare al loro uso.

Obiettivo:

- Ogni gap P0/P1 deve dichiarare quali comandi esistono, quali vanno creati, quali report produrre e quali safety gate rispettare.

Acceptance futura:

- Ogni task derivato da TASK-128 contiene una tabella `Automation contract`.
- Ogni nuovo comando compare in `help-json` e `commands-json`.
- Ogni report JSON valida schema.
- Ogni live/cleanup usa `MC_ALLOW_LIVE` / `MC_ALLOW_CLEANUP`.
- Nessun command workaround raw ripetitivo senza conversione in harness.

### P0.6 Tracking/evidence integrity

Problema:

- TASK-128 e i task futuri possono diventare difficili da revisionare se dichiarano letture, test o stato repo senza un evidence ledger verificabile.
- Il piano attuale distingue meglio automation e safety, ma deve rendere obbligatorio anche il controllo di coerenza tra GitHub, local, MASTER-PLAN, task file ed evidence.

Obiettivo:

- Rendere ogni futura execution auditabile senza fidarsi del solo handoff testuale dell'agente.

Acceptance futura:

- `docs/MASTER-PLAN.md` e file task coerenti.
- `docs/TASKS/EVIDENCE/<TASK-ID>/README.md` presente.
- Report JSON/Markdown indicizzati.
- Nessuna evidence fuori task dir salvo motivazione.
- Nessun claim di file letto/test passato senza report o nota read-only verificabile.
- Se GitHub non contiene ancora il task, stato marcato `LOCAL_ONLY_NOT_GITHUB_CANONICAL`.

Automation richiesta:

- riusare `git head-consistency`;
- riusare o estendere `scan master-plan-consistency`;
- riusare o estendere `scan evidence-metadata`;
- riusare `report validate-json`;
- se manca, creare `scan task-tracking-integrity --task TASKNNN --strict`.


## 6. Gap P1 — importante ma non blocker immediato

### P1.1 SwiftData lookup/performance

Problema:

- Alcuni punti iOS fetchano tutti i prodotti e filtrano in memoria o costruiscono mappe complete, ad esempio lookup barcode in import/pre-generate.

Obiettivo:

- Pianificare lookup chunked per barcode, supplier/category cache e benchmark grande dataset.

Acceptance futura:

- Import/pre-generate non deve degradare su dataset grande.
- Misurare prima di riscrivere.
- Niente mega-refactor preventivo.

File:

- `ExcelSessionViewModel.swift`
- `DatabaseView.swift`
- `ProductImportCore.swift`
- eventuale nuovo service futuro solo se giustificato da test.

### P1.2 Large import memory/progress/cancellation

Obiettivo:

- Benchmark memoria/tempo su XLSX/HTML/XLS grandi.
- Progress piu' fine.
- Cancellazione `Task` sicura.
- Limiti file e messaggi utente.
- Nessun parser rewrite senza misura.

Acceptance futura:

- Dataset sintetici grandi.
- Tempo, memoria e primo feedback misurati.
- Cancel/retry verificati.
- Errori utente localizzati e non tecnici.

Automation richiesta per TASK-132:

- se non esiste, creare `ios benchmark import-large --task TASK-132 --fixture <fixture>`;
- se non esiste, creare `scan swiftdata-fetch-budget --task TASK-132 --strict`;
- benchmark deve produrre tempo, memoria stimata/segnali disponibili, progress milestones, cancel/retry e regressione MainActor/fetch-all.

### P1.3 Options first-sync checklist

Obiettivo UX:

In Options mostrare checklist user-facing:

- account collegato;
- dati locali trovati;
- dati cloud trovati;
- review necessaria / completata;
- sync automatica attiva;
- pending locali N;
- ultimo sync/stato;
- azione chiara: Review / Retry / Sign in.

File:

- `OptionsView.swift`
- `Sync/Account/AccountSyncDecisionView.swift`
- `Sync/Automatic/Presentation/OptionsSyncSummaryProvider.swift`
- `Localizable.strings`

Acceptance futura:

- Stati empty/local-only/cloud-only/local+cloud/pending/error firmati da test.
- Nessun falso "tutto aggiornato" quando drift check manca o pending > 0.
- Copy breve in IT/EN/ES/ZH o set localizzazioni corrente.

### P1.4 Generated/PreGenerate dense UX

Obiettivo:

- Migliorare produttivita' senza copiare Android:
  - header sticky/contestuale;
  - search next/previous piu' evidente;
  - filtro errori piu' chiaro;
  - row detail piu' compatto;
  - column chooser piu' visuale;
  - import analysis error export piu' discoverable.

Vincolo:

- Non trasformare SwiftUI in clone Compose.
- Nessun redesign globale senza evidence di flusso.

### P1.5 Scanner real device edge cases

Pianificare test:

- scansione doppia veloce;
- barcode gia' in griglia;
- barcode in DB ma non in sessione;
- low light;
- ritorno da background;
- fallback manuale.

Acceptance futura:

- iPhone fisico dove necessario.
- Screenshot/log redatti.
- Nessuna regressione fallback manuale.

### P1.6 Accessibilita' / Dynamic Type / Localizzazioni

Pianificare:

- VoiceOver su Options/Generated/Database;
- Dynamic Type grande;
- cinese/spagnolo/testi lunghi;
- dark mode;
- focus tastiera nei sheet;
- contrasto badge/warning.

Acceptance futura:

- Verifiche statiche e simulator/manuali quando richieste.
- Evidence per almeno Options, Generated e Database.
- Nessun testo troncato nei controlli principali.

Automation richiesta per TASK-134/TASK-135:

- TASK-134 deve creare o riusare `ios smoke options-first-sync --task TASK-134`;
- TASK-135 deve creare o riusare `ios smoke scanner-edge --task TASK-135`;
- TASK-135 deve creare o riusare `ios smoke accessibility --task TASK-135`;
- se l'automazione UI non riesce per limiti simulator/accessibility, il risultato deve essere `PASS_WITH_NOTES` solo con fallback documentato e screenshot/log redatti, non PASS pieno.

## 7. Gap P2 — cleanup progressivo

Non mega-refactor.

Pianificare split futuro solo dopo golden corpus/test verdi:

- `ExcelAnalyzer.swift`
- `ExcelHeaderMapping.swift`
- `DatabaseImportPipeline.swift`
- `GeneratedInventoryState.swift`
- `GeneratedInventoryActions.swift`

Principio:

- Prima corpus e test.
- Poi estrazioni piccole.
- Ogni split deve preservare comportamento import/export e price history.
- Nessuna nuova dipendenza senza richiesta esplicita.

## 8. Matrice priorita'

| ID gap | Area | Severita' | Stato attuale | Rischio | File iOS | File Android | Supabase | Acceptance | Futuro task suggerito |
|--------|------|-----------|---------------|---------|----------|--------------|----------|------------|-----------------------|
| P0.1 | Android test health | P0 | Targeted sync/build storicamente PASS; broad `testDebugUnitTest` rosso/instabile per ByteBuddy/attach nel perimetro audit | CI non affidabile, regressioni nascoste | Solo riferimento tracking iOS | `app/build.gradle.kts`, `app/src/test/**`, `AppDatabase.kt`, `InventoryRepository.kt` | N/A | Broad PASS oppure quarantena tecnica + CI command stabile | TASK-129 |
| P0.2 | Price contract | P0 | iOS current su `Product`, history su `ProductPrice`; Android summary last/flow; old* in import/migration | Drift semantico prezzi tra piattaforme/export/Supabase | `Models.swift`, `ProductImportCore.swift`, `ExcelSessionViewModel.swift`, `ProductPriceHistoryView.swift` | `ProductPriceSummary.kt`, `InventoryRepository.kt`, DAO/Product models, `AppDatabase.kt` | `inventory_products`, `inventory_product_prices` | Matrice campo-per-campo + test create/update/import/export/round-trip | TASK-130 |
| P0.3 | Golden corpus | P0 | Import/export esistono ma corpus cross-platform unico non risulta consolidato | Regressioni parser/export non riproducibili | import/export tests, `ExcelSessionViewModel.swift`, `ProductImportCore.swift`, `DatabaseView.swift` | `ExcelUtils.kt`, `ExcelViewModel.kt`, `ImportAnalysis.kt`, import/export tests | Solo se round-trip DB export include remote schema | Corpus privacy-safe versionato + expected results | TASK-131 |
| P0.4 | Real sync/offline/background | P0 | TASK-123 copre simulator/emulator speed; TASK-125 copre real-device core con note background; non copre globale lungo | Drift, pending stuck, conflitti silenziosi in condizioni reali | `Sync/**`, `OptionsView.swift`, `LocalPendingChange.swift`, `HistoryEntry.swift` | sync/autosync coordinators, repository, UI status | `sync_events`, catalog, prices, shared sessions | Real-device matrix foreground/background/locked/offline/reconnect/conflict/delete | TASK-133 |
| P0.5 | Harness coverage / automation debt | P0 | Harness esiste, ma TASK-128 originale non mappava ogni gap a comandi/evidence | Execution future manuali, fragili o non redatte | `tools/agent/**`, task docs/evidence | Android wrapper/test commands | Supabase wrapper/cleanup/residue | Automation contract per ogni futuro task + nuovi comandi help-json/commands-json quando mancanti | Ogni TASK-129...135 |
| P0.6 | Tracking/evidence integrity | P0 | Piano migliorato, ma future execution devono rendere verificabili GitHub/local/MASTER-PLAN/evidence | Claim non supportati, task local-only scambiati per canonical, review difficile | `docs/MASTER-PLAN.md`, `docs/TASKS/**`, `tools/agent/**` | Android evidence/report se toccato | Supabase evidence/report se toccato | Evidence README + head/master/evidence scans + JSON validation | Ogni TASK-129...135 |
| P1.1 | SwiftData lookup performance | P1 | Alcuni path import/pre-generate costruiscono lookup ampi | Degrado su dataset grande | `ExcelSessionViewModel.swift`, `DatabaseView.swift`, `ProductImportCore.swift` | Android come benchmark funzionale | N/A | Benchmark + chunked/cached lookup se misurato | TASK-132 |
| P1.2 | Large import memory/progress/cancel | P1 | Parsing e progress esistono; hardening grande dataset da misurare | UI freeze, memoria alta, cancel fragile | `ExcelSessionViewModel.swift`, `PreGenerateView.swift`, `GeneratedView.swift` | `ExcelUtils.kt`, `ExcelViewModel.kt` | N/A | Tempo/memoria/progress/cancel evidence | TASK-132 |
| P1.3 | Options first-sync checklist | P1 | Options summary migliorata da TASK-127, checklist first-sync non completa | Utente non capisce review/sync/pending | `OptionsView.swift`, `AccountSyncDecisionView.swift`, `OptionsSyncSummaryProvider.swift`, Localizable | Options/status Android come riferimento | remote counts/read-only | Stati first-sync verificati + CTA chiara | TASK-134 |
| P1.4 | Generated/PreGenerate dense UX | P1 | UI funzionale, miglioramenti produttivita' non consolidati | Errori import meno visibili, lavoro lento | `GeneratedView.swift`, `PreGenerateView.swift`, `ExcelSessionViewModel.swift` | `GeneratedScreen.kt`, import analysis | N/A | UX smoke/static + no regressione import | TASK-135 |
| P1.5 | Scanner edge cases | P1 | Scanner/fallback presenti; edge real-device da pianificare | Doppie scansioni, ritorno background, low light | Scanner entry in `DatabaseView.swift` / Generated flow | Scanner Android se presente | N/A | Manual real-device evidence + fallback | TASK-135 |
| P1.6 | Accessibility/Dynamic Type/localization | P1 | Verifiche parziali in task storici | UI non usabile con testi lunghi/accessibility | Options/Generated/Database/Localizable | Android solo confronto | N/A | VoiceOver/Dynamic Type/dark mode/localization smoke | TASK-135 |
| P2.1 | Cleanup import/generated architecture | P2 | File grandi ma funzionanti | Refactor rischioso senza corpus | `ExcelSessionViewModel.swift`, `GeneratedView.swift`, `ProductImportCore.swift` | N/A | N/A | Split piccoli dopo corpus/test verdi | Post TASK-135 |

## 9. Sequenza consigliata dopo TASK-128

Roadmap futura consigliata. Non creare questi task durante TASK-128.

1. TASK-129: Android broad test health + CI isolation. Deve prima verificare/creare `android test broad`.
2. TASK-130: price contract current/previous/old + tests. Deve prima verificare/creare `scan price-contract`, `ios test price-contract`, `android test price-contract`.
3. TASK-131: golden corpus import/export cross-platform. Deve prima verificare/creare `harness golden-corpus validate/roundtrip`.
4. TASK-132: iOS SwiftData/import performance. Deve prima verificare/creare `ios benchmark import-large` e `scan swiftdata-fetch-budget`.
5. TASK-133: real device offline/background sync hardening. Deve riusare/estendere live real-device commands, non shell raw.
6. TASK-134: Options first-sync UX checklist. Deve prima verificare/creare `ios smoke options-first-sync`.
7. TASK-135: accessibility/scanner/UX polish. Deve prima verificare/creare scanner/accessibility smoke commands.

Regola trasversale per tutti i task TASK-129...135:

- prima di patch/runtime, aggiungere la sezione `Automation contract`;
- creare/aggiornare evidence README;
- eseguire head/master/evidence checks canonici;
- usare report JSON/Markdown come fonte di verita';
- non chiudere DONE senza review esplicita.

Sequenza motivata:

- Prima rendere affidabile il segnale test Android.
- Poi fissare il contratto dati prezzi, perche' alimenta corpus, export, Supabase e UI.
- Poi corpus golden, che diventa rete di sicurezza per performance e cleanup.
- Poi performance e real-device hardening.
- Infine UX/accessibilita' su base stabile.

## 10. Non obiettivi

- No codice Swift/Kotlin/SQL.
- No schema migration.
- No RLS/grants change.
- No dati reali.
- No `service_role` client.
- No cleanup globale.
- No claim production-ready globale.
- No refactor massivo.
- No apertura TASK-129.
- No modifica API pubbliche.
- No nuove dipendenze in TASK-128. I task futuri possono proporre dipendenze solo se giustificate, test-only dove possibile, documentate e accettate nel task specifico.
- No build/test runtime obbligatori in TASK-128.
- No Supabase write/delete/update.

## 11. Evidence richiesta per chiudere TASK-128 in REVIEW

TASK-128 puo' andare in REVIEW solo se:

- [ ] il file task esiste e contiene tutti i gap;
- [ ] `docs/MASTER-PLAN.md` aggiornato;
- [ ] repo iOS/Android/Supabase letti almeno in modo read-only;
- [ ] matrice priorita' compilata;
- [ ] roadmap TASK-129...135 proposta ma non creata;
- [ ] stato resta PLANNING/REVIEW, non DONE;
- [ ] nessuna patch runtime;
- [ ] nessun file Swift/Kotlin/SQL modificato;
- [ ] TASK-129 non aperto;
- [ ] nessun claim production-ready globale;
- [ ] sezione automation-first presente;
- [ ] mappa comandi esistenti/mancanti presente;
- [ ] safety gate live/cleanup/prefix/redaction presenti;
- [ ] tassonomia PASS/FAIL/BLOCKED/NOT_RUN/PASS_WITH_NOTES presente;
- [ ] criteri REVIEW/DONE futuri esplicitati;
- [ ] sezione tracking/MASTER-PLAN/evidence integrity presente;
- [ ] template obbligatorio TASK-129...135 presente;
- [ ] MCP/CLI governance presente;
- [ ] se viene indicata evidence "raccolta", deve esistere un report o una nota read-only verificabile; altrimenti va marcata come `PLANNED_READ_ONLY_CHECK`, non prova conclusiva.

Evidence read-only raccolta in creazione TASK-128:

- iOS `origin/main` fetch eseguito e local HEAD verificato allineato a `origin/main` su `cdb22534`.
- Letti/consultati `docs/MASTER-PLAN.md`, TASK-103, TASK-123, TASK-127.
- Consultati path iOS principali: modelli, import/pre-generate/generated/database/options/sync/pending.
- Consultati path Android principali: Gradle, DB/repository/ProductPriceSummary/import/sync/test config.
- Consultate migrations/SQL locali Supabase per catalogo, product prices, shared sessions, sync events, RLS/grants/RPC.

## 12. Output richiesto a Codex

Alla fine del turno Codex deve rispondere con:

- file creati/modificati;
- stato task;
- sintesi dei P0/P1/P2;
- cosa NON e' stato fatto;
- prossimo passo consigliato;
- comandi `mc-agent` usati o intenzionalmente non eseguiti in planning;
- comandi/harness mancanti da creare nei futuri task;
- safety gate identificati per live/cleanup;
- conferma che non ha aperto TASK-129 e non ha dichiarato production-ready globale.

## Execution - Codex

### Stato execution

- 2026-05-27: creazione planning/documentazione TASK-128 richiesta dall'utente.
- Fase mantenuta: PLANNING.
- Nessuna execution runtime avviata.

### File controllati

- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-103-final-real-device-cross-platform-acceptance-ios-supabase-android.md`
- `docs/TASKS/TASK-123-ios-android-simulator-autosync-speed-acceptance.md`
- `docs/TASKS/TASK-127-ios-options-responsiveness-sync-summary-performance.md`
- `iOSMerchandiseControl/Models.swift`
- `iOSMerchandiseControl/ProductImportCore.swift`
- `iOSMerchandiseControl/ExcelSessionViewModel.swift`
- `iOSMerchandiseControl/ProductPriceHistoryView.swift`
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/Sync/Automatic/Presentation/OptionsSyncSummaryProvider.swift`
- `iOSMerchandiseControl/Sync/Account/AccountSyncDecisionView.swift`
- `iOSMerchandiseControl/Sync/Automatic/Background/SyncBackgroundTaskScheduler.swift`
- `iOSMerchandiseControl/LocalPendingChange.swift`
- Android reference files discovered/read by search under `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView`.
- Supabase local migrations/SQL discovered/read by search under `/Users/minxiang/Desktop/MerchandiseControlSupabase`.

### Piano minimo applicato

1. Verificare `origin/main` e HEAD iOS.
2. Leggere MASTER-PLAN e task storici pertinenti.
3. Consultare codice/schema read-only per non inventare tabelle/campi.
4. Creare file TASK-128 planning-only.
5. Aggiornare MASTER-PLAN a ACTIVE / PLANNING.
6. Verificare che non siano state create patch runtime o TASK-129.

### Handoff post-planning

Handoff a Claude / Planner-Reviewer:

- Review richiesta sul piano TASK-128.
- Se approvato, la prossima azione consigliata e' aprire TASK-129 separato per Android broad test health.
- TASK-128 non e' DONE.
- TASK-128 non autorizza execution Swift/Kotlin/SQL.


## 13. Second planner-review verdict

Verdict di questa integrazione: **PLANNING_STRONGER_WITH_TRACKING_AND_AGENT_UX_GATES**.

Il piano ora copre:

- gap funzionali;
- automation-first;
- safety/redaction;
- evidence/report;
- cleanup/residue;
- tracking/MASTER-PLAN consistency;
- future task template;
- MCP/CLI governance;
- UX utente e UX operatore/agent.

Resta vietato usare questo file come autorizzazione a execution. Il prossimo passo corretto e' review/accettazione del piano e solo dopo apertura separata di TASK-129.
