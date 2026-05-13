# ProductPrice Current Previous

Status: `PASS`

## Executed

| Check | Result |
|-------|--------|
| iOS ProductPrice manual push service tests | PASS. |
| iOS ProductPrice apply service tests | PASS. |
| TASK-103 cross-platform regression tests selected for this run | PASS, with expected live-gated skips. |
| Supabase RLS metadata for `product_prices` | PASS_WITH_NOTES, table has RLS enabled and owner-scoped policy shape. |

## Not Executed

No real sentinel product was selected, so no current/previous price values were read or mutated on real shop data. No redacted pre/post ProductPrice table was generated.

## PASS 1 Verdict Impact

In PASS 1, CA-104-14 was `PARTIAL`, not `PASS`. The implementation had strong regression coverage, but TASK-104 specifically required an iOS/Supabase/Android read-back with sentinels.
## PASS 2 Update

ProductPrice current/previous verification passed in three scopes:

- iOS live sentinel: purchase and retail previous/current points were inserted and read back.
- Android live sentinel: Android pushed purchase and retail previous/current points; iOS pulled and applied them.
- Large synthetic benchmark: 6,000 products and 24,000 ProductPrice rows were applied locally; sample audits at first/middle/last product passed for purchase and retail current/previous.

Observed guards:
- duplicate ProductPrice push on Android returned no-op on the second write.
- same logical ProductPrice key with different price failed closed in iOS conflict test.
