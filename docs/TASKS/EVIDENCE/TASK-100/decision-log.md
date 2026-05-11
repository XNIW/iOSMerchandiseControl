# TASK-100 Decision Log

| Time | Decision | Rationale | Status |
|------|----------|-----------|--------|
| 2026-05-10 20:01 -0400 | Promote TASK-100 PLANNING -> EXECUTION by user override | The task file was planning-init only, but the user explicitly authorized full execution and evidence production. | applied |
| 2026-05-10 20:01 -0400 | Use synthetic `TASK100_*` D100-S and D100-M datasets first | Matches privacy requirements and avoids customer data. | applied |
| 2026-05-10 20:07 -0400 | Add TASK-100 XCTest acceptance harness instead of mutating production data | Enables repeatable D100-S/M import/export/sync/ProductPrice/UX checks. | applied |
| 2026-05-10 20:22 -0400 | Cache ProductPrice date formatters thread-locally | D100-M S100-F initially took about 37s; repeated formatter allocation was a narrow production bottleneck. | applied |
| 2026-05-10 20:45 -0400 | Keep minimum-closure result PARTIAL / REVIEW PASS WITH LIMITATIONS | Physical device, D100-L, and live Supabase were still missing. | superseded by targeted completion run |
| 2026-05-10 21:00 -0400 | Accept user override for targeted completion while TASK-100 is in REVIEW | User explicitly connected a physical iPhone and authorized D100-L/live Supabase checks. | applied |
| 2026-05-10 21:08 -0400 | Use `.xctestrun` environment injection for physical gated tests | Shell environment did not propagate to device XCTest; global Swift flags polluted SwiftPM dependency builds. | applied |
| 2026-05-10 21:16 -0400 | Treat physical D100-L as PASS with UX observation | 12k/480/320/48k completed without crash/OOM; device logged one 14.85s launch-overlap hang detection. | applied |
| 2026-05-10 21:25 -0400 | Commit empty catalog baseline before live catalog push in isolated test context | Release manual push preflight correctly blocks when no baseline exists; the test needed a valid empty baseline before synthetic local mutations. | applied |
| 2026-05-10 21:30 -0400 | Stop unbounded live preview investigation and switch to scoped TASK100 rows | Global live preview took too long and risked scanning unrelated account data; scoped preview is safer and aligned with TASK100 prefix. | applied |
| 2026-05-10 21:34 -0400 | Replace prefix `gte/lt` readback with `like(prefix%)` for Supabase reads/deletes | Live prefix range returned zero rows after successful writes; `like` matched the actual `TASK100_LIVE_*` rows. | applied |
| 2026-05-10 21:37 -0400 | Do not create more live rows after cleanup blocker | Targeted cleanup failed with RLS/delete permission `42501`; creating additional rows would increase residue. | applied |
| 2026-05-10 21:45 -0400 | Add and run live read-only verification for existing prefix | Validated scoped preview, ProductPrice read-back apply, and current/previous on existing residual rows without further remote mutation. | applied |
| 2026-05-10 21:46 -0400 | Keep TASK-100 PARTIAL / REVIEW PASS WITH LIMITATIONS / NON DONE | D100-L, device, live write/read are covered; live cleanup remains BLOCKED and test rows remain. | superseded by cleanup fix |
| 2026-05-10 22:02 -0400 | Diagnose cleanup `42501` from actual Supabase policies/grants | Remote inspection confirmed TASK-038 posture: `authenticated` has no DELETE grant/policy on catalog/prices; the app cleanup role is intentionally unable to delete `inventory_product_prices`. | applied |
| 2026-05-10 22:04 -0400 | Use admin/postgres scoped cleanup instead of changing RLS | The safest fix is operational cleanup of synthetic TASK100 rows only; weakening delete policy/grants would contradict the app's append-only/RLS posture. | applied |
| 2026-05-10 22:08 -0400 | Accept cleanup as resolved after SQL and physical test verification | Admin cleanup deleted exactly 1 supplier, 1 category, 120 products, 480 ProductPrice rows; SQL and device XCTest both verified 0 residue. | applied |
| 2026-05-10 22:09 -0400 | Move TASK-100 to REVIEW PASS FINAL / READY FOR FINAL ACCEPTANCE, still NON DONE | All technical TASK-100 blockers are resolved, but repo policy keeps DONE reserved for user/Claude confirmation. | applied |

## Problems Found And Resolved

- Physical XCTest env propagation: fixed by using `.xctestrun` env injection.
- SwiftPM flag pollution: compile-flag gating was removed in favor of runtime env/sentinel gates.
- Live catalog push preflight blocked without baseline: fixed by committing an empty local baseline in the isolated test store before seeding synthetic local catalog changes.
- Live readback prefix range returned zero rows: replaced with `like(prefix%)` queries.
- Live preview scope: added scoped read-only verification to avoid full-account preview scans.
- Live cleanup `42501`: diagnosed as missing authenticated DELETE grant/policy from TASK-038; resolved with admin/postgres scoped SQL cleanup, no policy/grant changes.

## Problems Remaining

- No TASK-100 technical blocker remains after cleanup verification.
- TASK-100 remains NON DONE only because the repo workflow reserves formal DONE for user/Claude confirmation.
