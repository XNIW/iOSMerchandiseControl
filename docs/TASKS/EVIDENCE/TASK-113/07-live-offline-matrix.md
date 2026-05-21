# Live And Offline Matrix

Status: PASS_WITH_NOTES.

Safety PASS:
- `live sync-matrix` without `MC_ALLOW_LIVE=1`: exit 4 refused.
- `live offline-matrix` without `MC_ALLOW_LIVE=1`: exit 4 refused.
- `android offline-write --tier L3` without live gate: exit 4 refused.

Offline tiers:
- L1 JVM deterministic: PASS.
- L2 instrumented Room/fake network: PASS in professional review.
- L3 live offline read-back: NOT_RUN / live-gated.

No live write, cleanup execute, global cleanup, DB reset or auth user delete was performed in REVIEW-FIX.

Professional review update — 2026-05-21:
- PASS: Android L2 write/drain pair with prefix `TASK113_OFFLINE_L2_`.
- REFUSED/PASS: Android L3 and `live offline-matrix` without `MC_ALLOW_LIVE=1` return exit 4 and do not claim live offline PASS.
- NOT_RUN: L3 remote read-back + cleanup scoped, because live gate was intentionally not enabled.
