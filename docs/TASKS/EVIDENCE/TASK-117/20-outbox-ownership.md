# TASK-117 - Outbox Ownership

Date: 2026-05-23 17:48:36 -0400

## Result
Outbox push/drain remains owner-bound and is not routed through the legacy manual VM.

## Evidence
- `SyncAutomaticRuntime.pushPending` calls clean catalog/product price/history/activity providers.
- `SyncActivityRegistrationAdapter` maps manual registration results to clean automatic DTOs at the boundary.
- `SyncOrchestrator` is the only automatic owner for local mutation, realtime signal, reconnect and safety loop triggers.
- `20260523T212324Z-scan-duplicate-sync-owner-task-TASK-117-p55793` PASS
- `20260523T214520Z-ios-test-sync-task-TASK-117-p90749` PASS

