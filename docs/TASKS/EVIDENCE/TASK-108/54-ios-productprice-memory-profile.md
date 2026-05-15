# TASK-108 Evidence 54 - iOS ProductPrice memory profile

Timestamp: 2026-05-14 13:23 -0400  
Scope: ProductPrice memory/performance measurements available in this pass.

## Previous live baseline reused for comparison

From evidence 51 / user context:

- Remote ProductPrice count: `290,955`
- Rows applied/linked: `290,953`
- Rows skipped: `2` tombstoned product references
- Final local ProductPrice: `328,589`
- Baseline runs: `1`
- Baseline records: `20,012`
- Duration: about `25m50s` (`1,550s`)
- Effective live rate: about `187.7 rows/sec` using `290,953 / 1,550`
- UI: scrollable, no crash/freeze observed

From previous performance evidence, RSS during the live full pull was roughly in the `~2.0GB -> ~3.5GB peak` range. That number is pre-patch and should not be used as post-patch proof.

## Post-patch measurements executed

### Targeted XCTest

Command:

```sh
xcodebuild test -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'id=240F400E-5EFA-486A-9137-FFBBE70F604D' -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 -only-testing:iOSMerchandiseControlTests/SupabaseProductPriceApplyServiceTests/testPagedFullPullAppliesLargeProductPriceHistoryWithoutFixedTotalLimit -only-testing:iOSMerchandiseControlTests/SupabaseProductPriceApplyServiceTests/testKeysetPagedFullPullCompletesThreePagesAndPublishesProgress -only-testing:iOSMerchandiseControlTests/SupabaseProductPriceApplyServiceTests/testKeysetPagedFullPullSkipsTombstonedProductPrices
```

Result:

- `3` tests executed
- `0` failures
- Total selected test time after the final lookup-context patch: `133.470s`
- The 30k test inserted `30,000` ProductPrice rows page-by-page, then ran an idempotent second pass over the same `30,000` rows.
- The keyset 2,700-row test completed 3 pages of 900 rows and emitted page progress.
- The tombstone test skipped the tombstoned product row and inserted the valid row.

### iOS app idle RSS

After Debug build install/launch on iPhone 17 Pro iOS 26.5 simulator:

- PID: `60617`
- RSS: `307,440 KB` immediately after launch
- This is an idle launch sample, not a sync peak.

## Requested live checkpoints

| Checkpoint | Post-patch full live measurement |
|---|---|
| 0 | NOT EXECUTED |
| 9,000 | NOT EXECUTED |
| 53,000 | NOT EXECUTED |
| 90,000 | NOT EXECUTED |
| 150,000 | NOT EXECUTED |
| 250,000 | NOT EXECUTED |
| Completion | NOT EXECUTED |

Reason: this pass implemented and tested memory-retention fixes, but did not complete another 25+ minute authenticated iOS live full pull after the patch.

## Verdict

Do not claim measured live speedup yet. Verified facts are:

- The memory-heavy global lookups were removed from the paged apply path.
- The synthetic 30k/idempotence ProductPrice test passes after the change.
- Fresh live post-patch peak RSS/duration remains required before saying "faster" or "optimized" in the strict measured sense.
