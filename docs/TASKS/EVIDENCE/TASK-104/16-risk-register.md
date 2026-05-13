# Risk Register

Status: `PASS`

| ID | Risk | Severity | PASS 1 Status | Decision |
|----|------|----------|----------------|----------|
| R104-01 | Real data leaks into evidence/git | P0 | Mitigated in this run by not opening/copying real files and using redacted markdown. | Continue final scan before handoff. |
| R104-02 | Owner/RLS mismatch | P0 | Partially checked by metadata; live owner/session not verified. | Superseded by PASS2 authenticated iOS/Android same owner hash. |
| R104-03 | Large import blocks shop workflow | P1/P0 | Synthetic benchmark evidence only. | Run small-first, then large only with operator consent. |
| R104-04 | Duplicates or ProductPrice mismatch | P0/P1 | Tests pass; no real sentinels. | Superseded by PASS2 synthetic sentinel read-back; still blocks only real-user-data claims. |
| R104-05 | Scanner hardware not usable | P1 | Not tested. | Require separate scanner/fallback verdict. |
| R104-06 | Export/share wrong or retained unsafely | P1 | Synthetic tests pass; no real export. | Require real export retention decision. |
| R104-07 | Cleanup/rollback ambiguous | P0 | No writes performed. | PASS2 retention selected; future cleanup must be prefix-scoped. |
| R104-08 | User cannot interpret sync/import/export state | P1 | No operator notes. | Capture during real acceptance. |
| R104-09 | Long session causes mistakes | P1 | Execution paused safely with no real mutation. | Use pause/resume template next run. |
| R104-10 | Baseline sentinels missing/mismatched | P0/P1 | No sentinels selected. | Superseded by PASS2 synthetic SENTINEL-A...E; real sentinels still required for real-user-data claims. |
| R104-11 | File provider exposes path or fragile flow | P1 | No real provider used. | Record only redacted provider metadata next run. |
## PASS 2 Risk Update

| Risk | Status | Mitigation |
|------|--------|------------|
| Real shop data exposure | Mitigated | Synthetic data only; no real files/screenshot committed. |
| Wrong owner/RLS | Mitigated | Same redacted project/owner hash on iOS and Android; no service_role. |
| Silent overwrite | Mitigated | Single-writer sequencing and conflict/stale fail-closed test passed. |
| Duplicate ProductPrice | Mitigated | Duplicate/no-op and current/previous audits passed. |
| Android signed out | Mitigated | Initial gate blocked writes; UI sign-in then preflight PASS. |
| Scanner hardware unknown | Residual note | Route as operator/manual hardware follow-up. |
| Android JVM unit attach failure | Residual engineering note | Instrumented live tests passed; investigate ByteBuddy attach separately. |
| Scoped Supabase residue | Accepted note | Retained for review with aggregate counts and prefix-only scope. |
