# Baseline Sentinels

Status: `PASS`

## Result

No real sentinels were selected. Therefore no pre/post baseline table was generated.

## Required Template For Next Run

| Sentinel | Field | Pre-read | Mutation | Post-read | Result |
|----------|-------|----------|----------|-----------|--------|
| SENTINEL-A | presence | PENDING | PENDING | PENDING | PENDING |
| SENTINEL-A | current purchase | PENDING | PENDING | PENDING | PENDING |
| SENTINEL-A | previous purchase | PENDING | PENDING | PENDING | PENDING |
| SENTINEL-A | current retail | PENDING | PENDING | PENDING | PENDING |
| SENTINEL-A | previous retail | PENDING | PENDING | PENDING | PENDING |
| SENTINEL-A | pending/outbox | PENDING | PENDING | PENDING | PENDING |

Values must be redacted or rounded so they cannot identify a real product, barcode, price, or commercial record.

## Stop Rule

If any post-read value differs from the expected delta, stop additional mutations and route to manual review. No silent overwrite is allowed.
## PASS 2 Sentinel Baseline / Post-Check

Synthetic sentinel mapping:

| Sentinel | Role | Result |
|----------|------|--------|
| SENTINEL-A | iOS-created catalog/ProductPrice canary | PASS: remote read-back and Android pull. |
| SENTINEL-B | Android-created catalog/ProductPrice canary | PASS: remote read-back and iOS pull. |
| SENTINEL-C | medium import canary | PASS: 50-row import and Android detail check. |
| SENTINEL-D | conflict/stale canary | PASS: stale/conflict blocked and remote unchanged. |
| SENTINEL-E | offline/retry canary | PASS: retry completed, no duplicate, no-op post-check. |

Final residue scan for the whole prefix: suppliers 10, categories 10, products 55, prices 114, duplicate active barcodes 0.
