# TASK-121 architecture before/after map

## Before

- Automatic retry ownership leaked through `SyncOrchestrator`, including `retry_after_sync_busy` and post-busy retry sleep.
- `AutomaticSyncRuntimeFacade.swift` was a fake alias to root runtime behavior.
- Root `SyncAutomaticRuntime.swift` still carried behavior instead of an Automatic boundary implementation.
- `Sync/Shared/HistorySessionSyncShared.swift` accepted `HistoryEntry` and performed remote-ID side effects through Shared helper paths.
- TASK-087/TASK-088 root DEBUG smoke service files remained in the app root.
- TASK-121 harness commands and scanners were not fully routed/discoverable/MCP-allowlisted as TASK-121-aware commands.

## After this pass

- `Sync/Automatic/Core/AutomaticSyncRetryPolicy.swift` exists and is used by `AutomaticSyncEngine`.
- `SyncOrchestrator` no longer contains `retry_after_sync_busy` or retry `Task.sleep` scheduling.
- `AutomaticSyncRuntimeFacade.swift` is a concrete facade; the root runtime file is a zero-behavior compatibility marker.
- Shared history payload mapping now uses a pure `HistorySessionLocalPayloadSnapshot`; SwiftData/`HistoryEntry` mutation moved out of `Sync/Shared`.
- TASK-087/TASK-088 root smoke service files were deleted; required TASK-088 seed DTO was retained as data shape only.
- TASK-121 scanner routing, fixtures, MCP allowlist, discovery evidence, and JSON evidence validation are in place.
- Debug/release builds, automatic tests, broad sync tests, manual regression tests, and Options smoke pass through the harness.
- Root sync-related service residues are physically moved out of the app root:
  - Recovery: `InventorySyncService.swift`, `SupabasePullApplyService.swift`, `SupabasePullPreviewModels.swift`, `SupabasePullPreviewService.swift`
  - Manual: `SupabaseProductPricePreviewService.swift`, `SupabaseProductPricePushDryRunService.swift`, `SupabasePushPreflightViewModel.swift`, `SupabaseSyncEventPreviewService.swift`
  - Outbox: `SyncEventOutboxDrainService.swift`, `SyncEventOutboxEnqueueService.swift`

## Root residue resolution pass

Before: 10 root residues.

After: 0 root residues.

Scanner evidence:
- `20260524T182117Z-scan-root-residue-task-TASK-121-strict-p96790`: PASS, reconciliation PASS, `classified_residue_count=0`.
- `20260524T180519Z-scan-sync-inventory-task-TASK-121-strict-p64584`: PASS, regenerated `sync-inventory.json` and `sync-inventory.csv` with moved paths.
- `20260524T180544Z-scan-xcode-membership-task-TASK-121-strict-p67343`: PASS.
- `20260524T180548Z-scan-duplicate-symbols-task-TASK-121-strict-p67804`: PASS.

Ledger:
- `docs/TASKS/EVIDENCE/TASK-121/root-residue-resolution-ledger.md`

Build/test evidence:
- `20260524T180557Z-ios-build-debug-task-TASK-121-p68827`: PASS.
- `20260524T180622Z-ios-build-release-task-TASK-121-p69597`: PASS.
- `20260524T180735Z-ios-test-automatic-architecture-task-TASK-121-p70419`: PASS.
- `20260524T180801Z-ios-test-automatic-domain-task-TASK-121-p71157`: PASS.
- `20260524T180811Z-ios-test-sync-task-TASK-121-p71682`: PASS.
- `20260524T181041Z-ios-test-manual-sync-regression-task-TASK-121-p72598`: PASS.
- `20260524T181548Z-ios-smoke-options-task-TASK-121-p75878`: PASS_WITH_NOTES via accepted XcodeBuildMCP fallback evidence.

No root-residue blocker remains after this pass.
