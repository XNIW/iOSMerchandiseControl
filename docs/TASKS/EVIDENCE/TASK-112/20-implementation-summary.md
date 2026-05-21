# TASK-112 — Implementation summary

Timestamp: 2026-05-20 20:47 -0400  
Agent: CURSOR / Executor  
Status: partial implementation, not DONE

## Scope actually changed

### iOS — `/Users/minxiang/Desktop/iOSMerchandiseControl`

- `OptionsView.swift`
  - Replaced the signed-in public manual sync card in Options with `SupabaseAutomaticSyncStatusCard`.
  - The new Release-visible card is status-only: automatic sync status, last valid baseline sync, pending count, specific signed-out / running / stale / pending copy.
  - Kept the legacy manual sync surface behind `#if DEBUG` as developer diagnostics only.
  - Kept `CloudSyncProgressInlineView` Release-visible because the new status card uses it for non-command progress feedback.
- `ContentView.swift`
  - Root foreground banner now suppresses public data-sync manual actions in Release UI and only exposes remediation-style action copy where appropriate.
- `Localizable.strings` EN/IT/ES/ZH
  - Added automatic sync status card copy.
  - Replaced public "Sync now / Sincronizza ora / Sincronizar ahora / 立即同步" user-facing copy with automatic-update wording.
- `SupabaseManualSyncViewModelTests.swift`
  - Updated one obsolete assertion that expected "Sincronizza ora" after the new automatic-sync copy contract.

### Android — `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView`

- `OptionsScreen.kt`
  - Removed the public `onCatalogRefresh` CTA path from Options.
  - Removed `CatalogCloudActionBlock`; cloud status is now read-only status/reconciliation messaging.
- `NavGraph.kt`
  - Removed the Options-level wiring to `catalogSyncViewModel.refreshCatalog()`.
- `strings.xml` EN/IT/ES/ZH/default
  - Replaced public sync command strings with automatic-sync status/reconciliation wording.
  - Added status/reconciliation strings for the cloud card.

### Supabase — `/Users/minxiang/Desktop/MerchandiseControlSupabase`

- No SQL migration applied.
- No live data created, modified, deleted, or cleaned up.
- Reason: local Supabase status was blocked by unavailable Docker daemon, and no verified authenticated live test/dev DB session was available in this execution. Applying a migration without verified target environment would violate the task safety constraints.

## Architecture impact

- Public Options UX is no longer a command center for manual data sync in Release source.
- Existing automatic mechanisms remain the underlying implementation:
  - iOS still relies on existing foreground/semi-automatic/manual coordinator internals and DEBUG-only diagnostics.
  - Android still relies on existing `CatalogAutoSyncCoordinator`, WorkManager/connectivity/realtime paths, and repository sync internals.
- A new full cross-domain offline-first orchestrator/outbox implementation was not completed in this execution. The audit identified that this is still a gap for CA-43…CA-68 and live CA-20.

## Deviations from requested end-to-end scope

- The requested full automatic offline-first sync across all domains was not fully implemented.
- The Release CTA removal/status-card portion was implemented and verified statically/build-wise.
- Live Supabase cross-platform scenarios and database read-back were not executed.
- TASK-112 must remain ACTIVE / BLOCKED, not DONE.
