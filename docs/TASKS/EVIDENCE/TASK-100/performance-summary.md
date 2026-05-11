# TASK-100 Performance Summary

Final local/simulator metrics are from `/tmp/task100_full_xctest_after_readonly_final.log` on iOS Simulator `iPhone 17 Pro`, iOS 26.4. Physical metrics are from `iPhone di Min` (`iPhone 15 Pro Max`, iOS 26.4.2).

| scenario_id | dataset_class | device_target | row_counts | file_size_mb | time_to_first_feedback_s | total_duration_s | result_state | failure_mode | notes_redacted |
|-------------|---------------|---------------|------------|--------------|--------------------------|------------------|--------------|--------------|----------------|
| S100-B-D100-S | D100-S | XCTest_synthetic | products=1000; suppliers=80; categories=50; product_prices=4000 | n/a | 0.000 | 0.000 | PASS | none | Synthetic manifest generated; privacy OK |
| S100-B-D100-M | D100-M | XCTest_synthetic | products=6000; suppliers=240; categories=160; product_prices=24000 | n/a | 0.000 | 0.000 | PASS | none | Synthetic manifest generated; privacy OK |
| S100-C | D100-M | XCTest_SwiftData_in_memory | products=6000; suppliers=240; categories=160; product_prices=24000 | 1.108 | 0.000 | 6.856 | PASS | none | Excel parsed and import core applied |
| S100-D-products-export | D100-M | XCTest_DEBUG_export_harness | products=6000 | 0.394 | 0.000 | 0.111 | PASS | none | Products XLSX generated and re-read |
| S100-D-full-db-export | D100-M | XCTest_DEBUG_export_harness | products=6000; suppliers=240; categories=160; product_prices=24000 | 1.108 | 0.000 | 0.322 | PASS | none | Full database XLSX generated and re-read |
| S100-E-preview | D100-M | XCTest_fake_SupabasePullPreviewService | products=6000; suppliers=240; categories=160; product_prices=24000; product_pages=9; price_pages=33 | n/a | 0.000 | 1.114 | PASS | none | Bounded paged preview |
| S100-F | D100-M | XCTest_SupabaseProductPriceApplyService | products=6000; product_prices=24000 | n/a | 0.000 | 11.736 | PASS | none | ProductPrice current/previous audit passed |
| S100-G-cancel-retry | D100-M | XCTest_SupabaseManualSyncViewModel_fake | not_applicable | n/a | 0.004 | 0.006 | PASS | none | Running state exposes cancel; cancelled state exposes retry |
| S100-C-D100-L | D100-L | physical iPhone XCTest | products=12000; suppliers=480; categories=320; product_prices=48000 | 2.218 | 0.000 | 13.732 | PASS | none | Excel parsed and import core applied |
| S100-D-full-db-export-D100-L | D100-L | physical iPhone XCTest | products=12000; suppliers=480; categories=320; product_prices=48000 | 2.218 | 0.000 | 0.617 | PASS | none | Full DB XLSX generated for import path |
| S100-E-preview-D100-L | D100-L | physical iPhone XCTest | products=12000; suppliers=480; categories=320; product_prices=48000; product_pages=13; price_pages=49 | n/a | 0.000 | 2.064 | PASS | none | Device log reported one 14.85s launch-overlap hang detection |
| S100-F-D100-L | D100-L | physical iPhone XCTest | products=12000; product_prices=48000 | n/a | 0.000 | 20.845 | PASS | none | ProductPrice current/previous audit passed |
| S100-I-live-catalog-push | TASK100-LIVE | physical iPhone + live Supabase | products=120; suppliers=1; categories=1; product_prices=480 | n/a | 0.000 | 1.652 | PASS | none | Collision scan clear; catalog pushed |
| S100-I-live-price-push | TASK100-LIVE | physical iPhone + live Supabase | products=120; suppliers=1; categories=1; product_prices=480; price_batches=5; dedupe_pages=5 | n/a | 0.000 | 5.917 | PASS | none | ProductPrice push and duplicate recovery verified |
| S100-I-live-readonly-verify | TASK100-LIVE | physical iPhone + live Supabase read-only | products=120; suppliers=1; categories=1; product_prices=480; product_pages=3; price_pages=10 | n/a | 0.000 | 2.461 | PASS | none | Existing live rows previewed and applied locally without remote mutation |
| S100-I-live-targeted-cleanup | TASK100-LIVE | physical iPhone + live Supabase | before=suppliers=1; categories=1; products=120; product_prices=480 | n/a | 0.000 | 0.518 | BLOCKED | cleanup_permission_denied_or_failed | Authenticated delete denied on `inventory_product_prices` |
| S100-I-live-admin-cleanup | TASK100-LIVE | Supabase linked DB admin/postgres | before=suppliers=1; categories=1; products=120; product_prices=480; deleted=suppliers=1;categories=1;products=120;product_prices=480; after=0/0/0/0 | n/a | 0.000 | 5.072 | PASS | none | Scoped SQL cleanup; no policy/grant changes |
| S100-I-live-targeted-cleanup-verification | TASK100-LIVE | physical iPhone + live Supabase | before=suppliers=0; categories=0; products=0; product_prices=0; deleted=0/0/0/0; after=0/0/0/0 | n/a | 0.000 | 0.504 | PASS | none | Physical cleanup test confirmed no residue |

## Performance Fixes / Notes

- ProductPrice D100-M initially took about 37s before the formatter-cache fix. Final D100-M S100-F is 11.736s; physical D100-L S100-F is 20.845s.
- The D100-L physical run completed without crash/OOM. iOS logged one `Hang detected: 14.85s (overlaps extended launch)` during the D100-L sequence; this is recorded as an under-load UX observation, not a data-integrity failure.
- Live Supabase global/unbounded preview was stopped during investigation after it ran too long; the verified path uses scoped TASK100 rows and bounded paging.
- Final live cleanup is complete. The earlier authenticated cleanup failure remains historical evidence of the intended RLS posture; final scoped admin cleanup and physical verification both pass.
