# 05 - Android to Supabase to iOS

## Setup

Run id: `TASK103_REAL_R1778622799_`; owner hash `ad3d747e936c`.

## Steps

1. Create Android SMOKE supplier/category/product on physical Android.
2. Record deterministic ProductPrice history and push through existing Android repository/sync path.
3. Read back scoped remote data.
4. Apply Android remote data on iOS through existing review/apply services.
5. Verify iOS local state and second no-op.

## Expected

The Android canary appears once remotely and in iOS local data with purchase 21.10/22.35 and retail 31.90/33.50.

## Observed

- Initial Android harness failure: ProductPrice current row used current time instead of deterministic manifest time.
- Fix lane: Android test harness creates product without initial current prices, records deterministic price history, then updates current fields directly.
- Initial rerun failure: scoped cleanup removed remote parent rows while local parent refs were marked applied.
- Fix lane: Android test harness marks supplier/category dirty before sync using existing public repository API.
- Android rerun passed: `TASK103_ANDROID_WRITE_SMOKE owner_hash=ad3d747e936c pushed_catalog=3 pushed_prices=4 product_hash=6ca9936ec03d second_noop_pushed=0`.
- Initial iOS harness no-op failure: stale preview object reused after local apply.
- Fix lane: iOS test harness regenerates no-op preview as unchanged and verifies ProductPrice `.noApplicableRows`.
- iOS rerun passed: `TASK103_IOS_PULL_ANDROID owner_hash=ad3d747e936c inserted_catalog=1 inserted_prices=4 no_op=true`.
- Scoped SQL read-back for `TASK103_REAL_R1778622799_ANDROID_0001`: product name `TASK103_REAL_R1778622799_CANARY_ANDROID_01`, purchase `22.35`, retail `33.5`, four ProductPrice rows, effectiveAt range `2026-05-12 14:00:00` to `2026-05-12 14:15:00`.

## Result

`PASS_AFTER_FIX` for CA-103-07 and CA-103-08.

## Notes/Redactions

The only cleanup during fix was scoped to the failed Android SMOKE canary under this run prefix. No schema/RLS/grant/migration changed.
