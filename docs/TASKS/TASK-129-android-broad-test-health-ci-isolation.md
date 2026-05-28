# TASK-129 — Android broad test health + CI isolation

## 1. Stato

- Task ID: TASK-129
- Titolo: Android broad test health + CI isolation
- Stato: DONE
- Fase attuale: CLOSED_BY_TASK130_CONSOLIDATED_REVIEW
- Stato operativo finale: DONE / ACCEPTED_WITH_BYTEBUDDY_QUARANTINE_NOTE
- Sorgente piano: TASK-128 P0.1 Android broad test health
- Repo iOS tracking/harness: `/Users/minxiang/Desktop/iOSMerchandiseControl`
- Repo Android target test: `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView`
- Supabase locale: `/Users/minxiang/Desktop/MerchandiseControlSupabase` read-only se necessario; non richiesto per test broad JVM
- Data creazione: 2026-05-27
- Ultimo aggiornamento: 2026-05-27
- Ultimo agente: Codex / Final reviewer-fixer
- Responsabile attuale: USER / Accepted closure with quarantine note
- Nota: execution harness/test-health. Nessuna patch Swift runtime, nessuna patch SQL/migration/RLS/grants. Patch Android minima applicata per rimuovere regressioni reali emerse dalla broad suite.

## 2. Obiettivo

Rendere verificabile e riutilizzabile la salute della broad unit suite Android, oppure produrre una quarantena tecnica corretta, evidence-backed e non ambigua. TASK-129 deve distinguere:

- broad PASS;
- broad FAIL reale;
- BLOCKED_EXTERNAL;
- MISCONFIGURED;
- PASS_WITH_NOTES;
- quarantena tecnica accettabile;
- failure JVM/ByteBuddy/MockK/JDK attach o ambiente test;
- regressioni reali da correggere prima di REVIEW.

Il comando canonico deve essere `android test broad --task TASK-129`; se la broad suite resta non-green per motivi strumentali, il comando canonico di diagnosi deve essere `android test quarantine-report --task TASK-129`.

## 3. Fonti lette

iOS/tracking/harness:

- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-128-release-hardening-final-production-gap-plan.md`
- `docs/TASKS/TASK-123-ios-android-simulator-autosync-speed-acceptance.md`
- `docs/TASKS/TASK-126-sync-policy-multistore-cache-mvp.md`
- `docs/TASKS/TASK-127-ios-options-responsiveness-sync-summary-performance.md`
- `tools/agent/README.md`
- `tools/agent/mc-agent.sh`
- `tools/agent/lib/common.sh`
- `tools/agent/lib/android.sh`
- `tools/agent/lib/report.sh`
- `tools/agent/lib/redact.sh`

Android:

- `app/build.gradle.kts`
- root `build.gradle.kts`
- `settings.gradle.kts`
- `gradle.properties`
- `app/src/test/**` inventory/sync/Room/MockK/Robolectric source set inventory

Supabase:

- Nessuna lettura schema live necessaria per questa execution: TASK-129 non esegue live DB, cleanup, migration, RLS/grants o dati test.

## 4. Repo state e local canonical

- iOS branch locale: `main`.
- iOS local HEAD e `origin/main`: `cdb225345f3b899fdf103b0d2045f83c408e87c5`.
- Android branch locale: `main`.
- Android HEAD locale: `c6cfb5d82797992a18d0653d408c2e24c73a3b4b`.
- Stato locale iOS all'ingresso: dirty documentale coerente con TASK-128/TASK-129 (`docs/MASTER-PLAN.md`, TASK-128 locale, evidence TASK-129).
- Stato locale Android: dirty coerente con TASK-129 (`InventoryRepository.kt`, `DefaultInventoryRepositoryTest.kt`), nessun conflitto Git reale.
- Classificazione: `LOCAL_CANONICAL_AHEAD_OF_REMOTE` per tracking/documentazione locale TASK-128/TASK-129 e patch TASK-129 non ancora pubblicate; non e' blocker per istruzione utente perche' HEAD e origin/main sono allineati e non ci sono conflitti Git reali.

## 5. Automation contract

Comandi canonici TASK-129:

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

Report attesi:

- broad test report Markdown/JSON/log;
- eventuale quarantine report Markdown/JSON/log;
- scan sensitive report Markdown/JSON/log;
- scan evidence report Markdown/JSON/log;
- validate-json report Markdown/JSON/log;
- final acceptance matrix in questo task file.

Exit code:

- `0`: PASS;
- `1`: FAIL;
- `2`: BLOCKED_EXTERNAL;
- `3`: MISCONFIGURED;
- `4`: UNSAFE_OPERATION_REFUSED.

Regole:

- Non usare PASS per test non eseguiti.
- Non dichiarare broad PASS se si usa quarantena.
- Non usare comandi Gradle raw ripetuti fuori dal harness.
- Manual one-off ammesso solo con motivazione `NO_CANONICAL_HARNESS`; in TASK-129 il comando broad viene aggiunto al harness.

## 6. Dataset / prefix policy

- Nessun dataset live previsto.
- Nessun write Supabase previsto.
- Nessun cleanup previsto.
- Se emergessero dati live non previsti: usare solo prefissi `TASK129_*`, `MC_ALLOW_LIVE=1` solo se esplicitamente necessario, collision scan, cleanup scoped dry-run/execute, residue-check; non usare dati reali, service_role client o bypass RLS.

## 7. Scenario matrix

| ID | Scenario | Comando | Esito accettabile | Evidence |
|---|---|---|---|---|
| S129-01 | Harness discovery | `help-json`, `list commands-json` | comandi TASK-129 discoverable | stdout / contract |
| S129-02 | Config | `config validate` | PASS | agent report |
| S129-03 | Git/head | `git head-consistency`, `preflight --require-head-consistency` | PASS o LOCAL_CANONICAL_AHEAD_OF_REMOTE documentato | agent report |
| S129-04 | Android build | `android build debug` | PASS | agent report |
| S129-05 | Android targeted sync | `android test sync` | PASS | agent report |
| S129-06 | Android broad unit | `android test broad` | PASS oppure FAIL classificato | agent report |
| S129-07 | Quarantine | `android test quarantine-report` | PASS_WITH_NOTES_CANDIDATE solo se failure strumentali | agent report |
| S129-08 | Redaction | `scan sensitive` | PASS | agent report |
| S129-09 | Evidence hygiene | `scan evidence` | PASS | agent report |
| S129-10 | JSON schema | `report validate-json` | PASS | agent report |

## 8. Acceptance matrix

| Gate | Requirement | Stato |
|---|---|---|
| AC-129-01 | TASK-129 tracking/evidence creati | PASS |
| AC-129-02 | `android test broad --task TASK-129` esiste ed e' discoverable | PASS |
| AC-129-03 | `android test broad` produce report Markdown/JSON e summary con NEXT_ACTION | PASS |
| AC-129-04 | Android build debug PASS | PASS |
| AC-129-05 | Android targeted sync PASS | PASS |
| AC-129-06A | Broad suite PASS | NOT_PASS |
| AC-129-06B | Oppure broad non-green classificata con quarantena corretta | PASS_WITH_NOTES_CANDIDATE |
| AC-129-07 | Nessuna regressione reale nascosta | PASS |
| AC-129-08 | Stable CI alternative documentato se quarantena | PASS |
| AC-129-09 | scan sensitive PASS | PASS |
| AC-129-10 | scan evidence PASS | PASS |
| AC-129-11 | validate-json PASS | PASS |
| AC-129-12 | MASTER-PLAN aggiornato; TASK-130 non aperto | PASS |

## 9. Safety / redaction policy

Tutti i report devono redigere:

- token/JWT/Bearer;
- access_token/refresh_token/anon_key/service_role;
- email reali;
- Supabase project ref;
- path `/Users/<nome>/...`;
- device serial;
- dati reali.

TASK-129 non deve:

- modificare codice Swift runtime;
- modificare codice Kotlin runtime salvo fix minimo solo se broad dimostra regressione reale;
- modificare SQL/migration/RLS/grants;
- usare Supabase live;
- usare service_role client;
- aprire TASK-130;
- dichiarare DONE o production-ready globale.

## 10. Execution log

- 2026-05-27: preflight iniziale richiesto eseguito con `MC_TASK_ID=TASK-129`.
- 2026-05-27: `help-json` e `list commands-json` pre-patch non contenevano ancora i comandi TASK-129.
- 2026-05-27: `config validate` PASS.
- 2026-05-27: `git head-consistency --task TASK-129` PASS.
- 2026-05-27: `preflight --require-head-consistency --task TASK-129` PASS.
- 2026-05-27: red check TDD `android test broad --task TASK-129` pre-patch = MISCONFIGURED, comando non instradato.
- 2026-05-27: aggiunti al harness `android test broad` e `android test quarantine-report`; aggiornati `help-json`, `list commands-json`, `tools/agent/README.md`.
- 2026-05-27: `android build debug --task TASK-129` PASS iniziale.
- 2026-05-27: `android test sync --task TASK-129` PASS iniziale.
- 2026-05-27: prima broad fresca non-green: 494 tests, 151 failures, 2 skipped; classificazione corretta dopo fix harness = 143 `BYTEBUDDY_ATTACH_ENV` + 8 `REAL_REGRESSION`.
- 2026-05-27: diagnostica one-off `NO_CANONICAL_HARNESS` su `DefaultInventoryRepositoryTest` ha confermato 8 failure reali standalone.
- 2026-05-27: fix Android minimo: `FakeCatalogRemote016` ora riflette upsert/tombstone nel fetch successivo, il test prune 114 usa un ref clean davvero gia' applicato, e `pullProductPricesFromRemote` usa paginazione anche nel full price pull.
- 2026-05-27: diagnostica one-off `DefaultInventoryRepositoryTest` post-fix PASS (167 tests).
- 2026-05-27: `android build debug --task TASK-129` finale PASS: `20260527T224451Z-android-build-debug-task-TASK-129-p82672.*`.
- 2026-05-27: `android test sync --task TASK-129` finale PASS: `20260527T224457Z-android-test-sync-task-TASK-129-p83057.*`.
- 2026-05-27: `android test broad --task TASK-129` finale non-green ma classificato: 494 tests, 143 failures, 2 skipped, `BYTEBUDDY_ATTACH_ENV` only. Report `20260527T224507Z-android-test-broad-task-TASK-129-p83471.*`.
- 2026-05-27: `android test quarantine-report --task TASK-129` PASS_WITH_NOTES: report `20260527T224559Z-android-test-quarantine-report-task-TASK-129-p84055.*`.
- 2026-05-27: `scan sensitive --task TASK-129 docs/TASKS/EVIDENCE/TASK-129` finale PASS: `20260527T224822Z-scan-sensitive-task-TASK-129-docs-TASKS-EVIDENCE-TASK-129-p87440.*`.
- 2026-05-27: `scan evidence --task TASK-129` finale PASS: `20260527T224832Z-scan-evidence-task-TASK-129-p88793.*`.
- 2026-05-27: `report validate-json --task TASK-129 --path docs/TASKS/EVIDENCE/TASK-129/agent-runs` finale PASS: `20260527T224840Z-report-validate-json-task-TASK-129-path-docs-TASKS-EVIDENCE-TASK-129-agent-runs-p90227.*`.
- 2026-05-27: `bash -n` harness PASS; `git diff --check` iOS + Android changed paths PASS.

## 11. Handoff REVIEW

TASK-129 passa a `ACTIVE / REVIEW`, non DONE, con Caso B:

- Android build debug: PASS.
- Android targeted sync: PASS.
- Android broad suite: non-green, 494 tests, 143 failures, 2 skipped.
- Quarantena tecnica: PASS_WITH_NOTES_CANDIDATE, failure residue solo `BYTEBUDDY_ATTACH_ENV`.
- Regressioni reali: 8 failure reali in `DefaultInventoryRepositoryTest` trovati e corretti prima del handoff; rerun mirato PASS, broad finale non mostra piu' `REAL_REGRESSION`.
- Stable CI alternative documentato: `android build debug --task TASK-129` + `android test sync --task TASK-129`.
- Evidence hygiene: scan sensitive PASS, scan evidence PASS, validate-json PASS.
- Stato finale richiesto: `ACTIVE / REVIEW — PASS_WITH_NOTES_CANDIDATE_QUARANTINE`.
- Rischio residuo: broad JVM non e' verde finche' resta il problema MockK/ByteBuddy/JDK attach; non dichiarare broad PASS.

TASK-130 non deve essere aperto in questa execution.

## 12. Final closure via TASK-130

2026-05-28: TASK-129 e' chiuso **DONE / ACCEPTED_WITH_BYTEBUDDY_QUARANTINE_NOTE** tramite review consolidata TASK-130.

- Broad Android non e' verde e non viene dichiarata PASS piena.
- Quarantine finale TASK-130: `20260528T004418Z-android-test-quarantine-report-task-TASK-130-p82451.*`.
- Residuo accettato: 143 failure `BYTEBUDDY_ATTACH_ENV` / MockK / JDK attach.
- Stable CI alternative confermata: `android build debug`, `android test sync`, `android test price-contract`.
- Nessuna regressione reale Android residua classificata nel report finale.
