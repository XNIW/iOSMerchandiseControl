# Reviewer Checklist

| CA | Status | Evidence / note |
|---|---|---|
| CA-116-01 | PASS | no-legacy-runtime-path static/live PASS |
| CA-116-02 | PASS | adapter no longer exposes automatic foreground methods; manual facade remains |
| CA-116-03 | PARTIAL | `SyncEventIncrementalPullService` no longer passes through legacy service; deeper file split pending review |
| CA-116-04 | PARTIAL | catalog behavior retained in domain apply engine; separate service file split pending review |
| CA-116-05 | PARTIAL | price behavior retained in domain apply engine; separate service file split pending review |
| CA-116-06 | PARTIAL | history behavior retained in domain apply engine; separate service file split pending review |
| CA-116-07 | PASS | automatic push path no longer VM-owned; iOS sync tests PASS |
| CA-116-08 | PASS | `WatermarkStore` retained; no legacy pull pass-through |
| CA-116-09 | PASS_WITH_NOTES | performance gate PASS; Options still observes manual facade for manual card |
| CA-116-10 | PASS | no-full-pull-normal-path PASS |
| CA-116-11 | PASS | no duplicate legacy automatic owner by static gate |
| CA-116-12 | BLOCKED | strict-live fixtures unavailable/device-dependent |
| CA-116-13 | BLOCKED | physical iPhone auth/store acceptance not ready |
| CA-116-14 | BLOCKED | Android device unavailable |
| CA-116-15 | BLOCKED | Android device unavailable |
| CA-116-16 | BLOCKED | physical/runtime parity blocked by device/auth |
| CA-116-17 | PASS_WITH_NOTES | build/test/lint smoke PASS; UI/manual import/export/scanner not exhaustively live-smoked |
| CA-116-18 | PASS | iOS/Android build/test/lint/scans pass where run |
| CA-116-19 | PASS | cleanup/residue scoped prefixes PASS/0 |
| CA-116-20 | PASS | sensitive `p52100` and evidence `p47131` scans PASS |

## Verdict for review
Eligible for ACTIVE / REVIEW, not DONE. Remaining blockers are external live devices/fixtures plus reviewer decision on whether the domain apply file split is sufficient for TASK-116 review or needs FIX before DONE.
