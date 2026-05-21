# TASK-112 — Final cleanup and DONE closure

Timestamp: 2026-05-21 00:01 -0400  
Agent: Codex / Executor  
Verdict: **DONE** — `Chiusura — FINAL EVIDENCE-BACKED AUTOMATIC SYNC PASS`

## Scope and user override

The user explicitly authorized simulator/device login, live Supabase read/write/read-back, scoped admin/postgres cleanup for synthetic `TASK112_*` / `TASK112_OFFLINE_*` rows, and closing TASK-112 as DONE only if all final gates passed with evidence.

No real data was used. No global cleanup, truncate, auth user deletion, service role in iOS/Android clients, client-side RLS bypass, or unscoped delete was used.

## Cleanup root cause

The app-auth cleanup blocker was:

```text
42501 permission denied for table inventory_product_prices
```

Audit result:

- `inventory_product_prices`, `inventory_products`, `inventory_suppliers`, and `inventory_categories` have RLS enabled.
- `authenticated` has SELECT/INSERT/UPDATE on catalog/ProductPrice tables, but no DELETE grant/policy for hard deletes.
- `shared_sheet_sessions` has an owner-scoped DELETE policy; `sync_events` is select-only.
- This is consistent with the TASK-038-era security posture: client runtime does not need hard delete for catalog/ProductPrice cleanup.
- The app runtime uses owner-scoped insert/update/read, soft-delete/tombstone/reconciliation semantics for catalog flow, and ProductPrice append/dedupe/fail-closed paths. TASK-112 needed hard delete only for synthetic test cleanup.

Decision: **admin/postgres scoped cleanup only**, no migration, no RLS/grant change.

## Prefixes and owner evidence

Initial residual prefixes:

| Prefix | Owner hash | Suppliers | Categories | Products | ProductPrice |
|---|---:|---:|---:|---:|---:|
| `TASK112_CA20_R20260521T030156Z_` | `bf727712f2b9c4c1` | 9 | 9 | 54 | 114 |
| `TASK112_OFFLINE_R20260521T030912Z_` | `bf727712f2b9c4c1` | 1 | 1 | 1 | 0 |

Final rerun prefix:

| Prefix | Owner hash | Suppliers | Categories | Products | ProductPrice |
|---|---:|---:|---:|---:|---:|
| `TASK112_FINAL_R20260521T033505Z_` | `ad3d747e936ccd13` | 10 | 10 | 55 | 114 |

Cleanup order used for each residual set:

1. `inventory_product_prices` joined to TASK112 products.
2. `inventory_products` scoped by TASK112 barcode/product data.
3. `inventory_suppliers` scoped by TASK112 name.
4. `inventory_categories` scoped by TASK112 name.
5. `shared_sheet_sessions` / `sync_events` scoped checks.
6. Final zero-residue read-back.

## Admin cleanup rows deleted

Initial cleanup:

| Table | Rows deleted |
|---|---:|
| `inventory_product_prices` | 114 |
| `inventory_products` | 55 |
| `inventory_suppliers` | 10 |
| `inventory_categories` | 10 |
| `shared_sheet_sessions` | 0 |
| `sync_events` | 0 |

Final prefix cleanup:

| Table | Rows deleted |
|---|---:|
| `inventory_product_prices` | 114 |
| `inventory_products` | 55 |
| `inventory_suppliers` | 10 |
| `inventory_categories` | 10 |
| `shared_sheet_sessions` | 0 |
| `sync_events` | 0 |

Operational notes:

- A temporary Supabase CLI circuit-breaker response occurred after parallel CLI authentication attempts; cleanup was retried serially.
- Two final cleanup SQL attempts failed at parse/type-check time before execution because of incorrect evidence-query columns/types. No delete was executed by those failed statements.
- Successful deletes were serial, scoped by exact prefixes, and followed by read-back.

## Final residue read-back

Final query result:

| Prefix | Suppliers | Categories | Products | ProductPrice |
|---|---:|---:|---:|---:|
| `TASK112_CA20_R20260521T030156Z_` | 0 | 0 | 0 | 0 |
| `TASK112_OFFLINE_R20260521T030912Z_` | 0 | 0 | 0 | 0 |
| `TASK112_FINAL_R20260521T033505Z_` | 0 | 0 | 0 | 0 |
| `TASK112_ANY` | 0 | 0 | 0 | 0 |

The authenticated cleanup harness was not used as the final cleanup mechanism because it intentionally lacks hard-delete permission under the current RLS/grant model. Admin SQL read-back is the closure evidence.

## Final live/sync rerun

Final prefix: `TASK112_FINAL_R20260521T033505Z_`

| Gate | Result | Evidence |
|---|---:|---|
| iOS auth preflight | PASS | `TASK112_IOS_AUTH_PREFLIGHT project_hash=42a5d0119a30 owner_hash=ad3d747e936c provider=google signed_in=true` |
| Android auth preflight | PASS | `adb shell am instrument ... Task103AuthPreflightTest ... OK (1 test)` |
| iOS collision scan | PASS | `collision=free` |
| iOS write/read-back | PASS | `price_inserted=4 no_op=true` |
| Android pull iOS | PASS | `OK (1 test)` |
| Android write/read-back | PASS | `OK (1 test)` |
| iOS pull Android/no-op | PASS | `inserted_catalog=1 inserted_prices=4 no_op=true` |
| Medium ProductPrice | PASS | `products=50 prices=102 price_inserted=102 price_batches=2 export_spotcheck=true duration_s=3.18` |
| Android medium pull | PASS | `OK (1 test)` |
| Conflict/stale/fail-closed | PASS | `catalog_stale=previewStale product_price_conflicts=1 price_ready=0 remote_unchanged=true` |
| iOS offline retry | PASS | `offline_status=failedBeforeWrite retry_status=completed remote_products=1 no_duplicate=true no_op=true` |
| Final prefix cleanup | PASS | rows deleted as above; final residue zero |

CA-20 remains PASS after final rerun.

## Final iOS checks

| Check | Result | Evidence |
|---|---:|---|
| `git diff --check` | PASS | no whitespace errors |
| Debug build | PASS | `** BUILD SUCCEEDED **` |
| Release build | PASS | `** BUILD SUCCEEDED **` |
| TASK-112 lifecycle gate tests | PASS | `SupabaseManualSyncLifecycleRunGateTests`: 7 tests, 0 failures |
| Reconnect/OAuth targeted regression | PASS | `AutomaticSyncReconnectSchedulerTests` + `testTask112NetworkReconnectBypassesForegroundCooldownWithReconnectReason` + `testTask112OAuthCallbackIsForwardedDuringSigningIn`: 5 tests, 0 failures |
| iOS live TASK-112 XCTest | PASS | final live matrix above |
| Options smoke | PASS | XcodeBuildMCP UI hierarchy reached `Options`; screenshot `/var/folders/nf/85_c2pqj60v6q0r7v8ktzkpw0000gn/T/screenshot_optimized_87cf026b-b3f0-4c59-8b4f-00fbbb1239f3.jpg` |
| Exact forbidden CTA scan | PASS | no `Sync now`, `Sincronizza ora`, `Sincronizar ahora`, `立即同步` in production iOS source |
| `plutil -lint` localizations | PASS | EN/IT/ES/ZH strings OK |
| Client secret scan | PASS_WITH_NOTES | production hits only the defensive rejection logic in `SupabaseConfig.swift`; no client secret/service_role embedded |

The earlier unfiltered full XCTest attempt entered unrelated historical/live benchmark suites and was not used as a TASK-112 gate. The TASK-112 lifecycle crash discovered there was fixed with explicit nonisolated deinit on the MainActor lifecycle gate/preflight classes and then verified by targeted tests and Debug/Release builds.

## Final Android checks

| Check | Result | Evidence |
|---|---:|---|
| `git diff --check` | PASS | no whitespace errors |
| `JAVA_TOOL_OPTIONS=-Djdk.attach.allowAttachSelf=true ./gradlew testDebugUnitTest` | PASS | `BUILD SUCCESSFUL`; previous evidence: 458 tests, 0 failures, 2 skipped |
| `./gradlew assembleDebug` | PASS | `BUILD SUCCESSFUL` |
| `./gradlew assembleRelease` | PASS | `BUILD SUCCESSFUL` |
| `./gradlew lintDebug` | PASS | `BUILD SUCCESSFUL` |
| Android app-auth preflight | PASS | `OK (1 test)` |
| Android live pull/write/medium | PASS | final instrumentation rows above |
| Options smoke | PASS | OnePlus `IN2013` UI dump shows `Opzioni` selected; screenshot `/tmp/task112-android-options-smoke.png`; crash buffer empty for this app smoke |
| Exact forbidden CTA scan | PASS | no `Sync now`, `Sincronizza ora`, `Sincronizar ahora`, `立即同步` in production Android source |
| Client secret scan | PASS | no service role/client secret match in production Android source |

## Final Supabase checks

| Check | Result | Evidence |
|---|---:|---|
| Residue check | PASS | all TASK112 prefixes and `TASK112_ANY` return 0 rows in suppliers/categories/products/ProductPrice |
| RLS enabled | PASS | RLS true on catalog/ProductPrice/session/event tables |
| Grants final | PASS | `authenticated` still has SELECT/INSERT/UPDATE on catalog/ProductPrice; no catalog/ProductPrice DELETE grant was added |
| Policies final | PASS | owner SELECT/INSERT/UPDATE policies retained; no DELETE policy added for catalog/ProductPrice |
| Migration status | NOT_APPLIED | no migration needed; no RLS/grant weakening |
| Privacy/security | PASS | no service_role/client secret in mobile clients; admin/postgres used only from backend CLI for scoped cleanup |

## Quality/efficiency review

Reviewed targeted code/evidence for:

- automatic sync entry points iOS/Android;
- single-flight/debounce/coalescing (`AutomaticSyncReconnectScheduler`, Android `CatalogAutoSyncCoordinator`, `SessionCloudSessionFlightOwner`);
- reconnect behavior and auth preflight;
- offline pending/retry iOS;
- ProductPrice paging/keyset/apply/push paths;
- History/session sync surfaces;
- no duplicate live read-back rows for TASK-112 canaries;
- no public Release manual sync CTA;
- RLS/42501 classification as permission/security issue, not cancelled/no-op;
- no sensitive evidence/log values beyond redacted owner/project hashes.

No new P0/P1 blocker was found in the TASK-112 closure surface.

## Residual risks

- Android does not have a dedicated live offline-write harness equivalent to iOS `test06OfflineRetryCatalogPendingNoDuplicate`; Android coverage remains app-auth preflight + live pull/write/medium + existing unit/static reconnect/offline paths.
- Full Dynamic Type/VoiceOver and Instruments/Perfetto profiling were not executed; Options smoke was UI-tree/screenshot based.
- Historical unrelated live/benchmark suites in the full iOS test target still require their own maintenance and were not used as TASK-112 closure gates.

## DONE rationale

TASK-112 can be closed because:

- CA-20 live iOS <-> Android <-> Supabase passed with app-auth clients.
- Initial and final TASK112 cleanup passed through admin/postgres scoped cleanup.
- Final residues for `TASK112_*`, `TASK112_OFFLINE_*`, and `TASK112_FINAL_*` are zero.
- iOS Debug/Release builds and targeted TASK-112 lifecycle/reconnect/live tests passed.
- Android unit/build/lint/device smoke/live instrumentation gates passed.
- Supabase RLS/grants were audited and preserved; no client security was weakened.
- Release/source exact manual sync CTA scans are clean.
- Evidence/tracking are updated with the chosen cleanup strategy and final zero read-back.
