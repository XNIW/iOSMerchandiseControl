# Android No-Push Evidence After Fix

- Tipo verifica: EMU/RUNTIME + SUPABASE/READONLY
- Scenario: app signed-in, local store has no real pending outbox, reopen after reinstall preserving data.

| signal | before after-fix reopen | after after-fix reopen | result |
|---|---:|---:|---|
| Supabase sync_events total | 1980 | 1980 | PASS no new sync_events |
| Latest sync_event id | 3035 | 3035 | PASS unchanged |
| Android sync_event_outbox_total | 0 | 0 | PASS |
| Android products | 19698 | 19698 | unchanged |
| Android suppliers | 61 | 61 | unchanged |
| Android categories | 30 | 30 | unchanged |
| Android product_prices | 41115 | 41115 | unchanged |

Notes:
- First Android runtime attempt before this fix failed because reopen emitted a `history_changed` event id `3035`.
- After the `HistorySessionPushCoordinator` fix, the latest row remains id `3035`; no row was inserted during the rerun.
- Raw evidence: `raw/supabase-sync-events-before-android-reopen-after-fix.raw`, `raw/supabase-sync-events-after-android-reopen-after-fix.raw`, `raw/supabase-sync-events-latest-after-android-fix.raw`, `raw/android-logcat-reopen-after-fix-filtered.txt`.

