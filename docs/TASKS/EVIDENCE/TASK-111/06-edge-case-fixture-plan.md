# TASK-111 — 06 Edge Case / Fixture Plan

## OBSERVED — Covered by tests in this pass

- Locale numbers IT/EN style, currency prefixes, spaces, scientific barcode.
- Excel percent 0–1 discount conversion.
- discountedPrice precedence.
- Duplicate barcode: warning + last row base + quantity aggregation.
- barcode missing.
- product name / second name missing.
- purchase negative.
- retail zero for new product.
- quantity negative.
- discount outside 0–100.
- old/current purchase and retail ProductPrice history.
- supplier/category mixed case/trim resolver.
- side-effect-free preview.
- HTML Excel fixture with colspan/rowspan and footer/subtotal row shape.

## OBSERVED — Existing regression coverage reused

- TASK-036 HTML fixtures for nested table, colspan, rowspan, title rows, decorative table.
- TASK-100 synthetic large datasets and ProductPrice current/previous benchmarks.
- TASK-105 small import dedupe, export roundtrip and large import/apply.

## ASSUMED

- Runtime-generated XLSX tests are preferred over committed binary `.xlsx` for privacy and diff hygiene.
- `.xls` legacy path remains covered by build/bridge audit, not a new binary fixture in this pass.

## NOT_RUN / Follow-up candidates

- Corrupted/quasi-empty workbook runtime test.
- Hidden row/hidden column semantic parity.
- Formula/error-cell semantics beyond cached/readable values.
- Real legacy `.xls` fixture from libxls path.
- Full cancel UI flow under large import.
