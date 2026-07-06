# TASK-135 History Architecture Audit

Timestamp: 2026-06-17 21:06 -0400

## Scope Read

- iOS tracking: `docs/MASTER-PLAN.md`, `docs/TASKS/TASK-135-task132d-immediate-drift-sync-unblocker.md`
- Protocol: `docs/CODEX-EXECUTION-PROTOCOL.md`
- iOS code: `HistoryEntry`, `HistoryView`, `HistorySessionSyncShared`, `HistorySessionSyncService`, `HistoryIncrementalApplyService`, `SyncEventIncrementalDomainApplyService`, `HistorySessionRemoteSupabaseAdapter`, `OptionsSyncSummaryProvider`, `SyncCountReconciliation`, `OptionsRemoteCountSupabaseAdapter`, `LocalPendingChange`
- Android code: NOT AVAILABLE in this workspace. `adb` is also unavailable (`zsh:1: command not found: adb`).
- Supabase local CLI: BLOCKED. `supabase status` fails because local container `supabase_db_iOSMerchandiseControl` is missing.

## Current Source Of Truth

- Remote source of truth for shared History sessions: `public.shared_sheet_sessions`.
- iOS local source: SwiftData `HistoryEntry`.
- Incremental propagation source: `sync_events` with domain `history` and `history_session_ids`.

## Idempotent Key / Remote Ref

- Existing primary idempotent key: `remote_id`.
- iOS stores remote ref in `HistoryEntry.remoteID`.
- Before this fix, both full pull and incremental apply matched only by `remoteID` or `uid`.
- This fix adds a logical payload fingerprint that excludes `remoteID`, so a local-only row with the same logical session can be linked instead of duplicated.

## Dirty / Outbox

- Dirty state: `remotePayloadFingerprint == nil || localChangeRevision > lastSyncedLocalRevision`.
- Pending queue: `LocalPendingChangeEntityKind.historySession`.
- When a local-only row is linked to a different remote id, this fix acknowledges both the new logical key and the previous remote/local key to avoid a phantom pending count.

## Payload Fields

- Remote payload: `remote_id`, `payload_version`, `display_name`, `timestamp`, `supplier`, `category`, `is_manual_entry`, `data`, `session_overlay`, `owner_user_id`, `updated_at`, `deleted_at`.
- Overlay payload: `editable`, `complete`.
- Runtime totals are recomputed locally from `data` + `complete`.

## Tombstone Support

- iOS supports tombstone push via `deleted_at` and local `remoteDeletedAt`.
- Pull protects dirty local entries from remote tombstones.

## Duplicate Handling

- Before fix: same logical History session with different `remote_id` inserted as a second row.
- After fix: full pull and incremental apply both link by logical fingerprint when identity match is absent.
- Count summary now uses active user-visible non-tombstoned sessions locally and remotely.

## Trigger Automatici

- Push: `HistorySessionPushService.syncHistorySessions(mode: .incremental)`.
- Pull/drain: `SyncEventIncrementalDomainApplyService` delegates to `HistoryIncrementalApplyService`.
- Recovery/full pull: `HistorySessionSyncService.pullHistorySessionsFromCloud`.

