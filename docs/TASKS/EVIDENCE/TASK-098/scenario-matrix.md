# TASK-098 Scenario Matrix

| ID | Scenario | Type | Result | evidence_ref |
|----|----------|------|--------|--------------|
| M98-01 | Preflight cross-platform | STATIC/LIVE | PASS | `manifest.md` ledger `preflight`; `test-build-summary.md` iOS/Android preflight; same project hash `42a5d0119a30`, owner hash redacted, iOS simulator and Android emulator available. |
| M98-02 | Collision scan `TASK098_*` before first write | LIVE | PASS | `manifest.md` ledger `collision_scan`; `remote-readback-notes.md` Preflight / Collision Scan; initial read-only scan found prefix free before mutation. |
| M98-03 | Android creates/updates product A + ProductPrice on Supabase | LIVE | PASS | `manifest.md` ledger `android_write_a`; `remote-readback-notes.md` A Android-First; `local-readback-android.md`; Android instrumentation `test02AndroidWriteAAndRemoteReadBack` PASS. |
| M98-04 | iOS pull/apply reads Android product A and ProductPrice | LIVE | PASS | `manifest.md` ledger `ios_pull_apply_a`/`ios_local_readback_a`; `local-readback-ios.md`; iOS `test02PullApplyAndroidProductAAndLocalReadBack` PASS with `inserted_catalog=1`, `inserted_prices=4`. |
| M98-05 | iOS creates/modifies product B + ProductPrice via Release flow | LIVE | PASS | `manifest.md` ledger `ios_write_b`; `remote-readback-notes.md` B iOS-First; `local-readback-ios.md`; iOS `test03IOSWriteProductBUsingReleaseServices` PASS. |
| M98-06 | Android pull/read-back reads iOS product B and ProductPrice | LIVE | PASS | `manifest.md` ledger `android_pull_readback_b`; `local-readback-android.md`; Android `test03AndroidPullReadBackB` PASS with scoped bootstrap `pulled_products=1`, `pulled_prices=4`. |
| M98-07 | ProductPrice current/previous parity | LIVE/MANUAL | PASS | `cross-platform-parity.md`; `remote-readback-notes.md`; `local-readback-ios.md`; `local-readback-android.md`; barcode/product + type + effectiveAt match with tolerance `<= 0.005`. |
| M98-08 | Owner/RLS/write sandbox | STATIC/LIVE | PASS | `manifest.md` ledger; `remote-readback-notes.md` Privacy; `anti-scope-checks.md`; normal authenticated clients only, no service role/admin token, SQL, backend, migration, or RLS bypass. |
| M98-09 | UX smoke minimo | MANUAL | PASS | `ux-acceptance.md`; `test-build-summary.md` Android preflight; Google account picker restored, no automatic modal mutation, sync status/logging observable and non-invasive. |
| M98-10 | Anti-scope/privacy final | STATIC | PASS | `anti-scope-checks.md`; `test-build-summary.md`; no TASK-099 file, destructive cleanup, secrets, SQL/backend/migration, or broad refactor. |

## PASS Cross-Platform Status

TASK-098 is `DONE / Chiusura — REVIEW PASS`.
