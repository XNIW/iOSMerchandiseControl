# mc-agent — Agent-friendly CLI harness

Entrypoint: `./tools/agent/mc-agent.sh`

## Scopo

`mc-agent` centralizza i comandi ripetitivi usati nei task cross-platform: preflight, build, test, smoke, verifica Supabase, live matrix, cleanup scoped e report evidence. La CLI e' la fonte canonica; MCP e' solo un adapter sottile.

## Architettura

- `mc-agent.sh`: dispatcher, exit code, report hook.
- `lib/common.sh`: config, safety, locks, scan, report/list/config commands.
- `lib/ios.sh`: `xcodebuild`, XCTest, smoke simulator/options, auth/live wrappers.
- `lib/android.sh`: Gradle, ADB, smoke, L1/L2/L3 offline harness.
- `lib/supabase.sh`: status/verify/residue/cleanup scoped con profili.
- `lib/report.sh`: `.log`, `.md`, `.json` schema `1.1`, scritti via `.tmp` e move atomico.
- `lib/redact.sh`: redaction token/JWT/email/path/device/query sensitive.
- `mcp/server.mjs`: wrapper MCP allowlisted sopra la CLI.

## Controllo dello spazio

Prima di acquisire lo slot Xcode o avviare Gradle, `mc-agent` misura lo spazio
disponibile sui volumi di checkout, evidence, temporanei e Gradle User Home.
Sotto 100 GB decimali scrive un avviso. Il lavoro parte se restano almeno
30 GB dopo la crescita prevista del batch. I valori iniziali sono 3,5 GB per
Xcode e 2 GB per Gradle, basati sui batch locali comparabili. Impostare
`MC_IOS_BATCH_GROWTH_BYTES` o `MC_ANDROID_BATCH_GROWTH_BYTES` per un batch con
un profilo misurato diverso. Se la misura fallisce o il margine è insufficiente,
produce `BLOCKED_EXTERNAL` / `BLOCKED_DISK_SPACE`, exit 2.
Le verifiche statiche e i comandi diagnostici che non avviano questi strumenti
restano utilizzabili. I driver esterni a `mc-agent` richiedono il proprio controllo.

## Conservazione degli output gestiti

`mc_run_wrapped` registra l'esecuzione prima del comando e finalizza dopo avere
verificato il report JSON/Markdown/log. L'indice locale si trova in
`agent-runs/managed-artifacts/index.jsonl`. Il codice del test e l'esito del cleanup
sono separati; il secondo compare anche nel file `.artifacts.txt` del report.
Prima del batch viene tentata la pulizia dei soli output conclusi registrati.
Il registro riesamina le esecuzioni interrotte e conserva la diagnostica.
Il postflight riesegue la pulizia dopo l'esito o un'interruzione gestita.

I comandi Xcode raggruppano i prodotti per scheme, configurazione, piattaforma,
architettura e toolchain. Rimane l'ultimo prodotto valido del gruppo.
`reuse-products` del registro restituisce un prodotto già completato con
input e dipendenze corrispondenti e registra il consumer. Chi lo usa verifica
il descriptor e la provenienza del prodotto per la prova prevista.
`build-for-testing` e i successivi
`test-without-building` mantengono descriptor e prodotti insieme fino alla
conclusione del comando e dei suoi consumatori. I risultati integrali riusciti
ripetitivi conservano gli ultimi due per configurazione e tipo di verifica.
Gli output Android in `app/build` e le cache Gradle continuano a essere riusati
nel progetto; questo runner non crea copie storiche aggiuntive degli APK.

Il limite operativo è 20 GB decimali per gli output sacrificabili, scelto rispetto
alle DerivedData misurate di circa 2–3 GB. Il materiale protetto non viene rimosso
per rispettare il limite: l'indice segnala l'eccesso e le dimensioni non ancora note.
Report compatti, failure, retry, risultati finali, pin e riferimenti esterni restano
protetti. Anche un SDK fallito seguito da un fallback complessivamente riuscito
mantiene prodotti e diagnostica del fallimento.
I log completi di build/test falliti vengono conservati nel `raw` del run con
un riferimento protetto; il report mantiene anche la coda sintetica. Il file viene
rinominato sullo stesso volume e rimane al percorso originale se ciò non riesce.

Impostare `MC_ARTIFACT_PIN_REASON`, `MC_ARTIFACT_RETRY_PENDING=1` o
`MC_ARTIFACT_FINAL_EVIDENCE=1` prima del comando quando sono previsti ulteriori
consumatori, una baseline o evidence finale. L'opzione facoltativa
`MC_IOS_SOURCE_PACKAGES_DIR` riusa un percorso SourcePackages esplicito;
la disponibilità viene verificata contro Package.resolved, revisioni dei checkout
e modifiche locali. In assenza di prova completa gli intermedi vengono conservati.
Le directory miste contenenti APK/app richiedono anch'esse tale prova, anche quando
registrate come risultati integrali. Per Gradle, il frontdoor di una vera qualifica
completa Debug/Release può chiamare `capture-gradle --run TOKEN --qualification Q`
in analisi, oppure aggiungere `--apply` per allegare una prova verificata. Servono
ricevute del vero processo SDK terminato con exit 0, entrambe le APK vincolate alla
qualifica, fonti/configurazioni invariate e percorsi esatti di dipendenze, SDK,
distribuzione Gradle, JDK e chiave Debug effettivamente usati. La manutenzione non
avvia nuove build per produrre questa prova e non riusa attestazioni parziali di
vecchie configurazioni. I profili `--fixture` sono esclusi dall'ammissione reale.

Il witness è limitato a 50.000 file, 30 GB logici inventariati e 8 MB di metadati:
registra identità/metadati dei componenti, hash delle fonti e dei file piccoli,
senza copie di dipendenze o segreti. Le fonti includono la membership; nuovi file
cache aggiuntivi non invalidano la prova, mentre file richiesti cambiati o mancanti
e dichiarazioni opzionali prima assenti causano HOLD. Dopo un vero PASS, solo
`GRADLE_AVAILABILITY_ATTACHED` con `applied: true` conferma l'allegato. Un errore
del collector mantiene gli output e non cambia il risultato dei test. AVD e dati
applicativi rimangono esclusi; il keystore è soltanto un file di input protetto.

Il piccolo helper `lib/artifact_lifecycle.py` opera soltanto nel root esplicito
`agent-runs/managed-artifacts`. Per un controllo senza rimozioni:

```bash
python3 tools/agent/lib/artifact_lifecycle.py --root /percorso/evidence/agent-runs/managed-artifacts cleanup
```

L'applicazione richiede `cleanup --apply`. `protect --run TOKEN --pin MOTIVO`
protegge ulteriori consumatori. `release-products --run TOKEN --receipt FILE`
richiede una ricevuta JSON legata al token con `disposition: products_superseded`,
`consumers_complete: true`, `retry_pending: false`, `reason`, `closed_pins` e
`diagnostic_paths` esistenti. Gli esiti storici e i risultati diagnostici falliti
rimangono invariati. Una copertura processi incerta richiede anche
`unattributed_consumers_reviewed_closed: true`; i processi propri ancora vivi
impediscono sempre il rilascio.

Le lease usano identità kernel del processo e nonce. I figli osservati, il gruppo
del comando e un token ereditato dai processi impediscono la rimozione di output
ancora utilizzati. Un confronto dei processi alla fine del comando conserva anche
eventuali nuovi sopravvissuti non attribuibili. Non vengono segnalati o terminati
processi estranei. Dopo un crash, il successivo avvio marca il run interrotto come
da verificare e conserva la diagnostica. Non vengono adottate o eliminate
automaticamente vecchie cartelle esterne al registro, né attraversati symlink.

## Setup config

```bash
cp tools/agent/config.example.env tools/agent/config.env
$EDITOR tools/agent/config.env
```

Non committare `config.env`. I valori sensibili devono restare in env locale.

## Comandi piu' usati

Per Codex/Cursor:

```bash
./tools/agent/mc-agent.sh preflight
./tools/agent/mc-agent.sh android test offline
./tools/agent/mc-agent.sh android offline-write --tier L2 --prefix TASK115_OFFLINE_L2_
./tools/agent/mc-agent.sh report --latest
./tools/agent/mc-agent.sh scan evidence --task TASK-115
```

TASK-118 harness gates:

```bash
./tools/agent/mc-agent.sh git head-consistency --task TASK-118
./tools/agent/mc-agent.sh preflight --require-head-consistency --task TASK-118
./tools/agent/mc-agent.sh scan sync-boundaries --task TASK-118 --strict
./tools/agent/mc-agent.sh scan no-full-pull-normal-path --task TASK-118 --strict
./tools/agent/mc-agent.sh ios test automatic-domain --task TASK-118
./tools/agent/mc-agent.sh report validate-json --task TASK-118 --path docs/TASKS/EVIDENCE/TASK-118/agent-runs
```

Per TASK-118 ogni comando deve usare `--task TASK-118` oppure `MC_TASK_ID=TASK-118`; evidence prodotta fuori da `docs/TASKS/EVIDENCE/TASK-118/` e' misconfigurata. Gli scan storici TASK-116/TASK-117 chiudono TASK-118 solo se eseguiti con semantica CA-118 e evidence TASK-118.

TASK-126 automation-first gates:

```bash
MC_TASK_ID=TASK-126 ./tools/agent/mc-agent.sh help-json
MC_TASK_ID=TASK-126 ./tools/agent/mc-agent.sh list commands-json
MC_TASK_ID=TASK-126 ./tools/agent/mc-agent.sh config validate
MC_TASK_ID=TASK-126 ./tools/agent/mc-agent.sh git head-consistency --task TASK-126
MC_TASK_ID=TASK-126 ./tools/agent/mc-agent.sh preflight --require-head-consistency --task TASK-126
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
./tools/agent/mc-agent.sh scan scanner-self-tests --task TASK-126 --strict
./tools/agent/mc-agent.sh ios test sync-policy --task TASK-126
./tools/agent/mc-agent.sh ios test account-store-boundary --task TASK-126
./tools/agent/mc-agent.sh ios test conflict-review --task TASK-126
./tools/agent/mc-agent.sh ios test conflict-review-ui --task TASK-126
./tools/agent/mc-agent.sh ios test account-switch-review-ui --task TASK-126
./tools/agent/mc-agent.sh ios smoke conflict-review-ui --task TASK-126
./tools/agent/mc-agent.sh ios smoke account-switch-review-ui --task TASK-126
./tools/agent/mc-agent.sh ios test cache-memory --task TASK-126
./tools/agent/mc-agent.sh android test sync-policy --task TASK-126
./tools/agent/mc-agent.sh android test account-store-boundary --task TASK-126
./tools/agent/mc-agent.sh android test conflict-review --task TASK-126
./tools/agent/mc-agent.sh android test conflict-review-ui --task TASK-126
./tools/agent/mc-agent.sh android test account-switch-review-ui --task TASK-126
./tools/agent/mc-agent.sh android smoke conflict-review-ui --task TASK-126
./tools/agent/mc-agent.sh android smoke account-switch-review-ui --task TASK-126
./tools/agent/mc-agent.sh android test cache-memory --task TASK-126
./tools/agent/mc-agent.sh scan task126-final-gates --task TASK-126 --strict
```

TASK-126 scanner fixtures live under `tools/agent/fixtures/task126_scanners/`. RED fixtures must fail and GREEN fixtures must pass before scanner output can be used as final evidence.

TASK-127 Options performance gates:

```bash
MC_TASK_ID=TASK-127 ./tools/agent/mc-agent.sh help-json
MC_TASK_ID=TASK-127 ./tools/agent/mc-agent.sh list commands-json
MC_TASK_ID=TASK-127 ./tools/agent/mc-agent.sh config validate
MC_TASK_ID=TASK-127 ./tools/agent/mc-agent.sh git head-consistency --task TASK-127
MC_TASK_ID=TASK-127 ./tools/agent/mc-agent.sh preflight --require-head-consistency --task TASK-127
./tools/agent/mc-agent.sh ios test options-summary-performance --task TASK-127
./tools/agent/mc-agent.sh ios test options-summary-provider --task TASK-127
./tools/agent/mc-agent.sh ios smoke options-performance --task TASK-127
./tools/agent/mc-agent.sh android audit options-performance --task TASK-127
./tools/agent/mc-agent.sh scan scanner-self-tests --task TASK-127 --strict
./tools/agent/mc-agent.sh scan options-mainactor-heavy-fetch --task TASK-127 --strict
./tools/agent/mc-agent.sh scan productprice-full-fetch-mainactor --task TASK-127 --strict
./tools/agent/mc-agent.sh scan options-refresh-debounce --task TASK-127 --strict
./tools/agent/mc-agent.sh scan task127-debug-hook-release-safety --task TASK-127 --strict
./tools/agent/mc-agent.sh scan task127-final-gates --task TASK-127 --strict
```

TASK-127 scanners are top-level `scan` commands; do not use `ios scan ...`. Scanner fixtures live under `tools/agent/fixtures/task127_scanners/` and must prove RED/GREEN behavior before final evidence is accepted. Cursor, Codex and Claude should use the same one-line commands above and rely on the standard `RESULT`, `EXIT_CODE`, `REPORT_MD`, `REPORT_JSON`, `NEXT_ACTION` wrapper output.

TASK-129 Android broad test health gates:

```bash
MC_TASK_ID=TASK-129 ./tools/agent/mc-agent.sh help-json
MC_TASK_ID=TASK-129 ./tools/agent/mc-agent.sh list commands-json
MC_TASK_ID=TASK-129 ./tools/agent/mc-agent.sh config validate
MC_TASK_ID=TASK-129 ./tools/agent/mc-agent.sh git head-consistency --task TASK-129
MC_TASK_ID=TASK-129 ./tools/agent/mc-agent.sh preflight --require-head-consistency --task TASK-129
./tools/agent/mc-agent.sh android build debug --task TASK-129
./tools/agent/mc-agent.sh android test sync --task TASK-129
./tools/agent/mc-agent.sh android test broad --task TASK-129
./tools/agent/mc-agent.sh android test quarantine-report --task TASK-129
./tools/agent/mc-agent.sh scan sensitive --task TASK-129 docs/TASKS/EVIDENCE/TASK-129
./tools/agent/mc-agent.sh scan evidence --task TASK-129
./tools/agent/mc-agent.sh report validate-json --task TASK-129 --path docs/TASKS/EVIDENCE/TASK-129/agent-runs
```

`android test broad` is the canonical broad JVM suite wrapper for `:app:testDebugUnitTest`; it sets the shared Gradle/JDK attach environment through `mc_android_gradle`, keeps console output short, and writes Markdown/JSON/log evidence. If broad is non-green, `android test quarantine-report` classifies failures as `REAL_REGRESSION`, `BYTEBUDDY_ATTACH_ENV`, `JDK_TOOLCHAIN_ENV`, `ROOM_TEST_ENV`, `FLAKY_RETRY_REQUIRED` or `UNKNOWN_NEEDS_FIX`. A quarantine report is not broad PASS; it can only support a `PASS_WITH_NOTES` review candidate when failures are instrumental and the stable CI alternative (`android build debug` + `android test sync`) is documented.

TASK-130 price contract and consolidated TASK-128 hardening gates:

```bash
MC_TASK_ID=TASK-130 ./tools/agent/mc-agent.sh help-json
MC_TASK_ID=TASK-130 ./tools/agent/mc-agent.sh list commands-json
MC_TASK_ID=TASK-130 ./tools/agent/mc-agent.sh config validate
MC_TASK_ID=TASK-130 ./tools/agent/mc-agent.sh git head-consistency --task TASK-130
MC_TASK_ID=TASK-130 ./tools/agent/mc-agent.sh preflight --require-head-consistency --task TASK-130
./tools/agent/mc-agent.sh ios build debug --task TASK-130
./tools/agent/mc-agent.sh ios test price-contract --task TASK-130
./tools/agent/mc-agent.sh android build debug --task TASK-130
./tools/agent/mc-agent.sh android test price-contract --task TASK-130
./tools/agent/mc-agent.sh supabase contract price-schema --task TASK-130 --read-only
./tools/agent/mc-agent.sh scan price-contract --task TASK-130 --strict
./tools/agent/mc-agent.sh scan swiftdata-fetch-budget --task TASK-130 --strict
./tools/agent/mc-agent.sh harness golden-corpus validate --task TASK-130
./tools/agent/mc-agent.sh harness golden-corpus roundtrip --task TASK-130
./tools/agent/mc-agent.sh harness real-device-feasibility --task TASK-130
./tools/agent/mc-agent.sh ios benchmark import-large --task TASK-130
./tools/agent/mc-agent.sh ios smoke options-first-sync --task TASK-130
./tools/agent/mc-agent.sh ios smoke scanner-edge --task TASK-130
./tools/agent/mc-agent.sh ios smoke accessibility --task TASK-130
./tools/agent/mc-agent.sh scan sensitive --task TASK-130 docs/TASKS/EVIDENCE/TASK-130
./tools/agent/mc-agent.sh scan evidence --task TASK-130
./tools/agent/mc-agent.sh report validate-json --task TASK-130 --path docs/TASKS/EVIDENCE/TASK-130/agent-runs
```

`scan price-contract` is a read-only static contract matrix for iOS, Android and local Supabase migrations. `ios/android test price-contract` run targeted unit/XCTest coverage only. `supabase contract price-schema` reads local migrations and does not run live queries or schema changes.

The consolidated TASK-130 commands keep the residual TASK-128 scope inside TASK-130 by design. `harness golden-corpus validate` checks privacy-safe fixture coverage and parser/export support; `harness golden-corpus roundtrip` records static cross-platform roundtrip readiness and marks binary app-to-app gaps as `PARTIAL` when no generated artifact is executed. `scan swiftdata-fetch-budget` guards import/pre-generate SwiftData lookup against fetch-all Product hot paths. `ios benchmark import-large` is a static/harness-readiness benchmark gate unless a reviewer provides a runtime dataset/device. `ios smoke options-first-sync`, `ios smoke scanner-edge`, and `ios smoke accessibility` are static smoke gates and must not be treated as physical-device or VoiceOver PASS. `harness real-device-feasibility` records local device/tool feasibility only; long background/locked/offline acceptance remains explicit `PARTIAL`/`BLOCKED_EXTERNAL` unless live/device commands are run.

TASK-131 physical-device sync policy acceptance gates:

```bash
MC_TASK_ID=TASK-131 ./tools/agent/mc-agent.sh help-json
MC_TASK_ID=TASK-131 ./tools/agent/mc-agent.sh list commands-json
MC_TASK_ID=TASK-131 ./tools/agent/mc-agent.sh config validate
MC_TASK_ID=TASK-131 ./tools/agent/mc-agent.sh git head-consistency --task TASK-131
MC_TASK_ID=TASK-131 ./tools/agent/mc-agent.sh preflight --require-head-consistency --task TASK-131
./tools/agent/mc-agent.sh physical devices list --task TASK-131
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh ios physical sync-policy-ui --task TASK-131 --prefix TASK131_IOS_
./tools/agent/mc-agent.sh ios simulator sync-policy-ui --task TASK-131 --prefix TASK131_IOS_SIM_
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh android physical sync-policy-ui --task TASK-131 --prefix TASK131_ANDROID_PHYS_
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh physical sync-policy-matrix --task TASK-131 --prefix TASK131_POLICY_
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh physical conflict-review-matrix --task TASK-131 --prefix TASK131_CONFLICT_
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh physical account-switch-matrix --task TASK-131 --prefix TASK131_ACCOUNT_
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh physical offline-background-matrix --task TASK-131 --prefix TASK131_OFFLINE_
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh physical accessibility-smoke --task TASK-131
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh physical hybrid-sync-policy-matrix --task TASK-131 --prefix TASK131_HYBRID_
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh physical hybrid-conflict-review-matrix --task TASK-131 --prefix TASK131_CONFLICT_
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh physical hybrid-offline-reconnect-matrix --task TASK-131 --prefix TASK131_OFFLINE_
./tools/agent/mc-agent.sh physical hybrid-accessibility-smoke --task TASK-131
./tools/agent/mc-agent.sh scan task131-matrix-completeness --task TASK-131 --strict
./tools/agent/mc-agent.sh scan task131-redaction --task TASK-131 --strict
./tools/agent/mc-agent.sh scan task131-final-gates --task TASK-131 --strict
./tools/agent/mc-agent.sh report validate-json --task TASK-131 --path docs/TASKS/EVIDENCE/TASK-131/agent-runs
```

TASK-131 wrappers are intentionally strict. `physical devices list` is discovery-only and can PASS with redacted device readiness. Full physical scope uses trusted iPhone physical plus Android physical; hybrid scope remains support-only when explicitly requested. Mandatory matrix and UI cases must not emit PASS while cases remain `NOT_RUN`; if devices or live gates are missing they return `BLOCKED_EXTERNAL`/`MISCONFIGURED`/`UNSAFE_OPERATION_REFUSED` instead of silently passing. Conflict/Review and accessibility physical UX require real tap/traversal evidence through reliable UI automation or redacted operator-assisted checklist JSON; static policy/UI contract tests alone are not physical PASS evidence.

`physical account-switch-matrix` is split by prerequisite. Same-account logout/login, auth fail-closed, owner/store mismatch fixture, legacy/unbound dirty recovery, export-before-discard/cancel and `localDefaultStoreOnly` run without a second account. Only true Account A -> Account B cases (`C126-14`, `C126-15`, `C126-16`, `C126-17`, `C126-40`) are classified as `BLOCKED_EXTERNAL_SECOND_ACCOUNT` when no approved second synthetic account is configured.

For operator-assisted evidence, use `docs/TASKS/EVIDENCE/TASK-131/operator-review-accessibility-checklist.md` / `.json` as the minimum checklist for Review CTA/cancel/destructive actions, VoiceOver, TalkBack and enlarged text/font-scale. Missing checklist evidence is `BLOCKED_EXTERNAL_OPERATOR_EVIDENCE_REQUIRED`, not PASS.

```bash
./tools/agent/mc-agent.sh config validate
./tools/agent/mc-agent.sh ios build debug
./tools/agent/mc-agent.sh android build debug
./tools/agent/mc-agent.sh supabase status-redacted
./tools/agent/mc-agent.sh sync counts --task TASK-114 --source supabase --profile linked
./tools/agent/mc-agent.sh sync counts --task TASK-114 --source android
./tools/agent/mc-agent.sh sync counts --task TASK-114 --source ios
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh ios live-full-pull --live --task TASK-114
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh android live-full-pull --live
./tools/agent/mc-agent.sh supabase cleanup --task TASK-115 --prefix TASK115_DRYRUN_ --dry-run
```

## Exit code

- `0`: PASS
- `1`: FAIL
- `2`: BLOCKED
- `3`: MISCONFIGURED
- `4`: UNSAFE_OPERATION_REFUSED

Ogni comando wrapped stampa:

```text
RESULT ...
EXIT_CODE ...
REPORT_MD ...
REPORT_JSON ...
NEXT_ACTION ...
```

`help-json` resta JSON puro per MCP/tooling.

## Safety gate

- Live write/auth/matrix: richiede `MC_ALLOW_LIVE=1`.
- Cleanup execute: richiede `MC_ALLOW_CLEANUP=1`.
- Prefix: deve essere `TASKNNN_*`; cleanup globale, `%`, path, shell metachar e prefix non TASK vengono rifiutati.
- Cleanup execute richiede un `cleanup_plan_id` creato da dry-run con stesso task e prefix.
- Live/cleanup usano lock: `docs/TASKS/EVIDENCE/<task>/agent-runs/.mc-agent-live.lock`.
- Vietati: `auth.users`, `truncate`, reset DB, cleanup globale, service-role client, bypass RLS client.

## Live mode

```bash
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh ios auth-preflight --live
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh android auth-preflight --live
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh ios live-full-pull --live --task TASK-114
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh android live-full-pull --live
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh live reconcile-counts --task TASK-114 --prefix TASK114_RECON_
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh live sync-matrix --task TASK-114 --prefix TASK114_FINAL_
```

## TASK-114 sync counts

`sync counts` reads one source at a time and writes Markdown/JSON under the requested `--task` evidence directory. The JSON report includes the `reconciliation` object with `schemaVersion`, `taskId`, source/session redaction, canonical counts (`active`, `deleted`, `all`, `dirty`, `pending`, `localOnly`, `userVisible`), checkpoints, prune summary and hashed samples.

- `--source supabase` uses the selected Supabase profile and read-only count SQL.
- `--source android` copies the debug Room database through `adb run-as` and performs read-only SQLite counts.
- `--source ios` reads the booted Simulator SwiftData SQLite store read-only.
- `ios live-full-pull --live --task TASK-114` runs the TASK-114 app-auth lookup repair on the test host, applies supplier/category lookup-only rows, and validates before/after counts.
- `android live-full-pull --live` runs the TASK-114 Android app-auth full pull without clearing local data; it is intended to repair/verify local Room counts after a full Supabase snapshot.
- `live reconcile-counts` is gated by `MC_ALLOW_LIVE=1`, takes the live lock, runs the three source collectors, and fails on drift or blocks on missing auth/device/local store evidence.

## Cleanup dry-run/execute

```bash
./tools/agent/mc-agent.sh supabase cleanup --task TASK-115 --prefix TASK115_DRYRUN_ --dry-run
MC_ALLOW_CLEANUP=1 ./tools/agent/mc-agent.sh supabase cleanup --task TASK-115 --prefix TASK115_DRYRUN_ --execute --cleanup-plan-id <id>
./tools/agent/mc-agent.sh supabase residue-check --prefix TASK115_DRYRUN_ --profile dry-run-no-db
```

Il dry-run genera un `cleanup_plan_id` in `agent-runs/cleanup-plans/`.

## Android offline L1/L2/L3

- `L1`: JVM deterministic offline harness (`Task113AndroidOfflineHarnessJvmTest`).
- `L2`: instrumentation/device/emulator con Room in-memory + fake/controlled network (`Task113AndroidOfflineHarnessTest#offlineWriteAndReconnectDrainInstrumentedL2`).
- `L3`: live offline matrix con Supabase read-back + cleanup scoped, gated da live/auth/device.

Regola: L1 non e' live offline PASS. Chiusura piena richiede almeno L2 PASS o PASS_WITH_NOTES esplicitamente accettato.

## Supabase profile

- `dry-run-no-db`: nessuna query DB, utile per safety/report in ambienti non linkati.
- `local`: usa Supabase local/Docker.
- `linked`: usa progetto linked read-only/cleanup backend dove autorizzato.

Mancanza linked/local deve risultare BLOCKED con next action, non crash. `supabase verify-schema` uses a bounded CLI timeout for `migration list`/`db lint`; if the Supabase CLI or linked project hangs, rerun after the linked/local environment is responsive.

## MCP adapter

```bash
cd tools/agent/mcp
npm install
npm test
npm start
```

Il server MCP usa allowlist, `spawn` con argv array, timeout, cwd fissato al repo iOS e non modifica `MC_ALLOW_LIVE` o `MC_ALLOW_CLEANUP`. `node_modules/` e' ignorato e non va committato.

## Troubleshooting

- Xcode/simulator: imposta `MC_IOS_DESTINATION`; controlla il path `xcresult` nel report.
- iOS Options JXA/Accessibility bloccato: `ios smoke options` puo' chiudere `PASS_WITH_NOTES` solo se esiste una evidence XcodeBuildMCP validata in `docs/TASKS/EVIDENCE/TASK-115/ios-options-xcodebuildmcp-fallback.txt`.
- Android JDK/Gradle: `JAVA_TOOL_OPTIONS=-Djdk.attach.allowAttachSelf=true` e' impostato dal wrapper.
- ADB device locked: sblocca schermo; piu' device richiedono `MC_ANDROID_DEVICE_SERIAL`.
- App non installata/signed-out: i comandi smoke/auth-live tornano BLOCKED con next action.
- ByteBuddy/MockK attach: usa il JBR configurato in `MC_ANDROID_JAVA_HOME`.
- Supabase Docker: avvia Docker e poi `supabase start`.
- Supabase pooler/rate limit: riduci query ripetute, usa cooldown/backoff.
- RLS 42501: non bypassare dal client; cleanup backend solo scoped e autorizzato.
- Missing auth session: esegui login app, verifica restore, poi retry auth-preflight.
- Residue > 0: esegui cleanup scoped dry-run/execute e rerun residue-check.
- node_modules not committed: `tools/agent/mcp/node_modules/` e' ignorato; rimuoverlo prima di final review se compare.
