# TASK-112 Evidence

Pacchetto evidence per **TASK-112 — Evidence-backed automatic cross-platform sync and removal of public manual sync CTA**.

Checkpoint iniziale: **2026-05-20** — **PLANNING only** *(nessun codice, nessun test runtime, nessuna mutation Supabase)*.

**Revisione integrativa PLANNING — 2026-05-20:** orchestrator single-flight, idempotenza, account boundary, observability, release gating, **CA-22…CA-42**, test matrix **1–36**.

**Planning refinement supplementare — 2026-05-20:** freshness contract mobile, conflict policy, data invariants, test data safety (`TASK112_*`), rollback/feature-gating, go/no-go matrix.

**Offline-first sync contract — 2026-05-20:** write pipeline, outbox/coalescing, reconnect/pull post-offline, network monitoring, UX offline, **CA-43…CA-55**, test matrix **37–50**, prefisso live **`TASK112_OFFLINE_*`**.

**Offline resilience refinement — 2026-05-20:** atomicità locale/outbox, dependency graph, partial ack/retry lanes, connectivity truth table, long-offline retention gap, storage failure UX, queue fairness, fake clock/scheduler tests, **CA-56…CA-68**, test matrix **51–62**.

## Scopo evidence
Documentare in modo **privacy-safe** e **verificabile** che:
1. la sync **automatica** copre tutti i domini richiesti *(catalog, ProductPrice, History, tombstone, metadata)*;
2. la gestione **offline-first** preserva modifiche locali, converge automaticamente al reconnect e rispetta resilienza *(atomicità, dependency graph, partial ack, connectivity truth)*;
3. la **CTA manuale pubblica** è assente in Release iOS/Android **solo dopo** i gate automatici PASS;
4. i test cross-platform live gated (**CA-20**) e i criteri (**CA-01…CA-68**) supportano la chiusura — o documentano blocker (**CA-21**).

**Riferimenti storici:** TASK-110 `final-cross-platform-completion/`; TASK-108 — **non** riusati come prova runtime senza rerun.

## Regole privacy
- **Non** salvare token, anon key complete, JWT, refresh token, service key, email raw, payload completi History/session, SQL/HTTP body con dati utente o altri payload sensibili.
- Usare hash brevi o placeholder `<REDACTED>`.
- Dump raw fuori repo (`/tmp/task112_*`); non committare.
- Live test solo prefissi **`TASK112_YYYYMMDD_*`** e **`TASK112_OFFLINE_*`**; cleanup scoped su prefisso/owner; no delete globali.

## Placeholder per fase

### Planning *(integrato + refinement + offline-first + offline resilience 2026-05-20)*
| File | Stato | Ruolo |
|------|-------|-------|
| `README.md` | **compiled** | Indice evidence e regole |
| `00-planning-preflight.md` | placeholder | Stato repos, TASK-109/110/111, scope |
| `01-planning-contract-summary.md` | placeholder | Contratto automatic sync + orchestrator |
| `02-planning-integration-notes.md` | placeholder | Revisione integrativa |
| `03-planning-refinement-supplement.md` | placeholder | Freshness, conflict, invariants, go/no-go |
| `04-planning-offline-first-contract.md` | placeholder | Offline-first pipeline, outbox, reconnect |
| `05-planning-offline-resilience-refinement.md` | placeholder | Atomicità, dependency graph, partial ack, connectivity truth |

### EXECUTION-AUDIT *(read-only — futuro)*
| File | Stato | Ruolo |
|------|-------|-------|
| `audit-ios-trigger-map.md` | placeholder | Trigger iOS vs T1–T9 |
| `audit-android-trigger-map.md` | placeholder | Trigger Android vs T1–T9 |
| `audit-supabase-contract.md` | placeholder | Schema, RLS, grants, sync_events |
| `audit-ux-options-release-cta.md` | placeholder | CTA Release vs DEBUG |
| `audit-gap-matrix.md` | placeholder | Gap T1–T9 / domini / CA-01…CA-68 |
| `audit-conflict-policy-and-invariants.md` | placeholder | Conflict policy + data invariants |
| `audit-testdata-cleanup-safety.md` | placeholder | Prefisso TASK112_* / TASK112_OFFLINE_* |
| `audit-go-no-go-matrix.md` | placeholder | GO / GO_WITH_NOTES / NO_GO / BLOCKED_EXTERNAL |
| `audit-offline-first-contract.md` | placeholder | Sottocontratto offline-first vs codice attuale |
| `audit-android-offline-network-workmanager.md` | placeholder | ConnectivityManager, WorkManager, IO |
| `audit-ios-offline-nwpath-bg-foreground.md` | placeholder | NWPathMonitor, foreground, BGTask |
| `audit-outbox-coalescing-idempotency.md` | placeholder | Outbox schema, coalescing, idempotency keys |
| `audit-offline-pull-reconnect.md` | placeholder | Pull post-offline, delta, gap reason codes |
| `audit-offline-conflict-policy.md` | placeholder | Conflict offline/remote, tombstone, dual-device |
| `audit-local-atomicity-recovery.md` | placeholder | Transazione locale/outbox, recovery scan |
| `audit-offline-dependency-graph.md` | placeholder | Ordine supplier→product→ProductPrice→History |
| `audit-partial-ack-retry-lanes.md` | placeholder | Batch partial ack, retry lanes, queue fairness |
| `audit-connectivity-truth-table.md` | placeholder | noNetwork / noAuth / RLS / onlineReady |
| `audit-long-offline-retention-gap.md` | placeholder | Retention sync_events, watermark gap |
| `audit-storage-failure-ux.md` | placeholder | Local persistence failure, UX non allarmistica |
| `audit-supplier.md` … `audit-sync-metadata.md` | placeholder | Righe matrice domini |
| `10-execution-audit-verdict.md` | placeholder | Ready for IMPLEMENTATION / BLOCKED |

### IMPLEMENTATION *(futuro)*
| File | Stato | Ruolo |
|------|-------|-------|
| `20-implementation-notes-ios.md` | placeholder | Patch iOS |
| `21-implementation-notes-android.md` | placeholder | Patch Android |
| `22-implementation-notes-supabase.md` | placeholder | Migration proposta *(se approvata)* |

### Tests / build *(futuro)*
| File | Stato | Ruolo |
|------|-------|-------|
| `30-test-matrix-results.md` | placeholder | Esiti test **1–62** |
| `31-ios-build-test.md` | placeholder | CA-18 |
| `32-android-build-test.md` | placeholder | CA-19 |
| `test-offline-ios.md` | placeholder | Suite offline iOS |
| `test-offline-android.md` | placeholder | Suite offline Android |
| `test-offline-cross-platform-live.md` | placeholder | Live cross-platform offline |
| `test-network-flapping.md` | placeholder | CA-46, test #45 |
| `test-offline-import-large.md` | placeholder | CA-50, test #43 |
| `live-01` … `live-12`, `live-17` … `live-31`, `live-33`, `live-29`, `live-37` … `live-42`, `live-48`, `live-49`, `live-57` | placeholder | Scenari live |
| `sim-20` … `sim-24`, `sim-32`, `sim-34`, `sim-44`, `sim-51` … `sim-56`, `sim-58`, `sim-59`, `sim-61` | placeholder | Scenari sim |
| `perf-13`, `perf-16`, `perf-25`, `perf-26` | placeholder | Performance |
| `ui-14`, `ui-27`, `ui-35`, `ui-50`, `ui-60` | placeholder | UI smoke |
| `scan-15`, `scan-28` | placeholder | Release scan |
| `unit-62-fake-clock-scheduler.md` | placeholder | CA-68, test #62 |
| `audit-22-schema-mismatch.md` | placeholder | CA-38 |
| `review-36-go-no-go-matrix.md` | placeholder | CA-39, CA-67 |

### Live gated / Review *(futuro)*
| File | Stato | Ruolo |
|------|-------|-------|
| `40-live-gated-verdict.md` | placeholder | CA-20/21 |
| `50-review-final-verdict.md` | placeholder | APPROVED / CHANGES_REQUIRED / REJECTED |
| `screenshots/`, `logs/` | placeholder | Redatti, no PII |

## Governance

| Agente | Quando |
|--------|--------|
| **CLAUDE / Planner-Reviewer** | PLANNING / REVIEW |
| **CODEX / Cursor Executor** | EXECUTION-AUDIT / IMPLEMENTATION / FIX |

**TASK-109** **BLOCKED / SOSPESO**. **TASK-110 / TASK-111** **DONE**. **TASK-112** **ACTIVE / PLANNING** *(offline resilience refinement 2026-05-20)*; nessun PASS inventato.
