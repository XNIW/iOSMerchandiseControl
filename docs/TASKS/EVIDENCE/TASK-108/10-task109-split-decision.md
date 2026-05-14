# TASK-108 Evidence 10 — TASK-109 Split Decision

Status: BLOCKED_SCHEMA_OR_POLICY proposal.

Current decision:
- Do not split functional parity out of TASK-108 just because it is large.
- A backend/schema TASK-109 is allowed only for precise `BLOCKED_SCHEMA_OR_POLICY` items.

Initial schema blocker candidate:
- Local Supabase migration `20260424021936_task045_sync_events.sql` supports `catalog` and `prices` domains, not `history` / `session`. History/session incremental event parity may require migration/RLS/RPC follow-up.

Proposed backend TASK-109:
- Extend `sync_events` domain/event-type checks and `record_sync_event` RPC to support `history` / `session`.
- Add/confirm owner-scoped RLS for history/session event recording and read-back.
- Add client-safe cursor/read policy for session events.
- Decide whether `LocalPendingChange` gains `historyEntry/sharedSheetSession` entity kind or a dedicated session outbox table.

FIX/COMPLETION decision 2026-05-13:
- TASK-109 is no longer required to unblock core TASK-108 History/session parity.
- Core iOS sync now uses the existing `shared_sheet_sessions` table directly, matching the Android reference behavior.
- Backend follow-up remains useful only for richer event/cursor telemetry through `sync_events`, remote delete/tombstone semantics, and any future decision to sync local export status.
- `LocalPendingChange` now has a `historySession` entity kind in iOS; no dedicated session outbox table was added.
