# TASK-108 Evidence 25 — Live Incremental Pull Smoke

Status: NOT RUN / BLOCKED_APP_AUTH.

Planned:
- Start from a valid app-auth baseline.
- Modify or create a scoped remote test row with prefix `TASK108_INCREMENTAL_PULL_`.
- Background/foreground or relaunch the app.
- Verify one safe incremental pull, no dirty-local overwrite, SwiftData update, Database UI refresh, and Options last-check update.

Actual:
- No authenticated app session was obtained.
- No scoped remote rows were created or modified.
- Live incremental pull was not executed.

Non-live coverage:
- Targeted TASK-108 tests passed for lifecycle/debounce and safe automatic sync presentation.
- Debug simulator foreground/signed-out smoke did not crash.

