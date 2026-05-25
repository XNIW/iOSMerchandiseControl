# TASK-122 Evidence README

## Scope
- **Task**: TASK-122 — iOS Sync Remote Domain Strangler and Final Architecture Purification
- **Task file**: `docs/TASKS/TASK-122-ios-sync-remote-domain-strangler.md`
- **Evidence root**: `docs/TASKS/EVIDENCE/TASK-122/`
- **Schema**: 1.1
- **Status corrente**: PLANNING_CREATED
- **Ultimo aggiornamento**: 2026-05-24 19:14 -0400

## Regole evidence
- Salvare output canonici sotto questa directory, preferendo sottocartelle `agent-runs/`, `audits/`, `scanner-fixtures/`, `build/`, `tests/`, `smoke/`, `supabase-readonly/`, `reports/`.
- Formati ammessi: `.md`, `.json`, `.csv`, `.log` privacy-safe.
- Ogni evidence operativa deve includere: comando harness, timestamp, task id, status canonico, summary, `NEXT_ACTION`, redaction summary.
- `NOT_RUN` non e' mai PASS.
- `BLOCKED_EXTERNAL` deve spiegare prerequisito esterno e fallback accettabile, se previsto.

## Gate iniziali futuri
La futura EXECUTION deve salvare evidence per:

```bash
./tools/agent/mc-agent.sh git head-consistency --task TASK-122
./tools/agent/mc-agent.sh preflight --require-head-consistency --task TASK-122
./tools/agent/mc-agent.sh config validate --task TASK-122
./tools/agent/mc-agent.sh help-json
./tools/agent/mc-agent.sh list commands-json
```

Controllo no-cache obbligatorio:
- local HEAD.
- origin/main.
- GitHub canonical main.
- commit-specific tree.
- GitHub raw per vecchi root files e nuovi Remote files.

Se diverge qualunque controllo, bloccare Swift moves/splits/deletes e registrare `BLOCKED_EXTERNAL_HEAD_MISMATCH` o `MISCONFIGURED_HEAD_MISMATCH` con `NEXT_ACTION`.

## Evidence obbligatorie previste
- `agent-runs/00-head-consistency.json`
- `agent-runs/00-preflight.json`
- `agent-runs/00-config-validate.json`
- `agent-runs/00-help-json.json`
- `agent-runs/00-commands-json.json`
- `agent-runs/00-discovery-summary.md`
- `audits/sync-inventory.md`
- `audits/sync-inventory.json`
- `audits/sync-inventory.csv`
- `audits/transport-call-site-map.md`
- `audits/transport-method-responsibility-map.md`
- `audits/protocol-conformance-map.md`
- `audits/android-parity-ledger.md`
- `audits/supabase-readonly-contract-map.md`
- `audits/xcode-membership-before-after.md`
- `audits/regression-risk-map.md`
- `reports/before-after-architecture-map.md`
- `reports/ca-122-ledger.md`
- `reports/final-handoff.md`

## Safety gates
- Nessun Supabase live write.
- Nessun cleanup live.
- Nessuna migration.
- Nessuna modifica RLS/grant/RPC/schema.
- Nessun service_role client.
- Nessun bypass RLS.
- Nessun secret in evidence.
- Nessun push GitHub senza override esplicito.
- Nessun DONE o 100% prima di review approval e accettazione utente.

## Stato iniziale
Questo README e' creato durante PLANNING. Non contiene risultati di build/test/scanner runtime. Il primo `NEXT_ACTION` e': review/integrazione Claude del planning TASK-122 e successivo handoff valido verso EXECUTION.

## Planning review integration
La review planning del 2026-05-24 ha rilevato che TASK-122 e il MASTER-PLAN aggiornato possono essere local-only rispetto a GitHub canonical raw. La futura execution deve salvare `planning-review-integration.md` e i report canonical/head prima di qualsiasi Swift patch. Se TASK-122 raw resta `404` o MASTER-PLAN remoto resta TASK-121-only, registrare `BLOCKED_EXTERNAL_HEAD_MISMATCH` o `MISCONFIGURED_HEAD_MISMATCH` con `NEXT_ACTION` e fermare move/split/delete Swift.
