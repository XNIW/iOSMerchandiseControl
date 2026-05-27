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
