# TASK-111 — Evidence pack (`docs/TASKS/EVIDENCE/TASK-111/`)

**Stato progetto (MASTER):** **`TASK-111 DONE / Chiusura — REVIEW PASS WITH NOTES`** *(review finale 2026-05-17 13:53 -0400; micro-fix post-review colonne 2026-05-17 14:35 -0400; micro-fix pending supplier/category create UX 2026-05-17 15:22 -0400; review micro-fix pending-create 2026-05-17 15:38 -0400 PASS WITH NOTES; TASK-109 ancora BLOCKED / SOSPESO; TASK-110 ancora DONE)*

Questa cartella ospita le evidence della **EXECUTION end-to-end** avviata su override utente. Il contenuto planning-only sotto resta storico; da questo pass gli artifact `00–10` vengono compilati con distinzione `OBSERVED` / `INFERRED` / `ASSUMED` / `NOT_RUN` / `BLOCKED`.

- La **lista nominale `00–10`** e' stata compilata nel pass EXECUTION.
- Sono stati aggiunti anche artifact `11–12` per implementation notes e regression locks.
- La review finale ha aggiunto artifact `13–17`.
- Il micro-fix post-review richiesto dall'utente ha aggiunto artifact `18`; la review indipendente del micro-fix ha aggiunto artifact `19`.
- Il micro-fix post-review pending supplier/category create UX ha aggiunto artifact `20`; la review indipendente del micro-fix ha aggiunto artifact `21`.
- Le dichiarazioni PASS sono limitate a build/test/smoke realmente eseguiti; la review finale ha chiuso TASK-111 con note non bloccanti.

## Elenco evidence attese (nome file)

| File | Stato EXECUTION | Ruolo |
|------|----------------|-------------------------------------|
| `00-preflight-tracking.md` | **compiled** | Preflight repos / governance TASK-109/110 |
| `01-ios-code-map.md` | **compiled** | Mappa modulo iOS / Unified Contract |
| `02-android-behavior-map.md` | **compiled** | Baseline Android **B-01–B-17** con cite |
| `03-supabase-impact-map.md` | **compiled** | Impatti IMPORT→CLOUD; no mutation |
| `04-parity-matrix-filled.md` | **compiled** | Matrice **M1–M28** evidence-driven |
| `05-ux-ui-decisions.md` | **compiled** | Decisioni UX/UI iOS-native |
| `06-edge-case-fixture-plan.md` | **compiled** | Edge ↔ fixture/test sintetici |
| `07-performance-risk-plan.md` | **compiled** | Performance / MainActor risk plan |
| `08-test-plan.md` | **compiled** | Build/test/smoke results |
| `09-followup-slices.md` | **compiled** | Follow-up non bloccanti |
| `10-execution-audit-verdict.md` | **compiled** | Verdict: ready for REVIEW, **not DONE** |
| `11-implementation-notes.md` | **compiled** | File modificati e note refactor |
| `12-regression-locks.md` | **compiled** | RL-01…RL-10 |
| `13-review-preflight.md` | **compiled** | Preflight review / branch / HEAD / dirty state |
| `14-review-code-quality.md` | **compiled** | Findings review e fix applicati |
| `15-review-test-results.md` | **compiled** | Build/test/static/smoke finali |
| `16-review-ux-performance.md` | **compiled** | UX, accessibilita', performance, stabilita' |
| `17-review-final-verdict.md` | **compiled** | Verdict finale review |
| `18-post-review-column-default-selection.md` | **compiled** | Micro-fix default colonne non identificate OFF ma visibili |
| `19-review-post-fix-column-default-selection.md` | **compiled** | Review indipendente del micro-fix default selection |
| `20-post-review-pending-supplier-category-create.md` | **compiled** | Micro-fix pending-create supplier/category PreGenerate |
| `21-review-pending-supplier-category-create.md` | **compiled** | Review indipendente del micro-fix pending-create supplier/category |

Durante solo **planning refinement**: compilare **`draft`** degli outline **solo** se servono note interne; **vietato** simulare verdict PASS tecnici senza EXECUTION-AUDIT.

## Governance

| Agente tipico | Quando |
|---------------|--------|
| **CLAUDE / Planner-Reviewer** | PLANNING / review piano / gate verso EXECUTION-AUDIT |
| **CURSOR Executor-Auditor** | **solo** dopo nuovo prompt **EXECUTION-AUDIT** (**read-only**) |
| **CODEX Executor** | **solo** dopo **EXECUTION-IMPLEMENTATION** autorizzato per slice |

### Repository

| Ruolo | Riferimento |
|-------|-----------|
| iOS | `https://github.com/XNIW/iOSMerchandiseControl` |
| Android (ref.) | `https://github.com/XNIW/MerchandiseControlSplitView` |
| Supabase (solo map/read doc) | `https://github.com/XNIW/MerchandiseControlSupabase` |

**TASK-109 BLOCKED**, **TASK-110 DONE** — invariati anche dopo review e micro-fix. **TASK-111 DONE / REVIEW PASS WITH NOTES**; nessun `TASK-112` aperto.
