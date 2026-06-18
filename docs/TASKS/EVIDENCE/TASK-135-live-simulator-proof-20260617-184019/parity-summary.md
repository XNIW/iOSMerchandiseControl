# TASK-135 parity summary

Generated: 2026-06-17 20:45 -0400

## Final active/user-visible counts

| surface | products | suppliers | categories | product_prices | history_sessions |
|---|---:|---:|---:|---:|---:|
| Supabase | 19704 | 66 | 35 | 41131 | 39 |
| iOS | 19704 | 66 | 35 | 41131 | 39 |
| Android | 19704 | 66 | 35 | 41131 | 39 |

## Gates

| gate | result | evidence |
|---|---|---|
| Catalog iOS -> Supabase -> Android | PASS | `raw/ios-cross-single-20260617_193032.log`, `counts/fixture-presence-ios-cross-supabase.json`, `counts/fixture-presence-ios-cross-android.txt` |
| Catalog Android -> Supabase -> iOS | PASS | `raw/android-cross-single-20260617_193207.log`, `counts/fixture-presence-android-cross-supabase.json`, `counts/fixture-presence-android-cross-ios.txt` |
| ProductPrice append-only | PASS | `raw/live-task135-mutation-near-realtime-report.json`: iOS->Android price events 3 / targeted price ids 13; Android->iOS price events 2 / targeted price ids 9; `missingTargetsForChangedEvents=0`; `fullPullUsed=false` |
| History/session propagation | PASS | `raw/live-task135-mutation-near-realtime-report.json`: history events 3 each direction, targeted session ids 5 each direction |
| Clean reopen / no false push | PASS | `counts/sync-events-before-clean-reopen-after-backfill-cleanup.json` and `counts/sync-events-after-clean-reopen-after-backfill-cleanup.json`: count 1848, max id 3100 both before and after |
| iOS Options clean state | PASS | `screenshots/ios-options-clean-reopen-after-backfill-cleanup-final.jpg`; runtime snapshot showed pending local changes 0 and `Database locale aggiornato` |
| iOS Options generic last sync label | PASS | `screenshots/ios-options-last-sync-label-final.jpg`; runtime snapshot shows `Ultima sincronizzazione` and no pull-specific legacy label |
| Android Options clean state | PASS | `screenshots/android-options-final-unified-no-header-20260617-2044.png`; XML shows `Up to date`, `Database locale pronto`, no public pending row, no `Cuenta cloud`, no `Waiting to sync` |
| iOS Options public UX polish | PASS | `screenshots/ios-options-final-no-tip-public-ux-20260617-2042.jpg`; no `Suggerimento`, no public pending row, `Ultima sincronizzazione`, clean counts |
| Android Options public UX polish | PASS | `screenshots/android-options-final-unified-no-header-20260617-2044.png`; single compact account/sync card, no redundant header, masked email, no public `Cambios locales pendientes`, no `Cuenta cloud`, no `Waiting to sync` |
| Post-polish counts parity | PASS | `counts/final-after-unified-no-header-supabase-counts.json`, `counts/final-after-unified-no-header-ios-counts.json`, `counts/final-after-unified-no-header-android-counts.json`: all `19704/66/35/41131/39`, iOS/Android pending aggregate 0 |
| Post-polish clean reopen / no false push | PASS | `counts/sync-events-after-unified-no-header.json`: count 1848, max id 3100 |

## Notes

- Android clean reopen initially exposed two generated `BACKFILL_CURR` ProductPrice rows without `product_price_remote_refs` for the iOS cross fixture. The final patch prevents cloud-linked products from receiving legacy backfill rows and removes only cloud-linked `BACKFILL_CURR` rows with no remote bridge.
- Final Android pending evidence: `counts/android-after-backfill-cleanup-pending-state.txt` reports `prices_pending_bridge=0`, `product_prices_total=41131`, `price_refs_total=41131`, outbox 0, tombstones 0.
- Final count JSONs: `counts/final-after-clean-reopen-supabase-counts.json`, `counts/final-after-clean-reopen-ios-counts.json`, `counts/final-after-clean-reopen-android-counts.json`.
- Post-label count JSONs: `counts/final-after-last-sync-label-supabase-counts.json`, `counts/final-after-last-sync-label-ios-counts.json`, `counts/final-after-last-sync-label-android-counts.json`.
- Post-label clean reopen invariant: `counts/sync-events-after-last-sync-label.json` reports count 1848, max id 3100.
- Public UX polish final count JSONs: `counts/final-after-unified-no-header-supabase-counts.json`, `counts/final-after-unified-no-header-ios-counts.json`, `counts/final-after-unified-no-header-android-counts.json`.
- Public UX polish did not change core sync runtime; it only removed public implementation rows and redundant cards/headers.
