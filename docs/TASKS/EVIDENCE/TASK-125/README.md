# TASK-125 Evidence README

## Stato
- Task: `TASK-125`
- Fase: `FIX — EXECUTABLE_SYNC_CONTRACT_AND_REAL_DEVICE_GATE_FAILED`
- Creato: 2026-05-25 19:41 -0400
- Refinement: 2026-05-25 20:15 -0400
- Execution attempt: 2026-05-25 20:58 -0400
- Evidence runtime: auth-preflight fisici PASS; matrici real-device complete non PASS/BLOCKED; executable contract gate non PASS.

## Regole evidence
- Evidence finale deve arrivare da device fisici reali: iOS `iPhone di Min` tramite `MC_IOS_DEVICE_UDID` redatto/hashato e Android `OnePlus` tramite `MC_ANDROID_DEVICE_SERIAL` redatto/hashato.
- Simulator/emulator ammessi solo come fallback diagnostico, non come sostituti finali.
- Cleanup solo scoped su prefisso `TASK125_`; vietato cleanup globale.
- Nessun PASS inventato: usare la tassonomia sotto.
- Ogni report JSON deve avere `redactionApplied=true` o equivalente `redaction_summary` PASS.

## Status taxonomy
- `PASS`: comando eseguito, exit 0, report JSON valido, evidence completa, redaction PASS.
- `FAIL`: bug nostro o criterio non rispettato; richiede fix in Execution.
- `BLOCKED` / `BLOCKED_EXTERNAL`: prerequisito esterno assente con `NEXT_ACTION` precisa.
- `NOT_RUN`: non ancora eseguito; non contribuisce a REVIEW/DONE.
- `PASS_WITH_NOTES`: solo per limiti esterni documentati, mai per correttezza sync core, drift, cleanup, RLS/security o dati persi.

## Prefissi test data
- Realtime: `TASK125_RT_`
- Offline/reconnect: `TASK125_OFFLINE_`
- Background: `TASK125_BG_`
- Kill/restart pending: `TASK125_RESTART_`
- Network flapping: `TASK125_FLAP_`
- Runtime parity: `TASK125_PARITY_`
- Cleanup/residue generale: `TASK125_`

## Struttura file evidence obbligatoria
- `canonical-head.md` / `.json`
- `remote-publish-check.md` / `.json`
- `github-raw-task.md` / `.json` alias legacy/advisory se prodotto
- `github-raw-master-plan.md` / `.json` alias legacy/advisory se prodotto
- `architecture-completion-plan.md` / `.json`
- `sync-responsibility-map.md` / `.json`
- `orchestrator-shell-audit.md` / `.json`
- `driver-split-audit.md` / `.json`
- `normal-path-callgraph.md` / `.json`
- `manual-path-isolation.md` / `.json`
- `full-pull-normal-path-scan.md` / `.json`
- `mainactor-heavy-sync-scan.md` / `.json`
- `remote-adapter-domain-map.md` / `.json`
- `architecture-gate-final.md` / `.json`
- `sync-state-machine.md` / `.json`
- `domain-dependency-graph.md` / `.json`
- `outbox-architecture-contract.md` / `.json`
- `atomic-ack-policy.md` / `.json`
- `remote-cursor-checkpoint-map.md` / `.json`
- `anti-entropy-contract.md` / `.json`
- `conflict-engine-policy-matrix.md` / `.json`
- `account-local-store-boundary.md` / `.json`
- `sync-runtime-singleflight.md` / `.json`
- `realtime-subscriber-resilience.md` / `.json`
- `productprice-large-pipeline-budget.md` / `.json`
- `sync-testability-fakes.md` / `.json`
- `sync-observability-metrics.md` / `.json`
- `sync-feature-flags.md` / `.json`
- `unified-sync-status-provider.md` / `.json`
- `local-remote-identity-map.md` / `.json`
- `tombstone-delete-sync-contract.md` / `.json`
- `sync-protocol-versioning.md` / `.json`
- `sync-unit-of-work.md` / `.json`
- `applied-event-ledger.md` / `.json`
- `sync-timestamp-clock-policy.md` / `.json`
- `sync-error-taxonomy.md` / `.json`
- `sync-resource-budget.md` / `.json`
- `local-store-repair-contract.md` / `.json`
- `remote-dto-validation-boundary.md` / `.json`
- `bulk-import-sync-boundary.md` / `.json`
- `sync-composition-root.md` / `.json`
- `cross-platform-sync-parity-matrix.md` / `.json`
- `android-sync-architecture-audit.md` / `.json`
- `android-gap-fix-plan.md` / `.json`
- `android-outbox-parity.md` / `.json`
- `android-atomic-ack-parity.md` / `.json`
- `android-cursor-checkpoint-parity.md` / `.json`
- `android-conflict-policy-parity.md` / `.json`
- `android-realtime-resilience-parity.md` / `.json`
- `android-productprice-pipeline-parity.md` / `.json`
- `android-tombstone-delete-parity.md` / `.json`
- `android-status-provider-parity.md` / `.json`
- `supabase-cross-platform-contract.md` / `.json`
- `cross-platform-architecture-gate-final.md` / `.json`
- `cross-platform-audit-fix-rerun-loop.md` / `.json`
- `ios-fix-rerun-log.md` / `.json`
- `android-fix-rerun-log.md` / `.json`
- `supabase-contract-fix-rerun-log.md` / `.json`
- `open-failures-zero-check.md` / `.json`
- `cross-platform-final-gate-summary.md` / `.json`
- `shared-sync-contract-spec.md` / `.json`
- `cross-platform-invariant-suite.md` / `.json`
- `cross-platform-golden-fixtures.md` / `.json`
- `sync-fault-injection-contract.md` / `.json`
- `schema-dto-compatibility-gate.md` / `.json`
- `cross-platform-performance-contract.md` / `.json`
- `cross-platform-recovery-contract.md` / `.json`
- `executable-contract-gate-final.md` / `.json`
- `architecture-audit.md` / `.json`
- `file-inventory.md` / `.json`
- `pbxproj-target-membership.md` / `.json`
- `android-reference-audit.md` / `.json`
- `supabase-contract-audit.md` / `.json`
- `harness-routing.md` / `.json`
- `scanner-self-tests.md` / `.json`
- `ios-physical-auth-preflight.md` / `.json`
- `android-physical-auth-preflight.md` / `.json`
- `real-device-realtime-matrix.md` / `.json`
- `offline-reconnect-matrix.md` / `.json`
- `background-sync-matrix.md` / `.json`
- `bg-registration.md` / `.json`
- `bg-schedule.md` / `.json`
- `bg-debug-trigger.md` / `.json`
- `bg-expiration.md` / `.json`
- `bg-no-ui-context-scan.md` / `.json`
- `kill-restart-pending.md` / `.json`
- `network-flapping.md` / `.json`
- `final-runtime-parity.md` / `.json`
- `cleanup-plan.md` / `.json`
- `residue-check.md` / `.json`
- `final-review.md`
- `final-handoff.md`
- `agent-runs/*.md`, `agent-runs/*.json`, `agent-runs/*.log` redatti.

## Esempi one-line
Cursor/Codex/Claude discovery:

```bash
MC_TASK_ID=TASK-125 ./tools/agent/mc-agent.sh help-json
MC_TASK_ID=TASK-125 ./tools/agent/mc-agent.sh list commands-json
MC_TASK_ID=TASK-125 ./tools/agent/mc-agent.sh report validate-json --task TASK-125 --path docs/TASKS/EVIDENCE/TASK-125/agent-runs
```

iOS auth-preflight fisico:

```bash
MC_ALLOW_LIVE=1 MC_TASK_ID=TASK-125 MC_IOS_DEVICE_UDID=<redacted> ./tools/agent/mc-agent.sh ios device-auth-preflight --live --task TASK-125
```

Android auth-preflight fisico:

```bash
MC_ALLOW_LIVE=1 MC_TASK_ID=TASK-125 MC_ANDROID_DEVICE_SERIAL=<redacted> ./tools/agent/mc-agent.sh android auth-preflight --live --task TASK-125
```

Realtime real-device:

```bash
MC_ALLOW_LIVE=1 MC_TASK_ID=TASK-125 ./tools/agent/mc-agent.sh live real-device-realtime --task TASK-125 --prefix TASK125_RT_
```

Cleanup scoped:

```bash
MC_ALLOW_CLEANUP=1 MC_TASK_ID=TASK-125 ./tools/agent/mc-agent.sh supabase cleanup --task TASK-125 --prefix TASK125_
MC_TASK_ID=TASK-125 ./tools/agent/mc-agent.sh supabase residue-check --task TASK-125 --prefix TASK125_
```

## Schema JSON minimo
Ogni JSON evidence deve includere almeno:

```json
{
  "schema_version": "1.1",
  "task_id": "TASK-125",
  "status": "PASS|FAIL|BLOCKED_EXTERNAL|NOT_RUN|PASS_WITH_NOTES",
  "exit_code": 0,
  "redactionApplied": true,
  "command": "<redacted command>",
  "started_at": "ISO-8601",
  "finished_at": "ISO-8601",
  "device": {
    "platform": "ios|android|supabase",
    "identifier_hash": "<hash-or-null>",
    "physical": true
  },
  "prefix": "TASK125_*",
  "metrics": {},
  "artifacts": {
    "markdown": "docs/TASKS/EVIDENCE/TASK-125/<file>.md",
    "json": "docs/TASKS/EVIDENCE/TASK-125/<file>.json"
  },
  "NEXT_ACTION": "Precise next action or none."
}
```

## Cleanup/residue
- Cleanup solo su prefissi `TASK125_*`.
- Vietati delete globali o non prefissati.
- Residue check obbligatorio su `inventory_suppliers`, `inventory_categories`, `inventory_products`, `inventory_product_prices`, `shared_sheet_sessions`, `sync_events`.
- DONE richiede residue totale 0.

## Redaction
- email -> `x***@domain` o hash.
- userId -> hash.
- device serial/UDID -> hash.
- Supabase project ref -> redacted/hash salvo gia' pubblico e necessario.
- path personali -> `<REDACTED_PATH>`.
- JWT/token/password/secret -> mai in log.
- `scan sensitive` e `scan evidence` obbligatori prima di REVIEW.

## Note iniziali
TASK-125 nasce per coprire cio' che TASK-124 ha esplicitamente escluso: iPhone fisico, Android fisico OnePlus, realtime reale tra device, offline/reconnect, kill/restart pending, network flapping e background/locked real-device. Nessuna evidence runtime e' stata prodotta nel turno di creazione/refinement planning.

## Execution snapshot — 2026-05-25 20:58 -0400
- PASS: local canonical/preflight, harness discovery, iOS Debug/Release build, iOS sync/automatic/manual tests, Android assembleDebug + sync/offline tests, scanner TASK-125, source-format, evidence-redaction, iPhone physical auth-preflight, OnePlus physical auth-preflight.
- PASS scoped/local only: local cleanup dry-run `TASK125_*` and local residue check.
- BLOCKED_EXTERNAL: Supabase linked RLS/grants and linked runtime parity due pooler/auth circuit breaker or hanging linked query.
- BLOCKED/FAIL: full real-device matrices `TASK125_RT_`, `TASK125_OFFLINE_`, `TASK125_BG_`, `TASK125_RESTART_`, `TASK125_FLAP_`, `TASK125_PARITY_` are not PASS and must not be used as acceptance.
- FAIL/NOT_RUN: executable cross-platform contract artifacts are intentionally marked non-PASS until dedicated checkers/fixtures/fault-injection gates exist and pass on iOS + Android + Supabase.
- Verdict: TASK-125 remains `ACTIVE / FIX`, not `REVIEW`, not `DONE`.
