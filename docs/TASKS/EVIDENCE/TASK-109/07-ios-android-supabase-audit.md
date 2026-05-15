# TASK-109 — 07 iOS / Android / Supabase Audit

Date: 2026-05-15  
Scope: static/runtime audit before and during implementation.

## Decisione architetturale finale

iOS already had most sync primitives, but the user-visible lifecycle was too view-scoped and the Review UX treated warnings/sample signals as actionable deltas. The chosen fix keeps the existing app-scoped `SupabaseManualSyncViewModel` / coordinator architecture and tightens ownership:

- `ContentView` / root shell refreshes auth context and schedules foreground checks.
- Options observes the shared ViewModel and only launches explicit manual sync.
- Review is gated by actionable remote/local work, not by warnings, product price samples, or stale summaries.
- History remains a first-class domain through `HistorySessionSyncService` and `shared_sheet_sessions`.

No SQL migration was needed. `sync_events` remains limited to `catalog` / `prices`; History continues to use owner-scoped `shared_sheet_sessions`.

## Android vs iOS

| Area | Android reference | iOS before/finding | iOS final |
|---|---|---|---|
| App lifecycle owner | `MerchandiseControlApplication` owns coordinators and foreground scheduling. | Root foreground check existed but Options still had static auto-start hooks. | Root owns auth/foreground trigger; Options no longer starts auto checks on appear/active. |
| Single-flight | `CatalogSyncStateTracker.tryBegin(owner)` gates active owner. | iOS lifecycle gate existed; duplicate visible ownership risk from Options hooks. | Existing gate retained; Options observes same operation instead of bootstrapping. |
| Options role | Observer/manual trigger. | Options could still schedule foreground semi-auto check. | Observer + explicit `Sync now` only. |
| Root banner | App-level cloud indicator. | Banner could advertise review for warning-only/no-op preview. | Warning-only no-op settles without review banner. Active job banner appears on Inventory before Options. |
| Review/no-op | No review for no-op. | `Sync now` could show Review with `Device already updated`. | No-op/warnings-only returns compact summary, no Review sheet. |
| Cancel | Operation cancel, no nested preview cancel. | Cancel review opened nested confirmation. | Review cancel dismisses directly; mutation confirmations remain only for mutative actions. |
| History | App-scoped repository/VM, Room counts. | History service present; runtime remote dataset empty. | Tests cover push, pull, dirty-skip, owner mismatch, no-op; Options count uses fetchCount. |
| Counts | DAO/count queries, no list materialization. | Options summary needed History count parity. | History sessions count is included and tested. |

## Supabase schema notes

- `shared_sheet_sessions`: owner-scoped RLS (`auth.uid() = owner_user_id`), payload v2, `updated_at`, authenticated DML grants.
- `sync_events`: domain constraint is `catalog` / `prices`; not a History transport.
- Inventory catalog/prices: owner-scoped RLS and indexes exist; product prices have owner/product/type/effective uniqueness.

## Efficiency / parity conclusion

Android remains the functional reference for app-scoped lifecycle. iOS is now aligned for the observed regression without touching Kotlin:

- no extra Options-owned job;
- no stale no-op Review;
- bounded product price preview remains a warning/note, not an actionable Review;
- History is covered by deterministic tests and Options count parity.

Potential Android improvement is not required for TASK-109: Android already has app-scoped lifecycle and observer Options behavior.
