# Field merge runtime gate

Status: NOT_RUN / REVIEW_REQUIRED.

Required by TASK-133:
- Android `productName` + iOS `retailPrice` on same barcode: automatic merge, zero prompt, final has both.
- Android `category` + iOS `purchasePrice` on same barcode: automatic merge.

Evidence currently available:
- iOS targeted policy/recovery/merge tests: `../../TASK-132C-clean-baseline-20260617-115823/raw/ios-task132-policy-recovery-merge-tests-final.log`, exit `0`.
- Android targeted policy/import/merge tests: `../../TASK-132C-clean-baseline-20260617-115823/raw/android-task132-policy-import-merge-tests.log`, exit `0`.
- Live propagation benchmark: `ios-to-android.md`, `android-to-ios.md`.

Reason this is not PASS:
- The TASK-133 live benchmark used the existing TASK-123 single-propagation harness, whose measured kind is `catalog_product_create`.
- It does not inject concurrent different-field edits to the same existing barcode on iOS and Android.

