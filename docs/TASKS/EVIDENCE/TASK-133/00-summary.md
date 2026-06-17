# TASK-133 Summary

Verdict: PARTIAL_PASS_NOT_DONE / REVIEW_REQUIRED.

## Cleanup and parity

| source | products active | suppliers active | categories active | product_prices | history active | pending/outbox | TASK user-visible |
|---|---:|---:|---:|---:|---:|---:|---:|
| Supabase | 19695 | 59 | 28 | 41109 | 35 | n/a | 0 |
| iOS simulator | 19695 | 59 | 28 | 41109 | 35 | 0 / 0 | 0 |
| Android emulator | 19695 | 59 | 28 | 41109 | 35 | 0 / 0 | 0 |

Evidence:
- TASK-132C evidence: `../TASK-132C-clean-baseline-20260617-115823/`.
- Performance evidence: `performance-20260617-130313/`.
- Final parity report: `../TASK-132C-clean-baseline-20260617-115823/final-parity-after-task133-cleanup.md`.

## Performance

| scenario | runs | p50_ms | p95_ms | max_ms | result |
|---|---:|---:|---:|---:|---|
| iOS startup no-op | 10 | 754 | 775 | 775 | PASS |
| Android startup no-op | 10 | 1045 | 1103 | 1103 | PASS |
| iOS -> Android propagation | 10 | 1241 | 1314 | 1314 | PASS |
| Android -> iOS propagation | 10 | 462 | 482 | 482 | PASS |

Artifacts:
- `performance-20260617-130313/performance.json`.
- `performance-20260617-130313/performance.csv`.
- `performance-20260617-130313/startup-ios.md`.
- `performance-20260617-130313/startup-android.md`.
- `performance-20260617-130313/ios-to-android.md`.
- `performance-20260617-130313/android-to-ios.md`.

## No-push regression

- iOS final signed-in reopen 95s: PASS, `sync_events` stayed `1823 / max 3035`.
- Android final signed-in reopen 95s: PASS, `sync_events` stayed `1823 / max 3035`.
- Screenshots: `performance-20260617-130313/screenshots/final-ios-options.png`, `performance-20260617-130313/screenshots/final-android-options.png`.

## Cleanup details

- Supabase TASK-132C cleanup applied with backup suffix `20260617_120028`.
- TASK-133 benchmark fixtures cleaned from Supabase and Android/iOS local residue.
- Benchmark `sync_events` id `3036..3065` backed up to `backup_task133_sync_events_20260617_174403` and deleted.
- Final Supabase residue report shows user-visible TASK residue `0` and `sync_events_after_task132_window = 0`.

## Remaining gates

These gates are not promoted to PASS because strict live fixtures were not run:
- Field merge same barcode: Android `productName` + iOS `retailPrice`.
- Field merge same barcode: Android `category` + iOS `purchasePrice`.
- Price append-only cross-device T1/T2.
- Same effectiveAt different price conflict.
- Remote deleted + local edited protected mode.
- Dirty/protected reopen no-push after injected unsafe local fixture.

## Tracking recommendation

Do not mark TASK-132/TASK-133 DONE yet. Move TASK-132 to REVIEW with the completed cleanup/parity/performance evidence and require a focused follow-up or reviewer decision for the strict live merge/conflict fixtures.

