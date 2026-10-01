# R-I06 History timestamp — independent bounded review

**Verdict: APPROVED. P0/P1/P2/P3: 0/0/0/0.**

Reviewed TASK-144 R-I06 planning after the Master Plan, the three changed files, their recovery/test context and the official result bundles. No source changes, build, test execution, device operation, auth audit or Git mutation were performed by this reviewer.

## Source identity

All 326 current app/test/UI file hashes match the frozen manifest. The manifest includes every tracked and nonignored untracked file in those three roots. Its independently recomputed compact sorted mapping fingerprint is `41eb3ec1d98d8091bea980690263a68b901f5a392c56f7a9b4b2b55b6ef55006`. Exactly the three authorized R-I06 files differ from approved R-I05 `0fa8c144b61cc0fccc72218b0368735b0196ae75dc12f6900dc5f52fda6580eb`:

- `iOSMerchandiseControl/Sync/Automatic/Recovery/ShopSyncRecoveryContract.swift`: `6f30aa68594f09e5ab00c4a03c8b82ae5562466135fb78a21ab0714faff95ab0`.
- `iOSMerchandiseControlTests/AtomicGenerationRecoverySnapshotPullServiceTests.swift`: `8d2089062988d3982b4d22c0082be5335f62a870526d76d6e22ba981e0521549`.
- `iOSMerchandiseControlTests/ShopSyncRecoveryContractTests.swift`: `711f293d2c411c91b51c9c90737434c9981606ddfecb86a1e19c1c357fdee96d`.

All four approved auth file hashes remain unchanged:

- `iOSMerchandiseControl/SupabaseAuthService.swift`: `2f37c30835cb6cb0a80579e9856e13fb2efa1f3a6efe5999e890b0a8faabf5b1`.
- `iOSMerchandiseControl/SupabaseAuthViewModel.swift`: `6f13de8ae1c05b2dbc3f9c6cdd9cad8e865051dc2ade96629f8f0c80922528d7`.
- `iOSMerchandiseControl/SupabaseClientProvider.swift`: `482e0ed79bf37e74b3e9c67d4227963e1c20d62780ee77b0c115a826717b1ae3`.
- `iOSMerchandiseControlTests/SupabaseAuthLifecycleTests.swift`: `f1eeb4c951ddeab2f571931cd1732b4ebe3d76f1d954336fadfabc478f348aca`.

## Contract and regression assessment

The new helper applies only to active History business timestamps. It first preserves the existing legacy validator, then admits precisely 24 ASCII bytes in `YYYY-MM-DDTHH:mm:ss.SSSZ`. The full match, byte length and ASCII pattern reject trailing newline, whitespace, alternate precision, offsets, Unicode digits and lowercase separators. Explicit calendar validation enforces year 0001–9999, Gregorian leap-year rules, valid day/month, hour 00–23 and minute/second 00–59. The helper returns the incoming string unchanged, so the History ledger version line retains exact digest bytes.

The only changed production call site is the active History suffix. Price effective/created timestamps still call the existing legacy helper; updated/deleted timestamps still call the unchanged UTC6 helper. Scope checks, tombstone behavior, payload digest requirements, chain digest, DTO/model and outbound/fingerprint behavior are unchanged. The patch matches the supplied planned backend/Android grammar; deployed cross-platform behavior is outside this three-file review.

The positive test uses the actual AtomicGenerationRecoverySnapshotPullService, its remote adapter, generation repository and SwiftData store with synthetic transport. The checkpoint helper hashes the raw wire timestamp independently of the new validator. It proves completed journal, activated manifest, exact raw NDJSON timestamp and fresh repository/controller reopen with matching remote ID and Date epoch `1783266011.305`, independently checked with UTC calendar arithmetic. The negative test constructs a checkpoint for normalized seconds while supplying the ISO millisecond row; it expects `checkpointChanged`, no activation, the identical prior container, preserved recovery journal and no persisted History in the old store.

## Official evidence readback

Fresh `xcrun xcresulttool get test-results summary` and `tests` reads match the saved exports semantically:

- Red: 0 PASS / 1 FAIL / 0 SKIP; actual recovery reports `nonCanonicalTimestamp`.
- Targeted: 57 unique cases, 57 PASS / 0 FAIL / 0 SKIP / 0 expected failures; 32 actual recovery cases and 25 contract cases.
- All five new R-I06 cases pass, with existing scope, digest, journal and adjacent recovery regressions retained. Negative grammar/calendar coverage includes 25 variants plus nil.

## Approval boundary

This approval is for frozen R-I06 source and targeted official results. Final canonical Release/full/analyze, signed candidate, exact-SHA CI/normal integration and authenticated live convergence require their own evidence. It does not claim a fractional outbound wire roundtrip, backend deployment, real-account recovery or a new auth approval. The detailed receipt is `ios-ri06-timestamp-review-receipt.json`.
