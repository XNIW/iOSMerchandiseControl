# TASK-108 Evidence 16 — Release Error Taxonomy

Status: EXECUTED (UNIT).

Taxonomy mapping target:
- `accountRequired`: no usable OAuth/client session.
- `accountNeedsCheck`: OAuth exists but remote auth/session needs recovery.
- `cloudPermission`: permission/RLS/schema access problem.
- `networkOffline`: network unavailable or remote unreachable.
- `localNeedsDownload`: signed-in, local baseline missing/incomplete and no incompatible pending.
- `localPending`: local pending push exists.
- `needsReview`: conflicts/tombstones/review items exist.
- `ready`: no blocking condition.

Reducer tests:
- `accountRequired`: covered by signed-out test.
- `accountNeedsCheck`: covered by signed-in remote auth failure.
- `cloudPermission`: covered by permission test.
- `networkOffline`: reducer implemented, no dedicated test in this pass.
- `localNeedsDownload`: covered by missing baseline test.
- `localPending`: covered by valid baseline + pending test.
- `needsReview`: covered by review precedence test.
- `ready`: covered by no blocking inputs test.

FIX/COMPLETION update 2026-05-13:
- Taxonomy tests passed in the full 659/0 suite.
- Signed-in remote auth/permission failures still map to account/cloud check recovery, not inert sign-in.
- History/session pending is now included in the aggregate pending count that can drive `localPending`.
