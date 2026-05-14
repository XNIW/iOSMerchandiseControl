# TASK-108 Evidence 28 — Live History / Session Smoke

Status: NOT RUN / BLOCKED_APP_AUTH.

Planned:
- Create a scoped `TASK108_HISTORY_` HistoryEntry.
- Push via app-auth to `shared_sheet_sessions`.
- Verify read-back, rename, complete state, editable values, dirty-skip, pending/ack, and owner safety.

Actual:
- No authenticated app session was obtained.
- No live History/session push/read-back was executed.
- No scoped History test data was created.

Non-live coverage:
- `HistorySessionSyncServiceTests` passed in targeted XCTest, covering push/ack, pull/restore, dirty-skip, and Options pending count.
- History signed-out UI smoke: `screenshots/2026-05-13-history-smoke-signed-out-after-fix.jpg`.

