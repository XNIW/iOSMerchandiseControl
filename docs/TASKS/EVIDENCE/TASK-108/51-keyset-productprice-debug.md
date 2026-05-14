# TASK-108 Evidence 51 — ProductPrice Keyset Debug / Final iOS App-Auth Run

Timestamp: 2026-05-14 12:34 -0400.

Status: **PASS for the observed ProductPrice keyset/apply bug**. Not a global TASK-108 DONE verdict.

## Original live failure

The prior app-auth run showed:
- remote `ProductPrice` total about `290,955`;
- `pageSize = 900`;
- keyset mode entered;
- UI returned to idle without completion or explicit error;
- local counts and baseline stayed unchanged or incomplete;
- `baseline_runs = 0`, `baseline_records = 0`.

This was treated as a client flow/lifecycle/error-propagation bug, not as a generic blocker.

## Root Causes Isolated

1. **Failure presentation was overwritten** after ProductPrice apply failure.
   - `applyProductPricesIfNeeded` could fail, but later presentation updates could show a no-change/idle-like state.
   - Fix: terminal failed/cancelled apply presentations are preserved and mapped to `CloudSyncProgressState.failed` / cancelled state.

2. **Postgres timestamp decode was too narrow**.
   - Live row with `effective_at` formatted like `yyyy-MM-dd HH:mm:ss+00` failed canonicalization.
   - Fix: `ProductPriceEffectiveAtCanonicalizer` now accepts Postgres space-separated timezone and fractional timestamp variants.

3. **Tombstoned remote products were classified as unmapped product failures**.
   - Live row `76A6D2C6-redacted` referenced product `A72BC4F4-redacted`, present remotely as deleted/tombstoned.
   - Fix: full ProductPrice apply prefetches deleted remote product IDs and explicitly skips price rows for tombstoned products.
   - Non-tombstoned missing products still fail explicitly as `unmappedProducts`.

4. **Sample plan was too conservative for full stream validation**.
   - A sampled preview can report `.unmappedProducts` before the full stream has enough data to classify tombstones.
   - Fix: `applyPagedFullPull` allows the full stream to validate `.unmappedProducts`; true active missing bridges still fail during row apply.

5. **Baseline UI state was stale after manual apply**.
   - Baseline was written, but parent Options state was not refreshed after manual sync apply.
   - Fix: `SupabaseManualSyncReleaseCard` notifies `OptionsView` to refresh the baseline summary after local apply.

## Instrumentation Added

Privacy-safe logs/events were added around:
- apply plan creation;
- keyset start and remote total;
- page request/return with page index and redacted first/last IDs;
- row invalid/skip reasons;
- page save/no-op;
- cancellation and exit;
- baseline commit/repair;
- terminal apply failure/cancellation.

No raw token/JWT/email/full UUID was added.

## Live Rerun Result

Simulator: iPhone 15 Pro Max, app-auth signed in with masked account.

Remote count:
- `inventory_product_prices`: `290,955`.

Run:
- Public Options flow: `Sincronizza ora` → review → `Aggiorna questo dispositivo`.
- UI progress passed `135,900`, `181,800`, `262,800`, `274,500`, then completed.
- Scroll remained responsive during apply.
- No crash.
- No idle-without-completion/error observed.

Final local DB:
- Products: `19,886`.
- Suppliers: `79`.
- Categories: `47`.
- ProductPrice total local rows: `328,589`.
- ProductPrice rows with remote ID: `290,953`.
- Baseline runs: `1`.
- Baseline records: `20,012`.
- Baseline records by kind: `19,886 product`, `79 supplier`, `47 productCategory`.

Two remote ProductPrice rows were skipped because their products are tombstoned. This is expected and explicit after the fix.

## Timing / Performance

Approximate live duration from apply confirmation to idle completion: about `25m 50s`.

Observed local ProductPrice count samples:

| Time | Local ProductPrice count | RSS | CPU |
| --- | ---: | ---: | ---: |
| 12:12:44 | 186,802 | 2.03 GB | 100% |
| 12:16:54 | 220,067 | 2.58 GB | 100% |
| 12:21:01 | 252,439 | 2.83 GB | 100% |
| 12:26:45 | 289,065 | 3.26 GB | 118% |
| 12:33:37 | 328,589 / 290,953 remote IDs | 3.53 GB | 101% |
| 12:33:52 | baseline committed | 3.25 GB | 59% |
| 12:34:07 | idle after completion | 3.25 GB | 0% |

Performance note:
- This is stable on the simulator but still memory-heavy because large SwiftData writes use the app ModelContext path.
- No crash occurred, but a future optimization should move full ProductPrice bootstrap to a private/bounded SwiftData context or chunked import strategy.

## UI Verification

Final Options state after rebuild/refresh:
- `Database locale aggiornato`.
- `Ultimo pull completo: 14 mag 2026, 12:33`.
- ProductPrice count visible: `328,589`.
- Baseline no longer reads as absent.

## Automated Tests

PASS after fix:
- `SupabaseProductPriceApplyServiceTests` full class.
- `SupabaseProductPriceApplyServiceTests.testKeysetPagedFullPullCompletesThreePagesAndPublishesProgress`.
- `SupabaseProductPriceApplyServiceTests.testPagedFullPullFailsWhenRemoteEndsBeforeReportedCount`.
- `SupabaseProductPriceApplyServiceTests.testKeysetPagedFullPullSkipsTombstonedProductPrices`.
- `SupabaseManualSyncViewModelTests.testTask108ProductPriceApplyCancellationShowsCancelledInsteadOfIdle`.
- `SupabaseManualSyncViewModelTests.testTask108ProductPriceApplyFailureShowsFailedInsteadOfIdle`.
- `SupabaseCatalogBaselineWriterReaderTests` full class.

Final command result: PASS, no failures.

## Verdict

ProductPrice keyset/full apply bug: **FIXED and live-verified**.

TASK-108 global status remains **ACTIVE / REVIEW, NON DONE** because Android signed-in rerun, full cross-platform E2E, controlled incremental pull/push, Generated live and History/session live acceptance are not all closed in this pass.
