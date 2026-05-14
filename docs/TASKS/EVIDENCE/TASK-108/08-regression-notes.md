# TASK-108 Evidence 08 — Regression Notes

Status: EXECUTED (LIMITED).

Regression areas to verify:
- Options Release card and DEBUG diagnostics.
- Database product/supplier/category flows from TASK-107.
- ProductPrice history.
- Generated apply flow.
- Local-first offline behavior.

Result:
- Debug build/run PASS.
- Targeted manual sync regression tests PASS.
- Generated inventory pending/idempotence test PASS.

Limitations:
- Full app XCTest suite was not run.
- Live Supabase push/pull/read-back was not run.
- Physical device and Dynamic Type matrix were not run.

FIX/COMPLETION update 2026-05-13:
- Full app XCTest suite is now run and PASS: 659 passed / 0 failed / 21 skipped.
- Debug and Release simulator builds PASS.
- Dynamic Type basic smoke at XXXL was run for Options and captured in screenshots.
- Live Supabase app-auth push/pull/read-back and physical iOS smoke remain NOT RUN.

Targeted Options cleanup FIX update 2026-05-13 20:45 -0400:
- Options public surface no longer shows Manual price history push, Outbox sync_events, Local Supabase baseline, Recent sync events, local preflight, dry-run, or manual drain as primary content.
- Sign-in path was smoke-tested to Google OAuth prompt.
- Database, Generated/Inventory, and History signed-out tab smokes passed after cleanup.
- Dynamic Type extra-extra-large smoke passed for the cleaned Options public surface.
- Live app-auth sync matrix remains NOT RUN / BLOCKED_APP_AUTH.

Large ProductPrice bootstrap FIX update 2026-05-13 22:45 -0400:
- Regression risk fixed: large ProductPrice history no longer turns into a source error only because it exceeds a fixed total row cap.
- Regression risk fixed: baseline writer no longer attempts to insert a large baseline snapshot in one SwiftData save.
- Public Options CTA copy improved for baseline-absent/applicable-review state: the button reads `Scarica database dal cloud` / `Download cloud database` instead of generic `Review`.
- Automated ProductPrice pagination/cancel/idempotence tests and baseline-batch test passed.
- Remaining regression risk: fresh live app-auth full bootstrap with the batched baseline writer is still NOT RUN after app-auth became unavailable post-rebuild.
