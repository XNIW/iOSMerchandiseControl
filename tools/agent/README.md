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

Per operatore umano:

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

Mancanza linked/local deve risultare BLOCKED con next action, non crash.

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
