# Outbox / Pending Migration

## Implemented
- Automatic push execution moved from `SupabaseManualSyncViewModel` to `SyncAutomaticRuntime`.
- Catalog, ProductPrice and History pending push providers are invoked directly by the automatic runtime.
- Activity registration/outbox drain is invoked through `SupabaseManualSyncReleaseActivityRegistrationAdapter`, not through the VM.
- `LocalOutboxStore` remains owner-bound and `PendingChangeCoalescer` remains unchanged.

## Safety
- No pending migration mutation was performed.
- Account fixture prepare/cleanup dry-run commands were added for future strict-live owner-bound validation.
- Cross-account strict live validation remains BLOCKED until device/account fixtures are available.

## Evidence
- iOS sync tests PASS: `agent-runs/20260523T162955Z-ios-test-sync-task-TASK-116-p21120.md`
- Account fixture prepare dry-run PASS: `agent-runs/20260523T161528Z-account-fixture-prepare-task-TASK-116-prefix-TASK116_ACCOUNT_-dry-run-p3825.md`
