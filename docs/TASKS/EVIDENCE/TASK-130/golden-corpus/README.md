# TASK-130 Golden Corpus

Synthetic, privacy-safe fixture set for consolidated TASK-128 import/export hardening inside TASK-130.

Coverage intent:

- normal spreadsheet rows through the existing TASK-031 XLSX fixture;
- HTML Excel import through `task130-golden-excel.html`;
- legacy XLS support via existing `Vendor/libxls` corpus, with TASK-130 semantic XLS binary still marked PARTIAL;
- scientific-notation barcode;
- dot/comma prices;
- discount and discounted price;
- duplicate barcode;
- missing barcode;
- missing product name with second product name present;
- invalid retail price;
- negative quantity;
- full DB Products/Suppliers/Categories/PriceHistory sheets.

All names and values are synthetic and scoped with `TASK130_`. No live Supabase data is used.
