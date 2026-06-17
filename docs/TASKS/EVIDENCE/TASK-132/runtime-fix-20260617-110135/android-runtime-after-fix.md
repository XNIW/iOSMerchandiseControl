# Android Runtime After Fix

- Tipo verifica: EMU/RUNTIME + SQLITE + SUPABASE/READONLY
- Device: `emulator-5554`
- Package: `com.example.merchandisecontrolsplitview`
- APK reinstall: PASS, `raw/android-install-after-fix.exit = 0`
- Runtime window: `raw/android-reopen-after-fix-started-at.txt` -> `raw/android-reopen-after-fix-ended-at.txt`
- Screenshot: `android-after-fix-screenshot.png`
- UI tree: `raw/android-ui-after-fix.xml`

| metric | before first run | after fix rerun | delta vs first run |
|---|---:|---:|---:|
| products | 19698 | 19698 | 0 |
| suppliers | 61 | 61 | 0 |
| categories | 30 | 30 | 0 |
| product_prices | 41115 | 41115 | 0 |
| history_entries | 90 | 90 | 0 |
| pending_catalog_tombstones | 0 | 0 | 0 |
| sync_event_outbox_total | 0 | 0 | 0 |
| sync_event_watermarks | 1 | 1 | 0 |
| sync_event_device_state | 1 | 1 | 0 |

## Local TASK Residue After Fix

| metric | count |
|---|---:|
| suppliers_TASK_prefix | 2 |
| categories_TASK_prefix | 2 |
| products_TASK_prefix | 3 |
| history_TASK_contains | 54 |

## Runtime Signals

- Auth restored: `SupabaseAuth: Sessione ripristinata`.
- Catalog foreground push blocked: `cycle=catalog_push outcome=skip reason=automatic_push_safety_guard originalReason=foreground policy=non_local_trigger`.
- Bootstrap skipped because not needed: `cycle=catalog_bootstrap outcome=skip reason=not_needed`.
- Sync events drain stayed no-op: `syncEventOutboxInserted=0`, `catalogEventEmitted=false`, `priceEventEmitted=false`, `syncEventsFetched=0`, watermark `3035 -> 3035`.
- History login fresh tick no longer emitted an event: `sessionsAttempted=0 sessionsUploaded=0 dirtySetMode=full_reconcile`.

