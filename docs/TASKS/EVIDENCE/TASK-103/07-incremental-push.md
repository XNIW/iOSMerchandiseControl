# 07 - Incremental Push / Idempotency

## Setup

Run id: `TASK103_REAL_R1778622799_`.

## Steps

1. Run iOS SMOKE push and second no-op.
2. Run Android SMOKE second no-op.
3. Run iOS MEDIUM import push with multiple catalog/ProductPrice records.
4. Run offline/retry no-op after retry.
5. Compare scoped read-back counts and canaries.

## Expected

No duplicate remote/local rows, ProductPrice dedupe by `(type, effectiveAt)`, pending changes acknowledged or retryable as appropriate, second no-op clean.

## Observed

- iOS SMOKE: `price_inserted=4 no_op=true`.
- Android SMOKE: `second_noop_pushed=0`.
- MEDIUM iOS push: `products=50 prices=102 catalog_status=completed price_inserted=102 price_batches=2 remote_medium_products=50 export_spotcheck=true duration_s=4.16`.
- Offline/retry: `offline_status=failedBeforeWrite retry_status=completed remote_products=1 no_duplicate=true no_op=true`.
- Pre-cleanup scoped SQL count: 55 products and 55 distinct product barcodes, confirming no duplicate barcode rows in the run.

## Result

`PASS` for CA-103-10.

## Notes/Redactions

No request bodies, keys or tokens are stored. Batch count is approximate evidence from the test output.
