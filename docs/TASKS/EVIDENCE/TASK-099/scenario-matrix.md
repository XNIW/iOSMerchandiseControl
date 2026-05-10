# TASK-099 Scenario Matrix

| Scenario / CA | TASK-099 evidence | Result |
|---------------|-------------------|--------|
| CA-T099-01 catalog conflict policy | No new catalog merge path was introduced. Existing TASK-082 deterministic blocking/skip policy remains covered by full XCTest; TASK-099 only changes state prioritization around sync summaries. | PASS / not directly modified |
| CA-T099-02 ProductPrice conflict/dedupe | Unique conflict during manual ProductPrice push now performs exact read-back. Exact match is treated as idempotent success; mismatch fails closed. Covered by `SupabaseProductPriceManualPushServiceTests`. | PASS |
| CA-T099-03 baseline stale | Sync plan precedence now keeps stale baseline above generic failed/review states, but below auth and permission/RLS blockers. Covered by `SupabaseSyncPlanContractTests`. | PASS |
| CA-T099-04 network/auth/RLS taxonomy | Remote preview distinguishes auth (`sessionMissing`, config/auth roots), permission/RLS, network, schema and unexpected failures. UI summary maps auth to sign-in and permission/RLS to cloud check. Covered by remote preview and ViewModel tests. | PASS |
| CA-T099-05 manual retry | Permission/RLS uses `Controlla cloud` / `Check cloud`; generic recoverable failures keep retry/recheck behavior. No automatic retry loop was introduced. Covered by ViewModel tests and anti-scope scan. | PASS |
| CA-T099-06 idempotent replay | ProductPrice duplicate replay with same logical remote row becomes success only when read-back exactly matches the snapshot fingerprint. Covered by ProductPrice manual push tests. | PASS |
| CA-T099-07 partial failure / surviving state | Mismatched read-back after unique conflict rethrows the original failure; pending/local state is not acknowledged silently. Existing fail-closed apply/push paths remain covered by full XCTest. | PASS |
| CA-T099-08 no new dependency | No package/project dependency changes. | PASS |
| CA-T099-09 regressions TASK-091...098 | Targeted sync/ProductPrice/Release tests and full XCTest passed. | PASS |
| CA-T099-10 privacy-safe evidence | Evidence files in this directory contain commands/results only; no full account identifiers, tokens, remote payloads, or secrets. | PASS |
| CA-T099-11 UX conflict/recovery | Concurrent states are prioritized as auth > permission/RLS > stale > generic failures/review; permission/RLS gets one primary cloud-check CTA instead of sign-in by default. Covered by sync plan and ViewModel tests. | PASS |
| CA-T099-12 accessibility/state | Existing SwiftUI presentation components were reused; icon choice for permission root uses existing presentation state path and localized labels/copy. No new icon-only control was introduced. | PASS |
| CA-T099-13 stable repeated failure | Permission/RLS and generic failures settle into recoverable/check states without background retries or alert loops; pending state remains visible through existing Release card/review flow. | PASS |
