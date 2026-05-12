# 06 - Foreground Auto Check

## Setup

Run id: `TASK103_REAL_R1778622799_`.

## Steps

1. Verify iOS foreground/review behavior through device XCTest on Android-created data.
2. Verify apply happens only through explicit apply call and is not silent.
3. Verify no-op after apply does not recreate a ghost review.
4. Static-check release foreground host gates: root foreground calls check path only, not apply/push.

## Expected

Foreground check detects cloud changes, then requires review/apply; no silent local apply, no silent push, no repeated ghost plan after no-op.

## Observed

- Android-to-iOS device XCTest inserted Android catalog and ProductPrice only after explicit apply calls.
- No-op preview after apply returned `noApplicableChanges`; ProductPrice no-op returned `.noApplicableRows` with four skipped existing rows.
- `ContentView` foreground host starts `startForegroundSemiAutomaticCheckIfAllowed(source: .rootForeground)` only; apply/push paths remain user-action driven.
- UX state evidence from existing contract tests confirms auth > permission > stale precedence and recovery CTA mapping.

## Result

`PASS` for CA-103-09.

## Notes/Redactions

No screenshots were needed for data proof; this file relies on physical device XCTest outputs plus static verification of the foreground host. No sensitive UI/account data is recorded.
