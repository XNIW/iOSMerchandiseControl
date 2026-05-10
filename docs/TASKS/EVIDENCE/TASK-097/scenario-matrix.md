# TASK-097 Scenario Matrix

Status: REVIEW PASS. All MUST scenarios M97-01...10 are PASS.

| Scenario | Verification type | Result | evidence_ref |
|----------|-------------------|--------|--------------|
| M97-01 - Preflight sandbox iOS | STATIC + BUILD + RUNTIME | PASS; branch/config/session/project/owner verified, no TASK-098 file, owner redacted | `manifest.md`, `test-build-summary.md#preflight` |
| M97-02 - Seed controllato TASK097_* | RUNTIME | PASS; seed executed only after config/session/owner/collision scan; owner-scoped synthetic rows only | `remote-readback-notes.md#seed-setup` |
| M97-03 - iOS pull/read-back supplier/category/product in SwiftData | RUNTIME | PASS; Release pull/apply created local supplier/category/products for A/B | `local-readback-notes.md#pull-apply-read-back` |
| M97-04 - ProductPrice pull/read-back current/previous | RUNTIME | PASS; A and B prices read locally with deterministic effectiveAt ordering and `<= 0.005` tolerance | `local-readback-notes.md#productprice-audit` |
| M97-05 - Local edit -> pending -> aggregated push | RUNTIME | PASS; Product B local edit created real pending rows and existing aggregated planner pushed them | `local-readback-notes.md#local-edit-and-pending`, `remote-readback-notes.md#post-push-read-back` |
| M97-06 - Remote read-back after push | RUNTIME | PASS; Product B catalog current prices and ProductPrice rows verified remotely after push | `remote-readback-notes.md#post-push-read-back` |
| M97-07 - Lifecycle retry/cancel smoke | RUNTIME + XCTest | PASS; interrupted, readyToRetry and duplicate active run behaviors verified; no optimistic success | `test-build-summary.md#runtime-smoke` |
| M97-08 - UX Release smoke | STATIC + XCTest | PASS; one primary Release card/action path, confirmation before mutative actions, no automatic modal, copy not technical | `ux-acceptance.md` |
| M97-09 - Anti-scope/privacy finale | STATIC | PASS; no TASK-098 file, no Android/Kotlin diff, no SQL/backend/migration diff, no new BGTask/Timer/polling/Realtime/worker in diff, no secrets in evidence | `anti-scope-checks.md` |
| M97-10 - Evidenze complete e navigabili | REVIEW | PASS; manifest, scenario matrix, test/build, remote/local read-back, UX and anti-scope files created | `manifest.md`, `test-build-summary.md`, `remote-readback-notes.md`, `local-readback-notes.md`, `ux-acceptance.md`, `anti-scope-checks.md` |

## Notes

- Exact proposed `TASK097_*` fixture names were used in the first smoke attempt and therefore collided on the final PASS run. The final PASS dataset used suffix `R1778437271`, documented in the manifest.
- The failed intermediate smoke diagnosis was caused by harness seed stock `0` while Release apply ignores stock by default, yielding a catalog fingerprint mismatch. The final PASS run aligned seed stock with Release semantics (`nil`) and required no production Swift patch.
- Review confirmed every MUST scenario has an explicit result, evidence reference and no TBD rows. TASK-097 is closed DONE / Chiusura - REVIEW PASS.
