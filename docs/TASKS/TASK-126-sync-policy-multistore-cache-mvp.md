# TASK-126: Cross-platform sync policy, conflict matrix and multi-store cache MVP

## Informazioni generali

- **Task ID**: TASK-126
- **Titolo**: Cross-platform sync policy, conflict matrix and multi-store cache MVP
- **Stato corrente**: DONE / Chiusura — REVIEW PASS FINAL
- **Fase attuale**: Chiusura
- **Responsabile attuale**: USER / Closure authorized
- **Ultimo aggiornamento**: 2026-05-27
- **Ultimo agente**: Codex / Reviewer+Fixer
- **Perimetro**: iOS target principale + Android parity + Supabase contract review
- **Tipo task**: policy + architecture contract + MVP implementation plan + UX recovery + memory/cache strategy + automation/harness hardening
- **Priorità**: HIGH / P0-P1 sync safety
- **Responsabile suggerito**: Codex/Cursor Executor, con review finale Claude/User
- **Evidence dir**: `docs/TASKS/EVIDENCE/TASK-126/`
- **File task suggerito**: `docs/TASKS/TASK-126-sync-policy-multistore-cache-mvp.md`

## Review planning integrata — verdict

Questo piano è valido come direzione di prodotto e architettura, ma prima dell'integrazione corrente era ancora troppo debole sul lato **automation/harness**: indicava build/test/evidence in modo corretto a livello concettuale, ma non obbligava abbastanza l'esecutore a usare il CLI canonico `./tools/agent/mc-agent.sh`, non distingueva chiaramente strumenti già disponibili da strumenti mancanti, e non definiva scanner TASK-126 dedicati per evitare regressioni su owner/store scope, cache active-store-only, base version e conflict matrix.

Questa versione rifinita rende TASK-126 **execution-proof**:

- usa `mc-agent` come fonte canonica per preflight, build, test, smoke, Supabase, live matrix, cleanup scoped e report;
- vieta sequenze manuali lunghe quando esiste o può essere creato un comando canonico;
- impone discovery `help-json` / `list commands-json` prima di qualsiasi implementazione;
- richiede la creazione/miglioramento degli scanner TASK-126 se non esistono;
- formalizza report Markdown/JSON, redaction, exit code, safety gate, prefissi test e condizioni REVIEW/DONE;
- integra UX non solo per l'utente finale, ma anche per l'operatore/agent CLI.

### Correzioni principali aggiunte in questa review

1. **Automation gap chiuso**: aggiunta sezione completa `Automation/harness contract`.
2. **Scanner mancanti esplicitati**: TASK-126 non può chiudere usando solo scanner TASK-117/124 se non coprono i nuovi invarianti.
3. **Safety live/cleanup rafforzata**: prefissi `TASK126_*`, dry-run prima di execute, residue-check finale.
4. **Exit taxonomy chiarita**: differenza tra `PASS`, `FAIL`, `BLOCKED`, `NOT_RUN`, `PASS_WITH_NOTES`, `MISCONFIGURED`, `UNSAFE_OPERATION_REFUSED`.
5. **Operator UX aggiunta**: ogni comando deve dare `RESULT`, `EXIT_CODE`, `REPORT_MD`, `REPORT_JSON`, `NEXT_ACTION`.
6. **No manual workaround**: se un harness manca, va creato o migliorato prima di eseguire matrix ripetitive.
7. **REVIEW/DONE gate più severi**: REVIEW solo con evidence completa; DONE solo con review/accettazione esplicita.


## Review planning seconda pass — integrazioni repo-grounded aggiunte

Questa seconda review conferma che il piano è già correttamente orientato a policy sync, conflict matrix, multi-store cache MVP e harness automation-aware. Restavano però alcuni gap pratici che in Execution avrebbero potuto generare falsi PASS, refactor troppo larghi o regressioni difficili da diagnosticare.

Integrazioni aggiunte in questa versione:

1. **Legacy/unbound local store policy**: gestione degli utenti che aggiornano da una versione precedente senza `LocalStoreIdentity`/`storeId`.
2. **Store epoch e remote reset detection**: evitare wipe o reseed silenziosi quando il cloud è stato resettato o ricreato.
3. **Switch lock/cancellation contract**: cambio account/store non può avvenire mentre push/pull/ack mutativo è in corso senza sospensione sicura.
4. **Physical vs logical cache decision più stretta**: Opzione A fisica resta preferita, ma richiede spike lifecycle SwiftData/Room prima di patch business.
5. **Scanner RED/GREEN obbligatori**: ogni nuovo scanner TASK-126 deve avere fixture positive/negative per evitare scanner cosmetici.
6. **Budget memoria/performance misurabile**: ProductPrice/cache devono produrre evidenza quantitativa, non solo dichiarazioni qualitative.
7. **Conflict Review batch UX**: Review deve supportare batch grandi senza obbligare l'utente a risolvere riga per riga se i conflitti sono omogenei.
8. **Store membership/permission future-proof**: revoca ruolo o store disabilitato deve bloccare mutazioni e preservare dirty local.
9. **Command catalog hardening**: se il dispatcher non espone i comandi TASK-126 in `help-json`, non basta documentarli nel task; vanno cablati e testati.
10. **Evidence completeness schema**: ogni report deve dichiarare input, fixture, scope, skipped cases, redaction, cleanup/residue e next action.

Queste integrazioni non autorizzano Execution. Servono solo a rendere il task pronto a una futura Execution più sicura e meno dipendente da interpretazioni manuali.


## Review planning terza pass — integrazioni finali repo/harness-grounded

Questa terza review conferma che il piano e' ormai correttamente automation-aware e coerente con lo stato TASK-125. Restavano pero' alcuni punti sottili che possono generare ambiguita' in una Execution reale: stato documentale canonico, schema Supabase non ancora store-aware, migrazioni locali, classificazione `NOT_RUN`, feature flag/sync protocol, invarianti business non riducibili a field-level merge e sicurezza del manifest cache.

Le seguenti integrazioni sono parte del piano TASK-126 e non autorizzano Execution.

### TP126-01 — Canonical document gate prima di Execution

Prima di qualunque patch business, la futura Execution deve verificare e, se necessario, creare/allineare:

```text
docs/TASKS/TASK-126-sync-policy-multistore-cache-mvp.md
docs/TASKS/EVIDENCE/TASK-126/README.md
docs/MASTER-PLAN.md
```

Regole:

- se TASK-126 non e' ancora registrato nel Master Plan locale, aggiornare solo documentazione/task tracking prima di patch runtime;
- se GitHub raw `main` e worktree locale divergono, classificare come `REMOTE_PUBLISH_PENDING` o `CANONICAL_LOCAL_CONFIRMED` solo se local consistency PASS e l'utente conferma il worktree locale come sorgente corrente;
- non usare `BLOCKED_EXTERNAL_CANONICAL_MISMATCH` se il solo problema e' publish pending gia' spiegato;
- non iniziare Swift/Kotlin/Supabase runtime finche' evidence README e task file non esistono.

Evidence richiesta:

```text
-1-11-task-docs-canonicalization.md/json
-1-12-master-plan-task126-registration.md/json
```

### TP126-02 — Store scope mode: local-default vs remote-store-aware

TASK-126 non deve inventare colonne remote. La modalita' store deve essere dichiarata dopo audit Supabase:

```text
mode = localDefaultStoreOnly
  Supabase non ha ancora store_id/workspace_id nelle tabelle runtime.
  TASK-126 usa defaultStoreId stabile localmente, ownerHash/account boundary, outbox/cursor local store-scoped.
  Il remote resta owner-scoped come oggi.
  Multi-store reale remoto resta follow-up.

mode = remoteStoreAware
  Supabase ha gia' store/workspace scope e RLS compatibile.
  TASK-126 puo' usare store_id remoto dopo audit schema/RLS/grants.
```

Regole:

- in `localDefaultStoreOnly`, non inviare `storeId` a endpoint/colonne inesistenti;
- in `localDefaultStoreOnly`, vietato dichiarare multi-store cloud completo;
- in `remoteStoreAware`, ogni query/mutation deve essere owner+store scoped e testata;
- se serve migration Supabase per vero multi-store, pianificarla come follow-up separato salvo blocker esplicito approvato.

Evidence:

```text
03a-supabase-store-scope-mode.md/json
```

### TP126-03 — Migration/rollback locale SwiftData e Room

Qualunque modifica a modelli SwiftData/Room per `LocalStoreIdentity`, `storeId`, `baseVersion`, `changedFields`, cache manifest o pending/outbox deve avere piano migration.

Regole iOS:

- nessuna migration distruttiva senza backup/export attempt e conferma forte;
- SwiftData schemaVersion deve essere documentato;
- se viene scelta cache fisica multi-store, ogni store file ha propria migration e recovery;
- fallback da cache fisica a logical scope non deve perdere dirty pending.

Regole Android:

- ogni cambio Room entity richiede Migration esplicita o motivazione sicura;
- vietato `fallbackToDestructiveMigration` per dati utente;
- WorkManager deve rifiutare job con schema/store/protocol mismatch invece di scrivere con vecchi input.

Evidence:

```text
14-local-schema-migration-rollback-plan.md/json
```

### TP126-04 — Sync protocol version e feature flags

TASK-126 introduce comportamenti che possono coesistere con client vecchi. Serve un contratto di rollout:

```text
syncProtocolVersion
localStoreSchemaVersion
conflictEngineVersion
cacheMode = logicalScope | physicalStore
featureFlag.conflictReviewV2
featureFlag.physicalMultiStoreCache
featureFlag.storeManifest
featureFlag.task126StrictOwnerStoreGate
```

Regole:

- flag non devono nascondere bug per far passare test;
- default sicuro: strict owner/store gate ON, destructive flows OFF, physical cache ON solo dopo spike PASS;
- client/protocol mismatch entra in fail-safe/recovery, non in silent overwrite;
- final report deve dichiarare quali flag sono ON/OFF e perche'.

Evidence:

```text
15-sync-protocol-feature-flags.md/json
```

### TP126-05 — `NOT_RUN` non e' un PASS

Il piano usa `NOT_RUN` come stato report/evidence, ma il README `mc-agent` espone exit code canonici `0 PASS`, `1 FAIL`, `2 BLOCKED`, `3 MISCONFIGURED`, `4 UNSAFE_OPERATION_REFUSED`.

Regola TASK-126:

- `NOT_RUN` e' una classificazione di caso/evidence, non un successo operativo;
- se un gate obbligatorio resta `NOT_RUN`, TASK-126 non puo' andare in REVIEW;
- se un caso opzionale e' `NOT_RUN`, deve avere `NOT_APPLICABLE` o `BLOCKED_EXTERNAL` motivato;
- per comando CLI, un mandatory-not-run deve uscire `1 FAIL` se e' omissione interna, oppure `2 BLOCKED` se manca prerequisito esterno.

Aggiornare gli eventuali wrapper nuovi per non restituire exit code `0` quando il target obbligatorio non e' stato trovato o testato.

### TP126-06 — Field-level merge non deve violare invarianti business

La regola "campi diversi = merge automatico" vale solo se non rompe invarianti di dominio.

Entrano in Review o policy dedicata:

- cambio `barcode`/business key mentre remote modifica la stessa entita';
- cambio supplier/category reference se il target remoto e' stato cancellato o rinominato in modo incompatibile;
- stock/quantity se esistono operazioni additive/subtractive concorrenti e non semplice set-value;
- remoteID/localID relink mentre pending locale usa vecchia identity;
- Product delete/tombstone con qualunque edit locale dipendente;
- Generated sheet row identity instabile.

Evidence:

```text
11a-domain-invariant-merge-policy.md/json
```

### TP126-07 — Cache manifest privacy e app data protection

Il cache manifest deve essere leggero ma non deve diventare leak di dati cliente.

Regole:

- manifest non contiene nomi reali cliente/negozio/prodotto/barcode salvo valori sintetici o gia' user-visible;
- ownerHash/storeId in report sono redatti/hashati;
- su iOS, valutare file protection per store/cache compatibile con background previsto;
- su Android, manifest/cache resta in app-private storage; export/backup richiede azione esplicita utente;
- cleanup report non deve stampare path personali completi se non necessario.

Evidence:

```text
16-cache-manifest-privacy-protection.md/json
```

### TP126-08 — Backup/export safety prima di scarto pending

Ogni flow che consente `Scarta e cambia account`, `Elimina cache`, `Recovery reseed`, o `Reset store locale` deve distinguere:

- cache clean: conferma leggera;
- cache dirty: conferma forte + opzione export/backup se tecnicamente possibile;
- recovery corrotto: tentativo backup best-effort prima di reseed;
- backup fallito: utente deve vedere il rischio prima di procedere.

Non serve implementare un nuovo formato backup se gia' esiste export utile, ma il piano deve dire quale export viene usato o perche' non e' disponibile.

Evidence:

```text
17-discard-reset-backup-safety.md/json
```

### TP126-09 — Store list UX non deve promettere cloud multi-store se il backend non e' pronto

Se `mode = localDefaultStoreOnly`, la UI non deve mostrare gestione multi-negozio completa. Sono ammessi solo:

- stato store/cache attivo;
- copy future-proof neutro;
- eventuale developer/internal status;
- nessuna promessa "crea piu' negozi cloud" senza schema/RLS store-aware.

Se `mode = remoteStoreAware`, la lista negozi puo' mostrare store remoti autorizzati con manifest leggero.

### TP126-10 — Required third-pass matrix additions

Aggiungere alla matrix finale:

| ID | Scenario | Azione corretta | Conferma utente | Full pull/reseed | Note |
|---|---|---|---|---|---|
| C126-49 | TASK-126 docs/evidence README mancanti | creare/allineare docs prima di runtime | no | no | planning/execution gate |
| C126-50 | Supabase senza store_id remoto | localDefaultStoreOnly, no colonne inventate | no | no | multi-store cloud follow-up |
| C126-51 | Supabase store-aware gia' presente | remoteStoreAware dopo RLS audit | no | no | owner+store scope |
| C126-52 | SwiftData/Room schema migration necessaria | migration/rollback plan obbligatorio | sì se rischiosa | recovery only | no destructive migration |
| C126-53 | Protocol/client version mismatch | fail-safe/recovery | sì se update richiesto | no | no silent overwrite |
| C126-54 | Feature flag fisico multi-store OFF | logical/default mode sicuro | no | no | no false claim |
| C126-55 | Barcode/business key conflict | Review o domain policy | sì | no | field-level non basta |
| C126-56 | Stock/quantity concurrent operations | domain operation merge o Review | sì se ambiguo | no | evitare lost update |
| C126-57 | Cache manifest privacy leak | FAIL sensitive/privacy gate | no | no | redaction required |
| C126-58 | Scarto pending senza backup option | FAIL UX/safety gate | sì | no | dirty destructive flow |
| C126-59 | Store list apre tutti i DB per calcolare badge | FAIL memory gate | no | no | manifest only |
| C126-60 | Mandatory case NOT_RUN | non puo' andare in REVIEW | no | no | NOT_RUN != PASS |

### TP126-11 — Required third-pass acceptance additions

Aggiungere agli acceptance criteria:

- **AC-126-51**: TASK-126 task doc, evidence README e Master Plan sono allineati prima di runtime patch.
- **AC-126-52**: Supabase store scope mode e' dichiarato `localDefaultStoreOnly` o `remoteStoreAware`.
- **AC-126-53**: nessuna colonna/tabella Supabase inventata senza schema/migration approvata.
- **AC-126-54**: SwiftData/Room migration e rollback plan documentati per ogni schema local change.
- **AC-126-55**: sync protocol version/feature flags documentati e non usati come workaround.
- **AC-126-56**: `NOT_RUN` obbligatorio blocca REVIEW.
- **AC-126-57**: domain invariant merge policy copre barcode, stock/quantity, FK supplier/category e relink remoteID.
- **AC-126-58**: cache manifest passa privacy/data-protection audit.
- **AC-126-59**: dirty destructive flows offrono backup/export o rischio esplicito.
- **AC-126-60**: UI store list non promette multi-store cloud se Supabase e' solo owner-scoped.

### TP126-12 — Aggiornamento dei gate REVIEW

Aggiornare ogni riferimento finale da `C126-00…C126-60` a `C126-00…C126-60` e da `AC-126-60` a `AC-126-60`.

Inoltre REVIEW richiede:

- canonical task docs/evidence README PASS;
- Supabase store scope mode dichiarato;
- local migration/rollback plan PASS se ci sono schema changes;
- NOT_RUN mandatory cases = 0;
- feature flag/protocol report PASS;
- privacy audit cache manifest PASS;
- backup/export safety dirty destructive flows PASS/PASS_WITH_NOTES motivato.

## Automation/harness contract obbligatorio

TASK-126 deve usare il sistema di automazione già presente nel progetto come canale canonico. La CLI primaria è:

```bash
./tools/agent/mc-agent.sh
```

Il piano non deve chiedere a Cursor/Codex di ricostruire manualmente sequenze lunghe di `xcodebuild`, `gradle`, `adb`, `supabase`, `psql`, `sqlite`, `grep` o script custom se esiste un comando canonico o se il comando ricorrente può essere incapsulato nel harness.

### A126-H0 — Discovery obbligatoria prima di implementare

In futura Execution, prima di qualunque patch Swift/Kotlin/SQL o test runtime:

```bash
MC_TASK_ID=TASK-126 ./tools/agent/mc-agent.sh help-json
MC_TASK_ID=TASK-126 ./tools/agent/mc-agent.sh list commands-json
MC_TASK_ID=TASK-126 ./tools/agent/mc-agent.sh config validate
MC_TASK_ID=TASK-126 ./tools/agent/mc-agent.sh git head-consistency --task TASK-126
MC_TASK_ID=TASK-126 ./tools/agent/mc-agent.sh preflight --require-head-consistency --task TASK-126
MC_TASK_ID=TASK-126 ./tools/agent/mc-agent.sh report --latest --task TASK-126
```

Se uno di questi comandi non supporta `--task TASK-126`, produce report fuori da `docs/TASKS/EVIDENCE/TASK-126/`, non redige dati sensibili, non restituisce exit code affidabile o non appare in `help-json`, la prima attività di Execution è **migliorare il harness**, non aggirarlo manualmente.

Evidence minima:

```text
docs/TASKS/EVIDENCE/TASK-126/agent-runs/
  00-help-json.log
  00-help-json.json
  01-commands-json.log
  01-commands-json.json
  02-config-validate.md/json
  03-head-consistency.md/json
  04-preflight.md/json
  05-harness-discovery.md/json
```

### A126-H1 — Strumenti già disponibili da riusare

Da verificare con `help-json` e `list commands-json`, ma il piano assume come già esistenti o storicamente presenti:

| Area | Strumento/comando atteso | Uso in TASK-126 |
|---|---|---|
| Preflight | `preflight`, `git head-consistency`, `config validate` | bloccare execution se HEAD/config non coerenti |
| Report | `report --latest`, `report validate-json` | generare/validare `.md` e `.json` evidence |
| iOS | `ios build debug`, `ios build release`, `ios test sync`, eventuali smoke/auth wrappers | build/test iOS senza comandi manuali fragili |
| Android | `android build debug`, `android test ...`, L1/L2/L3 offline harness se presenti | parity Android e offline matrix |
| Supabase | `supabase status-redacted`, `supabase cleanup`, `supabase residue-check` | schema/status/cleanup scoped e redatto |
| Sync/live | `sync counts`, `live reconcile-counts`, `live sync-matrix` se applicabili | solo con `MC_ALLOW_LIVE=1` |
| Scan | `scan sensitive`, `scan evidence`, `scan repo-diff`, `scan no-full-pull-normal-path`, `scan no-hidden-manual-sync`, `scan no-service-role-client`, `scan no-rls-bypass` | regressione/safety finale |
| MCP | `tools/agent/mcp/server.mjs` | solo adapter thin, non sorgente canonica |

### A126-H2 — Strumenti TASK-126 da creare o migliorare se mancanti

Se non esistono in `help-json`, Execution deve aggiungerli al harness in modo modulare, documentato e agent-friendly prima di usarli. Questi scanner/comandi sono richiesti perché TASK-126 introduce invarianti nuovi non coperti pienamente dai task precedenti:

```bash
./tools/agent/mc-agent.sh scan task126-policy-matrix --task TASK-126 --strict
./tools/agent/mc-agent.sh scan owner-store-scope --task TASK-126 --strict
./tools/agent/mc-agent.sh scan local-store-identity --task TASK-126 --strict
./tools/agent/mc-agent.sh scan pending-base-version --task TASK-126 --strict
./tools/agent/mc-agent.sh scan changed-fields-contract --task TASK-126 --strict
./tools/agent/mc-agent.sh scan no-cross-owner-store-pending-push --task TASK-126 --strict
./tools/agent/mc-agent.sh scan conflict-review-coverage --task TASK-126 --strict
./tools/agent/mc-agent.sh scan productprice-history-policy --task TASK-126 --strict
./tools/agent/mc-agent.sh scan cache-active-store-only --task TASK-126 --strict
./tools/agent/mc-agent.sh scan inactive-cache-cleanup-safety --task TASK-126 --strict
./tools/agent/mc-agent.sh scan task126-final-gates --task TASK-126 --strict
```

Se un comando viene implementato in Python/Shell:

- deve vivere sotto `tools/agent/lib/` o percorso coerente già usato dal harness;
- deve essere richiamabile dal dispatcher `mc-agent.sh`;
- deve comparire in `help-json` e `list commands-json`;
- deve produrre `.md` e `.json`;
- deve usare redaction comune;
- deve restituire exit code canonico;
- deve avere almeno fixture/self-test RED/GREEN per evitare falsi PASS.

### A126-H3 — Test command wrapper da aggiungere se mancanti

TASK-126 deve evitare test “a mano” ripetitivi per policy matrix. Se non esistono, creare wrapper:

```bash
./tools/agent/mc-agent.sh ios test sync-policy --task TASK-126
./tools/agent/mc-agent.sh ios test account-store-boundary --task TASK-126
./tools/agent/mc-agent.sh ios test conflict-review --task TASK-126
./tools/agent/mc-agent.sh ios test cache-memory --task TASK-126

./tools/agent/mc-agent.sh android test sync-policy --task TASK-126
./tools/agent/mc-agent.sh android test account-store-boundary --task TASK-126
./tools/agent/mc-agent.sh android test conflict-review --task TASK-126
./tools/agent/mc-agent.sh android test cache-memory --task TASK-126
```

I wrapper possono internamente chiamare XCTest/JVM/Instrumented test esistenti, ma l'operatore deve avere comandi one-line stabili.

### A126-H4 — Live, Supabase e cleanup safety gate

Qualunque test live o mutativo deve essere esplicitamente gated:

```bash
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh ios auth-preflight --live --task TASK-126
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh android auth-preflight --live --task TASK-126
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh live sync-matrix --task TASK-126 --prefix TASK126_POLICY_
```

Cleanup scoped:

```bash
./tools/agent/mc-agent.sh supabase cleanup --task TASK-126 --prefix TASK126_POLICY_ --dry-run
MC_ALLOW_CLEANUP=1 ./tools/agent/mc-agent.sh supabase cleanup --task TASK-126 --prefix TASK126_POLICY_ --execute --cleanup-plan-id <id>
./tools/agent/mc-agent.sh supabase residue-check --task TASK-126 --prefix TASK126_POLICY_ --profile linked
```

Regole:

- prefissi ammessi solo `TASK126_*`;
- cleanup globale vietato;
- `auth.users` vietato;
- `truncate` vietato;
- service-role nel client vietato;
- bypass RLS client vietato;
- `--execute` vietato senza dry-run precedente e `cleanup_plan_id`;
- residue finale deve essere `0` o `PASS_WITH_NOTES` motivato e accettato.

### A126-H5 — Prefissi test obbligatori

Usare prefissi distinti per rendere cleanup/residue leggibili:

```text
TASK126_POLICY_
TASK126_CONFLICT_
TASK126_ACCOUNT_
TASK126_STORE_
TASK126_CACHE_
TASK126_PRODUCTPRICE_
TASK126_OFFLINE_
TASK126_CLEANUP_
```

Ogni evidence live deve riportare prefix, cleanup status e residue status.

### A126-H6 — Report schema, path ed exit code

Ogni comando wrapper deve stampare e salvare:

```text
RESULT: PASS|FAIL|BLOCKED|PASS_WITH_NOTES|NOT_RUN|MISCONFIGURED|UNSAFE_OPERATION_REFUSED
EXIT_CODE: 0|1|2|3|4
REPORT_MD: docs/TASKS/EVIDENCE/TASK-126/agent-runs/<timestamp>-<command>.md
REPORT_JSON: docs/TASKS/EVIDENCE/TASK-126/agent-runs/<timestamp>-<command>.json
NEXT_ACTION: ...
```

Mappatura:

| Stato report | Significato |
|---|---|
| `PASS` | Verifica completata e criteri soddisfatti |
| `FAIL` | Bug/regressione reale; richiede fix |
| `BLOCKED` | Prerequisito esterno mancante, con next action concreta |
| `NOT_RUN` | Non eseguito; non può supportare REVIEW se era obbligatorio |
| `PASS_WITH_NOTES` | Passa nel perimetro dichiarato, con limite residuo non P0 |
| `MISCONFIGURED` | comando/env/harness sbagliato |
| `UNSAFE_OPERATION_REFUSED` | safety gate ha rifiutato operazione pericolosa |

### A126-H7 — Redaction obbligatoria

Ogni log/report deve redigere:

- JWT, refresh token, access token, API key, service key;
- email complete;
- project ref Supabase se policy corrente lo richiede;
- path personali (`/Users/minxiang/...`) se non necessari;
- seriali device;
- query SQL con valori sensibili;
- nomi clienti/negozi reali se non sintetici;
- barcode/prodotti reali se non fixture autorizzate.

Se `scan sensitive --task TASK-126` trova leak, TASK-126 non può andare in REVIEW.

### A126-H8 — UX operatore/agent

Ogni comando nuovo deve essere prevedibile:

- output breve di default;
- `--verbose` per dettagli;
- `--quiet` per CI;
- errore leggibile con causa e next action;
- nessun stack trace grezzo se non in report debug;
- esempi one-line nel README o nel task;
- comportamento coerente tra iOS/Android/Supabase;
- nessun comando che “passa” se non ha trovato il target da verificare.


### A126-H9 — Scanner self-test RED/GREEN obbligatorio

Ogni scanner o comando TASK-126 nuovo deve avere fixture minime:

- fixture **RED** che deve fallire quando manca owner/store scope, base version, changedFields, Review conflict o active-store-only rule;
- fixture **GREEN** che deve passare con struttura corretta;
- report che mostri quali fixture sono state eseguite;
- exit code non-zero se il test dello scanner fallisce.

Evidence richiesta:

```text
docs/TASKS/EVIDENCE/TASK-126/agent-runs/
  -1-08-scanner-self-tests-red-green.md/json
```

Uno scanner senza self-test non può essere usato come prova finale per REVIEW.

### A126-H10 — Gap noto da verificare su current-main

La review repo-grounded del piano deve trattare come **gap da verificare in Phase -1** il fatto che i nomi scanner specifici TASK-126 potrebbero non essere ancora presenti nel dispatcher `mc-agent.sh`/`help-json` corrente. Non è un blocker di planning, ma è un blocker di Execution business.

Regola:

- se `scan task126-policy-matrix` e gli altri scanner TASK-126 non compaiono in `help-json`, implementarli o instradarli in modo esplicito;
- vietato riusare scanner legacy TASK-117/118/124 come prova TASK-126 se non controllano realmente i nuovi invarianti;
- ogni alias legacy deve dichiarare nel report quale invariant TASK-126 copre.

### A126-H11 — Evidence completeness schema

Ogni report `.json` TASK-126 deve includere almeno:

```json
{
  "schemaVersion": "1.1-or-newer",
  "taskId": "TASK-126",
  "command": "...",
  "result": "PASS|FAIL|BLOCKED|PASS_WITH_NOTES|NOT_RUN|MISCONFIGURED|UNSAFE_OPERATION_REFUSED",
  "scope": "ios|android|supabase|cross-platform|harness",
  "inputs": {
    "prefix": "TASK126_* or null",
    "profile": "dry-run-no-db|local|linked|null",
    "live": false,
    "cleanup": false
  },
  "checks": [],
  "skipped": [],
  "redaction": {
    "applied": true,
    "sensitiveFindings": 0
  },
  "cleanup": {
    "required": false,
    "dryRunReport": null,
    "executeReport": null,
    "residue": null
  },
  "nextAction": "..."
}
```

Se un report finale non espone skipped cases, il caso si considera `NOT_RUN`, non `PASS`.

### A126-H12 — README e command catalog obbligatori

Se vengono aggiunti comandi o scanner TASK-126:

- aggiornare `tools/agent/README.md` con esempi one-line TASK-126;
- aggiornare `help-json` / `list commands-json`;
- aggiungere esempi per Cursor/Codex/Claude;
- documentare safety gate e prefissi;
- verificare che MCP adapter esponga solo comandi allowlisted e non duplichi logica.

Evidence richiesta:

```text
-1-09-command-catalog-update.md/json
-1-10-mcp-allowlist-parity.md/json
```

### A126-H13 — Timeout, lock e noise budget per agent UX

Ogni comando nuovo deve avere:

- timeout ragionevole o progress heartbeat;
- lock per live/cleanup/sync matrix;
- output breve di default;
- `--verbose` per dettaglio diagnostico;
- `NEXT_ACTION` sempre presente in caso `BLOCKED`, `MISCONFIGURED` o `UNSAFE_OPERATION_REFUSED`;
- niente log rumorosi con migliaia di righe non riassunte.

### A126-H14 — Manual fallback escalation

Il fallback manuale è ammesso solo per diagnostica una tantum e deve essere documentato come `MANUAL_DIAGNOSTIC_NOT_FINAL_EVIDENCE`. Se una verifica è necessaria per REVIEW e viene ripetuta più di una volta, deve diventare wrapper `mc-agent`.

### A126-H15 — Report di differenza piano vs execution

A fine Execution, prima del final gate, produrre:

```text
58-plan-vs-execution-delta.md/json
```

Deve elencare:

- cosa del piano è stato implementato;
- cosa è rimasto planning-only;
- quali casi C126 sono `PASS_WITH_NOTES`, `NOT_APPLICABLE` o `BLOCKED_EXTERNAL`;
- perché eventuali deviazioni non violano P0 sync safety.

## Motivazione

TASK-125 ha chiuso la sync core real-device iOS ↔ Android ↔ Supabase con nota accettata per background iOS, ma ora serve rendere esplicita e implementabile la policy per:

1. casi normali pull/push incrementali;
2. account switch;
3. local dirty/offline;
4. remote dirty;
5. conflitti field-level;
6. delete-vs-edit;
7. owner/store mismatch;
8. ProductPrice storico;
9. bulk import offline;
10. cache locale multi-account / multi-store con controllo memoria;
11. UX Review/Recovery solo quando serve davvero.

L'obiettivo non è rifare la sync da zero, ma consolidare una policy unica e testabile che impedisca perdita dati, cross-account contamination e full pull non necessari.

## Fonti obbligatorie da leggere prima di qualunque patch

### iOS — target principale

Leggere prima GitHub `main` e poi locale, se richiesto dal workflow locale.

- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-125-real-device-cross-platform-sync-final-architecture.md`
- `iOSMerchandiseControl/Sync/Account/AccountBindingStore.swift`
- `iOSMerchandiseControl/Sync/Account/AccountSwitchPolicy.swift`
- `iOSMerchandiseControl/Sync/Account/AccountSyncDecision.swift`
- `iOSMerchandiseControl/Sync/Account/AccountSyncDecisionView.swift`
- `iOSMerchandiseControl/Sync/Account/LocalStoreIdentity.swift`
- `iOSMerchandiseControl/Sync/SyncOrchestrator.swift`
- `iOSMerchandiseControl/Sync/SyncAutomaticRuntimeProviders.swift`
- `iOSMerchandiseControl/Sync/Automatic/Decision/**`
- `iOSMerchandiseControl/Sync/Automatic/Pull/**`
- `iOSMerchandiseControl/Sync/Automatic/Outbox/**`
- `iOSMerchandiseControl/Sync/Automatic/Presentation/**`
- `iOSMerchandiseControl/Sync/Outbox/**`
- `iOSMerchandiseControl/Sync/Recovery/**`
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/ContentView.swift`
- `iOSMerchandiseControl/Models.swift`
- `iOSMerchandiseControl/LocalPendingChange.swift`
- test sync/account/offline/recovery già presenti

### Android — parity e riferimento funzionale

Android non deve essere copiato 1:1, ma la policy deve essere equivalente.

- `CatalogAutoSyncCoordinator.kt`
- `RealtimeRefreshCoordinator.kt`
- `SupabaseSyncEventRemoteDataSource.kt`
- `SupabaseSyncEventRealtimeSubscriber.kt`
- `InventoryRepository.kt`
- ProductPrice local/remote data sources
- Room entities/DAO/migrations per Product, Supplier, Category, ProductPrice, HistoryEntry
- WorkManager/lifecycle/network hooks
- Options/status UI provider, se presente
- test JVM/instrumented sync/offline/conflict, se presenti

### Supabase — contract read-only prima di codice

Non inventare tabelle/colonne se schema già esiste. Prima leggere:

- migrations/schema/RLS/grants per `inventory_*`
- `inventory_product_prices`
- `shared_sheet_sessions`
- `sync_events`
- `record_sync_event`
- eventuali RPC/cursor/event ledger esistenti
- eventuali tabelle auth/profile/membership già presenti

## Obiettivo

Implementare o almeno rendere eseguibile in un unico task una policy cross-platform per:

1. **account identity**: ogni store locale è legato a un account/owner;
2. **future store identity**: preparare `storeId/workspaceId` per negozi multipli;
3. **multi-store cache MVP**: cache locale separata o logically separated per account/store, con un solo store attivo caricato in memoria;
4. **sync normal path**: push/pull incrementale, no full pull normale;
5. **offline dirty handling**: outbox persistente, owner/store scoped;
6. **field-level conflict resolution**: merge automatico se campi diversi, Review se stesso campo;
7. **ProductPrice storico**: append/dedupe/stale policy, non overwrite generico;
8. **Review/Recovery UX**: chiedere solo quando c'è rischio perdita dati o ambiguità;
9. **memory budget**: iOS SwiftData e Android Room non devono caricare tutti gli account/negozi/ProductPrice in RAM;
10. **test matrix**: casi normali, estremi, account switch, store switch, kill/restart, network flap, cursor gap, schema mismatch.

## Principio guida

Il database locale non è globale. È una cache/workbench scoped a:

```text
accountIdentity + tenantIdentity? + storeIdentity? + schemaVersion + syncProtocolVersion
```

Per MVP:

```text
accountIdentity + activeStoreIdentity
```

Dove `activeStoreIdentity` può essere inizialmente un default store implicito, ma la struttura deve essere compatibile con negozi multipli futuri.

### Regole fondamentali

- Supabase è fonte canonica dei dati già sincronizzati per quello specifico account/store.
- L'outbox locale è fonte temporanea delle modifiche non ancora pushate, ma solo per lo stesso account/store.
- È vietato pushare pending creati sotto account A o store X dentro account B o store Y.
- È vietato cancellare o sovrascrivere dati locali dirty senza Review/Recovery o conferma esplicita.
- Il normal path resta incrementale.
- Full pull/reseed è ammesso solo per setup, account/store switch confermato, recovery, cursor gap/corruption, schema/protocol upgrade.
- Solo lo store attivo deve essere aperto/caricato in memoria.
- Gli store non attivi possono restare come cache su disco, chiusa e cancellabile secondo policy.

## Definizioni

### Account

Identità autenticata tramite Google, WeChat, email o account creato dall'amministratore.

### App user

Profilo interno dell'app, mappato a una o più identità auth.

### Tenant / Organization

Cliente, azienda o famiglia di negozi. Per MVP può essere implicito.

### Store / Shop / Workspace

Singolo negozio/magazzino/catalogo separato. Per MVP può esistere un `defaultStoreId`, ma la cache deve essere pronta a diventare multi-store.

### Local store identity

Metadato locale che lega il DB/cache locale a account/store/schema/protocol:

```text
localStoreId
accountId / ownerHash
profileId
projectRef
storeId / workspaceId
schemaVersion
syncProtocolVersion
storeEpoch
boundAt
lastVerifiedAt
lastOpenedAt
lastCompactedAt
isDirty
pendingCount
lastKnownRemoteCursorByDomain
```

### Dirty local store

Store locale con pending/outbox non ackati o recovery item aperti.

### Clean local store

Store locale senza pending/outbox/recovery e con cursori coerenti.

### Conflict

Conflitto reale solo quando due modifiche agiscono sullo stesso campo logico della stessa entità partendo dalla stessa base, oppure quando c'è delete-vs-edit.

## Decisioni architetturali TASK-126

### D126-01 — Local store account/store-bound

Ogni pending/outbox/cursor deve includere almeno:

```text
ownerHash
accountId/profileId, se disponibile
storeId/workspaceId, anche default
localStoreId
syncProtocolVersion
schemaVersion
```

Se account/store attivo non combacia con pending/outbox/cursor, bloccare automatic push e aprire Review/Recovery.

### D126-02 — Base version obbligatoria per pending changes

Ogni pending change mutativa deve salvare la base da cui è partita:

```text
entityDomain
entityLocalId
entityRemoteId
businessKey
changedFields
baseRemoteUpdatedAt
baseRemoteVersion / baseEventId, se disponibile
localNewValues
createdAt
ownerHash
storeId
idempotencyKey
```

Serve per distinguere merge automatico da conflitto vero.

### D126-03 — Field-level merge

Se local e remote modificano campi diversi della stessa entità, merge automatico.

Esempio:

```text
iOS offline: productName = "MX"
Android online: retail price cambia tramite ProductPrice
Risultato: merge automatico
```

### D126-04 — Same-field conflict Review

Se local e remote modificano lo stesso campo logico della stessa entità, Review.

Esempio:

```text
iOS offline: productName = "MX"
Android online: productName = "X"
Risultato: Review conflitto
```

### D126-05 — ProductPrice non è normale overwrite

ProductPrice è dominio storico. La policy deve essere:

- append se evento nuovo;
- idempotent dedupe se stesso product/type/effectiveAt/value;
- Review o stale reject se stesso product/type/effectiveAt vicino ma value diverso;
- mai full load in memoria;
- keyset pagination e batch apply obbligatori.

### D126-06 — Multi-store cache MVP

Nel TASK-126 si introduce una base MVP per multi-store/account cache:

- ogni store locale ha identità separata;
- switch account/store controllato;
- solo store attivo aperto in memoria;
- altri store restano su disco o non creati;
- cache vecchie eliminabili con policy LRU/manuale;
- ProductPrice e sync_events paginati;
- outbox/cursor per store separati.

L'MVP può essere implementato in due modalità, da decidere dopo audit:

#### Opzione A — Physical multi-store cache

File DB separato per account/store.

```text
iOS SwiftData/SQLite:
MerchandiseControl-{ownerHash}-{storeId}.sqlite

Android Room:
merchandisecontrol_{ownerHash}_{storeId}.db
```

Pro:
- massima separazione;
- rischio cross-account minimo;
- cleanup per store semplice.

Contro:
- richiede attenzione a lifecycle ModelContainer/Room DB;
- serve safe switch e ricostruzione contesti.

#### Opzione B — Single physical DB, logical store scope

Un DB fisico con colonne/metadati owner/store ovunque.

Pro:
- meno invasiva;
- più semplice da introdurre se SwiftData ModelContainer è rigido.

Contro:
- rischio query senza filtro owner/store;
- più difficile garantire isolamento;
- più memoria se query sbagliate.

#### Decisione consigliata

- Audit prima.
- Preferire **Opzione A** se ModelContainer/Room lifecycle può essere gestito senza grandi regressioni.
- Usare **Opzione B** solo come step intermedio, con scanner obbligatorio per query senza owner/store scope.

### D126-07 — Account switch diverso da store switch

#### Cambio account

Safety-critical:

- bloccare se store dirty;
- Review/Recovery se pending esistono;
- vietato push A → B;
- conferma forte se si scarta/reseeda.

#### Cambio store nello stesso account

Meno pericoloso, ma scoped:

- outbox Store Centro ≠ outbox Store Periferia;
- cursor Store Centro ≠ cursor Store Periferia;
- se Store Centro ha pending offline, restano pending di Centro;
- aprire Store Periferia non deve pushare dati Centro;
- badge/status deve mostrare pending per store non attivo se noto, senza caricare tutto.

### D126-08 — No global background sync di tutti gli store nel MVP

Per controllo memoria e batteria:

- sync completa solo store attivo;
- store recenti: solo drain outbox leggero se già noto e sicuro, opzionale e feature-gated;
- metadata lista store: leggera;
- nessuna scansione completa di tutti i ProductPrice di tutti gli store.

### D126-09 — Full pull/reseed policy

Full pull/reseed consentito solo per:

1. primo login;
2. primo accesso a uno store su quel device;
3. account switch clean confermato;
4. store switch verso cache assente;
5. cursor/event gap;
6. local store corrotto;
7. schema/protocol upgrade;
8. recovery esplicita.

Mai nel normal automatic path.

### D126-10 — UX confirmation policy

Non chiedere conferma per operazioni sicure automatiche. Chiedere conferma per:

- account switch con local dirty;
- account switch clean ma con reseed visibile;
- store switch con cache assente e primo download grande;
- same-field conflict;
- delete-vs-edit;
- reset/reseed recovery;
- owner/store mismatch;
- scarto pending;
- migrazione dati tra account/store.

### D126-11 — Legacy/unbound local store repair

TASK-126 deve gestire dispositivi che aggiornano da una versione precedente dove il DB locale non ha ancora `LocalStoreIdentity`, `storeId`, `syncProtocolVersion` o cursori owner/store-scoped.

Policy:

- se local è vuoto o clean e l'account attivo è verificato, creare `LocalStoreIdentity` con `defaultStoreId` e cursori iniziali coerenti;
- se local contiene dati ma non è possibile provare l'owner remoto, entrare in Review/Recovery, non bindare automaticamente;
- se local ha pending/outbox legacy, bloccare automatic push finché non viene migrato o scartato esplicitamente;
- non fare reseed distruttivo prima di backup/export attempt o conferma forte;
- produrre evidence `legacy-unbound-store-repair`.

### D126-12 — Store epoch e remote reset detection

Ogni store deve avere un concetto di `storeEpoch` o equivalente remoto/logico. Serve a distinguere:

- normale incremento eventi;
- store appena creato;
- store remoto resettato/ricreato;
- cursor locale puntato a una storia remota non più valida.

Se `storeEpoch` remoto non combacia con local:

- se local clean: recovery/reseed controllato;
- se local dirty: Review/Recovery obbligatoria;
- vietato wipe silenzioso.

### D126-13 — Switch account/store lock e cancellation

Cambio account/store deve essere serializzato con il runtime sync:

- nessun switch durante fase mutativa `pushing`, `acking`, `saving`, `applying` senza sospensione sicura;
- se sync è cancellabile, cancellare e lasciare pending non acked;
- se sync è in fase atomica non interrompibile, mostrare stato `Switch in attesa` o bloccare temporaneamente;
- dopo switch, invalidare subscription/realtime/cursor del vecchio store e aprire solo target store;
- WorkManager/BGTask non deve continuare con identity vecchia.

### D126-14 — Default store identity stabile

Per MVP monostore compatibile con futuro multistore, `defaultStoreId` deve essere stabile e non derivato da nomi utente/negozio mutabili.

Suggerimento:

```text
defaultStoreId = remote store id se esiste
fallback locale temporaneo = default:<ownerHash>:v1, mai usato come id remoto definitivo
```

Quando Supabase introdurrà `stores`, deve esistere migration path da default locale a store remoto senza duplicare dati.

### D126-15 — Physical cache spike obbligatorio prima di Opzione A

Opzione A è preferita, ma prima di implementarla serve spike tecnico:

- iOS: verificare se `ModelContainer` può essere ricreato/sostituito in root senza rompere `@Environment(\.modelContext)`, `@Query`, background contexts e Navigation state;
- Android: verificare chiusura/riapertura Room DB, DAO/repository injection, WorkManager e Flow collectors;
- se lo spike mostra alto rischio, usare Opzione B temporanea con scanner query scope obbligatori.

Evidence:

```text
04a-ios-physical-cache-spike.md/json
04b-android-physical-cache-spike.md/json
04c-cache-option-risk-decision.md/json
```

### D126-16 — Conflict batch UX e risoluzione parziale

Review conflitti deve supportare batch grandi:

- raggruppare conflitti per dominio/campo/tipo;
- permettere `Applica a conflitti simili` solo se stessa regola, stesso campo e nessun delete-vs-edit;
- permettere merge automatico dei non-conflitti nello stesso sync run;
- non bloccare tutto lo store se solo poche entità sono in conflitto, salvo dipendenze critiche.

### D126-17 — Metrics e observability TASK-126

Ogni sync run rilevante deve produrre metriche privacy-safe:

```text
syncRunId
ownerHash redatto/storeId redatto
domain
pendingBefore/After
remoteEventsSeen
mergedCount
conflictCount
reviewCreatedCount
ackedCount
retryCount
cursorBefore/After
pageSize
rowsApplied
peakMemory/RSS/PSS se disponibile
durationMs per stage
```

### D126-18 — Permission/membership change con dirty local

Se in futuro un utente perde accesso a uno store mentre ha modifiche locali dirty:

- bloccare push;
- preservare outbox locale;
- mostrare stato `Accesso revocato o permessi cambiati`;
- consentire export/backup locale se policy lo permette;
- non cancellare cache dirty automaticamente.

## I quattro casi principali richiesti

### Caso 1 — Stesso account/store, local e remote già sincronizzati

#### 1A — Local dirty only

Situazione:

```text
local ha modifiche pending
remote non ha eventi nuovi rilevanti
account/store combacia
```

Azione:

- push automatico;
- ack atomico solo dopo remote write + sync_event/cursor + save locale;
- pull incrementale di conferma;
- nessuna conferma utente.

#### 1B — Remote dirty only

Situazione:

```text
local clean
remote ha eventi nuovi
account/store combacia
```

Azione:

- pull incrementale automatico;
- apply in background context;
- update cursor;
- nessuna conferma utente.

#### 1C — Local + remote dirty ma senza conflitto

Situazione:

```text
local cambia productName
remote cambia ProductPrice o altro campo compatibile
```

Azione:

- merge automatico field-level;
- push/pull incrementale;
- nessuna conferma utente;
- metriche sync run.

### Caso 2 — Account switch verso account nuovo/vuoto

#### Local clean

Azione:

- conferma leggera;
- attiva store/cache dell'account B;
- se remote B vuoto, local B resta vuoto;
- non cancellare necessariamente cache A se multi-store fisico: chiudere A e aprire B;
- no merge A → B.

#### Local dirty

Azione:

- bloccare automatic push;
- mostrare Review/Recovery;
- opzioni: torna ad account A e sincronizza, esporta backup, scarta pending, annulla;
- eventuale migrazione/import verso B solo flow esplicito separato.

### Caso 3 — Account switch verso account già popolato

#### Local clean

Azione:

- conferma leggera;
- aprire/cache B;
- se cache B assente, reseed da remote B;
- se cache B presente, incremental verify;
- non fare merge automatico tra account A e B.

#### Local dirty

Azione:

- come Caso 2 dirty;
- niente push cross-account;
- Review/Recovery obbligatoria.

### Caso 4 — Offline local changes + remote changes contemporanee

#### Campi diversi / domini compatibili

Esempio:

```text
iOS offline cambia productName
Android cambia prezzo dello stesso prodotto
```

Azione:

- merge automatico;
- ProductPrice append/dedupe;
- nessuna conferma.

#### Stesso campo

Esempio:

```text
iOS offline cambia productName = "MX"
Android cambia productName = "X"
```

Azione:

- Review conflitto;
- mostra locale/cloud/base se possibile;
- scelte: usa locale, usa cloud, modifica manualmente, applica a conflitti simili se sicuro.

#### Delete-vs-edit

Azione:

- Review obbligatoria;
- evitare resurrection silenziosa;
- possibile: ripristina, elimina, crea copia, annulla.

## Policy matrix completa

| ID | Scenario | Azione corretta | Conferma utente | Full pull/reseed | Note |
|---|---|---|---|---|---|
| C126-00 | Primo avvio, no account | sync bloccata, store non bindato | no | no | mostra sign-in/status |
| C126-01 | Primo login account/store | crea local store identity + primo pull | no/leggera | setup only | se dataset grande mostra progress |
| C126-02 | Stesso account/store, local clean, remote clean | idle/synced | no | no | Options può dire aggiornato |
| C126-03 | Stesso account/store, local dirty only | push automatico + ack atomico + pull conferma | no | no | owner/store must match |
| C126-04 | Stesso account/store, remote dirty only | pull incrementale automatico | no | no | cursor per dominio |
| C126-05 | Local+remote dirty, entità diverse | merge automatico | no | no | metriche run |
| C126-06 | Local+remote dirty, stessa entità ma campi diversi | field-level merge automatico | no | no | base version obbligatoria |
| C126-07 | Local+remote dirty, stesso campo | Review conflitto | sì | no | blocca solo entità conflittuali |
| C126-08 | Remote delete vs local edit | Review/Recovery | sì | no | evitare resurrection |
| C126-09 | Local delete vs remote edit | Review/Recovery | sì | no | tombstone policy |
| C126-10 | Network flap durante ack | pending resta non acked, retry/backoff | no | no | atomic ack |
| C126-11 | App kill/restart con pending | pending persistente, drain su relaunch/reconnect | no | no | outbox durable |
| C126-12 | Bulk Excel import offline | chunked outbox + coalescing | no se no conflict | no | memory budget |
| C126-13 | Cursor/event gap | recovery mirata/anti-entropy | forse | recovery only | distinguere da normal full pull |
| C126-14 | Local store owner mismatch | blocco automatic push + Review | sì | recovery only | fail-closed |
| C126-15 | Account A clean → account B vuoto | apri/cache B; B vuoto | sì leggera | setup/reseed | no merge A→B |
| C126-16 | Account A clean → account B popolato | apri/cache B; reseed/verify B | sì leggera | setup/reseed | no merge A→B |
| C126-17 | Account A dirty → account B | blocco push + Review/Recovery | sì forte | no finché non decide | vietato push A→B |
| C126-18 | Logout/login stesso account | keep cache se owner/store combacia | no/leggera | no | verify cursor/session |
| C126-19 | Token expired mid-sync | stop, no ack partial, retry after auth | no | no | blockedAuth |
| C126-20 | RLS/permission denied | fail-closed + user/admin action | sì se recovery | no | no bypass RLS |
| C126-21 | Schema/protocol mismatch | fail-closed + migration/recovery | sì | recovery only | no corruption |
| C126-22 | Device clock skew | server timestamp/event order wins | no | no | client effectiveAt business |
| C126-23 | Supplier/category duplicate case/trim | deterministic dedupe | no | no | normalized key |
| C126-24 | Same barcode created offline two devices | merge or Review | sì se field conflict | no | barcode business key |
| C126-25 | ProductPrice same product/type/effectiveAt/value | idempotent dedupe | no | no | no duplicate |
| C126-26 | ProductPrice same product/type/effectiveAt but value different | Review or stale reject | sì/forse | no | policy explicit |
| C126-27 | Remote reset/cleanup detected | recovery review, no silent wipe dirty | sì | recovery only | backup recommended |
| C126-28 | Store switch same account, current store clean | open target store/cache | no/leggera | setup if cache absent | no cross-store merge |
| C126-29 | Store switch same account, current store dirty | allow switch only if outbox store-scoped | no/leggera | no | pending badge per old store |
| C126-30 | Store switch target has local pending from older session | show pending badge, do not mix | no | no | drain only target store |
| C126-31 | Cache storage pressure | LRU cleanup clean inactive stores | sì if deleting cache with unsynced? | no | never delete dirty cache |
| C126-32 | Corrupted local store | recovery/reseed after backup attempt | sì | recovery only | store-specific |
| C126-33 | Admin disables user/store remotely | block sync + status | sì if action needed | no | RLS/status-aware |
| C126-34 | Membership role changes | refresh permissions + block forbidden operations | no/sì | no | future multi-user |
| C126-35 | Multiple login identities mapped to same app user | bind to app user/store, not raw provider only | no | no | Google/WeChat future |
| C126-36 | Upgrade da app legacy senza LocalStoreIdentity | bind/repair guidato o Review | sì se dati/pending presenti | setup/recovery only | no auto-bind ambiguo |
| C126-37 | Local legacy clean + account verificato | crea defaultStoreId/local identity | no/leggera | no | migrazione locale sicura |
| C126-38 | Local legacy dirty/pending | blocca push + Review/Recovery | sì forte | no | nessun push finché non migrato |
| C126-39 | Store epoch mismatch remoto | recovery/reseed se clean, Review se dirty | sì se dirty | recovery only | remote reset detection |
| C126-40 | Cambio store/account durante sync mutativa | suspend/cancel safe o wait | no/sì se bloccato | no | no partial ack |
| C126-41 | Trigger sync concorrenti stesso dominio | single-flight, dedupe trigger | no | no | actor/runtime lock |
| C126-42 | Harness comando obbligatorio mancante | ACTIVE / FIX — HARNESS_GAP | no | no | no workaround manuale finale |
| C126-43 | Scanner TASK-126 senza RED/GREEN | FAIL harness gate | no | no | non valido per REVIEW |
| C126-44 | Old app/client senza store protocol | fail-safe o compatibility path | sì se update richiesto | no | protocolVersion gate |
| C126-45 | Batch conflict parziale | merge non-conflitti, Review solo conflitti | sì per conflitti | no | UX batch |
| C126-46 | Memory budget superato ProductPrice/cache | stop/retry smaller page/recovery | forse | no | evidence quantitativa |
| C126-47 | Cache inattiva molto vecchia | incremental verify o cleanup se clean | sì se elimina | setup if deleted | no dirty cleanup |
| C126-48 | Membership/store permission revoked con dirty local | block push, preserve/export | sì | no | futuro multi-user |

## Conflict policy by domain

### Product

Field-level merge allowed for independent fields:

- `productName`
- `secondProductName`
- `itemNumber`
- supplier/category reference
- stock/quantity if policy exists
- remote IDs / metadata

Conflict if same field changed by both local and remote after same base.

### Supplier / Category

- Normalize `trim + lowercase/casefold` for duplicate detection.
- Rename same entity same field conflict → Review.
- Two devices create same normalized name → deterministic dedupe.
- Deleting supplier/category used by products → Review or blocked if FK/business rule requires.

### ProductPrice

- Append-only/history-first.
- Idempotency key should include product remote id/business key, type, effectiveAt, value/source signature.
- Same product/type/effectiveAt/value → dedupe.
- Same product/type/effectiveAt but different value → Review or stale policy.
- Different type PURCHASE vs RETAIL → no conflict.
- Different effectiveAt sufficiently separated → append.
- Never load all ProductPrice into memory.

### History / Session / Generated sheet

- History/session delete-vs-edit → Review.
- Rename/title conflict → Review if same field.
- Generated row edits can merge field-level if row identity stable.
- Exported status/metadata should not overwrite business fields blindly.

### Sync events

- Deduplicate seen event IDs.
- Skip self events.
- Gap detection triggers incremental pull or recovery, not normal full pull.

## Multi-store / multi-account cache MVP

### Target futuro

```text
AuthIdentity
  Google / WeChat / email / admin-created login

AppUser
  internal user profile

Tenant / Organization
  cliente o azienda

Store / Shop / Workspace
  negozio/magazzino/catalogo

Inventory Data
  suppliers, categories, products, product_prices, history, sessions, sync_events
```

### MVP TASK-126

Non serve implementare tutta la gestione admin/negozi/ruoli, ma il TASK-126 deve evitare di costruire una sync mononegozio impossibile da estendere.

Implementare o preparare:

1. `storeId` / `workspaceId` default nello `LocalStoreIdentity`.
2. outbox/cursor scoped per `ownerHash + storeId`.
3. status UI capace di distinguere account/store attivo.
4. cache active-store-only.
5. memory budget e cleanup per cache inattive.
6. Supabase contract review per capire dove aggiungere store scope in futuro.

### Cache memory rules iOS

- Un solo `ModelContainer`/store attivo aperto, se fisicamente possibile.
- Background sync usa `ModelContainer`/`ModelContext` non UI.
- Nessun apply/save pesante su MainActor.
- ProductPrice: keyset pagination + batch apply + progress throttling.
- Non materializzare array completi di ProductPrice/prodotti di tutti gli store.
- Cache inactive: file su disco, non caricata.
- Store switch: cancel/suspend sync corrente, flush stato, apri nuovo store, verify identity, poi incremental pull.
- Dirty inactive store: non cancellabile da cleanup automatico.
- LRU cleanup solo per store clean/inattivi.

### Cache memory rules Android

- Room DB attivo per account/store, o logical scope obbligatorio se DB unico.
- DAO/query devono essere owner/store scoped se DB unico.
- WorkManager deve passare account/store identity in input data.
- ProductPrice pull/apply paginato, non full memory load.
- Paging per database UI resta obbligatorio.
- Inactive stores non devono avere flussi Room osservati in UI.
- Cleanup cache solo per store clean/inattivi.
- Dirty cache mai cancellata automaticamente.

### Store cache status

Ogni store cache può essere:

```text
notCreated
cleanCached
active
activeDirty
inactiveDirty
requiresRecovery
corrupted
cleanupEligible
blockedAccountMismatch
blockedStoreMismatch
```

### Cache cleanup policy

- Mai eliminare cache dirty.
- Mai eliminare cache con recovery aperta.
- Eliminare solo cache clean/inattive dopo conferma o policy LRU documentata.
- Prima di eliminare cache grande, mostrare spazio stimato se disponibile.
- Eliminare cache non elimina dati cloud.
- Se utente riapre store eliminato, fare setup/reseed da Supabase.

### Budget memoria/performance misurabile

TASK-126 non deve chiudere con dichiarazioni qualitative tipo “memoria ok”. Deve produrre almeno:

- dataset size usato o fixture sintetica dichiarata;
- ProductPrice page size;
- numero righe applicate/skippate;
- durata fetch/apply/save;
- peak RSS/PSS dove disponibile;
- numero store cache aperti/osservati;
- prova che inactive store non ha flussi osservati o contesti aperti;
- eventuale riduzione page size/backpressure se budget superato.

La soglia numerica finale può essere calibrata in Execution in base a device/simulator disponibili, ma la regola architetturale è fissa: memoria deve crescere per pagina/batch, non in proporzione a tutti gli store o a tutta la history ProductPrice globale.

### Cache inventory manifest

Ogni cache locale deve avere o derivare un manifest leggero:

```text
localStoreId
ownerHash/storeId redatti
status
lastOpenedAt
lastSyncedAt
pendingCount
estimatedDiskBytes se disponibile
schemaVersion
syncProtocolVersion
storeEpoch
cleanupEligible
```

La lista negozi/cache deve leggere questo manifest, non aprire tutti i database/store per contare prodotti o ProductPrice.

## UX richiesta

### Options / Sync status card

Stati user-facing:

- Aggiornato
- Modifiche locali in attesa
- Offline, sincronizzazione in coda
- Sincronizzazione in corso
- Riconnessione: controllo modifiche
- Richiede revisione conflitti
- Bloccato: account diverso
- Bloccato: negozio diverso
- Bloccato: accesso/RLS
- Recovery richiesta
- Cache locale danneggiata
- Store non ancora scaricato su questo dispositivo

### Account switch clean dialog

Titolo: `Cambiare account?`

Testo: `Questo archivio locale appartiene all'account precedente. Passando al nuovo account, l'app mostrerà i dati cloud del nuovo account. I dati già sincronizzati restano nel cloud dell'account precedente.`

Azioni:

- Continua
- Annulla

### Account switch dirty dialog

Titolo: `Modifiche locali non sincronizzate`

Testo: `Questo dispositivo contiene modifiche locali dell'account precedente. Non verranno inviate al nuovo account. Sincronizza con l'account precedente, esporta un backup o scartale prima di continuare.`

Azioni:

- Torna all'account precedente
- Esporta backup
- Scarta e cambia account
- Annulla

### Store switch dialog — cache assente / download grande

Titolo: `Aprire questo negozio?`

Testo: `Questo negozio non è ancora disponibile su questo dispositivo. L'app scaricherà i dati cloud del negozio e creerà una cache locale.`

Azioni:

- Apri negozio
- Annulla

### Store dirty badge

Esempio lista negozi:

```text
Negozio Centro       Aggiornato
Negozio Periferia    12 modifiche in attesa
Magazzino            Mai scaricato su questo dispositivo
```

### Conflict Review

Mostrare solo conflitti reali:

- nome prodotto locale/cloud;
- valore base, se disponibile;
- data modifica locale/cloud;
- device/source, se disponibile e privacy-safe;
- azioni: Usa locale, Usa cloud, Modifica manualmente, Mantieni entrambe se dominio lo permette.

### UX anti-over-alert

Regola: Review/alert solo per rischio reale. Gli stati informativi devono preferire banner/card non bloccanti.

- Local-only dirty: badge `Modifiche in attesa`, niente popup.
- Remote-only dirty: progress leggero, niente popup.
- Field-level merge automatico: eventualmente toast/snackbar riepilogo, niente popup.
- Same-field conflict/delete-vs-edit/account dirty switch: sheet/dialog Review.
- Harness/operator error: messaggio con `NEXT_ACTION`, non stack trace grezzo.

### Accessibility e localizzazione

Ogni nuova UI deve prevedere:

- copy IT/EN/ES/ZH-Hans;
- Dynamic Type / large text su iOS;
- TalkBack/VoiceOver label per badge store e conflitti;
- destructive action marcata chiaramente;
- default action non distruttiva;
- possibilità di annullare senza perdere pending.

## Fasi di execution suggerite

### Phase -1 — Automation discovery and harness hardening gate

Questa fase è obbligatoria e precede il canonical audit. È ancora Planning/Execution-Audit, non implementazione business.

Obiettivi:

- scoprire i comandi reali disponibili tramite `help-json` e `list commands-json`;
- verificare che i report vadano in `docs/TASKS/EVIDENCE/TASK-126/`;
- verificare redaction/safety/exit code;
- creare o migliorare scanner/wrapper TASK-126 mancanti prima di runtime matrix;
- aggiornare `tools/agent/README.md` con esempi TASK-126 se vengono aggiunti nuovi comandi;
- validare MCP adapter solo come wrapper thin, senza duplicare logica.

Comandi minimi:

```bash
MC_TASK_ID=TASK-126 ./tools/agent/mc-agent.sh help-json
MC_TASK_ID=TASK-126 ./tools/agent/mc-agent.sh list commands-json
MC_TASK_ID=TASK-126 ./tools/agent/mc-agent.sh config validate
MC_TASK_ID=TASK-126 ./tools/agent/mc-agent.sh git head-consistency --task TASK-126
MC_TASK_ID=TASK-126 ./tools/agent/mc-agent.sh preflight --require-head-consistency --task TASK-126
MC_TASK_ID=TASK-126 ./tools/agent/mc-agent.sh scan automation-discovery --task TASK-126
MC_TASK_ID=TASK-126 ./tools/agent/mc-agent.sh report validate-json --task TASK-126 --path docs/TASKS/EVIDENCE/TASK-126/agent-runs
```

Se `scan automation-discovery --task TASK-126` non esiste o viene instradato a scanner legacy senza coprire TASK-126, aggiungerlo o migliorarne il routing.

Evidence:

- `-1-00-help-json.md/json`
- `-1-01-commands-json.md/json`
- `-1-02-config-validate.md/json`
- `-1-03-head-consistency.md/json`
- `-1-04-preflight.md/json`
- `-1-05-automation-discovery.md/json`
- `-1-06-harness-gap-list.md/json`
- `-1-07-harness-improvements.md/json`, se sono stati aggiunti comandi/scanner

Exit:

- nessuna patch business finché i comandi obbligatori non sono scoperti, funzionanti e reportano correttamente;
- se harness manca, stato corretto `ACTIVE / FIX — HARNESS_GAP`, non workaround manuale.

### Phase 0 — Canonical audit and no-code gate

Obiettivi:

- leggere iOS GitHub main;
- leggere local iOS se necessario;
- leggere Android riferimento;
- leggere Supabase schema read-only;
- classificare se iOS può supportare physical multi-store cache senza grande refactor.

Evidence:

- `00-canonical-head.md/json`
- `01-ios-sync-account-cache-audit.md/json`
- `02-android-sync-account-cache-audit.md/json`
- `03-supabase-store-scope-contract-audit.md/json`
- `04-multistore-cache-option-decision.md/json`

Exit:

- scegliere Opzione A physical multi-store o Opzione B logical scope MVP.

### Phase 1 — Shared policy contract

Obiettivi:

- scrivere/aggiornare contratto sync cross-platform;
- decision matrix C126-00…C126-60;
- conflict domain policy;
- base version contract;
- memory/cache policy.

Evidence:

- `10-shared-sync-policy-contract.md/json`
- `11-conflict-resolution-policy.md/json`
- `12-account-store-boundary-contract.md/json`
- `13-cache-memory-policy.md/json`

Exit:

- nessuna patch runtime senza contratto approvato internamente.

### Phase 2 — iOS implementation MVP

Obiettivi:

- rafforzare `LocalStoreIdentity` con account/store identity;
- pending/outbox/cursor owner/store scoped;
- base version/changed fields dove manca;
- account switch policy clean/dirty;
- store identity default;
- cache active-store-only o logical scope;
- Options status provider aggiornato;
- Review/Recovery UX per conflitti/account mismatch.

File probabili:

- `Sync/Account/LocalStoreIdentity.swift`
- `Sync/Account/AccountBindingStore.swift`
- `Sync/Account/AccountSwitchPolicy.swift`
- `Sync/Account/AccountSyncDecision.swift`
- `Sync/Account/AccountSyncDecisionView.swift`
- `Sync/Automatic/Decision/SyncDecisionEngine.swift`
- `Sync/Outbox/LocalOutboxStore.swift`
- `Sync/Outbox/PendingChangeCoalescer.swift`
- `Sync/Recovery/**`
- `Sync/Automatic/Presentation/OptionsSyncSummaryProvider.swift`
- `SyncOrchestrator.swift` solo wiring
- `OptionsView.swift` solo UI/status
- `Localizable.strings` IT/EN/ES/ZH-Hans
- test sync/account/offline/recovery

Evidence:

- `20-ios-local-store-identity-implementation.md/json`
- `21-ios-account-switch-policy-implementation.md/json`
- `22-ios-outbox-owner-store-scope.md/json`
- `23-ios-conflict-review-implementation.md/json`
- `24-ios-cache-memory-implementation.md/json`

### Phase 3 — Android parity implementation/audit

Obiettivi:

- verificare o implementare owner/store scope equivalente;
- pending/outbox/cursor equivalent se esistenti;
- WorkManager/lifecycle identity-safe;
- ProductPrice memory/paging invarianti;
- Options/status UI non mostra falso aggiornato.

File probabili:

- `CatalogAutoSyncCoordinator.kt`
- `RealtimeRefreshCoordinator.kt`
- `SupabaseSyncEventRemoteDataSource.kt`
- `SupabaseSyncEventRealtimeSubscriber.kt`
- `InventoryRepository.kt`
- ProductPrice data sources
- Room entities/DAO/migrations se serve metadata locale
- Options/status UI
- test JVM/instrumented

Evidence:

- `30-android-policy-parity-audit.md/json`
- `31-android-owner-store-scope.md/json`
- `32-android-cache-memory-policy.md/json`
- `33-android-conflict-policy-parity.md/json`

### Phase 4 — Supabase contract verification

Obiettivi:

- leggere schema attuale;
- verificare owner/RLS;
- valutare se store scope esiste o va pianificato in task futura;
- non introdurre migration non richiesta se non blocker;
- documentare futuri modelli `app_users`, `tenants`, `stores`, `store_memberships`.

Evidence:

- `40-supabase-owner-rls-contract.md/json`
- `41-supabase-store-scope-gap-analysis.md/json`
- `42-supabase-future-multitenant-plan.md/json`

### Phase 5 — Test matrix

Obiettivi:

- unit/integration tests iOS;
- JVM/instrumented Android;
- simulator/emulator sync cases;
- real-device optional/final if required;
- fault injection where possible.

Required tests:

1. same account local-only dirty → push automatico;
2. same account remote-only dirty → pull incrementale;
3. local+remote different fields → merge automatico;
4. local+remote same field → Review;
5. delete-vs-edit → Review;
6. ProductPrice append/dedupe;
7. ProductPrice same slot different value → Review/stale;
8. account switch clean → remote empty;
9. account switch clean → remote populated;
10. account switch dirty → blocked/recovery;
11. store switch clean → target cache opened;
12. store switch dirty old store → pending remains scoped;
13. owner mismatch → fail-closed;
14. store mismatch → fail-closed;
15. network flap during ack → no partial ack;
16. kill/restart pending → pending persists;
17. cursor gap → recovery, no normal full pull;
18. schema mismatch → blocked/recovery;
19. storage pressure cleanup → only clean inactive cache;
20. inactive dirty cache not deleted;
21. Options no false “Tutto aggiornato”.

Evidence:

- `50-ios-unit-tests.md/json`
- `51-ios-integration-tests.md/json`
- `52-android-unit-tests.md/json`
- `53-android-instrumented-tests.md/json`
- `54-cross-platform-policy-matrix.md/json`
- `55-no-full-pull-normal-path-scan.md/json`
- `56-memory-budget-cache-scan.md/json`
- `57-final-task126-gate-summary.md/json`

### Phase 6 — Final review packaging and regression guard

Obiettivi:

- consolidare matrix C126-00…C126-60;
- generare `plan-vs-execution-delta`;
- validare scanner RED/GREEN;
- validare report JSON e redaction;
- verificare che MASTER-PLAN e TASK-126 non facciano claim DONE non supportati;
- preparare handoff REVIEW con limiti residui espliciti.

Evidence:

- `58-plan-vs-execution-delta.md/json`
- `59-scanner-self-tests-red-green.md/json`
- `60-command-catalog-final.md/json`
- `61-sensitive-final.md/json`
- `62-evidence-json-validation-final.md/json`
- `63-review-handoff.md/json`

Exit:

- stato massimo dopo review-fix UI `ACTIVE / REVIEW — TASK126_POLICY_CACHE_MVP_READY_WITH_UI_INTERACTION_EVIDENCE`;
- nessun `DONE` senza review indipendente e accettazione utente.

## Acceptance criteria

### Policy and architecture

- **AC-126-01**: shared account/store sync policy documented and implemented where applicable.
- **AC-126-02**: four main cases covered with tests/evidence.
- **AC-126-03**: all edge cases C126-00…C126-60 classified PASS / PASS_WITH_NOTES / NOT_APPLICABLE / BLOCKED_EXTERNAL.
- **AC-126-04**: field-level merge policy implemented or explicitly gated.
- **AC-126-05**: same-field conflict enters Review, not silent overwrite.
- **AC-126-06**: delete-vs-edit enters Review.
- **AC-126-07**: ProductPrice append/dedupe/stale policy explicit and tested.
- **AC-126-08**: account switch clean/dirty policy implemented.
- **AC-126-09**: store identity default added/prepared.
- **AC-126-10**: pending/outbox/cursor owner/store scoped.
- **AC-126-11**: owner/store mismatch fail-closed.
- **AC-126-12**: no pending from account/store A can be pushed to B.

### Cache and memory

- **AC-126-13**: multi-store cache MVP decision implemented or documented with gate.
- **AC-126-14**: only active store is loaded/observed in memory.
- **AC-126-15**: inactive clean store cache can be closed and optionally cleaned.
- **AC-126-16**: inactive dirty store cache cannot be auto-deleted.
- **AC-126-17**: ProductPrice remains paginated/keyset and not full memory loaded.
- **AC-126-18**: Android Room/WorkManager equivalent does not observe/load all stores.
- **AC-126-19**: SwiftData/ModelContext heavy work stays off MainActor/UI context.
- **AC-126-20**: memory budget evidence exists for large ProductPrice/cache scenario.

### UX

- **AC-126-21**: Options/root status uses unified provider and no false “Tutto aggiornato”.
- **AC-126-22**: account switch clean confirmation exists.
- **AC-126-23**: account switch dirty Review/Recovery exists.
- **AC-126-24**: conflict Review shows only real conflicts.
- **AC-126-25**: store/cache states user-facing copy localized IT/EN/ES/ZH-Hans.

### Runtime and safety

- **AC-126-26**: no full pull normal path scan PASS.
- **AC-126-27**: no hidden manual sync normal path PASS.
- **AC-126-28**: atomic ack policy preserved.
- **AC-126-29**: network flap/kill-restart pending safe.
- **AC-126-30**: RLS/permission denied fail-closed.
- **AC-126-31**: schema/protocol mismatch fail-closed.
- **AC-126-32**: iOS Debug/Release build PASS.
- **AC-126-33**: Android build/tests PASS if Android modified.
- **AC-126-34**: Supabase schema/RLS reviewed read-only; no service_role client.
- **AC-126-35**: final evidence/sensitive scan PASS.

### Automation and legacy hardening

- **AC-126-36**: Phase -1 harness discovery PASS e comandi TASK-126 presenti in `help-json`/`commands-json` o creati correttamente.
- **AC-126-37**: scanner TASK-126 hanno fixture RED/GREEN documentate.
- **AC-126-38**: legacy/unbound local store repair policy implementata o gated con Review.
- **AC-126-39**: store epoch/remote reset mismatch gestito senza wipe silenzioso.
- **AC-126-40**: switch account/store serializzato con sync runtime, senza partial ack.
- **AC-126-41**: physical cache spike iOS/Android documentato prima di scegliere Opzione A.
- **AC-126-42**: defaultStoreId stabile e migration path futuro documentati.
- **AC-126-43**: conflict batch UX supporta risoluzione parziale e apply-to-similar sicuro.
- **AC-126-44**: permission/membership revoked con dirty local blocca push e preserva backup/export path.
- **AC-126-45**: cache inventory manifest permette lista store senza aprire tutte le cache.
- **AC-126-46**: memory/performance evidence quantitativa presente, non solo dichiarazione qualitativa.
- **AC-126-47**: command catalog/README aggiornati se sono stati aggiunti wrapper o scanner.
- **AC-126-48**: MCP adapter resta thin/allowlisted e non duplica logica CLI.
- **AC-126-49**: final `plan-vs-execution-delta` prodotto.
- **AC-126-60**: final REVIEW handoff non contiene claim DONE/production globale non supportati.

## Non-obiettivi

- Non implementare ancora tutta la gestione admin completa.
- Non implementare ancora WeChat/Google account mapping finale se non già esiste.
- Non creare utenti/negozi reali in Supabase live senza autorizzazione.
- Non introdurre nuove tabelle Supabase se il task può chiudere con contract + app-side MVP.
- Non fare full pull come scorciatoia del normal path.
- Non bypassare RLS.
- Non usare service_role nel client.
- Non fare cleanup globale.
- Non caricare tutti i negozi/account in memoria.
- Non trasformare background iOS in claim tecnico oltre quanto realmente testato.

## Rischi di regressione

1. Push di pending account A dentro account B.
2. Push di pending store X dentro store Y.
3. Perdita dati dirty durante account switch.
4. Full pull nascosto nel normal path.
5. Same-field conflict sovrascritto silenziosamente.
6. ProductPrice duplicati o perdita storico.
7. UI dice “Tutto aggiornato” mentre ci sono pending/recovery.
8. Store inactive dirty cancellato da cleanup cache.
9. SwiftData/Room carica troppi ProductPrice in RAM.
10. WorkManager/BG runner usa account/store vecchio.
11. Query Android/iOS dimentica filtro owner/store in logical scope mode.
12. Schema/RLS Supabase non compatibile con store future.

13. Bind automatico di dati legacy/unbound all'account sbagliato.
14. Store remoto resettato ma cache locale dirty sovrascritta in silenzio.
15. Cambio account/store durante ack atomico con pending marcati erroneamente come acked.
16. Scanner TASK-126 cosmetico senza fixture RED/GREEN.
17. Lista store che apre tutte le cache e causa picchi memoria.
18. Review conflitti troppo rumorosa e non usabile su import grandi.
19. Wrapper MCP che bypassa safety gate del CLI.
20. Report finale che marca skipped case come PASS.

## Check finali richiesti

- `git status` documentato.
- iOS HEAD/branch documentati.
- Android HEAD/branch documentati se toccato.
- Supabase project/schema read-only evidence documentata.
- iOS Debug build PASS.
- iOS Release build PASS.
- iOS sync/account/conflict/cache tests PASS.
- Android build/tests PASS se modificato.
- no-full-pull normal path scan PASS.
- no-hidden-manual-sync scan PASS.
- sensitive scan PASS.
- evidence JSON validation PASS.
- final matrix C126-00…C126-60 completa.
- scanner TASK-126 self-test RED/GREEN PASS.
- legacy/unbound local store matrix PASS/PASS_WITH_NOTES.
- store epoch/reset detection PASS/PASS_WITH_NOTES.
- switch account/store lock/cancellation PASS.
- physical cache spike decision documentata.
- cache manifest/list store non apre tutte le cache.
- memory/performance report quantitativo presente.
- command catalog/README aggiornati se harness modificato.
- plan-vs-execution-delta prodotto.
- final verdict: REVIEW, non DONE, finché non c'è review/conferma utente.

## Condizioni REVIEW / DONE

### REVIEW consentito solo se

- Phase -1 automation discovery PASS;
- Phase 0 canonical audit PASS/PASS_WITH_NOTES motivato;
- scanner TASK-126 obbligatori PASS o implementati se mancanti, con self-test RED/GREEN PASS;
- matrice C126-00…C126-60 completa;
- i quattro casi principali hanno evidence;
- no-full-pull normal path PASS;
- no-hidden-manual-sync PASS;
- no-service-role-client PASS;
- no-rls-bypass PASS;
- owner/store mismatch fail-closed PASS;
- cache active-store-only PASS o decisione tecnica documentata, con manifest/list-store che non apre tutte le cache;
- ProductPrice memory/pagination PASS con evidence quantitativa;
- build/test iOS PASS;
- Android parity PASS se toccato, o audit PASS se non toccato;
- Supabase read-only contract PASS;
- sensitive/evidence/repo-diff/json validation PASS;
- ogni `BLOCKED` ha causa esterna, next action e non nasconde P0 interno.

### DONE non consentito automaticamente

TASK-126 non deve essere marcato DONE da Codex/Cursor alla fine dell'Execution. Stato finale massimo senza review esplicita:

```text
ACTIVE / REVIEW — TASK126_POLICY_CACHE_MVP_READY_WITH_UI_INTERACTION_EVIDENCE
```

DONE richiede:

- review indipendente;
- accettazione utente;
- nessun P0 aperto;
- limiti residui accettati esplicitamente;
- nessun claim “production globale 100%” non supportato da evidence.

## Prompt futuro per estendere il piano

Se in futuro vuoi estendere TASK-126 o creare una TASK-127 collegata, usa uno di questi prompt sintetici:

### Estendere harness TASK-126

```text
Estendi il piano TASK-126 solo lato automation/harness. Leggi prima tools/agent/README.md, mc-agent help-json/list commands-json e gli scanner esistenti. Aggiungi o migliora i comandi mancanti per owner-store scope, conflict matrix, base version, active-store-only cache e ProductPrice memory. Non patchare business logic. Produci patch al piano, lista comandi, expected reports, exit codes, redaction e safety gates.
```

### Aggiungere nuova matrice test

```text
Integra nel piano TASK-126 una nuova test matrix per [scenario]. Deve usare mc-agent se possibile; se il comando non esiste, pianifica il nuovo wrapper CLI con report md/json, fixture, safety gate, redaction, cleanup e residue-check. Resta in Planning.
```

### Preparare Supabase multi-tenant futuro

```text
Crea un follow-up planning per Supabase multi-tenant/multi-store dopo TASK-126. Leggi schema/migrations/RLS correnti, non inventare colonne se esiste già uno schema. Proponi app_users, tenants, stores, store_memberships, RLS, migration/rollback, seed/test fixtures, cleanup scoped e parity iOS/Android. Planning only.
```

### Rifinire UX conflict review

```text
Estendi TASK-126 lato UX/UI per Conflict Review e Store Switch. Mantieni stile iOS nativo e Android Material coerente. Aggiungi copy IT/EN/ES/ZH, stati empty/loading/error, accessibility, Dynamic Type, operator evidence e test UI/smoke harness. Planning only.
```


## Prompt handoff consigliato per Codex/Cursor

```text
Apri TASK-126 in PLANNING/EXECUTION-AUDIT per iOSMerchandiseControl.
Prima leggi GitHub iOS main, poi locale iOS, Android reference e Supabase locale read-only.
Non patchare subito. Esegui Phase 0 audit: iOS sync account/cache, Android parity, Supabase owner/store contract.
Poi implementa TASK-126 solo se la decisione multi-store cache MVP è chiara.
Obbligatorio: no full pull normal path, no hidden manual sync, no service_role client, no RLS bypass, no cross-account/store pending push, ProductPrice paginato, active-store-only memory.
Chiudi in REVIEW con evidence matrix C126-00…C126-60, build/test/scans e final gate summary.
```

## Sintesi operativa

TASK-126 è un unico task, ma non è un piccolo fix. Va eseguito come hardening strutturale della sync:

```text
policy sync + conflict engine + account/store boundary + cache memory MVP
```

La parte admin/negozi/ruoli completa resta futura, ma TASK-126 deve preparare l'app a quel futuro evitando una sync mononegozio rigida.


### Handoff esteso automation-aware

```text
Apri TASK-126 in PLANNING/EXECUTION-AUDIT per iOSMerchandiseControl.

Prima di qualsiasi patch:
1. Leggi GitHub iOS main e documenti locali TASK-126/Master Plan.
2. Esegui discovery harness:
   MC_TASK_ID=TASK-126 ./tools/agent/mc-agent.sh help-json
   MC_TASK_ID=TASK-126 ./tools/agent/mc-agent.sh list commands-json
   MC_TASK_ID=TASK-126 ./tools/agent/mc-agent.sh config validate
   MC_TASK_ID=TASK-126 ./tools/agent/mc-agent.sh git head-consistency --task TASK-126
   MC_TASK_ID=TASK-126 ./tools/agent/mc-agent.sh preflight --require-head-consistency --task TASK-126
3. Verifica se esistono scanner TASK-126 per policy matrix, owner/store scope, base version, conflict review, ProductPrice memory, active-store-only cache.
4. Se mancano o sono fragili, implementa/migliora prima il harness e aggiorna help-json/list commands-json/README/evidence.
5. Solo dopo passa a Phase 0 audit iOS/Android/Supabase.
6. Non usare comandi manuali lunghi se esiste o va creato un wrapper mc-agent.
7. Non fare live/Supabase cleanup senza MC_ALLOW_LIVE/MC_ALLOW_CLEANUP e prefix TASK126_*.
8. Non usare service_role client, non bypassare RLS, non fare full pull normal path, non pushare pending cross-account/store.
9. Chiudi al massimo in REVIEW con report md/json, matrix C126-00…C126-60, final gate summary e sensitive scan PASS.
```

## Execution — Codex

Execution completata nel perimetro autorizzato dall'utente, con scope primario iOS Simulator + Android Emulator e Supabase contract read-only/scoped.

- Phase -1 harness discovery/hardening: completati scanner TASK-126, wrapper iOS/Android, help-json/commands-json, README harness, report JSON e self-test RED/GREEN.
- Phase 0/1: prodotti audit iOS/Android/Supabase e contratti policy/cache/conflict/account-store/migration/feature flag/backup safety in `docs/TASKS/EVIDENCE/TASK-126/`.
- iOS MVP: aggiunti `Task126SyncPolicy`, rafforzata `LocalStoreIdentity`, metadata owner/store/base version su `LocalPendingChange`, scope owner/store su outbox e validazione fail-closed prima del drain.
- Android parity: aggiunta policy nativa Kotlin TASK-126 e test JVM mirati per sync policy, account/store boundary, conflict review e cache memory.
- Supabase: nessuna migration e nessuna live mutation; mode documentato `localDefaultStoreOnly`. Local contract PASS; linked read-only schema/RLS/RPC ha incontrato circuit breaker/auth throttling esterno, documentato come note non bloccante per l'MVP locale.
- Validazione: build/test/smoke/scans passati via `mc-agent`; final state massimo impostato a REVIEW, non DONE.

Physical devices non sono requisito TASK-126: le evidence dichiarano esplicitamente `Validated primarily on iOS Simulator + Android Emulator`.

## Handoff post-execution — verso Claude/User Review

Stato handoff: `ACTIVE / REVIEW — TASK126_POLICY_CACHE_MVP_READY_WITH_UI_INTERACTION_EVIDENCE`.

Evidence principali:

- `docs/TASKS/EVIDENCE/TASK-126/58-plan-vs-execution-delta.md`
- `docs/TASKS/EVIDENCE/TASK-126/59-scanner-self-tests-red-green.md`
- `docs/TASKS/EVIDENCE/TASK-126/60-command-catalog-final.md`
- `docs/TASKS/EVIDENCE/TASK-126/61-sensitive-final.md`
- `docs/TASKS/EVIDENCE/TASK-126/62-evidence-json-validation-final.md`
- `docs/TASKS/EVIDENCE/TASK-126/63-review-handoff.md`

Next action: review indipendente Claude/User. Non marcare DONE senza accettazione esplicita utente.

## Fix — Codex Review UI Interaction Evidence

Pass mirato completato per la review TASK-126 su Case 3 e Case 4, senza riaprire il task da zero e senza marcare DONE.

- Implementata una superficie minima nativa di Review/Recovery per evidence UI: `Task126ReviewInteractionSheet` su iOS e `Task126ReviewInteractionDialog` su Android, con copy localizzata IT/EN/ES/ZH-Hans.
- Aggiunti reducer/fixture deterministici per tutte le scelte richieste: annulla, resta account corrente, esporta backup, scarta pending e cambia, usa locale, usa cloud, modifica manualmente, applica a simili, rimanda review.
- Aggiunti wrapper harness: `ios/android test conflict-review-ui`, `ios/android test account-switch-review-ui`, `ios/android smoke conflict-review-ui`, `ios/android smoke account-switch-review-ui`.
- Runtime smoke su iOS Simulator e Android Emulator: app installata/avviata, sheet/dialog visibile, pulsanti visibili, screenshot e JSON timing/state raccolti.
- Corretto il caso batch misto: se l'utente rimanda la Review, i non-conflitti gia' mergiati non restano pending; resta solo l'entita' conflittuale.
- Nessuna Supabase live mutation, nessun cleanup, nessun full pull, nessun service_role client, nessun bypass RLS.

Evidence aggiunte:

- `docs/TASKS/EVIDENCE/TASK-126/64-ios-conflict-review-ui-simulator.md`
- `docs/TASKS/EVIDENCE/TASK-126/65-android-conflict-review-ui-emulator.md`
- `docs/TASKS/EVIDENCE/TASK-126/66-ios-account-switch-review-ui-simulator.md`
- `docs/TASKS/EVIDENCE/TASK-126/67-android-account-switch-review-ui-emulator.md`
- `docs/TASKS/EVIDENCE/TASK-126/68-case3-case4-choice-outcome-matrix.md`
- `docs/TASKS/EVIDENCE/TASK-126/69-case3-case4-timing-and-state-metrics.md`
- `docs/TASKS/EVIDENCE/TASK-126/70-review-fix-final-gates.md`

## Handoff post-fix — verso Claude/User Review

Stato handoff: `ACTIVE / REVIEW — TASK126_POLICY_CACHE_MVP_READY_WITH_UI_INTERACTION_EVIDENCE`.

Validated primarily on iOS Simulator + Android Emulator. Physical devices are not required for TASK-126 review unless explicitly noted.

Next action: review indipendente Claude/User sulle evidence UI/runtime aggiunte. Non marcare DONE senza accettazione esplicita utente.

## Chiusura — REVIEW PASS FINAL

User override ricevuto per review/fix-to-DONE: Codex autorizzato a eseguire review indipendente completa, correggere problemi reali, rerunnare gate e chiudere TASK-126 a DONE se tutti i P0/P1 risultano PASS.

Esito finale: `DONE / Chiusura — REVIEW PASS FINAL`.

- Review/fix completata su codice iOS, Android, harness, evidence, task file, Master Plan, Supabase contract, UX/localizzazioni/accessibilità, performance/cache e safety scan.
- Fix review applicato: il gancio iOS `TASK126_UI_SMOKE_KIND` è ora esplicitamente DEBUG-only; build iOS Release rerunnata e PASS.
- Il blocco Xcode lock generato da parallelismo test durante review è stato rerunnato in sequenza e superseduto da PASS.
- iOS Debug/Release build PASS.
- Android Debug/Release build PASS.
- iOS Simulator UI test/smoke Case 3/4 PASS.
- Android Emulator UI test/smoke Case 3/4 PASS.
- Core wrapper iOS/Android sync-policy, account-store-boundary, conflict-review e cache-memory PASS.
- Scanner TASK-126, RED/GREEN, no-full-pull normal path, no-hidden-manual-sync, no-service-role-client, no-rls-bypass, sensitive/evidence/repo-diff e JSON validation PASS.
- Supabase locale read-only schema/RLS/grants/RPC PASS; Supabase live mutation non usata e non necessaria per questa chiusura.
- Cleanup execute non eseguito perché non sono stati creati dati live/remoti; residue-check locale `TASK126_POLICY_` PASS/0.
- Physical devices non richiesti per TASK-126 DONE; nessun claim real-device o production globale 100%.

Evidence finale:

- `docs/TASKS/EVIDENCE/TASK-126/71-review-pass-final.md`
- `docs/TASKS/EVIDENCE/TASK-126/71-review-pass-final.json`

Stato finale tracking: TASK-126 chiuso nel perimetro richiesto, con validazione primaria su iOS Simulator + Android Emulator e Supabase `localDefaultStoreOnly` read-only contract.
