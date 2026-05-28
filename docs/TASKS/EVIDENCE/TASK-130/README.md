# TASK-130 Evidence — Consolidated TASK-128 to TASK-130

## Stato

- Task: TASK-130
- Stato corrente: DONE / CONSOLIDATED_TASK128_TO_TASK130_REVIEW_PASS_WITH_NOTES
- Data: 2026-05-28
- Harness: `./tools/agent/mc-agent.sh`
- Evidence dir: `docs/TASKS/EVIDENCE/TASK-130`
- Agent runs: `docs/TASKS/EVIDENCE/TASK-130/agent-runs/`
- Live Supabase: non usato
- Cleanup/residue live: non applicabile
- Nota: override utente applicato; TASK-130 consolida i residui TASK-128 senza aprire TASK-131/TASK-132/TASK-133/TASK-134/TASK-135.

## Final gate reports

| Gate | Report Markdown/JSON | Stato |
|---|---|---|
| iOS build debug | `20260528T003119Z-ios-build-debug-task-TASK-130-p43834.*` | PASS |
| iOS price-contract tests | `20260528T003145Z-ios-test-price-contract-task-TASK-130-p45769.*` | PASS |
| Android build debug | `20260528T003119Z-android-build-debug-task-TASK-130-p43792.*` | PASS |
| Android targeted sync | `20260528T003145Z-android-test-sync-task-TASK-130-p45806.*` | PASS |
| Android price-contract tests | `20260528T003119Z-android-test-price-contract-task-TASK-130-p43793.*` | PASS |
| Android broad suite | `20260528T002959Z-android-test-broad-task-TASK-130-p42537.*` | FAIL broad globale |
| Android quarantine report | `20260528T003101Z-android-test-quarantine-report-task-TASK-130-p43280.*` | PASS_WITH_NOTES: 143 `BYTEBUDDY_ATTACH_ENV`, nessuna regressione reale residua |
| Price contract scan strict | `20260528T003145Z-scan-price-contract-task-TASK-130-strict-p45770.*` | PASS |
| Supabase price schema read-only | `20260528T003145Z-supabase-contract-price-schema-task-TASK-130-read-only-p45805.*` | PASS |
| Golden corpus validate | `20260528T003205Z-harness-golden-corpus-validate-task-TASK-130-p47713.*` | PASS_WITH_NOTES |
| Golden corpus roundtrip | `20260528T003205Z-harness-golden-corpus-roundtrip-task-TASK-130-p47714.*` | PASS_WITH_NOTES |
| SwiftData fetch budget | `20260528T003205Z-scan-swiftdata-fetch-budget-task-TASK-130-strict-p47754.*` | PASS_WITH_NOTES |
| Import-large benchmark | `20260528T003205Z-ios-benchmark-import-large-task-TASK-130-p47749.*` | PASS_WITH_NOTES |
| Options first-sync smoke | `20260528T003205Z-ios-smoke-options-first-sync-task-TASK-130-p47756.*` | PASS_WITH_NOTES |
| Scanner edge smoke | `20260528T003205Z-ios-smoke-scanner-edge-task-TASK-130-p47755.*` | PASS_WITH_NOTES |
| Accessibility smoke | `20260528T003205Z-ios-smoke-accessibility-task-TASK-130-p47779.*` | PASS_WITH_NOTES |
| Real-device feasibility | `20260528T003205Z-harness-real-device-feasibility-task-TASK-130-p47762.*` | PASS_WITH_NOTES / PARTIAL |

Final closure: `final-review-done-closure.md`.

Latest redaction/integrity gates after DONE tracking updates:

- `20260528T005310Z-scan-sensitive-task-TASK-130-docs-TASKS-EVIDENCE-TASK-130-p29836.*`
- `20260528T005322Z-scan-evidence-task-TASK-130-p37843.*`
- `20260528T005333Z-report-validate-json-task-TASK-130-path-docs-TASKS-EVIDENCE-TASK-130-agent-runs-p29831.*`

## Consolidated coverage summary

| TASK-128 gap | Copertura | Stato |
|---|---|---|
| Android broad test health | TASK-129 quarantine confirmed; TASK-130 real regressions fixed | PASS_WITH_NOTES |
| Price contract current/last/previous/old | iOS, Android, Supabase read-only, scanner and targeted tests | PASS |
| Golden corpus import/export | Synthetic fixtures + static/roundtrip harness | PASS_WITH_NOTES / PARTIAL binary exchange |
| SwiftData/import performance | Chunked iOS old-price lookup + static budget scan | PASS_WITH_NOTES |
| Real-device/offline/background | Feasibility checked only; no long locked/background run | PARTIAL |
| Options first-sync UX | Static smoke | PASS_WITH_NOTES |
| Scanner/accessibility/Dynamic Type/localization | Static smokes + build | PASS_WITH_NOTES |
| Cleanup/refactor P2 | No mega-refactor; targeted fixes only | NOT_RUN by design |

## Golden corpus

Fixture directory: `docs/TASKS/EVIDENCE/TASK-130/golden-corpus/`.

- `task130-golden-products.csv`
- `task130-golden-excel.html`
- `full-db/Products.csv`
- `full-db/Suppliers.csv`
- `full-db/Categories.csv`
- `full-db/PriceHistory.csv`
- `expected-results.json`

All rows are synthetic `TASK130_*`; no real operational data is included.

## Safety

- No dati reali.
- No Supabase live.
- No SQL/migration/RLS/grants/RPC patch.
- No service_role client.
- No cleanup globale.
- No TASK-131/TASK-132/TASK-133/TASK-134/TASK-135.
- DONE with accepted notes.
- No production-ready globale.
