# Reviewer Checklist

| CA | Status | Evidence / note |
|---|---|---|
| CA-116-01 | PASS | final-cleanup no-legacy-runtime-path static/live PASS `p31795`/`p34394`; `SyncAutomaticRuntime.swift` no longer depends on `SupabaseManualSync*Providing` names |
| CA-116-02 | PASS | adapter no longer exposes automatic foreground methods; manual facade remains |
| CA-116-03 | PASS | `SyncEventIncrementalPullService` dispatches to `SyncEventIncrementalDomainApplyService`; legacy apply pass-through absent; hardened gate PASS `p89574` |
| CA-116-04 | PASS | physical `CatalogIncrementalApplyService.swift` added and dispatcher uses it; iOS build/tests PASS `p90096`/`p91525` |
| CA-116-05 | PASS | physical `ProductPriceIncrementalApplyService.swift` added and dispatcher uses it; iOS build/tests PASS `p54844`/`p55368`/`p53802`; canonical sync suite now also runs existing ProductPrice apply tests |
| CA-116-06 | PASS | physical `HistoryIncrementalApplyService.swift` added and dispatcher uses it; iOS build/tests PASS `p54844`/`p55368`/`p53802`; canonical sync suite now also runs existing HistorySession tests |
| CA-116-07 | PASS | automatic push path no longer VM-owned; iOS sync tests PASS |
| CA-116-08 | PASS | `WatermarkStore` retained; no legacy pull pass-through |
| CA-116-09 | PASS | performance gate PASS `p58179`; Options remote count refresh now uses 60s fresh snapshot reuse + in-flight guard; regression test PASS `p53802`; explicit manual card remains separate from automatic runtime |
| CA-116-10 | PASS | no-full-pull-normal-path PASS after serial rerun `p35191` |
| CA-116-11 | PASS | no duplicate legacy automatic owner by static gate |
| CA-116-12 | BLOCKED | strict-live fixtures/device/sign-in readiness unavailable; latest retry `p64142` |
| CA-116-13 | BLOCKED | physical iPhone auth/store acceptance not ready; latest retries `p63133`/`p63640` |
| CA-116-14 | BLOCKED | Android serial `8ac48ff0` unavailable; latest retry `p62188` |
| CA-116-15 | BLOCKED | Android serial `8ac48ff0` unavailable; latest retry `p62658` |
| CA-116-16 | BLOCKED | physical/runtime parity blocked by device/auth/store; latest retry `p60350` |
| CA-116-17 | PASS_WITH_NOTES | build/test/lint smoke PASS; missing exhaustive live/manual smoke for Excel import, export/share XLSX, Database CRUD, supplier/category CRUD, History UI, scanner/barcode, Options UI and IT/EN/ES/ZH localization traversal |
| CA-116-18 | PASS | iOS build/test and Supabase read-only gates PASS on review rerun `p54844`/`p55368`/`p53802`/`p58880`/`p59316`/`p59833`; Android not retouched in this review |
| CA-116-19 | PASS | cleanup/residue scoped prefixes PASS/0 on review rerun `p73466`/`p74012`/`p74579`/`p75097`/`p75631`/`p76166` |
| CA-116-20 | PASS | severe-fix sensitive/evidence scans PASS `p75575`, `p75576` |

## Verdict for review
Eligible for ACTIVE / REVIEW, not DONE. Remaining blockers are external live devices/fixtures; automatic provider naming is cleaned up, domain apply has physical service files, Options refresh throttling has a direct regression test, and the final cleanup gate coverage prevents a return to `ManualSync`-named automatic runtime providers.
