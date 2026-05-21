# TASK-112 — Offline cross-platform matrix

Timestamp: 2026-05-20 22:26 -0400  
Agent: Codex / Executor

## What changed

iOS now has a testable automatic reconnect scheduler backed by `NWPathMonitor`:

- offline -> online schedules a single foreground automatic sync intent;
- flapping coalesces into one debounced intent;
- background cancels pending reconnect work;
- reconnect source bypasses stale foreground cooldown while still using run-gates/backoff;
- interrupted mutating runs keep priority over read-only reconnect checks.

This narrows the efficiency/parity gap with Android, whose `CatalogAutoSyncCoordinator`, connectivity callback and WorkManager-backed paths already had debounce/single-flight behavior.

## Automated checks

| Area | Result | Evidence |
|---|---:|---|
| iOS fake reconnect debounce/coalescing | PASS | `AutomaticSyncReconnectSchedulerTests` 3/3 PASS. |
| iOS reconnect reason/cooldown | PASS | `SupabaseManualSyncViewModelTests/testTask112NetworkReconnectBypassesForegroundCooldownWithReconnectReason` PASS. |
| iOS lifecycle priority | PASS | `SupabaseManualSyncLifecycleRunGateTests/testTask112InterruptedMutationHasPriorityOverNetworkReconnectCheck` PASS. |
| Android reconnect/coordinator/unit suite | PASS | `CatalogAutoSyncCoordinatorTest`, `DefaultInventoryRepositoryTest`, `HistorySessionPushCoordinatorTest`, `CatalogSyncViewModelTest`, `MerchandiseControlApplicationTest`: 200 tests, 0 failed with serialized MockK runner. |

## Required offline live scenarios

| Scenario | Result | Reason |
|---|---:|---|
| iOS offline create/edit -> reconnect -> Android receives | BLOCKED | Requires iOS authenticated live session and dual-client read-back. |
| Android offline create/edit -> reconnect -> iOS receives | BLOCKED | Requires iOS authenticated live read/apply. |
| Offline ProductPrice bidirectional | BLOCKED | Requires both clients authenticated. |
| Offline History/session bidirectional | BLOCKED | Requires both clients authenticated. |
| Network flapping during outbox drain | PASS_WITH_NOTES | Debounce/coalescing unit coverage exists; live drain under flapping not executed. |
| App kill/restart with pending | BLOCKED | Not executed end-to-end on both platforms. |
| Dual-offline conflict policy | BLOCKED | Not executed end-to-end on both platforms. |

## Verdict

**BLOCKED** for offline live acceptance. The iOS efficiency gap identified by the user was reduced with a concrete reconnect scheduler and tests, but CA-43…CA-68 still require authenticated cross-platform live/offline evidence before REVIEW.

## Final review+fix rerun update — 2026-05-20 22:26 -0400

- iOS background cancellation was tightened so root foreground/reconnect work marks `requestLifecycleInterruptionForBackground()` before canceling the task.
- Static XCTest now asserts the background lifecycle interruption call remains wired.
- Android unlocked Options smoke confirms the automatic sync status card remains visible without a public manual sync-now CTA.
- Offline live scenarios remain **BLOCKED** because dual-client authenticated iOS/Android read-back still cannot run without iOS app-auth.

## CA-20 app-auth rerun update — 2026-05-20 23:15 -0400

- iOS app-auth is no longer blocked by `sessionMissing`.
- Offline prefix `TASK112_OFFLINE_R20260521T030912Z_`:
  - collision scan PASS;
  - `test06OfflineRetryCatalogPendingNoDuplicate` PASS;
  - evidence: `offline_status=failedBeforeWrite retry_status=completed remote_products=1 no_duplicate=true no_op=true`.
- Residue before cleanup for the offline prefix: suppliers `1`, categories `1`, products `1`, ProductPrice `0`.
- Android offline live write/reconnect remains **PASS_WITH_NOTES/BLOCKED** because this repo does not currently include an Android live offline-write harness equivalent to the iOS test. Android reconnect/drain behavior remains covered by unit/static tests and live auth/pull/write checks.
- Cleanup of the offline prefix was not attempted after the CA-20 prefix cleanup hit RLS `42501`; final cleanup status is therefore **BLOCKED**.

## Final offline closure update — 2026-05-21 00:01 -0400

- iOS offline retry/drain remains PASS for `TASK112_OFFLINE_R20260521T030912Z_`.
- Final live rerun used `TASK112_FINAL_R20260521T033505Z_`; iOS offline retry was already covered and no duplicate/no-op behavior was confirmed.
- Admin/postgres scoped cleanup removed the offline residual row set: suppliers 1, categories 1, products 1, ProductPrice 0.
- Final SQL read-back for `TASK112_OFFLINE_R20260521T030912Z_` returned 0 rows in suppliers/categories/products/ProductPrice.
- Android has no equivalent live offline-write instrumentation harness in this repo; Android offline/reconnect remains PASS_WITH_NOTES via existing unit/static coverage plus final app-auth live pull/write.

Final offline verdict: **PASS_WITH_NOTES**, not blocking DONE.
