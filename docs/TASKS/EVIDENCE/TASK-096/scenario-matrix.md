# TASK-096 Scenario Matrix

Status: READY FOR REVIEW. All MUST scenarios are PASS.

| Scenario | Verification | Evidence target | Outcome |
|----------|--------------|-----------------|---------|
| M96-01 — Foreground check read-only senza mutazioni | XCTest + static source review | `SupabaseManualSyncViewModelTests.testTask091ForegroundPreviewRemainsReadOnlyAndSkipsMutativeDryRunPhases`; `SupabaseManualSyncReleaseUITests`; root/card review | PASS |
| M96-02 — Review/apply confermato con piano non stale | XCTest | `testTask091PreparedReviewDoesNotMutateBeforeConfirmation`; `testTask078FullApplicablePreviewEnablesUpdateDeviceAndAppliesLocally`; stale/owner invalidation tests | PASS |
| M96-03 — Pending locale -> push aggregato confermato | XCTest | `LocalPendingChangeAccumulatorTests` 12/0; `SupabaseManualSyncLocalPendingSnapshotProviderTests` 13/0; `LocalPendingAggregatedPushPlannerTests` 11/0; ViewModel push tests | PASS |
| M96-04 — Push/ProductPrice con remote write incerto | XCTest + static source review | `testTask095UnverifiedRemoteWriteDoesNotBecomeCompletedVerified`; `testTask095CancelDuringPushKeepsRemoteWriteInterrupted`; Release ProductPrice adapter read-back/verified-success review | PASS |
| M96-05 — Mutazione interrotta durante lifecycle | XCTest | `SupabaseManualSyncLifecycleRunGateTests` 6/0; ViewModel lifecycle interruption tests; Release UI no automatic modal/copy guard | PASS |
| M96-06 — Preflight auth/owner/rete fallisce | XCTest | `testTask095PreflightBlocksUnsafeMutativeRetryBeforeWrite`; `testTask095PreflightBlocksRetryWhenAuthOwnerNetworkOrContextAreUnsafe`; auth/session tests | PASS |
| M96-07 — Drain attivita manuale dove previsto | XCTest | ViewModel TASK-081 tests; `SupabaseManualSyncReleaseActivityRegistrationAdapterTests` 4/0; outbox regression suites | PASS |
| M96-08 — UX non invasiva durante flussi attivi | XCTest + static source review | `SupabaseManualSyncReleaseUITests` 24/0; `ContentView.swift` busy gating; `OptionsView.swift` user-initiated review/confirmation flow | PASS |
| M96-09 — Anti-scope finale | Static checks | app source grep clean; no TASK-097 file; no Android/Kotlin diff; no SQL/backend/migration diff; evidence privacy scan clean | PASS |

## Optional Runtime Smoke

Simulator/Supabase live smoke was NOT RUN. It is NICE/follow-up for TASK-096 because XCTest/fake and static checks cover all MUST scenarios without using live store data or secrets.
