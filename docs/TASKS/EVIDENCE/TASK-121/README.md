# TASK-121 Evidence README

## Stato
- **Task**: TASK-121 — iOS Sync Architecture Full Purification and Legacy Eradication
- **Stato corrente**: ACTIVE / FIX — CHANGES_REQUIRED
- **Scope di questa fase**: final independent review evidence and targeted scanner/tracking fix. Nessuna nuova feature utente, nessun Supabase live, nessun cleanup, nessuna migration/RLS/grant/RPC/schema change, nessun push GitHub in questo review pass.
- **Frase obbligatoria**: TASK-121 is created to plan the final architecture purification. Completion requires execution, review, and user acceptance.
- **Verdict corrente**: `TASK-121 ACTIVE / FIX — CHANGES_REQUIRED`, non DONE.
- **Reviewed SHA corrente**: local `HEAD`, `origin/main` e GitHub canonical `main` allineati su `a7564857128d08d4e15eaf0977617fbd8a91806a`.
- **Commit architetturale storico citato da evidence precedenti**: `2ac8cb02587657307a0ec136e8153f6ee29808a2`.
- **Blocco P1**: `iOSMerchandiseControl/Sync/Remote/SupabaseTransportClient.swift` resta un mega-service Remote multi-domain; `scan sync-architecture --task TASK-121 --strict` ora fallisce correttamente dopo il fix scanner `remote_transport_is_thin`.
- **Final review corrente**: `docs/TASKS/EVIDENCE/TASK-121/final-review.md`.

## Evidence root futura
La root unica per report di Execution/Review/Fix TASK-121 è:

```text
docs/TASKS/EVIDENCE/TASK-121/agent-runs/
```

Report generati altrove sono `MISCONFIGURED`.

La Execution/Review/Fix deve creare e mantenere:

```text
docs/TASKS/EVIDENCE/TASK-121/agent-runs/00-help-json.json
docs/TASKS/EVIDENCE/TASK-121/agent-runs/00-commands-json.json
docs/TASKS/EVIDENCE/TASK-121/agent-runs/00-discovery-summary.md
docs/TASKS/EVIDENCE/TASK-121/agent-runs/index.md
docs/TASKS/EVIDENCE/TASK-121/architecture-before-after.md
docs/TASKS/EVIDENCE/TASK-121/sync-inventory.csv
docs/TASKS/EVIDENCE/TASK-121/sync-inventory.json
```

Questi file sono ora evidence runtime/tracking di TASK-121. Live e cleanup restano `NOT_RUN` salvo override separato.

## Metadata obbligatori
Ogni comando wrapped deve produrre `.md`, `.json`, `.log` sotto `agent-runs/` con JSON schema `1.1` e:

- task id;
- git SHA;
- branch;
- dirty state;
- command slug;
- status canonico;
- exit code;
- safety level;
- started/ended timestamps;
- evidence path;
- `redaction_summary`;
- `NEXT_ACTION`.

Ogni output CLI deve esporre almeno:

```text
RESULT
EXIT_CODE
REPORT_MD
REPORT_JSON
NEXT_ACTION
```

Errori e blocchi devono essere concisi, azionabili e a basso rumore.

## Status taxonomy
Status JSON canonici:

```text
PASS
FAIL
BLOCKED_EXTERNAL
NOT_RUN
PASS_WITH_NOTES
MISCONFIGURED
UNSAFE_OPERATION_REFUSED
```

Exit code:

```text
0 PASS / PASS_WITH_NOTES
1 FAIL
2 BLOCKED_EXTERNAL
3 MISCONFIGURED
4 UNSAFE_OPERATION_REFUSED
```

Regole:
- `NOT_RUN` non conta mai come PASS.
- `PASS_WITH_NOTES` non chiude gate blocker-class senza accettazione esplicita in review.
- `BLOCKED_EXTERNAL` richiede `NEXT_ACTION` eseguibile dall'utente o dall'ambiente.
- `MISCONFIGURED` blocca REVIEW.
- `UNSAFE_OPERATION_REFUSED` è expected PASS solo nei safety-refusal tests, non nei gate normali.
- DONE richiede review approval e conferma utente esplicita.

## Redaction
I report TASK-121 devono redigere:
- Supabase URL;
- project ref;
- anon/service keys;
- JWT;
- token;
- password;
- email;
- auth session id;
- device serial;
- path personali assoluti;
- SQL output con dati utente;
- row samples reali;
- env vars sensibili.

Normalizzare path locali:

```text
/Users/minxiang/Desktop/iOSMerchandiseControl -> $IOS_REPO
/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView -> $ANDROID_REPO
/Users/minxiang/Desktop/MerchandiseControlSupabase -> $SUPABASE_REPO
```

## Discovery e ordine
Ogni futura Execution deve iniziare con HEAD/preflight/config e poi discovery harness:

```bash
./tools/agent/mc-agent.sh git head-consistency --task TASK-121
./tools/agent/mc-agent.sh preflight --require-head-consistency --task TASK-121
./tools/agent/mc-agent.sh config validate --task TASK-121
./tools/agent/mc-agent.sh help-json
./tools/agent/mc-agent.sh list commands-json
```

Ogni comando nella matrix deve essere discoverable prima dell'uso. Se manca, Execution deve creare/routare il comando, aggiornare MCP allowlist, aggiungere fixture RED/GREEN, rieseguire discovery e solo poi usarlo.

Execution non puo' continuare se discovery output non e' salvato, se un comando pianificato e' assente dalla discovery, o se MCP allowlist non corrisponde alla CLI discovery per nuovi comandi safe.

Sequenza futura obbligatoria:
1. HEAD/preflight/config.
2. `help-json` / `list commands-json`.
3. `task-docs` e `master-plan-consistency`.
4. `harness-routing`, `harness-health`, `mcp-wrapper`.
5. `source-format`.
6. Creazione/routing scanner TASK-121 mancanti.
7. Fixture RED/GREEN.
8. `scanner-self-tests`.
9. `sync-inventory`.
10. Architecture audit.
11. Solo dopo: Swift moves/splits/deletes.
12. Build/test/smoke.
13. Supabase read-only contract.
14. Sensitive/evidence/report validation.
15. Before/after architecture map.
16. Handoff solo `ACTIVE / REVIEW`, mai DONE.

## Matrix comandi futura
```bash
./tools/agent/mc-agent.sh git head-consistency --task TASK-121
./tools/agent/mc-agent.sh preflight --require-head-consistency --task TASK-121
./tools/agent/mc-agent.sh config validate --task TASK-121
./tools/agent/mc-agent.sh help-json
./tools/agent/mc-agent.sh list commands-json

./tools/agent/mc-agent.sh scan task-docs --task TASK-121 --strict
./tools/agent/mc-agent.sh scan master-plan-consistency --task TASK-121 --strict
./tools/agent/mc-agent.sh scan harness-routing --task TASK-121 --strict
./tools/agent/mc-agent.sh scan harness-health --task TASK-121 --strict
./tools/agent/mc-agent.sh scan mcp-wrapper --task TASK-121 --strict
./tools/agent/mc-agent.sh scan status-taxonomy --task TASK-121 --strict
./tools/agent/mc-agent.sh scan evidence-metadata --task TASK-121 --strict

./tools/agent/mc-agent.sh scan sync-inventory --task TASK-121 --strict
./tools/agent/mc-agent.sh scan sync-architecture --task TASK-121 --strict
./tools/agent/mc-agent.sh scan retry-ownership --task TASK-121 --strict
./tools/agent/mc-agent.sh scan manual-boundary --task TASK-121 --strict
./tools/agent/mc-agent.sh scan root-residue --task TASK-121 --strict
./tools/agent/mc-agent.sh scan shared-purity --task TASK-121 --strict
./tools/agent/mc-agent.sh scan dead-code --task TASK-121 --strict
./tools/agent/mc-agent.sh scan xcode-membership --task TASK-121 --strict
./tools/agent/mc-agent.sh scan duplicate-symbols --task TASK-121 --strict
./tools/agent/mc-agent.sh scan source-format --task TASK-121 --strict
./tools/agent/mc-agent.sh scan scanner-self-tests --task TASK-121 --strict

./tools/agent/mc-agent.sh supabase status-redacted --task TASK-121
./tools/agent/mc-agent.sh supabase contract sync-schema --task TASK-121 --read-only

./tools/agent/mc-agent.sh ios build debug --task TASK-121
./tools/agent/mc-agent.sh ios build release --task TASK-121
./tools/agent/mc-agent.sh ios test automatic-architecture --task TASK-121
./tools/agent/mc-agent.sh ios test automatic-domain --task TASK-121
./tools/agent/mc-agent.sh ios test sync --task TASK-121
./tools/agent/mc-agent.sh ios test manual-sync-regression --task TASK-121
./tools/agent/mc-agent.sh ios smoke options --task TASK-121

./tools/agent/mc-agent.sh scan sensitive --task TASK-121
./tools/agent/mc-agent.sh scan evidence --task TASK-121
./tools/agent/mc-agent.sh report validate-json --task TASK-121 --path docs/TASKS/EVIDENCE/TASK-121/agent-runs
git diff --check
```

Ogni comando nuovo o mancante deve essere creato e routed prima dell'uso.

## Scanner evidence attesa
`scan sync-inventory --task TASK-121 --strict` deve emettere Markdown, JSON schema `1.1`, CSV/structured table e fallire su `UNCATEGORIZED` o eccezioni prive di owner, motivo, test, scanner exception e review date.

Fixture scanner obbligatorie:

```text
tools/agent/fixtures/task121_scanners/
```

Ogni nuovo o modificato scanner TASK-121 deve avere fixture RED/GREEN, expected JSON status, expected exit code e README/manifest minimo. Gruppi richiesti: `sync-inventory`, `sync-architecture`, `retry-ownership`, `manual-boundary`, `root-residue`, `shared-purity`, `dead-code`, `xcode-membership`, `source-format`, `evidence-metadata`, `status-taxonomy`, `mcp-wrapper`.

Scanner TASK-121 previsti o da routare:
- `scan sync-inventory`;
- `scan retry-ownership`;
- `scan root-residue`;
- `scan shared-purity`;
- `scan sync-architecture --task TASK-121 --strict`;
- `scan manual-boundary --task TASK-121 --strict`;
- `scan dead-code --task TASK-121 --strict`;
- `scan xcode-membership --task TASK-121 --strict`.

Questi scanner non devono ricadere su fallback TASK-119/TASK-120. La logica deve vivere in `task121_scans.py` oppure in moduli generici task-aware, con routing discoverable e MCP allowlisted.

`task-docs` ed `evidence-metadata` devono fallire TASK-121 se questo README manca o non e' allineato al task file su evidence root, schema `1.1`, `.md/.json/.log`, `NEXT_ACTION`, `redaction_summary`, status canonici, `NOT_RUN` mai PASS, safety gates live/cleanup, esempi Cursor/Codex/Claude e report index.

`source-format` deve includere Swift sync files, root `Supabase*.swift`, root `*Sync*.swift`, `tools/agent/mc-agent.sh`, `tools/agent/lib/*.sh`, `tools/agent/lib/*.py` e `tools/agent/mcp/server.mjs`. File realmente one-line/minified devono essere ripuliti prima di refactor semantico.

Gli alias `ios test automatic-architecture`, `ios test automatic-domain`, `ios test sync` e `ios test manual-sync-regression` devono essere discoverable e mappati a XCTest plan/class reali prima dell'uso. Alias mancanti sono `MISCONFIGURED` con `NEXT_ACTION`, non workaround manuali `xcodebuild`.

`master-plan-consistency` deve riconoscere TASK-121 come unico task operativo corrente e non confondere heading storici ACTIVE/REVIEW/BLOCKED con lo stato corrente.

`Sync/Outbox/*` richiede classificazione file-by-file. Shared infrastructure non puo' essere trattata come `KEEP_SHARED_PURE`; usare `SPLIT_REQUIRED`, `KEEP_SHARED_INFRASTRUCTURE` o `EXCEPTION_REQUIRES_APPROVAL` secondo evidence.

Move/delete/split richiedono ledger con old/new path, action, owner, reason, symbols/types, callers before/after, Xcode membership before/after, tests required, rollback command, scanner checks ed evidence report.

Lo split `SupabaseInventoryService` richiede prima schema compatibility snapshot read-only e mappa table/column/RPC per adapter. Nessun adapter da colonne assunte senza evidence.

Android parity reference ledger obbligatorio: flow Android usato come riferimento, dominio iOS impattato, comportamento utente invariato, test/smoke, no Kotlin copied, no Android code changed senza override.

## Live e cleanup opzionali futuri
Default TASK-121: `NOT_RUN`. Non contano come PASS se non eseguiti.

Solo con autorizzazione esplicita:

```bash
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh live reconcile-counts --task TASK-121 --prefix TASK121_RECON_
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh live sync-matrix --task TASK-121 --prefix TASK121_FINAL_
./tools/agent/mc-agent.sh supabase cleanup --task TASK-121 --prefix TASK121_CLEANUP_ --dry-run
MC_ALLOW_CLEANUP=1 ./tools/agent/mc-agent.sh supabase cleanup --task TASK-121 --prefix TASK121_CLEANUP_ --execute --cleanup-plan-id <id>
./tools/agent/mc-agent.sh supabase residue-check --task TASK-121 --prefix TASK121_CLEANUP_
```

Vietato:
- cleanup globale;
- `%`;
- prefissi non `TASK121_*`;
- `auth.users`;
- reset DB;
- truncate;
- service-role client;
- bypass RLS;
- migration/RLS/grant/RPC/schema changes.

Cleanup execute richiede dry-run precedente, cleanup plan id, stesso task/prefix, lock e residue check finale.

## Esempi operatori
- Cursor: leggere questo README e il task document, poi verificare discovery prima di pianificare qualsiasi comando.
- Codex: in Execution/Fix rispettare l'ordine gate e non avviare Swift refactor prima di source-format, scanner routing, fixture e sync-inventory PASS.
- Claude: review planning prima di autorizzare Execution; TASK-121 resta ACTIVE / PLANNING finché non viene approvato il passaggio.

## Handoff corrente
`TASK-121 ACTIVE / PLANNING — READY_FOR_PLANNING_REVIEW`
