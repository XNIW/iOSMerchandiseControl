# TASK-121 SupabaseInventoryService strangler map

Generated during the final anti-false-positive review/fix pass on 2026-05-24.

## Status

- Local root file eliminated: `iOSMerchandiseControl/SupabaseInventoryService.swift` no longer exists in local `git ls-files` after the anti-false-positive fix.
- Canonical GitHub aligned: GitHub `main` no longer contains that root path after the authorized push; raw status is `404`.
- Remote transport host: `iOSMerchandiseControl/Sync/Remote/SupabaseTransportClient.swift`.
- Transport type renamed: the internal actor is now `SupabaseTransportClient`; production code no longer uses the legacy `SupabaseInventoryService` symbol.
- Automatic adapters added:
  - `iOSMerchandiseControl/Sync/Remote/CatalogRemoteSupabaseAdapter.swift`
  - `iOSMerchandiseControl/Sync/Remote/ProductPriceRemoteSupabaseAdapter.swift`
  - `iOSMerchandiseControl/Sync/Remote/HistorySessionRemoteSupabaseAdapter.swift`
  - `iOSMerchandiseControl/Sync/Remote/SyncEventRemoteSupabaseAdapter.swift`

## Dependency changes

- `AutomaticSyncRuntimeFactory` now wraps the remote transport in Remote adapters before passing dependencies into automatic services.
- `ContentView`, manual history sync, and manual incremental pull use Remote adapters instead of passing the concrete transport directly into automatic/recovery protocols.
- Existing manual-only protocols remain in `Sync/Manual`; concrete Supabase transport is physically and semantically under `Sync/Remote`.
- Manual/Recovery/Presentation call sites use protocol-backed dependencies or Remote adapters; concrete `SupabaseTransportClient` is allowed only in `Sync/Remote` and `Sync/Automatic/Composition`.

## Debug-only task hooks

TASK087/TASK088 support remains guarded by `#if DEBUG` in the Remote transport host. No TASK087/TASK088 root service files remain.

## Evidence

- Read-only schema contract: `20260524T193832Z-supabase-contract-sync-schema-task-TASK-121-read-only-p45438`
- Root residue PASS: `20260524T194147Z-scan-root-residue-task-TASK-121-strict-p65460`
- Debug build PASS: `20260524T193224Z-ios-build-debug-task-TASK-121-p31097`
- Release build PASS: `20260524T193330Z-ios-build-release-task-TASK-121-p41091`
