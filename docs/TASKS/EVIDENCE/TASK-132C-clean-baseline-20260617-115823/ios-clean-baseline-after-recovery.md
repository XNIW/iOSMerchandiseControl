# iOS clean baseline after automatic recovery

| metric | value |
|---|---:|
| products_active | 19695 |
| products_total | 19695 |
| suppliers_active | 59 |
| categories_active | 28 |
| product_prices | 41109 |
| history_active | 35 |
| pending_active | 0 |
| outbox_active | 0 |
| baseline_runs | 3 |
| baseline_records | 59343 |
| task_suppliers | 0 |
| task_categories | 0 |
| task_products | 0 |
| task_prices | 0 |
| task_history | 0 |


Evidence:
- Raw polling: `raw/ios-recovery-poll-counts.txt`.
- Table schema snapshot: `raw/ios-swiftdata-table-info-after-recovery.txt`.
- Defaults snapshot: `raw/ios-defaults-after-recovery-final.txt`.

Notes:
- Store-only reset preserved auth/session.
- First recovery pass reached ProductPrice target while lookup counts were still settling; a second recovery pass restarted ProductPrice apply and then settled.
- Polls 4-12 stayed stable at Supabase parity with active pending/outbox = 0 and TASK user-visible residue = 0.
