# TASK-104 Evidence Summary

Run ID: `TASK104_PASS2_20260512_214804_`  
Execution pass: `PASS 2 / REALISTIC-SHOP COMPLETION`  
Final task status after review: `DONE / Chiusura — REVIEW PASS FINAL / PASS_WITH_NOTES`  
Final verdict for TASK-104 only: `PASS_WITH_NOTES`

## Scope Actually Executed

- Real shop data was not used. The user explicitly authorized privacy-safe realistic synthetic data for PASS 2; this run is therefore **realistic shop acceptance**, not **real user data acceptance**.
- iOS physical device authenticated live Supabase acceptance passed: auth preflight, collision scan, iOS write/read-back, 50-row synthetic Excel import/export, ProductPrice current/previous, conflict/stale guard, offline/retry, residue scan.
- Android physical device authenticated live acceptance passed after UI Google sign-in: auth preflight, pull iOS sentinel, write Android sentinel, pull medium import.
- Bidirectional single-writer flow passed:
  - iOS writer -> Supabase read-back -> Android reader.
  - Android writer -> Supabase read-back -> iOS reader.
- Large synthetic performance/import/export/ProductPrice validation passed on simulator: 6,000 products, 240 suppliers, 160 categories, 24,000 ProductPrice rows.
- Cleanup decision: synthetic Supabase rows are intentionally retained as scoped review evidence under the run prefix; residue scan found 10 suppliers, 10 categories, 55 products, 114 prices, 0 duplicate active barcodes.
- No service role was used in either client. No RLS bypass was used. No TASK-105 file was opened.

## Key Evidence

| Area | Evidence |
|------|----------|
| Consent/privacy | User authorized synthetic realistic dataset and scoped Supabase writes; evidence redacted. |
| iOS auth/session | Auth preflight PASS; project and owner recorded only as hashes. |
| Android auth/session | First preflight correctly failed signed-out; after UI sign-in, preflight PASS with same project/owner hashes. |
| Small Excel | 50-row synthetic workbook imported/pushed/read back; Android pulled the resulting dataset. |
| Large Excel | 6,000-product synthetic workbook exported, re-read, imported into SwiftData, and ProductPrice current/previous audited. |
| ProductPrice | Live small and synthetic large current/previous purchase+retail PASS. |
| Round-trip | iOS->Supabase->Android PASS; Android->Supabase->iOS PASS. |
| Offline/retry | Failed-before-write path, retry, no duplicate, and no-op post-check PASS. |
| Export/share | Synthetic export/re-read PASS; manual share sheet not operator-confirmed. |
| Privacy | Final scan completed; no real Excel/export/screenshot committed. |

## CA-104 Ledger

| CA | State | Evidence |
|----|-------|----------|
| CA-104-01 | PASS | User explicitly authorized PASS 2 with synthetic realistic data and scoped Supabase test writes. |
| CA-104-02 | PASS_WITH_NOTES | Rollback defined as scoped retention/cleanup for `TASK104_PASS2_*`; rows retained intentionally for review. |
| CA-104-03 | PASS | Privacy-first evidence, hash-only owner/project, no real data artifacts. |
| CA-104-04 | PASS | Physical iOS device build/test/auth/live flow passed. |
| CA-104-05 | PASS | Physical Android device build/install/auth/live instrumentation passed. |
| CA-104-06 | PASS | iOS and Android authenticated to the same redacted project/owner hash. |
| CA-104-07 | PASS | Synthetic small import: 50 rows, live iOS push/read-back, Android pull. |
| CA-104-08 | PASS_WITH_NOTES | Synthetic large import/export: 6,000 products and 24,000 prices; not real shop data and not live Supabase large push. |
| CA-104-09 | PASS_WITH_NOTES | Import analysis/PreGenerate-equivalent core path passed; no operator file-picker UI run. |
| CA-104-10 | PASS_WITH_NOTES | Generated/edit/save equivalent exercised through local catalog + push services; no operator UI edit run. |
| CA-104-11 | PASS_WITH_NOTES | History/save contract covered by harness and previous UI evidence; no new operator History UI run. |
| CA-104-12 | PASS_WITH_NOTES | Manual fallback path accepted as fallback by PASS2 scope; scanner hardware camera not tested. |
| CA-104-13 | PASS_WITH_NOTES | iOS product/price edit exercised via model/service write path; not by manual Database UI tap sequence. |
| CA-104-14 | PASS | ProductPrice current/previous verified live and at large synthetic scale. |
| CA-104-15 | PASS | iOS writer -> Supabase read-back -> Android pull/read passed. |
| CA-104-16 | PASS | Android writer -> Supabase read-back -> iOS pull/read passed. |
| CA-104-17 | PASS_WITH_NOTES | Synthetic export/re-read passed; manual share destination not operator-confirmed. |
| CA-104-18 | PASS | Offline/retry pending path passed with failed-before-write, retry, no duplicate, no-op. |
| CA-104-19 | PASS | UX friction log updated with PASS2 notes and residual follow-ups. |
| CA-104-20 | PASS_WITH_NOTES | Cleanup/retention decision documented; scoped rows intentionally retained for review. |
| CA-104-21 | PASS | Large import/export/ProductPrice timings were sustainable in the automated benchmark. |
| CA-104-22 | PASS_WITH_NOTES | User authorized execution; final in-person operator acceptance was unavailable. |
| CA-104-23 | PASS | Build/run traceability recorded with redacted device/session details. |
| CA-104-24 | PASS | Decision log updated for PASS2. |
| CA-104-25 | PASS | Follow-up routing updated; TASK-105 not opened. |
| CA-104-26 | PASS | Owner/RLS sanity passed through authenticated client sessions; no service role/bypass. |
| CA-104-27 | PASS_WITH_NOTES | Scanner verdict separated: hardware not tested; manual fallback only. |
| CA-104-28 | PASS | Evidence templates/files populated with actual PASS2 results. |
| CA-104-29 | PASS_WITH_NOTES | Execution override documented; planning gate bypass remains explicit. |
| CA-104-30 | PASS | Pause/resume state reconstructible from run prefix, tests, and residue scan. |
| CA-104-31 | PASS | Risk register updated. |
| CA-104-32 | PASS | UX follow-up routing updated. |
| CA-104-33 | PASS | Synthetic SENTINEL-A…E baseline/post-check recorded. |
| CA-104-34 | PASS | Conflict/stale guard passed: stale preview and ProductPrice conflict fail-closed. |
| CA-104-35 | PASS_WITH_NOTES | File provider readiness reviewed; no real provider import selected. |
| CA-104-36 | PASS | Single-writer sequence followed for both directions. |
| CA-104-37 | PASS | Temporal sequence documented: pre-read, mutate, push, read-back, other-client pull, post-check. |
| CA-104-38 | PASS_WITH_NOTES | Temporary Excel exports deleted; scoped Supabase rows retained for review. |
| CA-104-39 | PASS_WITH_NOTES | Operational copy reviewed from UI smoke/static evidence; no live operator language confirmation. |

## Final Review Result

Review closed as `REVIEW PASS FINAL / PASS_WITH_NOTES` for **TASK-104 realistic shop acceptance**. Notes are real and bounded: no real shop data, no scanner hardware PASS, no final in-person operator acceptance, manual share destination not confirmed, scoped synthetic rows retained for review, Android broad JVM suite not green due ByteBuddy/attach and not counted as PASS. This is not a real user data acceptance verdict and not a global production-ready/no-notes/100% claim. TASK-105 was not opened.
