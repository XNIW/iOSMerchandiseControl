# D100 Dataset Manifest

| Dataset | Products | Suppliers | Categories | ProductPrice rows | Prefix | Source | Status |
|---------|----------|-----------|------------|-------------------|--------|--------|--------|
| D100-S | 1,000 | 80 | 50 | 4,000 | `TASK100_*` | synthetic XCTest | PASS |
| D100-M | 6,000 | 240 | 160 | 24,000 | `TASK100_*` | synthetic XCTest | PASS |
| D100-L | 12,000 | 480 | 320 | 48,000 | `TASK100_*` | synthetic XCTest on physical iPhone | PASS |
| TASK100-LIVE | 120 | 1 | 1 | 480 | `TASK100_LIVE_1778463255_` | live Supabase authenticated account | PASS / CLEANED |

## Dataset Policy

- No real customer/store data was used.
- Product, supplier, category, barcode, and remote identifiers were generated deterministically inside `Task100LargeDatasetAcceptanceTests`.
- Remote/Supabase-like row identity used UUIDs under the authenticated test owner used by the run.
- D100-L ran on physical iPhone with 12k products and 48k ProductPrice rows. Workbook size for full DB/import path: 2.218 MB.
- Live Supabase data used only `TASK100_LIVE_*` synthetic names/barcodes. Cleanup for `TASK100_LIVE_1778463255_` completed via admin/postgres scoped delete after authenticated RLS/delete permission blocked the app cleanup path.
- Final remote residue for `TASK100_LIVE_1778463255_`: 0 supplier, 0 category, 0 products, 0 ProductPrice rows.
