# Legacy blocked/partial closure alignment — 2026-05-12

## Scope

User override: close historical `BLOCKED`, `PARTIAL_ACCEPTED`, `SUPERSEDED` and `WONT_DO` task records when later evidence has either:

- verified the same functional area with equal or stronger coverage;
- superseded the historical task with a later task;
- accepted a non-blocking platform/manual limitation in a later final review.

This alignment is tracking/documentation-only. It does not create a new task, does not reopen production code, and does not claim global production-ready 100%.

## Evidence baseline

| Evidence | Coverage used for closure |
|---|---|
| `docs/TASKS/TASK-029-ios-completion-tracking-cleanup-manual-validation-matrix.md` | Original matrix of legacy blocked task packs A-E and closure candidates. |
| `docs/TASKS/EVIDENCE/TASK-100/` | Large dataset import/export/ProductPrice/sync-preview/cancel-retry acceptance, including physical-device D100-L and full DB export/import path. |
| `docs/TASKS/EVIDENCE/TASK-102/` | Final iOS UX smoke over Home, import handoff, PreGenerate, GeneratedView, row detail, manual entry, scanner fallback/search, History, Database CRUD, ProductPrice history, import/export surfaces and Dynamic Type extra-large. |
| `docs/TASKS/EVIDENCE/TASK-103/` | Final real-device iOS <-> Supabase <-> Android acceptance with import/export, ProductPrice current/previous, dedupe/no-op, conflict/recovery, offline/retry, cleanup scoped and privacy/security pass. |
| `docs/TASKS/EVIDENCE/TASK-097/` and `docs/TASKS/EVIDENCE/TASK-098/` | Runtime sandbox iOS/Supabase and cross-platform Android/Supabase/iOS smoke that superseded earlier runtime gaps. |

## Closure matrix

| Task(s) | Previous state | Closure state | Basis |
|---|---:|---:|---|
| TASK-002 | BLOCKED in task file; DONE in MASTER | DONE / accepted iOS limitation | Historical decision already accepted "Condividi/Invia copia"; cross-app "Apri con" is platform-limited and no longer blocks the app roadmap. |
| TASK-005, TASK-016 | BLOCKED | DONE / validated by later acceptance | ImportAnalysis/import dedupe covered by later import hardening plus TASK-102 smoke and full regression. |
| TASK-006, TASK-023, TASK-024, TASK-030 | BLOCKED | DONE / validated by later acceptance | Full DB import/export, re-read, large dataset, progress/cancel/retry and ProductPrice paths covered by TASK-100/TASK-103; UI surfaces covered by TASK-102. |
| TASK-008, TASK-018, TASK-019, TASK-025, TASK-027, TASK-028, TASK-032 | BLOCKED | DONE / validated by later acceptance | GeneratedView, row detail, manual entry, missing/summary/history surfaces and scanner fallback/reopen behavior covered by TASK-102 final smoke/review; data-scale and ProductPrice stability covered by TASK-100/TASK-103. |
| TASK-009, TASK-021 | BLOCKED | DONE / validated by later acceptance | ProductPrice history/current/previous and History warning surfaces covered by TASK-100/TASK-102/TASK-103. |
| TASK-020, TASK-026 | BLOCKED | DONE / accepted hardware note | Scanner fallback/permission surface covered in TASK-102. Physical camera/torch remains hardware-only and was accepted as non-blocking in TASK-102 final closure; no new torch engine changes are part of this alignment. |
| TASK-011 | SUPERSEDED | DONE / superseded | Umbrella task consumed by TASK-022/023/024 and then later validated by TASK-030-equivalent coverage through TASK-100/TASK-103. |
| TASK-013, TASK-015 | WONT_DO | DONE / wont-do accepted | `sim_ui.sh` performance and the historical standalone calculate-dialog backlog item are not part of the current standard workflow; later GeneratedView/manual-entry smoke and simulator/device evidence no longer depend on these records. |
| TASK-052 | BLOCKED / superseded | DONE / superseded | Superseded by TASK-053 onward; sync_events/outbox foundation through TASK-061/062/081/103 covers the roadmap without reopening TASK-052. |
| TASK-083 | DONE with BLOCKED preflight | DONE / superseded by later runtime acceptance | TASK-097 and TASK-103 provide the runtime manifest and acceptance evidence that TASK-083 originally lacked. |
| TASK-084 | DONE document-only | DONE / superseded by later runtime acceptance | TASK-098 and TASK-103 provide runtime cross-platform evidence. |
| TASK-085 | DONE / PARTIAL_ACCEPTED | DONE / later gaps closed | TASK-086 through TASK-103 close or explicitly accept the hardening gaps: updated_at policy, ProductPrice identity, large dataset, privacy/security, UX and final cross-platform acceptance. |
| TASK-090 | DONE / PARTIAL_ACCEPTED | DONE / later gaps closed | TASK-097, TASK-098, TASK-100 and TASK-103 cover the fresh runtime, ProductPrice, import/export, cleanup and cross-platform gaps that TASK-090 left partial. |

## Review verification run

Executed on 2026-05-12 after the tracking alignment.

| Check | Result | Notes |
|---|---:|---|
| `git diff --check` | PASS | No whitespace/conflict-marker issues in the iOS repo diff. |
| iOS Debug simulator build | PASS | `xcodebuild ... build` on iPhone 17 Pro / iOS 26.4.1 completed successfully. |
| iOS targeted regression ring | PASS | `SupabaseManualSyncViewModelTests`, `LocalPendingAggregatedPushPlannerTests`, `SupabaseManualSyncLifecycleRunGateTests`, `Task100LargeDatasetAcceptanceTests`, `Task103CrossPlatformAcceptanceTests`: `112 passed / 13 skipped / 0 failed`. Skips are the existing opt-in/live-gated paths. |
| iOS full XCTest | PASS | Fresh iPhone 17 Pro / iOS 26.5 run: `640 passed / 19 skipped / 0 failed` from `/tmp/iosmc-legacy-full.xcresult`. |
| Privacy/secret scan | PASS | Strict scan for JWT, refresh token, bearer token, API/anon/service-role assignments and email-like secrets returned no matches in the changed legacy evidence/tracking/test diff. Wider matches were reviewed as synthetic UUID/test fixture strings or historical guardrail text. |
| Android re-run | NOT REQUIRED FOR THIS ALIGNMENT | No Android files were changed by the legacy tracking closure. Android runtime/cross-platform evidence remains the TASK-098 and TASK-103 evidence baseline. |

## Residual notes

- Full VoiceOver gesture traversal and real camera/torch manual use remain non-blocking P1/manual notes from TASK-102, not active blockers.
- Historical `BLOCKED`/`PARTIAL_ACCEPTED` wording remains in older archival sections, templates, and successor-task rationale where it describes the state at that time; those mentions are not current tracking state.
- No hidden `FAIL`, `BLOCKED`, `NOT_RUN` or waiver is promoted to PASS inside the original evidence files; this alignment records that later tasks superseded or accepted those historical gaps.
- TASK-104 remains unopened.
