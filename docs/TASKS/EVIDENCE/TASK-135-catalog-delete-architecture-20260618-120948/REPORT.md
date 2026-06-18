# TASK-135 Catalog/Product Delete Architecture Report

Verdict: READY_FOR_USER_ACCEPTANCE / DONE candidate. Do not mark DONE until local review policy allows it.

## Scope

This pass fixed and verified Catalog/Product delete/tombstone parity across iOS, Android, and Supabase after the final delete smoke found the iOS hard-delete gap.

No refactor, no schema migration, no service role, no RLS bypass, no raw DB dump.

## Code Changes

iOS:
- `iOSMerchandiseControl/Sync/Automatic/Catalog/CatalogPushService.swift`
  - handles product `.delete` before `findProduct`
  - uses pending `entityRemoteID` or remote id from logical key
  - sends Supabase tombstone payload with `deleted_at`
  - acknowledges local-only delete without remote call
  - does not recreate hard-deleted Product rows
  - emits `catalog_tombstone` for pure Product tombstone pushes
- `iOSMerchandiseControlTests/Task118AutomaticDomainTests.swift`
  - covers hard-deleted pending Product tombstone and local-only delete ack
- `iOSMerchandiseControlTests/SyncEventLiveRecorderTests.swift`
  - covers `catalog_tombstone` RPC mapping
- `iOSMerchandiseControlTests/SyncCountReconciliationTests.swift`
  - aligns test fixtures with the TASK-135 History visibility contract
- `tools/agent/catalog_delete_state_dump.sh`
  - read-only state dump for iOS SwiftData pending/products, Android Room products/tombstones, and Supabase product/sync_events rows

Android:
- `app/src/main/java/com/example/merchandisecontrolsplitview/data/InventoryRepository.kt`
  - fallback quick-sync/realign drains pending catalog tombstones before active product push
- `app/src/test/java/com/example/merchandisecontrolsplitview/data/DefaultInventoryRepositoryTest.kt`
  - covers fallback tombstone drain without a remaining Product row

## Live Product Delete Smoke

Valid harnesses used repository/XCTest/instrumentation flows, not direct DB seed.

Prefixes:
- iOS: `TASK135_DELETE_PRODUCT_IOS_FIX_20260618T162539Z_`
- Android: `TASK135_DELETE_PRODUCT_ANDROID_FIX_20260618T162703Z_`

Evidence:
- iOS write/delete matrix PASS:
  `agent-runs/20260618T162539Z-task135-ios-write-product-delete-matrix-p72293.md`
- Android received iOS Product tombstone PASS:
  `agent-runs/20260618T162639Z-task135-android-pull-ios-product-delete-matrix-p79057.md`
- Android write/delete matrix PASS:
  `agent-runs/20260618T162703Z-task135-android-write-product-delete-matrix-p82305.md`
- iOS received Android Product tombstone PASS:
  `agent-runs/20260618T162751Z-task135-ios-pull-android-product-delete-matrix-p85344.md`

Supabase tombstone rows observed before cleanup:
- iOS tombstone row: `35bc3604-0c66-4a29-84f6-bba5274ac90e`, `deleted_at=2026-06-18 16:26:23.218+00`
- Android tombstone row: `510114b1-ea64-4e0f-b520-b8aa00fe67e3`, `deleted_at=2026-06-18 16:27:35.022981+00`

State dumps:
- `state/ios-live-after-cross-pull-v3/`
- `state/android-live-after-cross-pull-v3/`
- `state/supabase-timeout-queries/ios-products.json`
- `state/supabase-timeout-queries/android-products.json`

Final screenshots after clean reopen:
- `screenshots/ios-final-post-delete-clean-reopen.png`
- `screenshots/android-final-post-delete-clean-reopen.png`

## Cleanup And Reopen

Cleanup was scoped to the two Product delete prefixes only.

Supabase cleanup/residue PASS:
- iOS prefix dry-run/execute/residue PASS under `docs/TASKS/EVIDENCE/TASK-135/agent-runs/20260618T163546Z*`, `20260618T163558Z*`, `20260618T163609Z*`
- Android prefix dry-run/execute/residue PASS under `docs/TASKS/EVIDENCE/TASK-135/agent-runs/20260618T163618Z*`, `20260618T163628Z*`, `20260618T163638Z*`

Android local cleanup PASS:
- iOS prefix: `20260618T163656Z-android-cleanup-scoped-prefix-TASK135_DELETE_PRODUCT_IOS_FIX_20260618T162539Z_-execute-p12975.md`
- Android prefix final rerun: `20260618T163707Z-android-cleanup-scoped-prefix-TASK135_DELETE_PRODUCT_ANDROID_FIX_20260618T162703Z_-execute-p15420.md`

Clean reopen no false push:
- before: `sync_events count=1869`, `max_id=3121`
- after: `sync_events count=1869`, `max_id=3121`
- evidence: `counts/clean-reopen-sync-events-before.json`, `counts/clean-reopen-sync-events-after.json`

## Final Counts

Latest count artifacts are in `docs/TASKS/EVIDENCE/TASK-135/agent-runs/20260618T163817Z-*sync-counts*`.

- iOS: products active `19704`, suppliers `66`, categories `35`, product_prices active `41131`, History active `39`, History userVisible `35`, pending `0`
- Android: products active `19704`, suppliers `66`, categories `35`, product_prices active `41131`, History active `39`, History userVisible `35`, pending `0`
- Supabase: products active `19704`, suppliers `66`, categories `35`, product_prices active `41131`, History active `39`, History userVisible `35`, pending `0`

Supabase also has 4 tombstoned Product rows and 2 historical ProductPrice rows linked to deleted Products; they are excluded from active parity by design.

History row-level visible parity after Catalog delete cleanup:
- `diffs/history-visible-diff-after-catalog-delete-cleanup.md`
- visible rows iOS/Android/Supabase: `35/35/35`
- `present_on_all=35`
- duplicate remote id `0`
- duplicate fingerprint `0`
- payload/fingerprint mismatches `0`
- visible TASK135 residue `0`

Why History is `39` physical active and `35` visible:
- the 4 hidden active rows are `TASK135_MATRIX_*` technical fixtures
- they are owner-scoped to the linked test owner
- they are not user data and not another user's data
- Options and History UI use the same user-visible predicate, so both show/count `35`

## Build/Test/Check

PASS:
- iOS targeted Catalog delete tests
- iOS targeted History/Options tests: 39 tests, 0 failures
- iOS Debug build
- Android targeted Catalog delete tests
- Android targeted History tests
- Android `assembleDebug`
- Android `lintDebug`
- iOS `git diff --check`
- Android `git diff --check`
- `bash -n` for `catalog_delete_state_dump.sh` and History snapshot scripts
- `python3 -m py_compile tools/agent/history_diff.py`
- evidence hygiene: no raw DB/store dumps, no large raw DB dump, no `.idea`, no secret/client secret/service role key in changed/evidence files

Notes:
- one Android local cleanup attempt was blocked by the live lock because two scoped cleanups were accidentally launched in parallel; the same prefix was rerun serially and PASS.
- screenshot evidence is final post-clean-reopen UI state; row-level before/after truth is carried by harness reports, Supabase queries, SwiftData/Room state dumps, and sync_events before/after counts.
