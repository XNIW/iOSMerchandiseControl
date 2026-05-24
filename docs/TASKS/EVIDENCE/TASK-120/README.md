# TASK-120 Evidence README

## Stato
- **Task**: TASK-120 — iOS Sync Final Architecture Purification
- **Stato**: ACTIVE / PLANNING — HARDENED_PLUS_FINAL
- **Readiness**: REVIEW PLANNING REQUIRED BEFORE EXECUTION-AUDIT
- **Comandi eseguiti in questa fase planning**: nessuno
- **Build/test/smoke/runtime/live/cleanup**: non eseguiti e vietati in planning

## Evidence root futura
Tutti i report futuri TASK-120 devono vivere sotto:

```text
docs/TASKS/EVIDENCE/TASK-120/agent-runs/
```

Evidence fuori da `docs/TASKS/EVIDENCE/TASK-120/agent-runs/` e' `MISCONFIGURED`.

## Metadati obbligatori per ogni report futuro
Ogni comando futuro deve produrre `.md`, `.json`, `.log` redatti con:
- task id `TASK-120`;
- git SHA;
- dirty state;
- command slug;
- status canonico;
- exit code;
- safety level;
- evidence path;
- started timestamp;
- finished timestamp;
- redaction summary;
- `NEXT_ACTION`;
- JSON schema `1.1`.

## Status canonici
- `PASS`
- `FAIL`
- `BLOCKED_EXTERNAL`
- `NOT_RUN`
- `PASS_WITH_NOTES`
- `MISCONFIGURED`
- `UNSAFE_OPERATION_REFUSED`

Alias ammessi solo in testo umano:
- `BLOCKED` = `BLOCKED_EXTERNAL`
- `REFUSED` = `UNSAFE_OPERATION_REFUSED`

`NOT_RUN` non conta mai come PASS. `PASS_WITH_NOTES` non chiude blocker-class gates senza accettazione esplicita. `MISCONFIGURED` blocca REVIEW. `UNSAFE_OPERATION_REFUSED` blocca REVIEW salvo sia risultato atteso di un safety-refusal test.

## Redaction minima obbligatoria
Report, log, screenshot e JSON devono redarre:
- Supabase anon/service keys;
- JWT/token/password;
- email;
- project ref;
- home path locale;
- device serial/ID;
- OAuth callback data;
- SQL/query payloads con dati personali;
- dati reali cliente/negozio.

## Comandi futuri pianificati
Nessuno dei seguenti comandi e' stato eseguito in planning. Prima dell'uso, i comandi mancanti devono essere creati/instradati e resi discoverable da `help-json` o `list commands-json`.

```bash
./tools/agent/mc-agent.sh git head-consistency --task TASK-120
./tools/agent/mc-agent.sh preflight --require-head-consistency --task TASK-120
./tools/agent/mc-agent.sh config validate --task TASK-120
./tools/agent/mc-agent.sh help-json
./tools/agent/mc-agent.sh list commands-json
./tools/agent/mc-agent.sh scan task-docs --task TASK-120 --strict
./tools/agent/mc-agent.sh scan harness-routing --task TASK-120 --strict
./tools/agent/mc-agent.sh scan harness-health --task TASK-120 --strict
./tools/agent/mc-agent.sh scan source-format --task TASK-120 --strict
./tools/agent/mc-agent.sh scan duplicate-symbols --task TASK-120 --strict
./tools/agent/mc-agent.sh scan automatic-legacy-monolith --task TASK-120 --strict
./tools/agent/mc-agent.sh scan mainactor-boundary --task TASK-120 --strict
./tools/agent/mc-agent.sh scan swiftdata-context-boundary --task TASK-120 --strict
./tools/agent/mc-agent.sh scan manual-root-residue --task TASK-120 --strict
./tools/agent/mc-agent.sh scan master-plan-consistency --task TASK-120 --strict
./tools/agent/mc-agent.sh scan mcp-wrapper --task TASK-120 --strict
./tools/agent/mc-agent.sh scan scanner-self-tests --task TASK-120 --strict
./tools/agent/mc-agent.sh scan status-taxonomy --task TASK-120 --strict
./tools/agent/mc-agent.sh scan evidence-metadata --task TASK-120 --strict
./tools/agent/mc-agent.sh scan sync-architecture --task TASK-120 --strict
./tools/agent/mc-agent.sh scan manual-boundary --task TASK-120 --strict
./tools/agent/mc-agent.sh scan dead-code --task TASK-120 --strict
./tools/agent/mc-agent.sh scan xcode-membership --task TASK-120 --strict
./tools/agent/mc-agent.sh ios build debug --task TASK-120
./tools/agent/mc-agent.sh ios build release --task TASK-120
./tools/agent/mc-agent.sh ios test automatic-architecture --task TASK-120
./tools/agent/mc-agent.sh ios test automatic-domain --task TASK-120
./tools/agent/mc-agent.sh ios test sync --task TASK-120
./tools/agent/mc-agent.sh ios smoke options --task TASK-120
./tools/agent/mc-agent.sh supabase status-redacted --task TASK-120
./tools/agent/mc-agent.sh supabase contract sync-schema --task TASK-120 --read-only
./tools/agent/mc-agent.sh scan sensitive --task TASK-120
./tools/agent/mc-agent.sh scan evidence --task TASK-120
./tools/agent/mc-agent.sh report validate-json --task TASK-120 --path docs/TASKS/EVIDENCE/TASK-120/agent-runs
git diff --check
```

Live opzionale solo con autorizzazione esplicita:

```bash
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh live reconcile-counts --task TASK-120 --prefix TASK120_RECON_
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh live sync-matrix --task TASK-120 --prefix TASK120_FINAL_
```

Cleanup opzionale solo se futuri live tests creano righe sintetiche e solo con collision scan, dry-run, execute gated da `MC_ALLOW_CLEANUP=1`, residue check e prefissi `TASK120_*`.

