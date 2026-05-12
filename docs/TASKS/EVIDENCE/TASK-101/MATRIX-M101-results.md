# M101 Results

| ID | Area | Result | Evidence | Notes |
|---|---|---|---|---|
| M101-01 | Preflight | PASS | `MANIFEST.md` | iOS, Android and Supabase local/live contexts inspected; review reran iOS full XCTest. |
| M101-02 | RLS inventory | PASS | `rls-policy-inventory.md` | Core inventory, price, session and sync tables have RLS enabled; owner policies present where data is tenant-scoped. |
| M101-03 | Grants / roles | PASS_WITH_OPS_NOTE | `grants-audit.md`, `test-build-runtime-report.md`, `supabase-migration-drift-analysis.md` | Client-role EXECUTE on `rls_auto_enable()` fixed and verified. Legacy grants are fail-closed by RLS and migration drift is registry/history drift with live objects present; future repair should be deliberate, not blind. |
| M101-04 | Owner scope | PASS | `owner-scope-matrix.md` | iOS now adds explicit `owner_user_id` filters in read/update/read-back/debug paths and validates create-payload owner IDs in addition to RLS. |
| M101-05 | Auth session | PASS | `auth-session-audit.md`, `ios/simulator-smoke-ios-26.5.txt` | Code path reviewed; no token persistence by app code; app launch smoke passed. Manual OAuth with a real account was not repeated to avoid sensitive data in evidence. |
| M101-06 | service_role | PASS | `secrets-scan-notes.md` | No service-role key requirement in iOS/Android consumer app; iOS rejects server-only keys. |
| M101-07 | Delete/update policy | PASS_WITH_CAVEAT | `live-write-safety-audit.md` | Inventory DELETE intentionally unavailable to `authenticated`; cleanup requires documented operator/admin path. |
| M101-08 | Live write safety | PASS | `live-write-safety-audit.md` | No test data writes/deletes performed; live DDL remediation was scoped, reversible and verified. |
| M101-09 | Logging privacy | PASS | `logging-privacy-audit.md` | iOS diagnostics now redact email, URL and business identifiers; noisy logs gated behind DEBUG; plan-derived sync event identifiers hash raw fingerprints. |
| M101-10 | Retention / cleanup | PASS_POLICY | `cleanup-retention-policy.md` | TASK-101 created no data rows. Policy and admin-only cleanup model are documented; automated retention is a future Ops improvement, not an iOS release blocker. |
| M101-11 | Cross-platform parity | PASS | `android-ios-security-parity.md`, `android/` | Android raw userId log fixed; Android unit tests, lint, debug build and release build all passed with the Android Studio JBR environment. |
| M101-12 | Closure matrix | PASS | `decision-final.md`, `findings-register.md` | Findings routed atomically; TASK-101 criteria met with no BLOCKER/HIGH open. |
