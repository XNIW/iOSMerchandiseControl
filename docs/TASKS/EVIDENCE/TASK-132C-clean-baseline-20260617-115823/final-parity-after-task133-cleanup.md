# Final parity after TASK-133 cleanup

| source | products active | suppliers active | categories active | product_prices | history active | pending/outbox | TASK user-visible |
|---|---:|---:|---:|---:|---:|---:|---:|
| Supabase | 19695 | 59 | 28 | 41109 | 35 | n/a | 0 |
| iOS simulator | 19695 | 59 | 28 | 41109 | 35 | 0 / 0 | 0 |
| Android emulator | 19695 | 59 | 28 | 41109 | 35 | 0 / 0 | 0 |

Evidence:
- Supabase final counts: `../TASK-133/performance-20260617-130313/raw/final-supabase-counts-after-task133-sync-event-cleanup.raw`.
- Supabase final residue: `../TASK-133/performance-20260617-130313/raw/final-supabase-task-residue-after-task133-sync-event-cleanup.raw`.
- iOS local counts: `../TASK-133/performance-20260617-130313/raw/final-ios-local-counts-after-final-no-push.txt`.
- Android local counts: `../TASK-133/performance-20260617-130313/raw/final-android-local-counts-after-final-no-push.txt`.

Notes:
- Supabase `inventory_products` total is 19696 because one product is tombstoned; active parity is 19695.
- Supabase `shared_sheet_sessions` total is 87 because 52 sessions are tombstoned; active parity is 35.
- TASK-133 benchmark `sync_events` id `3036..3065` were backed up to `backup_task133_sync_events_20260617_174403` and deleted. Final `sync_events` returned to 1823 with max id 3035.
- Android local watermark remains at 3065 after processing benchmark events before cleanup. This is safe for future events because Postgres sequence will continue above the watermark; it is recorded as diagnostic state, not user-visible drift.

