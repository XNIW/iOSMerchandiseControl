# TASK-123 Fix Log

Timestamp: 2026-05-25T03:22Z.

## iOS Review Gate Persistence
- Problem: after using the existing Options Review flow, the same-account decision was not persisted into the local account binding.
- Fix: `AccountSyncChoiceBindingApplier` now binds the local store to the signed-in account when the user confirms the same-account Review decision.
- Tests: `AccountSyncPolicyTests.testConfirmedAccountDecisionChoiceBindsLocalStoreToSignedInAccount`, `testCancelledAccountDecisionChoiceLeavesBindingUnchanged`.

## iOS Same-Account Baseline Decision
- Problem: a confirmed same-account binding with absent baseline still forced bootstrap/recovery and kept auto-sync effectively gated.
- Fix: `SyncDecisionInputProvider` distinguishes confirmed same-account binding from anonymous local data when baseline is absent.
- Tests: `SyncDecisionEngineTests.testSameAccountBindingDoesNotForceBootstrapWhenBaselineIsAbsent`, `testAnonymousLocalDataStillRequiresBootstrapWhenBaselineIsAbsent`.

## TASK123 Harness Prefix
- Problem: live cross-platform harness rejected `TASK123_*` prefixes inherited from TASK-103/104/112/114/115.
- Fix: iOS XCTest and Android instrumentation harness now accept explicit `TASK123_` run prefixes.

## iOS Incremental Pull Watermark Starvation
- Problem: iOS saw Android sync events, but an unrecoverable old gap page did not advance the owner watermark. The same old page was fetched repeatedly, preventing new Android events from applying within timeout.
- Fix: `SyncEventIncrementalDomainApplyService` saves `watermarkAfter` even when returning a `requiresFullRecovery` gap summary, matching the Android reference behavior and preventing starvation.
- Test: `SyncEventIncrementalDomainApplyServiceTests.testUnrecoverableGapAdvancesWatermarkToAvoidRepeatingSamePage`.

## Android Foreground Auto-Push Debounce
- Problem: Android foreground catalog/history auto-push used a 2.0s debounce per push path, making the serial live matrix much slower than the TASK-123 warm budget.
- Fix: `CatalogAutoSyncCoordinator.DEBOUNCE_MS` and `HistorySessionPushCoordinator.DEBOUNCE_MS` reduced to 500ms.
- Tests: `CatalogAutoSyncCoordinatorTest.123 default catalog auto push debounce stays within warm autosync budget`, `HistorySessionPushCoordinatorTest.114 default history auto push debounce stays within near realtime budget`.

## Android Cleanup Harness
- Problem: Android scoped local cleanup accepted only `TASK114_` prefixes, so TASK-123 cleanup dry-run failed.
- Fix: instrumentation cleanup guard accepts only explicit `TASK114_` or `TASK123_` prefixes ending in `_`; cleanup evidence is emitted through instrumentation status.
- Evidence: `agent-runs/20260525T032055Z-android-cleanup-scoped-prefix-TASK123_-dry-run-p1548.log`.

## Supabase / Policy
- No schema, RLS, grant, RPC or migration changes were made.
- No client service-role key was introduced.
- Cleanup used only existing scoped CLI cleanup after dry-run and only for `TASK123_*`.
