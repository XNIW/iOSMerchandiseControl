# Real Excel Manifest Redacted

Status: `PASS_WITH_NOTES`

## Real Files

Real Excel-like files were discoverable outside the repository, but none were operator-selected for TASK-104 and none had documented backup/rollback consent.

For privacy, this evidence intentionally does not include:

- file names;
- absolute paths;
- sheet names;
- row content;
- product names;
- barcodes;
- prices;
- hashes derived from real shop files.

## PASS 1 Executed Instead

Synthetic/anonymized import and large-dataset regression tests were executed on the iOS codebase. Android import/export unit tests were also executed. These prove regression health, not real-shop acceptance.

## PASS 1 Verdict Impact

In PASS 1, CA-104-07 and CA-104-08 were `BLOCKED`. Any future real-user-data run must start with an operator-selected small file, backup confirmation, and then a separate operator-selected large file.
## PASS 2 Update

No real Excel file was used. PASS2 used synthetic realistic fixtures:

| Fixture | Scope | Rows | Persistence |
|---------|-------|------|-------------|
| Small synthetic workbook | iOS live import/export harness | 50 products, 102 price rows | Temporary XCTest artifact, deleted by test cleanup. |
| Large synthetic workbook | iOS simulator large benchmark | 6,000 products, 240 suppliers, 160 categories, 24,000 price rows | Temporary XCTest artifact, deleted by test cleanup. |

Large metrics observed:
- full database XLSX size: about 1.108 MB
- product-only XLSX size: about 0.394 MB
- import core total duration: about 6.883 s
- full export/re-read duration: about 0.308 s
- ProductPrice apply duration: about 9.805 s

No Excel fixture or export was committed to the repository.
