# TASK-108 Evidence 20 — History / Session Sync Parity

Status: IMPLEMENTED STATIC / LIVE BLOCKED. Do not claim PASS until app-auth History push/pull read-back clears dirty entries.

Schema and reference audit:
- `shared_sheet_sessions` exists and has owner-scoped authenticated RLS policies.
- `shared_sheet_sessions` includes payload v2 fields used by Android: `remote_id`, `payload_version`, `timestamp`, `supplier`, `category`, `is_manual_entry`, `data`, `display_name`, `session_overlay`, `owner_user_id`, `updated_at`.
- Android reference syncs history sessions directly through `shared_sheet_sessions`; Android excludes local-only fields such as export flag, local uid/id and local sync status from the remote payload.
- `sync_events` remains catalog/prices-only. This is a follow-up for event telemetry/cursor parity, not a blocker for direct Android-style session table sync.

Implemented iOS:
- New `HistorySessionSyncService` maps `HistoryEntry` to/from `shared_sheet_sessions`.
- Payload version 2 and overlay schema 1 are encoded with bounded overlay size.
- `HistoryEntry` now has remote bridge fields: `remoteID`, `remoteUpdatedAt`, `remoteDeletedAt`, `remotePayloadFingerprint`, local/synced revision counters.
- Push chooses dirty entries, ensures a stable remote id, upserts owner-scoped rows, verifies read-back, marks remote applied and acknowledges local pending.
- Pull pages remote sessions, inserts new entries, updates clean existing entries, and skips dirty local entries to avoid overwrites.
- `LocalPendingChange` now supports `historySession` and `historySessionSave`.
- `HistoryView` now exposes a read-only cloud status card; public History-only send/download actions were removed in the 2026-05-14 targeted FIX because Options `Sync now` is the global sync entry point.
- `GeneratedView` and `EntryInfoEditor` mark history/session pending when sheet state or metadata changes.

Tests:
- Push dirty history session and acknowledge pending: PASS.
- Pull remote history session into local SwiftData: PASS.
- Pull skips dirty local entry: PASS.
- Pending history sessions contribute to Options queued cloud operation count: PASS.

Not implemented yet / follow-up:
- `sync_events` domain/event type for history/session incremental cursor telemetry.
- Remote export flag, because Android payload v2 does not sync local export status.
- Remote tombstone/delete semantics for sessions; current policy remains review-first/no wipe.
- Live app-auth read-back smoke was NOT RUN due missing authenticated app session.

Verdict:
- Wave 6 core client functionality is no longer blocked.
- Backend follow-up is optional for richer event/cursor/delete/export parity and is documented in `10-task109-split-decision.md`.

Targeted Options cleanup FIX update 2026-05-13 20:45 -0400:
- History signed-out tab smoke after cleanup shows cloud actions disabled behind login and no crash.
- `HistorySessionSyncServiceTests` passed in the targeted TASK-108 run.
- Live History/session push/read-back remains NOT RUN / BLOCKED_APP_AUTH. Evidence: `28-live-history-session-smoke.md`.

Post-TASK-108 targeted FIX update 2026-05-14 00:38 -0400:
- UX cleanup PASS: History no longer shows public `Send` / `Download` buttons and instead shows read-only status plus Options `Sync now` hint.
- Global pending PASS: dirty local History entries are counted in Options pending summary via `LocalPendingChangeSnapshotProvider`.
- Live app-auth PARTIAL/BLOCKED: after a global `Sync now` attempt, the two local History entries still had no remote id/fingerprint and remained dirty.
- Likely blocker: live `shared_sheet_sessions` DML policy/grant or baseline/apply completion issue. This matches the Supabase repo’s known local migration that grants authenticated DML, but no live grant/RLS bypass was applied in this pass.
- Current verdict: STATIC INTEGRATION + UX PASS, LIVE HISTORY PUSH/PULL NOT PASSED.
