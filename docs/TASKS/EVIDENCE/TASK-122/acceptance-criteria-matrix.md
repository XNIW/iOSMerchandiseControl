# TASK-122 Acceptance Criteria Matrix

- CA-122-01..04: PASS via task docs, master plan, evidence metadata and P0 reports.
- CA-122-05..10: PASS via sync inventory, call-site/protocol/method maps, Supabase read-only map and Android parity ledger.
- CA-122-11..31: PASS via transport thin, adapter delegation, domain ownership, boundary, xcode membership and dead-code scanners.
- CA-122-32..34: PASS via source-format, sensitive/evidence scans and report JSON validation.
- CA-122-35..40: PASS via Debug/Release build, automatic architecture/domain tests, broad sync tests and manual sync regression (`20260525T005428Z`, `20260525T005439Z`, `20260525T005550Z`, `20260525T005611Z`, `20260525T005619Z`, `20260525T005858Z`).
- CA-122-41..44: PASS under final broad sync/ProductPrice/history/catalog/sync_events test coverage (`20260525T005619Z-ios-test-sync-task-TASK-122-p4660`).
- CA-122-45..49: PASS_WITH_NOTES/BLOCKED_EXTERNAL for live Options/account/device/cross-platform; local Supabase status/schema/RLS/grants PASS (`20260525T005918Z`, `20260525T005920Z`, `20260525T005927Z`, `20260525T005929Z`); no Supabase writes/schema/service_role/bypass performed.
- CA-122-50..52: PASS for architecture map and REVIEW handoff; DONE remains forbidden.
- CA-122-53..60: PASS_WITH_NOTES for local canonical override; scanner discovery, fixtures, report metadata and redaction gates PASS.
- CA-122-76..85: Architecture efficiency PASS; Runtime efficiency PASS_WITH_NOTES via `performance-baseline` (`20260525T010013Z`); Production readiness BLOCKED_EXTERNAL for live/offline/cross-platform; 100% user claim NOT_ELIGIBLE pending external acceptance and explicit user approval.
