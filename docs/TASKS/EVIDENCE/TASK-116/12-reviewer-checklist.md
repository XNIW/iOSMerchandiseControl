# Reviewer Checklist

| CA | Status | Evidence / note |
|---|---|---|
| CA-116-01 | PASS | no-legacy-runtime-path static/live PASS |
| CA-116-02 | PASS | adapter no longer exposes automatic foreground methods; manual facade remains |
| CA-116-03 | PASS | `SyncEventIncrementalPullService` dispatches to `SyncEventIncrementalDomainApplyService`; legacy apply pass-through absent; hardened gate PASS `p89574` |
| CA-116-04 | PASS | physical `CatalogIncrementalApplyService.swift` added and dispatcher uses it; iOS build/tests PASS `p90096`/`p91525` |
| CA-116-05 | PASS | physical `ProductPriceIncrementalApplyService.swift` added and dispatcher uses it; iOS build/tests PASS `p90096`/`p91525` |
| CA-116-06 | PASS | physical `HistoryIncrementalApplyService.swift` added and dispatcher uses it; iOS build/tests PASS `p90096`/`p91525` |
| CA-116-07 | PASS | automatic push path no longer VM-owned; iOS sync tests PASS |
| CA-116-08 | PASS | `WatermarkStore` retained; no legacy pull pass-through |
| CA-116-09 | PASS_WITH_NOTES | performance gate PASS; Options still observes manual facade for manual card |
| CA-116-10 | PASS | no-full-pull-normal-path PASS |
| CA-116-11 | PASS | no duplicate legacy automatic owner by static gate |
| CA-116-12 | BLOCKED | strict-live fixtures/device readiness unavailable; rerun `p73594` |
| CA-116-13 | BLOCKED | physical iPhone auth/store acceptance not ready; reruns `p72498`, `p72994` |
| CA-116-14 | BLOCKED | Android serial `8ac48ff0` unavailable; rerun `p71553` |
| CA-116-15 | BLOCKED | Android serial `8ac48ff0` unavailable; rerun `p72022` |
| CA-116-16 | BLOCKED | physical/runtime parity blocked by device/auth |
| CA-116-17 | PASS_WITH_NOTES | build/test/lint smoke PASS; UI/manual import/export/scanner not exhaustively live-smoked |
| CA-116-18 | PASS | iOS/Android build/test/lint/scans pass where run |
| CA-116-19 | PASS | cleanup/residue scoped prefixes PASS/0 |
| CA-116-20 | PASS | severe-fix sensitive/evidence scans PASS `p75575`, `p75576` |

## Verdict for review
Eligible for ACTIVE / REVIEW, not DONE. Remaining blockers are external live devices/fixtures; domain apply now has physical service files and gate coverage after severe FIX.
