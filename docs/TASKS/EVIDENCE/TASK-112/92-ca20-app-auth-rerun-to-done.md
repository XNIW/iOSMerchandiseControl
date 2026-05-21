# TASK-112 — CA-20 app-auth rerun toward DONE

Timestamp: 2026-05-20 23:15 -0400  
Agent: Codex / Executor  
Verdict: **BLOCKED** — CA-20 PASS, cleanup scoped BLOCKED by RLS/grants.

## Starting State

- TASK-112 started this rerun as **ACTIVE / BLOCKED**.
- Previous blocker: iOS live app-auth `sessionMissing`.
- User explicitly authorized simulator/device use, manual OAuth/login, scoped `TASK112_*` / `TASK112_OFFLINE_*` data, scoped cleanup, evidence/tracking updates, and DONE only if all gates truly pass.
- No service_role, no RLS bypass, no global cleanup, no real data deletion.

## iOS App-Auth Diagnosis

Observed cause:

- The app UI session existed on simulator `iPhone 15 Pro Max` (`459C668B-7CE8-443B-BAB3-7D3D5FFC9143`), but previous live XCTest was executed on a different/cloned test runtime and saw no auth storage.
- `SupabaseClientProvider` uses `KeychainLocalStorage` and DEBUG simulator fallback storage; the selected live runner must use the same simulator/container storage.
- `Info.plist` URL scheme matches `com.niwcyber.iosmerchandisecontrol`.
- `iOSMerchandiseControlApp.onOpenURL` forwards app URLs to `SupabaseAuthViewModel.handleOpenURL`.
- Earlier micro-fix already forwards callback while `.signingIn`.

Applied harness fix:

- `iOSMerchandiseControl.xcscheme`: `iOSMerchandiseControlTests` set non-parallelizable so live app-auth tests do not run in a clone without the app session.
- `SupabaseConfigSecurityTests`: TASK-112 iOS auth preflight gate added.
- `Task103CrossPlatformAcceptanceTests`: TASK-112 live prefix/gate support added.

## Login/Restore Evidence

- Cold-launch path: simulator was shutdown; `build_run_sim` booted and launched without resetting the container.
- UI restore PASS: Options showed `Cloud account connected`, signed in as redacted `x***@gmail.com`, `Automatic sync active`, pending local changes `0`.
- Screenshot: `/var/folders/nf/85_c2pqj60v6q0r7v8ktzkpw0000gn/T/screenshot_optimized_b08e863a-fd00-43a8-a1f5-623b9eff2624.jpg`.
- XCTest auth preflight PASS:
  - `SupabaseConfigSecurityTests/testTask103IOSAuthPreflightWhenEnabled`
  - env `TASK112_IOS_AUTH_PREFLIGHT=1`
  - log: `TASK112_IOS_AUTH_PREFLIGHT project_hash=42a5d0119a30 owner_hash=ad3d747e936c provider=google signed_in=true`

## Android App-Auth Diagnosis

Observed cause:

- `connectedDebugAndroidTest` installs app/test APK and then removes the app package at the end of the Gradle run, which erased the manual login before the next CA-20 step.
- Fix for live execution: install app + androidTest APK once, then run tests with `adb shell am instrument` so the app package/session remains present across steps.

Evidence:

- User completed Android login manually after persistent install.
- Android auth preflight PASS via `am instrument`:
  - `Task103AuthPreflightTest`
  - arg `task112AuthPreflight=true`
  - result `OK (1 test)`.
- Final Android UI smoke screenshot: `/private/tmp/task112_android_final_options.png`.
- Final Android UI text included `Catalogo cloud sincronizzato`; no public sync-now CTA observed.

## CA-20 Live Prefix

Prefix: `TASK112_CA20_R20260521T030156Z_`

| Step | Command/test | Result | Evidence |
|---|---|---:|---|
| iOS collision scan | `Task103CrossPlatformAcceptanceTests/test01PreflightAndCollisionScanReadOnly` | PASS | `TASK112_IOS_COLLISION ... collision=free` |
| iOS write/read-back | `test02IOSWriteSmokeAndRemoteReadBack` | PASS | `price_inserted=4 no_op=true` |
| Android pull iOS | `Task103CrossPlatformAcceptanceTest#test02AndroidPullIOSSmokeAndLocalReadBack` via `am instrument` | PASS | `OK (1 test)` |
| Android write/read-back | `Task103CrossPlatformAcceptanceTest#test03AndroidWriteSmokeAndRemoteReadBack` via `am instrument` | PASS | `OK (1 test)` |
| iOS pull Android/no-op | `test03IOSPullApplyAndroidSmokeAndNoOp` | PASS | `inserted_catalog=1 inserted_prices=4 no_op=true` |
| Medium ProductPrice | `test04MediumImportExportPushAndReadBack` | PASS | `products=50 prices=102 price_inserted=102 price_batches=2 export_spotcheck=true` |
| Android medium pull | `Task103CrossPlatformAcceptanceTest#test04AndroidPullMediumReadBack` via `am instrument` | PASS | `OK (1 test)` |
| Conflict/stale/fail-closed | `test05ConflictStaleRecoveryAndProductPriceFailClosed` | PASS | `previewStale`, `product_price_conflicts=1`, `remote_unchanged=true` |
| Residue before cleanup | `test07Task104Pass2ResidueScanReadOnly` | PASS | suppliers `9`, categories `9`, products `54`, prices `114`, duplicate active barcodes `0` |

## Offline Prefix

Prefix: `TASK112_OFFLINE_R20260521T030912Z_`

| Step | Command/test | Result | Evidence |
|---|---|---:|---|
| Collision scan | `test01PreflightAndCollisionScanReadOnly` | PASS | collision-free |
| iOS offline retry/drain | `test06OfflineRetryCatalogPendingNoDuplicate` | PASS | `offline_status=failedBeforeWrite retry_status=completed remote_products=1 no_duplicate=true no_op=true` |
| Residue before cleanup | `test07Task104Pass2ResidueScanReadOnly` | PASS | suppliers `1`, categories `1`, products `1`, prices `0`, duplicate active barcodes `0` |

Android offline live write was not executed because no equivalent Android live offline harness exists in the repo. Android reconnect/drain/offline behavior remains covered by existing unit/static tests plus live app-auth/pull/write checks.

## Cleanup Attempt

Cleanup test:

- `Task103CrossPlatformAcceptanceTests/test08Task112ScopedCleanupWhenEnabled`
- env `TASK112_LIVE_ACCEPTANCE=1`
- env `TASK112_RUN_PREFIX=TASK112_CA20_R20260521T030156Z_`
- env `TASK112_SCOPED_CLEANUP=1`

Result: **BLOCKED**

Error:

```text
PostgrestError(detail: nil, hint: nil, code: Optional("42501"), message: "permission denied for table inventory_product_prices")
```

Reason:

- Existing Supabase contract evidence already notes authenticated role does not have hard DELETE on `inventory_product_prices` / catalog hard-delete paths.
- This is consistent with TASK-038-era policy and cannot be bypassed under TASK-112 rules.

Data left live:

- `TASK112_CA20_R20260521T030156Z_`: suppliers `9`, categories `9`, products `54`, ProductPrice `114`.
- `TASK112_OFFLINE_R20260521T030912Z_`: suppliers `1`, categories `1`, products `1`, ProductPrice `0`.

No service_role/admin cleanup was run. No global cleanup was run.

## Commands/Checks

- `git diff --check` in iOS repo: PASS.
- `git diff --check` in Android repo: PASS.
- iOS Debug build via XcodeBuildMCP `build_run_sim`: PASS.
- Android `:app:installDebug :app:installDebugAndroidTest`: PASS.
- Android live instrumentation uses persistent package, not `connectedDebugAndroidTest`, to preserve manual app-auth session.

## Verdict Rationale

TASK-112 cannot be marked DONE because cleanup scoped is a critical gate and currently fails with app-auth due RLS/grants. CA-20 is no longer blocked by iOS `sessionMissing`; the remaining blocker is backend policy/cleanup authorization.

Required next decision:

- Approve scoped admin/postgres cleanup for only the two TASK-112 prefixes with before/after evidence; or
- Approve a reviewed live migration/RLS/grant change to allow owner-scoped authenticated cleanup, with backup/rollback evidence.

## Final cleanup and closure update — 2026-05-21 00:01 -0400

The first path was executed after explicit user authorization: scoped admin/postgres cleanup only.

Decision:

- No migration.
- No RLS/grant/policy change.
- No service role/client secret in iOS or Android.
- No unfiltered delete/truncate/global reset.

Cleanup and final rerun:

- Initial prefixes cleaned: ProductPrice 114, products 55, suppliers 10, categories 10.
- Final prefix `TASK112_FINAL_R20260521T033505Z_` rerun PASS across iOS/Android/Supabase.
- Final prefix cleaned: ProductPrice 114, products 55, suppliers 10, categories 10.
- Final SQL read-back: `TASK112_CA20_R20260521T030156Z_`, `TASK112_OFFLINE_R20260521T030912Z_`, `TASK112_FINAL_R20260521T033505Z_`, and `TASK112_ANY` all 0 rows.

Final gates:

- CA-20 PASS.
- Live/offline matrix PASS/PASS_WITH_NOTES with documented Android offline harness limitation.
- iOS Debug/Release build PASS.
- Android unit/build/lint/device smoke PASS.
- Exact public manual sync CTA scan PASS on iOS and Android.
- Supabase RLS/grants final check PASS with security posture preserved.

Canonical final evidence: `93-final-cleanup-done-closure.md`.

Final verdict: **DONE / Chiusura — FINAL EVIDENCE-BACKED AUTOMATIC SYNC PASS**.
