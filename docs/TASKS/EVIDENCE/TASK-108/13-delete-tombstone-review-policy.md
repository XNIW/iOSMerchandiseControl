# TASK-108 Evidence 13 — Delete / Tombstone Review Policy

Status: EXECUTED (STATIC).

Initial audit:
- Database supplier/category/product delete paths already create local pending changes in the TASK-107 code path.
- Remote tombstones/conflicts must remain review-first for pull/apply.

Evidence:
- No delete/tombstone behavior was made more destructive.
- Remote conflicts/tombstones still flow through review state and local apply guards.
- Live tombstone/delete review matrix NOT RUN.

FIX/COMPLETION update 2026-05-13:
- History/session sync does not implement silent remote delete wipe.
- `remoteDeletedAt` bridge field exists for future policy, but current apply path preserves dirty/local data and does not delete local sessions from remote absence.
- Remote delete/tombstone semantics for shared sessions remain a backend/policy follow-up.
