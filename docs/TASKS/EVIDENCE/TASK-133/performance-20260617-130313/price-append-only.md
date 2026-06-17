# Price append-only runtime gate

Status: NOT_RUN / REVIEW_REQUIRED.

Required by TASK-133:
- Android retailPrice T1 + iOS retailPrice T2 create two ProductPrice rows.
- Current price resolves to newest effectiveAt/event ordering.
- Duplicate count remains zero.

Evidence currently available:
- iOS policy/product-price regression batch: `../../TASK-132C-clean-baseline-20260617-115823/raw/ios-task132-policy-recovery-merge-tests-final.log`, exit `0`.
- Android policy/import/merge regression batch: `../../TASK-132C-clean-baseline-20260617-115823/raw/android-task132-policy-import-merge-tests.log`, exit `0`.
- Final duplicate/residue proxy: final active ProductPrice parity is `41109` on Supabase, iOS, and Android.

Reason this is not PASS:
- No strict live TASK-133 T1/T2 cross-device price fixture was run after clean baseline.

