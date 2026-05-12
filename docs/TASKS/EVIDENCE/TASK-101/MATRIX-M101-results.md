# M101 Results

| ID | Area | Result | Evidence | Notes |
|---|---|---|---|---|
| M101-01 | Preflight | PASS | `MANIFEST.md` | iOS, Android and Supabase local/live contexts inspected; review reran iOS full XCTest. |
| M101-02 | RLS inventory | PASS | `rls-policy-inventory.md` | Core inventory, price, session and sync tables have RLS enabled; owner policies present where data is tenant-scoped. |
| M101-03 | Grants / roles | PARTIAL | `grants-audit.md`, `test-build-runtime-report.md` | Client-role EXECUTE on `rls_auto_enable()` fixed. Legacy table grants and migration drift remain; linked lint was not reproducible in review due missing/invalid DB password environment. |
| M101-04 | Owner scope | PASS | `owner-scope-matrix.md` | iOS now adds explicit `owner_user_id` filters in read/update/read-back/debug paths and validates create-payload owner IDs in addition to RLS. |
| M101-05 | Auth session | PASS_STATIC | `auth-session-audit.md` | Code path reviewed; no token persistence by app code; no manual login UI run in this execution. |
| M101-06 | service_role | PASS | `secrets-scan-notes.md` | No service-role key requirement in iOS/Android consumer app; iOS rejects server-only keys. |
| M101-07 | Delete/update policy | PASS_WITH_CAVEAT | `live-write-safety-audit.md` | Inventory DELETE intentionally unavailable to `authenticated`; cleanup requires documented operator/admin path. |
| M101-08 | Live write safety | PASS | `live-write-safety-audit.md` | No test data writes/deletes performed; live DDL remediation was scoped, reversible and verified. |
| M101-09 | Logging privacy | PASS | `logging-privacy-audit.md` | iOS diagnostics now redact email, URL and business identifiers; noisy logs gated behind DEBUG; plan-derived sync event identifiers hash raw fingerprints. |
| M101-10 | Retention / cleanup | PARTIAL | `cleanup-retention-policy.md` | Policy documented; no automated retention/cleanup job created in TASK-101. |
| M101-11 | Cross-platform parity | PARTIAL_STATIC_ONLY | `android-ios-security-parity.md` | Android static parity checked; Android raw userId log remains open and no Android build/test was run. |
| M101-12 | Closure matrix | PASS | `decision-final.md`, `findings-register.md` | Findings routed atomically; global result is PARTIAL, not DONE. |
