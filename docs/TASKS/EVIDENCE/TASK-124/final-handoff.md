# TASK-124 Final Handoff

Status: `BLOCKED / BLOCKED_EXTERNAL_LIVE_DEVICE`

## Implemented
- Added TASK-124 canonical scanners with RED/GREEN fixtures and mc-agent routing.
- Split `ProductPriceRemoteSupabaseAdapter` into automatic, preview, manual push, and release composite adapters.
- Split Options remote count reads out of `SyncEventRemoteSupabaseAdapter` into `OptionsRemoteCountSupabaseAdapter`.
- Renamed misleading `inventoryService`/`supabaseInventoryService` transport composition labels where scoped.
- Removed `SupabaseManualSyncAggregatedPushOutboxProducer.swift` and `SyncAutomaticRuntime.swift` compatibility residue after call-site proof.

## PASS Gates
- TASK-124 scanner self-tests and all TASK-124 static scanners PASS.
- iOS build Debug PASS.
- iOS build Release PASS.
- iOS tests: sync PASS, automatic-domain PASS, automatic-architecture PASS, manual-sync-regression PASS.
- Android build/test/offline-tier targeted gates PASS.
- Supabase linked schema/RLS/grants/contract read-only PASS.
- Sensitive/evidence/repo-diff scans PASS.
- Supabase cleanup dry-run and residue-check for `TASK124_` PASS.

## BLOCKED_EXTERNAL Gates
- `supabase status-redacted`: blocked by local Supabase CLI/Docker stack not running.
- Offline/reconnect live matrix: blocked by missing `MC_ANDROID_DEVICE_SERIAL`.
- TASK-123 speed regression live gates: blocked by missing `MC_ANDROID_DEVICE_SERIAL`.
- Options smoke: blocked by macOS Accessibility/JXA permission.

No DONE, REVIEW PASS, production-global, or 100% completion claim is made.
