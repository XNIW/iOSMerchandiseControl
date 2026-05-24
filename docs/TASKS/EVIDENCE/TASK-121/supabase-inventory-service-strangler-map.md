# TASK-121 SupabaseInventoryService strangler map

Generated during the final anti-false-positive review/fix pass on 2026-05-24.

## Status

- Local root file eliminated: `iOSMerchandiseControl/SupabaseInventoryService.swift` no longer exists in local `git ls-files` after the anti-false-positive fix.
- Canonical GitHub blocker: GitHub `main` at the checked SHA still contains that root path because no push was allowed.
- Remote transport host: `iOSMerchandiseControl/Sync/Remote/SupabaseTransportClient.swift`.
- Compatibility type name retained: `SupabaseInventoryService` remains the internal actor name to avoid broad API churn, but its file and ownership moved to `Sync/Remote`.
- Automatic adapters added:
  - `iOSMerchandiseControl/Sync/Remote/CatalogRemoteSupabaseAdapter.swift`
  - `iOSMerchandiseControl/Sync/Remote/ProductPriceRemoteSupabaseAdapter.swift`
  - `iOSMerchandiseControl/Sync/Remote/HistorySessionRemoteSupabaseAdapter.swift`
  - `iOSMerchandiseControl/Sync/Remote/SyncEventRemoteSupabaseAdapter.swift`

## Dependency changes

- `AutomaticSyncRuntimeFactory` now wraps the remote transport in Remote adapters before passing dependencies into automatic services.
- `ContentView`, manual history sync, and manual incremental pull use Remote adapters instead of passing the concrete transport directly into automatic/recovery protocols.
- Existing manual-only protocols remain in `Sync/Manual`; concrete Supabase transport is physically under `Sync/Remote`.

## Debug-only task hooks

TASK087/TASK088 support remains guarded by `#if DEBUG` in the Remote transport host. No TASK087/TASK088 root service files remain.

## Evidence

- Read-only schema contract: `20260524T190040Z-supabase-contract-sync-schema-task-TASK-121-read-only-p43917`
- Root residue PASS: `20260524T184456Z-scan-root-residue-task-TASK-121-strict-p21697`
- Debug build PASS: `20260524T184725Z-ios-build-debug-task-TASK-121-p26069`
- Release build PASS: `20260524T184825Z-ios-build-release-task-TASK-121-p26986`
